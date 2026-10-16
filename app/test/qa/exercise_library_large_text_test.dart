// The exercise library with the owner's real catalogue, in Arabic at 1.6x on
// a small phone: R14 scrolled end to end and every move's R15, with nothing
// overflowing. The large-text sweep only ever sees R14 empty, because the
// library is empty under test.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/features/train/presentation/exercise_demo_view.dart';
import 'package:own_hub/features/train/presentation/exercise_library_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../helpers/exercise_library_fixture.dart';

ExerciseLibrary _catalogue() {
  final raw = (jsonDecode(
    File('../6-v2/content/exercise_library/catalogue.json').readAsStringSync(),
  ) as Map).cast<String, Object?>();
  return ExerciseLibrary.parse({
    'version': 1,
    'exercises': [
      for (final r in (raw['exercises']! as List).cast<Map<String, Object?>>())
        {
          'id': r['exerciseId'],
          'nameEn': r['name_en'],
          'nameAr': r['name_ar'],
          'kind': r['kind'],
          'primaryMuscles': r['primaryMuscles'],
          'secondaryMuscles': r['secondaryMuscles'],
          'bodyRegion': r['bodyRegion'],
          'pattern': r['pattern'],
          'equipment': r['equipment'],
          'place': r['place'],
          'level': r['level'],
          'quiet': r['quiet'],
          'floorOnly': r['floorOnly'],
          'tags': r['contraindicationTags'],
          if (r['setup_en'] != null) 'setupEn': r['setup_en'],
          if (r['setup_ar'] != null) 'setupAr': r['setup_ar'],
          'clips': [
            for (final c in (r['clips']! as List).cast<Map<String, Object?>>())
              {
                'file': c['file'],
                'angle': c['angle'],
                'bytes': 1,
                'seconds': c['seconds'],
              },
          ],
          'poster': {'file': (r['poster']! as Map)['file'], 'bytes': 1},
        },
    ],
  })!;
}

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ar'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('ar')),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.6)),
      child: child,
    ),
  ),
);

void main() {
  final saved = AppRouter.featureFlags;
  setUp(() => AppRouter.featureFlags = FeatureFlags.everything);
  tearDown(() => AppRouter.featureFlags = saved);

  final library = _catalogue();

  testWidgets('R14 in Arabic at 1.6x, top to bottom', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        ExerciseLibraryView(
          exercises: library.exercises,
          media: FakeExerciseMedia(fetchable: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 60; i++) {
      await tester.drag(list, const Offset(0, -500));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'after scroll $i');
    }
  });

  testWidgets('every R15 in Arabic at 1.6x', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final overflowing = <String>[];
    for (final exercise in library.exercises) {
      await tester.pumpWidget(
        _host(
          ExerciseDemoView(
            key: ValueKey(exercise.id),
            exercise: exercise,
            media: FakeExerciseMedia(),
            players: FakeClipPlayer.make,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (tester.takeException() != null) overflowing.add(exercise.id);
    }
    expect(overflowing, isEmpty);
    expect(library.exercises.length, greaterThan(70));
  });
}
