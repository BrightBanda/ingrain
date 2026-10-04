import 'package:ingrain/features/srs/domain/review_card.dart';

class ReviewCardDto {
  final Map<String, dynamic> map;

  ReviewCardDto({
    required String id,
    required String uid,
    required CardType cardType,
    required String sourceItemId,
    required String promptText,
    String? answerText,
    required DateTime createdAt,
    required DateTime dueAt,
    int intervalDays = 0,
    int repetitions = 0,
    double easeFactor = 2.5,
    int reviewCount = 0,
    DateTime? lastReviewedAt,
  }) : map = {
         'id': id,
         'uid': uid,
         'cardType': cardType.name,
         'sourceItemId': sourceItemId,
         'promptText': promptText,
         'answerText': answerText,
         'createdAt': createdAt.toIso8601String(),
         'dueAt': dueAt.toIso8601String(),
         'intervalDays': intervalDays,
         'repetitions': repetitions,
         'easeFactor': easeFactor,
         'reviewCount': reviewCount,
         'lastReviewedAt': lastReviewedAt?.toIso8601String(),
       };

  ReviewCardDto.fromMap(Map<String, dynamic> data) : map = Map.from(data);

  ReviewCard toDomain() {
    final lastReviewedAtStr = map['lastReviewedAt'] as String?;
    return ReviewCard(
      id: map['id'] as String,
      uid: map['uid'] as String,
      cardType: CardType.values.firstWhere(
        (e) => e.name == map['cardType'],
        orElse: () => CardType.sentence,
      ),
      sourceItemId: map['sourceItemId'] as String,
      promptText: map['promptText'] as String,
      answerText: map['answerText'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      dueAt: DateTime.parse(map['dueAt'] as String),
      intervalDays: (map['intervalDays'] as num?)?.toInt() ?? 0,
      repetitions: (map['repetitions'] as num?)?.toInt() ?? 0,
      easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      lastReviewedAt: lastReviewedAtStr != null
          ? DateTime.parse(lastReviewedAtStr)
          : null,
    );
  }

  static ReviewCard? fromMapSafe(Map<String, dynamic> data) {
    const requiredKeys = [
      'id',
      'uid',
      'sourceItemId',
      'promptText',
      'createdAt',
      'dueAt',
    ];
    for (final key in requiredKeys) {
      if (data[key] == null) return null;
    }
    return ReviewCardDto.fromMap(data).toDomain();
  }
}
