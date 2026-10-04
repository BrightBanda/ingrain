import 'package:ingrain/features/srs/domain/review_card.dart';

class ReviewEvent {
  final String id;
  final String uid;
  final String cardId;
  final CardType cardType;
  final Rating rating;
  final DateTime reviewedAt;
  final int intervalDaysAfter;

  const ReviewEvent({
    required this.id,
    required this.uid,
    required this.cardId,
    required this.cardType,
    required this.rating,
    required this.reviewedAt,
    required this.intervalDaysAfter,
  });
}
