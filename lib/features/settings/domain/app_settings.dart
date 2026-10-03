enum ThemeSetting { system, light, dark }

class AppSettings {
  final int dailyGoalMinutes;
  final ThemeSetting themeMode;
  final double playbackSpeed;
  final double subtitleFontSize;

  const AppSettings({
    this.dailyGoalMinutes = 30,
    this.themeMode = ThemeSetting.system,
    this.playbackSpeed = 1.0,
    this.subtitleFontSize = 16.0,
  });

  AppSettings copyWith({
    int? dailyGoalMinutes,
    ThemeSetting? themeMode,
    double? playbackSpeed,
    double? subtitleFontSize,
  }) {
    return AppSettings(
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      themeMode: themeMode ?? this.themeMode,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
    );
  }
}
