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

/// What rule 3 still bans after D37: a bare streak, the day-run spellings a
/// counter would use, and the words a loss state would need.
final RegExp _rule3Banned = RegExp(
  r'\b(streak|dayStreak|daysInARow|consecutiveDays|currentStreak|'
  r'longestStreak|missedDays|daysMissed|streakLost|lostStreak|brokenStreak|'
  r'streakBroken|streakAtRisk)\b',
  caseSensitive: false,
);

/// The ARB keys D37 allows to mention a streak. Exact keys, not a pattern.
const Set<String> kStreakCopyKeys = <String>{
  'trainingStreak',
  'trainingStreakDaysDays',
  'daysPluralOneTrainingStreak1Day',
  'showMyTrainingStreak',
  // Where to turn it back on, after she turns it off (no loss, no judgement).
  'streakHiddenTurnItBackOnIn',
};

/// Every string D37 added, whether or not it says "streak". All of them are
/// held to the loss check, in both languages' English source.
const Set<String> kD37CopyKeys = <String>{
  ...kStreakCopyKeys,
  'daysDays',
  'yourBestDaysDays',
  'daysPluralOneYourBest1Day',
  'day1StartsWithYourNextSession',
  'pausedUntilDate',
  'pausedUntilYouComeBack',
  'restDaysCountWhileYourWeekGoal',
  'pauseForAWeek',
  'pauseForTwoWeeks',
  'pauseUntilIComeBack',
  'resumeNow',
  'keptOnThisPhoneTurnItOff',
  'yourWeeksCountAndSoDoThe',
};

/// Loss language, banned from every streak string.
final RegExp _lossWords = RegExp(
  r"\b(lose|lost|losing|break|breaks|broke|broken|miss|missed|risk|save|"
  r"alive|don't|do not|keep it going)\b",
  caseSensitive: false,
);

void main() {
  test('RULE 3 — nothing in the source can hold or render a daily streak', () {
    // Weeks are the unit of reward. D37 (13 October 2026) admits exactly one
    // day-based thing: a training streak she controls, named as such
    // (`TrainingStreak`, `trainingStreak`, `StreakStatus`). Everything a bare
    // streak counter, a missed-day tally or a loss would need is still banned:
    // a field called `streak`, a count of missed days, a streak "at risk".
    expect(
      _hits(_rule3Banned),
      isEmpty,
      reason:
          'Rule 3 and D37: the only day-based mechanic is the training '
          'streak she controls. No bare streak counter, no missed days, no '
          'loss state.',
    );
  });

  test('RULE 3 — the D37 names pass and a bare counter still fails', () {
    expect(
      _hitsIn('final StreakStatus? trainingStreak = null;', _rule3Banned),
      isEmpty,
      reason: 'the training streak D37 allows, by its own names',
    );
    expect(
      _hitsIn('class TrainingStreak { const TrainingStreak(); }', _rule3Banned),
      isEmpty,
    );
    expect(_hitsIn('int streak = 0;', _rule3Banned), hasLength(1));
    expect(_hitsIn('final missedDays = 2;', _rule3Banned), hasLength(1));
    expect(_hitsIn('bool streakAtRisk = true;', _rule3Banned), hasLength(1));
  });

  test('RULE 3 — the deny-list exemption cannot hide a real streak', () {
    // Without this, the exemption added for `kForbiddenStreakKeys` would be a
    // hole: name any declaration "Forbidden" and hide a field inside it.
    final banned = RegExp(
      r'\b(streak|dayStreak|currentStreak)\b',
      caseSensitive: false,
    );

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

  test('RULE 3 — only the D37 copy mentions a streak, and never a loss', () {
    // Rule 3 is not only structural; the word must not reach a screen either,
    // except in the few strings D37 names — and those may never say she could
    // lose, break, miss or save anything.
    final arb = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final offenders = <String>[];
    arb.forEach((key, value) {
      if (key.startsWith('@')) return;
      if (value is! String) return;
      if (!RegExp('streak', caseSensitive: false).hasMatch(value)) return;
      if (!kStreakCopyKeys.contains(key)) {
        offenders.add('$key = "$value" (not a D37 string)');
      } else if (_lossWords.hasMatch(value)) {
        offenders.add('$key = "$value" (loss language)');
      }
    });
    expect(
      offenders,
      isEmpty,
      reason: 'Rule 3 and D37: streak copy is the named list, and never loss.',
    );
    // The list is not a wildcard: every key on it exists, and none of the
    // D37 strings — the pauses, the rule, the switch — speaks of loss.
    for (final key in kD37CopyKeys) {
      expect(arb.containsKey(key), isTrue, reason: '$key is not in the ARB');
      expect(
        _lossWords.hasMatch(arb[key] as String),
        isFalse,
        reason: '$key = "${arb[key]}" (loss language)',
      );
    }
  });

  test('RULE 3 — the loss check catches loss language', () {
    expect(_lossWords.hasMatch("Don't lose your streak"), isTrue);
    expect(_lossWords.hasMatch('Your streak is at risk'), isTrue);
    expect(_lossWords.hasMatch('Show my training streak'), isFalse);
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
    //
    // `lib/firebase_options.dart` is exempt, and nothing else is. The reason is
    // a real distinction, not a convenience: a Firebase apiKey is not a secret.
    // It is a public project identifier that ships inside every Android and iOS
    // binary by design, it authorises nothing on its own, and what actually
    // protects the data is `firebase/firestore.rules`. Google documents it as
    // safe to expose. Treating it as a secret would mean deleting the generated
    // file the app cannot compile without.
    //
    // The `AIza` half of the pattern still matters everywhere else, and that is
    // the whole reason this exemption is one path and not a relaxed regex: a
    // Gemini key is also `AIza...` and is indistinguishable by shape from the
    // Firebase one. A key that bills us, in a file anyone can unzip, would look
    // exactly like the line being allowed here. The pairing test below is what
    // stops that.
    final banned = RegExp(
      r'(sk-ant-|ANTHROPIC_API_KEY\s*=\s*.|AIza[0-9A-Za-z_\-]{30,})',
    );
    final offenders = _hits(banned)
        .where((hit) => !hit.contains('lib/firebase_options.dart'))
        .toList();
    expect(
      offenders,
      isEmpty,
      reason: 'No API key may be committed to the app source.',
    );
  });

  test('the firebase_options exemption cannot hide a real key', () {
    // Without this, the exemption above is a hole exactly the size of a Gemini
    // key: paste one into the generated file and no guard looks at it again.
    // Same shape as the deny-list pairing for rule 3.
    final file = File('lib/firebase_options.dart');
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'The exempted file must exist, or the exemption is stale and '
          'should be deleted rather than left pointing at nothing.',
    );
    final source = file.readAsStringSync();

    expect(
      source.contains('DefaultFirebaseOptions'),
      isTrue,
      reason:
          'The exempted path must be the FlutterFire generated file. If it '
          'is something else, the exemption is being reused for a file it was '
          'never reasoned about.',
    );
    expect(
      RegExp(r'sk-ant-|ANTHROPIC_API_KEY').hasMatch(source),
      isFalse,
      reason:
          'An Anthropic key is a secret wherever it is written, and the '
          'generated file has no reason to contain one.',
    );

    // Every Google-shaped key in the file must sit on an `apiKey:` line. A
    // Gemini key would arrive on some other field, or in a bare constant, and
    // that is the case this catches.
    final lines = source.split('\n');
    final misplaced = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (!RegExp(r'AIza[0-9A-Za-z_\-]{30,}').hasMatch(lines[i])) continue;
      if (_isComment(lines[i])) continue;
      if (RegExp(r'\bapiKey\s*:').hasMatch(lines[i])) continue;
      misplaced.add('lib/firebase_options.dart:${i + 1}  ${lines[i].trim()}');
    }
    expect(
      misplaced,
      isEmpty,
      reason:
          'A Google API key in the generated file that is not the Firebase '
          'apiKey field is not covered by the reasoning for this exemption.',
    );
  });
}
