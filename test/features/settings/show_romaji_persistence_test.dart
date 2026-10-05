import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/core/storage/local_document_store.dart';
import 'package:ingrain/features/auth/domain/auth_repository.dart';
import 'package:ingrain/features/settings/data/local_settings_repository.dart';
import 'package:ingrain/features/settings/domain/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth implements AuthRepository {
  @override
  Future<String> ensureUid() async => 'settings-test-user';

  @override
  Future<String?> get displayName async => null;

  @override
  Future<void> setDisplayName(String name) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('showRomaji persists across settings repository reads', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalSettingsRepository(
      LocalDocumentStore(preferences),
      _Auth(),
    );

    await repository.update(const AppSettings(showRomaji: true));

    expect((await repository.settings).showRomaji, isTrue);
  });
}
