import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/features/srs/presentation/viewmodel/anki_import_view_model.dart';
import 'package:path_provider/path_provider.dart';

/// Picks an Anki `.apkg` and imports it, showing what will be added first.
Future<void> startAnkiImport(BuildContext context) async {
  final file = await FilePicker.pickFile(type: FileType.any);
  if (file == null || !context.mounted) return;

  final extension = file.extension?.toLowerCase();
  if (extension == 'colpkg') {
    _explain(
      context,
      'That is a whole-collection backup. In Anki, use File › Export and '
      'choose "Anki Deck Package (.apkg)" instead.',
    );
    return;
  }
  if (extension != 'apkg') {
    _explain(context, 'Choose an Anki deck package: a file ending in .apkg.');
    return;
  }

  // Some pickers hand back content rather than a file on disk.
  var path = file.path;
  if (path == null) {
    final copy = File(
      '${(await getTemporaryDirectory()).path}/import-${file.name}',
    );
    await copy.writeAsBytes(await file.readAsBytes(), flush: true);
    path = copy.path;
  }
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AnkiImportDialog(path: path!),
  );
}

void _explain(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class AnkiImportDialog extends ConsumerStatefulWidget {
  final String path;

  const AnkiImportDialog({super.key, required this.path});

  @override
  ConsumerState<AnkiImportDialog> createState() => _AnkiImportDialogState();
}

class _AnkiImportDialogState extends ConsumerState<AnkiImportDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(ankiImportViewModelProvider.notifier).read(widget.path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ankiImportViewModelProvider);
    final theme = Theme.of(context);
    void close() => Navigator.of(context).pop();

    return switch (state) {
      AnkiImportReading() => const AlertDialog(
        title: Text('Reading Anki deck'),
        content: _Busy(label: 'Unpacking cards and their progress…'),
      ),
      AnkiImportReady(:final plan) => AlertDialog(
        title: const Text('Import from Anki'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${plan.cardCount} cards in ${plan.decks.length} '
                '${plan.decks.length == 1 ? 'deck' : 'decks'}, with their '
                'review progress.',
              ),
              const SizedBox(height: 12),
              for (final deck in plan.decks.take(8))
                Text(
                  '•  ${deck.name}  (${deck.cards.length})',
                  style: theme.textTheme.bodySmall,
                ),
              if (plan.decks.length > 8)
                Text(
                  '…and ${plan.decks.length - 8} more',
                  style: theme.textTheme.bodySmall,
                ),
              if (plan.skipped > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '${plan.skipped} cards are skipped: they have no text on '
                  'their front (images or audio only).',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (plan.cardCount > AnkiImportViewModel.largeImport) ...[
                const SizedBox(height: 12),
                Text(
                  'This is a large deck. The free cloud plan allows about '
                  '20,000 saves a day, so very large imports may need to be '
                  'finished tomorrow. Importing again later picks up '
                  'safely.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: close, child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                ref.read(ankiImportViewModelProvider.notifier).confirm(),
            child: const Text('Import'),
          ),
        ],
      ),
      AnkiImportSaving(:final progress) => AlertDialog(
        title: const Text('Importing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            Text('Saved ${progress.saved} of ${progress.total} cards'),
          ],
        ),
      ),
      AnkiImportDone(:final result) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline),
        title: const Text('Import complete'),
        content: Text(
          '${result.cards} cards in ${result.decks} '
          '${result.decks == 1 ? 'deck' : 'decks'} are ready to study.',
        ),
        actions: [FilledButton(onPressed: close, child: const Text('Done'))],
      ),
      AnkiImportFailed(:final message) => AlertDialog(
        icon: const Icon(Icons.error_outline),
        title: const Text('Could not import'),
        content: Text(message),
        actions: [TextButton(onPressed: close, child: const Text('Close'))],
      ),
    };
  }
}

class _Busy extends StatelessWidget {
  final String label;

  const _Busy({required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
      const SizedBox(width: 16),
      Expanded(child: Text(label)),
    ],
  );
}
