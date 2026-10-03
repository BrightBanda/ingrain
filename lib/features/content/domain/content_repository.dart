import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/content/domain/transcript_sentence.dart';

abstract interface class ContentRepository {
  Future<ContentItem> getContent(String id);

  Stream<List<ContentItem>> watchAll();

  Future<void> save(ContentItem item);

  Future<ContentItem> create({
    required String sourceUrl,
    required String title,
    String? channelTitle,
    String? thumbnailUrl,
    SourceType sourceType = SourceType.youtube,
  });

  Future<void> updateLastPosition(String id, int seconds);

  Future<void> delete(String id);

  Future<List<TranscriptSentence>> getTranscript(String contentId);

  Future<void> saveTranscript(
    String contentId,
    List<TranscriptSentence> sentences,
  );
}
