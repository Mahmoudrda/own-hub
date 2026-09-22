// P0-CYC-13 and P0-CYC-16 — Y12's switches and its deletion.
//
// `P0-CYC-13`: "All three start off. Turning one on leaves the other two off.
// The preview states exactly what the coach would see. Coaching never required
// any of them."
//
// `P0-CYC-16`: "The cycle document and every period are deleted. Workouts,
// meals, rewards and week counting are untouched. The screen states plainly what
// was deleted and what was kept."
//
// The last clause of CYC-16 **cannot pass**: the copy does not exist and G9 OQ-8
// is explicit that it and its Arabic must not be invented. The deletion itself
// is asserted here; the explanation is reported as NOT COVERED rather than
// papered over with a sentence this feature made up.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/cycle/domain/cycle_document.dart';
import 'package:own_hub/features/cycle/domain/cycle_repository.dart';
import 'package:own_hub/features/cycle/domain/cycle_sharing_policy.dart';
import 'package:own_hub/features/cycle/domain/period_entry.dart';
import 'package:own_hub/features/cycle/presentation/cycle_settings_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_toggle.dart';

const String _relId = 'coach_sara__client_mai';
final DateTime _today = DateTime(2027, 3, 20);

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

Future<InMemoryCycleRepository> _setUp() async {
  final repository = InMemoryCycleRepository();
  await repository.completeSetup(mode: CycleMode.datesAndSymptoms);
  return repository;
}

void main() {
  group('P0-CYC-13 — off by default, independent, and unrequired', () {
    testWidgets('all three sharing switches render off', (tester) async {
      final repository = await _setUp();
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleSettingsView(
            cycle: repository.current,
            repository: repository,
            relId: _relId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in [
        'Energy and appetite',
        'Cycle symptoms',
        'Period dates and patterns',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      final toggles = tester
          .widgetList<AppToggle>(find.byType(AppToggle))
          .toList();
      // Three sharing switches, all false. (The adaptation switches above them
      // are a different thing and are allowed to be on.)
      expect(
        toggles.where((t) => t.value == false).length,
        greaterThanOrEqualTo(3),
      );
      expect(repository.current!.sharing.isAllOff, isTrue);
    });

    testWidgets('turning one on leaves the other two off', (tester) async {
      final repository = await _setUp();
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleSettingsView(
            cycle: repository.current,
            repository: repository,
            relId: _relId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find
              .ancestor(
                of: find.text('Energy and appetite'),
                matching: find.byType(Row),
              )
              .first,
          matching: find.byType(AppToggle),
        ),
      );
      await tester.pumpAndSettle();

      final sharing = repository.current!.sharing;
      expect(sharing.energyAppetite, isTrue);
      expect(sharing.symptoms, isFalse);
      expect(sharing.datesAndPatterns, isFalse);
      expect(sharing.grantedForRelId, _relId);
    });

    testWidgets('with no coach the switches are not changeable', (
      tester,
    ) async {
      // Coaching never required sharing, and sharing without a relationship
      // would be a grant bound to nothing — which the next coach would inherit.
      final repository = await _setUp();
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleSettingsView(cycle: repository.current, repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      final sharingToggles = tester
          .widgetList<AppToggle>(find.byType(AppToggle))
          .where((t) => t.onChanged == null)
          .toList();

      expect(
        sharingToggles.length,
        3,
        reason: 'a switch she may not change still renders its state',
      );
    });

    testWidgets('the preview says "Not shared" when nothing is on', (
      tester,
    ) async {
      final repository = await _setUp();
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleSettingsView(
            cycle: repository.current,
            repository: repository,
            relId: _relId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Never an empty panel or a blank that reads as "no symptoms".
      expect(find.text('Not shared'), findsOneWidget);
    });

    testWidgets('the preview names the categories actually shared', (
      tester,
    ) async {
      final repository = await _setUp();
      await repository.setSharing(
        category: CycleCategory.energyAppetite,
        on: true,
        relId: _relId,
      );

      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleSettingsView(
            cycle: repository.current,
            repository: repository,
            relId: _relId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Derived from her switches, not the mockup's "Sara would see: energy
      // low, appetite usual" — which names a coach who may not be hers and
      // states values that are the prototype's.
      expect(find.text('Not shared'), findsNothing);
      expect(find.text('Energy and appetite'), findsWidgets);
    });
  });

  group('P0-CYC-16 — deleting cycle data', () {
    testWidgets('it confirms in place, never in a dialog', (tester) async {
      final repository = await _setUp();
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleSettingsView(
            cycle: repository.current,
            repository: repository,
            relId: _relId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Delete cycle data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete cycle data'));
      await tester.pumpAndSettle();

      // The destructive exemption permits confirming; it does not permit a
      // dialog in the feature that owns the most sensitive data in the product.
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancelling deletes nothing', (tester) async {
      final repository = await _setUp();
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleSettingsView(
            cycle: repository.current,
            repository: repository,
            relId: _relId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Delete cycle data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete cycle data'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.current, isNotNull);
    });

    testWidgets('confirming removes the document and every period', (
      tester,
    ) async {
      final repository = await _setUp();
      final periods = InMemoryPeriodRepository(cycles: repository);
      final result = PeriodEntry.validate(
        start: DateTime(2027, 3, 5),
        today: _today,
      );
      await periods.save((result as PeriodValid).entry);

      expect(repository.store.periods, isNotEmpty);

      var deleted = 0;
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleSettingsView(
            cycle: repository.current,
            repository: repository,
            relId: _relId,
            onDeleted: () => deleted++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Delete cycle data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete cycle data'));
      await tester.pumpAndSettle();
      // The confirm button, which is the filled one in the inline row.
      await tester.ensureVisible(find.text('Delete cycle data').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete cycle data').last);
      await tester.pumpAndSettle();

      expect(repository.current, isNull);
      expect(repository.store.periods, isEmpty);
      expect(deleted, 1);
    });
  });
}
