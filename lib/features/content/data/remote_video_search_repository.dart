import 'package:ingrain/core/error/app_error.dart';
import 'package:ingrain/core/network/api_client.dart';
import 'package:ingrain/features/content/domain/video_search.dart';

/// YouTube search through the HitaruJP API (`/youtube/search`,
/// `/youtube/videos/{id}`).
///
/// Used on web, where the browser blocks calls to youtube.com (CORS) and
/// [YoutubeVideoSearchRepository] cannot work. Mobile keeps searching YouTube
/// directly.
class RemoteVideoSearchRepository implements VideoSearchRepository {
  final ApiClient _api;

  RemoteVideoSearchRepository(this._api);

  @override
  Future<List<VideoSearchResult>> search(String query) async {
    final json = await _api.get('/youtube/search', query: {'q': query});
    final items = (json as Map)['items'] as List? ?? const [];
    return [
      for (final item in items) parse(Map<String, dynamic>.from(item as Map)),
    ];
  }

  @override
  Future<VideoSearchResult?> lookup(String videoId) async {
    try {
      final json = await _api.get('/youtube/videos/$videoId');
      return parse(Map<String, dynamic>.from(json as Map));
    } on ApiException catch (error) {
      if (error.error.type == AppErrorType.notFound) return null;
      rethrow;
    }
  }

  /// Maps one video from the API. Public for tests.
  static VideoSearchResult parse(Map<String, dynamic> json) {
    final seconds = (json['durationSeconds'] as num?)?.toInt();
    return VideoSearchResult(
      videoId: json['videoId'] as String,
      title: json['title'] as String,
      channelTitle: json['channelTitle'] as String?,
      duration: seconds == null ? null : Duration(seconds: seconds),
      thumbnailUrl: json['thumbnailUrl'] as String,
    );
  }
}
