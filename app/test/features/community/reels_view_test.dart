// M09 — Reels, and the fact that at launch there are none.
//
// The launch scope is photos and text. So the first thing this file proves is a
// negative: with `communityVideo` off there is no player, no camera and no
// sentence promising one later — and the absence comes from the flag, because
// switching it on brings the whole surface back in the very next test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/community/domain/audience_keys.dart';
import 'package:own_hub/features/community/domain/community_models.dart';
import 'package:own_hub/features/community/presentation/community_widgets.dart';
import 'package:own_hub/features/community/presentation/create_view_model.dart';
import 'package:own_hub/features/community/presentation/feed_view_model.dart';
import 'package:own_hub/features/community/presentation/reels_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_media.dart';
import 'package:own_hub/ui/app_scaffold.dart';

/// Community on, at its launch scope: photos and text.
///
/// Built from [FeatureFlags.allOff] rather than from `FeatureFlags.shipped`,
/// so every absence asserted below is an absence this file asked for. Borrowing
/// the defaults would make each of these a test of today's switch positions.
final _communityOn = FeatureFlags.allOff.with_(<Feature, bool>{
  Feature.community: true,
  Feature.communityPosts: true,
});
final _videoOn = _communityOn.with_(<Feature, bool>{
  Feature.communityVideo: true,
});

const _sara = AuthorCard(uid: 'sara', name: 'Sara Hany');
final _now = DateTime(2026, 7, 3);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: child,
  );
}

CommunityPost _reel() => CommunityPost(
  postId: 'r1',
  authorCard: _sara,
  kind: PostKind.reel,
  audienceKeys: AudienceKeys.forAuthor(_sara.uid),
  createdAt: _now,
  media: <PostMedia>[
    const PostMedia(
      mediaId: 'm1',
      url: 'x',
      thumbUrl: 'x',
      width: 1080,
      height: 1920,
    ),
  ],
  caption: 'Three floor moves for a flat with thin walls.',
  likeCount: 2140,
  commentCount: 86,
);

PostCardModel _card() => PostCardModel.from(_reel(), viewerUid: 'me');

/// Every string the widget tree is currently rendering.
List<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((s) => s.isNotEmpty)
    .toList();

void main() {
  group('video is off, so nothing video exists on this screen', () {
    testWidgets('the ordinary not-available panel, and no player', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(ReelsView(model: ReelsScreenModel.from(flags: _communityOn))),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NotAvailablePanel), findsOneWidget);
      expect(
        find.byType(BlurredShot),
        findsNothing,
        reason: 'no media surface while the capability is switched off',
      );
      expect(find.byType(AppMedia), findsNothing);
    });

    testWidgets('no camera, no videocam and no play control', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(ReelsView(model: ReelsScreenModel.from(flags: _communityOn))),
      );
      await tester.pumpAndSettle();

      for (final icon in <IconData>[
        Icons.photo_camera_outlined,
        Icons.videocam,
        Icons.videocam_outlined,
        Icons.play_arrow,
        Icons.play_circle_fill,
      ]) {
        expect(
          find.byIcon(icon),
          findsNothing,
          reason:
              'an entry point to recording on a screen whose capability is '
              'off is a control that cannot succeed',
        );
      }
    });

    testWidgets('nothing promises that video is coming', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(ReelsView(model: ReelsScreenModel.from(flags: _communityOn))),
      );
      await tester.pumpAndSettle();

      // The body draws its icon alone: no "coming soon", no explanation of a
      // flag, and no sentence the dictionary never minted. The screen's only
      // copy is its title and the tab bar.
      expect(
        tester.widgetList<Text>(
          find.descendant(
            of: find.byType(AppScaffold),
            matching: find.byType(Text),
          ),
        ),
        isEmpty,
      );
      expect(
        find.textContaining(RegExp('soon', caseSensitive: false)),
        findsNothing,
      );
    });
  });

  group('the flag is what decides, so switching it on brings it back', () {
    testWidgets('the player, the rail and the camera all return', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          ReelsView(
            model: ReelsScreenModel.from(
              flags: _videoOn,
              reels: <CommunityPost>[_reel()],
            ),
            posts: <PostCardModel>[_card()],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NotAvailablePanel), findsNothing);
      expect(find.byType(BlurredShot), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
      expect(find.text('Sara Hany'), findsOneWidget);
    });

    testWidgets('an empty reel list is not the not-available rendering', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(ReelsView(model: ReelsScreenModel.from(flags: _videoOn))),
      );
      await tester.pumpAndSettle();

      // "No reels yet" is not in the dictionary, so the panel draws its icon
      // alone — but it is a different icon from unavailable, because empty and
      // unavailable are different facts.
      expect(find.byType(NotAvailablePanel), findsNothing);
      expect(find.byIcon(Icons.videocam_off_outlined), findsOneWidget);
    });
  });

  group('her figures, and nobody ranked', () {
    testWidgets('likes and comments are Western digits in both languages', (
      tester,
    ) async {
      for (final locale in <Locale>[Locale('en'), Locale('ar')]) {
        _phone(tester);
        await tester.pumpWidget(
          _host(
            ReelsView(
              model: ReelsScreenModel.from(
                flags: _videoOn,
                reels: <CommunityPost>[_reel()],
              ),
              posts: <PostCardModel>[_card()],
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('2,140'),
          findsOneWidget,
          reason: 'Western digits in Arabic too — never NumberFormat',
        );
        expect(find.text('86'), findsOneWidget);
      }
    });

    testWidgets('no follower count renders anywhere', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          ReelsView(
            model: ReelsScreenModel.from(
              flags: _videoOn,
              reels: <CommunityPost>[_reel()],
            ),
            posts: <PostCardModel>[_card()],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(RegExp('followers', caseSensitive: false)),
        findsNothing,
        reason: 'communityFollowerCounts is off, and nothing here ranks women',
      );
      // The follow control is a state, not a figure.
      expect(find.byType(FollowPill), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
    });

    testWidgets('tapping the like count likes, it does not open a roster', (
      tester,
    ) async {
      _phone(tester);
      var liked = 0;
      String? opened;
      await tester.pumpWidget(
        _host(
          ReelsView(
            model: ReelsScreenModel.from(
              flags: _videoOn,
              reels: <CommunityPost>[_reel()],
            ),
            posts: <PostCardModel>[_card()],
            onLike: (_) => liked++,
            onOpenComments: (id) => opened = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('2,140'));
      await tester.pumpAndSettle();

      expect(liked, 1);
      expect(opened, isNull, reason: 'there is no "who liked this"');
      // Rule 9: like raises nothing.
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('offline, and no voice', () {
    testWidgets('offline is an explicit state, never cached media', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          ReelsView(
            model: ReelsScreenModel.from(
              flags: _videoOn,
              reels: <CommunityPost>[_reel()],
            ),
            posts: <PostCardModel>[_card()],
            online: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waiting for signal'), findsOneWidget);
      expect(
        find.byType(BlurredShot),
        findsNothing,
        reason:
            'community media is never downloaded for offline — it is other '
            "women's bodies",
      );
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'a spinner over media that is never coming is a lie',
      );
    });

    testWidgets('no microphone and no audio duration', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          ReelsView(
            model: ReelsScreenModel.from(
              flags: _videoOn,
              reels: <CommunityPost>[_reel()],
            ),
            posts: <PostCardModel>[_card()],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byIcon(Icons.mic_none), findsNothing);
      // "Her voice · 0:34" states the mockup's duration about a real clip.
      expect(
        _texts(tester).where((s) => RegExp(r'\d:\d\d').hasMatch(s)),
        isEmpty,
      );
    });
  });
}
