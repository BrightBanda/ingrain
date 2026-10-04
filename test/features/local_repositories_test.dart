import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/core/storage/local_document_store.dart';
import 'package:ingrain/features/auth/data/local_auth_repository.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/sentence_mining/data/local_sentence_repository.dart';
import 'package:ingrain/features/srs/data/local_review_repository.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/srs_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalDocumentStore store;
  late LocalSentenceRepository sentences;
  late LocalReviewRepository reviews;

  final now = DateTime(2026, 3, 15, 12, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = LocalDocumentStore(prefs);
    final auth = LocalAuthRepository(store);
    sentences = LocalSentenceRepository(store, auth);
    reviews = LocalReviewRepository(store, auth);
  });

  group('LocalSentenceRepository', () {
    test('save then get round-trips every field', () async {
      final saved = await sentences.save(
        japanese: 'これはテストです。',
        translation: 'This is a test.',
        explanation: 'Declarative sentence.',
        sourceType: SourceType.youtube,
        sourceId: 'content-1',
        sourceTitle: 'My Video',
        timestampSeconds: 42,
        contextSentence: 'Adjacent line.',
        sessionId: 'session-1',
        createdAt: now,
      );

      final loaded = await sentences.get(saved.id);

      expect(loaded, isNotNull);
      expect(loaded!.japanese, 'これはテストです。');
      expect(loaded.translation, 'This is a test.');
      expect(loaded.explanation, 'Declarative sentence.');
      expect(loaded.sourceType, SourceType.youtube);
      expect(loaded.sourceId, 'content-1');
      expect(loaded.sourceTitle, 'My Video');
      expect(loaded.timestampSeconds, 42);
      expect(loaded.contextSentence, 'Adjacent line.');
      expect(loaded.sessionId, 'session-1');
      expect(loaded.createdAt, now);
    });

    test('generated ids are unique', () async {
      final first = await sentences.save(
        japanese: '一',
        sourceType: SourceType.manual,
        sourceId: 'manual',
        createdAt: now,
      );
      final second = await sentences.save(
        japanese: '二',
        sourceType: SourceType.manual,
        sourceId: 'manual',
        createdAt: now,
      );

      expect(first.id, isNot(second.id));
    });

    test('blank optional fields are stored as null', () async {
      final saved = await sentences.save(
        japanese: '文',
        translation: '   ',
        explanation: '',
        sourceType: SourceType.manual,
        sourceId: 'manual',
        createdAt: now,
      );

      final loaded = await sentences.get(saved.id);

      expect(loaded!.translation, isNull);
      expect(loaded.explanation, isNull);
      expect(loaded.hasTranslation, isFalse);
    });

    test('watchAll returns newest first', () async {
      await sentences.save(
        japanese: '古い',
        sourceType: SourceType.manual,
        sourceId: 'manual',
        createdAt: now.subtract(const Duration(days: 2)),
      );
      await sentences.save(
        japanese: '新しい',
        sourceType: SourceType.manual,
        sourceId: 'manual',
        createdAt: now,
      );

      final all = await sentences.watchAll().first;

      expect(all.length, 2);
      expect(all.first.japanese, '新しい');
    });

    test('delete removes the sentence', () async {
      final saved = await sentences.save(
        japanese: '文',
        sourceType: SourceType.manual,
        sourceId: 'manual',
        createdAt: now,
      );

      await sentences.delete(saved.id);

      expect(await sentences.get(saved.id), isNull);
      expect(await sentences.count(), 0);
    });

    test('get on an unknown id returns null', () async {
      expect(await sentences.get('missing'), isNull);
    });

    test('count and countCreatedOn aggregate by day', () async {
      await sentences.save(
        japanese: '今日',
        sourceType: SourceType.manual,
        sourceId: 'manual',
        createdAt: now,
      );
      await sentences.save(
        japanese: '昨日',
        sourceType: SourceType.manual,
        sourceId: 'manual',
        createdAt: now.subtract(const Duration(days: 1)),
      );
      await sentences.save(
        japanese: '一週間前',
        sourceType: SourceType.manual,
        sourceId: 'manual',
        createdAt: now.subtract(const Duration(days: 7)),
      );

      expect(await sentences.count(), 3);
      expect(await sentences.countCreatedOn(now), 1);
      expect(
        await sentences.countCreatedOn(now.subtract(const Duration(days: 1))),
        1,
      );
      expect(
        await sentences.countCreatedOn(now.subtract(const Duration(days: 3))),
        0,
      );
    });

    test('countCreatedOn only counts the requested calendar day', () async {
      await sentences.save(
        japanese: '夜',
        sourceType: SourceType.manual,
        sourceId: 'manual',
        createdAt: DateTime(2026, 3, 15, 23, 30),
      );
      await sentences.save(
        japanese: '朝',
        sourceType: SourceType.manual,
        sourceId: 'manual',
        createdAt: DateTime(2026, 3, 15, 0, 30),
      );

      expect(await sentences.countCreatedOn(DateTime(2026, 3, 15)), 2);
      expect(await sentences.countCreatedOn(DateTime(2026, 3, 16)), 0);
    });

    test(
      'documents land in the sentences collection under the user id',
      () async {
        final uid = await LocalAuthRepository(store).ensureUid();
        final saved = await sentences.save(
          japanese: '文',
          sourceType: SourceType.manual,
          sourceId: 'manual',
          createdAt: now,
        );

        final doc = await store.getDoc(uid, 'sentences', saved.id);

        expect(doc['japanese'], '文');
        expect(doc['sourceType'], 'manual');
        expect(doc['createdAt'], now.toIso8601String());
      },
    );

    test('review cards and history use separate collections', () async {
      final uid = await LocalAuthRepository(store).ensureUid();
      final card = await reviews.createCard(
        cardType: CardType.sentence,
        sourceItemId: 'sentence-1',
        promptText: '文',
        createdAt: now,
      );
      await reviews.recordReview(
        cardId: card.id,
        cardType: CardType.sentence,
        rating: Rating.good,
        reviewedAt: now,
        intervalDaysAfter: 1,
      );

      expect(await store.listDocs(uid, 'reviewCards'), hasLength(1));
      expect(await store.listDocs(uid, 'reviewHistory'), hasLength(1));
      expect(await store.listDocs(uid, 'sentences'), isEmpty);
    });
  });

  group('LocalReviewRepository', () {
    test('createCard produces a card that is due immediately', () async {
      final card = await reviews.createCard(
        cardType: CardType.sentence,
        sourceItemId: 'sentence-1',
        promptText: 'これはテストです。',
        answerText: 'This is a test.',
        createdAt: now,
      );

      expect(card.easeFactor, SrsScheduler.initialEaseFactor);
      expect(card.intervalDays, 0);
      expect(card.repetitions, 0);
      expect(card.dueAt, now);
      expect(card.isDueAt(now), isTrue);
    });

    test('answer text is trimmed and blank becomes null', () async {
      final withText = await reviews.createCard(
        cardType: CardType.sentence,
        sourceItemId: 'sentence-1',
        promptText: '文',
        answerText: '  text  ',
        createdAt: now,
      );
      final blank = await reviews.createCard(
        cardType: CardType.sentence,
        sourceItemId: 'sentence-2',
        promptText: '文',
        answerText: '   ',
        createdAt: now,
      );

      expect(withText.answerText, 'text');
      expect(blank.answerText, isNull);
    });

    test('listDue filters and orders by dueAt', () async {
      final late = await reviews.createCard(
        cardType: CardType.sentence,
        sourceItemId: 'late',
        promptText: 'late',
        createdAt: now,
        dueAt: now.add(const Duration(days: 3)),
      );
      final later = await reviews.createCard(
        cardType: CardType.sentence,
        sourceItemId: 'later',
        promptText: 'later',
        createdAt: now,
        dueAt: now.add(const Duration(minutes: 30)),
      );
      await reviews.createCard(
        cardType: CardType.sentence,
        sourceItemId: 'now',
        promptText: 'now',
        createdAt: now,
      );

      final due = await reviews.listDue(now: now);

      expect(due.length, 1);
      expect(due.single.promptText, 'now');
      expect(due.map((c) => c.id), isNot(contains(late.id)));
      expect(due.map((c) => c.id), isNot(contains(later.id)));
      expect(await reviews.countDue(now: now), 1);
    });

    test('a rescheduled card leaves and re-enters the due list', () async {
      const scheduler = SrsScheduler();
      final card = await reviews.createCard(
        cardType: CardType.sentence,
        sourceItemId: 'sentence-1',
        promptText: '文',
        createdAt: now,
      );
      expect(await reviews.countDue(now: now), 1);

      final scheduled = scheduler.schedule(card, Rating.good, now);
      await reviews.saveCard(scheduled);

      expect(await reviews.countDue(now: now), 0);
      expect(await reviews.countDue(now: now.add(const Duration(days: 1))), 1);

      final loaded = (await reviews.listAllCards()).single;
      expect(loaded.intervalDays, 1);
      expect(loaded.repetitions, 1);
      expect(loaded.reviewCount, 1);
      expect(loaded.lastReviewedAt, now);
    });

    test('saveCard persists the full scheduler state', () async {
      const scheduler = SrsScheduler();
      var card = await reviews.createCard(
        cardType: CardType.sentence,
        sourceItemId: 'sentence-1',
        promptText: '文',
        answerText: 'text',
        createdAt: now,
      );

      card = scheduler.schedule(card, Rating.good, now);
      card = scheduler.schedule(
        card,
        Rating.easy,
        now.add(const Duration(days: 1)),
      );
      card = scheduler.schedule(
        card,
        Rating.again,
        now.add(const Duration(days: 5)),
      );
      await reviews.saveCard(card);

      final loaded = (await reviews.listAllCards()).single;
      expect(loaded.intervalDays, 0);
      expect(loaded.repetitions, 0);
      expect(loaded.reviewCount, 3);
      expect(loaded.answerText, 'text');
      expect(loaded.promptText, '文');
    });

    test('recordReview logs history newest first', () async {
      await reviews.recordReview(
        cardId: 'card-1',
        cardType: CardType.sentence,
        rating: Rating.good,
        reviewedAt: now.subtract(const Duration(hours: 2)),
        intervalDaysAfter: 1,
      );
      await reviews.recordReview(
        cardId: 'card-1',
        cardType: CardType.sentence,
        rating: Rating.easy,
        reviewedAt: now,
        intervalDaysAfter: 4,
      );

      final history = await reviews.listReviewHistory();

      expect(history.length, 2);
      expect(history.first.rating, Rating.easy);
      expect(history.first.intervalDaysAfter, 4);
      expect(history.last.rating, Rating.good);
    });

    test('listReviewHistory respects the limit', () async {
      for (var i = 0; i < 5; i++) {
        await reviews.recordReview(
          cardId: 'card-$i',
          cardType: CardType.sentence,
          rating: Rating.good,
          reviewedAt: now.add(Duration(minutes: i)),
          intervalDaysAfter: 1,
        );
      }

      expect((await reviews.listReviewHistory()).length, 5);
      expect((await reviews.listReviewHistory(limit: 2)).length, 2);
    });

    test('deleteCardsForSource removes only the linked card', () async {
      await reviews.createCard(
        cardType: CardType.sentence,
        sourceItemId: 'sentence-1',
        promptText: 'one',
        createdAt: now,
      );
      await reviews.createCard(
        cardType: CardType.sentence,
        sourceItemId: 'sentence-2',
        promptText: 'two',
        createdAt: now,
      );

      await reviews.deleteCardsForSource('sentence-1');

      final remaining = await reviews.listAllCards();
      expect(remaining.length, 1);
      expect(remaining.single.sourceItemId, 'sentence-2');
    });

    test('review history survives card deletion', () async {
      final card = await reviews.createCard(
        cardType: CardType.sentence,
        sourceItemId: 'sentence-1',
        promptText: '文',
        createdAt: now,
      );
      await reviews.recordReview(
        cardId: card.id,
        cardType: CardType.sentence,
        rating: Rating.good,
        reviewedAt: now,
        intervalDaysAfter: 1,
      );

      await reviews.deleteCardsForSource('sentence-1');

      expect(await reviews.listAllCards(), isEmpty);
      expect((await reviews.listReviewHistory()).length, 1);
    });

    test('an empty repository reports nothing due', () async {
      expect(await reviews.listDue(now: now), isEmpty);
      expect(await reviews.countDue(now: now), 0);
      expect(await reviews.listAllCards(), isEmpty);
      expect(await reviews.listReviewHistory(), isEmpty);
    });
  });

  group('mining to review round trip', () {
    test('a mined sentence is immediately due for review', () async {
      final sentence = await sentences.save(
        japanese: 'これはテストです。',
        translation: 'This is a test.',
        sourceType: SourceType.manual,
        sourceId: 'manual',
        createdAt: now,
      );

      final card = await reviews.createCard(
        cardType: CardType.sentence,
        sourceItemId: sentence.id,
        promptText: sentence.japanese,
        answerText: sentence.translation,
        createdAt: sentence.createdAt,
      );

      expect(card.promptText, 'これはテストです。');
      expect(card.answerText, 'This is a test.');
      expect(await reviews.countDue(now: now), 1);

      await sentences.delete(sentence.id);
      await reviews.deleteCardsForSource(sentence.id);

      expect(await sentences.count(), 0);
      expect(await reviews.countDue(now: now), 0);
    });
  });
}
