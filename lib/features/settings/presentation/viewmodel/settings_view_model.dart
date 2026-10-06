import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/core/error/app_error.dart';
import 'package:ingrain/core/providers.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/settings/data/local_settings_repository.dart';
import 'package:ingrain/features/settings/domain/app_settings.dart';
import 'package:ingrain/features/settings/domain/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final store = ref.watch(documentStoreProvider);
  final auth = ref.watch(authRepositoryProvider);
  return LocalSettingsRepository(store, auth);
});

class SettingsUiState {
  final bool isLoading;
  final AppSettings? settings;
  final AppError? error;

  const SettingsUiState._({required this.isLoading, this.settings, this.error});

  const SettingsUiState.loading() : this._(isLoading: true);

  const SettingsUiState.data(AppSettings settings)
    : this._(isLoading: false, settings: settings);

  const SettingsUiState.error(AppError error)
    : this._(isLoading: false, error: error);

  SettingsUiState copyWith({
    bool? isLoading,
    AppSettings? settings,
    AppError? error,
  }) {
    return SettingsUiState._(
      isLoading: isLoading ?? this.isLoading,
      settings: settings ?? this.settings,
      error: error ?? this.error,
    );
  }
}

final settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, SettingsUiState>(SettingsViewModel.new);

class SettingsViewModel extends Notifier<SettingsUiState> {
  late SettingsRepository _repository;

  @override
  SettingsUiState build() {
    _repository = ref.watch(settingsRepositoryProvider);
    _load();
    return const SettingsUiState.loading();
  }

  Future<void> _load() async {
    try {
      final settings = await _repository.settings;
      state = SettingsUiState.data(settings);
    } catch (e, st) {
      state = SettingsUiState.error(
        AppError.unknown(e, message: st.toString()),
      );
    }
  }

  Future<void> update(AppSettings settings) async {
    try {
      await _repository.update(settings);
      state = SettingsUiState.data(settings);
    } catch (e, st) {
      state = SettingsUiState.error(
        AppError.unknown(e, message: st.toString()),
      );
    }
  }

  Future<void> setDailyGoalMinutes(int minutes) async {
    final current = state.settings;
    if (current == null) return;
    await update(current.copyWith(dailyGoalMinutes: minutes));
  }

  Future<void> setThemeMode(ThemeSetting mode) async {
    final current = state.settings;
    if (current == null) return;
    await update(current.copyWith(themeMode: mode));
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final current = state.settings;
    if (current == null) return;
    await update(current.copyWith(playbackSpeed: speed));
  }

  Future<void> setSubtitleFontSize(double size) async {
    final current = state.settings;
    if (current == null) return;
    await update(current.copyWith(subtitleFontSize: size));
  }

  Future<void> setShowRomaji(bool show) async {
    final current = state.settings;
    if (current == null) return;
    await update(current.copyWith(showRomaji: show));
  }
}
