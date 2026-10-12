// T05 — When a tier slips.
//
// Nothing earned is taken away, and the slip is shown once. Both halves are
// testable, and both are the kind of thing that breaks quietly: a second
// showing is just a missing write, and "everything kept" becomes a lie the
// moment someone adds a line about what she lost.
//
// Rewritten for Phase 2 Flow 2. This sheet used to state three numbers it could
// not know — "Your 14 counted weeks", "Level 7 and every point", "Everything
// Regular opened" — to every woman. DECISIONS.md records that it "contradicts D6
// directly. It currently ships three."
//
// Two things changed. Her counted weeks and her level now come from real
// documents, so they are checked against her before they are shown. And the
// SHEET ITSELF is gated on there being a tier at all: every sentence in it names
// a tier or a threshold, and D6 has authored none, so with the shipped
// (unauthored) ladder the notice does not open. A tier-slip sheet with no tier
// is not a notice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/rewards.dart';
import 'package:own_hub/domain/rewards/tier_policy.dart';
import 'package:own_hub/domain/rewards/weekly_goal.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/tier_slip_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_card.dart';

final DateTime _monday = DateTime(2026, 9, 14);

/// She earned Regular; her label has slipped one step to Showing up.
const TierStanding _slipped = TierStanding(
  earned: Tier.regular,
  display: Tier.showingUp,
  slipped: true,
);

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

TierSlipView _view({
  TodayRepository? repository,
  Key? key,
  TierStanding? standing = _slipped,
  int countedWeeks = 14,
  int points = 490, // level 7
}) => TierSlipView(
  key: key,
  repository: repository ?? InMemoryTodayRepository(),
  date: _monday,
  standing: standing,
  goal: WeeklyGoal(countedWeeks: countedWeeks),
  rewards: Rewards(points: points),
  onStartShortSession: () {},
  onShrinkGoal: () {},
  onStartSession: () {},
  onRecall: () {},
  onSelectTab: (_) {},
);

void main() {
  group('the way back, not the fall', () {
    testWidgets('it names how close one counted week is', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(find.text('You are Showing up for now'), findsOneWidget);
      expect(
        find.textContaining('One more counted week brings it back.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('everything earned is listed as kept', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(find.text('Kept, all of it'), findsOneWidget);
      expect(find.text('Your 14 counted weeks'), findsOneWidget);
      expect(find.text('Level 7 and every point'), findsOneWidget);
      expect(find.text('Everything Regular opened'), findsOneWidget);
    });

    testWidgets('a different woman is told her own figures, not these', (
      tester,
    ) async {
      // The anti-constant control. Nine counted weeks and 235 points is level 3.
      _phone(tester);
      await tester.pumpWidget(_host(_view(countedWeeks: 9, points: 235)));
      await tester.pumpAndSettle();

      expect(find.text('Kept, all of it'), findsOneWidget);
      expect(
        find.text('Your 14 counted weeks'),
        findsNothing,
        reason: 'she has nine',
      );
      expect(
        find.text('Level 7 and every point'),
        findsNothing,
        reason: 'she is level 3',
      );
      // The tier line is still hers, because she really did earn Regular.
      expect(find.text('Everything Regular opened'), findsOneWidget);
    });

    testWidgets('a goal she can meet beats a goal she abandons', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(find.text('Start 10 minutes'), findsOneWidget);
      expect(find.text('Make this week 2 sessions'), findsOneWidget);
    });

    testWidgets('nothing here is a failure state', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      final cards = tester.widgetList<AppCard>(find.byType(AppCard));
      expect(cards, isNotEmpty);
      for (final card in cards) {
        expect(
          card.variant,
          isNot(AppCardVariant.error),
          reason: 'a slipped tier is not an error',
        );
      }
      expect(find.textContaining('lost'), findsNothing);
      expect(find.textContaining('missed'), findsNothing);
    });
  });

  group('D6 — no tier, no notice', () {
    testWidgets('with no tier authored the sheet does not open', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(standing: null)));
      await tester.pumpAndSettle();

      expect(
        find.text('You are Showing up for now'),
        findsNothing,
        reason:
            'every sentence in this sheet names a tier, and DECISIONS.md D6 '
            'says no tier number is authoritative until it is written down',
      );
      expect(find.text('Kept, all of it'), findsNothing);
      expect(find.text('Your 14 counted weeks'), findsNothing);
      expect(find.text('Everything Regular opened'), findsNothing);

      // Today is still underneath, and still hers to use.
      expect(find.text("Today's workout"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unknown standing is the same as none', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(standing: TierStanding.unknown)));
      await tester.pumpAndSettle();

      expect(find.text('Kept, all of it'), findsNothing);
      expect(find.text("Today's workout"), findsOneWidget);
    });

    testWidgets('an unopened notice is not marked as seen', (tester) async {
      // Otherwise the day the ladder IS authored, she silently never sees the
      // notice for whichever week the unwired build happened to run in.
      _phone(tester);
      final repo = InMemoryTodayRepository();

      await tester.pumpWidget(_host(_view(repository: repo, standing: null)));
      await tester.pumpAndSettle();

      expect(
        repo.noticeSeen(NoticeKind.tierSlip, WeekKey.of(_monday)),
        isFalse,
      );
    });
  });

  group('shown once, then silent', () {
    testWidgets('re-opening in the same ISO week says nothing', (tester) async {
      _phone(tester);
      final repo = InMemoryTodayRepository();

      await tester.pumpWidget(
        _host(_view(repository: repo, key: const ValueKey('first'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('You are Showing up for now'), findsOneWidget);
      expect(repo.noticeSeen(NoticeKind.tierSlip, WeekKey.of(_monday)), isTrue);

      // Same week, same woman, a second open.
      await tester.pumpWidget(
        _host(_view(repository: repo, key: const ValueKey('second'))),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('You are Showing up for now'),
        findsNothing,
        reason: 'the notice key contains the week, so it cannot repeat',
      );
      // Today is still underneath, and still hers to use.
      expect(find.text("Today's workout"), findsOneWidget);
    });
  });

  testWidgets('every string comes from the dictionary, in Arabic too', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(_view(), locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('إنتِ «مواظِبة» دلوقتي'), findsOneWidget);
    expect(find.text('محفوظ، كله'), findsOneWidget);
    expect(find.text('خلّي الأسبوع ده تمرينين'), findsOneWidget);
    expect(find.text('Kept, all of it'), findsNothing);

    // P0-A11Y-01: Western numerals, in Arabic too.
    final eastern = RegExp('[٠-٩]');
    for (final text
        in tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')) {
      expect(eastern.hasMatch(text), isFalse, reason: text);
    }
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

  testWidgets('a finger on a tab still works while the notice is raised', (
    tester,
  ) async {
    // The scrim used to be drawn over the bottom bar, so all three tabs were
    // painted at the foot of a notice she did not ask for and none of them
    // could be touched: the coloured box took every pointer, and it carried no
    // gesture of its own. That left exactly two ways off this screen, both of
    // them buttons inside the notice.
    //
    // Tapped with a FINGER rather than through the semantics action, because
    // `tester.semantics.tap` dispatches straight to the node and never
    // hit-tests — it passed throughout the defect. `tester.tap` at the painted
    // pixel is the only instrument that can see a scrim.
    _phone(tester);
    final tapped = <String>[];
    await tester.pumpWidget(
      _host(
        TierSlipView(
          repository: InMemoryTodayRepository(),
          date: _monday,
          standing: _slipped,
          goal: const WeeklyGoal(countedWeeks: 14),
          rewards: const Rewards(points: 490),
          onStartShortSession: () {},
          onShrinkGoal: () {},
          onStartSession: () {},
          onRecall: () {},
          onSelectTab: tapped.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('You are Showing up for now'),
      findsOneWidget,
      reason: 'the notice must be raised, or this proves nothing',
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(tapped, ['T01']);
  });

  testWidgets('and the scrim closes the notice rather than only blocking it', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(_view()));
    await tester.pumpAndSettle();
    expect(find.text('You are Showing up for now'), findsOneWidget);

    // Well above the sheet, which is bottom-aligned: this pixel is scrim.
    await tester.tapAt(const Offset(195, 120));
    await tester.pumpAndSettle();

    expect(find.text('You are Showing up for now'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
