// A test that depends on a flag must pin that flag itself.
//
// `FeatureFlags.shipped` is not a constant of nature. It is the owner's
// current switch positions, and it moves. When Phase 3 was switched on, 34
// tests failed at once — not one of them because it was wrong about the
// product, but because each had borrowed its precondition from the defaults
// instead of stating it. A case named "no Reel chip while communityVideo is
// off" that never switches communityVideo off is not testing the chip; it is
// testing today's defaults, and it breaks the day they move.
//
// Hence this guard: a test file may not *read* the shipped defaults unless the
// defaults are what it is about. Everywhere else the world under test is built
// from `FeatureFlags.allOff`, with only the switches that case needs turned on
// by name. Comments are stripped before the check, so a file may explain the
// rule — as several now do — without being accused of breaking it.
//
// The stronger check the same rule suggests — flip a switch in the defaults
// and prove no suite moves — cannot be written here: the defaults are a
// compile-time constant, so nothing at runtime can flip them. Reading the
// sources is the enforceable form of it.
//
// One gap this cannot close: a factory whose `flags` parameter defaults to the
// shipped value is read by every caller that omits it, and omitting it leaves
// no text to find. That is why the fix for those was to pass the flags, not to
// rely on a check catching them later.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The text a test file may not contain outside its comments.
///
/// Written as two adjacent literals so that this file, which has to name it,
/// does not match itself.
const String _needle = 'FeatureFlags.' 'shipped';

/// Files permitted to read the shipped defaults, each with a reason.
///
/// An entry here is a file whose *subject* is the defaults themselves rather
/// than a screen or a rule that happens to sit behind a flag. The list is
/// asserted below: an entry that is no longer needed is a failure rather than
/// a harmless leftover.
const Map<String, String> _mayReadTheDefaults = <String, String>{
  'test/release_readiness_test.dart':
      'Its subject is the build that goes to the stores, so the shipped set is '
      'the thing under test: that the first release opens on Home, that the '
      'community and the coach side are dark, and that no testing aid is '
      'reachable. Every other group in that file sets its own flags.',
  'test/domain/flags/feature_flags_test.dart':
      'Its first group asserts which features the owner has switched on. That '
      'group is the one place where the defaults are the subject rather than '
      'the setting; every other group there builds its own world.',
  'test/routing/feature_gating_test.dart':
      '"the shipped defaults match what is actually finished" is about which '
      'flows the defaults leave reachable. The deep-link tests below it set '
      'their own flags.',
  'test/features/assistant/assistant_service_test.dart':
      '"the assistant ships dark" records the default position of the kill '
      'switch. Every behavioural case in that file pins its own flags.',
  'test/features/coaching/checkout_gate_test.dart':
      '"this flow ships dark" records the default position of the '
      'marketplace. Every refusal tested around it pins its own flags.',
  'test/routing/verification_gate_test.dart':
      'One test there — "the flag is off in the shipped defaults, and that is '
      'deliberate" — has the default position of `accountRequired` as its '
      'subject. That flag is now the whole-app gate, and it is switched off '
      'because the verification functions are not deployed: turning it on '
      'first would lock out every user, silently. Every other group in that '
      'file builds its own world.',
  'test/navigation_smoke_test.dart':
      'It pushes every destination through the real router as the app '
      'actually ships, so the defaults are the point of the walk rather than '
      'an inherited convenience.',
};

List<File> _testFiles() => Directory('test')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

String _rel(File f) => f.path.replaceFirst(RegExp(r'^.*?/?test/'), 'test/');

/// [source] with its comments removed.
///
/// A trailing comment is only stripped when nothing on the line before it
/// looks like a string, so a `//` inside a URL is left alone.
String _code(String source) {
  final out = StringBuffer();
  for (final line in source.split('\n')) {
    if (line.trimLeft().startsWith('//')) continue;
    final at = line.indexOf('//');
    final before = at < 0 ? '' : line.substring(0, at);
    out.writeln(
      at >= 0 && !before.contains("'") && !before.contains('"') ? before : line,
    );
  }
  return out.toString();
}

bool _reads(File file) => _code(file.readAsStringSync()).contains(_needle);

void main() {
  test('a flag-dependent test states the flags it needs', () {
    final offenders = <String>[];
    for (final file in _testFiles()) {
      final path = _rel(file);
      if (_mayReadTheDefaults.containsKey(path)) continue;
      if (_reads(file)) offenders.add(path);
    }
    offenders.sort();

    expect(
      offenders,
      isEmpty,
      reason:
          'These files read the shipped defaults. Build the world under test '
          'from FeatureFlags.allOff and switch on only what the case needs, '
          'so the assertion survives the next time a default moves:\n  '
          '${offenders.join('\n  ')}',
    );
  });

  test('every file allowed to read the defaults still reads them', () {
    for (final entry in _mayReadTheDefaults.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} is gone');
      expect(
        _reads(file),
        isTrue,
        reason:
            '${entry.key} no longer reads the defaults, so its exception is '
            'stale. Delete the entry rather than leaving it to cover a file '
            'that could start reading them again unnoticed.',
      );
    }
  });
}
