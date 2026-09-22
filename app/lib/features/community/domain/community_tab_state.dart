/// Which of four things the Community tab renders — **M17 is a state, not a
/// route.**
///
/// `HANDOFF.md` rule 16 and `G10-community.md` §3.7:
///
/// ```dart
/// switch (CommunityTabState.from(feedKeys, firstPage)) {
///   case dayOne:      return const CommunityDayOne();    // M17
///   case joinedOnly:  return const FeedEmptyButJoined();
///   case ready:       return FeedList(...);
///   case offlineCold: return const FeedOfflineCold();
/// }
/// ```
///
/// `P0-COM-03`: *"M17 renders inside the Community route. Back exits the tab; it
/// never returns to an empty feed. No M17 entry exists in app_routes.dart."*
///
/// ## How the routing half is already true
///
/// `app_router.dart` lists `'M17'` in `firstRunStates`, and `appDestinations`
/// excludes every id in that set — so `AppRouter.goTo(context, 'M17')` resolves
/// to nothing and `onGenerateRoute` returns null for its path. M17 exists in the
/// generated inventory as a *screen*, which is what lets the design tooling know
/// it exists, and is absent from the *destinations*, which is what makes it
/// unnavigable. The community tests assert the second, not the first.
///
/// The consequence for this feature is the one that matters: the day-one
/// rendering is a `case` inside the feed view, so pressing back from it exits
/// the tab. There is no navigator entry to pop back to an empty feed, because
/// nothing ever pushed one.
///
/// ## Why offline-cold is a separate state and not an error
///
/// A woman with no cache and no signal has not hit a failure — she has hit
/// physics. `G8`'s offline contract forbids a "failed to load" for anything that
/// will work later, so this is a named state with its own rendering rather than
/// an exception a screen has to catch.
///
/// Note the ordering in [CommunityTabState.resolve]: offline-cold is checked
/// **before** day-one. A woman who follows nobody and also has no signal is
/// offline-cold, not day-one — offering her "join a group" when she cannot
/// reach the network would be an empty state that lies about what is possible.
library;

/// The four renderings of the Community tab.
enum CommunityTabState {
  /// M17. She follows nobody and has joined nothing.
  dayOne,

  /// She has joined groups, but nobody has posted yet. A different message and
  /// a different smallest action: post the first thing, rather than join.
  joinedOnly,

  ready,

  /// No cache, no signal. Not an error.
  offlineCold;

  /// Decides which one, from the two things §3.7 names plus the cache.
  ///
  /// Takes primitives rather than the model types so the whole branch is
  /// testable without constructing a post, and so no caller can pass a
  /// half-built document in to see what happens.
  static CommunityTabState resolve({
    required int followingKeyCount,
    required int groupKeyCount,
    required int firstPagePostCount,
    bool online = true,
    bool hasCachedPage = false,
  }) {
    // First, because a woman with no signal and no cache cannot act on any of
    // the empty states below.
    if (!online && !hasCachedPage && firstPagePostCount == 0) {
      return CommunityTabState.offlineCold;
    }

    if (firstPagePostCount > 0) return CommunityTabState.ready;

    // `followingKeys` and `groupKeys` both empty → M17 renders (§2.1).
    if (followingKeyCount == 0 && groupKeyCount == 0) {
      return CommunityTabState.dayOne;
    }

    return CommunityTabState.joinedOnly;
  }

  /// True for the two states that render an empty surface with an action.
  ///
  /// HANDOFF 17 — *the empty state is the onboarding*. There is no tour in this
  /// product, so each of these has to do that work itself.
  bool get isEmptyState =>
      this == CommunityTabState.dayOne || this == CommunityTabState.joinedOnly;
}
