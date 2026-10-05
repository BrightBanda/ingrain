import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/core/utils/clock.dart';
import 'package:ingrain/features/immersion/domain/immersion_repository.dart';
import 'package:ingrain/features/immersion/domain/immersion_session.dart';
import 'package:ingrain/features/immersion/presentation/viewmodel/immersion_session_view_model.dart';

class ManualClock extends Clock {
  DateTime _time;

  ManualClock(this._time);

  @override
  DateTime get now => _time;

  void advance(Duration delta) {
    _time = _time.add(delta);
  }
}

class FakeImmersionRepository implements ImmersionRepository {
  final List<ImmersionSession> sessions = [];
  final Map<String, int> savedDurations = {};

  @override
  Future<ImmersionSession> startSession({
    required String sourceId,
    String? sourceTitle,
    required ActivityType activityType,
    required DateTime startedAt,
  }) async {
    final session = ImmersionSession(
      id: 'session-${sessions.length}',
      uid: 'test-uid',
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      activityType: activityType,
      startedAt: startedAt,
    );
    sessions.add(session);
    return session;
  }

  @override
  Future<void> updateDuration(String sessionId, int durationSeconds) async {
    savedDurations[sessionId] = durationSeconds;
  }

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
  Future<void> stopSession(String sessionId, DateTime endedAt) async {
    final index = sessions.indexWhere((session) => session.id == sessionId);
    if (index != -1) {
      sessions[index] = sessions[index].copyWith(endedAt: endedAt);
    }
  }

  @override
  Future<ImmersionSession?> getSession(String sessionId) async {
    for (final s in sessions) {
      if (s.id == sessionId) return s;
    }
    return null;
  }

  @override
  Stream<List<ImmersionSession>> watchRecentSessions() async* {
    yield sessions;
  }

  @override
  Future<void> deleteSession(String sessionId) async {}
}

void main() {
  group('ImmersionSessionViewModel', () {
    late FakeImmersionRepository repository;
    late ManualClock clock;
    late ProviderContainer container;
    final startTime = DateTime(2026, 1, 1, 12, 0, 0);

    setUp(() {
      repository = FakeImmersionRepository();
      clock = ManualClock(startTime);

      container = ProviderContainer(
        overrides: [
          immersionRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(clock),
          tickIntervalProvider.overrideWithValue(
            const Duration(milliseconds: 10),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has no active session', () {
      container.read(immersionSessionViewModelProvider('content-1').notifier);
      final state = container.read(
        immersionSessionViewModelProvider('content-1'),
      );

      expect(state.hasActiveSession, isFalse);
      expect(state.isRunning, isFalse);
      expect(state.isPaused, isFalse);
      expect(state.elapsedSeconds, 0);
    });

    test('startSession transitions to running state', () async {
      final vm = container.read(
        immersionSessionViewModelProvider('content-1').notifier,
      );

      await vm.startSession(sourceTitle: 'My Video');

      clock.advance(const Duration(seconds: 5));

      await Future.delayed(const Duration(milliseconds: 50));

      final state = container.read(
        immersionSessionViewModelProvider('content-1'),
      );
      expect(state.hasActiveSession, isTrue);
      expect(state.isRunning, isTrue);
      expect(state.isPaused, isFalse);
      expect(state.sourceTitle, 'My Video');
      expect(state.sourceId, 'content-1');
    });

    test('pauseSession stops the timer', () async {
      final vm = container.read(
        immersionSessionViewModelProvider('content-1').notifier,
      );

      await vm.startSession(sourceTitle: 'Video');
      clock.advance(const Duration(seconds: 3));
      await Future.delayed(const Duration(milliseconds: 50));

      vm.pauseSession();

      clock.advance(const Duration(seconds: 10));
      await Future.delayed(const Duration(milliseconds: 50));

      final state = container.read(
        immersionSessionViewModelProvider('content-1'),
      );
      expect(state.isRunning, isFalse);
      expect(state.isPaused, isTrue);
      expect(state.elapsedSeconds, greaterThanOrEqualTo(3));
    });

    test('resumeSession restarts the timer', () async {
      final vm = container.read(
        immersionSessionViewModelProvider('content-1').notifier,
      );

      await vm.startSession(sourceTitle: 'Video');
      clock.advance(const Duration(seconds: 2));
      await Future.delayed(const Duration(milliseconds: 50));

      vm.pauseSession();
      clock.advance(const Duration(seconds: 5));
      await Future.delayed(const Duration(milliseconds: 50));

      vm.resumeSession();
      clock.advance(const Duration(seconds: 3));
      await Future.delayed(const Duration(milliseconds: 50));

      final state = container.read(
        immersionSessionViewModelProvider('content-1'),
      );
      expect(state.isRunning, isTrue);
      expect(state.isPaused, isFalse);
      expect(state.elapsedSeconds, greaterThanOrEqualTo(5));
    });

    test('stopSession clears the session state', () async {
      final vm = container.read(
        immersionSessionViewModelProvider('content-1').notifier,
      );

      await vm.startSession(sourceTitle: 'Video');
      clock.advance(const Duration(seconds: 3));
      await Future.delayed(const Duration(milliseconds: 50));

      await vm.stopSession();

      final state = container.read(
        immersionSessionViewModelProvider('content-1'),
      );
      expect(state.hasActiveSession, isFalse);
      expect(state.isRunning, isFalse);
      expect(state.sessionId, isNull);
      expect(repository.savedDurations['session-0'], 3);
      expect(repository.sessions.single.isActive, isFalse);
    });

    test('updatePosition saves position to repository', () async {
      final vm = container.read(
        immersionSessionViewModelProvider('content-1').notifier,
      );

      await vm.startSession(sourceTitle: 'Video');
      await vm.updatePosition(120);

      final state = container.read(
        immersionSessionViewModelProvider('content-1'),
      );
      expect(state.lastPositionSeconds, 120);
    });

    test('elapsed time accumulates across pause/resume', () async {
      final vm = container.read(
        immersionSessionViewModelProvider('content-1').notifier,
      );

      await vm.startSession(sourceTitle: 'Video');
      clock.advance(const Duration(seconds: 5));
      await Future.delayed(const Duration(milliseconds: 50));

      vm.pauseSession();
      await Future.delayed(const Duration(milliseconds: 50));

      clock.advance(const Duration(seconds: 3));
      vm.resumeSession();
      clock.advance(const Duration(seconds: 4));
      await Future.delayed(const Duration(milliseconds: 50));

      final state = container.read(
        immersionSessionViewModelProvider('content-1'),
      );
      expect(state.elapsedSeconds, greaterThanOrEqualTo(8));
    });
  });
}
