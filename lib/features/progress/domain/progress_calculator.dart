import 'package:ingrain/features/immersion/domain/immersion_session.dart';
import 'package:ingrain/features/progress/domain/progress_summary.dart';
import 'package:ingrain/features/sentence_mining/domain/sentence_item.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/review_event.dart';
import 'package:ingrain/features/vocabulary/domain/vocabulary_item.dart';

/// Pure progress aggregation. Every entry point takes an explicit `today` so
/// the results are deterministic and unit testable.
///
/// A session crossing midnight is attributed to the local day of its
/// `startedAt`, and only its accumulated `durationSeconds` counts (pause time
/// is already excluded by the session ViewModel).
class ProgressCalculator {
  const ProgressCalculator();

  static const int weekDayCount = 7;

  ProgressSummary summarize({
    required List<ImmersionSession> sessions,
    required List<SentenceItem> sentences,
    required List<VocabularyItem> vocabulary,
    required List<ReviewCard> dueCards,
    required List<ReviewEvent> reviewEvents,
    required DateTime today,
    required int dailyGoalMinutes,
  }) {
    final todayDay = _day(today);

    final secondsByDay = <DateTime, int>{};
    var lifetimeSeconds = 0;
    for (final session in sessions) {
      final seconds = session.durationSeconds;
      if (seconds <= 0) continue;
      final day = _day(session.startedAt.toLocal());
      secondsByDay.update(
        day,
        (value) => value + seconds,
        ifAbsent: () => seconds,
      );
      lifetimeSeconds += seconds;
    }

    final reviewsByDay = <DateTime, int>{};
    for (final event in reviewEvents) {
      final day = _day(event.reviewedAt.toLocal());
      reviewsByDay.update(day, (value) => value + 1, ifAbsent: () => 1);
    }

    final last7Days = <DailyActivity>[];
    var todaySeconds = 0;
    var weekSeconds = 0;
    for (var offset = weekDayCount - 1; offset >= 0; offset--) {
      final day = _shiftDays(todayDay, -offset);
      final seconds = secondsByDay[day] ?? 0;
      final reviews = reviewsByDay[day] ?? 0;
      if (offset == 0) todaySeconds = seconds;
      weekSeconds += seconds;
      last7Days.add(
        DailyActivity(day: day, seconds: seconds, reviews: reviews),
      );
    }

    final weekStart = _shiftDays(todayDay, -(weekDayCount - 1));
    final sentencesThisWeek = sentences.where((s) {
      final created = _day(s.createdAt.toLocal());
      return !created.isBefore(weekStart);
    }).length;

    final endOfToday = _shiftDays(todayDay, 1);
    final dueCount = dueCards
        .where((card) => card.dueAt.toLocal().isBefore(endOfToday))
        .length;

    final activeDays = secondsByDay.keys.toList()..sort();
    final reviewedToday = reviewsByDay[todayDay] ?? 0;

    return ProgressSummary(
      todaySeconds: todaySeconds,
      weekSeconds: weekSeconds,
      lifetimeSeconds: lifetimeSeconds,
      currentStreak: _currentStreak(activeDays, todayDay),
      longestStreak: _longestStreak(activeDays),
      totalSentences: sentences.length,
      sentencesThisWeek: sentencesThisWeek,
      totalWords: vocabulary.length,
      wordsLearningOrBetter: vocabulary
          .where((word) => word.state.isAtLeast(VocabState.learning))
          .length,
      dueCount: dueCount,
      reviewedToday: reviewedToday,
      totalReviews: reviewEvents.length,
      dailyGoalMinutes: dailyGoalMinutes,
      last7Days: last7Days,
    );
  }

  /// Streak counts back from today. If today has no immersion yet the streak is
  /// still alive when yesterday was active, so the user does not lose it before
  /// the end of the day.
  static int _currentStreak(
    List<DateTime> sortedActiveDays,
    DateTime todayDay,
  ) {
    if (sortedActiveDays.isEmpty) return 0;

    var cursor = todayDay;
    if (!sortedActiveDays.contains(cursor)) {
      cursor = _shiftDays(todayDay, -1);
      if (!sortedActiveDays.contains(cursor)) return 0;
    }

    final active = sortedActiveDays.toSet();
    var streak = 0;
    while (active.contains(cursor)) {
      streak++;
      cursor = _shiftDays(cursor, -1);
    }
    return streak;
  }

  static int _longestStreak(List<DateTime> sortedActiveDays) {
    if (sortedActiveDays.isEmpty) return 0;

    var longest = 1;
    var run = 1;
    for (var i = 1; i < sortedActiveDays.length; i++) {
      final previous = _shiftDays(sortedActiveDays[i], -1);
      if (sortedActiveDays[i - 1] == previous) {
        run++;
      } else {
        if (run > longest) longest = run;
        run = 1;
      }
    }
    return run > longest ? run : longest;
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Calendar-day arithmetic, avoiding `Duration` so DST transitions cannot
  /// shift the resulting date.
  static DateTime _shiftDays(DateTime day, int delta) =>
      DateTime(day.year, day.month, day.day + delta);
}
