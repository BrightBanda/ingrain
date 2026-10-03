import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/core/lifecycle.dart';
import 'package:ingrain/core/providers.dart';
import 'package:ingrain/core/utils/clock.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/immersion/data/local_immersion_repository.dart';
import 'package:ingrain/features/immersion/domain/immersion_repository.dart';
import 'package:ingrain/features/immersion/domain/immersion_session.dart';
import 'package:ingrain/features/immersion/domain/session_state.dart';

final Clock _defaultClock = SystemClock();

final immersionRepositoryProvider = Provider<ImmersionRepository>((ref) {
  final store = ref.watch(localDocumentStoreProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return LocalImmersionRepository(store, authRepo);
});

final clockProvider = Provider<Clock>((ref) => _defaultClock);

final tickIntervalProvider =
    Provider<Duration>((ref) => const Duration(seconds: 1));

class ImmersionSessionViewModel extends Notifier<SessionUiState> {
  final String contentId;
  late ImmersionRepository _repository;
  late Clock _clock;
  late Duration _tickInterval;
  Timer? _timer;
  DateTime? _lastTickAt;
  int _accumulatedSeconds = 0;

  ImmersionSessionViewModel({required this.contentId});

  @override
  SessionUiState build() {
    _repository = ref.watch(immersionRepositoryProvider);
    _clock = ref.watch(clockProvider);
    _tickInterval = ref.watch(tickIntervalProvider);

    ref.onDispose(() {
      _timer?.cancel();
    });

    ref.listen(appLifecycleProvider, (previous, next) {
      if (!state.isRunning) return;
      if (next == AppLifecycleState.paused) {
        _pauseSessionInternal();
      } else if (next == AppLifecycleState.resumed && state.isPaused) {
        _resumeSessionInternal();
      }
    });

    return const SessionUiState();
  }

  Future<void> startSession({
    required String sourceTitle,
    ActivityType activityType = ActivityType.watching,
    int initialPosition = 0,
  }) async {
    final now = _clock.now;
    final session = await _repository.startSession(
      sourceId: contentId,
      sourceTitle: sourceTitle,
      activityType: activityType,
      startedAt: now,
    );

    _lastTickAt = now;
    _accumulatedSeconds = 0;

    state = SessionUiState(
      hasActiveSession: true,
      isRunning: true,
      sessionId: session.id,
      sourceId: contentId,
      sourceTitle: sourceTitle,
      startedAt: now,
      lastPositionSeconds: initialPosition,
    );

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_tickInterval, (_) => _onTick());
  }

  void _onTick() {
    if (!state.isRunning || _lastTickAt == null || state.sessionId == null) {
      return;
    }

    final now = _clock.now;
    final elapsed =
        _accumulatedSeconds + now.difference(_lastTickAt!).inSeconds;

    state = state.copyWith(elapsedSeconds: elapsed);
    _repository.updateDuration(state.sessionId!, elapsed);
  }

  void pauseSession() {
    if (state.isRunning && !state.isPaused) {
      _pauseSessionInternal();
    }
  }

  void _pauseSessionInternal() {
    if (_lastTickAt == null) return;

    final now = _clock.now;
    _accumulatedSeconds += now.difference(_lastTickAt!).inSeconds;
    _lastTickAt = null;

    state = state.copyWith(
      isRunning: false,
      isPaused: true,
    );

    if (state.sessionId != null) {
      _repository.updateDuration(state.sessionId!, _accumulatedSeconds);
    }
  }

  void resumeSession() {
    if (state.isPaused) {
      _resumeSessionInternal();
    }
  }

  void _resumeSessionInternal() {
    _lastTickAt = _clock.now;
    state = state.copyWith(
      isRunning: true,
      isPaused: false,
    );
    _startTimer();
  }

  Future<void> stopSession() async {
    _timer?.cancel();

    if (state.sessionId != null) {
      final now = _clock.now;
      final totalDuration = _accumulatedSeconds +
          (_lastTickAt != null
              ? now.difference(_lastTickAt!).inSeconds
              : 0);

      await _repository.updateDuration(state.sessionId!, totalDuration);
      await _repository.stopSession(state.sessionId!, now);
    }

    state = const SessionUiState();
    _accumulatedSeconds = 0;
    _lastTickAt = null;
  }

  Future<void> updatePosition(int seconds) async {
    state = state.copyWith(lastPositionSeconds: seconds);
    if (state.sessionId != null) {
      await _repository.updatePosition(state.sessionId!, seconds);
    }
  }
}

final immersionSessionViewModelProvider =
    NotifierProvider.family<ImmersionSessionViewModel, SessionUiState, String>(
  (contentId) => ImmersionSessionViewModel(contentId: contentId),
);
