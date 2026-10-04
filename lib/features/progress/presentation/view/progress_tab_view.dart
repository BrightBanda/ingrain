import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        automaticallyImplyLeading: false,
        title: const Text('Progress'),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _TodayCard(summary: summary),
          const SizedBox(height: 12),
          _StatGrid(summary: summary),
          const SizedBox(height: 12),
          _WeeklyChart(activities: summary.last7Days),
          const SizedBox(height: 12),
          _LearningCard(summary: summary),
          if (summary.dueCount > 0) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('/review'),
              icon: const Icon(Icons.school),
              label: Text('Review ${summary.dueCount} due now'),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/vocabulary'),
            icon: const Icon(Icons.translate),
            label: const Text('Browse saved vocabulary'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/sentences'),
            icon: const Icon(Icons.bookmark_border),
            label: const Text('Browse mined sentences'),
          ),
          if (summary.isEmpty) ...[
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Start an immersion session and mine a sentence to see your '
                'progress here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Today's immersion against the daily goal, drawn as the dashboard hero.
class _TodayCard extends StatelessWidget {
  final ProgressSummary summary;

  const _TodayCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final goalReached = summary.todaySeconds >= summary.dailyGoalSeconds;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: goalReached
              ? [
                  theme.colorScheme.primary.withValues(alpha: 0.9),
                  theme.colorScheme.tertiary.withValues(alpha: 0.8),
                ]
              : [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.65),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Today',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '${summary.dailyGoalMinutes} min goal',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatDurationCompact(Duration(seconds: summary.todaySeconds)),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: summary.todayGoalProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            goalReached
                ? 'Daily goal reached 🎉'
                : '${formatDurationCompact(Duration(seconds: summary.dailyGoalSeconds - summary.todaySeconds))} to go',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
            accentColor: summary.currentStreak > 0
                ? const Color(0xFFF59E0B)
                : null,
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
  final Color? accentColor;
  final String? caption;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
            if (caption != null)
              Text(
                caption!,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
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

    final theme = Theme.of(context);
    final maxSeconds = activities.fold<int>(
      0,
      (max, a) => a.seconds > max ? a.seconds : max,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last 7 days', style: theme.textTheme.titleMedium),
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
    final theme = Theme.of(context);
    final fraction = maxSeconds <= 0 ? 0.0 : activity.seconds / maxSeconds;
    final height = maxSeconds <= 0
        ? 2.0
        : (fraction * maxBarHeight).clamp(2.0, maxBarHeight);
    final isActive = activity.hasActivity;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (activity.reviews > 0)
          Text(
            '${activity.reviews}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.55),
                    ],
                  )
                : null,
            color: isActive
                ? null
                : theme.colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _weekdayLabels[activity.day.weekday - 1],
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
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
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Learning', style: theme.textTheme.titleMedium),
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
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyLarge),
              if (caption != null)
                Text(caption!, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
        ),
      ],
    );
  }
}
