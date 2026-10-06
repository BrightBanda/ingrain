/// Base URL of the ingrain API (dialogue catalogue and AI explanations).
///
/// Defaults to the deployed API on Render. Override with
/// `--dart-define=API_BASE_URL=...` to use a local server: the emulator
/// reaches the host at `http://10.0.2.2:8000`, and a phone over USB at
/// `http://127.0.0.1:8000` after `adb reverse tcp:8000 tcp:8000` (both are
/// set up in `.vscode/launch.json`).
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://ingrain-api-y6ia.onrender.com',
);
