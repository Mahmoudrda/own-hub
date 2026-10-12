// T01 — Today.
//
// The product's hottest screen and the one the "everything is one tap" goal is
// measured on. The assertions worth having are the ones that catch silent
// failures: a log that asks permission, a progress indicator that counts days
// instead of weeks, and text that vanishes or overflows in Arabic.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/app_week_segments.dart';

// 15 September 2026 is a Tuesday, which is the day the prototype draws.
final DateTime _tuesday = DateTime(2026, 9, 15, 9, 41);

/// A phone, not the 800×600 default.
///
/// This matters for more than realism: at the default surface the layout is
/// wider than any device this ships on, so a row that overflows on a real phone
/// would pass. The large-text assertions below are only worth having at a real
/// width.
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

/// Every route out is stubbed, so a stray tap can never reach the real router
/// and no test depends on another screen existing.
TodayView _today({
  TodayRepository? repository,
  DateTime? now,
  int? level,
  String? sessionTitle,
}) {
  return TodayView(
    // The prototype's day, asked for by name. `InMemoryTodayRepository()` now
    // starts on day one, which is what a fresh install must get; these cases
    // are about a day part way through, so they state the day they mean.
    repository:
        repository ??
        InMemoryTodayRepository(
          day: InMemoryTodayRepository.defaultDay(date: _tuesday),
        ),
    now: now ?? _tuesday,
    level: level,
    sessionTitle: sessionTitle,
    onStartSession: () {},
    onRecall: () {},
    onOpenMeal: () {},
    onOpenPlate: () {},
    onOpenWeek: () {},
    onOpenCycle: () {},
    onAsk: () {},
    onNotifications: () {},
    onSelectTab: (_) {},
  );
}

/// Taps the walk's "Count it" and lets the undo offer finish animating in.
/// Until it has, the snackbar sits behind an IgnorePointer and a tap aimed at
/// Undo falls through to whatever is underneath.
Future<void> _countWalk(WidgetTester tester) async {
  await tester.tap(find.text('Count it'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

void main() {
  group('everything she might log today is already on the screen', () {
    testWidgets('the day, the walk, the session, the meal and the week', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_today()));
      await tester.pumpAndSettle();

      expect(find.text('Tuesday'), findsOneWidget);
      // No level was supplied, so no pill is drawn. See the two tests below.
      expect(find.text('Level 7 · Regular'), findsNothing);
      expect(find.text('Walk this morning · 32 min'), findsOneWidget);
      expect(find.text('Count it'), findsOneWidget);
      // The cover names the thing, not a programme. It was the fixed
      // `l10n.legsAndGlutes`, so Home told every woman the name of a programme
      // she had never chosen — and Train, one tap away, called the same
      // programme "Postpartum rebuild".
      expect(find.text("Today's workout"), findsOneWidget);
      expect(find.text('Legs and glutes'), findsNothing);
      expect(find.text('Week 3 of 8'), findsOneWidget);
      expect(find.text("Start, everything's ready"), findsOneWidget);
      expect(find.text('I already did it'), findsOneWidget);
      // The meal is headed by the hour it happened, not by a fixed
      // "Breakfast, your usual" that stayed on the card over a koshari bowl
      // logged at one in the afternoon. This one really is breakfast: 08:40.
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Breakfast, your usual'), findsNothing);
      expect(find.text('Ful and baladi'), findsOneWidget);
      expect(find.text('This week, 1 of 3'), findsOneWidget);
    });

    testWidgets('the cover names her plan when there is one', (tester) async {
      // And proves the line above is a fallback rather than a second constant:
      // a title supplied by her plan is what the cover sets.
      _phone(tester);
      await tester.pumpWidget(
        _host(_today(sessionTitle: 'Floor legs, no jumping')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Floor legs, no jumping'), findsOneWidget);
      expect(find.text("Today's workout"), findsNothing);
    });

    testWidgets('the meal heading follows the meal, not the mockup', (
      tester,
    ) async {
      // Found by driving the real app: log a koshari bowl at lunch and Home
      // still read "Breakfast, your usual" with the koshari underneath it. The
      // heading was a constant while everything under it was data.
      _phone(tester);
      final lunch = DateTime(2026, 9, 15, 13, 10);
      await tester.pumpWidget(
        _host(
          _today(
            now: lunch,
            repository: InMemoryTodayRepository(
              day: InMemoryTodayRepository.defaultDay(date: _tuesday).copyWith(
                mealLoggedAt: lunch,
                plates: const [
                  PlateSuggestion(foodId: 'koshari_bowl', kcal: 540),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Koshari bowl'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Breakfast'), findsNothing);
      expect(find.text('Breakfast, your usual'), findsNothing);
    });

    // "and says so" used to mean "Dinner, your usual". It does not any more.
    //
    // "Your usual" is a claim about a habit, and this fixture is a woman with
    // no plates at all: nothing she has ever eaten is on the card. The hour is
    // still guessed and still named, because that part was always right; what
    // had to earn itself is the word "usual". `MealCard` says it only when it
    // has a plate of hers to name.
    testWidgets('with nothing logged it guesses the hour, and says so', (
      tester,
    ) async {
      _phone(tester);
      final evening = DateTime(2026, 9, 15, 19, 30);
      await tester.pumpWidget(
        _host(
          _today(
            now: evening,
            repository: InMemoryTodayRepository(
              // Past day one, but nothing eaten yet today.
              day: TodayDay(
                date: _tuesday,
                state: DayState.nothingDone,
                arc: const FirstWeekArc(hasAnyLog: true),
                week: const WeekProgress(sessionsLogged: 0, sessionsTarget: 3),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('Dinner, your usual'), findsNothing);
      expect(find.text('Breakfast, your usual'), findsNothing);
    });

    testWidgets('the week line counts HER target, not the prototype 3', (
      tester,
    ) async {
      // The defect: this line was two finished sentences — "This week, 0 of 3"
      // and "This week, 1 of 3" — chosen by `sessionsLogged == 0`. So it never
      // counted past one, and a woman whose goal is four sessions read "0 of 3"
      // while the ring immediately below drew four segments from the same
      // object.
      //
      // The assertion above cannot catch it: the default fixture is 1 of 3, so
      // the parameterised output is byte-identical to the old constant and
      // passes either way. Only a different target tells a computation from a
      // constant — the same reason the R07 button needed a 20 kg move.
      await tester.pumpWidget(
        _host(
          _today(
            repository: InMemoryTodayRepository(
              day: InMemoryTodayRepository.defaultDay(date: _tuesday).copyWith(
                week: const WeekProgress(sessionsLogged: 2, sessionsTarget: 4),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This week, 2 of 4'), findsOneWidget);
      expect(find.text('This week, 1 of 3'), findsNothing);
      expect(find.text('This week, 0 of 3'), findsNothing);
      // And the line beside it counts down from the same two numbers. It was
      // the fixed "Two more and the week counts." — said beside "0 of 3" on a
      // fresh install, and said again to a woman who had finished her week.
      expect(find.text('2 more and the week counts.'), findsOneWidget);
      expect(find.text('Two more and the week counts.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a week she has finished says so, rather than asking for two '
        'more', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _today(
            repository: InMemoryTodayRepository(
              day: InMemoryTodayRepository.defaultDay(date: _tuesday).copyWith(
                week: const WeekProgress(sessionsLogged: 3, sessionsTarget: 3),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This week counts.'), findsOneWidget);
      expect(find.textContaining('more and the week counts'), findsNothing);
    });

    testWidgets('the level pill is HER level, and names no tier', (
      tester,
    ) async {
      // Home's pill read the fixed "Level 7 · Regular", so it announced level 7
      // to a woman on level 1 — on the first screen she sees — and named a tier
      // while P01, reading the same data, correctly showed none.
      //
      // Level 3 rather than 7: a fixture equal to the mockup's number passes
      // whether the value is computed or frozen, which is the whole reason the
      // old assertion could not catch this.
      _phone(tester);
      await tester.pumpWidget(_host(_today(level: 3)));
      await tester.pumpAndSettle();

      expect(find.text('Level 3'), findsOneWidget);
      expect(find.text('Level 7 · Regular'), findsNothing);
      expect(find.text('Level 7'), findsNothing);
      expect(
        find.textContaining('Regular'),
        findsNothing,
        reason:
            'D6: no tier ladder is authoritative, so no tier name may be shown '
            'anywhere — P01 shows none and Home must agree',
      );
    });

    testWidgets('an unknown level draws no pill rather than a default', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_today()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Level'), findsNothing);
    });

    testWidgets('a woman who never set up My cycle sees no cycle row', (
      tester,
    ) async {
      // P0-CYC-03: skipping costs nothing.
      //
      // This row rendered unconditionally, and this test asserted it did —
      // pinning the defect in place. Home showed a cycle card to a woman who
      // skipped cycle setup, or who never reached it at all, which is a cost.
      // Found by the Cycle agent, in a folder it was not allowed to edit.
      //
      // The old assertion was also for `My cycle · period day 2`, a string with
      // the mockup's sample baked in: it told every woman she was on day two.
      _phone(tester);
      await tester.pumpWidget(_host(_today()));
      await tester.pumpAndSettle();

      expect(find.text('My cycle'), findsNothing);
      expect(find.text('My cycle · period day 2'), findsNothing);
    });

    testWidgets('a woman who uses My cycle does see it', (tester) async {
      // The other half, so the gate cannot be satisfied by deleting the row.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _today(
            repository: InMemoryTodayRepository(
              day: InMemoryTodayRepository.defaultDay(date: _tuesday)
                  .copyWith(showCycleCard: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My cycle'), findsOneWidget);
      // Still never the baked-in sample, even when the row is shown.
      expect(find.text('My cycle · period day 2'), findsNothing);
    });

    testWidgets('the day name comes from the date, not from a fixed Tuesday', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _today(
            repository: InMemoryTodayRepository(
              day: InMemoryTodayRepository.defaultDay(
                date: DateTime(2026, 9, 14, 9, 41),
              ),
            ),
            now: DateTime(2026, 9, 14, 9, 41),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('Tuesday'), findsNothing);
    });
  });

  group('RULE 3 — weeks, not days', () {
    testWidgets('the only progress indicator on the screen is the week', (
      tester,
    ) async {
      // A daily counter is the thing this product must never grow. The week
      // segments are a session target, not seven days.
      _phone(tester);
      await tester.pumpWidget(_host(_today()));
      await tester.pumpAndSettle();

      final segments = find.byType(AppWeekSegments);
      expect(segments, findsOneWidget);
      expect(
        tester.widget<AppWeekSegments>(segments).total,
        3,
        reason: 'sessions the week asks for — never a number of days',
      );
      expect(tester.widget<AppWeekSegments>(segments).filled, 1);
    });
  });

  group('RULE 9 — undo, never confirmation', () {
    testWidgets('counting the walk saves at once and offers undo', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_today()));
      await tester.pumpAndSettle();

      await _countWalk(tester);

      // Nothing asked her anything.
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);

      // The row updated immediately — the log is hers before it is committed.
      expect(find.text('Count it'), findsNothing);

      // And the offer to take it back names what she logged.
      expect(find.text('Undo'), findsOneWidget);
      expect(find.text('Walk this morning · 32 min'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('undo inside the window puts the walk back', (tester) async {
      _phone(tester);
      final repo = InMemoryTodayRepository(
        day: InMemoryTodayRepository.defaultDay(date: _tuesday),
      );
      await tester.pumpWidget(_host(_today(repository: repo)));
      await tester.pumpAndSettle();

      await _countWalk(tester);
      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));

      expect(find.text('Count it'), findsOneWidget);
      expect(
        repo.day.walkToCount,
        isTrue,
        reason:
            'the write never reached the repository, so there is '
            'nothing queued to resurface when she reconnects',
      );
    });

    testWidgets('left alone, the walk is committed when the window closes', (
      tester,
    ) async {
      _phone(tester);
      final repo = InMemoryTodayRepository(
        day: InMemoryTodayRepository.defaultDay(date: _tuesday),
      );
      await tester.pumpWidget(_host(_today(repository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Count it'));
      await tester.pump(const Duration(seconds: 6));

      expect(repo.day.walkToCount, isFalse);
    });
  });

  group('after eight in the evening', () {
    testWidgets('the likelier answer takes the weight', (tester) async {
      // Not a sixth day state — the same state, rendered for the hour. An
      // unlogged session at 20:30 has almost certainly already happened.
      _phone(tester);
      await tester.pumpWidget(
        _host(_today(now: DateTime(2026, 9, 15, 20, 30))),
      );
      await tester.pumpAndSettle();

      AppButton buttonFor(String label) => tester.widget<AppButton>(
        find
            .ancestor(of: find.text(label), matching: find.byType(AppButton))
            .first,
      );

      expect(
        buttonFor('I already did it').variant,
        AppButtonVariant.filled,
        reason: 'the evening answer is the primary one',
      );
      expect(
        buttonFor("Start, everything's ready").variant,
        AppButtonVariant.outlined,
      );
    });

    testWidgets('before eight, starting is still the primary action', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_today(now: DateTime(2026, 9, 15, 9, 41))));
      await tester.pumpAndSettle();

      final start = tester.widget<AppButton>(
        find
            .ancestor(
              of: find.text("Start, everything's ready"),
              matching: find.byType(AppButton),
            )
            .first,
      );
      expect(start.variant, AppButtonVariant.filled);
    });
  });

  testWidgets('every string comes from the dictionary, in Arabic too', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(_today(), locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('الثلاثاء'), findsOneWidget);
    expect(find.text('تمرين النهارده'), findsOneWidget);
    expect(find.text('احسبيها'), findsOneWidget);
    expect(find.text('الأسبوع ده، 1 من 3'), findsOneWidget);
    // English surviving here is exactly what a hardcoded string looks like.
    expect(find.text("Today's workout"), findsNothing);
    expect(find.text('Count it'), findsNothing);
  });

  testWidgets('lays out right to left in Arabic', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(_today(), locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.text('الثلاثاء'))),
      TextDirection.rtl,
    );
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(_today(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'an overflow here hides the thing she came to tap',
    );
  });
}
