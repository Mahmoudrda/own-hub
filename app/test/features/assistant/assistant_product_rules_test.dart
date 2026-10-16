// The guards that are enforced in the dictionary and the source tree rather
// than in review: P0-ASK-13 (the key never ships), P0-ASK-18 (the word "AI" is
// absent), P1-RULE-10B (there is deliberately no publish tool), and G15 D1
// (the assistant writes nothing, anywhere).
//
// Each of these is a rule that holds for about a week when it is a convention.
// `product_rules_test.dart` establishes the source-scanning idiom, including the
// two lessons this file inherits: comments are skipped, because a file that
// documents its own rule is obeying it rather than breaking it; and every
// pattern is proved against text that MUST match before it is trusted against a
// tree that must not — a guard that matches nothing is indistinguishable from
// one whose regex is broken.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The assistant's own source. Scanned as a unit, because these rules are
/// properties of the feature rather than of any one file.
List<File> _assistantSource() =>
    Directory('lib/features/assistant')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

List<File> _allLibSource() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where(
      (f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/app_l10n'),
    )
    .toList();

bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('///') || t.startsWith('*');
}

/// `path:line` for every non-comment line matching [pattern].
List<String> _hits(List<File> files, RegExp pattern) {
  final out = <String>[];
  for (final file in files) {
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

/// Key shapes that must never appear in a shipped binary.
///
/// Named `kForbidden…` so `product_rules_test.dart`'s deny-list exemption reads
/// this as enforcement rather than as a violation.
final RegExp kForbiddenKeyShapes = RegExp(
  r'(sk-ant-[A-Za-z0-9_\-]{8,}'
  r'|AIza[0-9A-Za-z_\-]{30,}'
  r'|sk-[A-Za-z0-9]{32,}'
  r'|AKIA[0-9A-Z]{16}'
  r'|ya29\.[A-Za-z0-9_\-]{20,})',
);

/// Vendor endpoints the app must never call directly. Every model call
/// originates from a Cloud Function.
final RegExp kForbiddenVendorEndpoints = RegExp(
  r'(api\.anthropic\.com'
  r'|generativelanguage\.googleapis\.com'
  r'|aiplatform\.googleapis\.com'
  r'|api\.openai\.com)',
  caseSensitive: false,
);

/// Shapes that would mean the assistant had acquired a way to write.
///
/// `.add(` is deliberately absent: a list append is not a Firestore write, and
/// a guard that fired on one would be deleted within a week.
final RegExp kBannedWriteShapes = RegExp(
  r'(FirebaseFirestore|CollectionReference|DocumentReference|WriteBatch'
  r'|FieldValue|SetOptions'
  r'|Repository\s+\w+\s*;'
  r'|\.(set|update|delete)\()',
);

/// Names that would mean a key had been given somewhere to live.
final RegExp kBannedKeyHolders = RegExp(
  r'\b(apiKey|api_key|ANTHROPIC_API_KEY|GEMINI_API_KEY|GOOGLE_API_KEY|'
  r'secretKey|bearerToken|authToken)\b',
);

void main() {
  group('P0-ASK-13 — the API key never ships in the app', () {
    test('no key-shaped literal exists anywhere in lib/', () {
      // One exemption, and it is as narrow as it can be written: the `apiKey:`
      // lines of the FlutterFire generated `lib/firebase_options.dart`.
      //
      // A Firebase apiKey is not a secret. It is a public project identifier
      // that ships inside every Android and iOS binary by design, it
      // authorises nothing on its own, and what actually protects the data is
      // `firebase/firestore.rules`. The sentence in the reason below is still
      // exactly right about it: an APK is a zip and anything in it is public.
      // That is the argument FOR letting this one through, not against.
      //
      // The exemption is a line test rather than a file test on purpose. A
      // Gemini key is also `AIza...` and is indistinguishable by shape from
      // the Firebase one, so exempting the whole file would create a hole the
      // exact size of the key this rule exists to keep out. `sk-ant-`, `sk-`,
      // `AKIA` and `ya29.` still fail in this file like anywhere else, and the
      // pairing test below proves the hole stays closed.
      final offenders = _hits(_allLibSource(), kForbiddenKeyShapes).where((
        hit,
      ) {
        if (!hit.contains('lib/firebase_options.dart')) return true;
        if (!RegExp(r'\bapiKey\s*:').hasMatch(hit)) return true;
        return !RegExp(r'^[^:]*:\d+\s+apiKey:\s*.AIza[0-9A-Za-z_\-]{30,}.,?$')
            .hasMatch(hit.trim());
      }).toList();

      expect(
        offenders,
        isEmpty,
        reason:
            'An APK is a zip: anything in it is public. All model calls '
            'originate from the Cloud Function, and the key is a Secret '
            'Manager secret bound to it.',
      );
    });

    test('the firebase_options exemption cannot hide a model key', () {
      // Without this, the exemption above is a hole shaped like a Gemini key:
      // paste one onto an `apiKey:` line in the generated file and no guard
      // looks at it again. Same pairing idiom as the deny-list exemption in
      // `product_rules_test.dart`.
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
            'The exempted path must be the FlutterFire generated file. If '
            'it is something else, the exemption is being reused for a file it '
            'was never reasoned about.',
      );

      // Every Google-shaped key in the file sits on an `apiKey:` line, and no
      // other vendor shape appears at all. A model key would arrive on some
      // other field, in a bare constant, or with a different prefix, and each
      // of those is caught here.
      final lines = source.split('\n');
      final misplaced = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (_isComment(line)) continue;
        if (!kForbiddenKeyShapes.hasMatch(line)) continue;
        if (RegExp(r'\bapiKey\s*:\s*.AIza').hasMatch(line)) continue;
        misplaced.add('lib/firebase_options.dart:${i + 1}  ${line.trim()}');
      }
      expect(
        misplaced,
        isEmpty,
        reason:
            'A key-shaped literal in the generated file that is not the '
            'Firebase apiKey field is not covered by the reasoning for this '
            'exemption.',
      );
    });

    test('nothing in lib/ calls a model vendor directly', () {
      expect(
        _hits(_allLibSource(), kForbiddenVendorEndpoints),
        isEmpty,
        reason: 'FAILS if a direct vendor endpoint exists in the app',
      );
    });

    test('the assistant has nowhere to put a key', () {
      expect(
        _hits(_assistantSource(), kBannedKeyHolders),
        isEmpty,
        reason:
            'the seam takes no key: a provider that needs one is a provider '
            'talking to a vendor from a handset',
      );
    });

    test('the assistant opens no socket and imports no HTTP client', () {
      expect(
        _hits(
          _assistantSource(),
          RegExp(
            r'''import\s+'dart:io'|package:http/|HttpClient\(|'''
            r'''package:dio/|package:firebase_functions''',
          ),
        ),
        isEmpty,
        reason: 'no HTTP client, no package: the seam is one class from data/',
      );
    });

    test('the guards would actually bite', () {
      // Positive controls. A source-scanning guard that matches nothing is
      // indistinguishable from one whose regex is broken.
      for (final offender in [
        'const k = "sk-ant-api03-abcdefghij";',
        'const k = "AIzaSyD-abcdefghijklmnopqrstuvwxyz012345";',
      ]) {
        expect(
          kForbiddenKeyShapes.hasMatch(offender),
          isTrue,
          reason: 'must catch: $offender',
        );
      }
      expect(
        kForbiddenVendorEndpoints.hasMatch(
          "Uri.parse('https://api.anthropic.com/v1/messages')",
        ),
        isTrue,
      );
      expect(
        kForbiddenVendorEndpoints.hasMatch(
          "Uri.parse('https://generativelanguage.googleapis.com/v1beta/models')",
        ),
        isTrue,
      );
      expect(kBannedKeyHolders.hasMatch('final String apiKey;'), isTrue);

      // And must NOT fire on what the feature legitimately contains.
      expect(kForbiddenKeyShapes.hasMatch('final String answerKey;'), isFalse);
      expect(kBannedKeyHolders.hasMatch('final AnswerKey answerKey;'), isFalse);
    });
  });

  group('P0-ASK-18 — the word "AI" never appears on screen', () {
    // Enforced over the dictionary, not by review. Both locales, because a
    // hardcoded Arabic equivalent would never be seen by a test of the English
    // UI. The feature is called "the assistant" everywhere.
    final banned = <String, RegExp>{
      'the standalone token AI': RegExp(r'\bAI\b'),
      'A.I.': RegExp(r'A\.\s*I\.'),
      'ذكاء اصطناعي': RegExp('ذكاء اصطناعي'),
      'الذكاء الاصطناعي': RegExp('الذكاء الاصطناعي'),
    };

    for (final locale in ['en', 'ar']) {
      test('app_$locale.arb contains no reference to it', () {
        final dictionary = jsonDecode(
          File('lib/l10n/app_$locale.arb').readAsStringSync(),
        ) as Map<String, dynamic>;

        final offenders = <String>[];
        dictionary.forEach((key, value) {
          if (key.startsWith('@') || value is! String) return;
          for (final entry in banned.entries) {
            if (entry.value.hasMatch(value)) {
              offenders.add('$key = "$value"  (${entry.key})');
            }
          }
        });

        expect(
          offenders,
          isEmpty,
          reason: 'Do not call anything AI until it has shipped.',
        );
      });
    }

    test('no answer template in the feature names it either', () {
      final offenders = _hits(_assistantSource(), RegExp(r'\bAI\b'));
      expect(offenders, isEmpty);
    });

    test('the guard would actually bite', () {
      expect(banned['the standalone token AI']!.hasMatch('Ask the AI'), isTrue);
      expect(banned['A.I.']!.hasMatch('our A.I. assistant'), isTrue);
      expect(banned['ذكاء اصطناعي']!.hasMatch('مساعد ذكاء اصطناعي'), isTrue);
      // And must not fire on ordinary words that merely contain the letters.
      for (final innocent in [
        'Ask Sara instead',
        'It is available again',
        'a chair',
        'said',
      ]) {
        expect(
          banned['the standalone token AI']!.hasMatch(innocent),
          isFalse,
          reason: 'must not fire on: $innocent',
        );
      }
    });
  });

  group('P1-RULE-10B — there is deliberately no publish tool', () {
    test('nothing in the assistant publishes', () {
      expect(
        _hits(
          _assistantSource(),
          RegExp(
            r'\b(publish|publisher|publishStartingPlan)\w*\s*\(',
            caseSensitive: false,
          ),
        ),
        isEmpty,
        reason:
            'Publishing stays a human act. A prompt injection that says '
            '"publish it" reaches an endpoint that does not exist.',
      );
    });

    test('no import path reaches a publisher or a plan writer', () {
      expect(
        _hits(
          _assistantSource(),
          RegExp(
            r'''import\s+.*(plan_publisher|portfolio_publisher|'''
            r'''post_publish_service|plan_draft_service)''',
          ),
        ),
        isEmpty,
      );
    });
  });

  group('G15 D1 — the assistant writes nothing, anywhere', () {
    test('it holds no repository and no write call', () {
      // The owning group's service performs the write after the author taps.
      // There is no server path from a model token to a published plan.
      expect(
        _hits(_assistantSource(), kBannedWriteShapes),
        isEmpty,
        reason: 'G15 D1: it returns a validated payload and writes nothing',
      );
    });

    test('the guard would actually bite', () {
      // The first version of this pattern wrapped the whole alternation in
      // `\b…\b`. The trailing boundary can never match after a `;`, so the
      // `Repository name;` arm — the most likely real violation — silently
      // matched nothing. Caught by this control, which is why it exists.
      for (final offender in [
        '  final MealRepository repository;',
        '  await doc.set({});',
        '  FieldValue.increment(1);',
        '  final db = FirebaseFirestore.instance;',
      ]) {
        expect(
          kBannedWriteShapes.hasMatch(offender),
          isTrue,
          reason: 'must catch: $offender',
        );
      }

      // And must not fire on what the feature legitimately contains.
      for (final allowed in [
        '  final AssistantPack pack;',
        '  final List<AssistantPick> picks;',
        '  out.add(move);',
      ]) {
        expect(
          kBannedWriteShapes.hasMatch(allowed),
          isFalse,
          reason: 'must not fire on: $allowed',
        );
      }
    });
  });

  group('the feature ships dark, and the seam is honest', () {
    test('no working provider or classifier exists in lib/', () {
      // The only implementations are the ones that refuse. A fake that WORKS
      // must not exist in the shipped tree, or it will be mistaken for a model.
      final source = _assistantSource()
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(source, contains('class UnavailableAssistantProvider'));
      expect(source, contains('class UnavailableSafetyClassifier'));
      expect(
        RegExp(r'class \w*(Fake|Stub|Mock)\w*(Provider|Classifier)')
            .hasMatch(source),
        isFalse,
        reason: 'no fake that works may ship in lib/',
      );
    });
  });
}
