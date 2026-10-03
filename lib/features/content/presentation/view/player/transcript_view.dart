import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/core/utils/duration_format.dart';
import 'package:ingrain/features/content/presentation/viewmodel/content_view_model.dart';
import 'package:ingrain/features/content/presentation/view/player/immersion_player_view.dart';

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
            final isCurrent = position.inSeconds >= sentence.startSeconds &&
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
                  color: isCurrent
                      ? AppColors.primaryPale
                      : Colors.transparent,
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
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('Error loading transcript')),
    );
  }
}
