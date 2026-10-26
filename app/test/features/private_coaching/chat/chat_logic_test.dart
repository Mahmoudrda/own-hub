import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/chat_message.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_logic.dart';

import 'chat_support.dart';

void main() {
  group('ticks', () {
    final other = DateTime(2026, 10, 24, 13);

    test('a line waiting in the local cache shows the clock', () {
      expect(
        tickOf(line('a', 'me', 'x', pending: true), null),
        ChatTick.pending,
      );
    });

    test('a line stored on the server shows one tick', () {
      expect(tickOf(line('a', 'me', 'x'), null), ChatTick.sent);
      expect(
        tickOf(line('a', 'me', 'x'), DateTime(2026, 10, 24, 11)),
        ChatTick.sent,
      );
    });

    test('two ticks only when her read marker is later than the line', () {
      expect(tickOf(line('a', 'me', 'x'), other), ChatTick.read);
      expect(tickOf(line('a', 'me', 'x'), kClock), ChatTick.sent);
    });

    test('pending wins over a read marker', () {
      expect(
        tickOf(line('a', 'me', 'x', pending: true), other),
        ChatTick.pending,
      );
    });
  });

  group('day separators and tails', () {
    test('a separator sits above the oldest line of each day', () {
      final newestFirst = [
        line('3', 'c1', 'c', at: DateTime(2026, 10, 24, 12)),
        line('2', 'me', 'b', at: DateTime(2026, 10, 24, 9)),
        line('1', 'c1', 'a', at: DateTime(2026, 10, 23, 20)),
      ];
      final items = buildItems(newestFirst, myUid: 'me', now: kClock);
      expect(items.map((i) => i.runtimeType.toString()).toList(), [
        'LineItem',
        'LineItem',
        'DayItem',
        'LineItem',
        'DayItem',
      ]);
      expect((items[2] as DayItem).at, DateTime(2026, 10, 24, 9));
      expect((items[4] as DayItem).at, DateTime(2026, 10, 23, 20));
    });

    test('the tail goes on the first line of a run from one sender', () {
      final items = buildItems(
        [
          line('3', 'me', 'c', at: DateTime(2026, 10, 24, 12, 2)),
          line('2', 'me', 'b', at: DateTime(2026, 10, 24, 12, 1)),
          line('1', 'c1', 'a', at: DateTime(2026, 10, 24, 12)),
        ],
        myUid: 'me',
        now: kClock,
      ).whereType<LineItem>().toList();
      expect(items.map((i) => i.tail).toList(), [false, true, true]);
      expect(items.map((i) => i.mine).toList(), [true, true, false]);
    });

    test('a pending line counts as today', () {
      final items = buildItems(
        [
          line('2', 'me', 'b', pending: true),
          line('1', 'c1', 'a', at: DateTime(2026, 10, 23, 20)),
        ],
        myUid: 'me',
        now: kClock,
      );
      expect(items.whereType<DayItem>().length, 2);
    });
  });

  group('merging', () {
    test('a line in the live list and an older page is kept once', () {
      final live = [
        line('b', 'c1', 'b', at: DateTime(2026, 10, 24, 11)),
        line('a', 'c1', 'a', at: DateTime(2026, 10, 24, 10)),
      ];
      final older = [
        line('a', 'c1', 'a', at: DateTime(2026, 10, 24, 10)),
        line('z', 'c1', 'z', at: DateTime(2026, 10, 23)),
      ];
      expect(mergeLines(live, older).map((m) => m.id).toList(), [
        'b',
        'a',
        'z',
      ]);
    });

    test('lines the server has not stamped lead', () {
      final live = [line('p', 'me', 'p', pending: true), line('a', 'c1', 'a')];
      expect(mergeLines(live, const []).first.id, 'p');
    });

    test(
      'the server\'s own hidden line is dropped beside the hidden message',
      () {
        final live = [
          line(
            'hidden_m1',
            'me',
            '',
            type: MessageType.system,
            systemKind: SystemMessageKind.hidden,
          ),
          line('m1', 'me', 'x', hidden: true),
        ];
        expect(mergeLines(live, const []).map((m) => m.id).toList(), ['m1']);
      },
    );
  });

  group('previews', () {
    final en = l10nFor('en');
    final ar = l10nFor('ar');
    LastMessage last(
      String text, {
      MessageType type = MessageType.text,
      String by = 'c1',
    }) => LastMessage(text: text, type: type, senderUid: by);

    test('her own text gets You: in front, the other\'s does not', () {
      expect(
        previewOf(en, last('See you at 6', by: 'me'), 'me'),
        'You: See you at 6',
      );
      expect(previewOf(en, last('See you at 6'), 'me'), 'See you at 6');
    });

    test('new lines are folded into one', () {
      expect(previewOf(en, last('a\n\n  b'), 'me'), 'a b');
    });

    test('a hidden last line (no words) says so', () {
      expect(previewOf(en, last(''), 'me'), 'Message hidden');
    });

    test('shared items are named, not shown', () {
      expect(previewOf(en, last('', type: MessageType.recipe), 'me'), 'Recipe');
      expect(
        previewOf(en, last('', type: MessageType.workoutPlan, by: 'me'), 'me'),
        'You: Workout plan',
      );
      expect(
        previewOf(en, last('', type: MessageType.mealPlan), 'me'),
        'Meal plan',
      );
      expect(
        previewOf(en, last('', type: MessageType.session), 'me'),
        'Live session',
      );
    });

    test('a system line never gets You:', () {
      expect(
        previewOf(en, last('', type: MessageType.system, by: 'me'), 'me'),
        'New activity in the chat',
      );
    });

    test('Arabic uses its own words', () {
      expect(previewOf(ar, last('', type: MessageType.recipe), 'me'), 'وصفة');
      expect(previewOf(ar, last('تمام', by: 'me'), 'me'), 'إنتِ: تمام');
    });
  });

  group('times', () {
    final en = l10nFor('en');
    final ar = l10nFor('ar');

    test('today shows the clock with Western digits in both languages', () {
      final at = DateTime(2026, 10, 24, 15, 5);
      expect(listTimeLabel(en, at, kClock), '15:05');
      expect(listTimeLabel(ar, at, kClock), '3:05 ${ar.pm}');
    });

    test('yesterday, a weekday in the last week, then the date', () {
      expect(
        listTimeLabel(en, DateTime(2026, 10, 23, 22), kClock),
        'Yesterday',
      );
      expect(listTimeLabel(en, DateTime(2026, 10, 21, 9), kClock), 'Wednesday');
      expect(
        listTimeLabel(en, DateTime(2026, 9, 2, 9), kClock),
        '2 September 2026',
      );
      expect(listTimeLabel(ar, DateTime(2026, 9, 2, 9), kClock), contains('2'));
      expect(
        RegExp(r'[٠-٩]')
            .hasMatch(listTimeLabel(ar, DateTime(2026, 9, 2, 9), kClock)),
        isFalse,
      );
    });

    test('a week ago is a date, not the same weekday again', () {
      expect(
        dayLabel(en, DateTime(2026, 10, 17, 9), kClock),
        '17 October 2026',
      );
    });
  });

  group('thread rows', () {
    test('built from the relationship alone, newest first', () {
      final a = ChatThread.of(
        rel(
          id: 'a',
          last: LastMessage(
            text: 'x',
            senderUid: 'c1',
            at: DateTime(2026, 10, 24, 10),
          ),
          unread: {'me': 2},
        ),
        'me',
      );
      final b = ChatThread.of(
        rel(
          id: 'b',
          last: LastMessage(
            text: 'y',
            senderUid: 'c1',
            at: DateTime(2026, 10, 24, 11),
          ),
        ),
        'me',
      );
      final none = ChatThread.of(rel(id: 'c'), 'me');
      final sorted = [none, a, b]..sort(ChatThread.newestFirst);
      expect(sorted.map((t) => t.relId).toList(), ['b', 'a', 'c']);
      expect(a.unread, 2);
      expect(a.otherUid, 'c1');
      expect(ChatThread.of(rel(open: false), 'me').open, isFalse);
      expect(
        ChatThread.of(rel(status: RelationshipStatus.ended), 'me').open,
        isFalse,
      );
    });
  });

  test('a media line parses', () {
    final m = ChatMessage.fromMap('m', {
      'senderUid': 'u',
      'type': 'audio',
      'mediaPath': 'chat-media/a__b/u/x.m4a',
      'durationMs': 4000,
      'bytes': 900,
    });
    expect(m?.type, MessageType.audio);
    expect(m?.durationMs, 4000);
    expect(m?.bytes, 900);
    expect(m?.mediaPath, 'chat-media/a__b/u/x.m4a');
    expect(
      ChatMessage.fromMap('m', {'senderUid': 'u', 'type': 'gif'}),
      isNull,
    );
  });
}
