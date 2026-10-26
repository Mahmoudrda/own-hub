import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/data/saved_reply_store.dart';
import 'package:own_hub/features/private_coaching/domain/chat_screen.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_logic.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_thread_view.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/saved_replies_sheet.dart';
import 'package:own_hub/l10n/app_l10n_ar.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_support.dart';

const ChatPerson _client = ChatPerson(
  uid: 'cl1',
  name: 'Client #1234',
  subtitle: 'Active',
);

Future<(FakeChatRepository, SavedReplyStore)> _coachThread(
  WidgetTester tester, {
  List<String> starters = const ['Hello there'],
  bool otherIsCoach = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final store = SavedReplyStore(prefs: prefs);
  final repo = FakeChatRepository();
  await tester.pumpWidget(
    app(
      ChatThreadView(
        repository: repo,
        relId: 'me__cl1',
        myUid: 'me',
        person: _client,
        otherIsCoach: otherIsCoach,
        subId: 'sub1',
        savedReplyStore: store,
        starterReplies: starters,
        now: () => kClock,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (repo, store);
}

void main() {
  test('the first load copies the starters and stores them', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final s = SavedReplyStore();
    final a = await s.load('c1', ['x', 'y']);
    expect(a.map((r) => r.text).toList(), ['x', 'y']);
    final b = await s.load('c1', ['other']);
    expect(b.map((r) => r.text).toList(), ['x', 'y']);
  });

  test('a deleted starter list stays empty', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final s = SavedReplyStore();
    await s.save('c1', const <SavedReply>[]);
    final a = await s.load('c1', ['x']);
    expect(a, isEmpty);
  });

  test('lists are per coach', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final s = SavedReplyStore();
    await s.save('c1', const [SavedReply(id: '1', text: 'Hi')]);
    final a = await s.load('c2', const <String>[]);
    expect(a, isEmpty);
  });

  test('a broken value reads as empty', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'savedReplies.v1.c1': 'not json',
    });
    final s = SavedReplyStore();
    final a = await s.load('c1', ['x']);
    expect(a, isEmpty);
  });

  test('every starter passes the chat screen', () {
    final en = starterRepliesOf(AppL10nEn());
    final ar = starterRepliesOf(AppL10nAr());
    expect(en.length, 10);
    expect(ar.length, 10);
    for (final text in [...en, ...ar]) {
      expect(ChatScreen.screen(text), isNull, reason: text);
      expect(text.length, lessThanOrEqualTo(kSavedReplyChars), reason: text);
    }
  });

  testWidgets('tapping a reply puts it in the box, not sent', (tester) async {
    final (repo, _) = await _coachThread(tester, starters: ['Hello there']);
    await tester.tap(find.byTooltip('Share something'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello there'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Hello there');
    expect(repo.count('sendText'), 0);
  });

  testWidgets('a reply is added after existing text with a space', (
    tester,
  ) async {
    await _coachThread(tester, starters: ['Hello there']);
    await tester.enterText(find.byType(TextField), 'Hi');
    await tester.pump();
    await tester.tap(find.byTooltip('Share something'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello there'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Hi Hello there');
  });

  testWidgets('add, edit and delete take two taps to the editor', (
    tester,
  ) async {
    await _coachThread(tester, starters: const <String>[]);
    await tester.tap(find.byTooltip('Share something'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a reply'));
    await tester.pumpAndSettle();
    expect(find.text('New reply'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Well done');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share something'));
    await tester.pumpAndSettle();
    expect(find.text('Well done'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit reply'));
    await tester.pumpAndSettle();
    expect(find.text('Edit reply'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share something'));
    await tester.pumpAndSettle();
    expect(find.text('Well done'), findsNothing);
  });

  testWidgets('the editor refuses a phone number', (tester) async {
    final (_, store) = await _coachThread(tester, starters: const <String>[]);
    await tester.tap(find.byTooltip('Share something'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a reply'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'call 01012345678');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text(AppL10nEn().phoneNumbersCantBeSentInThe),
      findsOneWidget,
    );
    expect(await store.load('me', const <String>[]), isEmpty);
  });

  testWidgets('a client has no saved replies', (tester) async {
    await _coachThread(
      tester,
      otherIsCoach: true,
      starters: ['Hello there'],
    );
    await tester.tap(find.byTooltip('Share something'));
    await tester.pumpAndSettle();
    expect(find.text('Saved replies'), findsNothing);
  });
}
