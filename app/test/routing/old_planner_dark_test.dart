// C10. The old planner screens (W04 to W09, K19 to K23, and the assistant's two
// drafts) run on local state and would look like they publish. They are dark by
// Feature.coachPlanning and Feature.assistant. These tests fail the day that
// stops being true, or a live screen links to one.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

const List<String> kOldIds = <String>[
  'W04',
  'W05',
  'W07',
  'W08',
  'W09',
  'W11',
  'K19',
  'K20',
  'K21',
  'K22',
  'K23',
  'K26',
  'K27',
];

void main() {
  final original = AppRouter.featureFlags;
  tearDown(() => AppRouter.featureFlags = original);

  test('the switches that keep them dark are off in the shipped flags', () {
    final flags = AppRouter.featureFlags;
    for (final f in <Feature>[
      Feature.coachPlanning,
      Feature.assistant,
      Feature.payments,
      Feature.coachPortfolio,
    ]) {
      expect(
        flags.isOn(f),
        isFalse,
        reason: '$f must stay off until its screens write to the server',
      );
    }
  });

  test('none of the old ids is on', () {
    for (final id in kOldIds) {
      expect(AppRouter.screenIsOn(id), isFalse, reason: id);
    }
  });

  testWidgets('each old route answers FeatureOff, never the screen', (
    tester,
  ) async {
    for (final id in kOldIds) {
      final route = AppRouter.onGenerateRoute(
        RouteSettings(name: appRoutes[id]!.name),
      );
      if (id == 'W11') {
        expect(
          route,
          isNull,
          reason: '$id is a firstRunState, excluded from destinations',
        );
        continue;
      }
      expect(route, isNotNull, reason: id);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Builder(
            builder: (context) =>
                (route! as MaterialPageRoute<dynamic>).builder(context),
          ),
        ),
      );
      expect(find.byType(FeatureOff), findsOneWidget, reason: id);
    }
  });

  test('no live coach builder names an old id', () {
    final source = File('lib/routing/app_router.dart').readAsStringSync();
    final start = source.indexOf("    'K18': (context)");
    final end = source.indexOf("    'H01': (context)");
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final live = source.substring(start, end);
    for (final id in kOldIds) {
      expect(
        live.contains("'$id'"),
        isFalse,
        reason: '$id is named between K18 and H01',
      );
    }
  });

  test('no file of the live coaching feature names an old id', () {
    final hits = <String>[];
    for (final entity in Directory(
      'lib/features/private_coaching',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final id in kOldIds) {
        if (RegExp("['\"]$id['\"]").hasMatch(text)) {
          hits.add('${entity.path} names $id');
        }
      }
    }
    expect(hits, isEmpty);
  });
}
