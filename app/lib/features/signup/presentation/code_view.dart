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
/// The screen shows the number she actually typed, read from [AuthAwaitingCode],
/// so a mistyped number is obvious here, and "Edit number" takes her back to
/// fix it. A failed check keeps her digits and says why under the boxes: a code
/// that did not match, one that expired, no connection, or too many tries.
///
/// After the provider accepts the code there is still work to do (her claim
/// and her check's status are read before the next screen is chosen), so the
/// screen stays busy and says "Checking your code" until that is done. A
/// second tap in that window used to push the next screen twice.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_code_field.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_step_progress.dart';
import '../domain/auth_repository.dart';

class CodeView extends StatefulWidget {
  /// How long "Send it again" waits after a code was sent.
  static const Duration resendWait = Duration(seconds: 30);

  const CodeView({
    super.key,
    required this.repository,
    this.testCode,
    this.onConfirmed,
    this.onResent,
    this.onResendRefused,
    this.onBack,
    this.onEditNumber,
  });

  final AuthRepository repository;

  /// The code this build accepts, named on screen when there is one.
  ///
  /// Null against a real provider and null whenever an account is required —
  /// the caller decides, because that is a product gate rather than a screen's
  /// business. See [testCodeOf].
  final String? testCode;

  /// Fired when the provider has accepted the code and the account exists.
  ///
  /// Awaited: the screen stays busy until it completes, so the reads that
  /// decide where she goes next are not a silent wait with a live button.
  final Future<void> Function()? onConfirmed;

  /// How long she waits, once the code is sent, before the screen says it is
  /// still working (the same idea as `CheckingView.slowAfter`).
  static const Duration slowAfter = Duration(seconds: 8);

  /// A new code has gone out. The caller says so, because what there is to say
  /// depends on whether anything was really sent — see [testCode].
  final VoidCallback? onResent;

  /// The provider refused another send: she has asked too many times.
  final VoidCallback? onResendRefused;

  final VoidCallback? onBack;

  /// Back to `C06` to correct the number.
  final VoidCallback? onEditNumber;

  @override
  State<CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _resendFocus = FocusNode();
  bool _checking = false;

  /// True once the confirmation has run longer than [CodeView.slowAfter].
  bool _slow = false;
  Timer? _slowTimer;

  /// Why the last check failed, or null. Cleared when she edits the code.
  AuthFailure? _failure;
  String _failedCode = '';

  /// Seconds before "Send it again" is live. A code was sent the moment this
  /// screen opened, and every resend is a paid SMS: a tap that cannot get a
  /// new code yet is money spent and a second message she has to tell apart
  /// from the first. The provider's own limit still stands behind this one.
  int _resendIn = 0;
  Timer? _resendTimer;

  void _startResendWait() {
    _resendTimer?.cancel();
    setState(() => _resendIn = CodeView.resendWait.inSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) {
        timer.cancel();
        _resendTimer = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Continue is offered only on six digits, so the button's state follows
    // the boxes. Without this it rendered live on an empty field and did
    // nothing when tapped, which reads as a broken button rather than as a
    // code that is not finished.
    _controller.addListener(_onTyped);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startResendWait();
    });
  }

  void _onTyped() {
    if (!mounted) return;
    setState(() {
      if (_failure != null && _controller.text != _failedCode) _failure = null;
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTyped)
      ..dispose();
    _resendFocus.dispose();
    _resendTimer?.cancel();
    _slowTimer?.cancel();
    super.dispose();
  }

  /// Six digits are in the boxes and nothing is in flight.
  bool get _canConfirm =>
      !_checking && _controller.text.length == kVerificationCodeLength;

  /// The number the code was actually sent to, or null when the state is
  /// somehow not [AuthAwaitingCode]. Reaching this screen without having sent
  /// a code is a routing bug, and the line is left out rather than showing a
  /// number that is not hers.
  String? _sentToNumber() {
    final state = widget.repository.current;
    return state is AuthAwaitingCode ? state.phoneNumber : null;
  }

  Future<void> _confirm(String code) async {
    if (_checking || code.length != kVerificationCodeLength) return;
    setState(() {
      _checking = true;
      _slow = false;
      _failure = null;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(CodeView.slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
    try {
      await widget.repository.confirmCode(code);
      if (!mounted) return;
      // Held busy until the next screen has been chosen.
      await widget.onConfirmed?.call();
    } on AuthException catch (error) {
      // Her digits stay, and the reason is said under them.
      if (mounted) {
        setState(() {
          _failure = error.failure;
          _failedCode = _controller.text;
        });
        if (error.failure == AuthFailure.codeExpired) {
          _resendFocus.requestFocus();
        }
      }
    } finally {
      _slowTimer?.cancel();
      if (mounted) {
        setState(() {
          _checking = false;
          _slow = false;
        });
      }
    }
  }

  String _failureText(AppL10n l10n, AuthFailure failure) => switch (failure) {
    AuthFailure.invalidCode => l10n.thatCodeDidNotMatchCheckThe,
    AuthFailure.codeExpired => l10n.thatCodeHasExpiredAskForA_1vzf3,
    AuthFailure.network => l10n.noConnectionTryAgainWhenYouAre,
    AuthFailure.tooManyAttempts => l10n.tooManyTriesWaitAMinuteThen,
    AuthFailure.invalidNumber ||
    AuthFailure.unknown => l10n.weCouldNotCheckTheCodeTry,
  };

  Future<void> _resend() async {
    if (_resendIn > 0) return;
    _startResendWait();
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
    final sentTo = _sentToNumber();
    final failure = _failure;

    return AppScaffold(
      appBar: AppTopBar(
        title: signupPhaseLabel(l10n, SignupPhase.number),
        onBack: widget.onBack,
      ),
      footer: [
        if (_checking)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.checkingYourCode,
                    key: const ValueKey('code-checking'),
                    textAlign: TextAlign.center,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (_checking && _slow)
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.stillWorkingASlowConnectionCanTake,
              key: const ValueKey('code-slow'),
              textAlign: TextAlign.center,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        AppButton(
          l10n.continueLabel,
          // Live only on a full code. See [_canConfirm].
          onPressed: _canConfirm ? () => _confirm(_controller.text) : null,
        ),
        Focus(
          focusNode: _resendFocus,
          child: AppButton(
            _resendIn > 0
                ? l10n.sendItAgainInTime(
                    '0:${_resendIn.toString().padLeft(2, '0')}',
                  )
                : l10n.sendItAgain,
            variant: AppButtonVariant.text,
            height: 44,
            fontSize: 15,
            onPressed: _checking || _resendIn > 0 ? null : _resend,
          ),
        ),
      ],
      children: [
        Text(l10n.typeTheCode, style: AppText.display),
        if (sentTo != null)
          Text(
            // Her number, not the mockup's. The repository already holds it:
            // sendCode moves the state to AuthAwaitingCode carrying exactly
            // what she typed, so a mistyped number is obvious here rather
            // than after waiting for a message that will never arrive.
            l10n.weSentSixDigitsToPhone(sentTo),
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        if (widget.onEditNumber != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton(
              l10n.editNumber,
              variant: AppButtonVariant.text,
              height: 44,
              fontSize: 15,
              onPressed: _checking ? null : widget.onEditNumber,
            ),
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
        // Digits are typed and read left to right in Arabic too, so the
        // boxes fill from the left, in the order she types them.
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppCodeField(
            // Six, from the auth layer. Never a literal on a screen.
            length: kVerificationCodeLength,
            controller: _controller,
            enabled: !_checking,
            onCompleted: _confirm,
          ),
        ),
        if (failure != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _failureText(l10n, failure),
              key: const ValueKey('code-error'),
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          ),
        // `sageNote()`: the product's own voice, in sage rather than pink.
        AppCard(
          variant: AppCardVariant.sage,
          borderRadius: AppRadius.md,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            Text(
              // The first sentence only, on both platforms. The Android
              // sentence said the message was read for her, and this screen
              // holds no subscription that would act on it, so it waited for
              // digits anyway.
              l10n.itChecksItselfTheMomentTheSixth_1pr5i,
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
