// The desk's rules: who needs a follow up, in what order, and what the filters
// and the search keep.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/desk_model.dart';

import 'desk_support.dart';

DeskModel build(
  List<Subscription> subs, [
  List<Relationship> rels = const <Relationship>[],
]) => DeskModel.build(
  subscriptions: subs,
  relationships: rels,
  myUid: 'me',
  now: kDeskNow,
);

DateTime ago(int days, [int hours = 0]) =>
    kDeskNow.subtract(Duration(days: days, hours: hours));

void main() {
  group('follow up', () {
    test('no line for 7 days, not 6', () {
      final model = build(
        [deskSub('a'), deskSub('b')],
        [
          deskRel('ua', lastAt: ago(7), sender: 'me'),
          deskRel('ub', lastAt: ago(6, 23), sender: 'me'),
        ],
      );
      expect(model.followUps.map((c) => c.id), ['a']);
      expect(model.followUps.single.reasons, [FollowUpReason.quiet]);
      expect(model.followUps.single.quietDays, 7);
    });

    test('with no line at all it counts from when the coaching began', () {
      final model = build([
        deskSub('old', startsAt: ago(9)),
        deskSub('new', startsAt: ago(2)),
      ]);
      expect(model.followUps.map((c) => c.id), ['old']);
    });

    test(
      'her own last line older than 7 days is quiet, a client line is not',
      () {
        final model = build(
          [deskSub('mine'), deskSub('hers')],
          [
            deskRel('umine', lastAt: ago(8), sender: 'me'),
            deskRel('uhers', lastAt: ago(8)),
          ],
        );
        expect(
          {for (final c in model.followUps) c.id: c.reasons},
          {
            'mine': [FollowUpReason.quiet],
            'hers': [FollowUpReason.waitingReply],
          },
        );
      },
    );

    test('waiting for her reply from 24 hours, not 23', () {
      final model = build(
        [deskSub('a'), deskSub('b')],
        [deskRel('ua', lastAt: ago(1)), deskRel('ub', lastAt: ago(0, 23))],
      );
      expect(model.followUps.map((c) => c.id), ['a']);
      expect(model.followUps.single.reasons, [FollowUpReason.waitingReply]);
    });

    test(
      'waiting for a reply comes after a session today, before ending soon',
      () {
        final model = build(
          [
            deskSub('wait', endsAt: kDeskNow.add(const Duration(days: 2))),
            deskSub('ends', endsAt: kDeskNow.add(const Duration(days: 1))),
            deskSub('session', nextSessionAt: DateTime(2026, 10, 24, 20)),
          ],
          [
            deskRel('uwait', lastAt: ago(2)),
            deskRel('usession', lastAt: ago(0, 1)),
          ],
        );
        expect(model.followUps.map((c) => c.id).take(2), ['session', 'wait']);
      },
    );

    test('a programme ending in 3 days, not 4', () {
      final model = build([
        deskSub('soon', endsAt: kDeskNow.add(const Duration(days: 3))),
        deskSub('later', endsAt: kDeskNow.add(const Duration(days: 4))),
      ]);
      expect(model.followUps.map((c) => c.id), ['soon']);
      expect(model.followUps.single.reasons, [FollowUpReason.endingSoon]);
      expect(model.endingSoonCount, 1);
    });

    test('a live session today, not tomorrow', () {
      final model = build([
        deskSub('today', nextSessionAt: DateTime(2026, 10, 24, 18, 30)),
        deskSub('tomorrow', nextSessionAt: DateTime(2026, 10, 25, 9)),
      ]);
      expect(model.followUps.map((c) => c.id), ['today']);
      expect(model.followUps.single.reasons, [FollowUpReason.sessionToday]);
    });

    test(
      'a client with a fresh chat, a long programme and no session is clear',
      () {
        final model = build([deskSub('a')], [deskRel('ua', lastAt: ago(0, 5))]);
        expect(model.followUps, isEmpty);
      },
    );

    test(
      'most urgent first: session today, then ending soonest, then quietest',
      () {
        final model = build(
          [
            deskSub('quiet9', startsAt: ago(9)),
            deskSub('quiet12', startsAt: ago(12)),
            deskSub('ends2', endsAt: kDeskNow.add(const Duration(days: 2))),
            deskSub('ends1', endsAt: kDeskNow.add(const Duration(days: 1))),
            deskSub('session', nextSessionAt: DateTime(2026, 10, 24, 20)),
          ],
          [
            deskRel('uquiet9', lastAt: ago(9), sender: 'me'),
            deskRel('uquiet12', lastAt: ago(12), sender: 'me'),
            deskRel('uends2', lastAt: ago(1), sender: 'me'),
            deskRel('uends1', lastAt: ago(1), sender: 'me'),
            deskRel('usession', lastAt: ago(1), sender: 'me'),
          ],
        );
        expect(model.followUps.map((c) => c.id), [
          'session',
          'ends1',
          'ends2',
          'quiet12',
          'quiet9',
        ]);
      },
    );
  });

  group('unread, sorting and requests', () {
    test('unread counts only her own side', () {
      final model = build(
        [deskSub('a'), deskSub('b')],
        [
          deskRel('ua', lastAt: ago(0, 1), unread: 3),
          Relationship(
            id: relOf('ub'),
            coachUid: 'me',
            clientUid: 'ub',
            status: RelationshipStatus.active,
            lastMessageAt: ago(0, 2),
            unreadFor: const <String, int>{'ub': 5},
          ),
        ],
      );
      expect(model.unreadClients.map((c) => c.id), ['a']);
      expect(model.unreadClients.single.unread, 3);
    });

    test('latest activity first, clients with none last', () {
      final model = build(
        [deskSub('quiet', startsAt: ago(3)), deskSub('new'), deskSub('mid')],
        [
          deskRel('unew', lastAt: ago(0, 1)),
          deskRel('umid', lastAt: ago(1)),
          deskRel('uquiet'),
        ],
      );
      expect(model.clients.map((c) => c.id), ['new', 'mid', 'quiet']);
    });

    test('requests are the requested ones, the oldest first', () {
      final model = build([
        deskSub('r2', status: SubscriptionStatus.requested, createdAt: ago(1)),
        deskSub('r1', status: SubscriptionStatus.requested, createdAt: ago(3)),
        deskSub('paying', status: SubscriptionStatus.awaitingPayment),
        deskSub('a'),
      ]);
      expect(model.requests.map((r) => r.id), ['r1', 'r2']);
      expect(model.clients.map((c) => c.id), ['a']);
    });
  });

  group('filters and search', () {
    final model = build(
      [
        deskSub('a', name: 'Mona Ali', startsAt: ago(10)),
        deskSub('b', name: 'Nour Hassan'),
        deskSub(
          'c',
          name: 'mona Sami',
          endsAt: kDeskNow.add(const Duration(days: 1)),
        ),
        deskSub('d'),
      ],
      [
        deskRel('ub', lastAt: ago(0, 3), unread: 2),
        deskRel('ua', lastAt: ago(10), sender: 'me'),
        deskRel('uc', lastAt: ago(1), sender: 'me'),
        deskRel('ud', lastAt: ago(1), sender: 'me'),
      ],
    );

    List<String> ids(DeskFilter f, [String q = '']) =>
        model.filtered(f, q).map((c) => c.id).toList();

    test('each filter keeps what it says', () {
      expect(ids(DeskFilter.all).toSet(), {'a', 'b', 'c', 'd'});
      expect(ids(DeskFilter.unread), ['b']);
      expect(ids(DeskFilter.followUp).toSet(), {'a', 'c'});
      expect(ids(DeskFilter.endingSoon), ['c']);
      expect(model.countOf(DeskFilter.followUp), 2);
    });

    test('search matches the name, ignoring case and spaces at the ends', () {
      expect(ids(DeskFilter.all, '  MONA ').toSet(), {'a', 'c'});
      expect(ids(DeskFilter.all, 'hass'), ['b']);
      expect(ids(DeskFilter.all, 'zzz'), isEmpty);
    });

    test('search and a filter work together', () {
      expect(ids(DeskFilter.endingSoon, 'mona'), ['c']);
      expect(ids(DeskFilter.unread, 'mona'), isEmpty);
    });

    test('a client with no name is found by the tag shown for her', () {
      expect(ids(DeskFilter.all, tagOf('d')), ['d']);
    });
  });
}
