library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart' show kStackGap;
import '../data/payments_repository.dart';
import '../domain/payment_models.dart';
import '../domain/payments_rules.dart';
import 'payment_text.dart';
import 'record_refund_sheet.dart';

/// The "Refund requests" part of the coach's payments inbox: payments in
/// `refund_requested`, each with when it was asked and the day her answer is
/// due (`refund.coachDueAt`, then it goes to staff). A tap opens the sheet to
/// record the refund or to say she does not agree. A refund staff ordered
/// (`Payment.refundOwed`) is listed too, with the sum and the day it is due;
/// there she can only record it. A refunded payment is final and is not
/// listed here.
class RefundRequestsSection extends StatelessWidget {
  const RefundRequestsSection({
    super.key,
    required this.requests,
    required this.repository,
    required this.nameOf,
    required this.now,
  });

  final List<Payment> requests;
  final PaymentsRepository? repository;
  final String Function(Payment) nameOf;
  final DateTime Function() now;

  String _asked(AppL10n l10n, Payment p) {
    if (p.refundOwed) {
      final due = p.refundOwedDueAt;
      if (due == null) return '';
      return now().isAfter(due)
          ? l10n.ownHubDecidedYouOweARefund_c85m6(cairoDate(due))
          : l10n.ownHubDecidedYouOweARefund(cairoDate(due));
    }
    final asked = p.refundRequestedAt;
    if (asked == null) return '';
    final due =
        p.refundCoachDueAt ?? asked.add(const Duration(days: kRefundCoachDays));
    return now().isAfter(due)
        ? l10n.askedTimeTheAnswerWasDueDate(cairoStamp(asked), cairoStamp(due))
        : l10n.askedTimeAnswerByDate(cairoStamp(asked), cairoStamp(due));
  }

  Future<void> _open(BuildContext context, Payment p) async {
    final repo = repository;
    if (repo == null) return;
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final done = await showRecordRefundSheet(
      context: context,
      repository: repo,
      payment: p,
      clientName: nameOf(p),
      now: now,
    );
    if (done == true) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.sentYourClientWillSeeIt)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) return const SizedBox.shrink();
    final l10n = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: kStackGap,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.refundRequests, style: AppText.titleL),
        ),
        for (final p in requests)
          AppListItem(
            key: ValueKey('refund-${p.id}'),
            title: nameOf(p),
            subtitle: [
              '${p.reference} · ${egpText(l10n, p.refundOwed ? p.refundOwedPiasters : p.amountPiasters)}',
              _asked(l10n, p),
            ].where((s) => s.isNotEmpty).join('\n'),
            onTap: () => unawaited(_open(context, p)),
          ),
      ],
    );
  }
}
