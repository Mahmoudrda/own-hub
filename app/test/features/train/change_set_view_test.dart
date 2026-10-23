// R08 — Change a set.
//
// Implements P0-LOG-05: change a value with chips, two taps, no keyboard — and
// a hard set never lowers her weight.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/change_set_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

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
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

void main() {
  testWidgets('asks what she did, with the likely answers as chips', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const ChangeSetView()));
    await tester.pumpAndSettle();

    expect(find.text('What did you do?'), findsOneWidget);
    // The sheet names the move. It used to name "Set 2 · Goblet squat" from a
    // fixed string, so it said set 2 of a goblet squat for the fourth set of a
    // hip thrust; R08 is given one set and is told nothing about how many the
    // move has, so no set number is claimed.
    expect(find.text('Goblet squat'), findsWidgets);
    expect(find.text('Set 2 · Goblet squat'), findsNothing);
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Reps'), findsOneWidget);
    // What was planned, and one step either side.
    expect(find.text('10 kg'), findsOneWidget);
    expect(find.text('12 kg'), findsOneWidget);
    expect(find.text('14 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('P0-LOG-05 — no keyboard, unless she asks for one', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const ChangeSetView()));
    await tester.pumpAndSettle();

    // A woman mid-set should not have to dismiss a numeric keypad to see the
    // set she is editing.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Type a different number'), findsOneWidget);
  });

  testWidgets('the keyboard is behind one explicit tap', (tester) async {
    var typed = 0;
    await tester.pumpWidget(_host(ChangeSetView(onTypeANumber: () => typed++)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Type a different number'));
    await tester.pumpAndSettle();
    expect(typed, 1);
  });

  testWidgets('two taps change the value — and the change is really written', (
    tester,
  ) async {
    final repository = InMemoryTrainRepository();
    LogHandle? handle;
    await tester.pumpWidget(
      _host(ChangeSetView(repository: repository, onSaved: (h) => handle = h)),
    );
    await tester.pumpAndSettle();

    // Tap one: a harder weight. Tap two: fewer reps than asked.
    await tester.tap(find.text('14 kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9'));
    await tester.pumpAndSettle();

    // The button names what it is about to write.
    //
    // This test used to tap "14 kg", then "9", then a button reading
    // "Save · 12 kg × 8", and assert 14 × 9 was written. The disagreement WAS
    // the defect — `save12Kg8` was a fixed string beside two chip rows — and
    // the test passed straight through it. R07 had the same fault and was
    // fixed; R08 kept it, with a green test on top.
    expect(find.text('Save · 12 kg × 8'), findsNothing);
    expect(find.text('Done · 14 kg × 9'), findsOneWidget);

    await tester.tap(find.text('Done · 14 kg × 9'));
    await tester.pumpAndSettle();

    // The regression this pins. R08 used to hand a ChangedSet to its caller and
    // write nothing at all: the router assigned it to a field nothing read, so
    // her override was dropped and R09 went on to announce the prescription she
    // had just corrected. The old test asserted the callback's argument — which
    // was genuinely correct — and so stayed green through all of it. Asserting
    // the repository is what makes that impossible.
    expect(handle, isNotNull);
    expect(
      handle!.describe,
      'Set 2 saved · 14 kg × 9',
      reason: 'the bar names HER numbers, and 14 rather than 14.0',
    );

    // Nothing has reached the repository yet: the five seconds run first, which
    // is what makes undo reach a local draft instead of a queued write.
    expect(repository.flushes, isEmpty);

    await tester.pump(const Duration(seconds: 6));

    expect(repository.flushes, hasLength(1));
    final flushed = repository.flushes.single;
    expect(flushed.exerciseId, 'goblet_squat');
    expect(flushed.sets.single.outcome!.weightKg, 14);
    expect(flushed.sets.single.outcome!.reps, 9);
  });

  testWidgets('undo inside the window means it was never written at all', (
    tester,
  ) async {
    final repository = InMemoryTrainRepository();
    LogHandle? handle;
    await tester.pumpWidget(
      _host(ChangeSetView(repository: repository, onSaved: (h) => handle = h)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('14 kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done · 14 kg × 10'));
    await tester.pumpAndSettle();

    expect(handle!.undo(), isTrue);
    await tester.pump(const Duration(seconds: 6));

    // Not "written and then deleted" — never written. The draft never left the
    // bus, so there is no queued write to resurface when she reconnects.
    expect(repository.flushes, isEmpty);
  });

  testWidgets('a hard set never rewrites the prescription', (tester) async {
    final repository = InMemoryTrainRepository();
    await tester.pumpWidget(_host(ChangeSetView(repository: repository)));
    await tester.pumpAndSettle();

    // She managed fewer reps than asked.
    await tester.tap(find.text('8'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done · 12 kg × 8'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));

    // Asserted on what was stored, not on what was handed back: rule 1 is a
    // property of the record, so the record is what has to be checked.
    final stored = repository.flushes.single.sets.single;
    expect(stored.outcome!.reps, 8);
    // The plan still says 12 kg × 10. That it was hard does not change the plan.
    expect(stored.prescribed.weightKg, 12);
    expect(stored.prescribed.reps, 10);
  });

  testWidgets('the planned weight and the planned reps start selected', (
    tester,
  ) async {
    final repository = InMemoryTrainRepository();
    await tester.pumpWidget(_host(ChangeSetView(repository: repository)));
    await tester.pumpAndSettle();

    // A set done as asked is one tap. The reps used to open on a fixed 8.
    await tester.tap(find.text('Done · 12 kg × 10'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));

    expect(
      repository.flushes.single.sets.single.outcome!.weightKg,
      12,
      reason: 'the chip she is likeliest to mean is the one that was planned',
    );
    expect(repository.flushes.single.sets.single.outcome!.reps, 10);
  });

  testWidgets('the reps on offer sit around what she was asked for', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const ChangeSetView()));
    await tester.pumpAndSettle();
    // Asked for 10: mostly fewer, one step more.
    for (final reps in ['6', '8', '9', '10', '12']) {
      expect(find.text(reps), findsOneWidget, reason: reps);
    }
  });

  testWidgets('"Type a different number" opens a number pad in the sheet', (
    tester,
  ) async {
    final repository = InMemoryTrainRepository();
    await tester.pumpWidget(_host(ChangeSetView(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Type a different number'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '15');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done · 12 kg × 15'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    expect(repository.flushes.single.sets.single.outcome!.reps, 15);
  });

  testWidgets('changing a value never raises a dialog', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpWidget(_host(const ChangeSetView()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('14 kg'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const ChangeSetView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('عملتي إيه؟'), findsOneWidget);
    expect(find.text('الوزن'), findsOneWidget);
    expect(find.text('العدّات'), findsOneWidget);
    expect(find.text('اكتبي رقم تاني'), findsOneWidget);
    expect(find.text('Weight'), findsNothing);
  });

  testWidgets('the rep chips stay in Western digits in Arabic', (tester) async {
    // P0-A11Y-01. A bare "9" has nothing to translate, and the dictionary holds
    // no numeral-only value anywhere.
    await tester.pumpWidget(
      _host(const ChangeSetView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('9'), findsOneWidget);
    expect(find.text('12 كجم'), findsOneWidget);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ChangeSetView(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final shown in [true, false]) {
      testWidgets(
        'the plate helper ${shown ? 'fits' : 'is hidden by its switch'} at '
        'text scale 2.0 in ${locale.languageCode}',
        (tester) async {
          await tester.pumpWidget(
            _host(
              ChangeSetView(
                equipment: const [LibraryEquipment.barbell],
                weightOptionsKg: const [40, 42.5, 45],
                plateHelper: shown,
              ),
              locale: locale,
              textScale: 2,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('plate-diagram')),
            shown ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
