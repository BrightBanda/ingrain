class YoutubeUrlParser {
  static const _videoIdPattern = r'^[a-zA-Z0-9_-]{11}$';
  static String parse(String input) {
    final trimmed = input.trim();

    final bareId = _tryBareId(trimmed);
    if (bareId != null) return bareId;

    final fromUrl = _tryFromUrl(trimmed);
    if (fromUrl != null) return fromUrl;

    throw FormatException('Invalid YouTube URL or video ID: $input');
  }

  static String? _tryBareId(String input) {
    if (RegExp(_videoIdPattern).hasMatch(input)) return input;
    return null;
  }

  static String? _tryFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    if (uri.host.contains('youtu.be')) {
      return _extractFromPath(uri.path);
    }

    if (uri.host.contains('youtube.com') ||
        uri.host.contains('m.youtube.com') ||
        uri.host.contains('youtube-nocookie.com')) {
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'shorts') {
        return _extractFromPath(uri.path);
      }

      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'embed') {
        return _extractFromPath(uri.path);
      }

      final id = uri.queryParameters['v'];
      if (id != null && RegExp(_videoIdPattern).hasMatch(id)) {
        return id;
      }
    }

    final match = RegExp(r'([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (match != null) {
      final candidate = match.group(1)!;
      return candidate;
    }

    return null;
  }

  static String? _extractFromPath(String path) {
    final segments = path.split('/');
    for (final segment in segments) {
      if (RegExp(_videoIdPattern).hasMatch(segment)) {
        return segment;
      }
    }
    return null;
  }
}
