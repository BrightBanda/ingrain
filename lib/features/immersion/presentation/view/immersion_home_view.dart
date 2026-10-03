import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/content/presentation/viewmodel/content_view_model.dart';

class ImmersionHomeView extends ConsumerWidget {
  const ImmersionHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentList = ref.watch(contentViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ingrain'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(contentViewModelProvider.future),
        child: contentList.when(
          data: (items) => _buildHome(context, ref, items),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Failed to load content')),
        ),
      ),
    );
  }

  Widget _buildHome(
    BuildContext context,
    WidgetRef ref,
    List<ContentItem> items,
  ) {
    final hasContent = items.isNotEmpty;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Immersion',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${items.length} items in your library',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        if (!hasContent)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.book,
                    size: 64,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(height: 16),
                  const Text('No content in your library yet'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/content/add'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Content'),
                  ),
                ],
              ),
            ),
          ),
        if (hasContent)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: const SliverToBoxAdapter(child: _QuickActions()),
          ),
        if (hasContent)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Content',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ...List.generate(items.length, (index) {
                    final item = items[index];
                    return ListTile(
                      leading: const Icon(Icons.play_circle_fill),
                      title: Text(item.title),
                      subtitle: item.channelTitle != null
                          ? Text(item.channelTitle!)
                          : null,
                      onTap: () => context.go('/content/${item.id}'),
                    );
                  }),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        ElevatedButton.icon(
          onPressed: () => context.go('/content/add'),
          icon: const Icon(Icons.add),
          label: const Text('Add Content'),
        ),
        ElevatedButton.icon(
          onPressed: () => context.go('/library'),
          icon: const Icon(Icons.history),
          label: const Text('View Library'),
        ),
      ],
    );
  }
}
