import 'package:ingrain/features/content/domain/transcript_sentence.dart';

class TranscriptParser {
  static List<TranscriptSentence> parse(
    String raw, {
    required int durationSeconds,
    TranscriptFormat format = TranscriptFormat.auto,
  }) {
    final detected = format == TranscriptFormat.auto
        ? _detectFormat(raw)
        : format;

    switch (detected) {
      case TranscriptFormat.srt:
        return _parseSrt(raw);
      case TranscriptFormat.webvtt:
        return _parseWebVtt(raw);
      case TranscriptFormat.plain:
        return _parsePlain(raw, durationSeconds);
      case TranscriptFormat.auto:
        return _parsePlain(raw, durationSeconds);
    }
  }

  static TranscriptFormat _detectFormat(String raw) {
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('WEBVTT')) {
      return TranscriptFormat.webvtt;
    }
    if (_hasSrtTimecode(trimmed)) {
      return TranscriptFormat.srt;
    }
    return TranscriptFormat.plain;
  }

  static bool _hasSrtTimecode(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      if (RegExp(
        r'^\d{2}:\d{2}:\d{2}[,.]\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}[,.]\d{3}',
      ).hasMatch(line)) {
        return true;
      }
    }
    return false;
  }

  static List<TranscriptSentence> _parseSrt(String raw) {
    final stripped = _stripBom(raw);
    final lines = stripped.split(RegExp(r'\r?\n'));
    final sentences = <TranscriptSentence>[];
    var index = 0;
    var i = 0;

    while (i < lines.length) {
      final numberLine = lines[i].trim();
      final number = int.tryParse(numberLine);

      if (number != null) {
        i++;
        if (i >= lines.length) break;

        final timeLine = lines[i].trim();
        final times = _parseSrtTimestamps(timeLine);
        if (times == null) {
          i++;
          continue;
        }

        final startSec = times.$1;
        final endSec = times.$2;
        i++;

        final textLines = <String>[];
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          textLines.add(lines[i].trim());
          i++;
        }

        final text = textLines.join(' ');
        if (text.isNotEmpty) {
          sentences.add(
            TranscriptSentence(
              index: index++,
              text: text,
              startSeconds: startSec,
              endSeconds: endSec,
            ),
          );
        }
      } else {
        final timeLine = lines[i].trim();
        final times = _parseSrtTimestamps(timeLine);
        if (times != null) {
          final startSec = times.$1;
          final endSec = times.$2;
          i++;

          final textLines = <String>[];
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            textLines.add(lines[i].trim());
            i++;
          }

          final text = textLines.join(' ');
          if (text.isNotEmpty) {
            sentences.add(
              TranscriptSentence(
                index: index++,
                text: text,
                startSeconds: startSec,
                endSeconds: endSec,
              ),
            );
          }
        } else {
          i++;
        }
      }
    }

    if (sentences.isEmpty) return sentences;
    return _normalizeOverlapping(sentences);
  }

  static (int, int)? _parseSrtTimestamps(String line) {
    final match = RegExp(
      r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})',
    ).firstMatch(line);
    if (match == null) return null;

    final startH = int.parse(match.group(1)!);
    final startM = int.parse(match.group(2)!);
    final startS = int.parse(match.group(3)!);
    final startMs = int.parse(match.group(4)!);
    final endH = int.parse(match.group(5)!);
    final endM = int.parse(match.group(6)!);
    final endS = int.parse(match.group(7)!);
    final endMs = int.parse(match.group(8)!);

    final startTotal = startH * 3600 + startM * 60 + startS + startMs ~/ 1000;
    final endTotal = endH * 3600 + endM * 60 + endS + endMs ~/ 1000;

    return (startTotal, endTotal);
  }

  static List<TranscriptSentence> _parseWebVtt(String raw) {
    final stripped = _stripBom(raw);
    final lines = stripped.split(RegExp(r'\r?\n'));
    final sentences = <TranscriptSentence>[];
    var index = 0;
    var i = 0;

    while (i < lines.length && !lines[i].startsWith('NOTE')) {
      i++;
    }

    if (i >= lines.length) {
      return _parseSrt(stripped);
    }

    while (i < lines.length) {
      final line = lines[i].trim();

      if (line.isEmpty) {
        i++;
        continue;
      }

      final times = _parseSrtTimestamps(line);
      if (times != null) {
        final startSec = times.$1;
        final endSec = times.$2;
        i++;

        final textLines = <String>[];
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          textLines.add(lines[i].trim());
          i++;
        }

        final text = textLines.join(' ');
        if (text.isNotEmpty) {
          sentences.add(
            TranscriptSentence(
              index: index++,
              text: text,
              startSeconds: startSec,
              endSeconds: endSec,
            ),
          );
        }
      } else {
        i++;
      }
    }

    if (sentences.isEmpty) return sentences;
    return _normalizeOverlapping(sentences);
  }

  static List<TranscriptSentence> _parsePlain(String raw, int durationSeconds) {
    final stripped = _stripBom(raw);
    final normalized = stripped.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final segments = _splitJapanese(normalized);

    if (segments.isEmpty) return [];

    final totalChars = segments.fold<int>(0, (sum, s) => sum + s.length);

    if (totalChars == 0) return [];

    final sentences = <TranscriptSentence>[];
    var current = 0;
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (segment.isEmpty) continue;

      final segmentDuration = (durationSeconds * segment.length / totalChars)
          .round();
      final end = (current + segmentDuration).clamp(0, durationSeconds);
      sentences.add(
        TranscriptSentence(
          index: sentences.length,
          text: segment,
          startSeconds: current,
          endSeconds: end,
        ),
      );
      current = end;
    }

    if (sentences.isEmpty) return [];

    return _normalizeOverlapping(sentences);
  }

  static List<String> _splitJapanese(String text) {
    final pattern = RegExp(r'[。！？\n]+');
    final matches = pattern.allMatches(text);

    if (matches.isEmpty) {
      return [text.trim()];
    }

    final segments = <String>[];
    var lastEnd = 0;

    for (final match in matches) {
      final end = match.end;
      final segment = text.substring(lastEnd, end).trim();
      if (segment.isNotEmpty) {
        segments.add(segment);
      }
      lastEnd = end;
    }

    final remaining = text.substring(lastEnd).trim();
    if (remaining.isNotEmpty) {
      segments.add(remaining);
    }

    return segments;
  }

  static String _stripBom(String input) {
    if (input.isEmpty) return input;
    if (input.codeUnitAt(0) == 0xFEFF) {
      return input.substring(1);
    }
    return input;
  }

  static List<TranscriptSentence> _normalizeOverlapping(
    List<TranscriptSentence> sentences,
  ) {
    if (sentences.isEmpty) return sentences;

    final sorted = List<TranscriptSentence>.of(sentences)
      ..sort((a, b) => a.startSeconds.compareTo(b.startSeconds));

    final result = <TranscriptSentence>[];
    for (var i = 0; i < sorted.length; i++) {
      final current = sorted[i];
      var start = current.startSeconds;
      var end = current.endSeconds;

      if (i > 0) {
        final prevEnd = result[i - 1].endSeconds;
        if (start < prevEnd) {
          start = prevEnd;
        }
      }

      if (i < sorted.length - 1) {
        final nextStart = sorted[i + 1].startSeconds;
        if (end > nextStart) {
          end = nextStart;
        }
      }

      result.add(current.copyWith(startSeconds: start, endSeconds: end));
    }

    result.asMap().forEach((i, s) {
      result[i] = s.copyWith(index: i);
    });

    return result;
  }
}

enum TranscriptFormat { auto, srt, webvtt, plain }
