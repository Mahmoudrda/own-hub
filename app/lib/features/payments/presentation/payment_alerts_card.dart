/// The one-tap "turn on payment alerts" offer, on the coach's Payments inbox
/// and on a payment's status screen.
///
/// Payment pushes are a second yes, separate from the one on `C14`: the server
/// sends them only to a phone that listed "payments" when it registered
/// (`functions/payments/notices.py`). So nothing here asks at launch or on its
/// own. She taps, the card says exactly what will be sent (payment updates
/// only, nothing on the lock screen that names a person or an amount), and the
/// phone's own prompt follows if it has not been answered. Once she has said
/// yes the card goes; if the phone refuses notifications it says how to turn
/// them on in Settings instead of asking again.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_state/push_registration.dart'
    show PushAlertState, PushOptIn;
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';

/// What the card needs from the app: where payment alerts stand, how to turn
/// them on (the same registrar and watch `C14` uses), and the phone's
/// Settings. The router supplies it; a build with no push supplies none and no
/// card is drawn.
class PaymentAlertsAccess {
  const PaymentAlertsAccess({
    required this.state,
    required this.turnOn,
    required this.openSettings,
  });

  /// Read without asking for anything.
  final Future<PushAlertState> Function() state;

  /// Asks for the phone's permission if it has not been answered, registers the
  /// phone for payment alerts, and says what came of it. Takes her language.
  final Future<PushOptIn> Function(String locale) turnOn;

  final VoidCallback openSettings;

  /// The app's own, set by the router. Null draws no card.
  static PaymentAlertsAccess? current;
}

/// Whose words the card uses.
enum PaymentAlertsFor { coach, client }

class PaymentAlertsCard extends StatefulWidget {
  const PaymentAlertsCard({super.key, required this.who, this.access});

  final PaymentAlertsFor who;

  /// Tests hand in their own; the app's is [PaymentAlertsAccess.current].
  final PaymentAlertsAccess? access;

  @override
  State<PaymentAlertsCard> createState() => _PaymentAlertsCardState();
}

class _PaymentAlertsCardState extends State<PaymentAlertsCard> {
  PushAlertState? _state;
  PushOptIn? _answer;
  bool _busy = false;

  PaymentAlertsAccess? get _access =>
      widget.access ?? PaymentAlertsAccess.current;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  Future<void> _read() async {
    final access = _access;
    if (access == null) return;
    PushAlertState state;
    try {
      state = await access.state();
    } catch (_) {
      state = PushAlertState.unavailable;
    }
    if (mounted) setState(() => _state = state);
  }

  Future<void> _turnOn() async {
    final access = _access;
    if (access == null || _busy) return;
    final locale = Localizations.localeOf(context).languageCode;
    setState(() => _busy = true);
    PushOptIn answer;
    try {
      answer = await access.turnOn(locale);
    } catch (_) {
      answer = PushOptIn.unavailable;
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _answer = answer;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = _access;
    final state = _state;
    // Nothing to offer: no push in this build, still reading, already on, or
    // a phone that cannot receive them.
    if (access == null ||
        state == null ||
        (_answer == null &&
            (state == PushAlertState.on ||
                state == PushAlertState.unavailable))) {
      return const SizedBox.shrink();
    }
    final l10n = AppL10n.of(context);
    if (_answer == PushOptIn.on) {
      return Semantics(
        liveRegion: true,
        child: Text(
          l10n.paymentAlertsAreOnForThisPhone,
          key: const ValueKey('payment-alerts-on'),
          style: AppText.bodyM,
        ),
      );
    }
    final blocked =
        _answer == PushOptIn.denied ||
        (_answer == null && state == PushAlertState.blocked);
    final coach = widget.who == PaymentAlertsFor.coach;
    return AppCard(
      key: const ValueKey('payment-alerts-card'),
      variant: AppCardVariant.tonal,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            blocked
                ? l10n.notificationsAreOffForOwnHubOn
                : coach
                ? l10n.ownHubCanTellYouOnThis
                : l10n.weWillSendANotificationToThis,
            style: AppText.bodyM,
          ),
        ),
        if (_answer == PushOptIn.unavailable)
          Text(
            l10n.weCouldNotDoThatTryAgain,
            key: const ValueKey('payment-alerts-failed'),
            style: AppText.bodyM,
          ),
        if (blocked)
          AppButton(
            l10n.openSettings,
            key: const ValueKey('payment-alerts-settings'),
            variant: AppButtonVariant.outlined,
            height: 48,
            onPressed: access.openSettings,
          )
        else
          AppButton(
            coach ? l10n.turnOnPaymentAlerts : l10n.tellMeWhenItChanges,
            key: const ValueKey('payment-alerts-turn-on'),
            variant: AppButtonVariant.outlined,
            height: 48,
            onPressed: _busy ? null : () => unawaited(_turnOn()),
          ),
      ],
    );
  }
}
