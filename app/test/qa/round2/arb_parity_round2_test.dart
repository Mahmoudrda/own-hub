// R2-66 (round 2 QA). `test/i18n_guard_test.dart` already asserts perfect key
// parity between the two ARB files ("both ARB files exist and agree on their
// key set": `expect(ek.difference(ak), isEmpty)` both ways). What it does NOT
// assert, and what this file adds:
//
//   (a) every Arabic value is non-empty;
//   (b) every Arabic value differs from its English counterpart, except the
//       fifteen values the product has already decided are genuinely
//       non-translatable (R2-07: csv, unit codes, an endonym, and short
//       alphanumeric mockup ids/tokens that carry no language);
//   (c) every ICU argument name used in the English message is also used in
//       the Arabic message for that key, and vice versa — a mismatch here is
//       a placeholder that silently never gets filled in one language, or a
//       token the ICU parser cannot resolve, which is a render-time throw in
//       exactly one locale and therefore invisible to whichever language a
//       developer happens to be testing in.
//
// This is read-only against the two ARB files. It does not modify them.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The fifteen keys R2-07 says are genuinely non-translatable: unit/format
/// codes, a CSV literal, an Arabic endonym that must not be "translated" into
/// itself a second time, and short mockup ids. Kept as a literal list (not
/// computed) so a new addition to this set has to be argued for here, in
/// writing, exactly like `i18n_guard_test.dart`'s Arabic allowlist.
const Set<String> _knownNonTranslatable = {
  'aa',
  'arabicText_vqu26',
  'csv',
  'n012100',
  'n1',
  'n1210',
  'n20',
  'n23',
  'n38',
  'n48126',
  'n54',
  'n71',
  'n84',
  'n92',
  'nasmCpt',
};

Map<String, dynamic> _load(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Every ICU argument name a message actually uses, whether as a plain
/// placeholder (`{name}`) or as the pluralised/selected variable
/// (`{name, plural, one{…} other{…}}`).
///
/// Deliberately not a full ICU parser. A brace is an argument opener only when
/// the very next non-space character(s) form an identifier (`[a-zA-Z_]\w*`)
/// immediately followed by `,` or `}` (optionally after more spaces). A plural
/// case body such as `one{1 dish is hidden…}` or `other{{count} dishes…}`
/// fails that test at its own opening brace — its content starts with a digit,
/// an Arabic letter, or another `{` — so only genuine argument openers are
/// counted, and a nested placeholder inside a case body (like the `{count}`
/// above) is still found on its own subsequent `{`. This sidesteps the need to
/// track brace depth at all, and it sidesteps Arabic's extra plural categories
/// (zero/two/few/many) entirely, because case-label keywords are never read —
/// only the argument name in front of the first comma is.
final _caseLabel = RegExp(r'^(=\d+|zero|one|two|few|many|other)$');

Set<String> _argNames(String message) {
  final names = <String>{};
  var i = 0;
  while (i < message.length) {
    if (message[i] != '{') {
      i++;
      continue;
    }
    // The token immediately before this `{`, with no space between it and
    // the brace (`one{`, `other{`, `=0{`, …). A brace opening a plural/select
    // CASE BODY is never itself an argument opener, even when the body's
    // entire text happens to look like a bare identifier (`other{x}` reads
    // exactly like the placeholder `{x}` otherwise, and a positive control
    // below is what caught that ambiguity).
    var p = i - 1;
    while (p >= 0 && RegExp(r'[a-zA-Z0-9_=]').hasMatch(message[p])) {
      p--;
    }
    final precedingToken = message.substring(p + 1, i);
    if (_caseLabel.hasMatch(precedingToken)) {
      i++;
      continue;
    }

    var j = i + 1;
    while (j < message.length && message[j] == ' ') {
      j++;
    }
    final start = j;
    while (j < message.length && RegExp(r'[a-zA-Z0-9_]').hasMatch(message[j])) {
      j++;
    }
    final ident = message.substring(start, j);
    final isIdentifier = ident.isNotEmpty && RegExp(r'^[a-zA-Z_]').hasMatch(ident);
    var k = j;
    while (k < message.length && message[k] == ' ') {
      k++;
    }
    final closesHere = k < message.length && (message[k] == ',' || message[k] == '}');
    if (isIdentifier && closesHere) {
      names.add(ident);
    }
    i++; // Re-scan from the very next character either way, so a nested `{`
    // one character after this one (`{{count}`) is never skipped over.
  }
  return names;
}

void main() {
  final en = _load('lib/l10n/app_en.arb');
  final ar = _load('lib/l10n/app_ar.arb');

  final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();
  final arKeys = ar.keys.where((k) => !k.startsWith('@')).toSet();

  test('setup: key parity holds (re-confirming i18n_guard_test.dart\'s own '
      'assertion before building on it)', () {
    expect(enKeys.length, greaterThan(1500));
    expect(enKeys.difference(arKeys), isEmpty);
    expect(arKeys.difference(enKeys), isEmpty);
  });

  test('every Arabic value is non-empty', () {
    final empty = <String>[];
    for (final k in enKeys) {
      final v = ar[k];
      if (v is! String || v.trim().isEmpty) empty.add(k);
    }
    expect(
      empty,
      isEmpty,
      reason: 'Empty Arabic value(s) for key(s): ${empty.join(', ')}',
    );
  });

  test(
    'every Arabic value differs from its English counterpart, except the '
    'fifteen known non-translatables',
    () {
      final identical = <String>[];
      for (final k in enKeys) {
        if (_knownNonTranslatable.contains(k)) continue;
        final e = en[k];
        final a = ar[k];
        if (e is String && a is String && e == a) identical.add(k);
      }
      expect(
        identical,
        isEmpty,
        reason:
            'Arabic value identical to English (untranslated copy-paste) for '
            '${identical.length} key(s): ${identical.join(', ')}',
      );
    },
  );

  test(
    'the fifteen known-non-translatable keys are still exactly the keys that '
    'are identical across locales (the allowlist above does not rot)',
    () {
      // Positive control, matching the idiom `product_rules_test.dart` RULE 7
      // and `i18n_guard_test.dart`'s own allowlist tests use: an exemption
      // list is checked from both directions, not just consulted one way.
      final actuallyIdentical = <String>{
        for (final k in enKeys)
          if (en[k] is String && ar[k] is String && en[k] == ar[k]) k,
      };
      final stale = _knownNonTranslatable.difference(actuallyIdentical);
      final undeclared = actuallyIdentical.difference(_knownNonTranslatable);
      expect(
        stale,
        isEmpty,
        reason:
            'These keys are allowlisted as non-translatable but are NOT '
            'identical in the ARBs any more — remove from the allowlist: $stale',
      );
      expect(
        undeclared,
        isEmpty,
        reason:
            'These keys are identical across locales but are NOT on the known '
            'non-translatable list — either translate them or add them to the '
            'list with a reason: $undeclared',
      );
    },
  );

  test(
    'ICU argument names match between locales for every key (a mismatch '
    'throws at render time in one language only)',
    () {
      final mismatches = <String>[];
      for (final k in enKeys) {
        final e = en[k];
        final a = ar[k];
        if (e is! String || a is! String) continue;
        final enArgs = _argNames(e);
        final arArgs = _argNames(a);
        if (enArgs.difference(arArgs).isNotEmpty ||
            arArgs.difference(enArgs).isNotEmpty) {
          mismatches.add(
            '$k: en=${enArgs.toList()..sort()} ar=${arArgs.toList()..sort()}',
          );
        }
      }
      expect(
        mismatches,
        isEmpty,
        reason:
            '${mismatches.length} placeholder-argument mismatch(es):\n'
            '${mismatches.join('\n')}',
      );
    },
  );

  test(
    'the argument extractor actually bites: a positive control against '
    'synthetic ICU text, proven before being trusted against 2,270 real keys',
    () {
      expect(_argNames('Hello {name}'), {'name'});
      expect(
        _argNames('{count, plural, one{1 dish} other{{count} dishes}}'),
        {'count'},
      );
      expect(_argNames('{from} to {to}'), {'from', 'to'});
      // No false positive on a case body that happens to start with a Latin
      // word followed by more prose rather than a comma or a close-brace.
      expect(
        _argNames('{count, plural, one{About 1 hour in all} other{x}}'),
        {'count'},
      );
      // No false positive on Arabic prose immediately inside a brace.
      expect(_argNames('{count, plural, other{عنصر واحد}}'), {'count'});
      // A genuine mismatch is actually detected.
      expect(_argNames('{phone} رقمك'), isNot(_argNames('رقمك فقط')));
    },
  );
}
