import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/profile/domain/avatar_character.dart';
import 'package:ingrain/features/profile/domain/learner_preferences.dart';

/// The questions, in the order they are asked.
enum OnboardingStep { reasons, level, interests, name, avatar }

/// The answers so far. Nothing is saved until [OnboardingViewModel.finish].
class OnboardingDraft {
  static const maxNameLength = 40;

  final OnboardingStep step;
  final Set<LearningReason> reasons;
  final JlptLevel? level;

  /// "I'm not sure" was chosen: [level] is then the beginner fallback.
  final bool levelUnsure;
  final Set<ContentInterest> interests;
  final String displayName;
  final AvatarCharacter? avatar;
  final bool isSaving;

  const OnboardingDraft({
    this.step = OnboardingStep.reasons,
    this.reasons = const {},
    this.level,
    this.levelUnsure = false,
    this.interests = const {},
    this.displayName = '',
    this.avatar,
    this.isSaving = false,
  });

  bool get isFirstStep => step.index == 0;
  bool get isLastStep => step == OnboardingStep.values.last;

  /// 0..1 across the whole flow, counting the current step as begun.
  double get progress => (step.index + 1) / OnboardingStep.values.length;

  String? get nameError {
    final name = displayName.trim();
    if (name.isEmpty) return 'Enter a name';
    if (name.length > maxNameLength) {
      return 'Keep it under $maxNameLength characters';
    }
    return null;
  }

  bool get canContinue => switch (step) {
    OnboardingStep.reasons => reasons.isNotEmpty,
    OnboardingStep.level => level != null,
    OnboardingStep.interests => interests.isNotEmpty,
    OnboardingStep.name => nameError == null,
    OnboardingStep.avatar => avatar != null,
  };

  OnboardingDraft copyWith({
    OnboardingStep? step,
    Set<LearningReason>? reasons,
    JlptLevel? level,
    bool? levelUnsure,
    Set<ContentInterest>? interests,
    String? displayName,
    AvatarCharacter? avatar,
    bool? isSaving,
  }) {
    return OnboardingDraft(
      step: step ?? this.step,
      reasons: reasons ?? this.reasons,
      level: level ?? this.level,
      levelUnsure: levelUnsure ?? this.levelUnsure,
      interests: interests ?? this.interests,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class OnboardingViewModel extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() {
    // A learner from before this flow existed already has some answers (at
    // least a name); start from those rather than a blank slate.
    final profile = ref.read(authViewModelProvider).profile;
    final draft = OnboardingDraft(
      reasons: {...?profile?.learningReasons},
      level: profile?.level,
      interests: {...?profile?.interests},
      displayName: profile?.displayName ?? '',
      avatar: profile?.avatarId == null
          ? null
          : AvatarCharacter.fromId(profile!.avatarId),
    );
    if (draft.displayName.isEmpty) unawaited(_suggestName());
    return draft;
  }

  /// Prefills the name with the Google name or email local part, unless the
  /// learner has typed something by then.
  Future<void> _suggestName() async {
    final suggested = await ref
        .read(authViewModelProvider.notifier)
        .suggestedDisplayName();
    if (!ref.mounted || suggested == null || state.displayName.isNotEmpty) {
      return;
    }
    final trimmed = suggested.trim();
    state = state.copyWith(
      displayName: trimmed.length > OnboardingDraft.maxNameLength
          ? trimmed.substring(0, OnboardingDraft.maxNameLength)
          : trimmed,
    );
  }

  void toggleReason(LearningReason reason) {
    final next = {...state.reasons};
    if (!next.remove(reason)) next.add(reason);
    state = state.copyWith(reasons: next);
  }

  void selectLevel(JlptLevel level) =>
      state = state.copyWith(level: level, levelUnsure: false);

  /// "I'm not sure": start at beginner, and say so.
  void selectUnsure() =>
      state = state.copyWith(level: JlptLevel.fallback, levelUnsure: true);

  void toggleInterest(ContentInterest interest) {
    final next = {...state.interests};
    if (!next.remove(interest)) next.add(interest);
    state = state.copyWith(interests: next);
  }

  void setDisplayName(String name) => state = state.copyWith(displayName: name);

  void chooseAvatar(AvatarCharacter avatar) =>
      state = state.copyWith(avatar: avatar);

  /// Moves on when the current step is answered. Returns false otherwise.
  bool next() {
    if (!state.canContinue || state.isLastStep) return false;
    state = state.copyWith(step: OnboardingStep.values[state.step.index + 1]);
    return true;
  }

  /// Steps back. Returns false on the first step.
  bool back() {
    if (state.isFirstStep) return false;
    state = state.copyWith(step: OnboardingStep.values[state.step.index - 1]);
    return true;
  }

  /// Saves every answer to the profile. The router leaves onboarding as soon as
  /// the session flips to onboarded, without waiting for the writes; a failed
  /// write surfaces through the auth state's error.
  Future<void> finish() async {
    if (!state.canContinue || !state.isLastStep || state.isSaving) return;
    state = state.copyWith(isSaving: true);
    final draft = state;
    unawaited(
      ref
          .read(authViewModelProvider.notifier)
          .completeOnboarding(
            displayName: draft.displayName,
            avatarId: draft.avatar!.id,
            level: draft.level,
            learningReasons: draft.reasons.toList(),
            interests: draft.interests.toList(),
          )
          .catchError((Object _) {}),
    );
  }
}

final onboardingViewModelProvider =
    NotifierProvider.autoDispose<OnboardingViewModel, OnboardingDraft>(
      OnboardingViewModel.new,
    );
