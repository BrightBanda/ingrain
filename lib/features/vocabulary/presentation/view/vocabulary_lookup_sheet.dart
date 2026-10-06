import 'package:flutter/material.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/shared/widgets/colorful.dart';
import 'package:ingrain/features/vocabulary/domain/dictionary_index.dart';

/// Tap-to-look-up sheet (product spec MVP #4).
///
/// Shows what the bundled dictionary knows about a tapped word together with
/// the sentence it came from, and never dead-ends: a word the dictionary does
/// not have can still be saved with hand-written reading and meaning.
class VocabularyLookupSheet extends StatelessWidget {
  final String word;
  final DictionaryEntry? entry;
  final String? reading;
  final String? contextLabel;
  final bool alreadySaved;
  final VoidCallback? onJumpToTimestamp;
  final VoidCallback onSave;

  const VocabularyLookupSheet({
    super.key,
    required this.word,
    required this.onSave,
    this.entry,
    this.reading,
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
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 30,
                        color: AppColors.primaryMain,
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
                    reading == null
                        ? 'Not in the bundled dictionary. Add the reading and '
                              'meaning yourself to keep it.'
                        : 'Not in the bundled dictionary.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                )
              else ...[
                const SizedBox(height: 4),
              ],
              if (reading != null || entry != null) ...[
                Text(
                  reading ?? entry!.reading,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
              if (entry != null) ...[
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
                    color: AppColors.primaryMain.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    contextLabel!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                style: accentButtonStyle(AppColors.primaryMain),
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
          color: AppColors.primaryMain.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.primaryMain,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
