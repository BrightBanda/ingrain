import 'package:ingrain/features/srs/domain/review_card.dart';

/// Pure simplified SM-2 scheduler. Holds no persistence concerns so it can be
/// unit tested without any repository.
class SrsScheduler {
  const SrsScheduler();

  static const double initialEaseFactor = 2.5;
  static const double minimumEaseFactor = 1.3;
  static const double hardMultiplier = 1.2;
  static const double easyMultiplier = 1.3;
  static const double hardEasePenalty = 0.15;
  static const double againEasePenalty = 0.2;
  static const double easyEaseBonus = 0.15;
  static const Duration againDelay = Duration(minutes: 10);

  ReviewCard schedule(ReviewCard card, Rating rating, DateTime now) {
    final nextInterval = nextIntervalDays(card, rating);
    final nextEase = _nextEaseFactor(card.easeFactor, rating);

    return card.copyWith(
      intervalDays: nextInterval,
      repetitions: rating == Rating.again ? 0 : card.repetitions + 1,
      easeFactor: nextEase,
      dueAt: now.add(_delayFor(nextInterval, rating)),
      reviewCount: card.reviewCount + 1,
      lastReviewedAt: () => now,
    );
  }

  int nextIntervalDays(ReviewCard card, Rating rating) {
    final interval = card.intervalDays;
    final ease = card.easeFactor;

    switch (rating) {
      case Rating.again:
        return 0;
      case Rating.hard:
        return _maxInt(1, (interval * hardMultiplier).round());
      case Rating.good:
        if (interval <= 0) return 1;
        if (interval == 1) return 6;
        return (interval * ease).round();
      case Rating.easy:
        if (interval <= 0) return 4;
        return (interval * ease * easyMultiplier).round();
    }
  }

  double _nextEaseFactor(double ease, Rating rating) {
    switch (rating) {
      case Rating.again:
        return _maxDouble(minimumEaseFactor, ease - againEasePenalty);
      case Rating.hard:
        return _maxDouble(minimumEaseFactor, ease - hardEasePenalty);
      case Rating.good:
        return ease;
      case Rating.easy:
        return ease + easyEaseBonus;
    }
  }

  Duration _delayFor(int intervalDays, Rating rating) {
    if (rating == Rating.again) return againDelay;
    return Duration(days: intervalDays);
  }

  static int _maxInt(int a, int b) => a > b ? a : b;

  static double _maxDouble(double a, double b) => a > b ? a : b;
}
