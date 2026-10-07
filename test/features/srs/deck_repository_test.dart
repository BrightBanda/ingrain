import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/core/storage/local_document_store.dart';
import 'package:ingrain/features/srs/data/deck_repository.dart';
import 'package:ingrain/features/srs/data/local_review_repository.dart';
import 'package:ingrain/features/srs/domain/deck.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/srs_settings.dart';
import 'package:ingrain/features/srs/domain/study_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  late LocalDocumentStore store;
  late LocalReviewRepository cards;
  late DeckRepository decks;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LocalDocumentStore(await SharedPreferences.getInstance());
    final auth = FakeAuthRepository();
    cards = LocalReviewRepository(store, auth);
    decks = DeckRepository(store, auth, cards);
  });

  test('Mined phrases always exists and comes first', () async {
    await decks.createDeck('Verbs');

    final listed = await decks.listDecks();

    expect(listed.map((d) => d.name), ['Mined phrases', 'Verbs']);
    expect(listed.first.isBuiltIn, isTrue);
  });

  test('mined sentences and words land in Mined phrases', () async {
    await cards.createCard(
      cardType: CardType.sentence,
      sourceItemId: 'sentence-1',
      promptText: 'これはテストです。',
    );
    await cards.createCard(
      cardType: CardType.vocabulary,
      sourceItemId: 'word-1',
      promptText: '猫',
    );

    final mined = await decks.cardsIn(minedPhrasesDeckId);

    expect(mined.map((c) => c.promptText).toSet(), {'これはテストです。', '猫'});
  });

  test('a card saved before decks existed belongs to Mined phrases', () async {
    await store.setDoc(
      'test-uid',
      LocalReviewRepository.cardCollection,
      'old',
      {
        'id': 'old',
        'uid': 'test-uid',
        'cardType': 'sentence',
        'sourceItemId': 's-old',
        'promptText': '古い',
        'createdAt': '2026-01-01T00:00:00.000',
        'dueAt': '2026-01-01T00:00:00.000',
      },
    );

    final all = await cards.listAllCards();

    expect(all.single.deckId, minedPhrasesDeckId);
  });

  test('hand-written cards go to their deck and are due now', () async {
    final deck = await decks.createDeck('Verbs', description: 'う-verbs');

    final card = await decks.addCard(
      deckId: deck.id,
      front: ' 食べる ',
      back: 'to eat',
    );

    expect(card.cardType, CardType.basic);
    expect(card.promptText, '食べる');
    expect(card.isDueAt(DateTime.now()), isTrue);
    expect((await decks.cardsIn(deck.id)).single.answerText, 'to eat');
    expect(await decks.cardsIn(minedPhrasesDeckId), isEmpty);
  });

  test('deleting a deck removes its cards and nothing else', () async {
    final deck = await decks.createDeck('Verbs');
    await decks.addCard(deckId: deck.id, front: '食べる');
    await cards.createCard(
      cardType: CardType.sentence,
      sourceItemId: 'sentence-1',
      promptText: 'これはテストです。',
    );

    await decks.deleteDeck(deck);

    expect((await decks.listDecks()).map((d) => d.id), [minedPhrasesDeckId]);
    expect((await cards.listAllCards()).single.promptText, 'これはテストです。');
  });

  test('the built-in deck cannot be renamed or deleted', () async {
    await decks.renameDeck(Deck.minedPhrases, 'Something else');
    await decks.deleteDeck(Deck.minedPhrases);

    final listed = await decks.listDecks();
    expect(listed.single.name, 'Mined phrases');
  });

  test('summaries count new, learning and due cards per deck', () {
    final now = DateTime(2026, 5, 1, 12);
    ReviewCard card(
      String id,
      CardState state, {
      required DateTime due,
      String deck = minedPhrasesDeckId,
    }) => ReviewCard(
      id: id,
      uid: 'u',
      deckId: deck,
      cardType: CardType.basic,
      sourceItemId: id,
      promptText: id,
      createdAt: DateTime(2026),
      dueAt: due,
      state: state,
    );

    final cards = [
      card('new', CardState.newCard, due: now),
      card('learning', CardState.learning, due: now),
      card('due', CardState.review, due: DateTime(2026, 4, 1)),
      card('later', CardState.review, due: DateTime(2026, 6, 1)),
      card('elsewhere', CardState.newCard, due: now, deck: 'other'),
    ];
    final queue = StudyQueue.build(
      cards: cards,
      settings: const SrsSettings(),
      now: now,
    );

    final summary = DeckSummary.of(Deck.minedPhrases, cards, queue);

    expect(
      (summary.total, summary.fresh, summary.learning, summary.due),
      (4, 1, 1, 1),
    );
    expect(summary.toStudy, 3);
  });
}
