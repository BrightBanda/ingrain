import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/content/presentation/view/add_content_type.dart';
import 'package:ingrain/features/content/presentation/viewmodel/content_view_model.dart';
import 'package:ingrain/features/dialogue/presentation/view/library_content_filter.dart';
import 'package:ingrain/features/dialogue/presentation/view/library_dialogue_list_view.dart';
import 'package:ingrain/shared/widgets/colorful.dart';

class ContentHistoryView extends ConsumerStatefulWidget {
  const ContentHistoryView({super.key});

  @override
  ConsumerState<ContentHistoryView> createState() => _ContentHistoryViewState();
}

class _ContentHistoryViewState extends ConsumerState<ContentHistoryView> {
  LibraryContentFilter _filter = LibraryContentFilter.videos;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final uiState = ref.watch(contentViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Library'),
        actions: [
          if (_filter == LibraryContentFilter.videos) ...[
            IconButton(
              icon: const Icon(Icons.translate),
              tooltip: 'Saved vocabulary',
              onPressed: () => context.push('/vocabulary'),
            ),
            IconButton(
              icon: const Icon(Icons.bookmark_border),
              tooltip: 'Mined sentences',
              onPressed: () => context.push('/sentences'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add content',
            onPressed: () => context.push('/content/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: LibraryContentFilterControl(
              selected: _filter,
              onChanged: (filter) => setState(() => _filter = filter),
            ),
          ),
          Expanded(
            child: switch (_filter) {
              LibraryContentFilter.dialogues => const LibraryDialogueListView(),
              LibraryContentFilter.podcasts => const _PodcastsComingSoon(),
              LibraryContentFilter.videos => uiState.when(
                data: (items) => items.isEmpty
                    ? _buildEmpty(context)
                    : _buildList(context, ref, items),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return EmptyState(
      icon: Icons.smart_display,
      color: AppColors.primaryMain,
      title: 'Your library is empty',
      message:
          'Every video you add keeps its transcript, progress\nand mined '
          'language here.',
      action: FilledButton.icon(
        style: accentButtonStyle(AppColors.primaryMain),
        onPressed: () => context.push(AddContentType.youtube.route),
        icon: const Icon(Icons.add),
        label: const Text('Add content'),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<ContentItem> items,
  ) {
    final theme = Theme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        final minutes = item.totalImmersionSeconds ~/ 60;

        return Card(
          child: InkWell(
            onTap: () => context.push('/content/${item.id}'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryMain.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.play_circle_fill,
                      color: AppColors.primaryMain,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.channelTitle ?? item.sourceType.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: minutes > 0
                          ? AppColors.primaryMain.withValues(alpha: 0.14)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      minutes > 0 ? '${minutes}m immersed' : 'New',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 11,
                        color: minutes > 0
                            ? AppColors.primaryMain
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PodcastsComingSoon extends StatelessWidget {
  const _PodcastsComingSoon();

  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.headphones,
    color: AppColors.primaryMain,
    title: 'Podcasts are coming soon',
    message: 'Until then, try a YouTube video or a dialogue.',
  );
}
