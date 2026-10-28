library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_scaffold.dart';
import '../data/payments_hub.dart';
import '../data/payments_repository.dart';
import '../domain/payment_models.dart';
import '../domain/payments_rules.dart';
import 'payment_text.dart';

/// PAY8: what a woman can raise about a payment that was paid. [dispute] null
/// is "Ask for a refund": nothing to write, the server takes only the payment.
/// Otherwise it is a problem that goes to Own Hub with her note (the server
/// keeps it for staff, not for the coach): the service, a refund her coach
/// refused, or a refund that never arrived.
class PaymentProblemView extends StatefulWidget {
  const PaymentProblemView({
    super.key,
    required this.payment,
    this.dispute,
    this.repository,
  });

  final Payment payment;
  final DisputeKind? dispute;
  final PaymentsRepository? repository;

  @override
  State<PaymentProblemView> createState() => _PaymentProblemViewState();
}

class _PaymentProblemViewState extends State<PaymentProblemView> {
  final _note = TextEditingController();
  bool _busy = false;
  String _error = '';

  PaymentsRepository? get _repo => widget.repository ?? PaymentsHub.repository;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _ready =>
      !_busy &&
      _repo != null &&
      (widget.dispute == null || validProblemNote(_note.text));

  Future<void> _send() async {
    final repo = _repo;
    if (repo == null || _busy) return;
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (widget.dispute == null) {
        await repo.requestRefund(widget.payment.id);
      } else {
        await repo.openServiceDispute(
          widget.payment.id,
          note: _note.text.trim(),
        );
      }
    } on PaymentFailure catch (f) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = paymentFailureText(l10n, f);
        });
      }
      return;
    }
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          widget.dispute == null
              ? l10n.sentYourCoachHasNDaysTo(kRefundCoachDays.toString())
              : l10n.sentOwnHubWillLookAtIt,
        ),
      ),
    );
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final dispute = widget.dispute;
    final title = switch (dispute) {
      null => l10n.askForARefund,
      DisputeKind.service => l10n.serviceProblem,
      DisputeKind.refund => l10n.askOwnHubToLookAgain,
      DisputeKind.refundNotReceived => l10n.refundProblem,
    };
    final intro = switch (dispute) {
      null => l10n.youCanAskOnceInTheFirst(
        kRefundWindowDays.toString(),
        kRefundCoachDays.toString(),
      ),
      DisputeKind.service => l10n.tellUsWhatWentWrongOwnHub,
      DisputeKind.refund => l10n.yourCoachDidNotAgreeToThe,
      DisputeKind.refundNotReceived => l10n.yourCoachSaysSheSentTheMoney,
    };
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: title,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      footer: [
        AppButton(
          dispute == null ? l10n.askForARefund : l10n.send,
          key: const ValueKey('problem-send'),
          onPressed: _ready ? () => unawaited(_send()) : null,
        ),
      ],
      children: [
        Text(intro, key: const ValueKey('problem-intro'), style: AppText.bodyM),
        if (dispute == null)
          Text(l10n.ownHubDoesNotMoveMoneyIf, style: AppText.bodyM)
        else
          AppField(
            key: const ValueKey('problem-note'),
            controller: _note,
            label: l10n.tellUsMore,
            maxLines: 3,
            inputFormatters: [LengthLimitingTextInputFormatter(300)],
            onChanged: (_) => setState(() {}),
          ),
        if (_error.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              _error,
              key: const ValueKey('problem-error'),
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
