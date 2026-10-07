import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/srs_settings.dart';
import 'package:ingrain/features/srs/domain/study_queue.dart';

void main() {
  final now = DateTime(2026, 5, 1, 12);

  ReviewCard card(
    String id,
    CardState state, {
    DateTime? due,
    String deck = 'a',
    int createdMinute = 0,
    bool suspended = false,
  }) => ReviewCard(
    id: id,
    uid: 'u',
    deckId: deck,
    cardType: CardType.basic,
    sourceItemId: id,
    promptText: id,
    createdAt: DateTime(2026, 1, 1, 0, createdMinute),
    dueAt: due ?? now,
    state: state,
    suspended: suspended,
  );

  StudyQueue build(
    List<ReviewCard> cards, {
    SrsSettings settings = const SrsSettings(),
    Map<String, DailyStudyCounts> studied = const {},
    String? deckId,
  }) => StudyQueue.build(
    cards: cards,
    settings: settings,
    now: now,
    studiedToday: studied,
    deckId: deckId,
  );

  test('learning first, then reviews, then new cards', () {
    final queue = build([
      card('new', CardState.newCard),
      card(
        'review',
        CardState.review,
        due: now.subtract(const Duration(days: 1)),
      ),
      card('learning', CardState.learning),
    ]);

    expect(queue.cards.map((c) => c.id), ['learning', 'review', 'new']);
  });

  test('reviews due later today count; tomorrow\'s do not', () {
    final queue = build([
      card('tonight', CardState.review, due: DateTime(2026, 5, 1, 23)),
      card('tomorrow', CardState.review, due: DateTime(2026, 5, 2, 9)),
    ]);

    expect(queue.reviews.map((c) => c.id), ['tonight']);
  });

  test('learning cards due within 20 minutes are studied now', () {
    final queue = build([
      card(
        'soon',
        CardState.learning,
        due: now.add(const Duration(minutes: 15)),
      ),
      card(
        'later',
        CardState.relearning,
        due: now.add(const Duration(hours: 1)),
      ),
    ]);

    expect(queue.learning.map((c) => c.id), ['soon']);
  });

  test('new cards come in order, capped by what is left of the limit', () {
    final cards = [
      for (var i = 0; i < 10; i++)
        card('n$i', CardState.newCard, createdMinute: 10 - i),
    ];

    final queue = build(
      cards,
      settings: const SrsSettings(newCardsPerDay: 5),
      studied: {'a': const DailyStudyCounts(newStudied: 2)},
    );

    expect(queue.fresh.map((c) => c.id), ['n9', 'n8', 'n7']);
  });

  test('reviews are capped by the daily review limit', () {
    final cards = [
      for (var i = 0; i < 5; i++)
        card('r$i', CardState.review, due: now.subtract(Duration(days: i))),
    ];

    final queue = build(
      cards,
      settings: const SrsSettings(maximumReviewsPerDay: 3),
      studied: {'a': const DailyStudyCounts(reviewsDone: 1)},
    );

    expect(queue.reviews, hasLength(2));
    expect(queue.reviews.first.id, 'r4', reason: 'most overdue first');
  });

  test('limits apply per deck and suspended cards never appear', () {
    final queue = build([
      card('a1', CardState.newCard),
      card('b1', CardState.newCard, deck: 'b'),
      card('b2', CardState.newCard, deck: 'b'),
      card('s', CardState.review, suspended: true),
    ], settings: const SrsSettings(newCardsPerDay: 1));

    expect(queue.fresh.map((c) => c.id).toSet(), {'a1', 'b1'});
    expect(
      build([card('s', CardState.newCard, suspended: true)]).isEmpty,
      isTrue,
    );
  });

  test('one deck only when asked', () {
    final queue = build([
      card('a1', CardState.newCard),
      card('b1', CardState.newCard, deck: 'b'),
    ], deckId: 'b');

    expect(queue.cards.single.id, 'b1');
  });
}
