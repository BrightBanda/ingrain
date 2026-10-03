import 'package:ingrain/features/settings/domain/app_settings.dart';

abstract interface class SettingsRepository {
  Future<AppSettings> get settings;

  Future<void> update(AppSettings settings);

  Future<void> setDailyGoalMinutes(int minutes);

  Future<void> setThemeMode(ThemeSetting mode);

  Future<void> setPlaybackSpeed(double speed);

  Future<void> setSubtitleFontSize(double size);
}
