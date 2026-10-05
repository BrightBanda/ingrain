import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/dialogue/domain/dialogue.dart';
import 'package:ingrain/features/dialogue/presentation/viewmodel/dialogue_providers.dart';
import 'package:ingrain/features/dialogue/presentation/widgets/dialogue_token_row.dart';
import 'package:ingrain/features/dialogue/presentation/widgets/speaker_label.dart';
import 'package:ingrain/features/sentence_mining/presentation/view/sentence_save_sheet.dart';
import 'package:ingrain/features/sentence_mining/presentation/viewmodel/sentence_mining_view_model.dart';
import 'package:ingrain/features/srs/presentation/viewmodel/review_view_model.dart';
import 'package:ingrain/features/vocabulary/presentation/view/vocabulary_lookup_sheet.dart';
import 'package:ingrain/features/vocabulary/presentation/view/vocabulary_save_sheet.dart';
import 'package:ingrain/features/vocabulary/presentation/viewmodel/vocabulary_view_model.dart';
import 'package:ingrain/features/settings/presentation/viewmodel/settings_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

class DialogueReaderView extends ConsumerWidget {
  final String dialogueId;

  const DialogueReaderView({super.key, required this.dialogueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dialogueAsync = ref.watch(
      dialogueReaderViewModelProvider(dialogueId),
    );
    final settings = ref.watch(settingsViewModelProvider).settings;
    final showRomaji = settings?.showRomaji ?? false;
    final isCached = ref.read(dialogueRepositoryProvider).isShowingCachedCopy;

    return Scaffold(
      appBar: AppBar(
        title: dialogueAsync.asData == null
            ? const Text('Dialogue')
            : Text(dialogueAsync.asData!.value.title),
        actions: [
          IconButton(
            tooltip: showRomaji ? 'Hide romaji' : 'Show romaji',
            icon: Icon(showRomaji ? Icons.translate : Icons.translate_outlined),
            onPressed: () => ref
                .read(settingsViewModelProvider.notifier)
                .setShowRomaji(!showRomaji),
          ),
          if (dialogueAsync.asData?.value.source.url != null)
            IconButton(
              tooltip: 'Open source',
              icon: const Icon(Icons.open_in_new),
              onPressed: () =>
                  _openSource(context, dialogueAsync.asData!.value.source.url!),
            ),
        ],
      ),
      body: dialogueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load this dialogue'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref
                    .read(dialogueReaderViewModelProvider(dialogueId).notifier)
                    .refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (dialogue) => Column(
          children: [
            if (isCached) const _CachedDialogueNotice(),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: dialogue.lines.length,
                separatorBuilder: (_, _) => const SizedBox(height: 18),
                itemBuilder: (context, index) {
                  final line = dialogue.lines[index];
                  return _DialogueLineCard(
                    dialogue: dialogue,
                    line: line,
                    showRomaji: showRomaji,
                    onTokenTap: (token) =>
                        _openLookup(context, ref, dialogue, line, token),
                    onMine: () => _mineLine(context, ref, dialogue, line),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLookup(
    BuildContext context,
    WidgetRef ref,
    Dialogue dialogue,
    DialogueLine line,
    DialogueToken token,
  ) async {
    final dictionary = await ref.read(dictionaryProvider.future);
    final entry = dictionary.lookup(token.surface);
    final repository = ref.read(vocabularyRepositoryProvider);
    final alreadySaved = await repository.findByWord(token.surface) != null;
    if (!context.mounted) return;

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => VocabularyLookupSheet(
        word: token.surface,
        entry: entry,
        reading: token.reading,
        contextLabel: SentenceMiningViewModel.contextForDialogue(
          dialogue.lines,
          line.index,
        ),
        alreadySaved: alreadySaved,
        onSave: () => Navigator.of(sheetContext).pop(true),
      ),
    );
    if (shouldSave != true || !context.mounted) return;

    final request = await showModalBottomSheet<VocabularySaveRequest>(
      context: context,
      isScrollControlled: true,
      builder: (_) => VocabularySaveSheet(
        title: 'Save word',
        word: token.surface,
        reading: token.reading ?? entry?.reading,
        meaning: entry?.primaryMeaning,
        pos: entry?.pos,
        contextLabel: SentenceMiningViewModel.contextForDialogue(
          dialogue.lines,
          line.index,
        ),
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
          sourceType: SourceType.dialogue,
          sourceId: dialogue.id,
          sourceTitle: dialogue.title,
          contextSentence: SentenceMiningViewModel.contextForDialogue(
            dialogue.lines,
            line.index,
          ),
        );
    ref.invalidate(dueCountProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Word saved for review')));
    }
  }

  Future<void> _mineLine(
    BuildContext context,
    WidgetRef ref,
    Dialogue dialogue,
    DialogueLine line,
  ) async {
    final contextLabel = SentenceMiningViewModel.contextForDialogue(
      dialogue.lines,
      line.index,
    );
    final request = await showModalBottomSheet<SentenceSaveRequest>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SentenceSaveSheet(
        title: 'Mine sentence',
        japanese: line.text,
        contextLabel: contextLabel,
      ),
    );
    if (request == null || !context.mounted) return;
    final saved = await ref
        .read(sentenceMiningViewModelProvider.notifier)
        .saveFromDialogue(
          dialogueId: dialogue.id,
          dialogueTitle: dialogue.title,
          line: line,
          lines: dialogue.lines,
          translation: request.translation,
          explanation: request.explanation,
        );
    ref.invalidate(dueCountProvider);
    if (saved != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sentence saved for review')),
      );
    }
  }

  static Future<void> _openSource(
    BuildContext context,
    String sourceUrl,
  ) async {
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(sourceUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open source page')),
      );
    }
  }
}

class _DialogueLineCard extends StatelessWidget {
  final Dialogue dialogue;
  final DialogueLine line;
  final bool showRomaji;
  final ValueChanged<DialogueToken> onTokenTap;
  final VoidCallback onMine;

  const _DialogueLineCard({
    required this.dialogue,
    required this.line,
    required this.showRomaji,
    required this.onTokenTap,
    required this.onMine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (line.speaker != null) SpeakerLabel(speaker: line.speaker!),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DialogueTokenRow(
                    line: line,
                    showRomaji: showRomaji,
                    onTokenTap: onTokenTap,
                  ),
                ),
                IconButton(
                  tooltip: 'Mine sentence',
                  icon: const Icon(Icons.bookmark_add_outlined),
                  color: theme.colorScheme.primary,
                  onPressed: onMine,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CachedDialogueNotice extends StatelessWidget {
  const _CachedDialogueNotice();

  @override
  Widget build(BuildContext context) => const MaterialBanner(
    content: Text('Showing cached copy'),
    leading: Icon(Icons.cloud_off_outlined),
    actions: [SizedBox.shrink()],
  );
}
