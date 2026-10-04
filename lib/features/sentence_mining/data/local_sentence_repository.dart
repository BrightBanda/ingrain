import 'dart:math';

import 'package:ingrain/core/storage/local_document_store.dart';
import 'package:ingrain/features/auth/domain/auth_repository.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/sentence_mining/data/sentence_item_dto.dart';
import 'package:ingrain/features/sentence_mining/domain/sentence_item.dart';
import 'package:ingrain/features/sentence_mining/domain/sentence_repository.dart';

class LocalSentenceRepository implements SentenceRepository {
  final LocalDocumentStore _store;
  final AuthRepository _auth;

  LocalSentenceRepository(this._store, this._auth);

  static const String collection = 'sentences';

  static String generateSentenceId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = Random.secure().nextInt(0xFFFFFF);
    return '${ms.toRadixString(36)}-$rand';
  }

  @override
  Future<SentenceItem> save({
    required String japanese,
    String? translation,
    String? explanation,
    required SourceType sourceType,
    required String sourceId,
    String? sourceTitle,
    int? timestampSeconds,
    String? contextSentence,
    String? sessionId,
    DateTime? createdAt,
  }) async {
    final uid = await _auth.ensureUid();
    final id = generateSentenceId();
    final sentence = SentenceItem(
      id: id,
      uid: uid,
      japanese: japanese,
      translation: _normalize(translation),
      explanation: _normalize(explanation),
      sourceType: sourceType,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      timestampSeconds: timestampSeconds,
      contextSentence: _normalize(contextSentence),
      sessionId: sessionId,
      createdAt: createdAt ?? DateTime.now(),
    );
    final dto = SentenceItemDto(
      id: sentence.id,
      uid: sentence.uid,
      japanese: sentence.japanese,
      translation: sentence.translation,
      explanation: sentence.explanation,
      sourceType: sentence.sourceType,
      sourceId: sentence.sourceId,
      sourceTitle: sentence.sourceTitle,
      timestampSeconds: sentence.timestampSeconds,
      contextSentence: sentence.contextSentence,
      sessionId: sentence.sessionId,
      createdAt: sentence.createdAt,
    );
    await _store.setDoc(uid, collection, id, dto.map);
    return sentence;
  }

  @override
  Future<SentenceItem?> get(String id) async {
    final uid = await _auth.ensureUid();
    final doc = await _store.getDoc(uid, collection, id);
    if (doc.isEmpty) return null;
    return SentenceItemDto.fromMapSafe(doc);
  }

  @override
  Future<void> delete(String id) async {
    final uid = await _auth.ensureUid();
    await _store.deleteDoc(uid, collection, id);
  }

  @override
  Stream<List<SentenceItem>> watchAll() async* {
    final uid = await _auth.ensureUid();
    final docs = await _store.listDocs(uid, collection);
    final sentences =
        docs.map(SentenceItemDto.fromMapSafe).whereType<SentenceItem>().toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    yield sentences;
  }

  @override
  Future<int> count() async {
    final uid = await _auth.ensureUid();
    final docs = await _store.listDocs(uid, collection);
    return docs
        .map(SentenceItemDto.fromMapSafe)
        .whereType<SentenceItem>()
        .length;
  }

  @override
  Future<int> countCreatedOn(DateTime day) async {
    final uid = await _auth.ensureUid();
    final docs = await _store.listDocs(uid, collection);
    final target = DateTime(day.year, day.month, day.day);
    return docs
        .map(SentenceItemDto.fromMapSafe)
        .whereType<SentenceItem>()
        .where((s) {
          final created = s.createdAt.toLocal();
          return !created.isBefore(target) &&
              created.isBefore(target.add(const Duration(days: 1)));
        })
        .length;
  }

  static String? _normalize(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
