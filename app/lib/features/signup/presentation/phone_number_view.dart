/// C06 — What's your number?
///
/// Matches `6-v2/src/screens-signup.mjs` → `C06`. One field, no password: a
/// password is one more thing to forget and one more thing to leak, and the
/// phone is already the second factor.
///
/// The country code is a fixed box beside the field rather than part of it, so
/// the field holds only what she types. This product ships in Egypt, so `+20` is
/// not a picker.
///
/// **The copy promises six digits** (`DECISIONS.md` D2a) because Firebase phone
/// auth sends six and the length is not configurable. The screen must never
/// claim a length the provider does not send.
///
/// What this screen deliberately does **not** have: an error message. The
/// dictionary contains no invalid-number, offline or provider-down copy (G1 open
/// question 7), and an untranslated English string on the first screen of the
/// account flow is worse than none. So the action is *gated* instead — the
/// button does nothing until the number is long enough to be an Egyptian mobile,
/// and a rejected attempt leaves her on the screen with her number intact.
library;

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/auth_repository.dart';

/// Digits in an Egyptian mobile number after the country code.
const int _egyptianMobileDigits = 10;

class PhoneNumberView extends StatefulWidget {
  const PhoneNumberView({
    super.key,
    required this.repository,
    this.onCodeSent,
    this.onBack,
  });

  final AuthRepository repository;

  /// Fired only after the provider has accepted the number and sent a code, so
  /// she never lands on `C07` waiting for a message that was never sent.
  final VoidCallback? onCodeSent;

  final VoidCallback? onBack;

  @override
  State<PhoneNumberView> createState() => _PhoneNumberViewState();
}

class _PhoneNumberViewState extends State<PhoneNumberView> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTyped);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTyped);
    _controller.dispose();
    super.dispose();
  }

  void _onTyped() {
    if (mounted) setState(() {});
  }

  String get _digits => _controller.text.replaceAll(RegExp(r'[^0-9]'), '');

  /// Full international form. A leading zero is a local-dialling habit and is
  /// dropped rather than sent, because `+200100…` is not a number.
  String get _e164 {
    final digits = _digits.startsWith('0') ? _digits.substring(1) : _digits;
    return '+20$digits';
  }

  bool get _canSend =>
      !_sending &&
      (_digits.startsWith('0') ? _digits.length - 1 : _digits.length) >=
          _egyptianMobileDigits;

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() => _sending = true);
    try {
      await widget.repository.sendCode(_e164);
      if (!mounted) return;
      widget.onCodeSent?.call();
    } on AuthException {
      // No failure copy exists in the dictionary yet — see the note at the top
      // of this file. She keeps her number and can try again.
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(title: l10n.step1Of2, onBack: widget.onBack),
      footer: [
        AppButton(l10n.sendMeACode, onPressed: _canSend ? _send : null),
        Text(
          AppRouter.featureFlags.isOn(Feature.community)
              ? l10n.byJoiningYouAgreeToTheCommunity
              : l10n.byJoiningYouAgreeToTheOwn,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
      children: [
        Text(l10n.whatsYourNumber, style: AppText.display),
        Text(
          l10n.weTextYouASixDigitCode,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed, not a picker. Sized to the prototype's 86×60. Printed
            // clean: this is a form, and precision is what reads as trust.
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60, minWidth: 86),
              child: HandSurface(
                seed: handSeed(['dialling-code']),
                fill: AppColors.surfaceContainer,
                level: HandLevel.structural,
                radius: 5,
                looseCorner: 14,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    l10n.n20,
                    // A dialling code reads left to right in both languages.
                    textDirection: TextDirection.ltr,
                    style: AppText.titleM.copyWith(fontSize: 17),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                onSubmitted: (_) => _send(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
