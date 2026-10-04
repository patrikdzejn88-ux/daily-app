import 'package:flutter/material.dart';

import '../logic/hunter_progress.dart';
import '../theme/solo_colors.dart';

/// Большая неоновая карточка уровня + полоса опыта + ранг.
class HunterLevelCard extends StatelessWidget {
  const HunterLevelCard({super.key, required this.totalExp});

  final int totalExp;

  @override
  Widget build(BuildContext context) {
    final (level, current, needed) = HunterProgress.breakdown(totalExp);
    final negative = totalExp < 0;
    final levelColor = negative ? SoloColors.danger : SoloColors.textPrimary;
    final progress = needed <= 0
        ? 0.0
        : (current / needed).clamp(0.0, 1.0).toDouble();

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
              decoration: BoxDecoration(color: SoloColors.surfaceLight),
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
                        color: negative ? SoloColors.danger : null,
                        gradient: negative ? null : SoloColors.levelBar,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (negative
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
