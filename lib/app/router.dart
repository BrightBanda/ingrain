import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ingrain/features/auth/presentation/view/onboarding_view.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/content/presentation/view/add_content_type.dart';
import 'package:ingrain/features/content/presentation/view/content_add_view.dart';
import 'package:ingrain/features/content/presentation/view/content_history_view.dart';
import 'package:ingrain/features/content/presentation/view/transcript_editor_view.dart';
import 'package:ingrain/features/content/presentation/view/player/immersion_player_view.dart';
import 'package:ingrain/features/dialogue/presentation/view/dialogue_reader_view.dart';
import 'package:ingrain/features/immersion/presentation/view/immersion_home_view.dart';
import 'package:ingrain/features/kana/presentation/kana_view.dart';
import 'package:ingrain/features/profile/presentation/profile_view.dart';
import 'package:ingrain/features/search/presentation/view/search_view.dart';
import 'package:ingrain/features/sentence_mining/presentation/view/sentence_mining_view.dart';
import 'package:ingrain/features/srs/presentation/view/deck_detail_view.dart';
import 'package:ingrain/features/srs/presentation/view/flashcard_study_view.dart';
import 'package:ingrain/features/srs/presentation/view/flashcards_view.dart';
import 'package:ingrain/features/vocabulary/presentation/view/vocabulary_view.dart';
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
            path: '/flashcards',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: FlashcardsView()),
          ),
          GoRoute(
            path: LearnDestination.vocab.path,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: VocabularyView()),
          ),
          GoRoute(
            path: LearnDestination.kana.path,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: KanaView()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfileView()),
          ),
        ],
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingView(),
      ),
      GoRoute(
        path: '/flashcards/study',
        builder: (context, state) => FlashcardStudyView(
          deckId: state.uri.queryParameters['deck'],
          title: state.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: '/flashcards/deck/:id',
        builder: (context, state) =>
            DeckDetailView(deckId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/content/add',
        builder: (context, state) => ContentAddView(
          initialType: AddContentType.fromName(
            state.uri.queryParameters['type'],
          ),
        ),
      ),
      GoRoute(path: '/search', builder: (context, state) => const SearchView()),
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

/// The pages behind the Learn tab's drop-up menu.
enum LearnDestination {
  vocab('Vocab', Icons.translate, '/learn/vocab'),
  kana('Kana', Icons.font_download_outlined, '/learn/kana');

  const LearnDestination(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}

class MainShellView extends StatelessWidget {
  final Widget child;

  const MainShellView({super.key, required this.child});

  /// Tabs as (icon, label, location prefix). Learn has no page of its own: it
  /// opens a menu of [LearnDestination]s.
  static const _tabs = [
    (Icons.play_circle_fill, 'Immerse', '/immerse'),
    (Icons.video_library, 'Library', '/library'),
    (Icons.style, 'Flashcards', '/flashcards'),
    (Icons.school, 'Learn', '/learn'),
    (Icons.person, 'Profile', '/profile'),
  ];

  static const _learnIndex = 3;

  @override
  Widget build(BuildContext context) {
    return DoubleBackToExit(
      child: Scaffold(
        body: child,
        bottomNavigationBar: Builder(
          builder: (barContext) => NavigationBar(
            selectedIndex: _currentIndex(context),
            onDestinationSelected: (index) {
              if (index == _learnIndex) {
                _openLearnMenu(barContext);
              } else {
                context.go(_tabs[index].$3);
              }
            },
            destinations: [
              for (final (index, tab) in _tabs.indexed)
                NavigationDestination(
                  icon: Icon(tab.$1),
                  label: tab.$2,
                  tooltip: index == _learnIndex ? 'Learn: vocab or kana' : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _tabs.indexWhere((t) => location.startsWith(t.$3));
    return index < 0 ? 0 : index;
  }

  /// A menu that opens upwards from the Learn tab.
  Future<void> _openLearnMenu(BuildContext barContext) async {
    final bar = barContext.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(barContext).context.findRenderObject()! as RenderBox;
    final barTopLeft = bar.localToGlobal(Offset.zero, ancestor: overlay);
    final tabWidth = bar.size.width / _tabs.length;
    final tabLeft = barTopLeft.dx + tabWidth * _learnIndex;

    // Menus open downwards from `top`; start them one menu-height above the
    // bar so they sit on top of it instead.
    const itemHeight = kMinInteractiveDimension;
    const menuHeight = itemHeight * 2 + 16;
    final top = barTopLeft.dy - menuHeight - 8;

    final destination = await showMenu<LearnDestination>(
      context: barContext,
      position: RelativeRect.fromLTRB(
        tabLeft - 40,
        top,
        overlay.size.width - tabLeft - tabWidth,
        overlay.size.height - barTopLeft.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        for (final destination in LearnDestination.values)
          PopupMenuItem(
            value: destination,
            height: itemHeight,
            child: Row(
              children: [
                Icon(
                  destination.icon,
                  color: Theme.of(barContext).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(destination.label),
              ],
            ),
          ),
      ],
    );
    if (destination != null && barContext.mounted) {
      barContext.go(destination.path);
    }
  }
}
