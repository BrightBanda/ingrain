class UserProfile {
  final String uid;
  final String? displayName;
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    this.displayName,
    required this.createdAt,
  });

  UserProfile copyWith({
    String? uid,
    String? Function()? displayName,
    DateTime? createdAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName != null ? displayName() : this.displayName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
