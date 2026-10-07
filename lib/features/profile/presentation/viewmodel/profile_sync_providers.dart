import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/core/lifecycle.dart';
import 'package:ingrain/core/providers.dart';
import 'package:ingrain/features/auth/domain/user_profile.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/profile/data/remote_profile_sync_repository.dart';
import 'package:ingrain/features/profile/domain/profile_sync_repository.dart';

final profileSyncRepositoryProvider = Provider<ProfileSyncRepository>(
  (ref) => RemoteProfileSyncRepository(ref.watch(apiClientProvider)),
);

/// Pushes the learner's profile to the API whenever it changes.
///
/// Watches the profile *without* its subscription tier, so recording the tier
/// the server sends back does not trigger another push. Never fails: a learner
/// offline still gets the app, and the next change or launch retries.
///
/// Anything that depends on the server knowing the learner — the daily
/// recommendations — awaits this first.
final profileSyncProvider = FutureProvider<void>((ref) async {
  final profile = ref.watch(
    authViewModelProvider.select(
      (state) => state.isOnboarded
          ? state.profile?.copyWith(subscriptionTier: SubscriptionTier.free)
          : null,
    ),
  );
  if (profile == null) return;
  try {
    final tier = await ref.read(profileSyncRepositoryProvider).push(profile);
    if (ref.mounted) {
      ref.read(authViewModelProvider.notifier).applySubscriptionTier(tier);
    }
  } catch (error) {
    debugPrint('Profile sync failed: $error');
  }
});

/// Records a visit when an onboarded learner signs in and each time the app
/// comes back to the foreground, and keeps [profileSyncProvider] running.
///
/// Watched once from the app root.
final activityTrackerProvider = Provider<void>((ref) {
  final repository = ref.watch(profileSyncRepositoryProvider);

  void record() => unawaited(
    repository.recordVisit().catchError(
      (Object error) => debugPrint('Visit not recorded: $error'),
    ),
  );

  String onboardedUid() {
    final state = ref.read(authViewModelProvider);
    return state.isOnboarded ? state.uid : '';
  }

  ref.listen(authViewModelProvider.select((s) => s.isOnboarded ? s.uid : ''), (
    previous,
    uid,
  ) {
    if (uid.isNotEmpty && uid != previous) record();
  }, fireImmediately: true);
  // Coming back runs paused → hidden → inactive → resumed, while a dialog or
  // the notification shade only passes through inactive. Only a real trip to
  // the background counts as a new visit.
  var wasInBackground = false;
  ref.listen(appLifecycleProvider, (_, next) {
    if (next == AppLifecycleState.paused || next == AppLifecycleState.hidden) {
      wasInBackground = true;
    } else if (next == AppLifecycleState.resumed && wasInBackground) {
      wasInBackground = false;
      if (onboardedUid().isNotEmpty) record();
    }
  });
  ref.listen(profileSyncProvider, (_, _) {});
});
