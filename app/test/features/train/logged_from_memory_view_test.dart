// R12 — Logged from memory.
//
// Implements the G4 half of P0-LOG-04: it counts, it awards fewer points, and it
// never sets a personal best.
//
// The `unplanned` case is tested deliberately. The plan flags it as the newest
// thing in the schema and the least covered thing in the suite: a walk or a
// studio class must be treated exactly like a recalled session, because the rule
// is "only a measured live session", not "not recalled".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/logged_from_memory_view.dart';
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

const _recalled = TrainSession(
  id: 'recalled-2026-09-15-day-2',
  source: SessionSource.recalled,
  dateKey: '2026-09-15',
  recallMethod: RecallMethod.plan,
  sets: [],
  completed: true,
);

const _walk = TrainSession(
  id: 'recalled-2026-09-15-walk',
  source: SessionSource.unplanned,
  dateKey: '2026-09-15',
  activity: 'walk',
  sets: [],
  durationSec: 1920,
  completed: true,
);

const _live = TrainSession(
  id: 'live-1',
  source: SessionSource.live,
  dateKey: '2026-09-15',
  sets: [],
  completed: true,
);

void main() {
  testWidgets('the week still counts it, and says so', (tester) async {
    await tester.pumpWidget(_host(const LoggedFromMemoryView()));
    await tester.pumpAndSettle();

    expect(find.text("That's Tuesday done"), findsOneWidget);
    expect(
      find.text(
        'Logged from memory. Your week counts it like any other session.',
      ),
      findsOneWidget,
    );
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('One more session and this week counts.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('it awards fewer points than a live session', (tester) async {
    await tester.pumpWidget(_host(const LoggedFromMemoryView()));
    await tester.pumpAndSettle();

    expect(find.text('+15 points'), findsOneWidget);
    expect(find.text('+30 points'), findsNothing);
  });

  testWidgets('the reason sits where the trophy would have been', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const LoggedFromMemoryView(session: _recalled)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No personal best from this one. The numbers were copied, not measured.',
      ),
      findsOneWidget,
    );
    // The absence has to read as a rule, not as something that failed to load.
    expect(find.text('A personal best'), findsNothing);
  });

  testWidgets('a logged walk is treated exactly the same way', (tester) async {
    // The rule is `source == live`, so `unplanned` is suppressed by
    // construction rather than by a clause someone has to remember to add.
    await tester.pumpWidget(_host(const LoggedFromMemoryView(session: _walk)));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No personal best from this one'),
      findsOneWidget,
    );
    expect(find.text('A personal best'), findsNothing);
  });

  testWidgets('the suppression follows the session, not the screen', (
    tester,
  ) async {
    // Handed a measured live session, the "no personal best" note is not shown —
    // which proves the note is driven by the rule rather than hard-coded here.
    await tester.pumpWidget(_host(const LoggedFromMemoryView(session: _live)));
    await tester.pumpAndSettle();

    expect(find.textContaining('No personal best from this one'), findsNothing);
  });

  test('the rule itself lives in the domain layer', () {
    const eligibility = PersonalBestEligibility();
    expect(eligibility.isEligible(_live), isTrue);
    expect(eligibility.isEligible(_recalled), isFalse);
    expect(
      eligibility.isEligible(_walk),
      isFalse,
      reason: 'a walk is not a measured session either',
    );
  });

  testWidgets('back to today is the only way on', (tester) async {
    var back = 0;
    await tester.pumpWidget(
      _host(LoggedFromMemoryView(onBackToToday: () => back++)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back to today'));
    await tester.pumpAndSettle();
    expect(back, 1);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const LoggedFromMemoryView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('مسجَّل من الذاكرة. ويحتسبه أسبوعك كأي تمرين آخر.'),
      findsOneWidget,
    );
    expect(find.text('+15 نقطة'), findsOneWidget);
    expect(find.text('+15 points'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const LoggedFromMemoryView(),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
