import 'package:flutter/material.dart';

/// Explains that Anki import lives in the mobile app. Decks imported there sync
/// to the same account, so they appear here too.
Future<void> startAnkiImport(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    icon: const Icon(Icons.phone_android),
    title: const Text('Import from the mobile app'),
    content: const Text(
      'Anki decks can be imported in the ingrain app on Android or iOS. '
      'Once imported, they sync to your account and show up here too.',
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Got it'),
      ),
    ],
  ),
);
