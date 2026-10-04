import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:ingrain/features/vocabulary/domain/dictionary_index.dart';

/// Reads the bundled JMdict subset and turns it into a [DictionaryIndex].
///
/// The asset is only used at runtime through `rootBundle`, so tests inject a
/// stub bundle instead of shipping the real file.
class AssetDictionaryLoader {
  const AssetDictionaryLoader({this.assetBundle});

  static const assetPath = 'assets/data/dictionary.json';

  final AssetBundle? assetBundle;

  Future<DictionaryIndex> load() async {
    final bundle = assetBundle ?? rootBundle;
    final raw = await bundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return DictionaryIndex.empty;
    return DictionaryIndex.fromJson(decoded);
  }
}
