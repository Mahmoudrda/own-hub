/// `HANDOFF.md` rule 9 — **a follow-up belongs to a parent, and a thread is one
/// woman over time.**
///
/// Two separate prohibitions, and they fail in different ways, so they get
/// different mechanisms:
///
///   1. *Only the parent's author may attach a follow-up.* Enforced by
///      [FollowUpPolicy.assertCanAttach], which throws [NotYourPostError].
///      Re-asserted in `firestore.rules` with a `get()` on the parent, because a
///      domain check alone is a client-side check.
///   2. *Never a standalone before-and-after.* Enforced by [FollowUpChain],
///      whose constructor **cannot be given two authors**. The follow-up thread
///      view takes a chain, so there is no widget anywhere that could place two
///      different women side by side — which is the comparison this product
///      exists to avoid.
///
/// A third rule falls out of the first: a follow-up may not itself be a parent.
/// `followUpOk()` in the rules says `!('parentPostId' in postDoc(d.parentPostId))`,
/// and [FollowUpPolicy.assertCanAttach] throws [NestedFollowUpError] for the same
/// case. A chain is always one woman and always one level deep.
///
/// ## The cost card carries two integers and cannot carry a weight
///
/// `G10` §5, rule 11: *"`FollowUpCost.from(rewards, weeklyGoal)` returns exactly
/// `{sessions, countedWeeks}`; there is no constructor parameter that could carry
/// a weight."* That is [FollowUpCost] below. `P1-COM-02` greps for exactly this,
/// and the rules re-assert it with `hasOnly(['sessions','countedWeeks'])`.
///
/// The screens say it out loud — M12's card reads "no weight shown" — but the
/// reason a weight never appears there is that no field exists to put one in.
library;

import 'package:meta/meta.dart';

/// Attaching a follow-up to a post that is not hers.
class NotYourPostError extends Error {
  NotYourPostError({required this.parentPostId, required this.attemptedBy});

  final String parentPostId;
  final String attemptedBy;

  @override
  String toString() =>
      'NotYourPostError: $attemptedBy tried to attach a follow-up to '
      '$parentPostId, which belongs to another woman. HANDOFF 9 — a follow-up '
      'belongs to its parent, and only the parent\'s author may attach one.';
}

/// Attaching a follow-up to something that is already a follow-up.
class NestedFollowUpError extends Error {
  NestedFollowUpError(this.parentPostId);

  final String parentPostId;

  @override
  String toString() =>
      'NestedFollowUpError: $parentPostId is itself a follow-up. A chain is '
      'one woman and one level deep — no chains of chains.';
}

/// Two women in one chain, which `FollowUpChain` refuses to represent.
class MixedAuthorChainError extends Error {
  MixedAuthorChainError(this.authors);

  final Set<String> authors;

  @override
  String toString() =>
      'MixedAuthorChainError: a follow-up chain must be one woman over time, '
      'but this one names ${authors.length} authors ($authors). HANDOFF 9 — '
      'never two women side by side.';
}

/// What a follow-up cost her: sessions and counted weeks. Nothing else.
///
/// Note the absence. There is no `weightKg`, no `weightLost`, no `bodyFat`, no
/// `measurement` and no `before`/`after` figure of any kind, and no constructor
/// parameter one could be passed through. Rule 11 is not a validation applied to
/// this type; it is the set of fields this type does not have.
@immutable
class FollowUpCost {
  const FollowUpCost({required this.sessions, required this.countedWeeks})
    : assert(sessions >= 0),
      assert(countedWeeks >= 0);

  /// Built from her own reward counters at compose time.
  ///
  /// Takes two ints and returns two ints. G6 pays nothing for posting and this
  /// asks it for nothing — the figures are sessions she logged and weeks that
  /// counted, both of which already exist for reasons that have nothing to do
  /// with the community.
  factory FollowUpCost.from({
    required int sessionsLogged,
    required int countedWeeks,
  }) => FollowUpCost(sessions: sessionsLogged, countedWeeks: countedWeeks);

  final int sessions;
  final int countedWeeks;

  /// The exact key set the security rules allow, so a test can compare against
  /// the rules rather than against a comment.
  static const Set<String> wireKeys = <String>{'sessions', 'countedWeeks'};

  Map<String, int> toWire() => <String, int>{
    'sessions': sessions,
    'countedWeeks': countedWeeks,
  };

  @override
  bool operator ==(Object other) =>
      other is FollowUpCost &&
      other.sessions == sessions &&
      other.countedWeeks == countedWeeks;

  @override
  int get hashCode => Object.hash(sessions, countedWeeks);

  @override
  String toString() =>
      'FollowUpCost(sessions: $sessions, countedWeeks: $countedWeeks)';
}

/// The minimum a policy needs to know about a post to judge an attachment.
///
/// Deliberately not the full post type: the policy should be callable from the
/// composer, from a test, and from anywhere a parent's identity is known,
/// without dragging media and captions along.
@immutable
class FollowUpParent {
  const FollowUpParent({
    required this.postId,
    required this.authorUid,
    this.parentPostId,
  });

  final String postId;
  final String authorUid;

  /// Non-null when this post is itself a follow-up — which disqualifies it.
  final String? parentPostId;

  bool get isItselfAFollowUp => parentPostId != null;
}

/// The one place the two attachment rules are decided.
class FollowUpPolicy {
  const FollowUpPolicy();

  /// Throws unless [authorUid] may attach a follow-up to [parent].
  ///
  /// Throws rather than returning a bool on purpose: a caller that ignored a
  /// false would compose a post the server is going to reject, and the woman
  /// would lose the work. `P0-COM-04` drives both this and the rules.
  void assertCanAttach({
    required FollowUpParent parent,
    required String authorUid,
  }) {
    if (parent.authorUid != authorUid) {
      throw NotYourPostError(
        parentPostId: parent.postId,
        attemptedBy: authorUid,
      );
    }
    if (parent.isItselfAFollowUp) {
      throw NestedFollowUpError(parent.postId);
    }
  }

  /// The non-throwing form, for a view model deciding whether to *offer* the
  /// action. The UI must not show what the rules will refuse — `P0-COM-04`
  /// requires it to be "not offered in the UI" **and** refused by rules.
  bool canAttach({required FollowUpParent parent, required String authorUid}) =>
      parent.authorUid == authorUid && !parent.isItselfAFollowUp;
}

/// A parent and its follow-ups, which is the only shape M12 can render.
///
/// The constructor is the enforcement: hand it posts by two women and it throws.
/// `FollowUpThreadView` takes one of these and nothing else, so "two women side
/// by side" is not a state the widget tree can be put into.
@immutable
class FollowUpChain {
  /// Builds a chain, or throws.
  ///
  /// [moments] must be the parent followed by its follow-ups in time order. The
  /// caller supplies the order because `createdAt` is the server's and a chain
  /// assembled offline has none yet.
  factory FollowUpChain({
    required String authorUid,
    required List<FollowUpMoment> moments,
  }) {
    if (moments.isEmpty) {
      throw ArgumentError.value(
        moments,
        'moments',
        'a thread has a parent by definition — an empty chain is not a state '
            'M12 can be in',
      );
    }
    final authors = moments.map((m) => m.authorUid).toSet()..add(authorUid);
    if (authors.length != 1) throw MixedAuthorChainError(authors);
    return FollowUpChain._(authorUid, List.unmodifiable(moments));
  }

  const FollowUpChain._(this.authorUid, this.moments);

  /// The one woman this chain is about.
  final String authorUid;

  /// Parent first, then each follow-up.
  final List<FollowUpMoment> moments;

  FollowUpMoment get parent => moments.first;

  /// True once there is something to compare the parent against.
  bool get hasFollowUps => moments.length > 1;
}

/// One picture in a chain — "Week 1", "Week 4", "Now".
@immutable
class FollowUpMoment {
  const FollowUpMoment({
    required this.postId,
    required this.authorUid,
    required this.takenAt,
    this.cost,
  });

  final String postId;
  final String authorUid;
  final DateTime takenAt;

  /// What it cost her, when she chose to attach it. Optional — the card is an
  /// offer on M11, not a requirement.
  final FollowUpCost? cost;
}
