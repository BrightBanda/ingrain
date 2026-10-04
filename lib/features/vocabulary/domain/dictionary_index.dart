/// One dictionary headword, parsed from the bundled JMdict subset.
class DictionaryEntry {
  final String surface;
  final String reading;
  final String? pos;
  final List<String> meanings;

  const DictionaryEntry({
    required this.surface,
    required this.reading,
    required this.meanings,
    this.pos,
  });

  /// `cat (animal)` style single-line summary for review cards and lists.
  String get primaryMeaning => meanings.isEmpty ? '' : meanings.first;

  String get meaningLine => meanings.join('; ');

  /// `猫 (ねこ)` when the reading adds information.
  String get headword =>
      reading.isEmpty || reading == surface ? surface : '$surface ($reading)';
}

/// In-memory lookup over the bundled dictionary.
///
/// Words are indexed by their written form and by their reading, so a tap on
/// ねこ finds 猫. Construction takes the decoded JSON map rather than the asset
/// bundle, which keeps it unit-testable without a Flutter binding.
class DictionaryIndex {
  DictionaryIndex(List<DictionaryEntry> entries) {
    for (final entry in entries) {
      if (entry.surface.isEmpty) continue;
      _bySurface.putIfAbsent(entry.surface, () => entry);
      if (entry.reading.isNotEmpty) {
        _byReading.putIfAbsent(entry.reading, () => entry);
      }
    }
  }

  final Map<String, DictionaryEntry> _bySurface = {};
  final Map<String, DictionaryEntry> _byReading = {};

  /// Builds an index from `assets/data/dictionary.json`.
  ///
  /// Both the generated `meanings` list and the hand-written singular `meaning`
  /// string are accepted so an older asset still loads.
  factory DictionaryIndex.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    if (rawEntries is! List) return DictionaryIndex(const []);

    final entries = <DictionaryEntry>[];
    for (final raw in rawEntries) {
      if (raw is! Map) continue;
      final surface = (raw['surface'] as String?)?.trim();
      if (surface == null || surface.isEmpty) continue;

      final readings = raw['reading'];
      final reading = readings is String ? readings.trim() : '';

      final meanings = <String>[];
      final rawMeanings = raw['meanings'];
      if (rawMeanings is List) {
        for (final meaning in rawMeanings) {
          if (meaning is String && meaning.trim().isNotEmpty) {
            meanings.add(meaning.trim());
          }
        }
      }
      final singleMeaning = raw['meaning'];
      if (meanings.isEmpty &&
          singleMeaning is String &&
          singleMeaning.trim().isNotEmpty) {
        meanings.add(singleMeaning.trim());
      }
      if (meanings.isEmpty) continue;

      final pos = raw['pos'];
      entries.add(
        DictionaryEntry(
          surface: surface,
          reading: reading.isEmpty ? surface : reading,
          meanings: meanings,
          pos: pos is String && pos.trim().isNotEmpty ? pos.trim() : null,
        ),
      );
    }
    return DictionaryIndex(entries);
  }

  static final empty = DictionaryIndex(<DictionaryEntry>[]);

  int get length => _bySurface.length;

  /// Looks up a written form first, then a reading.
  DictionaryEntry? lookup(String word) {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return null;
    return _bySurface[trimmed] ?? _byReading[trimmed];
  }

  bool contains(String word) => lookup(word) != null;

  /// Every written form, for the tokenizer's longest-match lookups.
  Set<String> get surfaces => _bySurface.keys.toSet();
}
