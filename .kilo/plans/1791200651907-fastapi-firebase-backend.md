# Ingrained_backend — FastAPI content service + Firebase Auth/Firestore client wiring

## Goal

Create `Ingrained_backend/` at the repo root: a FastAPI service that serves the dialogue catalogue the
Flutter app already expects, and verify Firebase ID tokens so it can work alongside Firebase. Then wire
the Flutter client just far enough that Firebase Auth and Cloud Firestore are real: users sign in with
Google or email/password and their learning data lives in Firestore instead of SharedPreferences.

Two deliverables, one plan: the backend is useless alone (the app's library tab is permanently empty
today) and Firebase is inert without the client (there is no `firebase_*` dependency in the repo).

## Current state (verified)

- **No backend exists.** `RemoteDialogueRepository` calls `Uri.resolve('/dialogues')` on
  `API_BASE_URL` (`lib/features/dialogue/data/remote_dialogue_repository.dart:9-31,56`), default
  `http://10.0.2.2:8000`. Every request gets connection-refused today; `listSummaries` then rethrows
  because the cache is empty (`remote_dialogue_repository.dart:45-49`).
- **The API contract is already frozen** in `.kilo/plans/1791137412955-dialogue-reader-feature.md:58-99`
  and encoded in `lib/features/dialogue/data/dialogue_dto.dart`. That plan specified a **no-auth public
  catalogue** and deferred "accounts, auth, or cross-device sync" — this plan supersedes that deferral.
- **No Firebase at all.** No `firebase_*` package, no `google-services.json`, no `firebase_options.dart`.
  `LocalAuthRepository` mints a random local uid (`local_auth_repository.dart:18-22`).
- **`LocalDocumentStore` is Firestore-shaped, SharedPreferences-backed** (`core/storage/local_document_store.dart`):
  `getDoc(uid, collection, docId)` / `setDoc(..., merge:)` / `deleteDoc` / `listDocs`. Written by
  7 repositories, read through `localDocumentStoreProvider` by 7 view models.
- **All persisted maps are already Firestore-safe**: every timestamp is an ISO-8601 string, every id is
  `<base36ms>-<hex>` (no `/`). No `DateTime` object ever reaches the store.
- **The one schema landmine**: `LocalContentRepository` fakes a subcollection with a slash inside a
  collection name — `getDoc(uid, 'contentHistory/<id>', 'transcript')`
  (`local_content_repository.dart:97-101,131`). Firestore collection and document ids cannot contain `/`.
- **Tooling**: `uv` at `~/.local/bin/uv`, Python 3 at `/usr/bin/python3`, Node present, **no docker**.
- Android uses AGP `9.1.0` / Kotlin `2.4.0` (`android/settings.gradle.kts:22-23`), `minSdk = flutter.minSdkVersion`.
- Folder name is `Ingrained_backend` as requested. Note the app package is `ingrain` (no trailing *d*)
  — the mismatch is intentional here, do not "fix" it.

## Decisions (settled during planning)

| Decision | Choice |
|---|---|
| Firebase's role | **Hybrid.** Firebase Auth = identity. Firestore = user data, written **directly by the Flutter client**. FastAPI = the public content catalogue + token verification. |
| Plan scope | Backend + minimal Flutter wiring (not a full migration, not backend-only) |
| Catalogue source | Hand-authored JSON files in the repo, loaded into memory at startup. No credentials needed to serve. |
| Auth methods | Google + email/password on the client |
| Existing local data | **Dropped.** No migration path. Legacy SharedPreferences keys are deleted on first launch. |
| Backend features | Catalogue only: `/health`, `GET /dialogues`, `GET /dialogues/{id}`, `GET /me` |
| Deployment | Local now; `render.yaml` committed so Render is a config step later |
| Python tooling | `uv` + `pyproject.toml` + `uv.lock` (Render supports uv when `uv.lock` is present) |
| Auth verification | `google.oauth2.id_token` with the **project id only** — no service account, no Admin SDK |
| Dev Firestore | The real Firebase project. No emulator in the client (Google sign-in against the Auth emulator is a known time sink). |

### Why the hybrid and not a FastAPI facade over Firestore

Firestore's mobile/web SDK already gives offline persistence, which is the behaviour the current
local-first design was built for. Putting FastAPI in front of Firestore would delete that, add a network
hop to every read, and force `LocalDocumentStore` to stay as a hand-rolled cache — all to centralise
logic this app does not yet have.

## Prerequisites (manual, console-only — cannot be automated from the repo)

Do these first; nothing in Part A or B works without them.

1. Create a Firebase project (console.firebase.google.com). Note the **project id**.
2. **Authentication → Sign-in method**: enable **Google** and **Email/Password**. Disable "Anonymous".
3. **Firestore Database**: create in production mode, same region as the project default.
4. Add the Android app `com.example.ingrain` (from `android/app/build.gradle.kts:19`). Register the
   **SHA-1 and SHA-256** of the debug keystore — Google sign-in on Android fails with a silent
   `ApiException` without this.
5. Add a Web app (needed for the `web/` target).
6. Install the FlutterFire CLI and run `flutterfire configure` from the repo root with
   `--project-id=<id> --platforms=android,web`. This generates `lib/firebase_options.dart` and
   `android/app/google-services.json`. **Commit both** — they contain no secrets (an API key plus a
   project id); access is governed by Firestore rules, not by hiding these files.

## Part A — `Ingrained_backend/`

### A1. Project skeleton

`Ingrained_backend/pyproject.toml`

```toml
[project]
name = "ingrained-backend"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
  "fastapi",
  "uvicorn[standard]",
  "pydantic>=2",
  "pydantic-settings",
  "google-auth",
]

[dependency-groups]
dev = ["pytest", "httpx", "ruff"]

[tool.pytest.ini_options]
testpaths = ["tests"]

[tool.ruff]
line-length = 88
```

Also: `.python-version` (`3.12`), `.gitignore` (`.venv/`, `.env`, `__pycache__/`, `.pytest_cache/`),
`.env.example`, and run `uv lock` to produce `uv.lock`.

### A2. `app/config.py`

`pydantic_settings.BaseSettings`, `env_file=".env"`, `extra="ignore"`:

| Field | Default | Purpose |
|---|---|---|
| `firebase_project_id: str \| None` | `None` | `aud` for token verification. `None` ⇒ `/me` returns 503, everything else still works. |
| `cors_origins: list[str]` | `["*"]` | Public read API, no cookies ⇒ `*` is safe. |
| `catalogue_dir: Path` | `content/dialogues` | Resolved relative to the package root, not the cwd. |

### A3. `app/models/dialogue.py`

Pydantic v2 models that serialise to exactly the shapes in `dialogue_dto.dart`:

- `DialogueKind(StrEnum)`: `dialogue`, `story` — must serialise as the **value** string, because
  `DialogueDto._kind` compares against `DialogueKind.values.map((k) => k.name)`.
- `DialogueToken`: `surface: str`, `reading: str | None = None`, `romaji: str | None = None`.
- `DialogueLine`: `index: int`, `speaker: str | None = None`, `tokens: list[DialogueToken]`.
- `DialogueSummary`: `id, title, level, kind, speakers, line_count, attribution, source_url, updated_at`.
  Field names **must** be `lineCount` / `sourceUrl` / `updatedAt` on the wire — alias them
  (`alias_generator` or explicit `Field(alias=...)` + `populate_by_name=True`).
- `Dialogue`: summary fields + `lines`. `line_count` is derived, never stored.
- `DialogueListResponse`: `dialogues: list[DialogueSummary]`.

Serialise with `exclude_none=True` so absent `romaji`/`reading`/`speaker`/`sourceUrl` are *omitted*
rather than sent as `null` — the DTO tolerates both, but omission is what the contract describes and
it keeps payloads small.

### A4. `app/services/catalogue.py`

- `load_catalogue(directory) -> dict[str, Dialogue]`: read every `*.json`, validate, build the map.
  Runs once at startup via the FastAPI lifespan. Raise on duplicate `id`.
- `updatedAt` resolution: use the file's value when present, else the file **mtime** in UTC. The client
  invalidates its cached copy when `updatedAt` changes, so editing a file must bump it — mtime gives
  that for free without hand-maintained timestamps.
- Ordering: `list_summaries()` returns a stable sort by `(level, id)` so list ordering never flickers.
- `get(id) -> Dialogue | None`.

JSON file shape (`content/dialogues/<id>.json`):

```json
{
  "id": "greetings-01",
  "title": "Greetings and Introductions",
  "level": "N5",
  "kind": "dialogue",
  "attribution": "ingrain original",
  "speakers": ["Aiko", "Ken"],
  "lines": [
    { "index": 0, "speaker": "Aiko",
      "tokens": [
        { "surface": "おはよう", "reading": "おはよう", "romaji": "ohayou" },
        { "surface": "ございます", "reading": "ございます", "romaji": "gozaimasu" }
      ] }
  ]
}
```

`lineCount` and `updatedAt` are not stored. `sourceUrl` is omitted (see A7).

### A5. `app/routers/dialogues.py`

- `GET /dialogues` → `DialogueListResponse`.
- `GET /dialogues/{dialogue_id}` → `Dialogue`, or `404` with `{"detail": "dialogue '<id>' not found"}`.

**Mount at the root — no `/api` prefix.** The client uses `Uri.resolve('/dialogues')`, and a
leading-slash resolve discards any base path, so a prefix would be silently dropped.

### A6. `app/auth/firebase.py` + `app/routers/me.py`

- `verify_bearer_token(credentials, settings)` FastAPI dependency using
  `OAuth2PasswordBearer(tokenUrl="", auto_error=False)`.
- `google.oauth2.id_token.verify_token(token, google.auth.transport.requests.Request(),
  audience=settings.firebase_project_id)`. This needs **only the project id** — it fetches Google's
  public certs and caches them. The Admin SDK is deliberately not used: it would require a service
  account for an endpoint that only echoes claims.
- Map failures to `401` (missing / malformed / expired / wrong audience) and to `503` with a clear
  message when `firebase_project_id` is unset.
- `GET /me` → `{"uid", "email", "name", "emailVerified", "provider"}` from the decoded claims
  (`sub`, `email`, `name`, `email_verified`, and `firebase.sign_in_provider`).

### A7. `app/main.py`

`create_app()` factory: CORS from settings, include both routers, and

`GET /health` → `{"status": "ok", "dialogues": <count>}`.

`app/main.py` also carries the module-level `app = create_app()` so `uvicorn app.main:app` works.
`/health` must stay dependency-free — it is the Render health check.

### A8. Seed content — 6 dialogues

`content/dialogues/`: `greetings-01` (N5), `restaurant-01` (N5), `directions-01` (N5),
`shopping-01` (N4), `weather-01` (N4), `station-01` (N4, `kind: story` with **no** `speaker` fields
to exercise the prose path). 10-14 lines each, 2-3 speakers, every token carrying `surface` +
`reading` + `romaji`. `attribution: "ingrain original"`.

Do **not** scrape or copy NHK text — the earlier plan established that linking is fine and
re-hosting/transcribing a publisher's material is not. Omit `sourceUrl` on all six so the reader's
"open on NHK" button stays hidden (it renders only when `sourceUrl != null`).

### A9. Tests — `tests/`

- `test_dialogues_api.py` — `{"dialogues": [...]}` envelope; every summary carries
  `id/title/level/kind/speakers/lineCount`; `GET /dialogues/{id}` returns `lines` with sequential
  `index` values; unknown id → 404; `/health` → 200.
- `test_catalogue.py` — **contract invariants over the real seed files**: concatenating
  `tokens[].surface` per line yields a non-empty string with no leading/trailing space; every token
  has a non-empty `surface`; ids match `^[a-z0-9-]+$` (a `/` in an id would break the client's
  `dialogues/<id>` cache key); no duplicate ids; `updatedAt` falls back to mtime when absent;
  a malformed file raises an error naming the file.
- `test_auth.py` — `/me` with no header → 401; with a bogus token → 401; with `firebase_project_id`
  unset → 503; happy path via a monkeypatched verifier so **no test touches the network**.

### A10. `Ingrained_backend/README.md` + repo-root `render.yaml`

README: prerequisites, `uv sync`, `uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000`,
`uv run pytest`, curl examples, the JSON schema, how to add a dialogue, and the
**`10.0.2.2` note** (that is the Android emulator's alias for the host — a physical device needs the
host's LAN IP).

`render.yaml` goes at the **repo root** (Render looks for the Blueprint there):

```yaml
services:
  - type: web
    name: ingrain-api
    runtime: python
    rootDir: Ingrained_backend
    plan: free
    buildCommand: uv sync --frozen --no-dev
    startCommand: uv run uvicorn app.main:app --host 0.0.0.0 --port $PORT
    healthCheckPath: /health
    envVars:
      - key: PYTHON_VERSION
        value: "3.12.11"
      - key: FIREBASE_PROJECT_ID
        sync: false
```

## Part B — Flutter client wiring

### B1. Dependencies

`pubspec.yaml`: add `firebase_core: ^4.15.0`, `firebase_auth: ^6.7.0`, `cloud_firestore: ^6.9.0`,
`google_sign_in: ^7.2.0` (versions verified current; `cloud_firestore 6.9.0` needs
`firebase_core ^4.14.0`). Add `lib/firebase_options.dart` and `android/app/google-services.json`
from `flutterfire configure`.

### B2. Android build

- `android/settings.gradle.kts`: add `id("com.google.gms.google-services") version "<latest>" apply false`.
- `android/app/build.gradle.kts`: apply it.
- Set `minSdk = 23` explicitly **if** `flutter.minSdkVersion` resolves below 23 (Firebase requires 23+).
- **Contingency — read before you start:** this project is on AGP `9.1.0`. If the Google Services
  plugin conflicts, do **not** downgrade AGP. Instead skip the plugin entirely and pass
  `DefaultFirebaseOptions.currentPlatform` to `Firebase.initializeApp(options: ...)`, which supplies the
  same values at runtime; pass `DefaultFirebaseOptions.currentPlatform.web.clientId` (and the
  `GOOGLE_CLIENT_ID` from `firebase_options.dart`) to `GoogleSignIn(serverClientId: ...)`.

### B3. `lib/core/storage/` — the store split

1. **New** `document_store.dart`: `abstract interface class DocumentStore` with exactly four methods —
   `getDoc`, `setDoc`, `deleteDoc`, `listDocs`. Those are the only ones the 7 repositories call
   (verified by grep). Do not carry over `registerCollection` / `listCollectionIds` /
   `deleteCollection` / `clearAllForUid` — only `LocalDialogueCache` used `registerCollection`, and the
   other three have no callers at all.
2. `local_document_store.dart`: keep, add `implements DocumentStore`, keep the four methods plus
   `registerCollection` for the dialogue cache, and delete the three dead methods.
3. **New** `firestore_document_store.dart`, implementing `DocumentStore`:
   - `documentPath(uid, collection, docId)` as a **pure top-level function** so it is unit-testable
     without an emulator: `'users/$uid/$collection/$docId'`.
   - `getDoc` → `(await doc(path).get())`; return `{}` when `!exists` (matches the current
     "missing doc reads as empty map" contract that every repository relies on).
   - `setDoc(merge:)` → `doc(path).set(data, SetOptions(merge: merge))`.
   - `listDocs` → `firestore.collection('users/$uid/$collection').get()`, unordered, matching
     `LocalDocumentStore.listDocs`.
   - A recursive `assertFirestoreSafe(value)` guard rejecting anything outside
     `String/int/double/bool/null/List/Map`. Cheap insurance: the maps are all ISO strings today, but a
     stray `DateTime` would otherwise surface as an opaque runtime error on write.

### B4. `lib/core/providers.dart`

Add `firebaseApiProvider`, `firebaseAuthProvider`, `firestoreProvider`. Add
`documentStoreProvider` returning `FirestoreDocumentStore(ref.watch(firestoreProvider))`. Keep
`localDocumentStoreProvider` and `sharedPreferencesProvider` — the dialogue cache still needs them.

Switch the 7 view models from `localDocumentStoreProvider` to `documentStoreProvider`:
`review_view_model.dart:14`, `immersion_session_view_model.dart:17`, `content_view_model.dart:15`,
`vocabulary_view_model.dart:22`, `settings_view_model.dart:10`, `sentence_mining_view_model.dart:19`.
`dialogue_providers.dart:16` **stays** on the local store — that is the offline dialogue cache, not
user data.

Retype the store field in the 7 repositories from `LocalDocumentStore` to `DocumentStore`:
`local_vocabulary_repository.dart:11`, `local_settings_repository.dart:7`,
`local_sentence_repository.dart:11`, `local_content_repository.dart:10`,
`local_review_repository.dart:12`, `local_immersion_repository.dart:9`.

### B5. `lib/features/content/data/local_content_repository.dart`

Replace the slash-collection subcollection with a composite document id, at both call sites:
`getDoc(uid, collection, '$contentId__transcript')` (line 97) and
`setDoc(uid, collection, '$contentId__transcript', ...)` (line 131). Firestore forbids `/` in collection
and document ids, so this is required, not cosmetic. No existing test asserts the old key.

### B6. Auth — replace the local uid

- **Delete** `lib/features/auth/data/local_auth_repository.dart` and the `LocalAuthRepository` section
  of `test/features/auth_test.dart`.
- **New** `lib/features/auth/data/firebase_auth_repository.dart` implementing the extended
  `AuthRepository`:
  - `ensureUid()` — return `currentUser!.uid`; if null, await the first non-null `authStateChanges()`
    emission with a 10s timeout, then throw a descriptive `StateError`. Every repository calls this
    first, so a clear failure beats a null uid.
  - `displayName` — read `users/{uid}/profile/self` `displayName`, falling back to
    `user.displayName`, then the local part of `user.email`.
  - `setDisplayName(name)` — write the profile doc **and** `user.updateDisplayName(name)`.
  - `ensureProfile()` — on first sign-in, seed `users/{uid}/profile/self` with
    `{uid, displayName, createdAt}` if absent.
  - `signInWithGoogle()`, `signInWithEmail(email, password)`, `createAccount(email, password)`,
    `signOut()` (a **plain** sign-out — the current `clear()` deletes the profile and must not be
    reused), and an `authStateChanges()` stream.
- `auth_state.dart`: add `AuthState.signedOut()`; `isOnboarded` = signed in **and**
  `displayName != null`; add `String? error` for failed sign-in. Keep the existing shape so
  `router.dart:24-35` keeps working untouched.
- `auth_view_model.dart`: `_bootstrap` listens to the auth stream instead of calling `ensureUid()`
  (the current `catch` already lands on `AuthState.ready(uid: '')`, which is exactly "signed out").
  `authRepositoryProvider` (line 8-11) now builds the Firebase repository. Add the sign-in methods.
  `completeOnboarding` keeps its signature. Fix `profile` (line 47-55) to read the stored `createdAt`
  instead of `DateTime.now()`.
- `onboarding_view.dart`: becomes a sign-in screen — "Continue with Google", email + password fields,
  a create-account/sign-in toggle, then a display-name field after the first sign-in. Reuse the
  existing theme (`app_colors.dart` / `app_theme.dart`); do not introduce a new visual language.

### B7. `lib/main.dart`

`WidgetsFlutterBinding.ensureInitialized()` → `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
→ `SharedPreferences.getInstance()` → `runApp`. Override the new providers in `ProviderScope` exactly
as `sharedPreferencesProvider` is overridden today.

Add the one-time legacy cleanup: iterate `SharedPreferences.getKeys()` and remove every key starting
with `local_store_` on first launch. That honours the "drop it" decision and stops the old anonymous
uid's data from lingering on the device.

### B8. Firestore rules

Repo-root `firestore.rules` and `firebase.json`:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /{document=**} { allow read, write: if false; }
  }
}
```

Deny-by-default is essential here: the client writes its own data, so the rules *are* the
authorisation. Note in the README that the SRS scheduling state is therefore client-authoritative and
can be tampered with by a modified client — acceptable for a self-hosted learning app, revisit with
App Check or server-side scheduling if it ever matters.

Optional but recommended: `@firebase/rules-unit-testing` unit tests asserting a user can read their own
`users/{uid}/...`, cannot read another uid's, and cannot write anything when unauthenticated.

### Firestore layout (result)

`users/{uid}/` → `profile/self`, `settings/app`, `vocabulary/{id}`, `reviewCards/{id}`,
`reviewHistory/{id}`, `sentences/{id}`, `sessions/{id}`, `contentHistory/{id}`,
`contentHistory/{contentId}__transcript`. Document bodies are unchanged from the current maps — the
DTOs already emit ISO strings and primitives, so no schema migration is required.

## Failure modes

| Case | Behaviour |
|---|---|
| Backend down | Existing path: `RemoteDialogueRepository` serves the cached copy and flags `isShowingCachedCopy`. No change needed. |
| Render free tier asleep | First request after idle takes ~30s. The client timeout + cache covers it. Move to a paid plan before real users. |
| `GET /dialogues/{id}` 404 | Client throws, falls back to the cached copy. Correct. |
| Malformed seed JSON | Server refuses to start and names the file. Better than serving a broken catalogue. |
| `/me` with no `FIREBASE_PROJECT_ID` | 503 with an explanatory message; `/dialogues` and `/health` unaffected. |
| Not signed in but a repository is called | `ensureUid()` throws after its 10s timeout. In practice unreachable — the router redirects to `/onboarding` first. |
| Firestore offline | The SDK serves the last-known snapshot and queues writes. Same UX as today. |
| Google sign-in fails silently on Android | Missing SHA-1/SHA-256 fingerprints (Prerequisites step 4) or a missing `serverClientId`. |
| AGP 9.1 rejects the Google Services plugin | Contingency in B2 — pass options explicitly, do not downgrade AGP. |
| `displayName` null from Google | Falls back to the email local part; the onboarding name field fills it in. |

## Validation

Backend:
1. `cd Ingrained_backend && uv run pytest` — green, no network access.
2. `uv run ruff check .` — clean.
3. `uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000`, then `curl` all four endpoints
   and paste the responses into the PR description.
4. `curl -H "Authorization: Bearer notatoken" localhost:8000/me` → 401, not 500.

Client:
5. `flutter analyze` — clean, with the 3 pre-existing `use_null_aware_elements` infos as the baseline.
6. `flutter test` — green **except** `test/features/theme_controller_test.dart`, which hangs
   indefinitely on a clean checkout of `main`. Pre-existing; exclude it explicitly.
7. `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000` on the Android emulator, then:
   sign in with Google → Library → Dialogues lists 6 entries → open one → toggle romaji → tap a token
   and save a word → mine a sentence → confirm the new documents under `users/{uid}/vocabulary` and
   `users/{uid}/sentences` in the Firebase console → sign out → sign back in → the data is still there.
   That single loop validates the backend, Auth, Firestore, and the store swap together.

New tests:
8. `test/core/document_store_test.dart` — `documentPath` strings, including the composite transcript id.
9. `test/features/auth_test.dart` (rewritten) — `AuthState` transitions against a fake `AuthRepository`;
   sign-out must not delete the profile document.

## Risks

- **Dropping local data is irreversible for the current dev device.** The user still has vocabulary, SRS
  history, and immersion sessions under the anonymous uid. This was an explicit decision; the plan does
  not build a migration path.
- **AGP 9.1.0 + the Google Services plugin** is the single most likely thing to fail. Contingency in B2.
- **Auth changes are visible everywhere.** Every repository calls `ensureUid()` on entry, so a broken
  sign-in path blanks the whole app rather than one screen. Verify the sign-in → `/immerse` transition
  first, before touching anything else.
- **Firestore rules are the only authorisation.** A modified client can write arbitrary values into its
  own `users/{uid}/...` tree.
- **Catalogue JSON is hand-authored.** Romaji and readings are only as good as the authoring; the
  invariant tests catch structural mistakes, not linguistic ones.

## Out of scope

- Admin CRUD for dialogues, AI explanations, FCM push — all deliberately deferred.
- Podcast/RSS ingestion, audio playback, forced alignment (deferred in the earlier dialogue plan).
- Migrating existing local data to Firestore.
- Renaming the `Local*Repository` classes now that they are cloud-backed — cosmetic, do it separately.
- App Check, rate limiting, HTTPS termination config, CI, Docker.
- iOS and release signing. The `web/` target needs its authorised domain added in the Firebase console
  after the first deploy; `localhost` works by default for local runs.
