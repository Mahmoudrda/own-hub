library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app_state/app_changes.dart';
import '../../../app_state/private_coaching_state.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chevron.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_overflow_menu.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../private_coaching/presentation/coach/coach_widgets.dart'
    show CoachFieldError, CoachSwitchRow;
import '../../private_coaching/presentation/desk/desk_model.dart' show tagOf;
import '../../private_coaching/presentation/desk/desk_text.dart'
    show clientName;
import '../data/payments_hub.dart';
import '../data/payments_repository.dart';
import '../data/proof_images.dart';
import '../domain/payment_models.dart';
import '../domain/payments_rules.dart';
import 'client_paid_sheet.dart';
import 'coach_decision_view.dart';
import 'payment_address_view.dart';
import 'payment_alerts_card.dart';
import 'payment_decision_sheet.dart';
import 'payment_record_view.dart';
import 'payment_text.dart';
import 'proof_flow.dart';
import 'refund_requests_section.dart';
import 'status_text.dart';

/// How many settled payments the inbox keeps in view under "Earlier".
const int kEarlierShown = 10;

/// PAY4: the payments waiting for the coach's answer, then the last few that
/// are not. A coach keeps this even while new payments are paused: it only
/// answers what is already open.
class CoachPaymentsView extends StatefulWidget {
  const CoachPaymentsView({
    super.key,
    this.repository,
    this.coaching,
    this.picker = pickProofImages,
    this.prepare = prepareProofImage,
    this.now,
    this.onBack,
    this.alerts,
  });

  final PaymentsRepository? repository;

  /// Where "turn on payment alerts" comes from; the app's own by default.
  final PaymentAlertsAccess? alerts;

  /// Where her clients' names come from; the app's own by default.
  final PrivateCoachingState? coaching;
  final Future<List<Uint8List>> Function() picker;
  final PrepareImage prepare;
  final DateTime Function()? now;
  final VoidCallback? onBack;

  @override
  State<CoachPaymentsView> createState() => _CoachPaymentsViewState();
}

class _CoachPaymentsViewState extends State<CoachPaymentsView> {
  Stream<List<Payment>>? _payments;
  Stream<CoachAddress?>? _address;
  List<Payment> _latest = const <Payment>[];
  bool _autoOpened = false;
  bool? _autoOn;
  bool _autoBusy = false;
  String _autoError = '';

  PaymentsRepository? get _repo => widget.repository ?? PaymentsHub.repository;
  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final repo = _repo;
    if (repo != null) {
      _payments = repo.watchMyPaymentsAsCoach();
      _address = repo.watchMyAddress();
    }
  }

  String _name(AppL10n l10n, Payment p) {
    final coaching = widget.coaching ?? PrivateCoachingState.instance;
    for (final s in coaching.coachSubscriptions) {
      if (s.id == p.subId) return clientName(l10n, s);
    }
    return l10n.clientTag(tagOf(p.clientUid));
  }

  void _openAddress() => unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PaymentAddressView(repository: widget.repository),
      ),
    ),
  );

  Future<void> _open(Payment p) async {
    final repo = _repo;
    if (repo == null) return;
    final l10n = AppL10n.of(context);
    final choice = await showPaymentDecisionSheet(
      context: context,
      repository: repo,
      payment: p,
      clientName: _name(l10n, p),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case DecisionChoice.confirmed:
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(l10n.confirmedYourClientCanStart)),
        );
      case DecisionChoice.notReceived:
        _push(p, DecisionMode.notReceived);
      case DecisionChoice.differentAmount:
        _push(p, DecisionMode.differentAmount);
    }
  }

  void _push(Payment p, DecisionMode mode) => unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CoachDecisionView(
          payment: p,
          mode: mode,
          repository: widget.repository,
          picker: widget.picker,
          prepare: widget.prepare,
          now: widget.now,
        ),
      ),
    ),
  );

  /// PAY10: the record of a confirmed payment, to save or share.
  void _record(Payment p) => unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => PaymentRecordView(payment: p)),
    ),
  );

  void _reportPaid() {
    final repo = _repo;
    if (repo == null) return;
    final l10n = AppL10n.of(context);
    unawaited(
      showClientPaidSheet(
        context: context,
        repository: repo,
        payments: [
          for (final p in _latest)
            if (coachCanReport(p, _now)) p,
        ],
        nameOf: (p) => _name(l10n, p),
      ),
    );
  }

  Future<void> _toggleAuto(bool value) async {
    final repo = _repo;
    if (repo == null || _autoBusy) return;
    final l10n = AppL10n.of(context);
    setState(() {
      _autoBusy = true;
      _autoError = '';
      _autoOn = value;
    });
    try {
      await repo.setAutoConfirm(value);
    } on PaymentFailure catch (f) {
      if (mounted) {
        setState(() {
          _autoOn = null;
          _autoError = autoConfirmFailureText(l10n, f);
        });
      }
    } finally {
      if (mounted) setState(() => _autoBusy = false);
    }
  }

  String _failureLine(AppL10n l10n, Object? error) => error is PaymentFailure
      ? coachPaymentFailureText(l10n, error)
      : l10n.weCouldNotDoThatTryAgain;

  Widget _row(AppL10n l10n, Payment p, {required bool waiting}) {
    final amount = egpText(l10n, p.amountPiasters);
    final sent = p.submittedAt;
    // A payment that confirmed itself can still be flagged for 48 hours.
    final flaggable =
        !waiting &&
        p.canFlagAutoConfirmed(
          _now,
          const Duration(hours: kAutoConfirmFlagHours),
        );
    return AppListItem(
      key: ValueKey('${waiting ? 'waiting' : 'earlier'}-${p.id}'),
      title: _name(l10n, p),
      subtitle: waiting
          ? (sent == null
                ? '${p.reference} · $amount'
                : l10n.referenceAmountProofSentTime(
                    p.reference,
                    amount,
                    cairoStamp(sent),
                  ))
          : '${p.reference} · $amount · ${coachStatusWord(l10n, p)}',
      trailing: waiting
          ? (p.outcome == RiskOutcome.green
                ? AppPill(l10n.matches)
                : AppPill(
                    l10n.checkYourBank,
                    background: AppColors.amberContainer,
                    foreground: AppColors.amber,
                  ))
          : (flaggable || p.status.activatesPackage
                ? const AppChevron()
                : null),
      onTap: waiting
          ? () => unawaited(_open(p))
          : (flaggable
                ? () => _push(p, DecisionMode.notReceived)
                : (p.status.activatesPackage ? () => _record(p) : null)),
    );
  }

  Widget _body(
    AppL10n l10n,
    AsyncSnapshot<CoachAddress?> a,
    AsyncSnapshot<List<Payment>> ps,
  ) {
    if (ps.hasError) {
      return Semantics(
        liveRegion: true,
        child: Text(
          _failureLine(l10n, ps.error),
          key: const ValueKey('coach-payments-failure'),
          style: AppText.bodyM,
        ),
      );
    }
    final data = ps.data;
    if (data == null) return const Center(child: CircularProgressIndicator());
    _latest = data;
    final waiting =
        data.where((p) => p.status == PaymentStatus.proofSubmitted).toList()
          ..sort(
            (x, y) => (x.submittedAt ?? DateTime(0)).compareTo(
              y.submittedAt ?? DateTime(0),
            ),
          );
    final earlier = data
        .where(
          (p) =>
              p.status != PaymentStatus.proofSubmitted &&
              p.status != PaymentStatus.refundRequested &&
              !p.refundOwed &&
              !p.status.unpaid &&
              p.status != PaymentStatus.cancelled,
        )
        .take(kEarlierShown)
        .toList();
    if (!_autoOpened && waiting.length == 1) {
      _autoOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_open(waiting.single));
      });
    }
    final address = a.data;
    final noAddress =
        a.connectionState != ConnectionState.waiting &&
        (address == null || address.isEmpty);
    final autoOn = _autoOn ?? address?.autoConfirmGreen ?? false;
    final autoEligible =
        (address?.cleanConfirmed ?? 0) >= kCleanPaymentsForAutoConfirm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: kStackGap,
      children: [
        if (noAddress)
          AppCard(
            variant: AppCardVariant.tonal,
            children: [
              Text(
                l10n.addYourInstapayAddressSoClientsCan,
                style: AppText.bodyM,
              ),
              AppButton(
                l10n.addAddress,
                key: const ValueKey('add-address'),
                variant: AppButtonVariant.outlined,
                height: 48,
                onPressed: _openAddress,
              ),
            ],
          ),
        Semantics(
          header: true,
          child: Text(l10n.waitingForYou, style: AppText.titleL),
        ),
        if (waiting.isEmpty)
          AppSageNote(l10n.nothingIsWaitingForYou)
        else
          for (final p in waiting) _row(l10n, p, waiting: true),
        PaymentAlertsCard(who: PaymentAlertsFor.coach, access: widget.alerts),
        RefundRequestsSection(
          requests: [
            for (final p in data)
              if (p.status == PaymentStatus.refundRequested || p.refundOwed) p,
          ],
          repository: _repo,
          nameOf: (p) => _name(l10n, p),
          now: () => _now,
        ),
        if (earlier.isNotEmpty) ...[
          Semantics(
            header: true,
            child: Text(l10n.earlier, style: AppText.titleL),
          ),
          for (final p in earlier) _row(l10n, p, waiting: false),
        ],
        if (autoEligible || autoOn)
          CoachSwitchRow(
            key: const ValueKey('auto-confirm'),
            title: l10n.confirmMatchingPaymentsForMe,
            subtitle: l10n.onlyPaymentsThatMatchYouCanStill(
              kAutoConfirmFlagHours.toString(),
            ),
            value: autoOn,
            onChanged: _autoBusy ? null : (v) => unawaited(_toggleAuto(v)),
          ),
        if (_autoError.isNotEmpty) CoachFieldError(_autoError),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: l10n.payments,
        onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
        actions: [
          AppOverflowMenu(
            items: [
              AppOverflowItem(
                icon: Icons.account_balance_wallet_outlined,
                label: l10n.myInstapayAddress,
                onTap: _openAddress,
              ),
              AppOverflowItem(
                icon: Icons.payments_outlined,
                label: l10n.aClientPaidMe,
                onTap: _reportPaid,
              ),
            ],
          ),
        ],
      ),
      children: [
        if (_payments == null || _address == null)
          const Center(child: CircularProgressIndicator())
        else
          ListenableBuilder(
            listenable: AppChanges.instance,
            builder: (context, _) => StreamBuilder<CoachAddress?>(
              stream: _address,
              builder: (context, a) => StreamBuilder<List<Payment>>(
                stream: _payments,
                builder: (context, ps) => _body(l10n, a, ps),
              ),
            ),
          ),
      ],
    );
  }
}
