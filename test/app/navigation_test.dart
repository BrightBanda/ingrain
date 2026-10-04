import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/app/router.dart';
import 'package:ingrain/core/providers.dart';
import 'package:ingrain/features/auth/domain/auth_state.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/shared/widgets/double_back_to_exit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Skips the onboarding bootstrap so the router settles straight on the shell.
class OnboardedAuthViewModel extends AuthViewModel {
  @override
  AuthState build() =>
      const AuthState.ready(uid: 'uid-1', displayName: 'Tester');
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
        sharedPreferencesProvider.overrideWithValue(prefs),
        authViewModelProvider.overrideWith(OnboardedAuthViewModel.new),
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
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('a pushed screen shows a back button that returns to the tab', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.text('Add your first video'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Add Content'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Add your first video'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('the system back button pops a pushed screen too', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.text('Add your first video'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Add Content'), findsOneWidget);

      await pressSystemBack(tester);

      expect(find.text('Add your first video'), findsOneWidget);
      expect(exitCalls(), isEmpty);
      expect(find.text(DoubleBackToExit.message), findsNothing);
    });
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
