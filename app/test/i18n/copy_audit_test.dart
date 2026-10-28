// The copy audit (release plan 3.4): nothing she reads may tell her she missed,
// lost or failed, and no error may tell her she is wrong.
//
// It scans every value in both dictionaries. The strings that already say one
// of these words are listed below, each with the reason it stays: they reassure
// ("Nothing is lost"), speak for the product ("Something went wrong at our
// end"), face a coach, or carry a safety instruction. The list may only shrink:
// an entry that no longer matches fails the test, and a new string that matches
// fails it too, so the way past it is to say the thing another way.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final List<RegExp> _english = [
  RegExp(r'\bmissed\b', caseSensitive: false),
  RegExp(r'\blost\b', caseSensitive: false),
  RegExp(r'\bfailed\b', caseSensitive: false),
  RegExp('broken streak', caseSensitive: false),
  RegExp(r"you haven'?t", caseSensitive: false),
  RegExp(r'\binvalid\b', caseSensitive: false),
  RegExp(r'\bincorrect\b', caseSensitive: false),
  RegExp(r'\bwrong\b', caseSensitive: false),
];

/// Whole words, with the vowel marks dropped, as `egyptian_arabic_test` does.
const List<String> _arabic = ['فاتك', 'ضيعتي', 'فشلتي', 'انقطع'];

final RegExp _marks = RegExp('[ً-ٰـ]');
final RegExp _word = RegExp('[ء-ي]+');

/// Key to the reason it may keep a flagged word.
const Map<String, String> _allowed = {
  // The word is denied, not claimed: she is told nothing is lost.
  'nothingIsLostOneSessionStartsIt': 'reassures',
  'nothingWasLost': 'reassures',
  'nothingsLostOneSessionGetsItGoing': 'reassures',
  'missedADayNoProblemPickUp': 'reassures',
  'aMissedWeekRepairedWithoutAsking': 'reassures',
  'threeSessionsMakesTheWeekCountMiss': 'reassures',
  'noTimerOnAnyOfThemMiss': 'reassures',
  'hitYourGoalAndTheWeekCounts': 'reassures',
  'aFewTipsInYourFirstWeeks': 'says when tips do not appear, no blame',
  // The product owns the fault.
  'somethingWentWrongAtOurEndNothing': 'our fault, said so',
  'somethingWentWrongPleaseTryAgain': 'our fault, said so',
  'somethingWentWrongYourAnswersAreSaved': 'our fault, said so',
  'somethingWentWrongWhileListeningTryAgain': 'our fault, said so',
  'tellUsWhatWentWrongOwnHub': 'invites a report, no blame',
  // What she is about to lose, said before it happens so she can stop.
  'yourChangesToThisWorkoutWillBe': 'warns before an edit is discarded',
  // Written for a coach, about her clients.
  'missedSessions': 'coach-facing needs-attention label',
  // Safety instructions that must stay as written.
  'writtenForPregnancyCheckWithYourDoctor': 'medical safety instruction',
  'writtenForAfterABirthCheckWith': 'medical safety instruction',
  'weReadTheseFromYourSheetCheck': 'asks her to check what was read',
  // Plain facts she needs.
  'deletingYourAccountRemovesItFromOur_1xldi': 'legal disclosure of retention',
  'weCouldNotFindThePaymentIf': 'payment dispute wording, owned by payments',
  'theDateOrTimeOnYourPhone': 'clock fault, owned by the account builder',
};

Map<String, String> _values(String file) {
  final raw = jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final entry in raw.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value as String,
  };
}

Set<String> _flagged() {
  final keys = <String>{};
  for (final entry in _values('lib/l10n/app_en.arb').entries) {
    if (_english.any((pattern) => pattern.hasMatch(entry.value))) {
      keys.add(entry.key);
    }
  }
  for (final entry in _values('lib/l10n/app_ar.arb').entries) {
    final words = _word
        .allMatches(entry.value.replaceAll(_marks, ''))
        .map((m) => m.group(0)!)
        .toSet();
    if (words.intersection(_arabic.toSet()).isNotEmpty) keys.add(entry.key);
  }
  return keys;
}

void main() {
  test('no string says missed, lost, failed, wrong or a broken streak', () {
    final unlisted = _flagged().difference(_allowed.keys.toSet());
    expect(
      unlisted,
      isEmpty,
      reason:
          'Say it another way. If it truly must stay, add the key to _allowed '
          'with its reason.',
    );
  });

  test('the list holds only strings that still match', () {
    final stale = _allowed.keys.toSet().difference(_flagged());
    expect(stale, isEmpty, reason: 'Remove these from _allowed.');
  });

  test('the closing lines on R10 are clean and carry no figure', () {
    final en = _values('lib/l10n/app_en.arb');
    for (final key in const [
      'gladYouShowedUpToday',
      'thatWasForYou',
      'restWellYouEarnedIt',
      'beProudOfThatOne',
      'strongWorkToday',
    ]) {
      expect(en[key], isNotNull, reason: key);
      expect(en[key], isNot(contains(RegExp(r'\d'))), reason: key);
      expect(en[key], isNot(contains('—')), reason: key);
    }
  });
}
