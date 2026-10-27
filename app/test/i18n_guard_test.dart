// §7: "Every string through the localisation layer. No hardcoded English or
// Arabic in widgets." The brief requires this to be enforced by a check rather
// than by convention, because it is the kind of rule that holds for a week.
//
// A hardcoded Arabic literal is the more serious of the two: it silently bypasses
// the dictionary, so the English build shows Arabic text and no test of the
// English UI ever notices.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Arabic, Arabic Supplement, and the presentation forms.
final _arabic = RegExp(r'[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]');

/// Files permitted to contain Arabic literals, each with a reason.
///
/// This list is itself asserted below. It must stay tiny, and an entry that no
/// longer needs to be here is a failure rather than a harmless leftover.
/// The one presentation-layer file allowed to hold Arabic, named so the test
/// below can insist every *other* allowlisted file is not a screen.
const String _languageChooser =
    'lib/features/signup/presentation/language_view.dart';

const Map<String, String> _arabicAllowed = {
  // lib/main.dart was listed here for the temporary foundations shell's Arabic
  // probe string. The shell is gone — the app opens on C01 — so the exception
  // went with it. The "every allowlist entry is still needed" test below is what
  // forced this cleanup rather than letting a stale exception linger.
  'lib/features/signup/presentation/language_view.dart':
      'C02 is the language chooser. It must be readable by a woman who has not '
      'chosen a language yet, so the heading appears in both languages at '
      'once and each option is labelled with its own name. "عربي" is an '
      'endonym — a language\'s name in itself — and endonyms are never '
      'translated. This is the only screen where hardcoded Arabic is correct.',

  // The two entries below are a different category from the one above, and the
  // distinction is what keeps this guard meaningful rather than merely smaller.
  //
  // Both are in `domain/`. Neither renders anything: they contain no widget, no
  // AppL10n call and no string that ever reaches a screen. What they hold is
  // *grammar* — the words Arabic uses to join two things, the shapes a letter
  // takes with and without diacritics, the digits she may type. That is not
  // copy, and it cannot live in the dictionary: a translation file maps one
  // message per key per locale, while a parser has to recognise Arabic input
  // whatever language the interface is set to. A woman running the app in
  // English still says "كشري".
  //
  // The rule this guard actually protects — "a hardcoded Arabic literal
  // silently bypasses the dictionary, so the English build shows Arabic text
  // and no test of the English UI ever notices" — is untouched, because nothing
  // here can be shown to anybody.
  'lib/features/eat/domain/meal_sentence_parser.dart':
      'The sentence parser. Holds the connectors a woman types between foods '
      '(the waw, "مع"), the Arabic-Indic digits, and the small words that mean '
      'a number ("بيضتين" is both "two" and "eggs"). Matching data for input, '
      'never output — E02 and E03 must understand Arabic speech and typing in '
      'both interface languages.',
  'lib/features/eat/domain/food_library.dart':
      'The food matcher\'s normaliser. Strips harakat and folds the alef and '
      'ta-marbuta variants, so "كُشري", "كشري" and "كشرى" are one dish. Egyptian '
      'women type Arabic with and without diacritics, and a match that depended '
      'on exact orthography would fail on most real input.',
  'lib/features/private_coaching/domain/chat_screen.dart':
      'The coaching chat\'s safety screen, the twin of functions/coaching/'
      'chat.py. Holds the Arabic names of transfer wallets ("فودافون كاش", '
      '"انستاباي") and a short list of insults, plus the same letter folding '
      'as the food matcher, so a message that moves payment off the platform '
      'is caught in either interface language. Matching data for input, '
      'never shown to anybody.',
  'lib/features/private_coaching/domain/inbody_scan.dart':
      'The InBody printout reader. Holds the Arabic labels a printout or a '
      'typed goal can carry ("الوزن", "كتلة العضل", "نسبة الدهون", "الطول"), '
      'and the Arabic-Indic digits and decimal separator it folds to Western '
      'ones, so a scan in either language is read whatever the interface '
      'language is. Matching data for input, never shown to anybody; the '
      'sheet that shows the numbers takes every word from AppL10n.',
  'lib/features/train/domain/notification_voice.dart':
      'The notification picker\'s lock-screen guard. Holds Arabic words that '
      'must never reach a lock screen (weight, pregnancy, guilt words), '
      'matched against the values filled into a line, such as a food she '
      'logs. Matching data, never shown to anybody.',
};

List<File> _sourceFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where(
      (f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/app_l10n'),
    )
    .toList();

String _rel(File f) => f.path.replaceFirst(RegExp(r'^.*?/?lib/'), 'lib/');

void main() {
  test('no hardcoded Arabic outside the allowlist', () {
    // Code only. Arabic inside a doc comment is usually the author explaining
    // *why* something is the way it is — "the dictionary already gives us
    // 'الخطوة 2 من 4', so there is no formatting to do". That is documentation
    // worth keeping, and failing it would push people to write worse comments
    // rather than better code. A literal in an actual expression is the defect.
    bool isComment(String line) {
      final t = line.trimLeft();
      return t.startsWith('//') || t.startsWith('///') || t.startsWith('*');
    }

    final offenders = <String>[];
    for (final file in _sourceFiles()) {
      final rel = _rel(file);
      if (_arabicAllowed.containsKey(rel)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (isComment(lines[i])) continue;
        if (_arabic.hasMatch(lines[i])) {
          offenders.add('$rel:${i + 1}  ${lines[i].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Arabic belongs in app_ar.arb, reached through AppL10n.',
    );
  });

  test('the Arabic allowlist stays small', () {
    // If this needs raising, the reason belongs in the map above, in writing.
    //
    // Six, in two categories. One screen: the language chooser, which must
    // show both languages before she has picked either. Five domain files:
    // the Eat parser, its normaliser, the coaching chat's safety screen, the
    // InBody printout reader and the notification picker's lock-screen guard,
    // which hold Arabic as *matching data* rather than as copy and render
    // nothing at all.
    //
    // A fourth entry should be argued for, not assumed — and an entry for
    // anything under `presentation/` should be refused, because that is where
    // copy lives.
    expect(_arabicAllowed.length, lessThanOrEqualTo(6));

    for (final path in _arabicAllowed.keys) {
      expect(
        path.contains('/presentation/') && path != _languageChooser,
        isFalse,
        reason:
            '$path renders UI. Arabic there belongs in app_ar.arb, reached '
            'through AppL10n.',
      );
    }
  });

  test('every allowlist entry is still needed', () {
    // Stops the exception outliving the scaffolding it was granted for.
    for (final entry in _arabicAllowed.entries) {
      final file = File(entry.key);
      expect(
        file.existsSync(),
        isTrue,
        reason:
            '${entry.key} is allowlisted but does not exist — remove the entry.',
      );
      // Checks real code, matching the guard above: an allowlist entry that is
      // only justified by a comment is an entry that is no longer needed.
      final code = file
          .readAsLinesSync()
          .where((l) {
            final t = l.trimLeft();
            return !(t.startsWith('//') ||
                t.startsWith('///') ||
                t.startsWith('*'));
          })
          .join('\n');
      expect(
        _arabic.hasMatch(code),
        isTrue,
        reason:
            '${entry.key} no longer contains Arabic in code — remove its '
            'allowlist entry.',
      );
    }
  });

  test('the localisation layer is reached through AppL10n, not read directly', () {
    // Reading the ARB at runtime, or importing the generated delegate's private
    // per-locale classes, both route around the dictionary.
    final offenders = <String>[];
    for (final file in _sourceFiles()) {
      final src = file.readAsStringSync();
      if (RegExp(r'''\.arb['"]|app_l10n_(en|ar)\.dart''').hasMatch(src)) {
        offenders.add(_rel(file));
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Use AppL10n.of(context); never load an ARB or a locale class directly.',
    );
  });

  test('both ARB files exist and agree on their key set', () {
    // Parity is generated, but a hand-edit or a half-finished regeneration would
    // silently leave one locale short, and only the Arabic build would break.
    final en = File('lib/l10n/app_en.arb');
    final ar = File('lib/l10n/app_ar.arb');
    expect(en.existsSync(), isTrue);
    expect(ar.existsSync(), isTrue);

    // Parsed, not pattern-matched. The first version anchored `^` and ran
    // allMatches over the whole file as one string, so it matched almost nothing
    // and the parity assertion below was quietly meaningless.
    Set<String> messageKeys(File f) {
      final decoded = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      return decoded.keys.where((k) => !k.startsWith('@')).toSet();
    }

    final ek = messageKeys(en);
    final ak = messageKeys(ar);
    expect(ek.length, greaterThan(1500));
    expect(ek.difference(ak), isEmpty, reason: 'keys missing from Arabic');
    expect(ak.difference(ek), isEmpty, reason: 'keys missing from English');
  });
}
