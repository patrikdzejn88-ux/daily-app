import 'package:flutter/material.dart';

import '../data/task_database.dart';
import '../models/task.dart';
import '../theme/solo_colors.dart';
import '../widgets/add_task_dialog.dart';
import '../widgets/hunter_level.dart';
import '../widgets/system_message.dart';
import '../widgets/task_tile.dart';

/// Главный экран квестов.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = TaskDatabase.instance;
  List<Task> _tasks = [];
  bool _loading = true;
  final _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await _db.getAll();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  Future<void> _addTask() async {
    final task = await showAddTaskDialog(context);
    if (task == null) return;
    final id = await _db.insert(task);
    if (!mounted) return;
    setState(() {
      _tasks.insert(
        0,
        Task.fromMap({...task.toMap(), 'id': id}),
      );
    });
    showSystemMessage(
      context,
      message: 'Квест принят: ${task.title}',
      title: 'SYSTEM',
      color: SoloColors.neonBlue,
    );
  }

  Future<void> _toggle(Task task) async {
    final nowDone = task.isDoneOn(_now);
    final updated =
        nowDone ? task.markNotDone() : task.markDoneOn(_now);
    await _db.update(updated);
    if (!mounted) return;
    setState(() {
      final i = _tasks.indexWhere((t) => t.id == task.id);
      if (i != -1) _tasks[i] = updated;
    });
    if (!nowDone) {
      showSystemMessage(
        context,
        message: '+${updated.rank.exp} EXP — ${updated.title}',
        title: 'QUEST CLEAR',
        color: SoloColors.neonCyan,
      );
    } else {
      showSystemMessage(
        context,
        message: 'Квест не выполнен: ${updated.title}',
        title: 'SYSTEM',
        color: SoloColors.textDim,
      );
    }
  }

  Future<void> _delete(Task task) async {
    await _db.delete(task.id!);
    if (!mounted) return;
    setState(() {
      _tasks.removeWhere((t) => t.id == task.id);
    });
    showSystemMessage(
      context,
      message: 'Квест удалён: ${task.title}',
      title: 'SYSTEM',
      color: SoloColors.danger,
    );
  }

  List<Task> get _dueTasks =>
      _tasks.where((t) => t.isDueOn(_now)).toList();

  /// Квесты, назначенные на другие даты (не сегодня), кроме ежедневных.
  List<Task> get _scheduledTasks {
    final list = _tasks
        .where((t) => !t.daily && t.date != null && !t.isDueOn(_now))
        .toList();
    list.sort((a, b) => a.date!.compareTo(b.date!));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final due = _dueTasks;
    final active = due.where((t) => !t.isDoneOn(_now));
    final done = due.where((t) => t.isDoneOn(_now));
    final scheduled = _scheduledTasks;
    final totalExp = HunterProgress.expForTasks(_tasks);

    return Scaffold(
      backgroundColor: SoloColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(totalExp: totalExp),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: SoloColors.neonBlue,
                      ),
                    )
                  : _taskList(
                      active: active.toList(),
                      done: done.toList(),
                      scheduled: scheduled,
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        backgroundColor: SoloColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: SoloColors.borderGlow, width: 1.2),
        ),
        child: const Icon(Icons.add, color: SoloColors.neonCyan, size: 28),
      ),
    );
  }

  Widget _header({required int totalExp}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: SoloColors.neonBlue, width: 1.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.adjust,
                    color: SoloColors.neonBlue, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'DAILY QUEST',
                style: TextStyle(
                  color: SoloColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                _dateLabel(),
                style: const TextStyle(
                  color: SoloColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          HunterLevelCard(totalExp: totalExp),
        ],
      ),
    );
  }

  String _dateLabel() {
    const months = [
      null, 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    return '${_now.day} ${months[_now.month]}';
  }

  Widget _taskList({
    required List<Task> active,
    required List<Task> done,
    required List<Task> scheduled,
  }) {
    if (_tasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Квестов пока нет.\nНажми «+», чтобы создать свой первый квест.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SoloColors.textDim,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      children: [
        _sectionLabel(
            'АКТИВНЫЕ КВЕСТЫ (${active.length})', SoloColors.textSecondary),
        const SizedBox(height: 8),
        if (active.isEmpty)
          _emptyHint('На сегодня нет активных квестов.')
        else
          ...active.map((t) => TaskTile(
                task: t,
                onToggle: _toggle,
                onDelete: () => _delete(t),
              )),
        const SizedBox(height: 16),
        if (done.isNotEmpty) ...[
          _sectionLabel('ВЫПОЛНЕНО (${done.length})', SoloColors.done),
          const SizedBox(height: 8),
          ...done.map((t) => TaskTile(
                task: t,
                onToggle: _toggle,
                onDelete: () => _delete(t),
              )),
        ],
        const SizedBox(height: 16),
        if (scheduled.isNotEmpty) ...[
          _sectionLabel('ЗАПЛАНИРОВАНО (${scheduled.length})',
              SoloColors.neonViolet),
          const SizedBox(height: 8),
          ...scheduled.map((t) => TaskTile(
                task: t,
                onToggle: _toggle,
                onDelete: () => _delete(t),
              )),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SoloColors.surface,
        border: Border.all(color: SoloColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: SoloColors.textDim, fontSize: 13),
      ),
    );
  }
}
