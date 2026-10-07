/// The knobs of the Anki-style scheduler, with Anki's own defaults.
class SrsSettings {
  /// New cards introduced per day.
  final int newCardsPerDay;

  /// Review cards shown per day (learning cards are never capped).
  final int maximumReviewsPerDay;

  /// Delays a new card climbs before it graduates, e.g. 1m then 10m.
  final List<Duration> learningSteps;

  /// Delays a forgotten review card climbs before it returns to review.
  final List<Duration> relearningSteps;

  /// Interval in days when a learning card graduates with Good.
  final int graduatingIntervalDays;

  /// Interval in days when a learning card graduates with Easy.
  final int easyIntervalDays;

  /// Ease every card starts with, as a multiplier (2.5 = 250%).
  final double startingEase;

  /// Extra multiplier on top of ease for Easy answers.
  final double easyBonus;

  /// Multiplier for Hard answers on review cards.
  final double hardIntervalMultiplier;

  /// Scales every review interval: below 1 shows cards sooner, above later.
  final double intervalModifier;

  /// Intervals never grow beyond this many days.
  final int maximumIntervalDays;

  /// A forgotten card's new interval as a fraction of the old one (0 = 1 day).
  final double lapseIntervalFactor;

  const SrsSettings({
    this.newCardsPerDay = 20,
    this.maximumReviewsPerDay = 200,
    this.learningSteps = const [Duration(minutes: 1), Duration(minutes: 10)],
    this.relearningSteps = const [Duration(minutes: 10)],
    this.graduatingIntervalDays = 1,
    this.easyIntervalDays = 4,
    this.startingEase = 2.5,
    this.easyBonus = 1.3,
    this.hardIntervalMultiplier = 1.2,
    this.intervalModifier = 1.0,
    this.maximumIntervalDays = 36500,
    this.lapseIntervalFactor = 0.0,
  });

  static const minimumEase = 1.3;

  SrsSettings copyWith({
    int? newCardsPerDay,
    int? maximumReviewsPerDay,
    List<Duration>? learningSteps,
    List<Duration>? relearningSteps,
    int? graduatingIntervalDays,
    int? easyIntervalDays,
    double? startingEase,
    double? easyBonus,
    double? hardIntervalMultiplier,
    double? intervalModifier,
    int? maximumIntervalDays,
    double? lapseIntervalFactor,
  }) {
    return SrsSettings(
      newCardsPerDay: newCardsPerDay ?? this.newCardsPerDay,
      maximumReviewsPerDay: maximumReviewsPerDay ?? this.maximumReviewsPerDay,
      learningSteps: learningSteps ?? this.learningSteps,
      relearningSteps: relearningSteps ?? this.relearningSteps,
      graduatingIntervalDays:
          graduatingIntervalDays ?? this.graduatingIntervalDays,
      easyIntervalDays: easyIntervalDays ?? this.easyIntervalDays,
      startingEase: startingEase ?? this.startingEase,
      easyBonus: easyBonus ?? this.easyBonus,
      hardIntervalMultiplier:
          hardIntervalMultiplier ?? this.hardIntervalMultiplier,
      intervalModifier: intervalModifier ?? this.intervalModifier,
      maximumIntervalDays: maximumIntervalDays ?? this.maximumIntervalDays,
      lapseIntervalFactor: lapseIntervalFactor ?? this.lapseIntervalFactor,
    );
  }
}

/// How much of today's limits has been used.
class DailyStudyCounts {
  final int newStudied;
  final int reviewsDone;

  const DailyStudyCounts({this.newStudied = 0, this.reviewsDone = 0});
}

/// Anki-style step text: "1m 10m", "1h", "1d".
abstract final class StepFormat {
  static String format(List<Duration> steps) => steps.map(_one).join(' ');

  static String _one(Duration step) {
    if (step.inMinutes % (60 * 24) == 0 && step.inMinutes > 0) {
      return '${step.inDays}d';
    }
    if (step.inMinutes % 60 == 0 && step.inMinutes > 0) {
      return '${step.inHours}h';
    }
    if (step.inSeconds % 60 == 0) return '${step.inMinutes}m';
    return '${step.inSeconds}s';
  }

  /// Parses "1m 10m 1h"; null when any part is not a positive step.
  static List<Duration>? parse(String text) {
    final parts = text.trim().split(RegExp(r'[\s,]+'));
    if (parts.length == 1 && parts.single.isEmpty) return const [];
    final steps = <Duration>[];
    for (final part in parts) {
      final match = RegExp(r'^(\d+(?:\.\d+)?)([smhd]?)$').firstMatch(part);
      if (match == null) return null;
      final value = double.parse(match.group(1)!);
      if (value <= 0) return null;
      final seconds = switch (match.group(2)) {
        's' => value,
        'h' => value * 3600,
        'd' => value * 86400,
        _ => value * 60,
      };
      steps.add(Duration(seconds: seconds.round()));
    }
    return steps;
  }
}
