import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/core/providers.dart';
import 'package:ingrain/core/utils/clock.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/immersion/presentation/viewmodel/immersion_session_view_model.dart';
import 'package:ingrain/features/srs/data/deck_repository.dart';
import 'package:ingrain/features/srs/data/local_review_repository.dart';
import 'package:ingrain/features/srs/domain/deck.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/review_repository.dart';
import 'package:ingrain/features/srs/domain/srs_scheduler.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final store = ref.watch(documentStoreProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return LocalReviewRepository(store, authRepo);
});

final deckRepositoryProvider = Provider<DeckRepository>((ref) {
  return DeckRepository(
    ref.watch(documentStoreProvider),
    ref.watch(authRepositoryProvider),
    ref.watch(reviewRepositoryProvider),
  );
});

/// Every deck with its counts, for the Flashcards tab.
final deckSummariesProvider = FutureProvider<List<DeckSummary>>((ref) async {
  final decks = await ref.watch(deckRepositoryProvider).listDecks();
  final cards = await ref.watch(reviewRepositoryProvider).listAllCards();
  final now = ref.watch(clockProvider).now;
  return [for (final deck in decks) DeckSummary.of(deck, cards, now)];
});

/// One deck and its cards, newest first. Null when the deck is gone.
final deckDetailProvider =
    FutureProvider.family<(DeckSummary, List<ReviewCard>)?, String>((
      ref,
      deckId,
    ) async {
      final repository = ref.watch(deckRepositoryProvider);
      final deck = await repository.getDeck(deckId);
      if (deck == null) return null;
      final cards = await repository.cardsIn(deckId);
      final now = ref.watch(clockProvider).now;
      return (DeckSummary.of(deck, cards, now), cards);
    });

final srsSchedulerProvider = Provider<SrsScheduler>(
  (ref) => const SrsScheduler(),
);

class ReviewSessionState {
  final List<ReviewCard> queue;
  final int currentIndex;
  final bool answerShown;
  final bool isLoading;
  final int reviewedThisSession;

  /// The deck being studied, or null for every deck.
  final String? deckId;

  const ReviewSessionState({
    this.deckId,
    this.queue = const [],
    this.currentIndex = 0,
    this.answerShown = false,
    this.isLoading = false,
    this.reviewedThisSession = 0,
  });

  ReviewCard? get currentCard =>
      currentIndex < queue.length ? queue[currentIndex] : null;

  bool get isEmpty => !isLoading && queue.isEmpty;

  bool get isComplete => queue.isNotEmpty && currentIndex >= queue.length;

  int get total => queue.length;

  double get progress =>
      queue.isEmpty ? 0 : (currentIndex / queue.length).clamp(0.0, 1.0);

  ReviewSessionState copyWith({
    List<ReviewCard>? queue,
    int? currentIndex,
    bool? answerShown,
    bool? isLoading,
    int? reviewedThisSession,
  }) {
    return ReviewSessionState(
      deckId: deckId,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      answerShown: answerShown ?? this.answerShown,
      isLoading: isLoading ?? this.isLoading,
      reviewedThisSession: reviewedThisSession ?? this.reviewedThisSession,
    );
  }
}

final reviewViewModelProvider =
    NotifierProvider<ReviewViewModel, ReviewSessionState>(ReviewViewModel.new);

class ReviewViewModel extends Notifier<ReviewSessionState> {
  late ReviewRepository _repository;
  late SrsScheduler _scheduler;
  late Clock _clock;

  @override
  ReviewSessionState build() {
    _repository = ref.watch(reviewRepositoryProvider);
    _scheduler = ref.watch(srsSchedulerProvider);
    _clock = ref.watch(clockProvider);
    return const ReviewSessionState(isLoading: true);
  }

  /// Loads every card that is due now, in [deckId] when given, and resets
  /// the session.
  Future<void> startSession({String? deckId}) async {
    state = ReviewSessionState(deckId: deckId, isLoading: true);
    final due = await _repository.listDue(now: _clock.now);
    state = ReviewSessionState(
      deckId: deckId,
      queue: deckId == null
          ? due
          : due.where((card) => card.deckId == deckId).toList(),
    );
  }

  /// Reloads the same deck.
  Future<void> refreshDue() => startSession(deckId: state.deckId);

  void showAnswer() {
    if (state.currentCard == null) return;
    state = state.copyWith(answerShown: true);
  }

  Future<void> submitAnswer(Rating rating) async {
    final card = state.currentCard;
    if (card == null) return;

    final now = _clock.now;
    final updated = _scheduler.schedule(card, rating, now);
    await _repository.saveCard(updated);
    await _repository.recordReview(
      cardId: updated.id,
      cardType: updated.cardType,
      rating: rating,
      reviewedAt: now,
      intervalDaysAfter: updated.intervalDays,
    );

    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      answerShown: false,
      reviewedThisSession: state.reviewedThisSession + 1,
    );
  }

  /// Interval each rating would produce for the current card, shown on the
  /// answer buttons so the schedule is never a mystery.
  int previewInterval(Rating rating) {
    final card = state.currentCard;
    if (card == null) return 0;
    return _scheduler.nextIntervalDays(card, rating);
  }

  Future<int> countDue() => _repository.countDue(now: _clock.now);
}

/// Badge count for the navigation destination, refreshable from any screen.
final dueCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(reviewRepositoryProvider);
  final clock = ref.watch(clockProvider);
  return repository.countDue(now: clock.now);
});
