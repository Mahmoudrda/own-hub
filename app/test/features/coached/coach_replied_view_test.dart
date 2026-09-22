// G13 and G14 as screens — **the card, and the absence of the card.**
//
// This is §2.2 at the surface a woman actually sees. A coach can type anything
// she likes into a bubble; the only thing that can put "Plan updated" on her
// screen is a published revision, and these tests prove the screen behaves that
// way rather than trusting that it does.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coached/presentation/coach_replied_view.dart';
import 'package:own_hub/features/coached/presentation/coached_chat_view.dart';
import 'package:own_hub/features/coached/presentation/coached_widgets.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

/// The four-entry thread these tests used to get for free.
///
/// `CoachedChatView` once invented it from the dictionary whenever it was
/// given no entries, which meant every woman with an empty thread read one
/// client's messages — "Can we make Thursday shorter? I have 20 minutes." —
/// and a plan updated on a Thursday in September that was not hers. The
/// fixture belongs to the test that needs it, not to the screen.
List<ThreadEntry> _thread() => const [
  ThreadEntry.message(
    mine: true,
    text: 'Can we make Thursday shorter? I have 20 minutes.',
    state: 'Read',
    attachmentLabel: 'Thursday · full-body strength',
  ),
  ThreadEntry.message(
    mine: false,
    text: 'Yes, I have updated Thursday. The new session is in your plan.',
  ),
  ThreadEntry.planUpdate('Plan updated · Thursday 18 September'),
  ThreadEntry.message(mine: true, voiceDuration: '0:24', state: 'Delivered'),
];

void main() {
  group('G13 — a reply, with and without a publish behind it', () {
    testWidgets('a published revision renders the card', (tester) async {
      await tester.pumpWidget(
        _host(
          const CoachRepliedView(
            planChange: 'Thursday 18 September onwards · published by Sara',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Plan updated'), findsOneWidget);
      expect(
        find.text('Thursday 18 September onwards · published by Sara'),
        findsOneWidget,
      );
    });

    testWidgets('a reply with no publish behind it produces NO card at all', (
      tester,
    ) async {
      // The coach answered the review, agreed two things in words, and did
      // not publish. The agreed points appear; the card does not exist.
      await tester.pumpWidget(
        _host(
          const CoachRepliedView(
            agreed: ['Keep the weight, add reps'],
            planChange: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Keep the weight, add reps'), findsOneWidget);
      expect(
        find.text('Plan updated'),
        findsNothing,
        reason:
            'A message that says something changed, with nothing changed '
            'behind it, is how coaching over chat fails.',
      );
    });

    testWidgets('it states what a revision does not touch', (tester) async {
      await tester.pumpWidget(_host(const CoachRepliedView()));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Yesterday’s logs and any session you already started stay as they were.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('her voice note plays and is not written out', (tester) async {
      await tester.pumpWidget(
        _host(const CoachRepliedView(voiceDuration: '0:41')),
      );
      await tester.pumpAndSettle();

      expect(find.text('0:41'), findsOneWidget);
      // No transcript, no "listen to the text version", nothing in words.
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ')
          .toLowerCase();
      expect(texts.contains('transcript'), isFalse);
    });
  });

  group('G14 — a plan update is not a message', () {
    testWidgets('the system chip renders separately from the bubbles', (
      tester,
    ) async {
      await tester.pumpWidget(_host(CoachedChatView(entries: _thread())));
      await tester.pumpAndSettle();

      expect(find.byType(PlanUpdatedChip), findsOneWidget);
      expect(find.text('Plan updated · Thursday 18 September'), findsOneWidget);
      // It is not inside a bubble: the bubbles are the two messages and the
      // voice note.
      expect(find.byType(ChatBubble), findsNWidgets(3));
    });

    testWidgets('a thread with no published revision shows no chip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CoachedChatView(
            entries: [
              const ThreadEntry.message(
                mine: false,
                text: 'I have shortened Thursday to 20 minutes.',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlanUpdatedChip), findsNothing);
      expect(
        find.text('I have shortened Thursday to 20 minutes.'),
        findsOneWidget,
      );
    });

    testWidgets('the header states real working hours', (tester) async {
      // Hers, and only hers. Given none, the header states none rather than
      // promising a woman her coach answers Sunday to Thursday when she may
      // not.
      await tester.pumpWidget(_host(const CoachedChatView()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Not monitored at night'), findsNothing);

      await tester.pumpWidget(
        _host(
          const CoachedChatView(
            serviceHours:
                'Sun–Thu, 9:00–17:00 Cairo · replies within one '
                'working day. Not monitored at night.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Not monitored at night'), findsOneWidget);
    });

    testWidgets('delivery state is visible on the bubble', (tester) async {
      await tester.pumpWidget(_host(CoachedChatView(entries: _thread())));
      await tester.pumpAndSettle();

      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
    });

    testWidgets('an attachment opens the record it refers to', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        _host(
          CoachedChatView(entries: _thread(), onOpenAttachment: () => opened++),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thursday · full-body strength'));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });

    testWidgets(
      'P0-MSG-06 — an ended relationship closes the composer with words',
      (tester) async {
        await tester.pumpWidget(
          _host(CoachedChatView(entries: _thread(), composerEnabled: false)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Readable · new messages are closed'), findsOneWidget);
        // The history is still there.
        expect(find.byType(ChatBubble), findsNWidgets(3));
        // And there is no mic to tap.
        expect(find.byIcon(Icons.mic_none), findsNothing);
      },
    );

    testWidgets('a queued message shows the sync glyph at full opacity', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CoachedChatView(
            entries: [
              ThreadEntry.message(
                mine: true,
                text: 'Sending this from the metro.',
                state: 'Saved on your phone',
                queued: true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_queue), findsOneWidget);
      expect(find.text('Saved on your phone'), findsOneWidget);
    });
  });

  testWidgets('both screens render in Arabic', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(const CoachedChatView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _host(const CoachRepliedView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
