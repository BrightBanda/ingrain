enum CardType { sentence, vocabulary }

enum Rating { again, hard, good, easy }

class ReviewCard {
  final String id;
  final String uid;
  final CardType cardType;
  final String sourceItemId;
  final String promptText;
  final String? answerText;
  final DateTime createdAt;
  final DateTime dueAt;
  final int intervalDays;
  final int repetitions;
  final double easeFactor;
  final int reviewCount;
  final DateTime? lastReviewedAt;

  const ReviewCard({
    required this.id,
    required this.uid,
    required this.cardType,
    required this.sourceItemId,
    required this.promptText,
    this.answerText,
    required this.createdAt,
    required this.dueAt,
    this.intervalDays = 0,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.reviewCount = 0,
    this.lastReviewedAt,
  });

  bool isDueAt(DateTime now) => !dueAt.isAfter(now);

  ReviewCard copyWith({
    String? id,
    String? uid,
    CardType? cardType,
    String? sourceItemId,
    String? promptText,
    String? Function()? answerText,
    DateTime? createdAt,
    DateTime? dueAt,
    int? intervalDays,
    int? repetitions,
    double? easeFactor,
    int? reviewCount,
    DateTime? Function()? lastReviewedAt,
  }) {
    return ReviewCard(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      cardType: cardType ?? this.cardType,
      sourceItemId: sourceItemId ?? this.sourceItemId,
      promptText: promptText ?? this.promptText,
      answerText: answerText != null ? answerText() : this.answerText,
      createdAt: createdAt ?? this.createdAt,
      dueAt: dueAt ?? this.dueAt,
      intervalDays: intervalDays ?? this.intervalDays,
      repetitions: repetitions ?? this.repetitions,
      easeFactor: easeFactor ?? this.easeFactor,
      reviewCount: reviewCount ?? this.reviewCount,
      lastReviewedAt: lastReviewedAt != null
          ? lastReviewedAt()
          : this.lastReviewedAt,
    );
  }
}
