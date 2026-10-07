import 'package:ingrain/core/network/api_client.dart';
import 'package:ingrain/features/auth/domain/user_profile.dart';
import 'package:ingrain/features/profile/domain/profile_sync_repository.dart';

/// `PUT /me/profile`, `POST /me/activity` and `POST /me/watched`.
class RemoteProfileSyncRepository implements ProfileSyncRepository {
  final ApiClient _api;

  RemoteProfileSyncRepository(this._api);

  @override
  Future<SubscriptionTier> push(UserProfile profile) async {
    final response = await _api.put('/me/profile', body(profile));
    final json = response is Map ? response : const {};
    return SubscriptionTier.fromCode(json['subscriptionTier']);
  }

  /// The request body. Public for tests.
  static Map<String, Object?> body(UserProfile profile) => {
    'displayName': profile.displayName,
    'avatarId': profile.avatarId,
    'level': profile.level?.code,
    'learningReasons': [for (final r in profile.learningReasons) r.code],
    'interests': [for (final i in profile.interests) i.code],
    'preferences': {'onboardingVersion': profile.onboardingVersion},
  };

  @override
  Future<void> recordVisit() => _api.post('/me/activity');

  @override
  Future<void> recordWatched(String contentId) =>
      _api.post('/me/watched', {'contentId': contentId});
}
