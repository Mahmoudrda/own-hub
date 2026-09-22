// The P1-COM rule guards that are properties of the SOURCE rather than of any
// one screen, plus the deployment half of rule 11.
//
// `product_rules_test.dart` establishes the source-scanning idiom and the two
// lessons this file inherits from it:
//
//   1. **Scan the right folder.** Its rule-9 guard passed for weeks by filtering
//      to three directories and never looking at lib/features/train, which is
//      where the screens rule 9 is about actually live.
//   2. **Prove the matcher bites.** A guard that matches nothing is
//      indistinguishable from a guard whose regex is broken. Every pattern below
//      is proven against text that MUST match before it is trusted against a
//      tree that must not.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Dart file this feature owns.
List<File> _communitySource() {
  final dir = Directory('lib/features/community');
  expect(
    dir.existsSync(),
    isTrue,
    reason:
        'the feature folder was not found. A silently empty scan would report '
        'a perfectly clean feature over zero files.',
  );
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('///') || t.startsWith('*');
}

/// `path:line` for every non-comment line matching [pattern].
///
/// Comment-filtered like the rules guards: a file that says "there is
/// deliberately no snapshot listener here" is documenting the rule, not
/// breaking it, and a guard that fails on correct code for explaining itself
/// teaches people to stop explaining.
List<String> _hits(RegExp pattern) {
  final out = <String>[];
  for (final file in _communitySource()) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (_isComment(lines[i])) continue;
      if (pattern.hasMatch(lines[i])) {
        out.add('${file.path}:${i + 1}  ${lines[i].trim()}');
      }
    }
  }
  return out;
}

void main() {
  test('the scan actually sees the feature', () {
    // The vacuous-guard check, first, so every assertion below means something.
    expect(_communitySource().length, greaterThan(5));
    expect(
      _hits(RegExp('CommunityPost')),
      isNotEmpty,
      reason: 'if this is empty the scanner is not reading the feature at all',
    );
  });

  group('G10 §2.4 — no snapshot listeners anywhere in community', () {
    test('nothing streams, watches or listens', () {
      // "A live listener on a feed re-reads on every write by anyone she
      // follows — the standard way this bill goes to $500."
      final banned = RegExp(
        r'\b(Stream<|StreamController|snapshots\(|\.listen\(|StreamBuilder|'
        r'StreamSubscription|asBroadcastStream)',
      );

      expect(
        _hits(banned),
        isEmpty,
        reason:
            'community is cache-first with explicit pull-to-refresh. A '
            'listener here is a bill, not a feature.',
      );
    });

    test('the listener guard would bite', () {
      final banned = RegExp(
        r'\b(Stream<|StreamController|snapshots\(|\.listen\(|StreamBuilder|'
        r'StreamSubscription|asBroadcastStream)',
      );

      for (final offender in <String>[
        'Stream<FeedPage> watchFeed();',
        'final sub = query.snapshots().listen(_onData);',
        'return StreamBuilder<List<CommunityPost>>(',
        'final StreamController<int> _depth = StreamController();',
      ]) {
        expect(
          banned.hasMatch(offender),
          isTrue,
          reason: 'the guard must catch: $offender',
        );
      }

      // And must not fire on what the feature legitimately does.
      for (final allowed in <String>[
        'Future<FeedPage> feed({DateTime? startAfter, bool refresh = false});',
        'final page = await repository.feed();',
      ]) {
        expect(
          banned.hasMatch(allowed),
          isFalse,
          reason: 'the guard must not fire on: $allowed',
        );
      }
    });
  });

  group('no roster surfaces — who liked this, or who is in this group', () {
    test('no method could enumerate the women in a room', () {
      // `likedBy` is banned, `likedByMe` is not, and the difference is the
      // whole rule rather than a spelling exception. `likedByMe` is ONE
      // boolean about the viewer, read from posts/{id}/likes/{herUid} — a
      // point get on her own document, which the rules explicitly allow. A
      // roster is a LIST of women, which they explicitly do not. The lookahead
      // keeps the guard pointed at the second thing.
      final banned = RegExp(
        r'\b(whoLiked|likesOf|likedBy(?!Me\b)|memberList|membersOf|'
        r'listMembers|followersOf|followerList|followingList|listLikes)',
        caseSensitive: false,
      );

      expect(
        _hits(banned),
        isEmpty,
        reason:
            'likes are allow list: if false except constrained to her own '
            'posts, and members is allow list: if false outright — 4,210 '
            'women are not a list to scrape.',
      );
    });

    test('the roster guard would bite', () {
      final banned = RegExp(
        r'\b(whoLiked|likesOf|likedBy(?!Me\b)|memberList|membersOf|'
        r'listMembers|followersOf|followerList|followingList|listLikes)',
        caseSensitive: false,
      );

      for (final offender in <String>[
        'Future<List<AuthorCard>> whoLiked(String postId);',
        'final members = await membersOf(groupId);',
        'Future<List<String>> followersOf(String uid);',
        'final List<AuthorCard> likedBy;',
        'final likedByUids = <String>[];',
      ]) {
        expect(banned.hasMatch(offender), isTrue, reason: offender);
      }

      // And must NOT fire on the one-boolean form, which is what the rules
      // actually permit: "do I like this" is a get on her own like document.
      // If this ever starts failing, the guard has been widened into banning
      // the compliant shape — which would push someone to delete the guard.
      for (final allowed in <String>[
        'final bool likedByMe;',
        'likedByMe: post.likedByMe,',
        'this.likedByMe = false,',
      ]) {
        expect(
          banned.hasMatch(allowed),
          isFalse,
          reason: 'the guard must not fire on: $allowed',
        );
      }
    });
  });

  group('P1-COM-04 — no posting streak of any kind', () {
    test('no consecutive-day counter exists in the feature', () {
      // G10 adds these four to G8's single ban list, and noStreak() is AND-ed
      // into every G10 write server-side.
      final banned = RegExp(
        r'\b(postStreak|postingStreak|daysPosted|activeDays|streak|'
        r'consecutiveDays|daysInARow)\b',
        caseSensitive: false,
      );

      expect(_hits(banned), isEmpty, reason: 'rule 3: weeks, not days');
    });

    test('the streak guard would bite', () {
      final banned = RegExp(
        r'\b(postStreak|postingStreak|daysPosted|activeDays|streak|'
        r'consecutiveDays|daysInARow)\b',
        caseSensitive: false,
      );

      for (final offender in <String>[
        'final int postStreak;',
        'int daysPosted = 0;',
        "'activeDays': activeDays,",
      ]) {
        expect(banned.hasMatch(offender), isTrue, reason: offender);
      }
    });
  });

  group('P1-COM-02 — no weight reaches a community document', () {
    test('nothing in the feature can hold a scale figure', () {
      final banned = RegExp(
        r'\b(weightKg|weightLost|bodyFat|scaleWeight|startingWeight|'
        r'currentWeight)\b',
        caseSensitive: false,
      );

      expect(
        _hits(banned),
        isEmpty,
        reason:
            'the cost card is two integers. No field of that type exists in '
            'any G10 document, and rules re-assert it with hasOnly.',
      );
    });

    test('the weight guard would bite', () {
      final banned = RegExp(
        r'\b(weightKg|weightLost|bodyFat|scaleWeight|startingWeight|'
        r'currentWeight)\b',
        caseSensitive: false,
      );
      expect(banned.hasMatch('final num? weightKg;'), isTrue);
      expect(banned.hasMatch('cost.weightLost'), isTrue);
    });
  });

  group('P1-COM-08 — undo, not confirmation', () {
    test('no dialog is raised anywhere in the feature', () {
      // Blocking and deleting MAY confirm — G7's documented exemption — but a
      // Material dialog is the shape rule 9 is about, and product_rules_test
      // forbids one anywhere under lib/features. The sheet takes a second step
      // instead, which is deliberate without being a dialog.
      final banned = RegExp(r'showDialog|AlertDialog|CupertinoAlertDialog');

      expect(_hits(banned), isEmpty, reason: 'rule 9: undo, not confirmation');
    });

    test('the dialog guard would bite', () {
      final banned = RegExp(r'showDialog|AlertDialog|CupertinoAlertDialog');
      expect(
        banned.hasMatch('await showDialog<bool>(context: context,'),
        isTrue,
      );
      expect(banned.hasMatch('return AlertDialog(title: Text(x));'), isTrue);
    });
  });

  group('P1-COM-06 — rule 8, no face classification', () {
    test('nothing infers anything from a face', () {
      // Face DETECTION for on-device blur is permitted and is what the blur
      // pipeline uses. Classification is not.
      final banned = RegExp(
        r'(classifyGender|detectGender|genderFrom(Image|Face|Photo|Selfie)|'
        r'faceGender|genderClassif|predictGender|inferGender|genderDetect|'
        r'ageFromFace|ethnicity)',
        caseSensitive: false,
      );

      expect(
        _hits(banned),
        isEmpty,
        reason: 'sex comes from the ID number, never from a face',
      );
    });

    test('the classification guard would bite', () {
      final banned = RegExp(
        r'(classifyGender|detectGender|genderFrom(Image|Face|Photo|Selfie)|'
        r'faceGender|genderClassif|predictGender|inferGender|genderDetect|'
        r'ageFromFace|ethnicity)',
        caseSensitive: false,
      );
      expect(banned.hasMatch('final g = classifyGender(bytes);'), isTrue);
      expect(banned.hasMatch('detectGenderFromSelfie()'), isTrue);
    });
  });

  group('P1-COM-03 — the reward economy is not social', () {
    test('nothing in community awards points', () {
      // G6 pays nothing for posting, following or being followed, and G10 does
      // not ask for a key. A points call here would be the request arriving by
      // the back door.
      final banned = RegExp(
        r'\b(awardPoints|addPoints|points\s*\+=|grantAward|AwardTable|'
        r'rewards\.points\s*=)',
        caseSensitive: false,
      );

      expect(
        _hits(banned),
        isEmpty,
        reason: 'no points are awarded for any social action',
      );
    });

    test('the points guard would bite', () {
      final banned = RegExp(
        r'\b(awardPoints|addPoints|points\s*\+=|grantAward|AwardTable|'
        r'rewards\.points\s*=)',
        caseSensitive: false,
      );
      expect(banned.hasMatch('awardPoints(25);'), isTrue);
      expect(banned.hasMatch('points += 5;'), isTrue);
    });
  });

  group('rule 11 — nothing is ordered by a social figure', () {
    test('no sort, rank or comparator over followers or counts', () {
      final banned = RegExp(
        r'(orderBy\([^)]*(follower|likes|counts|memberCount)|'
        r'sortBy(Followers|Likes|Members)|'
        r'(follower|like|member)Leaderboard|rankBy|topBy|mostLiked|trending)',
        caseSensitive: false,
      );

      expect(_hits(banned), isEmpty, reason: 'displayed, never ranked');
    });

    test('the ranking guard would bite', () {
      final banned = RegExp(
        r'(orderBy\([^)]*(follower|likes|counts|memberCount)|'
        r'sortBy(Followers|Likes|Members)|'
        r'(follower|like|member)Leaderboard|rankBy|topBy|mostLiked|trending)',
        caseSensitive: false,
      );

      for (final offender in <String>[
        "query.orderBy('followerCount', descending: true)",
        'final top = sortByLikes(posts);',
        'Widget trendingRail() {',
      ]) {
        expect(banned.hasMatch(offender), isTrue, reason: offender);
      }
    });
  });

  group('P1-COM-01 — the forbidden orderings are unexecutable when deployed', () {
    // The Dart half is feed_query_test.dart (one Ordering value). This is the
    // storage half: Firestore auto-indexes EVERY field, so a forbidden ordering
    // is a working query unless the field is explicitly exempted. Absence of a
    // composite index is not sufficient and is not what this checks.
    late List<Map<String, dynamic>> overrides;

    setUpAll(() {
      final file = File('../firebase/firestore.indexes.json');
      expect(file.existsSync(), isTrue);
      final config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      overrides = (config['fieldOverrides'] as List)
          .cast<Map<String, dynamic>>();
    });

    bool isExempt(String group, String field) => overrides.any(
      (o) =>
          o['collectionGroup'] == group &&
          o['fieldPath'] == field &&
          (o['indexes'] as List).isEmpty,
    );

    test('a woman cannot be ordered by her followers', () {
      expect(isExempt('publicProfiles', 'followerCount'), isTrue);
    });

    test('a post cannot be ordered by its likes or its cost', () {
      expect(isExempt('posts', 'counts'), isTrue);
      expect(isExempt('posts', 'cost'), isTrue);
    });

    test('a group cannot be ordered by its size', () {
      expect(isExempt('groups', 'memberCount'), isTrue);
    });

    test('the exemption check would bite', () {
      // A field nobody exempted must report false, or the four assertions
      // above would pass over any spelling at all.
      expect(isExempt('posts', 'createdAt'), isFalse);
      expect(isExempt('publicProfiles', 'nameLower'), isFalse);
    });
  });
}
