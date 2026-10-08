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
  final store = ref.watch(documentStoreProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return LocalImmersionRepository(store, authRepo);
});

final clockProvider = Provider<Clock>((ref) => _defaultClock);

final tickIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 1),
);

/// Playback position is reported on every player tick (4x/second). Persisting
/// it that often means decoding and rewriting the whole sessions document on
/// the UI isolate, so writes are throttled while in-memory state stays exact.
final positionPersistIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);

class ImmersionSessionViewModel extends Notifier<SessionUiState> {
  final String contentId;
  late ImmersionRepository _repository;
  late Clock _clock;
  late Duration _tickInterval;
  late Duration _positionPersistInterval;
  Timer? _timer;
  DateTime? _lastTickAt;
  DateTime? _lastPositionPersistedAt;

  /// Time banked by earlier running stretches. Kept exact (not in whole
  /// seconds) so frequent pause/resume, as when the player goes fullscreen,
  /// does not drop a fraction of a second each time and drift the clock back.
  Duration _accumulated = Duration.zero;

  Duration get _elapsed =>
      _accumulated +
      (_lastTickAt == null
          ? Duration.zero
          : _clock.now.difference(_lastTickAt!));

  ImmersionSessionViewModel({required this.contentId});

  @override
  SessionUiState build() {
    _repository = ref.watch(immersionRepositoryProvider);
    _clock = ref.watch(clockProvider);
    _tickInterval = ref.watch(tickIntervalProvider);
    _positionPersistInterval = ref.watch(positionPersistIntervalProvider);

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

  /// Set while a start is waiting on storage. The player can report
  /// "playing" more than once in that window (the play button and the iframe
  /// both do, and fullscreen pauses and plays again); without this each one
  /// started a fresh session and reset the clock to zero.
  bool _starting = false;

  Future<void> startSession({
    required String sourceTitle,
    ActivityType activityType = ActivityType.watching,
    int initialPosition = 0,
  }) async {
    if (_starting || state.hasActiveSession) return;
    _starting = true;
    final now = _clock.now;
    final ImmersionSession session;
    try {
      session = await _repository.startSession(
        sourceId: contentId,
        sourceTitle: sourceTitle,
        activityType: activityType,
        startedAt: now,
      );
    } finally {
      _starting = false;
    }
    if (!ref.mounted) return;

    _lastTickAt = now;
    _accumulated = Duration.zero;
    _lastPositionPersistedAt = null;

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

    final elapsed = _elapsed.inSeconds;

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

    _accumulated = _elapsed;
    _lastTickAt = null;

    state = state.copyWith(
      isRunning: false,
      isPaused: true,
      elapsedSeconds: _accumulated.inSeconds,
    );

    if (state.sessionId != null) {
      _repository.updateDuration(state.sessionId!, _accumulated.inSeconds);
    }
  }

  void resumeSession() {
    if (state.isPaused) {
      _resumeSessionInternal();
    }
  }

  void _resumeSessionInternal() {
    _lastTickAt = _clock.now;
    state = state.copyWith(isRunning: true, isPaused: false);
    _startTimer();
  }

  Future<void> stopSession() async {
    _timer?.cancel();
    final stoppedElapsedSeconds = _elapsed.inSeconds;
    final stoppedPositionSeconds = state.lastPositionSeconds;

    if (state.sessionId != null) {
      final now = _clock.now;
      await _repository.updateDuration(state.sessionId!, stoppedElapsedSeconds);
      // Flush the final position so throttling never loses it.
      await _repository.updatePosition(
        state.sessionId!,
        stoppedPositionSeconds,
      );
      await _repository.stopSession(state.sessionId!, now);
    }

    state = SessionUiState(
      elapsedSeconds: stoppedElapsedSeconds,
      lastPositionSeconds: stoppedPositionSeconds,
    );
    _accumulated = Duration.zero;
    _lastTickAt = null;
    _lastPositionPersistedAt = null;
  }

  Future<void> updatePosition(int seconds) async {
    // The player reports several times a second, but the position is kept in
    // whole seconds: only a new second is a new state. Replacing the state on
    // every report rebuilt everything watching the session that often.
    if (seconds == state.lastPositionSeconds) return;
    state = state.copyWith(lastPositionSeconds: seconds);

    final sessionId = state.sessionId;
    if (sessionId == null) return;

    final now = _clock.now;
    final lastPersistedAt = _lastPositionPersistedAt;
    if (lastPersistedAt != null &&
        now.difference(lastPersistedAt) < _positionPersistInterval) {
      return;
    }

    _lastPositionPersistedAt = now;
    await _repository.updatePosition(sessionId, seconds);
  }
}

final immersionSessionViewModelProvider =
    NotifierProvider.family<ImmersionSessionViewModel, SessionUiState, String>(
      (contentId) => ImmersionSessionViewModel(contentId: contentId),
    );
