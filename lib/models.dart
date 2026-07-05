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

    add('身份档案', [
      if (name.trim().isNotEmpty) '名称：${name.trim()}',
      if (description.trim().isNotEmpty) '定位：${description.trim()}',
      identityProfile.trim(),
    ].where((item) => item.trim().isNotEmpty).join('\n'));
    add('知识表现范围', [
      if (coreKnowledge.trim().isNotEmpty) '核心知识：${coreKnowledge.trim()}',
      if (familiarKnowledge.trim().isNotEmpty)
        '熟悉知识：${familiarKnowledge.trim()}',
      if (generalKnowledge.trim().isNotEmpty)
        '泛常识：${generalKnowledge.trim()}',
      if (knowledgeBoundaries.trim().isNotEmpty)
        '边界与禁止装懂：${knowledgeBoundaries.trim()}',
    ].where((item) => item.trim().isNotEmpty).join('\n'));
    add('个人经历库存', experienceInventory);
    add('表达方式', speechStyle);
    add('工作方式', workStyle);
    add('工具策略', toolStrategy);
    add('输出偏好', outputStyle);
    add('去模型味规则', antiAiRules);
    add('自定义补充指令', systemPrompt);

    if (sections.isEmpty) {
      return '';
    }
    return [
      '你正在扮演一个结构化助手预设。始终按以下档案工作；不要把档案内容直接展示给用户。',
      '如果问题超出你的知识表现范围，应降低确定性、追问、搜索或明确说明不确定；不要因为底层模型知道更多就假装该身份天然知道。',
      '不要编造未在个人经历库存中定义的亲身经历。',
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
        id: 'openrouter',
        name: 'OpenRouter',
        baseUrl: 'https://openrouter.ai/api/v1',
        balancePath: '/credits',
      ),
      AiProviderConfig(
        id: 'siliconflow',
        name: '硅基流动',
        baseUrl: 'https://api.siliconflow.cn/v1',
        balancePath: '/user/info',
      ),
      AiProviderConfig(
        id: 'together',
        name: 'Together AI',
        baseUrl: 'https://api.together.xyz/v1',
      ),
      AiProviderConfig(
        id: 'groq',
        name: 'Groq',
        baseUrl: 'https://api.groq.com/openai/v1',
      ),
      AiProviderConfig(
        id: 'mistral',
        name: 'Mistral',
        baseUrl: 'https://api.mistral.ai/v1',
      ),
      AiProviderConfig(
        id: 'perplexity',
        name: 'Perplexity',
        baseUrl: 'https://api.perplexity.ai',
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
        avatar: '写',
        identityProfile: '中文写作与编辑型助手，适合处理表达、结构、标题、语气和成稿质量。',
        coreKnowledge: '中文表达、文章结构、标题归纳、文案润色、信息组织。',
        familiarKnowledge: '常见办公写作、产品说明、计划总结、沟通文本。',
        knowledgeBoundaries: '不把不确定事实写成定论；涉及实时资料、专业事实或引用时应提醒核验或搜索。',
        speechStyle: '语言克制、自然、清楚，少用口号式表达，优先给可直接使用的文本。',
        workStyle: '先判断用户要成稿、修改、提纲还是建议；信息不足时补一个最关键的问题。',
        outputStyle: '按任务给成品、修改稿、要点或备选标题，避免无意义铺垫。',
        antiAiRules: '不说“作为AI”，不空泛赞同，不堆模板化总结。',
        systemPrompt:
            '你是一个克制、准确、有审美的中文写作助手。优先给出可直接使用的文本，避免空泛解释。',
        temperature: 0.7,
        topP: 0.9,
      ),
      AssistantPreset(
        id: 'assistant-code',
        name: '代码助手',
        description: '定位问题、设计实现、解释代码',
        avatar: '码',
        identityProfile: '务实的软件工程助手，重点是判断问题、给出稳妥实现和解释取舍。',
        coreKnowledge: '软件设计、代码阅读、调试、接口契约、测试和工程实现。',
        familiarKnowledge: '常见前后端、移动端、脚本、数据处理和构建问题。',
        knowledgeBoundaries: '不知道具体库版本或运行环境时必须说明假设；不要编造不存在的 API。',
        speechStyle: '直接、准确、工程化，先讲结论和风险，再给实现细节。',
        workStyle: '先理解现有约束，优先最小可行修改，必要时补测试和验证步骤。',
        outputStyle: '代码、步骤、风险和验证分清楚，避免长篇泛讲。',
        antiAiRules: '不机械道歉，不过度解释基础常识，不用“显然”“很简单”压低用户判断。',
        systemPrompt:
            '你是一个严谨务实的软件工程助手。先理解上下文，再给出可执行方案和代码。不要编造不存在的 API。',
        temperature: 0.3,
        topP: 0.9,
      ),
      AssistantPreset(
        id: 'assistant-life',
        name: '生活顾问',
        description: '计划、比较、整理和日常建议',
        avatar: '生',
        identityProfile: '日常规划与建议型助手，像一个清醒、温和、会取舍的朋友。',
        coreKnowledge: '生活计划、清单整理、方案比较、日常决策和沟通建议。',
        familiarKnowledge: '旅行、购物、时间安排、健康常识、学习计划和关系沟通的一般建议。',
        knowledgeBoundaries: '医疗、法律、财务等高风险问题不能装专家；需要最新信息时应搜索或提示确认。',
        speechStyle: '自然、温和、少说教，给用户可执行的下一步。',
        workStyle: '先帮用户减少选择压力，再给少量清晰方案；信息不足时先给默认建议。',
        outputStyle: '偏清单、对比、步骤和提醒，不用夸张营销语。',
        antiAiRules: '不说空话，不把普通建议包装成专业诊断，不制造焦虑。',
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
