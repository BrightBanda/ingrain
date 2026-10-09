# HitaruJP Website — Implementation Plan

The public website for HitaruJP: a fast, static landing site that shows what the platform is about and gets people started. There are three exits, and nothing else:

- **Get started** → create an account in the web app
- **Log in** → sign in to the web app
- **Download** → the mobile apps

The site has no accounts, forms or app features of its own. It does **not** replace the Flutter web app; it points to it (§5.4).

| | |
|---|---|
| **Stack** | Astro (static output) + Tailwind CSS v4 + TypeScript |
| **Lives in** | `ingrain_site/` at the repo root, next to the app and `Ingrained_backend/` |
| **Hosted on** | Render, as a static site in the root `render.yaml` Blueprint |
| **Domains (proposed)** | `hitarujp.app` → website · `app.hitarujp.app` → Flutter web app · API unchanged |

---

## 1. Goals

1. **Explain HitaruJP in one screen.** Learn Japanese from real videos at your level, with a tappable transcript, AI explanations and spaced-repetition flashcards.
2. **Convert.** The primary action is **Get started**, which creates an account in the web app. **Log in** is for returning learners. The store badges download the mobile app.
3. **Be found.** Pages are crawlable, with real text, structured data and guide content ("What is JLPT N5?", "How to learn Japanese with anime"). The Flutter web app can't do this.
4. **Be trustworthy.** Host a privacy policy, terms, and a contact address. The app stores and Google's OAuth consent screen require a public privacy policy, and **none exists yet**.
5. **Feel like the app.** Same colours, shapes, characters and the seigaiha wave, so moving from the site into the app feels seamless.

**Success measures** (from analytics, see §11):
- Clicks on "Get started" and "Log in"
- Store-badge clicks
- Lighthouse ≥ 95 in every category on mobile

---

## 2. Tech stack

| Concern | Choice | Why |
|---|---|---|
| Framework | **Astro**, current major, `output: 'static'` | Plain HTML out, no JavaScript unless a component asks for it. Pages, layouts, Markdown and build-time data fetching built in. |
| Styling | **Tailwind CSS v4** via `@tailwindcss/vite` | CSS-first config: the app's tokens become `@theme` variables (§4). No component library, so no generic look. |
| Language | TypeScript (strict) | Types for the API response and content collections |
| Content | **Astro content collections** (Markdown + Zod schemas) | Guides, FAQ entries and legal pages as files, validated at build time |
| Images | `astro:assets` (`<Image>` / `<Picture>`) | AVIF and WebP output, explicit sizes, lazy loading |
| Icons | `astro-icon` + `@iconify-json/material-symbols` | The same Material icon family the app uses, inlined as SVG, with no icon font to download |
| Fonts | **Fontsource**, self-hosted (§4.3) | No Google Fonts request (privacy, speed). Japanese glyphs are split into subsets. |
| Interactivity | Vanilla TypeScript in `<script>` tags | The only interactive parts are the theme toggle, the mobile menu and a tiny kana demo; none need React. If something grows, use a **Preact** island, never React. |
| Sitemap / SEO | `@astrojs/sitemap`, hand-written `<head>` component | |
| Quality | `astro check`, Prettier + `prettier-plugin-astro`, ESLint, Lighthouse CI, a link checker | §13 |

**Ruled out:**
- **No CMS for now.** Markdown in git is enough until someone non-technical edits copy. If that happens, add a git-based CMS (Decap or Keystatic) on the same collections.
- **No UI kit** (daisyUI, Bootstrap). It would fight the app's design language.

---

## 3. Project structure

```
ingrain_site/
├── astro.config.mjs          # site URL, sitemap, Tailwind vite plugin, image settings
├── package.json              # pinned versions; "engines": { "node": ">=22" }
├── tsconfig.json             # strict
├── public/
│   ├── favicon.svg           # sprout mark on the hero blue
│   ├── apple-touch-icon.png
│   ├── og/                   # 1200×630 share images per page
│   └── robots.txt
├── src/
│   ├── styles/
│   │   └── global.css        # @import "tailwindcss"; @theme tokens; base styles
│   ├── layouts/
│   │   ├── BaseLayout.astro  # <html>, <head> (SEO), theme script, Nav, Footer
│   │   └── ProseLayout.astro # guides and legal pages: readable column, typography
│   ├── components/
│   │   ├── Nav.astro  Footer.astro  ThemeToggle.astro
│   │   ├── Button.astro  Pill.astro  IconBadge.astro  TintedCard.astro
│   │   ├── HeroPanel.astro   # blue gradient + seigaiha (see §4.5)
│   │   ├── Seigaiha.astro    # the wave as an inline SVG <pattern>
│   │   ├── LevelBadge.astro  LevelBars.astro
│   │   ├── VideoCard.astro   # catalogue video: thumbnail, level, category
│   │   ├── AvatarGrid.astro  # the 12 characters
│   │   ├── KanaDemo.astro    # tap-to-mark mini board (one <script>)
│   │   ├── PhoneFrame.astro  # screenshot in a device frame
│   │   ├── StoreBadges.astro # live links, or "Coming soon"
│   │   ├── FeatureRow.astro  SectionHeader.astro  Faq.astro  Cta.astro
│   │   └── Seo.astro         # title, description, canonical, OG, JSON-LD
│   ├── content/
│   │   ├── config.ts         # collections: guides, faq, legal (Zod schemas)
│   │   ├── guides/*.md
│   │   ├── faq/*.md
│   │   └── legal/privacy.md, terms.md
│   ├── data/
│   │   ├── catalog.ts        # build-time fetch from the API (§7)
│   │   ├── fallback-videos.json   # used when the API is unreachable at build
│   │   ├── levels.ts         # N5–N1 titles and descriptions (same text as the app)
│   │   └── site.ts           # URLs: app, stores, contact, socials
│   ├── assets/
│   │   ├── avatars/*.png     # exported from the app's painter (§8)
│   │   └── screenshots/*.png # real device screenshots (§8)
│   └── pages/
│       ├── index.astro
│       ├── features.astro
│       ├── levels.astro
│       ├── pricing.astro
│       ├── faq.astro
│       ├── download.astro
│       ├── guides/index.astro
│       ├── guides/[slug].astro
│       ├── privacy.astro  terms.astro  contact.astro
│       └── 404.astro
└── tests/                    # Playwright smoke tests (optional, §13)
```

---

## 4. Design system ("themes")

The source of truth is the app's `lib/app/theme/app_colors.dart`. Copy the *values*; never invent new hues for the site.

### 4.1 Colour tokens (`src/styles/global.css`)

```css
@import "tailwindcss";

@theme {
  /* Brand */
  --color-brand: #2f6fed;          /* primary: buttons, active states, icons */
  --color-brand-ink: #1f5bd6;      /* brand-coloured TEXT and links (see contrast note) */
  --color-brand-deep: #12305e;     /* headings on pale fills */
  --color-brand-soft: #9db8f0;     /* brand in dark mode */
  --color-hero-from: #5094f7;      /* hero gradient: light sky blue… */
  --color-hero-to: #2f6fed;        /* …into the brand blue (one hue, no violet) */

  /* Surfaces */
  --color-canvas: #f1f6fe;         /* page background */
  --color-surface: #ffffff;        /* cards */
  --color-ink: #141b2d;            /* body text */
  --color-ink-muted: #5b6577;
  --color-line: #dce2ec;

  /* Accents: one hue per kind of thing, as in the app */
  --color-video: #ff5a5f;
  --color-podcast: #9b5de5;
  --color-dialogue: #00b894;
  --color-review: #ffa62b;
  --color-streak: #ff7a45;
  --color-vocab: #f15bb5;
  --color-sky: #00a6ed;

  /* JLPT levels (identical to the app) */
  --color-n5: #00b894;
  --color-n4: #00a6ed;
  --color-n3: #2f6fed;
  --color-n2: #9b5de5;
  --color-n1: #f15bb5;

  /* Kana knowledge */
  --color-somewhat: #f5b90f;
  --color-known: #22b573;

  /* Shape */
  --radius-card: 1.25rem;          /* 20px */
  --radius-hero: 1.75rem;          /* 28px */
  --radius-tile: 0.875rem;         /* 14px: kana tiles, small cards */

  /* Type */
  --font-sans: "Inter Variable", "Noto Sans JP", system-ui, sans-serif;
  --font-jp: "Noto Sans JP", "Hiragino Sans", "Yu Gothic", sans-serif;
}
```

**Dark theme:** redefine the surface and ink tokens under `[data-theme="dark"]` and `@media (prefers-color-scheme: dark)`, using the app's dark values:
- canvas `#0d1015`
- surface `#161b24`
- ink `#e3e8f0`
- line `#39414f`
- brand `#9db8f0` for text, `#2f6fed` for fills

The theme toggle stores `system | light | dark` in `localStorage`. A small inline script in `<head>` sets `data-theme` *before* first paint, so pages don't flash the wrong theme.

### 4.2 Contrast rules (measured)

| Pair | Ratio | Rule |
|---|---|---|
| White on `#2f6fed` (brand) | 4.55 | OK for all text: buttons, hero body copy on the darker side |
| White on `#5094f7` (hero light end) | **3.03** | **Large text only** (≥ 24px, or ≥ 19px bold). Body copy in the hero must sit over the darker half, or the gradient goes to `#2f6fed` behind it. |
| `#2f6fed` on canvas `#f1f6fe` | **4.19** | **Not for small text.** Use `--color-brand-ink` (`#1f5bd6`) for links and brand-coloured text. |
| Level and accent hues | — | Use only as fills or tints with dark text, or as icons. Never as small text on white. |

### 4.3 Typography

- **Latin:** Inter (variable), self-hosted. Headings weight 700–800 with tight tracking (−0.02em), matching the app's `headlineSmall` feel. Body 16–18px, line-height 1.6.
- **Japanese:** Noto Sans JP via Fontsource's **unicode-range subsets**. The browser downloads only the slices a page uses (a full CJK font is several MB). Use `font-display: swap`.
- **Scale:** 14 / 16 / 18 / 20 / 24 / 30 / 36 / 48 / 60. Hero headline: 48–60 on desktop, 36 on mobile.
- **Japanese as decoration:** large kana and kanji (あ, 日本語, 藍) in the hero and section headers, set in `--font-jp` at low opacity. The app's profile banner does the same.

### 4.4 Shape, depth and spacing

- **Fills, not borders or shadows.** Tinted surfaces (the accent at 10–16% opacity) for cards, pills and icon badges, like the app's `TintedSurface`, `Pill` and `IconBadge`. Cards are white on the pale-blue canvas with a 1px `--color-line` border only where needed.
- **Radii:** cards 20px, hero 28px, pills fully rounded, buttons 14–16px.
- **Spacing:** a 4/8 grid. Section padding 96px top/bottom on desktop, 64px on mobile. Content max-width 1200px; prose 680px.
- **Motion:** gentle only, via CSS. Fade-and-rise on scroll (`IntersectionObserver` + a class) and the kana tiles' colour transition. All of it is disabled under `prefers-reduced-motion`.

### 4.5 The signature: seigaiha (青海波) hero

The app draws the wave with a Flutter painter. On the web, draw it as an **SVG `<pattern>`** with the same rules:
- rows of circles, each holding four concentric rings
- each row offset by one radius
- later rows cover earlier ones

To get the overlap in pure SVG, give every scale a fill in the panel colour and draw the rows top to bottom. White strokes, around 20% opacity. Fade it in from the left with `mask-image: linear-gradient(to right, transparent 25%, black)`, as the app does, so text stays clean.

`HeroPanel.astro` is the gradient (`--color-hero-from` → `--color-hero-to`, top-left to bottom-right) plus the masked wave. Reuse it for the hero, the pricing highlight and the closing call to action, nothing else, so it stays special.

### 4.6 Components (each maps to an app element)

| Site component | App equivalent | Notes |
|---|---|---|
| `Button` (primary, secondary, ghost) | `FilledButton` | Primary: brand fill, white text, 52px tall on mobile |
| `Pill` | `Pill` | Tinted; label ellipsizes |
| `IconBadge` | `IconBadge` | Rounded square, tinted, Material Symbol |
| `LevelBadge` + `LevelBars` | Level cards and bars | Code, title and five bars |
| `VideoCard` | Today's-picks card | 16:9 thumbnail, level pill, category pill, duration |
| `KanaDemo` | Kana board | 10 tiles: tap to mark somewhat (yellow), tap again for known (green). One `<script>`, no framework. |
| `AvatarGrid` | Onboarding avatar picker | The 12 characters with names and kana |
| `PhoneFrame` | — | Real screenshots in a simple frame |

---

## 5. Pages and sections

### 5.1 Home (`/`)

1. **Nav:**
   - Left: the logo (sprout on the hero blue) + "HitaruJP".
   - Middle links: Features, Levels, Pricing, Guides.
   - Right: **Log in** (text button) and **Get started** (primary button). Both go to the web app (§5.4).
   - Mobile: a menu button opens a sheet.
2. **Hero** (`HeroPanel`):
   - Headline, e.g. *"Learn Japanese from the videos you'd watch anyway."*
   - A subline about real YouTube, podcasts and anime-style content at your JLPT level, with a tap-anything transcript.
   - **Get started — it's free** (primary) and **I already have an account** (secondary, logs in), with the store badges below.
   - Right side: a phone screenshot of the player with its transcript, with a tilted second screenshot (kana board) behind it.
   - Large faint あ / 日本語 glyphs in the background.
3. **Social proof strip:** start with facts that are true now, e.g. "53 hand-picked videos across N5–N1 · New picks every day · Free to start". Add user counts or testimonials only once they're real.
4. **How it works** (3 steps, icon badges):
   1. Tell us your level and interests, with the onboarding screenshot.
   2. Watch today's picks, with the home screenshot.
   3. Tap any word and keep it, with the transcript and flashcards screenshot.
5. **Real videos at every level:** level tabs N5–N1. Each tab shows 3–6 `VideoCard`s **fetched from the API at build time** (§7). Each card links to the web app (`/content/...` once the app supports deep links; until then, to the app home).
6. **Feature rows** (alternating image/text):
   - tappable transcript with dictionary lookup
   - AI explanations (grammar, nuance, formality)
   - flashcards with spaced repetition and Anki import (mobile)
   - kana board with the self-marking demo (`KanaDemo` lives here)
   - progress and streaks
7. **Meet your character:** `AvatarGrid` with the 12 characters, and the line "Pick a character on day one. They're with you on every screen."
8. **Levels at a glance:** N5–N1 cards with the same plain-language descriptions as onboarding, plus "Not sure? Start at N5 and change any time." Links to `/levels`.
9. **Pricing teaser:** Free vs Premium in two cards, linking to `/pricing`.
10. **FAQ:** 5–6 questions as `<details>` (native, accessible, no JavaScript).
11. **Final call to action** (`HeroPanel`, compact): "Your first video is waiting." Get started + store badges.
12. **Footer:**
    - Columns: Product, Learn (guides), Company (contact), Legal (privacy, terms).
    - The theme toggle.
    - © line.

### 5.2 Other pages

| Page | Content |
|---|---|
| `/features` | Each feature in depth, with screenshots. Web vs mobile availability, stated honestly: Anki import is mobile-only, and YouTube search and transcripts are limited on web. |
| `/levels` | One section per JLPT level: what you can understand, the kind of content we pick, sample videos (build-time fetch). Strong SEO page ("JLPT N5 listening practice"). |
| `/pricing` | Free vs Premium table. **Premium features and prices are your decision** (§15). The backend already tracks tiers. |
| `/faq` | The full FAQ from the `faq` collection, with `FAQPage` JSON-LD. |
| `/download` | Store badges (or "Coming soon" with an email-me link), plus "Use it in your browser now" (Get started). |
| `/guides`, `/guides/[slug]` | Markdown guides, e.g. "What is JLPT N5?", "Learning Japanese with anime: a realistic plan", "Hiragana in a week", "How spaced repetition works". Phase 2. |
| `/privacy`, `/terms` | **Required.** See §10. |
| `/contact` | An email address (or a simple mailto form). Required by the stores. |
| `/404` | A friendly character ("Kitsune can't find that page"), with links home and to the app. |

### 5.3 Calls to action, everywhere

| Placement | Primary | Secondary |
|---|---|---|
| Nav (all pages) | Get started | Log in |
| Hero | Get started — it's free | I already have an account |
| Video cards, feature rows | Get started (as "Watch this in HitaruJP") | — |
| Final call to action, `/download` | Get started | Store badges |
| Mobile nav sheet | Get started (full width) | Log in, Download |

All URLs come from one file, `src/data/site.ts`, so they change in one place:

```ts
export const appUrl = import.meta.env.PUBLIC_APP_URL; // https://app.hitarujp.app
export const links = {
  getStarted: `${appUrl}/#/onboarding?mode=signup`,
  logIn: `${appUrl}/#/onboarding?mode=signin`,
  playStore: '…', // or null → "Coming soon"
  appStore: '…',
};
```

### 5.4 Hand-off to the web app

Sign-up and sign-in happen **in the web app, never on the landing site**. The buttons are plain links. This keeps one authentication system (Firebase, configured once), one set of authorised domains, and no credentials passing through the marketing site.

What happens on click:

| Visitor | Clicks | Lands on |
|---|---|---|
| New | Get started | The app's sign-in screen in **Create account** mode, then onboarding |
| Returning, signed out | Log in | The app's sign-in screen in **Sign in** mode |
| Already signed in (session in the browser) | Either | Straight to their home screen. The app's router already redirects onboarded users away from `/onboarding`. |
| On a phone | Store badge | The store listing |

**Required change in the Flutter app** (small, about an hour with a test). Today the sign-in screen always opens in sign-in mode. It should read a `mode` query parameter:

- `/onboarding?mode=signup` opens **Create account**
- `/onboarding?mode=signin`, or no parameter, opens **Sign in**

Change two places:
1. **Router:** pass `state.uri.queryParameters['mode']` into `OnboardingView`.
2. **`OnboardingView`:** use it to set the initial `_isCreateMode`.

Keep the parameter through the auth redirect, so a deep link survives a cold start.

**Optional:** switch the web app to path URLs (`usePathUrlStrategy()` in `main.dart`). Links then become `app.hitarujp.app/onboarding?mode=signup` instead of `/#/onboarding…`. The web app's Render config already rewrites every path to `index.html`, so this works without hosting changes. If you do it, also add routes `/signup` and `/login` that redirect to the parameters above, for shorter links in emails and ads.

**Mobile visitors:** on phones, show the store badges more prominently than "Get started", above the fold. Optionally detect Android or iOS from the user agent to show only the matching badge. Use the Apple smart app banner meta tag once the App Store listing exists.

### 5.5 Voice and copy

- Warm, direct, encouraging. Short sentences.
- Japanese words appear with readings on first use (e.g. 青海波 *seigaiha*).
- Never overclaim: "learn from real videos", not "fluent in 30 days". No invented numbers or testimonials.
- Write the name as "HitaruJP" (capital H, capital JP), as in the app.

---

## 6. Responsive layout

Breakpoints match the app's thinking:

| Width | Layout |
|---|---|
| < 640 | Single column. Nav collapses to a menu. Phone screenshots shrink and go below the text. |
| 640–1023 | Two-column feature rows. Video cards in a 2-up grid. |
| ≥ 1024 | Full layout. Hero text and phone side by side. Video cards 3-up. |

Test at 360, 390, 768, 1024, 1280 and 1440 wide.

---

## 7. Real content from the API (build time)

`src/data/catalog.ts`:

- Calls the public `GET {API_BASE_URL}/content?level=N5&limit=6` (and N4…N1) **during the build**, not in the visitor's browser. It needs no auth, and the response is camelCase with `resolvedThumbnailUrl` ready to display.
- **Timeout of 60s with one retry.** The API is on Render's free plan and can take about 30s to wake.
- **Fallback:** if the API is unreachable or returns fewer than 3 items for a level, use `src/data/fallback-videos.json`. This is a committed snapshot; refresh it with `npm run snapshot`.
- **Freshness:** add a Render **deploy hook**, triggered daily by a scheduled GitHub Action, so the site picks up catalogue changes. (Once the admin dashboard exists, publishing could call the hook directly.)
- **Images:** YouTube thumbnails come from `i.ytimg.com`. Use `<img loading="lazy" width height>` with `hqdefault.jpg`. Add `i.ytimg.com` to Astro's `image.domains` only if you want them re-encoded; plain `<img>` is fine.
- **No YouTube iframes on the home page.** They are heavy. If a demo video is wanted, use the `lite-youtube` web component (loads only on click).

---

## 8. Assets

| Asset | How to produce it |
|---|---|
| **Avatars (12)** | Export from the app's painter so they're identical. Add a tiny Flutter script (`tool/export_avatars.dart`, run with `flutter test` and golden-file output, or a small `flutter run -d linux` utility) that renders each `AvatarPortrait` at 512×512 to PNG in `ingrain_site/src/assets/avatars/`. Astro converts them to AVIF/WebP. |
| **Screenshots** | Must be **real device or emulator screenshots**: test renders use a placeholder font. Capture at 1080×2400 from an emulator in light mode with seeded demo data: home, player with transcript, kana board, profile, onboarding level step. Add a dark-mode set later. |
| **Logo and favicon** | The sprout on the hero blue with the wave, as SVG (`favicon.svg`), plus a 180px Apple touch icon and a 512px PNG. |
| **Share images** | 1200×630 per main page: the hero blue + wave, the headline, and a character. Static PNGs first; optionally generate later with `astro-og-canvas`. |
| **Store badges** | The official Apple and Google badge artwork only, following their usage rules. |

---

## 9. SEO and metadata

- `Seo.astro` covers:
  - a unique `<title>` (≤ 60 characters) and meta description (≤ 155)
  - the canonical URL
  - Open Graph and Twitter card tags
  - `theme-color` (`#2f6fed`)
- **Structured data (JSON-LD):**
  - `Organization` (site-wide)
  - `SoftwareApplication` (home, download: name, category EducationalApplication, offers with free price, operating systems)
  - `FAQPage` (FAQ)
  - `Article` (guides)
- **Crawling:**
  - `@astrojs/sitemap`
  - `robots.txt` pointing to it
  - every page reachable from the nav or footer
- **Language:** `lang="en"`. Japanese snippets wrapped in `<span lang="ja">` so screen readers and search engines handle them correctly.
- **Later:** Japanese and Spanish versions via Astro's i18n routing (`/ja/…`) with `hreflang`.

---

## 10. Legal and privacy (required before store submission)

The Play Store, App Store and Google OAuth consent screen all need a **public privacy policy URL**. The policy must describe what the app actually does:

- **Accounts:** Firebase Authentication (Google, email/password).
- **Data stored per user in Firestore:** profile (display name, avatar, level, reasons, interests), vocabulary, flashcards, sessions, kana marks.
- **Data the API stores:** profile copy, activity days and visit counts, watch history of catalogue videos, AI request counts, tokens and estimated cost. **No email addresses are stored by the API.**
- **Third parties:** Google (Firebase, YouTube embeds, Gemini for AI explanations; text you ask about is sent to it), Render (hosting).
- **Rights:** data deletion requests (state the contact address), retention, children's use (state a minimum age).

**Terms** cover acceptable use, content belonging to its YouTube creators, and subscription terms once Premium exists.

> These need review by you, and ideally someone with legal knowledge, before publishing. A plan can describe what to disclose, but not provide legal advice.

---

## 11. Analytics (privacy-friendly)

- Use **Plausible** or self-hosted **Umami**: cookieless, so no cookie banner is needed. Add the script to `BaseLayout` with `defer`.
- **Track:**
  - pageviews
  - outbound clicks on Get started, Log in and the store badges, as custom events with a `location` property (nav, hero, video card, final CTA)
  - guide reads
- Never send personal data. Don't include analytics in the Flutter app as part of this work.

---

## 12. Performance and accessibility budgets

**Performance:**

| Metric | Target |
|---|---|
| Lighthouse (mobile) | ≥ 95 in every category |
| Largest Contentful Paint | < 2.0s on 4G |
| CLS | < 0.05: every image has width and height |
| JavaScript per page | < 20 KB (theme, menu, kana demo) |
| Home page weight | < 600 KB excluding lazy thumbnails |
| Fonts | Inter variable (one file) + Japanese subsets on demand |

**Accessibility (WCAG 2.2 AA):**
- the contrast rules in §4.2
- visible focus rings
- a skip link
- semantic landmarks
- `alt` text on every screenshot that describes what it shows
- `<details>` for the FAQ
- the menu toggles `aria-expanded`
- the kana demo is fully keyboard-operable (buttons with `aria-pressed`)
- reduced motion respected

---

## 13. Quality and testing

**Scripts:**
- `npm run dev`
- `npm run build` (runs `astro check` first)
- `npm run preview`
- `npm run lint`
- `npm run snapshot` (refreshes the fallback videos)

**CI (GitHub Actions, on pull requests touching `ingrain_site/**`):**
- install
- check
- build
- link check (`lychee` on `dist/`)
- Lighthouse CI against the built site, failing under the §12 budgets

**Optional:** Playwright smoke tests. The home page renders, Get started and Log in point at the right app URLs (§5.3), the theme toggle persists, the kana demo cycles states, and there is no horizontal scroll at 360px.

**Manual review:** each page at the §6 widths, in light and dark mode, plus a keyboard-only pass.

---

## 14. Deployment

Add a second service to the **root `render.yaml`** (the web-app Blueprint):

```yaml
  - type: web
    runtime: static
    name: ingrain-site
    rootDir: ingrain_site
    buildCommand: npm ci && npm run build
    staticPublishPath: dist
    buildFilter:
      paths:
        - ingrain_site/**
    envVars:
      - key: API_BASE_URL
        value: https://ingrain-api-y6ia.onrender.com
      - key: PUBLIC_APP_URL          # where Get started and Log in go
        value: https://app.hitarujp.app
      - key: NODE_VERSION
        value: "22"
    headers:
      - path: /_astro/*              # hashed build assets: cache forever
        name: Cache-Control
        value: public, max-age=31536000, immutable
      - path: /*
        name: X-Content-Type-Options
        value: nosniff
```

**Domains:**
- In Render, attach `hitarujp.app` (and `www` → redirect) to `ingrain-site`, and `app.hitarujp.app` to `ingrain-web`.
- Add `app.hitarujp.app` in Firebase → Authentication → Authorized domains. The marketing site itself needs no auth.

**Daily rebuild:** a scheduled GitHub Action calls the site's Render deploy hook (the hook URL is stored as a repository secret).

---

## 15. Decisions needed from you

1. **Domain name**: is it `hitarujp.app` or something else?
2. **Store status**: are the Play Store and App Store listings live? If not, show "Coming soon" with an email signup or just the web call to action.
3. **Premium**: what does it include, and what does it cost? Until decided, the pricing page can say "Free while in beta".
4. **Legal details**: company or person name, contact email, and minimum age for the privacy policy and terms.
5. **Screenshots**: who captures them, and is there a demo account with good seed data?
6. **Analytics**: Plausible (paid, hosted) or Umami (free, self-hosted)?
7. **Launch language**: English only first?

---

## 16. Phases

| Phase | Scope | Estimate |
|---|---|---|
| **0. App hand-off** | The `mode` parameter in the Flutter app (§5.4), with a test; optionally path URLs and `/signup`, `/login` | 1–2 hours |
| **1. Foundation** | Scaffold Astro + Tailwind, tokens and dark theme, fonts, `BaseLayout`, `Seo`, Nav/Footer, `HeroPanel` + seigaiha SVG, core components | 1–1.5 days |
| **2. Home page** | All home sections with placeholder screenshots, build-time catalogue with fallback, kana demo, avatar grid, FAQ | 2 days |
| **3. Required pages** | Privacy, terms, contact, download, 404; Features, Levels, Pricing | 1.5 days |
| **4. Assets** | Avatar export script, real screenshots, OG images, favicon set | 1 day (+ capture time) |
| **5. Ship** | Render service + domains, deploy hook + daily rebuild, analytics, Lighthouse/a11y pass, CI | 1 day |
| **6. Growth (later)** | Guides collection and first 4–6 guides, i18n, testimonials once real | ongoing |

The **minimum to launch** is phases 1–3 plus legal pages with real details, about 5 days of build time.
