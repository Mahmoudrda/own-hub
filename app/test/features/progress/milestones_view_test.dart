// P02 — Milestones.
//
// The design note: "Unearned ones show plain progress instead of a locked badge,
// because a padlock reads as 'you are not allowed'." So there is a test for the
// absence of a lock, and one for the heading that claims twelve of something
// that does not yet exist.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/progress/domain/milestone.dart';
import 'package:own_hub/features/progress/presentation/milestones_view.dart';
import 'package:own_hub/features/progress/presentation/progress_view_model.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

Widget _view({
  MilestoneCounts counts = const MilestoneCounts(),
  Map<String, DateTime> earnedAt = const <String, DateTime>{},
}) => MilestonesView(
  summary: MilestonesSummary.from(
    catalogue: authoredMilestones,
    counts: counts,
    earnedAt: earnedAt,
  ),
  onBack: () {},
  onSelectTab: (_) {},
);

void main() {
  group('the list is the authored seven, and the heading knows it', () {
    testWidgets('"Twelve in all" is not claimed while eight exist', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Twelve in all'),
        findsNothing,
        reason:
            'G6 §9.14: P02 names eight and four more were inferred. A heading '
            'claiming twelve over a list of eight is a fiction.',
      );
    });

    testWidgets('"Came back" is a row now, not only a footnote', (
      tester,
    ) async {
      // It was the eighth milestone P02 names and the only one the dictionary
      // could not label, so it could not be a row. `cameBack` exists now.
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(find.text('Came back'), findsOneWidget);
    });

    testWidgets('a first-of-its-kind milestone shows no "0 of 1"', (
      tester,
    ) async {
      // Coming back is an event, not a count to climb — there is nothing to be
      // part-way through, so the bar says it and no figure does.
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(find.text('0 of 1'), findsNothing);
      // "Came back" is the only target-1 milestone on this screen, and it is
      // the row that must carry no figure.
      expect(find.text('1 of 1'), findsNothing);
    });

    testWidgets('no padlock, and no "locked" language anywhere', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_view(counts: const MilestoneCounts(sessions: 3))),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.textContaining('Locked'), findsNothing);
      expect(find.textContaining('locked'), findsNothing);
    });

    testWidgets('the one it most wants her to have has the last word', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '"Came back" is earned by returning after a break. It is the one we '
          'most want you to have.',
        ),
        findsOneWidget,
      );
    });
  });

  group('earned and ahead', () {
    testWidgets(
      'an earned milestone is ticked and dated when the date is hers',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _host(
            _view(
              counts: const MilestoneCounts(sessions: 12, countedWeeks: 2),
              earnedAt: {
                'first_session': DateTime(2026, 6, 3),
                'ten_sessions': DateTime(2026, 7, 1),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Earned'), findsOneWidget);
        expect(find.text('First session'), findsOneWidget);
        expect(find.text('3 Jun'), findsOneWidget);
        expect(find.text('10 sessions'), findsOneWidget);
        expect(find.text('1 Jul'), findsOneWidget);
      },
    );

    testWidgets('a different earn date shows the milestone without a date', (
      tester,
    ) async {
      // The dictionary holds "3 Jun" as a fixed string and has no month
      // vocabulary to build another from. A woman who earned it in August sees
      // the milestone and its tick, not somebody else's date.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(
            counts: const MilestoneCounts(sessions: 4),
            earnedAt: {'first_session': DateTime(2026, 8, 22)},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('First session'), findsOneWidget);
      expect(find.text('3 Jun'), findsNothing);
    });

    testWidgets('an unearned milestone shows a bar and her own figure', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(
            counts: const MilestoneCounts(
              sessions: 23,
              countedWeeks: 14,
              programDays: 11,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Next'), findsOneWidget);
      expect(find.text('20 counted weeks'), findsOneWidget);
      expect(find.text('14 of 20'), findsOneWidget);
      expect(find.text('23 of 50'), findsOneWidget);
      expect(
        find.text('11 of 18'),
        findsOneWidget,
        reason:
            'the programme row states her day against the target. It used to '
            'read "day 11 of 18" from a fixed string and was withheld from '
            'everybody else; the word "day" is the reported gap',
      );
    });

    testWidgets(
      'a woman with different figures is told none of the mockup\'s',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _host(
            _view(
              counts: const MilestoneCounts(
                sessions: 31,
                countedWeeks: 9,
                programDays: 4,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The names are hers, and so are the figures — which is the point of
        // the parameterised form. None of the mockup's pairs appears.
        expect(find.text('20 counted weeks'), findsOneWidget);
        expect(find.text('14 of 20'), findsNothing);
        expect(find.text('day 11 of 18'), findsNothing);
        expect(find.text('23 of 50'), findsNothing);

        expect(find.text('9 of 20'), findsOneWidget);
        expect(find.text('4 of 18'), findsOneWidget);
        expect(find.text('31 of 50'), findsOneWidget);
      },
    );

    testWidgets('a count past its target never reads "60 of 50"', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_view(counts: const MilestoneCounts(sessions: 60))),
      );
      await tester.pumpAndSettle();

      expect(find.text('60 of 50'), findsNothing);
      expect(find.text('50 of 50'), findsOneWidget);
    });

    testWidgets('nothing earned yet means no Earned card at all', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(find.text('Earned'), findsNothing);
      expect(find.text('Next'), findsOneWidget);
    });
  });

  group('P0-A11Y-01', () {
    testWidgets('it mirrors in Arabic with Western numerals', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(counts: const MilestoneCounts(sessions: 23, countedWeeks: 14)),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(MilestonesView))),
        TextDirection.rtl,
      );

      final eastern = RegExp('[٠-٩]');
      for (final text
          in tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data ?? '')) {
        expect(eastern.hasMatch(text), isFalse, reason: text);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('it does not overflow at the largest text size in Arabic', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(counts: const MilestoneCounts(sessions: 23)),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
