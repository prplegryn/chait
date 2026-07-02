import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_store.dart';
import '../models.dart';

const _ink = Color(0xFF111111);
const _muted = Color(0xFF8B8B8B);
const _line = Color(0xFFEDEDED);
const _soft = Color(0xFFF7F7F7);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('设置')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    title: '助手预设',
                    subtitle: '语气、角色、系统提示词',
                    icon: Icons.person_outline_rounded,
                    onTap: () => _open(
                      context,
                      AssistantListPage(store: store),
                    ),
                  ),
                  _SettingsTile(
                    title: '服务商设定',
                    subtitle: '实时获取模型、勾选可用模型',
                    icon: Icons.cloud_outlined,
                    onTap: () => _open(
                      context,
                      ProviderSettingsPage(store: store),
                    ),
                  ),
                  _SettingsTile(
                    title: '默认参数',
                    subtitle: 'temperature、top_p、max tokens、扩展 JSON',
                    icon: Icons.tune_rounded,
                    onTap: () => _open(
                      context,
                      DefaultParamsPage(store: store),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    title: '外观',
                    subtitle: '白色调、触感反馈',
                    icon: Icons.contrast_rounded,
                    onTap: () => _open(
                      context,
                      AppearancePage(store: store),
                    ),
                  ),
                  _SettingsTile(
                    title: '数据与备份',
                    subtitle: '导入、导出、清理',
                    icon: Icons.inventory_2_outlined,
                    onTap: () => _open(
                      context,
                      DataPage(store: store),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class ProviderSettingsPage extends StatelessWidget {
  const ProviderSettingsPage({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('服务商设定')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              const _StaticNotice(
                title: '模型实时获取',
                body: '这里不内置模型 ID。进入服务商后点击刷新，会从服务商 /models 接口读取当前可调用模型和元数据。',
              ),
              ...store.settings.providers.map((provider) {
                final enabledCount = store.settings.models
                    .where(
                      (model) => model.providerId == provider.id && model.enabled,
                    )
                    .length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SettingsCard(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      title: Text(provider.name),
                      subtitle: Text(
                        enabledCount == 0
                            ? '未添加模型'
                            : '已添加 $enabledCount 个模型',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: _muted,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProviderDetailPage(
                            store: store,
                            providerId: provider.id,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class ProviderDetailPage extends StatefulWidget {
  const ProviderDetailPage({
    super.key,
    required this.store,
    required this.providerId,
  });

  final AppStore store;
  final String providerId;

  @override
  State<ProviderDetailPage> createState() => _ProviderDetailPageState();
}

class _ProviderDetailPageState extends State<ProviderDetailPage> {
  late AiProviderConfig provider;
  late final TextEditingController name;
  late final TextEditingController baseUrl;
  late final TextEditingController modelsPath;
  late final TextEditingController apiKey;
  late final TextEditingController headers;
  bool loading = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    provider = AiProviderConfig.fromJson(
      widget.store.providerById(widget.providerId).toJson(),
    );
    name = TextEditingController(text: provider.name);
    baseUrl = TextEditingController(text: provider.baseUrl);
    modelsPath = TextEditingController(text: provider.modelsPath);
    apiKey = TextEditingController(
      text: widget.store.apiKeyForProvider(provider.id),
    );
    headers = TextEditingController(text: provider.customHeadersJson);
  }

  @override
  void dispose() {
    name.dispose();
    baseUrl.dispose();
    modelsPath.dispose();
    apiKey.dispose();
    headers.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_isJsonObject(headers.text)) {
      _snack(context, '自定义请求头必须是 JSON 对象。');
      return;
    }
    provider
      ..name = name.text.trim()
      ..baseUrl = baseUrl.text.trim()
      ..modelsPath = modelsPath.text.trim().isEmpty ? '/models' : modelsPath.text.trim()
      ..customHeadersJson = headers.text.trim().isEmpty ? '{}' : headers.text;
    await widget.store.updateProvider(provider, apiKey: apiKey.text.trim());
  }

  Future<void> _refresh() async {
    await _save();
    setState(() {
      loading = true;
      error = '';
    });
    try {
      await widget.store.refreshProviderModels(provider.id);
    } catch (err) {
      error = err.toString();
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final models = widget.store.settings.models
        .where((model) => model.providerId == provider.id)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        return _EditScaffold(
          title: provider.name,
          onSave: _save,
          child: Column(
            children: [
              _Field(label: '名称', hint: 'OpenAI', controller: name),
              _Field(
                label: 'Base URL',
                hint: 'https://api.example.com/v1',
                controller: baseUrl,
                keyboardType: TextInputType.url,
              ),
              _Field(
                label: '模型列表路径',
                hint: '/models',
                controller: modelsPath,
              ),
              _Field(
                label: 'API Key',
                hint: '服务商密钥',
                controller: apiKey,
                obscureText: true,
              ),
              _Field(
                label: '自定义请求头 JSON',
                hint: '{"HTTP-Referer":"https://example.com"}',
                controller: headers,
                minLines: 4,
                maxLines: 8,
              ),
              _ActionButton(
                label: loading ? '正在刷新…' : '从服务商刷新模型',
                onPressed: loading ? () {} : _refresh,
              ),
              if (error.isNotEmpty) ...[
                const SizedBox(height: 10),
                _StaticNotice(title: '刷新失败', body: error),
              ],
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '可用模型',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              if (models.isEmpty)
                const _StaticNotice(
                  title: '暂无模型',
                  body: '点击刷新后会显示服务商当前返回的模型；勾选后才会进入聊天、标题生成和润色模型选择。',
                )
              else
                ...models.map(
                  (model) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ModelMetadataTile(
                      model: model,
                      value: model.enabled,
                      onChanged: (value) =>
                          widget.store.setModelEnabled(model.id, value),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class ApiSettingsPage extends StatefulWidget {
  const ApiSettingsPage({super.key, required this.store});

  final AppStore store;

  @override
  State<ApiSettingsPage> createState() => _ApiSettingsPageState();
}

class _ApiSettingsPageState extends State<ApiSettingsPage> {
  late final TextEditingController baseUrl;
  late final TextEditingController apiKey;
  late final TextEditingController model;
  late final TextEditingController headers;
  late bool stream;

  @override
  void initState() {
    super.initState();
    final settings = widget.store.settings;
    baseUrl = TextEditingController(text: settings.baseUrl);
    apiKey = TextEditingController(text: widget.store.apiKey);
    model = TextEditingController(text: settings.model);
    headers = TextEditingController(text: settings.customHeadersJson);
    stream = settings.stream;
  }

  @override
  void dispose() {
    baseUrl.dispose();
    apiKey.dispose();
    model.dispose();
    headers.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_isJsonObject(headers.text)) {
      _snack(context, '自定义请求头必须是 JSON 对象。');
      return;
    }
    final next = copySettings(widget.store.settings)
      ..baseUrl = baseUrl.text.trim()
      ..model = model.text.trim()
      ..stream = stream
      ..customHeadersJson = headers.text.trim().isEmpty ? '{}' : headers.text;
    await widget.store.updateSettings(next, apiKey.text.trim());
    if (!mounted) {
      return;
    }
    _snack(context, '已保存');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _EditScaffold(
      title: 'API 与模型',
      onSave: _save,
      child: Column(
        children: [
          _Field(
            label: 'API 地址',
            hint: 'https://api.example.com/v1',
            controller: baseUrl,
            keyboardType: TextInputType.url,
          ),
          _Field(
            label: 'API Key',
            hint: 'sk-...',
            controller: apiKey,
            obscureText: true,
          ),
          _Field(
            label: '模型',
            hint: 'gpt-4o-mini / deepseek-chat / 自定义模型名',
            controller: model,
          ),
          SwitchListTile(
            value: stream,
            activeThumbColor: _ink,
            contentPadding: EdgeInsets.zero,
            title: const Text('流式输出'),
            subtitle: const Text('支持 SSE 的接口会逐字返回'),
            onChanged: (value) => setState(() => stream = value),
          ),
          _Field(
            label: '自定义请求头 JSON',
            hint: '{"HTTP-Referer":"https://example.com"}',
            controller: headers,
            minLines: 4,
            maxLines: 8,
          ),
        ],
      ),
    );
  }
}

class AssistantListPage extends StatelessWidget {
  const AssistantListPage({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('助手预设'),
            actions: [
              IconButton(
                tooltip: '新建助手',
                icon: const Icon(Icons.add_rounded),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AssistantEditorPage(
                      store: store,
                      preset: AssistantPreset(
                        id: newEntityId(),
                        name: '',
                        description: '',
                        systemPrompt: '',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            itemCount: store.assistants.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final assistant = store.assistants[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(assistant.name),
                subtitle: Text(assistant.description),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AssistantEditorPage(
                            store: store,
                            preset: AssistantPreset.fromJson(
                              assistant.toJson(),
                            ),
                          ),
                        ),
                      );
                    } else if (value == 'delete') {
                      store.deleteAssistant(assistant.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AssistantEditorPage(
                      store: store,
                      preset: AssistantPreset.fromJson(assistant.toJson()),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class AssistantEditorPage extends StatefulWidget {
  const AssistantEditorPage({
    super.key,
    required this.store,
    required this.preset,
  });

  final AppStore store;
  final AssistantPreset preset;

  @override
  State<AssistantEditorPage> createState() => _AssistantEditorPageState();
}

class _AssistantEditorPageState extends State<AssistantEditorPage> {
  late final TextEditingController name;
  late final TextEditingController description;
  late final TextEditingController prompt;
  late final TextEditingController temperature;
  late final TextEditingController topP;
  late final TextEditingController maxTokens;
  late String preferredModelId;
  bool polishing = false;

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    name = TextEditingController(text: preset.name);
    description = TextEditingController(text: preset.description);
    prompt = TextEditingController(text: preset.systemPrompt);
    prompt.addListener(_onPromptChanged);
    preferredModelId = preset.preferredModelId;
    temperature = TextEditingController(text: preset.temperature?.toString());
    topP = TextEditingController(text: preset.topP?.toString());
    maxTokens = TextEditingController(text: preset.maxTokens?.toString());
  }

  @override
  void dispose() {
    prompt.removeListener(_onPromptChanged);
    name.dispose();
    description.dispose();
    prompt.dispose();
    temperature.dispose();
    topP.dispose();
    maxTokens.dispose();
    super.dispose();
  }

  void _onPromptChanged() => setState(() {});

  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      _snack(context, '助手名称不能为空。');
      return;
    }
    final preset = widget.preset
      ..name = name.text.trim()
      ..description = description.text.trim()
      ..systemPrompt = prompt.text.trim()
      ..modelOverride = ''
      ..preferredModelId = preferredModelId
      ..temperature = _nullableDouble(temperature.text)
      ..topP = _nullableDouble(topP.text)
      ..maxTokens = _nullableInt(maxTokens.text);
    await widget.store.upsertAssistant(preset);
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _polish() async {
    if (prompt.text.trim().isEmpty || polishing) {
      return;
    }
    setState(() => polishing = true);
    try {
      final result = await widget.store.polishAssistantDraft(
        name: name.text,
        description: description.text,
        systemPrompt: prompt.text,
        temperature: temperature.text,
        topP: topP.text,
        maxTokens: maxTokens.text,
        modelId: preferredModelId,
      );
      name.text = result['name'] ?? name.text;
      description.text = result['description'] ?? description.text;
      prompt.text = result['systemPrompt'] ?? prompt.text;
      temperature.text = result['temperature'] ?? temperature.text;
      topP.text = result['topP'] ?? topP.text;
      maxTokens.text = result['maxTokens'] ?? maxTokens.text;
      preferredModelId = result['preferredModelId'] ?? preferredModelId;
    } catch (error) {
      if (mounted) {
        _snack(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => polishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditScaffold(
      title: '编辑助手',
      onSave: _save,
      child: Column(
        children: [
          _Field(label: '名称', hint: '写作助手', controller: name),
          _Field(label: '说明', hint: '结构、标题、润色', controller: description),
          _PromptField(
            label: '系统提示词',
            hint: '定义这个助手的角色、语气、边界和输出偏好',
            controller: prompt,
            polishing: polishing,
            onPolish: prompt.text.trim().isEmpty ? null : _polish,
          ),
          _ModelPickerTile(
            label: '助手偏好模型',
            value: preferredModelId,
            models: widget.store.enabledModels,
            emptyLabel: '继承全局默认模型',
            onChanged: (value) => setState(() => preferredModelId = value),
          ),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'temperature',
                  hint: '继承',
                  controller: temperature,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  label: 'top_p',
                  hint: '继承',
                  controller: topP,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          _Field(
            label: 'max tokens',
            hint: '继承',
            controller: maxTokens,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }
}

class DefaultParamsPage extends StatefulWidget {
  const DefaultParamsPage({super.key, required this.store});

  final AppStore store;

  @override
  State<DefaultParamsPage> createState() => _DefaultParamsPageState();
}

class _DefaultParamsPageState extends State<DefaultParamsPage> {
  late String defaultModelId;
  late String titleModelId;
  late String polishModelId;
  late final TextEditingController temperature;
  late final TextEditingController topP;
  late final TextEditingController maxTokens;
  late final TextEditingController presencePenalty;
  late final TextEditingController frequencyPenalty;
  late final TextEditingController seed;
  late final TextEditingController stop;
  late final TextEditingController responseFormat;
  late final TextEditingController extraBody;

  @override
  void initState() {
    super.initState();
    final settings = widget.store.settings;
    defaultModelId = settings.defaultModelId;
    titleModelId = settings.titleModelId;
    polishModelId = settings.polishModelId;
    temperature = TextEditingController(text: settings.temperature.toString());
    topP = TextEditingController(text: settings.topP.toString());
    maxTokens = TextEditingController(text: settings.maxTokens.toString());
    presencePenalty =
        TextEditingController(text: settings.presencePenalty.toString());
    frequencyPenalty =
        TextEditingController(text: settings.frequencyPenalty.toString());
    seed = TextEditingController(text: settings.seed);
    stop = TextEditingController(text: settings.stopSequences);
    responseFormat = TextEditingController(text: settings.responseFormat);
    extraBody = TextEditingController(text: settings.extraBodyJson);
  }

  @override
  void dispose() {
    temperature.dispose();
    topP.dispose();
    maxTokens.dispose();
    presencePenalty.dispose();
    frequencyPenalty.dispose();
    seed.dispose();
    stop.dispose();
    responseFormat.dispose();
    extraBody.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_isJsonObject(extraBody.text)) {
      _snack(context, '扩展请求体必须是 JSON 对象。');
      return;
    }
    final next = copySettings(widget.store.settings)
      ..defaultModelId = defaultModelId
      ..titleModelId = titleModelId
      ..polishModelId = polishModelId
      ..temperature = _doubleOr(temperature.text, 0.7)
      ..topP = _doubleOr(topP.text, 1)
      ..maxTokens = _intOr(maxTokens.text, 2048)
      ..presencePenalty = _doubleOr(presencePenalty.text, 0)
      ..frequencyPenalty = _doubleOr(frequencyPenalty.text, 0)
      ..seed = seed.text.trim()
      ..stopSequences = stop.text
      ..responseFormat = responseFormat.text.trim()
      ..extraBodyJson = extraBody.text.trim().isEmpty ? '{}' : extraBody.text;
    await widget.store.updateSettings(next, widget.store.apiKey);
    if (!mounted) {
      return;
    }
    _snack(context, '已保存');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _EditScaffold(
      title: '默认参数',
      onSave: _save,
      child: Column(
        children: [
          _ModelPickerTile(
            label: '全局默认会话模型',
            value: defaultModelId,
            models: widget.store.enabledModels,
            allowEmpty: false,
            onChanged: (value) => setState(() => defaultModelId = value),
          ),
          _ModelPickerTile(
            label: '标题生成模型',
            value: titleModelId,
            models: widget.store.enabledModels,
            emptyLabel: '未设置时使用第一条消息',
            onChanged: (value) => setState(() => titleModelId = value),
          ),
          _ModelPickerTile(
            label: '润色模型',
            value: polishModelId,
            models: widget.store.enabledModels,
            emptyLabel: '未设置',
            onChanged: (value) => setState(() => polishModelId = value),
          ),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'temperature',
                  hint: '0.7',
                  controller: temperature,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  label: 'top_p',
                  hint: '1',
                  controller: topP,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          _Field(
            label: 'max tokens',
            hint: '2048',
            controller: maxTokens,
            keyboardType: TextInputType.number,
          ),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'presence penalty',
                  hint: '0',
                  controller: presencePenalty,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  label: 'frequency penalty',
                  hint: '0',
                  controller: frequencyPenalty,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          _Field(label: 'seed', hint: '可选', controller: seed),
          _Field(
            label: 'stop',
            hint: '每行一个停止词',
            controller: stop,
            minLines: 3,
            maxLines: 6,
          ),
          _Field(
            label: 'response_format',
            hint: 'json_object 或 {"type":"json_schema",...}',
            controller: responseFormat,
          ),
          _Field(
            label: '扩展请求体 JSON',
            hint: '{"reasoning_effort":"medium","tools":[]}',
            controller: extraBody,
            minLines: 7,
            maxLines: 12,
          ),
        ],
      ),
    );
  }
}

class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key, required this.store});

  final AppStore store;

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  late bool haptics;

  @override
  void initState() {
    super.initState();
    haptics = widget.store.settings.haptics;
  }

  Future<void> _save() async {
    final next = copySettings(widget.store.settings)..haptics = haptics;
    await widget.store.updateSettings(next, widget.store.apiKey);
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _EditScaffold(
      title: '外观',
      onSave: _save,
      child: Column(
        children: [
          const _StaticNotice(
            title: '白色调',
            body: '界面保持白色和灰阶，不提供彩色主题。',
          ),
          SwitchListTile(
            value: haptics,
            activeThumbColor: _ink,
            contentPadding: EdgeInsets.zero,
            title: const Text('触感反馈'),
            subtitle: const Text('发送、切换助手等操作使用轻触反馈'),
            onChanged: (value) => setState(() => haptics = value),
          ),
        ],
      ),
    );
  }
}

class DataPage extends StatefulWidget {
  const DataPage({super.key, required this.store});

  final AppStore store;

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  bool includeApiKey = false;

  Future<void> _export() async {
    final data = await widget.store.exportData(includeApiKey: includeApiKey);
    await Clipboard.setData(ClipboardData(text: data));
    if (!mounted) {
      return;
    }
    _snack(context, '备份已复制到剪贴板');
  }

  Future<void> _import() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      _snack(context, '剪贴板没有可导入内容。');
      return;
    }
    try {
      await widget.store.importData(text);
      if (!mounted) {
        return;
      }
      _snack(context, '导入完成');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _snack(context, '导入失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据与备份')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          SwitchListTile(
            value: includeApiKey,
            activeThumbColor: _ink,
            contentPadding: EdgeInsets.zero,
            title: const Text('导出时包含 API Key'),
            subtitle: const Text('默认不导出密钥'),
            onChanged: (value) => setState(() => includeApiKey = value),
          ),
          const SizedBox(height: 10),
          _ActionButton(label: '复制备份', onPressed: _export),
          const SizedBox(height: 10),
          _ActionButton(label: '从剪贴板导入', onPressed: _import),
        ],
      ),
    );
  }
}

class _EditScaffold extends StatelessWidget {
  const _EditScaffold({
    required this.title,
    required this.onSave,
    required this.child,
  });

  final String title;
  final Future<void> Function() onSave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: onSave,
            child: const Text(
              '保存',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [child],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ModelMetadataTile extends StatelessWidget {
  const _ModelMetadataTile({
    required this.model,
    required this.value,
    required this.onChanged,
  });

  final AiModelConfig model;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      child: CheckboxListTile(
        value: value,
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? _ink : null,
        ),
        checkboxShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        title: Text(
          model.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _modelMeta(model),
            style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.35),
          ),
        ),
        onChanged: (next) => onChanged(next ?? false),
      ),
    );
  }
}

String _modelMeta(AiModelConfig model) {
  final parts = <String>[
    model.name,
    if (model.contextWindow != null) '上下文 ${model.contextWindow}',
    if (model.maxOutputTokens != null) '输出 ${model.maxOutputTokens}',
    if (model.supportsTools == true) '工具',
    if (model.supportsVision == true) '视觉',
    if (model.supportsJsonMode == true) 'JSON',
    if (model.supportsStructuredOutput == true) '结构化',
    if (model.inputModalities.isNotEmpty) '输入 ${model.inputModalities.join('/')}',
    if (model.outputModalities.isNotEmpty) '输出 ${model.outputModalities.join('/')}',
  ];
  return parts.join(' · ');
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _ink),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
      onTap: onTap,
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            minLines: minLines,
            maxLines: obscureText ? 1 : maxLines,
            cursorColor: _ink,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _muted, fontSize: 14),
              filled: true,
              fillColor: _soft,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: _ink, fontSize: 15, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _PromptField extends StatelessWidget {
  const _PromptField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.polishing,
    required this.onPolish,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool polishing;
  final VoidCallback? onPolish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 7),
          Stack(
            children: [
              TextField(
                controller: controller,
                minLines: 8,
                maxLines: 14,
                cursorColor: _ink,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: _muted, fontSize: 14),
                  filled: true,
                  fillColor: _soft,
                  contentPadding:
                      const EdgeInsets.fromLTRB(14, 13, 52, 52),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: _ink, fontSize: 15, height: 1.35),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: onPolish == null
                        ? const []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: IconButton(
                    tooltip: '润色提示词',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _ink,
                      disabledBackgroundColor: const Color(0xFFEAEAEA),
                      disabledForegroundColor: _muted,
                      fixedSize: const Size(38, 38),
                    ),
                    onPressed: polishing ? null : onPolish,
                    icon: polishing
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _ink,
                            ),
                          )
                        : const Icon(Icons.auto_fix_high_rounded, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModelPickerTile extends StatelessWidget {
  const _ModelPickerTile({
    required this.label,
    required this.value,
    required this.models,
    required this.onChanged,
    this.allowEmpty = true,
    this.emptyLabel = '不指定',
  });

  final String label;
  final String value;
  final List<AiModelConfig> models;
  final ValueChanged<String> onChanged;
  final bool allowEmpty;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final selected = models.where((model) => model.id == value);
    final title = selected.isEmpty ? emptyLabel : selected.first.displayName;
    final subtitle = selected.isEmpty
        ? '先到服务商设定里刷新并勾选模型'
        : '${selected.first.providerName} · ${_modelMeta(selected.first)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 7),
          Material(
            color: _soft,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => _showModelSheet(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _ink, fontSize: 15),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.expand_more_rounded, color: _muted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showModelSheet(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                if (allowEmpty)
                  ListTile(
                    title: Text(emptyLabel),
                    trailing: value.isEmpty ? const Icon(Icons.check_rounded) : null,
                    onTap: () => Navigator.pop(context, ''),
                  ),
                if (models.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      '还没有已添加模型。请先到服务商设定刷新并勾选模型。',
                      style: TextStyle(color: _muted),
                    ),
                  ),
                ...models.map(
                  (model) => ListTile(
                    title: Text(
                      model.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${model.providerName} · ${_modelMeta(model)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing:
                        value == model.id ? const Icon(Icons.check_rounded) : null,
                    onTap: () => Navigator.pop(context, model.id),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result != null) {
      onChanged(result);
    }
  }
}

class _StaticNotice extends StatelessWidget {
  const _StaticNotice({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: const TextStyle(color: _muted, fontSize: 13.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: _ink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

AppSettings copySettings(AppSettings source) {
  return AppSettings.fromJson(source.toJson());
}

bool _isJsonObject(String source) {
  final trimmed = source.trim();
  if (trimmed.isEmpty) {
    return true;
  }
  try {
    return jsonDecode(trimmed) is Map;
  } catch (_) {
    return false;
  }
}

double? _nullableDouble(String source) {
  final trimmed = source.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return double.tryParse(trimmed);
}

int? _nullableInt(String source) {
  final trimmed = source.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return int.tryParse(trimmed);
}

double _doubleOr(String source, double fallback) {
  return double.tryParse(source.trim()) ?? fallback;
}

int _intOr(String source, int fallback) {
  return int.tryParse(source.trim()) ?? fallback;
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
