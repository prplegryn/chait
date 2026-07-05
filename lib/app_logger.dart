import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();
  static const _channel = MethodChannel('chait.app/logs');

  final List<String> _earlyEntries = [];
  Future<void> _pending = Future<void>.value();
  IOSink? _privateSink;
  File? _privateFile;
  String _fileName = '';
  String _publicPath = '';
  String _nativeFailure = '';
  bool _started = false;
  bool _nativeFailureRecorded = false;

  String get fileName => _fileName;
  String get privatePath => _privateFile?.path ?? '';
  String get publicPath => _publicPath;
  String get nativeFailure => _nativeFailure;

  String get visiblePath {
    if (_publicPath.isNotEmpty) {
      return _publicPath;
    }
    if (_fileName.isNotEmpty) {
      return '/storage/emulated/0/Download/Chait/logs/$_fileName';
    }
    return privatePath;
  }

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    _fileName = 'chait-${_stampForFile(DateTime.now())}.log.txt';
    try {
      final dir = await _resolvePrivateLogDirectory();
      await dir.create(recursive: true);
      _privateFile = File('${dir.path}/$_fileName');
      _privateSink = _privateFile!.openWrite(mode: FileMode.writeOnlyAppend);
      await _deleteOldLogs(dir);
      for (final entry in _earlyEntries) {
        _privateSink?.write(entry);
      }
      _earlyEntries.clear();
      info(
        'logger',
        'started private=$privatePath publicHint=$visiblePath',
      );
    } catch (error, stack) {
      _earlyEntries.add(
        _format('ERROR', 'logger', 'start failed: $error', stack),
      );
    }
  }

  void event(String tag, Map<String, Object?> values) {
    info(tag, values.entries.map((entry) {
      final value = entry.value;
      return '${entry.key}=${value ?? 'null'}';
    }).join(' '));
  }

  void info(String tag, String message) {
    _log('INFO', tag, message);
  }

  void debug(String tag, String message) {
    _log('DEBUG', tag, message);
  }

  void warning(String tag, String message, [Object? error, StackTrace? stack]) {
    _log(
      'WARN',
      tag,
      error == null ? message : '$message: $error',
      stack,
    );
  }

  void error(String tag, Object error, [StackTrace? stack]) {
    _log('ERROR', tag, error.toString(), stack);
  }

  Future<void> flush() async {
    await _pending;
    await _privateSink?.flush();
  }

  Future<void> close() async {
    await flush();
    await _privateSink?.close();
  }

  void _log(String level, String tag, String message, [StackTrace? stack]) {
    final entry = _format(level, tag, message, stack);
    if (!_started) {
      _earlyEntries.add(entry);
      return;
    }
    _pending = _pending.then((_) => _write(entry));
  }

  Future<void> _write(String entry) async {
    try {
      _privateSink?.write(entry);
      await _privateSink?.flush();
    } catch (_) {
      // Logging must never crash the app.
    }

    if (kIsWeb || !Platform.isAndroid || _fileName.isEmpty) {
      return;
    }
    try {
      final path = await _channel.invokeMethod<String>('append', {
        'fileName': _fileName,
        'text': entry,
      }).timeout(const Duration(seconds: 2));
      if (path != null && path.isNotEmpty) {
        _publicPath = path;
      }
    } catch (error) {
      _nativeFailure = error.toString();
      if (!_nativeFailureRecorded) {
        _nativeFailureRecorded = true;
        try {
          _privateSink?.write(
            _format(
              'WARN',
              'logger',
              'public log write failed: $_nativeFailure',
            ),
          );
          await _privateSink?.flush();
        } catch (_) {}
      }
    }
  }

  String _format(
    String level,
    String tag,
    String message, [
    StackTrace? stack,
  ]) {
    final buffer = StringBuffer()
      ..write(DateTime.now().toIso8601String())
      ..write(' ')
      ..write(level.padRight(5))
      ..write(' ')
      ..write(tag)
      ..write(' ')
      ..writeln(_redact(message));
    if (stack != null) {
      buffer.writeln(_redact(stack.toString()));
    }
    return buffer.toString();
  }

  String _redact(String value) {
    return value
        .replaceAllMapped(
          RegExp(
            r'(authorization|api[-_ ]?key|apikey|token|password|secret)\s*[:=]\s*[^,\s}\]]+',
            caseSensitive: false,
          ),
          (match) => '${match.group(1)}=<redacted>',
        )
        .replaceAll(RegExp(r'sk-[A-Za-z0-9_-]{12,}'), 'sk-<redacted>')
        .replaceAll(
          RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]{12,}', caseSensitive: false),
          'Bearer <redacted>',
        );
  }

  Future<Directory> _resolvePrivateLogDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        return Directory('${external.path}/chait-logs');
      }
    }
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/chait-logs');
  }

  Future<void> _deleteOldLogs(Directory dir) async {
    try {
      final logs = dir
          .listSync()
          .whereType<File>()
          .where((file) =>
              file.path.endsWith('.log') || file.path.endsWith('.log.txt'))
          .toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      for (final file in logs.skip(20)) {
        try {
          await file.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  String _stampForFile(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}-'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }
}
