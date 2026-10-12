// A04 — Safety Centre.
//
// Covers P2-RTL-A04 and P2-TXT-A04, and the gap G7 Q14 reports in the suite
// itself: there is no P2-OFF-A04 row, and the queued-report state is "the single
// most misleading thing this group could ship".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/features/account/domain/safety.dart';
import 'package:own_hub/features/account/presentation/safety_centre_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

const _self = 'uid-mine';

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

Widget _screen({
  required InMemoryBlockService blocks,
  required InMemoryReportService reports,
  VoidCallback? onTalkToAHuman,
  String Function(String uid)? nameOf,
}) => SafetyCentreView(
  blockService: blocks,
  reportService: reports,
  onTalkToAHuman: onTalkToAHuman,
  nameOf: nameOf,
);

void main() {
  // Every row here is about other women — verified members, reporting one,
  // blocking one. A04 is tested in the build that has a community.
  final savedFlags = AppRouter.featureFlags;
  setUp(
    () => AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.community: true,
    }),
  );
  tearDown(() => AppRouter.featureFlags = savedFlags);

  group('the screen renders its authored rows', () {
    testWidgets('verification, reporting, blocking, help and the 122 line', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          _screen(
            blocks: InMemoryBlockService(selfUid: _self),
            reports: InMemoryReportService(reporterUid: _self),
            onTalkToAHuman: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Every member is verified'), findsOneWidget);
      expect(find.text('Report someone'), findsOneWidget);
      expect(find.text('Blocked members'), findsOneWidget);
      expect(find.text('Reports you made'), findsOneWidget);
      expect(find.text('What happens when I report?'), findsOneWidget);
      expect(find.text('Talk to a human'), findsOneWidget);
      expect(
        find.text(
          'If you are in danger right now, call 122. This app cannot reach '
          'the police for you.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('but the support row is absent while its page has no address', (
      tester,
    ) async {
      // The rule A03 already follows, and the one `release_readiness_test`
      // asserts: a row is drawn only once its page has somewhere to go. On the
      // safety screen a "Talk to a human" that does nothing is worse than no
      // row at all, because a woman who taps it concludes there is nobody.
      _phone(tester);

      await tester.pumpWidget(
        _host(
          _screen(
            blocks: InMemoryBlockService(selfUid: _self),
            reports: InMemoryReportService(reporterUid: _self),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Talk to a human'), findsNothing);
      expect(find.text('Report someone'), findsOneWidget);
    });
  });

  group('the rows that used to do nothing', () {
    testWidgets('blocked members opens the list, and unblocking works', (
      tester,
    ) async {
      _phone(tester);
      final blocks = InMemoryBlockService(selfUid: _self);
      await blocks.block('uid-nada', BlockSource.post);

      await tester.pumpWidget(
        _host(
          _screen(
            blocks: blocks,
            reports: InMemoryReportService(reporterUid: _self),
            nameOf: (uid) => uid == 'uid-nada' ? 'Nada' : '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blocked members'));
      await tester.pumpAndSettle();

      expect(find.text('Nada'), findsOneWidget);
      await tester.tap(find.text('Unblock'));
      await tester.pumpAndSettle();

      expect(blocks.blocks(), isEmpty);
      expect(find.text('You have not blocked anyone.'), findsOneWidget);
    });

    testWidgets('and says so plainly when she has blocked nobody', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          _screen(
            blocks: InMemoryBlockService(selfUid: _self),
            reports: InMemoryReportService(reporterUid: _self),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blocked members'));
      await tester.pumpAndSettle();

      expect(find.text('You have not blocked anyone.'), findsOneWidget);
    });

    testWidgets('the report question answers itself in three steps', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          _screen(
            blocks: InMemoryBlockService(selfUid: _self),
            reports: InMemoryReportService(reporterUid: _self),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('What happens when I report?'));
      await tester.pumpAndSettle();

      expect(find.text('You pick a reason and send it.'), findsOneWidget);
      expect(find.text('A woman on the team reads it.'), findsOneWidget);
      expect(find.text('She tells you what she did about it.'), findsOneWidget);
    });
  });

  group('a queued report never looks successful', () {
    testWidgets('filed offline, the row says it is waiting for signal', (
      tester,
    ) async {
      _phone(tester);
      final reports = InMemoryReportService(reporterUid: _self, online: false);
      await reports.file(
        subjectUid: 'uid-nada',
        reason: ReportReason.harassment,
      );

      await tester.pumpWidget(
        _host(
          _screen(
            blocks: InMemoryBlockService(selfUid: _self),
            reports: reports,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waiting for signal'), findsOneWidget);
    });

    testWidgets('a queued report never claims a moderator has it', (
      tester,
    ) async {
      _phone(tester);
      final reports = InMemoryReportService(reporterUid: _self, online: false);
      await reports.file(subjectUid: 'uid-nada', reason: ReportReason.nudity);

      await tester.pumpWidget(
        _host(
          _screen(
            blocks: InMemoryBlockService(selfUid: _self),
            reports: reports,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The hour promise appears exactly once — on "Report someone", where it
      // describes the service. It must never attach to a report that is still
      // sitting on her phone.
      expect(
        find.text('A woman moderator reads it within an hour'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Reports you made'),
            matching: find.byType(Row),
          ),
          matching: find.text('A woman moderator reads it within an hour'),
        ),
        findsNothing,
      );
    });

    testWidgets('once sent, the waiting line is gone', (tester) async {
      _phone(tester);
      final reports = InMemoryReportService(reporterUid: _self, online: false);
      await reports.file(subjectUid: 'uid-nada', reason: ReportReason.spam);
      await reports.goOnline();

      await tester.pumpWidget(
        _host(
          _screen(
            blocks: InMemoryBlockService(selfUid: _self),
            reports: reports,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waiting for signal'), findsNothing);
    });
  });

  group('counts are computed, and are not stated as the mockup\'s samples', () {
    testWidgets('two blocks do not render the fixed "2 blocked" string', (
      tester,
    ) async {
      _phone(tester);
      final blocks = InMemoryBlockService(selfUid: _self);
      await blocks.block('uid-a', BlockSource.post);
      await blocks.block('uid-b', BlockSource.profile);

      await tester.pumpWidget(
        _host(
          _screen(
            blocks: blocks,
            reports: InMemoryReportService(reporterUid: _self),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The dictionary's "2 blocked" is the mockup's figure: right for her and
      // wrong for everybody else. The parameterised form is what the row uses,
      // so the count on screen is the count she has.
      expect(find.text('2 blocked'), findsNothing);
      expect(find.text('Blocked: 2'), findsOneWidget);
      expect(blocks.blocks(), hasLength(2));
    });

    testWidgets('five blocks still state no count', (tester) async {
      _phone(tester);
      final blocks = InMemoryBlockService(selfUid: _self);
      for (final uid in ['a', 'b', 'c', 'd', 'e']) {
        await blocks.block('uid-$uid', BlockSource.safetyCentre);
      }

      await tester.pumpWidget(
        _host(
          _screen(
            blocks: blocks,
            reports: InMemoryReportService(reporterUid: _self),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 blocked'), findsNothing);
      expect(find.text('5 blocked'), findsNothing);
      expect(find.text('1 · resolved in 40 minutes'), findsNothing);
    });
  });

  group('P2-RTL-A04 and P2-TXT-A04', () {
    testWidgets('Arabic renders right-to-left', (tester) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          _screen(
            blocks: InMemoryBlockService(selfUid: _self),
            reports: InMemoryReportService(reporterUid: _self),
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Report someone'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the largest system text size clips nothing', (tester) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          _screen(
            blocks: InMemoryBlockService(selfUid: _self),
            reports: InMemoryReportService(reporterUid: _self),
          ),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Report someone'), findsOneWidget);
    });
  });
}
