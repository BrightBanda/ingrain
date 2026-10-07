import 'dart:isolate';

import 'package:ingrain/features/auth/domain/auth_repository.dart';
import 'package:ingrain/features/srs/data/anki/apkg_reader.dart';
import 'package:ingrain/features/srs/data/deck_repository.dart';
import 'package:ingrain/features/srs/domain/review_repository.dart';

enum AnkiImportPhase { reading, saving, done }

class AnkiImportProgress {
  final AnkiImportPhase phase;
  final int saved;
  final int total;

  const AnkiImportProgress(this.phase, {this.saved = 0, this.total = 0});

  /// 0..1 while saving; null while reading (no total known yet).
  double? get fraction =>
      phase == AnkiImportPhase.reading || total == 0 ? null : saved / total;
}

class AnkiImportResult {
  final int decks;
  final int cards;
  final int skipped;

  const AnkiImportResult({
    required this.decks,
    required this.cards,
    required this.skipped,
  });
}

/// Imports an Anki `.apkg`: one app deck per Anki deck, each card keeping its
/// Anki progress (interval, ease, due date, lapses, suspension).
///
/// Ids come from Anki's, so importing the same package again updates the
/// decks and cards instead of duplicating them.
class AnkiImporter {
  final DeckRepository _decks;
  final ReviewRepository _cards;
  final AuthRepository _auth;

  AnkiImporter(this._decks, this._cards, this._auth);

  /// Unpacks [apkgPath] off the UI thread, then reports what it would add.
  Future<AnkiImportPlan> read(
    String apkgPath, {
    required String tempDirectory,
    required int learningStepCount,
  }) {
    return Isolate.run(
      () => ApkgReader.readFile(
        apkgPath,
        tempDirectory: tempDirectory,
        learningStepCount: learningStepCount,
      ),
    );
  }

  Future<AnkiImportResult> save(
    AnkiImportPlan plan, {
    void Function(AnkiImportProgress progress)? onProgress,
  }) async {
    final uid = await _auth.ensureUid();
    final total = plan.cardCount;
    var saved = 0;
    onProgress?.call(AnkiImportProgress(AnkiImportPhase.saving, total: total));

    for (final deck in plan.decks) {
      await _decks.createDeck(
        deck.name,
        description: 'Imported from Anki',
        id: ApkgReader.deckId(deck.ankiId),
      );
      final before = saved;
      await _cards.saveCards(
        [for (final card in deck.cards) card.copyWith(uid: uid)],
        onProgress: (count) {
          saved = before + count;
          onProgress?.call(
            AnkiImportProgress(
              AnkiImportPhase.saving,
              saved: saved,
              total: total,
            ),
          );
        },
      );
      saved = before + deck.cards.length;
    }

    onProgress?.call(
      AnkiImportProgress(AnkiImportPhase.done, saved: total, total: total),
    );
    return AnkiImportResult(
      decks: plan.decks.length,
      cards: total,
      skipped: plan.skipped,
    );
  }
}
