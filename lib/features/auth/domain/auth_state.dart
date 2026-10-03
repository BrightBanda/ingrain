class AuthState {
  final bool isLoading;
  final String uid;
  final String? displayName;

  const AuthState._({
    required this.isLoading,
    required this.uid,
    this.displayName,
  });

  const AuthState.loading() : this._(isLoading: true, uid: '');

  const AuthState.ready({required String uid, String? displayName})
    : this._(isLoading: false, uid: uid, displayName: displayName);

  bool get isOnboarded => !isLoading && displayName != null;
}
