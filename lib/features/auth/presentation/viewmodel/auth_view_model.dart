import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ingrain/core/providers.dart';
import 'package:ingrain/firebase_options.dart';
import 'package:ingrain/features/auth/data/firebase_auth_repository.dart';
import 'package:ingrain/features/auth/data/user_profile_dto.dart';
import 'package:ingrain/features/auth/domain/auth_repository.dart';
import 'package:ingrain/features/auth/domain/auth_state.dart';
import 'package:ingrain/features/auth/domain/user_profile.dart';

final authRepositoryProvider = Provider<AuthSession>((ref) {
  return FirebaseAuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    // `FirebaseOptions` exposes only `androidClientId`/`iosClientId`, never a web
    // client id, and Google Sign-In on Android wants the web one. The generated
    // options are the best available guess; the dart-define overrides it.
    serverClientId: DefaultFirebaseOptions.currentPlatform.androidClientId,
  );
});

final authViewModelProvider = NotifierProvider<AuthViewModel, AuthState>(
  AuthViewModel.new,
);

final isOnboardedProvider = Provider<bool>((ref) {
  return ref.watch(authViewModelProvider).isOnboarded;
});

class AuthViewModel extends Notifier<AuthState> {
  late AuthSession _auth;
  StreamSubscription<String>? _subscription;

  @override
  AuthState build() {
    _auth = ref.watch(authRepositoryProvider);
    ref.onDispose(() => _subscription?.cancel());
    _bootstrap();
    return const AuthState.loading();
  }

  /// Follows the Firebase session rather than probing it once. This is the single
  /// point every repository's `ensureUid()` flows through, so it has to be right
  /// before anything else is touched.
  void _bootstrap() {
    _subscription = _auth.authStateChanges().listen(
      (uid) => _applySession(uid),
      onError: (_, _) {
        if (ref.mounted) state = const AuthState.signedOut();
      },
    );
    // Settle from the restored session instead of waiting for the stream's first
    // event. Firebase always emits one, but until it does the router sees
    // `isLoading` and the whole app sits behind a spinner. Deferred to a microtask
    // because `build()` has not returned its own state yet at this point.
    final current = _auth.currentUid;
    unawaited(Future<void>.microtask(() => _applySession(current ?? '')));
  }

  Future<void> _applySession(String uid) async {
    if (uid.isEmpty) {
      if (ref.mounted) state = const AuthState.signedOut();
      return;
    }
    try {
      await _auth.ensureProfile();
      final name = await _auth.profileDisplayName();
      // The stream outlives any single listener: a sign-out or a provider rebuild
      // can dispose this notifier while the profile read is still in flight.
      if (!ref.mounted) return;
      state = AuthState.ready(uid: uid, displayName: name);
    } catch (error) {
      if (!ref.mounted) return;
      state = AuthState.ready(
        uid: uid,
        error: 'Could not load your profile: $error',
      );
    }
  }

  /// Best-effort name for prefilling the onboarding field. Falls back to the Google
  /// name and then the email local part, so the field is rarely empty.
  Future<String?> suggestedDisplayName() => _auth.displayName;

  Future<bool> signInWithGoogle() => _runSignIn(_auth.signInWithGoogle);

  Future<bool> signInWithEmail(String email, String password) =>
      _runSignIn(() async {
        await _auth.signInWithEmail(email, password);
        return true;
      });

  Future<bool> createAccount(String email, String password) =>
      _runSignIn(() async {
        await _auth.createAccount(email, password);
        return true;
      });

  /// Surfaces failures in [AuthState.error] instead of throwing at the UI layer.
  /// Returns whether a session is now active — a dismissed account chooser reports
  /// false without setting an error.
  Future<bool> _runSignIn(Future<bool> Function() action) async {
    state = AuthState.ready(uid: state.uid, displayName: state.displayName);
    try {
      return await action();
    } on FirebaseAuthException catch (error) {
      state = AuthState.ready(
        uid: '',
        error: error.message ?? 'Sign-in failed (${error.code}).',
      );
      return false;
    } on GoogleSignInException catch (error) {
      state = AuthState.ready(
        uid: '',
        error: error.description ?? 'Sign-in failed.',
      );
      return false;
    } catch (error) {
      state = AuthState.ready(uid: '', error: '$error');
      return false;
    }
  }

  /// Keeps its signature: onboarding calls it once the user has chosen a name.
  ///
  /// Flip the session to onboarded before the name write finishes so the router
  /// can leave the onboarding screen even if Firestore is slow or temporarily
  /// unavailable. The write is still attempted, but the UI must not block on it.
  Future<void> completeOnboarding({required String displayName}) async {
    final safeName = displayName.trim();
    state = AuthState.ready(uid: state.uid, displayName: safeName, error: null);
    try {
      await _auth.setDisplayName(safeName);
    } catch (error) {
      state = AuthState.ready(
        uid: state.uid,
        displayName: safeName,
        error: 'Could not save your name: $error',
      );
      rethrow;
    }
  }

  /// Reads the stored `createdAt` rather than stamping "now" on every read.
  Future<UserProfile?> profile() async {
    if (state.isLoading || !state.isSignedIn) return null;
    return UserProfileDto.fromMapSafe(await _auth.profileDocument());
  }

  Future<void> refresh() async {
    final uid = await _auth.ensureUid();
    state = AuthState.ready(uid: uid, displayName: await _auth.displayName);
  }

  /// A plain sign-out. User data in Firestore is deliberately left intact.
  Future<void> signOut() async {
    await _auth.signOut();
    state = const AuthState.signedOut();
  }
}
