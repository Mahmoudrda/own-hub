import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/data/saved_reply_store.dart';
import 'package:own_hub/features/private_coaching/domain/chat_message.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_logic.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_sheets.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_thread_view.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/saved_replies_sheet.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/control_counter.dart';
import 'chat_support.dart';

const ChatPerson _coach = ChatPerson(
  uid: 'c1',
  name: 'Coach Sara',
  subtitle: 'Your coach',
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<FakeChatRepository> _thread(
  WidgetTester tester, {
  List<ChatMessage>? lines,
  ShareChoices share = const ShareChoices(),
  bool otherIsCoach = true,
  SavedReplyStore? savedReplyStore,
  List<String> starterReplies = const <String>[],
}) async {
  _phone(tester);
  final r = FakeChatRepository();
  r.current = lines ?? r.current;
  await tester.pumpWidget(
    app(
      ChatThreadView(
        repository: r,
        relId: 'c1__me',
        myUid: 'me',
        person: _coach,
        otherIsCoach: otherIsCoach,
        subId: 'sub1',
        share: share,
        now: () => kClock,
        savedReplyStore: savedReplyStore,
        starterReplies: starterReplies,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return r;
}

List<ChatMessage> _sample() => [
  line('4', 'me', 'See you at six', pending: true),
  line('3', 'me', 'Done, thank you', at: DateTime(2026, 10, 24, 11, 5)),
  line('2', 'c1', 'How did the squats feel?', at: DateTime(2026, 10, 24, 11)),
  line('1', 'me', 'Hello coach', at: DateTime(2026, 10, 23, 20)),
];

void main() {
  testWidgets(
    'the thread has at most 5 controls and no filled primary, as a client',
    (tester) async {
      await _thread(tester, otherIsCoach: true, lines: _sample());
      expect(
        countControlsAboveFold(tester, includeChrome: false),
        lessThanOrEqualTo(5),
      );
      expect(find.byType(FilledButton), findsNothing);
    },
  );

  testWidgets(
    'the thread has at most 5 controls with every share on, as a coach',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await _thread(
        tester,
        otherIsCoach: false,
        lines: _sample(),
        savedReplyStore: SavedReplyStore(prefs: prefs),
        starterReplies: starterRepliesOf(AppL10nEn()),
        share: ShareChoices(
          onRecipe: () {},
          onWorkoutPlan: () {},
          onMealPlan: () {},
          onSession: () {},
        ),
      );
      expect(
        countControlsAboveFold(tester, includeChrome: false),
        lessThanOrEqualTo(5),
      );
    },
  );
}
