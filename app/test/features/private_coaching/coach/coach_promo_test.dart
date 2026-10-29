import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/promo_video.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_promo_card.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/own_hub_for_you_card.dart';
import 'package:own_hub/features/private_coaching/presentation/why_stay_note.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_button.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const CoachVideo _fine = CoachVideo(
  path: '/tmp/none.mp4',
  extension: 'mp4',
  seconds: 75,
  bytes: 9000000,
);

void main() {
  test('the wire reads this month and drops a row it does not know', () {
    final month = PromoMonth.fromWire(<String, Object?>{
      'month': '2026-10',
      'target': 2,
      'approved': 1,
      'items': <Object?>[
        <String, Object?>{'id': 'a', 'topic': 'training_myth', 'status': 'approved'},
        <String, Object?>{
          'id': 'b',
          'topic': 'introduction',
          'status': 'changes',
          'reason': 'Too dark.',
        },
        <String, Object?>{'id': 'c', 'status': 'mystery'},
      ],
    });
    expect(month.approved, 1);
    expect(month.done, isFalse);
    expect(month.items.map((v) => v.status), <PromoStatus>[
      PromoStatus.approved,
      PromoStatus.changes,
    ]);
    expect(month.items.last.reason, 'Too dark.');
    expect(PromoMonth.fromWire(null).target, 2);
  });

  test('a video is checked for type, size and length before anything is sent', () {
    PromoProblem? check(int s, int b, [String e = 'mp4']) =>
        promoProblem(seconds: s, bytes: b, extension: e);
    expect(check(60, 1000), isNull);
    expect(check(30, 1000, 'MOV'), isNull);
    expect(check(180, kPromoMaxBytes), isNull);
    expect(check(29, 1000), PromoProblem.tooShort);
    expect(check(181, 1000), PromoProblem.tooLong);
    expect(check(60, kPromoMaxBytes + 1), PromoProblem.tooBig);
    expect(check(60, 0), PromoProblem.tooBig);
    expect(check(60, 1000, '3gp'), PromoProblem.unsupported);
    expect(
      promoPath(uid: 'u1', token: 'abc', extension: 'MOV'),
      'coach-docs/u1/promo/abc.mov',
    );
  });

  testWidgets('the card shows the count, each video and why one needs changes', (
    tester,
  ) async {
    _phone(tester);
    final store = InMemoryPromoVideoStore(
      current: const PromoMonth(
        approved: 1,
        items: <PromoVideo>[
          PromoVideo(id: 'a', topic: PromoTopic.workoutTip, status: PromoStatus.approved),
          PromoVideo(
            id: 'b',
            topic: PromoTopic.eatingIdea,
            status: PromoStatus.changes,
            reason: 'The sound is low.',
          ),
          PromoVideo(id: 'c', topic: PromoTopic.introduction, status: PromoStatus.waiting),
        ],
      ),
    );
    await tester.pumpWidget(_host(CoachPromoCard(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Videos for Own Hub this month: 1 of 2'), findsOneWidget);
    expect(find.text('A workout or movement tip'), findsOneWidget);
    expect(find.text('Approved by Own Hub'), findsOneWidget);
    expect(find.text('Needs changes'), findsOneWidget);
    expect(find.text('Needs changes: The sound is low.'), findsOneWidget);
    expect(find.text('Waiting for Own Hub'), findsOneWidget);
    expect(find.textContaining('never on your public page'), findsOneWidget);
    expect(find.text('You are done for this month. Thank you.'), findsNothing);
    expect(
      tester.widget<AppButton>(find.byKey(const ValueKey('promo-add'))).variant,
      AppButtonVariant.tonal,
    );
  });

  testWidgets('an empty month says so, and two approved says done', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(CoachPromoCard(store: InMemoryPromoVideoStore())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Videos for Own Hub this month: 0 of 2'), findsOneWidget);
    expect(find.text('No videos yet this month.'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        CoachPromoCard(
          key: UniqueKey(),
          store: InMemoryPromoVideoStore(current: const PromoMonth(approved: 2)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('You are done for this month. Thank you.'), findsOneWidget);
  });

  testWidgets('adding a video asks for a topic, then sends it and shows it waiting', (
    tester,
  ) async {
    _phone(tester);
    final store = InMemoryPromoVideoStore();
    await tester.pumpWidget(
      _host(CoachPromoCard(store: store, videoChooser: (_) async => _fine)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('promo-add')));
    await tester.pumpAndSettle();
    expect(find.text('What is the video about?'), findsOneWidget);
    expect(find.textContaining('from 30 seconds to 3 minutes'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('promo-topic-training_myth')));
    await tester.pumpAndSettle();

    expect(store.sent, hasLength(1));
    expect(store.sent.single.topic, PromoTopic.trainingMyth);
    expect(store.sent.single.seconds, 75);
    expect(find.text('Waiting for Own Hub'), findsOneWidget);
    expect(find.text('Your video was sent. Own Hub will watch it soon.'), findsOneWidget);
  });

  testWidgets('a video that is too short, too long or too big is not sent', (
    tester,
  ) async {
    _phone(tester);
    final cases = <CoachVideo, String>{
      const CoachVideo(path: 'p', extension: 'mp4', seconds: 10, bytes: 1000):
          'The video is shorter than 30 seconds.',
      const CoachVideo(path: 'p', extension: 'mp4', seconds: 400, bytes: 1000):
          'The video is longer than 3 minutes.',
      const CoachVideo(path: 'p', extension: 'mov', seconds: 60, bytes: kPromoMaxBytes + 1):
          'That video file is too big. Try a shorter one.',
      const CoachVideo(path: 'p', extension: 'avi', seconds: 60, bytes: 1000):
          'Only videos in the usual phone format can be used.',
    };
    for (final entry in cases.entries) {
      final store = InMemoryPromoVideoStore();
      await tester.pumpWidget(
        _host(
          CoachPromoCard(
            key: UniqueKey(),
            store: store,
            videoChooser: (_) async => entry.key,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('promo-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('promo-topic-introduction')));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget, reason: entry.value);
      expect(store.sent, isEmpty);
    }
  });

  testWidgets('backing out of the picker sends nothing and the card stays usable', (
    tester,
  ) async {
    _phone(tester);
    final store = InMemoryPromoVideoStore();
    await tester.pumpWidget(
      _host(CoachPromoCard(store: store, videoChooser: (_) async => null)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('promo-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('promo-topic-workout_tip')));
    await tester.pumpAndSettle();
    expect(store.sent, isEmpty);
    expect(find.byKey(const ValueKey('promo-add')), findsOneWidget);
  });

  testWidgets('the reasons to stay and what Own Hub does read in both languages', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(const Column(children: [WhyStayNote(), OwnHubForYouCard()])),
    );
    expect(find.text('Why stay in Own Hub'), findsOneWidget);
    expect(find.text('Own Hub never shows your number to your coach.'), findsOneWidget);
    expect(find.text('Your chat with your coach is private.'), findsOneWidget);
    expect(find.text('What Own Hub does for you'), findsOneWidget);
    expect(find.text('Clients find you in Find a coach.'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        const Column(children: [WhyStayNote(), OwnHubForYouCard()]),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ليه تفضلي في Own Hub'), findsOneWidget);
    expect(find.text('Own Hub بتعمل إيه علشانك'), findsOneWidget);
  });
}
