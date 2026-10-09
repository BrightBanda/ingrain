import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/shared/widgets/web_transcript_notice.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

  testWidgets('on web, the banner points to the mobile app', (tester) async {
    await pump(tester, const WebTranscriptBanner(force: true));

    expect(find.text(WebTranscriptNotice.message), findsOneWidget);
    expect(WebTranscriptNotice.message, contains('mobile app'));
  });

  testWidgets('off the web it renders nothing', (tester) async {
    // Tests run natively, as the mobile app does.
    expect(WebTranscriptNotice.applies, isFalse);
    await pump(tester, const WebTranscriptBanner());

    expect(find.text(WebTranscriptNotice.message), findsNothing);
  });
}
