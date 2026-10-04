import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/features/progress/presentation/viewmodel/progress_view_model.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/presentation/viewmodel/review_view_model.dart';

class ReviewTabView extends ConsumerStatefulWidget {
  const ReviewTabView({super.key});

  @override
  ConsumerState<ReviewTabView> createState() => _ReviewTabViewState();
}

class _ReviewTabViewState extends ConsumerState<ReviewTabView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reviewViewModelProvider.notifier).startSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(reviewViewModelProvider);
    final dueCount = ref.watch(dueCountProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          if (dueCount != null && dueCount > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$dueCount due',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh due cards',
            onPressed: () =>
                ref.read(reviewViewModelProvider.notifier).refreshDue(),
          ),
        ],
      ),
      body: _buildBody(session),
    );
  }

  Widget _buildBody(ReviewSessionState session) {
    if (session.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (session.isEmpty) return _buildEmpty();
    if (session.isComplete) return _buildComplete(session);

    final card = session.currentCard!;
    return Column(
      children: [
        _ProgressHeader(
          index: session.currentIndex + 1,
          total: session.total,
          progress: session.progress,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  card.promptText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                if (session.answerShown)
                  _AnswerPanel(answerText: card.answerText, card: card)
                else
                  FilledButton.icon(
                    onPressed: () =>
                        ref.read(reviewViewModelProvider.notifier).showAnswer(),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Show answer'),
                  ),
              ],
            ),
          ),
        ),
        if (session.answerShown)
          _RatingBar(
            onRate: (rating) => _submit(rating),
            intervalFor: (rating) => ref
                .read(reviewViewModelProvider.notifier)
                .previewInterval(rating),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _submit(Rating rating) async {
    await ref.read(reviewViewModelProvider.notifier).submitAnswer(rating);
    ref.invalidate(dueCountProvider);
    ref.invalidate(progressViewModelProvider);
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: AppColors.primaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              'All caught up',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'No sentences are due right now. Save lines while you immerse '
              'and they will queue up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplete(ReviewSessionState session) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.celebration_outlined,
              size: 64,
              color: AppColors.primaryMain,
            ),
            const SizedBox(height: 16),
            Text(
              'Session complete',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${session.reviewedThisSession} reviewed',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(reviewViewModelProvider.notifier).refreshDue(),
              icon: const Icon(Icons.refresh),
              label: const Text('Check for more'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/sentences'),
              child: const Text('Browse mined sentences'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int index;
  final int total;
  final double progress;

  const _ProgressHeader({
    required this.index,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.primaryPale,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryMain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$index / $total',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerPanel extends StatelessWidget {
  final String? answerText;
  final ReviewCard card;

  const _AnswerPanel({required this.answerText, required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryPale,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (answerText != null)
            Text(
              answerText!,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.primaryDark,
                height: 1.5,
              ),
            )
          else
            const Text(
              'No answer saved for this sentence. Recall the meaning, then '
              'rate yourself.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          const SizedBox(height: 12),
          Text(
            'Interval ${card.intervalDays}d • '
            'ease ${card.easeFactor.toStringAsFixed(2)} • '
            'seen ${card.reviewCount}x',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  final ValueChanged<Rating> onRate;
  final int Function(Rating) intervalFor;

  const _RatingBar({required this.onRate, required this.intervalFor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _RatingButton(
            label: 'Again',
            color: AppColors.error,
            onPressed: () => onRate(Rating.again),
            intervalLabel: _label(Rating.again),
          ),
          _RatingButton(
            label: 'Hard',
            color: Colors.orange.shade700,
            onPressed: () => onRate(Rating.hard),
            intervalLabel: _label(Rating.hard),
          ),
          _RatingButton(
            label: 'Good',
            color: AppColors.primaryMain,
            onPressed: () => onRate(Rating.good),
            intervalLabel: _label(Rating.good),
          ),
          _RatingButton(
            label: 'Easy',
            color: Colors.green.shade700,
            onPressed: () => onRate(Rating.easy),
            intervalLabel: _label(Rating.easy),
          ),
        ],
      ),
    );
  }

  String _label(Rating rating) {
    final days = intervalFor(rating);
    if (days <= 0) return '10m';
    return '${days}d';
  }
}

class _RatingButton extends StatelessWidget {
  final String label;
  final String intervalLabel;
  final Color color;
  final VoidCallback onPressed;

  const _RatingButton({
    required this.label,
    required this.intervalLabel,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                intervalLabel,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
