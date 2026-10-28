library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_sheet.dart';
import '../data/payments_repository.dart';
import '../domain/payment_models.dart';
import 'payment_text.dart';

/// What she chose on the sheet. [confirmed] is already done when it closes;
/// the other two hand over to PAY5.
enum DecisionChoice { confirmed, notReceived, differentAmount }

/// PAY5, the first step: what to look for in her bank and the three answers.
/// "I received it" is the one filled primary.
Future<DecisionChoice?> showPaymentDecisionSheet({
  required BuildContext context,
  required PaymentsRepository repository,
  required Payment payment,
  required String clientName,
}) => showAppSheet<DecisionChoice>(
  context: context,
  children: [
    _DecisionBody(
      repository: repository,
      payment: payment,
      clientName: clientName,
    ),
  ],
);

class _DecisionBody extends StatefulWidget {
  const _DecisionBody({
    required this.repository,
    required this.payment,
    required this.clientName,
  });

  final PaymentsRepository repository;
  final Payment payment;
  final String clientName;

  @override
  State<_DecisionBody> createState() => _DecisionBodyState();
}

class _DecisionBodyState extends State<_DecisionBody> {
  bool _busy = false;
  bool _loadingProof = false;
  bool _proofShown = false;
  bool _proofFailed = false;
  String _error = '';
  final List<Uint8List> _pictures = <Uint8List>[];

  Future<void> _confirm() async {
    final l10n = AppL10n.of(context);
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await widget.repository.coachConfirm(widget.payment.id);
      if (mounted) Navigator.of(context).pop(DecisionChoice.confirmed);
    } on PaymentFailure catch (f) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = coachPaymentFailureText(l10n, f);
        });
      }
    }
  }

  /// Her pictures come through the server one by one, only when asked for.
  Future<void> _showProof() async {
    setState(() => _loadingProof = true);
    final got = <Uint8List>[];
    var failed = false;
    for (final path in widget.payment.screenshotPaths) {
      try {
        final bytes = await widget.repository.partyImage(
          paymentId: widget.payment.id,
          path: path,
        );
        if (bytes.isEmpty) {
          failed = true;
        } else {
          got.add(bytes);
        }
      } on PaymentFailure {
        failed = true;
      }
    }
    if (!mounted) return;
    setState(() {
      _loadingProof = false;
      _proofShown = true;
      _proofFailed = failed;
      _pictures
        ..clear()
        ..addAll(got);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final p = widget.payment;
    final paidAt = p.paidAtClaimed;
    final green = p.outcome == RiskOutcome.green;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.paymentReference(p.reference),
              textDirection: TextDirection.ltr,
              style: AppText.titleL,
            ),
          ),
          Text(widget.clientName, style: AppText.bodyM),
          Text(
            l10n.lookForExactlyAmount(egpText(l10n, p.amountPiasters)),
            key: const ValueKey('look-for'),
            style: AppText.titleM,
          ),
          if (p.txnNumber.isNotEmpty)
            Text(
              l10n.transactionNumberTxn(p.txnNumber),
              key: const ValueKey('sheet-txn'),
              textDirection: TextDirection.ltr,
              style: AppText.bodyM,
            ),
          if (paidAt != null)
            Text(
              l10n.paidAtTime(cairoStamp(paidAt)),
              key: const ValueKey('sheet-paid-at'),
              style: AppText.bodyM,
            ),
          AppCard(
            variant: green ? AppCardVariant.sage : AppCardVariant.amber,
            children: [
              Text(
                green
                    ? l10n.herProofLooksRightStillCheckYour
                    : l10n.partOfHerProofDidNotMatch,
                key: ValueKey(green ? 'sheet-green' : 'sheet-amber'),
                style: AppText.bodyM,
              ),
            ],
          ),
          if (p.screenshotPaths.isNotEmpty && !_proofShown)
            AppButton(
              l10n.seeHerProof,
              key: const ValueKey('see-proof'),
              variant: AppButtonVariant.outlined,
              height: 48,
              onPressed: _loadingProof ? null : () => unawaited(_showProof()),
            ),
          for (final bytes in _pictures)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.memory(
                bytes,
                key: const ValueKey('proof-picture'),
                fit: BoxFit.fitWidth,
                semanticLabel: l10n.seeHerProof,
                errorBuilder: (_, _, _) =>
                    Text(l10n.weCouldNotLoadThisPicture, style: AppText.bodyM),
              ),
            ),
          if (_proofFailed)
            Text(
              l10n.weCouldNotLoadThisPicture,
              key: const ValueKey('proof-failed'),
              style: AppText.bodyM,
            ),
          if (_error.isNotEmpty)
            Semantics(
              liveRegion: true,
              child: Text(
                _error,
                key: const ValueKey('sheet-error'),
                style: AppText.bodyM.copyWith(color: AppColors.error),
              ),
            ),
          AppButton(
            l10n.iReceivedIt,
            key: const ValueKey('received'),
            onPressed: _busy ? null : () => unawaited(_confirm()),
          ),
          AppButton(
            l10n.notReceived,
            key: const ValueKey('not-received'),
            variant: AppButtonVariant.outlined,
            height: 48,
            onPressed: _busy
                ? null
                : () => Navigator.of(context).pop(DecisionChoice.notReceived),
          ),
          AppButton(
            l10n.differentAmount,
            key: const ValueKey('different-amount'),
            variant: AppButtonVariant.text,
            height: 44,
            fontSize: 15,
            onPressed: _busy
                ? null
                : () =>
                      Navigator.of(context).pop(DecisionChoice.differentAmount),
          ),
        ],
      ),
    );
  }
}
