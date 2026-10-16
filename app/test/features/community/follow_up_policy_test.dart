// HANDOFF rule 9 — a follow-up belongs to a parent, and a thread is one woman
// over time.
//
// P0-COM-04: only the parent's author may attach.
// P0-COM-05: never a standalone before-and-after.
// P1-COM-02: the cost card is two integers and nothing else.
// P1-COM-07: no follow-up of a follow-up.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/community/domain/follow_up_policy.dart';

const _policy = FollowUpPolicy();

FollowUpParent _parent({String author = 'habiba', String? parentPostId}) =>
    FollowUpParent(
      postId: 'post-7331',
      authorUid: author,
      parentPostId: parentPostId,
    );

void main() {
  group('only the parent s author may attach — P0-COM-04', () {
    test('her own post is fine', () {
      expect(
        () => _policy.assertCanAttach(parent: _parent(), authorUid: 'habiba'),
        returnsNormally,
      );
      expect(_policy.canAttach(parent: _parent(), authorUid: 'habiba'), isTrue);
    });

    test('another woman s post throws NotYourPostError', () {
      expect(
        () => _policy.assertCanAttach(
          parent: _parent(author: 'habiba'),
          authorUid: 'nada',
        ),
        throwsA(isA<NotYourPostError>()),
      );
    });

    test('and the UI is told not to offer it', () {
      // The case requires BOTH: "not offered in the UI, and refused by security
      // rules". A view model that only had the throwing form would have to
      // catch an exception to decide whether to draw a button.
      expect(
        _policy.canAttach(
          parent: _parent(author: 'habiba'),
          authorUid: 'nada',
        ),
        isFalse,
      );
    });
  });

  group('a chain is one level deep — P1-COM-07', () {
    test('a follow-up cannot itself be a parent', () {
      expect(
        () => _policy.assertCanAttach(
          parent: _parent(parentPostId: 'post-original'),
          authorUid: 'habiba',
        ),
        throwsA(isA<NestedFollowUpError>()),
      );
      expect(
        _policy.canAttach(
          parent: _parent(parentPostId: 'post-original'),
          authorUid: 'habiba',
        ),
        isFalse,
      );
    });

    test('the two refusals are distinguishable', () {
      // Different errors on purpose: "not yours" and "already a follow-up" are
      // different mistakes, and collapsing them would make the rules harder to
      // explain to whoever hits one.
      expect(
        () => _policy.assertCanAttach(
          parent: _parent(author: 'nada', parentPostId: 'p'),
          authorUid: 'habiba',
        ),
        throwsA(isA<NotYourPostError>()),
      );
    });
  });

  group('never two women side by side — P0-COM-05', () {
    FollowUpMoment moment(String author, int day) => FollowUpMoment(
      postId: 'post-$author-$day',
      authorUid: author,
      takenAt: DateTime(2026, 7, day),
    );

    test('a chain of one woman builds', () {
      final chain = FollowUpChain(
        authorUid: 'habiba',
        moments: <FollowUpMoment>[moment('habiba', 3), moment('habiba', 19)],
      );

      expect(chain.moments.length, 2);
      expect(chain.hasFollowUps, isTrue);
      expect(chain.parent.takenAt, DateTime(2026, 7, 3));
    });

    test('a chain naming two women cannot be constructed at all', () {
      expect(
        () => FollowUpChain(
          authorUid: 'habiba',
          moments: <FollowUpMoment>[moment('habiba', 3), moment('nada', 19)],
        ),
        throwsA(isA<MixedAuthorChainError>()),
        reason:
            'M12 takes a chain and nothing else, so "two women side by side" '
            'is not a state the widget tree can be put into.',
      );
    });

    test('a chain whose declared author is not in it is refused', () {
      expect(
        () => FollowUpChain(
          authorUid: 'yasmin',
          moments: <FollowUpMoment>[moment('habiba', 3)],
        ),
        throwsA(isA<MixedAuthorChainError>()),
      );
    });

    test('an empty chain is not a state M12 can be in', () {
      expect(
        () => FollowUpChain(authorUid: 'habiba', moments: const []),
        throwsArgumentError,
      );
    });
  });

  group('the cost card carries two integers — P1-COM-02', () {
    test('it is exactly sessions and counted weeks', () {
      final cost = FollowUpCost.from(sessionsLogged: 61, countedWeeks: 19);

      expect(cost.sessions, 61);
      expect(cost.countedWeeks, 19);
      expect(cost.toWire().keys.toSet(), FollowUpCost.wireKeys);
      expect(FollowUpCost.wireKeys, <String>{'sessions', 'countedWeeks'});
    });

    test('no key it can write resembles a weight', () {
      // The rules re-assert this with hasOnly(['sessions','countedWeeks']).
      // Here it is asserted against the shape the domain can actually produce.
      final keys = FollowUpCost.from(
        sessionsLogged: 61,
        countedWeeks: 19,
      ).toWire().keys.join(' ');

      expect(RegExp('weight', caseSensitive: false).hasMatch(keys), isFalse);
      expect(
        RegExp('lost|kg|scale', caseSensitive: false).hasMatch(keys),
        isFalse,
      );
    });

    test('negative figures are not constructible', () {
      expect(
        () => FollowUpCost(sessions: -1, countedWeeks: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('equal costs compare equal', () {
      expect(
        const FollowUpCost(sessions: 61, countedWeeks: 19),
        const FollowUpCost(sessions: 61, countedWeeks: 19),
      );
    });
  });
}
