import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/vocabulary/domain/vocabulary_item.dart';

abstract interface class VocabularyRepository {
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
    VocabState state,
    DateTime? createdAt,
  });

  Future<VocabularyItem?> get(String id);

  Future<void> update(VocabularyItem item);

  Future<void> delete(String id);

  Stream<List<VocabularyItem>> watchAll();

  /// Exact-word lookup, used to detect a word that is already saved.
  Future<VocabularyItem?> findByWord(String word);

  /// Registers a fresh encounter on an already saved word and returns the
  /// updated item, or null when the word is unknown.
  Future<VocabularyItem?> recordEncounter(String id, {DateTime? encounteredAt});

  Future<int> count();

  Future<Map<VocabState, int>> countByState();
}
