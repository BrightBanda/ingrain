import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/core/utils/duration_format.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/sentence_mining/domain/sentence_item.dart';
import 'package:ingrain/features/sentence_mining/presentation/view/sentence_save_sheet.dart';
import 'package:ingrain/features/sentence_mining/presentation/viewmodel/sentence_mining_view_model.dart';
import 'package:ingrain/features/srs/presentation/viewmodel/review_view_model.dart';

class SentenceMiningView extends ConsumerWidget {
  const SentenceMiningView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sentencesAsync = ref.watch(sentenceMiningViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mined Sentences'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: AppColors.textOnPrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openManualAdd(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: sentencesAsync.when(
        data: (sentences) {
          if (sentences.isEmpty) return _buildEmpty(context);
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(sentenceMiningViewModelProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: sentences.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _SentenceTile(sentence: sentences[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bookmark_border,
              size: 64,
              color: AppColors.primaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              'No mined sentences yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Save a line while watching, or add one by hand.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openManualAdd(BuildContext context, WidgetRef ref) async {
    final request = await showModalBottomSheet<SentenceSaveRequest>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SentenceSaveSheet(
        title: 'Add sentence',
        japanese: '',
        japaneseEditable: true,
      ),
    );
    if (request == null || !context.mounted) return;

    await ref
        .read(sentenceMiningViewModelProvider.notifier)
        .saveSentence(
          japanese: request.japanese,
          translation: request.translation,
          explanation: request.explanation,
          sourceType: SourceType.manual,
          sourceId: 'manual',
        );
    ref.invalidate(dueCountProvider);
  }
}

class _SentenceTile extends ConsumerWidget {
  final SentenceItem sentence;

  const _SentenceTile({required this.sentence});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sentence.japanese,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (sentence.hasTranslation) ...[
                    const SizedBox(height: 6),
                    Text(
                      sentence.translation!,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                  if (sentence.explanation != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      sentence.explanation!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _SourceRow(sentence: sentence),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete sentence',
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
        title: const Text('Delete sentence?'),
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

    await ref
        .read(sentenceMiningViewModelProvider.notifier)
        .deleteSentence(sentence.id);
    ref.invalidate(dueCountProvider);
  }
}

class _SourceRow extends StatelessWidget {
  final SentenceItem sentence;

  const _SourceRow({required this.sentence});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    final title = sentence.sourceTitle;
    if (title != null && title.isNotEmpty) {
      parts.add(title);
    } else if (sentence.sourceType != SourceType.manual) {
      parts.add(sentence.sourceType.name);
    }
    final timestamp = sentence.timestampSeconds;
    if (timestamp != null) {
      parts.add(formatDuration(Duration(seconds: timestamp)));
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        const Icon(
          Icons.bookmark_border,
          size: 14,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            parts.join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
