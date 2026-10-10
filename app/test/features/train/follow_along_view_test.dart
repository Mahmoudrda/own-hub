// R06 — Follow-along move.
//
// Zero taps to log. The assertion that carries the screen is the absence of a
// log control: the timer is the log, and the chip has to say so, because silence
// after a set is otherwise indistinguishable from a missed one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/train/presentation/follow_along_view.dart';
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

void main() {
  testWidgets('names the move, the position and the time left', (tester) async {
    await tester.pumpWidget(
      _host(const FollowAlongView(positionLabel: 'Move 3 of 5')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Move 3 of 5'), findsOneWidget);
    expect(find.text('Glute bridge'), findsOneWidget);
    expect(find.text('0:24'), findsOneWidget);
    expect(find.text('left'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no position given, it states none', (tester) async {
    // This test used to construct `FollowAlongView()` with no position at all
    // and assert "Move 3 of 5" — the fallback `positionLabel ?? move3Of5`, so
    // it pinned the prototype's position as the answer for a screen that had
    // not been told one. R06 says where she is, or says nothing.
    await tester.pumpWidget(_host(const FollowAlongView()));
    await tester.pumpAndSettle();

    expect(find.text('Move 3 of 5'), findsNothing);
    expect(find.text('Glute bridge'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('says out loud that it logs itself', (tester) async {
    await tester.pumpWidget(_host(const FollowAlongView()));
    await tester.pumpAndSettle();

    expect(find.text('counts itself'), findsOneWidget);
  });

  testWidgets('offers nothing to tap in order to log', (tester) async {
    // If a "Done" ever appears here, the screen has stopped being zero-tap and
    // the chip above is now a lie.
    await tester.pumpWidget(_host(const FollowAlongView()));
    await tester.pumpAndSettle();

    expect(find.text('Done · 12 kg × 10'), findsNothing);
    expect(find.textContaining('Done'), findsNothing);
    // Only the two controls the design has.
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Skip this move'), findsOneWidget);
  });

  testWidgets('pause and skip fire', (tester) async {
    var paused = 0;
    var skipped = 0;
    await tester.pumpWidget(
      _host(FollowAlongView(onPause: () => paused++, onSkip: () => skipped++)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pause'));
    await tester.tap(find.text('Skip this move'));
    await tester.pumpAndSettle();

    expect(paused, 1);
    expect(skipped, 1);
  });

  testWidgets('the countdown is a value, in Western digits in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const FollowAlongView(remaining: Duration(seconds: 65)),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1:05'), findsOneWidget);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const FollowAlongView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('يُحتسب تلقائيًا'), findsOneWidget);
    expect(find.text('إيقاف مؤقت'), findsOneWidget);
    expect(find.text('تخطّي هذا التمرين'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const FollowAlongView(),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
