import 'dart:convert';

String newEntityId() => DateTime.now().microsecondsSinceEpoch.toString();

class AssistantPreset {
  AssistantPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    this.modelOverride = '',
    this.preferredModelId = '',
    this.temperature,
    this.topP,
    this.maxTokens,
  });

  final String id;
  String name;
  String description;
  String systemPrompt;
  String modelOverride;
  String preferredModelId;
  double? temperature;
  double? topP;
  int? maxTokens;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'systemPrompt': systemPrompt,
        'modelOverride': modelOverride,
        'preferredModelId': preferredModelId,
        'temperature': temperature,
        'topP': topP,
        'maxTokens': maxTokens,
      };

  factory AssistantPreset.fromJson(Map<String, Object?> json) {
    return AssistantPreset(
      id: json['id'] as String? ?? newEntityId(),
      name: json['name'] as String? ?? '助手',
      description: json['description'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String? ?? '',
      modelOverride: json['modelOverride'] as String? ?? '',
      preferredModelId: json['preferredModelId'] as String? ??
          json['modelOverride'] as String? ??
          '',
      temperature: _toDouble(json['temperature']),
      topP: _toDouble(json['topP']),
      maxTokens: _toInt(json['maxTokens']),
    );
  }
}

class AiProviderConfig {
  AiProviderConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.isCustom = false,
    this.customHeadersJson = '{}',
    this.modelsPath = '/models',
    this.updatedAt,
  });

  final String id;
  String name;
  String baseUrl;
  bool isCustom;
  String customHeadersJson;
  String modelsPath;
  DateTime? updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'isCustom': isCustom,
        'customHeadersJson': customHeadersJson,
        'modelsPath': modelsPath,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory AiProviderConfig.fromJson(Map<String, Object?> json) {
    return AiProviderConfig(
      id: json['id'] as String? ?? newEntityId(),
      name: json['name'] as String? ?? '自定义服务商',
      baseUrl: json['baseUrl'] as String? ?? '',
      isCustom: json['isCustom'] as bool? ?? false,
      customHeadersJson: json['customHeadersJson'] as String? ?? '{}',
      modelsPath: json['modelsPath'] as String? ?? '/models',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

class AiModelConfig {
  AiModelConfig({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.name,
    String? displayName,
    this.enabled = false,
    this.contextWindow,
    this.maxOutputTokens,
    this.supportsTools,
    this.supportsToolChoice,
    this.supportsVision,
    this.supportsJsonMode,
    this.supportsStructuredOutput,
    this.supportsStreaming,
    List<String>? inputModalities,
    List<String>? outputModalities,
    this.rawJson = '{}',
    this.refreshedAt,
  })  : displayName = displayName ?? name,
        inputModalities = inputModalities ?? [],
        outputModalities = outputModalities ?? [];

  final String id;
  String providerId;
  String providerName;
  String name;
  String displayName;
  bool enabled;
  int? contextWindow;
  int? maxOutputTokens;
  bool? supportsTools;
  bool? supportsToolChoice;
  bool? supportsVision;
  bool? supportsJsonMode;
  bool? supportsStructuredOutput;
  bool? supportsStreaming;
  final List<String> inputModalities;
  final List<String> outputModalities;
  String rawJson;
  DateTime? refreshedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'providerId': providerId,
        'providerName': providerName,
        'name': name,
        'displayName': displayName,
        'enabled': enabled,
        'contextWindow': contextWindow,
        'maxOutputTokens': maxOutputTokens,
        'supportsTools': supportsTools,
        'supportsToolChoice': supportsToolChoice,
        'supportsVision': supportsVision,
        'supportsJsonMode': supportsJsonMode,
        'supportsStructuredOutput': supportsStructuredOutput,
        'supportsStreaming': supportsStreaming,
        'inputModalities': inputModalities,
        'outputModalities': outputModalities,
        'rawJson': rawJson,
        'refreshedAt': refreshedAt?.toIso8601String(),
      };

  factory AiModelConfig.fromJson(Map<String, Object?> json) {
    final name = json['name'] as String? ?? '';
    return AiModelConfig(
      id: json['id'] as String? ?? modelConfigId(
        json['providerId'] as String? ?? 'custom',
        name,
      ),
      providerId: json['providerId'] as String? ?? 'custom',
      providerName: json['providerName'] as String? ?? '自定义服务商',
      name: name,
      displayName: json['displayName'] as String? ?? name,
      enabled: json['enabled'] as bool? ?? false,
      contextWindow: _toInt(json['contextWindow']),
      maxOutputTokens: _toInt(json['maxOutputTokens']),
      supportsTools: json['supportsTools'] as bool?,
      supportsToolChoice: json['supportsToolChoice'] as bool?,
      supportsVision: json['supportsVision'] as bool?,
      supportsJsonMode: json['supportsJsonMode'] as bool?,
      supportsStructuredOutput: json['supportsStructuredOutput'] as bool?,
      supportsStreaming: json['supportsStreaming'] as bool?,
      inputModalities:
          (json['inputModalities'] as List?)?.whereType<String>().toList(),
      outputModalities:
          (json['outputModalities'] as List?)?.whereType<String>().toList(),
      rawJson: json['rawJson'] as String? ?? '{}',
      refreshedAt: DateTime.tryParse(json['refreshedAt'] as String? ?? ''),
    );
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isStreaming = false,
    this.error = '',
    this.raw = '',
  });

  final String id;
  final String role;
  String content;
  final DateTime createdAt;
  bool isStreaming;
  String error;
  String raw;

  bool get isUser => role == 'user';

  Map<String, Object?> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'isStreaming': isStreaming,
        'error': error,
        'raw': raw,
      };

  factory ChatMessage.fromJson(Map<String, Object?> json) {
    return ChatMessage(
      id: json['id'] as String? ?? newEntityId(),
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isStreaming: json['isStreaming'] as bool? ?? false,
      error: json['error'] as String? ?? '',
      raw: json['raw'] as String? ?? '',
    );
  }
}

class ChatSession {
  ChatSession({
    required this.id,
    required this.assistantId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.modelId = '',
    this.pinned = false,
  });

  final String id;
  String assistantId;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<ChatMessage> messages;
  String modelId;
  bool pinned;

  bool get isEmpty => messages.isEmpty;

  Map<String, Object?> toJson() => {
        'id': id,
        'assistantId': assistantId,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((message) => message.toJson()).toList(),
        'modelId': modelId,
        'pinned': pinned,
      };

  factory ChatSession.fromJson(Map<String, Object?> json) {
    final messagesJson = json['messages'];
    final messages = <ChatMessage>[];
    if (messagesJson is List) {
      for (final item in messagesJson) {
        if (item is Map) {
          messages.add(ChatMessage.fromJson(Map<String, Object?>.from(item)));
        }
      }
    }

    return ChatSession(
      id: json['id'] as String? ?? newEntityId(),
      assistantId: json['assistantId'] as String? ?? '',
      title: json['title'] as String? ?? '新对话',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      messages: messages,
      modelId: json['modelId'] as String? ?? '',
      pinned: json['pinned'] as bool? ?? false,
    );
  }
}

class AppSettings {
  AppSettings({
    this.baseUrl = '',
    this.model = '',
    List<AiProviderConfig>? providers,
    List<AiModelConfig>? models,
    this.defaultModelId = '',
    this.titleModelId = '',
    this.polishModelId = '',
    this.stream = true,
    this.temperature = 0.7,
    this.topP = 1,
    this.maxTokens = 2048,
    this.presencePenalty = 0,
    this.frequencyPenalty = 0,
    this.seed = '',
    this.stopSequences = '',
    this.responseFormat = '',
    this.customHeadersJson = '{}',
    this.extraBodyJson = '{}',
    this.haptics = true,
  })  : providers = providers ?? [],
        models = models ?? [];

  String baseUrl;
  String model;
  final List<AiProviderConfig> providers;
  final List<AiModelConfig> models;
  String defaultModelId;
  String titleModelId;
  String polishModelId;
  bool stream;
  double temperature;
  double topP;
  int maxTokens;
  double presencePenalty;
  double frequencyPenalty;
  String seed;
  String stopSequences;
  String responseFormat;
  String customHeadersJson;
  String extraBodyJson;
  bool haptics;

  Map<String, Object?> toJson() => {
        'baseUrl': baseUrl,
        'model': model,
        'providers': providers.map((provider) => provider.toJson()).toList(),
        'models': models.map((model) => model.toJson()).toList(),
        'defaultModelId': defaultModelId,
        'titleModelId': titleModelId,
        'polishModelId': polishModelId,
        'stream': stream,
        'temperature': temperature,
        'topP': topP,
        'maxTokens': maxTokens,
        'presencePenalty': presencePenalty,
        'frequencyPenalty': frequencyPenalty,
        'seed': seed,
        'stopSequences': stopSequences,
        'responseFormat': responseFormat,
        'customHeadersJson': customHeadersJson,
        'extraBodyJson': extraBodyJson,
        'haptics': haptics,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      baseUrl: json['baseUrl'] as String? ?? '',
      model: json['model'] as String? ?? '',
      providers: _providerList(json['providers']),
      models: _modelList(json['models']),
      defaultModelId: json['defaultModelId'] as String? ?? '',
      titleModelId: json['titleModelId'] as String? ?? '',
      polishModelId: json['polishModelId'] as String? ?? '',
      stream: json['stream'] as bool? ?? true,
      temperature: _toDouble(json['temperature']) ?? 0.7,
      topP: _toDouble(json['topP']) ?? 1,
      maxTokens: _toInt(json['maxTokens']) ?? 2048,
      presencePenalty: _toDouble(json['presencePenalty']) ?? 0,
      frequencyPenalty: _toDouble(json['frequencyPenalty']) ?? 0,
      seed: json['seed'] as String? ?? '',
      stopSequences: json['stopSequences'] as String? ?? '',
      responseFormat: json['responseFormat'] as String? ?? '',
      customHeadersJson: json['customHeadersJson'] as String? ?? '{}',
      extraBodyJson: json['extraBodyJson'] as String? ?? '{}',
      haptics: json['haptics'] as bool? ?? true,
    );
  }
}

List<AiProviderConfig> defaultProviders() => [
      AiProviderConfig(
        id: 'openai',
        name: 'OpenAI',
        baseUrl: 'https://api.openai.com/v1',
      ),
      AiProviderConfig(
        id: 'deepseek',
        name: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com/v1',
      ),
      AiProviderConfig(
        id: 'qwen',
        name: '通义千问',
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      ),
      AiProviderConfig(
        id: 'moonshot',
        name: 'Moonshot',
        baseUrl: 'https://api.moonshot.cn/v1',
      ),
      AiProviderConfig(
        id: 'zhipu',
        name: '智谱',
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      ),
      AiProviderConfig(
        id: 'openrouter',
        name: 'OpenRouter',
        baseUrl: 'https://openrouter.ai/api/v1',
      ),
      AiProviderConfig(
        id: 'siliconflow',
        name: '硅基流动',
        baseUrl: 'https://api.siliconflow.cn/v1',
      ),
      AiProviderConfig(
        id: 'custom',
        name: '自定义',
        baseUrl: '',
        isCustom: true,
      ),
    ];

String modelConfigId(String providerId, String modelName) {
  final normalized = modelName
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9._/-]+'), '-');
  return '$providerId::$normalized';
}

List<AssistantPreset> defaultAssistants() => [
      AssistantPreset(
        id: 'assistant-writing',
        name: '写作助手',
        description: '结构、标题、润色和表达优化',
        systemPrompt:
            '你是一个克制、准确、有审美的中文写作助手。优先给出可直接使用的文本，避免空泛解释。',
        temperature: 0.7,
        topP: 0.9,
      ),
      AssistantPreset(
        id: 'assistant-code',
        name: '代码助手',
        description: '定位问题、设计实现、解释代码',
        systemPrompt:
            '你是一个严谨务实的软件工程助手。先理解上下文，再给出可执行方案和代码。不要编造不存在的 API。',
        temperature: 0.3,
        topP: 0.9,
      ),
      AssistantPreset(
        id: 'assistant-life',
        name: '生活顾问',
        description: '计划、比较、整理和日常建议',
        systemPrompt:
            '你是一个简洁可靠的生活顾问。回答要具体、清楚、有取舍，不要说教。',
        temperature: 0.6,
        topP: 0.95,
      ),
    ];

String prettyJson(Object? value) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(value);
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

List<AiProviderConfig> _providerList(Object? value) {
  if (value is! List) {
    return [];
  }
  return value
      .whereType<Map>()
      .map((item) => AiProviderConfig.fromJson(Map<String, Object?>.from(item)))
      .toList();
}

List<AiModelConfig> _modelList(Object? value) {
  if (value is! List) {
    return [];
  }
  return value
      .whereType<Map>()
      .map((item) => AiModelConfig.fromJson(Map<String, Object?>.from(item)))
      .toList();
}
