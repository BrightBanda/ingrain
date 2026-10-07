/// A YouTube video found by search, before it is in the library.
class VideoSearchResult {
  final String videoId;
  final String title;
  final String? channelTitle;
  final Duration? duration;
  final String thumbnailUrl;

  const VideoSearchResult({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    this.channelTitle,
    this.duration,
  });

  String get url => 'https://www.youtube.com/watch?v=$videoId';
}

abstract interface class VideoSearchRepository {
  /// Up to one page of videos matching [query].
  Future<List<VideoSearchResult>> search(String query);

  /// The video behind a link or id, or null when it does not exist.
  Future<VideoSearchResult?> lookup(String videoId);
}
