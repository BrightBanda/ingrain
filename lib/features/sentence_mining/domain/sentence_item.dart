import 'package:ingrain/features/content/domain/content_item.dart';

class SentenceItem {
  final String id;
  final String uid;
  final String japanese;
  final String? translation;
  final String? explanation;
  final SourceType sourceType;
  final String sourceId;
  final String? sourceTitle;
  final int? timestampSeconds;
  final String? contextSentence;
  final String? sessionId;
  final DateTime createdAt;

  const SentenceItem({
    required this.id,
    required this.uid,
    required this.japanese,
    this.translation,
    this.explanation,
    required this.sourceType,
    required this.sourceId,
    this.sourceTitle,
    this.timestampSeconds,
    this.contextSentence,
    this.sessionId,
    required this.createdAt,
  });

  bool get hasTranslation =>
      translation != null && translation!.trim().isNotEmpty;

  SentenceItem copyWith({
    String? id,
    String? uid,
    String? japanese,
    String? Function()? translation,
    String? Function()? explanation,
    SourceType? sourceType,
    String? sourceId,
    String? Function()? sourceTitle,
    int? Function()? timestampSeconds,
    String? Function()? contextSentence,
    String? Function()? sessionId,
    DateTime? createdAt,
  }) {
    return SentenceItem(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      japanese: japanese ?? this.japanese,
      translation: translation != null ? translation() : this.translation,
      explanation: explanation != null ? explanation() : this.explanation,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      sourceTitle: sourceTitle != null ? sourceTitle() : this.sourceTitle,
      timestampSeconds: timestampSeconds != null
          ? timestampSeconds()
          : this.timestampSeconds,
      contextSentence: contextSentence != null
          ? contextSentence()
          : this.contextSentence,
      sessionId: sessionId != null ? sessionId() : this.sessionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
