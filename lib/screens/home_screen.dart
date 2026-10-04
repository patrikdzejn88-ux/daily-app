import 'dart:async';

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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _db = TaskDatabase.instance;
  List<Task> _tasks = [];
  bool _loading = true;
  String? _error;
  int _totalXp = 0;

  /// Квесты с выполняющейся мутацией: повторный тап игнорируется,
  /// пока идёт запрос (M5).
  final Set<int> _pendingIds = {};

  Timer? _midnightTimer;

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _scheduleMidnightReload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Вернулись в приложение — день мог смениться (C2).
    if (state == AppLifecycleState.resumed) _load();
  }

  /// Перезагрузка сразу после ближайшей полуночи (C2).
  void _scheduleMidnightReload() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(
      midnight.difference(now) + const Duration(seconds: 1),
      () {
        _load();
        _scheduleMidnightReload();
      },
    );
  }

  Future<void> _load() async {
    try {
      final today = _dayOnly(DateTime.now());
      // Джоба штрафов System за прошедшие дни (до чтения списка).
      await _db.applyMissedDayPenalties(today);
      final tasks = await _db.getAll();
      final xp = await _db.getTotalXp();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _totalXp = xp;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось связаться с System.';
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  Future<void> _addTask() async {
    final task = await showAddTaskDialog(context);
    if (task == null) return;
    try {
      final id = await _db.insert(task);
      if (!mounted) return;
      setState(() {
        _tasks.insert(0, Task.fromMap({...task.toMap(), 'id': id}));
      });
      showSystemMessage(
        context,
        'Квест принят: ${task.title}',
        title: 'SYSTEM',
        color: SoloColors.neonBlue,
      );
    } catch (_) {
      if (!mounted) return;
      showSystemMessage(
        context,
        'Не удалось создать квест',
        title: 'WARNING',
        color: SoloColors.danger,
      );
    }
  }

  Future<void> _toggle(Task task) async {
    final id = task.id;
    // M5: гонка двойного toggle — повторный тап по той же задаче
    // игнорируется, пока идёт запрос.
    if (id == null || _pendingIds.contains(id)) return;
    final today = _dayOnly(DateTime.now());
    final wasDone = task.isDoneOn(today);
    final updated = wasDone ? task.markNotDone() : task.markDoneOn(today);

    _pendingIds.add(id);
    // Оптимистичное обновление: при ошибке откатываем (в catch ниже).
    setState(() {
      final i = _tasks.indexWhere((t) => t.id == id);
      if (i != -1) _tasks[i] = updated;
    });

    try {
      await _db.update(updated);
      // Событийный XP (C1): выполнение → +exp, отмена → удаление события.
      if (wasDone) {
        await _db.removeCompletion(updated, today);
      } else {
        await _db.recordCompletion(updated, today);
      }
      final xp = await _db.getTotalXp();
      if (!mounted) return;
      setState(() => _totalXp = xp);
      if (!wasDone) {
        showSystemMessage(
          context,
          '+${updated.rank.exp} EXP — ${updated.title}',
          title: 'QUEST CLEAR',
          color: SoloColors.neonCyan,
        );
      } else {
        showSystemMessage(
          context,
          'Квест не выполнен: ${updated.title}',
          title: 'SYSTEM',
          color: SoloColors.textDim,
        );
      }
    } catch (_) {
      if (!mounted) return;
      // Откат оптимистичного обновления.
      setState(() {
        final i = _tasks.indexWhere((t) => t.id == id);
        if (i != -1) _tasks[i] = task;
      });
      showSystemMessage(
        context,
        'System недоступна: действие отменено',
        title: 'WARNING',
        color: SoloColors.danger,
      );
    } finally {
      _pendingIds.remove(id);
    }
  }

  Future<void> _delete(Task task) async {
    try {
      await _db.delete(task.id!);
      if (!mounted) return;
      setState(() {
        _tasks.removeWhere((t) => t.id == task.id);
      });
      showSystemMessage(
        context,
        'Квест удалён: ${task.title}',
        title: 'SYSTEM',
        color: SoloColors.danger,
      );
    } catch (_) {
      if (!mounted) return;
      showSystemMessage(
        context,
        'Не удалось удалить квест',
        title: 'WARNING',
        color: SoloColors.danger,
      );
    }
  }

  /// Квесты, назначенные на другие даты (не сегодня), кроме ежедневных
  /// и уже выполненных.
  List<Task> _scheduledTasks(DateTime today) {
    final list = _tasks
        .where(
          (t) => !t.daily && t.date != null && !t.isDueOn(today) && !t.done,
        )
        .toList();
    list.sort((a, b) => a.date!.compareTo(b.date!));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    // Единственный источник «сегодня» на весь экран (C2, C3).
    final today = _dayOnly(DateTime.now());
    final due = _tasks.where((t) => t.isDueOn(today)).toList();
    final active = due.where((t) => !t.isDoneOn(today)).toList();
    final done = due.where((t) => t.isDoneOn(today)).toList();
    final scheduled = _scheduledTasks(today);

    return Scaffold(
      backgroundColor: SoloColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(totalExp: _totalXp),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: SoloColors.neonBlue,
                      ),
                    )
                  : _error != null
                  ? _errorState()
                  : _taskList(
                      today: today,
                      active: active,
                      done: done,
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
                child: const Icon(
                  Icons.adjust,
                  color: SoloColors.neonBlue,
                  size: 20,
                ),
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
      null,
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    final now = DateTime.now();
    return '${now.day} ${months[now.month]}';
  }

  /// Состояние ошибки загрузки вместо вечного спиннера (B7).
  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: SoloColors.danger,
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'SYSTEM НЕДОСТУПНА',
              style: TextStyle(
                color: SoloColors.danger,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? 'Неизвестная ошибка',
              textAlign: TextAlign.center,
              style: const TextStyle(color: SoloColors.textDim, fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _retry,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: SoloColors.borderGlow),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Повторить',
                style: TextStyle(color: SoloColors.neonCyan),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskList({
    required DateTime today,
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
          'АКТИВНЫЕ КВЕСТЫ (${active.length})',
          SoloColors.textSecondary,
        ),
        const SizedBox(height: 8),
        if (active.isEmpty)
          _emptyHint('На сегодня нет активных квестов.')
        else
          ...active.map(
            (t) => TaskTile(
              task: t,
              today: today,
              onToggle: _toggle,
              onDelete: () => _delete(t),
            ),
          ),
        const SizedBox(height: 16),
        if (done.isNotEmpty) ...[
          _sectionLabel('ВЫПОЛНЕНО (${done.length})', SoloColors.done),
          const SizedBox(height: 8),
          ...done.map(
            (t) => TaskTile(
              task: t,
              today: today,
              onToggle: _toggle,
              onDelete: () => _delete(t),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (scheduled.isNotEmpty) ...[
          _sectionLabel(
            'ЗАПЛАНИРОВАНО (${scheduled.length})',
            SoloColors.neonViolet,
          ),
          const SizedBox(height: 8),
          ...scheduled.map(
            (t) => TaskTile(
              task: t,
              today: today,
              onToggle: _toggle,
              onDelete: () => _delete(t),
            ),
          ),
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
