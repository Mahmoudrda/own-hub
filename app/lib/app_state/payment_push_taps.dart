/// A tap on a payments push, turned into a screen.
///
/// The push carries a kind and an id (`features/payments/domain/payment_push.
/// dart`); anything that is not on that list opens nothing. These screens are
/// pushed as pages, not routed ids, so the router's gate does not run on them:
/// [open] asks [allowed] about her coach screen first (`H05`, or `K18` for the
/// coach side), which is where the sign-in, the verification check and the
/// feature flags are answered. A closed gate opens nothing, and the app stays
/// where the tap left it.
///
/// Only pushes: a tap never changes anything on a payment.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../features/payments/domain/payment_push.dart';
import '../features/payments/presentation/payments_navigation.dart';
import '../routing/app_routes.dart';

abstract final class PaymentPushTaps {
  /// Her coach screen (client side) and her coach space: the screens whose
  /// gates stand in for the payment screens opened over them.
  static const String clientScreen = 'H05';
  static const String coachScreen = 'K18';

  /// Opens the screen [data] names, or nothing. [allowed] answers whether a
  /// screen may be opened for her now. Returns whether anything opened.
  static bool open(
    NavigatorState? navigator,
    Map<String, Object?> data, {
    required bool Function(String screenId) allowed,
  }) {
    final push = paymentPushFor(data);
    if (navigator == null || push == null) return false;
    if (!allowed(push.forCoach ? coachScreen : clientScreen)) return false;
    final coachRoute = appRoutes[clientScreen]!.name;
    switch (push.screen) {
      case PaymentPushScreen.status:
        final id = push.paymentId;
        if (id == null) {
          // No payment named: her coach screen, where the payment card is.
          unawaited(navigator.pushNamed<Object?>(coachRoute));
        } else {
          PaymentsNav.status(navigator, id, coachRoute);
        }
      case PaymentPushScreen.coachInbox:
        PaymentsNav.coachPayments(navigator);
      case PaymentPushScreen.coachAddress:
        PaymentsNav.coachAddress(navigator);
      case PaymentPushScreen.statements:
        PaymentsNav.coachStatements(navigator, month: push.statementMonth);
    }
    return true;
  }
}
