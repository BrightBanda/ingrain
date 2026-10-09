import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/content/data/youtube_transcript_fetcher.dart';
import 'package:ingrain/features/content/domain/video_search.dart';
import 'package:ingrain/features/content/presentation/viewmodel/content_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_overrides.dart';

class FakeFetcher extends YoutubeTranscriptFetcher {
  String? transcript = '00:00:01,000 --> 00:00:03,000\nこんにちは';
  int durationSeconds = 95;
  int calls = 0;

  @override
  Future<YoutubeTranscriptResult> fetch(String videoId) async {
    calls++;
    return YoutubeTranscriptResult(
      title: 'Fetched title',
      channelTitle: 'Fetched channel',
      durationSeconds: durationSeconds,
      transcriptText: transcript,
    );
  }
}

const video = VideoSearchResult(
  videoId: 'abcDEF12345',
  title: '日本語 vlog',
  channelTitle: 'Yuka',
  thumbnailUrl: 'https://i.ytimg.com/vi/abcDEF12345/mqdefault.jpg',
  duration: Duration(seconds: 90),
);

void main() {
  late ProviderContainer container;
  late FakeFetcher fetcher;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fetcher = FakeFetcher();
    container = ProviderContainer(
      overrides: [
        ...appTestOverrides(prefs),
        youtubeTranscriptFetcherProvider.overrideWithValue(fetcher),
      ],
    );
    addTearDown(container.dispose);
    await container.read(contentViewModelProvider.future);
  });

  ContentViewModel viewModel() =>
      container.read(contentViewModelProvider.notifier);

  test('adds the video with its details and Japanese transcript', () async {
    final result = await viewModel().importYoutubeVideo(video);

    expect(result.hasTranscript, isTrue);
    expect(result.wasInLibrary, isFalse);
    final item = await container.read(
      contentItemProvider(video.videoId).future,
    );
    expect(item.title, '日本語 vlog');
    expect(item.channelTitle, 'Yuka');
    expect(item.durationSeconds, 95, reason: 'the fetched length wins');
    final transcript = await container.read(
      transcriptProvider(video.videoId).future,
    );
    expect(transcript.single.text, 'こんにちは');
  });

  test(
    'a fetcher that cannot tell the length keeps the searched one',
    () async {
      // The web fetcher (through the API) reports 0 for the length.
      fetcher.durationSeconds = 0;

      await viewModel().importYoutubeVideo(video);

      final item = await container.read(
        contentItemProvider(video.videoId).future,
      );
      expect(item.durationSeconds, 90);
    },
  );

  test('a second add returns the saved video without fetching again', () async {
    await viewModel().importYoutubeVideo(video);
    final again = await viewModel().importYoutubeVideo(video);

    expect(again.wasInLibrary, isTrue);
    expect(again.hasTranscript, isTrue);
    expect(fetcher.calls, 1);
    expect(container.read(contentViewModelProvider).value, hasLength(1));
  });

  test('a video without Japanese captions is still added', () async {
    fetcher.transcript = null;

    final result = await viewModel().importYoutubeVideo(video);

    expect(result.hasTranscript, isFalse);
    expect(container.read(contentViewModelProvider).value, hasLength(1));
  });

  group('videoIdFromInput', () {
    test('links and ids are videos', () {
      expect(videoIdFromInput('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(
        videoIdFromInput('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(videoIdFromInput(' dQw4w9WgXcQ '), 'dQw4w9WgXcQ');
    });

    test('everything else is a search', () {
      expect(videoIdFromInput('programming'), isNull);
      expect(videoIdFromInput('Programming'), isNull);
      expect(videoIdFromInput('日本語 vlog'), isNull);
      expect(videoIdFromInput('easy japanese'), isNull);
    });
  });
}
