// The six marketplace screens, in English and in Arabic.
//
// Each group holds one claim the screen must not make up: `H01` never states a
// figure it was not given and always opens a coach, `H02` never draws a block
// she hid, `H03` never draws a rail she cannot use, `H04` never suggests money
// moved, `H05` never shows two things waiting, and `H06` never offers a
// checkout where an enquiry is required.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/coaching/domain/coach_directory.dart';
import 'package:own_hub/features/coaching/domain/coaching_repository.dart';
import 'package:own_hub/features/coaching/domain/marketplace_stage.dart';
import 'package:own_hub/features/coaching/domain/money.dart';
import 'package:own_hub/features/coaching/domain/payment_provider.dart';
import 'package:own_hub/features/coaching/domain/payment_state_machine.dart';
import 'package:own_hub/features/coaching/presentation/coach_profile_view.dart';
import 'package:own_hub/features/coaching/presentation/coaching_ended_view.dart';
import 'package:own_hub/features/coaching/presentation/coaching_view_models.dart';
import 'package:own_hub/features/coaching/presentation/enquiry_view.dart';
import 'package:own_hub/features/coaching/presentation/find_a_coach_view.dart';
import 'package:own_hub/features/coaching/presentation/my_coach_view.dart';
import 'package:own_hub/features/coaching/presentation/packages_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_card.dart';

final FeatureFlags _on = FeatureFlags.allOff.with_({
  Feature.marketplace: true,
  Feature.payments: true,
});

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  onGenerateRoute: AppRouter.onGenerateRoute,
  onUnknownRoute: AppRouter.onUnknownRoute,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  ),
);

DirectoryRow _row(
  String uid,
  String name, {
  int? pounds = 1800,
  int reviewCount = 0,
  double? ratingAverage,
  int? replyMins,
  int? spotsLeft,
  bool acceptingClients = true,
}) => DirectoryRow(
  coachUid: uid,
  displayName: name,
  city: 'Giza',
  specialties: const [CoachingSpecialty.postpartum],
  languages: const [CoachingLanguage.arabic],
  acceptingClients: acceptingClients,
  priceFrom: pounds == null ? null : Money.pounds(pounds),
  reviewCount: reviewCount,
  ratingAverage: ratingAverage,
  replyMinsP50: replyMins,
  spotsLeft: spotsLeft,
);

const _monthly = CoachingOffer(
  id: 'monthly',
  coachUid: 'c1',
  name: 'Monthly coaching',
  period: OfferPeriod.monthly,
  price: Money.pounds(1800),
  lines: ['A plan built for your days and equipment'],
);

const _planOnly = CoachingOffer(
  id: 'plan-only',
  coachUid: 'c1',
  name: 'Plan only',
  period: OfferPeriod.oneOff,
  price: Money.pounds(900),
);

/// Every figure the prototype baked into its dictionary strings.
///
/// Named `kForbidden…` so `test/product_rules_test.dart` reads it as the deny
/// list it is rather than as a screen holding those values.
const List<String> kForbiddenMockupFigures = <String>[
  '4.8 ★ (126)',
  'from 1,800 EGP',
  'replies in ~2h',
  '12 spots left',
  // 'Under 2,000 EGP' used to be on this list, and H01 rendered no price-band
  // chip at all rather than a sentence with the mockup's ceiling frozen in it.
  // The parameterised `Under {n} EGP` has since been minted, so the chip is
  // built from `kDirectoryPriceBand` — the band the product chose, and the same
  // value the filter applies. The rendered words are the same words; what
  // changed is that moving the band moves them. `under2000Egp`, the baked
  // string, is asserted absent from `lib/` below.
];

void main() {
  group('H01 — find a coach', () {
    testWidgets('a row opens a coach, which the prototype never did', (
      tester,
    ) async {
      _phone(tester);
      String? opened;
      await tester.pumpWidget(
        _host(
          FindACoachView(
            model: FindACoachViewModel(
              snapshot: DirectorySnapshot(
                rows: [_row('c1', 'Nourhan El-Sayed')],
                source: DirectorySource.pack,
              ),
            ),
            onOpenCoach: (uid) => opened = uid,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nourhan El-Sayed'));
      await tester.pumpAndSettle();
      expect(
        opened,
        'c1',
        reason:
            'the prototype\'s coachRow carried no target, so the one directory '
            'in the product opened nothing',
      );
    });

    testWidgets('no mockup figure reaches the screen', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          FindACoachView(
            model: FindACoachViewModel(
              snapshot: DirectorySnapshot(
                rows: [
                  _row(
                    'c1',
                    'Nourhan El-Sayed',
                    reviewCount: 126,
                    ratingAverage: 4.8,
                    replyMins: 120,
                  ),
                ],
                source: DirectorySource.pack,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final figure in kForbiddenMockupFigures) {
        expect(
          find.text(figure),
          findsNothing,
          reason: '"$figure" is the mockup\'s number, not hers',
        );
      }
      // Her real figures do render, built from her own values.
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('(126)'), findsOneWidget);
    });

    testWidgets('a coach with four reviews shows no rating at all', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          FindACoachView(
            model: FindACoachViewModel(
              snapshot: DirectorySnapshot(
                rows: [
                  _row('c1', 'Hala', reviewCount: 4, ratingAverage: 2.5),
                ],
                source: DirectorySource.pack,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2.5'), findsNothing);
      expect(find.text('(4)'), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('an unpriced coach shows no price rather than a zero', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          FindACoachView(
            model: FindACoachViewModel(
              snapshot: DirectorySnapshot(
                rows: [_row('c1', 'Salma', pounds: null)],
                source: DirectorySource.pack,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Scoped to the row: the facet chips above it carry the price band, which
      // is a filter she chose and not a claim about this coach.
      final inRow = find.descendant(
        of: find.byType(AppCard),
        matching: find.textContaining(RegExp('EGP|0 ')),
      );
      expect(inRow, findsNothing);
    });

    testWidgets('the price band is a chip, and it filters', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          FindACoachView(
            model: FindACoachViewModel(
              snapshot: DirectorySnapshot(
                rows: [
                  _row('c1', 'Salma', pounds: 1500),
                  _row('c2', 'Hala', pounds: 2400),
                ],
                source: DirectorySource.pack,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Built from the band the product chose, not from `under2000Egp`.
      final chip = find.text('Under ${kDirectoryPriceBand.amountText} EGP');
      expect(chip, findsOneWidget);
      expect(find.text('Salma'), findsOneWidget);
      expect(find.text('Hala'), findsOneWidget);

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('Salma'), findsOneWidget);
      expect(
        find.text('Hala'),
        findsNothing,
        reason: 'the chip and the ceiling it applies are the same value',
      );

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('Hala'), findsOneWidget);
    });

    test('the baked price-band string reaches no screen', () {
      // `under2000Egp` is 'Under 2,000 EGP' with the figure inside the
      // sentence. The chip must never be built from it: the constant would
      // change and the words would not.
      final source = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(RegExp(r'l10n\.under2000Egp\b').hasMatch(source), isFalse);
    });

    testWidgets('a failed load says so instead of "no coaches"', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const FindACoachView(
            model: FindACoachViewModel(
              snapshot: DirectorySnapshot.unavailable(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('renders in Arabic without overflowing', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          FindACoachView(
            model: FindACoachViewModel(
              snapshot: DirectorySnapshot(
                rows: [_row('c1', 'Nourhan El-Sayed', replyMins: 120)],
                source: DirectorySource.pack,
              ),
            ),
          ),
          locale: const Locale('ar'),
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(FindACoachView), findsOneWidget);
    });
  });

  group('H02 — a coach profile', () {
    CoachProfileViewModel model({
      MarketplaceStage stage = MarketplaceStage.browsing,
      bool verified = true,
      bool acceptingClients = true,
      List<PortfolioBlock>? blocks,
    }) => CoachProfileViewModel(
      page: CoachPage(
        row: _row(
          'c1',
          'Nourhan El-Sayed',
          spotsLeft: 12,
          acceptingClients: acceptingClients,
        ),
        blocks:
            blocks ??
            const [
              CoverBlock(headline: 'Back to lifting, after birth'),
              MethodBlock(
                steps: ['We talk first', 'The floor weeks', 'Back under a weight'],
              ),
              OffersBlock(offerIds: ['monthly']),
            ],
        certificateLine: 'NASM CPT',
      ),
      offers: const [_monthly],
      stage: stage,
      flags: _on,
      verified: verified,
    );

    testWidgets('her blocks render in her order', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(CoachProfileView(model: model())));
      await tester.pumpAndSettle();
      expect(find.text('Back to lifting, after birth'), findsOneWidget);
      expect(find.text('We talk first'), findsOneWidget);
      expect(find.text('Monthly coaching'), findsOneWidget);
    });

    testWidgets('a block she hid is absent, leaving no gap', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CoachProfileView(
            model: model(
              blocks: const [
                CoverBlock(headline: 'Back to lifting, after birth'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Client results'), findsNothing);
      expect(find.text('What I offer'), findsNothing);
    });

    testWidgets('a block this build cannot draw draws nothing', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CoachProfileView(
            model: model(
              blocks: const [
                CoverBlock(headline: 'Back to lifting, after birth'),
                UnrenderableBlock('video'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Back to lifting, after birth'), findsOneWidget);
    });

    testWidgets('an unverified woman reads everything and cannot enquire', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(CoachProfileView(model: model(verified: false))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Back to lifting, after birth'), findsOneWidget);
      expect(find.text('See her packages'), findsOneWidget);
      expect(find.text('Message before you decide'), findsNothing);
    });

    testWidgets('the places count is hers, not the mockup\'s sentence', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(CoachProfileView(model: model())));
      await tester.pumpAndSettle();
      expect(find.text('12 spots left'), findsNothing);
      // Her own count, beside the word that says what it counts. The bare
      // "Spots" was all the dictionary had, and it read as a total.
      expect(find.text('12 Spots left'), findsOneWidget);
    });

    testWidgets('a coach who has closed her books says so', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(CoachProfileView(model: model(acceptingClients: false))),
      );
      await tester.pumpAndSettle();

      // The message button is not offered, and the reason is now stated. It
      // was silent while no dictionary line said "she has closed her books".
      expect(find.text('Message before you decide'), findsNothing);
      expect(
        find.text('She is not taking clients right now'),
        findsOneWidget,
      );
      // Not about this woman: browsing and her packages are still open.
      expect(find.text('Browse. Message when you are verified.'), findsNothing);
      expect(find.text('See her packages'), findsOneWidget);
    });

    testWidgets('renders in Arabic', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CoachProfileView(model: model()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('H03 — packages and checkout', () {
    PackagesViewModel model({
      MarketplaceStage stage = MarketplaceStage.acceptedAwaitingPayment,
      bool online = true,
      bool verified = true,
      List<CoachingOffer>? offers,
      PaymentView? payment,
    }) => PackagesViewModel.resolve(
      coachUid: 'c1',
      coachName: 'Nourhan El-Sayed',
      offers: offers ?? const [_monthly, _planOnly],
      stage: stage,
      flags: _on,
      verified: verified,
      online: online,
      coachAcceptingClients: true,
      spotsLeft: 12,
      payment: payment,
    );

    testWidgets('a monthly price renders from her figure and a dictionary word',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(PackagesView(model: model())));
      await tester.pumpAndSettle();
      expect(find.text('1,800 EGP a month'), findsOneWidget);
      // The mockup's own string is never used.
      expect(find.text('1,800 EGP'), findsNothing);
    });

    testWidgets('a one-off package states its price', (tester) async {
      // This asserted the opposite until the bare-currency word was minted,
      // and its comment said exactly why: withholding was the honest move
      // while the dictionary had nothing to say. `amountEgp` exists now, and
      // it is parameterised, so the figure is hers rather than the mockup's.
      //
      // Withholding at this point would be hiding a real price, and a package
      // whose price she cannot see is a package she cannot buy.
      _phone(tester);
      await tester.pumpWidget(
        _host(PackagesView(model: model(offers: const [_planOnly]))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Plan only'), findsOneWidget);
      expect(find.textContaining('900'), findsOneWidget);
    });

    testWidgets('P0-PAY-08 — offline draws no rails and offers no purchase', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(PackagesView(model: model(online: false))));
      await tester.pumpAndSettle();
      expect(find.text('Card'), findsNothing);
      expect(find.text('Fawry'), findsNothing);
      expect(find.text('Pay'), findsNothing);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);

      // This screen used to borrow 'Waiting for signal', which says the app is
      // waiting and says nothing about the charge. The minted sentence carries
      // the half that matters: nothing is held, so there is nothing to replay.
      expect(
        find.text('You need a connection to pay. Nothing is queued.'),
        findsOneWidget,
      );
      expect(find.text('Waiting for signal'), findsNothing);
    });

    testWidgets('a coach with closed books is said so, without a retry', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          PackagesView(
            model: PackagesViewModel.resolve(
              coachUid: 'c1',
              coachName: 'Nourhan El-Sayed',
              offers: const [_monthly],
              stage: MarketplaceStage.acceptedAwaitingPayment,
              flags: _on,
              verified: true,
              online: true,
              coachAcceptingClients: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Silent until this sentence existed: no dictionary line said her books
      // were closed, and the nearest ones were about this woman rather than
      // about the coach's capacity.
      expect(
        find.text('She is not taking clients right now'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Pay'), findsNothing);
    });

    testWidgets('what the seam says about a payment in flight', (tester) async {
      _phone(tester);
      const ledger = PaymentLedger();
      PaymentRecord created() => PaymentRecord.created(
        providerTxnId: 'pmb-772',
        relId: 'c1__client-93',
        engagementId: 'e1',
        rail: PaymentRail.card,
        priced: const Money.pounds(1800),
        createdAt: DateTime(2026, 9, 16),
      );

      Future<void> pump(PaymentRecord record) async {
        await tester.pumpWidget(
          _host(PackagesView(model: model(payment: PaymentView.record(record)))),
        );
        await tester.pumpAndSettle();
      }

      // Priced, nothing decided. Silent until "Preparing your payment" existed.
      await pump(created());
      expect(find.text('Preparing your payment'), findsOneWidget);

      // The only honest "Paid": a signed webhook, read through the seam.
      final paid = ledger
          .apply(
            ledger
                .apply(
                  created(),
                  ProviderOpened(at: DateTime(2026, 9, 16), reference: null),
                )
                .record,
            WebhookPaid(
              at: DateTime(2026, 9, 16),
              hmacVerifiedAt: DateTime(2026, 9, 16),
              amount: const Money.pounds(1800),
            ),
          )
          .record;
      await pump(paid);
      expect(find.text('Paid'), findsOneWidget);

      // Declined. The generic "something went wrong at our end" did not say
      // the part she needs, which is that nothing was charged.
      final failed = ledger
          .apply(
            ledger
                .apply(
                  created(),
                  ProviderOpened(at: DateTime(2026, 9, 16), reference: null),
                )
                .record,
            WebhookFailed(at: DateTime(2026, 9, 16), code: 'do_not_honour'),
          )
          .record;
      await pump(failed);
      expect(
        find.text('That payment was declined. Nothing was charged.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);

      // A refund on its way. No figure, and no day count: "a few days" is true
      // of a wallet and of a card.
      final refunding = ledger
          .apply(
            paid,
            RefundRequested(
              at: DateTime(2026, 9, 17),
              reason: RefundReason.clientChangedMind,
            ),
          )
          .record;
      await pump(refunding);
      expect(
        find.text('Your money is on its way back. It can take a few days.'),
        findsOneWidget,
      );
      expect(
        RegExp(r'\d').hasMatch(
          'Your money is on its way back. It can take a few days.',
        ),
        isFalse,
        reason: 'the mockup said "wallets 1-3 days, cards 5-14"; no such '
            'window was measured, and this sentence states none',
      );
    });

    testWidgets('without an accepted enquiry there are no rails', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(PackagesView(model: model(stage: MarketplaceStage.browsing))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Card'), findsNothing);
      expect(find.text('She pays only once you accept'), findsOneWidget);
    });

    testWidgets('paying takes two deliberate taps, and no dialog', (
      tester,
    ) async {
      _phone(tester);
      var paid = 0;
      await tester.pumpWidget(
        _host(
          PackagesView(
            model: model(),
            onPay: (offer, rail) => paid++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No rail chosen: the action is present and inert.
      expect(find.text('Continue'), findsOneWidget);

      // Two packages and three rails is taller than a phone, which is the
      // real layout rather than a test artefact.
      await tester.ensureVisible(find.text('Card'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Card'));
      await tester.pumpAndSettle();
      expect(find.text('Pay'), findsOneWidget);

      await tester.tap(find.text('Pay'));
      await tester.pumpAndSettle();
      expect(paid, 0, reason: 'the first tap opens the confirm step');
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.text('Pay'));
      await tester.pumpAndSettle();
      expect(paid, 1);
    });

    testWidgets('a Fawry code is shown left-to-right in Arabic', (
      tester,
    ) async {
      _phone(tester);
      const ledger = PaymentLedger();
      final created = PaymentRecord.created(
        providerTxnId: 'pmb-772',
        relId: 'c1__client-93',
        engagementId: 'e1',
        rail: PaymentRail.fawry,
        priced: const Money.pounds(1800),
        createdAt: DateTime(2026, 9, 16),
      );
      final awaiting = ledger
          .apply(
            created,
            ProviderOpened(at: DateTime(2026, 9, 16), reference: '7719 4402'),
          )
          .record;

      await tester.pumpWidget(
        _host(
          PackagesView(
            model: model(payment: PaymentView.record(awaiting)),
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('7719 4402'), findsOneWidget);
      final direction = tester.widget<Directionality>(
        find
            .ancestor(
              of: find.text('7719 4402'),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(direction.textDirection, TextDirection.ltr);
    });

    testWidgets('a seam that cannot answer shows no figure', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          PackagesView(
            model: model(
              payment: const PaymentView.unavailable(
                PaymentUnavailableReason.notImplemented,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // No rail is contracted, so nothing is said about one.
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });
  });

  group('H04 — the enquiry', () {
    EnquiryViewModel model({
      String text = '',
      EnquiryPhase phase = EnquiryPhase.composing,
      bool verified = true,
    }) => EnquiryViewModel(
      coachUid: 'c1',
      coachName: 'Nourhan El-Sayed',
      clientUid: 'client-93',
      stage: MarketplaceStage.browsing,
      flags: _on,
      verified: verified,
      coachAcceptingClients: true,
      text: text,
      phase: phase,
    );

    testWidgets('the promise is on the screen before she types', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(EnquiryView(model: model())));
      await tester.pumpAndSettle();
      expect(find.text('She pays only once you accept'), findsOneWidget);
    });

    testWidgets('an empty message cannot be sent', (tester) async {
      _phone(tester);
      var sent = 0;
      await tester.pumpWidget(
        _host(EnquiryView(model: model(), onSend: (_) => sent++)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(sent, 0);
    });

    testWidgets('typing enables the send', (tester) async {
      _phone(tester);
      var sent = 0;
      await tester.pumpWidget(
        _host(EnquiryView(model: model(), onSend: (_) => sent++)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Can you work with a knee that clicks?',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(sent, 1);
    });

    testWidgets('a queued send is never drawn as a failure', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(EnquiryView(model: model(phase: EnquiryPhase.queued))),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.cloud_queue), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('renders in Arabic', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(EnquiryView(model: model()), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('H05 — my coach', () {
    MyCoachViewModel model({
      MyCoachSnapshot? snapshot,
    }) => MyCoachViewModel(snapshot: snapshot);

    testWidgets('no coach renders the invitation, not an error', (
      tester,
    ) async {
      _phone(tester);
      var opened = 0;
      await tester.pumpWidget(
        _host(MyCoachView(model: model(), onFindACoach: () => opened++)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Every coach here is a verified woman with checked certificates.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Coaches').last);
      await tester.pumpAndSettle();
      expect(opened, greaterThan(0));
    });

    testWidgets('only one thing is waiting', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          MyCoachView(
            model: model(
              snapshot: const MyCoachSnapshot(
                relId: 'c1__client-93',
                coachName: 'Nourhan El-Sayed',
                stage: MarketplaceStage.coached,
                reviewDue: true,
                unreadMessages: 3,
                lastReviewAnswered: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Weekly review due'), findsOneWidget);
      expect(find.text('Last review'), findsNothing);
    });

    testWidgets('an unmeasured reply time makes no claim', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          MyCoachView(
            model: model(
              snapshot: const MyCoachSnapshot(
                relId: 'c1__client-93',
                coachName: 'Nourhan El-Sayed',
                stage: MarketplaceStage.coached,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('2 hours'), findsNothing);
    });

    testWidgets('renders in Arabic', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          MyCoachView(
            model: model(
              snapshot: const MyCoachSnapshot(
                relId: 'c1__client-93',
                coachName: 'Nourhan El-Sayed',
                stage: MarketplaceStage.coached,
                reviewDue: true,
              ),
            ),
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('H06 — coaching ended', () {
    CoachingEndedViewModel model({bool sharingCleared = true}) =>
        CoachingEndedViewModel(
          snapshot: EndedCoachingSnapshot(
            relId: 'c1__client-93',
            coachUid: 'c1',
            coachName: 'Nourhan El-Sayed',
            endedAt: DateTime(2026, 10, 7),
            reviewCount: 4,
            sharingCleared: sharingCleared,
          ),
          flags: _on,
        );

    testWidgets('history stays readable and says so', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(CoachingEndedView(model: model())));
      await tester.pumpAndSettle();
      expect(find.text('Everything you did is still here to read.'),
          findsOneWidget);
      expect(find.text('Readable · new messages are closed'), findsOneWidget);
      expect(find.text('Readable · no new assignments'), findsOneWidget);
    });

    testWidgets('P0-COACH-09 — working together again starts an enquiry', (
      tester,
    ) async {
      _phone(tester);
      var again = 0;
      await tester.pumpWidget(
        _host(
          CoachingEndedView(
            model: model(),
            onWorkTogetherAgain: () => again++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The label falls back to the neutral word: the dictionary's only
      // "again" line names the mockup's coach.
      await tester.tap(find.text('Coaches'));
      await tester.pumpAndSettle();
      expect(again, 1);
    });

    testWidgets('the sharing sentence is absent when it is not true', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(CoachingEndedView(model: model(sharingCleared: false))),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Cycle sharing switched itself off'),
        findsNothing,
      );
    });

    testWidgets('renders in Arabic at large text', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CoachingEndedView(model: model()),
          locale: const Locale('ar'),
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
