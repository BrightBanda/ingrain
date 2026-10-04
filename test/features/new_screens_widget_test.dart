import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/core/providers.dart';
import 'package:ingrain/core/utils/clock.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/content/domain/transcript_sentence.dart';
import 'package:ingrain/features/content/presentation/view/player/transcript_view.dart';
import 'package:ingrain/features/content/presentation/viewmodel/content_view_model.dart';
import 'package:ingrain/features/immersion/domain/immersion_repository.dart';
import 'package:ingrain/features/immersion/domain/immersion_session.dart';
import 'package:ingrain/features/immersion/presentation/viewmodel/immersion_session_view_model.dart';
import 'package:ingrain/features/progress/presentation/view/progress_tab_view.dart';
import 'package:ingrain/features/sentence_mining/domain/sentence_item.dart';
import 'package:ingrain/features/sentence_mining/domain/sentence_repository.dart';
import 'package:ingrain/features/sentence_mining/presentation/view/sentence_mining_view.dart';
import 'package:ingrain/features/sentence_mining/presentation/viewmodel/sentence_mining_view_model.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/review_event.dart';
import 'package:ingrain/features/srs/domain/review_repository.dart';
import 'package:ingrain/features/srs/presentation/view/review_tab_view.dart';
import 'package:ingrain/features/srs/presentation/viewmodel/review_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FixedTestClock extends Clock {
  @override
  DateTime get now => DateTime(2026, 3, 15, 12);
}

class InMemorySentenceRepository implements SentenceRepository {
  InMemorySentenceRepository([List<SentenceItem>? seed])
    : sentences = [...?seed];

  final List<SentenceItem> sentences;
  int _nextId = 0;

  @override
  Future<SentenceItem> save({
    required String japanese,
    String? translation,
    String? explanation,
    required SourceType sourceType,
    required String sourceId,
    String? sourceTitle,
    int? timestampSeconds,
    String? contextSentence,
    String? sessionId,
    DateTime? createdAt,
  }) async {
    final sentence = SentenceItem(
      id: 'sentence-${_nextId++}',
      uid: 'uid-1',
      japanese: japanese,
      translation: translation,
      explanation: explanation,
      sourceType: sourceType,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      timestampSeconds: timestampSeconds,
      contextSentence: contextSentence,
      sessionId: sessionId,
      createdAt: createdAt ?? DateTime(2026, 3, 15),
    );
    sentences.add(sentence);
    return sentence;
  }

  @override
  Future<SentenceItem?> get(String id) async {
    for (final sentence in sentences) {
      if (sentence.id == id) return sentence;
    }
    return null;
  }

  @override
  Future<void> delete(String id) async {
    sentences.removeWhere((s) => s.id == id);
  }

  @override
  Stream<List<SentenceItem>> watchAll() async* {
    final sorted = [...sentences]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    yield sorted;
  }

  @override
  Future<int> count() async => sentences.length;

  @override
  Future<int> countCreatedOn(DateTime day) async => sentences.length;
}

class InMemoryReviewRepository implements ReviewRepository {
  InMemoryReviewRepository([List<ReviewCard>? seed]) : cards = [...?seed];

  final List<ReviewCard> cards;
  final List<ReviewEvent> history = [];
  int _nextId = 0;

  @override
  Future<ReviewCard> createCard({
    required CardType cardType,
    required String sourceItemId,
    required String promptText,
    String? answerText,
    DateTime? createdAt,
    DateTime? dueAt,
  }) async {
    final created = createdAt ?? DateTime(2026, 3, 15);
    final card = ReviewCard(
      id: 'card-${_nextId++}',
      uid: 'uid-1',
      cardType: cardType,
      sourceItemId: sourceItemId,
      promptText: promptText,
      answerText: answerText,
      createdAt: created,
      dueAt: dueAt ?? created,
    );
    cards.add(card);
    return card;
  }

  @override
  Future<void> saveCard(ReviewCard card) async {
    final index = cards.indexWhere((c) => c.id == card.id);
    if (index == -1) {
      cards.add(card);
    } else {
      cards[index] = card;
    }
  }

  @override
  Future<List<ReviewCard>> listDue({DateTime? now}) async {
    final at = now ?? DateTime(2026, 3, 15, 12);
    final due = cards.where((c) => c.isDueAt(at)).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return due;
  }

  @override
  Future<List<ReviewCard>> listAllCards() async => List.of(cards);

  @override
  Future<ReviewEvent> recordReview({
    required String cardId,
    required CardType cardType,
    required Rating rating,
    required DateTime reviewedAt,
    required int intervalDaysAfter,
  }) async {
    final event = ReviewEvent(
      id: 'review-${history.length}',
      uid: 'uid-1',
      cardId: cardId,
      cardType: cardType,
      rating: rating,
      reviewedAt: reviewedAt,
      intervalDaysAfter: intervalDaysAfter,
    );
    history.add(event);
    return event;
  }

  @override
  Future<List<ReviewEvent>> listReviewHistory({int limit = 200}) async {
    final events = [...history]
      ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));
    return events.length > limit ? events.sublist(0, limit) : events;
  }

  @override
  Future<void> deleteCardsForSource(String sourceItemId) async {
    cards.removeWhere((c) => c.sourceItemId == sourceItemId);
  }

  @override
  Future<int> countDue({DateTime? now}) async {
    final at = now ?? DateTime(2026, 3, 15, 12);
    return cards.where((c) => c.isDueAt(at)).length;
  }
}

class EmptyImmersionRepository implements ImmersionRepository {
  const EmptyImmersionRepository();

  @override
  Future<ImmersionSession> startSession({
    required String sourceId,
    String? sourceTitle,
    required ActivityType activityType,
    required DateTime startedAt,
  }) => throw UnimplementedError();

  @override
  Future<void> updateDuration(String sessionId, int durationSeconds) async {}

  @override
  Future<void> updatePosition(
    String sessionId,
    int lastPositionSeconds,
  ) async {}

  @override
  Future<void> pauseSession(String sessionId, DateTime pausedAt) async {}

  @override
  Future<void> resumeSession(String sessionId, DateTime resumedAt) async {}

  @override
  Future<void> stopSession(String sessionId, DateTime endedAt) async {}

  @override
  Future<ImmersionSession?> getSession(String sessionId) async => null;

  @override
  Stream<List<ImmersionSession>> watchRecentSessions() async* {
    yield const [];
  }

  @override
  Future<void> deleteSession(String sessionId) async {}
}

SentenceItem sampleSentence() => SentenceItem(
  id: 'sentence-1',
  uid: 'uid-1',
  japanese: 'これはテストです。',
  translation: 'This is a test.',
  sourceType: SourceType.youtube,
  sourceId: 'content-1',
  sourceTitle: 'My Video',
  timestampSeconds: 42,
  createdAt: DateTime(2026, 3, 15, 9),
);

ContentItem sampleContent() => ContentItem(
  id: 'content-1',
  sourceType: SourceType.youtube,
  sourceUrl: 'https://youtu.be/abc',
  title: 'My Video',
  lastOpenedAt: DateTime(2026, 3, 15, 9),
);

List<TranscriptSentence> sampleTranscript() => const [
  TranscriptSentence(index: 0, text: '前の行', startSeconds: 0, endSeconds: 5),
  TranscriptSentence(
    index: 1,
    text: 'これはテストです。',
    startSeconds: 5,
    endSeconds: 12,
  ),
  TranscriptSentence(index: 2, text: '次の行', startSeconds: 12, endSeconds: 20),
];

ReviewCard sampleCard() => ReviewCard(
  id: 'card-1',
  uid: 'uid-1',
  cardType: CardType.sentence,
  sourceItemId: 'sentence-1',
  promptText: 'これはテストです。',
  answerText: 'This is a test.',
  createdAt: DateTime(2026, 3, 15, 9),
  dueAt: DateTime(2026, 3, 15, 9),
);

void main() {
  Future<ProviderContainer> pumpScreen(
    WidgetTester tester,
    Widget child, {
    List<SentenceItem> sentences = const [],
    List<ReviewCard> cards = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        // The progress dashboard reads the daily goal through settings.
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(FixedTestClock()),
        sentenceRepositoryProvider.overrideWithValue(
          InMemorySentenceRepository([...sentences]),
        ),
        reviewRepositoryProvider.overrideWithValue(
          InMemoryReviewRepository([...cards]),
        ),
        immersionRepositoryProvider.overrideWithValue(
          const EmptyImmersionRepository(),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: child),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('SentenceMiningView', () {
    testWidgets('shows the empty state with no mined sentences', (
      tester,
    ) async {
      await pumpScreen(tester, const SentenceMiningView());

      expect(find.text('Mined Sentences'), findsOneWidget);
      expect(find.text('No mined sentences yet'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lists a mined sentence with translation and source', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const SentenceMiningView(),
        sentences: [sampleSentence()],
      );

      expect(find.text('これはテストです。'), findsOneWidget);
      expect(find.text('This is a test.'), findsOneWidget);
      expect(find.text('My Video • 0:42'), findsOneWidget);
      expect(find.text('No mined sentences yet'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('ReviewTabView', () {
    testWidgets('shows the all caught up state when nothing is due', (
      tester,
    ) async {
      await pumpScreen(tester, const ReviewTabView());

      expect(find.text('Review'), findsOneWidget);
      expect(find.text('All caught up'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rates a due card through to the completion summary', (
      tester,
    ) async {
      await pumpScreen(tester, const ReviewTabView(), cards: [sampleCard()]);

      expect(find.text('これはテストです。'), findsOneWidget);
      expect(find.text('Show answer'), findsOneWidget);
      expect(find.text('1 due'), findsOneWidget);

      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();

      expect(find.text('This is a test.'), findsOneWidget);
      expect(find.text('Interval 0d • ease 2.50 • seen 0x'), findsOneWidget);
      for (final label in ['Again', 'Hard', 'Good', 'Easy']) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.tap(find.text('Good'));
      await tester.pumpAndSettle();

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('1 reviewed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('TranscriptView mining', () {
    testWidgets('saving a transcript line stores it and queues a review', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final sentenceRepository = InMemorySentenceRepository();
      final reviewRepository = InMemoryReviewRepository();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(FixedTestClock()),
          sentenceRepositoryProvider.overrideWithValue(sentenceRepository),
          reviewRepositoryProvider.overrideWithValue(reviewRepository),
          immersionRepositoryProvider.overrideWithValue(
            const EmptyImmersionRepository(),
          ),
          transcriptProvider('content-1')
              .overrideWith((ref) async => sampleTranscript()),
          contentItemProvider('content-1')
              .overrideWith((ref) async => sampleContent()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TranscriptView(contentId: 'content-1')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The second transcript line, so the saved context spans both neighbours.
      await tester.tap(find.byIcon(Icons.bookmark_add_outlined).at(1));
      await tester.pumpAndSettle();

      expect(find.text('Mine sentence'), findsOneWidget);
      expect(find.text('これはテストです。'), findsWidgets);
      expect(find.text('前の行 これはテストです。 次の行'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Japanese'), '');
      await tester.enterText(
        find.widgetWithText(TextField, 'Translation (optional)'),
        'This is a test.',
      );
      await tester.tap(find.text('Save sentence'));
      await tester.pumpAndSettle();

      expect(sentenceRepository.sentences, hasLength(1));
      final saved = sentenceRepository.sentences.single;
      expect(saved.japanese, 'これはテストです。');
      expect(saved.translation, 'This is a test.');
      expect(saved.sourceTitle, 'My Video');
      expect(saved.timestampSeconds, 5);
      expect(saved.contextSentence, '前の行 これはテストです。 次の行');

      expect(reviewRepository.cards, hasLength(1));
      expect(reviewRepository.cards.single.promptText, 'これはテストです。');
      expect(reviewRepository.cards.single.answerText, 'This is a test.');
      expect(find.text('Sentence saved for review'), findsOneWidget);

      // Let the confirmation snack bar dismiss so no timer outlives the test.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the empty state when there is no transcript', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(FixedTestClock()),
          transcriptProvider('content-1')
              .overrideWith((ref) async => const <TranscriptSentence>[]),
          contentItemProvider('content-1')
              .overrideWith((ref) async => sampleContent()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TranscriptView(contentId: 'content-1')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No transcript available'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_add_outlined), findsNothing);
    });
  });

  group('ProgressTabView', () {
    Future<void> scrollDashboardDown(WidgetTester tester) async {
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
    }

    testWidgets('renders the dashboard with no data', (tester) async {
      await pumpScreen(tester, const ProgressTabView());

      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Last 7 days'), findsOneWidget);
      expect(find.text('Learning'), findsOneWidget);
      expect(find.text('Sentences mined'), findsOneWidget);
      expect(find.text('Due for review'), findsOneWidget);
      expect(find.text('Reviewed today'), findsOneWidget);

      await scrollDashboardDown(tester);
      expect(find.text('Browse mined sentences'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('surfaces mined sentences and due reviews', (tester) async {
      await pumpScreen(
        tester,
        const ProgressTabView(),
        sentences: [sampleSentence()],
        cards: [sampleCard()],
      );

      expect(find.text('Sentences mined'), findsOneWidget);
      expect(find.text('Due for review'), findsOneWidget);

      await scrollDashboardDown(tester);
      expect(find.text('Review 1 due now'), findsOneWidget);
      expect(find.text('Browse mined sentences'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
