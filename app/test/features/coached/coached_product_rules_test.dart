// Source-level guards for the rules this feature owns, written the way
// `product_rules_test.dart` writes them: read the code, not the intention.
//
// These are the rules an implementer breaks *innocently*. A "share everything"
// toggle, a confirmation dialog before logging a set, a transcript so the coach
// can skim a voice note, a cycle field on the constraints projection — every one
// of those is a reasonable thing to build and each one breaks this product.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Dart file this feature owns.
List<File> _featureFiles() =>
    Directory('lib/features/coached')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('///') || t.startsWith('*');
}

/// `path:line` for every non-comment line matching [pattern].
List<String> _hits(RegExp pattern, {bool Function(File)? where}) {
  final out = <String>[];
  for (final file in _featureFiles()) {
    if (where != null && !where(file)) continue;
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
  test('HANDOFF 6 — there is no "share everything" switch to build', () {
    final banned = RegExp(
      r'\b(shareAll|shareEverything|enableAllSharing|allSwitches|masterSwitch|'
      r'setAllSharing|grantAll)\b',
      caseSensitive: false,
    );
    expect(
      _hits(banned),
      isEmpty,
      reason:
          'Four independent switches, and no fifth that moves them together. '
          'A master switch is the one control HANDOFF 6 forbids.',
    );
  });

  test('a voice note is never transcribed for the coach', () {
    final banned = RegExp(
      r'\b(transcript|transcription|transcribe|speechToText)\b',
      caseSensitive: false,
    );
    expect(_hits(banned), isEmpty);
  });

  test('§2.9 — undo, not confirmation, with the two named exemptions', () {
    // G11 §5: "Two deliberate exceptions, named so QA does not read them as
    // violations: paying and ending coaching MAY confirm."
    //
    // Everything else logs immediately with five seconds to take it back, so a
    // dialog anywhere in this feature's presentation layer is a defect — except
    // in the two files that own those two acts.
    const exempt = {
      'lib/features/coached/presentation/coaching_ended_view.dart',
      'lib/features/coached/domain/purchase_gate.dart',
      'lib/features/coached/domain/relationship.dart',
    };

    final banned = RegExp(
      r'\b(showDialog|AlertDialog|showConfirm|areYouSure)\b',
    );
    final offenders = _hits(
      banned,
      where: (f) => !exempt.any((e) => f.path.endsWith(e.split('/').last)),
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Logging a set, a meal or a review never asks first. Only paying and '
          'ending coaching may.',
    );
  });

  test('nothing in this feature can write a plan', () {
    // The message repository has its own dedicated guard. This is the wider
    // net: no file here may name a publish, because publishing is the coach
    // side's act and this feature is the client's.
    final banned = RegExp(
      r'\b(publishPlan|publishCoachPlan|writeAssignment|savePlanVersion|'
      r'PlanPublisher)\b',
    );
    expect(_hits(banned), isEmpty);
  });

  test('§2.3 / C6 — no streak, in any spelling', () {
    final banned = RegExp(
      r'\b(streak|dayStreak|daysInARow|consecutiveDays|currentStreak)\b',
      caseSensitive: false,
    );
    expect(_hits(banned), isEmpty);
  });

  test('§2.11 — nothing here can rank by weight, weight lost or followers', () {
    final banned = RegExp(
      r'\b(weightLost|followerCount|rankByWeight|sortByFollowers|leaderboard)\b',
      caseSensitive: false,
    );
    expect(_hits(banned), isEmpty);
  });

  test('the feature owns no second food diary and no second session store', () {
    // G11 §1.1: "G11 creates no second workout history and no second food
    // diary." The test is that nothing here declares a repository for them.
    final banned = RegExp(
      r'\bclass \w*(MealRepository|SessionRepository|FoodDiary)\b',
    );
    expect(_hits(banned), isEmpty);
  });

  test('every file in the feature is reached by the l10n and rule guards', () {
    // A sanity check on the scan itself: a guard that silently found no files
    // would pass every test above while protecting nothing.
    final files = _featureFiles();
    expect(
      files.length,
      greaterThanOrEqualTo(10),
      reason: 'the scan found ${files.length} files — is the path still right?',
    );
  });
}
