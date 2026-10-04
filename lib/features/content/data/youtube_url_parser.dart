class YoutubeUrlParser {
  static const _videoIdPattern = r'^[a-zA-Z0-9_-]{11}$';

  /// Parses a YouTube URL or 11-character video ID and returns the video ID.
  /// Throws a [FormatException] if parsing fails.
  static String parse(String input) {
    final result = tryParse(input);
    if (result != null) return result;

    throw FormatException('Invalid YouTube URL or video ID: $input');
  }

  /// Attempts to parse a YouTube URL or video ID.
  /// Returns null if the input is not a valid YouTube URL or video ID.
  static String? tryParse(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final bareId = _tryBareId(trimmed);
    if (bareId != null) return bareId;

    return _tryFromUrl(trimmed);
  }

  static String? _tryBareId(String input) {
    if (RegExp(_videoIdPattern).hasMatch(input)) return input;
    return null;
  }

  static String? _tryFromUrl(String input) {
    final normalized =
        (input.startsWith('http://') || input.startsWith('https://'))
        ? input
        : 'https://$input';

    final uri = Uri.tryParse(normalized);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();

    // youtu.be shortlinks: https://youtu.be/<videoId>?si=...
    if (host.contains('youtu.be')) {
      return _extractFromPathSegments(uri.pathSegments);
    }

    // Standard YouTube domains (including m.youtube.com, www.youtube.com, etc.)
    final isYouTubeDomain =
        host.contains('youtube.com') || host.contains('youtube-nocookie.com');

    if (isYouTubeDomain) {
      // 1. Check 'v' query parameter (e.g. /watch?v=ID or /watch?si=...&v=ID)
      final id = uri.queryParameters['v'];
      if (id != null && RegExp(_videoIdPattern).hasMatch(id)) {
        return id;
      }

      // 2. Check path segments for /shorts/ID, /embed/ID, /live/ID, /v/ID
      if (uri.pathSegments.isNotEmpty) {
        final first = uri.pathSegments.first.toLowerCase();
        if (const {'shorts', 'embed', 'live', 'v'}.contains(first)) {
          if (uri.pathSegments.length >= 2 &&
              RegExp(_videoIdPattern).hasMatch(uri.pathSegments[1])) {
            return uri.pathSegments[1];
          }
        }
        return _extractFromPathSegments(uri.pathSegments);
      }
    }

    // Fallback: check 'v' parameter or path segments only (avoid matching tracking params)
    final queryId = uri.queryParameters['v'];
    if (queryId != null && RegExp(_videoIdPattern).hasMatch(queryId)) {
      return queryId;
    }

    return _extractFromPathSegments(uri.pathSegments);
  }

  static String? _extractFromPathSegments(List<String> segments) {
    for (final segment in segments) {
      if (RegExp(_videoIdPattern).hasMatch(segment)) {
        return segment;
      }
    }
    return null;
  }
}
