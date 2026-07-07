import 'dart:async';

import 'package:flutter/material.dart';

OverlayEntry? _activeToast;

void showChaitToast(BuildContext context, String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty || !context.mounted) {
    return;
  }
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }
  _activeToast?.remove();
  _activeToast = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _ChaitToastOverlay(
      message: trimmed,
      onDismissed: () {
        if (_activeToast == entry) {
          _activeToast = null;
        }
        entry.remove();
      },
    ),
  );
  _activeToast = entry;
  overlay.insert(entry);
}

class _ChaitToastOverlay extends StatefulWidget {
  const _ChaitToastOverlay({
    required this.message,
    required this.onDismissed,
  });

  final String message;
  final VoidCallback onDismissed;

  @override
  State<_ChaitToastOverlay> createState() => _ChaitToastOverlayState();
}

class _ChaitToastOverlayState extends State<_ChaitToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  Timer? timer;
  bool dismissed = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 160),
    )..forward();
    timer = Timer(const Duration(milliseconds: 1350), _dismiss);
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (dismissed || !mounted) {
      return;
    }
    dismissed = true;
    await controller.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final top = media.padding.top + 58;
    final background = theme.colorScheme.surface.withValues(alpha: 0.94);
    final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.58);
    final borderColor = theme.colorScheme.outline.withValues(alpha: 0.14);
    final shadow = theme.brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.08);
    final curved = CurvedAnimation(
      parent: controller,
      curve: const Cubic(0.2, 0, 0, 1),
      reverseCurve: const Cubic(0.4, 0, 1, 1),
    );
    return Positioned(
      left: 18,
      right: 18,
      top: top,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: curved,
            child: AnimatedBuilder(
              animation: curved,
              builder: (context, child) {
                final value = curved.value;
                return Transform.translate(
                  offset: Offset(0, (1 - value) * -6),
                  child: Transform.scale(
                    scale: 0.98 + value * 0.02,
                    child: child,
                  ),
                );
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: media.size.width - 52,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: shadow,
                        blurRadius: 18,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Text(
                      widget.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12.5,
                        height: 1.25,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
