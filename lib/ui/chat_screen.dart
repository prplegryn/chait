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

  @override
  Widget build(BuildContext context) {
    final session = widget.store.currentSession;
    final assistant = widget.store.currentAssistant;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawerScrimColor: Colors.black.withValues(alpha: 0.08),
      drawer: ChaitDrawer(store: widget.store),
      appBar: AppBar(
        toolbarHeight: 58,
        leadingWidth: 56,
        leading: IconButton(
          tooltip: '打开侧边栏',
          icon: const Icon(Icons.menu_rounded, size: 24),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: _ChatTitle(
          assistantName: assistant.name,
          sessionTitle: session.title,
        ),
        actions: [
          IconButton(
            tooltip: '新对话',
            icon: const Icon(Icons.edit_square, size: 21),
            onPressed: () => widget.store.createSession(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const Divider(height: 1),
            Expanded(
              child: session.messages.isEmpty
                  ? _EmptyChat(assistant: assistant)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                      itemCount: session.messages.length,
                      itemBuilder: (context, index) {
                        return MessageBubble(
                          message: session.messages[index],
                          onRegenerate: widget.store.regenerateLastAnswer,
                        );
                      },
                    ),
            ),
            Composer(
              controller: _inputController,
              focusNode: _focusNode,
              isSending: widget.store.isSending,
              onSend: _send,
              onStop: widget.store.stopGeneration,
            ),
          ],
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
                  if (message.isStreaming)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: _TypingDots(),
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
    final content = message.content.isEmpty && message.isStreaming
        ? '正在输入'
        : message.content;
    final display = _formatForMarkdown(content);
    return MarkdownBody(
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
          border: Border(left: BorderSide(color: Color(0xFFD5D5D5), width: 3)),
        ),
        tableBorder: TableBorder.all(color: const Color(0xFFDCDCDC)),
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

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
        final index = (controller.value * 3).floor().clamp(0, 2);
        return Row(
          children: List.generate(3, (dot) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.symmetric(horizontal: 1.8),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: dot == index ? _ink : const Color(0xFFCFCFCF),
                shape: BoxShape.circle,
              ),
            );
          }),
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
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onStop;

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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 190),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 48, maxHeight: 154),
        padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: '添加',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_rounded, color: _muted, size: 24),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('附件入口已保留')),
                );
              },
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
              padding: const EdgeInsets.fromLTRB(18, 10, 14, 8),
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
                  const Spacer(),
                  IconButton(
                    tooltip: '新对话',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.store.createSession();
                    },
                  ),
                ],
              ),
            ),
            _SectionLabel('助手'),
            ...widget.store.assistants.map(
              (assistant) => _DrawerRow(
                title: assistant.name,
                subtitle: assistant.description,
                selected: assistant.id == widget.store.currentAssistantId,
                leading: _AssistantMark(name: assistant.name),
                onTap: () {
                  Navigator.pop(context);
                  widget.store.selectAssistant(assistant.id);
                },
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
            const Divider(height: 1),
            _DrawerRow(
              title: '设置',
              subtitle: '助手、API、参数、数据',
              leading: const Icon(Icons.settings_outlined, color: _ink),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(store: widget.store),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
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
    final assistant = widget.store.assistants.firstWhere(
      (item) => item.id == session.assistantId,
      orElse: () => widget.store.currentAssistant,
    );
    return _DrawerRow(
      title: session.title,
      subtitle: assistant.name,
      selected: session.id == widget.store.currentSessionId,
      leading: Icon(
        session.pinned ? Icons.push_pin_rounded : Icons.chat_bubble_outline,
        color: _muted,
        size: 19,
      ),
      trailing: PopupMenuButton<String>(
        tooltip: '更多',
        icon: const Icon(Icons.more_horiz_rounded, color: _muted, size: 20),
        onSelected: (value) {
          if (value == 'pin') {
            widget.store.togglePin(session);
          } else if (value == 'delete') {
            widget.store.deleteSession(session.id);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'pin',
            child: Text(session.pinned ? '取消置顶' : '置顶'),
          ),
          const PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
      onTap: () {
        Navigator.pop(context);
        widget.store.selectSession(session.id);
      },
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
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
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

class _AssistantMark extends StatelessWidget {
  const _AssistantMark({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: _soft,
      ),
      alignment: Alignment.center,
      child: Text(
        _initialOf(name),
        style: const TextStyle(
          color: _ink,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _initialOf(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return trimmed.substring(0, 1);
}
