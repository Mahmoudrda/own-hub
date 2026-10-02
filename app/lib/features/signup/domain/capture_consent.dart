/// Her agreement to be photographed, recorded before the lens opens.
///
/// The camera on `C10` is the first moment this product asks an Egyptian woman
/// for a picture of her face and her national ID card, and the first moment
/// those leave the country: the function runs on Google Cloud, in Frankfurt,
/// which is not Egypt. She is told that in her own language and agrees to it
/// explicitly, before anything opens, and the agreement is written down.
///
/// **What is recorded, and nothing else.** A uid, the version of the text she
/// agreed to, and when. Not the text, not a device fingerprint, not an IP
/// address, not her name. The version is what makes the record worth keeping:
/// "she consented" is unanswerable a year later when the wording has changed
/// twice, while "she consented to [kCaptureConsentVersion]" can be checked
/// against a text we still have.
///
/// **Why a version number and not a boolean.** A boolean means that rewriting
/// the consent copy silently re-uses an old agreement for new terms, which is
/// the exact failure that makes consent records worthless in an audit. A
/// version means the next change to the wording invalidates the old record and
/// asks her again, because the code compares what she agreed to against what is
/// currently on the screen.
library;

import 'package:meta/meta.dart';

/// The wording she is agreeing to, by number.
///
/// Version 1 is the consent wording dated 2026-09-25.
///
/// **Bump this whenever the consent copy changes in either language**, and in
/// particular whenever the list of processors changes. Adding a processor to
/// that screen without bumping this would leave every existing woman recorded
/// as having agreed to something she was never shown.
///
/// **It is an int, and it must move together with the server's
/// `config.CONSENT_VERSION`** (functions/identity/config.py). The server
/// refuses any other value with `consent_missing`, and the record it writes
/// lives at `users/{uid}/consents/verification-v<version>`. The shared
/// fixture `contracts/identity_contract.json` pins both sides; the Dart and
/// Python contract tests fail if either drifts.
///
/// Not bumped for the revision that removed Amazon Web Services from the
/// screen and replaced the 72 hour retention line with "nothing is kept". Both
/// changes happened on 2026-09-25, before any build reached a handset, so there
/// is no record anywhere that was taken against the superseded wording. The
/// next change to this text will not have that excuse.
const int kCaptureConsentVersion = 1;

/// One agreement, as it is stored.
@immutable
class CaptureConsent {
  const CaptureConsent({
    required this.uid,
    required this.version,
    required this.agreedAt,
  });

  final String uid;

  /// The [kCaptureConsentVersion] in force when she tapped agree.
  final int version;

  final DateTime agreedAt;

  /// Whether this record still covers what the screen says today.
  bool get isCurrent => version == kCaptureConsentVersion;

  Map<String, Object?> toJson() => <String, Object?>{
    'uid': uid,
    'version': version,
    'agreedAt': agreedAt.toUtc().toIso8601String(),
  };
}

/// Where consent is written and read back.
///
/// Read as well as written, because the check that matters is at the top of
/// `C10`: if there is no current consent, no camera opens. A record written and
/// never read is decoration.
abstract class CaptureConsentStore {
  /// Her current agreement, or null if she has never agreed or agreed to older
  /// wording.
  Future<CaptureConsent?> current(String uid);

  Future<void> record(CaptureConsent consent);
}

/// In memory, for tests and for a build with no back end.
///
/// It is honest about what it is: consent that does not survive a restart is
/// not a consent record, and the Firestore implementation is what actually
/// satisfies the spec. This exists so the screen can be built and tested
/// without a project.
class InMemoryCaptureConsentStore implements CaptureConsentStore {
  final Map<String, CaptureConsent> _byUid = <String, CaptureConsent>{};

  @override
  Future<CaptureConsent?> current(String uid) async {
    final held = _byUid[uid];
    return held != null && held.isCurrent ? held : null;
  }

  @override
  Future<void> record(CaptureConsent consent) async {
    _byUid[consent.uid] = consent;
  }
}
