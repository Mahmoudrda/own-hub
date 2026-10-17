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
// to look at: a woman from Own Hub reviews her case and contacts her by phone
// within 72 hours. There is no video service, so no copy may promise a video
// call. A screen that says otherwise is
// lying to her at the moment she is most dependent on it, which is why the copy
// assertions below are the substance of this file rather than decoration.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:async';

import 'package:own_hub/app_state/push_registration.dart';
import 'package:own_hub/features/signup/domain/server_verification.dart';
import 'package:own_hub/features/signup/presentation/being_checked_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_card.dart';
import 'package:own_hub/ui/hand/mascot/kitten.dart';

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
    expect(
      find.text('A woman from Own Hub will review your check'),
      findsOneWidget,
    );
    // Who contacts her, and by when. No text message is promised, because
    // nothing exists that could send one (S3). No video call is promised,
    // because no video service exists (1.4).
    expect(
      find.textContaining(
        'A woman from Own Hub reviews your case and contacts you by phone '
        'within 72 hours',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('video'), findsNothing);
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
            of: find.text('A woman from Own Hub will review your check'),
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

    expect(find.text('تحت المراجعة'), findsOneWidget);
    expect(find.text('واحدة من Own Hub هتراجع التحقق بتاعك'), findsOneWidget);
    expect(find.textContaining('فيديو'), findsNothing);
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
        find.textContaining('A woman from Own Hub will contact you on'),
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
        find.textContaining('A woman from Own Hub will contact you on'),
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

  // While she waits for a reviewer, the week she built is on the screen: the
  // one thing that is already hers.
  testWidgets('her saved week is on the waiting screen', (tester) async {
    await tester.pumpWidget(
      _host(
        const BeingCheckedView(
          savedWeek: '3 days a week, 20 minutes a session, at home',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your week is saved'), findsOneWidget);
    expect(
      find.text('3 days a week, 20 minutes a session, at home'),
      findsOneWidget,
    );
  });

  testWidgets('with no week built, there is no card', (tester) async {
    await tester.pumpWidget(_host(const BeingCheckedView()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('c14-saved-week')), findsNothing);
  });

  // R1-P5: a woman who reached the wait with no week of hers can build it
  // here, and is not offered it once she has one or once there is no wait.
  group('build your week while we check', () {
    testWidgets('offered while waiting with no week', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        _host(BeingCheckedView(onBuildWeek: () => opened++)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('c14-build-week')));
      await tester.tap(find.text('Build your week while we check'));
      expect(opened, 1);
    });

    testWidgets('not offered once her week is saved', (tester) async {
      await tester.pumpWidget(
        _host(BeingCheckedView(savedWeek: 'her week', onBuildWeek: () {})),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('c14-build-week')), findsNothing);
    });

    testWidgets('not offered when the wait is over', (tester) async {
      for (final state in [
        ServerVerificationState.rejected,
        ServerVerificationState.retry,
      ]) {
        await tester.pumpWidget(
          _host(
            BeingCheckedView(
              key: ValueKey(state),
              status: ServerVerification(state),
              onBuildWeek: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('c14-build-week')),
          findsNothing,
          reason: '$state',
        );
      }
    });

    testWidgets('in Arabic', (tester) async {
      await tester.pumpWidget(
        _host(BeingCheckedView(onBuildWeek: () {}), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();
      expect(find.text('جهّزي أسبوعك على ما نتحقّق'), findsOneWidget);
    });
  });

  // R1-P5: she may close the app for days. One push when the check is done,
  // asked for here and nowhere else.
  group('tell me when I am in', () {
    Future<void> ask(
      WidgetTester tester,
      PushOptIn answer, {
      VoidCallback? onOpenSettings,
    }) async {
      await tester.pumpWidget(
        _host(
          BeingCheckedView(
            key: ValueKey(answer),
            onNotifyMe: () async => answer,
            onOpenSettings: onOpenSettings,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Turn on notifications so we can tell you when your check '
          'is done.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('c14-notify-me')));
      await tester.tap(find.byKey(const ValueKey('c14-notify-me')));
      await tester.pumpAndSettle();
    }

    testWidgets('a yes is confirmed and the button goes', (tester) async {
      await ask(tester, PushOptIn.on);
      expect(
        find.text('We will tell you on this phone when your check is done.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('c14-notify-me')), findsNothing);
    });

    testWidgets('a no says where to change it', (tester) async {
      var opened = 0;
      await ask(tester, PushOptIn.denied, onOpenSettings: () => opened++);
      expect(find.textContaining('Notifications are off'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      expect(opened, 1);
    });

    testWidgets('a phone push cannot reach is told so', (tester) async {
      await ask(tester, PushOptIn.unavailable);
      expect(
        find.textContaining('Notifications cannot reach this phone'),
        findsOneWidget,
      );
    });

    testWidgets('never asked before the tap, nor off the wait', (tester) async {
      var asked = 0;
      await tester.pumpWidget(
        _host(
          BeingCheckedView(
            status: const ServerVerification(ServerVerificationState.rejected),
            onNotifyMe: () async {
              asked++;
              return PushOptIn.on;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('c14-notify-me')), findsNothing);
      expect(asked, 0);
    });
  });

  test('the device document is the rules\' whitelist, keyed by a hash', () {
    final doc = deviceDocument(
      token: 'fcm-token',
      platform: 'android',
      locale: 'ar',
      appVersion: '1.0.0+1',
    );
    expect(doc.keys.toSet(), {
      'token',
      'platform',
      'appVersion',
      'locale',
      'updatedAt',
    });
    expect(deviceDocId('fcm-token'), hasLength(32));
    expect(deviceDocId('fcm-token'), isNot(contains('fcm')));
  });

  group('the kitten', () {
    setUp(Kitten.resetPlayed);

    testWidgets('waits in sage while the check is pending, and settles once', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const BeingCheckedView()));
      await tester.pump();
      expect(find.byType(Kitten), findsOneWidget);
      final kitten = tester.widget<Kitten>(find.byType(Kitten));
      expect(kitten.pose, KittenPose.wait);
      expect(kitten.size, 56);
      expect(kitten.tint, KittenTint.sage);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('is never beside a refusal or a retry', (tester) async {
      for (final state in const [
        ServerVerificationState.rejected,
        ServerVerificationState.retry,
      ]) {
        await tester.pumpWidget(
          _host(
            BeingCheckedView(
              key: UniqueKey(),
              status: ServerVerification(state),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Kitten), findsNothing, reason: '$state');
      }
    });
  });

  testWidgets('she can always leave and sign in with another number', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      _host(BeingCheckedView(onSignInAgain: () => tapped++)),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('c14-use-another-number'));
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    expect(tapped, 1);
  });
}
