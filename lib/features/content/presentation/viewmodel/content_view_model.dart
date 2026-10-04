import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/core/providers.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/content/data/local_content_repository.dart';
import 'package:ingrain/features/content/data/youtube_transcript_fetcher.dart';
import 'package:ingrain/features/content/data/youtube_url_parser.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/content/domain/content_repository.dart';
import 'package:ingrain/features/content/domain/transcript_sentence.dart';
import 'package:ingrain/features/content/data/transcript_parser.dart';

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  final store = ref.watch(localDocumentStoreProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return LocalContentRepository(store, authRepo);
});

final youtubeTranscriptFetcherProvider = Provider<YoutubeTranscriptFetcher>((ref) {
  return YoutubeTranscriptFetcher();
});

class ContentViewModel extends AsyncNotifier<List<ContentItem>> {
  late ContentRepository _repository;

  @override
  FutureOr<List<ContentItem>> build() async {
    _repository = ref.watch(contentRepositoryProvider);
    return _repository.watchAll().first;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _repository.watchAll().first);
  }

  Future<ContentItem?> addContent({
    required String sourceUrl,
    required String title,
  }) async {
    try {
      YoutubeUrlParser.parse(sourceUrl);
      final item = await _repository.create(sourceUrl: sourceUrl, title: title);
      await refresh();
      return item;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<ContentItem?> addContentWithTranscript({
    required String sourceUrl,
    required String title,
    required int durationSeconds,
    required String transcriptText,
  }) async {
    try {
      YoutubeUrlParser.parse(sourceUrl);
      final item = await _repository.create(
        sourceUrl: sourceUrl,
        title: title,
      );
      final updatedItem = item.copyWith(durationSeconds: durationSeconds);
      await _repository.save(updatedItem);

      final sentences = TranscriptParser.parse(
        transcriptText,
        durationSeconds: durationSeconds,
        format: TranscriptFormat.srt,
      );
      await _repository.saveTranscript(item.id, sentences);

      await refresh();
      return updatedItem;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<void> deleteContent(String id) async {
    await _repository.delete(id);
    await refresh();
  }

  Future<void> saveTranscript(
    String contentId,
    List<TranscriptSentence> sentences,
  ) async {
    await _repository.saveTranscript(contentId, sentences);
  }

  Future<List<TranscriptSentence>> getTranscript(String contentId) {
    return _repository.getTranscript(contentId);
  }
}

final contentViewModelProvider =
    AsyncNotifierProvider<ContentViewModel, List<ContentItem>>(
      ContentViewModel.new,
    );

final contentItemProvider =
    FutureProvider.family<ContentItem, String>((ref, id) {
  return ref.watch(contentRepositoryProvider).getContent(id);
});

final transcriptProvider = FutureProvider.family<
    List<TranscriptSentence>, String>((ref, contentId) {
  return ref.watch(contentRepositoryProvider).getTranscript(contentId);
});
