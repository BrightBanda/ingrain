import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/content/data/youtube_url_parser.dart';

void main() {
  group('YoutubeUrlParser', () {
    test('parses youtu.be URL', () {
      expect(
        YoutubeUrlParser.parse('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('parses youtube.com/watch URL', () {
      expect(
        YoutubeUrlParser.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('parses youtube.com/watch with timestamp', () {
      expect(
        YoutubeUrlParser.parse(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30s',
        ),
        'dQw4w9WgXcQ',
      );
    });

    test('parses youtu.be with timestamp', () {
      expect(
        YoutubeUrlParser.parse('https://youtu.be/dQw4w9WgXcQ?t=30'),
        'dQw4w9WgXcQ',
      );
    });

    test('parses bare video ID', () {
      expect(YoutubeUrlParser.parse('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    });

    test('parses youtube.com/shorts URL', () {
      expect(
        YoutubeUrlParser.parse('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('parses embed URL', () {
      expect(
        YoutubeUrlParser.parse('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('rejects empty string', () {
      expect(() => YoutubeUrlParser.parse(''), throwsA(isA<FormatException>()));
    });

    test('rejects invalid URL with no valid ID', () {
      expect(
        () => YoutubeUrlParser.parse('https://example.com'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects too-short ID', () {
      expect(
        () => YoutubeUrlParser.parse('abc'),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles m.youtube.com URL', () {
      expect(
        YoutubeUrlParser.parse('https://m.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('handles youtube-nocookie.com URL', () {
      expect(
        YoutubeUrlParser.parse(
          'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ',
        ),
        'dQw4w9WgXcQ',
      );
    });
  });
}
