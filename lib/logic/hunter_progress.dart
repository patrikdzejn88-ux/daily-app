/// Логика уровня Hunter (как в Solo Leveling).
///
/// Чистые функции без DateTime.now() — для тестируемости.
/// Баланс опыта теперь хранится в SQLite (таблица xp_events),
/// здесь только раскладка суммы на уровень и прогресс полосы.
class HunterProgress {
  HunterProgress._();

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
}
