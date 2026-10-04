class DailyActivity {
  final DateTime day;
  final int seconds;
  final int reviews;

  const DailyActivity({
    required this.day,
    required this.seconds,
    this.reviews = 0,
  });

  bool get hasActivity => seconds > 0 || reviews > 0;
}

class ProgressSummary {
  final int todaySeconds;
  final int weekSeconds;
  final int lifetimeSeconds;
  final int currentStreak;
  final int longestStreak;
  final int totalSentences;
  final int sentencesThisWeek;
  final int dueCount;
  final int reviewedToday;
  final int totalReviews;
  final int dailyGoalMinutes;
  final List<DailyActivity> last7Days;

  const ProgressSummary({
    required this.todaySeconds,
    required this.weekSeconds,
    required this.lifetimeSeconds,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalSentences,
    required this.sentencesThisWeek,
    required this.dueCount,
    required this.reviewedToday,
    required this.totalReviews,
    required this.dailyGoalMinutes,
    required this.last7Days,
  });

  static const ProgressSummary empty = ProgressSummary(
    todaySeconds: 0,
    weekSeconds: 0,
    lifetimeSeconds: 0,
    currentStreak: 0,
    longestStreak: 0,
    totalSentences: 0,
    sentencesThisWeek: 0,
    dueCount: 0,
    reviewedToday: 0,
    totalReviews: 0,
    dailyGoalMinutes: 30,
    last7Days: <DailyActivity>[],
  );

  int get dailyGoalSeconds => dailyGoalMinutes * 60;

  /// Clamped 0..1 progress of today's immersion time towards the daily goal.
  double get todayGoalProgress {
    if (dailyGoalSeconds <= 0) return 0;
    return (todaySeconds / dailyGoalSeconds).clamp(0.0, 1.0);
  }

  bool get isEmpty =>
      lifetimeSeconds == 0 && totalSentences == 0 && totalReviews == 0;
}
