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

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final List<AssistantPreset> assistants = [];
  final List<ChatSession> sessions = [];
  AppSettings settings = AppSettings();
  String apiKey = '';
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
    apiKey = await _secureStorage.read(key: _apiKeyKey) ?? '';
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
  }

  Future<void> updateSettings(AppSettings next, String nextApiKey) async {
    settings = next;
    apiKey = nextApiKey;
    notifyListeners();
    await save();
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
    final now = DateTime.now();
    session.messages.add(
      ChatMessage(
        id: newEntityId(),
        role: 'user',
        content: trimmed,
        createdAt: now,
      ),
    );
    if (session.title == '新对话') {
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
      await _activeClient!.sendChat(
        config: AiRequestConfig(
          settings: settings,
          apiKey: apiKey,
          assistant: currentAssistant,
          messages: session.messages
              .where((message) => !message.isStreaming)
              .where((message) => message.content.trim().isNotEmpty)
              .toList(),
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
    };
    return prettyJson(payload);
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
    }
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
}
