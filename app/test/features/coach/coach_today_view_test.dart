// `K07` — Today, her desk. And `K24` — Today, day one.
//
// `P0-CDAY-01` is the case: *"K24 renders as a branch of the K07 route … No
// tour and no overlay. Accepting a first client flips the same route to K07
// with no navigation."* The second group proves exactly that — one widget, two
// renderings, chosen by the roster.
//
// The last group is the money one. The prototype's `K24` draws "Earnings this
// month · 0 EGP"; this screen draws nothing, because there is no provider and a
// zero is a claim about her month.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/coach/domain/coach_capacity.dart';
import 'package:own_hub/features/coach/domain/coach_desk.dart';
import 'package:own_hub/features/coach/domain/coach_profile.dart';
import 'package:own_hub/features/coach/domain/coach_verification.dart';
import 'package:own_hub/features/coach/domain/payments.dart';
import 'package:own_hub/features/coach/presentation/coach_today_view.dart';
import 'package:own_hub/features/coach/presentation/coach_view_models.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

final _tuesday = DateTime(2026, 9, 8, 19, 30);

/// Payments on — with its `marketplace` parent, because a child cannot
/// outlive its parent.
///
/// Built from [FeatureFlags.allOff] so the "flag is dark" cases below pin
/// their own precondition instead of inheriting `FeatureFlags.shipped`.
final FeatureFlags _paymentsOn = FeatureFlags.allOff.with_({
  Feature.marketplace: true,
  Feature.payments: true,
});

/// Payments dark. The default for `_view` below, said out loud.
final FeatureFlags _paymentsOff = FeatureFlags.allOff;

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
    onGenerateRoute: AppRouter.onGenerateRoute,
    onUnknownRoute: AppRouter.onUnknownRoute,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

DeskQueueItem _item(
  int n, {
  DeskReason reason = DeskReason.checkIn,
  String? name,
}) => DeskQueueItem(
  relId: 'coach-42_client-$n',
  displayName: name ?? 'Client $n',
  reason: reason,
  waitingSince: _tuesday.subtract(Duration(hours: n)),
);

CoachTodayView _view({
  required int taken,
  CoachVerificationState verification = CoachVerificationState.verified,
  List<DeskQueueItem> queue = const <DeskQueueItem>[],
  int overflow = 0,
  CoachFirstWeek firstWeek = const CoachFirstWeek(),
  EarningsState earnings = const EarningsState.unavailable(
    PaymentUnavailableReason.notImplemented,
  ),
  FeatureFlags? flags,
  Key? key,
}) => CoachTodayView(
  key: key,
  now: _tuesday,
  onSelectTab: (_) {},
  model: CoachTodayViewModel.from(
    profile: CoachProfile(
      displayName: 'Hala Mansour',
      // Sixty, so the forty-five-client case below is expressible at all.
      capacity: CoachCapacity(max: 60, taken: taken),
      verification: verification,
    ),
    desk: CoachDesk(
      queue: queue,
      overflowCount: overflow,
      verification: verification,
      firstWeek: firstWeek,
      earnings: earnings,
    ),
    now: _tuesday,
    flags: flags ?? _paymentsOff,
  ),
);

void main() {
  group('P0-CDAY-01 / HANDOFF 16 — a state, not a route', () {
    testWidgets('the same widget renders both, chosen by the roster', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(_view(key: const ValueKey('empty'), taken: 0)),
      );
      await tester.pumpAndSettle();
      expect(find.text('No clients yet'), findsOneWidget);
      expect(find.text('Worth doing before your first client'), findsOneWidget);

      // One client later. Same widget, same route, no navigation.
      await tester.pumpWidget(
        _host(
          _view(
            key: const ValueKey('working'),
            taken: 1,
            queue: [_item(6, name: 'Rania Fouad')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No clients yet'), findsNothing);
      expect(find.text('Rania Fouad'), findsOneWidget);
    });

    testWidgets('a busy coach with a quiet evening is not on day one', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(taken: 11)));
      await tester.pumpAndSettle();

      expect(
        find.text('No clients yet'),
        findsNothing,
        reason:
            'The branch reads her roster, not her queue. Branching on an empty '
            'queue would show the beginner screen the moment she caught up.',
      );
    });
  });

  group('K24 — rule 17: the empty state is the onboarding', () {
    testWidgets('it says what will appear and why it is empty', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(taken: 0)));
      await tester.pumpAndSettle();

      expect(find.text('No clients yet'), findsOneWidget);
      expect(
        find.textContaining('she lands here, in her own words'),
        findsOneWidget,
      );
    });

    testWidgets('and offers three pieces of real work, none of it a tour', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(taken: 0)));
      await tester.pumpAndSettle();

      expect(find.text('Finish your page'), findsOneWidget);
      expect(find.text('Save a split'), findsOneWidget);
      expect(find.text('Add a meal you always prescribe'), findsOneWidget);
      expect(find.text('Your first week'), findsOneWidget);
    });

    testWidgets('the verification card shows while she is being checked', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(taken: 0, verification: CoachVerificationState.humanReview),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('We are checking your certificates'), findsOneWidget);
      expect(
        find.text('Usually the same day. You can build everything else now.'),
        findsOneWidget,
      );
    });

    testWidgets('and is gone once a woman has cleared her', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_view(taken: 0, verification: CoachVerificationState.verified)),
      );
      await tester.pumpAndSettle();

      expect(find.text('We are checking your certificates'), findsNothing);
      expect(find.text('No clients yet'), findsOneWidget);
    });

    testWidgets('the first-week line states her own count, or none at all', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          _view(
            key: const ValueKey('two'),
            taken: 0,
            firstWeek: const CoachFirstWeek(
              completed: {
                CoachFirstWeekStep.publishPage,
                CoachFirstWeekStep.saveSplit,
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 of 4'), findsOneWidget);

      // A coach who has done one of four is not told she has done two.
      await tester.pumpWidget(
        _host(
          _view(
            key: const ValueKey('one'),
            taken: 0,
            firstWeek: const CoachFirstWeek(
              completed: {CoachFirstWeekStep.publishPage},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 of 4'), findsNothing);
      expect(find.text('1 of 4'), findsOneWidget);
    });
  });

  group('K07 — the queue, oldest first', () {
    testWidgets('each row names who is waiting and what for', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(
            taken: 7,
            queue: [
              _item(2, name: 'Mai Serry', reason: DeskReason.newEnquiry),
              _item(9, name: 'Rania Fouad', reason: DeskReason.reviewDue),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rania Fouad'), findsOneWidget);
      expect(find.text('Mai Serry'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('New enquiry'), findsOneWidget);
      expect(find.text('My portfolio'), findsOneWidget);
    });

    testWidgets('the waiting line is stated only when it is true of her', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(_host2(taken: 7, queue: [_item(1), _item(2), _item(3)])),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 check-ins waiting'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          _host2(
            key: const ValueKey('five'),
            taken: 7,
            queue: [_item(1), _item(2), _item(3), _item(4), _item(5)],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('3 check-ins waiting'),
        findsNothing,
        reason: 'Five waiting is not three. The number-free line is shown.',
      );
      expect(find.text('Needs a reply'), findsOneWidget);
    });

    testWidgets('everyone past the cap is a count, not thirty more rows', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(
            taken: 45,
            queue: [for (var i = 1; i <= 30; i++) _item(i)],
            overflow: 15,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clients'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a quiet evening draws no amber card at all', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(taken: 9)));
      await tester.pumpAndSettle();

      expect(find.text('Needs a reply'), findsNothing);
      expect(find.text('Start'), findsNothing);
    });
  });

  group('money is absent rather than zero', () {
    testWidgets("K24 does not draw the prototype's 0 EGP", (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(taken: 0)));
      await tester.pumpAndSettle();

      expect(find.text('0 EGP'), findsNothing);
      expect(find.textContaining('EGP'), findsNothing);
      // What it says instead is true whatever she earns.
      expect(find.text('You keep 80% of what she pays.'), findsOneWidget);
    });

    testWidgets('K07 draws no earnings line without a statement', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(taken: 7, queue: [_item(3)])));
      await tester.pumpAndSettle();

      expect(find.text('Earnings this month'), findsNothing);
    });

    testWidgets('nor with a statement while the flag is dark', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(
            taken: 7,
            queue: [_item(3)],
            earnings: EarningsState.statement(
              EarningsStatement(
                monthKey: '2026-09',
                grossPiastres: 930000,
                sharePiastres: 744000,
                lines: const [],
                asOf: _tuesday,
                payoutState: PayoutState.accruing,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Earnings this month'), findsNothing);
    });

    testWidgets('and only with both does the line appear', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(
            taken: 7,
            queue: [_item(3)],
            flags: _paymentsOn,
            earnings: EarningsState.statement(
              EarningsStatement(
                monthKey: '2026-09',
                grossPiastres: 930000,
                sharePiastres: 744000,
                lines: const [],
                asOf: _tuesday,
                payoutState: PayoutState.accruing,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Earnings this month'), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('day one renders in Arabic with no English left behind', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_view(taken: 0), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('No clients yet'), findsNothing);
      expect(find.text('Worth doing before your first client'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and neither branch overflows at the largest text size', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          _view(key: const ValueKey('a'), taken: 0),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _host(
          _view(
            key: const ValueKey('b'),
            taken: 9,
            queue: [_item(2, name: 'Rania Fouad')],
          ),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

/// The same builder, for the two cases that pump twice and need distinct keys.
CoachTodayView _host2({
  required int taken,
  List<DeskQueueItem> queue = const <DeskQueueItem>[],
  Key? key,
}) => _view(key: key ?? const ValueKey('three'), taken: taken, queue: queue);
