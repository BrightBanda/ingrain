import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ingrain/core/storage/local_document_store.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError(
    'Initialize SharedPreferences before runApp by overriding '
    'sharedPreferencesProvider.',
  );
});

final localDocumentStoreProvider = Provider<LocalDocumentStore>((ref) {
  return LocalDocumentStore(ref.watch(sharedPreferencesProvider));
});
