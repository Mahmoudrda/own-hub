library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app_state/open_link.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../data/payments_hub.dart';
import '../data/payments_local_store.dart';
import '../data/payments_repository.dart';
import '../domain/payment_models.dart';
import '../domain/payments_rules.dart';
import 'payment_text.dart';

/// Where "Open InstaPay" goes. Not every bank registers the same address, and
/// this one is not verified with the InstaPay app (UNVERIFIED): when nothing
/// answers, the screen says to open the bank app by hand. Change it here.
const String kInstapayLaunchUri = 'instapay://';

/// PAY1: what to pay, to whom, with which reference.
class PaymentView extends StatefulWidget {
  const PaymentView({
    super.key,
    required this.subId,
    required this.onIHavePaid,
    this.onInProgress,
    this.topUpOf,
    this.repository,
    this.now,
    this.opener,
    this.onBack,
  });

  final String subId;
  final ValueChanged<Payment> onIHavePaid;

  /// Called (instead of showing this screen) when her payment for this
  /// package is already past "waiting", so she lands on its status.
  final ValueChanged<Payment>? onInProgress;

  /// The payment whose missing part this one pays (spec 4.3).
  final String? topUpOf;
  final PaymentsRepository? repository;

  /// The clock the countdown reads (a display only; the server decides).
  final DateTime Function()? now;
  final Future<bool> Function(Uri uri)? opener;
  final VoidCallback? onBack;

  @override
  State<PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends State<PaymentView> {
  Payment? _payment;
  String _error = '';
  bool _notReady = false;
  Timer? _tick;
  late final String _key = PaymentsLocalStore.newKey();

  PaymentsRepository? get _repo => widget.repository ?? PaymentsHub.repository;
  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    unawaited(_open());
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      final p = _payment;
      if (p != null && p.timeLeft(_now) == Duration.zero) t.cancel();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Shows her open payment, or sends her to its status. False when there is
  /// none to use and a new request may be made.
  bool _useExisting(Payment? latest) {
    if (latest == null || widget.topUpOf != null) return false;
    if (latest.status.unpaid &&
        latest.canSendProof(_now) &&
        latest.address.address.isNotEmpty) {
      if (mounted) setState(() => _payment = latest);
      return true;
    }
    if (latest.inProgress && widget.onInProgress != null) {
      widget.onInProgress!(latest);
      return true;
    }
    return false;
  }

  Future<Payment?> _latest(PaymentsRepository repo) async =>
      (await repo.watchMyPaymentsAsClient().first)
          .where((p) => p.subId == widget.subId)
          .firstOrNull;

  /// Reuses her open payment for this package (one open payment at a time,
  /// spec 4.6), sends her on when it has moved past waiting, else creates one.
  Future<void> _open() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      if (_useExisting(await _latest(repo))) return;
      final created = await repo.createPayment(
        subId: widget.subId,
        idempotencyKey: _key,
        topUpOf: widget.topUpOf,
      );
      if (mounted) setState(() => _payment = created);
    } on PaymentFailure catch (f) {
      // The list she read first was out of date: read it again before giving up.
      if (f.reason == 'open_payment_exists') {
        try {
          if (_useExisting(await _latest(repo))) return;
        } on PaymentFailure {
          // falls through to the sentence below
        }
      }
      if (!mounted) return;
      final l10n = AppL10n.of(context);
      setState(() {
        _notReady = f.reason == 'coach_not_ready';
        _error = _notReady ? '' : paymentFailureText(l10n, f);
      });
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AppL10n.of(context).copied)));
  }

  /// Copies the exact amount (the first thing the bank asks for) and hands
  /// over to InstaPay when the phone knows it.
  Future<void> _openInstapay(Payment p) async {
    await Clipboard.setData(ClipboardData(text: egpPlain(p.amountPiasters)));
    var opened = false;
    try {
      opened = await (widget.opener ?? openOutside)(
        Uri.parse(kInstapayLaunchUri),
      );
    } catch (_) {}
    if (opened || !mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppL10n.of(context).theAmountIsCopiedOpenYourBank),
        ),
      );
  }

  String _clock(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0
        ? '$h:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
        : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  Widget _copyButton(String label, String value, Key key) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: AppButton(
      label,
      key: key,
      variant: AppButtonVariant.text,
      height: 44,
      fontSize: 15,
      icon: Icons.copy_outlined,
      onPressed: () => unawaited(_copy(value)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final p = _payment;
    final left = p?.timeLeft(_now) ?? Duration.zero;
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: l10n.payYourCoach,
        onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      ),
      footer: [
        if (p != null)
          AppButton(
            l10n.iHavePaid,
            key: const ValueKey('i-have-paid'),
            onPressed: () => widget.onIHavePaid(p),
          ),
      ],
      children: [
        if (_notReady)
          Text(
            l10n.yourCoachHasNotSetUpPayments,
            key: const ValueKey('not-ready'),
            style: AppText.titleM,
          ),
        if (_error.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              _error,
              key: const ValueKey('pay-error'),
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          ),
        if (p == null && !_notReady && _error.isEmpty)
          const Center(child: CircularProgressIndicator()),
        if (p != null) ...[
          AppCard(
            children: [
              Text(l10n.payExactly, style: AppText.bodyM),
              Semantics(
                label: egpText(l10n, p.amountPiasters),
                child: ExcludeSemantics(
                  child: Text(
                    egpText(l10n, p.amountPiasters),
                    key: const ValueKey('pay-amount'),
                    style: AppText.titleL,
                  ),
                ),
              ),
              _copyButton(
                l10n.copyAmount,
                egpPlain(p.amountPiasters),
                const ValueKey('copy-amount'),
              ),
            ],
          ),
          AppCard(
            children: [
              Text(l10n.payTo, style: AppText.bodyM),
              Text(
                l10n.nameNameAsShownByYourBank(p.address.accountName),
                style: AppText.titleM,
              ),
              Text(
                p.address.address,
                key: const ValueKey('pay-address'),
                textDirection: TextDirection.ltr,
                style: AppText.titleM,
              ),
              _copyButton(
                l10n.copyAddress,
                p.address.address,
                const ValueKey('copy-address'),
              ),
            ],
          ),
          AppCard(
            children: [
              Text(
                '${l10n.reference}  ${p.reference}',
                key: const ValueKey('pay-reference'),
                textDirection: TextDirection.ltr,
                style: AppText.titleM,
              ),
              Text(l10n.putTheReferenceInTheTransferNote, style: AppText.bodyM),
              _copyButton(
                l10n.copyReference,
                p.reference,
                const ValueKey('copy-reference'),
              ),
            ],
          ),
          for (final (i, step) in [
            l10n.openYourBankAppAndChooseInstapay,
            l10n.sendTheExactAmountToTheAddress,
            l10n.comeBackHereAndTapIHave,
          ].indexed)
            Text('${i + 1}. $step', style: AppText.bodyM),
          AppButton(
            l10n.openInstapay,
            key: const ValueKey('open-instapay'),
            variant: AppButtonVariant.outlined,
            onPressed: () => unawaited(_openInstapay(p)),
          ),
          left > Duration.zero
              ? Text(
                  l10n.timeLeftTime(_clock(left)),
                  key: const ValueKey('pay-left'),
                  style: AppText.bodyM,
                )
              : Text(
                  l10n.thisRequestHasExpiredIfYouAlready_1azdp(
                    kLateProofDays.toString(),
                  ),
                  key: const ValueKey('pay-expired'),
                  style: AppText.bodyM,
                ),
          AppSageNote(l10n.ownHubCannotUndoAnInstapayTransfer),
        ],
      ],
    );
  }
}
