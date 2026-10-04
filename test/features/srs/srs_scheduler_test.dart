import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/srs_scheduler.dart';

void main() {
  const scheduler = SrsScheduler();
  final start = DateTime(2026, 1, 1, 12, 0, 0);

  ReviewCard card({
    int intervalDays = 0,
    int repetitions = 0,
    double easeFactor = SrsScheduler.initialEaseFactor,
    int reviewCount = 0,
  }) {
    return ReviewCard(
      id: 'card-1',
      uid: 'uid-1',
      cardType: CardType.sentence,
      sourceItemId: 'sentence-1',
      promptText: '日本語',
      createdAt: start,
      dueAt: start,
      intervalDays: intervalDays,
      repetitions: repetitions,
      easeFactor: easeFactor,
      reviewCount: reviewCount,
    );
  }

  group('SrsScheduler defaults', () {
    test('new card is due immediately with SM-2 defaults', () {
      final fresh = card();
      expect(fresh.intervalDays, 0);
      expect(fresh.repetitions, 0);
      expect(fresh.easeFactor, 2.5);
      expect(fresh.dueAt, start);
      expect(fresh.reviewCount, 0);
    });

    test('isDueAt is inclusive of the due instant', () {
      final fresh = card();
      expect(fresh.isDueAt(start), isTrue);
      expect(
        fresh.isDueAt(start.subtract(const Duration(seconds: 1))),
        isFalse,
      );
    });
  });

  group('SrsScheduler good', () {
    test('first good schedules 1 day out', () {
      final result = scheduler.schedule(card(), Rating.good, start);
      expect(result.intervalDays, 1);
      expect(result.repetitions, 1);
      expect(result.dueAt, start.add(const Duration(days: 1)));
    });

    test('second good schedules 6 days out', () {
      final result = scheduler.schedule(
        card(intervalDays: 1, repetitions: 1),
        Rating.good,
        start,
      );
      expect(result.intervalDays, 6);
      expect(result.dueAt, start.add(const Duration(days: 6)));
    });

    test('third good multiplies by the ease factor', () {
      final result = scheduler.schedule(
        card(intervalDays: 6, repetitions: 2),
        Rating.good,
        start,
      );
      expect(result.intervalDays, 15);
      expect(result.dueAt, start.add(const Duration(days: 15)));
    });

    test('good leaves the ease factor unchanged', () {
      final result = scheduler.schedule(card(), Rating.good, start);
      expect(result.easeFactor, 2.5);
    });

    test('good increments review count and stamps lastReviewedAt', () {
      final result = scheduler.schedule(card(), Rating.good, start);
      expect(result.reviewCount, 1);
      expect(result.lastReviewedAt, start);
    });
  });

  group('SrsScheduler again', () {
    test('again resets repetitions and interval and delays 10 minutes', () {
      final result = scheduler.schedule(
        card(intervalDays: 15, repetitions: 3, reviewCount: 3),
        Rating.again,
        start,
      );
      expect(result.repetitions, 0);
      expect(result.intervalDays, 0);
      expect(result.dueAt, start.add(const Duration(minutes: 10)));
      expect(result.reviewCount, 4);
    });

    test('again still counts the review and stamps lastReviewedAt', () {
      final result = scheduler.schedule(card(), Rating.again, start);
      expect(result.reviewCount, 1);
      expect(result.lastReviewedAt, start);
    });

    test('again penalty floors the ease factor at 1.3', () {
      var current = card(easeFactor: 1.6);
      current = scheduler.schedule(current, Rating.again, start);
      expect(current.easeFactor, closeTo(1.4, 0.0001));
      current = scheduler.schedule(current, Rating.again, start);
      expect(current.easeFactor, 1.3);
      current = scheduler.schedule(current, Rating.again, start);
      expect(current.easeFactor, 1.3);
    });
  });

  group('SrsScheduler hard', () {
    test('hard multiplies the interval by 1.2 with a floor of 1', () {
      final fromZero = scheduler.schedule(card(), Rating.hard, start);
      expect(fromZero.intervalDays, 1);
      expect(fromZero.dueAt, start.add(const Duration(days: 1)));

      final fromTen = scheduler.schedule(
        card(intervalDays: 10, repetitions: 2),
        Rating.hard,
        start,
      );
      expect(fromTen.intervalDays, 12);
    });

    test('hard increments repetitions and penalizes ease by 0.15', () {
      final result = scheduler.schedule(
        card(repetitions: 2),
        Rating.hard,
        start,
      );
      expect(result.repetitions, 3);
      expect(result.easeFactor, closeTo(2.35, 0.0001));
    });

    test('hard ease floor is 1.3', () {
      final result = scheduler.schedule(
        card(easeFactor: 1.35),
        Rating.hard,
        start,
      );
      expect(result.easeFactor, 1.3);
    });
  });

  group('SrsScheduler easy', () {
    test('first easy jumps straight to 4 days', () {
      final result = scheduler.schedule(card(), Rating.easy, start);
      expect(result.intervalDays, 4);
      expect(result.dueAt, start.add(const Duration(days: 4)));
    });

    test('easy multiplies interval by ease and 1.3 and bumps ease', () {
      final result = scheduler.schedule(
        card(intervalDays: 6, repetitions: 2),
        Rating.easy,
        start,
      );
      expect(result.intervalDays, 20);
      expect(result.easeFactor, closeTo(2.65, 0.0001));
    });

    test('easy increments repetitions', () {
      final result = scheduler.schedule(card(), Rating.easy, start);
      expect(result.repetitions, 1);
    });
  });

  group('SrsScheduler nextIntervalDays preview', () {
    test('previews match the scheduled interval', () {
      final fresh = card();
      expect(scheduler.nextIntervalDays(fresh, Rating.again), 0);
      expect(scheduler.nextIntervalDays(fresh, Rating.hard), 1);
      expect(scheduler.nextIntervalDays(fresh, Rating.good), 1);
      expect(scheduler.nextIntervalDays(fresh, Rating.easy), 4);

      final mature = card(intervalDays: 15, repetitions: 4);
      expect(scheduler.nextIntervalDays(mature, Rating.good), 38);
      expect(scheduler.nextIntervalDays(mature, Rating.hard), 18);
      expect(scheduler.nextIntervalDays(mature, Rating.easy), 49);
    });
  });
}
