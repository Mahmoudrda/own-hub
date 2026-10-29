import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/check_in.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/check_in_history.dart';

import 'chat_support.dart';

CheckInCard _card(
  String week, {
  String reply = '',
  double? weight,
  int? workouts,
  String note = '',
  bool pain = false,
}) => CheckInCard(
  weekKey: week,
  reply: reply,
  answeredAt: DateTime.utc(2026, 10, 30, 9),
  answers: CheckInAnswers(
    training: TrainingAnswer.most,
    energy: 4,
    food: 3,
    pain: pain,
    note: note,
    weightKg: weight,
    workoutsDone: workouts,
  ),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  test('a week comes off the wire with the numbers she shared and the reply', () {
    final card = CheckInCard.fromWire(<String, Object?>{
      'weekKey': '2026-W44',
      'reply': 'Rest the knee.',
      'answeredAt': '2026-10-30T09:00:00+00:00',
      'answers': <String, Object?>{
        'training': 'some',
        'energy': 2,
        'food': 3,
        'pain': true,
        'note': 'sore',
        'weightKg': 61.5,
        'workoutsDone': 2,
      },
    })!;
    expect(card.answers.training, TrainingAnswer.some);
    expect(card.answers.weightKg, 61.5);
    expect(card.answers.workoutsDone, 2);
    expect(card.reply, 'Rest the knee.');
    expect(card.answeredAt, DateTime.utc(2026, 10, 30, 9));

    final plain = CheckInCard.fromWire(<String, Object?>{
      'weekKey': '2026-W43',
      'answers': <String, Object?>{'training': 'all', 'energy': 5, 'food': 5, 'pain': false},
    })!;
    expect(plain.answers.weightKg, isNull);
    expect(plain.answers.workoutsDone, isNull);
    expect(CheckInCard.fromWire(<String, Object?>{'weekKey': 'x'}), isNull);
  });

  testWidgets('the coach reads each week with the shared numbers and replies once', (
    tester,
  ) async {
    _phone(tester);
    final store = InMemoryCheckInStore()
      ..cards = <CheckInCard>[
        _card('2026-W44', weight: 61.5, workouts: 3, note: 'knee a bit sore', pain: true),
        _card('2026-W43', reply: 'Great week.'),
      ];
    await tester.pumpWidget(
      app(Scaffold(body: SingleChildScrollView(child: CheckInHistory(relId: 'r', canReply: true, store: store)))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check-in history'), findsOneWidget);
    expect(find.textContaining('Check-in of '), findsNWidgets(2));
    expect(find.textContaining('W44'), findsNothing);
    expect(find.text('Weight: 61.5 kg'), findsOneWidget);
    expect(find.text('Workouts from the plan: 3'), findsOneWidget);
    expect(find.text('Pain or injury: Yes'), findsOneWidget);
    expect(find.text('knee a bit sore'), findsOneWidget);
    // The week that has a reply shows it and offers no second one.
    expect(find.byKey(const ValueKey('reply-2026-W43')), findsOneWidget);
    expect(find.byKey(const ValueKey('reply-send-2026-W43')), findsNothing);
    expect(find.text('Your reply'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('reply-field-2026-W44')),
      '  Rest the knee, see me Friday.  ',
    );
    await tester.tap(find.byKey(const ValueKey('reply-send-2026-W44')));
    await tester.pumpAndSettle();
    expect(store.replies.single.weekKey, '2026-W44');
    expect(store.replies.single.text, 'Rest the knee, see me Friday.');
    expect(find.text('Your reply was sent.'), findsOneWidget);
  });

  testWidgets('an empty reply is not sent and a failed one is said in words', (
    tester,
  ) async {
    _phone(tester);
    final store = InMemoryCheckInStore()
      ..cards = <CheckInCard>[_card('2026-W44')]
      ..replyOutcome = CheckInReply.failed;
    await tester.pumpWidget(
      app(Scaffold(body: SingleChildScrollView(child: CheckInHistory(relId: 'r', canReply: true, store: store)))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reply-send-2026-W44')));
    await tester.pump();
    expect(store.replies, isEmpty);
    expect(find.text('We could not send it. Try again in a moment.'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('reply-field-2026-W44')), 'Hello');
    await tester.tap(find.byKey(const ValueKey('reply-send-2026-W44')));
    await tester.pumpAndSettle();
    expect(find.text('We could not send it. Try again in a moment.'), findsOneWidget);
    expect(find.text('Your reply was sent.'), findsNothing);
  });

  testWidgets('the client sees her coach\'s reply and has nothing to reply with', (
    tester,
  ) async {
    _phone(tester);
    final store = InMemoryCheckInStore()
      ..cards = <CheckInCard>[_card('2026-W44', reply: 'Well done, rest the knee.')];
    await tester.pumpWidget(
      app(Scaffold(body: SingleChildScrollView(child: CheckInHistory(relId: 'r', canReply: false, store: store)))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your check-ins'), findsOneWidget);
    expect(find.text("Your coach's reply"), findsOneWidget);
    expect(find.text('Well done, rest the knee.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('no weeks yet says so, in Arabic too', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: CheckInHistory(relId: 'r', canReply: true, store: InMemoryCheckInStore()),
          ),
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('لسه مفيش متابعات.'), findsOneWidget);
    expect(find.text('سجل المتابعات'), findsOneWidget);
  });

  testWidgets('a reply with a phone number is refused next to the field and her text stays', (
    tester,
  ) async {
    _phone(tester);
    final store = InMemoryCheckInStore()
      ..cards = <CheckInCard>[_card('2026-W44')]
      ..replyOutcome = CheckInReply.containsContact;
    await tester.pumpWidget(
      app(Scaffold(body: SingleChildScrollView(child: CheckInHistory(relId: 'r', canReply: true, store: store)))),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('reply-field-2026-W44')), 'call 0100');
    await tester.tap(find.byKey(const ValueKey('reply-send-2026-W44')));
    await tester.pumpAndSettle();

    expect(find.textContaining("can't include phone numbers"), findsOneWidget);
    expect(find.text('We could not send it. Try again in a moment.'), findsNothing);
    expect(find.text('call 0100'), findsOneWidget);

    // Editing clears the refusal; a plain failure still says try again.
    await tester.enterText(find.byKey(const ValueKey('reply-field-2026-W44')), 'call');
    await tester.pump();
    expect(find.textContaining("can't include phone numbers"), findsNothing);
    store.replyOutcome = CheckInReply.failed;
    await tester.tap(find.byKey(const ValueKey('reply-send-2026-W44')));
    await tester.pumpAndSettle();
    expect(find.text('We could not send it. Try again in a moment.'), findsOneWidget);
  });
}
