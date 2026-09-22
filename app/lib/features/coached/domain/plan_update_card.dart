/// The card that says a schedule was updated — and the reason it can never lie.
///
/// G13's "Plan updated · Thursday 18 September" and G14's inline system chip
/// are built here, from **published versions and nothing else**.
///
/// [PlanUpdateCard.resolve] takes a list of [PlanVersion] and a timestamp.
/// There is no messages parameter, no text argument, and no field on
/// `MessageDraft` a card could be synthesised from. So the two failure modes
/// this card exists to prevent are both unreachable:
///
///  * A coach types "I've shortened Thursday" and does not publish → the
///    version list is unchanged → **no card**, because there is nothing for
///    `resolve` to read. Not "the card is suppressed": there is no input.
///  * A card appears pointing at a revision that does not exist → impossible,
///    because every card is *made of* a revision that does.
///
/// ## Why `publishedAt`, not `effectiveFrom`
///
/// The card answers "has anything changed since you last looked", which is a
/// question about when the coach published, not about when the change starts.
/// A revision published on Tuesday and effective from Thursday must show on
/// Tuesday — that is the whole point of telling her — while still applying only
/// from Thursday. Both dates are on the card for exactly that reason.
library;

import 'package:meta/meta.dart';

import 'g2_contract.dart';

/// One published revision, as the card renders it.
@immutable
class PlanChange {
  const PlanChange({
    required this.version,
    required this.publishedAt,
    required this.effectiveFrom,
  });

  final String version;

  /// When the coach published it — what "since you last looked" compares to.
  final DateTime publishedAt;

  /// The first date it applies to. Yesterday's logs and any session already
  /// started keep the version they used.
  final DateTime effectiveFrom;

  @override
  bool operator ==(Object other) =>
      other is PlanChange &&
      other.version == version &&
      other.publishedAt == publishedAt &&
      other.effectiveFrom == effectiveFrom;

  @override
  int get hashCode => Object.hash(version, publishedAt, effectiveFrom);

  @override
  String toString() => 'PlanChange($version published $publishedAt)';
}

/// Builds the "plan updated" cards for a relationship.
class PlanUpdateCard {
  const PlanUpdateCard();

  /// Every revision published strictly after [since], oldest first.
  ///
  /// Strictly after, so re-reading with the same cursor shows the same card
  /// zero times rather than once more.
  ///
  /// The parameter list is the enforcement: `versions` and `since`. Adding a
  /// `messages` parameter here is the change that would have to be reviewed,
  /// and `message_repo_has_no_plan_path_test.dart` guards the other direction.
  List<PlanChange> resolve({
    required List<PlanVersion> versions,
    required DateTime since,
  }) {
    final changes =
        versions
            .where((v) => v.publishedAt.isAfter(since))
            .map(
              (v) => PlanChange(
                version: v.version,
                publishedAt: v.publishedAt,
                effectiveFrom: v.effectiveFrom,
              ),
            )
            .toList()
          ..sort((a, b) => a.publishedAt.compareTo(b.publishedAt));
    return List.unmodifiable(changes);
  }

  /// Whether anything at all has been published since [since].
  bool hasChangeSince({
    required List<PlanVersion> versions,
    required DateTime since,
  }) => resolve(versions: versions, since: since).isNotEmpty;
}

/// The version a running session is pinned to.
///
/// HANDOFF rule 2: a session pins its version at start and never re-reads it,
/// so a publish mid-session changes nothing that is running or already logged.
/// This type holds the pin, and it holds no method that could refresh it —
/// there is no `refresh()`, no `latest()` and no setter.
@immutable
class PinnedPlanVersion {
  const PinnedPlanVersion(this.version, {required this.pinnedAt});

  final String version;
  final DateTime pinnedAt;

  /// Whether [change] applies to this running session. Always false: a
  /// revision applies to future dates, and this session is not a future date.
  ///
  /// It exists as a method rather than a comment so a caller asking the
  /// question gets the answer from the domain instead of deciding for itself.
  bool appliesTo(PlanChange change) => false;

  @override
  String toString() => 'PinnedPlanVersion($version)';
}
