library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../events/domain/cairo_time.dart';
import '../data/payments_hub.dart';
import '../data/payments_repository.dart';
import '../domain/payment_models.dart';
import '../domain/payments_rules.dart';
import 'payment_text.dart';

enum _Step { form, code }

/// PAY7: the coach's InstaPay address. A change needs a fresh phone code and
/// takes effect 24 hours later (spec 4.4); the first address is active at once.
class PaymentAddressView extends StatefulWidget {
  const PaymentAddressView({
    super.key,
    this.repository,
    this.reauth,
    this.now,
    this.onBack,
  });

  final PaymentsRepository? repository;
  final PhoneReauth? reauth;
  final DateTime Function()? now;
  final VoidCallback? onBack;

  @override
  State<PaymentAddressView> createState() => _PaymentAddressViewState();
}

class _PaymentAddressViewState extends State<PaymentAddressView> {
  final _address = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();
  _Step _step = _Step.form;
  bool _busy = false;
  String _error = '';
  AddressChange? _saved;

  PaymentsRepository? get _repo => widget.repository ?? PaymentsHub.repository;
  PhoneReauth get _reauth => widget.reauth ?? PaymentsHub.reauth;
  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void dispose() {
    _address.dispose();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _formOk =>
      validInstapayHandle(_address.text) && validAccountName(_name.text);

  Future<void> _primary() async {
    final l10n = AppL10n.of(context);
    final repo = _repo;
    if (repo == null || _busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (_step == _Step.form) {
        await _reauth.sendCode();
        if (mounted) setState(() => _step = _Step.code);
      } else {
        await _reauth.confirm(_code.text.trim());
        final change = await repo.setAddress(
          address: _address.text.trim().toLowerCase(),
          accountName: _name.text.trim(),
        );
        if (mounted) {
          setState(() {
            _saved = change;
            _step = _Step.form;
            _code.clear();
            _address.clear();
            _name.clear();
          });
        }
      }
    } on PaymentFailure catch (f) {
      if (mounted) {
        setState(() {
          _error = paymentFailureText(l10n, f);
          // A refused address goes back to the form; a wrong code stays put.
          if (_step == _Step.code && f.reason.startsWith('address_')) {
            _step = _Step.form;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _stamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    final c = toCairo(t);
    return '${two(c.day)}/${two(c.month)} ${two(c.hour)}:${two(c.minute)}';
  }

  Widget _status(AppL10n l10n, CoachAddress? a) {
    final pendingAt = a != null && a.pendingAt(_now)
        ? a.pendingEffectiveAt
        : null;
    final line = _saved != null
        ? (_saved!.pending && _saved!.effectiveAt != null
              ? l10n.yourNewAddressStartsWorkingAtTime(
                  _stamp(_saved!.effectiveAt!),
                )
              : l10n.yourAddressIsSavedAndReady)
        : (pendingAt != null
              ? l10n.yourNewAddressStartsWorkingAtTime(_stamp(pendingAt))
              : '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (a != null && a.address.isNotEmpty) ...[
          Text(
            a.address,
            key: const ValueKey('current-address'),
            textDirection: TextDirection.ltr,
            style: AppText.titleM,
          ),
          Text(a.accountName, style: AppText.bodyM),
        ],
        if (line.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              line,
              key: const ValueKey('address-status'),
              style: AppText.bodyM,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final repo = _repo;
    final typed = _address.text.trim();
    final ready = _step == _Step.code ? _code.text.trim().length == 6 : _formOk;
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: l10n.yourInstapayAddress,
        onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      ),
      footer: [
        AppButton(
          _step == _Step.code ? l10n.confirm : l10n.sendMeACode,
          key: const ValueKey('address-primary'),
          onPressed: (!ready || _busy || repo == null)
              ? null
              : () => unawaited(_primary()),
        ),
      ],
      children: [
        AppCard(
          variant: AppCardVariant.tonal,
          children: [
            Text(l10n.clientsPayYouDirectlyOwnHubNever, style: AppText.bodyM),
            if (repo != null)
              StreamBuilder<CoachAddress?>(
                stream: repo.watchMyAddress(),
                builder: (context, snap) => _status(l10n, snap.data),
              )
            else
              _status(l10n, null),
          ],
        ),
        if (_step == _Step.form) ...[
          AppField(
            controller: _address,
            label: l10n.instapayAddress,
            hint: 'name@instapay',
            helper: looksLikePhone(typed)
                ? l10n.thatLooksLikeAPhoneNumberUse
                : l10n.useYourAddressNotAPhoneNumber,
            errorText:
                typed.isNotEmpty &&
                    !looksLikePhone(typed) &&
                    !validInstapayHandle(typed)
                ? l10n.thatDoesNotLookLikeAnInstapay
                : '',
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
          ),
          AppField(
            controller: _name,
            label: l10n.accountNameExactlyAsYourBankShows,
            onChanged: (_) => setState(() {}),
          ),
          AppSageNote(l10n.aNewAddressStartsWorkingAfter24),
        ] else ...[
          Text(l10n.weSentACodeToYourPhone, style: AppText.bodyM),
          AppField(
            controller: _code,
            label: l10n.code,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            autofillHints: const [AutofillHints.oneTimeCode],
            onChanged: (_) => setState(() {}),
          ),
        ],
        if (_error.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              _error,
              key: const ValueKey('address-error'),
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
