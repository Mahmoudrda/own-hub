/// `K05` — Getting paid.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K05`.
///
/// # This screen cannot be completed, and says so
///
/// There is no payment provider. G12 §9 **Q7** records it: payments, escrow, the
/// 80% split and payouts are absent from the spine entirely, and no group owns
/// them. So [PaymentProvider] has one implementation,
/// [UnavailablePaymentProvider], and this screen renders what it actually
/// returns.
///
/// What it does **not** do is show her the prototype's pre-filled
/// "Vodafone Cash · 010 xxx xx32" and let her tap Continue. That would be a
/// screen claiming to have stored a payout method that does not exist, on the
/// one page in the product where being wrong costs her money.
///
/// # Never queued offline
///
/// G12 §4 puts `K05` on the not-writable side of the offline line, with the
/// reason: *"tokenisation is a network round-trip by definition. Refused with a
/// reason, not a spinner."*
///
/// # The wallet number has no field here yet
///
/// [PayoutMethodDraft] carries one, for the length of one call, and this screen
/// has nowhere to type it: the dictionary has no label for a wallet or account
/// number. That string is reported as missing rather than invented in English.
/// Nothing is lost today — with no rail, there is nothing to tokenise.
library;

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_sage_note.dart';
import '../domain/payments.dart';
import 'coach_setup_scaffold.dart';
import 'coach_view_models.dart';

class CoachPayoutView extends StatefulWidget {
  const CoachPayoutView({
    super.key,
    required this.model,
    this.flags = FeatureFlags.shipped,
    this.onContinue,
    this.onBack,
    this.onSaveAndClose,
    this.onSetPayout,
    this.onPayoutLater,
  });

  final CoachSetupViewModel model;
  final FeatureFlags flags;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onSaveAndClose;

  /// Hands the draft to whoever holds the rail. **Null means there is no rail**,
  /// and then the number field is not drawn at all — a box you can type a wallet
  /// number into that tokenises nothing is worse than no box.
  ///
  /// The draft is transient by contract: it is handed over and dropped, and the
  /// number is never held by this screen beyond the controller it was typed in.
  final ValueChanged<PayoutMethodDraft>? onSetPayout;

  /// "Add payout later": submits her application without a payout method.
  /// A reviewer reads certificates, not a wallet; she adds the method on
  /// `K17` before she can be paid. Offered only while no method is set.
  final VoidCallback? onPayoutLater;

  @override
  State<CoachPayoutView> createState() => _CoachPayoutViewState();
}

class _CoachPayoutViewState extends State<CoachPayoutView> {
  late final TextEditingController _holder;
  final TextEditingController _account = TextEditingController();
  PayoutKind _kind = PayoutKind.mobileWallet;

  @override
  void initState() {
    super.initState();
    final current = widget.model.payout;
    _holder = TextEditingController(
      text: current is PayoutMethodSet ? current.destination.holderName : '',
    );
    if (current is PayoutMethodSet) _kind = current.destination.kind;
  }

  @override
  void dispose() {
    _holder.dispose();
    _account.dispose();
    super.dispose();
  }

  /// Hands over the draft the moment there is enough of one to tokenise.
  ///
  /// [PayoutMethodDraft.isComplete] is the gate, and it is the provider's
  /// weak one rather than a guess at an Egyptian wallet format — so an
  /// incomplete form simply sends nothing and the step stays unfinished.
  void _offer() {
    final send = widget.onSetPayout;
    if (send == null) return;
    final draft = PayoutMethodDraft(
      kind: _kind,
      holderName: _holder.text,
      accountRef: _account.text,
    );
    if (draft.isComplete) send(draft);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final model = widget.model;
    final railIsOn = widget.flags.isOn(Feature.payments);
    final usable = railIsOn && model.payout.isKnown;

    return CoachSetupScaffold(
      step: CoachSetupStep.payout,
      title: l10n.whereShouldWeSendYourMoney,
      subtitle: l10n.paidOutOnThe1stOfEach,
      onBack: () => goToScreen(context, 'K04', widget.onBack),
      onSaveAndClose: widget.onSaveAndClose,
      // Disabled until a rail can actually accept a method. Continuing here
      // would submit her application with no way to pay her.
      onPrimary: model.canAdvanceFrom(CoachSetupStep.payout)
          ? () => goToScreen(context, 'K06', widget.onContinue)
          : null,
      secondaryLabel: model.canAdvanceFrom(CoachSetupStep.payout)
          ? null
          : l10n.addPayoutLater,
      onSecondary: widget.onPayoutLater == null
          ? null
          : () => goToScreen(context, 'K06', widget.onPayoutLater),
      children: [
        if (!usable) ...[
          // The honest state: the rail cannot answer, so there is nothing to
          // choose yet. What she is told is what remains true whenever it
          // arrives — she is paid on the 1st, and she keeps 80%.
          AppEmptyState(
            icon: Icons.account_balance_wallet,
            title: l10n.payoutMethod,
            body: l10n.youKeep80TheFirstPayoutLands,
          ),
          if (model.payout case PayoutMethodUnavailable(
            reason: PaymentUnavailableReason.providerUnavailable,
          ))
            AppCard(
              variant: AppCardVariant.amber,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              children: [
                Text(
                  l10n.weCouldNotReachTheServerYour,
                  style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                ),
              ],
            ),
        ] else ...[
          AppListItem(
            variant: _kind == PayoutKind.mobileWallet
                ? AppCardVariant.selected
                : AppCardVariant.outlined,
            leading: const Icon(
              Icons.account_balance_wallet,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.mobileWallet,
            // The options, not one coach's number. The prototype's
            // "010 xxx xx32" is a sample about a specific person.
            subtitle: l10n.vodafoneCashOrangeMoneyEtisalatInstapay,
            trailing: _kind == PayoutKind.mobileWallet
                ? const Icon(
                    Icons.check_circle,
                    size: 24,
                    color: AppColors.primary,
                  )
                : null,
            onTap: () => setState(() {
              _kind = PayoutKind.mobileWallet;
              _offer();
            }),
          ),
          AppListItem(
            variant: _kind == PayoutKind.bankAccount
                ? AppCardVariant.selected
                : AppCardVariant.outlined,
            leading: const Icon(
              Icons.payments,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.bankAccount,
            subtitle: l10n.anyEgyptianBank,
            trailing: _kind == PayoutKind.bankAccount
                ? const Icon(
                    Icons.check_circle,
                    size: 24,
                    color: AppColors.primary,
                  )
                : null,
            onTap: () => setState(() {
              _kind = PayoutKind.bankAccount;
              _offer();
            }),
          ),
          AppField(
            controller: _holder,
            label: l10n.fullNameAsOnTheAccount,
            onChanged: (_) => setState(_offer),
          ),
          // Drawn only when something can actually tokenise it. What she types
          // here is handed to the rail and dropped; nothing on this screen
          // stores it, and `PayoutDestination` has no field it could live in.
          if (widget.onSetPayout != null)
            AppField(
              controller: _account,
              label: l10n.walletOrAccountNumber,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(_offer),
            ),
        ],
        AppSageNote(l10n.weNeverShowYourWalletNumberOr),
      ],
    );
  }
}
