import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/content/presentation/viewmodel/content_view_model.dart';

class ImmersionHomeView extends ConsumerWidget {
  const ImmersionHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentList = ref.watch(contentViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('ingrain'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(contentViewModelProvider.future),
        child: contentList.when(
          data: (items) => _buildHome(context, ref, items),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Failed to load content')),
        ),
      ),
    );
  }

  Widget _buildHome(
    BuildContext context,
    WidgetRef ref,
    List<ContentItem> items,
  ) {
    final theme = Theme.of(context);
    final hasContent = items.isNotEmpty;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Immerse', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Choose how you want to study Japanese',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            delegate: SliverChildListDelegate([
              _StudyModeCard(
                icon: Icons.smart_display_outlined,
                title: 'YouTube video',
                description: 'Watch with Japanese subtitles',
                actionLabel: 'Open library',
                onTap: () => context.go('/library'),
              ),
              _StudyModeCard(
                icon: Icons.headphones_outlined,
                title: 'Japanese podcasts',
                description: 'Listen and pick up natural speech',
                actionLabel: 'Open library',
                onTap: () => context.go('/library'),
              ),
              _StudyModeCard(
                icon: Icons.forum_outlined,
                title: 'Japanese dialogue',
                description: 'Read through everyday conversations',
                actionLabel: 'Open library',
                onTap: () => context.go('/library'),
              ),
            ]),
          ),
        ),
        if (!hasContent)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Your library is empty',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        if (hasContent)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(child: _QuickActions()),
          ),
        if (hasContent)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
              child: Text('Recent content', style: theme.textTheme.titleMedium),
            ),
          ),
        if (hasContent)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _ContentCard(item: items[index]),
            ),
          ),
      ],
    );
  }
}

class _StudyModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback? onTap;

  const _StudyModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = onTap == null
        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
        : theme.colorScheme.primary;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 6),
              if (onTap == null)
                Text(
                  actionLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 10,
                  ),
                )
              else
                Icon(Icons.chevron_right, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => context.push('/content/add'),
            icon: const Icon(Icons.add),
            label: const Text('Add content'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.go('/library'),
            icon: const Icon(Icons.video_library_outlined),
            label: const Text('Library'),
          ),
        ),
      ],
    );
  }
}

class _ContentCard extends StatelessWidget {
  final ContentItem item;

  const _ContentCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.play_circle_fill,
                  color: theme.colorScheme.primary,
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
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
