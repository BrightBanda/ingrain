# ingrain Admin Dashboard — Build Brief

You are building the **ingrain admin dashboard**: a Flutter app, for **web (desktop browsers)** and **mobile (Android/iOS)**. Administrators use it to manage the video catalogue, pin daily recommendations, look at usage and AI-cost statistics, and change learners' subscription tiers.

The backend API it talks to **already exists and is tested**. Your job is the client. Read this whole brief before writing code. Section 13 lists the acceptance criteria.

---

## 1. Context: what already exists

ingrain is a Japanese immersion app. A learner signs in with Firebase. During onboarding they choose a JLPT level (N5 easiest, N1 hardest), their interests, and a character avatar. Each day the app shows them 3 recommended YouTube videos, picked by the backend.

| Piece | Where | Notes |
|---|---|---|
| Learner app (Flutter) | repo root: `lib/`, `test/` | **Do not modify.** Read it for design language (`lib/app/theme/`, `lib/shared/widgets/colorful.dart`) and the avatar artwork (`lib/features/profile/`). |
| Backend (FastAPI + SQLite) | `Ingrained_backend/` (its own git repo) | Serves the admin API under `/admin/*`. Its README has a summary. The live OpenAPI docs are at `<API_BASE_URL>/docs`. |
| Firebase project | `ingrain-58270` | The same project for the app and the dashboard. Web config already exists in `lib/firebase_options.dart`. |
| Deployed API | `https://ingrain-api-y6ia.onrender.com` | On Render's free plan: the first request after an idle period can take about 30 s. The free plan also **wipes the SQLite database on every deploy or restart**. |

**Who is an admin** is decided by the backend only. An admin is either a Firebase uid listed in the backend's `ADMIN_UIDS` environment variable, or a user whose ID token carries the custom claim `admin: true`. The dashboard never decides this for itself (see §5).

---

## 2. Scope

### Build

1. Sign-in (Google and email/password via Firebase Auth), plus an admin check.
2. **Overview**: key numbers and trend charts at a glance.
3. **Content**: list, filter, search, create, edit, publish/archive, and delete videos.
4. **Recommendations**: a calendar of pinned daily sets; create, edit and unpin them; preview what each level sees today.
5. **Analytics**: users and usage over time (day/week/month), and AI usage and estimated cost.
6. **Users**: list, filter by tier, view a profile, change the subscription tier.
7. **Settings**: who is signed in, API target, theme, sign out.

One codebase. A responsive layout serves desktop web, tablets and phones (§8).

### Do not

- Do not change the learner app (`lib/`, `test/` at the repo root).
- Do not change backend behaviour or wire contracts. If you hit a real gap, follow §12: document it and propose the change. Do not silently work around it with a different contract.
- Do not store secrets in the client. Admin rights come from the server; never hide admin features behind a client-side flag alone.
- Do not add features the API cannot back, such as bulk actions, audit logs, email display or user search by name. List them as follow-ups instead (§12).

---

## 3. Project setup

Create a **new, separate Flutter project** at the repo root:

```
ingrain/                 ← repo root (learner app)
├── Ingrained_backend/   ← API
└── ingrain_admin/       ← you create this
```

```bash
flutter create --org com.ingrain --project-name ingrain_admin \
  --platforms web,android,ios ingrain_admin
```

- **Flutter**: the installed SDK is 3.47 (stable, Dart ≥ 3.13). Use the same `environment.sdk` constraint as the root `pubspec.yaml`: `^3.13.3`.
- **Firebase**: run `flutterfire configure --project=ingrain-58270` inside `ingrain_admin/` to generate `lib/firebase_options.dart`. If the CLI is unavailable, copy the root `lib/firebase_options.dart`; its `web` and `android` entries are valid for this project. iOS needs a registered iOS app in the Firebase console. If it isn't configured, the iOS build may fail at Firebase init: note it, and don't block on it.
- **API base URL**: read it from `--dart-define=API_BASE_URL=...`, defaulting to the deployed URL above, the same way the app does (`lib/core/config/api_config.dart`). For local development, `http://localhost:8000` works on web; on the Android emulator use `http://10.0.2.2:8000`.
- **CORS**: the backend already allows any origin, plus the methods `GET/POST/PUT/PATCH/DELETE` and the headers `Authorization`/`Content-Type`. Web works without changes.

### Running the backend locally for development

```bash
cd Ingrained_backend
uv sync
ADMIN_UIDS=<your-firebase-uid> FIREBASE_PROJECT_ID=ingrain-58270 \
  uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

On first start the database is seeded with 53 real videos across all five levels, so lists and charts are never empty. User and AI statistics start at zero. They grow as learners use the app, or you can drive them with the learner app pointed at the same server.

---

## 4. Dependencies

Use these. Pin to the latest stable versions that resolve together. Prefer what the learner app already uses so conventions match.

| Package | Purpose | Notes |
|---|---|---|
| `flutter_riverpod` (^3) | State management | Same as the app. Use `Notifier`/`AsyncNotifier` with hand-written providers. **No `riverpod_generator`/codegen**, to match the app's style. |
| `go_router` | Routing, deep links, web URLs | URL-addressable screens and filters (§9). |
| `dio` | HTTP | One configured `Dio` instance with interceptors (§6.3). |
| `firebase_core`, `firebase_auth` | Sign-in, ID tokens | |
| `google_sign_in` | Google sign-in on mobile | On **web**, use `FirebaseAuth.signInWithPopup(GoogleAuthProvider())` instead. |
| `fl_chart` | Line and bar charts | |
| `intl` | Number, currency and date formatting | |
| `collection` | List/map equality, `firstWhereOrNull` | |
| `url_launcher` | Open a video on YouTube | |
| `shared_preferences` | Remember theme and the last-used filters | Conveniences only, never data. |
| dev: `flutter_lints`, `mocktail`, `http_mock_adapter` | Tests | `http_mock_adapter` is a mock adapter for Dio. |

Optional, if you need them: `data_table_2` (sticky-header, sortable desktop tables) and `flutter_animate` (subtle entrance animations). Don't add state, model or codegen libraries (freezed, json_serializable, get_it, bloc). The app writes its models and DTOs by hand, and so should you.

---

## 5. Authentication and the admin gate

1. **Sign-in screen** (shown when Firebase has no user):
   - "Continue with Google": `signInWithPopup` on web, `google_sign_in` then `GoogleAuthProvider.credential` on mobile.
   - Email/password sign-in. **No sign-up**: admins are existing accounts.
2. **Admin check**. Once signed in, call `GET /admin/taxonomy`. It is cheap, and you need its data anyway.
   - `200`: the user is an admin. Cache the taxonomy and enter the app.
   - `403`: show the **Not authorized** screen. Show the signed-in email and the uid, with a copy button, so the user can ask an operator to add the uid to `ADMIN_UIDS`. Offer a sign-out button.
   - `401`: the token is bad or expired. Force-refresh it once and retry. If that fails, sign out.
   - `503`: the server has no `FIREBASE_PROJECT_ID`. Show a configuration error.
   - Network error or timeout: show "Can't reach the server" with a Retry button. Explain that the server may be waking up and the first request can take about 30 s.
3. **Router guard**. While auth is unknown, show a splash. Signed out → `/sign-in`. Signed in but not an admin → `/not-authorized`. Admin → requested route, or `/` by default. Build the router so it **refreshes on auth changes without rebuilding the `GoRouter` instance**: use `refreshListenable`, or watch only a small `(isLoading, status)` record. The learner app had a bug where watching the whole auth state reset navigation on every state change.
4. **Tokens**. Get a fresh ID token per request with `user.getIdToken()` (Firebase caches it and refreshes it near expiry). On a `401`, retry **once** with `getIdToken(true)`.

---

## 6. Architecture

Use feature-first folders. Each feature has `domain` / `data` / `presentation` layers, mirroring the learner app. Business logic never lives in widgets.

### 6.1 Layers

- **domain/**: plain Dart models and enums, plus repository *interfaces*. No Flutter, Dio or JSON here.
- **data/**: DTOs (JSON ↔ domain, written by hand) and repository *implementations* on top of the shared `ApiClient`.
- **presentation/**: Riverpod providers and view-models (`Notifier`/`AsyncNotifier`), plus widgets. Widgets read state and call view-model methods. Nothing else.

### 6.2 State conventions

- Each list screen has a view-model holding `(filters, page, AsyncValue<Page<T>>)`. Changing a filter resets to page 0 and refetches.
- Forms use a view-model with a draft model, validation getters (`canSave`, `fieldErrors`), and `save()`, which returns success or surfaces a typed error. This is the same pattern as the app's `EditProfileViewModel` (`lib/features/profile/presentation/viewmodel/edit_profile_view_model.dart`).
- After a mutation, invalidate the affected providers: list, detail, taxonomy counts, and Overview if it shows counts. **No optimistic updates** for admin writes. Wait for the server, then show a confirmation toast.
- Turn off Riverpod's automatic retry on providers that hit the API (`retry: (_, _) => null`). The UI offers Retry instead. The learner app does the same.
- Override every repository in tests. No test may touch the network.

### 6.3 Networking (Dio)

`core/network/api_client.dart` owns one `Dio`:

- `baseUrl` = `API_BASE_URL`; `connectTimeout` 15 s; `receiveTimeout` 40 s (covers Render's cold start).
- **Auth interceptor** (`QueuedInterceptorsWrapper`, so concurrent 401s refresh only once): attaches `Authorization: Bearer <token>`, and retries a `401` once with a force-refreshed token.
- **Error mapping**: convert every `DioException` into an `ApiException(AppError)`:

| Status | `AppErrorType` | Message to show |
|---|---|---|
| no response / timeout | `network` | "Can't reach the server. It may be waking up — try again." |
| 400 | `validation` | the server's `detail` |
| 401 | `auth` | "Your session expired. Sign in again." |
| 403 | `permission` | "You don't have admin access." |
| 404 | `notFound` | "Not found — it may have been deleted." |
| 409 | `conflict` | the server's `detail` (e.g. "content 'x' already exists") |
| 422 | `validation` | parsed `detail` (see below) |
| 5xx | `server` | "The server had a problem. Try again." |

**Error body format** (FastAPI): `{"detail": ...}`. `detail` is **either a string** (the backend's own errors) **or a list** of `{"loc": [...], "msg": "...", "type": "..."}` (request validation). Map the list form to field errors by the last element of `loc`, which is the camelCase field name, e.g. `["body","videoUrl"]` → `videoUrl`. Forms then show each message under its field.

### 6.4 Shared core

- `core/error/app_error.dart`: `AppError {type, message, fieldErrors}` and `ApiException`.
- `core/config/api_config.dart`: the `API_BASE_URL` define.
- `core/format/`: number (`1.2k`), currency (`$0.0123`; use 4 decimal places under $1), date (`Mon 7 Oct`), and duration (`3:55`, `1:02:11`) helpers.
- `core/time/utc.dart`: every server date is a **UTC calendar day** (§7.1). One helper builds `YYYY-MM-DD` strings from a UTC `DateTime`, and one parses them back.

---

## 7. Backend API reference (`/admin/*`)

All requests carry `Authorization: Bearer <Firebase ID token>`. JSON is **camelCase**. Responses never include server-internal fields beyond those listed.

### 7.1 Conventions

- **Dates**: `date` fields are `"YYYY-MM-DD"` UTC calendar days. Timestamps are ISO 8601 with offset (e.g. `2026-10-07T09:30:00+00:00`). **Weeks start on Monday.**
- **Pagination**: `limit` + `offset`. Responses return `total` so you can render "41–60 of 213".
- **Absent vs null**: optional fields may be omitted or `null`. Treat both the same.
- **Enums**. Treat unknown values defensively: show them raw rather than crashing.

| Enum | Values |
|---|---|
| `JlptLevel` | `N5` `N4` `N3` `N2` `N1` (N5 easiest) |
| `ContentCategory` | `anime` `youtube` `podcasts` `music` `news` `conversations` `travel` `reading` `gaming` `culture` |
| `ContentStatus` | `draft` `published` `archived`. Only `published` reaches learners. |
| `ContentType` | `video` (more types may come later) |
| `SubscriptionTier` | `free` `premium`. Anything other than `free` counts as paid. |
| `Granularity` | `day` `week` `month` |
| `RecommendationReason` | `curated` `interest` `level` `nearbyLevel` `rewatch` |

### 7.2 Models

```text
ContentItem {
  id: string                      // ^[a-z0-9][a-z0-9-]{0,63}$
  type: ContentType               // "video"
  title: string                   // 1–200 chars
  description: string             // ≤ 4000, may be ""
  level: JlptLevel
  categories: ContentCategory[]   // ≤ 10, de-duplicated by the server
  videoUrl: string                // must be a YouTube video link (watch, youtu.be, shorts, embed, live)
  thumbnailUrl: string | null     // admin-supplied override
  durationSeconds: int | null     // ≥ 0
  channelTitle: string | null     // ≤ 200
  status: ContentStatus
  createdAt: timestamp
  updatedAt: timestamp
  youtubeId: string | null        // computed by the server
  resolvedThumbnailUrl: string | null  // thumbnailUrl, else YouTube's hqdefault. USE THIS for display.
}

ContentCreate = ContentItem's editable fields + optional id (omit → server generates "v-xxxxxxxxxx")
ContentUpdate = any subset of editable fields (PATCH; omitted fields unchanged;
                null clears only thumbnailUrl, durationSeconds, channelTitle)
ContentListResponse { items: ContentItem[], total: int }

TaxonomyResponse {
  levels: JlptLevel[]
  categories: { id: ContentCategory, contentCount: int }[]
  types: ContentType[]
  statuses: ContentStatus[]
}

DailyRecommendationSet {
  date: "YYYY-MM-DD"
  level: JlptLevel | null          // null = applies to ALL levels
  contentIds: string[]             // 1–10, shown in this order
  note: string | null              // ≤ 500, admin-only memo
  updatedAt: timestamp | null      // server-set
}
DailyRecommendationSetList { sets: DailyRecommendationSet[] }

DailyRecommendations {             // what a learner sees
  date: "YYYY-MM-DD"
  validUntil: timestamp            // next UTC midnight
  level: JlptLevel
  items: (ContentItem + { reason: RecommendationReason })[]
}

UserStats {
  totalUsers, freeUsers, paidUsers: int
  byTier: { [SubscriptionTier]: int }      // e.g. {"free": 120, "premium": 8}
  newUsers: { today, last7Days, last30Days: int }
  activeUsers: { daily, weekly, monthly: int }   // distinct users: today, last 7 days, last 30 days
}
UsageStats { granularity, series: { periodStart: "YYYY-MM-DD", visits, activeUsers, newUsers: int }[] }

AiTotals { requests, failedRequests, inputTokens, outputTokens: int, estimatedCostUsd: number }
AiUsageStats {
  granularity
  totals: AiTotals
  series: (AiTotals + { periodStart })[]
  byModel: (AiTotals + { model: string })[]    // sorted by requests desc; model may be "unknown"
}

Profile {
  uid: string
  displayName: string | null
  avatarId: string | null          // e.g. "kitsune" (see §10.6)
  level: JlptLevel | null
  learningReasons: string[]        // codes, e.g. "travel", "anime_manga", "career"
  interests: string[]              // ContentCategory codes
  preferences: object              // free-form; currently {"onboardingVersion": 1}
  subscriptionTier: SubscriptionTier
  createdAt: timestamp
  lastActiveAt: timestamp
}
UserListResponse { users: Profile[], total: int }
UserTierUpdate { subscriptionTier: SubscriptionTier }
```

Learning-reason codes and their labels: `travel` Travel · `anime_manga` Anime & Manga · `career` Work / Career · `school` School / Education · `living_in_japan` Living in Japan · `friends` Making Japanese friends · `hobby` Hobby / Personal interest · `media` Understanding Japanese media · `other` Other.

### 7.3 Endpoints

| Method & path | Query / body | Returns | Errors and notes |
|---|---|---|---|
| `GET /admin/taxonomy` | none | `TaxonomyResponse` | Also the admin probe (§5). `contentCount` covers every status. |
| `GET /admin/content` | `level?`, `category?`, `status?`, `q?` (≤ 100, matches title/description/channel), `limit` 1–200 (default 50), `offset` | `ContentListResponse` | Newest first. Includes drafts and archived. |
| `POST /admin/content` | `ContentCreate` | `201 ContentItem` | `409` duplicate id; `422` invalid (bad YouTube URL, unknown level or category, empty title…). |
| `GET /admin/content/{id}` | none | `ContentItem` | `404` |
| `PATCH /admin/content/{id}` | `ContentUpdate` | `ContentItem` | `404`, `422`. Use it for publish/archive too: `{"status": "archived"}`. |
| `DELETE /admin/content/{id}` | none | `204` | `404`. Permanent. Pinned sets that reference it simply skip it. |
| `GET /admin/recommendations` | `from?`, `to?` (`YYYY-MM-DD`; default today → +30 days) | `DailyRecommendationSetList` | Sorted by date, then level. `level` is null for all-levels sets. |
| `PUT /admin/recommendations` | `DailyRecommendationSet` | `DailyRecommendationSet` | Creates or **replaces** the set for that (`date`, `level`). `422` if any `contentIds` don't exist (`detail`: "unknown content ids: a, b"). |
| `DELETE /admin/recommendations/{date}` | `level?` (omit for the all-levels set) | `204` | `404` if no set is pinned. |
| `GET /admin/recommendations/current` | `level` (required), `day?` | `DailyRecommendations` | What a learner at that level, with no interests or history, sees. Real learners also get interest and history weighting. |
| `GET /admin/stats/users` | none | `UserStats` | |
| `GET /admin/stats/usage` | `granularity` (default `day`), `periods` 1–366 (default 30) | `UsageStats` | `series` is oldest first and ends with the current, partial period. Empty periods are included as zeros. |
| `GET /admin/stats/ai` | `granularity`, `periods` | `AiUsageStats` | Costs are **estimates** from configured rates. Tokens may be estimated when the provider doesn't report them. |
| `GET /admin/users` | `tier?`, `limit` 1–200, `offset` | `UserListResponse` | Newest first. **No emails and no name search.** |
| `GET /admin/users/{uid}` | none | `Profile` | `404` |
| `PATCH /admin/users/{uid}` | `UserTierUpdate` | `Profile` | `404`, `422` for an unknown tier. |

Also useful: `GET /health` returns `{status, dialogues}` with no auth. Use it to wake a sleeping server and show the connection status in Settings.

### 7.4 Recommendation semantics (the screens must explain these)

For a learner on a given UTC day, the server picks `DAILY_RECOMMENDATION_COUNT` videos (default 3) in this order:

1. The **pinned set for their level** on that day, or else the **all-levels pinned set**, in the pinned order. Deleted or unknown ids are skipped.
2. Unwatched published videos at their level, weighted towards their interests; then nearby levels, easier first.
3. Already-watched videos, only if nothing else is left.

So a level-specific pin **replaces** the all-levels pin for that level; the two are not merged. A pin with fewer ids than the count is topped up automatically. Picks are deterministic per learner per day and change daily.

---

## 8. Responsive layout

Use one widget tree, with breakpoints on the window width (`MediaQuery.sizeOf(context).width`):

| Width | Class | Navigation | Content |
|---|---|---|---|
| < 600 | **compact** (phones) | `NavigationBar` (bottom) with 4 items: Overview, Content, Recommendations, Analytics. A "More" item opens a sheet with Users and Settings. | Single column, cards instead of tables, full-screen forms, FAB for "New". |
| 600–1023 | **medium** (tablets, small windows) | `NavigationRail`, icons with labels | Two-column grids, compact tables, dialogs or side sheets for forms. |
| ≥ 1024 | **expanded** (desktop web) | Permanent sidebar (240 px): logo, sections, and the signed-in admin at the bottom | Top bar with page title, breadcrumbs and primary action. Data tables. A **master–detail** layout where it fits: list on the left, editor on the right (≥ 1280). Max content width 1440, centred. |

Build an `AdaptiveScaffold` widget in `shared/layout/` that picks the navigation for the width class. Each screen gets a `WindowClass` (from a small provider or an `InheritedWidget`) and lays itself out with a `switch`.

On **web/desktop**:
- Hover states on rows and cards.
- Keyboard: `/` focuses search, `N` creates new content, `Esc` closes a dialog or side sheet, `⌘/Ctrl+S` saves a form.
- Tooltips on icon buttons.
- Right-aligned numbers in tables.
- Selectable text for ids and uids.

On **mobile**:
- Pull-to-refresh on every list and on Overview.
- Large touch targets (≥ 48 px).
- Sticky bottom action bar in forms.
- Use the system back gesture with an unsaved-changes guard.

---

## 9. Routes

| Path | Screen |
|---|---|
| `/sign-in` | Sign in |
| `/not-authorized` | Not authorized |
| `/` | Overview |
| `/content?level=&category=&status=&q=&page=` | Content list |
| `/content/new` | Content editor (create) |
| `/content/:id` | Content editor (edit). On expanded windows it can open as the detail pane of `/content`. |
| `/recommendations?month=YYYY-MM` | Recommendations calendar |
| `/recommendations/:date` | Day detail, all levels for that date (`:date` = `YYYY-MM-DD`) |
| `/analytics/usage?granularity=&periods=` | Users and usage |
| `/analytics/ai?granularity=&periods=` | AI usage |
| `/users?tier=&page=` | Users list |
| `/users/:uid` | User detail |
| `/settings` | Settings |

Mirror filters and pagination in the query string, so a URL is shareable and reload-safe on web. View-models read their initial filters from the route and write changes back with `context.go`.

---

## 10. Screens: UI and UX

Every data screen has four states: **loading** (skeletons shaped like the content, never a lone spinner on a blank page), **empty** (an illustration or icon, one sentence, and a primary action), **error** (the message from §6.3 plus Retry), and **data**.

### 10.1 Sign in and Not authorized

- A centred card, max width 420. Logo mark: the app's gradient badge with a sprout icon (see `_badge` in the root `lib/features/auth/presentation/view/onboarding_view.dart`). Title: "ingrain admin".
- Google button first, then a divider, then email + password, then Sign in. Show inline errors under the fields. No sign-up link.
- Not authorized: a lock icon, "This account isn't an admin", the email, the uid in a monospace selectable chip with a copy button, a one-line explanation of `ADMIN_UIDS`, and Sign out.

### 10.2 Overview (`/`)

Purpose: answer "how is ingrain doing right now?" in five seconds.

- **KPI row** (4 cards; a 2×2 grid on compact): Total users (with a "+N new in 7 days" sub-line), Daily active (with weekly and monthly underneath), Paid users (and the % of total), AI cost in the last 30 days (with the request count). Data comes from `stats/users` and `stats/ai?granularity=day&periods=30`.
- **Active users, last 30 days**: a line chart from `stats/usage?granularity=day&periods=30`, with two series: active users (primary) and new users (accent). Tooltip on hover or tap.
- **Visits, last 30 days**: a bar chart from the same request.
- **Catalogue health**: published-video counts per level (bar or stacked chip row) from `admin/content?status=published&level=X&limit=1` (read `total`; one call per level, run in parallel). Flag any level with fewer than 3 published videos, because learners at that level get borrowed content.
- **Today's pins**: from `admin/recommendations?from=today&to=today`. "No pins today — learners get automatic picks" is fine. Add a link to the Recommendations screen.
- Each card links to its detail screen. On compact, show the cards in a vertical stack with charts at full width and 200 px tall.

### 10.3 Content

**List** (`/content`):
- **Toolbar**: a search field (300 ms debounce, sent as `q`), a Level filter (segmented `All N5 N4 N3 N2 N1`), a Category multi-select (the API accepts one category, so send it when exactly one is chosen and otherwise filter client-side on the current page; or keep it to a single-select dropdown, which is simpler — your choice, but be consistent), a Status filter (`All / Published / Draft / Archived`), and a **New video** primary button.
- **Expanded layout** — a table with these columns:
  - thumbnail (64×36, rounded; `resolvedThumbnailUrl`)
  - title, with the channel on a second muted line
  - level pill
  - category pills (max 2 + "+n")
  - duration
  - status badge
  - updated (relative time)
  - a row menu: Edit, Open on YouTube, Publish/Unpublish, Archive, Delete

  Click a row to open the editor in the right pane (≥ 1280) or navigate to it (below 1280). Pagination footer: "1–50 of 213", page size 25/50/100.
- **Compact layout**: cards with a 16:9 thumbnail, title, level + status + duration on one line, and a ⋮ menu. Infinite scroll in pages of 25. A FAB for New.
- **Status badge colours**: published = success green, draft = amber, archived = grey.

**Editor** (`/content/new`, `/content/:id`):

The fields, in order:
1. **YouTube URL**. When it's valid, show a live preview card (thumbnail from `https://i.ytimg.com/vi/<id>/hqdefault.jpg`, plus an embedded-player link). Validate client-side with the same rules as the server (watch / youtu.be / shorts / embed / live, 11-character id), but trust the server's `422`. Optional auto-fill: try `https://www.youtube.com/oembed?url=<url>&format=json` to prefill title, channel and thumbnail. **Check this works under CORS on web.** If it doesn't, skip auto-fill on web rather than adding a proxy.
2. **Title** (required, ≤ 200, with a counter).
3. **Description** (multiline, ≤ 4000, with a counter). Hint: "Shown to learners on the card — one or two sentences."
4. **Level**: a segmented control, each segment showing the code and title (N5 Beginner, N4 Elementary, N3 Intermediate, N2 Upper Intermediate, N1 Advanced).
5. **Categories**: a wrap of toggle chips, at least one recommended. Warn, but don't block, when none is chosen: "Uncategorised videos can't match learners' interests".
6. **Duration** (`mm:ss` or `h:mm:ss` input, stored as seconds).
7. **Channel**, and a **Custom thumbnail URL** in an "Advanced" expander.
8. **Status**: radio Draft / Published / Archived. New items default to **Draft**, with the hint "Learners only see published videos."
9. **ID**, also in "Advanced": shown on create, optional, validated against `^[a-z0-9][a-z0-9-]{0,63}$`. Read-only on edit.

Behaviour:
- Primary actions: **Save** (and "Save & publish" on drafts). On edit, send **only the changed fields** with PATCH.
- **Unsaved-changes guard** on navigation, back, and tab close (web: `beforeunload` via `PopScope` plus a web-only handler).
- **Delete** sits in a "Danger zone" at the bottom. The confirm dialog suggests archiving instead, and says pinned sets will skip the video. On web, require typing the title for videos that are published. A plain confirm is fine elsewhere.
- Show `createdAt` and `updatedAt` as muted metadata.

### 10.4 Recommendations

**Calendar** (`/recommendations?month=`):
- Expanded: a month grid. Each day cell shows small level chips for pinned sets (`ALL` in neutral, `N5`…`N1` in level colours), with a count dot. Today is outlined. Past days are dimmed and read-only, but still viewable. Month navigation arrows and a Today button. A side panel shows the selected day.
- Compact: a vertical **agenda list** of the next 30 days (`GET /admin/recommendations` default range). Days without pins collapse into "Mon 7 – Wed 9: automatic picks".
- Load one month with `from`/`to` = the month's first and last day.

**Day detail** (`/recommendations/:date`): six rows, one per target: **All levels**, then N5…N1.
- Each row shows the pinned videos (thumbnail strips in order, with the note) or "Automatic". If an all-levels set exists, show "Inherits All levels" on the level rows that have none.
- Row actions: **Pin videos / Edit**, **Unpin**, **Preview**.
- **Pin editor** (dialog on expanded, full screen on compact):
  - A content picker that searches published content (`GET /admin/content?status=published&q=&level=`). It defaults its level filter to the row's level, which you can change.
  - A selected list that is **reorderable** by drag, max 10.
  - A hint above it: "Learners see the first 3; extra pins are used if earlier ones are deleted."
  - A note field.
  - Save sends `PUT /admin/recommendations`. Surface a `422` "unknown content ids" message clearly, in case content was deleted meanwhile.
- **Preview** calls `GET /admin/recommendations/current?level=X&day=<date>` and shows the 3 cards with their `reason` badges (`curated` → "Pinned", `level` → "At level", `nearbyLevel` → "Nearby level", `interest` → "Interest", `rewatch` → "Rewatch"). Footnote: "Real learners also get interest and watch-history weighting."
- Explain the precedence rule (§7.4) in an info banner the first time someone opens the screen (dismissible; remember it in `shared_preferences`).

### 10.5 Analytics

Both pages share a toolbar: a granularity segmented control (Day / Week / Month) and a range select that maps to `periods`:

| Granularity | Ranges | Default |
|---|---|---|
| Day | 7 / 30 / 90 | 30 |
| Week | 12 / 26 / 52 | 12 |
| Month | 6 / 12 / 24 | 12 |

Label each period by its start: "7 Oct", "Wk of 6 Oct", "Oct 2026". Mark the last point as "in progress" (dashed segment or hollow point), because the current period is partial. State "All times in UTC" in the page footer.

**Users and usage** (`/analytics/usage`):
- KPI strip from `stats/users`: total, free, paid, a by-tier breakdown (a donut on expanded, a stacked bar on compact), new today / 7d / 30d, DAU / WAU / MAU, and a "stickiness" figure computed as DAU ÷ MAU, as a %.
- Charts from `stats/usage`: active users (line), new users (bars), visits (bars).
- A table view toggle (expanded) with a **Copy CSV** action. The CSV is generated client-side from the series.

**AI usage** (`/analytics/ai`):
- KPIs from `totals`: requests, failure rate (`failedRequests / requests`), input tokens, output tokens, estimated cost (currency, 4 decimal places when under $1), and average cost per request.
- Charts: estimated cost per period (bars), requests vs. failed (stacked bars), and tokens in vs. out (lines).
- A **By model** table: model, requests, failure %, input tokens, output tokens, cost, and share of cost (a bar inside the cell).
- Disclaimer text: "Costs are estimates from configured per-token rates, not provider billing."

### 10.6 Users

**List** (`/users`):
- Tier filter chips (All / Free / Premium).
- Expanded table columns: avatar (32 px), display name (or "Unnamed learner" in italic), level pill, interests (max 3 pills), tier badge, joined date, last active (relative). Paginated.
- Compact: list tiles with avatar, name, level and tier, plus "active 2h ago".
- No search (the API doesn't support it). Don't fake it client-side across pages.

**Detail** (`/users/:uid`):
- A header modelled on the learner's own profile page: a large avatar on a banner tinted with the avatar's colour, the name, the uid (monospace, copyable), and joined / last-active dates.
- Sections: Level, Learning reasons (with the labels from §7.2), Interests, Preferences (key/value), Subscription.
- **Change tier**: a segmented Free / Premium control with a confirm dialog, sent as `PATCH /admin/users/:uid`. After success, show a toast: "Tier updated. The learner sees it next time the app syncs."

**Avatars**: `avatarId` is one of `neko kitsune shiba tanuki panda usagi kuma kappa oni ninja daruma onigiri`; anything else falls back to `neko`. To match the learner app exactly, **copy** (don't import across packages) these two files:
- `lib/features/profile/domain/avatar_character.dart` (the catalogue)
- `lib/features/profile/presentation/widgets/avatar_painter.dart` (a `CustomPainter` with no external deps, and each character's background colour)

Put them in `ingrain_admin/lib/shared/avatar/`. Wrap them in an `AdminAvatar(avatarId, size)` widget modelled on `AvatarPortrait` in `learner_avatar.dart`. If copying proves awkward, use a fallback: a circle in the character's background colour with the character's name initial.

### 10.7 Settings

- The signed-in admin's email and uid, and Sign out.
- The API base URL (read-only) with a live status dot from `GET /health`, showing latency, plus a "Wake server" button.
- Theme: System / Light / Dark, remembered in `shared_preferences`.
- The app version.

---

## 11. Visual design system

Match the learner app so the product feels like one brand. The source of truth is the root `lib/app/theme/app_colors.dart` and `app_theme.dart`. Copy the token *values*; don't depend on the app package.

### 11.1 Colour tokens

| Token | Light | Use |
|---|---|---|
| primary | `#2F6FED` | Primary actions, active nav, links |
| primaryDark | `#12305E` | Headings on pale fills |
| primaryLight | `#9DB8F0` | Primary in dark mode |
| hero gradient | `#2F6FED → #7B5CFA` | Logo badge, Overview header accent, premium badge |
| background | `#F1F6FE` (dark `#0D1015`) | Scaffold |
| surface | `#FFFFFF` (dark `#161B24`) | Cards, tables, sidebar |
| textPrimary / secondary | `#141B2D` / `#5B6577` | |
| outline | `#DCE2EC` (dark `#39414F`) | Hairlines, table dividers |
| success | `#188857` | Published, healthy |
| warning | `#B25E00` | Draft, cautions |
| error | `#B3261E` | Destructive, failures |

Accent hues, one per kind of thing. Use them for chart series and category pills:
- video `#FF5A5F`
- podcast `#9B5DE5`
- dialogue `#00B894`
- review/amber `#FFA62B`
- streak `#FF7A45`
- vocabulary `#F15BB5`
- sky `#00A6ED`

**Level colours** (keep them identical to the app): N5 `#00B894` · N4 `#00A6ED` · N3 `#2F6FED` · N2 `#9B5DE5` · N1 `#F15BB5`.

**Category colours** (as in the app's `learner_preference_style.dart`):
- anime `#FF5A5F`
- youtube `#E53935`
- podcasts `#9B5DE5`
- music `#F15BB5`
- news `#2F6FED`
- conversations `#00B894`
- travel `#00A6ED`
- reading `#FFA62B`
- gaming `#FF7A45`
- culture `#D1495B`

Dark mode is required. Build both themes from `ColorScheme.fromSeed(seedColor: #2F6FED)` with the overrides above, as `app_theme.dart` does.

### 11.2 Shape, type and spacing

- Material 3. **Fills rather than outlines**: tinted surfaces (accent at 10–16 % alpha) for chips, stat tiles and badges, in the style of the app's `TintedSurface`, `Pill` and `IconBadge`.
- Radii: cards 18–20, chips and pills 999, inputs 12–16, dialogs 24. Elevation 0, with depth from fills and hairlines. App bars have no shadow.
- Type: the default Material type scale, `headlineSmall` w700 at −0.3 tracking for page titles, `titleMedium` w600 for card titles. Use tabular figures (`FontFeature.tabularFigures()`) for every number in tables and KPIs.
- Spacing on a 4/8 grid. Page padding: 16 on compact, 24 on medium, 32 on expanded. Card padding 16–20. Grid gaps 12–16.
- **KPI card**: an icon badge (accent tint), the label (bodySmall, muted), the value (headlineSmall, tabular), and a delta or sub-line (labelSmall; green up, red down, only when meaningful).
- **Charts**: no chart junk. Light horizontal gridlines only, axis labels in muted bodySmall, primary for the main series and accent hues for the others, consistent per metric across pages. Show a legend only with two or more series. Tooltips show the exact value with the period label.

### 11.3 Accessibility

- Contrast ≥ 4.5:1 for text. Never use colour as the only signal: status badges carry text, and chart series differ in shape or dash as well as colour.
- Semantic labels on icon buttons and charts (a chart's semantics label summarises it: "Active users, last 30 days, latest 42").
- Logical focus order and visible focus rings on web. Respect text scaling up to 1.3× without clipping.

---

## 12. Known API gaps: don't work around them, propose them

Write each of these in your final report as a proposed backend change. Implement none of them in the backend unless the user asks.

1. **No `GET /admin/me`.** Admin status is probed via `/admin/taxonomy` (§5). That's fine for now.
2. **No user search, and no email or provider in profiles.** The users list is browse-only.
3. **No bulk content operations** (multi-select publish/archive/delete). One request per item. If you add multi-select, run the requests sequentially with progress, and report partial failures.
4. **Category filter takes one value.**
5. **No YouTube metadata endpoint.** Client-side oEmbed is best-effort (§10.3).
6. **No audit log** of who changed what.
7. **Ephemeral database on Render's free plan.** Show a dismissible warning banner on Overview when `GET /admin/stats/users` reports `totalUsers == 0` and the content count equals the seed count (53), because the server may have just been reset.

---

## 13. Quality bar and definition of done

### Tests

Run everything in `ingrain_admin/` with `flutter test`. Nothing may touch the network: override the repository providers in tests, and use `http_mock_adapter` for the `ApiClient`.

- **Unit tests**: every DTO round-trips the JSON shapes in §7.2, including null/absent fields and unknown enum values. Error mapping covers every row of the §6.3 table, including both `detail` forms. Each view-model covers filter → request params, pagination, save/patch diffs (PATCH sends only changed fields), and invalidation after mutations.
- **Widget tests**:
  - The admin gate: 200 → app, 403 → Not authorized, 401 → refresh-and-retry.
  - The content editor's validation and save.
  - Pin editor reordering and the 10-item limit.
  - The tier-change confirmation.
- **Layout tests**: each main screen at **390×844** (phone), **820×1180** (tablet) and **1440×900** (desktop) with no overflow (`tester.takeException()` is null). Check that the correct navigation appears at each size.

### Analysis

`flutter analyze` must be clean with `flutter_lints`.

### Builds

`flutter build web --release` and `flutter build apk --debug` both succeed. iOS is best-effort, depending on Firebase config (§3).

### Manual check against a local backend

Run the backend with your uid in `ADMIN_UIDS`, then:
1. Sign in, and confirm the Overview shows the catalogue counts.
2. Create a draft, publish it, edit its level, archive it, and delete it.
3. Pin a set for tomorrow for N4, plus an all-levels set. Preview N4 and N3 and confirm the precedence rule.
4. Flip a user's tier and see the paid count change on Overview.
5. Repeat the main flows in a narrow browser window and on an Android emulator.

### Deliverables

- The `ingrain_admin/` project.
- `ingrain_admin/README.md` covering setup, Firebase configuration, run/build commands, the `API_BASE_URL` define, how to become an admin (`ADMIN_UIDS` or the custom claim), and the screen map.
- A final report: what you built, how you verified it, and the §12 proposals. List anything you couldn't verify (e.g. iOS) explicitly.

---

## 14. Suggested file structure

```
ingrain_admin/
├── lib/
│   ├── main.dart                        # Firebase.initializeApp, ProviderScope, runApp
│   ├── firebase_options.dart            # flutterfire-generated
│   ├── app/
│   │   ├── app.dart                     # MaterialApp.router, themes
│   │   ├── router.dart                  # GoRouter, guards, routes (§9)
│   │   └── theme/
│   │       ├── admin_colors.dart        # tokens (§11.1)
│   │       └── admin_theme.dart         # light/dark ThemeData
│   ├── core/
│   │   ├── config/api_config.dart
│   │   ├── error/app_error.dart         # AppError, ApiException, field errors
│   │   ├── network/
│   │   │   ├── api_client.dart          # Dio setup, typed get/post/put/patch/delete
│   │   │   ├── auth_interceptor.dart    # bearer token + single 401 refresh
│   │   │   └── error_mapper.dart        # DioException → AppError (§6.3)
│   │   ├── format/                      # numbers, currency, dates, durations
│   │   ├── time/utc.dart
│   │   └── providers.dart               # firebaseAuth, dio/apiClient, prefs
│   ├── shared/
│   │   ├── layout/
│   │   │   ├── window_class.dart        # compact/medium/expanded
│   │   │   └── adaptive_scaffold.dart   # bottom bar / rail / sidebar
│   │   ├── widgets/                     # KpiCard, TintedSurface, Pill, StatusBadge,
│   │   │                                # LevelPill, CategoryPill, EmptyState, ErrorState,
│   │   │                                # Skeleton, ConfirmDialog, PaginationBar,
│   │   │                                # FilterBar, UnsavedChangesGuard
│   │   ├── charts/                      # TimeSeriesLineChart, PeriodBarChart, DonutChart
│   │   └── avatar/                      # copied avatar_character + avatar_painter, AdminAvatar
│   └── features/
│       ├── auth/
│       │   ├── domain/   admin_session.dart, auth_repository.dart
│       │   ├── data/     firebase_admin_auth_repository.dart
│       │   └── presentation/ sign_in_view.dart, not_authorized_view.dart,
│       │                     admin_session_view_model.dart
│       ├── taxonomy/     domain/, data/, presentation/taxonomy_provider.dart
│       ├── overview/     presentation/ overview_view.dart, overview_view_model.dart
│       ├── content/
│       │   ├── domain/   content_item.dart, content_enums.dart, content_repository.dart
│       │   ├── data/     content_dto.dart, remote_content_repository.dart
│       │   └── presentation/ content_list_view.dart, content_list_view_model.dart,
│       │                     content_editor_view.dart, content_editor_view_model.dart,
│       │                     widgets/ (content_table.dart, content_card.dart,
│       │                               youtube_preview.dart, level_selector.dart)
│       ├── recommendations/
│       │   ├── domain/   daily_set.dart, daily_preview.dart, recommendations_repository.dart
│       │   ├── data/     recommendations_dto.dart, remote_recommendations_repository.dart
│       │   └── presentation/ calendar_view.dart, day_detail_view.dart,
│       │                     pin_editor_sheet.dart, preview_panel.dart, *_view_model.dart
│       ├── analytics/
│       │   ├── domain/   user_stats.dart, usage_stats.dart, ai_usage_stats.dart,
│       │   │             stats_repository.dart
│       │   ├── data/     stats_dto.dart, remote_stats_repository.dart
│       │   └── presentation/ usage_view.dart, ai_usage_view.dart, range_toolbar.dart,
│       │                     *_view_model.dart
│       ├── users/
│       │   ├── domain/   learner_profile.dart, users_repository.dart
│       │   ├── data/     profile_dto.dart, remote_users_repository.dart
│       │   └── presentation/ users_list_view.dart, user_detail_view.dart, *_view_model.dart
│       └── settings/     presentation/ settings_view.dart
├── test/                                # mirrors lib/; support/ for fakes and pump helpers
├── web/                                 # index.html title "ingrain admin", favicon
└── README.md
```

---

## 15. Suggested order of work

1. Scaffold the project, add dependencies, set up the theme, and build `AdaptiveScaffold` with placeholder pages at all three window sizes.
2. Build `core/network` and the error mapping, with their tests.
3. Build auth and the admin gate, and the router guard, with their tests. **Checkpoint**: a real sign-in against the local backend.
4. Build taxonomy and content (list, editor, delete), with tests.
5. Build the recommendations calendar, day detail, pin editor and preview.
6. Build the analytics pages, then Overview, which reuses their repositories.
7. Build users and settings.
8. Do the responsive and accessibility pass at all three sizes, run the builds, write the README, and write the final report.

Keep each step shippable, and run `flutter analyze` and `flutter test` before moving on.
