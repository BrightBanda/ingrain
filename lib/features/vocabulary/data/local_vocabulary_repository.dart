import 'dart:math';

import 'package:ingrain/core/storage/local_document_store.dart';
import 'package:ingrain/features/auth/domain/auth_repository.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/vocabulary/data/vocabulary_item_dto.dart';
import 'package:ingrain/features/vocabulary/domain/vocabulary_item.dart';
import 'package:ingrain/features/vocabulary/domain/vocabulary_repository.dart';

class LocalVocabularyRepository implements VocabularyRepository {
  final LocalDocumentStore _store;
  final AuthRepository _auth;

  LocalVocabularyRepository(this._store, this._auth);

  static const String collection = 'vocabulary';

  static String generateVocabularyId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = Random.secure().nextInt(0xFFFFFF);
    return '${ms.toRadixString(36)}-$rand';
  }

  @override
  Future<VocabularyItem> save({
    required String word,
    String? reading,
    String? meaning,
    String? pos,
    required SourceType sourceType,
    required String sourceId,
    String? sourceTitle,
    int? timestampSeconds,
    String? contextSentence,
    String? sessionId,
    VocabState state = VocabState.encountered,
    DateTime? createdAt,
  }) async {
    final uid = await _auth.ensureUid();
    final id = generateVocabularyId();
    final now = createdAt ?? DateTime.now();
    final item = VocabularyItem(
      id: id,
      uid: uid,
      word: word,
      reading: _normalize(reading),
      meaning: _normalize(meaning),
      pos: _normalize(pos),
      sourceType: sourceType,
      sourceId: sourceId,
      sourceTitle: _normalize(sourceTitle),
      timestampSeconds: timestampSeconds,
      contextSentence: _normalize(contextSentence),
      sessionId: sessionId,
      state: state,
      createdAt: now,
      updatedAt: now,
    );
    await _store.setDoc(uid, collection, id, _toMap(item));
    return item;
  }

  @override
  Future<VocabularyItem?> get(String id) async {
    final uid = await _auth.ensureUid();
    final doc = await _store.getDoc(uid, collection, id);
    if (doc.isEmpty) return null;
    return VocabularyItemDto.fromMapSafe(doc);
  }

  @override
  Future<void> update(VocabularyItem item) async {
    final uid = await _auth.ensureUid();
    await _store.setDoc(uid, collection, item.id, _toMap(item));
  }

  @override
  Future<void> delete(String id) async {
    final uid = await _auth.ensureUid();
    await _store.deleteDoc(uid, collection, id);
  }

  @override
  Stream<List<VocabularyItem>> watchAll() async* {
    final uid = await _auth.ensureUid();
    final items = await _readAll(uid);
    yield items;
  }

  @override
  Future<VocabularyItem?> findByWord(String word) async {
    final uid = await _auth.ensureUid();
    final items = await _readAll(uid);
    for (final item in items) {
      if (item.word == word) return item;
    }
    return null;
  }

  @override
  Future<VocabularyItem?> recordEncounter(
    String id, {
    DateTime? encounteredAt,
  }) async {
    final existing = await get(id);
    if (existing == null) return null;

    final updated = existing.copyWith(
      encounterCount: existing.encounterCount + 1,
      updatedAt: encounteredAt ?? DateTime.now(),
    );
    await update(updated);
    return updated;
  }

  @override
  Future<int> count() async {
    final uid = await _auth.ensureUid();
    return (await _readAll(uid)).length;
  }

  @override
  Future<Map<VocabState, int>> countByState() async {
    final uid = await _auth.ensureUid();
    final counts = {for (final state in VocabState.values) state: 0};
    for (final item in await _readAll(uid)) {
      counts[item.state] = counts[item.state]! + 1;
    }
    return counts;
  }

  Future<List<VocabularyItem>> _readAll(String uid) async {
    final docs = await _store.listDocs(uid, collection);
    return docs
        .map(VocabularyItemDto.fromMapSafe)
        .whereType<VocabularyItem>()
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Map<String, dynamic> _toMap(VocabularyItem item) {
    return VocabularyItemDto(
      id: item.id,
      uid: item.uid,
      word: item.word,
      reading: item.reading,
      meaning: item.meaning,
      pos: item.pos,
      sourceType: item.sourceType,
      sourceId: item.sourceId,
      sourceTitle: item.sourceTitle,
      timestampSeconds: item.timestampSeconds,
      contextSentence: item.contextSentence,
      sessionId: item.sessionId,
      state: item.state,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      encounterCount: item.encounterCount,
    ).map;
  }

  static String? _normalize(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
