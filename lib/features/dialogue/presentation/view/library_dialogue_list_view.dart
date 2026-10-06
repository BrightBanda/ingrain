import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/features/content/presentation/view/add_content_type.dart';
import 'package:ingrain/features/dialogue/domain/dialogue.dart';
import 'package:ingrain/features/dialogue/presentation/viewmodel/dialogue_providers.dart';
import 'package:ingrain/shared/widgets/colorful.dart';
import 'package:url_launcher/url_launcher.dart';

const nhkEasyJapaneseUrl =
    'https://www3.nhk.or.jp/nhkworld/en/shows/easyjapanese';

class LibraryDialogueListView extends ConsumerWidget {
  const LibraryDialogueListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dialogues = ref.watch(dialogueListViewModelProvider);
    final isCached = ref.read(dialogueRepositoryProvider).isShowingCachedCopy;

    return dialogues.when(
      data: (items) => Column(
        children: [
          if (isCached) const _CachedCopyBanner(),
          Expanded(
            child: items.isEmpty
                ? _EmptyDialogues(onBrowse: () => _openNhk(context))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          mainAxisExtent: 136,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        DialogueSummaryCard(dialogue: items[index]),
                  ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _DialogueLoadError(
        onRetry: () =>
            ref.read(dialogueListViewModelProvider.notifier).refresh(),
        onBrowse: () => _openNhk(context),
        message: error.toString(),
      ),
    );
  }

  static Future<void> _openNhk(BuildContext context) async {
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(nhkEasyJapaneseUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open NHK Easy Japanese')),
      );
    }
  }
}

/// A dialogue in the catalogue, sized for a two-column grid.
class DialogueSummaryCard extends StatelessWidget {
  final DialogueSummary dialogue;

  const DialogueSummaryCard({super.key, required this.dialogue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStory = dialogue.kind == DialogueKind.story;
    const accent = AppColors.primaryMain;

    return Card(
      margin: EdgeInsets.zero,
      color: accent.withValues(alpha: 0.1),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/dialogues/${dialogue.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isStory ? Icons.menu_book_outlined : Icons.forum_outlined,
                    color: accent,
                    size: 20,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      dialogue.level,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  dialogue.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
              ),
              Text(
                '${isStory ? 'Story' : 'Dialogue'}  ·  '
                '${dialogue.lineCount} lines',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDialogues extends StatelessWidget {
  final VoidCallback onBrowse;

  const _EmptyDialogues({required this.onBrowse});

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.forum,
    color: AppColors.primaryMain,
    title: 'No dialogues available',
    message: 'Write your own, or browse NHK Easy Japanese.',
    action: Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        FilledButton.icon(
          style: accentButtonStyle(AppColors.primaryMain),
          onPressed: () => context.push(AddContentType.dialogue.route),
          icon: const Icon(Icons.edit),
          label: const Text('Write a dialogue'),
        ),
        OutlinedButton.icon(
          onPressed: onBrowse,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Browse NHK dialogues'),
        ),
      ],
    ),
  );
}

class _DialogueLoadError extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onBrowse;
  final String message;

  const _DialogueLoadError({
    required this.onRetry,
    required this.onBrowse,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off,
    color: AppColors.primaryMain,
    title: 'Could not load dialogues',
    message: message,
    action: Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
        OutlinedButton.icon(
          onPressed: onBrowse,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Browse NHK'),
        ),
      ],
    ),
  );
}

class _CachedCopyBanner extends StatelessWidget {
  const _CachedCopyBanner();

  @override
  Widget build(BuildContext context) => MaterialBanner(
    content: const Text('Showing cached copy'),
    leading: const Icon(Icons.cloud_off_outlined),
    actions: const [SizedBox.shrink()],
  );
}
