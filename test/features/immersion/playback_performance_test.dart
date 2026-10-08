import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/content/domain/transcript_sentence.dart';
import 'package:ingrain/features/content/presentation/view/player/immersion_player_view.dart';
import 'package:ingrain/features/content/presentation/view/player/transcript_view.dart';
import 'package:ingrain/features/content/presentation/viewmodel/content_view_model.dart';
import 'package:ingrain/features/immersion/presentation/viewmodel/immersion_session_view_model.dart';
import 'package:ingrain/features/vocabulary/presentation/widgets/tappable_transcript_text.dart';

import 'immersion_session_view_model_test.dart'
    show FakeImmersionRepository, ManualClock;

// While a video plays the player reports its position several times a second.
// These tests pin down that those reports only cause work when something the
// learner can see actually changes.

const sentences = [
  TranscriptSentence(index: 0, text: 'おはよう', startSeconds: 0, endSeconds: 3),
  TranscriptSentence(index: 1, text: 'ございます', startSeconds: 3, endSeconds: 6),
];

void main() {
  test('a repeated position does not replace the session state', () async {
    final container = ProviderContainer(
      overrides: [
        immersionRepositoryProvider.overrideWithValue(
          FakeImmersionRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final provider = immersionSessionViewModelProvider('video-1');
    var notifications = 0;
    container.listen(provider, (_, _) => notifications++);
    final vm = container.read(provider.notifier);

    await vm.updatePosition(12);
    await vm.updatePosition(12);
    await vm.updatePosition(12);
    await vm.updatePosition(13);

    expect(notifications, 2);
    expect(container.read(provider).lastPositionSeconds, 13);
  });

  group('session clock around fullscreen', () {
    late FakeImmersionRepository repository;
    late ManualClock clock;
    late ProviderContainer container;

    setUp(() {
      repository = FakeImmersionRepository();
      clock = ManualClock(DateTime(2026, 1, 1, 12));
      container = ProviderContainer(
        overrides: [
          immersionRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(clock),
          // Long enough that the periodic tick never fires during a test.
          tickIntervalProvider.overrideWithValue(const Duration(hours: 1)),
        ],
      );
      addTearDown(container.dispose);
    });

    test('overlapping "playing" reports start one session, not two', () async {
      final vm = container.read(
        immersionSessionViewModelProvider('video-1').notifier,
      );

      // The play button and the iframe both report playing before the first
      // start has been stored.
      await Future.wait([
        vm.startSession(sourceTitle: 'Video'),
        vm.startSession(sourceTitle: 'Video'),
      ]);
      clock.advance(const Duration(seconds: 30));
      await vm.startSession(sourceTitle: 'Video');

      expect(repository.sessions, hasLength(1));
      expect(
        container.read(immersionSessionViewModelProvider('video-1')).sessionId,
        repository.sessions.single.id,
      );
    });

    test('pausing and resuming often does not lose time', () async {
      final provider = immersionSessionViewModelProvider('video-1');
      final vm = container.read(provider.notifier);
      await vm.startSession(sourceTitle: 'Video');

      // Entering and leaving fullscreen: a pause and a play each time,
      // 700ms of playback in between. Ten of those are 7 seconds.
      for (var i = 0; i < 10; i++) {
        clock.advance(const Duration(milliseconds: 700));
        vm.pauseSession();
        vm.resumeSession();
      }
      vm.pauseSession();

      expect(container.read(provider).elapsedSeconds, 7);
      expect(container.read(provider).isPaused, isTrue);
    });
  });

  test('the current transcript line only changes between lines', () async {
    final container = ProviderContainer(
      overrides: [
        transcriptProvider('video-1').overrideWith((ref) async => sentences),
      ],
    );
    addTearDown(container.dispose);
    await container.read(transcriptProvider('video-1').future);

    final lines = <int>[];
    container.listen(
      currentSentenceIndexProvider('video-1'),
      (_, next) => lines.add(next),
      fireImmediately: true,
    );
    final position = container.read(playbackPositionProvider.notifier);
    // Four reports a second for five seconds.
    for (var ms = 0; ms <= 5000; ms += 250) {
      position.setPosition(Duration(milliseconds: ms));
      await Future<void>.delayed(Duration.zero);
    }

    expect(lines, [0, 1], reason: 'twenty reports, two line changes');
  });

  test('a position between lines has no current line', () {
    expect(currentSentenceIndex(sentences, 1), 0);
    expect(currentSentenceIndex(sentences, 3), 1);
    expect(currentSentenceIndex(sentences, 9), -1);
  });

  testWidgets('tap recognizers survive a rebuild with the same words', (
    tester,
  ) async {
    final tapped = <String>[];
    Widget text(Color color) => MaterialApp(
      home: Scaffold(
        body: TappableTranscriptText(
          tokens: const ['猫', 'が', '好き'],
          highlightColor: color,
          onTokenTap: tapped.add,
        ),
      ),
    );
    List<GestureRecognizer?> recognizers() {
      final span = tester.widget<RichText>(find.byType(RichText)).text;
      final found = <GestureRecognizer?>[];
      span.visitChildren((child) {
        if (child is TextSpan && child.recognizer != null) {
          found.add(child.recognizer);
        }
        return true;
      });
      return found;
    }

    await tester.pumpWidget(text(Colors.blue));
    final before = recognizers();
    // The current line moving re-styles the row; the words are unchanged.
    await tester.pumpWidget(text(Colors.black));

    expect(recognizers(), hasLength(3));
    for (var i = 0; i < 3; i++) {
      expect(identical(recognizers()[i], before[i]), isTrue);
    }

    (recognizers()[2]! as TapGestureRecognizer).onTap!();
    expect(tapped, ['好き']);
  });
}
