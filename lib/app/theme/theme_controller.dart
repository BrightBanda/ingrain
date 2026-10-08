import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/features/settings/domain/app_settings.dart';
import 'package:ingrain/features/settings/presentation/viewmodel/settings_view_model.dart';

/// Exposes the persisted [ThemeSetting] as a [ThemeMode] for `MaterialApp`.
///
/// The settings view model is the single writer; this provider only projects
/// its state so the app shell can react to changes coming from the Settings
/// screen. [overrideTo] exists for immediate feedback while settings are
/// still booting, and for tests.
class ThemeControllerNotifier extends Notifier<ThemeMode> {
  ThemeMode? _override;

  @override
  ThemeMode build() {
    final uiState = ref.watch(settingsViewModelProvider);
    final persisted = switch (uiState.settings?.themeMode) {
      ThemeSetting.light => ThemeMode.light,
      ThemeSetting.dark => ThemeMode.dark,
      ThemeSetting.system || null => ThemeMode.system,
    };
    final override = _override;
    if (override != null && uiState.settings == null) return override;
    _override = null;
    return persisted;
  }

  /// Immediately switches the app theme and persists the choice.
  Future<void> setMode(ThemeMode mode) async {
    _override = mode;
    state = mode;
    final current = ref.read(settingsViewModelProvider).settings;
    if (current == null) return;
    await ref.read(settingsViewModelProvider.notifier).setThemeMode(
      switch (mode) {
        ThemeMode.light => ThemeSetting.light,
        ThemeMode.dark => ThemeSetting.dark,
        ThemeMode.system => ThemeSetting.system,
      },
    );
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeControllerNotifier, ThemeMode>(
      ThemeControllerNotifier.new,
    );
