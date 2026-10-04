# Phase: Vocabulary Loop — Word Saving, Tap-to-Look-Up & Vocabulary States

## Goal
Complete the product spec's MVP loop step *encounter unknown language → look it up → understand it → save it* (spec §12). Tap any word in the player transcript to see reading, meaning, part of speech and examples from a bundled offline dictionary, save it with full immersion memory (source, title, timestamp, context, session), track its learning state, and review it as a vocabulary SRS card.

Covers MVP #6 (vocabulary saving), #4 (tap-to-look-up), #13 (vocabulary states). Runs parallel to the existing `/sentences` feature and reuses its SRS + storage patterns.

## Decisions Made (user-confirmed)
- **Scope**: vocabulary saving (#6) + tap-to-look-up (#4) + vocabulary states (#13) + vocabulary SRS cards. Deferred: AI explanations (#5, needs backend + secrets), Anki import/export (#9), learning-history search (#14), pitch accent/kanji detail (roadmap).
- **Dictionary**: offline bundled asset only. `assets/data/dictionary.json` is already declared in `pubspec.yaml` and already credited in Settings, but ships a single placeholder entry. No runtime dictionary API, no API keys, no new packages.
- **Segmentation**: pure-Dart longest-match tokenizer driven by the dictionary surfaces, plus script-run detection for non-dictionary text. No morphological analyser dependency.
- **Storage**: same local-first `LocalDocumentStore` JSON collection model, new collection `'vocabulary'`.
- **Word taps**: `SelectableText.rich` with per-word `TapGestureRecognizer`s created and disposed by a stateful widget. Sentence-level seek tap is preserved (tap on the timestamp gutter / container background).

## Data pipeline (new)

### `tool/build_dictionary.py`
Reproducible generator for the curated dictionary asset. Committed so the asset is regenerable, not hand-typed.

1. Fetch the OpenSubtitles JA frequency list (surface forms, descending frequency) and `JMdict_e.gz` from EDRDG.
2. Intersect the top-frequency surface forms with JMdict entries.
3. Emit one entry per surface: `{surface, reading, pos, meanings[], examples[{japanese, english}]}`, capped at **3000** entries, ordered by frequency (deterministic; ties broken by surface).
4. Keep the existing `meta` block (license, source, attribution) and update `entryCount`.
5. Graceful failure: if either download fails, the script exits non-zero and the existing asset is left untouched.

Asset JSON schema (loader stays tolerant of the current singular `meaning` string):

```json
{ "meta": { "license": "CC BY-SA 4.0", "source": "JMdict/EDICT",
            "attribution": "...", "entryCount": 3000,
            "description": "Curated Japanese dictionary subset for ingrain MVP" },
  "entries": [ { "surface": "猫", "reading": "ねこ", "pos": "noun",
                 "meanings": ["cat (animal)"],
                 "examples": [{ "japanese": "猫が好きです。", "english": "I like cats." }] } ] }
```

## New files

### `lib/features/vocabulary/`
- `domain/vocabulary_item.dart` — `enum VocabState { unknown, encountered, learning, known, mastered }` (spec §4 #13 order, explicit user control) and `VocabularyItem`:
  `id, uid, word, reading?, meaning?, pos?, examples?, sourceType (SourceType from content feature), sourceId, sourceTitle?, timestampSeconds?, contextSentence?, sessionId?, state, createdAt, updatedAt, encounterCount`
  Mirrors `SentenceItem` field-for-field so the Immersion Memory contract is identical.
- `domain/vocabulary_repository.dart` — contract:
  `save({...}) -> VocabularyItem`, `get(id)`, `update(VocabularyItem)`, `delete(id)`, `watchAll()`, `findByWord(String word)`, `count()`, `countByState(VocabState)`, `recordEncounter(String id, {DateTime? encounteredAt})`
- `domain/japanese_tokenizer.dart` — pure `JapaneseTokenizer.tokenize(String text)`:
  - longest dictionary match first (multi-kanji compounds like 日本語 before 日本),
  - kana runs (hiragana/katakana, incl. ー) and latin/digit runs grouped,
  - punctuation and whitespace preserved as their own tokens,
  - unknown kanji runs fall back to single characters so every tap target is tappable.
  Returns `List<String>`.
- `data/vocabulary_item_dto.dart` — map ↔ domain (ISO8601 `createdAt`/`updatedAt`, `state.name`, `pos` nullable).
- `data/local_vocabulary_repository.dart` — `LocalDocumentStore` collection `'vocabulary'`, docId = word item id (`generateVocabularyId()` mirroring `LocalSentenceRepository.generateSentenceId()`). `findByWord` matches on the exact `word` field.
- `data/asset_dictionary.dart` — `DictionaryIndex` (built from a decoded map, unit-testable without the bundle) + `AssetDictionaryLoader.load()` reading `assets/data/dictionary.json` via `rootBundle`. Indexes by surface **and** by reading.
- `presentation/viewmodel/vocabulary_view_model.dart` — `vocabularyRepositoryProvider`, `dictionaryProvider` (`FutureProvider<DictionaryIndex>`), `vocabularyViewModelProvider` (`AsyncNotifier<List<VocabularyItem>>`, same shape as `SentenceMiningViewModel`) with:
  `saveWord({...})`, `saveFromTranscript({...})`, `setState(String id, VocabState state)`, `deleteWord(String id)`, `refresh()`.
  Saving creates a `CardType.vocabulary` review card (prompt = word, answer = `reading + meaning`, falling back to `contextSentence`) and invalidates `dueCountProvider`. Saving a word that already exists **records an encounter** on the existing item (bumps `encounterCount`, refreshes source context) instead of creating a duplicate document.
- `presentation/view/vocabulary_view.dart` — `/vocabulary`: word + reading headline, meaning, `VocabState` chip with a state stepper, source title + timestamp, encounter count; tap → detail sheet; delete; state filter chips (All / each state); FAB → manual add.
- `presentation/view/vocabulary_lookup_sheet.dart` — the tap-to-look-up surface (#4): dictionary reading, POS, meanings, examples, context line, "Save word" and "Jump to timestamp" actions; `Not in dictionary` fallback with manual entry.
- `presentation/view/vocabulary_save_sheet.dart` — pre-filled save form (word/read-only unless manual, reading, meaning, POS) popping a `VocabularySaveRequest`.
- `presentation/widgets/tappable_transcript_text.dart` — stateful widget owning the per-word `TapGestureRecognizer` list, guaranteeing disposal on rebuild/dispose.

## Modified files
1. `lib/features/content/presentation/view/player/transcript_view.dart` — replace the plain `Text` for the sentence body with `TappableTranscriptText`; tapping a word opens the lookup sheet with the sentence's immersion memory pre-attached. Row-level seek tap and the existing mine-sentence button stay unchanged.
2. `lib/app/router.dart` — `GoRoute(path: '/vocabulary', ...)` outside `ShellRoute` (same pattern as `/sentences`).
3. `lib/features/content/presentation/view/content_history_view.dart` — Library app-bar action linking to `/vocabulary` next to the existing mined-sentences action.
4. `lib/features/progress/domain/progress_summary.dart` — add `totalWords` and `wordsLearningOrBetter` (state ≥ `learning`); `isEmpty` accounts for words.
5. `lib/features/progress/domain/progress_calculator.dart` — `summarize(...)` gains `required List<VocabularyItem> vocabulary`; counts only.
6. `lib/features/progress/presentation/viewmodel/progress_view_model.dart` — inject `vocabularyRepositoryProvider`.
7. `lib/features/progress/presentation/view/progress_tab_view.dart` — "Words saved" tile + "Browse vocabulary" action in the Learning card.
8. `pubspec.yaml` — no new dependencies (asset already declared).

## Storage shapes (LocalDocumentStore)
- `vocabulary/{id}`: `{id, uid, word, reading?, meaning?, pos?, examples?, sourceType, sourceId, sourceTitle?, timestampSeconds?, contextSentence?, sessionId?, state, createdAt, updatedAt, encounterCount}`

## Implementation order
1. `tool/build_dictionary.py` + regenerate `assets/data/dictionary.json` (verify `entryCount`, attribution, and that the existing 猫 entry survives).
2. Domain: `VocabState`/`VocabularyItem`, repository contract, `JapaneseTokenizer` + unit tests (longest match, kana run, unknown-kanji fallback, punctuation, empty/whitespace).
3. `DictionaryIndex` + loader + tests (lookup by surface, by reading, unknown → null, tolerant of singular `meaning`).
4. DTO + `LocalVocabularyRepository` + repository tests (round trip, `findByWord`, `countByState`, encounter increment, unknown-id null).
5. `VocabularyViewModel` + ViewModel tests (save creates vocabulary card; re-save records encounter; `setState` persists and invalidates; delete removes the linked card).
6. UI: lookup sheet, save sheet, `/vocabulary` screen, `TappableTranscriptText` wired into `TranscriptView`.
7. Router + Library action + progress vocabulary counts.
8. `dart format` touched files, `flutter analyze`, `flutter test`.

## Edge cases / failure modes
- Word already saved: encounter is recorded on the existing item, never a second document; the SRS card is not duplicated either.
- Word absent from the bundled dictionary: the lookup sheet still opens, shows the context line, and lets the learner type the reading/meaning manually — the flow never dead-ends.
- Unknown kanji runs: single-character tap targets, so any kanji in any transcript is tappable even when unknown to the dictionary.
- Deleting a word deletes its vocabulary SRS card (`deleteCardsForSource`), matching the sentence behaviour.
- Setting state to `mastered` does **not** delete or suspend the card (deliberate MVP simplification — noted in code, scheduling controls are roadmap).
- Empty states everywhere: no words saved, no dictionary hit, no transcript, no dictionary asset (loader failure degrades to "dictionary unavailable" while saving still works).
- Dictionary asset failure must never block saving a word.

## Validation
- `flutter analyze` clean; `dart format` applied to touched files.
- `flutter test`: tokenizer tests, dictionary index tests, DTO tests, local repository tests, vocabulary ViewModel flow tests (in-memory fakes + `ManualClock`, mirroring `new_screens_widget_test.dart` conventions), plus new widget tests for `/vocabulary` and the transcript word tap.
- Manual loop: open a video with a transcript → tap a word → see reading/meaning/examples → save → Library → Vocabulary shows the word → Review tab has the vocabulary card due → rate it → Progress shows words saved.

## Out of scope (explicit)
AI explanations, Anki import/export, learning-history search, kanji breakdown, pitch accent, conjugation, JLPT/frequency badges, dictionary editing UI, cloud sync, tags.

---

# Implementation Notes (what actually shipped)

## Deviations from the plan above
1. **No `examples` field.** JMdict's main file carries no usage examples (they live in a separate `JMdict_e_examp` download), so the model and asset omit them. The lookup sheet shows the *real* immersion context instead — the transcript line the word was tapped in — which is more useful than a generic example and needs no extra data.
2. **8000 entries, not 3000.** JMdict's most common band (`ichi1`/`news1`) holds ~22k words, so a 3000-entry cap cut everyday words like 猫, 食べる, 見る. The asset is now 8000 entries / ~830 KB and still loads in milliseconds.
3. **Selection is interleaved 1:2, frequency : common vocabulary.** The OpenSubtitles frequency list tokenises everyday words out of existence (猫, 日本語, 食べる, 見る are all absent), so it cannot stand alone; nor can JMdict's news band, which misses colloquial material. Both sources are woven together.
4. **Sense selection uses JMdict's canonical order.** The first sense without a `misc` marker (archaic/slang/abbreviation) is the meaning, and an entry whose canonical sense is a prefix or suffix is downgraded — this is what makes 何 resolve to "what" and 人 to "person" instead of 人's rare "-ian" suffix reading.
5. **Halfwidth katakana headwords are widened** (`ｺｰﾋｰ` → `コーヒー`) so subtitle text matches.
6. **`VocabState` filter uses a `NotifierProvider`.** Riverpod 3 has no `StateProvider`, so the filter is a small `Notifier<VocabState?>` with a `select` method.
7. **The lookup sheet awaits the dictionary.** `ref.read(dictionaryProvider.future)` instead of `.value`, so a still-loading asset can never answer "not in the dictionary"; the already-saved check queries `vocabularyRepository.findByWord` directly rather than loading the whole list.
8. **`/.cache/` is gitignored** — it holds the JMdict download used by the generator.

## Extra files beyond the plan
- `tool/build_dictionary.py` — reproducible generator for the asset.
- `test/features/vocabulary/dictionary_asset_test.dart` — loads the **real** committed asset and asserts everyday words resolve, guarding the offline data pipeline end to end.
- `test/features/vocabulary/` — tokenizer, dictionary index, DTO, ViewModel and asset suites (36 tests).
- `LocalVocabularyRepository` group appended to the shared `test/features/local_repositories_test.dart`.

## Final state
- `flutter analyze`: no issues in any file this phase touched (3 pre-existing `use_null_aware_elements` infos remain in `content_item_dto.dart`, `local_immersion_repository.dart`, `session_state.dart`).
- `flutter test`: 228 tests, all passing.