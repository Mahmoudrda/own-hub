/// §2 rule 6 — face blur defaults on.
///
/// G7 §5 owns the **default and the control**; the blur itself belongs to
/// whichever group is uploading the image (community, coach media, follow-ups).
/// Spine C11: "Blur is applied on-device before upload, and defaults on. No
/// unblurred image ever reaches Storage."
///
/// # The whole rule is one line, and the line is the point
///
/// `perImage ?? settings.blurFacesDefault`, where the stored default is `true`.
/// There is **no code path that reads a null default as false**: a missing
/// per-image choice falls back to her setting, and her setting is born on.
///
/// The failure this prevents is specific and common — an upload path that reads
/// `blurred: someBool ?? false` because `false` is the tidy default for a bool.
/// That one character ships an unblurred face. So the upload path is required to
/// call [MediaBlurPolicy.resolve] and is forbidden from reading the flag
/// directly (G7 §7.2); this type exists so that "read the flag directly" and
/// "apply the rule" are visibly different acts in a diff.
library;

import 'privacy_settings.dart';

class MediaBlurPolicy {
  const MediaBlurPolicy();

  /// Whether this image is blurred before it leaves the phone.
  ///
  /// [perImage] is her explicit choice for this one image — HANDOFF 8 makes
  /// turning blur off an explicit per-image action. Null means she did not
  /// choose, which is the normal case and must never read as "off".
  static bool resolve({bool? perImage, required PrivacySettings settings}) {
    return perImage ?? settings.blurFacesDefault;
  }

  /// True when turning this off is a decision that needs the consequence
  /// spelled out before it takes effect.
  ///
  /// G7 §5: flipping A03's switch off "opens a sheet stating the consequence and
  /// is recorded with `policyVersion`". Turning it *on* needs nothing — nobody
  /// has to be warned about becoming more private.
  static bool needsConsequenceSheet({required bool turningOn}) => !turningOn;
}
