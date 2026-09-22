// `K09`, `K16`, `K17`, `K18` and `K25`, against the prototype.
//
// Each group holds one claim the screen must not make up: `K09` never offers an
// accept it cannot honour, `K16` never draws a banner from a switch that is off,
// `K17` never states a figure, `K18` never states a reply time nobody measured,
// and `K25` has no state that means failed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coach/domain/client_view.dart';
import 'package:own_hub/features/coach/domain/coach_capacity.dart';
import 'package:own_hub/features/coach/domain/coach_chat.dart';
import 'package:own_hub/features/coach/domain/coach_desk.dart';
import 'package:own_hub/features/coach/domain/coach_profile.dart';
import 'package:own_hub/features/coach/domain/coach_repository.dart';
import 'package:own_hub/features/coach/domain/coach_verification.dart';
import 'package:own_hub/features/coach/domain/enquiry.dart';
import 'package:own_hub/features/coach/domain/payments.dart';
import 'package:own_hub/features/coach/presentation/coach_chat_view.dart';
import 'package:own_hub/features/coach/presentation/coach_earnings_view.dart';
import 'package:own_hub/features/coach/presentation/coach_enquiry_view.dart';
import 'package:own_hub/features/coach/presentation/coach_first_week_view.dart';
import 'package:own_hub/features/coach/presentation/coach_public_profile_view.dart';
import 'package:own_hub/features/coach/presentation/coach_view_models.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

final _at = DateTime(2026, 9, 8, 21, 14);

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

Enquiry _enquiry({EnquiryStatus status = EnquiryStatus.enquiry}) => Enquiry(
  relId: 'coach-42_client-93',
  coachUid: 'coach-42',
  clientUid: 'client-93',
  status: status,
  enquiredAt: DateTime(2026, 9, 7, 6, 40),
  displayName: 'Rania Fouad',
  situation: 'Postpartum, 7 months, at home, 25 minutes',
  herWords: 'I want my back to stop hurting when I lift my daughter.',
  authorisationId: 'auth-551',
);

CoachMessage _message({
  required String body,
  bool fromCoach = false,
  MessageDelivery delivery = MessageDelivery.sent,
}) => CoachMessage(
  msgId: 'm-$body',
  relId: 'coach-42_client-93',
  senderUid: fromCoach ? 'coach-42' : 'client-93',
  coachUid: 'coach-42',
  clientUid: 'client-93',
  body: body,
  createdAt: _at,
  delivery: delivery,
);

void main() {
  group('K09 — an enquiry', () {
    testWidgets('it carries her situation and her own words', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CoachEnquiryView(
            enquiry: _enquiry(),
            verification: CoachVerificationState.verified,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New enquiry'), findsOneWidget);
      expect(find.text('Rania Fouad'), findsOneWidget);
      expect(find.text('What she is asking for'), findsOneWidget);
      expect(
        find.text('Postpartum, 7 months, at home, 25 minutes'),
        findsOneWidget,
      );
      expect(
        find.textContaining('lift my daughter'),
        findsOneWidget,
        reason: 'Her own words are the reason this screen exists.',
      );
      expect(find.text('She pays only once you accept'), findsOneWidget);
    });

    testWidgets('a verified coach with room may accept', (tester) async {
      _phone(tester);
      var accepted = 0;
      await tester.pumpWidget(
        _host(
          CoachEnquiryView(
            enquiry: _enquiry(),
            verification: CoachVerificationState.verified,
            onAccept: () => accepted++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accept and send a welcome'));
      await tester.pumpAndSettle();
      expect(accepted, 1);
    });

    testWidgets('P0-CVER-01 — a coach still being checked cannot', (
      tester,
    ) async {
      _phone(tester);
      var accepted = 0;
      await tester.pumpWidget(
        _host(
          CoachEnquiryView(
            enquiry: _enquiry(),
            verification: CoachVerificationState.humanReview,
            onAccept: () => accepted++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accept and send a welcome'));
      await tester.pumpAndSettle();

      expect(accepted, 0);
      expect(
        find.textContaining('unverified coaches cannot take clients'),
        findsOneWidget,
        reason: 'The refusal is stated as the rule, not as an error.',
      );
    });

    testWidgets('P0-ENQ-04 — offline it is refused, not queued', (
      tester,
    ) async {
      _phone(tester);
      var accepted = 0;
      await tester.pumpWidget(
        _host(
          CoachEnquiryView(
            enquiry: _enquiry(),
            verification: CoachVerificationState.verified,
            network: NetworkStatus.offline,
            onAccept: () => accepted++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accept and send a welcome'));
      await tester.pumpAndSettle();
      expect(
        accepted,
        0,
        reason:
            'A queued accept could take money for a spot that no longer '
            'exists, or let two coaches take the same last spot.',
      );
    });

    testWidgets('a full roster refuses too', (tester) async {
      _phone(tester);
      var accepted = 0;
      await tester.pumpWidget(
        _host(
          CoachEnquiryView(
            enquiry: _enquiry(),
            verification: CoachVerificationState.verified,
            hasRoom: false,
            onAccept: () => accepted++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accept and send a welcome'));
      await tester.pumpAndSettle();
      expect(accepted, 0);
    });

    testWidgets('declining is offered as a neutral choice', (tester) async {
      _phone(tester);
      var declined = 0;
      await tester.pumpWidget(
        _host(
          CoachEnquiryView(
            enquiry: _enquiry(),
            verification: CoachVerificationState.verified,
            onDecline: () => declined++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Not a fit for me'), findsOneWidget);
      await tester.tap(find.text('Not a fit for me'));
      await tester.pumpAndSettle();
      expect(declined, 1);
    });
  });

  group('K16 — a conversation', () {
    testWidgets('the banner appears when the projection carries the reason', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CoachChatView(
            clientName: 'Rania Fouad',
            week: const ClientWeekSignal(
              quietWeeksInARow: 2,
              restWeekAlreadyUsed: true,
            ),
            messages: [_message(body: 'Work was impossible this week.')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Second quiet week. Her rest week is already used.'),
        findsOneWidget,
      );
      expect(find.text('Work was impossible this week.'), findsOneWidget);
      expect(find.text('Message or hold to talk'), findsOneWidget);
    });

    testWidgets('P1-RULE-15 — a closed switch draws no banner at all', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CoachChatView(
            clientName: 'Rania Fouad',
            messages: [_message(body: 'Work was impossible this week.')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Second quiet week. Her rest week is already used.'),
        findsNothing,
        reason:
            'The field is absent from the document, so there is nothing to '
            'draw — not a banner saying "not shared".',
      );
    });

    testWidgets('P0-CCHAT-01 — a queued message is queued, never failed', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CoachChatView(
            clientName: 'Rania Fouad',
            messages: [
              _message(
                body: 'Then this week is two sessions.',
                fromCoach: true,
                delivery: MessageDelivery.queued,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waiting for signal'), findsOneWidget);
      expect(find.textContaining('failed'), findsNothing);
      expect(find.textContaining('Failed'), findsNothing);
    });

    testWidgets('a delivered message carries no status at all', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CoachChatView(
            clientName: 'Rania Fouad',
            messages: [
              _message(body: 'Sunday and Wednesday.', fromCoach: true),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waiting for signal'), findsNothing);
    });
  });

  group('K17 — earnings', () {
    CoachEarningsView view({
      EarningsState earnings = const EarningsState.unavailable(
        PaymentUnavailableReason.notImplemented,
      ),
    }) => CoachEarningsView(
      onSelectTab: (_) {},
      model: CoachEarningsViewModel.from(
        earnings: earnings,
        payout: const PayoutMethodState.unavailable(
          PaymentUnavailableReason.notImplemented,
        ),
      ),
    );

    testWidgets('it states no figure, and says what stays true instead', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(view()));
      await tester.pumpAndSettle();

      expect(find.text('Earnings'), findsOneWidget);
      expect(find.text('Earnings this month'), findsOneWidget);
      expect(
        find.textContaining('The first payout lands on the 1st'),
        findsOneWidget,
      );
    });

    testWidgets("none of the prototype's samples reach the screen", (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(view()));
      await tester.pumpAndSettle();

      for (final sample in [
        '21,600 EGP',
        'September so far',
        'Your 80% of 27,000 EGP · 12 clients',
        '10 monthly packages',
      ]) {
        expect(find.text(sample), findsNothing, reason: sample);
      }
      expect(find.textContaining('EGP'), findsNothing);
    });

    testWidgets('the payout method leads to the screen that sets it', (
      tester,
    ) async {
      _phone(tester);
      var opened = 0;
      await tester.pumpWidget(
        _host(
          CoachEarningsView(
            onSelectTab: (_) {},
            onOpenPayoutMethod: () => opened++,
            model: CoachEarningsViewModel.from(
              earnings: const EarningsState.unavailable(
                PaymentUnavailableReason.notImplemented,
              ),
              payout: const PayoutMethodState.unavailable(
                PaymentUnavailableReason.notImplemented,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Payout method'));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });
  });

  group('K18 — her public profile', () {
    CoachPublicProfileView view({
      CoachVerificationState verification = CoachVerificationState.verified,
      int taken = 6,
      int max = 14,
      int? replyTime,
    }) => CoachPublicProfileView(
      model: CoachPublicProfileViewModel.from(
        profile: CoachProfile(
          displayName: 'Hala Mansour',
          city: 'Tanta',
          capacity: CoachCapacity(max: max, taken: taken),
          verification: verification,
          replyTimeP50Mins: replyTime,
        ),
        offers: InMemoryCoachRepository(),
        certificates: const [],
        now: _at,
      ),
    );

    testWidgets('it previews the real client view', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(view()));
      await tester.pumpAndSettle();

      expect(find.text('Your public profile'), findsOneWidget);
      expect(
        find.textContaining('This is exactly what a client sees'),
        findsOneWidget,
      );
      expect(find.text('Hala Mansour'), findsOneWidget);
      expect(find.text('Design your page'), findsOneWidget);
      expect(find.text('Packages'), findsOneWidget);
      expect(find.text('Spots'), findsOneWidget);
    });

    testWidgets("the spots line states her roster, or nobody's", (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(_host(view(taken: 12, max: 20)));
      await tester.pumpAndSettle();
      expect(find.text('12 of 20'), findsOneWidget);

      await tester.pumpWidget(_host(view(taken: 6, max: 14)));
      await tester.pumpAndSettle();
      expect(
        find.text('12 of 20'),
        findsNothing,
        reason: "Six of fourteen is not twelve of twenty.",
      );
      expect(find.text('6 of 14'), findsOneWidget);
    });

    testWidgets('a reply time nobody measured makes no claim', (tester) async {
      _phone(tester);

      await tester.pumpWidget(_host(view()));
      await tester.pumpAndSettle();
      expect(find.text('Reply time shown to clients'), findsOneWidget);
      expect(find.text('About 2 hours · measured, not typed'), findsNothing);

      await tester.pumpWidget(_host(view(replyTime: 120)));
      await tester.pumpAndSettle();
      expect(find.text('About 2 hours · measured, not typed'), findsOneWidget);
    });

    testWidgets(
      'a coach under review sees her page and is told it is not live',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _host(view(verification: CoachVerificationState.docsChecking)),
        );
        await tester.pumpAndSettle();

        expect(find.text('We are checking your certificates'), findsOneWidget);
        expect(
          find.text('Design your page'),
          findsOneWidget,
          reason: 'She wrote it, it is hers, and K06 promised she could.',
        );
      },
    );

    testWidgets('a cleared coach is not told she is being checked', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(view()));
      await tester.pumpAndSettle();

      expect(find.text('We are checking your certificates'), findsNothing);
    });
  });

  group('K25 — her first week', () {
    testWidgets('four steps, and every one of them real work', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const CoachFirstWeekView(
            firstWeek: CoachFirstWeek(
              completed: {
                CoachFirstWeekStep.publishPage,
                CoachFirstWeekStep.saveSplit,
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your first week'), findsOneWidget);
      expect(find.text('Publish your page'), findsOneWidget);
      expect(find.text('Save one split'), findsOneWidget);
      expect(find.text('Set up an assessment'), findsOneWidget);
      expect(find.text('Answer your first enquiry'), findsOneWidget);
      expect(find.text('of 4'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('nothing on it can fail, and it says so', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const CoachFirstWeekView(firstWeek: CoachFirstWeek())),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Nothing here expires, and no client sees your progress through it.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('failed'), findsNothing);
      expect(find.textContaining('missed'), findsNothing);
      expect(find.textContaining('overdue'), findsNothing);
    });

    testWidgets('"Two done" is shown only to a coach who has done two', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          const CoachFirstWeekView(
            firstWeek: CoachFirstWeek(
              completed: {
                CoachFirstWeekStep.publishPage,
                CoachFirstWeekStep.saveSplit,
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Two done'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const CoachFirstWeekView(
            firstWeek: CoachFirstWeek(
              completed: {CoachFirstWeekStep.publishPage},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Two done'), findsNothing);
      expect(
        find.textContaining('None of it is a tour'),
        findsOneWidget,
        reason: 'the line that is true of everyone stays',
      );
    });

    testWidgets('the cleared card appears only once a woman has cleared her', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(const CoachFirstWeekView(firstWeek: CoachFirstWeek())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Certificates checked'), findsNothing);

      await tester.pumpWidget(
        _host(
          const CoachFirstWeekView(
            firstWeek: CoachFirstWeek(certificatesCleared: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Certificates checked'), findsOneWidget);
      expect(
        find.text('Your page is visible and you can take clients.'),
        findsOneWidget,
      );
    });

    testWidgets('it holds together in Arabic at the largest text size', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const CoachFirstWeekView(firstWeek: CoachFirstWeek()),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
