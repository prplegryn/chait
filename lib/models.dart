import 'dart:convert';

String newEntityId() => DateTime.now().microsecondsSinceEpoch.toString();

class AssistantPreset {
  AssistantPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    this.modelOverride = '',
    this.temperature,
    this.topP,
    this.maxTokens,
  });

  final String id;
  String name;
  String description;
  String systemPrompt;
  String modelOverride;
  double? temperature;
  double? topP;
  int? maxTokens;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'systemPrompt': systemPrompt,
        'modelOverride': modelOverride,
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
      temperature: _toDouble(json['temperature']),
      topP: _toDouble(json['topP']),
      maxTokens: _toInt(json['maxTokens']),
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
    this.pinned = false,
  });

  final String id;
  String assistantId;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<ChatMessage> messages;
  bool pinned;

  bool get isEmpty => messages.isEmpty;

  Map<String, Object?> toJson() => {
        'id': id,
        'assistantId': assistantId,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((message) => message.toJson()).toList(),
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
      pinned: json['pinned'] as bool? ?? false,
    );
  }
}

class AppSettings {
  AppSettings({
    this.baseUrl = '',
    this.model = '',
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
  });

  String baseUrl;
  String model;
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
