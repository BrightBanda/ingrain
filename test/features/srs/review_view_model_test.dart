import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/core/utils/clock.dart';
import 'package:ingrain/features/immersion/presentation/viewmodel/immersion_session_view_model.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/review_event.dart';
import 'package:ingrain/features/srs/domain/review_repository.dart';
import 'package:ingrain/features/srs/presentation/viewmodel/review_view_model.dart';

class ManualClock extends Clock {
  DateTime _time;

  ManualClock(this._time);

  @override
  DateTime get now => _time;

  void advance(Duration delta) {
    _time = _time.add(delta);
  }
}

class FakeReviewRepository implements ReviewRepository {
  final List<ReviewCard> cards = [];
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
    final created = createdAt ?? DateTime(2026, 1, 1);
    final card = ReviewCard(
      id: 'card-${_nextId++}',
      uid: 'test-uid',
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
    final at = now ?? DateTime(2026, 1, 1);
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
      uid: 'test-uid',
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
    final events = List.of(history)
      ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));
    return events.length > limit ? events.sublist(0, limit) : events;
  }

  @override
  Future<void> deleteCardsForSource(String sourceItemId) async {
    cards.removeWhere((c) => c.sourceItemId == sourceItemId);
  }

  @override
  Future<int> countDue({DateTime? now}) async {
    final at = now ?? DateTime(2026, 1, 1);
    return cards.where((c) => c.isDueAt(at)).length;
  }
}

void main() {
  group('ReviewViewModel', () {
    late FakeReviewRepository repository;
    late ManualClock clock;
    late ProviderContainer container;
    final startTime = DateTime(2026, 1, 1, 12, 0, 0);

    ReviewViewModel vm() => container.read(reviewViewModelProvider.notifier);
    ReviewSessionState state() => container.read(reviewViewModelProvider);

    Future<void> seedDueCards(int count) async {
      for (var i = 0; i < count; i++) {
        await repository.createCard(
          cardType: CardType.sentence,
          sourceItemId: 'sentence-$i',
          promptText: '文 $i',
          answerText: 'Sentence $i',
          createdAt: startTime,
          dueAt: startTime,
        );
      }
    }

    setUp(() {
      repository = FakeReviewRepository();
      clock = ManualClock(startTime);

      container = ProviderContainer(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(clock),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is loading with no queue', () {
      expect(state().isLoading, isTrue);
      expect(state().queue, isEmpty);
      expect(state().currentCard, isNull);
    });

    test('startSession loads due cards into the queue', () async {
      await seedDueCards(3);

      await vm().startSession();

      final session = state();
      expect(session.isLoading, isFalse);
      expect(session.total, 3);
      expect(session.currentIndex, 0);
      expect(session.answerShown, isFalse);
      expect(session.isEmpty, isFalse);
      expect(session.currentCard!.promptText, '文 0');
    });

    test('startSession excludes cards that are not due yet', () async {
      await repository.createCard(
        cardType: CardType.sentence,
        sourceItemId: 'due',
        promptText: 'due',
        createdAt: startTime,
        dueAt: startTime,
      );
      await repository.createCard(
        cardType: CardType.sentence,
        sourceItemId: 'later',
        promptText: 'later',
        createdAt: startTime,
        dueAt: startTime.add(const Duration(days: 3)),
      );

      await vm().startSession();

      expect(state().total, 1);
      expect(state().currentCard!.promptText, 'due');
    });

    test('startSession with nothing due reports the empty state', () async {
      await vm().startSession();

      expect(state().isEmpty, isTrue);
      expect(state().isComplete, isFalse);
      expect(state().total, 0);
    });

    test('showAnswer reveals the answer', () async {
      await seedDueCards(1);
      await vm().startSession();

      expect(state().answerShown, isFalse);

      vm().showAnswer();

      expect(state().answerShown, isTrue);
    });

    test('showAnswer does nothing without a current card', () {
      vm().showAnswer();

      expect(state().answerShown, isFalse);
    });

    test('submitAnswer with good schedules and records the review', () async {
      await seedDueCards(1);
      await vm().startSession();

      await vm().submitAnswer(Rating.good);

      expect(repository.cards.single.intervalDays, 1);
      expect(repository.cards.single.repetitions, 1);
      expect(
        repository.cards.single.dueAt,
        startTime.add(const Duration(days: 1)),
      );
      expect(repository.history.single.rating, Rating.good);
      expect(repository.history.single.intervalDaysAfter, 1);
      expect(repository.history.single.reviewedAt, startTime);
    });

    test('submitAnswer advances to the next card', () async {
      await seedDueCards(2);
      await vm().startSession();

      await vm().submitAnswer(Rating.hard);

      expect(state().currentIndex, 1);
      expect(state().reviewedThisSession, 1);
      expect(state().answerShown, isFalse);
      expect(state().currentCard!.promptText, '文 1');
      expect(state().isComplete, isFalse);
    });

    test('completing the session reports every card reviewed', () async {
      await seedDueCards(2);
      await vm().startSession();

      await vm().submitAnswer(Rating.good);
      await vm().submitAnswer(Rating.easy);

      expect(state().isComplete, isTrue);
      expect(state().currentCard, isNull);
      expect(state().reviewedThisSession, 2);
      expect(state().progress, 1.0);
      expect(repository.history.length, 2);
    });

    test('rescheduling an again card makes it due again later', () async {
      await seedDueCards(1);
      await vm().startSession();

      await vm().submitAnswer(Rating.again);

      final card = repository.cards.single;
      expect(card.intervalDays, 0);
      expect(card.repetitions, 0);
      expect(card.dueAt, startTime.add(const Duration(minutes: 10)));

      clock.advance(const Duration(minutes: 10));
      await vm().refreshDue();

      expect(state().total, 1);
    });

    test('a reviewed card leaves the due queue until it comes back', () async {
      await seedDueCards(1);
      await vm().startSession();
      await vm().submitAnswer(Rating.good);

      await vm().refreshDue();

      expect(state().isEmpty, isTrue);
    });

    test('previewInterval matches what the scheduler will apply', () async {
      await seedDueCards(1);
      await vm().startSession();

      expect(vm().previewInterval(Rating.again), 0);
      expect(vm().previewInterval(Rating.hard), 1);
      expect(vm().previewInterval(Rating.good), 1);
      expect(vm().previewInterval(Rating.easy), 4);
    });

    test('previewInterval is zero without a current card', () async {
      expect(vm().previewInterval(Rating.good), 0);
    });

    test('submitAnswer does nothing without a current card', () async {
      await vm().startSession();

      await vm().submitAnswer(Rating.good);

      expect(repository.history, isEmpty);
      expect(state().reviewedThisSession, 0);
    });

    test('countDue reflects the repository at the current time', () async {
      await seedDueCards(2);

      expect(await vm().countDue(), 2);

      await vm().startSession();
      await vm().submitAnswer(Rating.good);

      expect(await vm().countDue(), 1);
    });
  });

  group('ReviewSessionState', () {
    test('progress is zero for an empty queue', () {
      expect(const ReviewSessionState().progress, 0);
    });

    test('progress tracks the current index', () {
      final epoch = DateTime(2026);
      final state = ReviewSessionState(
        queue: [
          ReviewCard(
            id: 'a',
            uid: 'u',
            cardType: CardType.sentence,
            sourceItemId: 's',
            promptText: 'a',
            createdAt: epoch,
            dueAt: epoch,
          ),
          ReviewCard(
            id: 'b',
            uid: 'u',
            cardType: CardType.sentence,
            sourceItemId: 's',
            promptText: 'b',
            createdAt: epoch,
            dueAt: epoch,
          ),
        ],
      );

      expect(state.progress, 0);
      expect(state.currentCard!.id, 'a');
      expect(state.copyWith(currentIndex: 1).currentCard!.id, 'b');
    });
  });
}
