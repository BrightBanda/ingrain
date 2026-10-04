# Phase: Sentence Mining, SRS Review & Progress Dashboard

## Goal
Implement the save → review → measure loop from the product spec: mine full sentences from the player transcript (or add manually), review them with an isolated simplified-SM-2 scheduler, and surface everything on the progress dashboard. Replaces the "coming soon" stubs at `/review` and `/progress`.

## Decisions Made (user-confirmed)
- **Scope**: Sentence mining (MVP #7) + SRS review (#8) + progress dashboard (#10). Vocabulary word-saving (#6), dictionary tap-to-lookup (#4), AI explanations (#5), Anki (#9), history search (#14) are **deferred** (data models anticipate them where free).
- **Storage**: Local-first via existing `LocalDocumentStore` (SharedPreferences JSON). **No Firebase** — the architecture doc's Firestore direction is explicitly deferred; the codebase has zero Firebase dependencies today. Repository contracts keep a later swap possible without touching ViewModels.
- **Mining UX**: Save button per transcript sentence (source, title, timestamp, surrounding context and active session auto-attached — the spec's "Immersion Memory") + manual add screen at `/sentences`.
- **SRS**: Simplified SM-2 (`again`/`hard`/`good`/`easy`), pure-Dart scheduler isolated from persistence (architecture §13), injected via provider so it is unit-testable without any repository.

## No new dependencies
Everything uses existing packages (flutter_riverpod, go_router, shared_preferences, intl, collection). Charts are hand-rolled `Container` bars — no chart package.

## New files

### `lib/features/sentence_mining/`
- `domain/sentence_item.dart` — `SentenceItem` domain model:
  `id, uid, japanese, translation?, explanation?, sourceType (SourceType from content feature — existing cross-feature import pattern), sourceId, sourceTitle?, timestampSeconds?, contextSentence?, sessionId?, createdAt`
- `domain/sentence_repository.dart` — contract:
  `save({...}) -> SentenceItem`, `get(id)`, `delete(id)`, `watchAll() -> Stream<List<SentenceItem>>`, `count()`, `countCreatedOn(DateTime day)`
- `data/sentence_item_dto.dart` — map ↔ domain (ISO8601 `createdAt`, `sourceType.name`)
- `data/local_sentence_repository.dart` — `LocalDocumentStore` collection `'sentences'`, docId = sentence id (pattern from `LocalImmersionRepository`; id = ms-radix36 + random)
- `presentation/viewmodel/sentence_mining_view_model.dart` — `sentenceRepositoryProvider`, `sentenceMiningViewModelProvider` (`AsyncNotifier<List<SentenceItem>>` per ContentVM pattern) with `saveSentence({...})`, `saveFromTranscript(...)`, `deleteSentence(id)` (also deletes linked SRS card via `reviewRepository.deleteCardsForSource`), `refresh()`
- `presentation/view/sentence_mining_view.dart` — `SentenceMiningView`: list (japanese, translation snippet, source title + timestamp), delete, FAB → manual add dialog (japanese required; translation/explanation optional; `sourceType: SourceType.manual`, `sourceId: 'manual'`)

### `lib/features/srs/`
- `domain/review_card.dart` — `CardType { sentence, vocabulary }`, `Rating { again, hard, good, easy }`, `ReviewCard`:
  `id, uid, cardType, sourceItemId, promptText (denormalized japanese — avoids cross-collection joins in a local JSON store), answerText?, createdAt, dueAt, intervalDays, repetitions, easeFactor, reviewCount, lastReviewedAt?`
- `domain/review_event.dart` — `ReviewEvent { id, uid, cardId, cardType, rating, reviewedAt, intervalDaysAfter }` (review-history log, matches architecture §11 `reviews` collection shape)
- `domain/srs_scheduler.dart` — pure `SrsScheduler` (see algorithm below)
- `domain/review_repository.dart` — contract:
  `createCard({cardType, sourceItemId, promptText, answerText?, createdAt?, dueAt?})`, `saveCard(card)`, `listDue({DateTime? now})`, `listAllCards()`, `recordReview({cardId, cardType, rating, reviewedAt, intervalDaysAfter})`, `listReviewHistory({int limit})`, `deleteCardsForSource(sourceItemId)`, `countDue({DateTime? now})`
- `data/review_card_dto.dart`, `data/review_event_dto.dart`
- `data/local_review_repository.dart` — collections `'reviewCards'` and `'reviewHistory'`; `listDue` filters `dueAt <= now` client-side and sorts by `dueAt`
- `presentation/viewmodel/review_view_model.dart` — `reviewRepositoryProvider`, `srsSchedulerProvider`, `reviewViewModelProvider` (`Notifier<ReviewSessionState>`). State: `queue, currentIndex, answerShown, reviewedThisSession, isEmpty`. Intents: `startSession()` (load due), `showAnswer()`, `submitAnswer(Rating)` → `card = scheduler.schedule(card, rating, now)` → `repository.saveCard(card)` + `repository.recordReview(...)` → advance. `refreshDue()` for tab counts.
- `presentation/view/review_tab_view.dart` — **replaces stub**: one-card-at-a-time session (japanese prompt → "Show answer" → answer → Again/Hard/Good/Easy buttons), progress indicator, completion summary, empty state "All caught up".

### `lib/features/progress/`
- `domain/progress_summary.dart` — `ProgressSummary { todaySeconds, weekSeconds, lifetimeSeconds, currentStreak, longestStreak, totalSentences, sentencesThisWeek, dueCount, reviewedToday, totalReviews, List<DailyActivity> last7Days (day, seconds, reviews) }`
- `domain/progress_calculator.dart` — pure functions (all take explicit `DateTime today`, unit-testable):
  - `summarize(sessions, sentences, dueCards, reviewEvents, {required today, required dailyGoalMinutes})`
  - Streak: per-local-day session seconds (attribute session to `startedAt` local day); current streak counts back from today, or from yesterday if today has no activity yet (streak alive); longest = longest consecutive run
  - Week = last 7 days incl. today
- `presentation/viewmodel/progress_view_model.dart` — `progressViewModelProvider` (`Notifier<ProgressUiState>` loading/data/error per SettingsVM pattern). Fetches `immersionRepositoryProvider.watchRecentSessions()`, `sentenceRepositoryProvider.watchAll().first`, `reviewRepositoryProvider.listDue()/listReviewHistory()`, `settingsViewModelProvider.settings.dailyGoalMinutes`, then computes via `ProgressCalculator`.
- `presentation/view/progress_tab_view.dart` — **replaces stub**: today card with goal progress bar, stat tiles (week / lifetime / streak), 7-day hand-rolled bar chart, learning card (sentences mined, due reviews, reviewed today), "Review now" button → `/review` when due > 0, empty state prompting to start immersion.

## SRS algorithm (simplified SM-2 — implement exactly, tests depend on it)
```
Initial card: intervalDays = 0, repetitions = 0, easeFactor = 2.5, dueAt = createdAt (due immediately)

schedule(card, rating, now):
  again:  repetitions = 0; intervalDays = 0; dueAt = now + 10min; ease = max(1.3, ease - 0.2)
  hard:   repetitions += 1; intervalDays = max(1, round(interval * 1.2)); dueAt = now + interval d; ease = max(1.3, ease - 0.15)
  good:   repetitions += 1; intervalDays = interval <= 0 ? 1 : (interval == 1 ? 6 : round(interval * ease)); dueAt = now + interval d
  easy:   repetitions += 1; intervalDays = interval <= 0 ? 4 : round(interval * ease * 1.3); dueAt = now + interval d; ease += 0.15
  reviewCount += 1; lastReviewedAt = now
```

## Modified files
1. `lib/features/content/presentation/view/player/transcript_view.dart` — add a save (`Icons.bookmark_add_outlined`) action per sentence tile → `showModalBottomSheet` save form (japanese readonly, translation + explanation fields). Pre-fill: content title from `contentItemProvider(contentId)`, `sessionId` from `immersionSessionViewModelProvider(contentId).sessionId`, `timestampSeconds` = `sentence.startSeconds`, `contextSentence` = adjacent sentence text.
2. `lib/features/content/presentation/view/content_history_view.dart` — header action (or section) linking to `/sentences` (mined sentences).
3. `lib/app/router.dart` — add full-screen `GoRoute(path: '/sentences', builder: ... SentenceMiningView)` outside `ShellRoute` (same pattern as `/content/add`); bottom-nav tabs unchanged.

## Storage shapes (LocalDocumentStore)
- `sentences/{id}`: `{id, uid, japanese, translation?, explanation?, sourceType, sourceId, sourceTitle?, timestampSeconds?, contextSentence?, sessionId?, createdAt}`
- `reviewCards/{id}`: `{id, uid, cardType, sourceItemId, promptText, answerText?, createdAt, dueAt, intervalDays, repetitions, easeFactor, reviewCount, lastReviewedAt?}`
- `reviewHistory/{id}`: `{id, uid, cardId, cardType, rating, reviewedAt, intervalDaysAfter}`

## Implementation order
1. Domain models + repository contracts (sentence_mining, srs)
2. `SrsScheduler` + unit tests (first good → 1d, second good → 6d, third good → 15d; `again` resets and reschedules +10min; `hard` ×1.2; `easy` ×1.3×ease and bumps ease; ease floor 1.3)
3. DTOs + local repositories
4. `ProgressCalculator` + unit tests (streak incl. today-missing case, weekly sums, per-day aggregation, empty inputs)
5. ViewModels + providers
6. UI: transcript save sheet, `/sentences` screen, review tab, progress tab
7. Router + Library entry point
8. `dart format` touched files, `flutter analyze`, `flutter test`

## Edge cases / failure modes
- Deleting a mined sentence also deletes its SRS card (`deleteCardsForSource`) — keep card and sentence consistent.
- Duplicate mining of the same sentence is allowed for MVP (deduplication is roadmap); note it in the save sheet via a subtle hint only if trivial, otherwise accept.
- Session crossing midnight attributes to `startedAt`'s local day (documented in calculator).
- Cards with `dueAt` in the past are due immediately; `again` cards reappear within the same session only after app restart (MVP).
- All repository methods take optional `DateTime now`/`createdAt` params for deterministic tests (existing `Clock`/`FixedClock` pattern).
- Empty states everywhere: no transcript → no mining; no cards → "All caught up"; no sessions → progress empty state.

## Validation
- `flutter analyze` clean; `dart format` applied to touched files.
- `flutter test`: scheduler tests, calculator tests, DTO mapping tests, review ViewModel flow test (fake repos + `ManualClock`, mirroring `immersion_session_view_model_test.dart` conventions).
- Manual loop: onboarding → add YouTube content with transcript → play → mine a sentence → Review tab shows it due → rate `good` → Progress shows sentence count, review activity, session time.

## Out of scope (explicit)
Vocabulary word-saving & dictionary lookup, AI-generated translation/explanation (needs Cloud Function + secrets — fields are manual-entry now), Anki import/export, learning-history search, calendar heatmap, reencounter engine, Firebase/Firestore migration, new packages.
