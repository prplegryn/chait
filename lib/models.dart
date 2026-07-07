import 'dart:convert';

String newEntityId() => DateTime.now().microsecondsSinceEpoch.toString();

class AssistantPreset {
  AssistantPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    this.avatar = '',
    this.avatarColorValue = 0xFFF2F2F2,
    this.avatarImagePath = '',
    this.wallpaperImagePath = '',
    this.age = '',
    this.gender = '',
    this.personality = '',
    this.relationship = '',
    this.communicationStyle = '',
    this.expertise = '',
    this.familiarTopics = '',
    this.limitedTopics = '',
    this.uncertaintyRules = '',
    this.emojiRules = '',
    this.paragraphRules = '',
    this.markdownRules = '',
    this.toolRules = '',
    this.advancedRules = '',
    this.identityProfile = '',
    this.coreKnowledge = '',
    this.familiarKnowledge = '',
    this.generalKnowledge = '',
    this.knowledgeBoundaries = '',
    this.experienceInventory = '',
    this.speechStyle = '',
    this.workStyle = '',
    this.toolStrategy = '',
    this.outputStyle = '',
    this.antiAiRules = '',
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
  String avatar;
  int avatarColorValue;
  String avatarImagePath;
  String wallpaperImagePath;
  String age;
  String gender;
  String personality;
  String relationship;
  String communicationStyle;
  String expertise;
  String familiarTopics;
  String limitedTopics;
  String uncertaintyRules;
  String emojiRules;
  String paragraphRules;
  String markdownRules;
  String toolRules;
  String advancedRules;
  String identityProfile;
  String coreKnowledge;
  String familiarKnowledge;
  String generalKnowledge;
  String knowledgeBoundaries;
  String experienceInventory;
  String speechStyle;
  String workStyle;
  String toolStrategy;
  String outputStyle;
  String antiAiRules;
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
        'avatar': avatar,
        'avatarColorValue': avatarColorValue,
        'avatarImagePath': avatarImagePath,
        'wallpaperImagePath': wallpaperImagePath,
        'age': age,
        'gender': gender,
        'personality': personality,
        'relationship': relationship,
        'communicationStyle': communicationStyle,
        'expertise': expertise,
        'familiarTopics': familiarTopics,
        'limitedTopics': limitedTopics,
        'uncertaintyRules': uncertaintyRules,
        'emojiRules': emojiRules,
        'paragraphRules': paragraphRules,
        'markdownRules': markdownRules,
        'toolRules': toolRules,
        'advancedRules': advancedRules,
        'identityProfile': identityProfile,
        'coreKnowledge': coreKnowledge,
        'familiarKnowledge': familiarKnowledge,
        'generalKnowledge': generalKnowledge,
        'knowledgeBoundaries': knowledgeBoundaries,
        'experienceInventory': experienceInventory,
        'speechStyle': speechStyle,
        'workStyle': workStyle,
        'toolStrategy': toolStrategy,
        'outputStyle': outputStyle,
        'antiAiRules': antiAiRules,
        'modelOverride': modelOverride,
        'preferredModelId': preferredModelId,
        'temperature': temperature,
        'topP': topP,
        'maxTokens': maxTokens,
      };

  factory AssistantPreset.fromJson(Map<String, Object?> json) {
    final name = json['name'] as String? ?? '助手';
    return AssistantPreset(
      id: json['id'] as String? ?? newEntityId(),
      name: name,
      description: json['description'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String? ?? '',
      avatar: json['avatar'] as String? ?? _initialAvatar(name),
      avatarColorValue: _toInt(json['avatarColorValue']) ?? 0xFFF2F2F2,
      avatarImagePath: json['avatarImagePath'] as String? ?? '',
      wallpaperImagePath: json['wallpaperImagePath'] as String? ?? '',
      age: json['age'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      personality: json['personality'] as String? ??
          json['identityProfile'] as String? ??
          '',
      relationship: json['relationship'] as String? ?? '',
      communicationStyle: json['communicationStyle'] as String? ??
          json['speechStyle'] as String? ??
          '',
      expertise: json['expertise'] as String? ??
          json['coreKnowledge'] as String? ??
          '',
      familiarTopics: json['familiarTopics'] as String? ??
          [
            json['familiarKnowledge'] as String? ?? '',
            json['generalKnowledge'] as String? ?? '',
          ].where((item) => item.trim().isNotEmpty).join('\n'),
      limitedTopics: json['limitedTopics'] as String? ??
          json['knowledgeBoundaries'] as String? ??
          '',
      uncertaintyRules: json['uncertaintyRules'] as String? ?? '',
      emojiRules: json['emojiRules'] as String? ?? '',
      paragraphRules: json['paragraphRules'] as String? ?? '',
      markdownRules: json['markdownRules'] as String? ??
          json['outputStyle'] as String? ??
          '',
      toolRules: json['toolRules'] as String? ??
          json['toolStrategy'] as String? ??
          '',
      advancedRules: json['advancedRules'] as String? ??
          [
            json['workStyle'] as String? ?? '',
            json['antiAiRules'] as String? ?? '',
            json['experienceInventory'] as String? ?? '',
          ].where((item) => item.trim().isNotEmpty).join('\n'),
      identityProfile: json['identityProfile'] as String? ?? '',
      coreKnowledge: json['coreKnowledge'] as String? ?? '',
      familiarKnowledge: json['familiarKnowledge'] as String? ?? '',
      generalKnowledge: json['generalKnowledge'] as String? ?? '',
      knowledgeBoundaries: json['knowledgeBoundaries'] as String? ?? '',
      experienceInventory: json['experienceInventory'] as String? ?? '',
      speechStyle: json['speechStyle'] as String? ?? '',
      workStyle: json['workStyle'] as String? ?? '',
      toolStrategy: json['toolStrategy'] as String? ?? '',
      outputStyle: json['outputStyle'] as String? ?? '',
      antiAiRules: json['antiAiRules'] as String? ?? '',
      modelOverride: json['modelOverride'] as String? ?? '',
      preferredModelId: json['preferredModelId'] as String? ??
          json['modelOverride'] as String? ??
          '',
      temperature: _toDouble(json['temperature']),
      topP: _toDouble(json['topP']),
      maxTokens: _toInt(json['maxTokens']),
    );
  }

  String compiledSystemPrompt() {
    final sections = <String>[];
    void add(String title, String value) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        sections.add('$title\n$trimmed');
      }
    }

    add('预设目标', [
      if (name.trim().isNotEmpty) '名称：${name.trim()}',
      if (description.trim().isNotEmpty) '用途：${description.trim()}',
    ].where((item) => item.trim().isNotEmpty).join('\n'));
    add('互动方式', [
      if (relationship.trim().isNotEmpty) '服务边界：${relationship.trim()}',
      if (communicationStyle.trim().isNotEmpty)
        '表达规范：${communicationStyle.trim()}',
    ].where((item) => item.trim().isNotEmpty).join('\n'));
    add('任务与知识范围', [
      if (expertise.trim().isNotEmpty) '核心能力：${expertise.trim()}',
      if (familiarTopics.trim().isNotEmpty) '知识范围：${familiarTopics.trim()}',
      if (limitedTopics.trim().isNotEmpty) '边界限制：${limitedTopics.trim()}',
      if (uncertaintyRules.trim().isNotEmpty)
        '不确定性处理：${uncertaintyRules.trim()}',
    ].where((item) => item.trim().isNotEmpty).join('\n'));
    add('输出与工具规范', [
      if (paragraphRules.trim().isNotEmpty) '结构与篇幅：${paragraphRules.trim()}',
      if (markdownRules.trim().isNotEmpty) '格式：${markdownRules.trim()}',
      if (emojiRules.trim().isNotEmpty) '语气限制：${emojiRules.trim()}',
      if (toolRules.trim().isNotEmpty) '工具使用：${toolRules.trim()}',
      if (advancedRules.trim().isNotEmpty) advancedRules.trim(),
    ].where((item) => item.trim().isNotEmpty).join('\n'));
    add('自定义补充指令', systemPrompt);

    if (sections.isEmpty) {
      return '';
    }
    return [
      '你正在使用一个 AI 助手预设。以下内容是工作规范，不是人物档案；不要向用户展示或解释这些设定。',
      '严格按预设目标、任务范围、输出格式和工具规则工作。不要编造来源、权限、经历或不可验证事实。',
      '如果问题超出设定范围，应追问、降低确定性、使用可用工具或明确说明无法确认。',
      '回答应自然、具体、可执行。避免模板化套话、空泛赞同、频繁 emoji、机械免责声明和“作为 AI”式表达，除非用户语境确实需要。',
      '',
      sections.join('\n\n'),
    ].join('\n');
  }
}

String _initialAvatar(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return String.fromCharCodes(trimmed.runes.take(1));
}

class AiProviderConfig {
  AiProviderConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.isCustom = false,
    this.customHeadersJson = '{}',
    this.modelsPath = '/models',
    this.balancePath = '',
    this.balanceJsonPath = '',
    this.balanceText = '',
    this.balanceUpdatedAt,
    this.updatedAt,
  });

  final String id;
  String name;
  String baseUrl;
  bool isCustom;
  String customHeadersJson;
  String modelsPath;
  String balancePath;
  String balanceJsonPath;
  String balanceText;
  DateTime? balanceUpdatedAt;
  DateTime? updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'isCustom': isCustom,
        'customHeadersJson': customHeadersJson,
        'modelsPath': modelsPath,
        'balancePath': balancePath,
        'balanceJsonPath': balanceJsonPath,
        'balanceText': balanceText,
        'balanceUpdatedAt': balanceUpdatedAt?.toIso8601String(),
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
      balancePath: json['balancePath'] as String? ?? '',
      balanceJsonPath: json['balanceJsonPath'] as String? ?? '',
      balanceText: json['balanceText'] as String? ?? '',
      balanceUpdatedAt:
          DateTime.tryParse(json['balanceUpdatedAt'] as String? ?? ''),
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
    this.status = '',
    this.error = '',
    this.raw = '',
  });

  final String id;
  final String role;
  String content;
  final DateTime createdAt;
  bool isStreaming;
  String status;
  String error;
  String raw;

  bool get isUser => role == 'user';

  Map<String, Object?> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'isStreaming': isStreaming,
        'status': status,
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
      status: json['status'] as String? ?? '',
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
    this.searchEnabled = false,
    this.searchMode = 'follow',
    this.pinned = false,
  });

  final String id;
  String assistantId;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<ChatMessage> messages;
  String modelId;
  bool searchEnabled;
  String searchMode;
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
        'searchEnabled': searchEnabled,
        'searchMode': searchMode,
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
      searchEnabled: json['searchEnabled'] as bool? ?? false,
      searchMode: _searchModeFromJson(json),
      pinned: json['pinned'] as bool? ?? false,
    );
  }
}

String _searchModeFromJson(Map<String, Object?> json) {
  final value = json['searchMode'] as String?;
  if (value == 'on' || value == 'off' || value == 'follow') {
    return value!;
  }
  return (json['searchEnabled'] as bool? ?? false) ? 'on' : 'follow';
}

class SearchProviderConfig {
  SearchProviderConfig({
    required this.id,
    required this.name,
    required this.kind,
    required this.baseUrl,
    this.enabled = true,
    this.customHeadersJson = '{}',
    this.extraBodyJson = '{}',
    this.maxResults = 5,
    this.updatedAt,
  });

  final String id;
  String name;
  String kind;
  String baseUrl;
  bool enabled;
  String customHeadersJson;
  String extraBodyJson;
  int maxResults;
  DateTime? updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'baseUrl': baseUrl,
        'enabled': enabled,
        'customHeadersJson': customHeadersJson,
        'extraBodyJson': extraBodyJson,
        'maxResults': maxResults,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory SearchProviderConfig.fromJson(Map<String, Object?> json) {
    return SearchProviderConfig(
      id: json['id'] as String? ?? newEntityId(),
      name: json['name'] as String? ?? '搜索服务',
      kind: json['kind'] as String? ?? 'custom',
      baseUrl: json['baseUrl'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      customHeadersJson: json['customHeadersJson'] as String? ?? '{}',
      extraBodyJson: json['extraBodyJson'] as String? ?? '{}',
      maxResults: _toInt(json['maxResults']) ?? 5,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

class McpServerConfig {
  McpServerConfig({
    required this.id,
    required this.name,
    required this.url,
    this.transport = 'streamable_http',
    this.enabled = true,
    this.customHeadersJson = '{}',
    this.notes = '',
    this.updatedAt,
  });

  final String id;
  String name;
  String url;
  String transport;
  bool enabled;
  String customHeadersJson;
  String notes;
  DateTime? updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'transport': transport,
        'enabled': enabled,
        'customHeadersJson': customHeadersJson,
        'notes': notes,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory McpServerConfig.fromJson(Map<String, Object?> json) {
    return McpServerConfig(
      id: json['id'] as String? ?? newEntityId(),
      name: json['name'] as String? ?? 'MCP 服务',
      url: json['url'] as String? ?? '',
      transport: json['transport'] as String? ?? 'streamable_http',
      enabled: json['enabled'] as bool? ?? true,
      customHeadersJson: json['customHeadersJson'] as String? ?? '{}',
      notes: json['notes'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

class AppSettings {
  AppSettings({
    this.baseUrl = '',
    this.model = '',
    List<AiProviderConfig>? providers,
    List<AiModelConfig>? models,
    List<SearchProviderConfig>? searchProviders,
    List<McpServerConfig>? mcpServers,
    this.defaultModelId = '',
    this.titleModelId = '',
    this.polishModelId = '',
    this.defaultSearchProviderId = '',
    this.searchEnabledByDefault = false,
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
    this.appearanceMode = 'light',
    this.themeColorValue = 0xFFE9E9E9,
    this.fontScale = 1,
    this.codeThemeId = 'default',
    this.codeBackgroundValue = 0,
    this.showSessionTitle = true,
    this.haptics = true,
  })  : providers = providers ?? [],
        models = models ?? [],
        searchProviders = searchProviders ?? [],
        mcpServers = mcpServers ?? [];

  String baseUrl;
  String model;
  final List<AiProviderConfig> providers;
  final List<AiModelConfig> models;
  final List<SearchProviderConfig> searchProviders;
  final List<McpServerConfig> mcpServers;
  String defaultModelId;
  String titleModelId;
  String polishModelId;
  String defaultSearchProviderId;
  bool searchEnabledByDefault;
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
  String appearanceMode;
  int themeColorValue;
  double fontScale;
  String codeThemeId;
  int codeBackgroundValue;
  bool showSessionTitle;
  bool haptics;

  Map<String, Object?> toJson() => {
        'baseUrl': baseUrl,
        'model': model,
        'providers': providers.map((provider) => provider.toJson()).toList(),
        'models': models.map((model) => model.toJson()).toList(),
        'searchProviders':
            searchProviders.map((provider) => provider.toJson()).toList(),
        'mcpServers': mcpServers.map((server) => server.toJson()).toList(),
        'defaultModelId': defaultModelId,
        'titleModelId': titleModelId,
        'polishModelId': polishModelId,
        'defaultSearchProviderId': defaultSearchProviderId,
        'searchEnabledByDefault': searchEnabledByDefault,
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
        'appearanceMode': appearanceMode,
        'themeColorValue': themeColorValue,
        'fontScale': fontScale,
        'codeThemeId': codeThemeId,
        'codeBackgroundValue': codeBackgroundValue,
        'showSessionTitle': showSessionTitle,
        'haptics': haptics,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      baseUrl: json['baseUrl'] as String? ?? '',
      model: json['model'] as String? ?? '',
      providers: _providerList(json['providers']),
      models: _modelList(json['models']),
      searchProviders: _searchProviderList(json['searchProviders']),
      mcpServers: _mcpServerList(json['mcpServers']),
      defaultModelId: json['defaultModelId'] as String? ?? '',
      titleModelId: json['titleModelId'] as String? ?? '',
      polishModelId: json['polishModelId'] as String? ?? '',
      defaultSearchProviderId:
          json['defaultSearchProviderId'] as String? ?? '',
      searchEnabledByDefault:
          json['searchEnabledByDefault'] as bool? ?? false,
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
      appearanceMode: json['appearanceMode'] as String? ?? 'light',
      themeColorValue: _toInt(json['themeColorValue']) ?? 0xFFE9E9E9,
      fontScale: _toDouble(json['fontScale']) ?? 1,
      codeThemeId: json['codeThemeId'] as String? ?? 'default',
      codeBackgroundValue: _toInt(json['codeBackgroundValue']) ?? 0,
      showSessionTitle: json['showSessionTitle'] as bool? ?? true,
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
        id: 'gemini',
        name: 'Google Gemini',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
      ),
      AiProviderConfig(
        id: 'xai',
        name: 'xAI',
        baseUrl: 'https://api.x.ai/v1',
      ),
      AiProviderConfig(
        id: 'mistral',
        name: 'Mistral',
        baseUrl: 'https://api.mistral.ai/v1',
      ),
      AiProviderConfig(
        id: 'groq',
        name: 'Groq',
        baseUrl: 'https://api.groq.com/openai/v1',
      ),
      AiProviderConfig(
        id: 'openrouter',
        name: 'OpenRouter',
        baseUrl: 'https://openrouter.ai/api/v1',
        balancePath: '/credits',
      ),
      AiProviderConfig(
        id: 'together',
        name: 'Together AI',
        baseUrl: 'https://api.together.xyz/v1',
      ),
      AiProviderConfig(
        id: 'fireworks',
        name: 'Fireworks AI',
        baseUrl: 'https://api.fireworks.ai/inference/v1',
      ),
      AiProviderConfig(
        id: 'cerebras',
        name: 'Cerebras',
        baseUrl: 'https://api.cerebras.ai/v1',
      ),
      AiProviderConfig(
        id: 'cohere',
        name: 'Cohere',
        baseUrl: 'https://api.cohere.com/compatibility/v1',
      ),
      AiProviderConfig(
        id: 'perplexity',
        name: 'Perplexity',
        baseUrl: 'https://api.perplexity.ai',
      ),
      AiProviderConfig(
        id: 'deepseek',
        name: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com/v1',
        balancePath: 'https://api.deepseek.com/user/balance',
      ),
      AiProviderConfig(
        id: 'volcengine',
        name: '火山方舟',
        baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
      ),
      AiProviderConfig(
        id: 'qwen',
        name: '通义千问',
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      ),
      AiProviderConfig(
        id: 'baidu_qianfan',
        name: '百度千帆',
        baseUrl: 'https://qianfan.baidubce.com/v2',
      ),
      AiProviderConfig(
        id: 'tencent_hunyuan',
        name: '腾讯混元',
        baseUrl: 'https://api.hunyuan.cloud.tencent.com/v1',
      ),
      AiProviderConfig(
        id: 'moonshot',
        name: 'Moonshot',
        baseUrl: 'https://api.moonshot.cn/v1',
        balancePath: '/users/me/balance',
        balanceJsonPath: 'data.available_balance',
      ),
      AiProviderConfig(
        id: 'zhipu',
        name: '智谱',
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      ),
      AiProviderConfig(
        id: 'siliconflow',
        name: '硅基流动',
        baseUrl: 'https://api.siliconflow.cn/v1',
        balancePath: '/user/info',
      ),
      AiProviderConfig(
        id: 'ollama',
        name: 'Ollama',
        baseUrl: 'http://127.0.0.1:11434/v1',
      ),
      AiProviderConfig(
        id: 'custom',
        name: '自定义',
        baseUrl: '',
        isCustom: true,
      ),
    ];

List<SearchProviderConfig> defaultSearchProviders() => [
      SearchProviderConfig(
        id: 'tavily',
        name: 'Tavily',
        kind: 'tavily',
        baseUrl: 'https://api.tavily.com',
        enabled: false,
      ),
      SearchProviderConfig(
        id: 'exa',
        name: 'Exa',
        kind: 'exa',
        baseUrl: 'https://api.exa.ai',
        enabled: false,
      ),
      SearchProviderConfig(
        id: 'brave',
        name: 'Brave Search',
        kind: 'brave',
        baseUrl: 'https://api.search.brave.com',
        enabled: false,
      ),
      SearchProviderConfig(
        id: 'serper',
        name: 'Serper',
        kind: 'serper',
        baseUrl: 'https://google.serper.dev',
        enabled: false,
      ),
      SearchProviderConfig(
        id: 'searxng',
        name: 'SearXNG',
        kind: 'searxng',
        baseUrl: '',
        enabled: false,
      ),
      SearchProviderConfig(
        id: 'linkup',
        name: 'LinkUp',
        kind: 'linkup',
        baseUrl: 'https://api.linkup.so',
        enabled: false,
      ),
      SearchProviderConfig(
        id: 'custom_search',
        name: '自定义搜索',
        kind: 'custom',
        baseUrl: '',
        enabled: false,
      ),
    ];

bool searchProviderNeedsApiKey(String kind) {
  switch (kind.trim().toLowerCase()) {
    case 'custom':
    case 'searxng':
      return false;
    default:
      return true;
  }
}

List<McpServerConfig> defaultMcpServers() => [];

bool isBuiltInProviderId(String providerId) {
  return defaultProviders()
      .any((provider) => provider.id == providerId && !provider.isCustom);
}

AiProviderConfig? builtInProviderById(String providerId) {
  final matches = defaultProviders()
      .where((provider) => provider.id == providerId && !provider.isCustom);
  if (matches.isEmpty) {
    return null;
  }
  return AiProviderConfig.fromJson(matches.first.toJson());
}

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
        relationship: '以编辑和协作者方式工作，先理解用途、受众和投放场景。',
        communicationStyle: '语言自然清楚，少用口号式表达，优先给可直接使用的文本。',
        expertise: '中文表达、文章结构、标题归纳、文案润色、信息组织。',
        familiarTopics: '办公写作、产品说明、计划总结、沟通文本、内容改写。',
        limitedTopics: '事实引用、实时资料、专业结论和数据来源需要查证。',
        uncertaintyRules: '不把不确定事实写成定论；需要最新信息时提醒核验或搜索。',
        paragraphRules: '根据文本用途自然分段，不用固定模板堆小标题。',
        markdownRules: '成稿优先给正文；需要比较、步骤或代码时再使用 Markdown。',
        advancedRules: '不空泛赞同，不堆模板化总结；需要改稿时说明关键取舍。',
        systemPrompt:
            '你是一个克制、准确、有审美的中文写作助手。优先给出可直接使用的文本，避免空泛解释。',
        temperature: 0.7,
        topP: 0.9,
      ),
      AssistantPreset(
        id: 'assistant-code',
        name: '代码助手',
        description: '定位问题、设计实现、解释代码',
        relationship: '以工程协作者方式工作，先读上下文，再给判断和改法。',
        communicationStyle: '先讲结论和关键风险，再给实现细节；避免长篇泛讲。',
        expertise: '软件设计、代码阅读、调试、接口契约、测试和工程实现。',
        familiarTopics: '常见前后端、移动端、脚本、数据处理和构建问题。',
        limitedTopics: '具体库版本、私有接口、当前环境状态和未提供的代码上下文。',
        uncertaintyRules: '不知道版本或环境时必须说明假设；不要编造不存在的 API。',
        paragraphRules: '按问题、原因、修改、验证组织，必要时才展开。',
        markdownRules: '代码、步骤、风险和验证分清楚；代码块必须标注语言。',
        advancedRules: '不机械道歉，不过度解释基础常识，不用“显然”“很简单”压低用户判断。',
        systemPrompt:
            '你是一个严谨务实的软件工程助手。先理解上下文，再给出可执行方案和代码。不要编造不存在的 API。',
        temperature: 0.3,
        topP: 0.9,
      ),
      AssistantPreset(
        id: 'assistant-life',
        name: '通用助手',
        description: '计划、比较、整理和日常建议',
        relationship: '以通用助理方式工作，先澄清目标，再给少量清晰方案。',
        communicationStyle: '自然、少说教，优先给可执行的下一步。',
        expertise: '计划拆解、清单整理、方案比较、日常决策和沟通建议。',
        familiarTopics: '旅行、购物、时间安排、学习计划、资料整理和一般建议。',
        limitedTopics: '医疗、法律、财务等高风险问题，以及价格、天气、营业时间等实时信息。',
        uncertaintyRules: '高风险问题不装专家；需要最新信息时搜索或提示确认。',
        paragraphRules: '先减少选择压力，再给少量清晰方案。',
        markdownRules: '适合用清单、对比、步骤和提醒；不用夸张营销语。',
        advancedRules: '不说空话，不把普通建议包装成专业诊断，不制造焦虑。',
        systemPrompt:
            '你是一个简洁可靠的通用助手。回答要具体、清楚、有取舍，不要说教。',
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

List<SearchProviderConfig> _searchProviderList(Object? value) {
  if (value is! List) {
    return [];
  }
  return value
      .whereType<Map>()
      .map((item) =>
          SearchProviderConfig.fromJson(Map<String, Object?>.from(item)))
      .toList();
}

List<McpServerConfig> _mcpServerList(Object? value) {
  if (value is! List) {
    return [];
  }
  return value
      .whereType<Map>()
      .map((item) => McpServerConfig.fromJson(Map<String, Object?>.from(item)))
      .toList();
}
