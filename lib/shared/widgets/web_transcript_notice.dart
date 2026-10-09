import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ingrain/app/theme/app_colors.dart';

/// Warns web users that YouTube transcripts are less reliable in the browser.
///
/// On web, captions come through the server, which YouTube sometimes blocks,
/// so a video may arrive without its transcript. The mobile apps fetch
/// captions themselves and do not have this problem.
abstract final class WebTranscriptNotice {
  static const message =
      'Transcripts on the web might not work as intended. Use the HitaruJP '
      'mobile app for the full experience.';

  /// For a snackbar when a video was added on web without its transcript.
  static const missingTranscript =
      'No transcript for this video on the web. Use the HitaruJP mobile app '
      'for the full experience.';

  /// True where the warning applies. A getter so tests can read it.
  static bool get applies => kIsWeb;
}

/// The warning as an inline banner. Renders nothing off the web.
class WebTranscriptBanner extends StatelessWidget {
  /// Shows the banner even off the web, for tests and previews.
  final bool force;

  const WebTranscriptBanner({super.key, this.force = false});

  @override
  Widget build(BuildContext context) {
    if (!WebTranscriptNotice.applies && !force) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.review.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.review.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.phone_android, color: AppColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                WebTranscriptNotice.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
