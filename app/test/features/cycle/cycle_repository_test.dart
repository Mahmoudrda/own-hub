// P0-CYC-01, P0-CYC-03, P0-CYC-09, P0-CYC-10, P0-CYC-11, P0-CYC-17 — the data
// layer behind setup, the period lifecycle, and logging with no signal.
//
// ## Every figure here differs from the prototype's
//
// The mockup draws September 2026, a period logged on the 15th, and an estimate
// of 12–14 October. `PHASE1-FIXES.md` #8 and #13 record five defects that
// shipped because the tests used the prototype's own sample values: "the
// parameterised label renders byte-identical text. All five existing assertions
// pass before and after the change. Only a *different* prescription
// distinguishes a real label from a constant one."
//
// So these tests run in March 2027 with a 30-day interval, and the assertions
// are on numbers no constant in the codebase could coincidentally match.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/cycle/domain/cycle_document.dart';
import 'package:own_hub/features/cycle/domain/cycle_projection_reconciler.dart';
import 'package:own_hub/features/cycle/domain/cycle_repository.dart';
import 'package:own_hub/features/cycle/domain/period_entry.dart';

// Deliberately not the mockup's September 2026.
final DateTime _today = DateTime(2027, 3, 20);

PeriodEntry _period(DateTime start, {DateTime? end}) {
  final result = PeriodEntry.validate(start: start, end: end, today: _today);
  expect(result, isA<PeriodValid>(), reason: 'fixture must be valid');
  return (result as PeriodValid).entry;
}

({InMemoryCycleRepository cycles, InMemoryPeriodRepository periods}) _repos() {
  final cycles = InMemoryCycleRepository();
  return (cycles: cycles, periods: InMemoryPeriodRepository(cycles: cycles));
}

void main() {
  group('P0-CYC-03 — skipping setup leaves the app exactly as it was', () {
    test('no document exists until setup completes', () {
      final repos = _repos();

      expect(repos.cycles.current, isNull);
      expect(
        repos.cycles.store.writes,
        isEmpty,
        reason:
            'skipping writes nothing at all — §3.1 notSetUp is "no '
            'cycle/current document", and Home shows no trace of the feature',
      );
    });

    test(
      'a purge returns to a state indistinguishable from never set up',
      () async {
        final repos = _repos();
        await repos.cycles.completeSetup(mode: CycleMode.datesAndSymptoms);
        await repos.periods.save(_period(DateTime(2027, 3, 5)));

        await repos.cycles.purge();

        expect(repos.cycles.current, isNull);
        expect(repos.cycles.store.periods, isEmpty);
        expect(
          resolveCycleSetupState(repos.cycles.current),
          CycleSetupState.notSetUp,
        );
      },
    );
  });

  group('P0-CYC-01 — setup writes what she chose, and nothing she did not', () {
    test('sharing is off and no cycle length is invented', () async {
      final repos = _repos();
      await repos.cycles.completeSetup(
        mode: CycleMode.datesAndSymptoms,
        contextFlags: {CycleContextFlag.none},
      );

      final cycle = repos.cycles.current!;
      expect(cycle.mode, CycleMode.datesAndSymptoms);
      expect(cycle.sharing.isAllOff, isTrue);
      expect(
        cycle.cycleLengthDays,
        isNull,
        reason: 'nothing pre-fills 28 days — "Not sure" stays not sure',
      );
    });

    test('saving preferences keeps a null cycle length null', () async {
      final repos = _repos();
      await repos.cycles.completeSetup(mode: CycleMode.datesAndSymptoms);
      await repos.cycles.savePreferences(
        cycleLengthDays: null,
        adaptation: CycleAdaptation.y02Defaults,
      );

      expect(repos.cycles.current!.cycleLengthDays, isNull);
      expect(repos.cycles.current!.adaptation.homeCard, isTrue);
    });

    test('a stated cycle length is stored as given', () async {
      final repos = _repos();
      await repos.cycles.completeSetup(mode: CycleMode.datesAndSymptoms);
      // 31, not the 28 any default would produce.
      await repos.cycles.savePreferences(
        cycleLengthDays: 31,
        adaptation: CycleAdaptation.allOff,
      );

      expect(repos.cycles.current!.cycleLengthDays, 31);
    });

    test('symptom-only mode resolves to its own state', () async {
      final repos = _repos();
      await repos.cycles.completeSetup(mode: CycleMode.symptomsOnly);

      expect(
        resolveCycleSetupState(repos.cycles.current),
        CycleSetupState.symptomsOnly,
      );
      expect(ForecastPolicy.isEnabled(repos.cycles.current), isFalse);
    });

    test(
      'a context flag removes forecasting rather than degrading it',
      () async {
        final repos = _repos();
        await repos.cycles.completeSetup(
          mode: CycleMode.datesAndSymptoms,
          contextFlags: {CycleContextFlag.perimenopause},
        );

        expect(
          resolveCycleSetupState(repos.cycles.current),
          CycleSetupState.forecastSuppressed,
        );
        expect(ForecastPolicy.isEnabled(repos.cycles.current), isFalse);
      },
    );
  });

  group(
    'P0-CYC-09 / P0-CYC-11 — a period can be added, corrected, deleted',
    () {
      test(
        'saving writes the period and rebuilds the derived fields',
        () async {
          final repos = _repos();
          await repos.cycles.completeSetup(mode: CycleMode.datesAndSymptoms);

          await repos.periods.save(_period(DateTime(2027, 3, 5)));

          expect(repos.cycles.store.periods.keys, ['2027-03-05']);
          expect(repos.cycles.current!.lastPeriod!.startDate, '2027-03-05');
          expect(repos.cycles.current!.recentStarts, ['2027-03-05']);
          expect(
            repos.cycles.current!.lastPeriod!.stillBleeding,
            isTrue,
            reason:
                'no end date means still bleeding — the two cannot disagree',
          );
        },
      );

      test('setting an end date clears the still-bleeding flag', () async {
        final repos = _repos();
        await repos.cycles.completeSetup(mode: CycleMode.datesAndSymptoms);

        await repos.periods.save(_period(DateTime(2027, 3, 5)));
        await repos.periods.save(
          _period(DateTime(2027, 3, 5), end: DateTime(2027, 3, 9)),
        );

        expect(repos.cycles.current!.lastPeriod!.endDate, '2027-03-09');
        expect(repos.cycles.current!.lastPeriod!.stillBleeding, isFalse);
        expect(
          repos.cycles.store.periods.length,
          1,
          reason: 'the id IS the start date, so correcting it is not a new doc',
        );
      });

      test('editing the start date deletes the old document', () async {
        final repos = _repos();
        await repos.cycles.completeSetup(mode: CycleMode.datesAndSymptoms);
        await repos.periods.save(_period(DateTime(2027, 3, 5)));

        await repos.periods.replace(
          oldId: '2027-03-05',
          entry: _period(DateTime(2027, 3, 7)),
        );

        expect(repos.cycles.store.periods.keys, ['2027-03-07']);
        expect(
          repos.cycles.current!.recentStarts,
          ['2027-03-07'],
          reason:
              'estimates built on the old date are cleared in the same '
              'transaction — that is what makes Y09\'s note true',
        );
      });

      test('deleting a period recomputes the patterns without it', () async {
        final repos = _repos();
        await repos.cycles.completeSetup(mode: CycleMode.datesAndSymptoms);
        await repos.periods.save(_period(DateTime(2027, 1, 4)));
        await repos.periods.save(_period(DateTime(2027, 2, 3)));
        await repos.periods.save(_period(DateTime(2027, 3, 5)));

        expect(repos.cycles.current!.recentStarts.length, 3);

        await repos.periods.remove('2027-03-05');

        expect(repos.cycles.current!.recentStarts, [
          '2027-02-03',
          '2027-01-04',
        ]);
        expect(repos.cycles.current!.lastPeriod!.startDate, '2027-02-03');
      });

      test('a month query returns only that month', () async {
        final repos = _repos();
        await repos.cycles.completeSetup(mode: CycleMode.datesAndSymptoms);
        await repos.periods.save(_period(DateTime(2027, 2, 3)));
        await repos.periods.save(_period(DateTime(2027, 3, 5)));

        final march = await repos.periods.inMonth(year: 2027, month: 3);
        expect(march.map((p) => p.id), ['2027-03-05']);
      });
    },
  );

  group('P0-CYC-10 — impossible dates are refused, never stored', () {
    test('a future start is refused and nothing is written', () async {
      final repos = _repos();
      await repos.cycles.completeSetup(mode: CycleMode.datesAndSymptoms);
      final writesBefore = repos.cycles.store.writes.length;

      final result = PeriodEntry.validate(
        start: DateTime(2027, 3, 25),
        today: _today,
      );

      expect(result, isA<PeriodInvalid>());
      expect(
        (result as PeriodInvalid).problems,
        contains(PeriodProblem.startInFuture),
      );
      // There is no entry to save, so nothing could have been written.
      expect(repos.cycles.store.writes.length, writesBefore);
      expect(repos.cycles.store.periods, isEmpty);
    });

    test('an end before the start is refused', () {
      final result = PeriodEntry.validate(
        start: DateTime(2027, 3, 15),
        end: DateTime(2027, 3, 10),
        today: _today,
      );

      expect(result, isA<PeriodInvalid>());
      expect(
        (result as PeriodInvalid).problems,
        contains(PeriodProblem.endBeforeStart),
      );
    });

    test('both problems are reported at once, not one at a time', () {
      final result = PeriodEntry.validate(
        start: DateTime(2027, 4, 2),
        end: DateTime(2027, 4, 1),
        today: _today,
      );

      expect(
        (result as PeriodInvalid).problems,
        containsAll([
          PeriodProblem.startInFuture,
          PeriodProblem.endBeforeStart,
        ]),
      );
    });

    test('today is not the future', () {
      // The boundary. An off-by-one here would refuse a period starting today,
      // which is the single most common thing she will log.
      expect(
        PeriodEntry.validate(start: _today, today: _today),
        isA<PeriodValid>(),
      );
    });
  });

  group('P0-CYC-17 — offline, a period saves with no signal', () {
    test('it lands locally and is marked queued', () async {
      final repos = _repos();
      await repos.cycles.completeSetup(mode: CycleMode.datesAndSymptoms);
      repos.cycles.goOffline();

      await repos.cycles.setAdaptation(const CycleAdaptation(homeCard: true));
      await repos.periods.save(_period(DateTime(2027, 3, 18)));

      // Visible immediately — from her point of view it is saved, because it is.
      expect(repos.cycles.store.periods.containsKey('2027-03-18'), isTrue);
      expect(repos.cycles.current!.recentStarts, contains('2027-03-18'));
      expect(repos.cycles.queued, isNotEmpty);
    });

    test('reconnecting produces no duplicate and no second period', () async {
      final repos = _repos();
      await repos.cycles.completeSetup(mode: CycleMode.datesAndSymptoms);
      repos.cycles.goOffline();
      await repos.periods.save(_period(DateTime(2027, 3, 18)));

      await repos.cycles.goOnline();
      // A replay of the same write, which is what a retry does.
      await repos.periods.save(_period(DateTime(2027, 3, 18)));

      expect(
        repos.cycles.store.periods.length,
        1,
        reason:
            'the id IS the start date, so a replayed retry targets the same '
            'document and collapses into the same state',
      );
      expect(repos.cycles.queued, isEmpty);
    });
  });

  group('the bounded projection', () {
    test('recentStarts never exceeds twelve', () async {
      final repos = _repos();
      await repos.cycles.completeSetup(mode: CycleMode.datesAndSymptoms);

      // Fifteen periods, roughly monthly through 2026.
      for (var i = 0; i < 15; i++) {
        await repos.periods.save(
          _period(DateTime(2026, 1, 3).add(Duration(days: 30 * i))),
        );
      }

      expect(
        repos.cycles.current!.recentStarts.length,
        CycleDocument.maxRecentStarts,
      );
    });

    test('the reconciler is idempotent', () {
      const reconciler = CycleProjectionReconciler();
      final periods = [
        _period(DateTime(2027, 1, 4)),
        _period(DateTime(2027, 3, 5)),
        _period(DateTime(2027, 2, 3)),
      ];

      final once = reconciler.rebuild(periods);
      final twice = reconciler.rebuild(periods);

      expect(once.recentStarts, twice.recentStarts);
      expect(once.lastPeriod!.startDate, twice.lastPeriod!.startDate);
      // Newest first, whatever order they arrived in.
      expect(once.recentStarts, ['2027-03-05', '2027-02-03', '2027-01-04']);
    });

    test('rebuilding from nothing clears the cache rather than keeping it', () {
      const reconciler = CycleProjectionReconciler();
      final projection = reconciler.rebuild(const <PeriodEntry>[]);

      expect(projection.lastPeriod, isNull);
      expect(projection.recentStarts, isEmpty);
    });
  });

  group('the listener is attached once per session', () {
    test('watch does not re-read per screen', () {
      final repos = _repos();
      expect(repos.cycles.attachCount, 0);

      repos.cycles.watch();
      expect(repos.cycles.attachCount, 1);
    });
  });
}
