// My cycle tells her what happened and lets her put it right.
//
// Y08's logged days open their period on Y09; Y09 names what it saved or
// removed; Y12 says what deleting takes before she confirms, and the check-ins
// go with it; the severe-pain card points to a doctor instead of two buttons
// that opened nothing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/cycle_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/cycle/domain/cycle_document.dart';
import 'package:own_hub/features/cycle/domain/cycle_repository.dart';
import 'package:own_hub/features/cycle/domain/period_entry.dart';
import 'package:own_hub/features/cycle/domain/today_check_in.dart';
import 'package:own_hub/features/cycle/presentation/cycle_calendar_view.dart';
import 'package:own_hub/features/cycle/presentation/cycle_settings_view.dart';
import 'package:own_hub/features/cycle/presentation/log_period_view.dart';
import 'package:own_hub/features/cycle/presentation/symptom_labels.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _today = DateTime(2027, 3, 20);
final AppL10n _en = AppL10nEn();

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  home: child,
);

PeriodEntry _period(DateTime start, {DateTime? end}) {
  final result = PeriodEntry.validate(start: start, end: end, today: _today);
  return (result as PeriodValid).entry;
}

/// A repository whose purge fails, the way a lost connection would.
class _FailingPurge extends InMemoryCycleRepository {
  @override
  Future<void> purge() async => throw StateError('no signal');
}

void main() {
  final savedFlags = AppRouter.featureFlags;
  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppRouter.todayCheckIn = TodayCheckIn.absent;
  });

  test('the check-in summary names only what she chose', () {
    expect(
      checkInSummary(
        _en,
        const TodayCheckIn(energy: Energy.low, cramps: Cramps.mild),
      ),
      'Energy: Low · Cramps: Mild',
    );
    expect(checkInSummary(_en, TodayCheckIn.absent), isEmpty);
  });

  test('period labels name her dates', () {
    final closed = _period(DateTime(2027, 3, 5), end: DateTime(2027, 3, 8));
    final open = _period(DateTime(2027, 3, 18));
    expect(
      periodSavedLabel(_en, closed),
      'Period saved · 2027-03-05 to 2027-03-08',
    );
    expect(periodSavedLabel(_en, open), 'Period saved · from 2027-03-18');
    expect(
      periodRemovedLabel(_en, closed),
      'Period removed · 2027-03-05 to 2027-03-08',
    );
  });

  testWidgets('Y08: a logged day opens its own period', (tester) async {
    final period = _period(DateTime(2027, 3, 5), end: DateTime(2027, 3, 8));
    PeriodEntry? opened;
    _phone(tester);
    await tester.pumpWidget(
      _host(
        CycleCalendarView(
          cycle: CycleDocument(mode: CycleMode.datesAndSymptoms),
          year: 2027,
          month: 3,
          now: _today,
          periods: [period],
          onOpenPeriod: (p) => opened = p,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tap a logged day to change it.'), findsOneWidget);
    await tester.tap(find.text('6'));
    await tester.pumpAndSettle();
    expect(opened?.id, period.id);

    // A day that is not a period day opens nothing.
    opened = null;
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    expect(opened, isNull);
  });

  testWidgets('Y09 opened on a period offers to delete it', (tester) async {
    final period = _period(DateTime(2027, 3, 5), end: DateTime(2027, 3, 8));
    final repository = InMemoryCycleRepository();
    await repository.completeSetup(mode: CycleMode.datesAndSymptoms);
    final periods = InMemoryPeriodRepository(cycles: repository);
    await periods.save(period);
    var deleted = 0;
    _phone(tester);
    await tester.pumpWidget(
      _host(
        LogPeriodView(
          repository: periods,
          existing: period,
          now: _today,
          onDeleted: () => deleted++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete this period'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
    expect(await periods.recent(), isEmpty);
  });

  group('Y12 delete cycle data', () {
    setUp(() => AppRouter.featureFlags = FeatureFlags.allOff);

    testWidgets('says what goes before she confirms', (tester) async {
      final repository = InMemoryCycleRepository();
      await repository.completeSetup(mode: CycleMode.datesAndSymptoms);
      var deleted = 0;
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleSettingsView(
            cycle: repository.current,
            repository: repository,
            onDeleted: () => deleted++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ask = find.text('Delete cycle data');
      await tester.ensureVisible(ask);
      await tester.tap(ask);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This deletes your period dates, check-ins and cycle settings from '
          'this phone. It cannot be undone.',
        ),
        findsOneWidget,
      );

      final confirm = find.text('Delete cycle data').first;
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(deleted, 1);
      expect(repository.current, isNull);
    });

    testWidgets('a failed delete claims nothing', (tester) async {
      final repository = _FailingPurge();
      await repository.completeSetup(mode: CycleMode.datesAndSymptoms);
      var deleted = 0;
      _phone(tester);
      await tester.pumpWidget(
        _host(
          Scaffold(
            body: CycleSettingsView(
              cycle: repository.current,
              repository: repository,
              onDeleted: () => deleted++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ask = find.text('Delete cycle data');
      await tester.ensureVisible(ask);
      await tester.tap(ask);
      await tester.pumpAndSettle();
      final confirm = find.text('Delete cycle data').first;
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(deleted, 0);
      expect(find.text('Nothing was deleted. Try again.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    test('her check-ins go with the rest', () {
      CycleAppState.instance.saveCheckIn(
        const TodayCheckIn(energy: Energy.low),
      );
      expect(CycleAppState.instance.checkIns, isNotEmpty);

      CycleAppState.instance.purged();

      expect(CycleAppState.instance.checkIns, isEmpty);
      expect(AppRouter.todayCheckIn, TodayCheckIn.absent);
    });
  });
}
