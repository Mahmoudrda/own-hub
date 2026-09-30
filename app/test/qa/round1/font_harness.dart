// Round one's instrument: the real fonts, loaded into the widget tester.
//
// Case R1-00 of docs/plan/LAUNCH-QA-PLAN.md. Nothing in this repository has
// ever loaded a font into `flutter test`: there is no FontLoader, no
// loadAppFonts and no flutter_test_config.dart anywhere in the tree. So every
// overflow figure, every layout assertion and every "no clipping" claim ever
// recorded here was measured against Ahem — a placeholder face whose every
// glyph is a solid box of identical advance width. Ahem is not Rubik and it is
// very much not Aref Ruqaa; Arabic shaping has never been exercised at all.
//
// This file loads the seven faces declared in pubspec.yaml under the same
// family names the theme asks for, so a round-one measurement is a measurement
// of what a woman will actually see.
//
// Not a `_test.dart` file, so the runner does not execute it.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The families and the files behind them, exactly as `app/pubspec.yaml`
/// declares them.
const Map<String, List<String>> appFontFiles = <String, List<String>>{
  'Rubik': <String>[
    'assets/fonts/Rubik-400.ttf',
    'assets/fonts/Rubik-500.ttf',
    'assets/fonts/Rubik-600.ttf',
    'assets/fonts/Rubik-700.ttf',
  ],
  'LaBelleAurore': <String>['assets/fonts/LaBelleAurore-400.ttf'],
  'ArefRuqaa': <String>[
    'assets/fonts/ArefRuqaa-400.ttf',
    'assets/fonts/ArefRuqaa-700.ttf',
  ],
};

bool _loaded = false;

/// Loads Rubik 400/500/600/700, LaBelleAurore 400 and ArefRuqaa 400/700 into
/// the tester's font collection.
///
/// Idempotent: the engine keeps the collection for the life of the isolate, so
/// a suite of tests pays for this once.
Future<void> loadAppFonts() async {
  if (_loaded) return;
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final entry in appFontFiles.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final file = File(path);
      if (!file.existsSync()) {
        throw StateError('R1-00: font file missing: $path');
      }
      loader.addFont(
        Future<ByteData>.value(
          ByteData.sublistView(file.readAsBytesSync()),
        ),
      );
    }
    await loader.load();
  }
  _loaded = true;
}
