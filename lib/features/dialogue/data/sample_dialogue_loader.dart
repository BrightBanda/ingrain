import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:ingrain/features/dialogue/data/dialogue_dto.dart';
import 'package:ingrain/features/dialogue/domain/dialogue.dart';

/// Reads the dialogues bundled in `assets/data/sample_dialogues.json`.
///
/// They are the last resort when the API is unreachable and nothing is cached,
/// so the Library and the reader are usable without running the backend.
class SampleDialogueLoader {
  SampleDialogueLoader({this.assetBundle});

  static const assetPath = 'assets/data/sample_dialogues.json';

  final AssetBundle? assetBundle;

  List<Dialogue>? _loaded;

  Future<List<Dialogue>> load() async {
    final loaded = _loaded;
    if (loaded != null) return loaded;
    final raw = await (assetBundle ?? rootBundle).loadString(assetPath);
    final decoded = jsonDecode(raw);
    final list = decoded is Map ? decoded['dialogues'] : null;
    if (list is! List) return _loaded = const [];
    return _loaded = list
        .map(
          (value) =>
              DialogueDto.fromMap(Map<String, dynamic>.from(value as Map))
                  .toDomain(),
        )
        .toList();
  }
}
