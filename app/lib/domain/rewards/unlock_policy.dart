/// What a tier opened stays open.
///
/// This is where *"nothing earned is ever taken away"* stops being copy and
/// becomes structure. [UnlockPolicy.isUnlocked] reads [TierStanding.earned],
/// which is monotonic; it does not read [TierStanding.display], which is the
/// only thing that can fall. T05's "Everything Regular opened" is therefore true
/// **by construction** rather than by somebody remembering to be kind, and a
/// slipped label closes nothing at all.
///
/// The enforcement is an absence: the word `display` does not appear in this
/// file, and `test/domain/rewards/rewards_rules_test.dart` scans for it. A guard
/// that reads the source is worth having here precisely because the bug would be
/// a one-character edit that no screenshot could show.
///
/// ## The unlock list is not authored either
///
/// For the same reason [TierLadder] is empty — `DECISIONS.md` D6 — there is no
/// shipped list of what each tier opens. [UnlockPolicy.unauthored] holds
/// nothing, and an unknown feature id is **not unlocked**: the policy fails
/// closed, so a feature nobody has assigned a tier to cannot be opened by
/// accident.
library;

import 'package:meta/meta.dart';

import 'tier_policy.dart';

/// One thing a tier opens.
@immutable
class Unlock {
  const Unlock({required this.id, required this.opensAt});

  /// A stable identifier, not a sentence. Copy belongs to the dictionary.
  final String id;

  final Tier opensAt;
}

/// Decides what is open. Reads only the monotonic tier.
@immutable
class UnlockPolicy {
  const UnlockPolicy(this.unlocks);

  /// What this codebase ships: nothing. See the library comment.
  static const UnlockPolicy unauthored = UnlockPolicy(<Unlock>[]);

  final List<Unlock> unlocks;

  bool get isAuthored => unlocks.isNotEmpty;

  /// Whether [featureId] is open to her.
  ///
  /// Fails closed on an unknown id, and on a standing computed from an
  /// unauthored ladder. Both answers are "no", and both are the safe direction:
  /// a feature that should be open and is not is a bug somebody reports, while a
  /// feature that should be shut and is open is a promise quietly broken.
  bool isUnlocked(String featureId, TierStanding standing) {
    final reached = standing.earned;
    if (reached == null) return false;
    for (final unlock in unlocks) {
      if (unlock.id == featureId) return reached.index >= unlock.opensAt.index;
    }
    return false;
  }

  /// Everything open to her, lowest tier first — T05's "kept, all of it" list.
  List<Unlock> openedFor(TierStanding standing) {
    final reached = standing.earned;
    if (reached == null) return const <Unlock>[];
    return unlocks.where((u) => reached.index >= u.opensAt.index).toList()
      ..sort((a, b) => a.opensAt.index.compareTo(b.opensAt.index));
  }
}
