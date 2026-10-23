// Spine C9 made structural: a post's audience is at most two keys, and the
// reader's key set is chunked at the SDK's array-contains-any limit.
//
// P0-COM-16 is the chunking case: "Following 95 women and in 6 groups … every
// followed author's recent posts are reachable … no author is silently
// dropped."

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/community/domain/audience_keys.dart';

void main() {
  group('a post s audience cannot grow', () {
    test('a post to her own followers has one key', () {
      final keys = AudienceKeys.forAuthor('u-7331');

      expect(keys.size, 1);
      expect(keys.values, <String>['a:u-7331']);
      expect(keys.groupKey, isNull);
    });

    test('a post into a group has two, in the order the rules pin', () {
      final keys = AudienceKeys.inGroup(
        authorUid: 'u-7331',
        groupId: 'quiet-flats',
      );

      // audienceKeys[0] == 'a:' + request.auth.uid in firestore.rules. A post
      // can never be addressed to a group without also naming its author.
      expect(keys.values, <String>['a:u-7331', 'g:quiet-flats']);
      expect(keys.size, 2);
    });

    test('there is no way to add a third', () {
      final keys = AudienceKeys.inGroup(authorUid: 'u-7331', groupId: 'g');

      expect(
        () => keys.values.add('a:someone-else'),
        throwsUnsupportedError,
        reason:
            'the forbidden design needs an audience field that grows with the '
            'audience. values is unmodifiable and there is no add() — a '
            'fan-out has nowhere to put the extra keys.',
      );
      expect(keys.size, lessThanOrEqualTo(2));
    });

    test('an empty uid is refused', () {
      expect(() => AudienceKeys.forAuthor(''), throwsArgumentError);
      expect(
        () => AudienceKeys.inGroup(authorUid: 'u-1', groupId: ''),
        throwsArgumentError,
      );
    });
  });

  group('the reader s keys are chunked, and nobody is dropped', () {
    // 95 women and 6 groups — P0-COM-16's exact precondition.
    List<String> herKeys() => <String>[
      for (var i = 0; i < 95; i++) 'a:woman-$i',
      for (var i = 0; i < 6; i++) 'g:group-$i',
    ];

    test('101 keys chunk at 30 into four queries', () {
      final chunks = chunkAudienceKeys(herKeys());

      expect(chunks.length, 4, reason: '101 keys / 30 = 4 chunks');
      expect(chunks.every((c) => c.length <= kAudienceChunk), isTrue);
    });

    test('every key lands in exactly one chunk', () {
      final keys = herKeys();
      final chunks = chunkAudienceKeys(keys);
      final flattened = <String>[for (final c in chunks) ...c];

      expect(
        flattened,
        keys,
        reason:
            'P0-COM-16: no author is silently dropped, and none is counted '
            'twice. Order is preserved so the chunking is deterministic.',
      );
    });

    test('a smaller SDK limit costs queries, never authors', () {
      // OQ-13: the limit was 10 before November 2023. If the deployed SDK
      // enforces 10, the feed's chunk count triples — a COST variance, not a
      // correctness one. This is that claim, executable.
      final keys = herKeys();
      final atTen = chunkAudienceKeys(keys, chunkSize: 10);

      expect(atTen.length, 11);
      expect(<String>[for (final c in atTen) ...c], keys);
    });

    test('duplicates are collapsed rather than paid for twice', () {
      final chunks = chunkAudienceKeys(<String>['a:w-1', 'a:w-1', 'g:g-1']);

      expect(
        <String>[for (final c in chunks) ...c],
        <String>['a:w-1', 'g:g-1'],
      );
    });

    test('no keys means no queries at all', () {
      // Day one. Issuing a query with an empty arrayContainsAny would be both
      // an error and a read she should not be charged for.
      expect(chunkAudienceKeys(const <String>[]), isEmpty);
    });

    test('a chunk size below one is refused', () {
      expect(
        () => chunkAudienceKeys(const <String>['a:w'], chunkSize: 0),
        throwsArgumentError,
      );
    });

    test('the drop-detector would bite', () {
      // Positive control for the "nobody is dropped" assertion above: if the
      // chunker silently truncated, this is the shape that would catch it.
      final truncating = chunkAudienceKeys(herKeys())
          .take(1)
          .expand((c) => c)
          .toList();

      expect(
        truncating.length,
        lessThan(herKeys().length),
        reason:
            'proves the equality assertion above is comparing something that '
            'could differ, rather than two views of one list',
      );
    });
  });
}
