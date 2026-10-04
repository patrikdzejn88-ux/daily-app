import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../theme/solo_colors.dart';

/// Диалог создания квеста. Фасад-функция — внешний контракт не меняется.
Future<Task?> showAddTaskDialog(BuildContext context) {
  return showDialog<Task>(
    context: context,
    barrierColor: SoloColors.background.withValues(alpha: 0.8),
    builder: (_) => const AddTaskDialog(),
  );
}

/// Диалог создания квеста. StatefulWidget — контроллер корректно
/// dispose'ится, состояние живёт в State, а не в StatefulBuilder.
class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({super.key});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final TextEditingController _controller = TextEditingController();
  TaskRank _selected = TaskRank.e;
  DateTime? _date;
  bool _daily = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
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
    // Диалог могли закрыть, пока выбирали дату.
    if (!mounted) return;
    if (picked != null) setState(() => _date = picked);
  }

  /// Создать квест (кнопка «Создать» или Enter в поле названия).
  /// Пустое название диалог не закрывает.
  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(
      context,
      Task(
        title: title,
        rank: _selected,
        date: _daily ? null : _date,
        daily: _daily,
        done: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(color: SoloColors.textPrimary),
              cursorColor: SoloColors.neonCyan,
              decoration: const InputDecoration(
                hintText: 'Название квеста',
                hintStyle: TextStyle(color: SoloColors.textDim),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: SoloColors.border),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: SoloColors.borderGlow),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Выбор ранга
            Wrap(
              spacing: 8,
              children: [for (final r in TaskRank.values) _rankChip(r)],
            ),
            const SizedBox(height: 16),
            // Дата vs ежедневный
            Row(
              children: [
                Expanded(
                  child: _optionButton(
                    label: _date == null
                        ? 'На дату'
                        : DateFormat('dd.MM.yyyy').format(_date!),
                    active: !_daily && _date != null,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _optionButton(
                    label: 'Ежедневный',
                    active: _daily,
                    onTap: () => setState(() => _daily = !_daily),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Отмена',
            style: TextStyle(color: SoloColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text(
            'Создать',
            style: TextStyle(
              color: SoloColors.neonCyan,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  /// Ранговый чип 48×48dp с ripple и семантикой выбора.
  Widget _rankChip(TaskRank r) {
    final active = r == _selected;
    return Semantics(
      button: true,
      selected: active,
      label: 'Ранг ${r.label}',
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: () => setState(() => _selected = r),
          containedInkWell: true,
          highlightShape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 48,
            height: 48,
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
              style: TextStyle(color: r.color, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  /// Кнопка периода («На дату» / «Ежедневный»): высота от 48dp, ripple.
  Widget _optionButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active
          ? SoloColors.neonBlue.withValues(alpha: 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
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
      ),
    );
  }
}
