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
/// [FeatureFlags.shipped] is what the stores get: sign-up, verification and
/// the whole-app gate ([Feature.accountRequired]) on, with Today, Train, Eat,
/// Progress, My cycle and the privacy centre. The community, the coach app,
/// the marketplace and the assistant are off until their back ends exist.
/// [FeatureFlags.everything] is the other shape: every feature on and no
/// account required, so the whole product can be walked end to end in tests.
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
/// [FeatureFlags.shipped], compiled in, and then `meta/features`, read once a
/// launch by a verified woman and laid over it (`RemoteFeatures`). The
/// document can switch a feature off when [Feature.serverMayTurnOff] allows
/// it, and on only when [Feature.serverMayTurnOn] does. Nothing in this file
/// talks to a network, so it stays testable and synchronous.
///
/// ## Every feature has a switch, and so does every new one
///
/// A new thing a woman can do gets its own [Feature] here, with a parent if
/// it lives inside another, a line in [FeatureFlags.shipped], and its screens
/// in `kScreenFeatures` (`lib/routing/screen_features.dart`). It arrives off,
/// and is switched on when it is ready. `test/domain/flags/
/// every_feature_has_a_switch_test.dart` fails the build when a screen has no
/// switch, when a feature is missing from the shipped list, or when a switch
/// opens nothing.
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

  /// Logging a meal by saying it (`E03` and every microphone that leads
  /// there). **Off**: no speech recogniser is wired, the release manifest
  /// strips `RECORD_AUDIO`, and the privacy policy and site say the app never
  /// uses the microphone. A microphone drawn on Eat would be a feature the
  /// build does not have. Its parent is [eat].
  voiceLogging,

  /// A photo of her plate, read by the server into foods and grams she checks
  /// before anything is logged (`E12`, `E13`). For verified members only.
  /// Its parent is [eat].
  mealPhotos,
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

  /// Events the owner runs: a class online, a meet-up at a ladies-only gym.
  /// The Events screen (`T09`) and the Upcoming card on Home. **Off** until
  /// the owner switches it on from Z14, which also writes `meta/features` so
  /// members' apps take the same answer at their next launch. Nothing about
  /// a woman is collected: there is no "interested" and no attendee list.
  events,

  // ------------------------------------------------- Parts of a feature
  //
  // Each of these is one thing a woman can do, inside a feature above. Its
  // own switch means it can be turned off on its own (from the server, at
  // her next launch) when it breaks, without taking the rest of the feature
  // with it, and a new part arrives dark until it is ready.

  /// Her first week on Home: the arc and "First week done" (`T07`, `T08`).
  firstWeek,

  /// "After a quiet week" (`T04`): the rest week she has earned.
  quietWeek,

  /// "When a tier slips" (`T05`). **Off** for launch: the screen is not
  /// finished.
  tiers,

  /// The lock-screen nudge (`T03`). **Off** for launch: the screen is not
  /// finished.
  lockScreenNudge,

  /// "I already did it": a session from memory (`T02`, `R12`).
  /// Inside [train], although `T02` opens from Home.
  recordFromMemory,

  /// A programme and its days (`R02`). Back on with the three starting plans
  /// (D47): her week, from her programme. Its parent is [train].
  program,

  /// The exercise video (`R04`).
  exerciseVideo,

  /// Swapping a move (`R05`).
  exerciseSwap,

  /// The follow-along move (`R06`): a hold counts itself down and logs.
  followAlong,

  /// The workout library the owner publishes (`R11`).
  workoutLibrary,

  /// The exercise library and one move's demo (`R14`, `R15`): the owner's
  /// clips, kept on the phone after the first view (D42).
  exerciseLibrary,

  /// Training reminders: the sheet on `A01`, offered on Home. No screen of its own.
  trainingReminders,

  /// Recipes, one recipe and Rahma's letter (`E05`, `E06`, `E11`).
  recipes,

  /// The week plan (`E07`).
  weekPlan,

  /// The grocery list (`E08`), made from the dinners she plans.
  groceryList,

  /// Milestones (`P02`).
  milestones,

  /// Personal bests (`P03`).
  personalBests,

  /// Weight and measurements, kept privately (`P04`).
  bodyPrivately,

  /// The progress card she can share (`P05`).
  shareCard,

  /// Her muscles on a body she can turn, coloured by the sets she logged
  /// (`P06`).
  muscleMap,

  /// Meals for today (`Y07`): up to three of Rahma's recipes, picked from
  /// today's check-in.
  cycleMeals,

  /// The cycle calendar (`Y08`).
  cycleCalendar,

  /// Her patterns (`Y10`).
  cyclePatterns,

  /// The tour before sign-up (`C03`, `C04`).
  appTour,

  /// Community groups (`M04`, `M05`, `M06`).
  communityGroups,

  /// Community stories (`M13`).
  communityStories,

  /// Before and after results on a coach's page (`B08`, `K11`), each one
  /// shown only with the client's own agreement in the app.
  coachResults,

  /// What her clients say, on a coach's page (`K12`).
  coachReviews,

  /// The ad designer (`B09`).
  coachAds,

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
  recipeTiering,

  // ------------------------------------------- Motivation design, D37–D41
  /// Her training streak (D37): a line on Home, a row on P01, a stage on R10,
  /// a sheet, and a switch on A02. Hers to pause or switch off.
  trainingStreak,

  /// One weekly challenge against her own last week (D38).
  weeklyChallenge,

  /// R10 as the peak (D40): her real results revealed one after another, and
  /// paper confetti, once.
  finishReveal,

  /// A light touch on a logged set and on R10 (D40).
  haptics,

  /// Short named steps on O05 and C12, each one an operation that really ran
  /// (D39).
  reassuringWaits;

  /// The feature this one lives inside, or null when it is top level.
  Feature? get parent => switch (this) {
    communityPosts ||
    communityVideo ||
    communityVoiceNotes ||
    communityFollowerCounts ||
    communityGroups ||
    communityStories => community,
    payments => marketplace,
    voiceLogging || recipes || mealPhotos => eat,
    // The plan is built from recipes, and the list from the plan.
    weekPlan => recipes,
    groceryList => weekPlan,
    recipeTiering => payments,
    firstWeek || quietWeek || tiers || lockScreenNudge => today,
    recordFromMemory ||
    program ||
    exerciseVideo ||
    exerciseSwap ||
    followAlong ||
    workoutLibrary ||
    exerciseLibrary ||
    trainingReminders => train,
    milestones ||
    personalBests ||
    bodyPrivately ||
    shareCard ||
    muscleMap ||
    trainingStreak => progress,
    weeklyChallenge || finishReveal => train,
    cycleMeals || cycleCalendar || cyclePatterns => cycle,
    appTour => signUp,
    coachResults || coachReviews || coachAds => coachPortfolio,
    _ => null,
  };

  /// Whether `meta/features` may switch this off for every member.
  ///
  /// True for nearly everything: switching a broken part off, without a
  /// release, is what a flag is for. False only where off is itself the
  /// danger or the answer is a rule, not a setting:
  ///
  ///   * [accountRequired], [signUp], [verification] — off would open a
  ///     women-only app to anyone, or leave women unable to join or be
  ///     checked. Never from a document.
  ///   * [today] — Home is the front door. Off would leave her nowhere.
  ///   * [privacyCentre] — her data and her way out are never switched off.
  ///   * [adminConsole] — compiled out of store builds anyway.
  ///   * [communityFollowerCounts], [voiceLogging], [payments],
  ///     [recipeTiering] — off already, and they stay off by rule or until
  ///     a release that has what they need.
  bool get serverMayTurnOff => !const {
    Feature.accountRequired,
    Feature.signUp,
    Feature.verification,
    Feature.today,
    Feature.privacyCentre,
    Feature.adminConsole,
    Feature.communityFollowerCounts,
    Feature.voiceLogging,
    Feature.payments,
    Feature.recipeTiering,
  }.contains(this);

  /// Whether `meta/features` may switch this on for every member, beyond
  /// what the build ships.
  ///
  /// Only for a part that is finished in this build and needs nothing the
  /// server does not already have. Everything else waits for a release:
  /// a document that could switch on the community or the coach side would
  /// be a way round the rules that keep them closed (`communityLive()`,
  /// `coachLive()`), and a way round every safety argument they rest on.
  bool get serverMayTurnOn => const {Feature.events}.contains(this);

  /// Why a feature that opens no screen of its own still has a switch.
  ///
  /// Every other feature gates at least one screen in `kScreenFeatures`
  /// (`lib/routing/screen_features.dart`), and a test holds both lists
  /// together, so a switch that does nothing cannot sit on `Z14`.
  static const Map<Feature, String> gatesNoScreen = {
    Feature.accountRequired: 'The whole-app gate: AppRouter.verificationGate.',
    Feature.verification:
        'The check screens belong to signUp and open with '
        'it. The switch stays so a release note can name it.',
    Feature.privacyCentre:
        'Her data and her way out live in account, which '
        'is never gated. The switch stays so a release note can name it.',
    Feature.communityPosts: 'Checked inside the community screens.',
    Feature.communityVoiceNotes: 'Checked inside the community screens.',
    Feature.communityFollowerCounts: 'Checked inside the community screens.',
    Feature.recipeTiering: 'Checked by the recipe access gate.',
    Feature.trainingReminders:
        'A sheet on A01 and R10, and the one-line offer on T01.',
    Feature.trainingStreak:
        'A line on T01, a row on P01, a stage on R10, a '
        'sheet, and a switch on A02.',
    Feature.weeklyChallenge: 'One line on T01, a note on R03, a line on R10.',
    Feature.finishReveal:
        'How R10 arrives: the staged reveal and the paper '
        'confetti.',
    Feature.haptics: 'A light tap on a logged set and on R10.',
    Feature.reassuringWaits: 'The named steps on O05 and C12.',
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
    // her national ID and a live selfie, or by a woman reviewer from Own Hub
    // who reviews her case and contacts her by phone (no video), before the
    // app opens. The whole-app gate closes on
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

    // No recogniser, no microphone permission, and a privacy policy that says
    // the microphone is never used. She types what she ate.
    Feature.voiceLogging: false,

    // A photo of her plate, checked by her before it is logged. Each scan is
    // a paid call, capped on the server at five a day for each member.
    Feature.mealPhotos: true,

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

    // Nothing shows until the owner turns it on, from Z14.
    Feature.events: false,

    // The parts of what ships. Each is on, and each can be switched off on
    // its own from the server if it breaks. Two are off for launch, each
    // because its screen is not finished: `tiers` and `lockScreenNudge`. Each
    // goes back on, with a line in DECISIONS.md (D43), when its screen is
    // real.
    Feature.firstWeek: true,
    Feature.quietWeek: true,
    Feature.tiers: false,
    Feature.lockScreenNudge: false,
    Feature.recordFromMemory: true,
    Feature.program: true,
    Feature.exerciseVideo: true,
    Feature.exerciseSwap: true,
    Feature.followAlong: true,
    Feature.workoutLibrary: true,
    Feature.exerciseLibrary: true,
    Feature.trainingReminders: true,
    Feature.recipes: true,
    Feature.weekPlan: true,
    Feature.groceryList: true,
    Feature.milestones: true,
    Feature.personalBests: true,
    Feature.bodyPrivately: true,
    Feature.shareCard: true,
    Feature.muscleMap: true,
    Feature.cycleMeals: true,
    Feature.cycleCalendar: true,
    Feature.cyclePatterns: true,
    Feature.appTour: true,

    // Parts of what is still waiting on a back end.
    Feature.communityGroups: false,
    Feature.communityStories: false,
    Feature.coachResults: false,
    Feature.coachReviews: false,
    Feature.coachAds: false,

    // Off, and its parent is `payments`, so this line is belt as well as
    // braces: `isOn()` would refuse it even set to true.
    Feature.recipeTiering: false,

    // D37–D41, the motivation design from the guide's §15. Each is on, and
    // each can be switched off on its own from the server if it misbehaves.
    Feature.trainingStreak: true,
    Feature.weeklyChallenge: true,
    Feature.finishReveal: true,
    Feature.haptics: true,
    Feature.reassuringWaits: true,
  });

  /// Every feature on, with no account required.
  ///
  /// This is the shape the product is explored and tested in, not the shape it
  /// ships in. The crawler, the journeys and the large-text sweep build it so
  /// that a screen which is off in the first release is still walked and still
  /// proved, instead of quietly rotting until the release that turns it on.
  static FeatureFlags get everything => allOff
      .with_(<Feature, bool>{for (final f in Feature.values) f: true})
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

  /// Whether this set names [feature] at all, on or off. `shipped` names
  /// every feature, so its absence is never how a release decided.
  bool decides(Feature feature) => _values.containsKey(feature);

  /// A copy with some switches moved.
  FeatureFlags with_(Map<Feature, bool> overrides) =>
      FeatureFlags(<Feature, bool>{..._values, ...overrides});

  /// The features that are reachable right now, in declaration order.
  Iterable<Feature> get enabled => Feature.values.where(isOn);

  @override
  String toString() => 'FeatureFlags(${enabled.map((f) => f.name).join(', ')})';
}
