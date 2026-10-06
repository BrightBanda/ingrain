import 'package:ingrain/core/error/app_error.dart';

enum ExplainKind { word, sentence }

/// What to explain. A record so it can key a provider family by value.
typedef ExplainRequest = ({String text, ExplainKind kind, String? context});

class GrammarPoint {
  final String point;
  final String explanation;

  const GrammarPoint({required this.point, required this.explanation});
}

class NaturalAlternative {
  final String japanese;
  final String note;

  const NaturalAlternative({required this.japanese, required this.note});
}

/// A Japanese-first explanation of a word or sentence in its context.
class AiExplanation {
  final String translation;
  final String? reading;
  final String meaning;
  final String? partOfSpeech;
  final List<GrammarPoint> grammar;
  final String nuance;
  final String formality;
  final List<NaturalAlternative> alternatives;

  const AiExplanation({
    required this.translation,
    required this.meaning,
    required this.nuance,
    required this.formality,
    this.reading,
    this.partOfSpeech,
    this.grammar = const [],
    this.alternatives = const [],
  });

  /// Plain-text notes for a mined sentence's "explanation" field.
  String toNotes() {
    final buffer = StringBuffer(meaning.trim());
    for (final point in grammar) {
      buffer.write('\n• ${point.point}: ${point.explanation}');
    }
    if (nuance.trim().isNotEmpty) buffer.write('\n${nuance.trim()}');
    return buffer.toString();
  }
}

abstract interface class AiExplanationRepository {
  /// Throws [AiExplanationException] on any failure.
  Future<AiExplanation> explain(ExplainRequest request);
}

/// A failure already translated into the app's error model, with a message
/// fit to show the learner.
class AiExplanationException implements Exception {
  final AppError error;

  const AiExplanationException(this.error);

  String get message => error.message ?? 'The AI could not answer, try again.';

  @override
  String toString() => message;
}
