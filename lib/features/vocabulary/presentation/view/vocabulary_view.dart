import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/core/utils/duration_format.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/srs/presentation/viewmodel/review_view_model.dart';
import 'package:ingrain/features/vocabulary/domain/vocabulary_item.dart';
import 'package:ingrain/features/vocabulary/presentation/view/vocabulary_save_sheet.dart';
import 'package:ingrain/features/vocabulary/presentation/viewmodel/vocabulary_view_model.dart';
import 'package:ingrain/shared/widgets/colorful.dart';

/// Which vocabulary states the list shows. `null` means every state.
class VocabularyFilterNotifier extends Notifier<VocabState?> {
  @override
  VocabState? build() => null;

  void select(VocabState? next) => state = next;
}

final vocabularyStateFilterProvider =
    NotifierProvider<VocabularyFilterNotifier, VocabState?>(
      VocabularyFilterNotifier.new,
    );

class VocabularyView extends ConsumerWidget {
  const VocabularyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordsAsync = ref.watch(vocabularyViewModelProvider);
    final filter = ref.watch(vocabularyStateFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulary')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryMain,
        foregroundColor: Colors.white,
        onPressed: () => _openManualAdd(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: wordsAsync.when(
        data: (words) {
          final visible = filter == null
              ? words
              : words.where((word) => word.state == filter).toList();
          return Column(
            children: [
              _StateFilterBar(
                counts: _countByState(words),
                selected: filter,
                onSelected: (state) => ref
                    .read(vocabularyStateFilterProvider.notifier)
                    .select(state),
              ),
              Expanded(
                child: visible.isEmpty
                    ? _buildEmpty(context, filtered: filter != null)
                    : RefreshIndicator(
                        onRefresh: () => ref
                            .read(vocabularyViewModelProvider.notifier)
                            .refresh(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _VocabularyTile(word: visible[index]),
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  static Map<VocabState, int> _countByState(List<VocabularyItem> words) {
    final counts = {for (final state in VocabState.values) state: 0};
    for (final word in words) {
      counts[word.state] = counts[word.state]! + 1;
    }
    return counts;
  }

  Widget _buildEmpty(BuildContext context, {required bool filtered}) {
    return EmptyState(
      icon: Icons.translate,
      color: AppColors.primaryMain,
      title: filtered ? 'No words in this state' : 'No saved words yet',
      message: filtered
          ? 'Pick another state to see the rest.'
          : 'Tap a word in a transcript to look it up and save it.',
    );
  }

  Future<void> _openManualAdd(BuildContext context, WidgetRef ref) async {
    final request = await showModalBottomSheet<VocabularySaveRequest>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const VocabularySaveSheet(
        title: 'Add word',
        word: '',
        wordEditable: true,
      ),
    );
    if (request == null || !context.mounted) return;

    await ref
        .read(vocabularyViewModelProvider.notifier)
        .saveWord(
          word: request.word,
          reading: request.reading,
          meaning: request.meaning,
          pos: request.pos,
          sourceType: SourceType.manual,
          sourceId: 'manual',
        );
    ref.invalidate(dueCountProvider);
  }
}

class _StateFilterBar extends StatelessWidget {
  final Map<VocabState, int> counts;
  final VocabState? selected;
  final ValueChanged<VocabState?> onSelected;

  const _StateFilterBar({
    required this.counts,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _FilterChip(
            label: 'All',
            color: AppColors.primaryMain,
            count: total,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final state in VocabState.values)
            _FilterChip(
              label: state.label,
              color: AppColors.primaryMain,
              count: counts[state] ?? 0,
              selected: selected == state,
              onTap: () => onSelected(state),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.color,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: FilterChip(
        label: Text('$label $count'),
        selected: selected,
        side: BorderSide.none,
        backgroundColor: color.withValues(alpha: 0.12),
        selectedColor: color,
        labelStyle: TextStyle(
          color: selected ? onAccent(color) : color,
          fontWeight: FontWeight.w600,
        ),
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _VocabularyTile extends ConsumerWidget {
  final VocabularyItem word;

  const _VocabularyTile({required this.word});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = AppColors.primaryMain;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(
              color: color,
              solid: true,
              child: Text(
                word.word.characters.first.toUpperCase(),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: onAccent(color),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.displayWithReading,
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
                  ),
                  if (word.hasMeaning) ...[
                    const SizedBox(height: 4),
                    Text(
                      word.meaning!,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _StateStepper(word: word),
                  const SizedBox(height: 8),
                  _SourceRow(word: word),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              tooltip: 'Delete word',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete word?'),
        content: const Text(
          'Its review card will be deleted too. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(vocabularyViewModelProvider.notifier).deleteWord(word.id);
    ref.invalidate(dueCountProvider);
  }
}

class _StateStepper extends ConsumerWidget {
  final VocabularyItem word;

  const _StateStepper({required this.word});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final state in VocabState.values)
          ChoiceChip(
            label: Text(state.label),
            selected: word.state == state,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            side: BorderSide.none,
            backgroundColor: AppColors.primaryMain.withValues(alpha: 0.1),
            selectedColor: AppColors.primaryMain,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: word.state == state
                  ? onAccent(AppColors.primaryMain)
                  : AppColors.primaryMain,
            ),
            onSelected: (_) => ref
                .read(vocabularyViewModelProvider.notifier)
                .setState(word.id, state),
          ),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  final VocabularyItem word;

  const _SourceRow({required this.word});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[];
    final title = word.sourceTitle;
    if (title != null && title.isNotEmpty) {
      parts.add(title);
    } else if (word.sourceType != SourceType.manual) {
      parts.add(word.sourceType.name);
    }
    final timestamp = word.timestampSeconds;
    if (timestamp != null) {
      parts.add(formatDuration(Duration(seconds: timestamp)));
    }
    if (word.encounterCount > 1) {
      parts.add('${word.encounterCount} encounters');
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(
          Icons.link,
          size: 14,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            parts.join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
