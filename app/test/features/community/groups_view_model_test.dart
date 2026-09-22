// M04, M05 and M06 — and the thing a challenge must never become.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/community/domain/community_models.dart';
import 'package:own_hub/features/community/presentation/groups_view_model.dart';

final _now = DateTime(2026, 9, 19, 10);

CommunityGroup _group({
  String id = 'quiet-flats',
  String name = 'Quiet flats',
  int members = 3407,
  int postsToday = 19,
  bool joined = false,
  DateTime? mutedUntil,
}) => CommunityGroup(
  groupId: id,
  name: name,
  memberCount: members,
  postsToday: postsToday,
  joined: joined,
  mutedUntil: mutedUntil,
);

GroupChallenge _challenge({
  int target = 500,
  int total = 317,
  int perWoman = 6,
  int myDone = 2,
  int womenFinished = 41,
  int womenTaking = 88,
  Duration left = const Duration(days: 9),
}) => GroupChallenge(
  challengeId: 'c-1',
  groupId: 'quiet-flats',
  target: target,
  total: total,
  perWoman: perWoman,
  myDone: myDone,
  womenFinished: womenFinished,
  womenTaking: womenTaking,
  endsAt: _now.add(left),
);

void main() {
  group('M04 — groups', () {
    test('yours and suggested are separate lists', () {
      final model = GroupsScreenModel.from(
        yours: <CommunityGroup>[_group(joined: true)],
        suggested: <CommunityGroup>[_group(id: 'ramadan', name: 'Ramadan')],
      );

      expect(model.yours.single.joined, isTrue);
      expect(model.suggested.single.offersJoin, isTrue);
      expect(model.isEmpty, isFalse);
    });

    test('member counts are her real figures, in Western digits', () {
      final row = GroupRowModel.from(_group(members: 3407, postsToday: 19));

      expect(row.memberLabel, '3,407');
      expect(row.postsTodayLabel, '19');
    });

    test('a muted group is still joined', () {
      final row = GroupRowModel.from(
        _group(joined: true, mutedUntil: _now.add(const Duration(days: 5))),
        now: _now,
      );

      expect(row.muted, isTrue);
      expect(
        row.joined,
        isTrue,
        reason:
            'mute is "still a member, just quiet" — leaving should not be the '
            'only way to get quiet',
      );
    });

    test('a lapsed mute is not a mute', () {
      final row = GroupRowModel.from(
        _group(joined: true, mutedUntil: _now.subtract(const Duration(days: 1))),
        now: _now,
      );

      expect(row.muted, isFalse);
    });
  });

  group('M06 — a shared total, never a leaderboard', () {
    test('there is no leaderboard, and no field that could feed one', () {
      final goal = GroupGoalModel.from(_challenge(), now: _now);

      expect(goal.showsLeaderboard, isFalse);
    });

    test('the group total and her own part are different numbers', () {
      final goal = GroupGoalModel.from(
        _challenge(target: 500, total: 317, perWoman: 6, myDone: 2),
        now: _now,
      );

      expect(goal.totalLabel, '317');
      expect(goal.targetLabel, '500');
      expect(goal.myDoneLabel, '2');
      expect(goal.perWomanLabel, '6');
      expect(goal.fraction, closeTo(317 / 500, 0.0001));
      expect(goal.myFraction, closeTo(2 / 6, 0.0001));
      expect(goal.myPartDone, isFalse);
    });

    test('finishing her part does not depend on anyone else', () {
      final goal = GroupGoalModel.from(
        _challenge(perWoman: 6, myDone: 6, total: 11),
        now: _now,
      );

      expect(
        goal.myPartDone,
        isTrue,
        reason:
            'M06: "One more and you have finished, whatever anyone else does."',
      );
    });

    test('overshooting the target is a success, not a layout bug', () {
      final goal = GroupGoalModel.from(
        _challenge(target: 500, total: 902),
        now: _now,
      );

      expect(goal.fraction, 1.0);
    });

    test('a challenge with no target does not divide by zero', () {
      final goal = GroupGoalModel.from(
        _challenge(target: 0, total: 0, perWoman: 0, myDone: 0),
        now: _now,
      );

      expect(goal.fraction, 0);
      expect(goal.myFraction, 0);
    });

    test('days left never runs negative', () {
      final goal = GroupGoalModel.from(
        _challenge(left: const Duration(days: -4)),
        now: _now,
      );

      expect(goal.daysLeftLabel, '0');
    });

    test('women who finished is a count, not an order', () {
      final goal = GroupGoalModel.from(
        _challenge(womenFinished: 41, womenTaking: 88),
        now: _now,
      );

      expect(goal.womenFinishedLabel, '41');
      expect(goal.womenTakingLabel, '88');
    });
  });

  group('M05 — a group is a feed plus one shared goal', () {
    test('the goal card is present when a challenge is running', () {
      final model = GroupScreenModel.from(
        group: _group(joined: true),
        postCount: 12,
        challenge: _challenge(),
        now: _now,
      );

      expect(model.showsGoal, isTrue);
      expect(model.isEmpty, isFalse);
    });

    test('a new group says so, and its smallest action is to post', () {
      final model = GroupScreenModel.from(
        group: _group(joined: true),
        postCount: 0,
        now: _now,
      );

      expect(model.isEmpty, isTrue);
      expect(model.showsGoal, isFalse);
    });

    test('there is no member roster anywhere on the screen', () {
      final model = GroupScreenModel.from(
        group: _group(joined: true),
        postCount: 3,
        now: _now,
      );

      expect(
        model.showsMemberRoster,
        isFalse,
        reason: 'members is allow list: if false — 3,407 women are not a list',
      );
    });
  });
}
