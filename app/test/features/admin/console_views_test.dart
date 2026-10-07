// Z15 Dashboard and Z16 Logs, against a fake of the two admin callables.
//
// The server is where the promises are kept (admin claim, phone sign-in, App
// Check, the access log, no person in any answer: functions/tests/
// test_console.py). What these hold is the screen's half: it draws what it is
// given, says why when it is refused, asks for the right page, and never
// invents a number it was not sent.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/data/callable_console_source.dart';
import 'package:own_hub/features/admin/domain/console_report.dart';
import 'package:own_hub/features/admin/domain/console_source.dart';
import 'package:own_hub/features/admin/presentation/dashboard_view.dart';
import 'package:own_hub/features/admin/presentation/logs_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_list_item.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

final Map<String, Object?> _dashboardJson = {
  'generatedAt': '2026-10-07T12:00:00+00:00',
  'members': {'total': 1204, 'verified': 1100},
  'reviews': {'pending': 6, 'overSla': 2, 'oldestHours': 80, 'slaHours': 72},
  'outcomes': {
    '7': {'APPROVED': 40, 'PENDING_REVIEW': 3, 'REJECTED_NOT_ELIGIBLE': 1},
    '30': {'APPROVED': 150, 'PENDING_REVIEW': 9},
  },
  'waitlist': {'total': 318},
  'deletions': {'pending': 1, 'done': 12},
  'events': {'upcoming': 2, 'drafts': 1},
  'content': {'exercises': 30, 'foods': 120, 'recipes': 7, 'programs': 4},
};

class _FakeConsole implements ConsoleSource {
  _FakeConsole({this.failure, Map<String, ConsoleLogPage>? pages})
    : pages = pages ?? {};

  ConsoleFailure? failure;
  final Map<String, ConsoleLogPage> pages;
  final List<bool> dashboardCalls = [];
  final List<(ConsoleLogKind, String?, String?)> logCalls = [];

  @override
  Future<ConsoleDashboard> dashboard({bool refresh = false}) async {
    dashboardCalls.add(refresh);
    if (failure case final f?) throw ConsoleException(f);
    return ConsoleDashboard.fromJson(_dashboardJson);
  }

  @override
  Future<ConsoleLogPage> logs(
    ConsoleLogKind kind, {
    String? before,
    String? outcome,
  }) async {
    logCalls.add((kind, before, outcome));
    if (failure case final f?) throw ConsoleException(f);
    return pages['${kind.wire}:${before ?? ''}'] ?? ConsoleLogPage(kind: kind);
  }
}

ConsoleLogPage _page(
  ConsoleLogKind kind,
  List<Map<String, Object?>> rows, {
  String? next,
}) => ConsoleLogPage.fromJson(kind, {'rows': rows, 'next': next});

void main() {
  group('Z15 — the dashboard', () {
    testWidgets('draws the counts it was sent and nothing else', (
      tester,
    ) async {
      _phone(tester);
      final console = _FakeConsole();
      await tester.pumpWidget(_host(DashboardView(source: console)));
      await tester.pumpAndSettle();

      expect(
        find.text('Counts only. Nothing here names a member.'),
        findsOneWidget,
      );
      expect(find.text('1,204'), findsOneWidget);
      expect(find.text('1,100'), findsOneWidget);
      expect(find.text('Human reviews waiting · 6'), findsOneWidget);
      expect(
        find.text('Oldest has waited 80 hours · 2 past the 72-hour promise'),
        findsOneWidget,
      );
      expect(find.text('Check outcomes, last 7 days'), findsOneWidget);
      expect(find.text('Approved'), findsNWidgets(2));
      expect(find.text('318'), findsOneWidget);
      expect(
        find.text('Updated 2026-10-07 15:00 · Cairo time'),
        findsOneWidget,
      );
      expect(console.dashboardCalls, [false]);
    });

    testWidgets('late reviews are amber, never red', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(DashboardView(source: _FakeConsole())));
      await tester.pumpAndSettle();
      final card = tester.widget<AppListItem>(
        find.byKey(const ValueKey('dashboard-reviews')),
      );
      expect(card.variant, AppCardVariant.amber);
      expect(card.variant, isNot(AppCardVariant.error));
    });

    testWidgets('refresh asks the server to skip its cache', (tester) async {
      _phone(tester);
      final console = _FakeConsole();
      await tester.pumpWidget(_host(DashboardView(source: console)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(console.dashboardCalls, [false, true]);
    });

    testWidgets('an account without the claim is told so, with no numbers', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          DashboardView(source: _FakeConsole(failure: ConsoleFailure.notAdmin)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('This account does not have admin access.'),
        findsOneWidget,
      );
      expect(find.text('1,204'), findsNothing);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('no connection offers a retry that works', (tester) async {
      _phone(tester);
      final console = _FakeConsole(failure: ConsoleFailure.unavailable);
      await tester.pumpWidget(_host(DashboardView(source: console)));
      await tester.pumpAndSettle();
      expect(
        find.text('The console needs a connection. Try again in a moment.'),
        findsOneWidget,
      );
      console.failure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('1,204'), findsOneWidget);
    });

    testWidgets('in Arabic, digits stay Western', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          DashboardView(source: _FakeConsole()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1,204'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Z16 — the logs', () {
    final decisions = _page(ConsoleLogKind.decisions, [
      {
        'at': '2026-10-07T09:00:00+00:00',
        'outcome': 'APPROVED',
        'reasons': ['MATCH_PASS'],
        'case': '3fa91c0e',
      },
    ], next: '2026-10-07T09:00:00+00:00');
    final older = _page(ConsoleLogKind.decisions, [
      {
        'at': '2026-10-06T09:00:00+00:00',
        'outcome': 'REJECTED_NOT_ELIGIBLE',
        'reasons': <String>[],
        'case': '9b2d41aa',
      },
    ]);

    testWidgets('a decision is an outcome, a time, codes and a case ref', (
      tester,
    ) async {
      _phone(tester);
      final console = _FakeConsole(
        pages: {
          'decisions:': decisions,
          'decisions:2026-10-07T09:00:00+00:00': older,
        },
      );
      await tester.pumpWidget(_host(LogsView(source: console)));
      await tester.pumpAndSettle();

      expect(find.text('Opening a log is recorded too.'), findsOneWidget);
      expect(find.text('Approved'), findsWidgets);
      expect(
        find.text('2026-10-07 12:00 · Case 3fa91c0e · MATCH_PASS'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(find.text('Load more'), 200);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(console.logCalls.last, (
        ConsoleLogKind.decisions,
        '2026-10-07T09:00:00+00:00',
        null,
      ));
      expect(find.text('2026-10-06 12:00 · Case 9b2d41aa'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('filtering by outcome asks the server for that outcome', (
      tester,
    ) async {
      _phone(tester);
      final console = _FakeConsole(pages: {'decisions:': decisions});
      await tester.pumpWidget(_host(LogsView(source: console)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not eligible'));
      await tester.pumpAndSettle();
      expect(console.logCalls.last, (
        ConsoleLogKind.decisions,
        null,
        'REJECTED_NOT_ELIGIBLE',
      ));
    });

    testWidgets('each log reads in its own terms', (tester) async {
      _phone(tester);
      final console = _FakeConsole(
        pages: {
          'reviews:': _page(ConsoleLogKind.reviews, [
            {
              'at': '2026-10-07T09:00:00+00:00',
              'action': 'schedule',
              'case': '3fa91c0e',
              'reviewer': 'c01d2e3f',
            },
          ]),
          'waitlist:': _page(ConsoleLogKind.waitlist, [
            {'day': '2026-10-07', 'joined': 12},
          ]),
          'deletions:': _page(ConsoleLogKind.deletions, [
            {'at': '2026-10-07T09:00:00+00:00', 'state': 'done', 'swept': true},
          ]),
          'errors:': _page(ConsoleLogKind.errors, [
            {
              'day': '2026-10-06',
              'counts': {'account_deletion_failed': 2},
            },
          ]),
          'access:': _page(ConsoleLogKind.access, [
            {
              'at': '2026-10-07T09:00:00+00:00',
              'action': 'logs.decisions',
              'admin': 'abcd1234',
            },
          ]),
        },
      );
      await tester.pumpWidget(_host(LogsView(source: console)));
      await tester.pumpAndSettle();

      Future<void> open(String chip) async {
        await tester.tap(find.text(chip).first);
        await tester.pumpAndSettle();
      }

      await open('Reviews');
      expect(find.text('Booked a review'), findsOneWidget);
      expect(
        find.text('2026-10-07 12:00 · Case 3fa91c0e · Reviewer c01d2e3f'),
        findsOneWidget,
      );
      await open('Waitlist');
      expect(find.text('2026-10-07'), findsOneWidget);
      expect(find.text('12 joined'), findsOneWidget);
      await open('Deletions');
      expect(find.text('Finished'), findsOneWidget);
      expect(find.text('2026-10-07 12:00 · Second sweep done'), findsOneWidget);
      await open('Errors');
      expect(find.text('account_deletion_failed · 2'), findsOneWidget);
      await open('Console reads');
      expect(find.text('Opened a log · Decisions'), findsOneWidget);
      expect(find.text('2026-10-07 12:00 · Admin abcd1234'), findsOneWidget);
    });

    testWidgets('an empty log says so', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(LogsView(source: _FakeConsole())));
      await tester.pumpAndSettle();
      expect(find.text('Nothing logged yet'), findsOneWidget);
    });

    testWidgets('refused, it says why', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          LogsView(
            source: _FakeConsole(failure: ConsoleFailure.signInRequired),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Sign in with your phone number to open the console.'),
        findsOneWidget,
      );
    });
  });

  group('reading the answers', () {
    test('a reference that is not eight hex characters is dropped', () {
      final row = ConsoleLogRow.fromJson(ConsoleLogKind.decisions, {
        'case': 'uHerAccount0001',
        'reviewer': '+201001234567',
        'outcome': 'SOMETHING_NEW',
        'reasons': ['MATCH_PASS', 'a sentence with spaces'],
      });
      expect(row.caseRef, isNull);
      expect(row.reviewerRef, isNull);
      expect(row.outcome, isNull);
      expect(row.reasons, ['MATCH_PASS']);
    });

    test('a missing count is zero and nothing is invented', () {
      final d = ConsoleDashboard.fromJson(const {});
      expect(d.accounts, 0);
      expect(d.oldestReviewHours, isNull);
      expect(d.outcomes7, isEmpty);
      expect(d.oldestIsLate, isFalse);
    });

    test('the server\'s refusals map to what a screen can say', () {
      expect(
        consoleFailureFor('permission-denied', 'phone_sign_in_required'),
        ConsoleFailure.signInRequired,
      );
      expect(
        consoleFailureFor('permission-denied', 'unauthenticated'),
        ConsoleFailure.notAdmin,
      );
      expect(
        consoleFailureFor('unauthenticated', null),
        ConsoleFailure.signInRequired,
      );
      expect(
        consoleFailureFor('failed-precondition', 'app_check_missing'),
        ConsoleFailure.unavailable,
      );
    });
  });
}
