import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_client.dart';
import 'mcp_client.dart';
import 'models.dart';
import 'search_client.dart';

class AppStore extends ChangeNotifier {
  AppStore();

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
    final searchProviderKeyJson =
        await _secureStorage.read(key: _searchProviderApiKeysKey);
    searchProviderApiKeys
      ..clear()
      ..addAll(_decodeStringMap(searchProviderKeyJson));
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
    currentSession.searchEnabled = enabled;
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
    if (provider.kind.trim().toLowerCase() != 'custom' &&
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
      status: _hasUsableSearch(session) ? '搜索中' : '...',
    );
    session.messages.add(assistantMessage);
    isSending = true;
    _cancelRequested = false;
    _sortSessions();
    notifyListeners();

    _activeClient = AiClient();
    try {
      final target = _resolveModelTarget(session);
      final assistant = assistantForSession(session);
      if (_hasUsableSearch(session)) {
        assistantMessage.status = '搜索中';
        notifyListeners();
      }
      final searchContext = await _searchContextFor(session, trimmed);
      assistantMessage.status = _statusForModel(target.model);
      notifyListeners();
      final outboundMessages = [
        if (searchContext.isNotEmpty)
          ChatMessage(
            id: newEntityId(),
            role: 'system',
            content: searchContext,
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
          assistantMessage.raw = raw;
        },
      );
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
        systemPrompt: '你只负责给聊天生成一个简短中文标题。不要解释，不要引号，最多 14 个字。',
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
          if (kind == 'custom') {
            return true;
          }
          return apiKeyForSearchProvider(provider.id).trim().isNotEmpty;
        })
        .map((provider) => provider.id)
        .toSet();
    for (final provider in settings.searchProviders) {
      final kind = provider.kind.trim().toLowerCase();
      if (kind != 'custom' &&
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

  Future<String> _searchContextFor(ChatSession session, String prompt) async {
    if (!_hasUsableSearch(session)) {
      return '';
    }
    try {
      final provider = searchProviderById(settings.defaultSearchProviderId);
      final client = SearchClient();
      final results = await client.search(
        provider: provider,
        apiKey: apiKeyForSearchProvider(provider.id),
        query: prompt,
      );
      return client.formatResults(results);
    } catch (_) {
      return '';
    }
  }

  bool _hasUsableSearch(ChatSession session) {
    if (!session.searchEnabled || settings.defaultSearchProviderId.isEmpty) {
      return false;
    }
    try {
      final provider = searchProviderById(settings.defaultSearchProviderId);
      if (!provider.enabled || provider.baseUrl.trim().isEmpty) {
        return false;
      }
      final kind = provider.kind.trim().toLowerCase();
      return kind == 'custom' ||
          apiKeyForSearchProvider(provider.id).trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _statusForModel(AiModelConfig model) {
    final name = model.name.toLowerCase();
    if (name.contains('reason') ||
        name.contains('thinking') ||
        name.contains('r1') ||
        name.contains('o1') ||
        name.contains('o3')) {
      return '思考中';
    }
    return '...';
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
