// The host every assistant widget test pumps into, and the one fixture pack
// they all read.
//
// Fixture ids and names are deliberately unlike the seeded library's, so a test
// cannot pass by accidentally reading real content — the idiom
// `assistant_screens_test.dart` established for this feature.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/features/assistant/domain/assistant_pack.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/theme/app_tokens.dart';

final AppL10n l10n = AppL10nEn();

/// Two moves with an authored prescription and one without, so a row that
/// renders no detail line can be told apart from one that renders the wrong
/// figure. One verified dish and one unverified, for the same reason.
final AssistantPack pack = AssistantPack(
  version: 'fx-pack-9112',
  exercises: const [
    AssistantExercise(
      exerciseId: 'fx_9112_bridge',
      name: 'fixture bridge',
      tags: {ContraindicationTag.supineLoad},
      quiet: true,
      floorOnly: true,
      prescriptionLabel: 'fixture detail bridge',
    ),
    AssistantExercise(
      exerciseId: 'fx_9112_box_squat',
      name: 'fixture box squat',
      tags: {ContraindicationTag.none},
      quiet: true,
      floorOnly: false,
      prescriptionLabel: 'fixture detail box squat',
    ),
    AssistantExercise(
      exerciseId: 'fx_9112_squat',
      name: 'fixture squat',
      tags: {ContraindicationTag.deepKneeFlexion},
      quiet: true,
      floorOnly: false,
    ),
  ],
  foods: const FoodLibrary(<Food>[
    Food(
      foodId: 'fx_9112_lentils',
      names: ['fixture lentils'],
      allergens: <String>{},
      sizes: [FoodSize(id: 'M', label: 'medium', kcal: 193, proteinG: 17)],
    ),
    Food(
      foodId: 'fx_9112_unverified',
      names: ['fixture unverified dish'],
      allergens: <String>{},
      verified: false,
      sizes: [FoodSize(id: 'M', label: 'medium', kcal: 404, proteinG: 13)],
    ),
  ]),
);

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

/// Every string the widget tree actually puts on screen.
List<String> renderedText(WidgetTester tester) => [
  for (final widget in tester.widgetList<Text>(find.byType(Text)))
    widget.data ?? '',
];
