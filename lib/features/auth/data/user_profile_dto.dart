import 'package:ingrain/features/auth/domain/user_profile.dart';

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
    );
  }

  static UserProfile? fromMapSafe(Map<String, dynamic> data) {
    if (data.isEmpty || data['uid'] == null) return null;
    return UserProfileDto.fromMap(data).toDomain();
  }
}
