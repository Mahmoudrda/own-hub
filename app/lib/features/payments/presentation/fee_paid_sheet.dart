library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_sheet.dart';
import '../data/payments_repository.dart';
import '../domain/payments_rules.dart';
import '../domain/receipt_reader.dart' show normalizeDigits;
import 'payment_text.dart';

/// PAY9: she paid Own Hub's fee by InstaPay and writes down the bank's
/// transaction number. Own Hub confirms it later; nothing is debited. True
/// when it was recorded.
Future<bool?> showFeePaidSheet({
  required BuildContext context,
  required PaymentsRepository repository,
  required String statementId,
}) => showAppSheet<bool>(
  context: context,
  children: [_FeePaidBody(repository: repository, statementId: statementId)],
);

class _FeePaidBody extends StatefulWidget {
  const _FeePaidBody({required this.repository, required this.statementId});

  final PaymentsRepository repository;
  final String statementId;

  @override
  State<_FeePaidBody> createState() => _FeePaidBodyState();
}

class _FeePaidBodyState extends State<_FeePaidBody> {
  final _txn = TextEditingController();
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _txn.dispose();
    super.dispose();
  }

  /// Six letters or digits at least, as the server reads them.
  bool get _txnOk => refundTxnKey(_txn.text).length >= 6;

  Future<void> _send() async {
    final l10n = AppL10n.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await widget.repository.recordFeePayment(
        statementId: widget.statementId,
        txnNumber: normalizeDigits(_txn.text).trim(),
      );
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.recordedOwnHubWillConfirmIt)),
      );
      nav.pop(true);
    } on PaymentFailure catch (f) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = feeFailureText(l10n, f);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.markFeeAsPaid, style: AppText.titleL),
          ),
          Text(
            l10n.useTheTransactionNumberFromYourInstapay,
            style: AppText.bodyM,
          ),
          AppField(
            key: const ValueKey('fee-txn'),
            controller: _txn,
            label: l10n.transactionNumber,
            keyboardType: TextInputType.text,
            textDirection: TextDirection.ltr,
            onChanged: (_) => setState(() {}),
          ),
          if (_error.isNotEmpty)
            Semantics(
              liveRegion: true,
              child: Text(
                _error,
                key: const ValueKey('fee-error'),
                style: AppText.bodyM.copyWith(color: AppColors.error),
              ),
            ),
          AppButton(
            l10n.send,
            key: const ValueKey('fee-send'),
            onPressed: _txnOk && !_busy ? () => unawaited(_send()) : null,
          ),
        ],
      ),
    );
  }
}
