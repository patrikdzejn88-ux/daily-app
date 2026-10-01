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
  });

  final Task task;
  final ValueChanged<Task> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rank = task.rank;
    final expired = !task.daily &&
        task.date != null &&
        task.date!.isBefore(_today) &&
        !task.done;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: task.done
            ? SoloColors.surface.withValues(alpha: 0.5)
            : SoloColors.surface,
        border: Border.all(
          color: task.done ? SoloColors.done : SoloColors.border,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => onToggle(task),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Ранговая плашка
              Container(
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        color: task.done
                            ? SoloColors.textSecondary
                            : SoloColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration:
                            task.done ? TextDecoration.lineThrough : null,
                        decorationColor: SoloColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle(task),
                      style: TextStyle(
                        color: expired
                            ? SoloColors.danger
                            : (task.done &&
                                    !_isToday(task) &&
                                    task.date != null)
                                ? SoloColors.done
                                : SoloColors.textDim,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Статус/удаление
              if (task.done)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_circle,
                      color: SoloColors.done, size: 22),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.radio_button_unchecked,
                      color: SoloColors.border, size: 22),
                ),
              GestureDetector(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close,
                      color: SoloColors.textDim, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static bool _isToday(Task t) {
    final n = DateTime.now();
    return t.date != null &&
        t.date!.year == n.year &&
        t.date!.month == n.month &&
        t.date!.day == n.day;
  }

  String _subtitle(Task t) {
    if (t.daily) {
      return t.done
          ? 'Ежедневный · завершён'
          : 'Ежедневный квест · +${t.rank.exp} EXP';
    }
    if (t.date == null) {
      return t.done ? '+${t.rank.exp} EXP' : 'Без даты · +${t.rank.exp} EXP';
    }
    final d = t.date!;
    final parts = <String>[
      '${_pad(d.day)}.${_pad(d.month)}.${d.year}',
    ];
    parts.add('+${t.rank.exp} EXP');
    if (t.done) parts.add('· завершён');
    return parts.join(' ');
  }

  String _pad(int v) => v.toString().padLeft(2, '0');
}
