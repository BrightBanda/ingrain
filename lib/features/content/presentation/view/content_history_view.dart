import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/content/presentation/viewmodel/content_view_model.dart';

class ContentHistoryView extends ConsumerWidget {
  const ContentHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(contentViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            tooltip: 'Mined sentences',
            onPressed: () => context.go('/sentences'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/content/add'),
          ),
        ],
      ),
      body: uiState.when(
        data: (items) {
          if (items.isEmpty) {
            return _buildEmpty(context);
          }
          return _buildList(context, ref, items);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.book, size: 64, color: AppColors.primaryLight),
          const SizedBox(height: 16),
          Text(
            'No content yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + to add YouTube content',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<ContentItem> items,
  ) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppColors.primaryPale,
            child: Icon(Icons.play_circle_fill, color: AppColors.primaryMain),
          ),
          title: Text(item.title),
          subtitle: Text(
            item.channelTitle ??
                '${item.sourceType.name} • ${item.lastOpenedAt.toLocal()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            '${item.totalImmersionSeconds}s',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          onTap: () => context.go('/content/${item.id}'),
        );
      },
    );
  }
}
