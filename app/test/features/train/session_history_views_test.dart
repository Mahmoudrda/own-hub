// The move history sheet, the recent sessions list and fixing a set.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_changes.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/set_history.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/move_history_sheet.dart';
import 'package:own_hub/features/train/presentation/recent_sessions_view.dart';
import 'package:own_hub/features/train/presentation/session_edit_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(
  Widget home, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

LoggedSet _set(String id, int order, {double? kg, int? reps, int? hold}) =>
    LoggedSet(
      prescribed: PrescribedSet(exerciseId: id, order: order, reps: 10),
      outcome: SetOutcome(weightKg: kg, reps: reps, holdSeconds: hold),
    );

InMemoryTrainRepository _repo() {
  const done = [
    TrainSession(
      id: 'a',
      source: SessionSource.live,
      dateKey: '2026-10-01',
      sets: [],
      completed: true,
      endedReason: EndedReason.finished,
    ),
    TrainSession(
      id: 'b',
      source: SessionSource.live,
      dateKey: '2026-10-08',
      sets: [],
      completed: true,
      endedReason: EndedReason.finished,
    ),
  ];
  return InMemoryTrainRepository()..restore(
    sessions: done,
    flushes: [
      (
        sessionId: 'a',
        exerciseId: 'hip_thrust',
        sets: [_set('hip_thrust', 1, kg: 40, reps: 10)],
      ),
      (
        sessionId: 'b',
        exerciseId: 'hip_thrust',
        sets: [
          _set('hip_thrust', 1, kg: 45, reps: 10),
          _set('hip_thrust', 2, kg: 45, reps: 8),
        ],
      ),
      (sessionId: 'b', exerciseId: 'plank', sets: [_set('plank', 1, hold: 45)]),
    ],
  );
}

String _name(String id) => id == 'plank' ? 'Plank' : 'Hip thrust';

Future<void> _openSheet(
  WidgetTester tester,
  InMemoryTrainRepository repo, {
  Locale locale = const Locale('en'),
  double scale = 1,
  String move = 'hip_thrust',
}) async {
  await tester.pumpWidget(
    _host(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showMoveHistorySheet(
              context,
              moveName: _name(move),
              history: moveHistory(repo, move),
            ),
            child: const Text('open'),
          ),
        ),
      ),
      locale: locale,
      scale: scale,
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('move history sheet', () {
    for (final (locale, scale) in [
      (const Locale('en'), 1.0),
      (const Locale('en'), 2.0),
      (const Locale('ar'), 1.0),
      (const Locale('ar'), 2.0),
    ]) {
      testWidgets('rows and bars, $locale at $scale', (tester) async {
        await _openSheet(tester, _repo(), locale: locale, scale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('Hip thrust'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('move-history-row-b')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('move-history-row-a')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('move-history-bars')), findsOneWidget);
        // Newest session first.
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('move-history-row-b')))
              .dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const ValueKey('move-history-row-a')))
                .dy,
          ),
        );
        // Western digits, even in Arabic.
        expect(find.textContaining('45'), findsWidgets);
        expect(find.textContaining('٤'), findsNothing);
        final close = tester.getSize(
          find.byKey(const ValueKey('move-history-close')),
        );
        expect(close.height, greaterThanOrEqualTo(48));
      });
    }

    testWidgets('sets read as weight × reps in English', (tester) async {
      await _openSheet(tester, _repo());
      expect(find.text('45 kg × 10 · 45 kg × 8'), findsOneWidget);
      expect(find.text('1 October 2026'), findsOneWidget);
    });

    testWidgets('a hold reads in seconds', (tester) async {
      await _openSheet(tester, _repo(), move: 'plank');
      expect(find.text('45 s'), findsOneWidget);
    });

    testWidgets('the bar of the best set is taller for the heavier session', (
      tester,
    ) async {
      await _openSheet(tester, _repo());
      final a = tester.getSize(
        find.byKey(const ValueKey('move-history-bar-a')),
      );
      final b = tester.getSize(
        find.byKey(const ValueKey('move-history-bar-b')),
      );
      expect(b.height, greaterThan(a.height));
    });

    testWidgets('bars are hidden from the screen reader, rows are labelled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _openSheet(tester, _repo());
      expect(
        find.bySemanticsLabel(RegExp('Best set on 8 October 2026: 45 kg × 10')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('empty state', (tester) async {
      await _openSheet(tester, InMemoryTrainRepository());
      expect(find.text('No sessions of this move yet'), findsOneWidget);
    });
  });

  group('recent sessions and fixing a set', () {
    testWidgets('lists finished sessions newest first with counts', (
      tester,
    ) async {
      final repo = _repo();
      await tester.pumpWidget(
        _host(
          RecentSessionsView(
            repository: repo,
            nameFor: _name,
            onSessionEdited: (_) {},
          ),
        ),
      );
      expect(find.text('Hip thrust · Plank'), findsOneWidget);
      expect(find.text('Hip thrust'), findsOneWidget);
      expect(find.textContaining('Moves: 2 · Sets: 3'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('recent-b'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('recent-a'))).dy),
      );
    });

    testWidgets('empty list', (tester) async {
      await tester.pumpWidget(
        _host(
          RecentSessionsView(
            repository: InMemoryTrainRepository(),
            nameFor: _name,
            onSessionEdited: (_) {},
          ),
        ),
      );
      expect(find.text('No finished sessions yet'), findsOneWidget);
    });

    testWidgets(
      'tapping a session opens it, in Arabic at 2.0 without overflow',
      (tester) async {
        await tester.pumpWidget(
          _host(
            RecentSessionsView(
              repository: _repo(),
              nameFor: _name,
              onSessionEdited: (_) {},
            ),
            locale: const Locale('ar'),
            scale: 2,
          ),
        );
        await tester.tap(find.byKey(const ValueKey('recent-b')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('session-edit-note')), findsOneWidget);
        expect(tester.takeException(), isNull);
        final edit = tester.getSize(
          find.byKey(const ValueKey('edit-set-1')).first,
        );
        expect(edit.height, greaterThanOrEqualTo(48));
        expect(edit.width, greaterThanOrEqualTo(48));
        await tester.tap(find.byKey(const ValueKey('edit-set-2')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('edit-save')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    Future<List<String>> pumpEdit(
      WidgetTester tester,
      InMemoryTrainRepository repo,
    ) async {
      final edited = <String>[];
      await tester.pumpWidget(
        _host(
          SessionEditView(
            sessionId: 'b',
            repository: repo,
            nameFor: _name,
            onSessionEdited: edited.add,
          ),
        ),
      );
      return edited;
    }

    testWidgets('fixing a set rewrites it and calls back with the id', (
      tester,
    ) async {
      final repo = _repo();
      final edited = await pumpEdit(tester, repo);
      expect(
        find.text('Fixing a typo updates your bests. Points stay as they are.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('edit-set-2')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('edit-weight')), '47.5');
      await tester.enterText(find.byKey(const ValueKey('edit-reps')), '9');
      await tester.tap(find.byKey(const ValueKey('edit-save')));
      await tester.pumpAndSettle();

      expect(edited, ['b']);
      final now = repo
          .loggedSetsFor(sessionId: 'b', exerciseId: 'hip_thrust')
          .last
          .outcome!;
      expect(now.weightKg, 47.5);
      expect(now.reps, 9);
      expect(find.text('Set 2 · 47.5 kg × 9'), findsOneWidget);
      expect(find.text('Set 2 is now 47.5 kg × 9'), findsOneWidget);
    });

    testWidgets('a fix and its undo both ask for a save', (tester) async {
      final repo = _repo();
      var bumps = 0;
      void onBump() => bumps++;
      AppChanges.instance.addListener(onBump);
      addTearDown(() => AppChanges.instance.removeListener(onBump));
      await pumpEdit(tester, repo);
      await tester.tap(find.byKey(const ValueKey('edit-set-2')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('edit-weight')), '45');
      await tester.tap(find.byKey(const ValueKey('edit-save')));
      await tester.pumpAndSettle();
      expect(bumps, 1);
      expect(
        repo
            .loggedSetsFor(sessionId: 'b', exerciseId: 'hip_thrust')
            .last
            .outcome!
            .weightKg,
        45,
      );
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(bumps, 2);
    });

    testWidgets('a figure outside the bounds is refused', (tester) async {
      final repo = _repo();
      final edited = await pumpEdit(tester, repo);
      await tester.tap(find.byKey(const ValueKey('edit-set-2')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('edit-weight')), '301');
      await tester.tap(find.byKey(const ValueKey('edit-save')));
      await tester.pumpAndSettle();
      expect(find.text('Weight must be 0 to 300 kg'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('edit-weight')), '45');
      await tester.enterText(find.byKey(const ValueKey('edit-reps')), '101');
      await tester.tap(find.byKey(const ValueKey('edit-save')));
      await tester.pumpAndSettle();
      expect(find.text('Reps must be 0 to 100'), findsOneWidget);
      expect(edited, isEmpty);
      expect(
        repo
            .loggedSetsFor(sessionId: 'b', exerciseId: 'hip_thrust')
            .last
            .outcome!
            .reps,
        8,
      );
    });

    testWidgets('a hold is fixed in seconds', (tester) async {
      final repo = _repo();
      await pumpEdit(tester, repo);
      await tester.tap(find.byKey(const ValueKey('edit-set-1')).last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('edit-seconds')), findsOneWidget);
      expect(find.byKey(const ValueKey('edit-weight')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('edit-seconds')), '601');
      await tester.tap(find.byKey(const ValueKey('edit-save')));
      await tester.pumpAndSettle();
      expect(find.text('Seconds must be 0 to 600'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('edit-seconds')), '50');
      await tester.tap(find.byKey(const ValueKey('edit-save')));
      await tester.pumpAndSettle();
      expect(
        repo
            .loggedSetsFor(sessionId: 'b', exerciseId: 'plank')
            .single
            .outcome!
            .holdSeconds,
        50,
      );
    });

    testWidgets('undo puts the old figure back and calls back again', (
      tester,
    ) async {
      final repo = _repo();
      final edited = await pumpEdit(tester, repo);
      await tester.tap(find.byKey(const ValueKey('edit-set-2')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('edit-reps')), '12');
      await tester.tap(find.byKey(const ValueKey('edit-save')));
      await tester.pumpAndSettle();
      expect(edited, ['b']);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(edited, ['b', 'b']);
      final back = repo
          .loggedSetsFor(sessionId: 'b', exerciseId: 'hip_thrust')
          .last
          .outcome!;
      expect(back.reps, 8);
      expect(back.weightKg, 45);
      expect(find.text('Set 2 · 45 kg × 8'), findsOneWidget);
    });

    test('correctedOutcome refuses what a set cannot be', () {
      const old = SetOutcome(weightKg: 40, reps: 10);
      expect(correctedOutcome(old, weightKg: 300, reps: 100), isNotNull);
      expect(correctedOutcome(old, weightKg: 0, reps: 0), isNotNull);
      expect(correctedOutcome(old, weightKg: 300.5, reps: 10), isNull);
      expect(correctedOutcome(old, weightKg: -1, reps: 10), isNull);
      expect(correctedOutcome(old, weightKg: 40, reps: 101), isNull);
      expect(correctedOutcome(old, weightKg: 40, reps: null), isNull);
      expect(correctedOutcome(old, weightKg: 40.3, reps: 10)!.weightKg, 40.5);
      const hold = SetOutcome(holdSeconds: 30);
      expect(correctedOutcome(hold, holdSeconds: 600), isNotNull);
      expect(correctedOutcome(hold, holdSeconds: 601), isNull);
    });
  });
}
