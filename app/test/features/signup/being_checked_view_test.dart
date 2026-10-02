// C14 — Being checked.
//
// "Never a dead end" is this screen's stated metric, so that is what the tests
// assert, and two owner decisions changed what "not a dead end" means here.
//
// It used to assert that workouts, recipes and coach profiles were reachable
// from this screen, because the only thing a pending check closed was the
// community. The gate is the whole app now, so those rows are gone and the
// assertion went with them.
//
// It also used to assert the headline "A woman reviewer is looking". Nothing of
// hers is stored any more, for any outcome, so there is nothing for a reviewer
// to look at: review is a short video call. A screen that says otherwise is
// lying to her at the moment she is most dependent on it, which is why the copy
// assertions below are the substance of this file rather than decoration.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:async';

import 'package:own_hub/features/signup/domain/server_verification.dart';
import 'package:own_hub/features/signup/presentation/being_checked_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_card.dart';

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
  testWidgets('says a call is coming, not that someone is reading her file', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const BeingCheckedView()));
    await tester.pumpAndSettle();

    expect(find.text('Being checked'), findsOneWidget);
    expect(find.text('A short video call with a woman'), findsOneWidget);
    // Who calls, and how. No text message is promised, because nothing
    // exists that could send one (S3).
    expect(
      find.textContaining('A woman reviewer from Own Hub will phone you'),
      findsOneWidget,
    );
    expect(find.textContaining('We will text you'), findsNothing);
    // The model that no longer exists must not survive in the copy.
    expect(find.text('A woman reviewer is looking'), findsNothing);
  });

  testWidgets('tells her nothing she photographed was kept', (tester) async {
    // Rule 7 at the moment she is most likely to wonder. Nothing was filed,
    // nothing is queued, nobody is looking at a picture of her.
    await tester.pumpWidget(_host(const BeingCheckedView()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Nothing you photographed is stored'),
      findsOneWidget,
    );
  });

  testWidgets('it is a caution, not a failure', (tester) async {
    // Amber is "not finished"; error is "something is wrong". One word of code
    // is the difference between waiting and being accused.
    await tester.pumpWidget(_host(const BeingCheckedView()));
    await tester.pumpAndSettle();

    final card = tester.widget<AppCard>(
      find
          .ancestor(
            of: find.text('A short video call with a woman'),
            matching: find.byType(AppCard),
          )
          .first,
    );
    expect(card.variant, AppCardVariant.amber);
    expect(card.variant, isNot(AppCardVariant.error));
  });

  testWidgets('the gate is the whole app, so nothing is offered to browse', (
    tester,
  ) async {
    // The three rows promised workouts, recipes and coach profiles while she
    // waited. The owner closed the whole app until the check completes, so a
    // row offering any of them would be a door that does not open.
    await tester.pumpWidget(_host(const BeingCheckedView()));
    await tester.pumpAndSettle();

    expect(find.text('While you wait, everything here is open'), findsNothing);
    expect(find.text('Workouts and videos'), findsNothing);
    expect(find.text('Coach profiles'), findsNothing);
    expect(find.textContaining('The community stays closed'), findsNothing);
    expect(
      find.textContaining('The app opens as soon as your check is done'),
      findsOneWidget,
    );
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const BeingCheckedView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('قيد المراجعة'), findsOneWidget);
    expect(find.text('مكالمة فيديو قصيرة مع إحدى النساء'), findsOneWidget);
    expect(find.text('Being checked'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const BeingCheckedView(),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('S8: it shows what the server says', () {
    testWidgets('a booked call shows its time', (tester) async {
      await tester.pumpWidget(
        _host(
          BeingCheckedView(
            status: ServerVerification(
              ServerVerificationState.pending,
              reviewRoute: 'video',
              reviewScheduledFor: DateTime(2026, 10, 5, 10),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Your video call is booked for'),
        findsOneWidget,
      );
      expect(find.textContaining('10:00'), findsOneWidget);
    });

    testWidgets('a rejection is told plainly, with where to delete', (
      tester,
    ) async {
      var deletes = 0;
      await tester.pumpWidget(
        _host(
          BeingCheckedView(
            status: const ServerVerification(ServerVerificationState.rejected),
            onDeleteMyData: () => deletes++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('We could not verify your account'), findsOneWidget);
      expect(
        find.textContaining('You can delete your account and everything'),
        findsOneWidget,
      );
      // Not "the app opens soon": it will not.
      expect(
        find.textContaining('The app opens as soon as your check is done'),
        findsNothing,
      );
      await tester.tap(find.text('Open Profile and settings'));
      expect(deletes, 1);
    });

    testWidgets('a lapsed review lets her take the check again', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          BeingCheckedView(
            status: const ServerVerification(ServerVerificationState.retry),
            onTryAgain: () => retries++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your review time ran out'), findsOneWidget);
      await tester.tap(find.text('Take the check again'));
      expect(retries, 1);
    });

    testWidgets('while waiting she can look around (C04)', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        _host(BeingCheckedView(onLookAround: () => opened++)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Look around while you wait'));
      expect(opened, 1);
    });

    testWidgets('a live update moves her on once, when approved', (
      tester,
    ) async {
      final updates = StreamController<ServerVerification?>();
      var approved = 0;
      await tester.pumpWidget(
        _host(
          BeingCheckedView(
            updates: updates.stream,
            onApproved: () => approved++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      updates.add(
        ServerVerification(
          ServerVerificationState.pending,
          reviewScheduledFor: DateTime(2026, 10, 5, 10),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Your video call is booked for'),
        findsOneWidget,
      );
      updates.add(const ServerVerification(ServerVerificationState.approved));
      await tester.pumpAndSettle();
      updates.add(const ServerVerification(ServerVerificationState.approved));
      await tester.pumpAndSettle();
      expect(approved, 1);
      await updates.close();
    });

    testWidgets('every variant fits at the largest text size in Arabic', (
      tester,
    ) async {
      for (final state in ServerVerificationState.values) {
        await tester.pumpWidget(
          _host(
            BeingCheckedView(
              key: ValueKey(state),
              status: ServerVerification(state),
              onTryAgain: () {},
              onDeleteMyData: () {},
              onLookAround: () {},
            ),
            locale: const Locale('ar'),
            textScale: 1.6,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$state');
      }
    });
  });
}
