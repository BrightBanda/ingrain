import 'package:ingrain/core/storage/document_store.dart';
import 'package:ingrain/features/auth/domain/auth_repository.dart';
import 'package:ingrain/features/dialogue/data/dialogue_dto.dart';
import 'package:ingrain/features/dialogue/domain/dialogue.dart';

/// Dialogues the user pasted in themselves, stored with the rest of their data
/// at `users/{uid}/myDialogues/{id}`.
class UserDialogueRepository {
  final DocumentStore _store;
  final AuthRepository _auth;

  UserDialogueRepository(this._store, this._auth);

  static const collection = 'myDialogues';

  /// Prefix that keeps user ids from ever colliding with catalogue ids.
  static const idPrefix = 'my-';

  static bool isUserDialogueId(String id) => id.startsWith(idPrefix);

  static String newId() =>
      '$idPrefix${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

  /// Newest first.
  Future<List<Dialogue>> listAll() async {
    final uid = await _auth.ensureUid();
    final docs = await _store.listDocs(uid, collection);
    final dialogues = docs
        .where((doc) => doc['id'] is String)
        .map((doc) => DialogueDto.fromMap(doc).toDomain())
        .toList();
    dialogues.sort(
      (a, b) =>
          (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
    );
    return dialogues;
  }

  Future<Dialogue?> get(String id) async {
    final uid = await _auth.ensureUid();
    final doc = await _store.getDoc(uid, collection, id);
    if (doc['id'] is! String) return null;
    return DialogueDto.fromMap(doc).toDomain();
  }

  Future<void> save(Dialogue dialogue) async {
    final uid = await _auth.ensureUid();
    await _store.setDoc(uid, collection, dialogue.id, dialogueToMap(dialogue));
  }

  Future<void> delete(String id) async {
    final uid = await _auth.ensureUid();
    await _store.deleteDoc(uid, collection, id);
  }
}
