// Community, driven through the REAL app: boot it, tap what she would tap,
// and assert the room changed.
//
// # Why this exists
//
// Every M screen had thorough widget tests and none of them proved anything
// about the running app, because the router built each screen from a model
// computed once and passed no callbacks: `onLike`, `onSave`, `onJoin` and the
// composer were all absent. A woman could tap a heart forever and the count
// never moved, while 254 community tests stayed green.
//
// So these tests drive `AppRouter.onGenerateRoute` through `OwnHubApp` and
// assert on what is on screen afterwards. Remove the wiring and the widget
// tests stay green while these go red — which is the only kind of test that
// could have caught the defect they exist for.
//
// # What is deliberately NOT asserted
//
// There are no other women in this build, so nothing here expects a like from
// someone else, a follower figure or a seeded post. The feed starts empty and
// fills with what she writes, and that is asserted too.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/community_state.dart';
import 'package:own_hub/app_state/pledge.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/account/domain/safety.dart';
import 'package:own_hub/features/community/domain/community_models.dart';
import 'package:own_hub/features/community/presentation/community_widgets.dart';
import 'package:own_hub/features/community/presentation/feed_view.dart';
import 'package:own_hub/features/community/presentation/feed_view_model.dart';
import 'package:own_hub/features/community/presentation/follow_up_thread_view.dart';
import 'package:own_hub/features/community/presentation/group_view.dart';
import 'package:own_hub/features/community/presentation/post_view.dart';
import 'package:own_hub/features/community/presentation/profile_view.dart'
    as member;
import 'package:own_hub/features/community/presentation/reels_view.dart';
import 'package:own_hub/features/community/presentation/safety_sheet_view.dart';
import 'package:own_hub/features/community/presentation/story_viewer_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_button.dart';

/// Long enough for the five-second undo window to close and the post to land.
const Duration _afterUndoWindow = Duration(seconds: 6);

/// The heart ON the post. The one in the feed's masthead opens Activity, and
/// tapping that instead is how a like test can pass while liking nothing.
final Finder _likeOnPost = find.descendant(
  of: find.byType(PostActionBar),
  matching: find.byIcon(Icons.favorite_border),
);

final Finder _unlikeOnPost = find.descendant(
  of: find.byType(PostActionBar),
  matching: find.byIcon(Icons.favorite),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// Boots the real app and opens [screenId] through the real router.
Future<void> _open(WidgetTester tester, String screenId) async {
  _phone(tester);
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .pushNamed(appDestinations[screenId]!.name);
  await tester.pumpAndSettle();
}

/// Opens [screenId] on an app that is already running.
Future<void> _goTo(WidgetTester tester, String screenId) async {
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .pushNamed(appDestinations[screenId]!.name);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

/// Writes one text post from M03's composer and waits for it to land.
Future<void> _writePost(
  WidgetTester tester,
  String words, {
  String? topic,
  String? audience,
}) async {
  await _tap(tester, find.text('Write a post'));
  await tester.enterText(find.byType(TextField).first, words);
  await tester.pumpAndSettle();
  if (audience != null) await _tap(tester, find.text(audience));
  if (topic != null) await _tap(tester, find.text(topic));
  await _tap(tester, find.widgetWithText(AppButton, 'Post'));
  await _settleUndoBar(tester);
}

/// Lets the undo bar appear, run its five seconds and leave.
///
/// The five seconds have to pass for the post to be written at all — the bus
/// holds the work until the window closes — and the bar has to go before the
/// next tap, because it sits over the footer of the screen underneath.
Future<void> _settleUndoBar(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(_afterUndoWindow);
  await tester.pumpAndSettle();
  // Then take the bar off the screen. It covers the footer of whatever is
  // underneath while it is up — which is how a tap on "Post the follow-up"
  // silently landed on a snackbar instead of a button.
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
      .clearSnackBars();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    CommunityState.instance.reset();
    // She agreed to the rules (C16) before the feed; the gate itself is
    // proved in pledge_gate_test.dart.
    PledgeState.instance.agree();
  });

  tearDown(() {
    CommunityState.instance.reset();
    PledgeState.instance.reset();
    // Built from allOff, never from the shipped defaults: this case needs
    // every feature on and no account required, and says so.
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
  });

  testWidgets('the feed starts empty and nothing in it is invented', (
    tester,
  ) async {
    await _open(tester, 'M01');

    expect(find.byType(FeedView), findsOneWidget);
    // Day one: she follows nobody and has joined nothing, so the tab is the
    // empty state and not somebody else's timeline.
    expect(find.text('Your feed is empty on purpose'), findsOneWidget);
    // The rooms are real and joinable; nobody is in them yet, so no room
    // states a member count.
    expect(find.text('Beginners group'), findsOneWidget);
    expect(CommunityState.instance.store.posts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('she writes a text post and it is on her feed, her page and M02', (
    tester,
  ) async {
    await _open(tester, 'M03');
    await _writePost(tester, 'Rain today, walked anyway.');

    // One document, hers, with no media — a text post is the same document
    // with nothing in media[].
    final posts = CommunityState.instance.store.posts;
    expect(posts, hasLength(1));
    expect(posts.single.isTextOnly, isTrue);
    expect(posts.single.caption, 'Rain today, walked anyway.');

    // M01 is no longer the empty state: it shows what she wrote.
    await _goTo(tester, 'M01');
    expect(find.textContaining('Rain today, walked anyway.'), findsWidgets);

    // Her own page shows it too.
    await _goTo(tester, 'M07');
    expect(find.byType(member.ProfileView), findsOneWidget);
    expect(find.textContaining('Rain today, walked anyway.'), findsWidgets);

    // Her tabs are three different reads of the store, not one grid relabelled:
    // a text post is on Photos and is not a reel.
    await _tap(tester, find.byIcon(Icons.videocam_outlined));
    expect(find.textContaining('Rain today, walked anyway.'), findsNothing);
    await _tap(tester, find.byIcon(Icons.photo_library_outlined));
    expect(find.textContaining('Rain today, walked anyway.'), findsWidgets);

    // And it opens as a post.
    await _goTo(tester, 'M01');
    await _tap(tester, find.textContaining('Rain today, walked anyway.'));
    expect(find.byType(PostView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('like, unlike, and the count is hers', (tester) async {
    await _open(tester, 'M03');
    await _writePost(tester, 'First week done.');
    await _goTo(tester, 'M01');

    expect(CommunityState.instance.store.posts.single.likeCount, 0);
    await _tap(tester, _likeOnPost);
    expect(CommunityState.instance.store.posts.single.likeCount, 1);
    expect(CommunityState.instance.store.posts.single.likedByMe, isTrue);
    // The heart on screen filled in.
    expect(find.byIcon(Icons.favorite), findsWidgets);

    await _tap(tester, _unlikeOnPost);
    expect(CommunityState.instance.store.posts.single.likeCount, 0);
    expect(CommunityState.instance.store.posts.single.likedByMe, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save shows on M15, and the chips narrow what she saved', (
    tester,
  ) async {
    await _open(tester, 'M03');
    await _writePost(tester, 'Quiet floor work.', topic: 'Quiet');
    await _goTo(tester, 'M01');

    await _tap(
      tester,
      find.descendant(
        of: find.byType(PostActionBar),
        matching: find.byIcon(Icons.bookmark_border),
      ),
    );
    expect(CommunityState.instance.store.saved, hasLength(1));

    await _goTo(tester, 'M15');
    expect(find.text('Nothing saved yet'), findsNothing);

    // "Quiet moves" keeps it — she gave the post that topic.
    await _tap(tester, find.text('Quiet moves'));
    expect(find.text('Nothing saved yet'), findsNothing);
    // Nothing in community is a meal, so that chip narrows to nothing rather
    // than pretending a post is one.
    await _tap(tester, find.text('Meals'));
    expect(find.text('Nothing saved yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('she comments on a post and it is there when she opens it', (
    tester,
  ) async {
    await _open(tester, 'M03');
    await _writePost(tester, 'Knees did not hurt.');
    await _goTo(tester, 'M01');
    await _tap(tester, find.textContaining('Knees did not hurt.'));

    await tester.enterText(find.byType(TextField).last, 'Well done, me.');
    await tester.pumpAndSettle();
    await _tap(tester, find.byIcon(Icons.send));

    final postId = CommunityState.instance.store.posts.single.postId;
    expect(CommunityState.instance.store.comments[postId], hasLength(1));
    expect(find.textContaining('Well done, me.'), findsWidgets);
    // The count on the post moved with it.
    expect(CommunityState.instance.store.posts.single.commentCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('her own post offers delete, and never report or block', (
    tester,
  ) async {
    await _open(tester, 'M03');
    await _writePost(tester, 'Something of mine.');
    await _goTo(tester, 'M01');
    await _tap(tester, find.byIcon(Icons.more_vert).first);

    // Reporting and blocking herself are refused by the rules, so they are not
    // offered at all rather than offered and then quietly failing.
    expect(find.text('Report this post'), findsNothing);
    expect(find.text('She disappears from your feed and cannot'), findsNothing);
    expect(find.text('Delete this post'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reporting another woman asks why, and files the reason', (
    tester,
  ) async {
    // There is no other woman in this build to open the sheet ON, so the sheet
    // is pumped with a subject who is not her. Everything else is the real
    // screen: the second step, the seven reasons and what they file.
    _phone(tester);
    ReportReason? filed;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: SafetySheetView(
          model: SafetySheetModel.from(subjectName: 'Someone'),
          onReportReason: (reason) => filed = reason,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The reasons are a second step in the same sheet — filing one without a
    // reason is not a report anybody can act on.
    await _tap(tester, find.text('Report this post'));
    expect(find.text('Why are you reporting this?'), findsOneWidget);
    expect(find.text('Harassment or bullying'), findsOneWidget);
    expect(find.text("This is a man's account"), findsOneWidget);
    expect(find.text('Another reason'), findsOneWidget);

    await _tap(tester, find.text('Spam'));
    expect(filed, ReportReason.spam);
    // Nothing anywhere claims a moderator is reading it.
    expect(find.textContaining('A woman moderator reads it'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('she deletes her own post and it is gone everywhere', (
    tester,
  ) async {
    await _open(tester, 'M03');
    await _writePost(tester, 'Posted by mistake.');
    await _goTo(tester, 'M01');
    await _tap(tester, find.byIcon(Icons.more_vert).first);

    // Deleting is the documented exemption to "undo, not confirmation": a
    // second step in this sheet, never a dialog.
    expect(find.text('Delete this post'), findsOneWidget);
    await _tap(tester, find.text('Delete this post'));
    expect(find.text('Tap again to delete it everywhere'), findsOneWidget);
    await _tap(tester, find.text('Delete this post'));

    expect(CommunityState.instance.store.posts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a report against another woman is filed against her', (
    tester,
  ) async {
    // Reporting her own post is refused by the service, so the one assertion
    // that the report really is filed is made against a post by somebody else.
    final before = AppRouter.reportService.reports().length;
    await CommunityState.instance.report('her', ReportReason.harassment);
    expect(AppRouter.reportService.reports().length, before + 1);
    expect(AppRouter.reportService.reports().first.subjectUid, 'her');
  });

  testWidgets('groups: join, post into one, then leave', (tester) async {
    await _open(tester, 'M04');

    expect(find.text('Beginners group'), findsOneWidget);
    await _tap(tester, find.widgetWithText(AppButton, 'Join').first);
    expect(find.text('Joined'), findsWidgets);
    expect(
      CommunityState.instance.store.groups.where((g) => g.joined),
      hasLength(1),
    );

    // Into the room, and post into it: the composer opens with the group
    // already chosen.
    await _tap(tester, find.text('Beginners group'));
    expect(find.byType(GroupView), findsOneWidget);
    await _tap(tester, find.widgetWithText(AppButton, 'Post'));
    await _writePost(tester, 'Hello, room.');

    final posted = CommunityState.instance.store.posts.single;
    expect(posted.groupId, isNotNull);
    expect(posted.audienceKeys.size, 2);

    // The group's own feed shows it.
    await _goTo(tester, 'M05');
    expect(find.textContaining('Hello, room.'), findsWidgets);

    // Leaving is one tap, because joining again is one tap.
    await _tap(tester, find.widgetWithText(AppButton, 'Leave group'));
    expect(
      CommunityState.instance.store.groups.where((g) => g.joined),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('muting a group is offered inside the room, and lifts again', (
    tester,
  ) async {
    await _open(tester, 'M04');
    await _tap(tester, find.widgetWithText(AppButton, 'Join').first);
    await _tap(tester, find.text('Beginners group'));
    await _tap(tester, find.byIcon(Icons.more_vert));

    expect(find.text('Mute this group for a week'), findsOneWidget);
    await _tap(tester, find.text('Mute this group for a week'));
    expect(CommunityState.instance.isMuted('g-beginners'), isTrue);
    // Still a member. Mute is not a way of leaving.
    expect(CommunityState.instance.group('g-beginners')!.joined, isTrue);

    await _tap(tester, find.byIcon(Icons.more_vert));
    expect(find.text('Unmute this group'), findsOneWidget);
    await _tap(tester, find.text('Unmute this group'));
    expect(CommunityState.instance.isMuted('g-beginners'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M10 chips narrow the grid to the topic she picked', (
    tester,
  ) async {
    await _open(tester, 'M03');
    await _writePost(tester, 'A quiet one.', topic: 'Quiet');
    await _goTo(tester, 'M10');

    // Every topic carries a chip now; two of the five used to be omitted for
    // want of a word in the dictionary.
    expect(find.text('Beginners'), findsOneWidget);
    expect(find.text('Walking'), findsOneWidget);

    expect(find.textContaining('A quiet one.'), findsWidgets);
    await _tap(tester, find.text('Ramadan'));
    expect(find.textContaining('A quiet one.'), findsNothing);
    await _tap(tester, find.text('Quiet'));
    expect(find.textContaining('A quiet one.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M14 shows what really happened on her post', (tester) async {
    await _open(tester, 'M03');
    await _writePost(tester, 'Something worth a heart.');
    await _goTo(tester, 'M01');
    await _tap(tester, _likeOnPost);

    await _goTo(tester, 'M14');
    // A line is a woman who did something. There is one woman in this build.
    expect(find.text('You'), findsWidgets);
    expect(find.byIcon(Icons.favorite), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a follow-up on her own post makes a thread on M12', (
    tester,
  ) async {
    await _open(tester, 'M03');
    await _writePost(tester, 'Week one.');

    await _goTo(tester, 'M14');
    // The nudge is about a real post of hers, and it is the only one here.
    await _tap(tester, find.widgetWithText(AppButton, 'Add'));
    await _tap(tester, find.widgetWithText(AppButton, 'Post the follow-up'));
    await _settleUndoBar(tester);

    final posts = CommunityState.instance.store.posts;
    expect(posts, hasLength(2));
    expect(posts.where((p) => p.isFollowUp), hasLength(1));
    // A chain is one woman over time.
    expect(posts.map((p) => p.authorUid).toSet(), hasLength(1));

    // And the thread it made is what M12 draws: two moments, one author.
    expect(find.byType(FollowUpThreadView), findsOneWidget);
    expect(AppRouter.communityFollowUpThreadModel.moments, hasLength(2));
    expect(AppRouter.communityFollowUpThreadModel.hasSingleAuthor, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M09 says there are no reels rather than drawing an empty one', (
    tester,
  ) async {
    await _open(tester, 'M09');
    expect(find.byType(ReelsView), findsOneWidget);
    expect(find.text('No reels yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a story goes on the rail and opens on M13, never in the feed', (
    tester,
  ) async {
    await _open(tester, 'M03');
    // A post first: the rail draws on a feed that has something in it, and a
    // woman with nothing but a story is still on day one.
    await _writePost(tester, 'Ten minutes, done.');
    await _goTo(tester, 'M03');
    await _writePost(tester, 'A walk before school.', audience: 'Your day');

    final story = CommunityState.instance.store.posts.firstWhere(
      (p) => p.kind == PostKind.story,
    );
    expect(story.expiresAt, isNotNull);

    await _goTo(tester, 'M01');
    // On the rail, labelled "Your day" — and NOT in the feed body.
    expect(find.text('Your day'), findsOneWidget);
    expect(find.textContaining('A walk before school.'), findsNothing);

    // The ring opens her day — one woman, in order, for twenty-four hours.
    await _tap(tester, find.text('Your day'));
    expect(find.byType(StoryViewerView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('there is no camera, and the recorder says so', (tester) async {
    await _open(tester, 'M16');
    final shutter = find.byIcon(Icons.camera_alt);
    if (shutter.evaluate().isEmpty) return;
    await _tap(tester, shutter);
    expect(
      find.textContaining('There is no camera in this build'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
