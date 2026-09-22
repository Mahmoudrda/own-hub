// **The unusual test G11 asks for, written the way it asks for it.**
//
// §2.2 — "a coach's message never changes a plan; publishing does" — is
// enforced four ways. Three of them are behavioural and live in
// `plan_update_card_test.dart` and `message_repository_test.dart`. This is the
// fourth, and it is a *source* test: it fails if the string `plans/` or the
// identifier `PlanRepository` appears anywhere in the message repository file
// **or its imports**.
//
// ## Why a source test rather than only a behavioural one
//
// A behavioural test proves that today's `send` does not touch a plan. It
// cannot prove that tomorrow's does not, because tomorrow's might take a
// perfectly reasonable-looking optional parameter and write a perfectly
// reasonable-looking second document. The failure this rule protects against is
// not a bug that would be noticed in review; it is a *convenience* that looks
// like a feature — "while we're sending the message, apply the change too".
//
// Reading the source closes that, because the forbidden capability has to be
// *spelled* somewhere before it can be used, and every spelling of it reaches a
// plan path or a plan repository.
//
// ## Transitive, deliberately
//
// Banning the tokens in one file is trivially defeated by a helper in a second
// file. So this walks the relative imports too, recursively: the file, what it
// imports, what those import. `message_repository.dart` imports
// `package:meta/meta.dart` and nothing else, which is asserted below as its own
// case — a repository that grew a relative import has grown a surface this test
// must then follow, and the assertion makes that visible rather than silent.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _repoPath = 'lib/features/coached/domain/message_repository.dart';

/// Every relative import in [source], resolved against [fromPath].
List<String> _relativeImports(String source, String fromPath) {
  final dir = File(fromPath).parent.path;
  final pattern = RegExp(
    '''^\\s*(?:import|export)\\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );
  final out = <String>[];
  for (final m in pattern.allMatches(source)) {
    final target = m.group(1)!;
    // Package imports are not ours to police, and `package:meta` has no
    // filesystem path here. A `package:own_hub/...` self-import would be, and
    // is caught by the "imports only meta" assertion below.
    if (target.startsWith('package:') || target.startsWith('dart:')) continue;
    out.add(File('$dir/$target').absolute.path);
  }
  return out;
}

/// The file and everything it reaches by relative import.
Set<String> _closureOf(String path) {
  final seen = <String>{};
  final queue = <String>[File(path).absolute.path];

  while (queue.isNotEmpty) {
    final current = queue.removeLast();
    if (!seen.add(current)) continue;
    final file = File(current);
    if (!file.existsSync()) continue;
    queue.addAll(_relativeImports(file.readAsStringSync(), current));
  }
  return seen;
}

void main() {
  late File repo;
  late String source;

  setUpAll(() {
    repo = File(_repoPath);
    expect(
      repo.existsSync(),
      isTrue,
      reason:
          '$_repoPath is the single write path for a message. If it moved, '
          'this guard must move with it — a guard that silently stops finding '
          'its subject is worse than no guard.',
    );
    source = repo.readAsStringSync();
  });

  test('P1-RULE-02B — the string "plans/" appears nowhere in the closure', () {
    final offenders = <String>[];

    for (final path in _closureOf(_repoPath)) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('plans/')) {
          final rel = path.replaceFirst(RegExp(r'^.*?/lib/'), 'lib/');
          offenders.add('$rel:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A message repository that can name a plan path is a message '
          'repository that can write one. Publishing changes a plan; a message '
          'does not.',
    );
  });

  test('P1-RULE-02B — the identifier PlanRepository appears nowhere', () {
    final banned = RegExp(r'\bPlanRepository\b');
    final offenders = <String>[];

    for (final path in _closureOf(_repoPath)) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (banned.hasMatch(lines[i])) {
          final rel = path.replaceFirst(RegExp(r'^.*?/lib/'), 'lib/');
          offenders.add('$rel:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(offenders, isEmpty, reason: 'Sending cannot reach publishing.');
  });

  test('the closure is exactly one file, importing only package:meta', () {
    // The guard above is only as strong as the closure it walks. Keeping the
    // repository dependency-free is what keeps that closure small enough to
    // reason about — and this is the assertion that makes growing it a
    // deliberate act rather than an accident.
    final closure = _closureOf(_repoPath);
    expect(
      closure.length,
      1,
      reason:
          'message_repository.dart grew a relative import. That is allowed, '
          'but the import is now inside the ban above — check it, then update '
          'this expectation deliberately.',
    );

    final imports = RegExp(
      '''^\\s*import\\s+['"]([^'"]+)['"]''',
      multiLine: true,
    ).allMatches(source).map((m) => m.group(1)!).toList();

    expect(imports, ['package:meta/meta.dart']);
  });

  test('send takes exactly two parameters: no overload, no flag', () {
    // The rule's own words: "no overload, no flag and no second parameter that
    // could address a plan". Read off the declaration rather than trusted.
    final decl = RegExp(r'Future<String>\s+send\(([^)]*)\)')
        .allMatches(source)
        .toList();

    expect(
      decl.length,
      2,
      reason:
          'Exactly two declarations of send: the abstract one and the '
          'in-memory implementation. A third is an overload.',
    );

    for (final match in decl) {
      final params = match
          .group(1)!
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      expect(
        params.length,
        2,
        reason: 'send(RelationshipRef, MessageDraft) — and nothing else.',
      );
      expect(
        params.any((p) => p.startsWith('{') || p.startsWith('[')),
        isFalse,
        reason:
            'An optional parameter on send is exactly where "while you are '
            'sending, also apply it" would live.',
      );
      expect(params.first, contains('RelationshipRef'));
      expect(params.last, contains('MessageDraft'));
    }
  });

  test('a message carries no field a plan change could be built from', () {
    // The card is made of published versions. A draft that carried a version,
    // an effective date or a "changed" flag would be a second source for it,
    // and two sources for one card is how a card starts lying.
    final banned = RegExp(
      r'\b(planVersion|effectiveFrom|publishedAt|planChanged|updatesPlan)\b',
    );
    final offenders = <String>[];
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trimLeft();
      if (line.startsWith('//') || line.startsWith('///')) continue;
      if (banned.hasMatch(lines[i])) offenders.add('line ${i + 1}: $line');
    }
    expect(offenders, isEmpty);
  });
}
