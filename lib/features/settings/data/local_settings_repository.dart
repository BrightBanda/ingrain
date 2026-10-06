import 'package:ingrain/core/storage/document_store.dart';
import 'package:ingrain/features/auth/domain/auth_repository.dart';
import 'package:ingrain/features/settings/domain/app_settings.dart';
import 'package:ingrain/features/settings/domain/settings_repository.dart';

class LocalSettingsRepository implements SettingsRepository {
  final DocumentStore _store;
  final AuthRepository _auth;

  LocalSettingsRepository(this._store, this._auth);

  static const String collection = 'settings';
  static const String docId = 'app';

  @override
  Future<AppSettings> get settings async {
    final uid = await _auth.ensureUid();
    final doc = await _store.getDoc(uid, collection, docId);
    if (doc.isEmpty) {
      return const AppSettings();
    }
    return AppSettings(
      dailyGoalMinutes: (doc['dailyGoalMinutes'] as num?)?.toInt() ?? 30,
      themeMode: _parseThemeMode(doc['themeMode'] as String?),
      playbackSpeed: (doc['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      subtitleFontSize: (doc['subtitleFontSize'] as num?)?.toDouble() ?? 16.0,
      showRomaji: doc['showRomaji'] as bool? ?? false,
    );
  }

  @override
  Future<void> update(AppSettings settings) async {
    final uid = await _auth.ensureUid();
    await _store.setDoc(uid, collection, docId, {
      'dailyGoalMinutes': settings.dailyGoalMinutes,
      'themeMode': settings.themeMode.name,
      'playbackSpeed': settings.playbackSpeed,
      'subtitleFontSize': settings.subtitleFontSize,
      'showRomaji': settings.showRomaji,
    });
  }

  @override
  Future<void> setDailyGoalMinutes(int minutes) =>
      _updateField('dailyGoalMinutes', minutes);

  @override
  Future<void> setThemeMode(ThemeSetting mode) =>
      _updateField('themeMode', mode.name);

  @override
  Future<void> setPlaybackSpeed(double speed) =>
      _updateField('playbackSpeed', speed);

  @override
  Future<void> setSubtitleFontSize(double size) =>
      _updateField('subtitleFontSize', size);

  @override
  Future<void> setShowRomaji(bool show) => _updateField('showRomaji', show);

  Future<void> _updateField(String key, dynamic value) async {
    final uid = await _auth.ensureUid();
    final existing = await _store.getDoc(uid, collection, docId);
    existing[key] = value;
    await _store.setDoc(uid, collection, docId, existing);
  }

  static ThemeSetting _parseThemeMode(String? name) {
    if (name == null) return ThemeSetting.system;
    return ThemeSetting.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ThemeSetting.system,
    );
  }
}
