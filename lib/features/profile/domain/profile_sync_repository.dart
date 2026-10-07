import 'package:ingrain/features/auth/domain/user_profile.dart';

/// Keeps the API's copy of the learner in step with the app.
///
/// The API needs the learner's level and interests to pick their daily videos,
/// and it counts visits for the admin statistics. Firestore remains the app's
/// own source of truth for the profile.
abstract interface class ProfileSyncRepository {
  /// Sends the learner's onboarding answers. Returns the subscription tier the
  /// server holds, which only the server can change.
  Future<SubscriptionTier> push(UserProfile profile);

  /// One app open, for the usage statistics.
  Future<void> recordVisit();

  /// The learner opened catalogue content; recommendations favour the rest.
  Future<void> recordWatched(String contentId);
}
