import 'package:ingrain/features/immersion/domain/immersion_session.dart';

class SessionUiState {
  final bool hasActiveSession;
  final bool isRunning;
  final bool isPaused;
  final String? sessionId;
  final String? sourceId;
  final String? sourceTitle;
  final int elapsedSeconds;
  final DateTime? startedAt;
  final int lastPositionSeconds;

  const SessionUiState({
    this.hasActiveSession = false,
    this.isRunning = false,
    this.isPaused = false,
    this.sessionId,
    this.sourceId,
    this.sourceTitle,
    this.elapsedSeconds = 0,
    this.startedAt,
    this.lastPositionSeconds = 0,
  });

  SessionUiState copyWith({
    bool? hasActiveSession,
    bool? isRunning,
    bool? isPaused,
    String? sessionId,
    String? sourceId,
    String? sourceTitle,
    int? elapsedSeconds,
    DateTime? startedAt,
    int? lastPositionSeconds,
  }) {
    return SessionUiState(
      hasActiveSession: hasActiveSession ?? this.hasActiveSession,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      sessionId: sessionId ?? this.sessionId,
      sourceId: sourceId ?? this.sourceId,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      startedAt: startedAt ?? this.startedAt,
      lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
    );
  }
}

class ImmersionSessionDto {
  final Map<String, dynamic> map;

  ImmersionSessionDto({
    required String id,
    required String uid,
    required String sourceId,
    String? sourceTitle,
    required ActivityType activityType,
    required DateTime startedAt,
    DateTime? endedAt,
    int durationSeconds = 0,
    int lastPositionSeconds = 0,
    DateTime? pausedAt,
    bool isPaused = false,
  }) : map = {
          'id': id,
          'uid': uid,
          'sourceId': sourceId,
          if (sourceTitle != null) 'sourceTitle': sourceTitle,
          'activityType': activityType.name,
          'startedAt': startedAt.toIso8601String(),
          if (endedAt != null) 'endedAt': endedAt.toIso8601String(),
          'durationSeconds': durationSeconds,
          'lastPositionSeconds': lastPositionSeconds,
          if (pausedAt != null) 'pausedAt': pausedAt.toIso8601String(),
          'isPaused': isPaused,
        };

  ImmersionSessionDto.fromMap(Map<String, dynamic> data) : map = Map.from(data);

  ImmersionSession toDomain() {
    final endedAtStr = map['endedAt'] as String?;
    return ImmersionSession(
      id: map['id'] as String,
      uid: map['uid'] as String,
      sourceId: map['sourceId'] as String,
      sourceTitle: map['sourceTitle'] as String?,
      activityType: ActivityType.values.firstWhere(
        (e) => e.name == map['activityType'],
        orElse: () => ActivityType.watching,
      ),
      startedAt: DateTime.parse(map['startedAt'] as String),
      endedAt: endedAtStr != null ? DateTime.parse(endedAtStr) : null,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      lastPositionSeconds:
          (map['lastPositionSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}
