import 'package:flutter/material.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/features/vocabulary/domain/dictionary_index.dart';

/// Tap-to-look-up sheet (product spec MVP #4).
///
/// Shows what the bundled dictionary knows about a tapped word together with
/// the sentence it came from, and never dead-ends: a word the dictionary does
/// not have can still be saved with hand-written reading and meaning.
class VocabularyLookupSheet extends StatelessWidget {
  final String word;
  final DictionaryEntry? entry;
  final String? contextLabel;
  final bool alreadySaved;
  final VoidCallback? onJumpToTimestamp;
  final VoidCallback onSave;

  const VocabularyLookupSheet({
    super.key,
    required this.word,
    required this.onSave,
    this.entry,
    this.contextLabel,
    this.alreadySaved = false,
    this.onJumpToTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = this.entry;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      word,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              if (entry == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Not in the bundled dictionary. Add the reading and '
                    'meaning yourself to keep it.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else ...[
                const SizedBox(height: 4),
                Text(
                  entry.reading,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (entry.pos != null) ...[
                  const SizedBox(height: 8),
                  _PosChip(label: entry.pos!),
                ],
                const SizedBox(height: 12),
                for (final meaning in entry.meanings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(meaning, style: theme.textTheme.bodyLarge),
                  ),
              ],
              if (contextLabel != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPale,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    contextLabel!,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: alreadySaved ? null : onSave,
                icon: Icon(alreadySaved ? Icons.check : Icons.bookmark_add),
                label: Text(alreadySaved ? 'Already saved' : 'Save word'),
              ),
              if (onJumpToTimestamp != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onJumpToTimestamp!();
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play from here'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PosChip extends StatelessWidget {
  final String label;

  const _PosChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryPale,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
