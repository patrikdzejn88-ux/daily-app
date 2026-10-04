import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/solo_colors.dart';

/// Одна запись в очереди системных сообщений.
class _SystemMsg {
  const _SystemMsg({
    required this.id,
    required this.title,
    required this.message,
    required this.color,
  });

  final int id;
  final String title;
  final String message;
  final Color color;
}

/// Очередь активных сообщений: одновременно видно не больше
/// [maxVisible], лишние вытесняют старейшие (FIFO).
/// Живёт всё время приложения.
class _SystemMessageQueue extends ChangeNotifier {
  /// Максимум сообщений на экране одновременно.
  static const int maxVisible = 4;

  final List<_SystemMsg> items = [];
  int _nextId = 0;

  void push(String title, String message, Color color) {
    items.add(
      _SystemMsg(id: _nextId++, title: title, message: message, color: color),
    );
    // FIFO-вытеснение старейших сверх лимита.
    while (items.length > maxVisible) {
      items.removeAt(0);
    }
    notifyListeners();
  }

  void remove(int id) {
    final before = items.length;
    items.removeWhere((m) => m.id == id);
    if (items.length != before) notifyListeners();
  }
}

final _SystemMessageQueue _queue = _SystemMessageQueue();

/// Единый хост-оверлей для всех сообщений. Создаётся лениво при первом
/// сообщении и удаляется, когда очередь пустеет.
OverlayEntry? _hostEntry;

/// System-уведомление в стиле Solo Leveling — неоновое окно,
/// которое появляется поверх контента и само исчезает.
///
/// Сообщения стакаются вертикальной очередью (максимум 4, каждое живёт
/// 3 секунды с fade in/out), а не налезают друг на друга в одной точке.
void showSystemMessage(
  BuildContext context,
  String message, {
  String title = 'SYSTEM',
  Color color = SoloColors.neonBlue,
}) {
  if (_hostEntry == null) {
    final overlay = Overlay.of(context);
    _hostEntry = OverlayEntry(builder: (_) => const _SystemMessageHost());
    overlay.insert(_hostEntry!);
  }
  _queue.push(title, message, color);
}

/// Хост очереди: один постоянный OverlayEntry, внутри — колонка
/// активных сообщений. При исчезновении записи остальные смещаются вверх.
class _SystemMessageHost extends StatefulWidget {
  const _SystemMessageHost();

  @override
  State<_SystemMessageHost> createState() => _SystemMessageHostState();
}

class _SystemMessageHostState extends State<_SystemMessageHost> {
  @override
  void initState() {
    super.initState();
    _queue.addListener(_onQueueChanged);
  }

  @override
  void dispose() {
    _queue.removeListener(_onQueueChanged);
    super.dispose();
  }

  void _onQueueChanged() {
    if (!mounted) return;
    setState(() {});
    if (_queue.items.isEmpty) {
      // Очередь пуста — хост больше не нужен. Удаляем после кадра,
      // чтобы не дёргать оверлей посреди построения, и только если
      // за это время не пришло новое сообщение.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_queue.items.isEmpty && _hostEntry != null) {
          _hostEntry!.remove();
          _hostEntry = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      // Сообщения не перехватывают нажатия.
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final msg in _queue.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SystemMessage(
                  key: ValueKey(msg.id),
                  msg: msg,
                  onDismiss: () => _queue.remove(msg.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Одно неоновое сообщение: fade in, 3 секунды жизни, fade out,
/// затем удаляется из очереди через [onDismiss].
class _SystemMessage extends StatefulWidget {
  const _SystemMessage({super.key, required this.msg, required this.onDismiss});

  final _SystemMsg msg;
  final VoidCallback onDismiss;

  @override
  State<_SystemMessage> createState() => _SystemMessageState();
}

class _SystemMessageState extends State<_SystemMessage>
    with SingleTickerProviderStateMixin {
  static const Duration _fadeDuration = Duration(milliseconds: 300);
  static const Duration _lifetime = Duration(seconds: 3);

  late final AnimationController _controller;
  late final Animation<double> _fade;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _fadeDuration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.addStatusListener((status) {
      // Fade out завершён — убираем сообщение из очереди.
      if (status == AnimationStatus.dismissed) {
        widget.onDismiss();
      }
    });
    _controller.forward();
    _timer = Timer(_lifetime, () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SoloColors.surface.withValues(alpha: 0.97),
            border: Border.all(color: widget.msg.color, width: 1.2),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: widget.msg.color.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: widget.msg.color,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.msg.title,
                      style: TextStyle(
                        color: widget.msg.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.msg.message,
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
    );
  }
}
