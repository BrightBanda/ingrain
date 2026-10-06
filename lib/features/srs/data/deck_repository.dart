import 'package:ingrain/core/storage/document_store.dart';
import 'package:ingrain/features/auth/domain/auth_repository.dart';
import 'package:ingrain/features/srs/data/local_review_repository.dart';
import 'package:ingrain/features/srs/domain/deck.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/review_repository.dart';

/// User decks live at `users/{uid}/decks/{id}`. Cards stay in the review
/// card collection and point at their deck through `deckId`, so scheduling
/// and history work the same for every deck.
class DeckRepository {
  final DocumentStore _store;
  final AuthRepository _auth;
  final ReviewRepository _cards;

  DeckRepository(this._store, this._auth, this._cards);

  static const collection = 'decks';

  /// The built-in deck first, then the user's, oldest first.
  Future<List<Deck>> listDecks() async {
    final uid = await _auth.ensureUid();
    final docs = await _store.listDocs(uid, collection);
    final own = docs.map(_fromMap).whereType<Deck>().toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [Deck.minedPhrases, ...own];
  }

  Future<Deck?> getDeck(String id) async {
    if (id == minedPhrasesDeckId) return Deck.minedPhrases;
    final uid = await _auth.ensureUid();
    return _fromMap(await _store.getDoc(uid, collection, id));
  }

  Future<Deck> createDeck(String name, {String? description}) async {
    final uid = await _auth.ensureUid();
    final deck = Deck(
      id: LocalReviewRepository.generateId('deck'),
      name: name.trim(),
      description: _blankToNull(description),
      createdAt: DateTime.now(),
    );
    await _store.setDoc(uid, collection, deck.id, _toMap(deck));
    return deck;
  }

  Future<void> renameDeck(Deck deck, String name) async {
    if (deck.isBuiltIn) return;
    final uid = await _auth.ensureUid();
    await _store.setDoc(uid, collection, deck.id, {
      'name': name.trim(),
    }, merge: true);
  }

  /// Deletes the deck and every card in it. Built-in decks are kept.
  Future<void> deleteDeck(Deck deck) async {
    if (deck.isBuiltIn) return;
    for (final card in await cardsIn(deck.id)) {
      await deleteCard(card);
    }
    final uid = await _auth.ensureUid();
    await _store.deleteDoc(uid, collection, deck.id);
  }

  /// Newest first.
  Future<List<ReviewCard>> cardsIn(String deckId) async {
    final cards = await _cards.listAllCards();
    return cards.where((card) => card.deckId == deckId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// A hand-written front/back card, due immediately.
  Future<ReviewCard> addCard({
    required String deckId,
    required String front,
    String? back,
  }) async {
    final uid = await _auth.ensureUid();
    final id = LocalReviewRepository.generateId('card');
    final now = DateTime.now();
    final card = ReviewCard(
      id: id,
      uid: uid,
      deckId: deckId,
      cardType: CardType.basic,
      // Hand-written cards are their own source, so deleting one by source
      // never touches another card.
      sourceItemId: id,
      promptText: front.trim(),
      answerText: _blankToNull(back),
      createdAt: now,
      dueAt: now,
    );
    await _cards.saveCard(card);
    return card;
  }

  /// Removes only the card; a mined sentence or saved word stays in its list.
  Future<void> deleteCard(ReviewCard card) =>
      _cards.deleteCardsForSource(card.sourceItemId);

  static Deck? _fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final name = map['name'];
    if (id is! String || name is! String) return null;
    return Deck(
      id: id,
      name: name,
      description: map['description'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.utc(2026),
    );
  }

  static Map<String, dynamic> _toMap(Deck deck) => {
    'id': deck.id,
    'name': deck.name,
    'description': deck.description,
    'createdAt': deck.createdAt.toIso8601String(),
  };

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
