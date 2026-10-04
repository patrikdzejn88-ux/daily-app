# Daily Quest

Мобильное приложение «задачи на месяц» в стиле Solo Leveling (тёмная неоновая тема, ранги квестов E–S, уровень Hunter).

## Возможности
- Система квестов с рангами E / D / C / B / A / S
- Ежедневные и одноразовые (на дату) задачи
- Прогресс уровня Hunter + полоса опыта
- System-уведомления в стиле аниме
- Локальное хранение (SQLite) — данные на устройстве

## Сборка
Сборка Android-APK выполняется автоматически при пуше в ветки `main` / `master`:

- **GitHub Actions** — `.github/workflows/build.yml`
- **Codemagic (Magic)** — `codemagic.yaml`

Готовый APK (артефакт): `build/app/outputs/flutter-apk/app-release.apk`

## Запуск локально
```bash
flutter pub get
flutter run
```

## Структура
```
lib/
  main.dart                 # точка входа, тема
  models/task.dart          # модель квеста + ранги
  logic/hunter_progress.dart# чистая логика уровня Hunter (уровни, полоса EXP)
  data/task_database.dart   # SQLite: квесты + журнал событий опыта (xp_events)
  screens/home_screen.dart
  theme/solo_colors.dart    # палитра Solo Leveling
  widgets/                  # system_message, hunter_level, task_tile, add_task_dialog
```
