import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ingrain/features/auth/presentation/view/onboarding_view.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/content/presentation/view/content_add_view.dart';
import 'package:ingrain/features/content/presentation/view/content_history_view.dart';
import 'package:ingrain/features/content/presentation/view/transcript_editor_view.dart';
import 'package:ingrain/features/content/presentation/view/player/immersion_player_view.dart';
import 'package:ingrain/features/dialogue/presentation/view/dialogue_reader_view.dart';
import 'package:ingrain/features/immersion/presentation/view/immersion_home_view.dart';
import 'package:ingrain/features/progress/presentation/view/progress_tab_view.dart';
import 'package:ingrain/features/sentence_mining/presentation/view/sentence_mining_view.dart';
import 'package:ingrain/features/settings/presentation/view/settings_view.dart';
import 'package:ingrain/features/vocabulary/presentation/view/vocabulary_view.dart';
import 'package:ingrain/features/srs/presentation/view/review_tab_view.dart';
import 'package:ingrain/shared/widgets/double_back_to_exit.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authViewModelProvider);

  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (context, state) {
      if (authState.isLoading) return null;
      final isOnboarded = authState.isOnboarded;
      final location = state.uri.toString();
      if (!isOnboarded && location != '/onboarding') {
        return '/onboarding';
      }
      if (isOnboarded && location == '/onboarding') {
        return '/immerse';
      }
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShellView(child: child),
        routes: [
          GoRoute(
            path: '/immerse',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ImmersionHomeView()),
          ),
          GoRoute(
            path: '/library',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ContentHistoryView()),
          ),
          GoRoute(
            path: '/review',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReviewTabView()),
          ),
          GoRoute(
            path: '/progress',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProgressTabView()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsView()),
          ),
        ],
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingView(),
      ),
      GoRoute(
        path: '/content/add',
        builder: (context, state) => const ContentAddView(),
      ),
      GoRoute(
        path: '/sentences',
        builder: (context, state) => const SentenceMiningView(),
      ),
      GoRoute(
        path: '/vocabulary',
        builder: (context, state) => const VocabularyView(),
      ),
      GoRoute(
        path: '/dialogues/:id',
        builder: (context, state) =>
            DialogueReaderView(dialogueId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/content/:id/transcript',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return TranscriptEditorView(
            contentId: state.pathParameters['id']!,
            initialTranscript: extra?['transcript'] as String?,
            initialDuration: extra?['duration'] as int?,
          );
        },
      ),
      GoRoute(
        path: '/content/:id',
        builder: (context, state) =>
            ImmersionPlayerView(contentId: state.pathParameters['id']!),
      ),
    ],
  );
});

class MainShellView extends StatelessWidget {
  final Widget child;

  const MainShellView({super.key, required this.child});

  static const _tabs = [
    (Icons.play_circle_fill, 'Immerse', '/immerse'),
    (Icons.book, 'Library', '/library'),
    (Icons.school, 'Review', '/review'),
    (Icons.insights, 'Progress', '/progress'),
    (Icons.settings, 'Settings', '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return DoubleBackToExit(
      child: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex(context),
          onDestinationSelected: (index) {
            context.go(_tabs[index].$3);
          },
          destinations: _tabs
              .map((t) => NavigationDestination(icon: Icon(t.$1), label: t.$2))
              .toList(),
        ),
      ),
    );
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    return _tabs.indexWhere((t) => location == t.$3);
  }
}
