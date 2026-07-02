import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../app_store.dart';
import '../models.dart';
import 'settings_screen.dart';

const _ink = Color(0xFF111111);
const _muted = Color(0xFF8B8B8B);
const _line = Color(0xFFEDEDED);
const _soft = Color(0xFFF7F7F7);
const _bubble = Color(0xFFF1F1F1);
const _userBubble = Color(0xFFE9E9E9);

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _send() async {
    final text = _inputController.text;
    if (text.trim().isEmpty) {
      return;
    }
    _inputController.clear();
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

  @override
  Widget build(BuildContext context) {
    final session = widget.store.currentSession;
    final assistant = widget.store.currentAssistant;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawerScrimColor: Colors.black.withValues(alpha: 0.08),
      drawer: ChaitDrawer(store: widget.store),
      body: Stack(
          children: [
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
                            top: MediaQuery.paddingOf(context).top + 76,
                            bottom: 108,
                          ),
                          child: _EmptyChat(assistant: assistant),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            18,
                            MediaQuery.paddingOf(context).top + 98,
                            18,
                            118,
                          ),
                          itemCount: session.messages.length,
                          itemBuilder: (context, index) {
                            return MessageBubble(
                              message: session.messages[index],
                              onRegenerate: widget.store.regenerateLastAnswer,
                            );
                          },
                        ),
                ),
              ),
            ),
            _ImmersiveTopBar(
              assistantName: assistant.name,
              sessionTitle: session.title,
              showNewChat: session.messages.isNotEmpty,
              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              onNewChat: () => widget.store.createSession(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Composer(
                controller: _inputController,
                focusNode: _focusNode,
                isSending: widget.store.isSending,
                onSend: _send,
                onStop: widget.store.stopGeneration,
                onOpenMenu: _openCurrentSessionModel,
              ),
            ),
          ],
      ),
    );
  }
}

class _ImmersiveTopBar extends StatelessWidget {
  const _ImmersiveTopBar({
    required this.assistantName,
    required this.sessionTitle,
    required this.showNewChat,
    required this.onOpenDrawer,
    required this.onNewChat,
  });

  final String assistantName;
  final String sessionTitle;
  final bool showNewChat;
  final VoidCallback onOpenDrawer;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Container(
        height: top + 92,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.white,
              Color(0xF2FFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [0, 0.58, 0.78, 1],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(top: top),
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '打开侧边栏',
                  icon: const Icon(Icons.menu_rounded, size: 24),
                  onPressed: onOpenDrawer,
                ),
                Expanded(
                  child: _ChatTitle(
                    assistantName: assistantName,
                    sessionTitle: sessionTitle,
                  ),
                ),
                AnimatedOpacity(
                  opacity: showNewChat ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: IgnorePointer(
                    ignoring: !showNewChat,
                    child: IconButton(
                      tooltip: '新对话',
                      icon: const Icon(Icons.edit_square, size: 21),
                      onPressed: onNewChat,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatTitle extends StatelessWidget {
  const _ChatTitle({
    required this.assistantName,
    required this.sessionTitle,
  });

  final String assistantName;
  final String sessionTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          assistantName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          sessionTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w400,
            height: 1.1,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.assistant});

  final AssistantPreset assistant;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _soft,
              ),
              alignment: Alignment.center,
              child: Text(
                _initialOf(assistant.name),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              assistant.name,
              style: const TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              assistant.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.onRegenerate,
  });

  final ChatMessage message;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.82,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                    decoration: BoxDecoration(
                      color: isUser ? _userBubble : _bubble,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 6),
                        bottomRight: Radius.circular(isUser ? 6 : 20),
                      ),
                    ),
                    child: _MessageContent(message: message),
                  ),
                ),
              );
            },
          ),
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 5),
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
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.content.isEmpty && message.isStreaming) {
      return const SizedBox(
        width: 88,
        height: 22,
        child: _StreamingHighlight(),
      );
    }
    final content = message.content;
    final display = _formatForMarkdown(content);
    return TweenAnimationBuilder<double>(
      key: ValueKey(display.length),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 3),
            child: child,
          ),
        );
      },
      child: MarkdownBody(
        data: display,
        softLineBreak: true,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(
            color: _ink,
            fontSize: 15.5,
            height: 1.45,
            letterSpacing: 0,
          ),
          code: const TextStyle(
            color: _ink,
            fontSize: 13.5,
            height: 1.45,
            fontFamily: 'monospace',
            backgroundColor: Color(0xFFE8E8E8),
          ),
          codeblockDecoration: BoxDecoration(
            color: const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(12),
          ),
          blockquoteDecoration: const BoxDecoration(
            border:
                Border(left: BorderSide(color: Color(0xFFD5D5D5), width: 3)),
          ),
          tableBorder: TableBorder.all(color: const Color(0xFFDCDCDC)),
        ),
      ),
    );
  }

  String _formatForMarkdown(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return source;
    }
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      try {
        return '```json\n${prettyJson(jsonDecode(trimmed))}\n```';
      } catch (_) {
        return source;
      }
    }
    if (trimmed.startsWith('<') && trimmed.endsWith('>')) {
      return '```xml\n$source\n```';
    }
    return source;
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
      icon: Icon(icon, size: 15, color: _muted),
      onPressed: onPressed,
    );
  }
}

class _StreamingHighlight extends StatefulWidget {
  const _StreamingHighlight();

  @override
  State<_StreamingHighlight> createState() => _StreamingHighlightState();
}

class _StreamingHighlightState extends State<_StreamingHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final width = constraints.maxWidth;
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Container(color: const Color(0xFFECECEC)),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: (width + 22) * controller.value - 22,
                    child: Container(
                      width: 22,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x00FFFFFF),
                            Color(0xFFFFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
    required this.onStop,
    required this.onOpenMenu,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onOpenMenu;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  bool get hasText => widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 190),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 48, maxHeight: 154),
        padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: '添加',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_rounded, color: _muted, size: 24),
              onPressed: widget.onOpenMenu,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  minLines: 1,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  cursorColor: _ink,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '问点什么…',
                    hintStyle: TextStyle(color: _muted, fontSize: 15.5),
                  ),
                  style: const TextStyle(
                    color: _ink,
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
                    ? _ink
                    : const Color(0xFFE4E4E4),
                foregroundColor: Colors.white,
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
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.84,
      backgroundColor: Colors.white,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
              child: Row(
                children: [
                  const Text(
                    'Chait',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: TextField(
                onChanged: (value) => setState(() => query = value),
                cursorColor: _ink,
                decoration: InputDecoration(
                  hintText: '搜索聊天',
                  hintStyle: const TextStyle(color: _muted, fontSize: 14),
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: _muted, size: 20),
                  filled: true,
                  fillColor: _soft,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  if (pinned.isNotEmpty) ...[
                    _SectionLabel('置顶'),
                    ...pinned.map(_sessionRow),
                  ],
                  _SectionLabel('最近'),
                  if (recent.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(18, 12, 18, 8),
                      child: Text(
                        '没有匹配的聊天',
                        style: TextStyle(color: _muted, fontSize: 13),
                      ),
                    )
                  else
                    ...recent.map(_sessionRow),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: _FloatingPillButton(
                      label: widget.store.currentAssistant.name,
                      icon: Icons.person_outline_rounded,
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
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(store: widget.store),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
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
        color: _muted,
        size: 19,
      ),
      onLongPress: () => _showSessionActions(session),
      onTap: () {
        Navigator.pop(context);
        widget.store.selectSession(session.id);
      },
    );
  }

  Future<void> _showSessionActions(ChatSession session) async {
    final action = await _showScaleMenu(
      context,
      children: [
        _MenuAction(
          icon: session.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
          label: session.pinned ? '取消置顶' : '置顶',
          value: 'pin',
        ),
        const _MenuAction(
          icon: Icons.delete_outline_rounded,
          label: '删除',
          value: 'delete',
        ),
      ],
    );
    if (action == 'pin') {
      widget.store.togglePin(session);
    } else if (action == 'delete') {
      widget.store.deleteSession(session.id);
    }
  }

  Future<void> _showAssistantChooser() async {
    final selected = await _showScaleMenu(
      context,
      children: widget.store.assistants
          .map(
            (assistant) => _MenuAction(
              icon: Icons.person_outline_rounded,
              label: assistant.name,
              subtitle: assistant.description,
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
          style: const TextStyle(
            color: _muted,
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
    this.subtitle = '',
    this.leading,
    this.trailing,
    this.selected = false,
    this.onLongPress,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onLongPress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: selected ? const Color(0xFFF2F2F2) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPress,
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
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(23),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _ink, size: 18),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: _ink, size: 20),
        onPressed: onTap,
      ),
    );
  }
}

class _MenuAction extends StatelessWidget {
  const _MenuAction({
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
      leading: Icon(icon, color: _ink),
      title: Text(label),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      onTap: () => Navigator.pop(context, value),
    );
  }
}

Future<String?> _showScaleMenu(
  BuildContext context, {
  required List<_MenuAction> children,
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
            width: MediaQuery.sizeOf(context).width * 0.76,
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 34,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: SafeArea(
              minimum: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: curved, child: child),
      );
    },
  );
}

String _initialOf(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return trimmed.substring(0, 1);
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
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.94, end: 1),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          return Transform.scale(scale: scale, alignment: Alignment.bottomCenter, child: child);
        },
        child: Container(
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ListTile(
                  title: Text(emptyLabel),
                  trailing: value.isEmpty ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.pop(context, ''),
                ),
                if (models.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      '还没有已添加模型。请先到设置的服务商设定里刷新并勾选模型。',
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
                      model.providerName,
                      maxLines: 1,
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
        ),
      );
    },
  );
  if (result != null) {
    onChanged(result);
  }
}
