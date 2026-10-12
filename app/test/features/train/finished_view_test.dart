// R10 — Finished.
//
// The one celebration. What it must get right is the order of what she earned,
// and that the trophy appears only for a session that was actually measured.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/finished_view.dart';
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

const _live = TrainSession(
  id: 'live-1',
  source: SessionSource.live,
  dateKey: '2026-09-15',
  sets: [],
  completed: true,
);

const _recalled = TrainSession(
  id: 'recalled-2026-09-15-day-2',
  source: SessionSource.recalled,
  dateKey: '2026-09-15',
  sets: [],
  completed: true,
);

void main() {
  // The share link posts to a group, so R10 is tested with Community on.
  final savedFlags = AppRouter.featureFlags;
  setUp(
    () => AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.community: true,
    }),
  );
  tearDown(() => AppRouter.featureFlags = savedFlags);

  testWidgets('names what she earned, in the order she cares about', (
    tester,
  ) async {
    // A Tuesday, so the heading is checkable. It used to say Tuesday to
    // everyone on every day, which is what this now guards against.
    await tester.pumpWidget(
      _host(FinishedView(finishedOn: DateTime(2026, 9, 15))),
    );
    await tester.pumpAndSettle();

    expect(find.text("That's Tuesday done"), findsOneWidget);
    // 30 is the product's own number for a live session —
    // `SessionCredit.livePoints` — so it is true of every woman and stays.
    expect(find.text('+30 points'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('One more session and this week counts.'), findsOneWidget);

    // What this test used to assert, and should not have.
    //
    // R10 is handed a session, a week and a level percentage — and no lifetime
    // balance, no session number and no points-to-next-level. It stated all
    // three anyway, from fixed strings, so the assertions below pinned the
    // prototype's history as every woman's. They are gone rather than
    // corrected: none has a parameterised form to correct them into.
    expect(
      find.text('15 minutes, 5 moves, 14 sets. You typed nothing.'),
      findsNothing,
    );
    expect(find.text('490 total'), findsNothing);
    expect(find.text('Session 20 · personal best 10'), findsNothing);
    expect(find.text('70 points to level 8.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a measured session may show a personal best', (tester) async {
    await tester.pumpWidget(_host(const FinishedView(session: _live)));
    await tester.pumpAndSettle();

    expect(find.text('A personal best'), findsOneWidget);
    // The trophy card named the prototype's lift — "Goblet squat, 12 kg × 10 —
    // two kilos more than your best." — to whoever finished a measured
    // session. The card still appears, and still only for a session eligible
    // to set one; what it was is not claimed.
    expect(find.textContaining('two kilos more than your best'), findsNothing);
  });

  testWidgets('a recalled session never shows one, even on this screen', (
    tester,
  ) async {
    // The rule travels with the session, not with the screen it lands on.
    await tester.pumpWidget(_host(const FinishedView(session: _recalled)));
    await tester.pumpAndSettle();

    expect(find.text('A personal best'), findsNothing);
  });

  testWidgets('sharing is a quiet link, and hands over an intent only', (
    tester,
  ) async {
    var shared = 0;
    var back = 0;
    await tester.pumpWidget(
      _host(FinishedView(onShare: () => shared++, onBackToToday: () => back++)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share the squat with your group'));
    await tester.tap(find.text('Back to today'));
    await tester.pumpAndSettle();

    expect(shared, 1);
    expect(back, 1);
  });

  testWidgets('the week is drawn as a count of sessions, never as days', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const FinishedView(sessionsThisWeek: 2, sessionsPrescribed: 3)),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 of 3'), findsOneWidget);
    // Rule 3: nothing on this screen counts consecutive days.
    expect(find.textContaining('day streak'), findsNothing);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(
        FinishedView(session: _live, finishedOn: DateTime(2026, 9, 15)),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('كده الثلاثاء خلص'), findsOneWidget);
    expect(find.text('رقم شخصي جديد'), findsOneWidget);
    expect(find.text('ارجعي لصفحة اليوم'), findsOneWidget);
    expect(find.text('Back to today'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const FinishedView(session: _live),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
