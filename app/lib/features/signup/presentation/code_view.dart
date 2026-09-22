/// C07 — Type the code.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C07`. Six boxes, because
/// `DECISIONS.md` D2a settled the code at six: Firebase phone auth sends six and
/// the length is not configurable. The count comes from
/// [kVerificationCodeLength] rather than from a literal, so the boxes on screen
/// cannot disagree with the digits the provider sent — which is exactly the
/// mismatch `P0-VER-08` exists to catch.
///
/// **The screen checks itself when the last digit lands.** She does not tap
/// Continue on a code that works; the button is there for the case where the
/// check failed and she has corrected a digit. On Android the message is read
/// for her by the SMS Retriever API, and on iOS the code is offered above the
/// keyboard — *neither needs permission to read SMS, and this app must never
/// ask for it.*
///
/// One gap is closed and one remains:
///
///  * **Closed.** The dictionary now carries a parameterised
///    `weSentSixDigitsToPhone({phone})`, so this screen shows the number she
///    actually typed. It is read from [AuthAwaitingCode], which `sendCode`
///    populated with exactly what she entered — a mistyped number is obvious
///    here rather than after waiting for a message that will never arrive.
///  * **Open.** No wrong-code, expired-code or offline copy is wired to this
///    screen (G1 open question 7), so a failed check clears the boxes for
///    another try rather than inventing an untranslated message. The words do
///    exist — `i18n/msa/14-states.json` carries 29 of them in both languages,
///    including "That code is not right" and "That code has expired" — but no
///    view in this app references any of them yet.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_code_field.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/auth_repository.dart';

class CodeView extends StatefulWidget {
  const CodeView({
    super.key,
    required this.repository,
    this.testCode,
    this.onConfirmed,
    this.onResent,
    this.onResendRefused,
    this.onBack,
  });

  final AuthRepository repository;

  /// The code this build accepts, named on screen when there is one.
  ///
  /// Null against a real provider and null whenever an account is required —
  /// the caller decides, because that is a product gate rather than a screen's
  /// business. See [testCodeOf].
  final String? testCode;

  /// Fired when the provider has accepted the code and the account exists.
  final VoidCallback? onConfirmed;

  /// A new code has gone out. The caller says so, because what there is to say
  /// depends on whether anything was really sent — see [testCode].
  final VoidCallback? onResent;

  /// The provider refused another send: she has asked too many times.
  final VoidCallback? onResendRefused;

  final VoidCallback? onBack;

  @override
  State<CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  final TextEditingController _controller = TextEditingController();
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // Continue is offered only on six digits, so the button's state follows
    // the boxes. Without this it rendered live on an empty field and did
    // nothing when tapped, which reads as a broken button rather than as a
    // code that is not finished.
    _controller.addListener(_onTyped);
  }

  void _onTyped() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTyped)
      ..dispose();
    super.dispose();
  }

  /// Six digits are in the boxes and nothing is in flight.
  bool get _canConfirm =>
      !_checking && _controller.text.length == kVerificationCodeLength;

  /// The number the code was actually sent to.
  ///
  /// Falls back to the placeholder only if the state is somehow not
  /// [AuthAwaitingCode] — reaching this screen without having sent a code should
  /// not be possible, and if it happens it is a routing bug, not something to
  /// crash her sign-up over.
  String _sentToNumber() {
    final state = widget.repository.current;
    return state is AuthAwaitingCode ? state.phoneNumber : '+20 100 555 0132';
  }

  Future<void> _confirm(String code) async {
    if (_checking || code.length != kVerificationCodeLength) return;
    setState(() => _checking = true);
    try {
      await widget.repository.confirmCode(code);
      if (!mounted) return;
      widget.onConfirmed?.call();
    } on AuthException {
      // No failure copy exists yet — see the note at the top of this file.
      // Clearing the boxes is the whole retry: she types six digits again.
      if (mounted) _controller.clear();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    try {
      await widget.repository.resendCode();
      if (mounted) widget.onResent?.call();
    } on AuthException {
      // Rate-limited after three attempts, and said rather than swallowed: a
      // resend that answers with nothing at all is indistinguishable from a
      // button that is not wired to anything.
      if (mounted) widget.onResendRefused?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(title: l10n.step2Of2, onBack: widget.onBack),
      footer: [
        AppButton(
          l10n.continueLabel,
          // Live only on a full code. See [_canConfirm].
          onPressed: _canConfirm ? () => _confirm(_controller.text) : null,
        ),
        AppButton(
          l10n.sendItAgain,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: _resend,
        ),
      ],
      children: [
        Text(l10n.typeTheCode, style: AppText.display),
        Text(
          // Her number, not the mockup's. The repository already holds it:
          // sendCode moves the state to AuthAwaitingCode carrying exactly what
          // she typed, so a mistyped number is obvious here rather than after
          // waiting for a message that will never arrive.
          l10n.weSentSixDigitsToPhone(_sentToNumber()),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        // The one code this build accepts, said plainly and only while there
        // is one. Without it the sign-up chain cannot be walked by hand: no
        // message is sent, so there is nothing to read the six digits off.
        if (widget.testCode case final code?)
          AppCard(
            variant: AppCardVariant.amber,
            borderRadius: AppRadius.md,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              Text(
                l10n.testBuildNoTextMessageIsSent(code),
                style: AppText.body.copyWith(color: AppColors.amber),
              ),
            ],
          ),
        const SizedBox(height: 4),
        AppCodeField(
          // Six, from the auth layer. Never a literal on a screen.
          length: kVerificationCodeLength,
          controller: _controller,
          enabled: !_checking,
          onCompleted: _confirm,
        ),
        // `sageNote()`: the product's own voice, in sage rather than pink.
        AppCard(
          variant: AppCardVariant.sage,
          borderRadius: AppRadius.md,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            Text(
              l10n.itChecksItselfTheMomentTheSixth,
              style: AppText.body.copyWith(
                color: AppColors.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
