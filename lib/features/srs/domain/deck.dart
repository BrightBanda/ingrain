import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/study_queue.dart';

/// A named set of flashcards, like an Anki deck.
class Deck {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;

  /// Built-in decks always exist and cannot be renamed or deleted.
  final bool isBuiltIn;

  const Deck({
    required this.id,
    required this.name,
    required this.createdAt,
    this.description,
    this.isBuiltIn = false,
  });

  /// Everything mined while immersing: transcript lines, dialogue lines and
  /// saved words.
  static final minedPhrases = Deck(
    id: minedPhrasesDeckId,
    name: 'Mined phrases',
    description: 'Lines and words you save while immersing',
    createdAt: DateTime.utc(2026),
    isBuiltIn: true,
  );
}

/// A deck with Anki's three counts: new cards available today, cards in
/// learning, and reviews due today (all within the daily limits).
class DeckSummary {
  final Deck deck;
  final int total;
  final int fresh;
  final int learning;
  final int due;

  const DeckSummary({
    required this.deck,
    required this.total,
    required this.fresh,
    required this.learning,
    required this.due,
  });

  /// Everything there is to study in this deck today.
  int get toStudy => fresh + learning + due;

  static DeckSummary of(Deck deck, List<ReviewCard> cards, StudyQueue queue) {
    bool inDeck(ReviewCard card) => card.deckId == deck.id;
    return DeckSummary(
      deck: deck,
      total: cards.where(inDeck).length,
      fresh: queue.fresh.where(inDeck).length,
      learning: queue.learning.where(inDeck).length,
      due: queue.reviews.where(inDeck).length,
    );
  }
}
