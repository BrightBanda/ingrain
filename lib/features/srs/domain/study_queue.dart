import 'dart:math';

import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/srs_settings.dart';

/// Today's cards to study, in Anki's order: learning cards first (they are
/// on a short clock), then reviews due today, then new cards.
class StudyQueue {
  final List<ReviewCard> learning;
  final List<ReviewCard> reviews;
  final List<ReviewCard> fresh;

  const StudyQueue({
    this.learning = const [],
    this.reviews = const [],
    this.fresh = const [],
  });

  static const empty = StudyQueue();

  /// Learning cards due within this window are studied now rather than
  /// making the learner wait a few minutes (Anki's "learn ahead limit").
  static const learnAhead = Duration(minutes: 20);

  List<ReviewCard> get cards => [...learning, ...reviews, ...fresh];

  int get total => learning.length + reviews.length + fresh.length;

  bool get isEmpty => total == 0;

  /// Builds the queue for one deck, or for every deck when [deckId] is null.
  ///
  /// Daily limits are per deck, like Anki's defaults: each deck may introduce
  /// [SrsSettings.newCardsPerDay] new cards and show
  /// [SrsSettings.maximumReviewsPerDay] reviews, minus what [studiedToday]
  /// says was already used. Suspended cards never appear.
  static StudyQueue build({
    required List<ReviewCard> cards,
    required SrsSettings settings,
    required DateTime now,
    Map<String, DailyStudyCounts> studiedToday = const {},
    String? deckId,
  }) {
    final endOfToday = DateTime(now.year, now.month, now.day + 1);
    final byDeck = <String, List<ReviewCard>>{};
    for (final card in cards) {
      if (card.suspended) continue;
      if (deckId != null && card.deckId != deckId) continue;
      byDeck.putIfAbsent(card.deckId, () => []).add(card);
    }

    final learning = <ReviewCard>[];
    final reviews = <ReviewCard>[];
    final fresh = <ReviewCard>[];
    for (final MapEntry(key: deck, value: deckCards) in byDeck.entries) {
      final used = studiedToday[deck] ?? const DailyStudyCounts();

      learning.addAll(
        deckCards.where(
          (c) => c.state.isLearning && !c.dueAt.isAfter(now.add(learnAhead)),
        ),
      );

      final dueReviews =
          deckCards
              .where(
                (c) =>
                    c.state == CardState.review && c.dueAt.isBefore(endOfToday),
              )
              .toList()
            ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      reviews.addAll(
        dueReviews.take(
          max(0, settings.maximumReviewsPerDay - used.reviewsDone),
        ),
      );

      final newCards =
          deckCards.where((c) => c.state == CardState.newCard).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      fresh.addAll(
        newCards.take(max(0, settings.newCardsPerDay - used.newStudied)),
      );
    }

    learning.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    reviews.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return StudyQueue(learning: learning, reviews: reviews, fresh: fresh);
  }
}
