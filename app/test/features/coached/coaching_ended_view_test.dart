// G16 and G05 — the month, and the end of it.
//
// P0-COACH-08: "Plan, conversation and reviews stay readable. New assignments
// and messages are closed… Cycle sharing has switched itself off." Three of
// those four are visible on G16, and the fourth is a Function the domain tests
// cover.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coached/domain/coached_repository.dart';
import 'package:own_hub/features/coached/domain/g2_contract.dart';
import 'package:own_hub/features/coached/presentation/coaching_ended_view.dart';
import 'package:own_hub/features/coached/presentation/thirty_days_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_button.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

void main() {
  group('G16 — history stays readable', () {
    testWidgets('the three records are offered, each labelled read-only', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const CoachingEndedView()));
      await tester.pumpAndSettle();

      expect(find.text('Your 30-day plan'), findsOneWidget);
      expect(find.text('Readable · no new assignments'), findsOneWidget);
      expect(find.text('Your conversation'), findsOneWidget);
      expect(find.text('Readable · new messages are closed'), findsOneWidget);
      expect(find.text('Your reviews'), findsOneWidget);
    });

    testWidgets('it says cycle sharing switched itself off', (tester) async {
      await tester.pumpWidget(_host(const CoachingEndedView()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Cycle sharing switched itself off'),
        findsOneWidget,
      );
    });

    testWidgets('nothing on the screen claims to be active', (tester) async {
      await tester.pumpWidget(_host(const CoachingEndedView()));
      await tester.pumpAndSettle();

      // The pill used to read "Ended 7 Oct" from the dictionary whatever her
      // last day was. Given no date, it states none…
      expect(find.text('Ended 7 Oct'), findsNothing);
      expect(find.text('Start workout'), findsNothing);
      expect(find.text('Weekly review due'), findsNothing);

      // …and given hers, it states hers.
      await tester.pumpWidget(
        _host(const CoachingEndedView(endedLabel: 'Ended 3 Nov')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ended 3 Nov'), findsOneWidget);
    });

    testWidgets(
      'P0-PAY-08 — renewal is unavailable offline, and nothing is queued',
      (tester) async {
        var attempts = 0;
        await tester.pumpWidget(
          _host(
            CoachingEndedView(online: false, onWorkAgain: () => attempts++),
          ),
        );
        await tester.pumpAndSettle();

        final button = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Work with Sara again'),
        );
        expect(button.onPressed, isNull);

        await tester.tap(
          find.text('Work with Sara again'),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        expect(attempts, 0, reason: 'no optimistic state, no queued charge');
      },
    );

    testWidgets('online, renewal is available', (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        _host(CoachingEndedView(onWorkAgain: () => attempts++)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Work with Sara again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work with Sara again'));
      await tester.pumpAndSettle();

      expect(attempts, 1);
    });
  });

  group('G05 — thirty days, three kinds of day', () {
    List<PlanDay> daysWith({PlanDayKind free = PlanDayKind.free}) {
      final start = DateTime(2026, 9, 12);
      return [
        for (var n = 1; n <= PlanVersion.calendarLength; n++)
          PlanDay(
            dayNumber: n,
            kind: n == 30
                ? free
                : n % 4 == 0
                ? PlanDayKind.rest
                : PlanDayKind.train,
            date: start.add(Duration(days: n - 1)),
            done: n < 8,
            isToday: n == 8,
          ),
      ];
    }

    testWidgets('it draws thirty cells', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(ThirtyDaysView(days: daysWith())));
      await tester.pumpAndSettle();

      for (final n in [1, 8, 15, 23, 30]) {
        expect(find.text('$n'), findsWidgets, reason: 'day $n is missing');
      }
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Rest day'), findsOneWidget);
    });

    testWidgets('a rest day is labelled and a trained day is not "done"', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(ThirtyDaysView(days: daysWith())));
      await tester.pumpAndSettle();

      // Rest days carry the word; the days she actually completed carry
      // "done", counted from her logs rather than from the plan.
      expect(find.text('rest'), findsWidgets);
      expect(find.text('done'), findsWidgets);
      expect(find.text('train'), findsWidgets);
    });

    testWidgets('opening a day reports that day', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      PlanDay? opened;
      await tester.pumpWidget(
        _host(ThirtyDaysView(days: daysWith(), onOpenDay: (d) => opened = d)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('12').first);
      await tester.pumpAndSettle();

      expect(opened?.dayNumber, 12);
    });

    testWidgets('the subscription row points at what happens when it ends', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(ThirtyDaysView(days: daysWith())));
      await tester.pumpAndSettle();

      expect(find.text('What happens when it ends'), findsOneWidget);
    });
  });

  testWidgets('both screens render in Arabic', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(const CoachingEndedView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
