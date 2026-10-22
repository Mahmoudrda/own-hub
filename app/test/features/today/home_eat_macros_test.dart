// The Home eat card: protein, carbs and fat as three separated columns, each
// with the value on top, "of 120 g" under it and the name last.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/daily_targets.dart';
import 'package:own_hub/features/eat/domain/day_totals.dart';
import 'package:own_hub/features/today/presentation/today_cards.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

const _totals = DayTotals(
  kcalSoFar: 1240,
  proteinSoFar: 42,
  proteinTargetG: 120,
  carbsSoFar: 118,
  fatSoFar: 31,
);

const _targets = DailyTargets(
  kcal: 1900,
  proteinG: 120,
  carbsG: 210,
  fatG: 62,
  fiberG: 25,
  usesDefaults: false,
);

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double scale = 1.0,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  ),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400); // 360 wide at 3x
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  const card = HomeEatCard(totals: _totals, targets: _targets);

  testWidgets('three columns: value, "of 120 g", then the name', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(card));
    await tester.pumpAndSettle();

    for (final text in [
      '42 g', 'of 120 g', 'Protein', //
      '118 g', 'of 210 g', 'Carbs',
      '31 g', 'of 62 g', 'Fat',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    // No "42 of 120 g" squeezed onto one line.
    expect(find.text('42 of 120 g'), findsNothing);

    // Each column stacks value, target, name, top to bottom.
    for (final (i, value) in [(0, '42 g'), (1, '118 g'), (2, '31 g')]) {
      final column = find.byKey(ValueKey('today-eat-macro-$i'));
      final top = tester.getTopLeft(
        find.descendant(of: column, matching: find.text(value)),
      );
      final name = tester.getTopLeft(
        find.descendant(
          of: column,
          matching: find.text(['Protein', 'Carbs', 'Fat'][i]),
        ),
      );
      expect(name.dy, greaterThan(top.dy + 20), reason: value);
    }
  });

  testWidgets('the columns do not overlap and have a gap and dividers', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(card));
    await tester.pumpAndSettle();

    final rects = [
      for (var i = 0; i < 3; i++)
        tester.getRect(find.byKey(ValueKey('today-eat-macro-$i'))),
    ];
    for (var i = 0; i < 2; i++) {
      expect(
        rects[i + 1].left - rects[i].right,
        greaterThanOrEqualTo(8),
        reason: 'gap between column $i and ${i + 1}',
      );
    }
    final macros = tester.getRect(
      find.byKey(const ValueKey('today-eat-macros')),
    );
    for (final r in rects) {
      expect(macros.contains(r.center), isTrue);
    }
    // Two dividers sit between the three columns.
    final dividers = find.descendant(
      of: find.byKey(const ValueKey('today-eat-macros')),
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxWidth == 1,
      ),
    );
    expect(dividers, findsNWidgets(2));
  });

  testWidgets('a macro with no target shows its grams alone', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(const HomeEatCard(totals: _totals)));
    await tester.pumpAndSettle();
    expect(find.text('42 g'), findsOneWidget);
    expect(find.textContaining('of '), findsNothing);
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('no overflow at ${locale.languageCode} text scale $scale', (
        tester,
      ) async {
        _phone(tester);
        await tester.pumpWidget(_host(card, locale: locale, scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('today-eat-macros')), findsOneWidget);
        final macros = tester.getRect(
          find.byKey(const ValueKey('today-eat-macros')),
        );
        expect(macros.left, greaterThanOrEqualTo(0));
        expect(macros.right, lessThanOrEqualTo(360));
        // Every figure is still on the screen, whichever layout it took.
        expect(find.textContaining('42'), findsWidgets);
        expect(find.textContaining('118'), findsWidgets);
        expect(find.textContaining('31'), findsWidgets);
      });
    }
  }

  testWidgets('each column reads as one thing to a screen reader', (
    tester,
  ) async {
    _phone(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(card));
    await tester.pumpAndSettle();
    final label = tester
        .getSemantics(
          find.ancestor(
            of: find.byKey(const ValueKey('today-eat-macro-0')),
            matching: find.byType(MergeSemantics),
          ),
        )
        .label;
    expect(label, contains('42 g'));
    expect(label, contains('of 120 g'));
    expect(label, contains('Protein'));
    handle.dispose();
  });
}
