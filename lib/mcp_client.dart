import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

class McpClient {
  HttpClient? _client;

  void cancel() {
    _client?.close(force: true);
    _client = null;
  }

  Future<String> test(McpServerConfig server) async {
    final url = server.url.trim();
    if (url.isEmpty) {
      throw const McpException('请先填写 MCP 服务地址。');
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const McpException('MCP 服务地址不可用。');
    }

    _client = HttpClient();
    try {
      final transport = server.transport.trim().toLowerCase();
      if (transport == 'sse') {
        return await _testSse(uri, server.customHeadersJson);
      }
      return await _testStreamableHttp(uri, server.customHeadersJson);
    } on TimeoutException {
      throw const McpException('MCP 服务无响应。');
    } on SocketException {
      throw const McpException('网络连接失败。');
    } finally {
      _client?.close();
      _client = null;
    }
  }

  Future<String> _testSse(Uri uri, String headersJson) async {
    final request = await _client!.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    _applyHeaders(request, headersJson);
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain();
      throw McpException('MCP 连接失败 (${response.statusCode})。');
    }
    return '连接成功';
  }

  Future<String> _testStreamableHttp(Uri uri, String headersJson) async {
    final request = await _client!.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/json, text/event-stream',
    );
    _applyHeaders(request, headersJson);
    request.write(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2025-06-18',
          'capabilities': <String, Object?>{},
          'clientInfo': {'name': 'Chait', 'version': '1.0.0'},
        },
      }),
    );
    final response = await request.close().timeout(const Duration(seconds: 20));
    final contentType = response.headers.contentType?.mimeType ?? '';
    if (contentType == 'text/event-stream') {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain();
        throw McpException('MCP 连接失败 (${response.statusCode})。');
      }
      return '连接成功';
    }
    final raw = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw McpException('MCP 连接失败 (${response.statusCode})。');
    }
    final decoded = _tryDecodeJson(raw);
    if (decoded is Map && decoded['error'] != null) {
      throw McpException(_errorMessage(decoded['error']));
    }
    return '连接成功';
  }

  void _applyHeaders(HttpClientRequest request, String source) {
    for (final entry in _decodeJsonObject(source).entries) {
      request.headers.set(entry.key, entry.value.toString());
    }
  }

  Map<String, Object?> _decodeJsonObject(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return {};
    }
    final decoded = _tryDecodeJson(trimmed);
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
    return {};
  }

  Object? _tryDecodeJson(String source) {
    try {
      return jsonDecode(source);
    } catch (_) {
      return null;
    }
  }

  String _errorMessage(Object? error) {
    if (error is Map) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
    }
    return 'MCP 服务返回错误。';
  }
}

class McpException implements Exception {
  const McpException(this.message);

  final String message;

  @override
  String toString() => message;
}
