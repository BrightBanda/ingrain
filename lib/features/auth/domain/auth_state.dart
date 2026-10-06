class AuthState {
  final bool isLoading;
  final String uid;
  final String? displayName;

  /// Set when the last sign-in attempt failed; cleared on the next attempt.
  final String? error;

  const AuthState._({
    required this.isLoading,
    required this.uid,
    this.displayName,
    this.error,
  });

  const AuthState.loading() : this._(isLoading: true, uid: '');

  /// The pre-Firebase "no user" state: `uid` empty, no name, nothing to show.
  const AuthState.signedOut() : this._(isLoading: false, uid: '');

  const AuthState.ready({
    required String uid,
    String? displayName,
    String? error,
  }) : this._(
         isLoading: false,
         uid: uid,
         displayName: displayName,
         error: error,
       );

  bool get isSignedIn => !isLoading && uid.isNotEmpty;

  /// Both halves are required: signed in *and* has chosen a name. A Firebase user
  /// who has authenticated but not completed onboarding is neither. The trim guards
  /// against a name that is only whitespace, which would otherwise sail through.
  bool get isOnboarded =>
      isSignedIn && (displayName?.trim().isNotEmpty ?? false);
}
