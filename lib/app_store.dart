import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';
import 'ai_client.dart';
import 'mcp_client.dart';
import 'models.dart';
import 'search_client.dart';

class AppStore extends ChangeNotifier {
  AppStore() {
    assistants.addAll(defaultAssistants());
    currentAssistantId = assistants.first.id;
    sessions.add(_newSession(currentAssistantId));
    currentSessionId = sessions.first.id;
  }

  static const _assistantsKey = 'assistants';
  static const _sessionsKey = 'sessions';
  static const _settingsKey = 'settings';
  static const _currentSessionKey = 'currentSessionId';
  static const _currentAssistantKey = 'currentAssistantId';
  static const _apiKeyKey = 'apiKey';
  static const _providerApiKeysKey = 'providerApiKeys';
  static const _searchProviderApiKeysKey = 'searchProviderApiKeys';

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final List<AssistantPreset> assistants = [];
  final List<ChatSession> sessions = [];
  AppSettings settings = AppSettings();
  String apiKey = '';
  final Map<String, String> providerApiKeys = {};
  final Map<String, String> searchProviderApiKeys = {};
  String currentSessionId = '';
  String currentAssistantId = 'assistant-writing';
  bool isReady = false;
  bool isSending = false;

  AiClient? _activeClient;
  bool _cancelRequested = false;
  bool _backgroundInitialized = false;
  bool _backgroundHeld = false;

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

  AssistantPreset assistantForSession(ChatSession session) {
    return assistants.firstWhere(
      (assistant) => assistant.id == session.assistantId,
      orElse: () => currentAssistant,
    );
  }

  Future<void> load() async {
    AppLogger.instance.info('store.load', 'start');
    try {
      final prefs = await SharedPreferences.getInstance();
      AppLogger.instance.info('store.load', 'prefs ready');
      assistants
        ..clear()
        ..addAll(_decodeAssistantList(prefs.getString(_assistantsKey)));
      if (assistants.isEmpty) {
        assistants.addAll(defaultAssistants());
      }
      AppLogger.instance.event('store.load', {
        'phase': 'assistants',
        'count': assistants.length,
      });

      settings = _decodeSettings(prefs.getString(_settingsKey));
      _ensureProviders();
      AppLogger.instance.event('store.load', {
        'phase': 'settings',
        'providers': settings.providers.length,
        'models': settings.models.length,
        'enabledModels': settings.models.where((model) => model.enabled).length,
        'searchProviders': settings.searchProviders.length,
        'mcpServers': settings.mcpServers.length,
        'defaultModel': settings.defaultModelId.isNotEmpty,
        'titleModel': settings.titleModelId.isNotEmpty,
      });
      apiKey = await _secureStorage.read(key: _apiKeyKey) ?? '';
      final providerKeyJson =
          await _secureStorage.read(key: _providerApiKeysKey);
      providerApiKeys
        ..clear()
        ..addAll(_decodeStringMap(providerKeyJson));
      final searchProviderKeyJson =
          await _secureStorage.read(key: _searchProviderApiKeysKey);
      searchProviderApiKeys
        ..clear()
        ..addAll(_decodeStringMap(searchProviderKeyJson));
      if (apiKey.isNotEmpty && providerApiKeys.isEmpty) {
        providerApiKeys[settings.providers.first.id] = apiKey;
      }
      AppLogger.instance.event('store.load', {
        'phase': 'secureStorage',
        'legacyApiKey': apiKey.isNotEmpty,
        'providerKeys': providerApiKeys.length,
        'searchKeys': searchProviderApiKeys.length,
      });
      currentAssistantId =
          prefs.getString(_currentAssistantKey) ?? assistants.first.id;

      sessions
        ..clear()
        ..addAll(_decodeSessionList(prefs.getString(_sessionsKey)));
      if (sessions.isEmpty) {
        sessions.add(_newSession(currentAssistantId));
      }
      currentSessionId =
          prefs.getString(_currentSessionKey) ?? sessions.first.id;
      AppLogger.instance.event('store.load', {
        'phase': 'sessions',
        'count': sessions.length,
        'currentSession': currentSessionId,
        'currentAssistant': currentAssistantId,
      });

      _repairSelection();
      _sortSessions();
      isReady = true;
      AppLogger.instance.event('store.load', {
        'phase': 'ready',
        'currentSessionMessages': currentSession.messages.length,
        'currentAssistant': currentAssistant.id,
      });
      notifyListeners();
    } catch (error, stack) {
      AppLogger.instance.error('store.load', error, stack);
      rethrow;
    }
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
    await _secureStorage.write(
      key: _searchProviderApiKeysKey,
      value: jsonEncode(searchProviderApiKeys),
    );
  }

  Future<void> updateSettings(AppSettings next, String nextApiKey) async {
    settings = next;
    _ensureProviders();
    _repairModelSelections();
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
    _repairModelSelections();
    notifyListeners();
    await save();
  }

  Future<void> deleteProvider(String providerId) async {
    if (isBuiltInProviderId(providerId)) {
      await resetProvider(providerId);
      return;
    }
    if (settings.providers.length <= 1) {
      return;
    }
    settings.providers.removeWhere((provider) => provider.id == providerId);
    settings.models.removeWhere((model) => model.providerId == providerId);
    providerApiKeys.remove(providerId);
    _repairModelSelections();
    notifyListeners();
    await save();
  }

  Future<void> resetProvider(String providerId) async {
    final preset = builtInProviderById(providerId);
    if (preset == null) {
      await deleteProvider(providerId);
      return;
    }
    final index = settings.providers.indexWhere((item) => item.id == providerId);
    if (index == -1) {
      settings.providers.add(preset);
    } else {
      settings.providers[index] = preset;
    }
    settings.models.removeWhere((model) => model.providerId == providerId);
    providerApiKeys.remove(providerId);
    _repairModelSelections();
    notifyListeners();
    await save();
  }

  String apiKeyForProvider(String providerId) {
    return providerApiKeys[providerId] ?? '';
  }

  Future<String> refreshProviderBalance(String providerId) async {
    final provider = providerById(providerId);
    final balance = await AiClient().fetchBalance(
      provider: provider,
      apiKey: apiKeyForProvider(provider.id),
    );
    provider
      ..balanceText = balance
      ..balanceUpdatedAt = balance.isEmpty ? null : DateTime.now();
    notifyListeners();
    await save();
    return balance;
  }

  Future<void> refreshProviderBalances() async {
    var changed = false;
    for (final provider in settings.providers) {
      if (provider.balancePath.trim().isEmpty ||
          apiKeyForProvider(provider.id).trim().isEmpty) {
        continue;
      }
      String balance;
      try {
        balance = await AiClient().fetchBalance(
          provider: provider,
          apiKey: apiKeyForProvider(provider.id),
        );
      } catch (_) {
        continue;
      }
      if (balance.trim().isEmpty) {
        continue;
      }
      provider
        ..balanceText = balance
        ..balanceUpdatedAt = DateTime.now();
      changed = true;
    }
    if (changed) {
      notifyListeners();
      await save();
    }
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
    _repairModelSelections();
    notifyListeners();
    await save();
    return fetched;
  }

  Future<AiModelConfig> addManualModel(
    String providerId,
    String modelName,
  ) async {
    final name = modelName.trim();
    if (name.isEmpty) {
      throw const AiException('请输入模型 ID。');
    }
    final provider = providerById(providerId);
    final model = AiClient().modelFromId(
      provider: provider,
      modelId: name,
      enabled: true,
    );
    final index = settings.models.indexWhere((item) => item.id == model.id);
    if (index == -1) {
      settings.models.add(model);
    } else {
      settings.models[index] = model..enabled = true;
    }
    if (settings.defaultModelId.isEmpty) {
      settings.defaultModelId = model.id;
    }
    provider.updatedAt = DateTime.now();
    _repairModelSelections();
    notifyListeners();
    await save();
    return model;
  }

  Future<void> setModelEnabled(String modelId, bool enabled) async {
    final model = modelById(modelId);
    model.enabled = enabled;
    if (enabled && settings.defaultModelId.isEmpty) {
      settings.defaultModelId = model.id;
    }
    _repairModelSelections();
    notifyListeners();
    await save();
  }

  Future<void> setSessionModel(String modelId) async {
    currentSession.modelId = modelId;
    _repairModelSelections();
    notifyListeners();
    await save();
  }

  Future<void> setSessionSearchEnabled(bool enabled) async {
    currentSession
      ..searchEnabled = enabled
      ..searchMode = enabled ? 'on' : 'off';
    notifyListeners();
    await save();
  }

  bool isSearchEnabledForSession(ChatSession session) {
    return switch (session.searchMode) {
      'on' => true,
      'off' => false,
      _ => settings.searchEnabledByDefault,
    };
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
      orElse: () => throw AiException('模型不可用或未添加：$id'),
    );
  }

  SearchProviderConfig searchProviderById(String id) {
    return settings.searchProviders.firstWhere(
      (provider) => provider.id == id,
      orElse: () => settings.searchProviders.first,
    );
  }

  String apiKeyForSearchProvider(String providerId) {
    return searchProviderApiKeys[providerId] ?? '';
  }

  Future<void> updateSearchProvider(
    SearchProviderConfig provider, {
    String? apiKey,
  }) async {
    final index =
        settings.searchProviders.indexWhere((item) => item.id == provider.id);
    if (index == -1) {
      settings.searchProviders.add(provider);
    } else {
      settings.searchProviders[index] = provider;
    }
    if (apiKey != null) {
      searchProviderApiKeys[provider.id] = apiKey;
    }
    if (provider.enabled && settings.defaultSearchProviderId.isEmpty) {
      settings.defaultSearchProviderId = provider.id;
    }
    _repairModelSelections();
    notifyListeners();
    await save();
  }

  Future<void> deleteSearchProvider(String providerId) async {
    settings.searchProviders.removeWhere((provider) => provider.id == providerId);
    searchProviderApiKeys.remove(providerId);
    if (settings.defaultSearchProviderId == providerId) {
      settings.defaultSearchProviderId = settings.searchProviders.isEmpty
          ? ''
          : settings.searchProviders.first.id;
    }
    _repairModelSelections();
    notifyListeners();
    await save();
  }

  Future<String> testSearchProvider(String providerId) async {
    final provider = SearchProviderConfig.fromJson(
      searchProviderById(providerId).toJson(),
    )..enabled = true;
    if (provider.baseUrl.trim().isEmpty) {
      throw const SearchException('请先填写搜索服务地址。');
    }
    if (searchProviderNeedsApiKey(provider.kind) &&
        apiKeyForSearchProvider(provider.id).trim().isEmpty) {
      throw const SearchException('请先填写搜索服务密钥。');
    }
    final results = await SearchClient().search(
      provider: provider,
      apiKey: apiKeyForSearchProvider(provider.id),
      query: 'OpenAI',
    );
    if (results.isEmpty) {
      return '连接成功，暂无结果';
    }
    return '连接成功，返回 ${results.length} 条结果';
  }

  Future<void> updateMcpServer(McpServerConfig server) async {
    final index = settings.mcpServers.indexWhere((item) => item.id == server.id);
    if (index == -1) {
      settings.mcpServers.add(server);
    } else {
      settings.mcpServers[index] = server;
    }
    notifyListeners();
    await save();
  }

  Future<void> deleteMcpServer(String serverId) async {
    settings.mcpServers.removeWhere((server) => server.id == serverId);
    notifyListeners();
    await save();
  }

  Future<String> testMcpServer(String serverId) async {
    final server = settings.mcpServers.firstWhere(
      (item) => item.id == serverId,
      orElse: () => throw const McpException('MCP 服务不存在。'),
    );
    return McpClient().test(server);
  }

  Future<String> testModel(String modelId) async {
    final model = modelById(modelId);
    final provider = providerById(model.providerId);
    final key = apiKeyForProvider(provider.id);
    if (provider.baseUrl.trim().isEmpty || model.name.trim().isEmpty || key.isEmpty) {
      throw const AiException('请检查模型所属服务商的 Base URL、API Key 和模型。');
    }
    final text = await AiClient().generateText(
      settings: settings,
      apiKey: key,
      assistant: currentAssistant,
      baseUrl: provider.baseUrl,
      model: model.name,
      customHeadersJson: provider.customHeadersJson,
      systemPrompt: '只回复 OK。',
      userPrompt: '请回复 OK。',
      temperature: 0,
      maxTokens: 16,
    );
    final normalized = text.trim();
    return normalized.isEmpty ? '连接成功' : '连接成功：$normalized';
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

  Future<void> renameSession(String id, String title) async {
    final trimmed = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.isEmpty) {
      return;
    }
    final session = sessions.firstWhere(
      (item) => item.id == id,
      orElse: () => currentSession,
    );
    session.title = _truncateTitle(trimmed);
    session.updatedAt = DateTime.now();
    _sortSessions();
    notifyListeners();
    await save();
  }

  Future<void> restoreAutoTitle(String id) async {
    final session = sessions.firstWhere(
      (item) => item.id == id,
      orElse: () => currentSession,
    );
    final firstUser = session.messages.where((message) => message.role == 'user');
    if (firstUser.isEmpty) {
      session.title = '新对话';
      notifyListeners();
      await save();
      return;
    }
    final prompt = firstUser.first.content;
    session.title = '新对话';
    notifyListeners();
    await save();
    if (settings.titleModelId.isNotEmpty) {
      await generateTitleForSession(session.id, fallbackPrompt: prompt);
    } else {
      await _setFallbackTitle(session, prompt);
    }
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

  Future<void> clearUnpinnedSessions() async {
    sessions.removeWhere((session) => !session.pinned);
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

  Future<void> clearSessionsBefore(ChatSession anchor) async {
    final cutoff = anchor.updatedAt;
    sessions.removeWhere(
      (session) => !session.pinned && session.updatedAt.isBefore(cutoff),
    );
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
      status: '思考中',
    );
    session.messages.add(assistantMessage);
    isSending = true;
    _cancelRequested = false;
    _sortSessions();
    notifyListeners();

    await _enableBackgroundDuringGeneration();
    _activeClient = AiClient();
    try {
      final target = _resolveModelTarget(session);
      final assistant = assistantForSession(session);
      final sentWithTools = await _trySendWithSearchTools(
        session: session,
        assistant: assistant,
        assistantMessage: assistantMessage,
        target: target,
      );
      if (!sentWithTools) {
        await _sendWithSearchFallback(
          session: session,
          prompt: trimmed,
          assistant: assistant,
          assistantMessage: assistantMessage,
          target: target,
        );
      }
      if (_cancelRequested && assistantMessage.content.trim().isEmpty) {
        assistantMessage.content = '已停止生成。';
      }
    } catch (error) {
      final message = friendlyError(error);
      assistantMessage.error = message;
      if (assistantMessage.content.trim().isEmpty) {
        assistantMessage.content = message;
      }
    } finally {
      assistantMessage.isStreaming = false;
      assistantMessage.status = '';
      isSending = false;
      _activeClient = null;
      _cancelRequested = false;
      session.updatedAt = DateTime.now();
      _sortSessions();
      notifyListeners();
      await _disableBackgroundAfterGeneration();
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

  String friendlyError(Object error) {
    final raw = error.toString().replaceFirst(RegExp(r'^[A-Za-z]+Exception: '), '');
    final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    final lower = text.toLowerCase();
    if (text.startsWith('请先') || text.startsWith('请选择')) {
      return text;
    }
    if (lower.contains('api key') ||
        lower.contains('apikey') ||
        lower.contains('unauthorized') ||
        lower.contains('forbidden') ||
        lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('密钥')) {
      return '密钥无效或权限不足，请检查服务商配置。';
    }
    if (lower.contains('balance') ||
        lower.contains('quota') ||
        lower.contains('credit') ||
        lower.contains('insufficient') ||
        lower.contains('余额') ||
        lower.contains('429')) {
      return '余额不足或请求过于频繁，请稍后重试。';
    }
    if (lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('tls') ||
        lower.contains('network') ||
        lower.contains('网络')) {
      return '网络连接失败，请稍后重试。';
    }
    if (lower.contains('model') || lower.contains('模型')) {
      return '模型不可用，请重新选择可用模型。';
    }
    if (lower.contains('base url') || lower.contains('地址')) {
      return '服务地址不可用，请检查配置。';
    }
    if (lower.contains('search') || lower.contains('搜索')) {
      return '搜索服务不可用，请检查配置。';
    }
    if (lower.contains('mcp')) {
      return 'MCP 服务不可用，请检查地址和权限。';
    }
    if (text.isEmpty) {
      return '请求失败，请稍后重试。';
    }
    return text.length > 80 ? '${text.substring(0, 80)}...' : text;
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
      if (includeApiKey) 'searchProviderApiKeys': searchProviderApiKeys,
    };
    return prettyJson(payload);
  }

  Future<void> generateTitleForSession(
    String sessionId, {
    required String fallbackPrompt,
  }) async {
    final session = sessions.firstWhere(
      (item) => item.id == sessionId,
      orElse: () => currentSession,
    );
    if (settings.titleModelId.isEmpty) {
      await _setFallbackTitle(session, fallbackPrompt);
      return;
    }
    final assistant = assistantForSession(session);
    try {
      final target = _resolveSpecificModelTarget(settings.titleModelId);
      final title = await AiClient().generateText(
        settings: settings,
        apiKey: target.apiKey,
        assistant: assistant,
        baseUrl: target.provider.baseUrl,
        model: target.model.name,
        customHeadersJson: target.provider.customHeadersJson,
        systemPrompt: '''
你只负责给聊天生成一个简短中文会话标题。
要求：
- 归纳用户意图，不摘抄原句。
- 使用名词短语或任务短语，2 到 10 个中文字符优先，最多 14 个字。
- 闲聊、问候、查询、计划、写作、代码、翻译、总结、比较、建议等都应归入清晰意图。
- 去掉语气词、标点、称呼、冗余对象和口语尾巴。
- 不要解释，不要引号，不要 Markdown。
''',
        userPrompt: fallbackPrompt,
        temperature: 0.2,
        maxTokens: 48,
      );
      final cleaned = title.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (cleaned.isNotEmpty) {
        session.title = cleaned;
        notifyListeners();
        await save();
      } else {
        await _setFallbackTitle(session, fallbackPrompt);
      }
    } catch (_) {
      await _setFallbackTitle(session, fallbackPrompt);
    }
  }

  Future<Map<String, String>> polishAssistantDraft({
    required String brief,
    required String name,
    required String description,
    required String systemPrompt,
    required String relationship,
    required String communicationStyle,
    required String expertise,
    required String familiarTopics,
    required String limitedTopics,
    required String uncertaintyRules,
    required String emojiRules,
    required String paragraphRules,
    required String markdownRules,
    required String toolRules,
    required String advancedRules,
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
        'brief': brief,
        'name': name,
        'description': description,
        'systemPrompt': systemPrompt,
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
        'preferredModelId': modelId,
        'temperature': temperature,
        'topP': topP,
        'maxTokens': maxTokens,
      }),
      temperature: 0.2,
      maxTokens: 1800,
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
    final importedSearchProviderKeys = map['searchProviderApiKeys'];
    if (importedSearchProviderKeys is Map) {
      searchProviderApiKeys
        ..clear()
        ..addAll(importedSearchProviderKeys.map(
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
      searchEnabled: settings.searchEnabledByDefault,
      searchMode: 'follow',
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
      if (session.searchMode != 'on' &&
          session.searchMode != 'off' &&
          session.searchMode != 'follow') {
        session.searchMode = session.searchEnabled ? 'on' : 'follow';
      }
      for (final message in session.messages) {
        message.isStreaming = false;
        message.status = '';
      }
    }
    _repairModelSelections();
  }

  void _repairModelSelections() {
    final enabledIds = settings.models
        .where((model) => model.enabled)
        .map((model) => model.id)
        .toSet();
    if (!enabledIds.contains(settings.defaultModelId)) {
      settings.defaultModelId = enabledIds.isEmpty ? '' : enabledIds.first;
    }
    if (!enabledIds.contains(settings.titleModelId)) {
      settings.titleModelId = '';
    }
    if (!enabledIds.contains(settings.polishModelId)) {
      settings.polishModelId = '';
    }
    for (final session in sessions) {
      if (session.modelId.isNotEmpty && !enabledIds.contains(session.modelId)) {
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
    final searchIds = settings.searchProviders
        .where((provider) {
          if (!provider.enabled) {
            return false;
          }
          final kind = provider.kind.trim().toLowerCase();
          if (!searchProviderNeedsApiKey(kind)) {
            return true;
          }
          return apiKeyForSearchProvider(provider.id).trim().isNotEmpty;
        })
        .map((provider) => provider.id)
        .toSet();
    for (final provider in settings.searchProviders) {
      final kind = provider.kind.trim().toLowerCase();
      if (searchProviderNeedsApiKey(kind) &&
          apiKeyForSearchProvider(provider.id).trim().isEmpty) {
        provider.enabled = false;
      }
    }
    if (!searchIds.contains(settings.defaultSearchProviderId)) {
      settings.defaultSearchProviderId =
          searchIds.isEmpty ? '' : searchIds.first;
    }
  }

  Future<void> _setFallbackTitle(
    ChatSession session,
    String fallbackPrompt,
  ) async {
    if (session.title != '新对话') {
      return;
    }
    session.title = _titleFromPrompt(fallbackPrompt);
    notifyListeners();
    await save();
  }

  void _ensureProviders() {
    if (settings.providers.isEmpty) {
      settings.providers.addAll(defaultProviders());
    }
    for (final preset in defaultProviders()) {
      final index =
          settings.providers.indexWhere((provider) => provider.id == preset.id);
      if (index == -1) {
        settings.providers.add(AiProviderConfig.fromJson(preset.toJson()));
        continue;
      }
      final provider = settings.providers[index];
      if (isBuiltInProviderId(provider.id)) {
        if (provider.modelsPath.trim().isEmpty) {
          provider.modelsPath = preset.modelsPath;
        }
        if (provider.balancePath.trim().isEmpty) {
          provider.balancePath = preset.balancePath;
        }
        if (provider.balanceJsonPath.trim().isEmpty) {
          provider.balanceJsonPath = preset.balanceJsonPath;
        }
      }
    }
    _sortProvidersByPresetOrder();
    if (settings.searchProviders.isEmpty) {
      settings.searchProviders.addAll(defaultSearchProviders());
    }
    for (final preset in defaultSearchProviders()) {
      if (!settings.searchProviders.any((provider) => provider.id == preset.id)) {
        settings.searchProviders.add(
          SearchProviderConfig.fromJson(preset.toJson()),
        );
      }
    }
    if (settings.mcpServers.isEmpty) {
      settings.mcpServers.addAll(defaultMcpServers());
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

  void _sortProvidersByPresetOrder() {
    final order = {
      for (var index = 0; index < defaultProviders().length; index += 1)
        defaultProviders()[index].id: index,
    };
    settings.providers.sort((a, b) {
      final aOrder = order[a.id];
      final bOrder = order[b.id];
      if (aOrder != null && bOrder != null) {
        return aOrder.compareTo(bOrder);
      }
      if (aOrder != null) {
        return -1;
      }
      if (bOrder != null) {
        return 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  Future<_SearchOutcome> _searchContextFor(
    ChatSession session,
    String prompt, {
    required bool shouldSearch,
  }) async {
    if (!shouldSearch) {
      return const _SearchOutcome();
    }
    try {
      final provider = searchProviderById(settings.defaultSearchProviderId);
      final client = SearchClient();
      final response = await client.searchDetailed(
        provider: provider,
        apiKey: apiKeyForSearchProvider(provider.id),
        query: prompt,
      );
      return _SearchOutcome(context: client.formatContext(response));
    } catch (error) {
      return _SearchOutcome(
        error:
            '本轮尝试联网搜索但失败：${friendlyError(error)}。请不要编造实时资料；如果问题需要最新信息，请说明当前无法确认。',
      );
    }
  }

  Future<bool> _trySendWithSearchTools({
    required ChatSession session,
    required AssistantPreset assistant,
    required ChatMessage assistantMessage,
    required _ResolvedModelTarget target,
  }) async {
    if (!_hasUsableSearch(session) || target.model.supportsTools == false) {
      return false;
    }

    final payloads = _baseChatPayloads(
      assistant: assistant,
      session: session,
    );
    final tools = [_webSearchToolDefinition()];
    var toolRounds = 0;

    while (!_cancelRequested) {
      late final AiChatResult result;
      try {
        result = await _activeClient!.sendChat(
          config: AiRequestConfig(
            settings: settings,
            apiKey: target.apiKey,
            assistant: assistant,
            messages: const <ChatMessage>[],
            messagePayloads: payloads,
            tools: tools,
            baseUrl: target.provider.baseUrl,
            model: target.model.name,
            customHeadersJson: target.provider.customHeadersJson,
          ),
          isCancelled: () => _cancelRequested,
          onToolCall: (_) {
            assistantMessage.status = '搜索中';
            notifyListeners();
          },
          onDelta: (delta) {
            assistantMessage.status = '';
            assistantMessage.content += delta;
            notifyListeners();
          },
          onRaw: (raw) {
            _appendRaw(assistantMessage, raw);
          },
        );
      } catch (error) {
        if (toolRounds == 0 &&
            assistantMessage.content.trim().isEmpty &&
            _looksLikeUnsupportedToolError(error)) {
          return false;
        }
        rethrow;
      }

      if (result.toolCalls.isEmpty) {
        return true;
      }

      payloads.add(_assistantToolCallPayload(result));
      if (toolRounds >= 2) {
        if (assistantMessage.content.trim().isEmpty) {
          assistantMessage.content = '搜索调用过多，已停止继续调用。';
        }
        return true;
      }

      toolRounds += 1;
      for (final call in result.toolCalls) {
        if (_cancelRequested) {
          return true;
        }
        assistantMessage.status =
            call.name == 'search_web' ? '搜索中' : '处理中...';
        notifyListeners();
        final toolContent = call.name == 'search_web'
            ? await _executeSearchTool(call)
            : _unknownToolResult(call);
        payloads.add({
          'role': 'tool',
          'tool_call_id': call.id,
          'name': call.name,
          'content': toolContent,
        });
      }
      assistantMessage.status = '思考中';
      notifyListeners();
    }

    return true;
  }

  Future<void> _sendWithSearchFallback({
    required ChatSession session,
    required String prompt,
    required AssistantPreset assistant,
    required ChatMessage assistantMessage,
    required _ResolvedModelTarget target,
  }) async {
    final shouldSearch = _shouldSearch(session, prompt);
    if (shouldSearch) {
      assistantMessage.status = '搜索中';
      notifyListeners();
    }
    final searchOutcome = await _searchContextFor(
      session,
      prompt,
      shouldSearch: shouldSearch,
    );
    assistantMessage.status = '思考中';
    notifyListeners();
    final outboundMessages = [
      ChatMessage(
        id: newEntityId(),
        role: 'system',
        content: _runtimeSystemContext(),
        createdAt: DateTime.now(),
      ),
      if (searchOutcome.context.isNotEmpty)
        ChatMessage(
          id: newEntityId(),
          role: 'system',
          content: searchOutcome.context,
          createdAt: DateTime.now(),
        ),
      if (searchOutcome.error.isNotEmpty)
        ChatMessage(
          id: newEntityId(),
          role: 'system',
          content: searchOutcome.error,
          createdAt: DateTime.now(),
        ),
      ...session.messages
          .where((message) => !message.isStreaming)
          .where((message) => message.content.trim().isNotEmpty),
    ];
    await _activeClient!.sendChat(
      config: AiRequestConfig(
        settings: settings,
        apiKey: target.apiKey,
        assistant: assistant,
        messages: outboundMessages,
        baseUrl: target.provider.baseUrl,
        model: target.model.name,
        customHeadersJson: target.provider.customHeadersJson,
      ),
      isCancelled: () => _cancelRequested,
      onDelta: (delta) {
        assistantMessage.status = '';
        assistantMessage.content += delta;
        notifyListeners();
      },
      onRaw: (raw) {
        _appendRaw(assistantMessage, raw);
      },
    );
  }

  List<Map<String, Object?>> _baseChatPayloads({
    required AssistantPreset assistant,
    required ChatSession session,
  }) {
    final systemPrompt = assistant.compiledSystemPrompt().trim();
    return [
      if (systemPrompt.isNotEmpty)
        {
          'role': 'system',
          'content': systemPrompt,
        },
      {
        'role': 'system',
        'content': _runtimeSystemContext(),
      },
      ...session.messages
          .where((message) => !message.isStreaming)
          .where((message) => message.content.trim().isNotEmpty)
          .map(
            (message) => {
              'role': message.role,
              'content': message.content,
            },
          ),
    ];
  }

  AiToolDefinition _webSearchToolDefinition() {
    final now = DateTime.now();
    return AiToolDefinition(
      name: 'search_web',
      description: '''
Search the web for current, verifiable, or specific information.
Use this when the user asks for latest/current facts, news, prices, weather, schedules, source verification, or a concrete web page.
Generate focused search keywords. Run more than one search only when the first results are not enough.
Today is ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.

When using results, cite the relevant sentence with [citation,domain](id). Use only ids returned by the tool.
If the results are weak or unavailable, say that clearly instead of guessing.
'''.trim(),
      parameters: const {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Focused search query.',
          },
        },
        'required': ['query'],
      },
    );
  }

  Future<String> _executeSearchTool(AiToolCall call) async {
    final query = _queryFromToolArguments(call.arguments);
    if (query.isEmpty) {
      return _toolError('搜索参数缺少 query。');
    }
    try {
      final provider = searchProviderById(settings.defaultSearchProviderId);
      final client = SearchClient();
      final response = await client.searchDetailed(
        provider: provider,
        apiKey: apiKeyForSearchProvider(provider.id),
        query: query,
      );
      if (response.isEmpty) {
        return _toolError('没有搜索结果。');
      }
      return client.formatToolResponse(response);
    } catch (error) {
      return _toolError(friendlyError(error));
    }
  }

  Map<String, Object?> _assistantToolCallPayload(AiChatResult result) {
    return {
      'role': 'assistant',
      'content': result.content,
      'tool_calls': result.toolCalls.map((call) => call.toOpenAiJson()).toList(),
    };
  }

  String _unknownToolResult(AiToolCall call) {
    return _toolError('不支持的工具：${call.name}');
  }

  String _toolError(String message) {
    return const JsonEncoder.withIndent('  ').convert({
      'error': message,
      'items': <Object>[],
    });
  }

  String _queryFromToolArguments(String arguments) {
    final trimmed = arguments.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        for (final key in const ['query', 'q', 'keyword', 'keywords']) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }
    } catch (_) {
      return trimmed;
    }
    return trimmed;
  }

  bool _looksLikeUnsupportedToolError(Object error) {
    final text = error.toString().toLowerCase();
    final mentionsTool = text.contains('tool') ||
        text.contains('function_call') ||
        text.contains('function calling') ||
        text.contains('function');
    final unsupported = text.contains('not support') ||
        text.contains('unsupported') ||
        text.contains('unknown parameter') ||
        text.contains('invalid parameter') ||
        text.contains('unrecognized') ||
        text.contains('不支持');
    return mentionsTool && unsupported;
  }

  void _appendRaw(ChatMessage message, String raw) {
    if (raw.trim().isEmpty) {
      return;
    }
    message.raw = message.raw.trim().isEmpty ? raw : '${message.raw}\n$raw';
  }

  bool _hasUsableSearch(ChatSession session) {
    if (!isSearchEnabledForSession(session) ||
        settings.defaultSearchProviderId.isEmpty) {
      return false;
    }
    try {
      final provider = searchProviderById(settings.defaultSearchProviderId);
      if (!provider.enabled || provider.baseUrl.trim().isEmpty) {
        return false;
      }
      final kind = provider.kind.trim().toLowerCase();
      return !searchProviderNeedsApiKey(kind) ||
          apiKeyForSearchProvider(provider.id).trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _shouldSearch(ChatSession session, String prompt) {
    return _hasUsableSearch(session) && _promptNeedsSearch(prompt);
  }

  bool _promptNeedsSearch(String prompt) {
    final text = prompt.trim();
    if (text.isEmpty) {
      return false;
    }
    final lower = text.toLowerCase();
    if (RegExp(r'https?://|www\.|[\w-]+\.(com|cn|net|org|io|ai|dev|app)\b')
        .hasMatch(lower)) {
      return true;
    }
    const directTriggers = [
      '搜索',
      '联网',
      '查一下',
      '查下',
      '搜一下',
      '网上',
      '官网',
      '来源',
      '新闻',
      '最新',
      '近期',
      '最近',
      '现任',
      '当前版本',
      '今天的',
      '实时',
      '股价',
      '汇率',
      '价格',
      '余额',
      '天气',
      '赛程',
      '比赛',
      '航班',
      '票价',
      '政策',
      '法规',
      '发布',
      '更新',
    ];
    if (directTriggers.any(text.contains)) {
      return true;
    }
    const englishTriggers = [
      'latest',
      'recent',
      'today',
      'current',
      'news',
      'weather',
      'price',
      'stock',
      'schedule',
      'release',
      'version',
      'who is the current',
    ];
    return englishTriggers.any(lower.contains);
  }

  String _runtimeSystemContext() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absOffset = offset.abs();
    final hours = absOffset.inHours.toString().padLeft(2, '0');
    final minutes =
        (absOffset.inMinutes % 60).toString().padLeft(2, '0');
    final platform = kIsWeb
        ? 'web'
        : Platform.operatingSystem;
    final locale = kIsWeb ? '' : Platform.localeName;
    return [
      '系统上下文：',
      '- 当前本地时间：${_formatDateTime(now)}',
      '- 时区：${now.timeZoneName} UTC$sign$hours:$minutes',
      if (locale.trim().isNotEmpty) '- 系统语言：$locale',
      '- 平台：$platform',
      '请用这些系统上下文回答时间、日期、时区等问题；不要臆测未提供的位置、日历、联系人、文件、电量或其它隐私数据。',
    ].join('\n');
  }

  String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  Future<void> _enableBackgroundDuringGeneration() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      if (!_backgroundInitialized) {
        _backgroundInitialized = await FlutterBackground.initialize(
          androidConfig: const FlutterBackgroundAndroidConfig(
            notificationTitle: 'Chait 正在生成',
            notificationText: '正在保持网络连接',
            notificationImportance: AndroidNotificationImportance.normal,
            notificationIcon: AndroidResource(
              name: 'ic_launcher',
              defType: 'mipmap',
            ),
            enableWifiLock: true,
          ),
        );
      }
      if (_backgroundInitialized &&
          !FlutterBackground.isBackgroundExecutionEnabled) {
        _backgroundHeld = await FlutterBackground.enableBackgroundExecution();
      }
    } catch (_) {
      _backgroundHeld = false;
    }
  }

  Future<void> _disableBackgroundAfterGeneration() async {
    if (kIsWeb || !Platform.isAndroid || !_backgroundHeld) {
      return;
    }
    try {
      await FlutterBackground.disableBackgroundExecution();
    } catch (_) {
      // The request is already finished; failing to release here should not
      // affect the chat response.
    } finally {
      _backgroundHeld = false;
    }
  }

  _ResolvedModelTarget _resolveModelTarget(ChatSession session) {
    final assistant = assistantForSession(session);
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
    if (!model.enabled) {
      throw AiException('模型未启用：${model.displayName}');
    }
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
    final lower = normalized.toLowerCase();
    if (normalized.isEmpty) {
      return '新对话';
    }
    if (RegExp(r'^(你?好|您好|你好吗|最近好吗|hi|hello|hey|嗨|哈喽)[\s!！。,.，?？]*$')
        .hasMatch(lower)) {
      return '问候';
    }
    if (lower.contains('天气') ||
        lower.contains('气温') ||
        lower.contains('下雨') ||
        lower.contains('台风')) {
      return '询问天气';
    }
    if (lower.contains('翻译') || lower.contains('translate')) {
      return '文本翻译';
    }
    if (lower.contains('总结') ||
        lower.contains('概括') ||
        lower.contains('摘要') ||
        lower.contains('summarize')) {
      return '内容总结';
    }
    if (lower.contains('代码') ||
        lower.contains('报错') ||
        lower.contains('bug') ||
        lower.contains('flutter') ||
        lower.contains('api')) {
      return '代码问题';
    }
    if (lower.contains('写') ||
        lower.contains('润色') ||
        lower.contains('文案') ||
        lower.contains('标题')) {
      return '写作处理';
    }
    if (lower.contains('比较') ||
        lower.contains('哪个好') ||
        lower.contains('区别') ||
        lower.contains('对比')) {
      return '方案比较';
    }
    if (lower.contains('计划') ||
        lower.contains('安排') ||
        lower.contains('规划') ||
        lower.contains('日程')) {
      return '计划安排';
    }
    if (lower.contains('搜索') ||
        lower.contains('查') ||
        lower.contains('最新') ||
        lower.contains('新闻')) {
      return '信息查询';
    }
    if (lower.contains('?') || lower.contains('？') || lower.startsWith('为什么')) {
      return '问题咨询';
    }
    if (normalized.length <= 18) {
      return normalized;
    }
    return _truncateTitle(normalized, max: 18);
  }

  String _truncateTitle(String value, {int max = 24}) {
    final runes = value.runes.toList();
    if (runes.length <= max) {
      return value;
    }
    return '${String.fromCharCodes(runes.take(max))}...';
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
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
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

class _SearchOutcome {
  const _SearchOutcome({
    this.context = '',
    this.error = '',
  });

  final String context;
  final String error;
}

const _polishSystemPrompt = '''
你是 AI 助手预设设计器。请把用户的一句话描述和现有配置，转换为可微调的专业助手规范。
必须只返回 JSON 对象，不要 Markdown，不要解释。
字段：
- name: 简短中文名称，2 到 8 个字。
- description: 14 到 28 个字，说明用途和适用任务，不营销。
- relationship: 服务边界与交互方式，例如编辑、技术协作者、学习教练、研究助理。
- communicationStyle: 句长、正式度、术语密度、解释深度、追问方式和默认语气。
- expertise: 核心能力和可以稳定完成的任务类型。
- familiarTopics: 允许基于常识、上下文或用户资料处理的知识范围。
- limitedTopics: 不该强答、需要查证、需要工具或需要降低确定性的范围。
- uncertaintyRules: 不确定、超出知识范围、实时信息和高风险问题的处理方式。
- emojiRules: 语气限制，例如少用 emoji、避免口号、避免过度热情或机械道歉。
- paragraphRules: 结构和篇幅规则。不要默认机械分段，不要每句另起一段。
- markdownRules: Markdown、代码、公式、表格、引用、长短文结构和输出格式偏好。
- toolRules: 搜索、系统时间、MCP、附件等工具的使用条件。
- advancedRules: 高级约束，包含不要暴露系统设定、不要编造来源、不要模板化话术等。
- systemPrompt: 用户额外补充的最终硬性指令。没有必要时可保留现有值或返回空字符串。
- temperature: 0 到 2 的数字字符串；偏事实任务降低，创意任务可提高。
- topP: 0 到 1 的数字字符串。
- maxTokens: 256 到 8192 的整数字符串。
不要修改 preferredModelId，原样返回。
如果 brief 与现有字段冲突，以 brief 为主，但不要生成危险、欺骗、色情、仇恨、违法或要求模型假装真实经历、权限或来源的设定。
''';
