import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('Send stays off until the four questions are answered', (
    tester,
  ) async {
    _phone(tester);
    final store = InMemoryCheckInStore();
    await tester.pumpWidget(
      app(CheckInView(relId: 'r', weekKey: '2026-W44', store: store)),
    );

    expect(
      tester.widget<AppButton>(find.byType(AppButton)).onPressed,
      isNull,
    );

    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.tap(find.text('4').first);
    await tester.pump();
    await tester.tap(find.text('3').last);
    await tester.pump();

    expect(
      tester.widget<AppButton>(find.byType(AppButton)).onPressed,
      isNull,
    );

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
    await tester.enterText(find.byType(TextField), 'knee');
    await tester.pump();

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

  testWidgets('a refused or repeated send is said in words and keeps the answers', (
    tester,
  ) async {
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
    await tester.tap(find.text('Send to my coach'));
    await tester.pump();

    expect(find.text('You already sent this one.'), findsOneWidget);
  });

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

  testWidgets('the thread draws the card for the client and a pill for the coach', (
    tester,
  ) async {
    _phone(tester);
    final checkInMsg = ChatMessage(
      id: 'm1',
      senderUid: 'system',
      type: MessageType.system,
      systemKind: SystemMessageKind.checkIn,
      weekKey: '2026-W44',
      createdAt: kClock,
    );

    final clientRepo = FakeChatRepository()..current = <ChatMessage>[checkInMsg];
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

    final coachRepo = FakeChatRepository()..current = <ChatMessage>[checkInMsg];
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
  });

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
    expect(others, lessThanOrEqualTo(5));
  });
}
