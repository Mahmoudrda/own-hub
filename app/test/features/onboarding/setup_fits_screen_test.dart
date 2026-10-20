// Every one-question setup screen fits a phone without scrolling at the normal
// text size, in English and in Egyptian Arabic, and still wraps with no overflow
// at a large one. O03 (presets, custom schedule, level) and O04 (the optional
// "About you" block) carry more than one screen of answers and scroll by
// design; they are held to no overflow at either size.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/presentation/goal_view.dart';
import 'package:own_hub/features/onboarding/presentation/equipment_view.dart';
import 'package:own_hub/features/onboarding/presentation/life_stage_view.dart';
import 'package:own_hub/features/onboarding/presentation/place_view.dart';
import 'package:own_hub/features/onboarding/presentation/schedule_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/screen_scope.dart';

import '../../qa/round1/font_harness.dart';

Widget _host(String id, Widget child, Locale locale, double textScale) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(locale),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: ScreenScope(screenId: id, child: child),
      ),
    );

void main() {
  // Real Rubik, so the lines wrap as they do on a phone rather than in Ahem.
  setUpAll(loadAppFonts);

  final screens = <String, Widget Function()>{
    'O01': () => GoalView(
      repository: InMemoryIntakeRepository(),
      onSkip: () {},
      onBack: () {},
    ),
    'O02': () => PlaceView(
      repository: InMemoryIntakeRepository(),
      onSkip: () {},
      onBack: () {},
    ),
    'O06': () => EquipmentView(
      repository: InMemoryIntakeRepository(),
      onSkip: () {},
      onBack: () {},
    ),
    'O03': () => ScheduleView(
      repository: InMemoryIntakeRepository(),
      onSkip: () {},
      onBack: () {},
    ),
    'O04': () =>
        LifeStageView(repository: InMemoryIntakeRepository(), onBack: () {}),
  };

  const scrolls = {'O03', 'O04'};

  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} fits a 360 x 720 phone without scrolling in '
          '${locale.languageCode}', (tester) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_host(entry.key, entry.value(), locale, 1.0));
        await tester.pumpAndSettle();

        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        if (!scrolls.contains(entry.key)) {
          expect(
            scrollable.position.maxScrollExtent,
            0,
            reason: '${entry.key} scrolls at the normal text size',
          );
        }
        expect(tester.takeException(), isNull);
        expect(
          find.text(
            AppL10n.of(tester.element(find.byType(Scaffold).first)).skip,
          ),
          // O04, the safety question, is the one screen with no Skip.
          entry.key == 'O04' ? findsNothing : findsOneWidget,
        );
      });

      testWidgets(
        '${entry.key} wraps at 2x text in ${locale.languageCode} with '
        'no overflow',
        (tester) async {
          tester.view.physicalSize = const Size(360, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_host(entry.key, entry.value(), locale, 2.0));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
