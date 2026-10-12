// T02 — I already did it.
//
// A logging surface, so §2 rule 9 is the thing under test: it saves at once and
// offers five seconds to take it back, and nothing on any path asks "are you
// sure". The sheet's own copy promises exactly that, so a confirmation here
// would make the screen lie about itself.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/already_did_it_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _tuesday = DateTime(2026, 9, 15, 9, 41);

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

/// The three rows this screen draws **when a caller gives it a history**.
///
/// `lastOtherTitle` is supplied here because the screen no longer invents one.
/// "Upper body, like last Thursday" was a fixed string offered to every woman
/// on a fresh install, and tapping Save wrote that sentence into her log as the
/// session's title. Nothing in the shipping build can name her last other
/// session, so the router passes nothing and the row is not drawn there; these
/// cases are about the row when the data exists, and `_viewWithNoHistory` below
/// is about the case when it does not.
AlreadyDidItView _view({TodayRepository? repository}) {
  return AlreadyDidItView(
    repository:
        repository ??
        InMemoryTodayRepository(
          day: InMemoryTodayRepository.defaultDay(date: _tuesday),
        ),
    lastOtherTitle: 'Upper body, like last Thursday',
    onLogged: (_) {},
    onStartSession: () {},
    onOpenMeal: () {},
    onSelectTab: (_) {},
  );
}

/// The same screen on a fresh install: no plan detail, no history.
AlreadyDidItView _viewWithNoHistory() => AlreadyDidItView(
  repository: InMemoryTodayRepository(
    day: InMemoryTodayRepository.defaultDay(date: _tuesday),
  ),
  onLogged: (_) {},
  onStartSession: () {},
  onOpenMeal: () {},
  onSelectTab: (_) {},
);

/// The sheet is taller than a phone, so anything below the fold is scrolled to
/// before it is tapped — the same thing a woman's thumb does.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

/// Lets the undo offer finish animating in. Until it has it sits behind an
/// IgnorePointer, and a tap aimed at Undo would fall through to the sheet.
Future<void> _settleSnackBar(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 800));

void main() {
  group('three likely answers, not one guess', () {
    testWidgets('the plan, her last other session, and time alone', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(find.text('What did you do?'), findsOneWidget);
      expect(
        find.text('Tap one and it is saved. Undo for five seconds.'),
        findsOneWidget,
      );
      expect(find.text("Legs and glutes, today's plan"), findsOneWidget);
      expect(find.text('Upper body, like last Thursday'), findsOneWidget);
      expect(find.text('A class or a walk'), findsOneWidget);
      expect(find.text('Counts by time alone'), findsOneWidget);
      for (final chip in ['20 min', '30 min', '45 min', '1 hour']) {
        expect(find.text(chip), findsOneWidget, reason: chip);
      }
      expect(find.text('Save'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Today is still visible underneath — it is a sheet, not a page',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(_host(_view()));
        await tester.pumpAndSettle();

        expect(find.text('Tuesday'), findsOneWidget);
        expect(find.text("Today's workout"), findsOneWidget);
        expect(find.text('Breakfast'), findsOneWidget);
      },
    );
  });

  group('RULE 9 — undo, never confirmation', () {
    testWidgets('saving asks nothing and offers undo', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Save').first);
      await _settleSnackBar(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Undo'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('the undo offer names what the button named', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Save').first);
      await _settleSnackBar(tester);

      // She should never have to wonder what she just agreed to.
      expect(find.text("Legs and glutes, today's plan"), findsWidgets);

      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('left alone, the session is credited to the week', (
      tester,
    ) async {
      _phone(tester);
      final repo = InMemoryTodayRepository(
        day: InMemoryTodayRepository.defaultDay(date: _tuesday),
      );
      await tester.pumpWidget(_host(_view(repository: repo)));
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Save').first);
      await tester.pump(const Duration(seconds: 6));

      expect(repo.day.state, DayState.recalled);
      expect(
        repo.day.week.sessionsLogged,
        2,
        reason: 'optimistic week credit, deduplicated by session id',
      );
    });

    testWidgets('undo inside the window means the write never happens', (
      tester,
    ) async {
      _phone(tester);
      final repo = InMemoryTodayRepository(
        day: InMemoryTodayRepository.defaultDay(date: _tuesday),
      );
      await tester.pumpWidget(_host(_view(repository: repo)));
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Save').first);
      await _settleSnackBar(tester);
      await tester.tap(find.text('Undo'));
      await tester.pump(const Duration(seconds: 6));

      expect(repo.day.week.sessionsLogged, 1);
      expect(repo.day.state, isNot(DayState.recalled));
    });

    testWidgets('a class or a walk counts by time alone, in one tap', (
      tester,
    ) async {
      _phone(tester);
      final repo = InMemoryTodayRepository(
        day: InMemoryTodayRepository.defaultDay(date: _tuesday),
      );
      await tester.pumpWidget(_host(_view(repository: repo)));
      await tester.pumpAndSettle();

      await _tap(tester, find.text('30 min'));
      await _settleSnackBar(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Undo'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      expect(repo.day.week.sessionsLogged, 2);
    });
  });

  testWidgets('every string comes from the dictionary, in Arabic too', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(_viewWithNoHistory(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('عملتي إيه؟'), findsOneWidget);
    expect(find.text('الرجلين والأرداف، خطة النهارده'), findsOneWidget);
    // `_viewWithNoHistory`, so the only strings on the screen are the screen's
    // own. The last-other row's title comes from its caller now, and a caller
    // passing an English one would be measuring the fixture rather than the
    // dictionary.
    expect(find.text('احفظي'), findsOneWidget);
    expect(find.text('What did you do?'), findsNothing);
    expect(find.text('Save'), findsNothing);
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
