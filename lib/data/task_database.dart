import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/task.dart';

/// Локальное хранилище квестов (SQLite).
class TaskDatabase {
  TaskDatabase._();
  static final TaskDatabase instance = TaskDatabase._();

  static const _dbName = 'daily_app.db';
  static const _dbVersion = 2;

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    final path = join(dir, _dbName);
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE tasks ADD COLUMN last_done_date TEXT');
        }
      },
    );
    return _db!;
  }

  Future<List<Task>> getAll() async {
    final db = await _database;
    final rows = await db.query('tasks', orderBy: 'created_at DESC');
    return rows.map(Task.fromMap).toList();
  }

  Future<int> insert(Task task) async {
    final db = await _database;
    return db.insert('tasks', task.toMap());
  }

  Future<void> update(Task task) async {
    final db = await _database;
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}
