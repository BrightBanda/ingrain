import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/core/providers.dart';
import 'package:ingrain/features/auth/data/local_auth_repository.dart';
import 'package:ingrain/features/auth/domain/auth_repository.dart';
import 'package:ingrain/features/auth/domain/auth_state.dart';
import 'package:ingrain/features/auth/domain/user_profile.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final store = ref.watch(localDocumentStoreProvider);
  return LocalAuthRepository(store);
});

final authViewModelProvider = NotifierProvider<AuthViewModel, AuthState>(
  AuthViewModel.new,
);

final isOnboardedProvider = Provider<bool>((ref) {
  return ref.watch(authViewModelProvider).isOnboarded;
});

class AuthViewModel extends Notifier<AuthState> {
  late AuthRepository _authRepository;

  @override
  AuthState build() {
    _authRepository = ref.watch(authRepositoryProvider);
    _bootstrap();
    return const AuthState.loading();
  }

  Future<void> _bootstrap() async {
    try {
      final uid = await _authRepository.ensureUid();
      final name = await _authRepository.displayName;
      state = AuthState.ready(uid: uid, displayName: name);
    } catch (e) {
      state = const AuthState.ready(uid: '');
    }
  }

  Future<void> completeOnboarding({required String displayName}) async {
    await _authRepository.setDisplayName(displayName);
    final uid = await _authRepository.ensureUid();
    state = AuthState.ready(uid: uid, displayName: displayName);
  }

  UserProfile? get profile {
    if (state.isLoading) return null;
    return UserProfile(
      uid: state.uid,
      displayName: state.displayName,
      createdAt: DateTime.now(),
    );
  }

  Future<void> refresh() async {
    final uid = await _authRepository.ensureUid();
    final name = await _authRepository.displayName;
    state = AuthState.ready(uid: uid, displayName: name);
  }

  Future<void> signOut() async {
    await _authRepository.clear();
    state = const AuthState.loading();
    _bootstrap();
  }
}
