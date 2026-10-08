import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/srs/presentation/view/anki_import_unsupported.dart';

// Web builds get this stand-in instead of the real importer (see
// `anki_import.dart`): browsers cannot run the native SQLite it needs. Tests run
// natively, so the stand-in is exercised directly.
void main() {
  testWidgets('web explains that Anki import is in the mobile app', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => startAnkiImport(context),
            child: const Text('Import'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(find.text('Import from the mobile app'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
