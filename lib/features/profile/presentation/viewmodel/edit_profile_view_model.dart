import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/features/auth/domain/user_profile.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/onboarding/presentation/viewmodel/onboarding_view_model.dart';
import 'package:ingrain/features/profile/domain/avatar_character.dart';
import 'package:ingrain/features/profile/domain/learner_preferences.dart';

class EditProfileState {
  final UserProfile draft;
  final bool isSaving;
  final String? error;

  const EditProfileState({
    required this.draft,
    this.isSaving = false,
    this.error,
  });

  String? get nameError {
    final name = draft.displayName?.trim() ?? '';
    if (name.isEmpty) return 'Enter a name';
    if (name.length > OnboardingDraft.maxNameLength) {
      return 'Keep it under ${OnboardingDraft.maxNameLength} characters';
    }
    return null;
  }

  bool get canSave => nameError == null && !isSaving;

  EditProfileState copyWith({
    UserProfile? draft,
    bool? isSaving,
    String? Function()? error,
  }) => EditProfileState(
    draft: draft ?? this.draft,
    isSaving: isSaving ?? this.isSaving,
    error: error != null ? error() : this.error,
  );
}

/// A working copy of the profile; nothing is stored until [save].
class EditProfileViewModel extends Notifier<EditProfileState> {
  @override
  EditProfileState build() {
    final auth = ref.read(authViewModelProvider);
    return EditProfileState(
      draft:
          auth.profile ??
          UserProfile(
            uid: auth.uid,
            displayName: auth.displayName,
            createdAt: DateTime.now().toUtc(),
          ),
    );
  }

  void _edit(UserProfile draft) =>
      state = state.copyWith(draft: draft, error: () => null);

  void setDisplayName(String name) =>
      _edit(state.draft.copyWith(displayName: () => name));

  void chooseAvatar(AvatarCharacter avatar) =>
      _edit(state.draft.copyWith(avatarId: () => avatar.id));

  void selectLevel(JlptLevel level) =>
      _edit(state.draft.copyWith(level: () => level));

  void toggleReason(LearningReason reason) {
    final reasons = [...state.draft.learningReasons];
    if (!reasons.remove(reason)) reasons.add(reason);
    _edit(state.draft.copyWith(learningReasons: reasons));
  }

  void toggleInterest(ContentInterest interest) {
    final interests = [...state.draft.interests];
    if (!interests.remove(interest)) interests.add(interest);
    _edit(state.draft.copyWith(interests: interests));
  }

  /// Returns true once saved.
  Future<bool> save() async {
    if (!state.canSave) return false;
    state = state.copyWith(isSaving: true, error: () => null);
    try {
      await ref.read(authViewModelProvider.notifier).updateProfile(state.draft);
      return true;
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(
          isSaving: false,
          error: () => 'Could not save your profile. Try again.',
        );
      }
      return false;
    }
  }
}

final editProfileViewModelProvider =
    NotifierProvider.autoDispose<EditProfileViewModel, EditProfileState>(
      EditProfileViewModel.new,
    );
