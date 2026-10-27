library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../private_coaching/domain/coaching_contract.dart'
    show SubscriptionStatus;
import '../../private_coaching/domain/subscription.dart' show Subscription;
import '../data/proof_images.dart';
import '../domain/payment_models.dart';
import 'pay_card.dart';
import 'payment_view.dart';
import 'proof_flow.dart';
import 'proof_view.dart';
import 'status_view.dart';

/// How a woman moves through PAY1 to PAY3 and PAY6. Pushed routes, not
/// routed ids (`appRoutes` is generated). [coachRoute] is H05's route name:
/// "back to my coach" pops to it.
abstract final class PaymentsNav {
  /// How PAY2 picks and hides pictures. Tests swap them.
  @visibleForTesting
  static Future<List<Uint8List>> Function() picker = pickProofImages;
  @visibleForTesting
  static PrepareImage prepare = prepareProofImage;

  /// The payment entry for H05, or null (no payment UI at all) while the
  /// feature is off. The server switch is asked by the card itself, so it can
  /// change while the screen is open.
  static Widget? payEntry(
    BuildContext context,
    Subscription sub, {
    required FeatureFlags flags,
    required String coachRoute,
  }) => flags.isOn(Feature.instapayPayments)
      ? PayEntryCard(
          subId: sub.id,
          canPay: sub.status == SubscriptionStatus.awaitingPayment,
          onPay: () => pay(Navigator.of(context), sub.id, coachRoute),
          onSeePayment: (p) => status(Navigator.of(context), p.id, coachRoute),
        )
      : null;

  static bool _home(Route<dynamic> r, String coachRoute) =>
      r.isFirst || r.settings.name == coachRoute;

  /// PAY1. [topUpOf] pays the missing part of a payment (spec 4.3).
  static void pay(
    NavigatorState nav,
    String subId,
    String coachRoute, {
    String? topUpOf,
  }) {
    unawaited(
      nav.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PaymentView(
            subId: subId,
            topUpOf: topUpOf,
            // Already past waiting: land on the status, not on PAY1.
            onInProgress: (p) => unawaited(
              nav.pushReplacement<void, void>(
                _statusRoute(nav, p.id, coachRoute),
              ),
            ),
            onIHavePaid: (p) => proof(nav, p, coachRoute),
          ),
        ),
      ),
    );
  }

  /// PAY2. A sent proof lands on PAY3; a queued one goes back to H05.
  static void proof(NavigatorState nav, Payment p, String coachRoute) {
    unawaited(
      nav.push<void>(
        MaterialPageRoute<void>(
          builder: (inner) => ProofView(
            payment: p,
            picker: picker,
            prepare: prepare,
            onSent: (result, {required bool queued}) {
              if (queued) {
                ScaffoldMessenger.maybeOf(inner)?.showSnackBar(
                  SnackBar(
                    content: Text(AppL10n.of(inner).savedWeWillSendItWhenYou),
                  ),
                );
                nav.popUntil((r) => _home(r, coachRoute));
                return;
              }
              unawaited(
                nav.pushAndRemoveUntil<void>(
                  _statusRoute(nav, p.id, coachRoute),
                  (r) => _home(r, coachRoute),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// PAY6: pictures added to a payment under review. Goes back to PAY3.
  static void addEvidence(NavigatorState nav, Payment p) {
    unawaited(
      nav.push<void>(
        MaterialPageRoute<void>(
          builder: (inner) => ProofView(
            payment: p,
            addEvidence: true,
            picker: picker,
            prepare: prepare,
            onSent: (result, {required bool queued}) {
              ScaffoldMessenger.maybeOf(inner)?.showSnackBar(
                SnackBar(
                  content: Text(AppL10n.of(inner).sentOwnHubWillLookAtIt),
                ),
              );
              nav.pop();
            },
          ),
        ),
      ),
    );
  }

  /// PAY3.
  static void status(NavigatorState nav, String paymentId, String coachRoute) {
    unawaited(nav.push<void>(_statusRoute(nav, paymentId, coachRoute)));
  }

  static Route<void> _statusRoute(
    NavigatorState nav,
    String paymentId,
    String coachRoute,
  ) => MaterialPageRoute<void>(
    builder: (_) => PaymentStatusView(
      paymentId: paymentId,
      onAction: (action, p) => _act(nav, action, p, coachRoute),
    ),
  );

  static void _act(
    NavigatorState nav,
    StatusAction action,
    Payment p,
    String coachRoute,
  ) {
    switch (action) {
      case StatusAction.pay:
        pay(nav, p.subId, coachRoute);
      case StatusAction.payRest:
        pay(nav, p.subId, coachRoute, topUpOf: p.id);
      case StatusAction.sendProof:
        proof(nav, p, coachRoute);
      case StatusAction.addProof:
        addEvidence(nav, p);
      case StatusAction.openCoaching:
        nav.popUntil((r) => _home(r, coachRoute));
      case StatusAction.agree:
        break;
    }
  }
}
