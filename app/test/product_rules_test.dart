// Executable guards for the §2 rules that can be enforced mechanically, written
// before the code that could violate them exists.
//
// These are the rules an implementer breaks *innocently*: a streak counter, a
// calorie countdown and a gender classifier are all normal things to build, and
// each one breaks this product. The schema is designed so they cannot be stored
// (SCHEMA-SPINE.md C6/C7); these tests make sure they cannot be written either.
//
// The remaining P1 rules need the domain layer and get their tests with it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source we own. The generated localisation Dart is checked separately, against
/// the ARB it comes from, so a failure points at the dictionary and not at 10,000
/// lines of generated getters.
List<File> _ownSource() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where(
      (f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/app_l10n'),
    )
    .toList();

/// True for a line that is only a comment.
///
/// These guards scan code, not prose. A file that says "this is deliberately not
/// a streak" is documenting the rule, not breaking it — and a guard that fails
/// on correct code for explaining itself teaches people to stop explaining, or
/// to delete the guard. Both are worse than the guard not existing.
bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('///') || t.startsWith('*');
}

/// Opens a declaration whose NAME says it is a deny list.
///
/// `const Set<String> kForbiddenStreakKeys = <String>{` and friends.
final RegExp _denyListOpens = RegExp(
  r'^\s*(const|final|static)\b.*\b\w*(Forbidden|Banned|Blocked|Denied)\w*\s*=.*\{\s*$',
);

/// True for a line that closes a brace-delimited declaration.
bool _closesDeclaration(String line) {
  final t = line.trim();
  return t == '};' || t == '},' || t == '}';
}

/// Reports `path:line` for every line matching [pattern], excluding comments
/// and the contents of deny lists.
///
/// ## Why deny lists are excluded
///
/// The same reasoning as [_isComment], one step further. A file that writes
///
/// ```dart
/// const Set<String> kForbiddenStreakKeys = <String>{'dayStreak', ...};
/// ```
///
/// is not holding a streak. It is the code that makes a streak **unstorable**,
/// and it has to name the thing it bans in order to ban it. Failing it here
/// leaves an implementer two moves: delete the guard, or rename the keys so the
/// scanner stops seeing them — and the second one is worse, because the ban
/// survives in name while matching nothing.
///
/// This was not theoretical. Two Phase 3 agents independently wrote deny lists
/// for rule 3, and both were reported as rule-3 violations by this guard.
///
/// The exemption is narrow: only lines **inside** a declaration whose own name
/// contains Forbidden/Banned/Blocked/Denied, and only until its closing brace.
/// `_denyListExemptionIsNarrow` below proves a real field one line outside such
/// a list is still caught.
List<String> _hits(RegExp pattern) {
  final out = <String>[];
  for (final file in _ownSource()) {
    final lines = file.readAsLinesSync();
    var inDenyList = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isComment(line)) continue;
      if (inDenyList) {
        if (_closesDeclaration(line)) inDenyList = false;
        continue;
      }
      if (_denyListOpens.hasMatch(line)) {
        inDenyList = true;
        continue;
      }
      if (pattern.hasMatch(line)) {
        out.add('${file.path}:${i + 1}  ${line.trim()}');
      }
    }
  }
  return out;
}

/// The same scan over an arbitrary source string, for the controls below.
List<String> _hitsIn(String source, RegExp pattern) {
  final out = <String>[];
  final lines = source.split('\n');
  var inDenyList = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (_isComment(line)) continue;
    if (inDenyList) {
      if (_closesDeclaration(line)) inDenyList = false;
      continue;
    }
    if (_denyListOpens.hasMatch(line)) {
      inDenyList = true;
      continue;
    }
    if (pattern.hasMatch(line)) out.add('${i + 1}  ${line.trim()}');
  }
  return out;
}

void main() {
  test('RULE 3 — nothing in the source can hold or render a daily streak', () {
    // Weeks are the only unit. A rest week repairs a missed week automatically,
    // which is incompatible with a consecutive-day counter existing at all.
    final banned = RegExp(
      r'\b(streak|dayStreak|daysInARow|consecutiveDays|currentStreak|longestStreak)\b',
      caseSensitive: false,
    );
    expect(
      _hits(banned),
      isEmpty,
      reason: 'Rule 3: weeks, not days. No streak may exist in any form.',
    );
  });

  test('RULE 3 — the deny-list exemption cannot hide a real streak', () {
    // Without this, the exemption added for `kForbiddenStreakKeys` would be a
    // hole: name any declaration "Forbidden" and hide a field inside it.
    final banned = RegExp(r'\b(streak|dayStreak|currentStreak)\b',
        caseSensitive: false);

    const denyList = '''
const Set<String> kForbiddenStreakKeys = <String>{
  'dayStreak',
  'currentStreak',
};
''';
    expect(
      _hitsIn(denyList, banned),
      isEmpty,
      reason: 'a list that BANS the keys is enforcing rule 3, not breaking it',
    );

    // One line outside the list, and it is caught again.
    const realViolation = '''
const Set<String> kForbiddenStreakKeys = <String>{
  'dayStreak',
};
int currentStreak = 0;
''';
    expect(
      _hitsIn(realViolation, banned),
      hasLength(1),
      reason: 'the exemption ends at the closing brace, not at the file',
    );

    // A field that merely sits near a deny list is still caught.
    const nearMiss = 'class Coach { int dayStreak = 0; }';
    expect(_hitsIn(nearMiss, banned), hasLength(1));
  });

  test('RULE 3 — no user-facing copy mentions a streak', () {
    // Rule 3 is not only structural; the word must not reach a screen either.
    final arb = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final offenders = <String>[];
    arb.forEach((key, value) {
      if (key.startsWith('@')) return;
      if (value is String &&
          RegExp('streak', caseSensitive: false).hasMatch(value)) {
        offenders.add('$key = "$value"');
      }
    });
    expect(offenders, isEmpty, reason: 'Rule 3: no streak language in the UI.');
  });

  test('the running total is never a countdown', () {
    // A calm total that moves, never a budget draining toward zero. Enforced by
    // making the countdown unrepresentable rather than by review.
    final banned = RegExp(
      r'\b(kcalRemaining|caloriesRemaining|calorieCountdown|remainingCalories|kcalLeft)\b',
      caseSensitive: false,
    );
    expect(
      _hits(banned),
      isEmpty,
      reason: 'A calorie countdown is not a variation of a running total.',
    );
  });

  test('RULE 7 — the ID photo and the selfie have nowhere to be kept', () {
    // The promise C13 makes at the moment she is most likely to believe it:
    // the pictures are gone, the result is not. Rules 3, 8, 9 and 11 each had
    // an executable guard; this one had only copy assertions on three screens,
    // so nothing stopped `String? idPhotoUrl` being added to VerificationResult
    // tomorrow with the whole suite green. QA called it the most valuable
    // missing guard in the codebase.
    //
    // Enforced the way C6 enforces rule 3 — by making it unstorable rather than
    // forbidden. `VerificationResult` holds a method, two timestamps and
    // nothing else; there is deliberately no field an image, a document number
    // or a name could live in.
    //
    // Face DETECTION for on-device blur is a different thing and is permitted:
    // this targets somewhere to PUT a captured image, not the act of looking at
    // one. `CaptureTarget.selfie` and `_StepLabel.selfieMatched` are a capture
    // request and a progress label, so the matcher requires a storage-shaped
    // name rather than the word alone.
    // No trailing \b — deliberately, and the control below is why.
    //
    // With one, `idPhotoUrl` did NOT match: the boundary would have to fall
    // between `Photo` and `Url`, and both sides are word characters. So the
    // guard silently missed every identifier that continues past the banned
    // suffix — `idPhotoUrl`, `cardScanPath`, `selfieImageData` — which is most
    // of the realistic ones. It would have shipped as protection that could
    // never fire. The leading \b stays, so it still will not match mid-word.
    final banned = RegExp(
      r'\b('
      r'(id|card|selfie|face|document|passport)(Photo|Image|Picture|Scan|Bytes|File|Url|Uri|Path|Base64|Blob|Data)'
      r'|(photo|image|picture|scan)Of(Id|Card|Face|Document)'
      r'|(nationalIdNumber|documentNumber|dateOfBirth|legalName)'
      r')',
      caseSensitive: false,
    );

    expect(
      _hits(banned),
      isEmpty,
      reason:
          'Rule 7: the ID photo and the selfie are deleted once the check '
          'completes, and the cheapest way to keep that promise is to have '
          'nowhere to put them. A field like this is somewhere to put them.',
    );
  });

  test('RULE 7 — the guard would actually bite', () {
    // A positive control. A source-scanning guard that matches nothing is
    // indistinguishable from one whose regex is broken, and this codebase has
    // already shipped a vacuous rule-9 guard that passed for weeks by not
    // looking at the right folder. So the pattern is proven against text that
    // must match before it is trusted against a tree that must not.
    final banned = RegExp(
      r'\b('
      r'(id|card|selfie|face|document|passport)(Photo|Image|Picture|Scan|Bytes|File|Url|Uri|Path|Base64|Blob|Data)'
      r'|(photo|image|picture|scan)Of(Id|Card|Face|Document)'
      r'|(nationalIdNumber|documentNumber|dateOfBirth|legalName)'
      r')',
      caseSensitive: false,
    );

    for (final offender in [
      'final String? idPhotoUrl;',
      'final Uint8List selfieBytes;',
      'String cardScanPath = "";',
      'final String photoOfId;',
      'final String nationalIdNumber;',
      'final DateTime dateOfBirth;',
    ]) {
      expect(
        banned.hasMatch(offender),
        isTrue,
        reason: 'the guard must catch: $offender',
      );
    }

    // And must NOT fire on the things rule 7 permits.
    for (final allowed in [
      'final session = await widget.captureService.open(CaptureTarget.selfie);',
      '_StepLabel.selfieMatched => l10n.selfieMatchedToTheCard,',
      'final DateTime? imagesDeletedAt;',
      'bool get imagesConfirmedDeleted => imagesDeletedAt != null;',
    ]) {
      expect(
        banned.hasMatch(allowed),
        isFalse,
        reason: 'the guard must not fire on: $allowed',
      );
    }
  });

  test('RULE 8 — no face-based gender classification anywhere', () {
    // The women-only gate is the 13th digit of the national ID number, never a
    // model looking at a face (Tickle v Giggle, Full Federal Court of Australia,
    // May 2026). Face DETECTION for on-device blur is a different thing and is
    // explicitly permitted — this matcher targets classification only.
    final banned = RegExp(
      r'(classifyGender|detectGender|genderFrom(Image|Face|Photo|Selfie)|'
      r'faceGender|genderClassif|predictGender|inferGender|genderDetect)',
      caseSensitive: false,
    );
    expect(
      _hits(banned),
      isEmpty,
      reason: 'Rule 8: sex comes from the ID number, never from a face.',
    );
  });

  test(
    'RULE 11 — nothing sorts women by weight, weight lost, or followers',
    () {
      final banned = RegExp(
        r'(orderBy\([^)]*(weight|followers|weightLost)|'
        r'sortBy(Weight|Followers|WeightLost)|'
        r'(weight|follower)Leaderboard|rankBy(Weight|Followers))',
        caseSensitive: false,
      );
      expect(
        _hits(banned),
        isEmpty,
        reason: 'Rule 11: displayed, never ranked.',
      );
    },
  );

  test('RULE 9 — logging never raises a confirmation dialog', () {
    // Five-second undo instead. A confirmation on a log is the friction this
    // product exists to remove. Destructive bulk actions may confirm; none exist
    // in this tree yet, so any showDialog beside a log call is a violation.
    // Scans EVERY feature, not a hand-picked subset.
    //
    // This filtered to '/log', '/today' and '/eat' and therefore never looked at
    // lib/features/train/ — which is where R07, R08, R09 and R13 live, the exact
    // screens rule 9 is about. The guard passed for weeks by not looking. QA
    // caught it; a vacuous guard is worse than no guard, because it is trusted.
    // Second defect, same guard, opposite direction: it read whole files with
    // readAsStringSync() and so was the ONLY rule guard that never applied the
    // _isComment filter rules 3, 7, 8 and 11 all use. A file whose doc comment
    // said "there is deliberately no showDialog here" failed the build for
    // saying so. Three correct files tripped it at once — body_privately_view,
    // cycle_deletion_machine and cycle_settings_view — every one of them a file
    // documenting that it obeys rule 9.
    //
    // A guard that punishes explaining it has two outcomes, and both are worse
    // than no guard: people stop writing the explanation, or they delete the
    // guard. Line-scanned and comment-filtered like the others, and reporting
    // path:line so the next failure names the dialog instead of the file.
    final logFiles = _ownSource().where(
      (f) =>
          f.path.contains('/features/') || f.path.contains('/domain/logging'),
    );
    final banned = RegExp(r'showDialog|AlertDialog');
    final offenders = <String>[];
    for (final f in logFiles) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_isComment(lines[i])) continue;
        if (banned.hasMatch(lines[i])) {
          offenders.add('${f.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Rule 9: undo, not confirmation, on every logging path.',
    );
  });

  test('no Claude or third-party API key is present in the app source', () {
    // §7: the key never ships in the app. The assistant calls Claude from a Cloud
    // Function. A key in the bundle is extractable by anyone who downloads it.
    final banned = RegExp(
      r'(sk-ant-|ANTHROPIC_API_KEY\s*=\s*.|AIza[0-9A-Za-z_\-]{30,})',
    );
    expect(
      _hits(banned),
      isEmpty,
      reason: 'No API key may be committed to the app source.',
    );
  });
}
