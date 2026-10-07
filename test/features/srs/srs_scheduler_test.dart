import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/srs_scheduler.dart';
import 'package:ingrain/features/srs/domain/srs_settings.dart';

void main() {
  const scheduler = SrsScheduler();
  final now = DateTime(2026, 1, 1, 12);

  ReviewCard card({
    CardState state = CardState.newCard,
    int step = 0,
    int intervalDays = 0,
    double ease = 2.5,
    DateTime? dueAt,
    int lapses = 0,
  }) {
    return ReviewCard(
      id: 'card-1',
      uid: 'uid-1',
      cardType: CardType.basic,
      sourceItemId: 'card-1',
      promptText: '日本語',
      createdAt: now,
      dueAt: dueAt ?? now,
      state: state,
      step: step,
      intervalDays: intervalDays,
      easeFactor: ease,
      lapses: lapses,
    );
  }

  Duration delay(ReviewCard c, Rating r) => scheduler.nextDelay(c, r, now);

  group('new cards (steps 1m 10m)', () {
    test('again, hard, good, easy wait 1m, 5.5m, 10m, 4d', () {
      final fresh = card();
      expect(delay(fresh, Rating.again), const Duration(minutes: 1));
      expect(delay(fresh, Rating.hard), const Duration(seconds: 330));
      expect(delay(fresh, Rating.good), const Duration(minutes: 10));
      expect(delay(fresh, Rating.easy), const Duration(days: 4));
    });

    test('good moves to the next learning step', () {
      final next = scheduler.schedule(card(), Rating.good, now);

      expect(next.state, CardState.learning);
      expect(next.step, 1);
      expect(next.easeFactor, 2.5);
      expect(next.reviewCount, 1);
      expect(next.lastReviewedAt, now);
    });

    test('good on the last step graduates with the graduating interval', () {
      final last = card(state: CardState.learning, step: 1);
      final next = scheduler.schedule(last, Rating.good, now);

      expect(next.state, CardState.review);
      expect(next.intervalDays, 1);
      expect(next.dueAt, now.add(const Duration(days: 1)));
    });

    test('easy graduates straight away with the easy interval', () {
      final next = scheduler.schedule(card(), Rating.easy, now);

      expect(next.state, CardState.review);
      expect(next.intervalDays, 4);
    });

    test('again returns to the first step; hard repeats a later step', () {
      final second = card(state: CardState.learning, step: 1);

      expect(scheduler.schedule(second, Rating.again, now).step, 0);
      expect(delay(second, Rating.hard), const Duration(minutes: 10));
    });

    test('a single step makes hard 1.5x that step', () {
      const oneStep = SrsScheduler(
        SrsSettings(learningSteps: [Duration(minutes: 10)]),
      );
      expect(
        oneStep.nextDelay(card(), Rating.hard, now),
        const Duration(minutes: 15),
      );
    });

    test('new cards start at the configured starting ease', () {
      const easier = SrsScheduler(SrsSettings(startingEase: 2.0));
      expect(easier.schedule(card(ease: 2.5), Rating.good, now).easeFactor, 2);
    });
  });

  group('review cards', () {
    final mature = card(state: CardState.review, intervalDays: 10);

    test('hard ×1.2, good ×ease, easy ×ease×1.3', () {
      expect(delay(mature, Rating.hard), const Duration(days: 12));
      expect(delay(mature, Rating.good), const Duration(days: 25));
      expect(delay(mature, Rating.easy), const Duration(days: 33));
    });

    test('hard and easy move ease; good keeps it', () {
      expect(scheduler.schedule(mature, Rating.hard, now).easeFactor, 2.35);
      expect(scheduler.schedule(mature, Rating.good, now).easeFactor, 2.5);
      expect(scheduler.schedule(mature, Rating.easy, now).easeFactor, 2.65);
    });

    test('each answer is at least a day more than the one below it', () {
      final young = card(state: CardState.review, intervalDays: 1, ease: 1.3);

      expect(delay(young, Rating.hard).inDays, 2);
      expect(delay(young, Rating.good).inDays, 3);
      expect(delay(young, Rating.easy).inDays, 4);
    });

    test('an overdue card earns credit for the days it survived', () {
      final overdue = card(
        state: CardState.review,
        intervalDays: 10,
        dueAt: now.subtract(const Duration(days: 10)),
      );

      // (10 + 10 / 2) × 2.5
      expect(delay(overdue, Rating.good), const Duration(days: 38));
    });

    test('again is a lapse: ease down, relearning, interval reset', () {
      final lapsed = scheduler.schedule(mature, Rating.again, now);

      expect(lapsed.state, CardState.relearning);
      expect(lapsed.lapses, 1);
      expect(lapsed.easeFactor, closeTo(2.3, 1e-9));
      expect(lapsed.intervalDays, 1);
      expect(lapsed.dueAt, now.add(const Duration(minutes: 10)));
    });

    test('ease never drops below 130%', () {
      final hard = card(state: CardState.review, intervalDays: 5, ease: 1.35);

      expect(scheduler.schedule(hard, Rating.again, now).easeFactor, 1.3);
    });

    test('the interval modifier and maximum interval apply', () {
      const tuned = SrsScheduler(
        SrsSettings(intervalModifier: 0.8, maximumIntervalDays: 20),
      );

      expect(tuned.nextDelay(mature, Rating.hard, now).inDays, 11);
      expect(tuned.nextDelay(mature, Rating.good, now).inDays, 20);
      expect(tuned.nextDelay(mature, Rating.easy, now).inDays, 20);
    });

    test('a lapse keeps part of the interval when configured', () {
      const kind = SrsScheduler(SrsSettings(lapseIntervalFactor: 0.5));

      expect(kind.schedule(mature, Rating.again, now).intervalDays, 5);
    });

    test('without relearning steps a lapse stays in review', () {
      const noRelearn = SrsScheduler(SrsSettings(relearningSteps: []));
      final lapsed = noRelearn.schedule(mature, Rating.again, now);

      expect(lapsed.state, CardState.review);
      expect(lapsed.dueAt, now.add(const Duration(days: 1)));
    });
  });

  group('relearning cards', () {
    test('good after the relearning step returns to review', () {
      final relearning = card(
        state: CardState.relearning,
        intervalDays: 3,
        ease: 2.3,
      );
      final back = scheduler.schedule(relearning, Rating.good, now);

      expect(back.state, CardState.review);
      expect(back.intervalDays, 3);
      expect(back.easeFactor, 2.3);
    });
  });

  group('StepFormat', () {
    test('formats and parses Anki step text', () {
      const steps = [
        Duration(minutes: 1),
        Duration(minutes: 10),
        Duration(hours: 1),
        Duration(days: 1),
      ];
      expect(StepFormat.format(steps), '1m 10m 1h 1d');
      expect(StepFormat.parse('1m 10m 1h 1d'), steps);
      expect(StepFormat.parse('30s, 5'), const [
        Duration(seconds: 30),
        Duration(minutes: 5),
      ]);
      expect(StepFormat.parse(''), isEmpty);
      expect(StepFormat.parse('10x'), isNull);
      expect(StepFormat.parse('0m'), isNull);
    });
  });
}
