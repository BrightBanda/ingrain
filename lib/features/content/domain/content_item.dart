enum SourceType { youtube, podcast, manual }

class ContentItem {
  final String id;
  final SourceType sourceType;
  final String sourceUrl;
  final String title;
  final String? channelTitle;
  final String? thumbnailUrl;
  final int lastPositionSeconds;
  final int totalImmersionSeconds;
  final DateTime lastOpenedAt;

  const ContentItem({
    required this.id,
    required this.sourceType,
    required this.sourceUrl,
    required this.title,
    this.channelTitle,
    this.thumbnailUrl,
    this.lastPositionSeconds = 0,
    this.totalImmersionSeconds = 0,
    required this.lastOpenedAt,
  });

  ContentItem copyWith({
    String? id,
    SourceType? sourceType,
    String? sourceUrl,
    String? title,
    String? channelTitle,
    String? thumbnailUrl,
    int? lastPositionSeconds,
    int? totalImmersionSeconds,
    DateTime? lastOpenedAt,
  }) {
    return ContentItem(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      title: title ?? this.title,
      channelTitle: channelTitle ?? this.channelTitle,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
      totalImmersionSeconds:
          totalImmersionSeconds ?? this.totalImmersionSeconds,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }
}
