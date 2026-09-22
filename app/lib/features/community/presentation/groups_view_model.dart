/// What M04, M05 and M06 draw.
///
/// ## A challenge is a shared total, never a leaderboard
///
/// M06's design note is the rule: *"Challenges are shared totals, not
/// leaderboards: everyone who does her part finishes, so there is no last place
/// and no reason to compare a 3 kg dumbbell with a barbell."*
///
/// So [GroupGoalModel] carries a group total, her own part, and a count of women
/// who have finished — and **no ordering of women at all**. There is no list of
/// members here, no "top contributor", and no method that could produce one:
/// `groups/{gid}/members` is `allow list: if false` in the rules, so a roster is
/// not merely absent from this file, it is unreadable.
///
/// ## Member counts are displayed, never ranked
///
/// `groups.memberCount` has a single-field index exemption, so "order groups by
/// size" is unexecutable in the deployed project. Here it is an `int` rendered
/// through `countLabel` — her real figure, not the prototype's 4,210.
library;

import 'package:meta/meta.dart';

import '../../../domain/format/number_label.dart';
import '../domain/community_models.dart';

/// One group row on M04.
@immutable
class GroupRowModel {
  const GroupRowModel({
    required this.groupId,
    required this.name,
    required this.memberCount,
    this.blurb = '',
    this.postsToday = 0,
    this.joined = false,
    this.muted = false,
  });

  factory GroupRowModel.from(CommunityGroup group, {DateTime? now}) =>
      GroupRowModel(
        groupId: group.groupId,
        name: group.name,
        memberCount: group.memberCount,
        blurb: group.blurb,
        postsToday: group.postsToday,
        joined: group.joined,
        muted: now != null && group.isMutedAt(now),
      );

  final String groupId;
  final String name;
  final int memberCount;

  /// What the room is for, in its own words. Empty for a room that has none,
  /// and never filled in with a sentence about it that nobody wrote.
  final String blurb;
  final int postsToday;
  final bool joined;

  /// Muted for a week. Still a member — her posts still count for the
  /// challenge; only the group's posts leave her feed.
  final bool muted;

  String get memberLabel => countLabel(memberCount);

  /// Whether there is a count worth drawing.
  ///
  /// A curated room nobody has joined has **no** members, and a bare "0" under
  /// its name reads as a figure about the room rather than the absence of one.
  bool get showsMemberCount => memberCount > 0;
  String get postsTodayLabel => countLabel(postsToday);

  /// Joining is one tap and raises no dialog.
  bool get offersJoin => !joined;
}

/// M04 — Groups.
@immutable
class GroupsScreenModel {
  const GroupsScreenModel({required this.yours, required this.suggested});

  factory GroupsScreenModel.from({
    required List<CommunityGroup> yours,
    required List<CommunityGroup> suggested,
    DateTime? now,
  }) => GroupsScreenModel(
    yours: <GroupRowModel>[
      for (final g in yours) GroupRowModel.from(g, now: now),
    ],
    suggested: <GroupRowModel>[
      for (final g in suggested) GroupRowModel.from(g, now: now),
    ],
  );

  final List<GroupRowModel> yours;
  final List<GroupRowModel> suggested;

  /// M04 is never empty — curated groups ship with the app.
  bool get isEmpty => yours.isEmpty && suggested.isEmpty;
}

/// M06 — the shared goal.
@immutable
class GroupGoalModel {
  const GroupGoalModel({
    required this.target,
    required this.total,
    required this.perWoman,
    required this.myDone,
    required this.womenFinished,
    required this.womenTaking,
    required this.daysLeft,
  });

  factory GroupGoalModel.from(
    GroupChallenge challenge, {
    required DateTime now,
  }) => GroupGoalModel(
    target: challenge.target,
    total: challenge.total,
    perWoman: challenge.perWoman,
    myDone: challenge.myDone,
    womenFinished: challenge.womenFinished,
    womenTaking: challenge.womenTaking,
    daysLeft: challenge.daysLeftFrom(now),
  );

  final int target;
  final int total;
  final int perWoman;
  final int myDone;

  /// How many women have finished their part. A **count**, not an ordering —
  /// there is no way to ask which women, or in what order.
  final int womenFinished;

  final int womenTaking;
  final int daysLeft;

  /// Whether a challenge is running at all.
  ///
  /// A room with none has no figures, and a zero against a zero target is not
  /// a goal — it is a goal nobody set, drawn as though somebody had.
  bool get hasChallenge => target > 0;

  /// 0..1 for the bar, clamped: a group that overshoots is a success.
  double get fraction => target == 0 ? 0 : (total / target).clamp(0.0, 1.0);

  /// Her own part, as a fraction of what one woman is asked for.
  double get myFraction =>
      perWoman == 0 ? 0 : (myDone / perWoman).clamp(0.0, 1.0);

  bool get myPartDone => myDone >= perWoman;

  String get totalLabel => countLabel(total);
  String get targetLabel => countLabel(target);
  String get myDoneLabel => countLabel(myDone);
  String get perWomanLabel => countLabel(perWoman);
  String get womenFinishedLabel => countLabel(womenFinished);
  String get womenTakingLabel => countLabel(womenTaking);
  String get daysLeftLabel => countLabel(daysLeft);

  /// **Always false.** Nothing here ranks one woman against another, and there
  /// is no field this model could read to do so.
  bool get showsLeaderboard => false;
}

/// M05 — one group: a feed plus one shared goal.
@immutable
class GroupScreenModel {
  const GroupScreenModel({
    required this.group,
    required this.postCount,
    this.goal,
    this.isEmpty = false,
  });

  factory GroupScreenModel.from({
    required CommunityGroup group,
    required int postCount,
    GroupChallenge? challenge,
    DateTime? now,
  }) => GroupScreenModel(
    group: GroupRowModel.from(group, now: now),
    postCount: postCount,
    goal: challenge == null || now == null
        ? null
        : GroupGoalModel.from(challenge, now: now),
    // "This group is new" — the empty state's smallest action is to post.
    isEmpty: postCount == 0,
  );

  final GroupRowModel group;
  final int postCount;

  /// The challenge card sits first, because a shared total is what makes a
  /// group feel like a room rather than a noticeboard.
  final GroupGoalModel? goal;

  final bool isEmpty;

  bool get showsGoal => goal != null;

  /// There is no member list on this screen and no way to reach one.
  bool get showsMemberRoster => false;
}
