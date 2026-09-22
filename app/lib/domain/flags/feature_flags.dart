/// Which parts of the product are switched on.
///
/// One object, read everywhere, written in one place. It exists so a feature
/// can be finished, merged and shipped **dark** — present in the binary,
/// unreachable in the UI — and turned on when it is actually ready rather than
/// when the code happens to land.
///
/// ## Why an enum and not a `Map<String, bool>`
///
/// A string-keyed map makes a typo a silent "off", and silent-off on a safety
/// surface is the worst failure this product has. Every flag is a [Feature]
/// enum value, so a misspelling is a compile error and `isOn` can never be
/// asked a question it does not understand.
///
/// ## Why flags have parents
///
/// "Community is off but community video is on" is not a state anyone means.
/// Each feature may declare a [Feature.parent]; [FeatureFlags.isOn] walks up
/// the chain and returns false if **any** ancestor is off. So switching off one
/// flag switches off everything that lives inside it, and there is no way to
/// leave an orphan reachable. This is checked by test, not by discipline.
///
/// ## Defaults
///
/// **Everything is on except [Feature.accountRequired]**, at the owner's
/// instruction, so the whole product can be walked end to end without an
/// account. That one must be switched back on before a public release.
///
/// Three of these were previously off for reasons worth re-reading before a
/// public release, because they are not preferences:
///
///   * [Feature.communityFollowerCounts] — nothing in this product ranks
///     women, and a visible count is the first step toward one. This one is a
///     §2 rule, not a setting.
///   * [Feature.communityVideo] — on-device blur export is unmeasured on a
///     budget Android handset, and a slow export makes women switch blur off.
///   * [Feature.communityVoiceNotes] — a whole content type with no moderation
///     story behind it.
///
/// Switching any of them back is one line here, or one tap on Z14.
///
/// ## Where the values come from
///
/// Today: [FeatureFlags.shipped], compiled in. Later: a remote config document,
/// read once at startup and merged over the defaults with [FeatureFlags.with_].
/// The specs already name the keys (`kill_switches.assistant`,
/// `community_show_follower_counts`, `assistant_model`, `min_age`…). Nothing in
/// this file talks to a network, so it stays testable and synchronous.
library;

import 'package:meta/meta.dart';

/// Every switchable part of the product.
///
/// Adding a value here is deliberately cheap; removing one is deliberately
/// visible, because a removed flag is a feature that can no longer be turned
/// off in an emergency.
enum Feature {
  // ----------------------------------------------------------- Phase 1
  /// Whether she must sign up — and be verified — before she can use the
  /// app. Off: the app opens straight onto Home as a guest who holds both
  /// roles, so every screen, the coach side included, can be walked without
  /// an account. Separate from [signUp], which only decides whether the
  /// sign-up screens exist at all: with this off they are still there to be
  /// looked at, they just are not a gate.
  accountRequired,

  signUp,
  verification,
  today,
  train,

  // ----------------------------------------------------------- Phase 2
  eat,
  progress,
  cycle,
  privacyCentre,
  adminConsole,

  // ----------------------------------------------------------- Phase 3
  /// The community as a whole. Parent of every community sub-feature.
  community,

  /// Posting a photo or text. The launch scope.
  communityPosts,

  /// Video and reels. **Deferred**: on-device blur export is unmeasured on a
  /// budget Android handset, and a slow export makes women switch blur off —
  /// which is a rule 6 failure by user experience rather than by code.
  communityVideo,

  /// Voice notes in community. **Deferred**: a whole content type with no
  /// moderation story is a safety gap, not a missing feature.
  communityVoiceNotes,

  /// Showing follower counts. Off: nothing in this product ranks women, and a
  /// visible count is the first step toward one.
  communityFollowerCounts,

  /// The coach's own app — her desk, her clients, her earnings.
  coachApp,

  /// Splits, assessments, the 30-day planner, publishing.
  coachPlanning,

  /// The public portfolio a coach builds.
  coachPortfolio,

  /// Life as a coached client.
  coachedLife,

  /// Finding and choosing a coach.
  marketplace,

  /// Taking money. Separate from [marketplace] on purpose: the directory and
  /// profiles can be browsed long before a payment rail is contracted.
  payments,

  /// The assistant.
  assistant;

  /// The feature this one lives inside, or null when it is top level.
  Feature? get parent => switch (this) {
    communityPosts ||
    communityVideo ||
    communityVoiceNotes ||
    communityFollowerCounts => community,
    payments => marketplace,
    _ => null,
  };
}

/// An immutable set of switch positions.
@immutable
class FeatureFlags {
  const FeatureFlags(this._values);

  final Map<Feature, bool> _values;

  /// What ships today.
  ///
  /// Everything on, at the owner's instruction, so the whole product can be
  /// explored. See the library doc for the three that were off for reasons
  /// rather than for sequencing.
  static const FeatureFlags shipped = FeatureFlags(<Feature, bool>{
    // OFF at the owner's instruction, so the whole app can be browsed and
    // tested without creating an account. Switch it back ON before any
    // public release: with it off, anyone who installs the app is inside,
    // unverified.
    Feature.accountRequired: false,

    // Phase 1 — built and shipped.
    Feature.signUp: true,
    Feature.verification: true,
    Feature.today: true,
    Feature.train: true,

    // Phase 2 — built and shipped.
    Feature.eat: true,
    Feature.progress: true,
    Feature.cycle: true,
    Feature.privacyCentre: true,
    Feature.adminConsole: true,

    // Phase 3 — all on at the owner's instruction.
    Feature.community: true,
    Feature.communityPosts: true,
    Feature.communityVideo: true,
    Feature.communityVoiceNotes: true,
    Feature.communityFollowerCounts: true,
    Feature.coachApp: true,
    Feature.coachPlanning: true,
    Feature.coachPortfolio: true,
    Feature.coachedLife: true,
    Feature.marketplace: true,
    Feature.payments: true,
    Feature.assistant: true,
  });

  /// Everything off. Useful in tests that assert a screen is unreachable.
  static final FeatureFlags allOff = FeatureFlags(<Feature, bool>{
    for (final f in Feature.values) f: false,
  });

  /// Whether [feature] is reachable.
  ///
  /// False if the feature itself is off **or any ancestor is off**, so a
  /// sub-feature can never outlive its parent. An unlisted feature is off:
  /// a flag nobody set is not a flag somebody meant to enable.
  bool isOn(Feature feature) {
    for (Feature? f = feature; f != null; f = f.parent) {
      if (_values[f] != true) return false;
    }
    return true;
  }

  /// The value of this one switch, ignoring its ancestors.
  ///
  /// For the admin screen, which must show what a switch is set to even while
  /// its parent makes it unreachable — otherwise turning the parent on looks
  /// like it silently changed the children.
  bool isSetOn(Feature feature) => _values[feature] == true;

  /// A copy with some switches moved.
  FeatureFlags with_(Map<Feature, bool> overrides) =>
      FeatureFlags(<Feature, bool>{..._values, ...overrides});

  /// The features that are reachable right now, in declaration order.
  Iterable<Feature> get enabled => Feature.values.where(isOn);

  @override
  String toString() => 'FeatureFlags(${enabled.map((f) => f.name).join(', ')})';
}
