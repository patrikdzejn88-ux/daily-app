import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme/solo_colors.dart';

/// Логика уровня Hunter (как в Solo Leveling).
class HunterProgress {
  /// Начальный уровень.
  static const int startLevel = 1;

  /// Опыт для уровня: чем выше — тем больше нужно.
  static int expForLevel(int level) => 100 + (level - 1) * 50;

  /// Раскладывает накопленный EXP на уровень + остаток, поддерживая
  /// отрицательные значения (уровень может опускаться ниже 1).
  static (int level, int current, int needed) breakdown(int totalExp) {
    int level = startLevel;
    int current = totalExp;

    // Поднимаемся вверх, пока хватает на следующий уровень.
    while (current >= expForLevel(level)) {
      current -= expForLevel(level);
      level++;
    }

    // Уходим вниз ниже 1 при долге: каждый уровень вниз возвращает его объём.
    while (current < 0) {
      final prev = level - 1 < startLevel ? startLevel : level - 1;
      current += expForLevel(prev);
      level--;
    }

    final needed = expForLevel(level < startLevel ? startLevel : level);
    return (level, current.clamp(0, needed), needed);
  }

  /// Суммарный баланс EXP по квестам.
  /// - одноразовый выполненный: +rank.exp;
  /// - ежедневный выполненный сегодня: +rank.exp;
  /// - ежедневный НЕ выполненный сегодня: −rank.exp (штраф).
  static int expForTasks(List<Task> tasks) {
    final today = DateTime.now();
    int sum = 0;
    for (final t in tasks) {
      if (t.daily) {
        sum += t.isDoneOn(today) ? t.rank.exp : -t.rank.exp;
      } else if (t.done) {
        sum += t.rank.exp;
      }
    }
    return sum;
  }
}

/// Большая неоновая карточка уровня + полоса опыта + ранг.
class HunterLevelCard extends StatelessWidget {
  const HunterLevelCard({super.key, required this.totalExp});

  final int totalExp;

  @override
  Widget build(BuildContext context) {
    final (level, current, needed) = HunterProgress.breakdown(totalExp);
    final negative = totalExp < 0;
    final levelColor = negative ? SoloColors.danger : SoloColors.textPrimary;
    final progress =
        needed <= 0 ? 0.0 : (current / needed).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SoloColors.surface,
        border: Border.all(
          color: negative ? SoloColors.danger : SoloColors.borderGlow,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: negative
            ? [
                BoxShadow(
                  color: SoloColors.danger.withValues(alpha: 0.25),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                negative ? 'WARNING' : 'HUNTER',
                style: TextStyle(
                  color: negative ? SoloColors.danger : SoloColors.neonBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'LV. $level',
                style: TextStyle(
                  color: levelColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'EXP $current / $needed',
            style: TextStyle(
              color: negative ? SoloColors.danger : SoloColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: SoloColors.surfaceLight,
              ),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: SoloColors.surfaceLight,
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: negative
                            ? SoloColors.danger
                            : null,
                        gradient: negative
                            ? null
                            : SoloColors.levelBar,
                        boxShadow: [
                          BoxShadow(
                            color: (negative
                                    ? SoloColors.danger
                                    : SoloColors.neonCyan)
                                .withValues(alpha: 0.6),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
