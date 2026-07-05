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
    required this.baseUrl,
    required this.model,
    this.customHeadersJson = '{}',
    this.messagePayloads,
    this.tools = const [],
  });

  final AppSettings settings;
  final String apiKey;
  final AssistantPreset assistant;
  final List<ChatMessage> messages;
  final String baseUrl;
  final String model;
  final String customHeadersJson;
  final List<Map<String, Object?>>? messagePayloads;
  final List<AiToolDefinition> tools;
}

class AiToolDefinition {
  const AiToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, Object?> parameters;

  Map<String, Object?> toJson() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };
}

class AiToolCall {
  AiToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final String arguments;

  Map<String, Object?> toOpenAiJson() => {
        'id': id,
        'type': 'function',
        'function': {
          'name': name,
          'arguments': arguments,
        },
      };
}

class AiChatResult {
  const AiChatResult({
    required this.content,
    required this.raw,
    required this.toolCalls,
  });

  final String content;
  final String raw;
  final List<AiToolCall> toolCalls;
}

class AiClient {
  HttpClient? _client;

  void cancel() {
    _client?.close(force: true);
    _client = null;
  }

  Future<AiChatResult> sendChat({
    required AiRequestConfig config,
    required void Function(String delta) onDelta,
    required void Function(String raw) onRaw,
    required bool Function() isCancelled,
    void Function(String toolName)? onToolCall,
  }) async {
    final baseUrl = config.baseUrl.trim();
    final model = config.model.trim();

    if (baseUrl.isEmpty || model.isEmpty || config.apiKey.trim().isEmpty) {
      throw const AiException('请先在设置里配置 API 地址、密钥和模型。');
    }

    final uri = _chatUri(baseUrl);
    final body = _buildBody(config, model);
    final headers = _decodeJsonObject(config.customHeadersJson);

    _client = HttpClient();
    try {
      final request = await _client!.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader,
          'Bearer ${config.apiKey.trim()}');
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value.toString());
      }
      request.write(jsonEncode(body));

      final response =
          await request.close().timeout(const Duration(seconds: 90));
      final status = response.statusCode;

      if (status < 200 || status >= 300) {
        final errorBody = await response.transform(utf8.decoder).join();
        throw AiException('请求失败 ($status)：${_compactError(errorBody)}');
      }

      if (config.settings.stream && body['stream'] == true) {
        final result = await _readStream(
          response,
          onDelta,
          onRaw,
          isCancelled,
          onToolCall,
        );
        return AiChatResult(
          content: result.content,
          raw: result.raw,
          toolCalls: result.toolCalls,
        );
      } else {
        final raw = await response.transform(utf8.decoder).join();
        onRaw(raw);
        final decoded = jsonDecode(raw);
        final content = _extractFullContent(decoded);
        final toolCalls = _extractToolCalls(decoded);
        if (content.trim().isNotEmpty) {
          onDelta(content);
        }
        if (toolCalls.isNotEmpty) {
          onToolCall?.call(toolCalls.first.name);
        }
        return AiChatResult(
          content: content,
          raw: raw,
          toolCalls: toolCalls,
        );
      }
    } finally {
      _client?.close();
      _client = null;
    }
  }

  Future<List<AiModelConfig>> fetchModels({
    required AiProviderConfig provider,
    required String apiKey,
  }) async {
    if (provider.baseUrl.trim().isEmpty) {
      throw const AiException('请先填写服务商 Base URL。');
    }

    _client = HttpClient();
    final request = await _client!.getUrl(_modelsUri(provider));
    request.headers.contentType = ContentType.json;
    if (apiKey.trim().isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    }
    for (final entry in _decodeJsonObject(provider.customHeadersJson).entries) {
      request.headers.set(entry.key, entry.value.toString());
    }

    final response = await request.close().timeout(const Duration(seconds: 45));
    final raw = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiException('获取模型失败 (${response.statusCode})：${_compactError(raw)}');
    }

    final decoded = jsonDecode(raw);
    final list = _extractModelList(decoded);
    if (list.isEmpty) {
      throw const AiException('服务商没有返回可识别的模型列表。');
    }

    final refreshedAt = DateTime.now();
    final models = <AiModelConfig>[];
    for (final rawModel in list) {
      final id = _firstString(rawModel, const ['id', 'name', 'model', 'slug']);
      var enriched = rawModel;
      if (id.isNotEmpty && !_hasUsefulMetadata(rawModel)) {
        final detail = await _tryFetchModelDetail(
          provider: provider,
          apiKey: apiKey,
          modelId: id,
        );
        if (detail.isNotEmpty) {
          enriched = {...rawModel, ...detail};
        }
      }
      final parsed = _parseModel(provider, enriched, refreshedAt);
      if (parsed.name.trim().isNotEmpty) {
        models.add(parsed);
      }
    }
    return models..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<String> fetchBalance({
    required AiProviderConfig provider,
    required String apiKey,
  }) async {
    if (provider.baseUrl.trim().isEmpty ||
        provider.balancePath.trim().isEmpty) {
      return '';
    }
    _client = HttpClient();
    try {
      final request = await _client!.getUrl(_balanceUri(provider));
      request.headers.contentType = ContentType.json;
      if (apiKey.trim().isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      }
      for (final entry
          in _decodeJsonObject(provider.customHeadersJson).entries) {
        request.headers.set(entry.key, entry.value.toString());
      }
      final response =
          await request.close().timeout(const Duration(seconds: 20));
      final raw = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return '';
      }
      final decoded = _tryDecodeJson(raw);
      final balance = _extractBalance(decoded, provider.balanceJsonPath);
      return balance.trim();
    } finally {
      _client?.close();
      _client = null;
    }
  }

  Future<String> generateText({
    required AppSettings settings,
    required String apiKey,
    required AssistantPreset assistant,
    required String baseUrl,
    required String model,
    required String customHeadersJson,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.2,
    int maxTokens = 512,
  }) async {
    final tempSettings = AppSettings.fromJson(settings.toJson())
      ..stream = false
      ..temperature = temperature
      ..maxTokens = maxTokens;
    final taskAssistant = AssistantPreset(
      id: 'task-${newEntityId()}',
      name: '任务助手',
      description: '',
      systemPrompt: systemPrompt,
      temperature: temperature,
      maxTokens: maxTokens,
    );
    var text = '';
    await sendChat(
      config: AiRequestConfig(
        settings: tempSettings,
        apiKey: apiKey,
        assistant: taskAssistant,
        messages: [
          ChatMessage(
            id: newEntityId(),
            role: 'user',
            content: userPrompt,
            createdAt: DateTime.now(),
          ),
        ],
        baseUrl: baseUrl,
        model: model,
        customHeadersJson: customHeadersJson,
      ),
      onDelta: (delta) => text += delta,
      onRaw: (_) {},
      isCancelled: () => false,
    );
    return text.trim();
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

  Uri _modelsUri(AiProviderConfig provider) {
    final baseUrl = provider.baseUrl.trim();
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final path = provider.modelsPath.trim().isEmpty
        ? '/models'
        : provider.modelsPath.trim();
    if (normalized.endsWith(path)) {
      return Uri.parse(normalized);
    }
    if (normalized.endsWith('/chat/completions')) {
      return Uri.parse(
        '${normalized.substring(0, normalized.length - '/chat/completions'.length)}$path',
      );
    }
    return Uri.parse('$normalized$path');
  }

  Uri _balanceUri(AiProviderConfig provider) {
    final baseUrl = provider.baseUrl.trim();
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final path = provider.balancePath.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    if (normalized.endsWith(path)) {
      return Uri.parse(normalized);
    }
    return Uri.parse('$normalized${path.startsWith('/') ? path : '/$path'}');
  }

  Uri _modelDetailUri(AiProviderConfig provider, String modelId) {
    final modelsUri = _modelsUri(provider).toString();
    final encoded = Uri.encodeComponent(modelId);
    return Uri.parse('${modelsUri.endsWith('/') ? modelsUri : '$modelsUri/'}$encoded');
  }

  Future<Map<String, Object?>> _tryFetchModelDetail({
    required AiProviderConfig provider,
    required String apiKey,
    required String modelId,
  }) async {
    try {
      final request = await _client!.getUrl(_modelDetailUri(provider, modelId));
      request.headers.contentType = ContentType.json;
      if (apiKey.trim().isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      }
      for (final entry in _decodeJsonObject(provider.customHeadersJson).entries) {
        request.headers.set(entry.key, entry.value.toString());
      }
      final response =
          await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain();
        return {};
      }
      final raw = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, Object?>.from(decoded);
      }
    } catch (_) {
      return {};
    }
    return {};
  }

  Map<String, Object?> _buildBody(AiRequestConfig config, String model) {
    final settings = config.settings;
    final assistant = config.assistant;
    final systemPrompt = assistant.compiledSystemPrompt().trim();
    final body = <String, Object?>{
      'model': model,
      'stream': settings.stream,
      'temperature': assistant.temperature ?? settings.temperature,
      'top_p': assistant.topP ?? settings.topP,
      'max_tokens': assistant.maxTokens ?? settings.maxTokens,
      'presence_penalty': settings.presencePenalty,
      'frequency_penalty': settings.frequencyPenalty,
      'messages': config.messagePayloads ??
          [
            if (systemPrompt.isNotEmpty)
              {
                'role': 'system',
                'content': systemPrompt,
              },
            ...config.messages.map(
              (message) => {
                'role': message.role,
                'content': message.content,
              },
            ),
          ],
    };

    if (config.tools.isNotEmpty) {
      body['tools'] = config.tools.map((tool) => tool.toJson()).toList();
    }

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

  List<Map<String, Object?>> _extractModelList(Object? decoded) {
    if (decoded is List) {
      return decoded
          .map((item) {
            if (item is Map) {
              return Map<String, Object?>.from(item);
            }
            return <String, Object?>{'id': item?.toString() ?? ''};
          })
          .toList();
    }
    if (decoded is Map) {
      for (final key in ['data', 'models', 'items']) {
        final value = decoded[key];
        if (value is List) {
          return value.map((item) {
            if (item is Map) {
              return Map<String, Object?>.from(item);
            }
            return <String, Object?>{'id': item?.toString() ?? ''};
          }).toList();
        }
      }
    }
    return [];
  }

  AiModelConfig _parseModel(
    AiProviderConfig provider,
    Map<String, Object?> raw,
    DateTime refreshedAt,
  ) {
    final id = _firstString(raw, const ['id', 'name', 'model', 'slug']);
    final displayName =
        _firstString(raw, const ['display_name', 'displayName', 'label']);
    final supportedParameters = _stringList(raw['supported_parameters']);
    final capabilities = _mapValue(raw['capabilities']);
    final architecture = _mapValue(raw['architecture']);
    final topProvider = _mapValue(raw['top_provider']);

    final inputModalities = <String>{
      ..._stringList(raw['input_modalities']),
      ..._stringList(raw['inputModalities']),
      ..._stringList(architecture['input_modalities']),
      ..._stringList(architecture['inputModalities']),
      ..._stringList(raw['modalities']),
    }.toList()
      ..sort();
    final outputModalities = <String>{
      ..._stringList(raw['output_modalities']),
      ..._stringList(raw['outputModalities']),
      ..._stringList(architecture['output_modalities']),
      ..._stringList(architecture['outputModalities']),
    }.toList()
      ..sort();

    return AiModelConfig(
      id: modelConfigId(provider.id, id),
      providerId: provider.id,
      providerName: provider.name,
      name: id,
      displayName: displayName.isEmpty ? id : displayName,
      contextWindow: _firstInt(
        raw,
        const [
          'context_length',
          'contextLength',
          'context_window',
          'contextWindow',
          'max_context_length',
          'max_input_tokens',
        ],
      ) ??
          _toInt(topProvider['context_length']),
      maxOutputTokens: _firstInt(
        raw,
        const [
          'max_output_tokens',
          'maxOutputTokens',
          'max_completion_tokens',
          'max_tokens',
        ],
      ),
      supportsTools: _boolCapability(
        raw,
        capabilities,
        supportedParameters,
        const ['tools', 'tool_calls', 'function_calling', 'function_call'],
      ),
      supportsToolChoice: _boolCapability(
        raw,
        capabilities,
        supportedParameters,
        const ['tool_choice'],
      ),
      supportsVision: _boolCapability(
            raw,
            capabilities,
            supportedParameters,
            const ['vision', 'image', 'images', 'image_url'],
          ) ??
          inputModalities.any((item) => item.contains('image')),
      supportsJsonMode: _boolCapability(
        raw,
        capabilities,
        supportedParameters,
        const ['json', 'json_mode', 'response_format'],
      ),
      supportsStructuredOutput: _boolCapability(
        raw,
        capabilities,
        supportedParameters,
        const ['structured_outputs', 'json_schema'],
      ),
      supportsStreaming: _boolCapability(
            raw,
            capabilities,
            supportedParameters,
            const ['stream', 'streaming'],
          ) ??
          true,
      inputModalities: inputModalities,
      outputModalities: outputModalities,
      rawJson: jsonEncode(raw),
      refreshedAt: refreshedAt,
    );
  }

  bool _hasUsefulMetadata(Map<String, Object?> raw) {
    const keys = [
      'context_length',
      'contextLength',
      'context_window',
      'max_output_tokens',
      'supported_parameters',
      'capabilities',
      'architecture',
      'top_provider',
      'input_modalities',
      'output_modalities',
      'modalities',
    ];
    return keys.any(raw.containsKey);
  }

  Future<_StreamReadResult> _readStream(
    HttpClientResponse response,
    void Function(String delta) onDelta,
    void Function(String raw) onRaw,
    bool Function() isCancelled,
    void Function(String toolName)? onToolCall,
  ) async {
    final rawBuffer = StringBuffer();
    final contentBuffer = StringBuffer();
    final toolAccumulator = _ToolCallAccumulator();
    var toolNotified = false;
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
          contentBuffer.write(delta);
          onDelta(delta);
        }
        final seenTool = toolAccumulator.addFromChunk(decoded);
        if (seenTool && !toolNotified) {
          toolNotified = true;
          onToolCall?.call(toolAccumulator.firstToolName);
        }
      } catch (_) {
        if (data.isNotEmpty) {
          contentBuffer.write(data);
          onDelta(data);
        }
      }
    }
    final raw = rawBuffer.toString();
    onRaw(raw);
    return _StreamReadResult(
      content: contentBuffer.toString(),
      raw: raw,
      toolCalls: toolAccumulator.toToolCalls(),
    );
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

  List<AiToolCall> _extractToolCalls(Object? decoded) {
    if (decoded is! Map) {
      return const [];
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      return const [];
    }
    final first = Map<String, Object?>.from(choices.first as Map);
    final message = first['message'];
    if (message is Map) {
      return _toolCallsFromList(message['tool_calls']);
    }
    final delta = first['delta'];
    if (delta is Map) {
      return _toolCallsFromList(delta['tool_calls']);
    }
    return const [];
  }

  List<AiToolCall> _toolCallsFromList(Object? value) {
    if (value is! List) {
      return const [];
    }
    final calls = <AiToolCall>[];
    for (var index = 0; index < value.length; index += 1) {
      final item = value[index];
      if (item is! Map) {
        continue;
      }
      final map = Map<String, Object?>.from(item);
      final function = _mapValue(map['function']);
      final name = _contentToText(function['name']).trim();
      final arguments = _contentToText(function['arguments']).trim();
      if (name.isEmpty) {
        continue;
      }
      var id = _contentToText(map['id']).trim();
      if (id.isEmpty) {
        id = 'call_$index';
      }
      calls.add(AiToolCall(id: id, name: name, arguments: arguments));
    }
    return calls;
  }

  String _extractBalance(Object? decoded, String jsonPath) {
    if (decoded == null) {
      return '';
    }
    if (jsonPath.trim().isNotEmpty) {
      final value = _valueAtPath(decoded, jsonPath.trim());
      final text = _balanceText(value);
      if (text.isNotEmpty) {
        return text;
      }
    }
    if (decoded is Map) {
      final map = Map<String, Object?>.from(decoded);
      final data = _mapValue(map['data']);
      final openRouterCredit = _toDouble(data['total_credits']);
      final openRouterUsage = _toDouble(data['total_usage']);
      if (openRouterCredit != null && openRouterUsage != null) {
        return _formatNumber(openRouterCredit - openRouterUsage);
      }
      for (final candidate in [map, data]) {
        final balanceInfos = candidate['balance_infos'];
        if (balanceInfos is List && balanceInfos.isNotEmpty) {
          final parts = <String>[];
          for (final item in balanceInfos.whereType<Map>()) {
            final info = Map<String, Object?>.from(item);
            final amount = _balanceText(
              info['total_balance'] ?? info['balance'] ?? info['amount'],
            );
            final currency = _contentToText(info['currency']).trim();
            if (amount.isNotEmpty) {
              parts.add(currency.isEmpty ? amount : '$amount $currency');
            }
          }
          if (parts.isNotEmpty) {
            return parts.join(' / ');
          }
        }
        for (final key in const [
          'balance',
          'total_balance',
          'totalBalance',
          'available_balance',
          'availableBalance',
          'credit',
          'credits',
          'quota',
          'amount',
          'money',
        ]) {
          final text = _balanceText(candidate[key]);
          if (text.isNotEmpty) {
            return text;
          }
        }
      }
    }
    return '';
  }

  Object? _valueAtPath(Object? value, String path) {
    Object? current = value;
    for (final segment in path.split('.')) {
      if (current is Map) {
        current = current[segment];
      } else if (current is List) {
        final index = int.tryParse(segment);
        current = index == null || index < 0 || index >= current.length
            ? null
            : current[index];
      } else {
        return null;
      }
    }
    return current;
  }

  String _balanceText(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is num) {
      return _formatNumber(value.toDouble());
    }
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is Map) {
      final map = Map<String, Object?>.from(value);
      final amount = _balanceText(
        map['amount'] ?? map['value'] ?? map['balance'],
      );
      final currency = _contentToText(map['currency']).trim();
      if (amount.isNotEmpty && currency.isNotEmpty) {
        return '$amount $currency';
      }
      return amount;
    }
    return '';
  }

  String _formatNumber(double value) {
    final fixed = value.toStringAsFixed(4);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
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

  String _firstString(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num || value is bool) {
        return value.toString();
      }
    }
    return '';
  }

  int? _firstInt(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = _toInt(map[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  Map<String, Object?> _mapValue(Object? value) {
    if (value is Map) {
      return Map<String, Object?>.from(value);
    }
    return {};
  }

  List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return [value.trim().toLowerCase()];
    }
    return [];
  }

  bool? _boolCapability(
    Map<String, Object?> raw,
    Map<String, Object?> capabilities,
    List<String> supportedParameters,
    List<String> names,
  ) {
    for (final name in names) {
      final direct = raw[name] ?? capabilities[name];
      if (direct is bool) {
        return direct;
      }
      if (direct is String) {
        final normalized = direct.toLowerCase();
        if (normalized == 'true' || normalized == 'supported') {
          return true;
        }
        if (normalized == 'false' || normalized == 'unsupported') {
          return false;
        }
      }
    }
    if (supportedParameters.any((item) => names.contains(item))) {
      return true;
    }
    return null;
  }

  int? _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  double? _toDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
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

class _StreamReadResult {
  const _StreamReadResult({
    required this.content,
    required this.raw,
    required this.toolCalls,
  });

  final String content;
  final String raw;
  final List<AiToolCall> toolCalls;
}

class _ToolCallAccumulator {
  final Map<int, _MutableToolCall> _calls = {};

  String get firstToolName {
    if (_calls.isEmpty) {
      return '';
    }
    return _calls.values.first.name.trim();
  }

  bool addFromChunk(Object? decoded) {
    if (decoded is! Map) {
      return false;
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      return false;
    }
    final first = Map<String, Object?>.from(choices.first as Map);
    final delta = first['delta'];
    if (delta is! Map) {
      return false;
    }
    final toolCalls = delta['tool_calls'];
    if (toolCalls is! List || toolCalls.isEmpty) {
      return false;
    }
    for (var fallbackIndex = 0; fallbackIndex < toolCalls.length; fallbackIndex += 1) {
      final item = toolCalls[fallbackIndex];
      if (item is! Map) {
        continue;
      }
      final map = Map<String, Object?>.from(item);
      final index = _toInt(map['index']) ?? fallbackIndex;
      final mutable = _calls.putIfAbsent(index, () => _MutableToolCall());
      final id = _contentToText(map['id']).trim();
      if (id.isNotEmpty) {
        mutable.id = id;
      }
      final function = _mapValue(map['function']);
      final name = _contentToText(function['name']);
      if (name.isNotEmpty) {
        mutable.name += name;
      }
      final arguments = _contentToText(function['arguments']);
      if (arguments.isNotEmpty) {
        mutable.arguments += arguments;
      }
    }
    return true;
  }

  List<AiToolCall> toToolCalls() {
    final entries = _calls.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final calls = <AiToolCall>[];
    for (final entry in entries) {
      final call = entry.value;
      if (call.name.trim().isEmpty) {
        continue;
      }
      calls.add(
        AiToolCall(
          id: call.id.trim().isEmpty ? 'call_${entry.key}' : call.id.trim(),
          name: call.name.trim(),
          arguments: call.arguments.trim(),
        ),
      );
    }
    return calls;
  }

  int? _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  Map<String, Object?> _mapValue(Object? value) {
    if (value is Map) {
      return Map<String, Object?>.from(value);
    }
    return {};
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
    return '';
  }
}

class _MutableToolCall {
  String id = '';
  String name = '';
  String arguments = '';
}
