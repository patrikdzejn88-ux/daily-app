import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/solo_colors.dart';

/// System-уведомление в стиле Solo Leveling — синее неоновое окно,
/// которое появляется поверх контента и само исчезает.
Future<void> showSystemMessage(
  BuildContext context, {
  required String message,
  String title = 'SYSTEM',
  Color color = SoloColors.neonBlue,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SystemMessage(
      title: title,
      message: message,
      color: color,
      onDismiss: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
  return Future.delayed(
    const Duration(seconds: 3),
    () {
      if (entry.mounted) entry.remove();
    },
  );
}

class _SystemMessage extends StatefulWidget {
  const _SystemMessage({
    required this.title,
    required this.message,
    required this.color,
    required this.onDismiss,
  });

  final String title;
  final String message;
  final Color color;
  final VoidCallback onDismiss;

  @override
  State<_SystemMessage> createState() => _SystemMessageState();
}

class _SystemMessageState extends State<_SystemMessage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _timer = Timer(const Duration(seconds: 3), widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SoloColors.surface.withValues(alpha: 0.97),
              border: Border.all(color: widget.color, width: 1.2),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: widget.color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: widget.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.message,
                        style: const TextStyle(
                          color: SoloColors.textPrimary,
                          fontSize: 14,
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
