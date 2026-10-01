import 'package:flutter/material.dart';

/// Фирменная палитра Solo Leveling — тёмный фон, синий неон.
class SoloColors {
  SoloColors._();

  // Фон и поверхности
  static const Color background = Color(0xFF070B14); // почти чёрный с синим
  static const Color surface = Color(0xFF0E1420); // тёмно-синяя панель
  static const Color surfaceLight = Color(0xFF16203A);

  // Границы и линии
  static const Color border = Color(0xFF1E2B4A);
  static const Color borderGlow = Color(0xFF2E6BFF);

  // Неоновый синий (фирменный System)
  static const Color neonBlue = Color(0xFF2E6BFF);
  static const Color neonCyan = Color(0xFF00D4FF);
  static const Color neonViolet = Color(0xFF8A5CFF);

  // Текст
  static const Color textPrimary = Color(0xFFE6EEFF);
  static const Color textSecondary = Color(0xFF8090B0);
  static const Color textDim = Color(0xFF4A5878);

  // Ранги задач (как в Solo Leveling)
  static const Color rankE = Color(0xFF7A8A99); // серый
  static const Color rankD = Color(0xFF4A9E6C); // зелёный
  static const Color rankC = Color(0xFF3E8FD9); // синий
  static const Color rankB = Color(0xFF9B59B6); // фиолетовый
  static const Color rankA = Color(0xFFE67E22); // оранжевый
  static const Color rankS = Color(0xFFE74C3C); // красный

  // Выполнено / просрочено
  static const Color done = Color(0xFF1F8F5B);
  static const Color danger = Color(0xFFE74C3C);

  static const LinearGradient levelBar = LinearGradient(
    colors: [neonBlue, neonCyan],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
