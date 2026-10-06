import 'package:ingrain/features/srs/domain/review_card.dart';

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

/// A deck with the counts its tile shows.
class DeckSummary {
  final Deck deck;
  final int total;
  final int due;

  /// Cards never reviewed yet.
  final int fresh;

  const DeckSummary({
    required this.deck,
    required this.total,
    required this.due,
    required this.fresh,
  });

  static DeckSummary of(Deck deck, List<ReviewCard> cards, DateTime now) {
    final inDeck = cards.where((card) => card.deckId == deck.id);
    return DeckSummary(
      deck: deck,
      total: inDeck.length,
      due: inDeck.where((card) => card.isDueAt(now)).length,
      fresh: inDeck.where((card) => card.reviewCount == 0).length,
    );
  }
}
