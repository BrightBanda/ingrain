import 'package:ingrain/features/srs/domain/review_card.dart';

class ReviewCardDto {
  final Map<String, dynamic> map;

  ReviewCardDto({
    required String id,
    required String uid,
    String deckId = minedPhrasesDeckId,
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
    CardState state = CardState.newCard,
    int step = 0,
    int lapses = 0,
    bool suspended = false,
  }) : map = {
         'id': id,
         'uid': uid,
         'deckId': deckId,
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
         'state': state.name,
         'step': step,
         'lapses': lapses,
         'suspended': suspended,
       };

  /// Every stored field of [card].
  ReviewCardDto.fromDomain(ReviewCard card)
    : this(
        id: card.id,
        uid: card.uid,
        deckId: card.deckId,
        cardType: card.cardType,
        sourceItemId: card.sourceItemId,
        promptText: card.promptText,
        answerText: card.answerText,
        createdAt: card.createdAt,
        dueAt: card.dueAt,
        intervalDays: card.intervalDays,
        repetitions: card.repetitions,
        easeFactor: card.easeFactor,
        reviewCount: card.reviewCount,
        lastReviewedAt: card.lastReviewedAt,
        state: card.state,
        step: card.step,
        lapses: card.lapses,
        suspended: card.suspended,
      );

  ReviewCardDto.fromMap(Map<String, dynamic> data) : map = Map.from(data);

  ReviewCard toDomain() {
    final lastReviewedAtStr = map['lastReviewedAt'] as String?;
    final reviewCount = (map['reviewCount'] as num?)?.toInt() ?? 0;
    final intervalDays = (map['intervalDays'] as num?)?.toInt() ?? 0;
    return ReviewCard(
      id: map['id'] as String,
      uid: map['uid'] as String,
      // Cards from before decks existed have no deckId: they were all mined.
      deckId: map['deckId'] as String? ?? minedPhrasesDeckId,
      cardType: CardType.values.firstWhere(
        (e) => e.name == map['cardType'],
        orElse: () => CardType.sentence,
      ),
      sourceItemId: map['sourceItemId'] as String,
      promptText: map['promptText'] as String,
      answerText: map['answerText'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      dueAt: DateTime.parse(map['dueAt'] as String),
      intervalDays: intervalDays,
      repetitions: (map['repetitions'] as num?)?.toInt() ?? 0,
      easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
      reviewCount: reviewCount,
      lastReviewedAt: lastReviewedAtStr != null
          ? DateTime.parse(lastReviewedAtStr)
          : null,
      state: _state(map['state'], reviewCount, intervalDays),
      step: (map['step'] as num?)?.toInt() ?? 0,
      lapses: (map['lapses'] as num?)?.toInt() ?? 0,
      suspended: map['suspended'] as bool? ?? false,
    );
  }

  /// Cards saved before card states existed have none: one never answered is
  /// new, one answered but with no interval yet was mid-learning, anything
  /// else had graduated to review.
  static CardState _state(Object? stored, int reviewCount, int intervalDays) {
    for (final state in CardState.values) {
      if (state.name == stored) return state;
    }
    if (reviewCount == 0) return CardState.newCard;
    if (intervalDays == 0) return CardState.learning;
    return CardState.review;
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
