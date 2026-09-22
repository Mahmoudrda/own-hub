/// D7's one asymmetry — **only a coach may assign.**
///
/// `P0-SPLIT-03`: a client has authored her own split; applying it to another
/// uid has "no UI path", is denied by rules, and throws here. The three layers
/// are deliberate. Rules are the boundary that holds against a direct write;
/// this is the boundary that holds against a call from inside the app, which
/// rules never see because the app is signed in as her.
///
/// A woman applying her own split to herself passes. That is the whole of D7:
/// she builds and uses her own; only a coach reaches somebody else's month.
library;

import 'package:meta/meta.dart';

/// Who is acting. Not an identity system — the smallest thing the guard needs.
enum ActorRole { coach, client }

@immutable
class PlanningActor {
  const PlanningActor({required this.uid, required this.role});

  const PlanningActor.coach(String uid) : this(uid: uid, role: ActorRole.coach);

  const PlanningActor.client(String uid)
    : this(uid: uid, role: ActorRole.client);

  final String uid;
  final ActorRole role;

  bool get isCoach => role == ActorRole.coach;
}

/// Thrown when a split would reach a month that is not the actor's to write.
class NotYourClient implements Exception {
  const NotYourClient({required this.actorUid, required this.targetUid});

  final String actorUid;
  final String targetUid;

  @override
  String toString() =>
      'NotYourClient($actorUid → $targetUid) — only a coach with an active '
      'relationship may apply a split to another woman';
}

/// The guard `SplitApplicator` runs before it materialises anything.
class SplitAssignmentGuard {
  const SplitAssignmentGuard._();

  /// Throws [NotYourClient] unless the actor may write [targetUid]'s month.
  ///
  /// [hasActiveRelationship] comes from G11 and is the authorisation for every
  /// coach action in this feature. A coach with no active relationship is, for
  /// this purpose, a stranger.
  static void assertMayAssign({
    required PlanningActor actor,
    required String targetUid,
    required bool hasActiveRelationship,
  }) {
    if (actor.uid == targetUid) return;
    if (actor.isCoach && hasActiveRelationship) return;
    throw NotYourClient(actorUid: actor.uid, targetUid: targetUid);
  }

  /// The same question, asked rather than thrown — for a screen deciding
  /// whether to offer "apply to…" at all. The UI path and the guard therefore
  /// agree by construction instead of by review.
  static bool mayAssign({
    required PlanningActor actor,
    required String targetUid,
    required bool hasActiveRelationship,
  }) {
    try {
      assertMayAssign(
        actor: actor,
        targetUid: targetUid,
        hasActiveRelationship: hasActiveRelationship,
      );
      return true;
    } on NotYourClient {
      return false;
    }
  }
}
