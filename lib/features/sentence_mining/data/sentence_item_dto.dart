import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/sentence_mining/domain/sentence_item.dart';

class SentenceItemDto {
  final Map<String, dynamic> map;

  SentenceItemDto({
    required String id,
    required String uid,
    required String japanese,
    String? translation,
    String? explanation,
    required SourceType sourceType,
    required String sourceId,
    String? sourceTitle,
    int? timestampSeconds,
    String? contextSentence,
    String? sessionId,
    required DateTime createdAt,
  }) : map = {
         'id': id,
         'uid': uid,
         'japanese': japanese,
         'translation': translation,
         'explanation': explanation,
         'sourceType': sourceType.name,
         'sourceId': sourceId,
         'sourceTitle': sourceTitle,
         'timestampSeconds': timestampSeconds,
         'contextSentence': contextSentence,
         'sessionId': sessionId,
         'createdAt': createdAt.toIso8601String(),
       };

  SentenceItemDto.fromMap(Map<String, dynamic> data) : map = Map.from(data);

  SentenceItem toDomain() {
    final timestamp = (map['timestampSeconds'] as num?)?.toInt();
    return SentenceItem(
      id: map['id'] as String,
      uid: map['uid'] as String,
      japanese: map['japanese'] as String,
      translation: map['translation'] as String?,
      explanation: map['explanation'] as String?,
      sourceType: SourceType.values.firstWhere(
        (e) => e.name == map['sourceType'],
        orElse: () => SourceType.manual,
      ),
      sourceId: map['sourceId'] as String,
      sourceTitle: map['sourceTitle'] as String?,
      timestampSeconds: timestamp,
      contextSentence: map['contextSentence'] as String?,
      sessionId: map['sessionId'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  static SentenceItem? fromMapSafe(Map<String, dynamic> data) {
    const requiredKeys = ['id', 'uid', 'japanese', 'sourceId', 'createdAt'];
    for (final key in requiredKeys) {
      if (data[key] == null) return null;
    }
    return SentenceItemDto.fromMap(data).toDomain();
  }
}
