import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ingrain/core/error/app_error.dart';
import 'package:ingrain/core/network/api_client.dart';
import 'package:ingrain/features/auth/data/user_profile_dto.dart';
import 'package:ingrain/features/auth/domain/auth_state.dart';
import 'package:ingrain/features/auth/domain/user_profile.dart';
import 'package:ingrain/features/catalog/data/remote_catalog_repository.dart';
import 'package:ingrain/features/catalog/domain/catalog_video.dart';
import 'package:ingrain/features/profile/data/remote_profile_sync_repository.dart';
import 'package:ingrain/features/profile/domain/avatar_character.dart';
import 'package:ingrain/features/profile/domain/learner_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';

final created = DateTime.utc(2026, 1, 2, 3, 4, 5);
final completed = DateTime.utc(2026, 10, 7, 9);

UserProfile onboarded() => UserProfile(
  uid: 'u1',
  displayName: 'Aiko',
  createdAt: created,
  avatarId: 'kitsune',
  level: JlptLevel.n4,
  learningReasons: const [LearningReason.travel, LearningReason.animeManga],
  interests: const [ContentInterest.anime, ContentInterest.music],
  onboardingCompletedAt: completed,
  onboardingVersion: 1,
);

ApiClient api(MockClientHandler handler, {String? token = 'id-token'}) =>
    ApiClient(
      client: MockClient(handler),
      idToken: () async => token,
      baseUrl: 'https://api.example.test',
    );

http.Response json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

const picksBody = {
  'date': '2026-10-07',
  'validUntil': '2026-10-08T00:00:00Z',
  'level': 'N4',
  'items': [
    {
      'id': 'shun-hakone',
      'title': '箱根 Road-trip',
      'description': 'A road trip.',
      'level': 'N4',
      'categories': ['travel', 'not-a-category'],
      'videoUrl': 'https://www.youtube.com/watch?v=NlPLRfQwrD8',
      'youtubeId': 'NlPLRfQwrD8',
      'resolvedThumbnailUrl':
          'https://i.ytimg.com/vi/NlPLRfQwrD8/hqdefault.jpg',
      'durationSeconds': 1648,
      'channelTitle': 'Japanese with Shun',
      'reason': 'interest',
    },
  ],
};

void main() {
  group('UserProfileDto', () {
    test('round-trips every onboarding answer', () {
      final profile = onboarded();
      final stored = {
        'uid': 'u1',
        'createdAt': created.toIso8601String(),
        ...UserProfileDto.learnerFields(profile),
      };

      expect(UserProfileDto.fromMapSafe(stored), profile);
    });

    test('skips codes it does not know instead of failing', () {
      final profile = UserProfileDto.fromMapSafe({
        'uid': 'u1',
        'level': 'N9',
        'learningReasons': ['travel', 'telepathy'],
        'interests': ['anime', 42],
      })!;

      expect(profile.level, isNull);
      expect(profile.effectiveLevel, JlptLevel.n5);
      expect(profile.learningReasons, [LearningReason.travel]);
      expect(profile.interests, [ContentInterest.anime]);
    });

    test('never writes a subscription tier', () {
      final fields = UserProfileDto.learnerFields(
        onboarded().copyWith(subscriptionTier: SubscriptionTier.premium),
      );

      expect(fields.containsKey('subscriptionTier'), isFalse);
    });
  });

  group('onboarding completeness', () {
    test('needs a name and a completed onboarding', () {
      final legacy = onboarded().copyWith(onboardingCompletedAt: () => null);

      expect(onboarded().isOnboarded, isTrue);
      expect(legacy.isOnboarded, isFalse, reason: 'name-only legacy profile');
      expect(
        AuthState.ready(
          uid: 'u1',
          displayName: 'Aiko',
          profile: legacy,
        ).isOnboarded,
        isFalse,
      );
      expect(
        const AuthState.ready(uid: 'u1', displayName: 'Aiko').isOnboarded,
        isTrue,
        reason: 'without a loaded profile the name decides, as before',
      );
    });

    test('unknown avatar ids fall back to the default character', () {
      expect(AvatarCharacter.fromId('kitsune'), AvatarCharacter.kitsune);
      expect(AvatarCharacter.fromId('dragon'), AvatarCharacter.fallback);
      expect(AvatarCharacter.fromId(null), AvatarCharacter.fallback);
      expect(
        AvatarCharacter.values.map((c) => c.id).toSet().length,
        AvatarCharacter.values.length,
        reason: 'ids are stored in profiles, so they must be unique',
      );
    });
  });

  group('ApiClient', () {
    test('signs requests and maps failures to app errors', () async {
      late http.BaseRequest sent;
      final ok = api((request) async {
        sent = request;
        return json({'ok': true});
      });
      expect(await ok.get('/thing', query: {'a': 'b'}), {'ok': true});
      expect(sent.headers['Authorization'], 'Bearer id-token');
      expect(sent.url.toString(), 'https://api.example.test/thing?a=b');

      Future<AppErrorType> typeFor(int status) async {
        try {
          await api((_) async => json({}, status)).get('/x');
        } on ApiException catch (error) {
          return error.error.type;
        }
        fail('expected ApiException');
      }

      expect(await typeFor(401), AppErrorType.auth);
      expect(await typeFor(404), AppErrorType.notFound);
      expect(await typeFor(429), AppErrorType.rateLimited);
      expect(await typeFor(500), AppErrorType.unknown);
    });

    test('refuses to call without a signed-in user', () async {
      var called = false;
      final client = api((_) async {
        called = true;
        return json({});
      }, token: null);

      await expectLater(client.get('/x'), throwsA(isA<ApiException>()));
      expect(called, isFalse);
    });
  });

  group('RemoteCatalogRepository', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('parses daily picks and caches them for offline use', () async {
      final online = RemoteCatalogRepository(
        api((request) async {
          expect(request.url.path, '/recommendations/daily');
          return json(picksBody);
        }),
        FakeAuthRepository(uid: 'u1'),
        prefs,
      );

      final picks = await online.dailyPicks();

      expect(picks.date, DateTime.utc(2026, 10, 7));
      expect(picks.level, JlptLevel.n4);
      expect(picks.isCached, isFalse);
      final video = picks.videos.single;
      expect(video.youtubeId, 'NlPLRfQwrD8');
      expect(video.categories, [ContentInterest.travel]);
      expect(video.reason, PickReason.interest);
      expect(video.thumbnailUrl, contains('NlPLRfQwrD8'));

      final offline = RemoteCatalogRepository(
        api((_) async => throw http.ClientException('offline')),
        FakeAuthRepository(uid: 'u1'),
        prefs,
      );
      final cached = await offline.dailyPicks();
      expect(cached.isCached, isTrue);
      expect(cached.videos.single.id, 'shun-hakone');
    });

    test('rethrows when offline with nothing cached', () async {
      final offline = RemoteCatalogRepository(
        api((_) async => throw http.ClientException('offline')),
        FakeAuthRepository(uid: 'someone-else'),
        prefs,
      );

      await expectLater(offline.dailyPicks(), throwsA(isA<ApiException>()));
    });

    test('lists content at a level', () async {
      final repository = RemoteCatalogRepository(
        api((request) async {
          expect(request.url.queryParameters, {'level': 'N3', 'limit': '10'});
          return json({'items': picksBody['items'], 'total': 1});
        }),
        FakeAuthRepository(),
        prefs,
      );

      final videos = await repository.videosAtLevel(JlptLevel.n3);
      expect(videos.single.reason, PickReason.interest);
    });
  });

  group('RemoteProfileSyncRepository', () {
    test('sends the answers and reads back the tier', () async {
      late http.Request sent;
      final repository = RemoteProfileSyncRepository(
        api((request) async {
          sent = request;
          return json({'subscriptionTier': 'premium'});
        }),
      );

      final tier = await repository.push(onboarded());

      expect(tier, SubscriptionTier.premium);
      expect(sent.method, 'PUT');
      expect(sent.url.path, '/me/profile');
      expect(jsonDecode(sent.body), {
        'displayName': 'Aiko',
        'avatarId': 'kitsune',
        'level': 'N4',
        'learningReasons': ['travel', 'anime_manga'],
        'interests': ['anime', 'music'],
        'preferences': {'onboardingVersion': 1},
      });
    });

    test('an unknown tier from the server reads as free', () {
      expect(SubscriptionTier.fromCode('platinum'), SubscriptionTier.free);
    });
  });
}
