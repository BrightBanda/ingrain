import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/vocabulary/domain/vocabulary_item.dart';

class VocabularyItemDto {
  final Map<String, dynamic> map;

  VocabularyItemDto({
    required String id,
    required String uid,
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
    required VocabState state,
    required DateTime createdAt,
    required DateTime updatedAt,
    int encounterCount = 1,
  }) : map = {
         'id': id,
         'uid': uid,
         'word': word,
         'reading': reading,
         'meaning': meaning,
         'pos': pos,
         'sourceType': sourceType.name,
         'sourceId': sourceId,
         'sourceTitle': sourceTitle,
         'timestampSeconds': timestampSeconds,
         'contextSentence': contextSentence,
         'sessionId': sessionId,
         'state': state.name,
         'createdAt': createdAt.toIso8601String(),
         'updatedAt': updatedAt.toIso8601String(),
         'encounterCount': encounterCount,
       };

  VocabularyItemDto.fromMap(Map<String, dynamic> data) : map = Map.from(data);

  VocabularyItem toDomain() {
    final timestamp = (map['timestampSeconds'] as num?)?.toInt();
    final createdAt = DateTime.parse(map['createdAt'] as String);
    final updatedAt = map['updatedAt'] == null
        ? createdAt
        : DateTime.parse(map['updatedAt'] as String);
    return VocabularyItem(
      id: map['id'] as String,
      uid: map['uid'] as String,
      word: map['word'] as String,
      reading: map['reading'] as String?,
      meaning: map['meaning'] as String?,
      pos: map['pos'] as String?,
      sourceType: SourceType.values.firstWhere(
        (e) => e.name == map['sourceType'],
        orElse: () => SourceType.manual,
      ),
      sourceId: map['sourceId'] as String,
      sourceTitle: map['sourceTitle'] as String?,
      timestampSeconds: timestamp,
      contextSentence: map['contextSentence'] as String?,
      sessionId: map['sessionId'] as String?,
      state: VocabState.fromName(map['state'] as String?),
      createdAt: createdAt,
      updatedAt: updatedAt,
      encounterCount: (map['encounterCount'] as num?)?.toInt() ?? 1,
    );
  }

  static VocabularyItem? fromMapSafe(Map<String, dynamic> data) {
    const requiredKeys = ['id', 'uid', 'word', 'sourceId', 'createdAt'];
    for (final key in requiredKeys) {
      if (data[key] == null) return null;
    }
    return VocabularyItemDto.fromMap(data).toDomain();
  }
}
