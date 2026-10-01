import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../theme/solo_colors.dart';

/// Диалог создания квеста.
Future<Task?> showAddTaskDialog(BuildContext context) async {
  final controller = TextEditingController();
  TaskRank selected = TaskRank.e;
  DateTime? date;
  bool daily = false;

  return showDialog<Task>(
    context: context,
    barrierColor: SoloColors.background.withValues(alpha: 0.8),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> pickDate() async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: ctx,
              initialDate: date ?? now,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 3),
              builder: (_, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: SoloColors.neonBlue,
                    surface: SoloColors.surface,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) setState(() => date = picked);
          }

          return AlertDialog(
            backgroundColor: SoloColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: SoloColors.borderGlow),
            ),
            title: const Text(
              'NEW QUEST',
              style: TextStyle(
                color: SoloColors.neonBlue,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: SoloColors.textPrimary),
                    cursorColor: SoloColors.neonCyan,
                    decoration: const InputDecoration(
                      hintText: 'Название квеста',
                      hintStyle:
                          TextStyle(color: SoloColors.textDim),
                      enabledBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: SoloColors.border),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: SoloColors.borderGlow),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Выбор ранга
                  Wrap(
                    spacing: 8,
                    children: TaskRank.values.map((r) {
                      final active = r == selected;
                      return GestureDetector(
                        onTap: () => setState(() => selected = r),
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: active
                                ? r.color.withValues(alpha: 0.25)
                                : Colors.transparent,
                            border: Border.all(
                              color: active ? r.color : SoloColors.border,
                              width: active ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            r.label,
                            style: TextStyle(
                              color: r.color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Дата vs ежедневный
                  Row(
                    children: [
                      Expanded(
                        child: _optionButton(
                          label: date == null ? 'На дату' : DateFormat(
                                  'dd.MM.yyyy')
                              .format(date!),
                          active: !daily && date != null,
                          onTap: pickDate,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _optionButton(
                          label: 'Ежедневный',
                          active: daily,
                          onTap: () => setState(() => daily = !daily),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена',
                    style: TextStyle(color: SoloColors.textSecondary)),
              ),
              TextButton(
                onPressed: () {
                  final title = controller.text.trim();
                  if (title.isEmpty) return;
                  Navigator.pop(
                    ctx,
                    Task(
                      title: title,
                      rank: selected,
                      date: daily ? null : date,
                      daily: daily,
                      done: false,
                      createdAt: DateTime.now(),
                    ),
                  );
                },
                child: const Text('Создать',
                    style: TextStyle(
                        color: SoloColors.neonCyan,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _optionButton({
  required String label,
  required bool active,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? SoloColors.neonBlue.withValues(alpha: 0.15)
            : Colors.transparent,
        border: Border.all(
          color: active ? SoloColors.neonBlue : SoloColors.border,
          width: active ? 1.2 : 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: active ? SoloColors.neonCyan : SoloColors.textSecondary,
          fontSize: 13,
        ),
      ),
    ),
  );
}
