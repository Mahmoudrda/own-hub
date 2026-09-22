/// What a follow button renders, and what a blocked woman is told — which is
/// **nothing**.
///
/// `G10-community.md` §3.8 lists five renderings, and §6.1 states the rule the
/// fifth one exists to keep:
///
/// > every blocked surface renders the ordinary **"not available"**, never
/// > "you are blocked" … `blockedBy` is `read: if false` for everyone including
/// > its owner.
///
/// `P0-COM-13`: *"Nothing anywhere tells A she has been blocked."*
///
/// ## How that is made true rather than promised
///
/// There is **no `blocked` value in this enum.** A block in either direction
/// resolves to [FollowState.unavailable], which is the same value a woman gets
/// when the other woman simply turned her profile off. A screen cannot render
/// the two differently because it cannot tell them apart — the information does
/// not reach it.
///
/// [SurfaceAvailability] does the same job for a whole screen. Its two values
/// are `available` and `notAvailable`; there is no third value meaning "blocked",
/// and [SurfaceAvailability.resolve] deliberately collapses three very different
/// causes into one answer.
///
/// That collapse is the design. A distinguishable "blocked" state anywhere —
/// even a different icon, even a different empty-state string — is a side
/// channel that tells a woman who blocked her, and the whole point of blocking
/// in this product is that it is invisible to the person blocked.
///
/// ## The honest limit, from §6.1
///
/// Blocking is a **contact and experience** boundary, not a confidentiality one.
/// Every post in this room was already readable by every verified woman, and a
/// block does not retro-classify it. What is rules-enforced is every write that
/// reaches another woman — comment, like, follow, message. The feed-level
/// exclusion is a client-side filter over a Function-maintained `hiddenAuthors`
/// array, because evaluating `notBlockedBy()` per document would be one billed
/// read per post per page. `OQ-2` records that G7 must ratify this.
library;

/// The five renderings of a follow button.
///
/// Note what is absent: no `blocked`, no `blockedByHer`, no `restricted`.
enum FollowState {
  /// Her own profile. No button at all — not a disabled one.
  self,

  notFollowing,

  /// Tapped offline. Optimistic and at full opacity, with the queued glyph;
  /// the mirror and her follower's count land on sync.
  pendingLocal,

  following,

  /// A block in **either** direction, or a profile that is not discoverable.
  ///
  /// One value for three causes, on purpose. See the library comment.
  unavailable,
}

/// Whether a whole surface can be shown.
///
/// Used by M07 (a profile), M02 (a post) and M08 (the safety sheet).
enum SurfaceAvailability {
  available,

  /// Renders the ordinary not-available state. Identical copy whether she was
  /// blocked, the other woman hid her profile, or the post was deleted.
  notAvailable;

  bool get isAvailable => this == SurfaceAvailability.available;
}

/// Resolves the button and the surface without ever returning "blocked".
///
/// A single object so the collapse happens in one place. Two call sites deciding
/// this independently is how one of them eventually grows a special case.
class FollowStateResolver {
  const FollowStateResolver();

  /// [hiddenEitherWay] is true when she appears in the viewer's `hiddenAuthors`,
  /// which is symmetric — it holds blocks in both directions and the caller
  /// cannot tell which. That asymmetry of *knowledge* is what makes the
  /// guarantee hold: this function could not leak the direction if it tried.
  FollowState resolve({
    required String viewerUid,
    required String otherUid,
    required bool isFollowing,
    bool hiddenEitherWay = false,
    bool profileDiscoverable = true,
    bool pendingLocal = false,
  }) {
    if (viewerUid == otherUid) return FollowState.self;

    // Checked before anything else, so no later branch can reveal a state that
    // implies contact is possible.
    if (hiddenEitherWay || !profileDiscoverable) {
      return FollowState.unavailable;
    }

    if (pendingLocal) return FollowState.pendingLocal;
    return isFollowing ? FollowState.following : FollowState.notFollowing;
  }

  /// Whether a surface about [otherUid] may be shown to the viewer.
  ///
  /// [profileExists] is false when `publicProfiles/{uid}` is absent — which is
  /// what a woman who turned her profile off looks like, because the projection
  /// Function deletes the document. Indistinguishable from a block, by design.
  SurfaceAvailability surfaceFor({
    required bool profileExists,
    bool hiddenEitherWay = false,
  }) => (!profileExists || hiddenEitherWay)
      ? SurfaceAvailability.notAvailable
      : SurfaceAvailability.available;

  /// Whether the viewer may act on another woman — comment, like, follow,
  /// message.
  ///
  /// Returns a plain bool with no reason attached. A `Result` carrying "because
  /// you are blocked" would be exactly the leak this file exists to prevent, and
  /// the UI has nothing to say here beyond not offering the action. The server
  /// refuses it too: `notBlockedBy()` is in the rules on every one of those
  /// writes, so this is the courtesy and the rules are the enforcement.
  bool mayContact({required bool hiddenEitherWay}) => !hiddenEitherWay;
}
