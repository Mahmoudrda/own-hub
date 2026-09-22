// M13 — the stories viewer.
//
// Three things this screen must not be able to do, each with a test: tell a
// woman she was blocked, show who watched, or keep another woman's picture on
// the phone for later. The fourth is the one the design note is about — the
// reply goes to her privately, so encouragement is not performed in front of a
// group.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/community/domain/audience_keys.dart';
import 'package:own_hub/features/community/domain/community_models.dart';
import 'package:own_hub/features/community/presentation/community_widgets.dart';
import 'package:own_hub/features/community/presentation/feed_view_model.dart';
import 'package:own_hub/features/community/presentation/story_viewer_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

const _nada = AuthorCard(uid: 'nada', name: 'Nada Samir');
const _me = AuthorCard(uid: 'me', name: 'Mona');
final _now = DateTime(2026, 7, 3, 9, 41);

/// Community on, at its launch scope: photos and text.
///
/// Built from [FeatureFlags.allOff] rather than from `FeatureFlags.shipped`,
/// so every absence asserted below is an absence this file asked for. Borrowing
/// the defaults would make each of these a test of today's switch positions.
final _communityOn = FeatureFlags.allOff.with_(<Feature, bool>{
  Feature.community: true,
  Feature.communityPosts: true,
});

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

CommunityPost _story({
  required String id,
  AuthorCard author = _nada,
  Duration age = const Duration(hours: 3),
}) {
  final created = _now.subtract(age);
  return CommunityPost(
    postId: id,
    authorCard: author,
    kind: PostKind.story,
    audienceKeys: AudienceKeys.forAuthor(author.uid),
    createdAt: created,
    expiresAt: created.add(const Duration(hours: 24)),
    media: <PostMedia>[
      const PostMedia(
        mediaId: 'm',
        url: 'x',
        thumbUrl: 'x',
        width: 1080,
        height: 1920,
      ),
    ],
  );
}

StoryViewerModel _model({
  List<CommunityPost>? stories,
  String viewerUid = 'me',
  String? openPostId,
  bool hiddenEitherWay = false,
  bool online = true,
}) => StoryViewerModel.from(
  stories: stories ?? <CommunityPost>[_story(id: 's1')],
  viewerUid: viewerUid,
  now: _now,
  openPostId: openPostId,
  hiddenEitherWay: hiddenEitherWay,
  online: online,
  flags: _communityOn,
);

List<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((s) => s.isNotEmpty)
    .toList();

void main() {
  group('a blocked woman cannot learn she is blocked', () {
    testWidgets('blocked renders exactly what expired renders', (tester) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(StoryViewerView(model: _model(hiddenEitherWay: true))),
      );
      await tester.pumpAndSettle();
      final blocked = _texts(tester);
      final blockedPanels = find.byType(NotAvailablePanel).evaluate().length;

      // The same woman, with no live story left — the TTL took it.
      await tester.pumpWidget(
        _host(
          StoryViewerView(
            model: _model(
              stories: <CommunityPost>[
                _story(id: 's1', age: const Duration(hours: 25)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _texts(tester),
        blocked,
        reason:
            'P0-COM-15 and a block must be one rendering. A difference here '
            'is a side channel that tells her she was blocked.',
      );
      expect(find.byType(NotAvailablePanel).evaluate().length, blockedPanels);
    });

    testWidgets('the unavailable rendering never says "blocked"', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(StoryViewerView(model: _model(hiddenEitherWay: true))),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(RegExp('block', caseSensitive: false)),
        findsNothing,
      );
      expect(find.byType(NotAvailablePanel), findsOneWidget);
      // No reply bar on a surface that is not available: offering contact
      // would say more than the panel does.
      expect(find.text('Send her something kind'), findsNothing);
    });
  });

  group('one woman, in order', () {
    testWidgets('the strip has one segment per frame', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          StoryViewerView(
            model: _model(
              stories: <CommunityPost>[
                _story(id: 's1', age: const Duration(hours: 5)),
                _story(id: 's2', age: const Duration(hours: 3)),
                _story(id: 's3', age: const Duration(hours: 1)),
              ],
              openPostId: 's2',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final strip = tester.widget<StoryProgressStrip>(
        find.byType(StoryProgressStrip),
      );
      expect(strip.frames, hasLength(3));
      expect(strip.index, 1, reason: 'opened on the ring that was tapped');
      expect(find.text('Nada Samir'), findsOneWidget);
    });

    testWidgets('another woman in the same page is not in this session', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          StoryViewerView(
            model: _model(
              stories: <CommunityPost>[
                _story(id: 's1'),
                _story(id: 'h1', author: const AuthorCard(
                  uid: 'habiba',
                  name: 'Habiba Nasr',
                )),
              ],
              openPostId: 's1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nada Samir'), findsOneWidget);
      expect(
        find.text('Habiba Nasr'),
        findsNothing,
        reason: 'a session is one woman\'s day, never a mixture',
      );
    });

    testWidgets('her own day offers no reply bar and reads "Your day"', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          StoryViewerView(
            model: _model(
              stories: <CommunityPost>[_story(id: 'mine', author: _me)],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your day'), findsOneWidget);
      expect(find.text('Send her something kind'), findsNothing);
    });
  });

  group('what this screen cannot show', () {
    testWidgets('no follower count and no viewer roster', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(StoryViewerView(model: _model())));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(RegExp('follower', caseSensitive: false)),
        findsNothing,
      );
      expect(
        find.textContaining(RegExp('view(er|ed|s)', caseSensitive: false)),
        findsNothing,
        reason: 'seen state is local sqflite, so no roster exists to draw',
      );
      expect(find.byIcon(Icons.visibility), findsNothing);
    });

    testWidgets('no video affordance and no microphone', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(StoryViewerView(model: _model())));
      await tester.pumpAndSettle();

      expect(_model().offersVideo, isFalse);
      for (final icon in <IconData>[
        Icons.play_arrow,
        Icons.play_circle_fill,
        Icons.videocam,
        Icons.mic,
        Icons.mic_none,
      ]) {
        expect(find.byIcon(icon), findsNothing);
      }
    });

    testWidgets('no time-ago figure, because none is parameterised', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(StoryViewerView(model: _model())));
      await tester.pumpAndSettle();

      expect(
        _texts(tester).where((s) => RegExp(r'\d').hasMatch(s)),
        isEmpty,
        reason:
            "the mockup's '3 hours ago' would be a figure about a real story "
            'that nobody computed',
      );
    });
  });

  group('the picture, and the reply', () {
    testWidgets('faces are blurred and the picture says so', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(StoryViewerView(model: _model())));
      await tester.pumpAndSettle();

      final shot = tester.widget<BlurredShot>(find.byType(BlurredShot));
      expect(shot.blurred, isTrue);
      expect(find.text('Faces blurred'), findsOneWidget);
    });

    testWidgets('offline draws the explicit state, never cached media', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(StoryViewerView(model: _model(online: false))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waiting for signal'), findsOneWidget);
      expect(find.byType(BlurredShot), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('the reply sends, and raises nothing', (tester) async {
      _phone(tester);
      var sent = 0;
      var liked = 0;
      await tester.pumpWidget(
        _host(
          StoryViewerView(
            model: _model(),
            onSendReply: () => sent++,
            onLike: () => liked++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Send'));
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(sent, 1);
      expect(liked, 1);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
