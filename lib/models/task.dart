import 'package:flutter/material.dart';

import '../theme/solo_colors.dart';

/// Ранг квеста — от E до S, как в Solo Leveling.
enum TaskRank {
  e('E', SoloColors.rankE, 1),
  d('D', SoloColors.rankD, 2),
  c('C', SoloColors.rankC, 3),
  b('B', SoloColors.rankB, 4),
  a('A', SoloColors.rankA, 5),
  s('S', SoloColors.rankS, 6);

  const TaskRank(this.label, this.color, this.exp);

  /// Буква ранга для UI.
  final String label;

  /// Цвет ранга.
  final Color color;

  /// Опыт за выполнение квеста этого ранга.
  final int exp;
}

/// Квест. Ежедневный либо на конкретную дату.
class Task {
  Task({
    this.id,
    required this.title,
    this.rank = TaskRank.e,
    this.date, // если null и daily == true — ежедневный
    this.daily = false,
    this.done = false,
    this.lastDoneDate, // для ежедневных: день последнего выполнения
    this.createdAt,
  });

  final int? id;
  final String title;
  final TaskRank rank;

  /// Дата, на которую назначен квест (yyyy-MM-dd). Для ежедневных — null.
  final DateTime? date;

  /// Ежедневный повторяющийся квест.
  final bool daily;

  /// Состояние для одноразовых квестов (и дублирование для совместимости).
  final bool done;

  /// День последнего выполнения ежедневного квеста (yyyy-MM-dd).
  final DateTime? lastDoneDate;
  final DateTime? createdAt;

  /// Ежедневный квест считается выполненным сегодня, если lastDoneDate —
  /// это сегодня. Одноразовый — по флагу done.
  bool isDoneOn(DateTime day) {
    if (daily) {
      if (lastDoneDate == null) return false;
      return sameDay(lastDoneDate!, day);
    }
    return done;
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Task markDoneOn(DateTime day) => daily
      ? Task(
          id: id,
          title: title,
          rank: rank,
          date: date,
          daily: daily,
          done: true,
          lastDoneDate: day,
          createdAt: createdAt,
        )
      : copyWith(done: true);

  Task markNotDone() => daily
      ? Task(
          id: id,
          title: title,
          rank: rank,
          date: date,
          daily: daily,
          done: false,
          lastDoneDate: null,
          createdAt: createdAt,
        )
      : copyWith(done: false);

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'rank': rank.name,
      'date': date?.toIso8601String(),
      'daily': daily ? 1 : 0,
      'done': done ? 1 : 0,
      'last_done_date': lastDoneDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, Object?> m) {
    final rank = TaskRank.values.firstWhere(
      (r) => r.name == m['rank'],
      orElse: () => TaskRank.e,
    );
    return Task(
      id: m['id'] as int?,
      title: m['title'] as String? ?? '',
      rank: rank,
      date: m['date'] != null ? DateTime.parse(m['date'] as String) : null,
      daily: (m['daily'] as int? ?? 0) == 1,
      done: (m['done'] as int? ?? 0) == 1,
      lastDoneDate: m['last_done_date'] != null
          ? DateTime.parse(m['last_done_date'] as String)
          : null,
      createdAt: m['created_at'] != null
          ? DateTime.parse(m['created_at'] as String)
          : null,
    );
  }

  /// Квест нужно показать в этот день (сегодня).
  bool isDueOn(DateTime day) {
    if (daily) return true;
    if (date == null) return true;
    return date!.year == day.year &&
        date!.month == day.month &&
        date!.day == day.day;
  }

  Task copyWith({bool? done}) => Task(
        id: id,
        title: title,
        rank: rank,
        date: date,
        daily: daily,
        done: done ?? this.done,
        lastDoneDate: lastDoneDate,
        createdAt: createdAt,
      );
}
