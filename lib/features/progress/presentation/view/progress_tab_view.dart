import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/core/utils/duration_format.dart';
import 'package:ingrain/features/progress/domain/progress_summary.dart';
import 'package:ingrain/features/progress/presentation/viewmodel/progress_view_model.dart';

class ProgressTabView extends ConsumerWidget {
  const ProgressTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(progressViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(progressViewModelProvider.notifier).refresh(),
          ),
        ],
      ),
      body: uiState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : uiState.error != null
          ? Center(child: Text('Error: ${uiState.error!.message ?? 'unknown'}'))
          : _buildDashboard(context, ref, uiState.summary!),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    ProgressSummary summary,
  ) {
    return RefreshIndicator(
      onRefresh: () => ref.read(progressViewModelProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _TodayCard(summary: summary),
          const SizedBox(height: 16),
          _StatGrid(summary: summary),
          const SizedBox(height: 16),
          _WeeklyChart(activities: summary.last7Days),
          const SizedBox(height: 16),
          _LearningCard(summary: summary),
          if (summary.dueCount > 0) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('/review'),
              icon: const Icon(Icons.school),
              label: Text('Review ${summary.dueCount} due now'),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.go('/vocabulary'),
            icon: const Icon(Icons.translate),
            label: const Text('Browse saved vocabulary'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.go('/sentences'),
            icon: const Icon(Icons.bookmark_border),
            label: const Text('Browse mined sentences'),
          ),
          if (summary.isEmpty) ...[
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Start an immersion session and mine a sentence to see your '
                'progress here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final ProgressSummary summary;

  const _TodayCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final goalReached = summary.todaySeconds >= summary.dailyGoalSeconds;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Today', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  '${summary.dailyGoalMinutes} min goal',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              formatDurationCompact(Duration(seconds: summary.todaySeconds)),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryMain,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: summary.todayGoalProgress,
                minHeight: 8,
                backgroundColor: AppColors.primaryPale,
                valueColor: AlwaysStoppedAnimation<Color>(
                  goalReached ? Colors.green.shade600 : AppColors.primaryMain,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              goalReached
                  ? 'Daily goal reached'
                  : '${formatDurationCompact(Duration(seconds: summary.dailyGoalSeconds - summary.todaySeconds))} to go',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final ProgressSummary summary;

  const _StatGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'This week',
            value: formatDurationCompact(
              Duration(seconds: summary.weekSeconds),
            ),
            icon: Icons.date_range,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'All time',
            value: formatDurationCompact(
              Duration(seconds: summary.lifetimeSeconds),
            ),
            icon: Icons.history,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Streak',
            value: '${summary.currentStreak}d',
            icon: Icons.local_fire_department,
            caption: summary.longestStreak > 0
                ? 'best ${summary.longestStreak}d'
                : null,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? caption;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryMain),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            if (caption != null)
              Text(
                caption!,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<DailyActivity> activities;

  const _WeeklyChart({required this.activities});

  static const double _maxBarHeight = 96;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const SizedBox.shrink();

    final maxSeconds = activities.fold<int>(
      0,
      (max, a) => a.seconds > max ? a.seconds : max,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last 7 days', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: _maxBarHeight + 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final activity in activities)
                    Expanded(
                      child: _DayBar(
                        activity: activity,
                        maxSeconds: maxSeconds,
                        maxBarHeight: _maxBarHeight,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  final DailyActivity activity;
  final int maxSeconds;
  final double maxBarHeight;

  const _DayBar({
    required this.activity,
    required this.maxSeconds,
    required this.maxBarHeight,
  });

  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final fraction = maxSeconds <= 0 ? 0.0 : activity.seconds / maxSeconds;
    final height = maxSeconds <= 0
        ? 2.0
        : (fraction * maxBarHeight).clamp(2.0, maxBarHeight);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (activity.reviews > 0)
          Text(
            '${activity.reviews}',
            style: const TextStyle(fontSize: 10, color: AppColors.primaryMain),
          ),
        Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: activity.hasActivity
                ? AppColors.primaryMain
                : AppColors.primaryPale,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _weekdayLabels[activity.day.weekday - 1],
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _LearningCard extends StatelessWidget {
  final ProgressSummary summary;

  const _LearningCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Learning', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _LearningRow(
              icon: Icons.bookmark,
              label: 'Sentences mined',
              value: '${summary.totalSentences}',
              caption: '${summary.sentencesThisWeek} this week',
            ),
            const Divider(height: 20),
            _LearningRow(
              icon: Icons.translate,
              label: 'Words saved',
              value: '${summary.totalWords}',
              caption: '${summary.wordsLearningOrBetter} learning or better',
            ),
            const Divider(height: 20),
            _LearningRow(
              icon: Icons.pending_actions,
              label: 'Due for review',
              value: '${summary.dueCount}',
            ),
            const Divider(height: 20),
            _LearningRow(
              icon: Icons.check_circle_outline,
              label: 'Reviewed today',
              value: '${summary.reviewedToday}',
              caption: '${summary.totalReviews} all time',
            ),
          ],
        ),
      ),
    );
  }
}

class _LearningRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? caption;

  const _LearningRow({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryMain),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              if (caption != null)
                Text(
                  caption!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
