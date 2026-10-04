import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Review'),
        actions: [
          if (dueCount != null && dueCount > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$dueCount due',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 26,
                    height: 1.5,
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 44,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text('All caught up', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'No sentences are due right now. Save lines while you immerse '
              'and they will queue up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplete(ReviewSessionState session) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.celebration_outlined,
                size: 44,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text('Session complete', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '${session.reviewedThisSession} reviewed',
              style: theme.textTheme.bodyMedium,
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
              onPressed: () => context.push('/sentences'),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$index / $total',
            style: theme.textTheme.bodySmall,
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (answerText != null)
            Text(
              answerText!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 18,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Text(
              'No answer saved for this sentence. Recall the meaning, then '
              'rate yourself.',
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: 12),
          Text(
            'Interval ${card.intervalDays}d • '
            'ease ${card.easeFactor.toStringAsFixed(2)} • '
            'seen ${card.reviewCount}x',
            style: theme.textTheme.bodySmall,
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
            color: Theme.of(context).colorScheme.error,
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
            color: Theme.of(context).colorScheme.primary,
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
            side: BorderSide(color: color.withValues(alpha: 0.6)),
            backgroundColor: color.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                intervalLabel,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
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
