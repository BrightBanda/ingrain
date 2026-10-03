abstract interface class AuthRepository {
  Future<String> ensureUid();

  Future<String?> get displayName;

  Future<void> setDisplayName(String name);

  Future<void> clear();
}
