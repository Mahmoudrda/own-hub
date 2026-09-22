/// `H03` — her packages, and the checkout behind them.
///
/// The prototype drew these as two screens, `H03` (packages) and `H04` (pay),
/// with a "Continue · 1,800 EGP" button between them that took a woman straight
/// from a price to a payment form. **Buy-direct is removed**, so that door no
/// longer exists: a checkout opens only when a coach has already accepted her,
/// and the rails belong on the same screen as the package they are paying for.
/// `H04` is now the enquiry, which is what every woman meets first.
///
/// ## What this screen will not do
///
///  * **It will not state a price it was not given.** A package whose price the
///    seam could not supply renders with no figure and no purchase action. It
///    does not render `0 EGP`, a dash, or the mockup's 1,800.
///  * **It will not queue a purchase.** With no signal the rails are not drawn
///    at all and the refusal says so *in those words* — "You need a connection
///    to pay. Nothing is queued." There is no pending state, no optimistic
///    "paid", and nothing for a sync layer to replay (`P0-PAY-08`).
///  * **It will not claim a payment succeeded.** Paid arrives from a signed
///    webhook, read through the seam. Coming back from the provider's tab
///    triggers a *read*.
///  * **It will not hold a card number.** The rails open the provider's hosted
///    page in a platform browser tab. There is no text field on this screen
///    that could take one, and no type in this feature that could hold one.
///
/// ## Paying may confirm
///
/// One of rule 9's two carve-outs (the other is ending coaching). It is
/// destructive, it logs nothing, and it cannot be undone — the same argument
/// block and account deletion already won. The confirmation is an **inline
/// step on this screen**, not a dialog: `showDialog` is banned across every
/// feature folder by an executable guard, and a modal whose copy lives in a
/// widget is a modal nobody translates.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/checkout_gate.dart';
import '../domain/coaching_repository.dart';
import '../domain/payment_provider.dart';
import '../domain/payment_state_machine.dart';
import 'coaching_money.dart';
import 'coaching_view_models.dart';
import 'coaching_widgets.dart';

class PackagesView extends StatefulWidget {
  const PackagesView({
    super.key,
    required this.model,
    this.onBack,
    this.onSelectOffer,
    this.onPay,
    this.onRetry,
    this.testNote,
    this.onTestAccept,
    this.testAcceptNote,
  });

  final PackagesViewModel model;
  final VoidCallback? onBack;
  final ValueChanged<String>? onSelectOffer;

  /// Called once she has chosen a rail and confirmed. The caller runs
  /// [CheckoutRunner]; this screen never talks to a provider itself.
  final void Function(CoachingOffer offer, PaymentRail rail)? onPay;

  final VoidCallback? onRetry;

  /// A sentence about the rail she is about to use, when it is not a real one.
  ///
  /// Today's only caller is the test build, where no provider is contracted
  /// and no money moves. Null renders nothing — and with a real rail it stays
  /// null, so a live checkout can never carry a note saying it is a test.
  final String? testNote;

  /// The coach's own accept, offered to the woman looking at the screen.
  ///
  /// **Only ever her own coach page, and only while no account is required.**
  /// [CheckoutGate] opens a checkout from one stage — the coach accepted — and
  /// that is not relaxed anywhere. One woman holds both roles in this build, so
  /// rather than leaving her stuck at a refusal she cannot answer, the accept
  /// is offered here with [testAcceptNote] saying whose act it is. Null on
  /// every other coach's page, which is every real case.
  final VoidCallback? onTestAccept;

  final String? testAcceptNote;

  @override
  State<PackagesView> createState() => _PackagesViewState();
}

class _PackagesViewState extends State<PackagesView> {
  String? _selectedOfferId;
  PaymentRail? _rail;

  /// The inline confirm step. False until she has chosen a rail and tapped pay
  /// once; the second tap is the one that spends money.
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final model = widget.model;
    final offers = model.offers;
    final selectedId = _selectedOfferId ?? model.selectedOfferId;
    final selected = offers.where((o) => o.id == selectedId).firstOrNull;

    final footer = <Widget>[..._footerFor(context, l10n, model, selected)];

    return AppScaffold(
      appBar: AppTopBar(
        title: model.coachName,
        onBack: () => goToScreen(context, 'H02', widget.onBack),
      ),
      footer: footer,
      children: [
        for (final offer in offers)
          _PackageCard(
            offer: offer,
            selected: offer.id == selectedId,
            onTap: () {
              setState(() {
                _selectedOfferId = offer.id;
                _confirming = false;
              });
              widget.onSelectOffer?.call(offer.id);
            },
          ),

        // The rails, and only when the gate has actually cleared a purchase.
        if (model.mayPay) ...[
          CoachingSectionHead(l10n.howWouldYouLikeToPay),
          for (final rail in model.rails)
            _RailRow(
              rail: rail,
              selected: _rail == rail,
              onTap: () => setState(() {
                _rail = rail;
                _confirming = false;
              }),
            ),
          // The refund promise, stated before payment where it reduces fear
          // rather than after, where it reads as an apology.
          CoachingNote(l10n.yourCoachIsPaidAfterYourFirst),
          // What this rail actually is. Drawn above the button that spends
          // money, not after it.
          if (widget.testNote case final String text)
            CoachingNotice(icon: Icons.science_outlined, text: text),
        ] else if (model.refusal != null) ...[
          _RefusalNotice(reason: model.refusal!, onRetry: widget.onRetry),
          // Her own page: the accept she is waiting for is hers to give.
          if (widget.onTestAccept case final VoidCallback accept)
            CoachingNotice(
              icon: Icons.science_outlined,
              text: widget.testAcceptNote ?? '',
              action: l10n.acceptAsTheCoachTest,
              onAction: accept,
            ),
        ],

        // What the seam knows about a payment already in flight.
        if (model.paymentState != null)
          _PaymentStateCard(
            state: model.paymentState!,
            reference: model.fawryReference,
            onRetry: widget.onRetry,
          )
        else if (model.paymentUnavailable != null)
          _SeamUnavailableNotice(reason: model.paymentUnavailable!),
      ],
    );
  }

  List<Widget> _footerFor(
    BuildContext context,
    AppL10n l10n,
    PackagesViewModel model,
    CoachingOffer? selected,
  ) {
    if (!model.mayPay || selected == null) return const <Widget>[];
    final price = model.clearedPrice;
    // Belt and braces: the gate cleared a price, and a missing one still draws
    // no button. A purchase action beside no figure asks her to trust a number
    // nobody stated.
    if (price == null) return const <Widget>[];

    final rail = _rail;
    if (rail == null) {
      return <Widget>[
        AppButton(
          l10n.continueLabel,
          height: 56,
          // Disabled until she has picked a rail. Not hidden: a missing button
          // reads as a broken screen.
          onPressed: null,
        ),
      ];
    }

    if (!_confirming) {
      return <Widget>[
        AppButton(
          l10n.pay,
          height: 56,
          icon: Icons.lock,
          onPressed: () => setState(() => _confirming = true),
        ),
      ];
    }

    // The confirm step. The figure is hers, from the gate, beside the word that
    // says what it buys.
    final line = priceLine(l10n, price: price, period: selected.period);
    return <Widget>[
      if (line != null) CoachingNote(line, tone: AppColors.onSurface),
      AppButton(
        l10n.pay,
        height: 56,
        icon: Icons.lock,
        onPressed: () => widget.onPay?.call(selected, rail),
      ),
      AppButton(
        l10n.cancel,
        variant: AppButtonVariant.text,
        height: 44,
        fontSize: 15,
        onPressed: () => setState(() => _confirming = false),
      ),
    ];
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.offer,
    required this.selected,
    required this.onTap,
  });

  final CoachingOffer offer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final price = priceLine(l10n, price: offer.price, period: offer.period);

    return AppCard(
      variant: selected ? AppCardVariant.selected : AppCardVariant.outlined,
      onTap: onTap,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(offer.name, style: AppText.titleL),
                  const SizedBox(height: 3),
                  CoachingNote(
                    offer.period == OfferPeriod.monthly
                        ? l10n.cancelAnyTimeRenewsMonthly
                        : l10n.aProgramNoCheckIns,
                  ),
                ],
              ),
            ),
            // Withheld rather than invented. `priceLine` returns null for a
            // one-off package because the dictionary has no bare currency
            // word — see coaching_money.dart.
            if (price != null) ...[
              const SizedBox(width: 12),
              Text(price, style: AppText.titleM),
            ],
          ],
        ),
        for (final line in offer.lines)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check, size: 20, color: AppColors.tertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  line,
                  style: AppText.body.copyWith(color: AppColors.onSurface),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _RailRow extends StatelessWidget {
  const _RailRow({
    required this.rail,
    required this.selected,
    required this.onTap,
  });

  final PaymentRail rail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final (icon, title, subtitle) = switch (rail) {
      PaymentRail.card => (
        Icons.credit_card,
        l10n.card,
        l10n.visaMastercardMeeza,
      ),
      PaymentRail.mobileWallet => (
        Icons.account_balance_wallet,
        l10n.mobileWallet,
        l10n.vodafoneCashOrangeMoneyEtisalatInstapay,
      ),
      PaymentRail.fawry => (
        Icons.receipt_long,
        l10n.fawry,
        l10n.payWithACodeAtAnyFawry,
      ),
    };

    return AppListItem(
      leading: Icon(icon, size: 24, color: AppColors.primaryDim),
      title: title,
      subtitle: subtitle,
      variant: selected ? AppCardVariant.selected : AppCardVariant.outlined,
      trailing: selected
          ? const Icon(Icons.check_circle, size: 24, color: AppColors.primary)
          : null,
      onTap: onTap,
    );
  }
}

/// Why she cannot pay right now, in the plainest words the dictionary has.
///
/// Every branch that renders nothing is a **missing string**, listed in the
/// handover. Saying nothing is better than saying the wrong thing, and far
/// better than inventing an English sentence that would ship untranslated.
class _RefusalNotice extends StatelessWidget {
  const _RefusalNotice({required this.reason, this.onRetry});

  final CheckoutRefusal reason;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final (text, action) = switch (reason) {
      // "You need a connection to pay. Nothing is queued." — the second
      // sentence is the whole point, and it is why `waitingForSignal` and the
      // offline-logging line were both refused here: they promise that
      // something is held and will go out, and `P0-PAY-08` says nothing is.
      CheckoutRefusal.offline => (
        l10n.youNeedAConnectionToPayNothing,
        l10n.tryAgain,
      ),
      CheckoutRefusal.notVerified => (
        l10n.browseMessageWhenYouAreVerified,
        null,
      ),
      // Enquiry first, always. The message button is the way forward.
      CheckoutRefusal.noAcceptedEnquiry => (
        l10n.shePaysOnlyOnceYouAccept,
        null,
      ),
      CheckoutRefusal.alreadyPaying => (l10n.awaitingReply, null),
      // Her books are closed. Said plainly, and with no retry beside it:
      // trying again in a second changes nothing about her capacity.
      CheckoutRefusal.coachNotAccepting => (
        l10n.sheIsNotTakingClientsRightNow,
        null,
      ),
      CheckoutRefusal.priceUnknown => (null, null),
      CheckoutRefusal.marketplaceOff => (null, null),
      CheckoutRefusal.paymentsOff => (null, null),
    };
    if (text == null) return const SizedBox.shrink();
    return CoachingNotice(
      icon: reason == CheckoutRefusal.offline
          ? Icons.cloud_off
          : Icons.info_outline,
      text: text,
      action: action,
      onAction: action == null ? null : onRetry,
    );
  }
}

/// What the seam says about a payment in flight.
///
/// Note what is absent: there is **no branch that renders a figure**. A receipt
/// is `H05`'s, once the webhook has landed and the relationship has moved.
/// *Paid* is a word, not an amount, and it is said only for the state a signed
/// webhook produced — never optimistically, and never on returning from the
/// provider's tab.
class _PaymentStateCard extends StatelessWidget {
  const _PaymentStateCard({required this.state, this.reference, this.onRetry});

  final PaymentState state;
  final String? reference;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = switch (state) {
      // The callable has priced it and nothing is decided yet.
      PaymentState.created => l10n.preparingYourPayment,
      // The hosted page is open or the code is issued. "The provider's page is
      // open" has no dictionary entry, and the reference below says more than
      // a sentence about it would.
      PaymentState.awaitingProvider => null,
      // From a signed, verified webhook, read through the seam. The only
      // honest "Paid", which is why the screen may say it.
      PaymentState.paid => l10n.paid,
      // "That payment was declined. Nothing was charged." — the second
      // sentence is the one she needs, and the generic server-error line did
      // not carry it. All three rails are offered again below.
      PaymentState.failed => l10n.thatPaymentWasDeclinedNothingWasCharged,
      PaymentState.expired => l10n.thatCodeHasExpiredAskForA,
      // "It can take a few days" states no figure, so it is true of a wallet
      // and of a card. The mockup's "wallets 1–3 days, cards 5–14" is not in
      // the dictionary and is not invented here.
      PaymentState.refundPending => l10n.yourMoneyIsOnItsWayBack,
      // Settled. "On its way back" would be untrue, and there is no line that
      // says it has arrived.
      PaymentState.refunded => null,
      PaymentState.disputed => null,
    };

    final showReference =
        reference != null && state == PaymentState.awaitingProvider;

    if (text == null && !showReference) return const SizedBox.shrink();

    return AppCard(
      // Amber is a thing to attend to. A payment that landed is not one.
      variant: state == PaymentState.paid
          ? AppCardVariant.sage
          : AppCardVariant.amber,
      children: [
        if (text != null)
          Text(text, style: AppText.body.copyWith(color: AppColors.onSurface)),
        if (showReference)
          // The Fawry code. Selectable, and left-to-right even in Arabic: a
          // reference she has to read out at a counter must not be mirrored.
          Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(
              reference!,
              style: AppText.titleL.copyWith(color: AppColors.onSurface),
            ),
          ),
        if (state.invitesAnotherAttempt)
          AppButton(
            l10n.tryAgain,
            variant: AppButtonVariant.outlined,
            height: 46,
            fontSize: 15,
            onPressed: onRetry,
          ),
      ],
    );
  }
}

/// The seam could not answer at all.
class _SeamUnavailableNotice extends StatelessWidget {
  const _SeamUnavailableNotice({required this.reason});

  final PaymentUnavailableReason reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = switch (reason) {
      PaymentUnavailableReason.offline => l10n.waitingForSignal,
      PaymentUnavailableReason.providerUnavailable =>
        l10n.somethingWentWrongAtOurEndNothing,
      // No rail is contracted, or the flag is dark. Neither is a sentence a
      // woman needs; the purchase action is simply not offered.
      PaymentUnavailableReason.notImplemented => null,
      PaymentUnavailableReason.featureOff => null,
    };
    if (text == null) return const SizedBox.shrink();
    return CoachingNotice(icon: Icons.cloud_off, text: text);
  }
}
