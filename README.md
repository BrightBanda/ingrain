# ingrain

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Deploying the web app

`render.yaml` is a Render Blueprint for the web build, as a static site.
In Render choose **New → Blueprint** and pick this repository.

- The build (`tool/render_build_web.sh`) installs the Flutter version pinned in
  `render.yaml`. Keep `FLUTTER_VERSION` in step with `flutter --version`.
- `API_BASE_URL` in `render.yaml` is the API the site talks to. It is baked in at
  build time, so redeploy after changing it.
- The API is deployed separately, from its own Blueprint in
  `Ingrained_backend/render.yaml`.
- After the first deploy, add the site's domain in the Firebase console under
  **Authentication → Settings → Authorized domains**, or Google sign-in fails.
- Not available on web: Anki import (mobile only), YouTube search, and
  transcripts. Browsers block requests to youtube.com from other sites.
