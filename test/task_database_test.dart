import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:daily_app/data/task_database.dart';
import 'package:daily_app/models/task.dart';

TaskDatabase get db => TaskDatabase.instance;

/// Уникальный временный файл для миграционных тестов (in-memory БД
/// не переживает закрытие/повторное открытие со сменой версии).
String tempDbPath() => p.join(
  Directory.systemTemp.path,
  'daily_app_test_${DateTime.now().microsecondsSinceEpoch}.db',
);

Future<void> deleteDbFile(String path) async {
  final f = File(path);
  if (await f.exists()) await f.delete();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await TaskDatabase.instance.close();
    TaskDatabase.debugDatabasePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await TaskDatabase.instance.close();
    TaskDatabase.debugDatabasePath = null;
  });

  group('getTotalXp', () {
    test('empty database gives 0', () async {
      expect(await db.getTotalXp(), 0);
    });
  });

  group('recordCompletion / removeCompletion', () {
    test('recordCompletion adds rank exp to total', () async {
      final day = DateTime(2026, 10, 4);
      final id = await db.insert(
        Task(title: 'run', rank: TaskRank.c, daily: true, createdAt: day),
      );
      final task = Task(
        id: id,
        title: 'run',
        rank: TaskRank.c,
        daily: true,
        createdAt: day,
      );

      await db.recordCompletion(task, day);

      expect(await db.getTotalXp(), TaskRank.c.exp);
    });

    test('removeCompletion for daily removes only that day', () async {
      final day1 = DateTime(2026, 10, 3);
      final day2 = DateTime(2026, 10, 4);
      final id = await db.insert(
        Task(title: 'run', rank: TaskRank.c, daily: true),
      );
      final task = Task(id: id, title: 'run', rank: TaskRank.c, daily: true);

      await db.recordCompletion(task, day1);
      await db.recordCompletion(task, day2);
      expect(await db.getTotalXp(), TaskRank.c.exp * 2);

      await db.removeCompletion(task, day2);
      expect(await db.getTotalXp(), TaskRank.c.exp);
    });

    test('undo is idempotent', () async {
      final day = DateTime(2026, 10, 4);
      final id = await db.insert(Task(title: 'boss', rank: TaskRank.s));
      final task = Task(id: id, title: 'boss', rank: TaskRank.s);

      await db.recordCompletion(task, day);
      await db.removeCompletion(task, day);
      await db.removeCompletion(task, day);

      expect(await db.getTotalXp(), 0);
    });

    test(
      'one-off removeCompletion removes by task id regardless of day',
      () async {
        final id = await db.insert(Task(title: 'boss', rank: TaskRank.a));
        final task = Task(id: id, title: 'boss', rank: TaskRank.a);

        await db.recordCompletion(task, DateTime(2026, 10, 1));
        await db.removeCompletion(task, DateTime(2026, 12, 31));

        expect(await db.getTotalXp(), 0);
      },
    );

    test('deleting a task keeps earned xp (M7)', () async {
      final day = DateTime(2026, 10, 4);
      final id = await db.insert(Task(title: 'boss', rank: TaskRank.b));
      final task = Task(id: id, title: 'boss', rank: TaskRank.b);

      await db.recordCompletion(task, day);
      await db.delete(id);

      expect(await db.getTotalXp(), TaskRank.b.exp);
    });
  });

  group('applyMissedDayPenalties', () {
    test('missed day gives -rank exp', () async {
      final created = DateTime(2024, 1, 1);
      await db.insert(
        Task(title: 'train', rank: TaskRank.c, daily: true, createdAt: created),
      );

      // Первый запуск: фиксирует точку отсчёта без ретро-штрафов.
      await db.applyMissedDayPenalties(DateTime(2024, 1, 2));
      expect(await db.getTotalXp(), 0);

      // На следующий день System штрафует за пропущенное 2 января.
      await db.applyMissedDayPenalties(DateTime(2024, 1, 3));
      expect(await db.getTotalXp(), -TaskRank.c.exp);
    });

    test('today is never penalized', () async {
      final today = DateTime(2024, 1, 10);
      await db.insert(
        Task(
          title: 'train',
          rank: TaskRank.c,
          daily: true,
          createdAt: DateTime(2024, 1, 1),
        ),
      );

      await db.applyMissedDayPenalties(today);
      await db.applyMissedDayPenalties(today);

      expect(await db.getTotalXp(), 0);
    });

    test('creation day is not penalized by a same-day run', () async {
      final today = DateTime(2024, 1, 10);
      await db.insert(
        Task(
          title: 'new quest',
          rank: TaskRank.b,
          daily: true,
          createdAt: today,
        ),
      );

      await db.applyMissedDayPenalties(today);

      expect(await db.getTotalXp(), 0);
    });

    test('second run does not duplicate penalties', () async {
      await db.insert(
        Task(
          title: 'train',
          rank: TaskRank.e,
          daily: true,
          createdAt: DateTime(2024, 1, 1),
        ),
      );

      await db.applyMissedDayPenalties(DateTime(2024, 1, 2));
      await db.applyMissedDayPenalties(DateTime(2024, 1, 3));
      await db.applyMissedDayPenalties(DateTime(2024, 1, 3));

      expect(await db.getTotalXp(), -TaskRank.e.exp);
    });

    test('day with a completion event is not penalized', () async {
      final created = DateTime(2024, 1, 1);
      final id = await db.insert(
        Task(title: 'train', rank: TaskRank.c, daily: true, createdAt: created),
      );
      final task = Task(
        id: id,
        title: 'train',
        rank: TaskRank.c,
        daily: true,
        createdAt: created,
      );

      await db.applyMissedDayPenalties(DateTime(2024, 1, 2));
      await db.recordCompletion(task, DateTime(2024, 1, 2));
      await db.applyMissedDayPenalties(DateTime(2024, 1, 3));

      expect(await db.getTotalXp(), TaskRank.c.exp);
    });

    test('days before task creation are not penalized', () async {
      // Квест создан 5 января, джоба впервые запущена 3 января:
      // 3 и 4 января штрафоваться не должны, 5 и 6 — должны.
      await db.insert(
        Task(
          title: 'late quest',
          rank: TaskRank.e,
          daily: true,
          createdAt: DateTime(2024, 1, 5),
        ),
      );

      await db.applyMissedDayPenalties(DateTime(2024, 1, 3));
      await db.applyMissedDayPenalties(DateTime(2024, 1, 7));

      expect(await db.getTotalXp(), -TaskRank.e.exp * 2);
    });

    test('a single pass is capped at 370 days', () async {
      await db.insert(
        Task(
          title: 'ancient',
          rank: TaskRank.e,
          daily: true,
          createdAt: DateTime(2023, 1, 1),
        ),
      );

      await db.applyMissedDayPenalties(DateTime(2023, 1, 2));
      // Прошло больше года: проверяем не более 370 дней за проход.
      await db.applyMissedDayPenalties(DateTime(2024, 6, 1));

      expect(await db.getTotalXp(), -TaskRank.e.exp * 370);
    });
  });

  group('миграции', () {
    test('v1→v3: бэкфилл last_done_date для выполненных daily (M1)', () async {
      final path = tempDbPath();
      try {
        // Создаём БД версии 1 со старой схемой (без last_done_date).
        final raw = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await db.execute('''
                  CREATE TABLE tasks (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    title TEXT NOT NULL,
                    rank TEXT NOT NULL,
                    date TEXT,
                    daily INTEGER NOT NULL DEFAULT 0,
                    done INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT
                  )
                ''');
            },
          ),
        );
        await raw.insert('tasks', {
          'title': 'daily old',
          'rank': 'c',
          'daily': 1,
          'done': 1,
          'created_at': DateTime(2024, 1, 1).toIso8601String(),
        });
        await raw.insert('tasks', {
          'title': 'daily open',
          'rank': 'c',
          'daily': 1,
          'done': 0,
          'created_at': DateTime(2024, 1, 1).toIso8601String(),
        });
        await raw.close();

        // Открываем через TaskDatabase (version 3) — миграция v1→v3.
        await TaskDatabase.instance.close();
        TaskDatabase.debugDatabasePath = path;

        final tasks = await db.getAll();
        final old = tasks.firstWhere((t) => t.title == 'daily old');
        final open = tasks.firstWhere((t) => t.title == 'daily open');

        expect(old.lastDoneDate, isNotNull);
        // date('now') в SQLite — UTC; допускаем локальный или UTC день.
        final d = old.lastDoneDate!;
        final nowLocal = DateTime.now();
        final nowUtc = DateTime.now().toUtc();
        expect(Task.sameDay(d, nowLocal) || Task.sameDay(d, nowUtc), isTrue);
        expect(open.lastDoneDate, isNull);

        // Бэкфилл + сидинг v2→v3: выполненный daily получил событие +exp.
        expect(await db.getTotalXp(), TaskRank.c.exp);
      } finally {
        await TaskDatabase.instance.close();
        TaskDatabase.debugDatabasePath = inMemoryDatabasePath;
        await deleteDbFile(path);
      }
    });

    test('v2→v3: сидинг xp_events из текущего состояния', () async {
      final path = tempDbPath();
      try {
        final raw = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 2,
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
            },
          ),
        );
        await raw.insert('tasks', {
          'title': 'oneoff done',
          'rank': 'a',
          'daily': 0,
          'done': 1,
          'created_at': DateTime(2024, 1, 1).toIso8601String(),
        });
        await raw.insert('tasks', {
          'title': 'oneoff open',
          'rank': 'a',
          'daily': 0,
          'done': 0,
          'created_at': DateTime(2024, 1, 1).toIso8601String(),
        });
        await raw.insert('tasks', {
          'title': 'daily today',
          'rank': 'c',
          'daily': 1,
          'done': 1,
          'last_done_date': DateTime.now().toIso8601String(),
          'created_at': DateTime(2024, 1, 1).toIso8601String(),
        });
        await raw.insert('tasks', {
          'title': 'daily old',
          'rank': 'c',
          'daily': 1,
          'done': 0,
          'last_done_date': DateTime(2020, 1, 1).toIso8601String(),
          'created_at': DateTime(2024, 1, 1).toIso8601String(),
        });
        await raw.close();

        await TaskDatabase.instance.close();
        TaskDatabase.debugDatabasePath = path;

        // +exp за выполненный one-off и за daily, закрытый сегодня.
        final expected = TaskRank.a.exp + TaskRank.c.exp;
        expect(await db.getTotalXp(), expected);

        // Повторное открытие не дублирует сид (флаг xp_seeded).
        await TaskDatabase.instance.close();
        expect(await db.getTotalXp(), expected);
      } finally {
        await TaskDatabase.instance.close();
        TaskDatabase.debugDatabasePath = inMemoryDatabasePath;
        await deleteDbFile(path);
      }
    });
  });
}
