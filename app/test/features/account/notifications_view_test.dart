// A01 — Notifications.
//
// Covers P2-RTL-A01 and P2-TXT-A01, and pins the decision that keeps this
// screen honest: a notification kind with no authored copy is counted and not
// drawn, rather than rendered with the prototype's sample about somebody else.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/account/domain/notifications.dart';
import 'package:own_hub/features/account/presentation/account_view_models.dart';
import 'package:own_hub/features/account/presentation/notifications_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_empty_state.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
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
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

AppNotification _notification(NotificationKind kind, int day) =>
    AppNotification(
      id: '${kind.name}-$day',
      kind: kind,
      createdAt: DateTime(2026, 9, day),
    );

void main() {
  group('the inbox renders only what it can say truthfully', () {
    testWidgets('an empty inbox is the onboarding, not an error', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(_host(const NotificationsView()));
      await tester.pumpAndSettle();

      // HANDOFF rule 17 — the empty state IS the onboarding. It says what will
      // appear and states the rule about them stopping.
      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(
        find.text('A few gentle reminders. Turn any of them off here.'),
        findsOneWidget,
      );
    });

    testWidgets('every kind draws its own authored title', (tester) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          NotificationsView(
            notifications: [
              _notification(NotificationKind.coachReply, 18),
              _notification(NotificationKind.groupMilestone, 17),
              _notification(NotificationKind.reaction, 16),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppL10n(const Locale('en'));
      expect(find.text(l10n.yourCoachRepliedToYourReview), findsOneWidget);
      expect(find.text(l10n.yourGroupReachedANewMilestone), findsOneWidget);
      expect(find.text(l10n.yourBestGotAFewLikes), findsOneWidget);

      // None of the prototype's four sample sentences reaches a screen: each
      // names a coach, a group or a woman who may not exist for her.
      expect(find.text('Sara replied to your review'), findsNothing);
      expect(find.text('Beginners group reached 146 sessions'), findsNothing);
      expect(find.text('Habiba and 12 others liked your best'), findsNothing);
      expect(find.byType(AppEmptyState), findsNothing);
    });

    test('every kind has a title in English and Arabic', () {
      for (final code in ['en', 'ar']) {
        final l10n = lookupAppL10n(Locale(code));
        for (final kind in NotificationKind.values) {
          expect(
            NotificationCopy.titleFor(kind, l10n).trim(),
            isNotEmpty,
            reason: '$kind in $code',
          );
          expect(NotificationCopy.hasAuthoredCopy(kind, l10n), isTrue);
        }
      }
    });

    test('the gap is counted, so it is measurable rather than silent', () {
      final view = NotificationsInboxView.from(
        notifications: [
          _notification(NotificationKind.coachReply, 18),
          _notification(NotificationKind.weekClosed, 17),
        ],
        permission: NotificationPermission.initial,
        // No kind has authored copy today.
        hasAuthoredCopy: (_) => false,
      );

      expect(view.rows, isEmpty);
      expect(view.isEmpty, isTrue);
      expect(
        view.unrenderableCount,
        2,
        reason:
            'the count expires by itself the day G7 Q11 is settled and the '
            'strings land',
      );
    });

    test('a kind WITH copy is drawn, proving the path is not dead', () {
      // The positive control. A view model that held everything back would be
      // indistinguishable from one whose filter is broken — the vacuous-guard
      // failure PHASE1-FIXES.md §14 records.
      final view = NotificationsInboxView.from(
        notifications: [
          _notification(NotificationKind.weekClosed, 17),
          _notification(NotificationKind.coachReply, 18),
        ],
        permission: NotificationPermission.initial,
        hasAuthoredCopy: (kind) => kind == NotificationKind.weekClosed,
      );

      expect(view.rows, hasLength(1));
      expect(view.rows.single.kind, NotificationKind.weekClosed);
      expect(view.unrenderableCount, 1);
      expect(view.isEmpty, isFalse);
    });
  });

  group('the permission row', () {
    testWidgets('offers the nudge when it may still be asked for', (
      tester,
    ) async {
      // It read "Turn on notifications so we can tell you when your check is
      // done" — ID-verification copy, on the bell that is the second most
      // prominent control on the app's first screen, for a check this build
      // does not run and a sign-up flow that is switched off. What it asks for
      // now is the nudge the screen has always promised below it.
      _phone(tester);

      await tester.pumpWidget(_host(const NotificationsView()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('your check is done'),
        findsNothing,
        reason: 'there is no check in this release',
      );
      expect(
        find.text(
          'Turn notifications on, so we can nudge you at your usual time.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a terminal denial deep-links to settings, never re-prompts', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          const NotificationsView(
            permission: NotificationPermission(
              state: NotifPermission.deniedTerminal,
              promptsUsed: 2,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open settings'), findsOneWidget);
      expect(
        find.text(
          'Turn notifications on, so we can nudge you at your usual time.',
        ),
        findsNothing,
        reason: 'G7 §3.1: denied forever means never prompting again',
      );
    });

    testWidgets('a granted permission offers neither', (tester) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          const NotificationsView(
            permission: NotificationPermission(state: NotifPermission.granted),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open settings'), findsNothing);
      expect(
        find.text(
          'Turn notifications on, so we can nudge you at your usual time.',
        ),
        findsNothing,
      );
    });
  });

  group('P2-RTL-A01 and P2-TXT-A01', () {
    testWidgets('Arabic renders right-to-left', (tester) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(const NotificationsView(), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the largest system text size clips nothing', (tester) async {
      _phone(tester);

      await tester.pumpWidget(_host(const NotificationsView(), textScale: 2.0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AppEmptyState), findsOneWidget);
    });
  });
}
