/// `claim_fast_verification`: asked right after a code is accepted, so a
/// number the team already knows opens the app without a check.
///
/// The server decides. It approves only when the token's phone number is on
/// the pre-approved list, the test list or the store-reviewer list, and
/// answers `none` for everyone else. Any failure here, including a callable
/// that is not deployed yet, reads as `none`: she is sent to the check as
/// she was before, and nothing is granted on the phone's say-so.
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../../app_state/firebase_boot.dart';

const String kClaimFastVerificationCallable = 'claim_fast_verification';

enum FastVerification { approved, none }

abstract class FastVerificationClaimer {
  /// Never throws; any trouble is [FastVerification.none].
  Future<FastVerification> claim();
}

class CallableFastVerificationClaimer implements FastVerificationClaimer {
  const CallableFastVerificationClaimer({
    this.timeout = const Duration(seconds: 6),
  });

  final Duration timeout;

  @override
  Future<FastVerification> claim() async {
    if (!FirebaseBoot.isReady) return FastVerification.none;
    try {
      final callable = FirebaseBoot.functions.httpsCallable(
        kClaimFastVerificationCallable,
        options: HttpsCallableOptions(timeout: timeout),
      );
      final response = await callable.call<Object?>(<String, Object?>{});
      final data = response.data;
      return data is Map && data['state'] == 'approved'
          ? FastVerification.approved
          : FastVerification.none;
    } catch (_) {
      return FastVerification.none;
    }
  }
}

/// Where the router asks. Replaced in tests.
@visibleForTesting
FastVerificationClaimer? fastVerificationClaimerOverride;

FastVerificationClaimer get fastVerificationClaimer =>
    fastVerificationClaimerOverride ?? const CallableFastVerificationClaimer();
