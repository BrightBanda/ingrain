import 'package:collection/collection.dart';
import 'package:ingrain/features/profile/domain/learner_preferences.dart';

/// Account tiers. Only the server changes a tier; the app shows it.
enum SubscriptionTier {
  free('free'),
  premium('premium');

  const SubscriptionTier(this.code);

  final String code;

  bool get isPaid => this != SubscriptionTier.free;

  /// Unknown tiers (a newer server, an older app) read as free.
  static SubscriptionTier fromCode(Object? code) =>
      values.where((tier) => tier.code == code).firstOrNull ??
      SubscriptionTier.free;
}

/// Who the learner is and what they told us during onboarding.
///
/// Stored at `users/{uid}/profile/self` and mirrored to the API, which uses it
/// for recommendations. New onboarding questions become new optional fields;
/// existing documents simply lack them, and [onboardingVersion] says which
/// version of the flow a learner last completed.
class UserProfile {
  /// Bump when onboarding gains a question existing learners should answer.
  static const currentOnboardingVersion = 1;

  final String uid;
  final String? displayName;
  final DateTime createdAt;
  final String? avatarId;
  final JlptLevel? level;
  final List<LearningReason> learningReasons;
  final List<ContentInterest> interests;
  final DateTime? onboardingCompletedAt;
  final int onboardingVersion;
  final DateTime? lastActiveAt;
  final SubscriptionTier subscriptionTier;

  const UserProfile({
    required this.uid,
    this.displayName,
    required this.createdAt,
    this.avatarId,
    this.level,
    this.learningReasons = const [],
    this.interests = const [],
    this.onboardingCompletedAt,
    this.onboardingVersion = 0,
    this.lastActiveAt,
    this.subscriptionTier = SubscriptionTier.free,
  });

  /// Has a name and has been through the full onboarding flow. A learner who
  /// signed up before the flow existed has a name but no completion date, and is
  /// walked through it once.
  bool get isOnboarded =>
      (displayName?.trim().isNotEmpty ?? false) &&
      onboardingCompletedAt != null;

  /// The level to pick content for: the learner's own, else beginner.
  JlptLevel get effectiveLevel => level ?? JlptLevel.fallback;

  UserProfile copyWith({
    String? uid,
    String? Function()? displayName,
    DateTime? createdAt,
    String? Function()? avatarId,
    JlptLevel? Function()? level,
    List<LearningReason>? learningReasons,
    List<ContentInterest>? interests,
    DateTime? Function()? onboardingCompletedAt,
    int? onboardingVersion,
    DateTime? Function()? lastActiveAt,
    SubscriptionTier? subscriptionTier,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName != null ? displayName() : this.displayName,
      createdAt: createdAt ?? this.createdAt,
      avatarId: avatarId != null ? avatarId() : this.avatarId,
      level: level != null ? level() : this.level,
      learningReasons: learningReasons ?? this.learningReasons,
      interests: interests ?? this.interests,
      onboardingCompletedAt: onboardingCompletedAt != null
          ? onboardingCompletedAt()
          : this.onboardingCompletedAt,
      onboardingVersion: onboardingVersion ?? this.onboardingVersion,
      lastActiveAt: lastActiveAt != null ? lastActiveAt() : this.lastActiveAt,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
    );
  }

  static const _listEquality = ListEquality<Object>();

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.uid == uid &&
      other.displayName == displayName &&
      other.createdAt == createdAt &&
      other.avatarId == avatarId &&
      other.level == level &&
      _listEquality.equals(other.learningReasons, learningReasons) &&
      _listEquality.equals(other.interests, interests) &&
      other.onboardingCompletedAt == onboardingCompletedAt &&
      other.onboardingVersion == onboardingVersion &&
      other.lastActiveAt == lastActiveAt &&
      other.subscriptionTier == subscriptionTier;

  @override
  int get hashCode => Object.hash(
    uid,
    displayName,
    createdAt,
    avatarId,
    level,
    _listEquality.hash(learningReasons),
    _listEquality.hash(interests),
    onboardingCompletedAt,
    onboardingVersion,
    lastActiveAt,
    subscriptionTier,
  );
}
