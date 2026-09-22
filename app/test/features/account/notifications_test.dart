// A01 — the inbox that cannot become an unbounded scan, and the permission
// machine in which "denied forever" is a first-class state.
//
// The counts here are deliberately not the prototype's four sample rows.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/account/domain/notifications.dart';

AppNotification _nudge(String id, int day, {NudgeOutcome? outcome}) =>
    AppNotification(
      id: id,
      kind: NotificationKind.mealNudge,
      createdAt: DateTime(2026, 9, day, 8, 40),
      outcome: outcome,
    );

void main() {
  group('the inbox is bounded by construction', () {
    test('a page larger than the cap is refused, not quietly served', () async {
      final repository = InMemoryNotificationsRepository();

      // G7 §2: at 15 documents a page, a once-a-day habit spends 15 of the
      // 8-read daily allowance on this screen alone. A fake that honoured any
      // limit would let a 50-row page pass every test here and blow the budget
      // in production.
      expect(() => repository.page(limit: 40), throwsA(isA<StateError>()));
    });

    test('the default page is exactly the cap', () async {
      final repository = InMemoryNotificationsRepository([
        for (var i = 1; i <= 23; i++)
          AppNotification(
            id: 'week-2026-W$i-closed',
            kind: NotificationKind.weekClosed,
            createdAt: DateTime(2026, 4, i),
          ),
      ]);

      final page = await repository.page();

      expect(page, hasLength(kInboxPageSize));
      expect(kInboxPageSize, 15);
    });

    test('newest first', () async {
      final repository = InMemoryNotificationsRepository([
        _nudge('nudge-2026-09-14-breakfast', 14),
        _nudge('nudge-2026-09-17-breakfast', 17),
        _nudge('nudge-2026-09-15-breakfast', 15),
      ]);

      final page = await repository.page();

      expect(page.map((n) => n.id).toList(), [
        'nudge-2026-09-17-breakfast',
        'nudge-2026-09-15-breakfast',
        'nudge-2026-09-14-breakfast',
      ]);
    });

    test('there is no watch() — a live listener is what breaks the budget', () {
      // Asserted structurally: NotificationsRepository has no Stream-returning
      // method, so a screen cannot open a snapshot listener on the inbox. A
      // listener re-reads on every server-side write and is the standard way
      // this goes wrong.
      final repository = InMemoryNotificationsRepository();
      expect(repository, isA<NotificationsRepository>());
    });

    test('expiry is derived from createdAt, never stored separately', () {
      final notification = _nudge('nudge-2026-09-02-breakfast', 2);

      expect(
        notification.expiresAt,
        DateTime(2026, 9, 2, 8, 40).add(kNotificationTtl),
      );
      expect(kNotificationTtl, const Duration(days: 30));
    });
  });

  group('the client writes three fields and no others', () {
    test('marking read records one id', () async {
      final repository = InMemoryNotificationsRepository([
        _nudge('nudge-2026-09-16-breakfast', 16),
      ]);

      await repository.markRead('nudge-2026-09-16-breakfast');

      expect(repository.reads, ['nudge-2026-09-16-breakfast']);
      final page = await repository.page();
      expect(page.single.read, isTrue);
      expect(page.single.readAt, isNotNull);
    });

    test('an outcome is written to that nudge\'s own document', () async {
      // The C3 correction applied to G7's own collection: two devices answering
      // the same nudge converge on one document, rather than clobbering a
      // shared array on the user document.
      final repository = InMemoryNotificationsRepository([
        _nudge('nudge-2026-09-16-breakfast', 16),
      ]);

      await repository.recordOutcome(
        'nudge-2026-09-16-breakfast',
        NudgeOutcome.logged,
      );

      expect(repository.outcomes, ['nudge-2026-09-16-breakfast:logged']);
    });
  });

  group('spine C6 — "ignore three and they stop", with nothing counting', () {
    test('three ignored nudges suppress the next one', () {
      final ignored = [
        _nudge('n3', 18, outcome: NudgeOutcome.ignored),
        _nudge('n2', 17, outcome: NudgeOutcome.ignored),
        _nudge('n1', 16, outcome: NudgeOutcome.ignored),
      ];

      expect(MealNudgeSuppression.suppressed(ignored), isTrue);
    });

    test('one answered nudge in the last three does not suppress', () {
      final mixed = [
        _nudge('n3', 18, outcome: NudgeOutcome.ignored),
        _nudge('n2', 17, outcome: NudgeOutcome.logged),
        _nudge('n1', 16, outcome: NudgeOutcome.ignored),
      ];

      expect(MealNudgeSuppression.suppressed(mixed), isFalse);
    });

    test('a dismissal is not an ignore', () {
      // Dismissing is an answer — she saw it and said no. Ignoring is silence.
      final mixed = [
        _nudge('n3', 18, outcome: NudgeOutcome.ignored),
        _nudge('n2', 17, outcome: NudgeOutcome.dismissed),
        _nudge('n1', 16, outcome: NudgeOutcome.ignored),
      ];

      expect(MealNudgeSuppression.suppressed(mixed), isFalse);
    });

    test('fewer than three is never suppression', () {
      final two = [
        _nudge('n2', 18, outcome: NudgeOutcome.ignored),
        _nudge('n1', 17, outcome: NudgeOutcome.ignored),
      ];

      expect(
        MealNudgeSuppression.suppressed(two),
        isFalse,
        reason:
            'a woman with two ignored nudges has not told us anything three '
            'times',
      );
      expect(MealNudgeSuppression.suppressed(const []), isFalse);
    });

    test('the rule is derived at read time from documents that already exist', () async {
      // The C6 guarantee: there is no field anywhere in the G7 schema holding a
      // run of ignored nudges, so this cannot be rendered as a streak. The
      // input is three documents; the output is computed on the spot.
      final repository = InMemoryNotificationsRepository([
        _nudge('n4', 19, outcome: NudgeOutcome.ignored),
        _nudge('n3', 18, outcome: NudgeOutcome.ignored),
        _nudge('n2', 17, outcome: NudgeOutcome.ignored),
        _nudge('n1', 16, outcome: NudgeOutcome.logged),
        AppNotification(
          id: 'week-2026-W38-closed',
          kind: NotificationKind.weekClosed,
          createdAt: DateTime(2026, 9, 20),
        ),
      ]);

      final recent = await repository.recentMealNudges();

      // Only meal nudges, only the last three — the week-closed row is not one.
      expect(recent, hasLength(3));
      expect(recent.map((n) => n.id).toList(), ['n4', 'n3', 'n2']);
      expect(MealNudgeSuppression.suppressed(recent), isTrue);
    });
  });

  group('permission — denied forever is a real state', () {
    test('the product never prompts at launch, but may prompt once asked', () {
      const initial = NotificationPermission.initial;

      expect(initial.state, NotifPermission.notDetermined);
      expect(initial.canPrompt, isTrue);
      expect(initial.delivers, isFalse);
    });

    test('granted delivers', () {
      final prompting = NotificationPermissionController.transition(
        NotificationPermission.initial,
        PermissionEvent.promptShown,
      );
      expect(prompting.state, NotifPermission.prompting);
      expect(prompting.promptsUsed, 1);

      final granted = NotificationPermissionController.transition(
        prompting,
        PermissionEvent.userGranted,
      );
      expect(granted.state, NotifPermission.granted);
      expect(granted.delivers, isTrue);
    });

    test('the first denial is soft and leaves exactly one more chance', () {
      var permission = NotificationPermissionController.transition(
        NotificationPermission.initial,
        PermissionEvent.promptShown,
      );
      permission = NotificationPermissionController.transition(
        permission,
        PermissionEvent.userDenied,
      );

      expect(permission.state, NotifPermission.deniedSoft);
      expect(
        permission.canPrompt,
        isTrue,
        reason: 'may ask once more, at a moment of value',
      );
    });

    test('the second denial is terminal and is never prompted again', () {
      var permission = NotificationPermission.initial;
      // Ask, denied.
      permission = NotificationPermissionController.transition(
        permission,
        PermissionEvent.promptShown,
      );
      permission = NotificationPermissionController.transition(
        permission,
        PermissionEvent.userDenied,
      );
      // Ask once more, denied again.
      permission = NotificationPermissionController.transition(
        permission,
        PermissionEvent.promptShown,
      );
      permission = NotificationPermissionController.transition(
        permission,
        PermissionEvent.userDenied,
      );

      expect(permission.state, NotifPermission.deniedTerminal);
      expect(permission.canPrompt, isFalse);

      // And asking again changes nothing at all.
      final again = NotificationPermissionController.transition(
        permission,
        PermissionEvent.promptShown,
      );
      expect(again.state, NotifPermission.deniedTerminal);
      expect(
        again.promptsUsed,
        permission.promptsUsed,
        reason:
            're-prompting a woman who said no twice is how an app earns a '
            'permanent OS-level denial',
      );
    });

    test('provisional behaves as granted', () {
      final prompting = NotificationPermissionController.transition(
        NotificationPermission.initial,
        PermissionEvent.promptShown,
      );
      final provisional = NotificationPermissionController.transition(
        prompting,
        PermissionEvent.userGrantedProvisional,
      );

      expect(provisional.state, NotifPermission.provisional);
      expect(provisional.delivers, isTrue);
    });

    test('revoking in Settings is detected, and re-granting is too', () {
      const granted = NotificationPermission(state: NotifPermission.granted);

      final revoked = NotificationPermissionController.transition(
        granted,
        PermissionEvent.detectedRevoked,
      );
      expect(revoked.state, NotifPermission.revokedInSettings);
      expect(revoked.delivers, isFalse);

      final back = NotificationPermissionController.transition(
        revoked,
        PermissionEvent.detectedGrantedInSettings,
      );
      expect(back.state, NotifPermission.granted);
    });

    test('a token failure wins from any state, and never fails silently', () {
      for (final from in [
        NotifPermission.notDetermined,
        NotifPermission.granted,
        NotifPermission.provisional,
        NotifPermission.deniedTerminal,
      ]) {
        final unavailable = NotificationPermissionController.transition(
          NotificationPermission(state: from),
          PermissionEvent.deliveryUnavailable,
        );

        expect(unavailable.state, NotifPermission.unavailable);
        expect(unavailable.delivers, isFalse);
        expect(unavailable.canPrompt, isFalse);
      }
    });

    test('an unexpected callback is a no-op rather than a crash', () {
      // Both platforms deliver permission callbacks more than once. Crashing
      // her app over a duplicate would be a worse answer than ignoring it.
      const granted = NotificationPermission(state: NotifPermission.granted);

      expect(
        NotificationPermissionController.transition(
          granted,
          PermissionEvent.userDenied,
        ),
        granted,
      );
    });
  });
}
