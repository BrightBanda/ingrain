import 'package:ingrain/core/storage/document_store.dart';
import 'package:ingrain/features/auth/domain/auth_repository.dart';
import 'package:ingrain/features/kana/domain/kana_knowledge.dart';

/// Stores every mark in one document beside the profile,
/// `users/{uid}/profile/kana`: `{"states": {"あ": "known", "か": "somewhat"}}`.
///
/// One small document (at most ~200 entries) means one read for the whole
/// board, and it travels with the rest of the learner's profile.
class LocalKanaProgressRepository implements KanaProgressRepository {
  final DocumentStore _store;
  final AuthRepository _auth;

  LocalKanaProgressRepository(this._store, this._auth);

  static const String collection = 'profile';
  static const String docId = 'kana';
  static const String field = 'states';

  @override
  Future<Map<String, KanaKnowledge>> load() async {
    final uid = await _auth.ensureUid();
    final doc = await _store.getDoc(uid, collection, docId);
    final raw = doc[field];
    if (raw is! Map) return {};
    return {
      for (final entry in raw.entries)
        '${entry.key}': ?KanaKnowledge.fromCode(entry.value),
    };
  }

  @override
  Future<void> set(String kana, KanaKnowledge? knowledge) async {
    final uid = await _auth.ensureUid();
    final doc = await _store.getDoc(uid, collection, docId);
    final states = Map<String, dynamic>.from(doc[field] as Map? ?? const {});
    if (knowledge == null) {
      states.remove(kana);
    } else {
      states[kana] = knowledge.code;
    }
    await _store.setDoc(uid, collection, docId, {
      field: states,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
