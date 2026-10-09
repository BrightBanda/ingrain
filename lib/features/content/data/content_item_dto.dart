import 'package:ingrain/features/content/domain/content_item.dart';

class ContentItemDto {
  final Map<String, dynamic> map;

  ContentItemDto({
    required String id,
    required SourceType sourceType,
    required String sourceUrl,
    required String title,
    String? channelTitle,
    String? thumbnailUrl,
    int lastPositionSeconds = 0,
    int totalImmersionSeconds = 0,
    DateTime? lastOpenedAt,
    int? durationSeconds,
  }) : map = {
         'id': id,
         'sourceType': sourceType.name,
         'sourceUrl': sourceUrl,
         'title': title,
         'channelTitle': channelTitle,
         'thumbnailUrl': thumbnailUrl,
         'lastPositionSeconds': lastPositionSeconds,
         'totalImmersionSeconds': totalImmersionSeconds,
         if (lastOpenedAt != null)
           'lastOpenedAt': lastOpenedAt.toIso8601String(),
         if (durationSeconds != null) 'durationSeconds': durationSeconds,
       };

  ContentItemDto.fromMap(Map<String, dynamic> data) : map = Map.from(data);

  ContentItem toDomain() {
    return ContentItem(
      id: map['id'] as String,
      sourceType: SourceType.values.firstWhere(
        (e) => e.name == map['sourceType'],
        orElse: () => SourceType.manual,
      ),
      sourceUrl: map['sourceUrl'] as String,
      title: map['title'] as String,
      channelTitle: map['channelTitle'] as String?,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      lastPositionSeconds: (map['lastPositionSeconds'] as num?)?.toInt() ?? 0,
      totalImmersionSeconds:
          (map['totalImmersionSeconds'] as num?)?.toInt() ?? 0,
      lastOpenedAt: () {
        final str = map['lastOpenedAt'] as String?;
        return str != null ? DateTime.parse(str) : DateTime.now();
      }(),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt(),
    );
  }
}
