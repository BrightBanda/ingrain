import 'package:ingrain/features/content/domain/video_search.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Searches YouTube through `youtube_explode_dart`, the same library that
/// fetches captions. No API key or quota, at the cost of relying on an
/// unofficial client that can break when YouTube changes its pages.
class YoutubeVideoSearchRepository implements VideoSearchRepository {
  final YoutubeExplode _youtube;

  YoutubeVideoSearchRepository([YoutubeExplode? youtube])
    : _youtube = youtube ?? YoutubeExplode();

  void close() => _youtube.close();

  @override
  Future<List<VideoSearchResult>> search(String query) async {
    final videos = await _youtube.search.search(query);
    return [
      for (final video in videos)
        // Live streams have no fixed transcript to read along with.
        if (!video.isLive) _toResult(video),
    ];
  }

  @override
  Future<VideoSearchResult?> lookup(String videoId) async {
    try {
      return _toResult(await _youtube.videos.get(videoId));
    } on VideoUnavailableException {
      return null;
    }
  }

  static VideoSearchResult _toResult(Video video) => VideoSearchResult(
    videoId: video.id.value,
    title: video.title,
    channelTitle: video.author,
    duration: video.duration,
    thumbnailUrl: video.thumbnails.mediumResUrl,
  );
}
