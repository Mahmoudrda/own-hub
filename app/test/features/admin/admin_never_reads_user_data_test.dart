// An executable guard over this feature's own source, in the idiom
// `product_rules_test.dart` established.
//
// D12: "**An admin is staff, not a member.** The console manages the content
// library. It is not a window into anyone's account." G16 §1 puts the same thing
// in terms a test can check: "nothing in it reads `users/**`."
//
// The guards elsewhere in this repo were written because a rule everybody agrees
// with is still broken innocently — a streak counter and a calorie countdown are
// normal things to build. So is a "show me this member's logs" screen in an
// admin console. Every admin tool anybody has used has one. This is what stops
// it being added here without an argument.
//
// Two lessons from `product_rules_test.dart` are applied deliberately:
//
//   1. It scans line by line and skips comment lines. A guard that failed on a
//      file for *documenting* the rule taught people to stop explaining
//      themselves, and three correct files tripped it at once.
//   2. It proves the pattern bites before trusting it over a tree that must not
//      match. A guard matching nothing is indistinguishable from a broken one.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// This feature's source, which is the only tree this guard is about.
List<File> _adminSource() {
  final dir = Directory('lib/features/admin');
  if (!dir.existsSync()) return const [];
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

List<String> _hits(RegExp pattern) {
  final out = <String>[];
  for (final file in _adminSource()) {
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

/// Collections and fields that belong to a woman, never to the library.
///
/// ## There is no leading `\b`, and that is the whole lesson of RULE 7
///
/// This pattern was first written as `\b( users | mealLogs | … )`, with one
/// boundary in front of the alternation. It missed `readMealLogs(uid)` — the
/// boundary would have to fall between `read` and `MealLogs`, and both sides are
/// word characters, so it never matched. The positive control below is what
/// caught it, before the guard was ever trusted over real source.
///
/// `product_rules_test.dart` records the identical defect in the opposite
/// direction: its rule-7 matcher had a *trailing* `\b`, and so "silently missed
/// every identifier that continues past the banned suffix — `idPhotoUrl`,
/// `cardScanPath`, `selfieImageData` — which is most of the realistic ones. It
/// would have shipped as protection that could never fire."
///
/// A banned name in real code almost always carries a verb in front of it:
/// `readMealLogs`, `fetchCheckIns`, `loadMeasurements`. So each alternative
/// keeps its **trailing** boundary — which is what stops `periods?` matching
/// inside `periodic` — and drops the leading one. `cycle` is the exception and
/// keeps both, because without a leading boundary it fires on `lifecycle` and
/// `recycled`, and a guard that cries wolf is a guard somebody deletes.
///
/// `cycle` carries one more exclusion: **`Feature.cycle` is the name of a
/// switch, not of a collection.** Z14 lists every feature in the product with a
/// toggle beside it, and one of the features is My cycle — so the switchboard
/// necessarily writes the identifier down. Naming a flag is the opposite of
/// reading a woman's cycle documents, and the guard has to be able to tell the
/// difference or the only screen that can switch a feature off becomes
/// unwritable. Nothing else is excused: `cycleData`, `cycleLog` and a bare
/// `cycle` still bite wherever they appear.
final RegExp _memberData = RegExp(
  r'users/'
  r'|users\b'
  r'|(?<!Feature\.)\bcycle(Data|Log|Entry)?\b'
  r'|periods?\b'
  r'|checkIns?\b'
  r'|measurements?\b'
  r'|progressPhotos?\b'
  r'|mealLogs?\b'
  r'|sessionLogs?\b'
  r'|phoneNumber\b'
  r'|verificationResult\b',
  caseSensitive: false,
);

void main() {
  test('the admin feature exists and this guard is looking at it', () {
    // The vacuous-guard check. `product_rules_test.dart` shipped a rule-9 guard
    // that passed for weeks by filtering to folders it never looked in; this
    // asserts the tree is non-empty before anything below is believed.
    expect(
      _adminSource(),
      isNotEmpty,
      reason:
          'lib/features/admin has no Dart files, so every assertion below '
          'passes over nothing at all.',
    );
  });

  test('nothing in the admin console names a member collection', () {
    expect(
      _hits(_memberData),
      isEmpty,
      reason:
          'D12: an admin is staff, not a member. This console manages the '
          'content library and is not a window into anyone\'s account. A '
          'reference to users/** here is the first step of the feature that '
          'would make that false.',
    );
  });

  test('the guard would actually bite', () {
    // The positive control, exactly as RULE 7 has one.
    for (final offender in [
      "final doc = db.collection('users').doc(uid);",
      "final path = 'users/\$uid/progressPhotos';",
      'final logs = await readMealLogs(uid);',
      'final String phoneNumber;',
      'final checkIns = snapshot.docs;',
      'final measurements = <String>[];',
      // Still caught when it is a collection rather than a switch.
      "final cycle = await db.collection('cycle').get();",
    ]) {
      expect(
        _memberData.hasMatch(offender),
        isTrue,
        reason: 'the guard must catch: $offender',
      );
    }

    // And must not fire on the content library's own vocabulary, or the whole
    // feature becomes unwritable and somebody deletes the guard.
    for (final allowed in [
      "storagePathFor(collection: ContentCollection.recipes, documentId: id)",
      "const String prefix = 'content/exercises';",
      'final rows = plan.writes;',
      'expect(manifest.csvPaths, [\'foods.csv\']);',
      // Z14's row for My cycle. A flag identifier, not a document path.
      'Feature.cycle,',
    ]) {
      expect(
        _memberData.hasMatch(allowed),
        isFalse,
        reason: 'the guard must not fire on: $allowed',
      );
    }
  });

  test('no storage or firestore path outside content/ is written here', () {
    // §4 and §5 both narrow to `content/`. Anything else is out of scope for
    // this console by construction.
    final pathLiteral = RegExp(r"""'((?:content|users|user-[a-z]+)/[^']*)'""");
    final offenders = <String>[];

    for (final file in _adminSource()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_isComment(lines[i])) continue;
        for (final m in pathLiteral.allMatches(lines[i])) {
          final path = m.group(1)!;
          if (!path.startsWith('content/')) {
            offenders.add('${file.path}:${i + 1}  $path');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'The admin console addresses content/ and nothing else. '
          '${offenders.join(', ')}',
    );
  });

  test('this feature raises no confirmation dialog', () {
    // Rule 9's guard in `product_rules_test.dart` already covers every feature
    // folder, so this is a second copy — deliberately. The destructive-bulk
    // exemption is most likely to be claimed HERE, by someone who has read §3.1
    // and reasonably concluded that rewriting the library deserves a prompt. It
    // does. `ImportCommit.confirming` is that prompt, and it is a state.
    expect(
      _hits(RegExp(r'showDialog|AlertDialog')),
      isEmpty,
      reason:
          'Destructive bulk actions confirm with an inline `confirming` state '
          '(see import_commit_machine.dart), never a dialog.',
    );
  });

  test('no number is formatted through NumberFormat', () {
    // P0-A11Y-01: Western digits in both languages. `intl`'s NumberFormat
    // switches to Eastern digits under `ar`, and every count this console shows
    // — rows ready, rows with problems, files in the upload — would flip.
    expect(
      _hits(RegExp(r'\bNumberFormat\b')),
      isEmpty,
      reason: 'Use countLabel from lib/domain/format/number_label.dart.',
    );
  });

  test('no daily streak, in any spelling', () {
    // Rule 3 is global and already guarded, but an import summary counting
    // "days in a row of successful imports" is the kind of thing that gets
    // added to an admin dashboard without anybody thinking of rule 3.
    expect(
      _hits(
        RegExp(
          r'\b(streak|daysInARow|consecutiveDays|dayStreak)\b',
          caseSensitive: false,
        ),
      ),
      isEmpty,
      reason: 'Rule 3: weeks are the only unit.',
    );
  });

  test('layout is written directionally, so it mirrors in Arabic', () {
    // The app is RTL-first. `EdgeInsets.only(left:)` does not mirror, and the
    // failure is invisible in English — which is the language this feature was
    // written in. Caught by a guard rather than by review for that reason.
    final offenders = _hits(
      RegExp(
        r'EdgeInsets\.only\(\s*(left|right)\s*:|Alignment\.centerLeft|'
        r'Alignment\.centerRight|Alignment\.topLeft|Alignment\.topRight',
      ),
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Use EdgeInsetsDirectional and AlignmentDirectional so the console '
          'mirrors in Arabic like every other screen. ${offenders.join(', ')}',
    );
  });
}
