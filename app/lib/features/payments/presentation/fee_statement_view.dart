library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../private_coaching/presentation/desk/desk_model.dart' show tagOf;
import '../data/payments_hub.dart';
import '../data/payments_repository.dart';
import '../domain/payment_models.dart';
import 'fee_paid_sheet.dart';
import 'payment_text.dart';

/// "2026-10": the statement's month, the same in both languages.
String feeMonthLabel(FeeStatement s) =>
    '${s.year}-${s.month.toString().padLeft(2, '0')}';

/// The day a bill's fee became owed (its first line), else its month.
String feeBillTitle(AppL10n l10n, FeeStatement s) {
  final owed = s.lines.isEmpty ? null : s.lines.first.owedAt;
  return owed == null
      ? l10n.feeForMonth(feeMonthLabel(s))
      : l10n.feeBillOfDate(cairoDate(owed));
}

/// PAY9: what the coach owes Own Hub for a month, one line per payment, where
/// to pay it and the one thing she does after paying. The newest statement is
/// shown first; a tap on another month shows that one instead, so an older
/// unpaid statement can still be paid. The app debits nothing.
class FeeStatementView extends StatefulWidget {
  const FeeStatementView({
    super.key,
    this.repository,
    this.now,
    this.onBack,
    this.initialMonth,
    this.initialBill,
  });

  final PaymentsRepository? repository;

  /// "2026-10": opens that month's statement first, as a push about it does.
  final String? initialMonth;

  /// A payment id: opens the bill made for that payment first.
  final String? initialBill;
  final DateTime Function()? now;
  final VoidCallback? onBack;

  @override
  State<FeeStatementView> createState() => _FeeStatementViewState();
}

class _FeeStatementViewState extends State<FeeStatementView> {
  Stream<List<FeeStatement>>? _statements;
  String? _picked;
  bool _sheetOpen = false;

  PaymentsRepository? get _repo => widget.repository ?? PaymentsHub.repository;
  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _statements = _repo?.watchMyStatements();
  }

  /// Open and with something owed: the only state she can pay from.
  bool _payable(FeeStatement s) => s.status == 'open' && s.totalDuePiasters > 0;

  bool _late(FeeStatement s) =>
      s.status == 'open' && s.dueAt != null && !s.dueAt!.isAfter(_now);

  int _sum(FeeStatement s, String state) => s.lines
      .where((l) => l.feeState == state)
      .fold(0, (a, l) => a + l.feePiasters);

  String _stateWord(AppL10n l10n, FeeLine line) => switch (line.feeState) {
    'disputed' => l10n.disputedPending,
    'settled' => l10n.settled,
    'waived' => l10n.waived,
    _ => l10n.due,
  };

  Future<void> _copy(String address) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final copied = AppL10n.of(context).copied;
    await Clipboard.setData(ClipboardData(text: address));
    messenger?.showSnackBar(SnackBar(content: Text(copied)));
  }

  /// While the sheet is open its Send is the one filled button on screen.
  Future<void> _markPaid(FeeStatement s) async {
    final repo = _repo;
    if (repo == null || _sheetOpen) return;
    setState(() => _sheetOpen = true);
    await showFeePaidSheet(
      context: context,
      repository: repo,
      statementId: s.id,
    );
    if (mounted) setState(() => _sheetOpen = false);
  }

  Widget _amountRow(String label, String amount, Key key) => Row(
    key: key,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(child: Text(label, style: AppText.bodyM)),
      const SizedBox(width: 12),
      Text(amount, textDirection: TextDirection.ltr, style: AppText.bodyM),
    ],
  );

  Widget _card(AppL10n l10n, FeeStatement s) {
    final disputed = _sum(s, 'disputed');
    final settled = _sum(s, 'settled');
    final waived = _sum(s, 'waived');
    final due = s.dueAt;
    return AppCard(
      children: [
        Semantics(
          header: true,
          child: Text(feeBillTitle(l10n, s), style: AppText.titleM),
        ),
        Text(l10n.totalDue, style: AppText.bodyM),
        Text(
          egpText(l10n, s.totalDuePiasters),
          key: const ValueKey('fee-total'),
          textDirection: TextDirection.ltr,
          style: AppText.titleL,
        ),
        Text(l10n.paymentsCount('${s.paymentCount}'), style: AppText.bodyM),
        if (disputed > 0)
          _amountRow(
            l10n.disputedPending,
            egpText(l10n, disputed),
            const ValueKey('fee-disputed'),
          ),
        if (settled > 0)
          _amountRow(
            l10n.settled,
            egpText(l10n, settled),
            const ValueKey('fee-settled'),
          ),
        if (waived > 0)
          _amountRow(
            l10n.waived,
            egpText(l10n, waived),
            const ValueKey('fee-waived'),
          ),
        if (s.paid)
          Text(
            l10n.paidAndConfirmed,
            key: const ValueKey('fee-status'),
            style: AppText.titleM,
          )
        else if (s.status == 'paid_claimed') ...[
          Text(
            l10n.paidOwnHubWillConfirm,
            key: const ValueKey('fee-status'),
            style: AppText.titleM,
          ),
          if (s.claimedTxn.isNotEmpty)
            Text(
              s.claimedTxn,
              key: const ValueKey('fee-claimed-txn'),
              textDirection: TextDirection.ltr,
              style: AppText.bodyM,
            ),
        ] else if (s.onHold)
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.yourAccountIsOnHoldItEnds,
              key: const ValueKey('fee-hold'),
              style: AppText.bodyM.copyWith(color: AppColors.amber),
            ),
          )
        else if (_late(s))
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.thisFeeIsLateYourAccountGoes(
                cairoDate(s.holdAt ?? s.dueAt!),
              ),
              key: const ValueKey('fee-late'),
              style: AppText.bodyM.copyWith(color: AppColors.amber),
            ),
          )
        else if (due != null)
          Text(
            l10n.dueByDate(cairoDate(due)),
            key: const ValueKey('fee-due'),
            style: AppText.bodyM,
          ),
      ],
    );
  }

  List<Widget> _payBlock(AppL10n l10n, FeeStatement s) {
    final address = s.payTo.address;
    return [
      Text(l10n.payOwnHubsFeeByInstapayTo, style: AppText.bodyM),
      if (address.isEmpty)
        Text(
          l10n.ownHubWillSendYouTheAddress,
          key: const ValueKey('fee-no-address'),
          style: AppText.titleM,
        )
      else ...[
        Text(
          address,
          key: const ValueKey('fee-address'),
          textDirection: TextDirection.ltr,
          style: AppText.titleM,
        ),
        if (s.payTo.holderName.isNotEmpty)
          Text(
            l10n.accountNameName(s.payTo.holderName),
            key: const ValueKey('fee-holder'),
            style: AppText.bodyM,
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton(
            l10n.copy,
            key: const ValueKey('copy-fee-address'),
            variant: AppButtonVariant.text,
            height: 44,
            fontSize: 15,
            onPressed: () => unawaited(_copy(address)),
          ),
        ),
      ],
      if (!_late(s) && s.holdAt != null)
        Text(
          l10n.unpaidOnDateYourAccountGoesOn(cairoDate(s.holdAt!)),
          key: const ValueKey('fee-rule'),
          style: AppText.bodyM,
        ),
    ];
  }

  String _monthWord(AppL10n l10n, FeeStatement s) => switch (s.status) {
    'paid' => l10n.paid,
    'paid_claimed' => l10n.paidOwnHubWillConfirm,
    _ => l10n.due,
  };

  List<Widget> _body(AppL10n l10n, FeeStatement s, List<FeeStatement> all) {
    final others = [
      for (final o in all)
        if (o.id != s.id) o,
    ];
    return [
      _card(l10n, s),
      for (final line in s.lines)
        AppListItem(
          key: ValueKey('fee-line-${line.paymentId}'),
          title: line.reference.isEmpty
              ? tagOf(line.paymentId)
              : line.reference,
          subtitle: [
            l10n.feeFeeOnBase(
              egpText(l10n, line.feePiasters),
              egpText(l10n, line.basePiasters),
            ),
            _stateWord(l10n, line),
          ].join('\n'),
        ),
      if (_payable(s)) ..._payBlock(l10n, s),
      if (others.isNotEmpty) ...[
        Semantics(
          header: true,
          child: Text(l10n.otherMonths, style: AppText.titleL),
        ),
        for (final o in others)
          AppListItem(
            key: ValueKey('month-${o.id}'),
            title: o.lines.isEmpty || o.lines.first.owedAt == null
                ? feeMonthLabel(o)
                : cairoDate(o.lines.first.owedAt!),
            subtitle:
                '${egpText(l10n, o.totalDuePiasters)} · ${_monthWord(l10n, o)}',
            onTap: () => setState(() => _picked = o.id),
          ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return StreamBuilder<List<FeeStatement>>(
      stream: _statements,
      builder: (context, snap) {
        final all = snap.data;
        final shown = all == null || all.isEmpty
            ? null
            : all.firstWhere(
                (s) => s.id == _picked,
                orElse: () => all.firstWhere(
                  (s) =>
                      widget.initialBill != null &&
                      s.id.endsWith('__${widget.initialBill}'),
                  orElse: () => all.firstWhere(
                    (s) => feeMonthLabel(s) == widget.initialMonth,
                    orElse: () => all.first,
                  ),
                ),
              );
        final Widget top;
        if (snap.hasError) {
          final e = snap.error;
          top = Semantics(
            liveRegion: true,
            child: Text(
              e is PaymentFailure
                  ? coachPaymentFailureText(l10n, e)
                  : l10n.weCouldNotDoThatTryAgain,
              key: const ValueKey('statements-failure'),
              style: AppText.bodyM,
            ),
          );
        } else if (all == null) {
          top = const Center(child: CircularProgressIndicator());
        } else if (shown == null) {
          top = AppSageNote(l10n.noFeeBillYetOneIsMade);
        } else {
          top = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: kStackGap,
            children: _body(l10n, shown, all),
          );
        }
        return AppScaffold(
          showArt: false,
          appBar: AppTopBar(
            title: l10n.feeBills,
            onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
          ),
          footer: [
            if (shown != null && _payable(shown))
              AppButton(
                l10n.markFeeAsPaid,
                key: const ValueKey('mark-fee'),
                onPressed: _sheetOpen
                    ? null
                    : () => unawaited(_markPaid(shown)),
              ),
          ],
          children: [top],
        );
      },
    );
  }
}
