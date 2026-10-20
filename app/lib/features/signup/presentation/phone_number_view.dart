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
/// The action is *gated*: the button does nothing until the number is long
/// enough to be an Egyptian mobile, counting Arabic-Indic digits as digits. A
/// rejected attempt leaves her on the screen with her number intact and says
/// why, out loud, under the field: a wrong number, no connection, too many
/// tries, or a send that failed for a reason that is not hers.
///
/// **It is also where she accepts the Terms and the Privacy Policy** (M1).
/// The button reads "Agree and send me a code" and the line under it names
/// both documents and opens them, so one tap is the acceptance and the send,
/// and no extra step is added. Before the code is sent the acceptance is
/// written to this phone ([PendingLegalAcceptance]); the router sends it to
/// the server once her code is accepted. The line above the button says
/// where her number and her account go. Crash reports are an optional
/// switch here, off unless she turns it on, and apply at once.
///
/// "Help improve Own Hub" (usage statistics) is a second optional switch,
/// separate from crash reports and from the acceptance: a different purpose
/// and a different transfer, so a different choice. Off unless she turns it
/// on, applied before the code is sent, and changeable later in Privacy.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_step_progress.dart';
import '../../../ui/app_toggle.dart';
import '../../../ui/hand/hand.dart';
import '../domain/auth_repository.dart';
import '../domain/digits.dart';
import '../domain/legal_acceptance.dart';
import '../domain/phone_format.dart';

class PhoneNumberView extends StatefulWidget {
  const PhoneNumberView({
    super.key,
    required this.repository,
    this.onCodeSent,
    this.onBack,
    this.onOpenTerms,
    this.onOpenPrivacy,
    this.crashReportsInitially = false,
    this.onCrashReportsChosen,
    this.analyticsInitially = false,
    this.onAnalyticsChosen,
    this.now,
    this.signIn = false,
  });

  final AuthRepository repository;

  /// Opens on the sign-in wording instead of sign-up. One tap on the toggle
  /// switches it, and the number she typed stays.
  final bool signIn;

  /// Open the Terms of Use and the Privacy Policy in her language. Null while
  /// the pages have no address, and the names are then plain text.
  final VoidCallback? onOpenTerms;
  final VoidCallback? onOpenPrivacy;

  /// Where the crash-report switch starts. Off unless she allowed it before.
  final bool crashReportsInitially;

  /// Her crash-report choice, applied before the code is sent.
  final Future<void> Function(bool allowed)? onCrashReportsChosen;

  /// Where the usage-statistics switch starts. Off unless she allowed it.
  final bool analyticsInitially;

  /// Her usage-statistics choice, applied before the code is sent. Null
  /// hides the switch.
  final Future<void> Function(bool allowed)? onAnalyticsChosen;

  /// Injectable so a test can assert the recorded time.
  final DateTime Function()? now;

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
  late bool _signIn = widget.signIn;
  bool _formatting = false;

  /// The optional crash-report switch. Off unless she turns it on.
  late bool _crashReports = widget.crashReportsInitially;

  /// The optional usage-statistics switch. Off unless she turns it on.
  late bool _analytics = widget.analyticsInitially;

  /// Why the last send failed, or null. Cleared as soon as she edits the
  /// number, because the sentence is about the number she sent.
  AuthFailure? _failure;

  /// The text the failure was about.
  String _failedText = '';

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
    if (!mounted) return;
    // Pasted, autofilled or typed: one shape. See `formatEgyptianMobile`.
    if (!_formatting) {
      final formatted = formatEgyptianMobile(_controller.value);
      if (formatted != _controller.value) {
        _formatting = true;
        _controller.value = formatted;
        _formatting = false;
      }
    }
    setState(() {
      if (_failure != null && _controller.text != _failedText) _failure = null;
    });
  }

  /// Arabic-Indic digits count, because an Arabic keyboard types them.
  String get _digits => asciiDigits(_controller.text);

  /// Full international form. The field already holds only the ten digits
  /// after the country code, so `+200100…` cannot be built.
  String get _e164 => '+20$_digits';

  bool get _canSend =>
      !_sending &&
      _digits.length == kEgyptianMobileDigits &&
      !_digits.startsWith('0');

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() {
      _sending = true;
      _failure = null;
    });
    // Her tap is the acceptance, recorded on this phone before anything is
    // sent, then her crash-report choice. Only then does a code go out.
    final locale = Localizations.localeOf(context).languageCode;
    await PendingLegalAcceptance.write(
      LegalAcceptance.now(locale, clock: widget.now),
    );
    await widget.onCrashReportsChosen?.call(_crashReports);
    await widget.onAnalyticsChosen?.call(_analytics);
    if (!mounted) return;
    try {
      await widget.repository.sendCode(_e164);
      if (!mounted) return;
      widget.onCodeSent?.call();
    } on AuthException catch (error) {
      // She keeps her number and is told why, so a typo and a dead connection
      // no longer look the same.
      if (mounted) {
        setState(() {
          _failure = error.failure;
          _failedText = _controller.text;
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _failureText(AppL10n l10n, AuthFailure failure) => switch (failure) {
    AuthFailure.invalidNumber => l10n.thatNumberDoesNotLookRightCheck,
    AuthFailure.network => l10n.noConnectionYourNumberIsStillHere,
    AuthFailure.tooManyAttempts => l10n.tooManyTriesWaitAMinuteThen,
    AuthFailure.invalidCode ||
    AuthFailure.codeExpired ||
    AuthFailure.unknown => l10n.weCouldNotSendTheCodeTry,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final failure = _failure;

    return AppScaffold(
      appBar: AppTopBar(
        title: signupPhaseLabel(l10n, SignupPhase.number),
        onBack: widget.onBack,
      ),
      footer: [
        AppButton(l10n.agreeAndSendMeACode, onPressed: _canSend ? _send : null),
        LegalAcceptanceLine(
          text: l10n.byTappingAgreeAndSendMeA,
          links: [
            (l10n.termsOfUse, widget.onOpenTerms),
            (l10n.privacyPolicy, widget.onOpenPrivacy),
          ],
        ),
        if (AppRouter.featureFlags.isOn(Feature.community))
          Text(
            l10n.byJoiningYouAgreeToTheCommunity,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
      ],
      children: [
        Text(
          _signIn ? l10n.signInWithYourNumber : l10n.whatsYourNumber,
          style: AppText.display,
        ),
        Text(
          l10n.weTextYouASixDigitCode_18wn2,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        // Left to right in both languages: a phone number is written +20 then
        // the digits, and in Arabic the row used to mirror and put the dialling
        // code after her number.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
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
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  onSubmitted: (_) => _send(),
                ),
              ),
            ],
          ),
        ),
        if (failure != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _failureText(l10n, failure),
              key: const ValueKey('phone-error'),
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          ),
        // Sign up and sign in are the same flow; this only changes the words,
        // and the number she typed stays.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton(
            _signIn
                ? l10n.newHereCreateAccount
                : l10n.alreadyHaveAnAccountSignIn,
            key: const ValueKey('phone-toggle-intent'),
            variant: AppButtonVariant.text,
            height: 44,
            fontSize: 15,
            onPressed: _sending
                ? null
                : () => setState(() => _signIn = !_signIn),
          ),
        ),
        // Where her number and her account go, before she sends either.
        Text(
          l10n.toSendYourCodeYourNumberGoes,
          key: const ValueKey('phone-transfer-notice'),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        // Optional, off by default, and changeable later in Privacy.
        AppListItem(
          title: l10n.sendCrashReports,
          subtitle: l10n.optionalHelpsUsFixTheAppNo,
          trailing: AppToggle(
            key: const ValueKey('phone-crash-reports'),
            value: _crashReports,
            semanticLabel: l10n.sendCrashReports,
            onChanged: (value) => setState(() => _crashReports = value),
          ),
          onTap: () => setState(() => _crashReports = !_crashReports),
        ),
        // Its own choice, beside crash reports and never folded into them.
        if (widget.onAnalyticsChosen != null)
          AppListItem(
            title: l10n.helpImproveOwnHub,
            subtitle: l10n.optionalSharesBasicAppUsageWithGoogle,
            trailing: AppToggle(
              key: const ValueKey('phone-analytics'),
              value: _analytics,
              semanticLabel: l10n.helpImproveOwnHub,
              onChanged: (value) => setState(() => _analytics = value),
            ),
            onTap: () => setState(() => _analytics = !_analytics),
          ),
      ],
    );
  }
}

/// A sentence with the names of documents in it, each name opening its page.
///
/// The names are found in the sentence as the dictionary spells them,
/// ignoring case, so the sentence stays one translatable string in both
/// languages. A name whose callback is null is plain text: a link that opens
/// nothing is worse than none.
class LegalAcceptanceLine extends StatefulWidget {
  const LegalAcceptanceLine({
    super.key,
    required this.text,
    required this.links,
  });

  final String text;
  final List<(String, VoidCallback?)> links;

  @override
  State<LegalAcceptanceLine> createState() => _LegalAcceptanceLineState();
}

class _LegalAcceptanceLineState extends State<LegalAcceptanceLine> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final base = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);
    final linkStyle = base.copyWith(
      color: AppColors.primary,
      decoration: TextDecoration.underline,
    );
    final text = widget.text;
    final lower = text.toLowerCase();

    // Where each linked name sits in the sentence, first match only.
    final found = <(int, int, VoidCallback)>[];
    for (final (name, onTap) in widget.links) {
      if (onTap == null || name.isEmpty) continue;
      final at = lower.indexOf(name.toLowerCase());
      if (at >= 0) found.add((at, at + name.length, onTap));
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final (start, end, onTap) in found) {
      if (start < cursor) continue;
      if (start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, start)));
      }
      final recognizer = TapGestureRecognizer()..onTap = onTap;
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: linkStyle,
          recognizer: recognizer,
        ),
      );
      cursor = end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));

    return Text.rich(
      TextSpan(style: base, children: spans),
      key: const ValueKey('legal-acceptance-line'),
    );
  }
}
