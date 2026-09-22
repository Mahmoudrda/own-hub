/// The field that makes fan-out-on-read possible — and the reason a post is
/// **one** document however many followers its author has.
///
/// `SCHEMA-SPINE.md` C9, restated by `G10-community.md` §1.2:
///
/// > `audienceKeys[]` — `['a:{authorUid}']` or `['a:{authorUid}','g:{groupId}']`
/// > … **the whole feed design.** Size ≤2, always — this is the field that makes
/// > fan-out-on-read one query.
///
/// ## Why the size cap is a type invariant and not a validation
///
/// The forbidden design is a timeline collection: one copy of a post per
/// follower. The shape that design needs is an audience field that **grows with
/// the audience**. So the defence is not "check the length before writing" — it
/// is that there is no constructor here capable of producing a third element.
/// [AudienceKeys.forAuthor] makes one key; [AudienceKeys.inGroup] makes two.
/// There is no `add`, no `+`, and [values] hands back an unmodifiable list.
///
/// A future implementer who wants to fan out has to change this file, and the
/// change is visible. That is the whole mechanism — the same one `PrescribedSet`
/// uses for rule 1 and `FollowerCount` uses for rule 11.
///
/// ## The reader holds the keys, not the writer
///
/// `G10` §2.1 states it so nobody "optimises" it back:
///
/// > `followGraph/{uid}` is written when **she** follows or joins — O(1) per
/// > *her* action. The forbidden shape is writing to N documents when **she
/// > posts**.
///
/// So these keys go on the post (≤2 of them), and the *reader's* key set — the
/// women she follows plus the groups she joined — is what gets chunked by
/// [chunkAudienceKeys] at query time.
library;

import 'package:meta/meta.dart';

/// The documented `array-contains-any` limit.
///
/// It is 30 today and was 10 before November 2023. `P0-COM-16` asserts the
/// chunker against whatever the deployed SDK actually enforces, because a lower
/// limit costs **money, not correctness**: the feed simply issues more chunks.
/// `OQ-13` records that this is a cost variance to verify at build time.
const int kAudienceChunk = 30;

/// The prefix for "everything this woman posts".
const String kAuthorKeyPrefix = 'a:';

/// The prefix for "everything posted into this group".
const String kGroupKeyPrefix = 'g:';

/// A post's audience, which is at most two keys and never more.
@immutable
class AudienceKeys {
  const AudienceKeys._(this._values);

  /// A post that goes to the author's own followers.
  factory AudienceKeys.forAuthor(String authorUid) {
    _assertUid(authorUid);
    return AudienceKeys._(<String>['$kAuthorKeyPrefix$authorUid']);
  }

  /// A post published into a group she is a member of.
  ///
  /// Two keys, in this order. The security rules pin the order —
  /// `d.audienceKeys[0] == 'a:' + request.auth.uid` — so a post can never be
  /// addressed to a group without also naming its author.
  factory AudienceKeys.inGroup({
    required String authorUid,
    required String groupId,
  }) {
    _assertUid(authorUid);
    if (groupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'must not be empty');
    }
    return AudienceKeys._(<String>[
      '$kAuthorKeyPrefix$authorUid',
      '$kGroupKeyPrefix$groupId',
    ]);
  }

  static void _assertUid(String uid) {
    if (uid.isEmpty) {
      throw ArgumentError.value(uid, 'authorUid', 'must not be empty');
    }
  }

  final List<String> _values;

  /// The keys, in rules order. Unmodifiable: a caller cannot append a third.
  List<String> get values => List<String>.unmodifiable(_values);

  /// Always 1 or 2. Never a function of an audience size.
  int get size => _values.length;

  /// The author key, which every post has.
  String get authorKey => _values.first;

  /// The group key, or null for a post that is not in a group.
  String? get groupKey => _values.length > 1 ? _values[1] : null;

  @override
  bool operator ==(Object other) =>
      other is AudienceKeys &&
      other._values.length == _values.length &&
      other.authorKey == authorKey &&
      other.groupKey == groupKey;

  @override
  int get hashCode => Object.hash(authorKey, groupKey);

  @override
  String toString() => 'AudienceKeys(${_values.join(', ')})';
}

/// Splits a reader's key set into `array-contains-any` sized chunks.
///
/// This is the *read* side: the keys a woman holds are her `followingKeys`
/// (≤300) plus her `groupKeys` (≤10), so the realistic chunk count is 1 at p50
/// and 2 at p95. `G10` §2.1 caps a page at 10 chunks.
///
/// Every key lands in exactly one chunk and the order is preserved, so no author
/// is silently dropped — which is the correctness half of `P0-COM-16`. Ordering
/// within the merged result is `createdAt` and nothing else; a chunk boundary
/// must not become a ranking.
List<List<String>> chunkAudienceKeys(
  List<String> keys, {
  int chunkSize = kAudienceChunk,
}) {
  if (chunkSize < 1) {
    throw ArgumentError.value(chunkSize, 'chunkSize', 'must be at least 1');
  }
  // Duplicates would cost reads and return the same posts twice through the
  // merge. Deduplicated here rather than trusted from the caller, preserving
  // first-seen order so the chunking is deterministic and testable.
  final unique = <String>[];
  final seen = <String>{};
  for (final key in keys) {
    if (seen.add(key)) unique.add(key);
  }

  final out = <List<String>>[];
  for (var i = 0; i < unique.length; i += chunkSize) {
    final end = i + chunkSize;
    out.add(
      List<String>.unmodifiable(
        unique.sublist(i, end > unique.length ? unique.length : end),
      ),
    );
  }
  return List<List<String>>.unmodifiable(out);
}
