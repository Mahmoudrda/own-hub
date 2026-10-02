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
  assistant,

  /// Whether a recipe's [RecipeTier] means anything.
  ///
  /// Its parent is [payments], deliberately: `isOn()` walks ancestors, so this
  /// is **structurally impossible** to switch on while there is no way to take
  /// money. That is the honest version of "the flag is off" — not a promise in
  /// a comment that somebody flips during a release, but a gate that cannot
  /// open until billing exists above it.
  ///
  /// Every seeded recipe is `free` and no paywall, price or locked card is
  /// built. The flag exists so the entitlement can be modelled and tested now,
  /// and so the day a paid tier is real, the shape it plugs into was designed
  /// when nobody was in a hurry.
  recipeTiering;

  /// The feature this one lives inside, or null when it is top level.
  Feature? get parent => switch (this) {
    communityPosts ||
    communityVideo ||
    communityVoiceNotes ||
    communityFollowerCounts => community,
    payments => marketplace,
    recipeTiering => payments,
    _ => null,
  };
}

/// An immutable set of switch positions.
@immutable
class FeatureFlags {
  const FeatureFlags(this._values);

  final Map<Feature, bool> _values;

  /// What the first public release contains.
  ///
  /// Everything here is on because it works on this phone, with no server
  /// behind it: she trains, she eats, she tracks her cycle, she watches her
  /// own progress, and all of it is hers and stays on her handset.
  ///
  /// Everything else is off, and each one is off for the same reason rather
  /// than for taste: **it needs a back end that does not exist yet.** An
  /// account needs somewhere to live; verification needs an identity provider;
  /// the community needs moderation, which means a person and a queue, not a
  /// list in memory; coaching needs both women to be real accounts and money to
  /// move; the assistant needs a model behind a Cloud Function. Shipping any of
  /// them now would mean shipping a promise the build cannot keep, which is
  /// both a rejection and, in the community's case, a safety claim that is not
  /// true.
  ///
  /// Turning one back on is one line here. Turning several back on is the
  /// second release, once Firebase is standing.
  static const FeatureFlags shipped = FeatureFlags(<Feature, bool>{
    // Sign-up and verification ship at launch (owner decision, 2026-10-02):
    // a woman signs up with her phone number and is verified as a woman with
    // her national ID and a live selfie, or by a woman reviewer on a short
    // video call, before the app opens. The whole-app gate closes on
    // `accountRequired` (see `AppRouter.verificationGate`).
    //
    // RELEASE ORDER (G7), which this line depends on: deploy `functions/`,
    // the rules and the indexes, verify one real account end to end on a
    // Play closed-track build, and only then release a build with these on.
    // With the functions absent every woman would wait on C14 for a review
    // nothing can book.
    //
    // With `accountRequired` on, `AppRouter.testingAidsAllowed` is false in
    // every build, debug included.
    Feature.accountRequired: true,
    Feature.signUp: true,
    Feature.verification: true,

    // The first release, and all of it works with no network at all.
    Feature.today: true,
    Feature.train: true,
    Feature.eat: true,
    Feature.progress: true,
    Feature.cycle: true,
    Feature.privacyCentre: true,

    // The console is for the people who run the product, not for the women
    // using it. It is also compiled out of a release build entirely.
    Feature.adminConsole: false,

    // Waiting on a back end.
    Feature.community: false,
    Feature.communityPosts: false,
    Feature.communityVideo: false,
    Feature.communityVoiceNotes: false,
    Feature.communityFollowerCounts: false,
    Feature.coachApp: false,
    Feature.coachPlanning: false,
    Feature.coachPortfolio: false,
    Feature.coachedLife: false,
    Feature.marketplace: false,
    Feature.payments: false,
    Feature.assistant: false,

    // Off, and its parent is `payments`, so this line is belt as well as
    // braces: `isOn()` would refuse it even set to true.
    Feature.recipeTiering: false,
  });

  /// Every feature on, with no account required.
  ///
  /// This is the shape the product is explored and tested in, not the shape it
  /// ships in. The crawler, the journeys and the large-text sweep build it so
  /// that a screen which is off in the first release is still walked and still
  /// proved, instead of quietly rotting until the release that turns it on.
  static FeatureFlags get everything =>
      allOff.with_(<Feature, bool>{for (final f in Feature.values) f: true})
          .with_(<Feature, bool>{Feature.accountRequired: false});

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
