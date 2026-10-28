library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_sheet.dart';
import '../data/payments_repository.dart';
import '../domain/payment_models.dart';
import 'payment_text.dart';

/// A payment a coach can say was paid: nothing sent yet, and the late proof
/// window is still open (a payment with no window is refused). These are
/// the ones the server finds.
bool coachCanReport(Payment p, DateTime now) =>
    p.status.unpaid &&
    p.coachReportTxn.isEmpty &&
    p.lateUntil != null &&
    !p.lateUntil!.isBefore(now);

/// Spec 4.5: "A client paid me". She picks the payment and types the number
/// from her bank; the client is asked to confirm. True when it was sent.
Future<bool?> showClientPaidSheet({
  required BuildContext context,
  required PaymentsRepository repository,
  required List<Payment> payments,
  required String Function(Payment) nameOf,
}) => showAppSheet<bool>(
  context: context,
  children: [
    _ClientPaidBody(repository: repository, payments: payments, nameOf: nameOf),
  ],
);

class _ClientPaidBody extends StatefulWidget {
  const _ClientPaidBody({
    required this.repository,
    required this.payments,
    required this.nameOf,
  });

  final PaymentsRepository repository;
  final List<Payment> payments;
  final String Function(Payment) nameOf;

  @override
  State<_ClientPaidBody> createState() => _ClientPaidBodyState();
}

class _ClientPaidBodyState extends State<_ClientPaidBody> {
  final _txn = TextEditingController();
  String? _picked;
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _txn.dispose();
    super.dispose();
  }

  /// The same rule as the client's proof: six letters or digits at least.
  bool get _txnOk =>
      _txn.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length >= 6;

  Future<void> _send() async {
    final l10n = AppL10n.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await widget.repository.coachReport(
        reference: _picked,
        txnNumber: _txn.text.trim(),
      );
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.sentYourClientWillBeAskedTo)),
      );
      nav.pop(true);
    } on PaymentFailure catch (f) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = coachPaymentFailureText(l10n, f);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final ready = _picked != null && _txnOk && !_busy;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.aClientPaidMe, style: AppText.titleL),
          ),
          if (widget.payments.isEmpty)
            AppSageNote(l10n.noClientHasAnOpenPaymentRight)
          else ...[
            Text(
              l10n.pickThePaymentThenTypeTheTransaction,
              style: AppText.bodyM,
            ),
            for (final p in widget.payments)
              AppListItem(
                key: ValueKey('report-${p.id}'),
                title: widget.nameOf(p),
                subtitle: '${p.reference} · ${egpText(l10n, p.amountPiasters)}',
                variant: _picked == p.reference
                    ? AppCardVariant.selected
                    : AppCardVariant.outlined,
                onTap: () => setState(() => _picked = p.reference),
              ),
            AppField(
              controller: _txn,
              label: l10n.transactionNumber,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (_error.isNotEmpty)
            Semantics(
              liveRegion: true,
              child: Text(
                _error,
                key: const ValueKey('report-error'),
                style: AppText.bodyM.copyWith(color: AppColors.error),
              ),
            ),
          AppButton(
            l10n.send,
            key: const ValueKey('report-send'),
            onPressed: ready ? () => unawaited(_send()) : null,
          ),
        ],
      ),
    );
  }
}
