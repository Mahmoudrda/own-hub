library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_state/app_changes.dart';
import '../../../app_state/payments_switch.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../data/payments_hub.dart';
import '../data/payments_repository.dart';
import '../data/pending_proofs.dart';
import '../domain/payment_models.dart';

/// Shown on H05 while the coach waits for her payment.
class PayCard extends StatelessWidget {
  const PayCard({super.key, required this.onPay});
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppCard(
      variant: AppCardVariant.tonal,
      children: [
        Text(l10n.yourCoachAcceptedYouPayToStart, style: AppText.titleM),
        AppButton(
          l10n.payNow,
          key: const ValueKey('pay-now'),
          onPressed: onPay,
        ),
      ],
    );
  }
}

/// Shown on H05 while a payment is with the coach or under review.
class SeePaymentCard extends StatelessWidget {
  const SeePaymentCard({super.key, required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppCard(
      variant: AppCardVariant.tonal,
      children: [
        Text(l10n.yourPaymentIsOnItsWay, style: AppText.titleM),
        AppButton(
          l10n.seeYourPayment,
          key: const ValueKey('see-payment'),
          variant: AppButtonVariant.outlined,
          onPressed: onOpen,
        ),
      ],
    );
  }
}

/// The one payment entry on H05. It asks the server switch before offering a
/// NEW payment (missing or off means nothing shows), but a payment that
/// already exists stays reachable with the switch off (spec 10).
class PayEntryCard extends StatefulWidget {
  const PayEntryCard({
    super.key,
    required this.subId,
    required this.canPay,
    required this.onPay,
    required this.onSeePayment,
    this.repository,
    this.live,
  });

  final String subId;

  /// The coach has accepted her and is waiting for the money.
  final bool canPay;
  final VoidCallback onPay;
  final ValueChanged<Payment> onSeePayment;
  final PaymentsRepository? repository;

  /// Tests pass the switch; with none, [PaymentsSwitch.live] answers.
  final bool Function()? live;

  @override
  State<PayEntryCard> createState() => _PayEntryCardState();
}

class _PayEntryCardState extends State<PayEntryCard> {
  PaymentsRepository? get _repo => widget.repository ?? PaymentsHub.repository;
  bool get _live => (widget.live ?? () => PaymentsSwitch.live)();
  Stream<List<Payment>>? _payments;

  @override
  void initState() {
    super.initState();
    if (widget.live == null) unawaited(PaymentsSwitch.load());
    final repo = _repo;
    _payments = repo?.watchMyPaymentsAsClient();
    // A proof saved for want of signal goes out when she is back at My coach.
    if (repo != null) unawaited(PendingProofs().flush(repo));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppChanges.instance,
      builder: (context, _) {
        final pay = widget.canPay && _live
            ? PayCard(onPay: widget.onPay)
            : const SizedBox.shrink();
        if (_payments == null) return pay;
        return StreamBuilder<List<Payment>>(
          stream: _payments,
          builder: (context, snap) {
            final latest = (snap.data ?? const <Payment>[])
                .where((p) => p.subId == widget.subId)
                .firstOrNull;
            if (latest != null &&
                (latest.status.settling ||
                    (latest.status.unpaid && widget.canPay && !_live))) {
              return SeePaymentCard(onOpen: () => widget.onSeePayment(latest));
            }
            return pay;
          },
        );
      },
    );
  }
}
