import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/core/error/app_error.dart';
import 'package:ingrain/core/utils/clock.dart';
import 'package:ingrain/features/immersion/domain/immersion_repository.dart';
import 'package:ingrain/features/immersion/presentation/viewmodel/immersion_session_view_model.dart';
import 'package:ingrain/features/progress/domain/progress_calculator.dart';
import 'package:ingrain/features/progress/domain/progress_summary.dart';
import 'package:ingrain/features/sentence_mining/domain/sentence_repository.dart';
import 'package:ingrain/features/sentence_mining/presentation/viewmodel/sentence_mining_view_model.dart';
import 'package:ingrain/features/settings/presentation/viewmodel/settings_view_model.dart';
import 'package:ingrain/features/srs/domain/review_repository.dart';
import 'package:ingrain/features/srs/presentation/viewmodel/review_view_model.dart';
import 'package:ingrain/features/vocabulary/domain/vocabulary_repository.dart';
import 'package:ingrain/features/vocabulary/presentation/viewmodel/vocabulary_view_model.dart';

class ProgressUiState {
  final bool isLoading;
  final ProgressSummary? summary;
  final AppError? error;

  const ProgressUiState._({required this.isLoading, this.summary, this.error});

  const ProgressUiState.loading() : this._(isLoading: true);

  const ProgressUiState.data(ProgressSummary summary)
    : this._(isLoading: false, summary: summary);

  const ProgressUiState.error(AppError error)
    : this._(isLoading: false, error: error);
}

final progressViewModelProvider =
    NotifierProvider<ProgressViewModel, ProgressUiState>(ProgressViewModel.new);

class ProgressViewModel extends Notifier<ProgressUiState> {
  static const ProgressCalculator _calculator = ProgressCalculator();

  late ImmersionRepository _immersionRepository;
  late SentenceRepository _sentenceRepository;
  late VocabularyRepository _vocabularyRepository;
  late ReviewRepository _reviewRepository;
  late Clock _clock;

  @override
  ProgressUiState build() {
    _immersionRepository = ref.watch(immersionRepositoryProvider);
    _sentenceRepository = ref.watch(sentenceRepositoryProvider);
    _vocabularyRepository = ref.watch(vocabularyRepositoryProvider);
    _reviewRepository = ref.watch(reviewRepositoryProvider);
    _clock = ref.watch(clockProvider);
    _load();
    return const ProgressUiState.loading();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    // Watched rather than read so the goal is correct even when settings are
    // still loading on first build: the dependency re-runs this ViewModel.
    final goalMinutes =
        ref.watch(settingsViewModelProvider).settings?.dailyGoalMinutes ?? 30;

    try {
      final now = _clock.now;
      final sessions = await _immersionRepository.watchRecentSessions().first;
      final sentences = await _sentenceRepository.watchAll().first;
      final vocabulary = await _vocabularyRepository.watchAll().first;
      final dueCards = await _reviewRepository.listDue(now: now);
      final reviewEvents = await _reviewRepository.listReviewHistory();

      final summary = _calculator.summarize(
        sessions: sessions,
        sentences: sentences,
        vocabulary: vocabulary,
        dueCards: dueCards,
        reviewEvents: reviewEvents,
        today: now,
        dailyGoalMinutes: goalMinutes,
      );
      state = ProgressUiState.data(summary);
    } catch (e, st) {
      state = ProgressUiState.error(
        AppError.unknown(e, message: st.toString()),
      );
    }
  }
}
