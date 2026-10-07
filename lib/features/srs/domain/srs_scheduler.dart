import 'dart:math';

import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/srs_settings.dart';

/// Anki's scheduler (the SM-2 based v3 scheduler, without FSRS).
///
/// * New and learning cards climb [SrsSettings.learningSteps] (minutes
///   apart). Good moves one step up, Again goes back to the first step, Hard
///   repeats the step, Easy graduates at once. Passing the last step graduates
///   the card to review with the graduating (or easy) interval.
/// * Review cards grow by their ease: Hard ×1.2, Good ×ease, Easy
///   ×ease×easy bonus, each at least a day longer than the one before, and
///   all scaled by the interval modifier. Hard lowers ease by 0.15, Easy
///   raises it by 0.15.
/// * Again on a review card is a lapse: ease drops by 0.20 and the card goes
///   through [SrsSettings.relearningSteps] before returning to review with a
///   shorter interval.
///
/// Pure and deterministic (no fuzz), so it is fully unit-testable.
class SrsScheduler {
  final SrsSettings settings;

  const SrsScheduler([this.settings = const SrsSettings()]);

  static const double hardEasePenalty = 0.15;
  static const double againEasePenalty = 0.20;
  static const double easyEaseBonus = 0.15;

  ReviewCard schedule(ReviewCard card, Rating rating, DateTime now) {
    final next = switch (card.state) {
      CardState.newCard || CardState.learning => _learn(
        card,
        rating,
        now,
        settings.learningSteps,
        relearning: false,
      ),
      CardState.relearning => _learn(
        card,
        rating,
        now,
        settings.relearningSteps,
        relearning: true,
      ),
      CardState.review => _review(card, rating, now),
    };
    return next.copyWith(
      reviewCount: card.reviewCount + 1,
      repetitions: rating == Rating.again ? 0 : card.repetitions + 1,
      lastReviewedAt: () => now,
    );
  }

  /// How long until [card] comes back if answered with [rating] now. Shown on
  /// the answer buttons, so it always matches what [schedule] will do.
  Duration nextDelay(ReviewCard card, Rating rating, DateTime now) =>
      schedule(card, rating, now).dueAt.difference(now);

  ReviewCard _learn(
    ReviewCard card,
    Rating rating,
    DateTime now,
    List<Duration> steps, {
    required bool relearning,
  }) {
    final ease = card.state == CardState.newCard
        ? settings.startingEase
        : card.easeFactor;
    final state = relearning ? CardState.relearning : CardState.learning;

    if (steps.isEmpty || rating == Rating.easy) {
      return _graduate(card, ease, now, easy: rating == Rating.easy);
    }

    final step = card.state == CardState.newCard
        ? 0
        : card.step.clamp(0, steps.length - 1);

    switch (rating) {
      case Rating.again:
        return card.copyWith(
          state: state,
          step: 0,
          easeFactor: ease,
          dueAt: now.add(steps.first),
        );
      case Rating.hard:
        return card.copyWith(
          state: state,
          step: step,
          easeFactor: ease,
          dueAt: now.add(_hardDelay(steps, step)),
        );
      case Rating.good:
        if (step + 1 < steps.length) {
          return card.copyWith(
            state: state,
            step: step + 1,
            easeFactor: ease,
            dueAt: now.add(steps[step + 1]),
          );
        }
        return _graduate(card, ease, now, easy: false);
      case Rating.easy:
        return _graduate(card, ease, now, easy: true);
    }
  }

  /// Hard repeats the current step, except on the first step, where Anki
  /// waits halfway to the next one (or 1.5× a single step, at most a day
  /// more).
  static Duration _hardDelay(List<Duration> steps, int step) {
    if (step == 0 && steps.length >= 2) {
      return Duration(seconds: (steps[0].inSeconds + steps[1].inSeconds) ~/ 2);
    }
    if (step == 0) {
      final longer = Duration(seconds: (steps[0].inSeconds * 1.5).round());
      final cap = steps[0] + const Duration(days: 1);
      return longer < cap ? longer : cap;
    }
    return steps[step];
  }

  ReviewCard _graduate(
    ReviewCard card,
    double ease,
    DateTime now, {
    required bool easy,
  }) {
    final int interval;
    if (card.state == CardState.relearning) {
      // The shorter interval was already set when the card lapsed.
      final lapsed = max(1, card.intervalDays);
      interval = easy ? lapsed + 1 : lapsed;
    } else {
      interval = easy
          ? settings.easyIntervalDays
          : settings.graduatingIntervalDays;
    }
    final days = _clamp(interval);
    return card.copyWith(
      state: CardState.review,
      step: 0,
      intervalDays: days,
      easeFactor: ease,
      dueAt: now.add(Duration(days: days)),
    );
  }

  ReviewCard _review(ReviewCard card, Rating rating, DateTime now) {
    final interval = max(1, card.intervalDays);
    final ease = card.easeFactor;
    // Remembering an overdue card proves more, so the overdue days count.
    final daysLate = max(0, now.difference(card.dueAt).inDays);
    final modifier = settings.intervalModifier;

    if (rating == Rating.again) {
      final lapsedInterval = _clamp(
        (interval * settings.lapseIntervalFactor).round(),
      );
      final lowerEase = max(SrsSettings.minimumEase, ease - againEasePenalty);
      final relearn = settings.relearningSteps;
      return card.copyWith(
        state: relearn.isEmpty ? CardState.review : CardState.relearning,
        step: 0,
        lapses: card.lapses + 1,
        easeFactor: lowerEase,
        intervalDays: lapsedInterval,
        dueAt: now.add(
          relearn.isEmpty ? Duration(days: lapsedInterval) : relearn.first,
        ),
      );
    }

    final hardInterval = _clamp(
      max(
        (interval * settings.hardIntervalMultiplier * modifier).round(),
        interval + 1,
      ),
    );
    final goodInterval = _clamp(
      max(
        ((interval + daysLate / 2) * ease * modifier).round(),
        hardInterval + 1,
      ),
    );
    final easyInterval = _clamp(
      max(
        ((interval + daysLate) * ease * settings.easyBonus * modifier).round(),
        goodInterval + 1,
      ),
    );

    final (days, newEase) = switch (rating) {
      Rating.hard => (
        hardInterval,
        max(SrsSettings.minimumEase, ease - hardEasePenalty),
      ),
      Rating.good => (goodInterval, ease),
      Rating.easy => (easyInterval, ease + easyEaseBonus),
      Rating.again => throw StateError('handled above'),
    };
    return card.copyWith(
      state: CardState.review,
      intervalDays: days,
      easeFactor: newEase,
      dueAt: now.add(Duration(days: days)),
    );
  }

  int _clamp(int days) => days.clamp(1, max(1, settings.maximumIntervalDays));
}
