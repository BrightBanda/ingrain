enum ActivityType { watching, listening, reading, speaking }

class ImmersionSession {
  final String id;
  final String uid;
  final String sourceId;
  final String? sourceTitle;
  final ActivityType activityType;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final int lastPositionSeconds;

  const ImmersionSession({
    required this.id,
    required this.uid,
    required this.sourceId,
    this.sourceTitle,
    this.activityType = ActivityType.watching,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.lastPositionSeconds = 0,
  });

  bool get isActive => endedAt == null;

  ImmersionSession copyWith({
    String? id,
    String? uid,
    String? sourceId,
    String? sourceTitle,
    ActivityType? activityType,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    int? lastPositionSeconds,
  }) {
    return ImmersionSession(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      sourceId: sourceId ?? this.sourceId,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      activityType: activityType ?? this.activityType,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
    );
  }
}
