import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:ingrain/features/srs/data/anki/anki_template.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:libcompress/libcompress.dart';
import 'package:sqlite3/sqlite3.dart';

/// One Anki deck, ready to save: its cards already rendered to text and
/// carrying their Anki scheduling state.
class AnkiDeckPlan {
  final int ankiId;

  /// Anki's `Parent::Child` shown as `Parent › Child`.
  final String name;
  final List<ReviewCard> cards;

  const AnkiDeckPlan({
    required this.ankiId,
    required this.name,
    required this.cards,
  });
}

class AnkiImportPlan {
  final List<AnkiDeckPlan> decks;

  /// Cards left out because nothing readable was left on their front (an
  /// image-only card, say).
  final int skipped;

  const AnkiImportPlan({required this.decks, this.skipped = 0});

  int get cardCount => decks.fold(0, (sum, deck) => sum + deck.cards.length);
}

class AnkiFormatException implements Exception {
  final String message;

  const AnkiFormatException(this.message);

  @override
  String toString() => message;
}

/// Reads an Anki `.apkg` and converts it into decks of [ReviewCard]s.
///
/// Handles both package formats: the legacy one (`collection.anki2` or
/// `.anki21`, plain SQLite with note types as JSON in `col`) and the current
/// one (`collection.anki21b`, zstd-compressed SQLite with note types in their
/// own tables and templates as protobuf). Media is not imported.
///
/// Synchronous and self-contained so it can run in a background isolate.
abstract final class ApkgReader {
  /// Card ids are derived from Anki's, so importing the same deck again
  /// updates those cards instead of duplicating them.
  static String cardId(int ankiCardId) => 'anki-$ankiCardId';
  static String deckId(int ankiDeckId) => 'anki-$ankiDeckId';

  static AnkiImportPlan readFile(
    String apkgPath, {
    required String tempDirectory,
    required int learningStepCount,
  }) {
    final input = InputFileStream(apkgPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      final dbBytes = _collectionBytes(archive);
      final dbFile = File(
        '$tempDirectory/anki-import-${DateTime.now().microsecondsSinceEpoch}.db',
      )..writeAsBytesSync(dbBytes, flush: true);
      try {
        return readCollection(
          dbFile.path,
          learningStepCount: learningStepCount,
        );
      } finally {
        if (dbFile.existsSync()) dbFile.deleteSync();
      }
    } on ArchiveException {
      throw const AnkiFormatException('This is not an Anki .apkg file.');
    } finally {
      input.closeSync();
    }
  }

  /// Prefers the newest collection in the package. Modern exports also hold a
  /// tiny legacy `collection.anki2` that only says "please update Anki".
  static Uint8List _collectionBytes(Archive archive) {
    ArchiveFile? find(String name) => archive.findFile(name);

    final modern = find('collection.anki21b');
    if (modern != null) {
      return decompressZstd(modern.content);
    }
    final legacy = find('collection.anki21') ?? find('collection.anki2');
    if (legacy != null) return legacy.content;
    throw const AnkiFormatException(
      'No Anki collection found in this file. Export from Anki as '
      '"Anki Deck Package (.apkg)".',
    );
  }

  /// Anki 2.1.50+ compresses the collection with zstd. Collections can be
  /// large, so the default 256 MB safety cap is raised to 1 GB.
  static Uint8List decompressZstd(Uint8List data) =>
      ZstdCodec(maxDecompressedSize: 1 << 30).decompress(data);

  /// Reads an unpacked collection database.
  static AnkiImportPlan readCollection(
    String dbPath, {
    required int learningStepCount,
  }) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final modern = db
          .select(
            "select 1 from sqlite_master where type = 'table' "
            "and name = 'notetypes'",
          )
          .isNotEmpty;
      final crt = (db.select('select crt from col').first['crt'] as int?) ?? 0;
      final noteTypes = modern ? _modernNoteTypes(db) : _legacyNoteTypes(db);
      final deckNames = modern ? _modernDecks(db) : _legacyDecks(db);

      final notes = <int, _Note>{
        for (final row in db.select('select id, mid, flds from notes'))
          row['id'] as int: _Note(
            id: row['id'] as int,
            noteTypeId: row['mid'] as int,
            fields: (row['flds'] as String).split('\x1f'),
          ),
      };

      final byDeck = <int, List<ReviewCard>>{};
      var skipped = 0;
      final rows = db.select(
        'select id, nid, did, odid, ord, type, queue, due, ivl, factor, '
        'reps, lapses, left from cards order by did, due, id',
      );
      for (final row in rows) {
        final note = notes[row['nid'] as int];
        final noteType = note == null ? null : noteTypes[note.noteTypeId];
        if (note == null || noteType == null) {
          skipped++;
          continue;
        }
        final ord = row['ord'] as int;
        final (front, back) = noteType.render(note, ord);
        if (front.isEmpty) {
          skipped++;
          continue;
        }
        // A card in a filtered deck really belongs to its original deck.
        final originalDeck = row['odid'] as int? ?? 0;
        final deck = originalDeck != 0 ? originalDeck : row['did'] as int;
        byDeck
            .putIfAbsent(deck, () => [])
            .add(
              _card(
                row,
                front: front,
                back: back,
                deckId: deckId(deck),
                noteId: note.id,
                crtSeconds: crt,
                learningStepCount: learningStepCount,
              ),
            );
      }

      return AnkiImportPlan(
        decks: [
          for (final MapEntry(key: id, value: cards) in byDeck.entries)
            AnkiDeckPlan(
              ankiId: id,
              name: deckNames[id] ?? 'Imported deck',
              cards: cards,
            ),
        ]..sort((a, b) => a.name.compareTo(b.name)),
        skipped: skipped,
      );
    } finally {
      db.close();
    }
  }

  /// Maps Anki's scheduling columns onto a [ReviewCard].
  static ReviewCard _card(
    Row row, {
    required String front,
    required String back,
    required String deckId,
    required int noteId,
    required int crtSeconds,
    required int learningStepCount,
  }) {
    final type = row['type'] as int;
    final queue = row['queue'] as int;
    final due = row['due'] as int;
    final factor = row['factor'] as int? ?? 0;
    final id = cardId(row['id'] as int);
    final createdAt = DateTime.fromMillisecondsSinceEpoch(noteId);

    // Review and day-learning cards are due on a day counted from the
    // collection's creation; intraday learning cards on a unix timestamp.
    DateTime dueOnDay(int day) =>
        DateTime.fromMillisecondsSinceEpoch((crtSeconds + day * 86400) * 1000);
    DateTime dueAtSecond(int seconds) =>
        DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

    final (CardState state, DateTime dueAt) = switch (type) {
      2 => (CardState.review, dueOnDay(due)),
      1 => (CardState.learning, queue == 3 ? dueOnDay(due) : dueAtSecond(due)),
      3 => (
        CardState.relearning,
        queue == 3 ? dueOnDay(due) : dueAtSecond(due),
      ),
      // New: `due` is the position in the new queue. Keep that order by
      // spacing creation times one second apart from Anki's collection start.
      _ => (CardState.newCard, dueAtSecond(crtSeconds + due)),
    };

    // `left` holds the learning steps still to go in its last three digits.
    final remaining = (row['left'] as int? ?? 0) % 1000;
    final step = state.isLearning && learningStepCount > 0
        ? (learningStepCount - remaining).clamp(0, learningStepCount - 1)
        : 0;

    return ReviewCard(
      id: id,
      uid: '',
      deckId: deckId,
      cardType: CardType.basic,
      sourceItemId: id,
      promptText: front,
      answerText: back.isEmpty ? null : back,
      createdAt: state == CardState.newCard ? dueAt : createdAt,
      dueAt: state == CardState.newCard ? DateTime.now() : dueAt,
      intervalDays: state == CardState.newCard
          ? 0
          : (row['ivl'] as int? ?? 0).clamp(0, 36500),
      easeFactor: factor > 0 ? factor / 1000 : 2.5,
      reviewCount: row['reps'] as int? ?? 0,
      repetitions: row['reps'] as int? ?? 0,
      lapses: row['lapses'] as int? ?? 0,
      state: state,
      step: step,
      // -1 is suspended; buried cards (-2, -3) simply come back as normal.
      suspended: queue == -1,
    );
  }

  static Map<int, String> _legacyDecks(Database db) {
    final json = db.select('select decks from col').first['decks'] as String;
    final decks = jsonDecode(json) as Map<String, dynamic>;
    return {
      for (final MapEntry(:key, :value) in decks.entries)
        int.parse(key): _deckName((value as Map)['name'] as String, '::'),
    };
  }

  static Map<int, String> _modernDecks(Database db) => {
    for (final row in db.select('select id, name from decks'))
      row['id'] as int: _deckName(row['name'] as String, '\x1f'),
  };

  static String _deckName(String raw, String separator) =>
      raw.split(separator).join(' › ');

  static Map<int, _NoteType> _legacyNoteTypes(Database db) {
    final json = db.select('select models from col').first['models'] as String;
    final models = jsonDecode(json) as Map<String, dynamic>;
    return {
      for (final MapEntry(:key, :value) in models.entries)
        int.parse(key): _NoteType.fromLegacy(value as Map<String, dynamic>),
    };
  }

  static Map<int, _NoteType> _modernNoteTypes(Database db) {
    final fields = <int, List<String>>{};
    for (final row in db.select(
      'select ntid, name from fields order by ntid, ord',
    )) {
      fields
          .putIfAbsent(row['ntid'] as int, () => [])
          .add(row['name'] as String);
    }
    final templates = <int, List<(String, String)>>{};
    for (final row in db.select(
      'select ntid, config from templates order by ntid, ord',
    )) {
      final config = _protoStrings(row['config'] as Uint8List);
      templates.putIfAbsent(row['ntid'] as int, () => []).add((
        config[1] ?? '',
        config[2] ?? '',
      ));
    }
    return {
      for (final row in db.select('select id, config from notetypes'))
        row['id'] as int: _NoteType(
          isCloze: _protoVarint(row['config'] as Uint8List, 1) == 1,
          fieldNames: fields[row['id'] as int] ?? const [],
          templates: templates[row['id'] as int] ?? const [],
        ),
    };
  }

  /// The string fields of a protobuf message, by field number. Anki stores a
  /// template's question format as field 1 and answer format as field 2.
  static Map<int, String> _protoStrings(Uint8List bytes) {
    final result = <int, String>{};
    _walkProto(bytes, (field, wireType, value) {
      if (wireType == 2 && value is Uint8List) {
        result[field] = utf8.decode(value, allowMalformed: true);
      }
    });
    return result;
  }

  static int? _protoVarint(Uint8List bytes, int fieldNumber) {
    int? result;
    _walkProto(bytes, (field, wireType, value) {
      if (field == fieldNumber && wireType == 0) result = value as int;
    });
    return result;
  }

  static void _walkProto(
    Uint8List bytes,
    void Function(int field, int wireType, Object value) visit,
  ) {
    var pos = 0;
    int varint() {
      var result = 0;
      var shift = 0;
      while (pos < bytes.length) {
        final byte = bytes[pos++];
        result |= (byte & 0x7f) << shift;
        if (byte & 0x80 == 0) break;
        shift += 7;
      }
      return result;
    }

    while (pos < bytes.length) {
      final key = varint();
      final field = key >> 3;
      final wireType = key & 7;
      switch (wireType) {
        case 0:
          visit(field, wireType, varint());
        case 1:
          pos += 8;
        case 2:
          final length = varint();
          final end = (pos + length).clamp(0, bytes.length);
          visit(field, wireType, Uint8List.sublistView(bytes, pos, end));
          pos = end;
        case 5:
          pos += 4;
        default:
          return; // Unknown wire type: stop rather than misread.
      }
    }
  }
}

class _Note {
  final int id;
  final int noteTypeId;
  final List<String> fields;

  const _Note({
    required this.id,
    required this.noteTypeId,
    required this.fields,
  });
}

class _NoteType {
  final bool isCloze;
  final List<String> fieldNames;

  /// (question format, answer format) per card template, by ord.
  final List<(String, String)> templates;

  const _NoteType({
    required this.isCloze,
    required this.fieldNames,
    required this.templates,
  });

  factory _NoteType.fromLegacy(Map<String, dynamic> json) {
    List<Map<String, dynamic>> sorted(Object? list) => [
      for (final item in list as List? ?? const [])
        item as Map<String, dynamic>,
    ]..sort((a, b) => (a['ord'] as int).compareTo(b['ord'] as int));
    return _NoteType(
      isCloze: json['type'] == 1,
      fieldNames: [
        for (final field in sorted(json['flds'])) field['name'] as String,
      ],
      templates: [
        for (final template in sorted(json['tmpls']))
          (
            template['qfmt'] as String? ?? '',
            template['afmt'] as String? ?? '',
          ),
      ],
    );
  }

  /// (front, back) of [note]'s card [ord]. Without a usable template, the
  /// first field is the front and the rest the back.
  (String, String) render(_Note note, int ord) {
    final values = {
      for (var i = 0; i < fieldNames.length && i < note.fields.length; i++)
        fieldNames[i]: note.fields[i],
    };
    // Cloze cards all share template 0; ord picks which deletion they ask.
    final template = isCloze
        ? templates.firstOrNull
        : (ord < templates.length ? templates[ord] : templates.firstOrNull);
    if (template == null) {
      final texts = note.fields.map(AnkiTemplate.htmlToText).toList();
      return (texts.firstOrNull ?? '', texts.skip(1).join('\n'));
    }
    final clozeNumber = ord + 1;
    final front = AnkiTemplate.render(
      template.$1,
      values,
      question: true,
      clozeNumber: clozeNumber,
    );
    final back = AnkiTemplate.render(
      template.$2,
      values,
      question: false,
      clozeNumber: clozeNumber,
    );
    return (front, back);
  }
}
