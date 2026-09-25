/// One object that holds the whole identity check together, so wiring it into
/// the router is a few lines rather than a dozen.
///
/// The pieces have to share state and it is easy to get wrong in a way that
/// looks like a screen bug. Two things in particular:
///
///  * The capture service and the repository must hold **the same**
///    [VerificationEvidence], or `C10` fills one object and `C12` submits a
///    different, empty one, and the failure surfaces as "the server says the
///    card is missing" three files away from the mistake.
///  * They must also share **the same liveness session**. `C11` prompts the
///    challenge the server minted, and `C12` submits against that session id.
///    Two sessions means a set of frames answering questions nobody asked.
///
/// Constructing them together removes both possibilities instead of
/// documenting them.
///
/// Held for one sign-up and then dropped. Nothing here is a singleton: a second
/// attempt gets a second [IdentityCheck] with empty evidence and a fresh
/// challenge, which is what "she photographs the card again" should mean.
library;

import 'package:firebase_auth/firebase_auth.dart';

import '../domain/capture_consent.dart';
import '../domain/id_capture.dart';
import '../domain/verification.dart';
import '../domain/verification_evidence.dart';
import '../domain/verification_provider.dart';
import 'callable_verification_provider.dart';
import 'camera_capture_service.dart';
import 'provider_verification_repository.dart';

class IdentityCheck {
  IdentityCheck({
    required this.consent,
    VerificationProvider? provider,
    ClaimRefresher? refreshClaims,
  }) : _provider = provider ?? CallableVerificationProvider(),
       _refreshClaims = refreshClaims ?? _refreshIdToken;

  /// Where her agreement is recorded. Read before `C10` opens anything.
  final CaptureConsentStore consent;

  final VerificationProvider _provider;
  final ClaimRefresher _refreshClaims;

  /// The frames, in memory, for the seconds between the shutter and the call.
  final VerificationEvidence evidence = VerificationEvidence();

  late final CameraCaptureService _capture = CameraCaptureService(
    evidence: evidence,
  );

  CaptureService get capture => _capture;

  late final ProviderVerificationRepository _verification =
      ProviderVerificationRepository(
        provider: _provider,
        evidence: evidence,
        refreshClaims: _refreshClaims,
      );

  VerificationRepository get verification => _verification;

  /// Mints the liveness challenge and hands it to both halves.
  ///
  /// Called once, immediately before `C11` opens. Not before `C10`: the session
  /// has an expiry measured in a minute or two, and starting it while she is
  /// still finding her ID card in her bag would burn most of it on the card
  /// steps.
  ///
  /// Returns false when no session could be minted. `C11` then refuses and
  /// offers the video call rather than opening a camera for frames nothing can
  /// score.
  Future<bool> startLiveness() async {
    try {
      final challenge = await _provider.startSession();
      if (!challenge.isRunnable) return false;
      _capture.challenge = challenge;
      _verification.challenge = challenge;
      return true;
    } catch (_) {
      // Logged by nobody on purpose: a failure here is not about her, and the
      // screen that called this says something true and moves on.
      return false;
    }
  }

  /// Whether the camera may open at all.
  ///
  /// The router asks this before it builds `C10`. A woman who has not agreed,
  /// or who agreed to wording we have since changed, goes back to the consent
  /// screen rather than straight to a lens.
  Future<bool> mayOpenCamera(String uid) async =>
      await consent.current(uid) != null;

  /// Drops whatever is still held. Safe to call more than once.
  void abandon() {
    evidence.shred();
    _capture.challenge = null;
    _verification.challenge = null;
  }

  /// Forces a fresh ID token so the custom claim the function wrote becomes
  /// visible to the app.
  ///
  /// This is the whole reason `refreshToken` exists in the response. Without
  /// it, a woman is told "You're in" on `C13` and then meets an app that still
  /// believes she is unverified, and since the gate is now the whole app rather
  /// than just the community, that is a locked door rather than a cosmetic bug.
  static Future<void> _refreshIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.getIdToken(true);
  }
}
