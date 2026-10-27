library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../../events/domain/cairo_time.dart';
import '../data/payments_hub.dart';
import '../data/payments_repository.dart';
import '../data/pending_proofs.dart';
import '../domain/payment_models.dart';
import 'payment_text.dart';
import 'status_text.dart';

/// What the one primary does for the current state. [agree] is answered on
/// the screen itself; the rest hand over to the router.
enum StatusAction { pay, sendProof, payRest, addProof, openCoaching, agree }

/// PAY3: where her payment is, what happens next, and the one thing she can
/// do. Refreshes on open (Firestore pushes every change as it happens).
class PaymentStatusView extends StatefulWidget {
  const PaymentStatusView({
    super.key,
    required this.paymentId,
    required this.onAction,
    this.repository,
    this.now,
    this.onBack,
  });

  final String paymentId;
  final void Function(StatusAction action, Payment payment) onAction;
  final PaymentsRepository? repository;
  final DateTime Function()? now;
  final VoidCallback? onBack;

  @override
  State<PaymentStatusView> createState() => _PaymentStatusViewState();
}

class _PaymentStatusViewState extends State<PaymentStatusView> {
  String _error = '';
  bool _busy = false;
  Stream<Payment?>? _payment;
  Stream<List<PaymentEvent>>? _events;

  PaymentsRepository? get _repo => widget.repository ?? PaymentsHub.repository;
  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final repo = _repo;
    if (repo != null) {
      _payment = repo.watchPayment(widget.paymentId);
      _events = repo.watchEvents(widget.paymentId);
      unawaited(PendingProofs().flush(repo));
    }
  }

  StatusAction? _action(Payment p) {
    if (p.coachAsks) return null;
    switch (p.status) {
      case PaymentStatus.awaitingPayment:
        return StatusAction.pay;
      case PaymentStatus.expired:
        return p.canSendProof(_now) ? StatusAction.sendProof : null;
      case PaymentStatus.differentAmount:
        return p.acceptLower ? StatusAction.agree : StatusAction.payRest;
      case PaymentStatus.coachNotReceived:
      case PaymentStatus.inReview:
        return disputeAsksForProof(p) ? StatusAction.addProof : null;
      case PaymentStatus.confirmed:
      case PaymentStatus.resolvedPaid:
        return StatusAction.openCoaching;
      default:
        return null;
    }
  }

  String _label(AppL10n l, StatusAction a) => switch (a) {
    StatusAction.pay => l.payNow,
    StatusAction.sendProof => l.sendMyProof,
    StatusAction.payRest => l.payTheRest,
    StatusAction.addProof => l.addProof,
    StatusAction.openCoaching => l.openMyCoaching,
    StatusAction.agree => l.iAgree,
  };

  Future<void> _run(
    Future<Object?> Function(PaymentsRepository repo) call,
  ) async {
    final repo = _repo;
    if (repo == null || _busy) return;
    final l10n = AppL10n.of(context);
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await call(repo);
    } on PaymentFailure catch (f) {
      if (mounted) setState(() => _error = paymentFailureText(l10n, f));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A payment that is not there, cannot be read, or has no signal.
  String _failureLine(AppL10n l10n, Object? failure) {
    if (failure is PaymentFailure &&
        (failure.unreachable || failure.reason.isNotEmpty)) {
      return paymentFailureText(l10n, failure);
    }
    return l10n.thisPaymentChangedRefreshAndTryAgain;
  }

  String _stamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    final c = toCairo(t);
    return '${two(c.day)}/${two(c.month)} ${two(c.hour)}:${two(c.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return StreamBuilder<Payment?>(
      stream: _payment,
      builder: (context, snap) {
        final p = snap.data;
        final action = p == null ? null : _action(p);
        final until = p?.accessUntil;
        final open = until != null && until.isAfter(_now);
        final failure = snap.error;
        return AppScaffold(
          showArt: false,
          appBar: AppTopBar(
            title: l10n.yourPayment,
            onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
          ),
          footer: [
            if (p != null && action != null)
              AppButton(
                _label(l10n, action),
                key: const ValueKey('status-primary'),
                onPressed: _busy
                    ? null
                    : action == StatusAction.agree
                    ? () => unawaited(
                        _run(
                          (r) =>
                              r.clientRespondDifferentAmount(p.id, agree: true),
                        ),
                      )
                    : () => widget.onAction(action, p),
              ),
          ],
          children: [
            if (p == null &&
                failure == null &&
                snap.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator()),
            if (p == null &&
                (failure != null ||
                    snap.connectionState != ConnectionState.waiting))
              Semantics(
                liveRegion: true,
                child: Text(
                  _failureLine(l10n, failure),
                  key: const ValueKey('status-failure'),
                  style: AppText.bodyM,
                ),
              ),
            if (p != null) ...[
              AppCard(
                children: [
                  Text(egpText(l10n, p.amountPiasters), style: AppText.titleL),
                  Text(
                    '${l10n.reference}  ${p.reference}',
                    textDirection: TextDirection.ltr,
                    style: AppText.bodyM,
                  ),
                  Text(
                    statusWord(l10n, p),
                    key: const ValueKey('status-word'),
                    style: AppText.titleM,
                  ),
                ],
              ),
              Text(
                nextLine(l10n, p),
                key: const ValueKey('next-line'),
                style: AppText.bodyM,
              ),
              if (p.status == PaymentStatus.proofSubmitted &&
                  p.outcome == RiskOutcome.green &&
                  open)
                AppCard(
                  variant: AppCardVariant.tonal,
                  children: [
                    Text(
                      l10n.youCanStartNowThisStaysOpen(_stamp(until)),
                      key: const ValueKey('green-access'),
                      style: AppText.bodyM,
                    ),
                  ],
                ),
              if (p.status == PaymentStatus.proofSubmitted &&
                  p.outcome == RiskOutcome.amber)
                Text(
                  l10n.yourCoachIsCheckingHerBankThis,
                  key: const ValueKey('amber'),
                  style: AppText.bodyM,
                ),
              if (p.coachAsks)
                AppCard(
                  variant: AppCardVariant.tonal,
                  children: [
                    Text(
                      l10n.yourCoachSaysYouPaidReferenceIs(p.reference),
                      style: AppText.titleM,
                    ),
                    AppButton(
                      l10n.yesIPaid,
                      key: const ValueKey('report-yes'),
                      onPressed: _busy
                          ? null
                          : () => unawaited(
                              _run(
                                (r) => r.clientAnswerReport(p.id, yes: true),
                              ),
                            ),
                    ),
                    AppButton(
                      l10n.no,
                      key: const ValueKey('report-no'),
                      variant: AppButtonVariant.text,
                      height: 44,
                      fontSize: 15,
                      onPressed: _busy
                          ? null
                          : () => unawaited(
                              _run(
                                (r) => r.clientAnswerReport(p.id, yes: false),
                              ),
                            ),
                    ),
                  ],
                ),
              if (action == StatusAction.agree)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppButton(
                    l10n.iDoNotAgree,
                    key: const ValueKey('disagree'),
                    variant: AppButtonVariant.text,
                    height: 44,
                    fontSize: 15,
                    onPressed: _busy
                        ? null
                        : () => unawaited(
                            _run(
                              (r) => r.clientRespondDifferentAmount(
                                p.id,
                                agree: false,
                              ),
                            ),
                          ),
                  ),
                ),
              StreamBuilder<List<PaymentEvent>>(
                stream: _events,
                builder: (context, es) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in es.data ?? const <PaymentEvent>[])
                      if (timelineSentence(l10n, e) case final sentence?)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '${e.at == null ? '' : _stamp(e.at!)}  $sentence',
                            style: AppText.bodyM,
                          ),
                        ),
                  ],
                ),
              ),
              if (_error.isNotEmpty)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error,
                    key: const ValueKey('status-error'),
                    style: AppText.bodyM.copyWith(color: AppColors.error),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
