/// Cards saved while immersing land here unless they say otherwise.
const minedPhrasesDeckId = 'mined-phrases';

/// `basic` is a front/back card the user wrote by hand in a deck.
enum CardType { sentence, vocabulary, basic }

enum Rating { again, hard, good, easy }

/// Where a card is in Anki's life cycle.
///
/// New cards climb the learning steps (minutes apart) until they graduate to
/// review (days apart). A failed review card drops into relearning steps and
/// then returns to review with a shorter interval.
enum CardState {
  newCard,
  learning,
  review,
  relearning;

  bool get isLearning => this == learning || this == relearning;
}

class ReviewCard {
  final String id;
  final String uid;
  final String deckId;
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
  final CardState state;

  /// Index into the learning or relearning steps while [state] is one of
  /// those; unused otherwise.
  final int step;

  /// How many times this card was forgotten after graduating.
  final int lapses;

  /// Suspended cards never come up for study (Anki's "suspend").
  final bool suspended;

  const ReviewCard({
    required this.id,
    required this.uid,
    this.deckId = minedPhrasesDeckId,
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
    this.state = CardState.newCard,
    this.step = 0,
    this.lapses = 0,
    this.suspended = false,
  });

  bool isDueAt(DateTime now) => !suspended && !dueAt.isAfter(now);

  ReviewCard copyWith({
    String? id,
    String? uid,
    String? deckId,
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
    CardState? state,
    int? step,
    int? lapses,
    bool? suspended,
  }) {
    return ReviewCard(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      deckId: deckId ?? this.deckId,
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
      state: state ?? this.state,
      step: step ?? this.step,
      lapses: lapses ?? this.lapses,
      suspended: suspended ?? this.suspended,
    );
  }
}
