import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/app/theme/theme_controller.dart';
import 'package:ingrain/core/providers.dart';
import 'package:ingrain/features/settings/domain/app_settings.dart';
import 'package:ingrain/features/settings/presentation/viewmodel/settings_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;

  Future<void> pump() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    // Warm up both providers so the projected theme mode is resolved.
    container.read(settingsViewModelProvider);
    await Future<void>.delayed(Duration.zero);
    container.read(themeControllerProvider);
  }

  group('ThemeControllerNotifier', () {
    testWidgets('defaults to system when no theme is persisted', (tester) async {
      await pump();

      expect(container.read(themeControllerProvider), ThemeMode.system);
    });

    testWidgets('projects a persisted dark setting', (tester) async {
      await pump();

      await container
          .read(settingsViewModelProvider.notifier)
          .setThemeMode(ThemeSetting.dark);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(themeControllerProvider), ThemeMode.dark);
    });

    testWidgets('projects a persisted light setting', (tester) async {
      await pump();

      await container
          .read(settingsViewModelProvider.notifier)
          .setThemeMode(ThemeSetting.light);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(themeControllerProvider), ThemeMode.light);
    });

    testWidgets('setMode switches immediately and persists the choice', (
      tester,
    ) async {
      await pump();

      await container
          .read(themeControllerProvider.notifier)
          .setMode(ThemeMode.dark);

      expect(container.read(themeControllerProvider), ThemeMode.dark);

      final settings = await container.read(settingsRepositoryProvider).settings;
      expect(settings.themeMode, ThemeSetting.dark);
    });

    testWidgets('setMode back to system keeps following persisted state', (
      tester,
    ) async {
      await pump();

      await container
          .read(themeControllerProvider.notifier)
          .setMode(ThemeMode.dark);
      await container
          .read(themeControllerProvider.notifier)
          .setMode(ThemeMode.system);

      expect(container.read(themeControllerProvider), ThemeMode.system);
      final settings = await container.read(settingsRepositoryProvider).settings;
      expect(settings.themeMode, ThemeSetting.system);
    });
  });
}
