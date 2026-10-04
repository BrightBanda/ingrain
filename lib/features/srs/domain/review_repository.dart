import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/review_event.dart';

abstract interface class ReviewRepository {
  Future<ReviewCard> createCard({
    required CardType cardType,
    required String sourceItemId,
    required String promptText,
    String? answerText,
    DateTime? createdAt,
    DateTime? dueAt,
  });

  Future<void> saveCard(ReviewCard card);

  Future<List<ReviewCard>> listDue({DateTime? now});

  Future<List<ReviewCard>> listAllCards();

  Future<ReviewEvent> recordReview({
    required String cardId,
    required CardType cardType,
    required Rating rating,
    required DateTime reviewedAt,
    required int intervalDaysAfter,
  });

  Future<List<ReviewEvent>> listReviewHistory({int limit});

  Future<void> deleteCardsForSource(String sourceItemId);

  Future<int> countDue({DateTime? now});
}
