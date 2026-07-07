import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:markdown/markdown.dart' as md;

import '../models.dart';

class CodeThemeOption {
  const CodeThemeOption({
    required this.id,
    required this.label,
    this.background,
    this.foreground,
    this.comment,
    this.string,
    this.number,
    this.keyword,
    this.type,
    this.function,
    this.operator,
    this.gutter,
  });

  final String id;
  final String label;
  final Color? background;
  final Color? foreground;
  final Color? comment;
  final Color? string;
  final Color? number;
  final Color? keyword;
  final Color? type;
  final Color? function;
  final Color? operator;
  final Color? gutter;
}

const codeThemeOptions = <CodeThemeOption>[
  CodeThemeOption(id: 'default', label: '默认'),
  CodeThemeOption(
    id: 'github-light',
    label: 'GitHub Light',
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF24292F),
    comment: Color(0xFF6E7781),
    string: Color(0xFF0A3069),
    number: Color(0xFF0550AE),
    keyword: Color(0xFFCF222E),
    type: Color(0xFF8250DF),
    function: Color(0xFF8250DF),
    operator: Color(0xFF57606A),
    gutter: Color(0xFF8C959F),
  ),
  CodeThemeOption(
    id: 'vscode-light',
    label: 'VS Code Light',
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF1F1F1F),
    comment: Color(0xFF008000),
    string: Color(0xFFA31515),
    number: Color(0xFF098658),
    keyword: Color(0xFF0000FF),
    type: Color(0xFF267F99),
    function: Color(0xFF795E26),
    operator: Color(0xFF333333),
    gutter: Color(0xFF858585),
  ),
  CodeThemeOption(
    id: 'one-light',
    label: 'One Light',
    background: Color(0xFFFAFAFA),
    foreground: Color(0xFF383A42),
    comment: Color(0xFFA0A1A7),
    string: Color(0xFF50A14F),
    number: Color(0xFF986801),
    keyword: Color(0xFFA626A4),
    type: Color(0xFFC18401),
    function: Color(0xFF4078F2),
    operator: Color(0xFF383A42),
    gutter: Color(0xFF9DA5B4),
  ),
  CodeThemeOption(
    id: 'solarized-light',
    label: 'Solarized Light',
    background: Color(0xFFFDF6E3),
    foreground: Color(0xFF657B83),
    comment: Color(0xFF93A1A1),
    string: Color(0xFF2AA198),
    number: Color(0xFFD33682),
    keyword: Color(0xFF859900),
    type: Color(0xFFB58900),
    function: Color(0xFF268BD2),
    operator: Color(0xFF586E75),
    gutter: Color(0xFF93A1A1),
  ),
  CodeThemeOption(
    id: 'ayu-light',
    label: 'Ayu Light',
    background: Color(0xFFFAFAFA),
    foreground: Color(0xFF5C6773),
    comment: Color(0xFFABB0B6),
    string: Color(0xFF86B300),
    number: Color(0xFFA37ACC),
    keyword: Color(0xFFFA8D3E),
    type: Color(0xFF399EE6),
    function: Color(0xFFF2AE49),
    operator: Color(0xFFED9366),
    gutter: Color(0xFFA1A6AC),
  ),
  CodeThemeOption(
    id: 'github-dark',
    label: 'GitHub Dark',
    background: Color(0xFF0D1117),
    foreground: Color(0xFFC9D1D9),
    comment: Color(0xFF8B949E),
    string: Color(0xFFA5D6FF),
    number: Color(0xFF79C0FF),
    keyword: Color(0xFFFF7B72),
    type: Color(0xFFD2A8FF),
    function: Color(0xFFD2A8FF),
    operator: Color(0xFFC9D1D9),
    gutter: Color(0xFF6E7681),
  ),
  CodeThemeOption(
    id: 'vscode-dark',
    label: 'VS Code Dark',
    background: Color(0xFF1E1E1E),
    foreground: Color(0xFFD4D4D4),
    comment: Color(0xFF6A9955),
    string: Color(0xFFCE9178),
    number: Color(0xFFB5CEA8),
    keyword: Color(0xFF569CD6),
    type: Color(0xFF4EC9B0),
    function: Color(0xFFDCDCAA),
    operator: Color(0xFFD4D4D4),
    gutter: Color(0xFF858585),
  ),
  CodeThemeOption(
    id: 'one-dark',
    label: 'One Dark',
    background: Color(0xFF282C34),
    foreground: Color(0xFFABB2BF),
    comment: Color(0xFF5C6370),
    string: Color(0xFF98C379),
    number: Color(0xFFD19A66),
    keyword: Color(0xFFC678DD),
    type: Color(0xFFE5C07B),
    function: Color(0xFF61AFEF),
    operator: Color(0xFF56B6C2),
    gutter: Color(0xFF636D83),
  ),
  CodeThemeOption(
    id: 'dracula',
    label: 'Dracula',
    background: Color(0xFF282A36),
    foreground: Color(0xFFF8F8F2),
    comment: Color(0xFF6272A4),
    string: Color(0xFFF1FA8C),
    number: Color(0xFFBD93F9),
    keyword: Color(0xFFFF79C6),
    type: Color(0xFF8BE9FD),
    function: Color(0xFF50FA7B),
    operator: Color(0xFFFF79C6),
    gutter: Color(0xFF7B86B8),
  ),
  CodeThemeOption(
    id: 'monokai',
    label: 'Monokai',
    background: Color(0xFF272822),
    foreground: Color(0xFFF8F8F2),
    comment: Color(0xFF75715E),
    string: Color(0xFFE6DB74),
    number: Color(0xFFAE81FF),
    keyword: Color(0xFFF92672),
    type: Color(0xFF66D9EF),
    function: Color(0xFFA6E22E),
    operator: Color(0xFFF92672),
    gutter: Color(0xFF90908A),
  ),
  CodeThemeOption(
    id: 'nord',
    label: 'Nord',
    background: Color(0xFF2E3440),
    foreground: Color(0xFFD8DEE9),
    comment: Color(0xFF616E88),
    string: Color(0xFFA3BE8C),
    number: Color(0xFFB48EAD),
    keyword: Color(0xFF81A1C1),
    type: Color(0xFF8FBCBB),
    function: Color(0xFF88C0D0),
    operator: Color(0xFF81A1C1),
    gutter: Color(0xFF6B7488),
  ),
  CodeThemeOption(
    id: 'night-owl',
    label: 'Night Owl',
    background: Color(0xFF011627),
    foreground: Color(0xFFD6DEEB),
    comment: Color(0xFF637777),
    string: Color(0xFFECC48D),
    number: Color(0xFFF78C6C),
    keyword: Color(0xFFC792EA),
    type: Color(0xFFFFCB8B),
    function: Color(0xFF82AAFF),
    operator: Color(0xFFC792EA),
    gutter: Color(0xFF5F7E97),
  ),
  CodeThemeOption(
    id: 'tokyo-night',
    label: 'Tokyo Night',
    background: Color(0xFF1A1B26),
    foreground: Color(0xFFC0CAF5),
    comment: Color(0xFF565F89),
    string: Color(0xFF9ECE6A),
    number: Color(0xFFFF9E64),
    keyword: Color(0xFFBB9AF7),
    type: Color(0xFF2AC3DE),
    function: Color(0xFF7AA2F7),
    operator: Color(0xFF89DDFF),
    gutter: Color(0xFF6A6F8F),
  ),
  CodeThemeOption(
    id: 'catppuccin',
    label: 'Catppuccin',
    background: Color(0xFF1E1E2E),
    foreground: Color(0xFFCDD6F4),
    comment: Color(0xFF6C7086),
    string: Color(0xFFA6E3A1),
    number: Color(0xFFFAB387),
    keyword: Color(0xFFCBA6F7),
    type: Color(0xFFF9E2AF),
    function: Color(0xFF89B4FA),
    operator: Color(0xFF89DCEB),
    gutter: Color(0xFF7F849C),
  ),
  CodeThemeOption(
    id: 'palenight',
    label: 'Palenight',
    background: Color(0xFF292D3E),
    foreground: Color(0xFFA6ACCD),
    comment: Color(0xFF676E95),
    string: Color(0xFFC3E88D),
    number: Color(0xFFF78C6C),
    keyword: Color(0xFFC792EA),
    type: Color(0xFFFFCB6B),
    function: Color(0xFF82AAFF),
    operator: Color(0xFF89DDFF),
    gutter: Color(0xFF737AA2),
  ),
];

CodeThemeOption codeThemeById(String id) {
  return codeThemeOptions.firstWhere(
    (theme) => theme.id == id,
    orElse: () => codeThemeOptions.first,
  );
}

class MessageRenderer extends StatelessWidget {
  const MessageRenderer({
    super.key,
    required this.content,
    required this.textColor,
    required this.mutedColor,
    required this.codeBackground,
    required this.isUser,
    this.animate = false,
    this.codeThemeId = 'default',
    this.codeBackgroundValue = 0,
  });

  final String content;
  final Color textColor;
  final Color mutedColor;
  final Color codeBackground;
  final bool isUser;
  final bool animate;
  final String codeThemeId;
  final int codeBackgroundValue;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseMessageBlocks(content);
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < blocks.length; index += 1)
          _RevealBlock(
            enabled: animate && blocks[index].kind != _MessageBlockKind.markdown,
            token: '${index}_${blocks[index].kind}',
            child: Padding(
              padding: EdgeInsets.only(
                top: index == 0 ? 0 : _gapBefore(blocks[index]),
              ),
              child: _BlockView(
                block: blocks[index],
                textColor: textColor,
                mutedColor: mutedColor,
                codeBackground: codeBackground,
                isUser: isUser,
                codeThemeId: codeThemeId,
                codeBackgroundValue: codeBackgroundValue,
              ),
            ),
          ),
      ],
    );
  }

  double _gapBefore(_MessageBlock block) {
    return switch (block.kind) {
      _MessageBlockKind.markdown => 6,
      _MessageBlockKind.displayMath => 12,
      _MessageBlockKind.code => 12,
      _MessageBlockKind.table => 12,
    };
  }
}

class _RevealBlock extends StatelessWidget {
  const _RevealBlock({
    required this.enabled,
    required this.token,
    required this.child,
  });

  final bool enabled;
  final String token;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(token),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
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
      child: child,
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({
    required this.block,
    required this.textColor,
    required this.mutedColor,
    required this.codeBackground,
    required this.isUser,
    required this.codeThemeId,
    required this.codeBackgroundValue,
  });

  final _MessageBlock block;
  final Color textColor;
  final Color mutedColor;
  final Color codeBackground;
  final bool isUser;
  final String codeThemeId;
  final int codeBackgroundValue;

  @override
  Widget build(BuildContext context) {
    return switch (block.kind) {
      _MessageBlockKind.markdown => _MarkdownText(
          data: block.text,
          textColor: textColor,
          mutedColor: mutedColor,
          codeBackground: codeBackground,
          isUser: isUser,
        ),
      _MessageBlockKind.displayMath => _DisplayMath(
          source: block.source,
          tex: block.text,
          textColor: textColor,
          mutedColor: mutedColor,
        ),
      _MessageBlockKind.code => _CodeBlock(
          code: block.text,
          language: block.language,
          textColor: textColor,
          mutedColor: mutedColor,
          backgroundColor: codeBackground,
          isUser: isUser,
          codeThemeId: codeThemeId,
          codeBackgroundValue: codeBackgroundValue,
        ),
      _MessageBlockKind.table => _MarkdownTable(
          table: block.table!,
          textColor: textColor,
          mutedColor: mutedColor,
          backgroundColor: codeBackground,
          isUser: isUser,
        ),
    };
  }
}

class _MarkdownText extends StatelessWidget {
  const _MarkdownText({
    required this.data,
    required this.textColor,
    required this.mutedColor,
    required this.codeBackground,
    required this.isUser,
  });

  final String data;
  final Color textColor;
  final Color mutedColor;
  final Color codeBackground;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = TextStyle(
      color: isUser ? textColor : textColor.withValues(alpha: 0.94),
      fontSize: 16.2,
      height: isUser ? 1.56 : 1.66,
      letterSpacing: 0,
      fontWeight: FontWeight.w400,
    );
    final headingStyle = bodyStyle.copyWith(
      fontSize: isUser ? 16.4 : 16.8,
      height: 1.42,
      fontWeight: FontWeight.w600,
    );
    final inlineCodeBackground =
        isUser ? textColor.withValues(alpha: 0.11) : codeBackground;
    return MarkdownBody(
      data: data.trim(),
      softLineBreak: true,
      extensionSet: md.ExtensionSet.gitHubWeb,
      inlineSyntaxes: [
        _ParenInlineMathSyntax(),
        _DollarInlineMathSyntax(),
      ],
      builders: {
        'math': _InlineMathBuilder(
          textColor: textColor,
          mutedColor: mutedColor,
          baseStyle: bodyStyle,
        ),
      },
      styleSheet: MarkdownStyleSheet(
        p: bodyStyle,
        pPadding: EdgeInsets.only(bottom: isUser ? 0 : 7),
        a: bodyStyle.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
        ),
        strong: bodyStyle.copyWith(fontWeight: FontWeight.w600),
        em: bodyStyle.copyWith(fontStyle: FontStyle.italic),
        h1: headingStyle.copyWith(fontSize: isUser ? 17.6 : 18.2),
        h2: headingStyle.copyWith(fontSize: isUser ? 17 : 17.4),
        h3: headingStyle,
        h1Padding: const EdgeInsets.only(top: 12, bottom: 8),
        h2Padding: const EdgeInsets.only(top: 11, bottom: 7),
        h3Padding: const EdgeInsets.only(top: 9, bottom: 5),
        blockSpacing: isUser ? 7 : 9,
        listIndent: isUser ? 21 : 20,
        listBullet: bodyStyle.copyWith(color: mutedColor),
        listBulletPadding: const EdgeInsets.only(right: 6),
        code: TextStyle(
          color: textColor,
          fontSize: 13.4,
          height: 1.4,
          fontFamily: 'monospace',
          backgroundColor: inlineCodeBackground,
        ),
        codeblockPadding: EdgeInsets.zero,
        codeblockDecoration: const BoxDecoration(color: Colors.transparent),
        blockquote: bodyStyle.copyWith(color: textColor.withValues(alpha: 0.78)),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: mutedColor.withValues(alpha: 0.36),
              width: 2,
            ),
          ),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: mutedColor.withValues(alpha: 0.24)),
          ),
        ),
        tableHead: bodyStyle.copyWith(fontWeight: FontWeight.w600),
        tableBody: bodyStyle.copyWith(fontSize: 14.5),
        tableBorder: TableBorder.all(color: mutedColor.withValues(alpha: 0.18)),
        tableCellsPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}

class _DisplayMath extends StatelessWidget {
  const _DisplayMath({
    required this.source,
    required this.tex,
    required this.textColor,
    required this.mutedColor,
  });

  final String source;
  final String tex;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: Alignment.center,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            tex,
            mathStyle: MathStyle.display,
            textStyle: TextStyle(
              color: textColor,
              fontSize: 18,
              height: 1.35,
            ),
            onErrorFallback: (_) => Text(
              source,
              style: TextStyle(
                color: mutedColor,
                fontSize: 14.5,
                height: 1.45,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineMathBuilder extends MarkdownElementBuilder {
  _InlineMathBuilder({
    required this.textColor,
    required this.mutedColor,
    required this.baseStyle,
  });

  final Color textColor;
  final Color mutedColor;
  final TextStyle baseStyle;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final source = element.attributes['source'] ?? element.textContent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Math.tex(
        element.textContent,
        mathStyle: MathStyle.text,
        textStyle: (parentStyle ?? preferredStyle ?? baseStyle).copyWith(
          color: textColor,
          fontSize: baseStyle.fontSize,
          height: 1.1,
        ),
        onErrorFallback: (_) => Text(
          source,
          style: baseStyle.copyWith(color: mutedColor),
        ),
      ),
    );
  }
}

class _DollarInlineMathSyntax extends md.InlineSyntax {
  _DollarInlineMathSyntax()
      : super(
          r'\$((?=[^$\n]*(?:\\|[=^_{}]))[^$\n]+?)\$',
          startCharacter: 36,
        );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = match[1]?.trim() ?? '';
    final source = match[0] ?? tex;
    parser.addNode(
      md.Element.text('math', tex)..attributes['source'] = source,
    );
    return true;
  }
}

class _ParenInlineMathSyntax extends md.InlineSyntax {
  _ParenInlineMathSyntax()
      : super(
          r'\\\(([^\n]+?)\\\)',
          startCharacter: 92,
        );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = match[1]?.trim() ?? '';
    final source = match[0] ?? tex;
    parser.addNode(
      md.Element.text('math', tex)..attributes['source'] = source,
    );
    return true;
  }
}

class _CodeBlock extends StatefulWidget {
  const _CodeBlock({
    required this.code,
    required this.language,
    required this.textColor,
    required this.mutedColor,
    required this.backgroundColor,
    required this.isUser,
    required this.codeThemeId,
    required this.codeBackgroundValue,
  });

  final String code;
  final String language;
  final Color textColor;
  final Color mutedColor;
  final Color backgroundColor;
  final bool isUser;
  final String codeThemeId;
  final int codeBackgroundValue;

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _wrap = false;
  bool _expanded = false;
  bool _preview = false;

  bool get _isLong =>
      widget.code.split('\n').length > 18 || widget.code.length > 1600;

  @override
  Widget build(BuildContext context) {
    final language = _languageLabel(widget.language, widget.code);
    final safeSvg = _isSvgLanguage(language) && _isSafeSvg(widget.code);
    final showPreview = safeSvg && _preview;
    final codeTheme = _resolvedCodeTheme(
      themeId: widget.codeThemeId,
      customBackgroundValue: widget.codeBackgroundValue,
      fallbackBackground: widget.isUser
          ? widget.textColor.withValues(alpha: 0.10)
          : widget.backgroundColor,
      fallbackText: widget.textColor,
      fallbackMuted: widget.mutedColor,
    );
    final background = codeTheme.background;
    final borderColor = widget.mutedColor.withValues(alpha: 0.12);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CodeToolbar(
              language: language,
              mutedColor: widget.mutedColor,
              textColor: codeTheme.foreground,
              canPreview: safeSvg,
              preview: _preview,
              wrap: _wrap,
              expanded: _expanded,
              isLong: _isLong,
              onTogglePreview: safeSvg
                  ? () => setState(() => _preview = !_preview)
                  : null,
              onToggleWrap: showPreview
                  ? null
                  : () => setState(() => _wrap = !_wrap),
              onToggleExpanded:
                  _isLong ? () => setState(() => _expanded = !_expanded) : null,
              onCopy: () async {
                await Clipboard.setData(ClipboardData(text: widget.code));
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制')),
                );
              },
            ),
            AnimatedCrossFade(
              firstChild: _CodeTextBody(
                code: widget.code,
                language: language,
                theme: codeTheme,
                backgroundColor: background,
                wrap: _wrap,
                collapsed: _isLong && !_expanded,
              ),
              secondChild: _SvgPreview(
                svg: widget.code,
                mutedColor: widget.mutedColor,
                backgroundColor: background,
              ),
              crossFadeState:
                  showPreview ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
              sizeCurve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeToolbar extends StatelessWidget {
  const _CodeToolbar({
    required this.language,
    required this.mutedColor,
    required this.textColor,
    required this.canPreview,
    required this.preview,
    required this.wrap,
    required this.expanded,
    required this.isLong,
    required this.onTogglePreview,
    required this.onToggleWrap,
    required this.onToggleExpanded,
    required this.onCopy,
  });

  final String language;
  final Color mutedColor;
  final Color textColor;
  final bool canPreview;
  final bool preview;
  final bool wrap;
  final bool expanded;
  final bool isLong;
  final VoidCallback? onTogglePreview;
  final VoidCallback? onToggleWrap;
  final VoidCallback? onToggleExpanded;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: mutedColor.withValues(alpha: 0.10))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              language,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: mutedColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          if (canPreview)
            _CodeIconButton(
              tooltip: preview ? '查看源码' : '预览',
              icon: preview ? Icons.code_rounded : Icons.visibility_outlined,
              color: preview ? textColor : mutedColor,
              onPressed: onTogglePreview,
            ),
          if (!preview)
            _CodeIconButton(
              tooltip: wrap ? '横向滚动' : '自动换行',
              icon: wrap ? Icons.wrap_text_rounded : Icons.notes_rounded,
              color: wrap ? textColor : mutedColor,
              onPressed: onToggleWrap,
            ),
          if (isLong)
            _CodeIconButton(
              tooltip: expanded ? '收起' : '展开',
              icon: expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: expanded ? textColor : mutedColor,
              onPressed: onToggleExpanded,
            ),
          _CodeIconButton(
            tooltip: '复制',
            icon: Icons.copy_rounded,
            color: mutedColor,
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

class _CodeIconButton extends StatelessWidget {
  const _CodeIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      icon: Icon(
        icon,
        size: 16,
        color: onPressed == null ? color.withValues(alpha: 0.32) : color,
      ),
      onPressed: onPressed,
    );
  }
}

class _CodeTextBody extends StatelessWidget {
  const _CodeTextBody({
    required this.code,
    required this.language,
    required this.theme,
    required this.backgroundColor,
    required this.wrap,
    required this.collapsed,
  });

  final String code;
  final String language;
  final _ResolvedCodeTheme theme;
  final Color backgroundColor;
  final bool wrap;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final lineCount = code.isEmpty ? 1 : '\n'.allMatches(code).length + 1;
        final gutterWidth = (lineCount.toString().length * 7.0 + 18)
            .clamp(30.0, 54.0)
            .toDouble();
        final baseStyle = TextStyle(
          color: theme.foreground.withValues(alpha: 0.96),
          fontSize: 13,
          height: 1.5,
          letterSpacing: 0,
          fontFamily: 'monospace',
        );
        final codeText = SelectableText.rich(
          _highlightCode(
            code: code,
            language: language,
            theme: theme,
            baseStyle: baseStyle,
          ),
        );
        final lineNumbers = List.generate(lineCount, (index) => '${index + 1}')
            .join('\n');
        Widget codePane;
        if (wrap) {
          codePane = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: gutterWidth,
                child: Text(
                  lineNumbers,
                  textAlign: TextAlign.right,
                  style: baseStyle.copyWith(
                    color: theme.gutter.withValues(alpha: 0.62),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: codeText),
            ],
          );
        } else {
          final minCodeWidth = constraints.maxWidth.isFinite
              ? (constraints.maxWidth - gutterWidth - 48)
                  .clamp(0, double.infinity)
                  .toDouble()
              : 0.0;
          codePane = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: gutterWidth,
                  child: Text(
                    lineNumbers,
                    textAlign: TextAlign.right,
                    style: baseStyle.copyWith(
                      color: theme.gutter.withValues(alpha: 0.62),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: minCodeWidth),
                  child: codeText,
                ),
              ],
            ),
          );
        }
        Widget body = Padding(
          padding: const EdgeInsets.fromLTRB(10, 11, 12, 12),
          child: codePane,
        );
        if (collapsed) {
          body = SizedBox(
            height: 320,
            child: Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(child: body),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 28,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            backgroundColor.withValues(alpha: 0.96),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return body;
      },
    );
  }
}

class _ResolvedCodeTheme {
  const _ResolvedCodeTheme({
    required this.background,
    required this.foreground,
    required this.comment,
    required this.string,
    required this.number,
    required this.keyword,
    required this.type,
    required this.function,
    required this.operator,
    required this.gutter,
  });

  final Color background;
  final Color foreground;
  final Color comment;
  final Color string;
  final Color number;
  final Color keyword;
  final Color type;
  final Color function;
  final Color operator;
  final Color gutter;
}

_ResolvedCodeTheme _resolvedCodeTheme({
  required String themeId,
  required int customBackgroundValue,
  required Color fallbackBackground,
  required Color fallbackText,
  required Color fallbackMuted,
}) {
  final option = codeThemeById(themeId);
  final customBackground = customBackgroundValue == 0
      ? null
      : Color(0xFF000000 | (customBackgroundValue & 0x00FFFFFF));
  final background = customBackground ?? option.background ?? fallbackBackground;
  final foreground = option.foreground ??
      (customBackground == null ? fallbackText : _readableCodeText(background));
  final muted = fallbackMuted;
  return _ResolvedCodeTheme(
    background: background,
    foreground: foreground,
    comment: option.comment ?? muted.withValues(alpha: 0.82),
    string: option.string ?? foreground.withValues(alpha: 0.86),
    number: option.number ?? foreground.withValues(alpha: 0.86),
    keyword: option.keyword ?? foreground,
    type: option.type ?? foreground.withValues(alpha: 0.90),
    function: option.function ?? foreground.withValues(alpha: 0.92),
    operator: option.operator ?? foreground.withValues(alpha: 0.72),
    gutter: option.gutter ?? muted.withValues(alpha: 0.70),
  );
}

Color _readableCodeText(Color background) {
  return background.computeLuminance() > 0.45
      ? const Color(0xFF1F1F1F)
      : const Color(0xFFF3F3F3);
}

TextSpan _highlightCode({
  required String code,
  required String language,
  required _ResolvedCodeTheme theme,
  required TextStyle baseStyle,
}) {
  final spans = <TextSpan>[];
  final pattern = RegExp(
    '("""[\\s\\S]*?"""|\\\'\\\'\\\'[\\s\\S]*?\\\'\\\'\\\'|'
    '"(?:\\\\.|[^"\\\\])*"|\\\'(?:\\\\.|[^\\\'\\\\])*\\\'|'
    '//[^\\n]*|/\\*[\\s\\S]*?\\*/|#[^\\n]*|'
    '\\b\\d+(?:\\.\\d+)?\\b|\\b[A-Za-z_\\\$][\\w\\\$]*\\b|'
    '[{}()[\\];,.<>:+\\-*/%=!&|^~?]+)',
    multiLine: true,
  );
  var cursor = 0;
  for (final match in pattern.allMatches(code)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: code.substring(cursor, match.start)));
    }
    final token = match[0] ?? '';
    spans.add(
      TextSpan(
        text: token,
        style: baseStyle.copyWith(
          color: _tokenColor(
            token: token,
            code: code,
            end: match.end,
            language: language,
            theme: theme,
          ),
          fontWeight: _tokenWeight(token, language),
        ),
      ),
    );
    cursor = match.end;
  }
  if (cursor < code.length) {
    spans.add(TextSpan(text: code.substring(cursor)));
  }
  return TextSpan(style: baseStyle, children: spans);
}

Color _tokenColor({
  required String token,
  required String code,
  required int end,
  required String language,
  required _ResolvedCodeTheme theme,
}) {
  final normalized = language.toLowerCase();
  if (_isCommentToken(token, normalized)) {
    return theme.comment;
  }
  if (_isStringToken(token)) {
    return theme.string;
  }
  if (RegExp(r'^\d').hasMatch(token)) {
    return theme.number;
  }
  if (RegExp(r'^[{}()[\];,.<>:+\-*/%=!&|^~?]+$').hasMatch(token)) {
    return theme.operator;
  }
  final keywordToken = normalized == 'sql' ? token.toLowerCase() : token;
  if (_keywordsFor(normalized).contains(keywordToken)) {
    return theme.keyword;
  }
  if (_typeWords.contains(token) ||
      RegExp(r'^[A-Z][A-Za-z0-9_]*$').hasMatch(token)) {
    return theme.type;
  }
  final after = code.substring(end).trimLeft();
  if (after.startsWith('(')) {
    return theme.function;
  }
  return theme.foreground;
}

FontWeight _tokenWeight(String token, String language) {
  final normalized = language.toLowerCase();
  final keywordToken = normalized == 'sql' ? token.toLowerCase() : token;
  if (_keywordsFor(normalized).contains(keywordToken)) {
    return FontWeight.w600;
  }
  return FontWeight.w400;
}

bool _isStringToken(String token) {
  return token.startsWith('"') ||
      token.startsWith("'") ||
      token.startsWith('"""') ||
      token.startsWith("'''");
}

bool _isCommentToken(String token, String language) {
  if (token.startsWith('//') || token.startsWith('/*')) {
    return true;
  }
  if (!token.startsWith('#')) {
    return false;
  }
  return {
    'python',
    'py',
    'ruby',
    'rb',
    'shell',
    'bash',
    'sh',
    'zsh',
    'yaml',
    'yml',
    'toml',
    'ini',
    'dockerfile',
  }.contains(language);
}

Set<String> _keywordsFor(String language) {
  const common = {
    'as',
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'do',
    'else',
    'enum',
    'export',
    'extends',
    'false',
    'final',
    'finally',
    'for',
    'from',
    'function',
    'if',
    'import',
    'in',
    'is',
    'let',
    'new',
    'null',
    'return',
    'static',
    'super',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'var',
    'void',
    'while',
    'with',
    'yield',
  };
  const python = {
    'and',
    'as',
    'assert',
    'async',
    'await',
    'break',
    'class',
    'continue',
    'def',
    'del',
    'elif',
    'else',
    'except',
    'False',
    'finally',
    'for',
    'from',
    'global',
    'if',
    'import',
    'in',
    'is',
    'lambda',
    'None',
    'nonlocal',
    'not',
    'or',
    'pass',
    'raise',
    'return',
    'True',
    'try',
    'while',
    'with',
    'yield',
  };
  const sql = {
    'select',
    'from',
    'where',
    'join',
    'left',
    'right',
    'inner',
    'outer',
    'group',
    'by',
    'order',
    'insert',
    'update',
    'delete',
    'create',
    'alter',
    'drop',
    'table',
    'into',
    'values',
    'and',
    'or',
    'not',
    'null',
    'limit',
    'offset',
    'having',
    'distinct',
  };
  if (language == 'python' || language == 'py') {
    return python;
  }
  if (language == 'sql') {
    return sql;
  }
  return common;
}

const _typeWords = {
  'String',
  'int',
  'double',
  'bool',
  'num',
  'List',
  'Map',
  'Set',
  'Future',
  'Stream',
  'Widget',
  'State',
  'BuildContext',
  'Object',
  'dynamic',
  'void',
  'number',
  'boolean',
  'unknown',
  'never',
  'Promise',
  'Record',
};

class _SvgPreview extends StatelessWidget {
  const _SvgPreview({
    required this.svg,
    required this.mutedColor,
    required this.backgroundColor,
  });

  final String svg;
  final Color mutedColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      alignment: Alignment.center,
      color: backgroundColor,
      child: SizedBox(
        height: 220,
        child: SvgPicture.string(
          svg,
          fit: BoxFit.contain,
          placeholderBuilder: (context) => SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: mutedColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkdownTable extends StatelessWidget {
  const _MarkdownTable({
    required this.table,
    required this.textColor,
    required this.mutedColor,
    required this.backgroundColor,
    required this.isUser,
  });

  final _ParsedTable table;
  final Color textColor;
  final Color mutedColor;
  final Color backgroundColor;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final fill = isUser
        ? textColor.withValues(alpha: 0.10)
        : backgroundColor.withValues(alpha: 0.96);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: mutedColor.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: mutedColor.withValues(alpha: 0.14),
                ),
              ),
              children: [
                _tableRow(table.header, true),
                for (final row in table.rows) _tableRow(row, false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TableRow _tableRow(List<String> cells, bool header) {
    return TableRow(
      decoration: header
          ? BoxDecoration(color: textColor.withValues(alpha: 0.045))
          : null,
      children: [
        for (var index = 0; index < table.columnCount; index += 1)
          Container(
            constraints: const BoxConstraints(minWidth: 82, maxWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Text(
              index < cells.length ? cells[index] : '',
              softWrap: true,
              style: TextStyle(
                color: header ? textColor : textColor.withValues(alpha: 0.88),
                fontSize: header ? 13.5 : 13.2,
                height: 1.36,
                fontWeight: header ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0,
              ),
            ),
          ),
      ],
    );
  }
}

enum _MessageBlockKind { markdown, displayMath, code, table }

class _MessageBlock {
  const _MessageBlock.markdown(this.text)
      : kind = _MessageBlockKind.markdown,
        source = text,
        language = '',
        table = null;

  const _MessageBlock.displayMath({
    required this.text,
    required this.source,
  })  : kind = _MessageBlockKind.displayMath,
        language = '',
        table = null;

  const _MessageBlock.code({
    required this.text,
    required this.language,
  })  : kind = _MessageBlockKind.code,
        source = text,
        table = null;

  const _MessageBlock.table(this.table)
      : kind = _MessageBlockKind.table,
        text = '',
        source = '',
        language = '';

  final _MessageBlockKind kind;
  final String text;
  final String source;
  final String language;
  final _ParsedTable? table;
}

class _ParsedTable {
  const _ParsedTable({
    required this.header,
    required this.rows,
  });

  final List<String> header;
  final List<List<String>> rows;

  int get columnCount {
    var count = header.length;
    for (final row in rows) {
      if (row.length > count) {
        count = row.length;
      }
    }
    return count;
  }
}

List<_MessageBlock> _parseMessageBlocks(String source) {
  final standalone = _standaloneStructuredBlock(source);
  if (standalone != null) {
    return [standalone];
  }

  final normalized = source.replaceAll('\r\n', '\n');
  final lines = normalized.split('\n');
  final blocks = <_MessageBlock>[];
  final buffer = StringBuffer();
  var index = 0;

  void flushText() {
    if (buffer.isEmpty) {
      return;
    }
    final text = buffer.toString();
    for (final block in _splitDisplayMath(text)) {
      blocks.add(block);
    }
    buffer.clear();
  }

  while (index < lines.length) {
    final line = lines[index];
    final fence = _openingFence(line);
    if (fence != null) {
      flushText();
      final codeLines = <String>[];
      index += 1;
      while (index < lines.length && !_closingFence(lines[index], fence)) {
        codeLines.add(lines[index]);
        index += 1;
      }
      if (index < lines.length) {
        index += 1;
      }
      final code = codeLines.join('\n').trimRight();
      blocks.add(
        _MessageBlock.code(
          text: _normalizeCodeForLanguage(code, fence.language),
          language: fence.language,
        ),
      );
      continue;
    }

    if (_isTableStart(lines, index)) {
      flushText();
      final tableLines = <String>[];
      while (index < lines.length && _couldBeTableLine(lines[index])) {
        tableLines.add(lines[index]);
        index += 1;
      }
      final parsed = _parseTable(tableLines);
      if (parsed == null) {
        buffer.writeln(tableLines.join('\n'));
      } else {
        blocks.add(_MessageBlock.table(parsed));
      }
      continue;
    }

    buffer.writeln(line);
    index += 1;
  }

  flushText();
  return blocks.where((block) {
    if (block.kind != _MessageBlockKind.markdown) {
      return true;
    }
    return block.text.trim().isNotEmpty;
  }).toList();
}

_MessageBlock? _standaloneStructuredBlock(String source) {
  final trimmed = source.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
      (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
    try {
      return _MessageBlock.code(
        text: prettyJson(jsonDecode(trimmed)),
        language: 'json',
      );
    } catch (_) {
      return null;
    }
  }
  if (_looksLikeSvg(trimmed)) {
    return _MessageBlock.code(text: trimmed, language: 'svg');
  }
  if (_looksLikeXml(trimmed)) {
    return _MessageBlock.code(text: trimmed, language: 'xml');
  }
  return null;
}

List<_MessageBlock> _splitDisplayMath(String source) {
  final blocks = <_MessageBlock>[];
  final buffer = StringBuffer();
  var index = 0;

  void flushText() {
    if (buffer.isEmpty) {
      return;
    }
    final text = buffer.toString();
    if (text.trim().isNotEmpty) {
      blocks.add(_MessageBlock.markdown(text));
    }
    buffer.clear();
  }

  while (index < source.length) {
    if (source.startsWith(r'$$', index)) {
      final end = source.indexOf(r'$$', index + 2);
      if (end != -1) {
        flushText();
        blocks.add(
          _MessageBlock.displayMath(
            text: source.substring(index + 2, end).trim(),
            source: source.substring(index, end + 2),
          ),
        );
        index = end + 2;
        continue;
      }
    }
    if (source.startsWith(r'\[', index)) {
      final end = source.indexOf(r'\]', index + 2);
      if (end != -1) {
        flushText();
        blocks.add(
          _MessageBlock.displayMath(
            text: source.substring(index + 2, end).trim(),
            source: source.substring(index, end + 2),
          ),
        );
        index = end + 2;
        continue;
      }
    }
    buffer.write(source[index]);
    index += 1;
  }

  flushText();
  return blocks;
}

class _Fence {
  const _Fence({
    required this.marker,
    required this.length,
    required this.language,
  });

  final String marker;
  final int length;
  final String language;
}

_Fence? _openingFence(String line) {
  final trimmedLeft = line.trimLeft();
  if (line.length - trimmedLeft.length > 3) {
    return null;
  }
  if (!trimmedLeft.startsWith('```') && !trimmedLeft.startsWith('~~~')) {
    return null;
  }
  final marker = trimmedLeft[0];
  var count = 0;
  while (count < trimmedLeft.length && trimmedLeft[count] == marker) {
    count += 1;
  }
  if (count < 3) {
    return null;
  }
  final info = trimmedLeft.substring(count).trim();
  final language = info.split(RegExp(r'\s+')).first.trim();
  return _Fence(marker: marker, length: count, language: language);
}

bool _closingFence(String line, _Fence fence) {
  final trimmed = line.trim();
  var count = 0;
  while (count < trimmed.length && trimmed[count] == fence.marker) {
    count += 1;
  }
  if (count < fence.length) {
    return false;
  }
  return trimmed.substring(count).trim().isEmpty;
}

bool _isTableStart(List<String> lines, int index) {
  if (index + 1 >= lines.length) {
    return false;
  }
  return _couldBeTableLine(lines[index]) && _isTableSeparator(lines[index + 1]);
}

bool _couldBeTableLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || !trimmed.contains('|')) {
    return false;
  }
  return _splitTableCells(trimmed).length >= 2;
}

bool _isTableSeparator(String line) {
  final cells = _splitTableCells(line);
  if (cells.length < 2) {
    return false;
  }
  return cells.every(
    (cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell.replaceAll(' ', '')),
  );
}

_ParsedTable? _parseTable(List<String> lines) {
  if (lines.length < 2 || !_isTableSeparator(lines[1])) {
    return null;
  }
  final header = _splitTableCells(lines.first);
  final rows = <List<String>>[];
  for (var index = 2; index < lines.length; index += 1) {
    final cells = _splitTableCells(lines[index]);
    if (cells.isNotEmpty) {
      rows.add(cells);
    }
  }
  return _ParsedTable(header: header, rows: rows);
}

List<String> _splitTableCells(String line) {
  var value = line.trim();
  if (value.startsWith('|')) {
    value = value.substring(1);
  }
  if (value.endsWith('|')) {
    value = value.substring(0, value.length - 1);
  }
  return value.split('|').map((cell) => cell.trim()).toList();
}

String _normalizeCodeForLanguage(String code, String language) {
  final normalized = _normalizeLanguage(language);
  if (normalized == 'json') {
    try {
      return prettyJson(jsonDecode(code));
    } catch (_) {
      return code;
    }
  }
  return code;
}

String _languageLabel(String explicit, String code) {
  final normalized = _normalizeLanguage(explicit);
  if (normalized.isNotEmpty && normalized != 'code') {
    return _prettyLanguage(normalized);
  }
  return _prettyLanguage(_detectLanguage(code));
}

String _normalizeLanguage(String language) {
  final value = language.trim().toLowerCase();
  if (value.isEmpty) {
    return '';
  }
  const aliases = {
    'js': 'javascript',
    'jsx': 'javascript',
    'mjs': 'javascript',
    'ts': 'typescript',
    'tsx': 'typescript',
    'py': 'python',
    'rb': 'ruby',
    'kt': 'kotlin',
    'kts': 'kotlin',
    'sh': 'shell',
    'bash': 'shell',
    'zsh': 'shell',
    'yml': 'yaml',
    'md': 'markdown',
    'htm': 'html',
    'text': 'code',
    'txt': 'code',
  };
  return aliases[value] ?? value;
}

String _detectLanguage(String code) {
  final trimmed = code.trim();
  final lower = trimmed.toLowerCase();
  if (trimmed.isEmpty) {
    return 'code';
  }
  if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
      (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
    try {
      jsonDecode(trimmed);
      return 'json';
    } catch (_) {
      // Continue with the lighter heuristics below.
    }
  }
  if (_looksLikeSvg(trimmed)) {
    return 'svg';
  }
  if (_looksLikeXml(trimmed)) {
    return 'xml';
  }
  if (lower.contains('import flutter') ||
      lower.contains("package:flutter") ||
      RegExp(r'\bwidget\s+build\s*\(').hasMatch(lower)) {
    return 'dart';
  }
  if (RegExp(r'\bfun\s+\w+\s*\(').hasMatch(trimmed) ||
      RegExp(r'^\s*val\s+\w+\s*[:=]', multiLine: true).hasMatch(trimmed)) {
    return 'kotlin';
  }
  if (lower.contains('import swiftui') ||
      (lower.contains('struct ') && lower.contains(': view'))) {
    return 'swift';
  }
  if (RegExp(r'\bdef\s+\w+\s*\(').hasMatch(trimmed) ||
      RegExp(r'^\s*from\s+\w+\s+import\s+', multiLine: true).hasMatch(trimmed)) {
    return 'python';
  }
  if (RegExp(r'\b(const|let|var)\s+\w+\s*=').hasMatch(trimmed) ||
      trimmed.contains('=>') ||
      RegExp(r'\bfunction\s+\w*\s*\(').hasMatch(trimmed)) {
    return 'javascript';
  }
  if (RegExp(r'\bselect\b[\s\S]+\bfrom\b', caseSensitive: false)
      .hasMatch(trimmed)) {
    return 'sql';
  }
  if (RegExp(r'^[\w.#:\-\s]+\{[\s\S]*;[\s\S]*\}$').hasMatch(trimmed)) {
    return 'css';
  }
  if (trimmed.startsWith('#!/bin/') ||
      RegExp(r'^\s*(npm|pnpm|yarn|git|curl|cd|ls|mkdir)\s+', multiLine: true)
          .hasMatch(trimmed)) {
    return 'shell';
  }
  if (_looksLikeYaml(trimmed)) {
    return 'yaml';
  }
  return 'code';
}

String _prettyLanguage(String language) {
  final normalized = _normalizeLanguage(language);
  const labels = {
    'javascript': 'JavaScript',
    'typescript': 'TypeScript',
    'python': 'Python',
    'dart': 'Dart',
    'kotlin': 'Kotlin',
    'swift': 'Swift',
    'java': 'Java',
    'json': 'JSON',
    'yaml': 'YAML',
    'xml': 'XML',
    'svg': 'SVG',
    'html': 'HTML',
    'css': 'CSS',
    'shell': 'Shell',
    'sql': 'SQL',
    'markdown': 'Markdown',
    'ruby': 'Ruby',
    'code': 'Code',
  };
  if (normalized.isEmpty) {
    return 'Code';
  }
  return labels[normalized] ??
      '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

bool _isSvgLanguage(String language) =>
    _normalizeLanguage(language) == 'svg' || language.toLowerCase() == 'svg';

bool _looksLikeSvg(String value) {
  final lower = value.trimLeft().toLowerCase();
  return lower.startsWith('<svg') ||
      (lower.startsWith('<?xml') && lower.contains('<svg'));
}

bool _looksLikeXml(String value) {
  final trimmed = value.trimLeft();
  if (!trimmed.startsWith('<') || !trimmed.endsWith('>')) {
    return false;
  }
  final lower = trimmed.toLowerCase();
  return RegExp(r'^<\??[a-z!][\s\S]*>$').hasMatch(lower);
}

bool _looksLikeYaml(String value) {
  final lines = value.split('\n').where((line) => line.trim().isNotEmpty);
  var keyLines = 0;
  for (final line in lines.take(10)) {
    if (RegExp(r'^\s*[\w.-]+\s*:\s*.+$').hasMatch(line)) {
      keyLines += 1;
    }
  }
  return keyLines >= 2;
}

bool _isSafeSvg(String source) {
  if (source.length > 220000 || !_looksLikeSvg(source)) {
    return false;
  }
  final lower = source.toLowerCase();
  final bannedTags = [
    '<script',
    '<foreignobject',
    '<iframe',
    '<object',
    '<embed',
    '<audio',
    '<video',
    '<canvas',
    '<use',
  ];
  for (final tag in bannedTags) {
    if (lower.contains(tag)) {
      return false;
    }
  }
  final bannedPatterns = [
    RegExp(r'\son[a-z]+\s*=', caseSensitive: false),
    RegExp(r'javascript\s*:', caseSensitive: false),
    RegExp(
      '\\b(?:href|src|xlink:href)\\s*=\\s*["\\\']\\s*(?:https?:|//|data:)',
      caseSensitive: false,
    ),
  ];
  return !bannedPatterns.any((pattern) => pattern.hasMatch(source));
}
