// P03 — Personal bests.
//
// The screen's own note is the rule it must not break: "Sessions you logged as
// 'I already did it' never set a best, because the numbers were copied." That
// sentence has to be on the screen, and the detector behind it has to mean it —
// which is tested in test/domain/rewards/personal_best_detector_test.dart.
//
// Here the subject is the rendering: her figures, never the prototype's, and no
// row at all for a move the dictionary cannot name.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/features/progress/presentation/personal_bests_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

/// The prototype's own four rows.
const List<PersonalBest> _mockupBests = <PersonalBest>[
  PersonalBest(
    exerciseId: 'goblet_squat',
    metric: BestMetric.load,
    dateKey: '2026-09-16',
    sessionId: 's1',
    loadKg: 12,
    reps: 10,
    previous: PreviousBest(loadKg: 10),
  ),
  PersonalBest(
    exerciseId: 'glute_bridge',
    metric: BestMetric.reps,
    dateKey: '2026-09-09',
    sessionId: 's2',
    reps: 15,
    previous: PreviousBest(reps: 12),
  ),
  PersonalBest(
    exerciseId: 'plank_hold',
    metric: BestMetric.hold,
    dateKey: '2026-09-02',
    sessionId: 's3',
    holdSec: 45,
    previous: PreviousBest(holdSec: 30),
  ),
  PersonalBest(
    exerciseId: 'step_back_lunge',
    metric: BestMetric.variation,
    dateKey: '2026-08-26',
    sessionId: 's4',
    rank: 3,
    previous: PreviousBest(rank: 1),
  ),
];

Widget _view(List<PersonalBest> bests) =>
    PersonalBestsView(bests: bests, onBack: () {}, onSelectTab: (_) {});

void main() {
  group('the four kinds of best', () {
    testWidgets('all four render for the woman they describe', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(_mockupBests)));
      await tester.pumpAndSettle();

      expect(find.text('Goblet squat'), findsOneWidget);
      expect(
        find.text('12 kg × 10 · 16 September · was 10 kg'),
        findsOneWidget,
      );
      expect(find.text('+2 kg'), findsOneWidget);

      expect(find.text('Glute bridge'), findsOneWidget);
      expect(find.text('+3 reps'), findsOneWidget);

      expect(find.text('Plank hold'), findsOneWidget);
      expect(find.text('+15 s'), findsOneWidget);

      expect(find.text('Step-back lunge'), findsOneWidget);
      expect(find.text('level up'), findsOneWidget);
    });

    testWidgets('the rule that excludes recalled sessions is on the screen', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(_mockupBests)));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Sessions you logged as "I already did it" never set a best, because '
          'the numbers were copied.',
        ),
        findsOneWidget,
      );
    });
  });

  group('her numbers, not the prototype\'s', () {
    testWidgets('a different squat best shows the name without the figures', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(const [
            PersonalBest(
              exerciseId: 'goblet_squat',
              metric: BestMetric.load,
              dateKey: '2026-09-18',
              sessionId: 's1',
              loadKg: 18,
              reps: 6,
              previous: PreviousBest(loadKg: 16),
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Goblet squat'), findsOneWidget);
      expect(
        find.text('12 kg × 10 · 16 September · was 10 kg'),
        findsNothing,
        reason: 'she lifted 18 kg × 6, not the mockup\'s 12 × 10',
      );
      expect(
        find.text('+2 kg'),
        findsOneWidget,
        reason: '18 − 16 really is two kilos, so this line IS hers',
      );
    });

    testWidgets('a gain that is not two kilos does not read "+2 kg"', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(const [
            PersonalBest(
              exerciseId: 'goblet_squat',
              metric: BestMetric.load,
              dateKey: '2026-09-18',
              sessionId: 's1',
              loadKg: 20,
              reps: 5,
              previous: PreviousBest(loadKg: 16),
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Goblet squat'), findsOneWidget);
      expect(find.text('+2 kg'), findsNothing, reason: 'it was four');
      expect(
        find.text('+4 kg'),
        findsOneWidget,
        reason:
            '`nKg` is parameterised, so a four-kilo gain is stated. The fixed '
            '`n2Kg` could only ever say two, so she was shown nothing at all',
      );
    });

    testWidgets('a half-kilo gain keeps its half, and drops no other zero', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(const [
            PersonalBest(
              exerciseId: 'goblet_squat',
              metric: BestMetric.load,
              dateKey: '2026-09-18',
              sessionId: 's1',
              loadKg: 12.5,
              reps: 8,
              previous: PreviousBest(loadKg: 10),
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+2.5 kg'), findsOneWidget);
      expect(find.text('+2.50 kg'), findsNothing);
    });

    testWidgets('reps and holds are computed too, not recited', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(const [
            PersonalBest(
              exerciseId: 'glute_bridge',
              metric: BestMetric.reps,
              dateKey: '2026-09-18',
              sessionId: 's2',
              reps: 20,
              previous: PreviousBest(reps: 12),
            ),
            PersonalBest(
              exerciseId: 'plank_hold',
              metric: BestMetric.hold,
              dateKey: '2026-09-18',
              sessionId: 's3',
              holdSec: 60,
              previous: PreviousBest(holdSec: 30),
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+8 reps'), findsOneWidget);
      expect(find.text('+30 s'), findsOneWidget);
      expect(find.text('+3 reps'), findsNothing, reason: "the mockup's");
      expect(find.text('+15 s'), findsNothing, reason: "the mockup's");
    });

    testWidgets('a first-ever best has no gain to name', (tester) async {
      // Nothing to subtract from. "+18 kg" would be a comparison with a
      // previous best that does not exist.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(const [
            PersonalBest(
              exerciseId: 'goblet_squat',
              metric: BestMetric.load,
              dateKey: '2026-09-18',
              sessionId: 's1',
              loadKg: 18,
              reps: 6,
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Goblet squat'), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });
  });

  group('a move the dictionary cannot name', () {
    testWidgets('is left out rather than rendered as an exercise id', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(const [
            PersonalBest(
              exerciseId: 'bulgarian_split_squat',
              metric: BestMetric.load,
              dateKey: '2026-09-18',
              sessionId: 's1',
              loadKg: 18,
            ),
            ..._mockupBests,
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('bulgarian'), findsNothing);
      expect(find.textContaining('split_squat'), findsNothing);
      // The nameable ones still render.
      expect(find.text('Goblet squat'), findsOneWidget);
    });

    testWidgets('a list of only unnameable bests reads as empty, not broken', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(const [
            PersonalBest(
              exerciseId: 'bulgarian_split_squat',
              metric: BestMetric.load,
              dateKey: '2026-09-18',
              sessionId: 's1',
              loadKg: 18,
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('no bests at all', () {
    testWidgets('an empty state, not an empty screen', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(const [])));
      await tester.pumpAndSettle();

      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect(
        find.textContaining('Measured against your own history only'),
        findsOneWidget,
      );
    });
  });

  group('P0-A11Y-01', () {
    testWidgets('it mirrors in Arabic with Western numerals', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_view(_mockupBests), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(PersonalBestsView))),
        TextDirection.rtl,
      );

      final eastern = RegExp('[٠-٩]');
      for (final text
          in tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data ?? '')) {
        expect(eastern.hasMatch(text), isFalse, reason: text);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('it does not overflow at the largest text size in Arabic', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_view(_mockupBests), locale: const Locale('ar'), textScale: 1.6),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
