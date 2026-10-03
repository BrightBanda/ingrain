import 'package:ingrain/features/immersion/domain/immersion_session.dart';

abstract interface class ImmersionRepository {
  Future<ImmersionSession> startSession({
    required String sourceId,
    String? sourceTitle,
    required ActivityType activityType,
    required DateTime startedAt,
  });

  Future<void> updateDuration(String sessionId, int durationSeconds);

  Future<void> updatePosition(String sessionId, int lastPositionSeconds);

  Future<void> pauseSession(String sessionId, DateTime pausedAt);

  Future<void> resumeSession(String sessionId, DateTime resumedAt);

  Future<void> stopSession(String sessionId, DateTime endedAt);

  Future<ImmersionSession?> getSession(String sessionId);

  Stream<List<ImmersionSession>> watchRecentSessions();

  Future<void> deleteSession(String sessionId);
}
