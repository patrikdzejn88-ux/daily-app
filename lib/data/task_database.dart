import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/task.dart';

/// Ошибка локального хранилища с человекочитаемым сообщением (B7).
class TaskDatabaseException implements Exception {
  TaskDatabaseException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'TaskDatabaseException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Локальное хранилище квестов и событий опыта (SQLite).
///
/// Схема v3:
/// - tasks — квесты;
/// - xp_events — журнал событий опыта (+exp за выполнение, −exp штрафы
///   System). Баланс охотника = SUM(delta). События НЕ удаляются вместе
///   с квестом: заработанный опыт сохраняется (M7);
/// - meta — служебные ключи (флаг сидинга, день последней джобы штрафов).
class TaskDatabase {
  TaskDatabase._();
  static final TaskDatabase instance = TaskDatabase._();

  static const _dbName = 'daily_app.db';
  static const _dbVersion = 3;

  static const _kXpSeeded = 'xp_seeded';
  static const _kLastPenaltyDay = 'last_penalty_day';

  /// За один проход джобы штрафов проверяем не больше года дней.
  static const _maxPenaltyDaysPerPass = 370;

  Database? _db;

  /// Тестовый крючок: подмена пути к БД (в продакшене всегда null).
  static String? debugDatabasePath;

  /// Закрыть соединение (нужно тестам для чистого состояния).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final path = debugDatabasePath ?? join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            rank TEXT NOT NULL,
            date TEXT,
            daily INTEGER NOT NULL DEFAULT 0,
            done INTEGER NOT NULL DEFAULT 0,
            last_done_date TEXT,
            created_at TEXT
          )
        ''');
        await _createXpTables(db);
        // Свежая установка: задач нет, сидить нечего.
        await db.insert('meta', {'key': _kXpSeeded, 'value': '1'});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE tasks ADD COLUMN last_done_date TEXT');
          // M1: переносим старый флаг done в last_done_date, иначе
          // обновление обнуляет прогресс ежедневных квестов.
          await db.execute(
            "UPDATE tasks SET last_done_date = date('now') "
            'WHERE daily = 1 AND done = 1',
          );
        }
        if (oldVersion < 3) {
          await _createXpTables(db);
          await _seedXpEvents(db);
        }
      },
    );
    return _db!;
  }

  static Future<void> _createXpTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS xp_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER,
        title TEXT,
        delta INTEGER NOT NULL,
        day TEXT NOT NULL,
        kind TEXT NOT NULL,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  /// Одноразовый перенос текущего прогресса в события опыта при апгрейде
  /// на v3: выполненный одноразовый квест → +rank.exp, ежедневный,
  /// выполненный сегодня, → +rank.exp. Помечается флагом xp_seeded,
  /// чтобы не задвоиться при повторном апгрейде.
  static Future<void> _seedXpEvents(DatabaseExecutor db) async {
    final flag = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: [_kXpSeeded],
      limit: 1,
    );
    if (flag.isNotEmpty && flag.first['value'] == '1') return;

    final todayKey = _dayKey(DateTime.now());
    // Бэкфилл M1 пишет last_done_date через SQLite date('now') (UTC),
    // а приложение — локальный ISO. Принимаем оба варианта «сегодня».
    final utcTodayKey = _dayKey(DateTime.now().toUtc());
    final nowIso = DateTime.now().toIso8601String();
    final rows = await db.query('tasks');
    for (final r in rows) {
      final daily = (r['daily'] as int? ?? 0) == 1;
      final done = (r['done'] as int? ?? 0) == 1;
      bool completed;
      if (daily) {
        final ldd = r['last_done_date'] as String?;
        completed =
            ldd != null &&
            ldd.length >= 10 &&
            (ldd.substring(0, 10) == todayKey ||
                ldd.substring(0, 10) == utcTodayKey);
      } else {
        completed = done;
      }
      if (!completed) continue;
      final rank = _rankFromName(r['rank'] as String?);
      await db.insert('xp_events', {
        'task_id': r['id'],
        'title': r['title'],
        'delta': rank.exp,
        'day': todayKey,
        'kind': 'done',
        'created_at': nowIso,
      });
    }
    await db.insert('meta', {
      'key': _kXpSeeded,
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- Квесты ----------

  Future<List<Task>> getAll() async {
    final db = await _database;
    try {
      final rows = await db.query('tasks', orderBy: 'created_at DESC');
      final tasks = <Task>[];
      for (final row in rows) {
        try {
          tasks.add(Task.fromMap(row));
        } catch (_) {
          // Битая строка не должна ронять весь список (m2).
        }
      }
      return tasks;
    } catch (e) {
      throw TaskDatabaseException('Не удалось загрузить квесты', e);
    }
  }

  Future<int> insert(Task task) async {
    final db = await _database;
    try {
      return await db.insert('tasks', task.toMap());
    } catch (e) {
      throw TaskDatabaseException('Не удалось создать квест', e);
    }
  }

  Future<void> update(Task task) async {
    final db = await _database;
    try {
      await db.update(
        'tasks',
        task.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
    } catch (e) {
      throw TaskDatabaseException('Не удалось обновить квест', e);
    }
  }

  /// Удаление квеста. События опыта (xp_events) намеренно НЕ удаляются:
  /// заработанный опыт остаётся с охотником, даже если квест убрали (M7).
  Future<void> delete(int id) async {
    final db = await _database;
    try {
      await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw TaskDatabaseException('Не удалось удалить квест', e);
    }
  }

  // ---------- Опыт (xp_events) ----------

  /// Суммарный баланс опыта охотника.
  Future<int> getTotalXp() async {
    final db = await _database;
    try {
      final rows = await db.rawQuery(
        'SELECT COALESCE(SUM(delta), 0) AS total FROM xp_events',
      );
      return (rows.first['total'] as num?)?.toInt() ?? 0;
    } catch (e) {
      throw TaskDatabaseException('Не удалось получить опыт охотника', e);
    }
  }

  /// Записать выполнение квеста: +rank.exp за день [day] (C1).
  Future<void> recordCompletion(Task task, DateTime day) async {
    final db = await _database;
    try {
      await db.insert('xp_events', {
        'task_id': task.id,
        'title': task.title,
        'delta': task.rank.exp,
        'day': _dayKey(day),
        'kind': 'done',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw TaskDatabaseException('Не удалось записать опыт за квест', e);
    }
  }

  /// Отменить выполнение: ежедневному квесту удаляем событие 'done' за
  /// день [day], одноразовому — все события выполнения по task_id.
  Future<void> removeCompletion(Task task, DateTime day) async {
    final db = await _database;
    try {
      if (task.daily) {
        await db.delete(
          'xp_events',
          where: "task_id = ? AND day = ? AND kind = 'done'",
          whereArgs: [task.id, _dayKey(day)],
        );
      } else {
        await db.delete(
          'xp_events',
          where: "task_id = ? AND kind = 'done'",
          whereArgs: [task.id],
        );
      }
    } catch (e) {
      throw TaskDatabaseException('Не удалось отменить опыт за квест', e);
    }
  }

  /// Джоба штрафов System: за каждый полностью прошедший день, когда
  /// ежедневный квест не был выполнен, начисляется −rank.exp.
  ///
  /// [today] — сегодня (без времени). Сегодня не штрафуется: день ещё
  /// можно закрыть. День до создания квеста — тоже.
  ///
  /// last_penalty_day в meta — день последнего ЗАПУСКА джобы (а не
  /// последний проверенный день), поэтому проверяем дни от него
  /// включительно до вчера; от дублей страхует проверка существующего
  /// штрафа/выполнения за этот день.
  Future<void> applyMissedDayPenalties(DateTime today) async {
    final db = await _database;
    try {
      final todayDay = _dayOnly(today);
      final todayKey = _dayKey(todayDay);
      await db.transaction((txn) async {
        final rows = await txn.query(
          'meta',
          where: 'key = ?',
          whereArgs: [_kLastPenaltyDay],
          limit: 1,
        );
        if (rows.isEmpty) {
          // Первый запуск после установки/апгрейда: без ретро-штрафов.
          await txn.insert('meta', {
            'key': _kLastPenaltyDay,
            'value': todayKey,
          });
          return;
        }
        final last = _parseDay(rows.first['value'] as String?) ?? todayDay;
        final dailies = await txn.query('tasks', where: 'daily = 1');
        // Защита от перевода часов назад.
        var day = last.isAfter(todayDay) ? todayDay : last;
        var guard = 0;
        while (day.isBefore(todayDay) && guard < _maxPenaltyDaysPerPass) {
          final dayKey = _dayKey(day);
          for (final t in dailies) {
            final taskId = t['id'] as int;
            final created = _parseDay(t['created_at'] as String?);
            if (created != null && day.isBefore(created)) continue;
            if (await _hasEvent(txn, taskId, dayKey, 'done')) continue;
            if (await _hasEvent(txn, taskId, dayKey, 'penalty')) continue;
            final rank = _rankFromName(t['rank'] as String?);
            await txn.insert('xp_events', {
              'task_id': taskId,
              'title': t['title'],
              'delta': -rank.exp,
              'day': dayKey,
              'kind': 'penalty',
              'created_at': DateTime.now().toIso8601String(),
            });
          }
          day = day.add(const Duration(days: 1));
          guard++;
        }
        await txn.insert('meta', {
          'key': _kLastPenaltyDay,
          'value': todayKey,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    } catch (e) {
      throw TaskDatabaseException('Не удалось применить штрафы System', e);
    }
  }

  // ---------- Вспомогательное ----------

  static Future<bool> _hasEvent(
    DatabaseExecutor db,
    int taskId,
    String day,
    String kind,
  ) async {
    final rows = await db.query(
      'xp_events',
      where: 'task_id = ? AND day = ? AND kind = ?',
      whereArgs: [taskId, day, kind],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  static TaskRank _rankFromName(String? name) => TaskRank.values.firstWhere(
    (r) => r.name == name,
    orElse: () => TaskRank.e,
  );

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// День в формате 'yyyy-MM-dd' — так хранятся все дни-даты в xp_events.
  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDay(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final p = DateTime.parse(raw);
      return DateTime(p.year, p.month, p.day);
    } catch (_) {
      return null;
    }
  }
}
