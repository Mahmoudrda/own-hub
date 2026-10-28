library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../private_coaching/presentation/coach/coach_widgets.dart'
    show CoachSwitchRow;
import '../data/payments_hub.dart';
import '../data/payments_repository.dart';
import '../data/proof_images.dart';
import '../domain/payment_models.dart';
import '../domain/payments_rules.dart';
import '../domain/receipt_reader.dart' show ExpectedPayment;
import 'payment_text.dart';
import 'proof_flow.dart';

enum DecisionMode { notReceived, differentAmount }

/// PAY5, the second step. "Not received": why, her note and her own bank list
/// for the day (the server reads it and refuses a claim her list contradicts).
/// "Different amount": what arrived, and whether she accepts less in writing.
class CoachDecisionView extends StatefulWidget {
  const CoachDecisionView({
    super.key,
    required this.payment,
    required this.mode,
    this.repository,
    this.picker = pickProofImages,
    this.prepare = prepareProofImage,
    this.now,
  });

  final Payment payment;
  final DecisionMode mode;
  final PaymentsRepository? repository;
  final Future<List<Uint8List>> Function() picker;
  final PrepareImage prepare;
  final DateTime Function()? now;

  @override
  State<CoachDecisionView> createState() => _CoachDecisionViewState();
}

class _CoachDecisionViewState extends State<CoachDecisionView> {
  final _note = TextEditingController();
  final _amount = TextEditingController();
  final List<PreparedImage> _images = <PreparedImage>[];
  String? _reason;
  bool _searched = false;
  bool _acceptLower = false;
  bool _busy = false;
  String _error = '';

  PaymentsRepository? get _repo => widget.repository ?? PaymentsHub.repository;

  @override
  void dispose() {
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  ExpectedPayment get _expected => ExpectedPayment(
    amountPiasters: widget.payment.amountPiasters,
    coachAddress: widget.payment.address.address,
    coachAccountName: widget.payment.address.accountName,
    createdAt: widget.payment.createdAt ?? (widget.now ?? DateTime.now)(),
  );

  Future<void> _addStatement() async {
    setState(() => _error = '');
    final l10n = AppL10n.of(context);
    final raw = await widget.picker();
    if (!mounted || raw.isEmpty) return;
    final got = <PreparedImage>[];
    var unreadable = false;
    for (final bytes in raw) {
      try {
        final p = await widget.prepare(context, bytes, _expected);
        if (!mounted) return;
        if (p != null) got.add(p);
      } on FormatException {
        if (!mounted) return;
        unreadable = true;
      }
    }
    setState(() {
      if (unreadable) _error = l10n.thisPictureIsTooBigOrCould;
      if (got.isNotEmpty) {
        _images
          ..clear()
          ..addAll(got);
      }
    });
  }

  bool get _notReceivedReady =>
      _reason != null &&
      _searched &&
      validNotReceivedNote(_note.text) &&
      _images.isNotEmpty;

  int? get _entered => parseAmountPiasters(_amount.text);

  bool get _amountReady {
    final e = _entered;
    return e != null && e != widget.payment.amountPiasters;
  }

  bool get _lower =>
      _entered != null && _entered! < widget.payment.amountPiasters;

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
    String done;
    try {
      if (widget.mode == DecisionMode.notReceived) {
        await repo.coachNotReceived(
          paymentId: widget.payment.id,
          reasonCode: _reason!,
          note: _note.text.trim(),
          images: [for (final i in _images) i.png],
        );
        done = l10n.sentOwnHubWillLookAtIt;
      } else if (_lower) {
        await repo.coachDifferentAmount(
          paymentId: widget.payment.id,
          receivedPiasters: _entered!,
          acceptLower: _acceptLower,
        );
        done = l10n.sentYourClientWillSeeIt;
      } else {
        // More than was asked: the server confirms it with the amount
        // received (it refuses "different amount" for a sum at or above it).
        await repo.coachConfirm(widget.payment.id, receivedPiasters: _entered!);
        done = l10n.confirmedYourClientCanStart;
      }
    } on PaymentFailure catch (f) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = coachPaymentFailureText(l10n, f);
        });
      }
      return;
    }
    messenger?.showSnackBar(SnackBar(content: Text(done)));
    nav.pop();
  }

  String _reasonText(AppL10n l, String code) => switch (code) {
    'not_seen' => l.iDoNotSeeItInMy,
    'wrong_amount' => l.theAmountIsDifferent,
    'wrong_name' => l.theNameIsDifferent,
    'paid_by_someone_else' => l.someoneElsePaid,
    _ => l.anotherReason,
  };

  List<Widget> _notReceived(AppL10n l10n) {
    final p = widget.payment;
    final amount = egpText(l10n, p.amountPiasters);
    return [
      Text(l10n.whatDoYouSeeInYourBank, style: AppText.titleM),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          for (final code in kNotReceivedReasons)
            AppListItem(
              key: ValueKey('reason-$code'),
              title: _reasonText(l10n, code),
              variant: _reason == code
                  ? AppCardVariant.selected
                  : AppCardVariant.outlined,
              onTap: () => setState(() => _reason = code),
            ),
        ],
      ),
      AppField(
        controller: _note,
        label: l10n.tellUsWhatYouSaw,
        maxLines: 3,
        inputFormatters: [LengthLimitingTextInputFormatter(300)],
        onChanged: (_) => setState(() {}),
      ),
      // Two things she must do before sending, drawn as one short list.
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Semantics(
            checked: _searched,
            child: AppListItem(
              key: const ValueKey('searched'),
              title: p.txnNumber.isEmpty
                  ? l10n.iSearchedMyBankForAmount(amount)
                  : l10n.iSearchedMyBankForAmountAnd(amount, p.txnNumber),
              leading: Icon(
                _searched ? Icons.check_box : Icons.check_box_outline_blank,
              ),
              variant: _searched
                  ? AppCardVariant.selected
                  : AppCardVariant.outlined,
              onTap: () => setState(() => _searched = !_searched),
            ),
          ),
          AppListItem(
            key: const ValueKey('add-statement'),
            title: l10n.addYourBankListForThatDay,
            subtitle: _images.isEmpty
                ? ''
                : l10n.picturesAddedCount(_images.length.toString()),
            leading: const Icon(Icons.photo_library_outlined),
            variant: _images.isEmpty
                ? AppCardVariant.outlined
                : AppCardVariant.selected,
            onTap: _busy ? null : () => unawaited(_addStatement()),
          ),
        ],
      ),
    ];
  }

  List<Widget> _differentAmount(AppL10n l10n) => [
    Text(l10n.howMuchDidYouReceive, style: AppText.titleM),
    AppField(
      controller: _amount,
      label: l10n.amountReceivedEgp,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textDirection: TextDirection.ltr,
      onChanged: (_) => setState(() {}),
    ),
    if (_lower)
      CoachSwitchRow(
        key: const ValueKey('accept-lower'),
        title: l10n.acceptThisLowerAmountAndStartThe,
        subtitle: l10n.ifYouAcceptHerPackageStartsOtherwise,
        value: _acceptLower,
        onChanged: _busy ? null : (v) => setState(() => _acceptLower = v),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final notReceived = widget.mode == DecisionMode.notReceived;
    final ready =
        !_busy &&
        _repo != null &&
        (notReceived ? _notReceivedReady : _amountReady);
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: notReceived ? l10n.notReceived : l10n.differentAmount,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      footer: [
        AppButton(
          l10n.send,
          key: const ValueKey('decision-send'),
          onPressed: ready ? () => unawaited(_send()) : null,
        ),
      ],
      children: [
        ...(notReceived ? _notReceived(l10n) : _differentAmount(l10n)),
        if (_error.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              _error,
              key: const ValueKey('decision-error'),
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
