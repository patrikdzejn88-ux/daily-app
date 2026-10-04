import 'package:flutter_test/flutter_test.dart';

import 'package:daily_app/logic/hunter_progress.dart';
import 'package:daily_app/models/task.dart';

void main() {
  group('HunterProgress.expForLevel', () {
    test('level 1 needs 100 exp', () {
      expect(HunterProgress.expForLevel(1), 100);
    });

    test('each next level costs 50 more', () {
      expect(HunterProgress.expForLevel(2), 150);
      expect(HunterProgress.expForLevel(3), 200);
    });
  });

  group('HunterProgress.breakdown negative level', () {
    test('small negative total drops to level 0 with clamped progress', () {
      final (level, current, needed) = HunterProgress.breakdown(-20);
      expect(level, 0);
      expect(current, greaterThanOrEqualTo(0));
      expect(current, lessThanOrEqualTo(needed));
    });

    test('larger negative drops level below zero', () {
      final (level, _, _) = HunterProgress.breakdown(-150);
      expect(level, lessThan(1));
    });

    test('positive exp still levels up', () {
      final (level, _, _) = HunterProgress.breakdown(250);
      expect(level, greaterThanOrEqualTo(2));
    });
  });

  group('Task.isDoneOn daily reset', () {
    test('daily done yesterday is NOT done today', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final task = Task(
        title: 'x',
        rank: TaskRank.e,
        daily: true,
      ).markDoneOn(yesterday);
      expect(task.isDoneOn(DateTime.now()), isFalse);
    });

    test('daily done today IS done today', () {
      final task = Task(
        title: 'x',
        rank: TaskRank.e,
        daily: true,
      ).markDoneOn(DateTime.now());
      expect(task.isDoneOn(DateTime.now()), isTrue);
    });
  });

  group('Task.fromMap broken rows (m2)', () {
    test('broken dates become null instead of throwing', () {
      final task = Task.fromMap({
        'id': 1,
        'title': 'x',
        'rank': 'zzz',
        'date': '###',
        'daily': 1,
        'done': 0,
        'last_done_date': 'вчера',
        'created_at': '',
      });
      expect(task.date, isNull);
      expect(task.lastDoneDate, isNull);
      expect(task.createdAt, isNull);
      expect(task.rank, TaskRank.e);
    });
  });
}
