/// The server's off button for InstaPay payments (`config/payments.enabled`).
///
/// A missing document or anything but `true` means off: no pay card, no way
/// to start a payment, no InstaPay row in the coach space. A payment that is
/// already open stays readable and can still be answered (spec 10), because
/// those screens do not ask this switch.
library;

import 'package:flutter/foundation.dart';

import '../domain/flags/feature_flags.dart';
import '../features/payments/data/payments_hub.dart';
import '../routing/app_router.dart';
import 'app_changes.dart';

abstract final class PaymentsSwitch {
  /// What the server said at the last read. Off until it has said on.
  static bool enabled = false;

  /// Whether a NEW payment may be started: the compiled-in flag AND the
  /// server switch.
  static bool get live =>
      AppRouter.featureFlags.isOn(Feature.instapayPayments) && enabled;

  /// Reads the document once. Never throws; a failed read keeps the last answer.
  static Future<void> load() async {
    try {
      final repo = PaymentsHub.repository;
      if (repo == null) return;
      final value = await repo.paymentsEnabled();
      if (value == null || value == enabled) return;
      enabled = value;
      AppChanges.bump();
    } catch (_) {}
  }

  @visibleForTesting
  static void resetForTest() => enabled = false;
}
