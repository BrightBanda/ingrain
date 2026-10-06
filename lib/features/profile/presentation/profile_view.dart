import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/core/utils/duration_format.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/progress/presentation/view/progress_dashboard.dart';
import 'package:ingrain/features/progress/presentation/viewmodel/progress_view_model.dart';
import 'package:ingrain/features/settings/presentation/view/settings_panel.dart';
import 'package:ingrain/shared/widgets/colorful.dart';

/// The Profile tab: who you are, your progress and analytics, and settings.
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Profile'),
        ),
        body: const Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _ProfileHeader(),
            ),
            TabBar(
              tabs: [
                Tab(icon: Icon(Icons.insights), text: 'Progress'),
                Tab(icon: Icon(Icons.settings), text: 'Settings'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [ProgressDashboard(), SettingsPanel()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = ref.watch(authViewModelProvider).displayName?.trim();
    final summary = ref.watch(progressViewModelProvider).summary;
    final displayName = name == null || name.isEmpty ? 'Learner' : name;

    final stats = summary == null
        ? 'Loading your stats…'
        : '${summary.currentStreak} day streak  ·  '
              '${formatDurationCompact(Duration(seconds: summary.lifetimeSeconds))} '
              'immersed';

    return GradientPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Text(
              displayName.characters.first.toUpperCase(),
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stats,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            color: Colors.white,
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your vocabulary, decks and progress stay saved to your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authViewModelProvider.notifier).signOut();
    }
  }
}
