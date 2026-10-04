import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/review_event.dart';

class ReviewEventDto {
  final Map<String, dynamic> map;

  ReviewEventDto({
    required String id,
    required String uid,
    required String cardId,
    required CardType cardType,
    required Rating rating,
    required DateTime reviewedAt,
    required int intervalDaysAfter,
  }) : map = {
         'id': id,
         'uid': uid,
         'cardId': cardId,
         'cardType': cardType.name,
         'rating': rating.name,
         'reviewedAt': reviewedAt.toIso8601String(),
         'intervalDaysAfter': intervalDaysAfter,
       };

  ReviewEventDto.fromMap(Map<String, dynamic> data) : map = Map.from(data);

  ReviewEvent toDomain() {
    return ReviewEvent(
      id: map['id'] as String,
      uid: map['uid'] as String,
      cardId: map['cardId'] as String,
      cardType: CardType.values.firstWhere(
        (e) => e.name == map['cardType'],
        orElse: () => CardType.sentence,
      ),
      rating: Rating.values.firstWhere(
        (e) => e.name == map['rating'],
        orElse: () => Rating.good,
      ),
      reviewedAt: DateTime.parse(map['reviewedAt'] as String),
      intervalDaysAfter: (map['intervalDaysAfter'] as num?)?.toInt() ?? 0,
    );
  }

  static ReviewEvent? fromMapSafe(Map<String, dynamic> data) {
    const requiredKeys = ['id', 'uid', 'cardId', 'reviewedAt'];
    for (final key in requiredKeys) {
      if (data[key] == null) return null;
    }
    return ReviewEventDto.fromMap(data).toDomain();
  }
}
