library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_sheet.dart';
import '../data/payments_repository.dart';
import '../domain/payment_models.dart';
import '../domain/payments_rules.dart';
import '../domain/receipt_reader.dart' show normalizeDigits;
import 'payment_text.dart';

/// PAY8, coach side: she sent the money back by InstaPay and writes it down
/// (amount, the bank's transaction number), or says she does not agree. Own
/// Hub moves nothing. True when either was sent. A refund staff ordered
/// (`payment.refundOwed`) is for the sum they named: it is shown, not typed,
/// and there is no way to disagree.
Future<bool?> showRecordRefundSheet({
  required BuildContext context,
  required PaymentsRepository repository,
  required Payment payment,
  required String clientName,
  DateTime Function()? now,
}) => showAppSheet<bool>(
  context: context,
  children: [
    _RefundBody(
      repository: repository,
      payment: payment,
      clientName: clientName,
      now: now ?? DateTime.now,
    ),
  ],
);

class _RefundBody extends StatefulWidget {
  const _RefundBody({
    required this.repository,
    required this.payment,
    required this.clientName,
    required this.now,
  });

  final PaymentsRepository repository;
  final Payment payment;
  final String clientName;
  final DateTime Function() now;

  @override
  State<_RefundBody> createState() => _RefundBodyState();
}

class _RefundBodyState extends State<_RefundBody> {
  late final TextEditingController _amount = TextEditingController(
    text: egpPlain(_full),
  );
  final _txn = TextEditingController();
  String? _reason;
  bool _denying = false;
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _amount.dispose();
    _txn.dispose();
    super.dispose();
  }

  /// What she received, never more than the payment: a full refund. The
  /// server marks a smaller sum as partial by itself.
  int get _full {
    final p = widget.payment;
    final got = p.receivedPiasters ?? p.amountPiasters;
    return got < p.amountPiasters ? got : p.amountPiasters;
  }

  bool get _owed => widget.payment.refundOwed;

  int? get _entered => _owed
      ? widget.payment.refundOwedPiasters
      : parseAmountPiasters(_amount.text);

  bool get _amountOk => _owed || (_entered != null && _entered! <= _full);

  bool get _recordReady => _amountOk && validRefundTxn(_txn.text) && !_busy;

  Future<void> _run(
    Future<Object?> Function() call,
    String Function(AppL10n, PaymentFailure) failureText,
  ) async {
    final l10n = AppL10n.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await call();
    } on PaymentFailure catch (f) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failureText(l10n, f);
        });
      }
      return;
    }
    nav.pop(true);
  }

  Future<void> _record() => _run(
    () => widget.repository.recordRefund(
      paymentId: widget.payment.id,
      txnNumber: normalizeDigits(_txn.text).trim(),
      amountPiasters: _entered!,
      kind: 'refund',
      paidAt: widget.now().toUtc(),
    ),
    refundFailureText,
  );

  Future<void> _deny() => _run(
    () => widget.repository.denyRefund(widget.payment.id, reasonCode: _reason!),
    coachPaymentFailureText,
  );

  String _reasonText(AppL10n l, String code) => switch (code) {
    'sessions_delivered' => l.iAlreadyGaveTheSessions,
    'outside_terms' => l.itIsOutsideTheTerms,
    _ => l.anotherReason,
  };

  List<Widget> _recordFields(AppL10n l10n) {
    final p = widget.payment;
    final entered = _entered;
    return [
      Semantics(
        header: true,
        child: Text(l10n.recordRefund, style: AppText.titleL),
      ),
      Text(
        '${widget.clientName} · ${p.reference} · ${egpText(l10n, p.amountPiasters)}',
        style: AppText.titleM,
      ),
      Text(l10n.sendTheMoneyBackToYourClient, style: AppText.bodyM),
      if (_owed) ...[
        Text(l10n.amountSentBackEgp, style: AppText.bodyM),
        Text(
          egpPlain(p.refundOwedPiasters),
          key: const ValueKey('refund-owed-amount'),
          textDirection: TextDirection.ltr,
          style: AppText.titleL,
        ),
        Text(l10n.ownHubSetThisAmount, style: AppText.bodyM),
      ] else
        AppField(
          key: const ValueKey('refund-amount'),
          controller: _amount,
          label: l10n.amountSentBackEgp,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          onChanged: (_) => setState(() {}),
        ),
      if (!_owed && _amountOk && entered! < _full)
        Text(
          l10n.partOfThePaymentAmountOfTotal(
            egpText(l10n, entered),
            egpText(l10n, _full),
          ),
          key: const ValueKey('refund-partial'),
          style: AppText.bodyM,
        ),
      AppField(
        key: const ValueKey('refund-txn'),
        controller: _txn,
        label: l10n.transactionNumber,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        onChanged: (_) => setState(() {}),
      ),
      if (_error.isNotEmpty) _errorLine(),
      AppButton(
        l10n.recordRefund,
        key: const ValueKey('record-refund'),
        onPressed: _recordReady ? () => unawaited(_record()) : null,
      ),
      if (!_owed)
        AppButton(
          l10n.iDoNotAgreeToThisRefund,
          key: const ValueKey('deny-refund'),
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: _busy
              ? null
              : () => setState(() {
                  _denying = true;
                  _error = '';
                }),
        ),
    ];
  }

  List<Widget> _denyFields(AppL10n l10n) => [
    Semantics(
      header: true,
      child: Text(l10n.whyDoYouNotAgree, style: AppText.titleL),
    ),
    Text(l10n.yourClientCanThenAskOwnHub, style: AppText.bodyM),
    for (final code in kDenyReasons)
      AppListItem(
        key: ValueKey('deny-$code'),
        title: _reasonText(l10n, code),
        variant: _reason == code
            ? AppCardVariant.selected
            : AppCardVariant.outlined,
        onTap: () => setState(() => _reason = code),
      ),
    if (_error.isNotEmpty) _errorLine(),
    AppButton(
      l10n.send,
      key: const ValueKey('deny-send'),
      variant: AppButtonVariant.outlined,
      height: 48,
      onPressed: _reason != null && !_busy ? () => unawaited(_deny()) : null,
    ),
    AppButton(
      l10n.cancel,
      key: const ValueKey('deny-back'),
      variant: AppButtonVariant.text,
      height: 44,
      fontSize: 15,
      onPressed: _busy
          ? null
          : () => setState(() {
              _denying = false;
              _error = '';
            }),
    ),
  ];

  Widget _errorLine() => Semantics(
    liveRegion: true,
    child: Text(
      _error,
      key: const ValueKey('refund-error'),
      style: AppText.bodyM.copyWith(color: AppColors.error),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: _denying ? _denyFields(l10n) : _recordFields(l10n),
      ),
    );
  }
}
