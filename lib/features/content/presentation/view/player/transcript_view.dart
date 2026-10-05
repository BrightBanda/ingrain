import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/core/utils/duration_format.dart';
import 'package:ingrain/features/content/domain/transcript_sentence.dart';
import 'package:ingrain/features/content/presentation/viewmodel/content_view_model.dart';
import 'package:ingrain/features/content/presentation/view/player/immersion_player_view.dart';
import 'package:ingrain/features/immersion/presentation/viewmodel/immersion_session_view_model.dart';
import 'package:ingrain/features/sentence_mining/presentation/view/sentence_save_sheet.dart';
import 'package:ingrain/features/sentence_mining/presentation/viewmodel/sentence_mining_view_model.dart';
import 'package:ingrain/features/srs/presentation/viewmodel/review_view_model.dart';
import 'package:ingrain/features/vocabulary/domain/dictionary_index.dart';
import 'package:ingrain/features/vocabulary/presentation/view/vocabulary_lookup_sheet.dart';
import 'package:ingrain/features/vocabulary/presentation/view/vocabulary_save_sheet.dart';
import 'package:ingrain/features/vocabulary/presentation/viewmodel/vocabulary_view_model.dart';
import 'package:ingrain/features/vocabulary/presentation/widgets/tappable_transcript_text.dart';

class TranscriptView extends ConsumerStatefulWidget {
  final String? contentId;

  const TranscriptView({super.key, this.contentId});

  @override
  ConsumerState<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends ConsumerState<TranscriptView> {
  final ScrollController _scrollController = ScrollController();
  int? _lastScrolledIndex;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeScrollToCurrent(
    List<TranscriptSentence> sentences,
    Duration position,
  ) {
    if (!mounted || !_scrollController.hasClients) return;

    final currentIndex = sentences.indexWhere(
      (sentence) =>
          position.inSeconds >= sentence.startSeconds &&
          position.inSeconds < sentence.endSeconds,
    );
    if (currentIndex < 0 || currentIndex == _lastScrolledIndex) return;

    _lastScrolledIndex = currentIndex;
    final targetOffset = currentIndex * 68.0;
    final maxOffset = _scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset).toDouble();

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(playbackPositionProvider);
    final controller = ref.watch(playerControllerProvider);
    final tokenizer = ref.watch(transcriptTokenizerProvider);
    final theme = Theme.of(context);

    if (widget.contentId == null) {
      return const Center(child: Text('No content selected'));
    }

    final transcriptAsync = ref.watch(transcriptProvider(widget.contentId!));

    return transcriptAsync.when(
      data: (sentences) {
        if (sentences.isEmpty) {
          return const Center(child: Text('No transcript available'));
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _maybeScrollToCurrent(sentences, position);
          }
        });

        return ListView.separated(
          controller: _scrollController,
          itemCount: sentences.length,
          separatorBuilder: (_, _) => const SizedBox(height: 2),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          itemBuilder: (context, index) {
            final sentence = sentences[index];
            final isCurrent =
                position.inSeconds >= sentence.startSeconds &&
                position.inSeconds < sentence.endSeconds;

            return GestureDetector(
              onTap: controller != null
                  ? () => controller.seekTo(
                      seconds: sentence.startSeconds.toDouble(),
                    )
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? theme.colorScheme.primary.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isCurrent
                      ? Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.25,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 42,
                      child: Text(
                        formatDuration(
                          Duration(seconds: sentence.startSeconds),
                        ),
                        style: TextStyle(
                          color: isCurrent
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                          fontSize: 11,
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TappableTranscriptText(
                        tokens: tokenizer.tokenize(sentence.text),
                        highlightColor: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        style: TextStyle(
                          color: isCurrent
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.w400,
                          fontSize: 14,
                        ),
                        onTokenTap: (token) => _openLookupSheet(
                          context,
                          ref,
                          sentences: sentences,
                          sentence: sentence,
                          word: token,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.bookmark_add_outlined),
                      color: theme.colorScheme.primary,
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      tooltip: 'Mine this sentence',
                      onPressed: () => _openSaveSheet(
                        context,
                        ref,
                        sentences: sentences,
                        sentence: sentence,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('Error loading transcript')),
    );
  }

  /// Tap-to-look-up (product spec MVP #4): show the dictionary entry for the
  /// tapped token and let the learner save it with its immersion memory.
  Future<void> _openLookupSheet(
    BuildContext context,
    WidgetRef ref, {
    required List<TranscriptSentence> sentences,
    required TranscriptSentence sentence,
    required String word,
  }) async {
    final contentId = widget.contentId;
    if (contentId == null) return;

    final controller = ref.watch(playerControllerProvider);
    // Awaited rather than read: the dictionary may still be loading, and a
    // lookup must never answer "not in the dictionary" just because of that.
    DictionaryIndex? dictionary;
    try {
      dictionary = await ref.read(dictionaryProvider.future);
    } catch (_) {
      dictionary = null;
    }
    final entry = dictionary?.lookup(word);
    final contextLabel = SentenceMiningViewModel.contextForTranscript(
      sentences,
      sentence.index,
    );
    final saved = await ref.read(vocabularyRepositoryProvider).findByWord(word);
    final alreadySaved = saved != null;
    if (!context.mounted) return;

    if (!context.mounted) return;

    final wantsSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => VocabularyLookupSheet(
        word: entry?.surface ?? word,
        entry: entry,
        contextLabel: contextLabel,
        alreadySaved: alreadySaved,
        onJumpToTimestamp: controller == null
            ? null
            : () =>
                  controller.seekTo(seconds: sentence.startSeconds.toDouble()),
        onSave: () => Navigator.of(sheetContext).pop(true),
      ),
    );
    if (wantsSave != true || !context.mounted) return;

    final request = await showModalBottomSheet<VocabularySaveRequest>(
      context: context,
      isScrollControlled: true,
      builder: (_) => VocabularySaveSheet(
        title: 'Save word',
        word: entry?.surface ?? word,
        reading: entry?.reading,
        meaning: entry?.primaryMeaning,
        pos: entry?.pos,
        contextLabel: contextLabel,
      ),
    );
    if (request == null || !context.mounted) return;

    String? contentTitle;
    try {
      contentTitle = (await ref.read(contentItemProvider(contentId).future))
          .title;
    } catch (_) {
      contentTitle = null;
    }
    final sessionId = ref
        .read(immersionSessionViewModelProvider(contentId))
        .sessionId;

    await ref
        .read(vocabularyViewModelProvider.notifier)
        .saveFromTranscript(
          contentId: contentId,
          word: request.word,
          sentence: sentence,
          transcript: sentences,
          contentTitle: contentTitle,
          sessionId: sessionId,
          reading: request.reading,
          meaning: request.meaning,
          pos: request.pos,
        );
    ref.invalidate(dueCountProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Word saved for review')));
  }

  Future<void> _openSaveSheet(
    BuildContext context,
    WidgetRef ref, {
    required List<TranscriptSentence> sentences,
    required TranscriptSentence sentence,
  }) async {
    final contentId = widget.contentId;
    if (contentId == null) return;

    // Read lazily rather than watching: the player already keeps this provider
    // alive, so watching here would only add a rebuild dependency to the list.
    String? contentTitle;
    try {
      contentTitle = (await ref.read(contentItemProvider(contentId).future))
          .title;
    } catch (_) {
      contentTitle = null;
    }
    final sessionId = ref
        .read(immersionSessionViewModelProvider(contentId))
        .sessionId;
    if (!context.mounted) return;

    final request = await showModalBottomSheet<SentenceSaveRequest>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SentenceSaveSheet(
        title: 'Mine sentence',
        japanese: sentence.text,
        contextLabel: SentenceMiningViewModel.contextForTranscript(
          sentences,
          sentence.index,
        ),
      ),
    );
    if (request == null || !context.mounted) return;

    await ref
        .read(sentenceMiningViewModelProvider.notifier)
        .saveFromTranscript(
          contentId: contentId,
          sentence: sentence,
          transcript: sentences,
          contentTitle: contentTitle,
          sessionId: sessionId,
          translation: request.translation,
          explanation: request.explanation,
        );
    ref.invalidate(dueCountProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sentence saved for review')));
  }
}
