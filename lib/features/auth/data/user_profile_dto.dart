import 'package:ingrain/features/auth/domain/user_profile.dart';
import 'package:ingrain/features/profile/domain/learner_preferences.dart';

/// Maps [UserProfile] to and from the `users/{uid}/profile/self` document.
///
/// Reading is lenient: a missing field takes its default and an unknown level,
/// reason or interest code (say, from a newer app version) is skipped rather
/// than failing the whole profile.
class UserProfileDto {
  final Map<String, dynamic> map;

  UserProfileDto._(this.map);

  factory UserProfileDto({
    required String uid,
    String? displayName,
    DateTime? createdAt,
  }) {
    final result = <String, dynamic>{'uid': uid};
    if (displayName != null) result['displayName'] = displayName;
    if (createdAt != null) result['createdAt'] = createdAt.toIso8601String();
    return UserProfileDto._(result);
  }

  UserProfileDto.fromMap(Map<String, dynamic> data) : map = Map.from(data);

  UserProfile toDomain() {
    final createdAtStr = map['createdAt'] as String?;
    return UserProfile(
      uid: map['uid'] as String,
      displayName: map['displayName'] as String?,
      createdAt: createdAtStr != null
          ? DateTime.parse(createdAtStr)
          : DateTime.now(),
      avatarId: map['avatarId'] as String?,
      level: JlptLevel.fromCode(map['level']),
      learningReasons: _codes(map['learningReasons'], LearningReason.fromCode),
      interests: _codes(map['interests'], ContentInterest.fromCode),
      onboardingCompletedAt: _date(map['onboardingCompletedAt']),
      onboardingVersion: (map['onboardingVersion'] as num?)?.toInt() ?? 0,
      lastActiveAt: _date(map['lastActiveAt']),
    );
  }

  static UserProfile? fromMapSafe(Map<String, dynamic> data) {
    if (data.isEmpty || data['uid'] == null) return null;
    return UserProfileDto.fromMap(data).toDomain();
  }

  /// The fields onboarding and profile editing write, merged into the stored
  /// document so `uid`, `createdAt` and any future fields are left alone.
  ///
  /// The subscription tier is deliberately absent: the app never writes it.
  static Map<String, dynamic> learnerFields(UserProfile profile) => {
    if (profile.displayName != null) 'displayName': profile.displayName,
    'avatarId': profile.avatarId,
    'level': profile.level?.code,
    'learningReasons': [for (final r in profile.learningReasons) r.code],
    'interests': [for (final i in profile.interests) i.code],
    if (profile.onboardingCompletedAt != null)
      'onboardingCompletedAt': profile.onboardingCompletedAt!
          .toUtc()
          .toIso8601String(),
    'onboardingVersion': profile.onboardingVersion,
  };

  static List<T> _codes<T>(Object? raw, T? Function(Object?) parse) => [
    for (final code in raw is List ? raw : const []) ?parse(code),
  ];

  static DateTime? _date(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;
}
