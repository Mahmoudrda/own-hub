library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
import '../../events/domain/cairo_time.dart';
import '../data/payments_hub.dart';
import '../data/payments_local_store.dart';
import '../data/payments_repository.dart';
import '../data/pending_proofs.dart';
import '../data/proof_images.dart';
import '../domain/payment_models.dart';
import '../domain/payments_rules.dart';
import '../domain/receipt_reader.dart';
import 'payment_text.dart';
import 'proof_flow.dart';

/// Counsel may switch the optional "help improve" question off (spec 13.13
/// item 5). Off asks nothing and sends `learnConsent: false`.
const bool kAskLearnConsent = true;

/// PAY2 (send the proof) and, with [addEvidence], PAY6 (add proof after a
/// dispute): the same pick, hide and read steps.
class ProofView extends StatefulWidget {
  const ProofView({
    super.key,
    required this.payment,
    required this.onSent,
    this.addEvidence = false,
    this.repository,
    this.picker = pickProofImages,
    this.prepare = prepareProofImage,
    this.store,
    this.pending,
    this.now,
  });

  final Payment payment;

  /// [result] is null for a queued proof and for added evidence.
  final void Function(ProofResult? result, {required bool queued}) onSent;
  final bool addEvidence;
  final PaymentsRepository? repository;
  final Future<List<Uint8List>> Function() picker;
  final PrepareImage prepare;
  final PaymentsLocalStore? store;
  final PendingProofs? pending;
  final DateTime Function()? now;

  @override
  State<ProofView> createState() => _ProofViewState();
}

class _ProofViewState extends State<ProofView> {
  final _txn = TextEditingController();
  final _handle = TextEditingController();
  final List<PreparedImage> _images = <PreparedImage>[];
  ReceiptReading? _reading;
  bool _edit = false;
  bool _needHandle = false;
  bool _busy = false;
  bool _otherPayerOk = false;
  String _error = '';
  String _serverHint = '';
  bool _askOther = false;
  late String _key = PaymentsLocalStore.newKey();

  PaymentsRepository? get _repo => widget.repository ?? PaymentsHub.repository;
  PaymentsLocalStore get _store => widget.store ?? PaymentsLocalStore();
  DateTime get _now => (widget.now ?? DateTime.now)();

  ExpectedPayment get _expected => ExpectedPayment(
    amountPiasters: widget.payment.amountPiasters,
    coachAddress: widget.payment.address.address,
    coachAccountName: widget.payment.address.accountName,
    createdAt: widget.payment.createdAt ?? _now,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.addEvidence) unawaited(_load());
  }

  Future<void> _load() async {
    final h = await _store.senderHandle();
    if (!mounted) return;
    setState(() {
      _handle.text = h;
      _needHandle = h.isEmpty;
    });
  }

  @override
  void dispose() {
    _txn.dispose();
    _handle.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    setState(() => _error = '');
    final l10n = AppL10n.of(context);
    final raw = await widget.picker();
    if (!mounted || raw.isEmpty) return;
    final got = <PreparedImage>[];
    for (final bytes in raw) {
      try {
        final p = await widget.prepare(context, bytes, _expected);
        if (!mounted) return;
        if (p != null) got.add(p);
      } on FormatException {
        if (!mounted) return;
        setState(() => _error = l10n.thisPictureIsTooBigOrCould);
      }
    }
    if (got.isEmpty) return;
    if (widget.addEvidence) {
      setState(() {
        _images
          ..clear()
          ..addAll(got);
      });
      return;
    }
    final reading = readReceipt(
      got.map((g) => g.text).toList(),
      _expected,
      _now,
    );
    setState(() {
      _images
        ..clear()
        ..addAll(got);
      _reading = reading;
      _serverHint = '';
      _askOther = false;
      if (reading.txnNumber != null) _txn.text = reading.txnNumber!;
      if (reading.txnNumber == null) _edit = true;
      if (_handle.text.isEmpty && reading.senderHandle != null) {
        _handle.text = reading.senderHandle!;
      }
    });
  }

  PhoneVerdict? get _verdict =>
      _reading == null ? null : phoneVerdict(_reading!);

  /// The transaction number has at least six letters or digits, like the server asks.
  bool get _txnOk =>
      _txn.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length >= 6;

  bool get _ready => widget.addEvidence
      ? _images.isNotEmpty && !_busy
      : _images.isNotEmpty &&
            _txnOk &&
            _verdict != PhoneVerdict.wrongMessage &&
            !_busy;

  Future<bool> _consent() async {
    if (!kAskLearnConsent || await _store.consentAsked() || !mounted) {
      return kAskLearnConsent ? await _store.learnConsent() : false;
    }
    final l10n = AppL10n.of(context);
    final yes = await showAppSheet<bool>(
      context: context,
      children: [
        Text(l10n.helpImproveReceiptReading, style: AppText.titleL),
        Text(l10n.weKeepOnlyTheTextFieldsWe, style: AppText.bodyM),
        Builder(
          builder: (sheet) => AppButton(
            l10n.yesHelp,
            key: const ValueKey('consent-yes'),
            onPressed: () => Navigator.of(sheet).pop(true),
          ),
        ),
        Builder(
          builder: (sheet) => AppButton(
            l10n.noThanks,
            key: const ValueKey('consent-no'),
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(sheet).pop(false),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
    await _store.answerLearnConsent(yes == true);
    return yes == true;
  }

  /// The time printed on the receipt as an instant (Cairo wall clock), or null.
  DateTime? _claimedAt() {
    final t = _reading?.timeSeen;
    if (t == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return parseCairo(
      '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}',
    );
  }

  Future<void> _send() async {
    final repo = _repo;
    if (repo == null || !_ready) return;
    final l10n = AppL10n.of(context);
    setState(() {
      _busy = true;
      _error = '';
    });
    final bytes = <Uint8List>[for (final i in _images) i.png];
    try {
      if (widget.addEvidence) {
        await repo.addEvidence(paymentId: widget.payment.id, images: bytes);
        if (mounted) widget.onSent(null, queued: false);
        return;
      }
      final consent = await _consent();
      final handle = _handle.text.trim().toLowerCase();
      final sender = validInstapayHandle(handle) ? handle : null;
      if (sender != null) await _store.saveSenderHandle(sender);
      final reading = <String, Object?>{
        ...?_reading?.toJson(),
        'learnConsent': consent,
      };
      final claimed = _claimedAt();
      final txn = _txn.text.trim();
      try {
        final r = await repo.submitProof(
          paymentId: widget.payment.id,
          idempotencyKey: _key,
          amountPiasters: widget.payment.amountPiasters,
          images: bytes,
          txnNumber: txn,
          senderHandle: sender,
          paidAtClaimed: claimed,
          phoneReading: reading,
          otherPayerOk: _otherPayerOk,
        );
        if (!mounted) return;
        if (r.retry) {
          // The payment is where it was: she may fix the hint and send again.
          setState(() {
            _key = PaymentsLocalStore.newKey();
            _serverHint = _hintFor(
              l10n,
              r.reasons.isEmpty ? 'unclear' : r.reasons.first,
            );
            _askOther = r.reasons.contains('someoneElsePaid');
            _edit = true;
          });
        } else {
          widget.onSent(r, queued: false);
        }
      } on PaymentFailure catch (f) {
        if (!f.unreachable) rethrow;
        await (widget.pending ?? PendingProofs()).add(
          PendingProof(
            paymentId: widget.payment.id,
            key: _key,
            amountPiasters: widget.payment.amountPiasters,
            txnNumber: txn,
            senderHandle: sender,
            paidAtClaimed: claimed,
            phoneReading: reading,
            otherPayerOk: _otherPayerOk,
            files: const <String>[],
          ),
          bytes,
        );
        if (mounted) widget.onSent(null, queued: true);
      }
    } on PaymentFailure catch (f) {
      if (mounted) setState(() => _error = paymentFailureText(l10n, f));
    } catch (_) {
      if (mounted) setState(() => _error = l10n.weCouldNotDoThatTryAgain);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendOther() async {
    setState(() => _otherPayerOk = true);
    await _send();
  }

  String _hintFor(AppL10n l10n, String code) => switch (code) {
    'needDetails' => l10n.weNeedALittleMoreToCheck,
    'amountUnreadable' => l10n.weCouldNotReadTheAmountPick,
    'wrongMessage' => l10n.thisLooksLikeACardMessageNot,
    'someoneElsePaid' => l10n.thisPaymentCameFromADifferentInstapay,
    'referenceMissing' => l10n.weCouldNotSeeYourReferenceOn,
    _ => l10n.weCouldNotReadThisClearlyPick,
  };

  String _phoneHint(AppL10n l10n) => switch (_verdict) {
    PhoneVerdict.green => l10n.everythingMatchesTapSend,
    PhoneVerdict.amber => l10n.weCouldNotReadEverythingAddThe,
    PhoneVerdict.red => l10n.thisDoesNotMatchYourPaymentYou,
    PhoneVerdict.wrongMessage => l10n.thisLooksLikeACardMessageNot,
    null => '',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final txn = _txn.text.trim();
    final hint = _serverHint.isNotEmpty
        ? _serverHint
        : (widget.addEvidence ? '' : _phoneHint(l10n));
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: widget.addEvidence ? l10n.addProof : l10n.sendYourProof,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      footer: [
        AppButton(
          widget.addEvidence ? l10n.send : l10n.sendToCoach,
          key: const ValueKey('send'),
          onPressed: _ready ? () => unawaited(_send()) : null,
        ),
      ],
      children: [
        Text(
          widget.addEvidence
              ? l10n.addAScreenshotOfYourBanksTransaction
              : l10n.addYourBankScreenshotsTheReceiptAnd,
          style: AppText.bodyM,
        ),
        AppButton(
          l10n.chooseScreenshots,
          key: const ValueKey('choose'),
          variant: AppButtonVariant.outlined,
          onPressed: _busy ? null : () => unawaited(_choose()),
        ),
        Text(l10n.youCanHidePrivateDetailsBeforeAnything, style: AppText.bodyM),
        if (!widget.addEvidence)
          AppCard(
            children: [
              Text(
                '${l10n.paymentAmount}  ${egpText(l10n, widget.payment.amountPiasters)}',
                style: AppText.bodyM,
              ),
              Text(
                '${l10n.transactionNumber}  ${txn.isEmpty ? l10n.notFoundYet : txn}',
                key: const ValueKey('txn-row'),
                textDirection: TextDirection.ltr,
                style: AppText.bodyM,
              ),
              if (_images.isNotEmpty)
                Text(
                  l10n.picturesAddedCount('${_images.length}'),
                  key: const ValueKey('count-row'),
                  style: AppText.bodyM,
                ),
            ],
          )
        else if (_images.isNotEmpty)
          Text(
            l10n.picturesAddedCount('${_images.length}'),
            key: const ValueKey('count-row'),
            style: AppText.bodyM,
          ),
        if (!widget.addEvidence && !_edit)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton(
              l10n.edit,
              key: const ValueKey('edit'),
              variant: AppButtonVariant.text,
              height: 44,
              fontSize: 15,
              onPressed: () => setState(() => _edit = true),
            ),
          ),
        if (!widget.addEvidence && _edit)
          AppField(
            controller: _txn,
            label: l10n.transactionNumber,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            onChanged: (_) => setState(() {}),
          ),
        if (!widget.addEvidence && _needHandle)
          AppField(
            controller: _handle,
            label: l10n.yourOwnInstapayAddress,
            textDirection: TextDirection.ltr,
            helper: looksLikePhone(_handle.text)
                ? l10n.aPhoneNumberWouldShowOnYour
                : l10n.weUseItToMatchYourReceipt,
            onChanged: (_) => setState(() {}),
          ),
        if (hint.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              hint,
              key: const ValueKey('hint'),
              style: AppText.bodyM,
            ),
          ),
        if (_askOther)
          AppButton(
            l10n.yesSomeoneElsePaidForMe,
            key: const ValueKey('other-paid'),
            variant: AppButtonVariant.text,
            height: 44,
            fontSize: 15,
            onPressed: _busy ? null : () => unawaited(_sendOther()),
          ),
        if (_error.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              _error,
              key: const ValueKey('proof-error'),
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
