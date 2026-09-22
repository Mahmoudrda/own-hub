// P0-CYC-04 — "three taps and nothing carried over", and §3.3's
// `severeSelectedUnsaved`.
//
// The case: "Every chip starts unselected — yesterday's severe cramps do not
// prefill today. The save takes three taps, all optional, and the hub returns to
// her unchanged plan."
//
// The strongest assertion here is structural rather than behavioural: the widget
// has **no parameter that could carry yesterday's check-in**, so "nothing is
// carried over" is not a rule the sheet remembers — it is a thing it cannot do.
// §3.3: "a diary that assumes continuity has stopped being a diary, and a
// carried-over severe symptom would suppress a workout on a day she feels fine."

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/cycle/domain/severe_symptom_gate.dart';
import 'package:own_hub/features/cycle/domain/today_check_in.dart';
import 'package:own_hub/features/cycle/presentation/check_in_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_chip_row.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: child,
  );
}

void main() {
  group('P0-CYC-04 — nothing is carried over from yesterday', () {
    testWidgets('every chip starts unselected', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(const CheckInView()));
      await tester.pumpAndSettle();

      // Three groups are rendered, and not one of them has a selection.
      final rows = tester.widgetList<AppChipRow>(find.byType(AppChipRow));
      expect(rows, isNotEmpty);
      for (final row in rows) {
        expect(
          row.selected,
          isEmpty,
          reason:
              'yesterday\'s severe cramps must not prefill today — a new day '
              'always starts at noCheckIn',
        );
      }
    });

    testWidgets('saving with no taps at all yields an empty check-in', (
      tester,
    ) async {
      TodayCheckIn? saved;
      _phone(tester);
      await tester.pumpWidget(_host(CheckInView(onSaved: (c) => saved = c)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save check-in'));
      await tester.pumpAndSettle();

      // Every field is optional, and an empty check-in is a valid document.
      expect(saved, isNotNull);
      expect(saved!.isEmpty, isTrue);
    });

    testWidgets('three taps produce exactly what she chose', (tester) async {
      TodayCheckIn? saved;
      _phone(tester);
      await tester.pumpWidget(_host(CheckInView(onSaved: (c) => saved = c)));
      await tester.pumpAndSettle();

      // Deliberately not the mockup's default row (low / mild / usual): a
      // fixture matching the prototype would pass for a constant too.
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moderate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Less hungry'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save check-in'));
      await tester.pumpAndSettle();

      expect(saved!.energy, Energy.high);
      expect(saved!.cramps, Cramps.moderate);
      expect(saved!.appetite, Appetite.low);
      // And nothing she did not touch.
      expect(saved!.sleep, isNull);
      expect(saved!.bleeding, isNull);
    });
  });

  group('§3.3 — an unsaved severe selection stores nothing', () {
    testWidgets('selecting Severe shows the guidance immediately', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(const CheckInView()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Severe or unusual pain'), findsNothing);

      await tester.tap(find.text('Severe'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Severe or unusual pain'), findsOneWidget);
    });

    testWidgets('but nothing is handed up until Save', (tester) async {
      var saves = 0;
      _phone(tester);
      await tester.pumpWidget(_host(CheckInView(onSaved: (_) => saves++)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Severe'));
      await tester.pumpAndSettle();

      expect(
        saves,
        0,
        reason:
            'persisting a symptom she did not save would be a lie in a symptom '
            'diary',
      );
    });

    testWidgets('backing out discards it', (tester) async {
      var saves = 0;
      var cancels = 0;
      _phone(tester);
      await tester.pumpWidget(
        _host(CheckInView(onSaved: (_) => saves++, onCancel: () => cancels++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Severe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(saves, 0);
      expect(cancels, 1);
    });
  });

  group('"More to log" — the half of the severe gate Y04 could not reach', () {
    // The point of this group. `SevereSymptomGate` fires on severe cramps OR
    // heavy bleeding, and until this sheet had a bleeding row the second arm
    // was dead from the interface: the domain implemented it, and no woman
    // could trigger it. Every assertion below is about that path being real.

    Future<void> openMore(WidgetTester tester) async {
      final more = find.text('More to log: sleep, bloating, bleeding');
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
    }

    Future<void> tapChip(WidgetTester tester, Finder chip) async {
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    testWidgets('the extra rows are closed until she asks for them', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(const CheckInView()));
      await tester.pumpAndSettle();

      // Three taps are still the sheet.
      for (final hidden in ['Sleep', 'Bloating', 'Bleeding', 'Heavy']) {
        expect(find.text(hidden), findsNothing);
      }
      expect(
        find.text('More to log: sleep, bloating, bleeding'),
        findsOneWidget,
      );

      await openMore(tester);

      for (final shown in [
        'Sleep',
        'Bloating',
        'Bleeding',
        'Poor',
        'Good',
        'Spotting',
        'Heavy',
      ]) {
        expect(find.text(shown), findsOneWidget, reason: '"$shown" is missing');
      }
    });

    testWidgets('heavy bleeding produces a check-in the severe gate accepts', (
      tester,
    ) async {
      TodayCheckIn? saved;
      _phone(tester);
      await tester.pumpWidget(_host(CheckInView(onSaved: (c) => saved = c)));
      await tester.pumpAndSettle();

      await openMore(tester);
      await tapChip(tester, find.text('Heavy'));
      await tapChip(tester, find.text('Save check-in'));

      expect(saved!.bleeding, Bleeding.heavy);
      // No cramps at all — so anything severe about this day came from the
      // bleeding row and from nothing else.
      expect(saved!.cramps, isNull);
      expect(
        const SevereSymptomGate().evaluate(saved!),
        isTrue,
        reason:
            'bleeding == heavy is half of §2.5, and this is the first time the '
            'interface can reach it',
      );
    });

    testWidgets('the guidance shows on heavy bleeding, with no cramps logged', (
      tester,
    ) async {
      var saves = 0;
      _phone(tester);
      await tester.pumpWidget(_host(CheckInView(onSaved: (_) => saves++)));
      await tester.pumpAndSettle();

      await openMore(tester);
      expect(find.textContaining('Severe or unusual pain'), findsNothing);

      await tapChip(tester, find.text('Heavy'));

      expect(find.textContaining('Severe or unusual pain'), findsOneWidget);
      // Same rule as severe cramps: shown immediately, written never.
      expect(saves, 0);
    });

    testWidgets('spotting is not severe', (tester) async {
      // The other value in the same row. If the gate were reading "she touched
      // the bleeding row" rather than the value, this would trip.
      TodayCheckIn? saved;
      _phone(tester);
      await tester.pumpWidget(_host(CheckInView(onSaved: (c) => saved = c)));
      await tester.pumpAndSettle();

      await openMore(tester);
      await tapChip(tester, find.text('Spotting'));

      expect(find.textContaining('Severe or unusual pain'), findsNothing);

      await tapChip(tester, find.text('Save check-in'));
      expect(saved!.bleeding, Bleeding.spotting);
      expect(const SevereSymptomGate().evaluate(saved!), isFalse);
    });

    testWidgets('the bloating row writes bloating, not cramps', (tester) async {
      // Both rows are labelled None/Mild/Moderate/Severe — the same four words,
      // which is precisely how a copy-pasted handler would go unnoticed.
      TodayCheckIn? saved;
      _phone(tester);
      await tester.pumpWidget(_host(CheckInView(onSaved: (c) => saved = c)));
      await tester.pumpAndSettle();

      await openMore(tester);
      expect(find.text('Moderate'), findsNWidgets(2));

      // The second one is bloating's.
      await tapChip(tester, find.text('Moderate').last);
      await tapChip(tester, find.text('Save check-in'));

      expect(saved!.bloating, Bloating.moderate);
      expect(saved!.cramps, isNull);
    });

    testWidgets('a value logged behind More to log survives a later tap', (
      tester,
    ) async {
      // The regression this guards: the three original rows each rebuilt the
      // draft naming only energy, cramps and appetite. Harmless while nothing
      // else could be logged — and the day bleeding could be, tapping an
      // energy chip afterwards dropped it, taking the suppression with it.
      TodayCheckIn? saved;
      _phone(tester);
      await tester.pumpWidget(_host(CheckInView(onSaved: (c) => saved = c)));
      await tester.pumpAndSettle();

      await openMore(tester);
      await tapChip(tester, find.text('Heavy'));
      await tapChip(tester, find.text('Poor'));
      // Now go back and touch a row that comes before it.
      await tapChip(tester, find.text('High'));
      await tapChip(tester, find.text('Save check-in'));

      expect(saved!.energy, Energy.high);
      expect(
        saved!.bleeding,
        Bleeding.heavy,
        reason: 'a later tap must not silently clear what she already logged',
      );
      expect(saved!.sleep, Sleep.poor);
      expect(const SevereSymptomGate().evaluate(saved!), isTrue);
    });
  });

  group('rule 9 — the check-in never asks her to confirm', () {
    testWidgets('saving raises no dialog', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(const CheckInView()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save check-in'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    });
  });
}
