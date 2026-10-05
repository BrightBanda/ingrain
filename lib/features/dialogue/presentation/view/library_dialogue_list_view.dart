import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ingrain/features/dialogue/domain/dialogue.dart';
import 'package:ingrain/features/dialogue/presentation/viewmodel/dialogue_providers.dart';
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
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _DialogueSummaryCard(dialogue: items[index]),
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

class _DialogueSummaryCard extends StatelessWidget {
  final DialogueSummary dialogue;

  const _DialogueSummaryCard({required this.dialogue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: () => context.push('/dialogues/${dialogue.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.forum_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dialogue.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${dialogue.level}  ·  ${dialogue.lineCount} lines'
                      '${dialogue.source.attribution == null ? '' : '  ·  ${dialogue.source.attribution}'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
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
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined, size: 42),
          const SizedBox(height: 14),
          Text(
            'No dialogues available',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onBrowse,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Browse NHK dialogues'),
          ),
        ],
      ),
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
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load dialogues'),
          const SizedBox(height: 4),
          Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
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
        ],
      ),
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
