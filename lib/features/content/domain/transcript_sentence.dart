class TranscriptSentence {
  final int index;
  final String text;
  final int startSeconds;
  final int endSeconds;

  const TranscriptSentence({
    required this.index,
    required this.text,
    required this.startSeconds,
    required this.endSeconds,
  });

  TranscriptSentence copyWith({
    int? index,
    String? text,
    int? startSeconds,
    int? endSeconds,
  }) {
    return TranscriptSentence(
      index: index ?? this.index,
      text: text ?? this.text,
      startSeconds: startSeconds ?? this.startSeconds,
      endSeconds: endSeconds ?? this.endSeconds,
    );
  }
}
