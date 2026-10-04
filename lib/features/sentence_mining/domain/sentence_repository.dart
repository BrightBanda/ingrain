import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/sentence_mining/domain/sentence_item.dart';

abstract interface class SentenceRepository {
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
  });

  Future<SentenceItem?> get(String id);

  Future<void> delete(String id);

  Stream<List<SentenceItem>> watchAll();

  Future<int> count();

  Future<int> countCreatedOn(DateTime day);
}
