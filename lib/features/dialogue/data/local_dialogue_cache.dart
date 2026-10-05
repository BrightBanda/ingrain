import 'package:ingrain/core/storage/local_document_store.dart';
import 'package:ingrain/features/auth/domain/auth_repository.dart';
import 'package:ingrain/features/dialogue/data/dialogue_dto.dart';
import 'package:ingrain/features/dialogue/domain/dialogue.dart';

class LocalDialogueCache {
  final LocalDocumentStore _store;
  final AuthRepository _auth;

  LocalDialogueCache(this._store, this._auth);

  static const _collection = 'dialogues';
  static const _indexDocument = '_index';

  Future<List<DialogueSummary>> getSummaries() async {
    final uid = await _auth.ensureUid();
    final doc = await _store.getDoc(uid, _collection, _indexDocument);
    final raw = doc['summaries'];
    if (raw is! List) return const [];
    return raw
        .map(
          (value) => DialogueSummaryDto.fromMap(
            Map<String, dynamic>.from(value as Map),
          ).toDomain(),
        )
        .toList();
  }

  Future<void> cacheSummaries(List<DialogueSummary> summaries) async {
    final uid = await _auth.ensureUid();
    final previous = await getSummaries();
    final nextById = {for (final item in summaries) item.id: item};
    for (final item in previous) {
      final next = nextById[item.id];
      if (next != null && next.updatedAt != item.updatedAt) {
        await _store.deleteDoc(uid, '$_collection/${item.id}', 'dialogue');
      }
    }
    await _store.registerCollection(uid, _collection);
    await _store.setDoc(uid, _collection, _indexDocument, {
      'summaries': summaries
          .map((item) => DialogueSummaryDto(item).map)
          .toList(),
    });
  }

  Future<Dialogue?> getDialogue(String id) async {
    final uid = await _auth.ensureUid();
    final doc = await _store.getDoc(uid, '$_collection/$id', 'dialogue');
    final raw = doc['dialogue'];
    if (raw is! Map) return null;
    return DialogueDto.fromMap(Map<String, dynamic>.from(raw)).toDomain();
  }

  Future<void> cacheDialogue(Dialogue dialogue) async {
    final uid = await _auth.ensureUid();
    final collection = '$_collection/${dialogue.id}';
    await _store.registerCollection(uid, collection);
    await _store.setDoc(uid, collection, 'dialogue', {
      'dialogue': dialogueToMap(dialogue),
    });
  }
}
