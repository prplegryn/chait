import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_client.dart';
import 'models.dart';

class AppStore extends ChangeNotifier {
  AppStore();

  static const _assistantsKey = 'assistants';
  static const _sessionsKey = 'sessions';
  static const _settingsKey = 'settings';
  static const _currentSessionKey = 'currentSessionId';
  static const _currentAssistantKey = 'currentAssistantId';
  static const _apiKeyKey = 'apiKey';
  static const _providerApiKeysKey = 'providerApiKeys';

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final List<AssistantPreset> assistants = [];
  final List<ChatSession> sessions = [];
  AppSettings settings = AppSettings();
  String apiKey = '';
  final Map<String, String> providerApiKeys = {};
  String currentSessionId = '';
  String currentAssistantId = 'assistant-writing';
  bool isReady = false;
  bool isSending = false;

  AiClient? _activeClient;
  bool _cancelRequested = false;

  AssistantPreset get currentAssistant {
    return assistants.firstWhere(
      (assistant) => assistant.id == currentAssistantId,
      orElse: () => assistants.first,
    );
  }

  ChatSession get currentSession {
    final existing = sessions.where((session) => session.id == currentSessionId);
    if (existing.isNotEmpty) {
      return existing.first;
    }
    return sessions.first;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    assistants
      ..clear()
      ..addAll(_decodeAssistantList(prefs.getString(_assistantsKey)));
    if (assistants.isEmpty) {
      assistants.addAll(defaultAssistants());
    }

    settings = _decodeSettings(prefs.getString(_settingsKey));
    _ensureProviders();
    apiKey = await _secureStorage.read(key: _apiKeyKey) ?? '';
    final providerKeyJson = await _secureStorage.read(key: _providerApiKeysKey);
    providerApiKeys
      ..clear()
      ..addAll(_decodeStringMap(providerKeyJson));
    if (apiKey.isNotEmpty && providerApiKeys.isEmpty) {
      providerApiKeys[settings.providers.first.id] = apiKey;
    }
    currentAssistantId =
        prefs.getString(_currentAssistantKey) ?? assistants.first.id;

    sessions
      ..clear()
      ..addAll(_decodeSessionList(prefs.getString(_sessionsKey)));
    if (sessions.isEmpty) {
      sessions.add(_newSession(currentAssistantId));
    }
    currentSessionId = prefs.getString(_currentSessionKey) ?? sessions.first.id;

    _repairSelection();
    _sortSessions();
    isReady = true;
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _assistantsKey,
      jsonEncode(assistants.map((assistant) => assistant.toJson()).toList()),
    );
    await prefs.setString(
      _sessionsKey,
      jsonEncode(sessions.map((session) => session.toJson()).toList()),
    );
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    await prefs.setString(_currentSessionKey, currentSessionId);
    await prefs.setString(_currentAssistantKey, currentAssistantId);
    await _secureStorage.write(key: _apiKeyKey, value: apiKey);
    await _secureStorage.write(
      key: _providerApiKeysKey,
      value: jsonEncode(providerApiKeys),
    );
  }

  Future<void> updateSettings(AppSettings next, String nextApiKey) async {
    settings = next;
    _ensureProviders();
    apiKey = nextApiKey;
    notifyListeners();
    await save();
  }

  Future<void> updateProvider(
    AiProviderConfig provider, {
    String? apiKey,
  }) async {
    final index = settings.providers.indexWhere((item) => item.id == provider.id);
    if (index == -1) {
      settings.providers.add(provider);
    } else {
      settings.providers[index] = provider;
    }
    if (apiKey != null) {
      providerApiKeys[provider.id] = apiKey;
    }
    notifyListeners();
    await save();
  }

  String apiKeyForProvider(String providerId) {
    return providerApiKeys[providerId] ?? '';
  }

  Future<List<AiModelConfig>> refreshProviderModels(String providerId) async {
    final provider = providerById(providerId);
    final fetched = await AiClient().fetchModels(
      provider: provider,
      apiKey: apiKeyForProvider(provider.id),
    );
    for (final model in fetched) {
      final existingIndex =
          settings.models.indexWhere((item) => item.id == model.id);
      if (existingIndex == -1) {
        settings.models.add(model);
      } else {
        final enabled = settings.models[existingIndex].enabled;
        settings.models[existingIndex] = model..enabled = enabled;
      }
    }
    provider.updatedAt = DateTime.now();
    notifyListeners();
    await save();
    return fetched;
  }

  Future<void> setModelEnabled(String modelId, bool enabled) async {
    final model = modelById(modelId);
    model.enabled = enabled;
    if (enabled && settings.defaultModelId.isEmpty) {
      settings.defaultModelId = model.id;
    }
    if (!settings.models.any((item) => item.id == settings.defaultModelId && item.enabled)) {
      settings.defaultModelId = enabledModels.isEmpty ? '' : enabledModels.first.id;
    }
    notifyListeners();
    await save();
  }

  Future<void> setSessionModel(String modelId) async {
    currentSession.modelId = modelId;
    notifyListeners();
    await save();
  }

  List<AiModelConfig> get enabledModels =>
      settings.models.where((model) => model.enabled).toList()
        ..sort((a, b) => '${a.providerName}${a.name}'.compareTo('${b.providerName}${b.name}'));

  AiProviderConfig providerById(String id) {
    return settings.providers.firstWhere(
      (provider) => provider.id == id,
      orElse: () => settings.providers.first,
    );
  }

  AiModelConfig modelById(String id) {
    return settings.models.firstWhere(
      (model) => model.id == id,
      orElse: () => enabledModels.isNotEmpty
          ? enabledModels.first
          : AiModelConfig(
              id: modelConfigId('legacy', settings.model),
              providerId: settings.providers.first.id,
              providerName: settings.providers.first.name,
              name: settings.model,
              enabled: true,
            ),
    );
  }

  Future<void> upsertAssistant(AssistantPreset preset) async {
    final index = assistants.indexWhere((item) => item.id == preset.id);
    if (index == -1) {
      assistants.add(preset);
    } else {
      assistants[index] = preset;
    }
    if (currentAssistantId.isEmpty) {
      currentAssistantId = preset.id;
    }
    notifyListeners();
    await save();
  }

  Future<void> deleteAssistant(String id) async {
    if (assistants.length <= 1) {
      return;
    }
    assistants.removeWhere((assistant) => assistant.id == id);
    for (final session in sessions) {
      if (session.assistantId == id) {
        session.assistantId = assistants.first.id;
      }
    }
    if (currentAssistantId == id) {
      currentAssistantId = assistants.first.id;
    }
    notifyListeners();
    await save();
  }

  Future<void> selectAssistant(String id) async {
    currentAssistantId = id;
    final session = currentSession;
    if (session.messages.isEmpty) {
      session.assistantId = id;
    } else if (session.assistantId != id) {
      final next = _newSession(id);
      sessions.insert(0, next);
      currentSessionId = next.id;
    }
    notifyListeners();
    await save();
  }

  Future<void> selectSession(String id) async {
    currentSessionId = id;
    final session = currentSession;
    currentAssistantId = session.assistantId;
    notifyListeners();
    await save();
  }

  Future<void> createSession({String? assistantId}) async {
    final session = _newSession(assistantId ?? currentAssistantId);
    sessions.insert(0, session);
    currentSessionId = session.id;
    currentAssistantId = session.assistantId;
    notifyListeners();
    await save();
  }

  Future<void> togglePin(ChatSession session) async {
    session.pinned = !session.pinned;
    session.updatedAt = DateTime.now();
    _sortSessions();
    notifyListeners();
    await save();
  }

  Future<void> deleteSession(String id) async {
    sessions.removeWhere((session) => session.id == id);
    if (sessions.isEmpty) {
      sessions.add(_newSession(currentAssistantId));
    }
    if (!sessions.any((session) => session.id == currentSessionId)) {
      currentSessionId = sessions.first.id;
      currentAssistantId = sessions.first.assistantId;
    }
    notifyListeners();
    await save();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isSending) {
      return;
    }

    final session = currentSession;
    final isNewSession = session.messages.isEmpty;
    final now = DateTime.now();
    session.messages.add(
      ChatMessage(
        id: newEntityId(),
        role: 'user',
        content: trimmed,
        createdAt: now,
      ),
    );
    if (isNewSession && settings.titleModelId.isEmpty) {
      session.title = _titleFromPrompt(trimmed);
    }
    session.updatedAt = now;

    final assistantMessage = ChatMessage(
      id: newEntityId(),
      role: 'assistant',
      content: '',
      createdAt: DateTime.now(),
      isStreaming: true,
    );
    session.messages.add(assistantMessage);
    isSending = true;
    _cancelRequested = false;
    _sortSessions();
    notifyListeners();

    _activeClient = AiClient();
    try {
      final target = _resolveModelTarget(session);
      await _activeClient!.sendChat(
        config: AiRequestConfig(
          settings: settings,
          apiKey: target.apiKey,
          assistant: currentAssistant,
          messages: session.messages
              .where((message) => !message.isStreaming)
              .where((message) => message.content.trim().isNotEmpty)
              .toList(),
          baseUrl: target.provider.baseUrl,
          model: target.model.name,
          customHeadersJson: target.provider.customHeadersJson,
        ),
        isCancelled: () => _cancelRequested,
        onDelta: (delta) {
          assistantMessage.content += delta;
          notifyListeners();
        },
        onRaw: (raw) {
          assistantMessage.raw = raw;
        },
      );
      if (_cancelRequested && assistantMessage.content.trim().isEmpty) {
        assistantMessage.content = '已停止生成。';
      }
    } catch (error) {
      assistantMessage.error = error.toString();
      if (assistantMessage.content.trim().isEmpty) {
        assistantMessage.content = error.toString();
      }
    } finally {
      assistantMessage.isStreaming = false;
      isSending = false;
      _activeClient = null;
      _cancelRequested = false;
      session.updatedAt = DateTime.now();
      _sortSessions();
      notifyListeners();
      await save();
      if (isNewSession && settings.titleModelId.isNotEmpty) {
        await generateTitleForSession(session.id, fallbackPrompt: trimmed);
      }
    }
  }

  void stopGeneration() {
    if (!isSending) {
      return;
    }
    _cancelRequested = true;
    _activeClient?.cancel();
    notifyListeners();
  }

  Future<void> regenerateLastAnswer() async {
    if (isSending) {
      return;
    }
    final session = currentSession;
    if (session.messages.isEmpty) {
      return;
    }
    final lastUserIndex = session.messages.lastIndexWhere(
      (message) => message.role == 'user',
    );
    if (lastUserIndex == -1) {
      return;
    }
    final lastUserCreatedAt = session.messages[lastUserIndex].createdAt;
    session.messages.removeWhere(
      (message) =>
          message.role == 'assistant' &&
          message.createdAt.isAfter(lastUserCreatedAt),
    );
    final prompt = session.messages[lastUserIndex].content;
    session.messages.removeAt(lastUserIndex);
    notifyListeners();
    await sendMessage(prompt);
  }

  Future<String> exportData({bool includeApiKey = false}) async {
    final payload = {
      'version': 1,
      'assistants': assistants.map((assistant) => assistant.toJson()).toList(),
      'sessions': sessions.map((session) => session.toJson()).toList(),
      'settings': settings.toJson(),
      if (includeApiKey) 'apiKey': apiKey,
      if (includeApiKey) 'providerApiKeys': providerApiKeys,
    };
    return prettyJson(payload);
  }

  Future<void> generateTitleForSession(
    String sessionId, {
    required String fallbackPrompt,
  }) async {
    if (settings.titleModelId.isEmpty) {
      return;
    }
    final session = sessions.firstWhere(
      (item) => item.id == sessionId,
      orElse: () => currentSession,
    );
    final target = _resolveSpecificModelTarget(settings.titleModelId);
    try {
      final title = await AiClient().generateText(
        settings: settings,
        apiKey: target.apiKey,
        assistant: currentAssistant,
        baseUrl: target.provider.baseUrl,
        model: target.model.name,
        customHeadersJson: target.provider.customHeadersJson,
        systemPrompt: '你只负责给聊天生成一个简短中文标题。不要解释，不要引号，最多 14 个字。',
        userPrompt: fallbackPrompt,
        temperature: 0.2,
        maxTokens: 48,
      );
      if (title.trim().isNotEmpty) {
        session.title = title.trim().replaceAll('\n', ' ');
        notifyListeners();
        await save();
      }
    } catch (_) {
      if (session.title == '新对话') {
        session.title = _titleFromPrompt(fallbackPrompt);
        notifyListeners();
        await save();
      }
    }
  }

  Future<Map<String, String>> polishAssistantDraft({
    required String name,
    required String description,
    required String systemPrompt,
    required String temperature,
    required String topP,
    required String maxTokens,
    required String modelId,
  }) async {
    if (settings.polishModelId.isEmpty) {
      throw const AiException('请先在设置里选择润色模型。');
    }
    final target = _resolveSpecificModelTarget(settings.polishModelId);
    final result = await AiClient().generateText(
      settings: settings,
      apiKey: target.apiKey,
      assistant: currentAssistant,
      baseUrl: target.provider.baseUrl,
      model: target.model.name,
      customHeadersJson: target.provider.customHeadersJson,
      systemPrompt: _polishSystemPrompt,
      userPrompt: jsonEncode({
        'name': name,
        'description': description,
        'systemPrompt': systemPrompt,
        'preferredModelId': modelId,
        'temperature': temperature,
        'topP': topP,
        'maxTokens': maxTokens,
      }),
      temperature: 0.2,
      maxTokens: 1000,
    );
    final decoded = jsonDecode(_extractJsonObject(result));
    if (decoded is! Map) {
      throw const FormatException('润色结果不是 JSON 对象。');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
  }

  Future<void> importData(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('备份内容格式不正确。');
    }
    final map = Map<String, Object?>.from(decoded);
    assistants
      ..clear()
      ..addAll(_decodeAssistantList(jsonEncode(map['assistants'])));
    if (assistants.isEmpty) {
      assistants.addAll(defaultAssistants());
    }
    sessions
      ..clear()
      ..addAll(_decodeSessionList(jsonEncode(map['sessions'])));
    if (sessions.isEmpty) {
      sessions.add(_newSession(assistants.first.id));
    }
    final settingsJson = map['settings'];
    if (settingsJson is Map) {
      settings = AppSettings.fromJson(Map<String, Object?>.from(settingsJson));
    }
    final importedApiKey = map['apiKey'];
    if (importedApiKey is String) {
      apiKey = importedApiKey;
    }
    final importedProviderKeys = map['providerApiKeys'];
    if (importedProviderKeys is Map) {
      providerApiKeys
        ..clear()
        ..addAll(importedProviderKeys.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ));
    }
    currentAssistantId = assistants.first.id;
    currentSessionId = sessions.first.id;
    _repairSelection();
    _sortSessions();
    notifyListeners();
    await save();
  }

  ChatSession _newSession(String assistantId) {
    return ChatSession(
      id: newEntityId(),
      assistantId: assistantId,
      title: '新对话',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: [],
    );
  }

  void _repairSelection() {
    _ensureProviders();
    if (!assistants.any((assistant) => assistant.id == currentAssistantId)) {
      currentAssistantId = assistants.first.id;
    }
    if (!sessions.any((session) => session.id == currentSessionId)) {
      currentSessionId = sessions.first.id;
    }
    for (final session in sessions) {
      if (!assistants.any((assistant) => assistant.id == session.assistantId)) {
        session.assistantId = assistants.first.id;
      }
      for (final message in session.messages) {
        message.isStreaming = false;
      }
      if (session.modelId.isNotEmpty &&
          !settings.models.any((model) => model.id == session.modelId && model.enabled)) {
        session.modelId = '';
      }
    }
    for (final assistant in assistants) {
      if (assistant.preferredModelId.isEmpty && assistant.modelOverride.isNotEmpty) {
        assistant.preferredModelId = assistant.modelOverride;
      }
      if (assistant.preferredModelId.isNotEmpty &&
          !settings.models.any(
            (model) => model.id == assistant.preferredModelId && model.enabled,
          )) {
        assistant.preferredModelId = '';
      }
    }
  }

  void _ensureProviders() {
    if (settings.providers.isEmpty) {
      settings.providers.addAll(defaultProviders());
    }
    if (settings.models.isEmpty &&
        settings.model.trim().isNotEmpty &&
        settings.baseUrl.trim().isNotEmpty) {
      final provider = settings.providers.first;
      final legacyModel = AiModelConfig(
        id: modelConfigId(provider.id, settings.model),
        providerId: provider.id,
        providerName: provider.name,
        name: settings.model,
        enabled: true,
      );
      settings.models.add(legacyModel);
      settings.defaultModelId = legacyModel.id;
    }
  }

  _ResolvedModelTarget _resolveModelTarget(ChatSession session) {
    final assistant = currentAssistant;
    final id = session.modelId.trim().isNotEmpty
        ? session.modelId
        : assistant.preferredModelId.trim().isNotEmpty
            ? assistant.preferredModelId
            : settings.defaultModelId;
    return _resolveSpecificModelTarget(id);
  }

  _ResolvedModelTarget _resolveSpecificModelTarget(String modelId) {
    if (modelId.trim().isEmpty) {
      throw const AiException('请先在设置里添加并选择模型。');
    }
    final model = modelById(modelId);
    final provider = providerById(model.providerId);
    final key = apiKeyForProvider(provider.id);
    if (provider.baseUrl.trim().isEmpty || model.name.trim().isEmpty || key.isEmpty) {
      throw const AiException('请检查模型所属服务商的 Base URL、API Key 和模型。');
    }
    return _ResolvedModelTarget(provider: provider, model: model, apiKey: key);
  }

  void _sortSessions() {
    sessions.sort((a, b) {
      if (a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  String _titleFromPrompt(String prompt) {
    final normalized = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 18) {
      return normalized;
    }
    return '${normalized.substring(0, 18)}...';
  }

  List<AssistantPreset> _decodeAssistantList(String? source) {
    if (source == null || source.trim().isEmpty) {
      return [];
    }
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      return [];
    }
    return decoded
        .whereType<Map>()
        .map((item) => AssistantPreset.fromJson(Map<String, Object?>.from(item)))
        .toList();
  }

  List<ChatSession> _decodeSessionList(String? source) {
    if (source == null || source.trim().isEmpty) {
      return [];
    }
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      return [];
    }
    return decoded
        .whereType<Map>()
        .map((item) => ChatSession.fromJson(Map<String, Object?>.from(item)))
        .toList();
  }

  AppSettings _decodeSettings(String? source) {
    if (source == null || source.trim().isEmpty) {
      return AppSettings();
    }
    final decoded = jsonDecode(source);
    if (decoded is Map) {
      return AppSettings.fromJson(Map<String, Object?>.from(decoded));
    }
    return AppSettings();
  }

  Map<String, String> _decodeStringMap(String? source) {
    if (source == null || source.trim().isEmpty) {
      return {};
    }
    final decoded = jsonDecode(source);
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
    }
    return {};
  }

  String _extractJsonObject(String source) {
    final start = source.indexOf('{');
    final end = source.lastIndexOf('}');
    if (start == -1 || end <= start) {
      return source;
    }
    return source.substring(start, end + 1);
  }
}

class _ResolvedModelTarget {
  _ResolvedModelTarget({
    required this.provider,
    required this.model,
    required this.apiKey,
  });

  final AiProviderConfig provider;
  final AiModelConfig model;
  final String apiKey;
}

const _polishSystemPrompt = '''
你是 AI 助手预设编辑器。请润色用户提交的助手配置，让它更清晰、稳定、克制、可执行。
必须只返回 JSON 对象，不要 Markdown，不要解释。
字段：
- name: 简短中文名称，2 到 8 个字。
- description: 14 到 28 个字，说明用途，不营销。
- systemPrompt: 完整系统提示词，清楚描述角色、边界、输出风格、拒绝编造、必要时追问。
- temperature: 0 到 2 的数字字符串；偏事实任务降低，创意任务可提高。
- topP: 0 到 1 的数字字符串。
- maxTokens: 256 到 8192 的整数字符串。
不要修改 preferredModelId，原样返回。
''';
