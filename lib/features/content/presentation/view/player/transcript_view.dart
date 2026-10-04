import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/core/utils/duration_format.dart';
import 'package:ingrain/features/content/domain/transcript_sentence.dart';
import 'package:ingrain/features/content/presentation/viewmodel/content_view_model.dart';
import 'package:ingrain/features/content/presentation/view/player/immersion_player_view.dart';
import 'package:ingrain/features/immersion/presentation/viewmodel/immersion_session_view_model.dart';
import 'package:ingrain/features/sentence_mining/presentation/view/sentence_save_sheet.dart';
import 'package:ingrain/features/sentence_mining/presentation/viewmodel/sentence_mining_view_model.dart';
import 'package:ingrain/features/srs/presentation/viewmodel/review_view_model.dart';

class TranscriptView extends ConsumerWidget {
  final String? contentId;

  const TranscriptView({super.key, this.contentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playbackPositionProvider);
    final controller = ref.watch(playerControllerProvider);

    if (contentId == null) {
      return const Center(child: Text('No content selected'));
    }

    final transcriptAsync = ref.watch(transcriptProvider(contentId!));

    return transcriptAsync.when(
      data: (sentences) {
        if (sentences.isEmpty) {
          return const Center(child: Text('No transcript available'));
        }
        return ListView.separated(
          itemCount: sentences.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isCurrent ? AppColors.primaryPale : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        formatDuration(
                          Duration(seconds: sentence.startSeconds),
                        ),
                        style: TextStyle(
                          color: isCurrent
                              ? AppColors.primaryMain
                              : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        sentence.text,
                        style: TextStyle(
                          color: isCurrent
                              ? AppColors.primaryDark
                              : AppColors.textPrimary,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.bookmark_add_outlined),
                      color: AppColors.primaryMain,
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
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

  Future<void> _openSaveSheet(
    BuildContext context,
    WidgetRef ref, {
    required List<TranscriptSentence> sentences,
    required TranscriptSentence sentence,
  }) async {
    final contentId = this.contentId;
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
