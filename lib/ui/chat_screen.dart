import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_logger.dart';
import '../app_store.dart';
import '../models.dart';
import 'message_renderer.dart';
import 'settings_screen.dart';

const _ink = Color(0xFF111111);
const _soft = Color(0xFFF7F7F7);

Color _surface(BuildContext context) => Theme.of(context).colorScheme.surface;
Color _background(BuildContext context) =>
    Theme.of(context).scaffoldBackgroundColor;
Color _textColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;
Color _mutedColor(BuildContext context) =>
    _textColor(context).withValues(alpha: 0.52);
Color _softColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.06)
        : _soft;
Color _shadowColor(BuildContext context, [double alpha = 0.12]) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: alpha + 0.12)
        : Colors.black.withValues(alpha: alpha);
Color _userBubbleColor(BuildContext context) =>
    Theme.of(context).colorScheme.primary;
Color _onUserBubbleColor(BuildContext context) {
  final color = _userBubbleColor(context);
  return color.computeLuminance() > 0.54 ? _ink : Colors.white;
}

String _fmtSize(Size value) {
  return '${value.width.toStringAsFixed(1)}x${value.height.toStringAsFixed(1)}';
}

String _fmtOffset(Offset value) {
  return '${value.dx.toStringAsFixed(1)},${value.dy.toStringAsFixed(1)}';
}

String _fmtInsets(EdgeInsets value) {
  return '${value.left.toStringAsFixed(1)},'
      '${value.top.toStringAsFixed(1)},'
      '${value.right.toStringAsFixed(1)},'
      '${value.bottom.toStringAsFixed(1)}';
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _topBarKey = GlobalKey(debugLabel: 'topBar');
  final _composerKey = GlobalKey(debugLabel: 'composer');
  final _textFieldKey = GlobalKey(debugLabel: 'textField');
  final _emptyChatKey = GlobalKey(debugLabel: 'emptyChat');
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _stickToBottom = true;
  bool _forceNextScroll = false;
  String _lastSessionId = '';

  @override
  void initState() {
    super.initState();
    AppLogger.instance.event('chat.ui', {
      'event': 'init',
      'session': widget.store.currentSessionId,
      'messages': widget.store.currentSession.messages.length,
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logSurfaceState('firstFrame');
    });
    widget.store.addListener(_onStoreChanged);
    _scrollController.addListener(_onScroll);
    _lastSessionId = widget.store.currentSessionId;
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    _scrollController.removeListener(_onScroll);
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) {
      return;
    }
    final sessionChanged = widget.store.currentSessionId != _lastSessionId;
    if (sessionChanged) {
      _lastSessionId = widget.store.currentSessionId;
      _forceNextScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _logSurfaceState('sessionChanged');
        }
      });
    }
    final shouldScroll = _forceNextScroll || _stickToBottom;
    setState(() {});
    if (shouldScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToEnd(jump: sessionChanged);
        _forceNextScroll = false;
      });
    }
  }

  void _onScroll() {
    _stickToBottom = _isNearBottom();
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 90;
  }

  void _scrollToEnd({bool jump = false}) {
    if (!_scrollController.hasClients) {
      return;
    }
    if (jump) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _logSurfaceState(String phase) {
    if (!mounted) {
      return;
    }
    final media = MediaQuery.of(context);
    AppLogger.instance.event('surface', {
      'phase': phase,
      'size': _fmtSize(media.size),
      'padding': _fmtInsets(media.padding),
      'viewInsets': _fmtInsets(media.viewInsets),
      'textScale': media.textScaler.scale(1).toStringAsFixed(2),
      'focus': _focusNode.hasFocus,
      'keyboard': media.viewInsets.bottom > 0,
      'messages': widget.store.currentSession.messages.length,
    });
    _logBox('topBar', _topBarKey);
    _logBox('composer', _composerKey);
    _logBox('textField', _textFieldKey);
    _logBox('emptyChat', _emptyChatKey);
  }

  void _logBox(String name, GlobalKey key) {
    final keyContext = key.currentContext;
    if (keyContext == null) {
      AppLogger.instance.info('surface', '$name missing');
      return;
    }
    final render = keyContext.findRenderObject();
    if (render is! RenderBox || !render.hasSize) {
      AppLogger.instance.info('surface', '$name no-size');
      return;
    }
    final offset = render.localToGlobal(Offset.zero);
    AppLogger.instance.event('surface', {
      'box': name,
      'offset': _fmtOffset(offset),
      'size': _fmtSize(render.size),
    });
  }

  Future<void> _send() async {
    final text = _inputController.text;
    if (text.trim().isEmpty) {
      return;
    }
    _inputController.clear();
    _forceNextScroll = true;
    _stickToBottom = true;
    _focusNode.requestFocus();
    await widget.store.sendMessage(text);
  }

  void _openCurrentSessionModel() {
    showModelChoiceSheet(
      context: context,
      title: '当前会话模型',
      value: widget.store.currentSession.modelId,
      models: widget.store.enabledModels,
      emptyLabel: '跟随助手或全局默认',
      onChanged: widget.store.setSessionModel,
    );
  }

  Future<void> _renameCurrentSession() async {
    await _showRenameSessionDialog(
      context: context,
      store: widget.store,
      session: widget.store.currentSession,
    );
  }

  Future<void> _openComposerMenu(Offset anchor) async {
    final searchEnabled =
        widget.store.isSearchEnabledForSession(widget.store.currentSession);
    final selected = await _showContextMenu(
      context,
      anchor: anchor,
      children: [
        const _MenuAction(
          icon: Icons.memory_rounded,
          label: '当前会话模型',
          value: 'model',
        ),
        _MenuAction(
          icon: searchEnabled
              ? Icons.travel_explore_rounded
              : Icons.public_off_rounded,
          label: searchEnabled ? '关闭搜索' : '开启搜索',
          value: 'search',
        ),
      ],
    );
    if (!mounted || selected == null) {
      return;
    }
    if (selected == 'model') {
      _openCurrentSessionModel();
    } else if (selected == 'search') {
      if (!searchEnabled && !_searchReady()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先配置搜索服务')),
        );
        return;
      }
      widget.store.setSessionSearchEnabled(!searchEnabled);
    }
  }

  void _copyMessageText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制')),
    );
  }

  void _editUserMessage(String text) {
    _inputController.text = text;
    _inputController.selection = TextSelection.collapsed(offset: text.length);
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logSurfaceState('editMessage');
    });
  }

  bool _searchReady() {
    final id = widget.store.settings.defaultSearchProviderId;
    if (id.isEmpty) {
      return false;
    }
    try {
      final provider = widget.store.searchProviderById(id);
      if (!provider.enabled || provider.baseUrl.trim().isEmpty) {
        return false;
      }
      return !searchProviderNeedsApiKey(provider.kind) ||
          widget.store.apiKeyForSearchProvider(provider.id).trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.store.currentSession;
    final assistant = widget.store.currentAssistant;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _background(context),
      drawerScrimColor: Colors.black.withValues(alpha: 0.08),
      drawer: ChaitDrawer(store: widget.store),
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _AssistantWallpaper(assistant: assistant),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: session.messages.isEmpty
                      ? Padding(
                          padding: EdgeInsets.only(
                            top: MediaQuery.paddingOf(context).top + 116,
                          ),
                          child: _EmptyChat(key: _emptyChatKey),
                        )
                      : NotificationListener<UserScrollNotification>(
                          onNotification: (notification) {
                            if (widget.store.isSending &&
                                notification.direction.name != 'idle') {
                              _stickToBottom = _isNearBottom();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollController,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              20,
                              MediaQuery.paddingOf(context).top + 130,
                              20,
                              118,
                            ),
                            itemCount: session.messages.length,
                            itemBuilder: (context, index) {
                              return MessageBubble(
                                key: ValueKey(session.messages[index].id),
                                message: session.messages[index],
                                codeThemeId: widget.store.settings.codeThemeId,
                                codeBackgroundValue:
                                    widget.store.settings.codeBackgroundValue,
                                onRegenerate: widget.store.regenerateLastAnswer,
                                onCopy: _copyMessageText,
                                onEditUserMessage: _editUserMessage,
                              );
                            },
                          ),
                        ),
                ),
              ),
            ),
            const _BottomChatFade(),
            _ImmersiveTopBar(
              key: _topBarKey,
              assistant: assistant,
              sessionTitle: session.title,
              showSessionTitle: widget.store.settings.showSessionTitle,
              showNewChat: session.messages.isNotEmpty,
              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              onNewChat: () => widget.store.createSession(),
              onRenameTitle: _renameCurrentSession,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Composer(
                key: _composerKey,
                controller: _inputController,
                focusNode: _focusNode,
                textFieldKey: _textFieldKey,
                onSurfaceProbe: () => _logSurfaceState('composerProbe'),
                isSending: widget.store.isSending,
                onSend: _send,
                onStop: widget.store.stopGeneration,
                onOpenMenu: _openComposerMenu,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showRenameSessionDialog({
  required BuildContext context,
  required AppStore store,
  required ChatSession session,
}) async {
  final controller = TextEditingController(text: session.title);
  final action = await showDialog<String>(
    context: context,
    builder: (context) => _ChatSoftDialog(
      title: '会话标题',
      child: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 24,
        cursorColor: _textColor(context),
        decoration: InputDecoration(
          counterText: '',
          hintText: '输入自定义标题',
          filled: true,
          fillColor: _softColor(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        ),
      ),
      actions: [
        _ChatDialogAction(
          label: '恢复自动',
          onPressed: () => Navigator.pop(context, 'auto'),
        ),
        _ChatDialogAction(
          label: '取消',
          onPressed: () => Navigator.pop(context),
        ),
        _ChatDialogAction(
          label: '保存',
          filled: true,
          onPressed: () => Navigator.pop(context, 'save'),
        ),
      ],
    ),
  );
  final title = controller.text;
  controller.dispose();
  if (action == 'save') {
    await store.renameSession(session.id, title);
  } else if (action == 'auto') {
    await store.restoreAutoTitle(session.id);
  }
}

class _AssistantWallpaper extends StatelessWidget {
  const _AssistantWallpaper({required this.assistant});

  final AssistantPreset assistant;

  @override
  Widget build(BuildContext context) {
    final path = assistant.wallpaperImagePath.trim();
    if (path.isEmpty || !File(path).existsSync()) {
      return const Positioned.fill(child: SizedBox.shrink());
    }
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(path), fit: BoxFit.cover),
          ColoredBox(color: _background(context).withValues(alpha: 0.82)),
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: const ColoredBox(color: Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class _ImmersiveTopBar extends StatelessWidget {
  const _ImmersiveTopBar({
    super.key,
    required this.assistant,
    required this.sessionTitle,
    required this.showSessionTitle,
    required this.showNewChat,
    required this.onOpenDrawer,
    required this.onNewChat,
    required this.onRenameTitle,
  });

  final AssistantPreset assistant;
  final String sessionTitle;
  final bool showSessionTitle;
  final bool showNewChat;
  final VoidCallback onOpenDrawer;
  final VoidCallback onNewChat;
  final VoidCallback onRenameTitle;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final contentTop = top + 2;
    final bg = _background(context);
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SizedBox(
        height: top + 132,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black,
                        Colors.black,
                        Color(0xE0000000),
                        Color(0x7A000000),
                        Color(0x00000000),
                      ],
                      stops: [0, 0.46, 0.72, 0.90, 1],
                    ).createShader(bounds);
                  },
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: const ColoredBox(color: Colors.transparent),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bg,
                      bg.withValues(alpha: 0.99),
                      bg.withValues(alpha: 0.94),
                      bg.withValues(alpha: 0.90),
                      bg.withValues(alpha: 0.66),
                      bg.withValues(alpha: 0.28),
                      bg.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.34, 0.50, 0.65, 0.82, 0.94, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: contentTop),
              child: SizedBox(
                height: 50,
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    _RoundShadowButton(
                      tooltip: '打开侧边栏',
                      icon: Icons.menu_rounded,
                      compact: true,
                      onPressed: onOpenDrawer,
                    ),
                    Expanded(
                      child: _ChatTitle(
                        assistant: assistant,
                        sessionTitle: sessionTitle,
                        showSessionTitle: showSessionTitle,
                        onLongPress: onRenameTitle,
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: showNewChat ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: IgnorePointer(
                        ignoring: !showNewChat,
                        child: _RoundShadowButton(
                          tooltip: '新对话',
                          icon: Icons.add_comment_outlined,
                          compact: true,
                          onPressed: onNewChat,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTitle extends StatelessWidget {
  const _ChatTitle({
    required this.assistant,
    required this.sessionTitle,
    required this.showSessionTitle,
    required this.onLongPress,
  });

  final AssistantPreset assistant;
  final String sessionTitle;
  final bool showSessionTitle;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 220.0;
        final textWidth = maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: onLongPress,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: textWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    assistant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textColor(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      letterSpacing: 0,
                    ),
                  ),
                  if (showSessionTitle) ...[
                    const SizedBox(height: 3),
                    Text(
                      sessionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _mutedColor(context),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                        height: 1.1,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _background(context),
            _softColor(context).withValues(alpha: 0.18),
            _background(context),
          ],
          stops: const [0, 0.58, 1],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _BottomChatFade extends StatelessWidget {
  const _BottomChatFade();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: bottom + 118,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _background(context).withValues(alpha: 0),
                _background(context).withValues(alpha: 0.34),
                _background(context).withValues(alpha: 0.92),
              ],
              stops: const [0, 0.58, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatSoftDialog extends StatelessWidget {
  const _ChatSoftDialog({
    required this.title,
    required this.child,
    required this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _shadowColor(context, 0.18),
              blurRadius: 34,
              spreadRadius: 1,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: _textColor(context),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            child,
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatDialogAction extends StatelessWidget {
  const _ChatDialogAction({
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: filled ? _textColor(context) : _softColor(context),
        foregroundColor: filled ? _background(context) : _textColor(context),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.codeThemeId,
    required this.codeBackgroundValue,
    required this.onRegenerate,
    required this.onCopy,
    required this.onEditUserMessage,
  });

  final ChatMessage message;
  final String codeThemeId;
  final int codeBackgroundValue;
  final VoidCallback onRegenerate;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onEditUserMessage;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final waiting =
        !isUser && message.isStreaming && message.content.trim().isEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: isUser ? 22 : 20),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (isUser)
            LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.82,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPressStart: (details) {
                        final render = context.findRenderObject() as RenderBox?;
                        _showMessageMenu(
                          context,
                          anchor: details.globalPosition,
                          selectionIndex: _estimateSelectionIndex(
                            message.content,
                            details.localPosition,
                            render?.size,
                          ),
                        );
                      },
                      child: _UserBubbleFrame(
                        child: _MessageContent(
                          message: message,
                          codeThemeId: codeThemeId,
                          codeBackgroundValue: codeBackgroundValue,
                        ),
                      ),
                    ),
                  ),
                );
              },
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: SizedBox(
                width: double.infinity,
                child: waiting
                    ? _GenerationStatusText(
                        text: message.status.trim().isEmpty
                            ? '...'
                            : message.status.trim(),
                      )
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPressStart: (details) {
                          final render =
                              context.findRenderObject() as RenderBox?;
                          _showMessageMenu(
                            context,
                            anchor: details.globalPosition,
                            selectionIndex: _estimateSelectionIndex(
                              message.content,
                              details.localPosition,
                              render?.size,
                            ),
                          );
                        },
                        child: _MessageContent(
                          message: message,
                          codeThemeId: codeThemeId,
                          codeBackgroundValue: codeBackgroundValue,
                        ),
                      ),
              ),
            ),
          if (!isUser && message.content.trim().isNotEmpty && !message.isStreaming)
            Padding(
              padding: const EdgeInsets.only(left: 0, top: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TinyAction(
                    tooltip: '复制',
                    icon: Icons.copy_rounded,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制')),
                      );
                    },
                  ),
                  _TinyAction(
                    tooltip: '重新生成',
                    icon: Icons.refresh_rounded,
                    onPressed: onRegenerate,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showMessageMenu(
    BuildContext context, {
    required Offset anchor,
    required int selectionIndex,
  }) async {
    if (message.content.trim().isEmpty) {
      return;
    }
    final action = await _showContextMenu(
      context,
      anchor: anchor,
      children: [
        const _MenuAction(
          icon: Icons.copy_rounded,
          label: '全部复制',
          value: 'copy',
        ),
        const _MenuAction(
          icon: Icons.text_fields_rounded,
          label: '自由选择',
          value: 'select',
        ),
        const _MenuAction(
          icon: Icons.menu_book_outlined,
          label: '阅读',
          value: 'read',
        ),
        if (message.isUser)
          const _MenuAction(
            icon: Icons.edit_note_rounded,
            label: '重新编辑',
            value: 'edit',
          )
        else if (!message.isStreaming)
          const _MenuAction(
            icon: Icons.refresh_rounded,
            label: '重新生成',
            value: 'regenerate',
          ),
      ],
    );
    if (action == 'copy') {
      onCopy(message.content);
    } else if (action == 'select') {
      _openMessageReader(
        context,
        message.content,
        selectionIndex,
        codeThemeId: codeThemeId,
        codeBackgroundValue: codeBackgroundValue,
      );
    } else if (action == 'read') {
      _openMessageReader(
        context,
        message.content,
        null,
        codeThemeId: codeThemeId,
        codeBackgroundValue: codeBackgroundValue,
      );
    } else if (action == 'edit') {
      onEditUserMessage(message.content);
    } else if (action == 'regenerate') {
      onRegenerate();
    }
  }

  int _estimateSelectionIndex(String text, Offset localPosition, Size? size) {
    if (text.isEmpty || size == null || size.width <= 0 || size.height <= 0) {
      return 0;
    }
    final lines = text.split('\n');
    final lineHeight = 24.0;
    final visibleLine = (localPosition.dy / lineHeight)
        .floor()
        .clamp(0, lines.length - 1)
        .toInt();
    var offset = 0;
    for (var index = 0; index < visibleLine; index += 1) {
      offset += lines[index].length + 1;
    }
    final line = lines[visibleLine];
    final ratio = (localPosition.dx / size.width).clamp(0.0, 1.0);
    offset += (line.length * ratio).round();
    return offset.clamp(0, text.length).toInt();
  }
}

void _openMessageReader(
  BuildContext context,
  String content,
  int? selectionIndex, {
  required String codeThemeId,
  required int codeBackgroundValue,
}) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (_, __, ___) => _MessageReaderPage(
        content: content,
        selectionIndex: selectionIndex,
        codeThemeId: codeThemeId,
        codeBackgroundValue: codeBackgroundValue,
      ),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return ColoredBox(
          color: _background(context),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.025, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 190),
      reverseTransitionDuration: const Duration(milliseconds: 120),
    ),
  );
}

class _MessageReaderPage extends StatefulWidget {
  const _MessageReaderPage({
    required this.content,
    required this.selectionIndex,
    required this.codeThemeId,
    required this.codeBackgroundValue,
  });

  final String content;
  final int? selectionIndex;
  final String codeThemeId;
  final int codeBackgroundValue;

  @override
  State<_MessageReaderPage> createState() => _MessageReaderPageState();
}

class _MessageReaderPageState extends State<_MessageReaderPage> {
  late final TextEditingController controller;
  late final FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.content);
    focusNode = FocusNode();
    final selectionIndex = widget.selectionIndex;
    if (selectionIndex != null) {
      final offset = selectionIndex.clamp(0, widget.content.length).toInt();
      controller.selection = TextSelection.collapsed(offset: offset);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const selectionColor = Color(0x663B82F6);
    const cursorColor = Color(0xFF2563EB);
    final selecting = widget.selectionIndex != null;
    return TextSelectionTheme(
      data: const TextSelectionThemeData(
        cursorColor: cursorColor,
        selectionColor: selectionColor,
        selectionHandleColor: cursorColor,
      ),
      child: Scaffold(
        backgroundColor: _background(context),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: selecting
                ? TextField(
                    controller: controller,
                    focusNode: focusNode,
                    readOnly: true,
                    showCursor: true,
                    enableInteractiveSelection: true,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    cursorColor: cursorColor,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                    style: TextStyle(
                      color: _textColor(context),
                      fontSize: 17,
                      height: 1.72,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w400,
                    ),
                  )
                : SingleChildScrollView(
                    child: MessageRenderer(
                      content: widget.content,
                      textColor: _textColor(context),
                      mutedColor: _mutedColor(context),
                      codeBackground: _softColor(context),
                      isUser: false,
                      codeThemeId: widget.codeThemeId,
                      codeBackgroundValue: widget.codeBackgroundValue,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _UserBubbleFrame extends StatefulWidget {
  const _UserBubbleFrame({required this.child});

  final Widget child;

  @override
  State<_UserBubbleFrame> createState() => _UserBubbleFrameState();
}

class _UserBubbleFrameState extends State<_UserBubbleFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = Curves.easeOutCubic.transform(controller.value);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: Transform.scale(
              alignment: Alignment.bottomRight,
              scale: 0.985 + value * 0.015,
              child: child,
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 9),
        decoration: BoxDecoration(
          color: _userBubbleColor(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.message,
    required this.codeThemeId,
    required this.codeBackgroundValue,
  });

  final ChatMessage message;
  final String codeThemeId;
  final int codeBackgroundValue;

  @override
  Widget build(BuildContext context) {
    final content = message.content;
    final textColor =
        message.isUser ? _onUserBubbleColor(context) : _textColor(context);
    final muted = message.isUser
        ? textColor.withValues(alpha: 0.72)
        : _mutedColor(context);
    final codeBackground = message.isUser
        ? textColor.withValues(alpha: 0.10)
        : _softColor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MessageRenderer(
          content: content,
          textColor: textColor,
          mutedColor: muted,
          codeBackground: codeBackground,
          isUser: message.isUser,
          animate: message.isStreaming,
          codeThemeId: codeThemeId,
          codeBackgroundValue: codeBackgroundValue,
        ),
      ],
    );
  }
}

class _TinyAction extends StatelessWidget {
  const _TinyAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 28),
      icon: Icon(icon, size: 15, color: _mutedColor(context)),
      onPressed: onPressed,
    );
  }
}

class _GenerationStatusText extends StatefulWidget {
  const _GenerationStatusText({required this.text});

  final String text;

  @override
  State<_GenerationStatusText> createState() => _GenerationStatusTextState();
}

class _GenerationStatusTextState extends State<_GenerationStatusText>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final label = _statusLabel(widget.text);
        final value = controller.value;
        final breath = Curves.easeInOutSine.transform(
          value < 0.5 ? value * 2 : (1 - value) * 2,
        );
        final alpha = 0.42 + breath * 0.28;
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: Transform.translate(
                key: ValueKey(label),
                offset: Offset(0, (1 - breath) * 0.8),
                child: Text(
                  label,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: _mutedColor(context).withValues(alpha: alpha),
                    fontSize: 13.5,
                    height: 1.45,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text == '...') {
      return '思考中';
    }
    if (text == '…') {
      return '思考中';
    }
    if (text.endsWith('...')) {
      return text.substring(0, text.length - 3).trim().isEmpty
          ? '思考中'
          : text.substring(0, text.length - 3).trim();
    }
    if (text.endsWith('…')) {
      final trimmed = text.substring(0, text.length - 1).trim();
      return trimmed.isEmpty ? '思考中' : trimmed;
    }
    return text;
  }
}

class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.textFieldKey,
    required this.onSurfaceProbe,
    required this.isSending,
    required this.onSend,
    required this.onStop,
    required this.onOpenMenu,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final GlobalKey textFieldKey;
  final VoidCallback onSurfaceProbe;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final ValueChanged<Offset> onOpenMenu;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  bool get hasText => widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  void _onFocusChanged() {
    AppLogger.instance.event('composer', {
      'event': 'focus',
      'focused': widget.focusNode.hasFocus,
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onSurfaceProbe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sendColor = _textColor(context);
    return SafeArea(
      top: false,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          AppLogger.instance.event('composer', {
            'event': 'pointerDown',
            'position': _fmtOffset(event.position),
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onSurfaceProbe();
          });
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 48, maxHeight: 154),
            padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
            decoration: BoxDecoration(
              color: _surface(context),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: _shadowColor(context, 0.10),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Builder(
                  builder: (buttonContext) {
                    return IconButton(
                      tooltip: '添加',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.add_rounded,
                        color: _mutedColor(context),
                        size: 24,
                      ),
                      onPressed: () {
                        final render =
                            buttonContext.findRenderObject() as RenderBox?;
                        final anchor = render == null
                            ? Offset.zero
                            : render.localToGlobal(
                                render.size.center(Offset.zero),
                              );
                        widget.onOpenMenu(anchor);
                      },
                    );
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: TextField(
                      key: widget.textFieldKey,
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      minLines: 1,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      cursorColor: sendColor,
                      onTap: () {
                        AppLogger.instance.info('composer', 'textField tap');
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          widget.onSurfaceProbe();
                        });
                      },
                      onTapOutside: (_) {
                        AppLogger.instance
                            .info('composer', 'textField tapOutside');
                        widget.focusNode.unfocus();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          widget.onSurfaceProbe();
                        });
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '问点什么…',
                        hintStyle: TextStyle(
                          color: _mutedColor(context),
                          fontSize: 15.5,
                        ),
                      ),
                      style: TextStyle(
                        color: sendColor,
                        fontSize: 15.5,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: widget.isSending ? '停止' : '发送',
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: widget.isSending || hasText
                        ? sendColor
                        : _softColor(context),
                    foregroundColor: _background(context),
                    disabledForegroundColor: _mutedColor(context),
                    fixedSize: const Size(36, 36),
                  ),
                  icon: Icon(
                    widget.isSending ? Icons.stop_rounded : Icons.arrow_upward,
                    size: 19,
                  ),
                  onPressed: widget.isSending
                      ? widget.onStop
                      : hasText
                          ? widget.onSend
                          : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChaitDrawer extends StatefulWidget {
  const ChaitDrawer({super.key, required this.store});

  final AppStore store;

  @override
  State<ChaitDrawer> createState() => _ChaitDrawerState();
}

class _ChaitDrawerState extends State<ChaitDrawer> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final pinned = _filteredSessions(true);
    final recent = _filteredSessions(false);
    final padding = MediaQuery.paddingOf(context);
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.84,
      backgroundColor: _surface(context),
      elevation: 12,
      shadowColor: _shadowColor(context, 0.12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(22)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              padding: EdgeInsets.fromLTRB(0, padding.top + 76, 0, 26),
              children: [
                if (pinned.isNotEmpty) ...[
                  _SectionLabel('置顶'),
                  ...pinned.map(_sessionRow),
                ],
                _SectionLabel('最近'),
                if (recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                    child: Text(
                      '没有匹配的聊天',
                      style: TextStyle(
                        color: _mutedColor(context),
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  ...recent.map(_sessionRow),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: padding.top + 92,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _surface(context),
                      _surface(context).withValues(alpha: 0.92),
                      _surface(context).withValues(alpha: 0),
                    ],
                    stops: const [0, 0.62, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: padding.top + 10,
            child: _DrawerSearchField(
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: padding.bottom + 14,
            child: Row(
              children: [
                Expanded(
                  child: _FloatingPillButton(
                    label: widget.store.currentAssistant.name,
                    icon: Icons.extension_outlined,
                    onTap: _showAssistantChooser,
                  ),
                ),
                const SizedBox(width: 10),
                _RoundShadowButton(
                  icon: Icons.settings_outlined,
                  tooltip: '设置',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      chaitPageRoute(
                        SettingsScreen(store: widget.store),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        ),
    );
  }

  List<ChatSession> _filteredSessions(bool pinned) {
    return widget.store.sessions.where((session) {
      final matchesPinned = session.pinned == pinned;
      final matchesQuery =
          query.trim().isEmpty || session.title.contains(query.trim());
      return matchesPinned && matchesQuery;
    }).toList();
  }

  Widget _sessionRow(ChatSession session) {
    return _DrawerRow(
      title: session.title,
      selected: session.id == widget.store.currentSessionId,
      leading: Icon(
        session.pinned ? Icons.push_pin_rounded : Icons.chat_bubble_outline,
        color: _mutedColor(context),
        size: 19,
      ),
      onLongPressStart: (anchor) => _showSessionActions(session, anchor),
      onTap: () {
        Navigator.pop(context);
        widget.store.selectSession(session.id);
      },
    );
  }

  Future<void> _showSessionActions(ChatSession session, Offset anchor) async {
    final action = await _showContextMenu(
      context,
      anchor: anchor,
      children: [
        _MenuAction(
          icon: session.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
          label: session.pinned ? '取消置顶' : '置顶',
          value: 'pin',
        ),
        const _MenuAction(
          icon: Icons.drive_file_rename_outline_rounded,
          label: '自定义标题',
          value: 'rename',
        ),
        const _MenuAction(
          icon: Icons.delete_outline_rounded,
          label: '删除',
          value: 'delete',
        ),
        const _MenuAction(
          icon: Icons.playlist_remove_rounded,
          label: '清除此会话以前的历史',
          value: 'clear_before',
        ),
        const _MenuAction(
          icon: Icons.clear_all_rounded,
          label: '清除所有会话历史',
          value: 'clear_all',
        ),
      ],
    );
    if (action == 'pin') {
      widget.store.togglePin(session);
    } else if (action == 'rename') {
      await _showRenameSessionDialog(
        context: context,
        store: widget.store,
        session: session,
      );
    } else if (action == 'delete') {
      widget.store.deleteSession(session.id);
    } else if (action == 'clear_before') {
      final ok = await _confirmClear('清除此会话以前的历史？');
      if (ok) {
        widget.store.clearSessionsBefore(session);
      }
    } else if (action == 'clear_all') {
      final ok = await _confirmClear('清除所有会话历史？');
      if (ok) {
        widget.store.clearUnpinnedSessions();
      }
    }
  }

  Future<bool> _confirmClear(String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _ChatSoftDialog(
        title: title,
        child: Text(
          '置顶会话会保留。',
          style: TextStyle(
            color: _mutedColor(context),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actions: [
          _ChatDialogAction(
            label: '取消',
            onPressed: () => Navigator.pop(context, false),
          ),
          _ChatDialogAction(
            label: '清除',
            filled: true,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showAssistantChooser(Offset anchor) async {
    final selected = await _showContextMenu(
      context,
      anchor: anchor,
      children: widget.store.assistants
          .map(
            (assistant) => _MenuAction(
              icon: Icons.extension_outlined,
              label: assistant.name,
              value: assistant.id,
            ),
          )
          .toList(),
    );
    if (selected != null) {
      Navigator.pop(context);
      widget.store.selectAssistant(selected);
    }
  }
}

class _DrawerSearchField extends StatelessWidget {
  const _DrawerSearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(22),
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
          hintText: '搜索聊天',
          hintStyle: TextStyle(color: _mutedColor(context), fontSize: 14),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: _mutedColor(context),
            size: 20,
          ),
          filled: true,
          fillColor: _surface(context),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: _mutedColor(context),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DrawerRow extends StatelessWidget {
  const _DrawerRow({
    required this.title,
    this.leading,
    this.selected = false,
    this.onLongPressStart,
    required this.onTap,
  });

  final String title;
  final Widget? leading;
  final bool selected;
  final ValueChanged<Offset>? onLongPressStart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: selected ? _softColor(context) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPressStart == null
              ? null
              : () {
                  final render = context.findRenderObject() as RenderBox?;
                  final anchor = render == null
                      ? Offset.zero
                      : render.localToGlobal(render.size.center(Offset.zero));
                  onLongPressStart!(anchor);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                if (leading != null) ...[
                  SizedBox(width: 30, child: Center(child: leading)),
                  const SizedBox(width: 8),
                ],
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
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingPillButton extends StatelessWidget {
  const _FloatingPillButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final ValueChanged<Offset> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: _shadowColor(context, 0.12),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(23),
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: () {
            final render = context.findRenderObject() as RenderBox?;
            final anchor = render == null
                ? Offset.zero
                : render.localToGlobal(Offset.zero);
            onTap(anchor);
          },
          child: SizedBox(
            height: 46,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: _textColor(context), size: 18),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _textColor(context),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundShadowButton extends StatelessWidget {
  const _RoundShadowButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.onPressed,
    this.compact = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 40.0 : 46.0;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _surface(context),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _shadowColor(context, 0.12),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            icon: Icon(
              icon,
              color: _mutedColor(context),
              size: compact ? 19 : 20,
            ),
            onPressed: onPressed ?? onTap,
          ),
        ),
      ),
    );
  }
}

class _MenuAction extends StatelessWidget {
  const _MenuAction({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _textColor(context)),
      title: Text(label, style: TextStyle(color: _textColor(context))),
      onTap: () => Navigator.pop(context, value),
    );
  }
}

Future<String?> _showContextMenu(
  BuildContext context, {
  required Offset anchor,
  required List<_MenuAction> children,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.08),
    transitionDuration: const Duration(milliseconds: 170),
    pageBuilder: (context, _, __) {
      final size = MediaQuery.sizeOf(context);
      final padding = MediaQuery.paddingOf(context);
      final placement = _menuPlacement(
        size: size,
        padding: padding,
        anchor: anchor,
        width: (size.width * 0.68).clamp(216.0, 320.0).toDouble(),
        estimatedHeight: (children.length * 56.0).clamp(56.0, 420.0).toDouble(),
      );
      return Stack(
        children: [
          Positioned(
            left: placement.left,
            top: placement.top,
            width: placement.width,
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.94, end: 1),
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOutCubic,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    alignment: placement.alignment,
                    child: child,
                  );
                },
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: placement.maxHeight,
                  ),
                  decoration: BoxDecoration(
                    color: _surface(context),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: _shadowColor(context, 0.14),
                        blurRadius: 30,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, _, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

_MenuPlacement _menuPlacement({
  required Size size,
  required EdgeInsets padding,
  required Offset anchor,
  required double width,
  required double estimatedHeight,
}) {
  const margin = 10.0;
  final safeTop = padding.top + margin;
  final safeBottom = size.height - padding.bottom - margin;
  final spaceBelow = safeBottom - anchor.dy;
  final spaceAbove = anchor.dy - safeTop;
  final openAbove = spaceBelow < estimatedHeight && spaceAbove > spaceBelow;
  final maxHeight = (openAbove ? spaceAbove : spaceBelow)
      .clamp(96.0, size.height * 0.72)
      .toDouble();
  final actualHeight = estimatedHeight.clamp(56.0, maxHeight).toDouble();
  final alignRight = anchor.dx + width > size.width - margin;
  final left = alignRight
      ? (anchor.dx - width)
          .clamp(margin, size.width - width - margin)
          .toDouble()
      : anchor.dx.clamp(margin, size.width - width - margin).toDouble();
  final top = openAbove
      ? (anchor.dy - actualHeight)
          .clamp(safeTop, safeBottom - actualHeight)
          .toDouble()
      : anchor.dy.clamp(safeTop, safeBottom - actualHeight).toDouble();
  return _MenuPlacement(
    left: left,
    top: top,
    width: width,
    maxHeight: maxHeight,
    alignment: Alignment(
      alignRight ? 1 : -1,
      openAbove ? 1 : -1,
    ),
  );
}

class _MenuPlacement {
  const _MenuPlacement({
    required this.left,
    required this.top,
    required this.width,
    required this.maxHeight,
    required this.alignment,
  });

  final double left;
  final double top;
  final double width;
  final double maxHeight;
  final Alignment alignment;
}

class _SheetSearchField extends StatelessWidget {
  const _SheetSearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      cursorColor: _textColor(context),
      decoration: InputDecoration(
        hintText: '搜索已添加模型',
        hintStyle: TextStyle(color: _mutedColor(context), fontSize: 13.5),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: _mutedColor(context),
          size: 19,
        ),
        filled: true,
        fillColor: _softColor(context),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      style: TextStyle(
        color: _textColor(context),
        fontSize: 14,
        height: 1.25,
      ),
    );
  }
}

Future<void> showModelChoiceSheet({
  required BuildContext context,
  required String title,
  required String value,
  required List<AiModelConfig> models,
  required String emptyLabel,
  required ValueChanged<String> onChanged,
}) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      var query = '';
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final normalized = query.trim().toLowerCase();
          final filtered = models.where((model) {
            if (normalized.isEmpty) {
              return true;
            }
            return model.name.toLowerCase().contains(normalized) ||
                model.displayName.toLowerCase().contains(normalized) ||
                model.providerName.toLowerCase().contains(normalized);
          }).toList();
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.96, end: 1),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: child,
              );
            },
            child: Container(
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
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
                      child: Text(
                        title,
                        style: TextStyle(
                          color: _textColor(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      child: _SheetSearchField(
                        onChanged: (value) =>
                            setSheetState(() => query = value),
                      ),
                    ),
                    ListTile(
                      title: Text(emptyLabel),
                      trailing:
                          value.isEmpty ? const Icon(Icons.check_rounded) : null,
                      onTap: () => Navigator.pop(context, ''),
                    ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          models.isEmpty ? '暂无可选模型' : '没有匹配模型',
                          style: TextStyle(color: _mutedColor(context)),
                        ),
                      ),
                    ...filtered.map(
                      (model) => ListTile(
                        title: Text(
                          model.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          model.providerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _mutedColor(context)),
                        ),
                        trailing: value == model.id
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: () => Navigator.pop(context, model.id),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
  if (result != null) {
    onChanged(result);
  }
}
