import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/training/prescribed_set.dart' show LoggedSet;
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/private_coaching/domain/chat_message.dart';
import 'package:own_hub/features/private_coaching/domain/check_in.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_logic.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_thread_view.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/check_in_view.dart';
import 'package:own_hub/ui/app_button.dart';

import '../../../helpers/control_counter.dart';
import '../../../helpers/primary_actions.dart';
import 'chat_support.dart';

const ChatPerson _coach = ChatPerson(
  uid: 'c1',
  name: 'Coach Sara',
  subtitle: 'Your coach',
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  tearDown(() {
    CheckIns.override = null;
    CheckIns.answeredThisSession.clear();
  });

  test(
    'the coach\'s list row carries the latest answers the server returned',
    () {
      final row = attentionRowFromWire(<Object?, Object?>{
        'subId': 's1',
        'relId': 'c__u',
        'clientName': 'Aya',
        'reasons': <Object?>['healthFlag'],
        'checkIn': <Object?, Object?>{
          'weekKey': '2026-W44',
          'answers': <Object?, Object?>{
            'training': 'some',
            'energy': 2,
            'food': 3,
            'pain': true,
            'note': '  my knee hurts when I squat ',
          },
        },
      });
      expect(row.pain, isTrue);
      expect(row.note, 'my knee hurts when I squat');
      expect(row.reasons, <String>['healthFlag']);

      final bare = attentionRowFromWire(<Object?, Object?>{
        'subId': 's2',
        'relId': 'c__v',
        'reasons': <Object?>['unread'],
      });
      expect(bare.pain, isFalse);
      expect(bare.note, isEmpty);
      expect(bare.clientName, isEmpty);
    },
  );

  testWidgets('Send stays off until the four questions are answered', (
    tester,
  ) async {
    _phone(tester);
    final store = InMemoryCheckInStore();
    await tester.pumpWidget(
      app(CheckInView(relId: 'r', weekKey: '2026-W44', store: store)),
    );

    expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNull);

    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.tap(find.text('4').first);
    await tester.pump();
    await tester.tap(find.text('3').last);
    await tester.pump();

    expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNull);

    await tester.tap(find.text('No'));
    await tester.pump();

    expect(
      tester.widget<AppButton>(find.byType(AppButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('a full answer sends the right values once', (tester) async {
    _phone(tester);
    final store = InMemoryCheckInStore();
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => CheckInView(
                    relId: 'r',
                    weekKey: '2026-W44',
                    store: store,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.tap(find.text('4').first);
    await tester.pump();
    await tester.tap(find.text('3').last);
    await tester.pump();
    await tester.tap(find.text('Yes'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'knee');
    await tester.pump();

    await tester.ensureVisible(find.text('Send to my coach'));
    await tester.tap(find.text('Send to my coach'));
    await tester.pumpAndSettle();

    final sent = store.sent.single;
    expect(sent.training, TrainingAnswer.all);
    expect(sent.energy, 4);
    expect(sent.food, 3);
    expect(sent.pain, isTrue);
    expect(sent.note, 'knee');
    expect(find.byType(CheckInView), findsNothing);
  });

  testWidgets('pain Yes shows the doctor line', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      app(
        CheckInView(
          relId: 'r',
          weekKey: '2026-W44',
          store: InMemoryCheckInStore(),
        ),
      ),
    );
    const doctorLine =
        'Tell your coach more below if you like. If it is sharp or getting worse, please see a doctor.';

    expect(find.text(doctorLine), findsNothing);
    await tester.tap(find.text('Yes'));
    await tester.pump();
    expect(find.text(doctorLine), findsOneWidget);

    await tester.tap(find.text('No'));
    await tester.pump();
    expect(find.text(doctorLine), findsNothing);
  });

  testWidgets(
    'a refused or repeated send is said in words and keeps the answers',
    (tester) async {
      _phone(tester);
      final store = InMemoryCheckInStore()..result = CheckInResult.failed;
      await tester.pumpWidget(
        app(CheckInView(relId: 'r', weekKey: '2026-W44', store: store)),
      );

      await tester.tap(find.text('All'));
      await tester.pump();
      await tester.tap(find.text('4').first);
      await tester.pump();
      await tester.tap(find.text('3').last);
      await tester.pump();
      await tester.tap(find.text('No'));
      await tester.pump();

      await tester.ensureVisible(find.text('Send to my coach'));
      await tester.tap(find.text('Send to my coach'));
      await tester.pump();

      expect(
        find.text('We could not send it. Try again in a moment.'),
        findsOneWidget,
      );
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNotNull,
      );

      store.result = CheckInResult.alreadySent;
      await tester.ensureVisible(find.text('Send to my coach'));
      await tester.tap(find.text('Send to my coach'));
      await tester.pump();

      expect(find.text('You already sent this one.'), findsOneWidget);
    },
  );

  testWidgets('Arabic and 2.0 text scale fit', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      app(
        CheckInView(
          relId: 'r',
          weekKey: '2026-W44',
          store: InMemoryCheckInStore(),
        ),
        locale: const Locale('ar'),
        scale: 2.0,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('ابعتي لمدرّبتك'), findsOneWidget);
  });

  testWidgets(
    'the thread draws the card for the client and a pill for the coach',
    (tester) async {
      _phone(tester);
      final checkInMsg = ChatMessage(
        id: 'm1',
        senderUid: 'system',
        type: MessageType.system,
        systemKind: SystemMessageKind.checkIn,
        weekKey: '2026-W44',
        createdAt: kClock,
      );

      final clientRepo = FakeChatRepository()
        ..current = <ChatMessage>[checkInMsg];
      await tester.pumpWidget(
        app(
          ChatThreadView(
            repository: clientRepo,
            relId: 'c1__me',
            myUid: 'me',
            person: _coach,
            otherIsCoach: true,
            subId: 'sub1',
            now: () => kClock,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Answer'), findsOneWidget);

      final coachRepo = FakeChatRepository()
        ..current = <ChatMessage>[checkInMsg];
      await tester.pumpWidget(
        app(
          ChatThreadView(
            repository: coachRepo,
            relId: 'c1__me',
            myUid: 'c1',
            person: _coach,
            otherIsCoach: false,
            subId: 'sub1',
            now: () => kClock,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Weekly check-in sent'), findsOneWidget);
      expect(find.text('Answer'), findsNothing);
    },
  );

  testWidgets('form budget', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      app(
        CheckInView(
          relId: 'r',
          weekKey: '2026-W44',
          store: InMemoryCheckInStore(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.tap(find.text('4').first);
    await tester.pump();
    await tester.tap(find.text('3').last);
    await tester.pump();
    await tester.tap(find.text('No'));
    await tester.pump();

    final primaries = filledPrimaryActions(tester);
    final backButtons = find.byType(IconButton).evaluate().length;
    final others =
        countControlsAboveFold(tester, includeChrome: false) -
        primaries -
        backButtons;
    expect(primaries, 1);
    // 5 until the optional weight field joined the form (Phase 5, owner request).
    expect(others, lessThanOrEqualTo(6));
  });

  test('a weight is read from Arabic digits and a comma, to one decimal, within bounds', () {
    expect(parseCheckInWeight('61.46'), 61.5);
    expect(parseCheckInWeight(' 61,4 '), 61.4);
    expect(parseCheckInWeight('٦١٫٥'), 61.5);
    expect(parseCheckInWeight('30'), 30);
    expect(parseCheckInWeight('300'), 300);
    expect(parseCheckInWeight('29.9'), isNull);
    expect(parseCheckInWeight('300.1'), isNull);
    expect(parseCheckInWeight('abc'), isNull);
    expect(parseCheckInWeight(''), isNull);
    expect(parseCheckInWeight('NaN'), isNull);
    expect(parseCheckInWeight('Infinity'), isNull);
  });

  test('only finished sessions of the coach plan in that week are counted', () {
    TrainSession session(
      String id,
      String day, {
      String? plan = 'coach_plan@3',
      bool completed = true,
      EndedReason? ended = EndedReason.finished,
    }) => TrainSession(
      id: id,
      source: SessionSource.live,
      dateKey: day,
      sets: const <LoggedSet>[],
      planVersion: plan,
      completed: completed,
      endedReason: ended,
    );
    final history = <TrainSession>[
      session('a', '2026-10-26'), // Monday of 2026-W44
      session('b', '2026-11-01'), // Sunday of the same week
      session('c', '2026-11-02'), // the next week
      session('d', '2026-10-27', plan: 'full_body@1'), // her own split
      session('e', '2026-10-28', plan: null),
      session('f', '2026-10-29', completed: false),
      session('g', '2026-10-30', ended: EndedReason.abandoned),
    ];
    expect(coachWorkoutsInWeek(history, '2026-W44'), 2);
    expect(coachWorkoutsInWeek(history, '2026-W45'), 1);
    expect(coachWorkoutsInWeek(history, '2026-W43'), 0);
    expect(coachWorkoutsInWeek(const <TrainSession>[], '2026-W44'), 0);
  });

  test('the wire carries weight and workouts only when they are set', () {
    const plain = CheckInAnswers(
      training: TrainingAnswer.all,
      energy: 3,
      food: 3,
      pain: false,
    );
    expect(plain.toWire().keys, isNot(contains('weightKg')));
    expect(plain.toWire().keys, isNot(contains('workoutsDone')));
    const shared = CheckInAnswers(
      training: TrainingAnswer.all,
      energy: 3,
      food: 3,
      pain: false,
      weightKg: 61.5,
      workoutsDone: 3,
    );
    expect(shared.toWire()['weightKg'], 61.5);
    expect(shared.toWire()['workoutsDone'], 3);
    expect(shared.toWire()['weightConsent'], isTrue);
    expect(plain.toWire().keys, isNot(contains('weightConsent')));
  });

  Future<void> answerAll(WidgetTester tester) async {
    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.tap(find.text('4').first);
    await tester.pump();
    await tester.tap(find.text('3').last);
    await tester.pump();
    await tester.tap(find.text('No'));
    await tester.pump();
  }

  testWidgets('her weight and the workout count go only with her tick', (
    tester,
  ) async {
    _phone(tester);
    final store = InMemoryCheckInStore();
    await tester.pumpWidget(
      app(
        CheckInView(
          relId: 'r',
          weekKey: '2026-W44',
          store: store,
          workoutsDone: 3,
        ),
      ),
    );
    expect(
      find.text("Workouts from your coach's plan this week: 3"),
      findsOneWidget,
    );
    expect(find.text('Share my weight with my coach'), findsNothing);
    await answerAll(tester);

    await tester.enterText(
      find.byKey(const ValueKey('check-in-weight')),
      '61,46',
    );
    await tester.pump();
    // The tick appears once there is a weight, and starts off.
    expect(find.text('Share my weight with my coach'), findsOneWidget);

    await tester.ensureVisible(find.text('Send to my coach'));
    await tester.tap(find.text('Send to my coach'));
    await tester.pumpAndSettle();
    expect(store.sent.single.weightKg, isNull);
    expect(store.sent.single.workoutsDone, isNull);
  });

  testWidgets('with both ticks set the weight and the count are sent', (
    tester,
  ) async {
    _phone(tester);
    final store = InMemoryCheckInStore();
    await tester.pumpWidget(
      app(
        CheckInView(
          relId: 'r',
          weekKey: '2026-W44',
          store: store,
          workoutsDone: 0,
        ),
      ),
    );
    await answerAll(tester);
    await tester.enterText(
      find.byKey(const ValueKey('check-in-weight')),
      '61.46',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Share my weight with my coach'));
    await tester.tap(find.text('Share my weight with my coach'));
    await tester.pump();
    await tester.ensureVisible(find.text('Share the workouts I finished this week'));
    await tester.tap(find.text('Share the workouts I finished this week'));
    await tester.pump();

    await tester.ensureVisible(find.text('Send to my coach'));
    await tester.tap(find.text('Send to my coach'));
    await tester.pumpAndSettle();
    expect(store.sent.single.weightKg, 61.5);
    expect(store.sent.single.workoutsDone, 0);
  });

  testWidgets('a weight outside the limits blocks Send once she shares it', (
    tester,
  ) async {
    _phone(tester);
    final store = InMemoryCheckInStore();
    await tester.pumpWidget(
      app(CheckInView(relId: 'r', weekKey: '2026-W44', store: store)),
    );
    await answerAll(tester);
    await tester.enterText(find.byKey(const ValueKey('check-in-weight')), '12');
    await tester.pump();
    await tester.ensureVisible(find.text('Share my weight with my coach'));
    await tester.tap(find.text('Share my weight with my coach'));
    await tester.pump();

    expect(
      find.text('Enter a weight between 30 and 300 kilograms.'),
      findsOneWidget,
    );
    expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('check-in-weight')), '58');
    await tester.pump();
    expect(
      tester.widget<AppButton>(find.byType(AppButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('without a coach plan the workout row is not there', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      app(
        CheckInView(
          relId: 'r',
          weekKey: '2026-W44',
          store: InMemoryCheckInStore(),
        ),
      ),
    );
    expect(find.text('Share the workouts I finished this week'), findsNothing);
  });

  testWidgets('a note the server refuses for a phone number is said next to it and kept', (
    tester,
  ) async {
    _phone(tester);
    final store = InMemoryCheckInStore()..result = CheckInResult.containsContact;
    await tester.pumpWidget(
      app(CheckInView(relId: 'r', weekKey: '2026-W44', store: store)),
    );
    await answerAll(tester);
    await tester.enterText(find.byType(TextField).first, 'call 0100');
    await tester.ensureVisible(find.text('Send to my coach'));
    await tester.tap(find.text('Send to my coach'));
    await tester.pumpAndSettle();

    expect(find.textContaining("can't include phone numbers"), findsOneWidget);
    expect(find.text('We could not send it. Try again in a moment.'), findsNothing);
    expect(find.text('call 0100'), findsOneWidget);
    expect(find.byType(CheckInView), findsOneWidget);
  });

  test('the workout count never goes over what the server takes', () {
    final many = <TrainSession>[
      for (var i = 0; i < 20; i++)
        TrainSession(
          id: 's$i',
          source: SessionSource.live,
          dateKey: '2026-10-27',
          sets: const <LoggedSet>[],
          planVersion: 'coach_plan@1',
          completed: true,
          endedReason: EndedReason.finished,
        ),
    ];
    expect(coachWorkoutsInWeek(many, '2026-W44'), 14);
  });
}
