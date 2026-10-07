import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/content/domain/transcript_sentence.dart';
import 'package:ingrain/features/content/data/transcript_parser.dart';

void main() {
  group('TranscriptParser', () {
    group('SRT format', () {
      test('parses valid SRT', () {
        const srt = '''1
00:00:01,000 --> 00:00:04,000
Hello world

2
00:00:05,000 --> 00:00:08,500
This is a test''';

        final result = TranscriptParser.parse(srt, durationSeconds: 10);
        expect(result.length, 2);
        expect(result[0].text, 'Hello world');
        expect(result[0].startSeconds, 1);
        expect(result[0].endSeconds, 4);
        expect(result[1].text, 'This is a test');
        expect(result[1].startSeconds, 5);
        expect(result[1].endSeconds, 8);
      });

      test('parses SRT with comma and period timestamps', () {
        const srt = '''1
00:00:01,500 --> 00:00:04,500
Test''';

        final result = TranscriptParser.parse(srt, durationSeconds: 10);
        expect(result.length, 1);
        expect(result[0].startSeconds, 1);
        expect(result[0].endSeconds, 4);
      });

      test('handles BOM', () {
        const srt = '\uFEFF1\n00:00:01,000 --> 00:00:02,000\nHello';
        final result = TranscriptParser.parse(srt, durationSeconds: 10);
        expect(result.length, 1);
        expect(result[0].text, 'Hello');
      });

      test('handles CRLF line endings', () {
        const srt = '1\r\n00:00:01,000 --> 00:00:02,000\r\nHello\r\n\r\n';
        final result = TranscriptParser.parse(srt, durationSeconds: 10);
        expect(result.length, 1);
        expect(result[0].text, 'Hello');
      });

      test('parses SRT without explicit index numbers', () {
        const srt = '''00:00:01,000 --> 00:00:02,000
Hello

00:00:03,000 --> 00:00:04,000
World''';

        final result = TranscriptParser.parse(srt, durationSeconds: 10);
        expect(result.length, 2);
        expect(result[0].text, 'Hello');
        expect(result[0].startSeconds, 1);
        expect(result[1].text, 'World');
        expect(result[1].startSeconds, 3);
      });

      test('skips malformed entries', () {
        const srt = '''1
00:00:01,000 --> 00:00:02,000
Hello

not a valid line

2
00:00:03,000 --> 00:00:04,000
World''';

        final result = TranscriptParser.parse(srt, durationSeconds: 10);
        expect(result.length, 2);
      });

      test('handles out-of-order cues by sorting', () {
        const srt = '''1
00:00:05,000 --> 00:00:08,000
Second

2
00:00:01,000 --> 00:00:04,000
First''';

        final result = TranscriptParser.parse(srt, durationSeconds: 10);
        expect(result.length, 2);
        expect(result[0].text, 'First');
        expect(result[1].text, 'Second');
      });

      test('normalizes overlapping cues', () {
        const srt = '''1
00:00:01,000 --> 00:00:05,000
First

2
00:00:03,000 --> 00:00:06,000
Second''';

        final result = TranscriptParser.parse(srt, durationSeconds: 10);
        expect(result.length, 2);
        expect(result[0].endSeconds, result[1].startSeconds);
      });
    });

    group('WebVTT format', () {
      test('parses WebVTT with header', () {
        const vtt = '''WEBVTT

1
00:00:01.000 --> 00:00:04.000
Hello world

2
00:00:05.000 --> 00:00:08.500
This is a test''';

        final result = TranscriptParser.parse(vtt, durationSeconds: 10);
        expect(result.length, 2);
        expect(result[0].text, 'Hello world');
        expect(result[0].startSeconds, 1);
        expect(result[1].text, 'This is a test');
        expect(result[1].endSeconds, 8);
      });

      test('parses WebVTT without header', () {
        const vtt = '''1
00:00:01.000 --> 00:00:02.000
Hello''';

        final result = TranscriptParser.parse(vtt, durationSeconds: 10);
        expect(result.length, 1);
        expect(result[0].text, 'Hello');
      });
    });

    group('Plain text format', () {
      test('splits on Japanese punctuation', () {
        const text = 'こんにちは。良い天気です。';
        final result = TranscriptParser.parse(text, durationSeconds: 10);
        expect(result.length, 2);
        expect(result[0].text, 'こんにちは。');
        expect(result[1].text, '良い天気です。');
      });

      test('splits on exclamation and question marks', () {
        const text = 'お元気ですか！いいえ。';
        final result = TranscriptParser.parse(text, durationSeconds: 9);
        expect(result.length, 2);
        expect(result[0].text, 'お元気ですか！');
        expect(result[1].text, 'いいえ。');
      });

      test('distributes timestamps proportionally by char count', () {
        const text = 'aaaa。bb。';
        final result = TranscriptParser.parse(text, durationSeconds: 60);
        expect(result.length, 2);
        expect(result[0].startSeconds, 0);
        expect(result[0].endSeconds, 38); // 5/8 * 60 = 37.5 -> 38
        expect(result[1].startSeconds, 38);
        expect(result[1].endSeconds, 60);
      });

      test('handles newlines as sentence boundaries', () {
        const text = 'Line one\nLine two\n';
        final result = TranscriptParser.parse(text, durationSeconds: 10);
        expect(result.length, 2);
        expect(result[0].text, 'Line one');
        expect(result[1].text, 'Line two');
      });
    });

    group('Edge cases', () {
      test('returns empty for empty input', () {
        final result = TranscriptParser.parse('', durationSeconds: 0);
        expect(result, isEmpty);
      });

      test('handles mixed content correctly', () {
        const text = 'Hello world';
        final result = TranscriptParser.parse(text, durationSeconds: 10);
        expect(result.length, 1);
        expect(result[0].text, 'Hello world');
      });
    });
  });

  test('toSrt round-trips timings and text', () {
    const sentences = [
      TranscriptSentence(
        index: 0,
        text: 'こんにちは',
        startSeconds: 0,
        endSeconds: 3,
      ),
      TranscriptSentence(
        index: 1,
        text: '元気ですか',
        startSeconds: 3725,
        endSeconds: 3730,
      ),
    ];

    final parsed = TranscriptParser.parse(
      TranscriptParser.toSrt(sentences),
      durationSeconds: 0,
    );

    expect(parsed.map((s) => (s.text, s.startSeconds, s.endSeconds)), [
      ('こんにちは', 0, 3),
      ('元気ですか', 3725, 3730),
    ]);
  });
}
