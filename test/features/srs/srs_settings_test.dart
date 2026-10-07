import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/core/storage/local_document_store.dart';
import 'package:ingrain/features/srs/data/srs_settings_repository.dart';
import 'package:ingrain/features/srs/domain/srs_settings.dart';
import 'package:ingrain/features/srs/presentation/view/srs_settings_view.dart';
import 'package:ingrain/features/srs/presentation/viewmodel/review_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  late SrsSettingsRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = SrsSettingsRepository(
      LocalDocumentStore(await SharedPreferences.getInstance()),
      FakeAuthRepository(),
    );
  });

  test('defaults when nothing is saved, round-trips when it is', () async {
    final defaults = await repository.load();
    expect(defaults.newCardsPerDay, 20);
    expect(defaults.learningSteps, const [
      Duration(minutes: 1),
      Duration(minutes: 10),
    ]);

    await repository.save(
      const SrsSettings(
        newCardsPerDay: 7,
        learningSteps: [Duration(minutes: 5), Duration(hours: 1)],
        relearningSteps: [],
        intervalModifier: 0.9,
      ),
    );
    final saved = await repository.load();

    expect(saved.newCardsPerDay, 7);
    expect(saved.learningSteps, const [
      Duration(minutes: 5),
      Duration(hours: 1),
    ]);
    expect(saved.relearningSteps, isEmpty);
    expect(saved.intervalModifier, 0.9);
  });

  test('daily counts add up per deck and per day', () async {
    final day = DateTime(2026, 5, 1, 9);
    await repository.recordStudied(day, 'a', wasNew: true, wasReview: false);
    await repository.recordStudied(day, 'a', wasNew: false, wasReview: true);
    await repository.recordStudied(day, 'b', wasNew: true, wasReview: false);
    await repository.recordStudied(
      DateTime(2026, 5, 2),
      'a',
      wasNew: true,
      wasReview: false,
    );

    final counts = await repository.countsFor(DateTime(2026, 5, 1, 23));
    expect((counts['a']!.newStudied, counts['a']!.reviewsDone), (1, 1));
    expect(counts['b']!.newStudied, 1);
  });

  testWidgets('the settings screen edits and saves values', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          srsSettingsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: SrsSettingsView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New cards per day'), findsOneWidget);
    expect(find.text('1m 10m'), findsOneWidget);

    await tester.tap(find.text('New cards per day'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '35');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await repository.load()).newCardsPerDay, 35);

    await tester.tap(find.text('Learning steps'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '10m nonsense');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Use steps like'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '2m 15m 1h');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('2m 15m 1h'), findsOneWidget);
    expect((await repository.load()).learningSteps, hasLength(3));
  });
}
