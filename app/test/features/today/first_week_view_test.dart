// T07 — Your first week.
//
// HANDOFF rule 17 and `P0-FR-02`: no timer, no expiry, no failure state. The
// arc's steps simply wait. `DECISIONS.md` D1 also makes the step count
// load-bearing — all five ship, including the two that belong to Community —
// because an arc that quietly became three steps would leave T08 unreachable
// while looking finished.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/first_week_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_ring_stat.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // 390×844 at 3×
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
        // copyWith, not a bare MediaQueryData: a fresh one zeroes the window
        // size, so any widget that measures itself against the screen lays out
        // to nothing here while working perfectly in production.
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

FirstWeekView _view({
  TodayRepository? repository,
  ValueChanged<String>? onOpenStep,
}) {
  return FirstWeekView(
    repository: repository ?? InMemoryTodayRepository(),
    onClose: () {},
    onStartSession: () {},
    onOpenStep: onOpenStep ?? (_) {},
    onBackToToday: () {},
    onSeeProgress: () {},
  );
}

void main() {
  group('five concrete first actions', () {
    testWidgets('all five are listed, in order', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(find.text('Your first week'), findsOneWidget);
      for (final step in [
        'Log one set',
        'Log one meal',
        'Finish one session',
        'Join one group',
        'Add a follow-up picture',
      ]) {
        expect(find.text(step), findsOneWidget, reason: step);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the two Community steps are kept, not dropped', (
      tester,
    ) async {
      // D1 withdrew the MVP cut. Community is not built yet, so these route
      // onward and land on the router's "not built yet" page — visible rather
      // than silently missing.
      _phone(tester);
      final opened = <String>[];
      await tester.pumpWidget(_host(_view(onOpenStep: opened.add)));
      await tester.pumpAndSettle();

      for (final step in ['Join one group', 'Add a follow-up picture']) {
        await tester.ensureVisible(find.text(step));
        await tester.pumpAndSettle();
        await tester.tap(find.text(step));
        await tester.pumpAndSettle();
      }

      expect(opened, ['M04', 'M11']);
    });

    testWidgets('progress is two of five, from the arc', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      final ring = tester.widget<AppRingStat>(find.byType(AppRingStat));
      expect(ring.big, '2');
      expect(ring.small, 'of 5');
      expect(ring.fraction, 2 / 5);
      expect(find.text('Two done, three waiting'), findsOneWidget);
      expect(find.text('done'), findsNWidgets(2));
    });
  });

  group('rule 17 — nothing expires, and nothing can fail', () {
    test('there is no failed state to construct', () {
      // The absence is the enforcement: a step can only be done, current or
      // waiting, so a failure indicator is not expressible here.
      expect(ArcStepState.values, [
        ArcStepState.done,
        ArcStepState.now,
        ArcStepState.waiting,
      ]);
      expect(
        ArcStepState.values.map((s) => s.name),
        isNot(anyElement(anyOf('failed', 'expired', 'missed'))),
      );
    });

    testWidgets('and the screen says so out loud', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No timer on any of them. Miss a day and nothing here changes.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('is not a deadline'), findsOneWidget);
    });

    testWidgets('the reward is the points the app already gives', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      // "35 points so far" was a fixed string sitting two lines from
      // `widget.points`, the real figure. Label and value now, the same shape
      // T08 uses.
      expect(find.text('Points'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(find.text('35 points so far'), findsNothing);
      expect(
        find.textContaining('Nothing extra for opening it.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('every string comes from the dictionary, in Arabic too', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(_view(), locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('أسبوعك الأول'), findsOneWidget);
    expect(find.text('سجّلي مجموعة واحدة'), findsOneWidget);
    expect(find.text('انضمّي إلى مجموعة واحدة'), findsOneWidget);
    expect(find.text('Log one set'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(_view(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
