import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme/solo_colors.dart';

/// Карточка одного квеста с рангом сбоку.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.today,
  });

  final Task task;
  final ValueChanged<Task> onToggle;
  final VoidCallback onDelete;

  /// «Сегодня», обрезанное до дня. Передаётся снаружи (контракт),
  /// чтобы плитка не вычисляла дату сама.
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final rank = task.rank;
    final doneOn = task.isDoneOn(today);

    // День назначения квеста (без времени) — для корректных сравнений.
    final taskDay = task.date == null
        ? null
        : DateTime(task.date!.year, task.date!.month, task.date!.day);

    // Одноразовый квест на будущую дату — выполнять раньше срока нельзя.
    final locked = !task.daily && taskDay != null && taskDay.isAfter(today);
    // Просроченный одноразовый квест (дата прошла, квест не выполнен).
    final expired =
        !task.daily && taskDay != null && taskDay.isBefore(today) && !doneOn;

    final stateLabel = doneOn
        ? 'выполнен'
        : (locked ? 'заблокирован' : 'активен');

    return Opacity(
      // Будущие квесты приглушены — они пока недоступны.
      opacity: locked ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: doneOn
              ? SoloColors.surface.withValues(alpha: 0.5)
              : SoloColors.surface,
          border: Border.all(
            color: doneOn ? SoloColors.done : SoloColors.border,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Semantics(
          button: true,
          enabled: !locked,
          label: 'Квест ${task.title}, ранг ${rank.label}, $stateLabel',
          child: InkWell(
            // Заблокированный квест по статусу не кликабелен.
            onTap: locked ? null : () => onToggle(task),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Ранговая плашка
                  ExcludeSemantics(
                    child: Container(
                      width: 40,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rank.color.withValues(alpha: 0.15),
                        border: Border.all(color: rank.color, width: 1.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rank.label,
                        style: TextStyle(
                          color: rank.color,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          shadows: [
                            Shadow(
                              color: rank.color.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              color: doneOn
                                  ? SoloColors.textSecondary
                                  : SoloColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: doneOn
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: SoloColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _subtitle(doneOn, locked, expired),
                            style: TextStyle(
                              color: expired
                                  ? SoloColors.danger
                                  : (task.daily && !doneOn)
                                  ? SoloColors.danger
                                  : SoloColors.textDim,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Статус квеста
                  ExcludeSemantics(child: _statusIcon(doneOn, locked)),
                  // Удаление — с подтверждением, мишень не меньше 48dp.
                  Semantics(
                    container: true,
                    button: true,
                    label: 'Удалить квест',
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: SoloColors.textDim,
                        size: 20,
                      ),
                      tooltip: 'Удалить квест',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      visualDensity: VisualDensity.compact,
                      splashRadius: 22,
                      onPressed: () => _confirmDelete(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Иконка статуса: выполнен / заблокирован до даты / активен.
  Widget _statusIcon(bool doneOn, bool locked) {
    final IconData icon;
    final Color color;
    if (doneOn) {
      icon = Icons.check_circle;
      color = SoloColors.done;
    } else if (locked) {
      icon = Icons.lock_outline;
      color = SoloColors.textDim;
    } else {
      icon = Icons.radio_button_unchecked;
      color = SoloColors.border;
    }
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Icon(icon, color: color, size: 22),
    );
  }

  /// Диалог подтверждения удаления в стиле System-окна.
  /// widget.onDelete вызывается только после подтверждения.
  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: SoloColors.background.withValues(alpha: 0.8),
      builder: (ctx) => AlertDialog(
        backgroundColor: SoloColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: SoloColors.borderGlow),
        ),
        title: const Text(
          'SYSTEM',
          style: TextStyle(
            color: SoloColors.neonBlue,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        content: Text(
          'Удалить квест «${task.title}»? Прогресс Hunter сохранится.',
          style: const TextStyle(
            color: SoloColors.textPrimary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'ОТМЕНА',
              style: TextStyle(color: SoloColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'УДАЛИТЬ',
              style: TextStyle(
                color: SoloColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }

  String _subtitle(bool doneOn, bool locked, bool expired) {
    if (task.daily) {
      return doneOn
          ? 'Ежедневный · выполнено +${task.rank.exp} EXP'
          : 'Ежедневный · не выполнено −${task.rank.exp} EXP';
    }
    if (task.date == null) {
      return doneOn
          ? '+${task.rank.exp} EXP'
          : 'Без даты · +${task.rank.exp} EXP';
    }
    final d = task.date!;
    final dateStr = '${_pad(d.day)}.${_pad(d.month)}.${d.year}';
    if (locked) {
      return 'ДОСТУПЕН $dateStr · +${task.rank.exp} EXP';
    }
    final parts = <String>[dateStr, '+${task.rank.exp} EXP'];
    if (doneOn) {
      parts.add('· завершён');
    } else if (expired) {
      parts.add('· ПРОСРОЧЕН');
    }
    return parts.join(' ');
  }

  String _pad(int v) => v.toString().padLeft(2, '0');
}
