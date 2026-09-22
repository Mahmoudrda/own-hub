/// §2 rule 11 — displayed, never ranked — enforced by what the projection can
/// hold.
///
/// G7 §5 owns rule 11 as **the projection**: what another member sees of her is
/// built "from an allowlisted field set that structurally cannot contain weight
/// or measurements", backed by spine C7 (no such index exists, so the sort
/// cannot be executed even if someone wrote the query).
///
/// # Two different numbers, and only one of them is banned
///
/// This distinction is easy to collapse and the whole rule depends on it:
///
///   * **Scale weight and body measurements** — `measurements.weightKg`,
///     `measurements.body`. Private to her, never projected, and there is no
///     field on [PublicProfile] or [PublicBest] that could carry one.
///   * **A lift** — "goblet squat, 14 kg × 9". That is her *result*, it is what
///     A03's "Show my personal bests · numbers only, never weight from a scale"
///     is offering, and it is allowed.
///
/// So [PublicBest] carries `loadKg`, and nothing anywhere carries her body. A
/// reviewer does not have to remember which is which; the type only has room for
/// one of them.
///
/// # The allowlist is the constructor
///
/// [PublicProfileProjection.build] takes named parameters for exactly the fields
/// that may be published and ignores everything else. A future caller who wanted
/// to publish her weight would have to add a parameter, a field and a line — all
/// three visible in a diff — rather than forget to strip one.
library;

import 'package:meta/meta.dart';

import 'privacy_settings.dart';

/// One personal best, as another member may see it.
///
/// No `weightKg`, no `body`, no measurement of any kind. See the file note on
/// why `loadKg` is a different thing.
@immutable
class PublicBest {
  const PublicBest({
    required this.exerciseId,
    required this.loadKg,
    required this.reps,
  });

  final String exerciseId;

  /// What she lifted, not what she weighs.
  final num loadKg;
  final int reps;

  @override
  bool operator ==(Object other) =>
      other is PublicBest &&
      other.exerciseId == exerciseId &&
      other.loadKg == loadKg &&
      other.reps == reps;

  @override
  int get hashCode => Object.hash(exerciseId, loadKg, reps);
}

/// Everything another member may see. The allowlist, as a type.
@immutable
class PublicProfile {
  const PublicProfile({
    this.firstName,
    this.verified = false,
    this.groups = const <String>[],
    this.bests = const <PublicBest>[],
    this.visible = true,
  });

  /// Nothing is published at all.
  ///
  /// Not an empty profile — an *absent* one. `profileVisible == false` means she
  /// does not appear, and a profile rendered with her name blanked out would
  /// still confirm that the account exists.
  static const PublicProfile hidden = PublicProfile(visible: false);

  /// Typed by her, never lifted off the ID (spine §1: the ID images are deleted
  /// under rule 7, and a legal name is not what she consented to publish).
  final String? firstName;

  final bool verified;
  final List<String> groups;

  /// Empty whenever `showBests` is off. Emptied at projection time rather than
  /// filtered at render time, so a screen cannot accidentally read past it.
  final List<PublicBest> bests;

  final bool visible;

  @override
  String toString() => visible
      ? 'PublicProfile($firstName, ${bests.length} bests)'
      : 'PublicProfile.hidden';
}

class PublicProfileProjection {
  const PublicProfileProjection();

  /// Builds what another member sees, from her settings.
  ///
  /// Both switches are honoured independently: `profileVisible` decides whether
  /// she appears at all, `showBests` decides whether her bests travel with her.
  /// Neither implies the other.
  static PublicProfile build({
    required PrivacySettings settings,
    String? firstName,
    bool verified = false,
    List<String> groups = const <String>[],
    List<PublicBest> bests = const <PublicBest>[],
  }) {
    if (!settings.profileVisible) return PublicProfile.hidden;

    return PublicProfile(
      firstName: firstName,
      verified: verified,
      groups: List<String>.unmodifiable(groups),
      bests: settings.showBests
          ? List<PublicBest>.unmodifiable(bests)
          : const <PublicBest>[],
    );
  }
}
