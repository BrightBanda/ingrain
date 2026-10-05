# Dialogue Reader — text-only Japanese dialogues with optional romaji

## Goal

Add a new content type to ingrain: **simple dialogues** (Japanese text, no audio) served from a
FastAPI backend, with a per-token romaji toggle that renders readings beneath the words, full parity
with the existing transcript learning loop (tap-to-look-up → save vocabulary, mine sentence → SRS
card), and buttons that deep-link out to NHK where a matching source page exists.

## Decisions (settled during planning)

| Decision | Choice |
|---|---|
| Backend | FastAPI, plain JSON over HTTP, behind a repository interface |
| Romaji source | Backend sends **per-token** `{surface, reading, romaji}` |
| Romaji toggle | Inline action in reader app bar + a row in Settings → Appearance, persisted globally, default off |
| Feature scope | Full parity with `TranscriptView`: vocabulary lookup/save + sentence mining + SRS card |
| Navigation | Videos/Dialogues filter inside the existing Library tab (keeps 5 bottom-bar destinations) |
| Line layout | Speaker name row above the line; per-token two-row cells inside a `Wrap` |
| NHK button | Both: conditional per-dialogue "open on NHK" + a browse link in the list empty state |

### Verified facts that shaped this plan

- There is **no backend today**. No `http`/`dio` import in `lib/`; `LocalDocumentStore` is
  SharedPreferences-backed (`lib/core/storage/local_document_store.dart:5`); auth is a local uid via
  `ensureUid()`.
- **NHK has dialogue lessons but no Japanese-language story section.** Easy Japanese (48 episodes) is
  the dialogue material. Magical Japanese is English-narrated vocabulary commentary and cannot use the
  per-token romaji pipeline. Any *stories* must be authored in the backend.
  - Easy Japanese: `https://www3.nhk.or.jp/nhkworld/en/shows/easyjapanese`
  - MP3/PDF downloads: `https://www3.nhk.or.jp/nhkworld/lesson/en/segment/downloads`
- `url_launcher` is in `pubspec.lock` only as a **transitive** dep of `share_plus`; it must be added to
  `pubspec.yaml` directly to import it.
- `SentenceMiningViewModel.saveFromTranscript` **hardcodes** `sourceType: SourceType.youtube`
  (`lib/features/sentence_mining/presentation/viewmodel/sentence_mining_view_model.dart:100`).
- `LocalContentRepository.save()` silently drops `durationSeconds` (`local_content_repository.dart:42-51`)
  — a pre-existing bug. Not triggered by this feature (dialogues are not `ContentItem`s), but do not
  copy that pattern for the dialogue DTO.
- NHK's podcast feed (`https://www.nhk.or.jp/lesson/en/rss/podcast.xml`) was fetched and inspected.
  It carries title, `itunes:summary` (an English plot summary, **not** a transcript), `pubDate`,
  channel-level artwork, `itunes:duration`, and a direct `audio/mpeg` enclosure URL. It is 48 items,
  last published **2020-09-08**, `lastBuildDate` **2021-08-12**, `<language>en</language>`, with **no
  `<guid>`** per item and **no `podcast:transcript`**. Details and consequences in the follow-up
  phase section below.

### Note on approach

This plan contains **no NHK scraping and no audio download**. NHK appears only as (a) a `sourceUrl`
string the backend may attach to a dialogue and (b) two `url_launcher` deep-links out to their site.
A proposed alternative of fetching and re-hosting NHK audio was considered and rejected: re-hosting
third-party audio is redistribution, whereas linking to a publisher's own URL is not.

## API contract (backend must be built to this)

Base URL supplied at build time:
`String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000')`

### `GET /dialogues` → list of summaries

```json
{ "dialogues": [
  { "id": "nhk-easy-conversation-01",
    "title": "Lesson 1: Where is Haru-san's house?",
    "level": "N5",
    "kind": "dialogue",
    "speakers": ["タム", "ハル"],
    "lineCount": 12,
    "sourceUrl": "https://www3.nhk.or.jp/nhkworld/en/shows/easyjapanese",
    "attribution": "NHK WORLD-JAPAN",
    "updatedAt": "2026-10-01T00:00:00Z" }
]}
```

### `GET /dialogues/{id}` → full dialogue

```json
{ "id": "nhk-easy-conversation-01",
  "title": "Lesson 1: Where is Haru-san's house?",
  "level": "N5",
  "kind": "dialogue",
  "attribution": "NHK WORLD-JAPAN",
  "sourceUrl": "https://www3.nhk.or.jp/nhkworld/en/shows/easyjapanese",
  "lines": [
    { "index": 0,
      "speaker": "タム",
      "tokens": [ { "surface": "先生", "reading": "せんせい", "romaji": "sensei" },
                  { "surface": "は", "reading": "は", "romaji": "wa" } ] }
  ] }
```

### Contract rules the client relies on

1. Concatenating `tokens[].surface` in order must reproduce the full line text exactly. Mining and
   review-context building reconstruct the string this way.
2. `romaji`, `reading`, and `speaker` are **all optional**. Absent `romaji` → that cell renders
   Japanese only. Absent `speaker` → no name row (prose/story lines).
3. `sourceUrl` is optional and drives the conditional NHK button. Absent ⇒ button hidden.
4. No auth. Public read-only catalogue.
5. `updatedAt` drives cache invalidation for the summary index.

## Tasks

### 1. Dependencies and config
- `pubspec.yaml`: add `http` and `url_launcher` as **direct** dependencies.
- Add the `API_BASE_URL` constant via `String.fromEnvironment`.

### 2. Domain layer — `lib/features/dialogue/domain/`
- `dialogue.dart`: `Dialogue`, `DialogueSummary`, `DialogueLine`, `DialogueToken`,
  `DialogueKind { dialogue, story }`, `DialogueSource`. All tokens optional-safe per rule 2.
- `dialogue_repository.dart`: `abstract interface class DialogueRepository` with
  `listSummaries()`, `getDialogue(id)`, `getCachedDialogue(id)`, `cacheDialogue(d)`.
  Follow the existing `abstract interface class` + provider pattern
  (`content_repository.dart`, `settings_repository.dart`).

### 3. Data layer — `lib/features/dialogue/data/`
- `dialogue_dto.dart`: JSON ↔ domain. Mirror `content_item_dto.dart` conventions. **Persist every
  optional field it reads** so cache round-trips are lossless.
- `remote_dialogue_repository.dart`: `http.Client`-backed, injected via provider so tests can stub it.
  Cache-through: on success write to cache then return; on failure return cached and signal staleness.
- `local_dialogue_cache.dart`: wrap `LocalDocumentStore` — index under `dialogues/_index`,
  bodies under `dialogues/<id>`. Invalidate an entry when `updatedAt` changes.

### 4. Romaji setting
- `AppSettings`: add `bool showRomaji = false` + `copyWith` + persist key.
- `SettingsRepository` / `LocalSettingsRepository`: add `setShowRomaji`.
- `SettingsViewModel`: add `setShowRomaji`.
- `SettingsView`: add a `SwitchListTile` in the existing **Appearance** section, next to
  Subtitle font size.

### 5. Speaker + source types
- `SourceType`: add `dialogue` (keeps mined sentences distinguishable from YouTube content).
  `ContentItemDto.toDomain` already falls back via `orElse`, so this is additive.

### 6. Mining parity
- `SentenceMiningViewModel`: add `saveFromDialogue({dialogueId, dialogueTitle, line, lines})` calling
  the existing `saveSentence` with `sourceType: SourceType.dialogue`, `timestampSeconds: null`
  (already nullable on `SentenceItem`).
- Add a context helper for dialogue lines mirroring `contextForTranscript`
  (`sentence_mining_view_model.dart:130`) but over line texts. Prefer generalizing the existing helper
  over duplicating it.
- Note `saveSentence` already creates the SRS review card (`_createReviewCard`), so parity is automatic.

### 7. Presentation
- `widgets/dialogue_token_row.dart`: the core renderer. One `Wrap` of per-token cells; each cell is a
  `Column` with Japanese on top and romaji below (muted, `bodySmall`, hidden when the toggle is off).
  `Wrap` + per-token `Column` is required — two stacked text rows cannot stay aligned once the
  Japanese wraps. Each cell keeps a tap target that opens `VocabularyLookupSheet`.
- `widgets/speaker_label.dart`: name row with a stable per-speaker accent colour derived from the
  speaker name hash so colour is consistent across dialogues.
- `view/dialogue_reader_view.dart`: app bar with the romaji toggle and the conditional NHK action.
  Body is the token rows. **No playback**: do not read `playbackPositionProvider`, no highlight, no
  auto-scroll. Pass `null` where `TranscriptView` passes a null controller
  (see the `onJumpToTimestamp: controller == null ? null : ...` pattern at `transcript_view.dart:233`),
  so the lookup sheet renders without a jump-to-timestamp action.
- `view/library_dialogue_list_view.dart`: summary list + empty state containing **Browse NHK
  dialogues** → Easy Japanese URL.
- `view/library_content_filter.dart`: `SegmentedButton<Videos|Dialogues>` matching the
  `SegmentedButton<ThemeSetting>` pattern already in `SettingsView`.
- `viewmodel/dialogue_list_view_model.dart` and `dialogue_reader_view_model.dart`: mirror
  `SettingsViewModel`/`SettingsUiState` loading-data-error shape. Show a "showing cached copy"
  banner when the network path was used.

### 8. Routing and Library integration
- `router.dart`: add `/dialogues/:id` as a **pushed** top-level route alongside `/content/:id`.
  Use `context.push` at every call site so the back button works — consistent with the back-navigation
  work already landed.
- `content_history_view.dart`: add the filter above the list; keep the existing app-bar actions
  (vocabulary, mined sentences) applying to the Videos tab only, and hide them on Dialogues.

### 9. NHK deep links
- Reader: `Icons.open_in_new` app-bar action, rendered **only** when `dialogue.sourceUrl != null`,
  via `launchUrl(uri, mode: LaunchMode.externalApplication)`.
- List empty state: browse link to Easy Japanese.
- Handle `launchUrl` returning `false` with a SnackBar rather than a silent no-op.

## Failure modes to handle

| Case | Behaviour |
|---|---|
| Backend unreachable | Serve cached content + "showing cached copy" banner. Empty list shows Retry + Browse NHK |
| Malformed JSON | Typed parse error caught by the view model → existing `AsyncError` path |
| Token missing `romaji` | That cell renders Japanese only; no crash, no placeholder gap |
| `speaker` absent | No name row |
| `sourceUrl` absent | NHK button hidden |
| Surfaces do not concatenate to a clean line | Reader still renders; test asserts the invariant so the mismatch surfaces in CI rather than in shipped mining data |
| `launchUrl` unsupported | SnackBar, no crash |

## Validation

New tests, following the existing fakes-in-`new_screens_widget_test.dart` style
(`InMemory*Repository` + `overrideWithValue`):

1. `dialogue_dto_test.dart` — round-trip the full contract; and each optional field absent
   (`romaji`, `reading`, `speaker`, `sourceUrl`).
2. `remote_dialogue_repository_test.dart` — cache-through on success; fallback to cache on network
   failure; no real network (inject a fake `http.Client`).
3. `dialogue_reader_view_test.dart` — romaji **hidden** by default; toggling reveals per-token romaji;
   tapping a token opens the lookup sheet with the backend `reading`; the mine action produces a
   `SentenceItem` and a review card with `sourceType: SourceType.dialogue`.
4. `library_filter_test.dart` — the filter switches between the content list and the dialogue list.
5. `settings_test.dart` — `showRomaji` persists across a repository round-trip.

Gates:
- `flutter analyze` clean (3 pre-existing `use_null_aware_elements` infos are the current baseline).
- Full suite green **except** `test/features/theme_controller_test.dart`, which hangs
  indefinitely on a clean checkout of `main`. Pre-existing; exclude it explicitly rather than
  treating it as a regression.

## Follow-up phase: generic podcast ingestion (architecture only, NOT built in this plan)

Recorded because the design was agreed but is explicitly deferred. Nothing below is part of this
phase's implementation.

### Shape

Make podcast ingestion a **generic multi-source system**; NHK is one source, not the system. Store
metadata and the publisher's `audioUrl` — never copy or re-host the audio. Playback streams from the
source's own URL.

### Verified constraints on NHK specifically

- **No transcript exists in the feed.** The learning loop (listen → tap word → save sentence → SRS)
  needs one. For NHK it lives only in a separate PDF download with no timestamps, so highlight and
  auto-scroll would require offline forced alignment. **RSS metadata alone cannot drive the loop.**
- **Not an ongoing feed.** 48 static episodes ending 2020-09-08. Do not design for a steady stream of
  new content from this source.
- **Parser must synthesize a stable id** from `title` + `pubDate`; the feed omits `<guid>`, which is
  an RSS 2.0 violation and something podcast apps normally rely on.
- Artwork is channel-level only, so per-episode thumbnails must fall back or be derived.
- **Playing/streaming the publisher's URL is fine; re-hosting or repackaging the audio is not.**
  Offline download for personal use is a separate question from redistribution and should be treated
  as such. Verify NHK's specific terms before any public distribution.

### Data model

Do **not** add a parallel `PodcastEpisode` entity. `ContentItem` already covers it and additionally
carries `lastPositionSeconds` / `totalImmersionSeconds`, which the immersion loop needs:

| Proposed | Existing |
|---|---|
| id | `id` |
| source | `sourceType` — already has an **unused** `SourceType.podcast` value |
| title, thumbnailUrl | `title`, `thumbnailUrl` |
| duration | `durationSeconds` |
| description, audioUrl, episodeUrl, publishedAt, language | new nullable fields on `ContentItem` |

Adding nullable fields keeps `ImmersionSession` and `LocalContentRepository.updateLastPosition`
working unchanged.

### Prerequisites before this phase is buildable

1. **The `ImmersionMediaController` abstraction.** `playerControllerProvider` is typed
   `YoutubePlayerController?` (`immersion_player_view.dart:28-40`) and `TranscriptView` calls
   `seekTo` on that concrete type (`transcript_view.dart:99-101`). One interface
   (`play/pause/seek/position/rate`) with a YouTube adapter and a `just_audio` adapter is the
   load-bearing refactor. Consider `audio_service` for lock-screen controls, since the app already
   tracks sessions.
2. **A file-based asset store.** `LocalDocumentStore` is SharedPreferences-backed
   (`local_document_store.dart:5`) and cannot hold audio.
3. **Transcript strategy** — `podcast:transcript` VTT/SRT when a source publishes it, forced alignment
   when it does not, or authored text. Decide per source; do not assume the feed has one.

### Also deferred

"AI explanation" on word tap is a new capability — the app currently uses the bundled JMdict
dictionary with zero network calls. The FastAPI backend is the natural host for it.

## Out of scope

- Podcast RSS ingestion, audio playback, and forced alignment — see the follow-up phase above for the
  agreed architecture and its prerequisites.
- Per-dialogue read-progress tracking.
- Accounts, auth, or cross-device sync. The catalogue is public read-only; the local uid is unchanged.
- Romaji for existing YouTube content (romaji is backend-supplied for dialogues only).
- Japanese-language stories sourced from NHK — NHK has dialogue lessons but no Japanese-language
  story section. Stories must be authored in the backend.
- Pre-existing bug in `LocalContentRepository.save()` dropping `durationSeconds` — separate fix.
