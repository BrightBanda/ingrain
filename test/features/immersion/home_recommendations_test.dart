import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/dialogue/domain/dialogue.dart';
import 'package:ingrain/features/immersion/presentation/view/immersion_home_view.dart';

ContentItem _item(String id, {required int day, int seconds = 0}) =>
    ContentItem(
      id: id,
      sourceType: SourceType.youtube,
      sourceUrl: 'https://youtu.be/$id',
      title: id,
      totalImmersionSeconds: seconds,
      lastOpenedAt: DateTime(2026, 10, day),
    );

DialogueSummary _dialogue(String id) =>
    DialogueSummary(id: id, title: id, level: 'N5');

void main() {
  group('recentContent', () {
    test('orders by last opened, newest first, and caps the count', () {
      final items = [
        _item('a', day: 1),
        _item('c', day: 3),
        _item('b', day: 2),
      ];

      expect(recentContent(items, limit: 2).map((i) => i.id), ['c', 'b']);
    });
  });

  group('recommendedVideo', () {
    test('is null for an empty library', () {
      expect(recommendedVideo(const []), isNull);
    });

    test('prefers the least watched, then the newest', () {
      final items = [
        _item('watched', day: 5, seconds: 600),
        _item('old-fresh', day: 1),
        _item('new-fresh', day: 4),
      ];

      expect(recommendedVideo(items)?.id, 'new-fresh');
    });
  });

  group('dialogueOfTheDay', () {
    final dialogues = [_dialogue('b'), _dialogue('a'), _dialogue('c')];

    test('is null when there are no dialogues', () {
      expect(dialogueOfTheDay(const [], DateTime(2026, 10, 6)), isNull);
    });

    test('is stable within a day and ignores input order', () {
      final morning = dialogueOfTheDay(dialogues, DateTime(2026, 10, 6, 8));
      final evening = dialogueOfTheDay(
        dialogues.reversed.toList(),
        DateTime(2026, 10, 6, 22),
      );

      expect(morning?.id, evening?.id);
    });

    test('visits every dialogue over consecutive days', () {
      final seen = {
        for (var day = 1; day <= 3; day++)
          dialogueOfTheDay(dialogues, DateTime(2026, 10, day))!.id,
      };

      expect(seen, {'a', 'b', 'c'});
    });
  });
}
