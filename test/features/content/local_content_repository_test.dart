import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/core/storage/local_document_store.dart';
import 'package:ingrain/features/auth/data/local_auth_repository.dart';
import 'package:ingrain/features/content/data/local_content_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalDocumentStore store;
  late LocalContentRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = LocalDocumentStore(prefs);
    final auth = LocalAuthRepository(store);
    repository = LocalContentRepository(store, auth);
  });

  group('LocalContentRepository', () {
    test('extracts video ID correctly from standard YouTube URL', () async {
      final item = await repository.create(
        sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        title: 'Rickroll',
      );
      expect(item.id, 'dQw4w9WgXcQ');
    });

    test('extracts video ID from mobile share URL with tracking parameter before v', () async {
      final item = await repository.create(
        sourceUrl:
            'https://www.youtube.com/watch?si=1234567890123456&v=dQw4w9WgXcQ',
        title: 'Rickroll Mobile',
      );
      expect(item.id, 'dQw4w9WgXcQ');
    });

    test(
      'extracts video ID from youtu.be link with tracking parameter',
      () async {
        final item = await repository.create(
          sourceUrl: 'https://youtu.be/dQw4w9WgXcQ?si=abcdefghijklmnop',
          title: 'Rickroll Shortlink',
        );
        expect(item.id, 'dQw4w9WgXcQ');
      },
    );

    test('extracts video ID from mobile live stream URL', () async {
      final item = await repository.create(
        sourceUrl: 'https://www.youtube.com/live/dQw4w9WgXcQ?feature=share',
        title: 'Live Stream',
      );
      expect(item.id, 'dQw4w9WgXcQ');
    });

    test('extracts video ID from bare video ID', () async {
      final item = await repository.create(
        sourceUrl: 'dQw4w9WgXcQ',
        title: 'Bare ID',
      );
      expect(item.id, 'dQw4w9WgXcQ');
    });
  });
}
