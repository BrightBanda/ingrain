#!/usr/bin/env bash
# Builds the Flutter web app on Render (see render.yaml).
#
# Render's build machines have no Flutter, so this installs the pinned SDK
# first. Keep FLUTTER_VERSION in step with the version used locally
# (`flutter --version`): a different SDK can resolve dependencies differently.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.4}"
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter-sdk}"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "Installing Flutter $FLUTTER_VERSION into $FLUTTER_DIR"
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --no-analytics >/dev/null
flutter --version

# The lockfile is the contract: fail rather than silently pick new versions.
flutter pub get --enforce-lockfile

flutter build web --release \
  --dart-define=API_BASE_URL="${API_BASE_URL:?Set API_BASE_URL in render.yaml or the dashboard}"
