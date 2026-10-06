import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/app/router.dart';
import 'package:ingrain/features/auth/domain/auth_state.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/dialogue/domain/dialogue.dart';
import 'package:ingrain/features/dialogue/domain/dialogue_repository.dart';
import 'package:ingrain/features/dialogue/presentation/viewmodel/dialogue_providers.dart';
import 'package:ingrain/shared/widgets/double_back_to_exit.dart';
import '../support/test_overrides.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Skips the onboarding bootstrap so the router settles straight on the shell.
class OnboardedAuthViewModel extends AuthViewModel {
  @override
  AuthState build() =>
      const AuthState.ready(uid: 'uid-1', displayName: 'Tester');
}

class NavigationDialogueRepository implements DialogueRepository {
  final dialogue = Dialogue(
    id: 'lesson-1',
    title: 'At the station',
    level: 'N5',
    lines: [
      DialogueLine(
        index: 0,
        tokens: [DialogueToken(surface: '駅', reading: 'えき', romaji: 'eki')],
      ),
    ],
  );

  @override
  bool isShowingCachedCopy = false;

  @override
  Future<List<DialogueSummary>> listSummaries() async => [dialogue];

  @override
  Future<Dialogue> getDialogue(String id) async => dialogue;

  @override
  Future<Dialogue?> getCachedDialogue(String id) async => dialogue;

  @override
  Future<void> cacheDialogue(Dialogue dialogue) async {}
}

void main() {
  late List<MethodCall> platformCalls;

  setUp(() {
    platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Iterable<MethodCall> exitCalls() =>
      platformCalls.where((call) => call.method == 'SystemNavigator.pop');

  /// Mirrors the Android back button reaching the running app.
  Future<void> pressSystemBack(WidgetTester tester) async {
    final message = const JSONMethodCodec().encodeMethodCall(
      const MethodCall('popRoute'),
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      message,
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        ...appTestOverrides(prefs),
        authViewModelProvider.overrideWith(OnboardedAuthViewModel.new),
        dialogueRepositoryProvider.overrideWithValue(
          NavigationDialogueRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(appRouterProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('app bar back buttons', () {
    testWidgets('the root tab offers no back button', (tester) async {
      await pumpApp(tester);

      expect(find.text('ingrain'), findsOneWidget);
      expect(find.text('YouTube video'), findsOneWidget);
      expect(find.text('Japanese podcasts'), findsOneWidget);
      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final gridDelegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(gridDelegate.crossAxisCount, 2);
      expect(gridDelegate.childAspectRatio, 1);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
      await tester.pumpAndSettle();
      expect(find.text('Japanese dialogue'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('study mode grid does not overflow on a phone viewport', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpApp(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('a study card opens Library, where content can be added', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.text('YouTube video'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Library'), findsOneWidget);
      expect(find.text('Add content'), findsOneWidget);

      await tester.tap(find.text('Add content'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Add Content'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Library'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('podcast and dialogue cards also open Library', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Japanese podcasts'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Library'), findsOneWidget);

      await tester.tap(find.text('Immerse'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Japanese dialogue'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Library'), findsOneWidget);
    });

    testWidgets('system back from Add Content returns to Library', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.text('YouTube video'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add content'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Add Content'), findsOneWidget);

      await pressSystemBack(tester);

      expect(find.widgetWithText(AppBar, 'Library'), findsOneWidget);
      expect(exitCalls(), isEmpty);
      expect(find.text(DoubleBackToExit.message), findsNothing);
    });
  });

  testWidgets('Library filter shows dialogues and opens the reader', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('Dialogues'), findsOneWidget);

    await tester.tap(find.text('Dialogues'));
    await tester.pumpAndSettle();
    expect(find.text('At the station'), findsOneWidget);

    await tester.tap(find.text('At the station'));
    await tester.pumpAndSettle();
    expect(find.text('駅'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  group('double back to exit', () {
    testWidgets('the first back press on a root tab only warns', (
      tester,
    ) async {
      await pumpApp(tester);

      await pressSystemBack(tester);

      expect(find.text(DoubleBackToExit.message), findsOneWidget);
      expect(find.text('ingrain'), findsOneWidget);
      expect(exitCalls(), isEmpty);
    });

    testWidgets('the second back press leaves the app', (tester) async {
      await pumpApp(tester);

      await pressSystemBack(tester);
      await pressSystemBack(tester);

      expect(exitCalls(), hasLength(1));
    });

    testWidgets('the warning lapses, so a later press only warns again', (
      tester,
    ) async {
      await pumpApp(tester);

      await pressSystemBack(tester);
      await tester.pump(
        DoubleBackToExit.promptDuration + const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();

      await pressSystemBack(tester);

      expect(find.text(DoubleBackToExit.message), findsOneWidget);
      expect(exitCalls(), isEmpty);
    });
  });
}
