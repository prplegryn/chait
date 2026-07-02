import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

class AiRequestConfig {
  AiRequestConfig({
    required this.settings,
    required this.apiKey,
    required this.assistant,
    required this.messages,
  });

  final AppSettings settings;
  final String apiKey;
  final AssistantPreset assistant;
  final List<ChatMessage> messages;
}

class AiClient {
  HttpClient? _client;

  void cancel() {
    _client?.close(force: true);
    _client = null;
  }

  Future<void> sendChat({
    required AiRequestConfig config,
    required void Function(String delta) onDelta,
    required void Function(String raw) onRaw,
    required bool Function() isCancelled,
  }) async {
    final baseUrl = config.settings.baseUrl.trim();
    final model = (config.assistant.modelOverride.trim().isNotEmpty
            ? config.assistant.modelOverride
            : config.settings.model)
        .trim();

    if (baseUrl.isEmpty || model.isEmpty || config.apiKey.trim().isEmpty) {
      throw const AiException('请先在设置里配置 API 地址、密钥和模型。');
    }

    final uri = _chatUri(baseUrl);
    final body = _buildBody(config, model);
    final headers = _decodeJsonObject(config.settings.customHeadersJson);

    _client = HttpClient();
    final request = await _client!.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader,
        'Bearer ${config.apiKey.trim()}');
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value.toString());
    }
    request.write(jsonEncode(body));

    final response = await request.close().timeout(const Duration(seconds: 90));
    final status = response.statusCode;

    if (status < 200 || status >= 300) {
      final errorBody = await response.transform(utf8.decoder).join();
      throw AiException('请求失败 ($status)：${_compactError(errorBody)}');
    }

    if (config.settings.stream && body['stream'] == true) {
      await _readStream(response, onDelta, onRaw, isCancelled);
    } else {
      final raw = await response.transform(utf8.decoder).join();
      onRaw(raw);
      final content = _extractFullContent(jsonDecode(raw));
      if (content.trim().isNotEmpty) {
        onDelta(content);
      }
    }
  }

  Uri _chatUri(String baseUrl) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    if (normalized.endsWith('/chat/completions')) {
      return Uri.parse(normalized);
    }
    return Uri.parse('$normalized/chat/completions');
  }

  Map<String, Object?> _buildBody(AiRequestConfig config, String model) {
    final settings = config.settings;
    final assistant = config.assistant;
    final body = <String, Object?>{
      'model': model,
      'stream': settings.stream,
      'temperature': assistant.temperature ?? settings.temperature,
      'top_p': assistant.topP ?? settings.topP,
      'max_tokens': assistant.maxTokens ?? settings.maxTokens,
      'presence_penalty': settings.presencePenalty,
      'frequency_penalty': settings.frequencyPenalty,
      'messages': [
        if (assistant.systemPrompt.trim().isNotEmpty)
          {
            'role': 'system',
            'content': assistant.systemPrompt.trim(),
          },
        ...config.messages.map(
          (message) => {
            'role': message.role,
            'content': message.content,
          },
        ),
      ],
    };

    final seed = int.tryParse(settings.seed.trim());
    if (seed != null) {
      body['seed'] = seed;
    }

    final stops = settings.stopSequences
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (stops.isNotEmpty) {
      body['stop'] = stops.length == 1 ? stops.first : stops;
    }

    final responseFormat = settings.responseFormat.trim();
    if (responseFormat.isNotEmpty) {
      final decoded = _tryDecodeJson(responseFormat);
      body['response_format'] = decoded ?? {'type': responseFormat};
    }

    body.addAll(_decodeJsonObject(settings.extraBodyJson));
    return body;
  }

  Future<void> _readStream(
    HttpClientResponse response,
    void Function(String delta) onDelta,
    void Function(String raw) onRaw,
    bool Function() isCancelled,
  ) async {
    final rawBuffer = StringBuffer();
    await for (final line
        in response.transform(utf8.decoder).transform(const LineSplitter())) {
      if (isCancelled()) {
        break;
      }
      if (!line.startsWith('data:')) {
        continue;
      }
      final data = line.substring(5).trim();
      if (data.isEmpty || data == '[DONE]') {
        continue;
      }
      rawBuffer.writeln(data);
      try {
        final decoded = jsonDecode(data);
        final delta = _extractDelta(decoded);
        if (delta.isNotEmpty) {
          onDelta(delta);
        }
      } catch (_) {
        if (data.isNotEmpty) {
          onDelta(data);
        }
      }
    }
    onRaw(rawBuffer.toString());
  }

  String _extractDelta(Object? decoded) {
    if (decoded is! Map) {
      return '';
    }

    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final first = Map<String, Object?>.from(choices.first as Map);
      final delta = first['delta'];
      if (delta is Map) {
        return _contentToText(delta['content']);
      }
      final message = first['message'];
      if (message is Map) {
        return _contentToText(message['content']);
      }
      return _contentToText(first['text']);
    }

    final outputText = decoded['output_text'];
    if (outputText is String) {
      return outputText;
    }

    return '';
  }

  String _extractFullContent(Object? decoded) {
    if (decoded is! Map) {
      return '';
    }

    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final first = Map<String, Object?>.from(choices.first as Map);
      final message = first['message'];
      if (message is Map) {
        return _contentToText(message['content']);
      }
      final delta = first['delta'];
      if (delta is Map) {
        return _contentToText(delta['content']);
      }
      return _contentToText(first['text']);
    }

    final outputText = decoded['output_text'];
    if (outputText is String) {
      return outputText;
    }

    final candidates = decoded['candidates'];
    if (candidates is List && candidates.isNotEmpty && candidates.first is Map) {
      final candidate = Map<String, Object?>.from(candidates.first as Map);
      final content = candidate['content'];
      if (content is Map) {
        final parts = content['parts'];
        if (parts is List) {
          return parts.map((part) => _contentToText(part)).join();
        }
      }
    }

    return _contentToText(decoded['content']);
  }

  String _contentToText(Object? content) {
    if (content == null) {
      return '';
    }
    if (content is String) {
      return content;
    }
    if (content is num || content is bool) {
      return content.toString();
    }
    if (content is List) {
      return content.map(_contentToText).join();
    }
    if (content is Map) {
      final map = Map<String, Object?>.from(content);
      for (final key in ['text', 'content', 'output_text']) {
        final value = map[key];
        final text = _contentToText(value);
        if (text.isNotEmpty) {
          return text;
        }
      }
      return jsonEncode(content);
    }
    return content.toString();
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

  String _compactError(String body) {
    final decoded = _tryDecodeJson(body);
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is Map) {
        return _contentToText(error['message']).trim();
      }
      if (error is String) {
        return error;
      }
    }
    return body.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class AiException implements Exception {
  const AiException(this.message);

  final String message;

  @override
  String toString() => message;
}
