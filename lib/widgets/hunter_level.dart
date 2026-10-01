import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme/solo_colors.dart';

/// Логика уровня Hunter (как в Solo Leveling).
class HunterProgress {
  /// Начальный уровень.
  static const int startLevel = 1;

  /// Опыт для уровня: чем выше — тем больше нужно.
  static int expForLevel(int level) => 100 + (level - 1) * 50;

  static int levelForExp(int exp) {
    int level = startLevel;
    int remaining = exp;
    while (remaining >= expForLevel(level)) {
      remaining -= expForLevel(level);
      level++;
    }
    return level;
  }

  static (int level, int current, int needed) breakdown(int totalExp) {
    int level = startLevel;
    int remaining = totalExp;
    while (remaining >= expForLevel(level)) {
      remaining -= expForLevel(level);
      level++;
    }
    return (level, remaining, expForLevel(level));
  }

  /// Суммарный опыт за выполненные квесты.
  static int expForTasks(List<Task> tasks, {required bool onlyToday}) {
    int sum = 0;
    for (final t in tasks) {
      if (!t.done) continue;
      if (onlyToday && !t.isDueOn(DateTime.now())) continue;
      sum += t.rank.exp;
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
    final progress = needed <= 0 ? 0.0 : (current / needed).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SoloColors.surface,
        border: Border.all(color: SoloColors.borderGlow, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'HUNTER',
                style: TextStyle(
                  color: SoloColors.neonBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'LV. $level',
                style: const TextStyle(
                  color: SoloColors.textPrimary,
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
            style: const TextStyle(
              color: SoloColors.textSecondary,
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
                        gradient: SoloColors.levelBar,
                        boxShadow: [
                          BoxShadow(
                            color: SoloColors.neonCyan
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
