import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/core/providers.dart';
import 'package:ingrain/core/utils/clock.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/immersion/presentation/viewmodel/immersion_session_view_model.dart';
import 'package:ingrain/features/srs/data/local_review_repository.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/review_repository.dart';
import 'package:ingrain/features/srs/domain/srs_scheduler.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final store = ref.watch(localDocumentStoreProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return LocalReviewRepository(store, authRepo);
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

  const ReviewSessionState({
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

  /// Loads every card that is due now and resets the session.
  Future<void> startSession() async {
    state = state.copyWith(isLoading: true);
    final due = await _repository.listDue(now: _clock.now);
    state = ReviewSessionState(queue: due, isLoading: false);
  }

  Future<void> refreshDue() => startSession();

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
