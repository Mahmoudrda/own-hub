/// Which painted meal images are bundled.
///
/// Pure Dart, like the rest of this folder: `main.dart` reads
/// `assets/art/meals/index.json` and hands the text to [adopt]. Until then, and
/// for any id that has no picture yet, [assetFor] is null and the screen keeps
/// the drawn mark it always had.
library;

import 'dart:convert';

abstract final class MealImages {
  static const indexPath = 'assets/art/meals/index.json';
  static const folder = 'assets/art/meals';

  static Map<String, String> _assets = const {};

  /// Reads the index. A file that cannot be read leaves the set empty.
  static void adopt(String indexJson) {
    try {
      final rows = jsonDecode(indexJson) as List<dynamic>;
      _assets = {
        for (final row in rows)
          (row as Map<String, dynamic>)['id'] as String:
              '$folder/${row['id']}.webp',
      };
    } on Object {
      _assets = const {};
    }
  }

  /// The bundled 1x file for [id], or null when none is installed.
  static String? assetFor(String id) => _assets[id];

  static void clear() => _assets = const {};
}
