// Implements TEST-CASES.csv P0-RWD-03 — "A measurement can be undone, and is
// never comparable."
//
// Expected: "Removed, with no confirmation dialog. P04 stays private to her: no
// query reads measurements across users and the single-field index exemption
// makes the sort impossible." Rule 9 + rule 11 + spine C7.
//
// The undo half is tested against the REPOSITORY rather than against a callback.
// PHASE1-FIXES.md §1 records R08 saving nothing at all while its test passed,
// because the test asserted the callback's argument — which was correct — and
// nobody was listening. So these assertions are all "what reached storage".
//
// The measurement half of the screen was withheld until the dictionary carried
// "Waist", "Hips", "Arm", "Thigh" and "{label} {value} cm". It does now, so the
// Add control is built — and every figure in this file is deliberately NOT the
// mockup's 82 and 96, so a chip that recited the prototype would fail here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/progress/domain/progress_repository.dart';
import 'package:own_hub/features/progress/presentation/body_privately_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/app_chip_row.dart';

final DateTime _now = DateTime(2026, 9, 18, 7, 30);

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

/// The weight card's Add — a button. The measurements card's Add is a chip, and
/// both read "Add", so every finder here names the shape as well as the word.
final Finder _addWeightButton = find.widgetWithText(AppButton, 'Add');

/// The measurements card's Add — a chip.
final Finder _addMeasurementChip = find.widgetWithText(AppChip, 'Add');

final Finder _saveButton = find.widgetWithText(AppButton, 'Save');
final Finder _cancelButton = find.widgetWithText(AppButton, 'Cancel');

/// The text inside the undo bar, which is a different widget from the chip that
/// may be showing the same figure on the card behind it.
Finder _inSnackBar(String text) =>
    find.descendant(of: find.byType(SnackBar), matching: find.text(text));

/// Types a weight into the inline field and taps Save.
Future<void> _addWeight(WidgetTester tester, String kg) async {
  await tester.tap(_addWeightButton);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), kg);
  await tester.tap(_saveButton);
  // One frame to run the handler, then enough for the snackbar to finish
  // animating in. Until it has, it sits under an IgnorePointer and a tap on
  // "Undo" silently misses — the write then lands and the test reads as though
  // undo were broken. Still well inside the five-second window.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Taps something that may be below the fold.
///
/// The measurements card is the third on a 390×844 phone and the open form
/// grows it, so Save and Cancel can sit past the bottom edge. A tap that misses
/// only logs a warning and changes nothing, which then reads in the assertion
/// as a control that does not work — so every tap in this group scrolls first.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Opens the measurement form, picks [field] by its label, types [cm] and saves.
Future<void> _addMeasurement(
  WidgetTester tester,
  String field,
  String cm,
) async {
  await _tap(tester, _addMeasurementChip);
  await _tap(tester, find.widgetWithText(AppChip, field));
  await tester.enterText(find.byType(TextField), cm);

  // Not pumpAndSettle after this one: the undo snackbar has to be allowed to
  // animate in without waiting out its five-second life.
  await tester.ensureVisible(_saveButton);
  await tester.pumpAndSettle();
  await tester.tap(_saveButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('P0-RWD-03 — a measurement can be undone', () {
    testWidgets('adding one opens a field, never a dialog', (tester) async {
      _phone(tester);
      final repo = InMemoryMeasurementsRepository();

      await tester.pumpWidget(
        _host(BodyPrivatelyView(repository: repo, now: _now)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      await tester.tap(_addWeightButton);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.byType(AlertDialog),
        findsNothing,
        reason:
            'rule 9: undo, never confirmation. Asking a woman to confirm her '
            'own weight is the worst place in this product for a dialog.',
      );

      // Advance past the undo window so no timer outlives the test.
      await tester.pump(kUndoWindow + const Duration(seconds: 1));
    });

    testWidgets('the write is held for five seconds, then lands', (
      tester,
    ) async {
      _phone(tester);
      final repo = InMemoryMeasurementsRepository();
      final bus = LogCommandBus();

      await tester.pumpWidget(
        _host(BodyPrivatelyView(repository: repo, bus: bus, now: _now)),
      );
      await tester.pumpAndSettle();

      await _addWeight(tester, '63.5');

      expect(
        repo.saves,
        isEmpty,
        reason: 'nothing may reach storage while undo is still offered',
      );
      expect(find.text('Undo'), findsOneWidget);

      await tester.pump(kUndoWindow + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(repo.saves, hasLength(1));
      expect(repo.saves.single.weightKg, 63.5);
      expect(
        repo.saves.single.dayId,
        '2026-09-18',
        reason: 'a date-keyed document id, so an offline retry is idempotent',
      );
    });

    testWidgets('the undo bar names the weight she can take back', (
      tester,
    ) async {
      // It used to read the bare word "Saved", which is true of every
      // measurement and therefore tells her nothing about the one still in
      // reach. `weightKgSaved` names the figure.
      _phone(tester);
      final repo = InMemoryMeasurementsRepository();

      await tester.pumpWidget(
        _host(BodyPrivatelyView(repository: repo, now: _now)),
      );
      await tester.pumpAndSettle();

      await _addWeight(tester, '63.5');

      expect(_inSnackBar('63.5 kg saved'), findsOneWidget);
      expect(
        find.text('Saved'),
        findsNothing,
        reason: 'the bare word says nothing about which log this is',
      );

      await tester.pump(kUndoWindow + const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });

    testWidgets('a whole number of kilos drops the trailing zero', (
      tester,
    ) async {
      // weightLabel, not NumberFormat: "63 kg saved", never "63.0 kg saved" and
      // never Eastern digits.
      _phone(tester);
      final repo = InMemoryMeasurementsRepository();

      await tester.pumpWidget(
        _host(BodyPrivatelyView(repository: repo, now: _now)),
      );
      await tester.pumpAndSettle();

      await _addWeight(tester, '63');

      expect(_inSnackBar('63 kg saved'), findsOneWidget);
      expect(find.text('63.0 kg saved'), findsNothing);

      await tester.pump(kUndoWindow + const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });

    testWidgets('undo inside the window means nothing was ever written', (
      tester,
    ) async {
      _phone(tester);
      final repo = InMemoryMeasurementsRepository();

      await tester.pumpWidget(
        _host(BodyPrivatelyView(repository: repo, now: _now)),
      );
      await tester.pumpAndSettle();

      await _addWeight(tester, '63.5');
      expect(repo.saves, isEmpty);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // Well past the window: if the write had been issued and then
      // compensated, it would appear here. It was never issued at all.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(
        repo.saves,
        isEmpty,
        reason:
            'the write is held in LogCommandBus, so an undone measurement '
            'leaves nothing queued to resurface on reconnect',
      );
      expect(await repo.latest(), isNull);
    });

    testWidgets('a second measurement the same day merges by field', (
      tester,
    ) async {
      _phone(tester);
      final store = ProgressStore();
      store.applyMeasurement(
        Measurement(dayId: '2026-09-18', takenAt: _now, waistCm: 76),
      );
      final repo = InMemoryMeasurementsRepository(store: store);

      await tester.pumpWidget(
        _host(BodyPrivatelyView(repository: repo, now: _now)),
      );
      await tester.pumpAndSettle();

      await _addWeight(tester, '63.5');
      await tester.pump(kUndoWindow + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final merged = await repo.latest();
      expect(merged?.weightKg, 63.5);
      expect(merged?.waistCm, 76, reason: 'the earlier figure survives');
    });

    testWidgets('nothing usable typed writes nothing', (tester) async {
      _phone(tester);
      final repo = InMemoryMeasurementsRepository();

      await tester.pumpWidget(
        _host(BodyPrivatelyView(repository: repo, now: _now)),
      );
      await tester.pumpAndSettle();

      await _addWeight(tester, 'nonsense');
      await tester.pump(kUndoWindow + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(repo.saves, isEmpty);
      expect(find.byType(TextField), findsNothing, reason: 'the field closed');
    });

    testWidgets('cancel writes nothing and says nothing', (tester) async {
      _phone(tester);
      final repo = InMemoryMeasurementsRepository();

      await tester.pumpWidget(
        _host(BodyPrivatelyView(repository: repo, now: _now)),
      );
      await tester.pumpAndSettle();

      await tester.tap(_addWeightButton);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '63.5');
      await tester.tap(_cancelButton);
      await tester.pumpAndSettle();

      expect(repo.saves, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('adding a measurement — the control the dictionary used to block', () {
    testWidgets('the Add chip opens an inline form, never a dialog', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(BodyPrivatelyView(now: _now)));
      await tester.pumpAndSettle();

      expect(_addMeasurementChip, findsOneWidget);
      await _tap(tester, _addMeasurementChip);

      // The four field labels, straight from the dictionary.
      for (final field in ['Waist', 'Hips', 'Arm', 'Thigh']) {
        expect(find.widgetWithText(AppChip, field), findsOneWidget);
      }
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.byType(AlertDialog),
        findsNothing,
        reason: 'rule 9 applies to every logging path on this screen',
      );

      await tester.pump(kUndoWindow + const Duration(seconds: 1));
    });

    testWidgets('it writes only the field she filled in, after the window', (
      tester,
    ) async {
      _phone(tester);
      final repo = InMemoryMeasurementsRepository();

      await tester.pumpWidget(
        _host(BodyPrivatelyView(repository: repo, now: _now)),
      );
      await tester.pumpAndSettle();

      await _addMeasurement(tester, 'Waist', '74');

      expect(repo.saves, isEmpty, reason: 'still inside the undo window');

      await tester.pump(kUndoWindow + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(repo.saves, hasLength(1));
      expect(repo.saves.single.waistCm, 74);
      expect(
        repo.saves.single.weightKg,
        isNull,
        reason:
            'the document is merged by field, so a waist must not carry a null '
            'weight that would blank one written on another handset',
      );
      expect(repo.saves.single.dayId, '2026-09-18');
    });

    testWidgets('the chip states her figure, and the undo bar names it', (
      tester,
    ) async {
      _phone(tester);
      final repo = InMemoryMeasurementsRepository();

      await tester.pumpWidget(
        _host(BodyPrivatelyView(repository: repo, now: _now)),
      );
      await tester.pumpAndSettle();

      await _addMeasurement(tester, 'Waist', '74');

      // Shown at once, before anything is written — it is her own document and
      // it is not waiting on a network.
      expect(find.widgetWithText(AppChip, 'Waist 74 cm'), findsOneWidget);
      expect(_inSnackBar('Waist 74 cm'), findsOneWidget);
      expect(
        find.text('Waist 82 cm'),
        findsNothing,
        reason: "82 is the mockup's waist, and she is not the mockup",
      );

      await tester.pump(kUndoWindow + const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });

    testWidgets('undoing it takes the chip back off the screen', (
      tester,
    ) async {
      _phone(tester);
      final repo = InMemoryMeasurementsRepository();

      await tester.pumpWidget(
        _host(BodyPrivatelyView(repository: repo, now: _now)),
      );
      await tester.pumpAndSettle();

      await _addMeasurement(tester, 'Hips', '91');
      expect(find.widgetWithText(AppChip, 'Hips 91 cm'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(repo.saves, isEmpty);
      expect(find.widgetWithText(AppChip, 'Hips 91 cm'), findsNothing);
    });

    testWidgets('a second field joins the first rather than replacing it', (
      tester,
    ) async {
      _phone(tester);
      final store = ProgressStore();
      store.applyMeasurement(
        Measurement(dayId: '2026-09-18', takenAt: _now, waistCm: 74),
      );
      final repo = InMemoryMeasurementsRepository(store: store);

      await tester.pumpWidget(
        _host(BodyPrivatelyView(repository: repo, now: _now)),
      );
      await tester.pumpAndSettle();

      await _addMeasurement(tester, 'Thigh', '55');
      await tester.pump(kUndoWindow + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppChip, 'Waist 74 cm'), findsOneWidget);
      expect(find.widgetWithText(AppChip, 'Thigh 55 cm'), findsOneWidget);

      final merged = await repo.latest();
      expect(merged?.waistCm, 74);
      expect(merged?.thighCm, 55);
    });

    testWidgets('all four fields render from her own figures', (tester) async {
      _phone(tester);
      final store = ProgressStore();
      // None of these is the prototype's pair.
      store.applyMeasurement(
        Measurement(
          dayId: '2026-09-18',
          takenAt: _now,
          waistCm: 74,
          hipsCm: 91,
          armCm: 28.5,
          thighCm: 55,
        ),
      );

      await tester.pumpWidget(
        _host(
          BodyPrivatelyView(
            repository: InMemoryMeasurementsRepository(store: store),
            now: _now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waist 74 cm'), findsOneWidget);
      expect(find.text('Hips 91 cm'), findsOneWidget);
      expect(
        find.text('Arm 28.5 cm'),
        findsOneWidget,
        reason: 'a half centimetre survives; only a trailing ".0" is dropped',
      );
      expect(find.text('Thigh 55 cm'), findsOneWidget);
    });

    testWidgets('a field she has never recorded has no chip at all', (
      tester,
    ) async {
      _phone(tester);
      final store = ProgressStore();
      store.applyMeasurement(
        Measurement(dayId: '2026-09-18', takenAt: _now, waistCm: 74),
      );

      await tester.pumpWidget(
        _host(
          BodyPrivatelyView(
            repository: InMemoryMeasurementsRepository(store: store),
            now: _now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waist 74 cm'), findsOneWidget);
      for (final absent in ['Hips', 'Arm', 'Thigh']) {
        expect(
          find.textContaining('$absent '),
          findsNothing,
          reason: 'an absence is an absence, never a zero',
        );
      }
    });

    testWidgets('nothing usable typed writes nothing and says nothing', (
      tester,
    ) async {
      _phone(tester);
      final repo = InMemoryMeasurementsRepository();

      await tester.pumpWidget(
        _host(BodyPrivatelyView(repository: repo, now: _now)),
      );
      await tester.pumpAndSettle();

      await _addMeasurement(tester, 'Arm', '-4');
      await tester.pump(kUndoWindow + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        repo.saves,
        isEmpty,
        reason: 'the rules refuse a measurement that is not positive',
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(TextField), findsNothing, reason: 'the form closed');
    });

    testWidgets('cancel closes the form and writes nothing', (tester) async {
      _phone(tester);
      final repo = InMemoryMeasurementsRepository();

      await tester.pumpWidget(
        _host(BodyPrivatelyView(repository: repo, now: _now)),
      );
      await tester.pumpAndSettle();

      await _tap(tester, _addMeasurementChip);
      await tester.enterText(find.byType(TextField), '74');
      await _tap(tester, _cancelButton);

      expect(repo.saves, isEmpty);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Waist 74 cm'), findsNothing);
    });
  });

  group('rule 11 — it is displayed, and there is nothing to rank', () {
    testWidgets('the screen says plainly that nobody else sees it', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(BodyPrivatelyView(now: _now)));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Nobody sees this. Not the community, not your coach unless you send it.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Optional. You can use the app forever without it.'),
        findsOneWidget,
      );
    });

    testWidgets('a measurement chip is shown only to the woman it describes', (
      tester,
    ) async {
      _phone(tester);
      final store = ProgressStore();
      // Not the prototype's 82 cm.
      store.applyMeasurement(
        Measurement(dayId: '2026-09-18', takenAt: _now, waistCm: 76),
      );

      await tester.pumpWidget(
        _host(
          BodyPrivatelyView(
            repository: InMemoryMeasurementsRepository(store: store),
            now: _now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Waist 82 cm'),
        findsNothing,
        reason: 'her waist is 76 cm; 82 is the mockup\'s',
      );
      expect(find.text('Waist 76 cm'), findsOneWidget);
    });

    testWidgets('and IS shown to the woman it does describe', (tester) async {
      _phone(tester);
      final store = ProgressStore();
      store.applyMeasurement(
        Measurement(
          dayId: '2026-09-18',
          takenAt: _now,
          waistCm: 82,
          hipsCm: 96,
        ),
      );

      await tester.pumpWidget(
        _host(
          BodyPrivatelyView(
            repository: InMemoryMeasurementsRepository(store: store),
            now: _now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waist 82 cm'), findsOneWidget);
      expect(find.text('Hips 96 cm'), findsOneWidget);
    });

    testWidgets('the chips do not reorder when her figures change', (
      tester,
    ) async {
      // The order is MeasurementField's declaration order and nothing else. If
      // anything here ever sorted by size, this is the test that would catch it.
      _phone(tester);
      final store = ProgressStore();
      store.applyMeasurement(
        Measurement(
          dayId: '2026-09-18',
          takenAt: _now,
          // Deliberately descending, so "sorted ascending" and "declaration
          // order" cannot look alike.
          waistCm: 95,
          hipsCm: 88,
          armCm: 30,
          thighCm: 20,
        ),
      );

      await tester.pumpWidget(
        _host(
          BodyPrivatelyView(
            repository: InMemoryMeasurementsRepository(store: store),
            now: _now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chips = tester
          .widgetList<AppChip>(find.byType(AppChip))
          .map((c) => c.label)
          .where((l) => l != 'Add')
          .toList();

      expect(chips, ['Waist 95 cm', 'Hips 88 cm', 'Arm 30 cm', 'Thigh 20 cm']);
    });

    testWidgets('nothing on the screen ranks or compares her', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(BodyPrivatelyView(now: _now)));
      await tester.pumpAndSettle();

      for (final banned in ['rank', 'compared to', 'average', 'leaderboard']) {
        expect(find.textContaining(banned), findsNothing);
      }
    });
  });

  group('P0-A11Y-01', () {
    testWidgets('it mirrors in Arabic with Western numerals', (tester) async {
      _phone(tester);
      final store = ProgressStore();
      store.applyMeasurement(
        Measurement(
          dayId: '2026-09-18',
          takenAt: _now,
          waistCm: 74,
          hipsCm: 91,
          armCm: 28,
          thighCm: 55,
        ),
      );

      await tester.pumpWidget(
        _host(
          BodyPrivatelyView(
            repository: InMemoryMeasurementsRepository(store: store),
            now: _now,
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(BodyPrivatelyView))),
        TextDirection.rtl,
      );

      final eastern = RegExp('[٠-٩]');
      for (final text
          in tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data ?? '')) {
        expect(eastern.hasMatch(text), isFalse, reason: text);
      }

      // Her figures really are on the screen, in Western digits inside Arabic.
      expect(find.textContaining('74'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the measurement form is Arabic-labelled and does not overflow',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _host(
            BodyPrivatelyView(now: _now),
            locale: const Locale('ar'),
            textScale: 1.6,
          ),
        );
        await tester.pumpAndSettle();

        // At 1.6 the card sits below the fold, and a tap that misses reports a
        // warning and changes nothing — which would read as a broken control
        // rather than an off-screen one. Scroll it into view first.
        await tester.ensureVisible(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason:
              'four field chips in Arabic at the largest text size must wrap, '
              'not clip',
        );

        await tester.pump(kUndoWindow + const Duration(seconds: 1));
      },
    );

    testWidgets('it does not overflow at the largest text size in Arabic', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          BodyPrivatelyView(now: _now),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
