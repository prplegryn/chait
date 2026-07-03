import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_store.dart';
import '../models.dart';

const _soft = Color(0xFFF7F7F7);

Color _surface(BuildContext context) => Theme.of(context).colorScheme.surface;
Color _background(BuildContext context) =>
    Theme.of(context).scaffoldBackgroundColor;
Color _textColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;
Color _mutedColor(BuildContext context) =>
    _textColor(context).withValues(alpha: 0.52);
Color _lineColor(BuildContext context) =>
    Theme.of(context).colorScheme.outline.withValues(alpha: 0.72);
Color _softColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.06)
        : _soft;
Color _shadowColor(BuildContext context, [double alpha = 0.08]) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: alpha + 0.12)
        : Colors.black.withValues(alpha: alpha);

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
                    subtitle: '服务商、密钥、模型',
                    icon: Icons.cloud_outlined,
                    onTap: () => _open(
                      context,
                      ProviderSettingsPage(store: store),
                    ),
                  ),
                  _SettingsTile(
                    title: '默认参数',
                    subtitle: '模型与生成参数',
                    icon: Icons.tune_rounded,
                    onTap: () => _open(
                      context,
                      DefaultParamsPage(store: store),
                    ),
                  ),
                  _SettingsTile(
                    title: '搜索服务',
                    subtitle: '搜索源和密钥',
                    icon: Icons.travel_explore_rounded,
                    onTap: () => _open(
                      context,
                      SearchSettingsPage(store: store),
                    ),
                  ),
                  _SettingsTile(
                    title: 'MCP 服务',
                    subtitle: '服务地址和权限',
                    icon: Icons.account_tree_outlined,
                    onTap: () => _open(
                      context,
                      McpSettingsPage(store: store),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    title: '外观',
                    subtitle: '主题、颜色、触感',
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

class ProviderSettingsPage extends StatefulWidget {
  const ProviderSettingsPage({super.key, required this.store});

  final AppStore store;

  @override
  State<ProviderSettingsPage> createState() => _ProviderSettingsPageState();
}

class _ProviderSettingsPageState extends State<ProviderSettingsPage> {
  String query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.refreshProviderBalances();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final providers = widget.store.settings.providers.where((provider) {
          final normalized = query.trim().toLowerCase();
          if (normalized.isEmpty) {
            return true;
          }
          return provider.name.toLowerCase().contains(normalized) ||
              provider.baseUrl.toLowerCase().contains(normalized);
        }).toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('服务商设定'),
            actions: [
              IconButton(
                tooltip: '添加服务商',
                icon: const Icon(Icons.add_rounded),
                onPressed: _showAddProvider,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _FloatingSearchField(
                hint: '搜索服务商',
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 14),
              if (providers.isEmpty)
                const _EmptyLine('没有匹配服务商'),
              ...providers.map((provider) {
                final enabledCount = widget.store.settings.models
                    .where(
                      (model) => model.providerId == provider.id && model.enabled,
                    )
                    .length;
                final summary = _providerSummary(provider, enabledCount);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SettingsCard(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      title: Text(
                        provider.name,
                        style: TextStyle(color: _textColor(context)),
                      ),
                      subtitle: summary.isEmpty
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                summary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _mutedColor(context),
                                  fontSize: 12,
                                  height: 1.2,
                                ),
                              ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: _mutedColor(context),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProviderDetailPage(
                            store: widget.store,
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

  Future<void> _showAddProvider() async {
    final existing = widget.store.settings.providers.map((item) => item.id).toSet();
    final presets = defaultProviders()
        .where((provider) => !existing.contains(provider.id))
        .toList();
    final actions = [
      ...presets.map(
        (provider) => _MenuChoice(
          icon: Icons.cloud_outlined,
          label: provider.name,
          subtitle: provider.baseUrl,
          value: provider.id,
        ),
      ),
      const _MenuChoice(
        icon: Icons.add_circle_outline_rounded,
        label: '自定义服务商',
        subtitle: '填写 OpenAI 兼容接口',
        value: '__custom__',
      ),
    ];
    final selected = await _showChoiceMenu(context, children: actions);
    if (!mounted || selected == null) {
      return;
    }
    final provider = selected == '__custom__'
        ? AiProviderConfig(
            id: newEntityId(),
            name: '自定义服务商',
            baseUrl: '',
            isCustom: true,
          )
        : AiProviderConfig.fromJson(
            defaultProviders()
                .firstWhere((item) => item.id == selected)
                .toJson(),
          );
    await widget.store.updateProvider(provider);
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderDetailPage(
          store: widget.store,
          providerId: provider.id,
        ),
      ),
    );
  }

  String _providerSummary(AiProviderConfig provider, int enabledCount) {
    final hasKey = widget.store.apiKeyForProvider(provider.id).trim().isNotEmpty;
    final balance = provider.balanceText.trim();
    final configured = hasKey ||
        enabledCount > 0 ||
        balance.isNotEmpty ||
        provider.updatedAt != null ||
        (provider.isCustom && provider.baseUrl.trim().isNotEmpty);
    if (!configured) {
      return '';
    }
    final parts = <String>['$enabledCount models'];
    if (balance.isNotEmpty) {
      parts.add(balance);
    }
    return parts.join(' · ');
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
  String testingModelId = '';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBalanceQuietly();
    });
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
    await _refreshBalanceQuietly();
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
      error = widget.store.friendlyError(err);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _refreshBalanceQuietly() async {
    if (provider.balancePath.trim().isEmpty ||
        apiKey.text.trim().isEmpty ||
        !mounted) {
      return;
    }
    try {
      await widget.store.refreshProviderBalance(provider.id);
    } catch (_) {
      return;
    }
  }

  Future<void> _testModel(AiModelConfig model) async {
    if (testingModelId.isNotEmpty) {
      return;
    }
    await _save();
    setState(() => testingModelId = model.id);
    try {
      final result = await widget.store.testModel(model.id);
      if (mounted) {
        _snack(context, result);
      }
    } catch (err) {
      if (mounted) {
        _snack(context, widget.store.friendlyError(err));
      }
    } finally {
      if (mounted) {
        setState(() => testingModelId = '');
      }
    }
  }

  Future<void> _delete() async {
    await widget.store.deleteProvider(provider.id);
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _reset() async {
    await widget.store.resetProvider(provider.id);
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
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
        final currentProvider = widget.store.providerById(provider.id);
        return _EditScaffold(
          title: provider.name,
          onSave: _save,
          actions: [
            if (isBuiltInProviderId(provider.id))
              IconButton(
                tooltip: '重置服务商',
                icon: const Icon(Icons.restart_alt_rounded),
                onPressed: _reset,
              )
            else if (widget.store.settings.providers.length > 1)
              IconButton(
                tooltip: '删除服务商',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _delete,
              ),
          ],
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
              if (currentProvider.balanceText.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '余额 ${currentProvider.balanceText}',
                      style: TextStyle(
                        color: _mutedColor(context),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ),
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
                        color: _textColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              if (models.isEmpty)
                const _EmptyLine('暂无模型')
              else
                ...models.map(
                  (model) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ModelMetadataTile(
                      model: model,
                      value: model.enabled,
                      onChanged: (value) =>
                          widget.store.setModelEnabled(model.id, value),
                      testing: testingModelId == model.id,
                      onTest: () => _testModel(model),
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
            activeThumbColor: _textColor(context),
            contentPadding: EdgeInsets.zero,
            title: const Text('流式输出'),
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

class SearchSettingsPage extends StatefulWidget {
  const SearchSettingsPage({super.key, required this.store});

  final AppStore store;

  @override
  State<SearchSettingsPage> createState() => _SearchSettingsPageState();
}

class _SearchSettingsPageState extends State<SearchSettingsPage> {
  String testingProviderId = '';

  Future<void> _setDefaultEnabled(bool value) async {
    final next = copySettings(widget.store.settings)
      ..searchEnabledByDefault = value;
    await widget.store.updateSettings(next, widget.store.apiKey);
  }

  Future<void> _setDefaultProvider(String id) async {
    final next = copySettings(widget.store.settings)
      ..defaultSearchProviderId = id;
    await widget.store.updateSettings(next, widget.store.apiKey);
  }

  Future<void> _testProvider(SearchProviderConfig provider) async {
    if (testingProviderId.isNotEmpty) {
      return;
    }
    setState(() => testingProviderId = provider.id);
    try {
      final result = await widget.store.testSearchProvider(provider.id);
      if (mounted) {
        _snack(context, result);
      }
    } catch (err) {
      if (mounted) {
        _snack(context, widget.store.friendlyError(err));
      }
    } finally {
      if (mounted) {
        setState(() => testingProviderId = '');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final providers = widget.store.settings.searchProviders;
        return Scaffold(
          appBar: AppBar(
            title: const Text('搜索服务'),
            actions: [
              IconButton(
                tooltip: '添加搜索服务',
                icon: const Icon(Icons.add_rounded),
                onPressed: _showAddSearchProvider,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              SwitchListTile(
                value: widget.store.settings.searchEnabledByDefault,
                activeThumbColor: _textColor(context),
                contentPadding: EdgeInsets.zero,
                title: const Text('新会话默认开启搜索'),
                onChanged: _setDefaultEnabled,
              ),
              const SizedBox(height: 10),
              if (providers.isEmpty)
                const _EmptyLine('暂无搜索服务'),
              ...providers.map(
                (provider) {
                  final selected =
                      widget.store.settings.defaultSearchProviderId ==
                          provider.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SettingsCard(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.travel_explore_rounded,
                          color: selected
                              ? _textColor(context)
                              : _mutedColor(context),
                        ),
                        title: Text(
                          provider.name,
                          style: TextStyle(color: _textColor(context)),
                        ),
                        subtitle: Text(
                          _searchProviderState(widget.store, provider),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _mutedColor(context),
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '测试',
                              icon: testingProviderId == provider.id
                                  ? SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _mutedColor(context),
                                      ),
                                    )
                                  : Icon(
                                      Icons.bolt_outlined,
                                      color: _mutedColor(context),
                                    ),
                              onPressed: testingProviderId.isNotEmpty
                                  ? null
                                  : () => _testProvider(provider),
                            ),
                            IconButton(
                              tooltip: '设为默认',
                              icon: Icon(
                                Icons.radio_button_checked_rounded,
                                color: selected
                                    ? _mutedColor(context)
                                    : _textColor(context),
                              ),
                              onPressed: selected
                                  ? null
                                  : () => _setDefaultProvider(provider.id),
                            ),
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SearchProviderDetailPage(
                              store: widget.store,
                              providerId: provider.id,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddSearchProvider() async {
    final existing =
        widget.store.settings.searchProviders.map((item) => item.id).toSet();
    final presets = defaultSearchProviders()
        .where((provider) => !existing.contains(provider.id))
        .toList();
    final selected = await _showChoiceMenu(
      context,
      children: [
        ...presets.map(
          (provider) => _MenuChoice(
            icon: Icons.travel_explore_rounded,
            label: provider.name,
            subtitle: provider.kind,
            value: provider.id,
          ),
        ),
        const _MenuChoice(
          icon: Icons.add_circle_outline_rounded,
          label: '自定义搜索',
          subtitle: 'POST query/max_results',
          value: '__custom__',
        ),
      ],
    );
    if (!mounted || selected == null) {
      return;
    }
    final provider = selected == '__custom__'
        ? SearchProviderConfig(
            id: newEntityId(),
            name: '自定义搜索',
            kind: 'custom',
            baseUrl: '',
          )
        : SearchProviderConfig.fromJson(
            defaultSearchProviders()
                .firstWhere((item) => item.id == selected)
                .toJson(),
          );
    await widget.store.updateSearchProvider(provider);
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchProviderDetailPage(
          store: widget.store,
          providerId: provider.id,
        ),
      ),
    );
  }
}

class SearchProviderDetailPage extends StatefulWidget {
  const SearchProviderDetailPage({
    super.key,
    required this.store,
    required this.providerId,
  });

  final AppStore store;
  final String providerId;

  @override
  State<SearchProviderDetailPage> createState() =>
      _SearchProviderDetailPageState();
}

class _SearchProviderDetailPageState extends State<SearchProviderDetailPage> {
  late SearchProviderConfig provider;
  late final TextEditingController name;
  late final TextEditingController kind;
  late final TextEditingController baseUrl;
  late final TextEditingController apiKey;
  late final TextEditingController maxResults;
  late final TextEditingController headers;
  late final TextEditingController extraBody;
  late bool enabled;
  bool testing = false;

  @override
  void initState() {
    super.initState();
    provider = SearchProviderConfig.fromJson(
      widget.store.searchProviderById(widget.providerId).toJson(),
    );
    name = TextEditingController(text: provider.name);
    kind = TextEditingController(text: provider.kind);
    baseUrl = TextEditingController(text: provider.baseUrl);
    apiKey = TextEditingController(
      text: widget.store.apiKeyForSearchProvider(provider.id),
    );
    maxResults = TextEditingController(text: provider.maxResults.toString());
    headers = TextEditingController(text: provider.customHeadersJson);
    extraBody = TextEditingController(text: provider.extraBodyJson);
    enabled = provider.enabled;
  }

  @override
  void dispose() {
    name.dispose();
    kind.dispose();
    baseUrl.dispose();
    apiKey.dispose();
    maxResults.dispose();
    headers.dispose();
    extraBody.dispose();
    super.dispose();
  }

  Future<bool> _persist({bool showSnack = true}) async {
    if (!_isJsonObject(headers.text) || !_isJsonObject(extraBody.text)) {
      _snack(context, '请求头和扩展请求体必须是 JSON 对象。');
      return false;
    }
    final normalizedKind =
        kind.text.trim().isEmpty ? 'custom' : kind.text.trim().toLowerCase();
    if (enabled && normalizedKind != 'custom' && apiKey.text.trim().isEmpty) {
      _snack(context, '请先填写 API Key。');
      return false;
    }
    provider
      ..name = name.text.trim()
      ..kind = normalizedKind
      ..baseUrl = baseUrl.text.trim()
      ..enabled = enabled
      ..maxResults = _intOr(maxResults.text, 5).clamp(1, 10).toInt()
      ..customHeadersJson = headers.text.trim().isEmpty ? '{}' : headers.text
      ..extraBodyJson = extraBody.text.trim().isEmpty ? '{}' : extraBody.text
      ..updatedAt = DateTime.now();
    await widget.store.updateSearchProvider(
      provider,
      apiKey: apiKey.text.trim(),
    );
    if (!mounted) {
      return true;
    }
    if (showSnack) {
      _snack(context, '已保存');
    }
    return true;
  }

  Future<void> _save() async {
    await _persist();
  }

  Future<void> _delete() async {
    await widget.store.deleteSearchProvider(provider.id);
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _test() async {
    if (testing) {
      return;
    }
    final saved = await _persist(showSnack: false);
    if (!saved || !mounted) {
      return;
    }
    setState(() => testing = true);
    try {
      final result = await widget.store.testSearchProvider(provider.id);
      if (mounted) {
        _snack(context, result);
      }
    } catch (err) {
      if (mounted) {
        _snack(context, widget.store.friendlyError(err));
      }
    } finally {
      if (mounted) {
        setState(() => testing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditScaffold(
      title: provider.name,
      onSave: _save,
      actions: [
        IconButton(
          tooltip: '测试',
          icon: testing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.bolt_outlined),
          onPressed: testing ? null : _test,
        ),
        IconButton(
          tooltip: '删除搜索服务',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: _delete,
        ),
      ],
      child: Column(
        children: [
          SwitchListTile(
            value: enabled,
            activeThumbColor: _textColor(context),
            contentPadding: EdgeInsets.zero,
            title: const Text('启用'),
            onChanged: (value) => setState(() => enabled = value),
          ),
          _Field(label: '名称', hint: 'Tavily', controller: name),
          _Field(
            label: '类型',
            hint: 'tavily / exa / brave / linkup / custom',
            controller: kind,
          ),
          _Field(
            label: 'Base URL',
            hint: 'https://api.tavily.com',
            controller: baseUrl,
            keyboardType: TextInputType.url,
          ),
          _Field(
            label: 'API Key',
            hint: '搜索服务密钥',
            controller: apiKey,
            obscureText: true,
          ),
          _Field(
            label: '最大结果数',
            hint: '5',
            controller: maxResults,
            keyboardType: TextInputType.number,
          ),
          _Field(
            label: '自定义请求头 JSON',
            hint: '{"X-Header":"value"}',
            controller: headers,
            minLines: 4,
            maxLines: 8,
          ),
          _Field(
            label: '扩展请求体 JSON',
            hint: '{"search_depth":"advanced"}',
            controller: extraBody,
            minLines: 4,
            maxLines: 8,
          ),
        ],
      ),
    );
  }
}

class McpSettingsPage extends StatelessWidget {
  const McpSettingsPage({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('MCP 服务'),
            actions: [
              IconButton(
                tooltip: '添加 MCP 服务',
                icon: const Icon(Icons.add_rounded),
                onPressed: () async {
                  final server = McpServerConfig(
                    id: newEntityId(),
                    name: 'MCP 服务',
                    url: '',
                  );
                  await store.updateMcpServer(server);
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => McpServerDetailPage(
                        store: store,
                        serverId: server.id,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              if (store.settings.mcpServers.isEmpty)
                const _EmptyLine('暂无 MCP 服务'),
              ...store.settings.mcpServers.map(
                (server) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SettingsCard(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      leading: Icon(
                        server.enabled
                            ? Icons.account_tree_rounded
                            : Icons.account_tree_outlined,
                        color: server.enabled
                            ? _textColor(context)
                            : _mutedColor(context),
                      ),
                      title: Text(
                        server.name,
                        style: TextStyle(color: _textColor(context)),
                      ),
                      subtitle: Text(
                        '${server.transport} · ${server.url}',
                        style: TextStyle(color: _mutedColor(context)),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: _mutedColor(context),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => McpServerDetailPage(
                            store: store,
                            serverId: server.id,
                          ),
                        ),
                      ),
                    ),
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

class McpServerDetailPage extends StatefulWidget {
  const McpServerDetailPage({
    super.key,
    required this.store,
    required this.serverId,
  });

  final AppStore store;
  final String serverId;

  @override
  State<McpServerDetailPage> createState() => _McpServerDetailPageState();
}

class _McpServerDetailPageState extends State<McpServerDetailPage> {
  late McpServerConfig server;
  late final TextEditingController name;
  late final TextEditingController url;
  late final TextEditingController transport;
  late final TextEditingController headers;
  late final TextEditingController notes;
  late bool enabled;
  bool testing = false;

  @override
  void initState() {
    super.initState();
    server = McpServerConfig.fromJson(
      widget.store.settings.mcpServers
          .firstWhere((item) => item.id == widget.serverId)
          .toJson(),
    );
    name = TextEditingController(text: server.name);
    url = TextEditingController(text: server.url);
    transport = TextEditingController(text: server.transport);
    headers = TextEditingController(text: server.customHeadersJson);
    notes = TextEditingController(text: server.notes);
    enabled = server.enabled;
  }

  @override
  void dispose() {
    name.dispose();
    url.dispose();
    transport.dispose();
    headers.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<bool> _persist({bool showSnack = true}) async {
    if (!_isJsonObject(headers.text)) {
      _snack(context, '自定义请求头必须是 JSON 对象。');
      return false;
    }
    server
      ..name = name.text.trim().isEmpty ? 'MCP 服务' : name.text.trim()
      ..url = url.text.trim()
      ..transport = transport.text.trim().isEmpty
          ? 'streamable_http'
          : transport.text.trim()
      ..enabled = enabled
      ..customHeadersJson = headers.text.trim().isEmpty ? '{}' : headers.text
      ..notes = notes.text.trim()
      ..updatedAt = DateTime.now();
    await widget.store.updateMcpServer(server);
    if (!mounted) {
      return true;
    }
    if (showSnack) {
      _snack(context, '已保存');
    }
    return true;
  }

  Future<void> _save() async {
    await _persist();
  }

  Future<void> _delete() async {
    await widget.store.deleteMcpServer(server.id);
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _test() async {
    if (testing) {
      return;
    }
    final saved = await _persist(showSnack: false);
    if (!saved || !mounted) {
      return;
    }
    setState(() => testing = true);
    try {
      final result = await widget.store.testMcpServer(server.id);
      if (mounted) {
        _snack(context, result);
      }
    } catch (err) {
      if (mounted) {
        _snack(context, widget.store.friendlyError(err));
      }
    } finally {
      if (mounted) {
        setState(() => testing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditScaffold(
      title: server.name,
      onSave: _save,
      actions: [
        IconButton(
          tooltip: '测试',
          icon: testing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.bolt_outlined),
          onPressed: testing ? null : _test,
        ),
        IconButton(
          tooltip: '删除 MCP 服务',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: _delete,
        ),
      ],
      child: Column(
        children: [
          SwitchListTile(
            value: enabled,
            activeThumbColor: _textColor(context),
            contentPadding: EdgeInsets.zero,
            title: const Text('启用'),
            onChanged: (value) => setState(() => enabled = value),
          ),
          _Field(label: '名称', hint: 'Browser MCP', controller: name),
          _Field(
            label: '服务地址',
            hint: 'https://example.com/mcp',
            controller: url,
            keyboardType: TextInputType.url,
          ),
          _Field(
            label: '传输方式',
            hint: 'streamable_http / sse',
            controller: transport,
          ),
          _Field(
            label: '自定义请求头 JSON',
            hint: '{"Authorization":"Bearer ..."}',
            controller: headers,
            minLines: 4,
            maxLines: 8,
          ),
          _Field(
            label: '备注',
            hint: '用途、工具范围、权限说明',
            controller: notes,
            minLines: 3,
            maxLines: 6,
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
        _snack(context, widget.store.friendlyError(error));
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
  late String appearanceMode;
  late int themeColorValue;

  @override
  void initState() {
    super.initState();
    final settings = widget.store.settings;
    haptics = settings.haptics;
    appearanceMode = settings.appearanceMode;
    themeColorValue = settings.themeColorValue;
  }

  Future<void> _save() async {
    final next = copySettings(widget.store.settings)
      ..appearanceMode = appearanceMode
      ..themeColorValue = themeColorValue
      ..haptics = haptics;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingLabel('模式'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AppearancePill(
                label: '浅色',
                selected: appearanceMode == 'light',
                onTap: () => setState(() => appearanceMode = 'light'),
              ),
              _AppearancePill(
                label: '深色',
                selected: appearanceMode == 'dark',
                onTap: () => setState(() => appearanceMode = 'dark'),
              ),
              _AppearancePill(
                label: 'OLED',
                selected: appearanceMode == 'oled',
                onTap: () => setState(() => appearanceMode = 'oled'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingLabel('气泡颜色'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _themeColorPresets
                .map(
                  (preset) => _ThemeColorChoice(
                    label: preset.label,
                    color: Color(preset.value),
                    selected: themeColorValue == preset.value,
                    onTap: () => setState(() => themeColorValue = preset.value),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            value: haptics,
            activeThumbColor: _textColor(context),
            contentPadding: EdgeInsets.zero,
            title: const Text('触感反馈'),
            onChanged: (value) => setState(() => haptics = value),
          ),
        ],
      ),
    );
  }
}

class _ThemeColorPreset {
  const _ThemeColorPreset(this.label, this.value);

  final String label;
  final int value;
}

const _themeColorPresets = [
  _ThemeColorPreset('石墨', 0xFFE9E9E9),
  _ThemeColorPreset('云蓝', 0xFFDCEBFF),
  _ThemeColorPreset('松绿', 0xFFDDF4E7),
  _ThemeColorPreset('雾紫', 0xFFE9E2FF),
  _ThemeColorPreset('玫瑰', 0xFFFFE1EA),
  _ThemeColorPreset('琥珀', 0xFFFFEDC7),
  _ThemeColorPreset('青瓷', 0xFFDDF7F4),
  _ThemeColorPreset('雾灰', 0xFFE4E7EC),
];

class _AppearancePill extends StatelessWidget {
  const _AppearancePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _textColor(context) : _softColor(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _background(context) : _textColor(context),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeColorChoice extends StatelessWidget {
  const _ThemeColorChoice({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 76,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _textColor(context) : _lineColor(context),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _shadowColor(context, 0.08),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _textColor(context),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
            activeThumbColor: _textColor(context),
            contentPadding: EdgeInsets.zero,
            title: const Text('导出时包含 API Key'),
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

class _FloatingSearchField extends StatelessWidget {
  const _FloatingSearchField({
    required this.hint,
    required this.onChanged,
  });

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _shadowColor(context, 0.08),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        cursorColor: _textColor(context),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _mutedColor(context), fontSize: 14),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: _mutedColor(context),
            size: 20,
          ),
          isDense: true,
          filled: true,
          fillColor: _surface(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
        style: TextStyle(
          color: _textColor(context),
          fontSize: 14.5,
          height: 1.25,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MenuChoice extends StatelessWidget {
  const _MenuChoice({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle = '',
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _textColor(context)),
      title: Text(label, style: TextStyle(color: _textColor(context))),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, style: TextStyle(color: _mutedColor(context))),
      onTap: () => Navigator.pop(context, value),
    );
  }
}

Future<String?> _showChoiceMenu(
  BuildContext context, {
  required List<_MenuChoice> children,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.08),
    transitionDuration: const Duration(milliseconds: 170),
    pageBuilder: (context, _, __) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.sizeOf(context).width * 0.78,
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              color: _surface(context),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _shadowColor(context, 0.14),
                  blurRadius: 34,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: children,
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: curved, child: child),
      );
    },
  );
}

class _EditScaffold extends StatelessWidget {
  const _EditScaffold({
    required this.title,
    required this.onSave,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Future<void> Function() onSave;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...actions,
          TextButton(
            onPressed: onSave,
            child: Text(
              '保存',
              style: TextStyle(
                color: _textColor(context),
                fontWeight: FontWeight.w600,
              ),
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
        color: _surface(context),
        border: Border.all(color: _lineColor(context)),
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
        color: _surface(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _shadowColor(context, 0.06),
            blurRadius: 18,
            spreadRadius: 1,
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
    required this.testing,
    required this.onTest,
  });

  final AiModelConfig model;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool testing;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
        child: Row(
          children: [
            Checkbox(
              value: value,
              fillColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? _textColor(context)
                    : null,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              onChanged: (next) => onChanged(next ?? false),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textColor(context)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _modelMeta(model),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _mutedColor(context),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '测试',
              visualDensity: VisualDensity.compact,
              onPressed: testing ? null : onTest,
              icon: testing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _mutedColor(context),
                      ),
                    )
                  : Icon(
                      Icons.bolt_outlined,
                      color: _mutedColor(context),
                      size: 20,
                    ),
            ),
          ],
        ),
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

String _searchProviderState(AppStore store, SearchProviderConfig provider) {
  final key = store.apiKeyForSearchProvider(provider.id).trim();
  final kind = provider.kind.trim().toLowerCase();
  if (kind != 'custom' && key.isEmpty) {
    return '未配置';
  }
  return provider.enabled ? '已启用' : '已停用';
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
      leading: Icon(icon, color: _textColor(context)),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _textColor(context),
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _mutedColor(context),
          fontSize: 11.5,
          height: 1.2,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: _mutedColor(context)),
      onTap: onTap,
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Text(
        text,
        style: TextStyle(
          color: _mutedColor(context),
          fontSize: 12.5,
          height: 1.3,
        ),
      ),
    );
  }
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: _mutedColor(context),
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
      ),
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
            style: TextStyle(
              color: _mutedColor(context),
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
            cursorColor: _textColor(context),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _mutedColor(context), fontSize: 14),
              filled: true,
              fillColor: _softColor(context),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
            style: TextStyle(
              color: _textColor(context),
              fontSize: 15,
              height: 1.35,
            ),
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
            style: TextStyle(
              color: _mutedColor(context),
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
                cursorColor: _textColor(context),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: _mutedColor(context),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: _softColor(context),
                  contentPadding:
                      const EdgeInsets.fromLTRB(14, 13, 52, 52),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(
                  color: _textColor(context),
                  fontSize: 15,
                  height: 1.35,
                ),
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
                              spreadRadius: 1,
                            ),
                          ],
                  ),
                  child: IconButton(
                    tooltip: '润色提示词',
                    style: IconButton.styleFrom(
                      backgroundColor: _surface(context),
                      foregroundColor: _textColor(context),
                      disabledBackgroundColor: _softColor(context),
                      disabledForegroundColor: _mutedColor(context),
                      fixedSize: const Size(38, 38),
                    ),
                    onPressed: polishing ? null : onPolish,
                    icon: polishing
                        ? SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _textColor(context),
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
        ? '未选择'
        : _compactModelMeta(selected.first);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _mutedColor(context),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 7),
          Material(
            color: _softColor(context),
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
                            style: TextStyle(
                              color: _textColor(context),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _mutedColor(context),
                              fontSize: 11.5,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.expand_more_rounded,
                      color: _mutedColor(context),
                    ),
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
            color: _surface(context),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _shadowColor(context, 0.12),
                blurRadius: 30,
                spreadRadius: 1,
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 10),
              children: [
                if (allowEmpty)
                  ListTile(
                    title: Text(emptyLabel),
                    trailing: value.isEmpty ? const Icon(Icons.check_rounded) : null,
                    onTap: () => Navigator.pop(context, ''),
                  ),
                if (models.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      '暂无可选模型',
                      style: TextStyle(color: _mutedColor(context)),
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
                      style: TextStyle(color: _mutedColor(context)),
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

String _compactModelMeta(AiModelConfig model) {
  return [
    model.providerName,
    if (model.contextWindow != null) '上下文 ${model.contextWindow}',
    if (model.supportsTools == true) '工具',
    if (model.supportsVision == true) '视觉',
  ].join(' · ');
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
        color: _softColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _textColor(context),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: TextStyle(
              color: _mutedColor(context),
              fontSize: 13.5,
              height: 1.4,
            ),
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
          backgroundColor: _textColor(context),
          foregroundColor: _background(context),
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
