import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/profile/domain/learner_preferences.dart';
import 'package:ingrain/features/profile/presentation/widgets/preference_pickers.dart';
import 'package:ingrain/features/progress/domain/progress_summary.dart';
import 'package:ingrain/features/progress/presentation/view/progress_dashboard.dart';
import 'package:ingrain/features/progress/presentation/viewmodel/progress_view_model.dart';

// Small phones with the system font size turned up are where text-heavy
// layouts break first. These screens must fit there without overflowing.

class _BusyWeek extends ProgressViewModel {
  @override
  ProgressUiState build() {
    final today = DateTime(2026, 10, 8);
    return ProgressUiState.data(
      ProgressSummary(
        todaySeconds: 1800,
        weekSeconds: 9000,
        lifetimeSeconds: 90000,
        currentStreak: 5,
        longestStreak: 9,
        totalSentences: 40,
        sentencesThisWeek: 6,
        dueCount: 12,
        reviewedToday: 30,
        totalReviews: 400,
        dailyGoalMinutes: 30,
        last7Days: [
          for (var i = 6; i >= 0; i--)
            DailyActivity(
              day: today.subtract(Duration(days: i)),
              // The busiest day also has reviews: its count label sits on
              // top of the tallest bar, which used to overflow.
              seconds: i == 2 ? 5400 : 600 * (i + 1),
              reviews: i == 2 ? 128 : i,
            ),
        ],
      ),
    );
  }
}

void main() {
  Future<void> pumpAtLargeText(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [progressViewModelProvider.overrideWith(_BusyWeek.new)],
        child: MaterialApp(
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: app!,
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the weekly chart fits, review counts and all', (tester) async {
    await pumpAtLargeText(tester, const ProgressDashboard());
    await tester.scrollUntilVisible(find.text('Last 7 days'), 200);

    expect(tester.takeException(), isNull);
    expect(find.text('128'), findsOneWidget);
  });

  testWidgets('long onboarding options wrap instead of being cut off', (
    tester,
  ) async {
    await pumpAtLargeText(
      tester,
      SingleChildScrollView(
        child: ReasonPicker(selected: const {}, onToggle: (_) {}),
      ),
    );

    expect(tester.takeException(), isNull);
    final label = tester.widget<Text>(find.text(LearningReason.media.label));
    expect(label.maxLines, isNull);
    expect(label.overflow, isNot(TextOverflow.ellipsis));

    // Tiles in a row share a height, so the grid stays even.
    final media = tester.getSize(
      find.ancestor(
        of: find.text(LearningReason.media.label),
        matching: find.byType(SelectableTile),
      ),
    );
    final other = tester.getSize(
      find.ancestor(
        of: find.text(LearningReason.other.label),
        matching: find.byType(SelectableTile),
      ),
    );
    expect(media.width, other.width);
  });
}
