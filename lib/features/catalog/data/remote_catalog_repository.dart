import 'dart:convert';

import 'package:ingrain/core/network/api_client.dart';
import 'package:ingrain/features/auth/domain/auth_repository.dart';
import 'package:ingrain/features/catalog/data/catalog_video_dto.dart';
import 'package:ingrain/features/catalog/domain/catalog_repository.dart';
import 'package:ingrain/features/catalog/domain/catalog_video.dart';
import 'package:ingrain/features/profile/domain/learner_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `GET /recommendations/daily` and `GET /content`, with the last daily picks
/// cached on the device per learner.
class RemoteCatalogRepository implements CatalogRepository {
  final ApiClient _api;
  final AuthRepository _auth;
  final SharedPreferences _prefs;

  RemoteCatalogRepository(this._api, this._auth, this._prefs);

  static String cacheKey(String uid) => 'catalog_daily_picks_$uid';

  @override
  Future<DailyPicks> dailyPicks() async {
    final key = cacheKey(await _auth.ensureUid());
    try {
      final json = await _api.get('/recommendations/daily');
      final map = Map<String, dynamic>.from(json as Map);
      await _prefs.setString(key, jsonEncode(map));
      return CatalogVideoDto.picksFromJson(map);
    } catch (_) {
      // Yesterday's picks beat an empty home screen while offline.
      final cached = _prefs.getString(key);
      if (cached == null) rethrow;
      return CatalogVideoDto.picksFromJson(
        Map<String, dynamic>.from(jsonDecode(cached) as Map),
        isCached: true,
      );
    }
  }

  @override
  Future<List<CatalogVideo>> videosAtLevel(
    JlptLevel level, {
    int limit = 10,
  }) async {
    final json = await _api.get(
      '/content',
      query: {'level': level.code, 'limit': '$limit'},
    );
    final items = (json as Map)['items'] as List? ?? const [];
    return [
      for (final item in items)
        CatalogVideoDto.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }
}
