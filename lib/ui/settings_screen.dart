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
                    title: 'API 与模型',
                    subtitle: store.settings.model.isEmpty
                        ? '配置自定义接口'
                        : store.settings.model,
                    icon: Icons.key_rounded,
                    onTap: () => _open(
                      context,
                      ApiSettingsPage(store: store),
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
  late final TextEditingController model;
  late final TextEditingController temperature;
  late final TextEditingController topP;
  late final TextEditingController maxTokens;

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    name = TextEditingController(text: preset.name);
    description = TextEditingController(text: preset.description);
    prompt = TextEditingController(text: preset.systemPrompt);
    model = TextEditingController(text: preset.modelOverride);
    temperature = TextEditingController(text: preset.temperature?.toString());
    topP = TextEditingController(text: preset.topP?.toString());
    maxTokens = TextEditingController(text: preset.maxTokens?.toString());
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    prompt.dispose();
    model.dispose();
    temperature.dispose();
    topP.dispose();
    maxTokens.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      _snack(context, '助手名称不能为空。');
      return;
    }
    final preset = widget.preset
      ..name = name.text.trim()
      ..description = description.text.trim()
      ..systemPrompt = prompt.text.trim()
      ..modelOverride = model.text.trim()
      ..temperature = _nullableDouble(temperature.text)
      ..topP = _nullableDouble(topP.text)
      ..maxTokens = _nullableInt(maxTokens.text);
    await widget.store.upsertAssistant(preset);
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
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
          _Field(
            label: '系统提示词',
            hint: '定义这个助手的角色、语气、边界和输出偏好',
            controller: prompt,
            minLines: 8,
            maxLines: 14,
          ),
          _Field(
            label: '模型覆盖',
            hint: '留空则使用默认模型',
            controller: model,
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
