import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/core/error/app_error.dart';
import 'package:ingrain/features/ai/domain/ai_explanation.dart';
import 'package:ingrain/features/ai/presentation/ai_explanation_providers.dart';
import 'package:ingrain/features/sentence_mining/presentation/view/sentence_save_sheet.dart';
import 'package:ingrain/features/vocabulary/presentation/view/vocabulary_lookup_sheet.dart';

class FakeAiRepository implements AiExplanationRepository {
  final List<ExplainRequest> requests = [];
  bool fail = false;

  /// When set, answers wait for it, so a test can see the loading state.
  Completer<void>? hold;

  @override
  Future<AiExplanation> explain(ExplainRequest request) async {
    requests.add(request);
    await hold?.future;
    if (fail) {
      throw const AiExplanationException(
        AppError(type: AppErrorType.rateLimited, message: 'The AI is busy.'),
      );
    }
    return const AiExplanation(
      translation: 'cat',
      reading: 'ねこ',
      meaning: 'The animal.',
      partOfSpeech: 'noun',
      nuance: 'Neutral word.',
      formality: 'neutral',
      grammar: [GrammarPoint(point: 'が', explanation: 'marks the subject')],
      alternatives: [NaturalAlternative(japanese: 'にゃんこ', note: 'cute')],
    );
  }
}

Future<FakeAiRepository> pump(WidgetTester tester, Widget child) async {
  final fake = FakeAiRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [aiExplanationRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  return fake;
}

void main() {
  testWidgets('the lookup sheet only asks the AI when the learner taps', (
    tester,
  ) async {
    final fake = await pump(
      tester,
      VocabularyLookupSheet(word: '猫', contextLabel: '猫がいる', onSave: () {}),
    );

    expect(fake.requests, isEmpty);
    await tester.tap(find.text('Explain with AI'));
    await tester.pumpAndSettle();

    expect(fake.requests.single, (
      text: '猫',
      kind: ExplainKind.word,
      context: '猫がいる',
    ));
    expect(find.text('cat'), findsOneWidget);
    expect(find.text('The animal.'), findsOneWidget);
    expect(find.text('にゃんこ'), findsOneWidget);
  });

  testWidgets('an AI failure shows its message and can be retried', (
    tester,
  ) async {
    final fake = await pump(
      tester,
      VocabularyLookupSheet(word: '猫', onSave: () {}),
    );
    fake.fail = true;

    await tester.tap(find.text('Explain with AI'));
    await tester.pumpAndSettle();
    expect(find.text('The AI is busy.'), findsOneWidget);

    fake.fail = false;
    fake.hold = Completer<void>();
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Asking the AI…'), findsOneWidget);
    expect(find.text('The AI is busy.'), findsNothing);

    fake.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.text('cat'), findsOneWidget);
    expect(fake.requests, hasLength(2));
  });

  testWidgets('mining fills translation and notes from the AI', (tester) async {
    final fake = await pump(
      tester,
      const SentenceSaveSheet(title: 'Mine sentence', japanese: '猫がいる'),
    );

    await tester.tap(find.text('Translate & explain with AI'));
    await tester.pumpAndSettle();

    expect(fake.requests.single.kind, ExplainKind.sentence);
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Translation (optional)'),
          )
          .controller!
          .text,
      'cat',
    );
    final notes = tester
        .widget<TextField>(
          find.widgetWithText(TextField, 'Explanation / notes (optional)'),
        )
        .controller!
        .text;
    expect(notes, contains('• が: marks the subject'));
  });
}
