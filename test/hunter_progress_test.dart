import 'package:flutter_test/flutter_test.dart';

import 'package:daily_app/models/task.dart';
import 'package:daily_app/widgets/hunter_level.dart';

void main() {
  group('HunterProgress.expForTasks', () {
    test('daily quest finished today gives +EXP', () {
      final task = Task(
        title: 'run',
        rank: TaskRank.c,
        daily: true,
      ).markDoneOn(DateTime.now());
      expect(HunterProgress.expForTasks([task]), TaskRank.c.exp);
    });

    test('unfinished daily quest penalizes by -EXP', () {
      final task = Task(
        title: 'run',
        rank: TaskRank.c,
        daily: true,
      );
      expect(HunterProgress.expForTasks([task]), -TaskRank.c.exp);
    });

    test('one-off finished quest gives +EXP once', () {
      final task = Task(
        title: 'boss',
        rank: TaskRank.s,
        date: DateTime.now(),
      ).markDoneOn(DateTime.now());
      expect(HunterProgress.expForTasks([task]), TaskRank.s.exp);
    });

    test('mixed: finished + unfinished daily cancels out', () {
      final done = Task(title: 'a', rank: TaskRank.e, daily: true)
          .markDoneOn(DateTime.now());
      final notDone = Task(title: 'b', rank: TaskRank.e, daily: true);
      // +1 -1 = 0
      expect(HunterProgress.expForTasks([done, notDone]), 0);
    });
  });

  group('HunterProgress.breakdown negative level', () {
    test('small negative total keeps level 1 with clamped progress', () {
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
      final task = Task(title: 'x', rank: TaskRank.e, daily: true)
          .markDoneOn(yesterday);
      expect(task.isDoneOn(DateTime.now()), isFalse);
    });

    test('daily done today IS done today', () {
      final task = Task(title: 'x', rank: TaskRank.e, daily: true)
          .markDoneOn(DateTime.now());
      expect(task.isDoneOn(DateTime.now()), isTrue);
    });
  });
}
