import 'package:ingrain/features/kana/domain/kana_chart.dart';

/// How well the learner says they know a kana. Self-assessed and set by hand.
///
/// "Not set" is the absence of a value, not a member: a kana the learner never
/// marked has no entry at all.
enum KanaKnowledge {
  somewhat('somewhat', 'Somewhat know', 'I somewhat know this character.'),
  known('known', 'Fully know', 'I fully know this character.');

  const KanaKnowledge(this.code, this.label, this.description);

  final String code;
  final String label;
  final String description;

  static KanaKnowledge? fromCode(Object? code) =>
      values.where((knowledge) => knowledge.code == code).firstOrNull;
}

/// Persists the learner's kana marks, keyed by the kana itself (`あ`, `ア`, `きゃ`).
/// Hiragana and katakana are separate characters and are marked separately.
abstract interface class KanaProgressRepository {
  Future<Map<String, KanaKnowledge>> load();

  /// Sets [kana] to [knowledge], or clears it when [knowledge] is null.
  Future<void> set(String kana, KanaKnowledge? knowledge);
}

/// How many kana in [sections] are known and somewhat known, out of the total.
typedef KanaTally = ({int known, int somewhat, int total});

KanaTally tallyKana(
  Iterable<KanaSection> sections,
  Map<String, KanaKnowledge> marks,
) {
  var known = 0, somewhat = 0, total = 0;
  for (final section in sections) {
    for (final kana in section.rows.expand((row) => row).whereType<Kana>()) {
      total++;
      switch (marks[kana.kana]) {
        case KanaKnowledge.known:
          known++;
        case KanaKnowledge.somewhat:
          somewhat++;
        case null:
      }
    }
  }
  return (known: known, somewhat: somewhat, total: total);
}
