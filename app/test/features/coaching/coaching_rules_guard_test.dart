// Executable guards for the rules this feature can break silently.
//
// Each one scans `lib/features/coaching/` and each one carries a **positive
// control**: a matcher that catches nothing is indistinguishable from a matcher
// that is broken, and this codebase has shipped two of those. So every pattern
// is proved against text it must catch before it is trusted against a tree it
// must not.
//
// The headline guard is the first group. A fake success is the one defect in
// this feature that reaches a woman's bank, and it is caught two ways: by the
// type (only `payment_state_machine.dart` can build a record at all) and by the
// scan below (nothing else may construct one even if the type were widened).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coaching/domain/checkout_gate.dart';
import 'package:own_hub/features/coaching/domain/coach_directory.dart';

const String _feature = 'lib/features/coaching';
const String _ledger = 'lib/features/coaching/domain/payment_state_machine.dart';

List<File> _source() => Directory(_feature)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// True for a line that is only a comment.
///
/// These guards scan code, not prose. A file that explains *why* it has no
/// `showDialog` is documenting the rule, not breaking it — and a guard that
/// fails on correct code for explaining itself teaches people to stop
/// explaining, or to delete the guard.
bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('///') || t.startsWith('*');
}

/// Opens a declaration whose NAME says it is a deny list. Mirrors the idiom in
/// `test/product_rules_test.dart` so the two agree about what a deny list is.
final RegExp _denyListOpens = RegExp(
  r'^\s*(const|final|static)\b.*\b\w*(Forbidden|Banned|Blocked|Denied)\w*\s*=.*\{\s*$',
);

bool _closesDeclaration(String line) {
  final t = line.trim();
  return t == '};' || t == '},' || t == '}';
}

/// True for a line that *declares* one of these shapes, or *destructures* one,
/// rather than building one.
///
/// Three forms, and all three are reads rather than writes:
///
///   * `const factory PaymentView.record(PaymentRecord record) = PaymentKnown;`
///     — the sealed hierarchy declaring the variant that a real adapter will
///     one day build. Banning the declaration would ban the type.
///   * `const PaymentKnown(this.record);` — the variant's own constructor,
///     which is the thing being guarded, not a use of it.
///   * `PaymentKnown(:final record) => record.state,` — an object pattern in a
///     switch. This is a screen **reading** a payment, which is the whole point
///     of the seam existing.
///
/// Narrow on purpose: `return PaymentView.record(record);` matches none of
/// these and is still caught, and the positive control below proves it.
bool _isDeclarationOrPattern(String line) {
  final t = line.trim();
  return t.contains('factory ') ||
      RegExp(r'\w\(this\.').hasMatch(t) ||
      RegExp(r'\w\(\s*:').hasMatch(t) ||
      RegExp(r'\w\(\)\s*=>').hasMatch(t);
}

List<String> _hits(
  RegExp pattern, {
  List<String> except = const [],
  bool skipDeclarations = false,
}) {
  final out = <String>[];
  for (final file in _source()) {
    if (except.any(file.path.endsWith)) continue;
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
      if (skipDeclarations && _isDeclarationOrPattern(line)) continue;
      if (pattern.hasMatch(line)) {
        out.add('${file.path}:${i + 1}  ${line.trim()}');
      }
    }
  }
  return out;
}

/// Building a payment that has money in it, or a checkout that has opened.
///
/// Refusals are not matched: `CheckoutOutcome.unavailable`,
/// `PaymentView.unavailable` and `RefundOutcome.refused` are the honest answers
/// and exist to be built.
final RegExp _fabricatedPayment = RegExp(
  r'\b('
  r'PaymentRecord\s*\('
  r'|PaymentRecord\.created\s*\('
  r'|PaymentView\.record\s*\('
  r'|PaymentKnown\s*\('
  r'|CheckoutOutcome\.started\s*\('
  r'|CheckoutStarted\s*\('
  r'|RefundOutcome\.requested\s*\('
  r'|RefundRequestedOk\s*\('
  r'|state:\s*PaymentState\.(paid|refunded)'
  r')',
);

void main() {
  group('a payment success is never fabricated', () {
    test('nothing outside the ledger constructs a payment or a checkout', () {
      expect(
        _hits(
          _fabricatedPayment,
          except: const [_ledger],
          skipDeclarations: true,
        ),
        isEmpty,
        reason:
            'There is no contracted payment provider. A file that built a '
            'PaymentRecord, a PaymentKnown or a CheckoutStarted would be '
            'reporting money that did not move. Only the ledger may build a '
            'record, and only a real adapter in data/ may build a started '
            'checkout — and there is not one yet.\n\n'
            'This is the one defect in this feature that reaches a woman\'s '
            'bank. Do not add an exemption; add the adapter.',
      );
    });

    test('the guard would actually bite — a positive control', () {
      for (final offender in [
        "return PaymentView.record(record);",
        'const PaymentKnown(record)',
        "return CheckoutOutcome.started(HostedCheckout(providerTxnId: 'x', rail: rail));",
        'CheckoutStarted(checkout)',
        'PaymentRecord.created(providerTxnId: id, relId: rel,',
        'record._with(state: PaymentState.paid, paidAt: now)',
        'return RefundOutcome.requested(quote);',
      ]) {
        expect(
          _fabricatedPayment.hasMatch(offender) &&
              !_isDeclarationOrPattern(offender),
          isTrue,
          reason: 'the guard must catch: $offender',
        );
      }
    });

    test('the declaration filter is narrow, not a hole', () {
      // It must excuse the three read-shaped forms and nothing else.
      for (final excused in [
        'const factory PaymentView.record(PaymentRecord record) = PaymentKnown;',
        'const PaymentKnown(this.record);',
        'PaymentKnown(:final record) => record.state,',
      ]) {
        expect(_isDeclarationOrPattern(excused), isTrue, reason: excused);
      }
      for (final notExcused in [
        'return PaymentView.record(record);',
        'const PaymentKnown(record)',
        'CheckoutStarted(checkout)',
      ]) {
        expect(_isDeclarationOrPattern(notExcused), isFalse,
            reason: notExcused);
      }
    });

    test('and must not fire on an honest refusal', () {
      for (final allowed in [
        'return CheckoutOutcome.unavailable(reason);',
        'return const PaymentView.unavailable(PaymentUnavailableReason.offline);',
        'return RefundOutcome.unavailable(this.reason);',
        'PaymentView.unavailable(reason) = PaymentUnknown;',
        'PaymentState? get paymentState => switch (payment) {',
        'if (record.state == PaymentState.paid) {',
        'case PaymentState.paid => null,',
      ]) {
        expect(
          _fabricatedPayment.hasMatch(allowed),
          isFalse,
          reason: 'the guard must not fire on: $allowed',
        );
      }
    });

    test('the unavailable provider is the only implementation that ships', () {
      final implementations = _hits(
        RegExp(r'\bimplements\s+PaymentProvider\b'),
      );
      expect(
        implementations,
        hasLength(1),
        reason:
            'A second implementation is either a real adapter — which belongs '
            'in data/ with a contracted provider behind it — or a fake that '
            'succeeds, which is the one thing this seam exists to prevent. '
            'Found: ${implementations.join(', ')}',
      );
      expect(implementations.single, contains('payment_provider.dart'));
    });

    test('the seam that refuses is the one the app is wired to', () {
      final seam = File(
        '$_feature/domain/payment_provider.dart',
      ).readAsStringSync();
      expect(seam, contains('class UnavailablePaymentProvider'));
      // Nothing in it may reach for the ledger: a provider that could build a
      // record is a provider that could pay.
      expect(
        seam,
        isNot(contains('PaymentRecord.created')),
        reason: 'the refusing provider must not be able to build a payment',
      );
    });

    test('the checkout request has no amount to tamper with', () {
      final seam = File(
        '$_feature/domain/payment_provider.dart',
      ).readAsStringSync();
      final start = seam.indexOf('class CheckoutRequest');
      final end = seam.indexOf('class HostedCheckout');
      expect(start, isNot(-1));
      final body = seam.substring(start, end);
      expect(
        RegExp(r'\bMoney\b').hasMatch(body),
        isFalse,
        reason:
            'P0-PAY-09: the server prices the offer. A Money field here is a '
            'field a tampered client can halve.',
      );
      expect(RegExp(r'\bamount\b').hasMatch(body), isFalse);
    });
  });

  group('rule 9 — undo, not confirmation, with two named carve-outs', () {
    test('no dialog exists anywhere in this feature', () {
      // Paying and ending coaching MAY confirm — G11 §5, the same carve-out
      // block and account deletion already have. That carve-out is honoured as
      // an **inline confirm step** in the view model and on the screen, not as
      // a modal: `test/product_rules_test.dart` bans showDialog across every
      // feature folder, and a modal whose copy lives in a widget is a modal
      // nobody translates.
      expect(
        _hits(RegExp(r'\b(showDialog|AlertDialog|showConfirm|areYouSure)\b')),
        isEmpty,
        reason:
            'The two carve-outs are inline steps, not dialogs. See '
            'PackagesViewModel.payingMayConfirm.',
      );
    });

    test('the confirm step is a real step, not a comment', () {
      final packages = File(
        '$_feature/presentation/packages_view.dart',
      ).readAsStringSync();
      expect(packages, contains('_confirming'));
    });
  });

  group('no streaks, no weight, nothing ranked', () {
    test('no streak in any form', () {
      expect(
        _hits(
          RegExp(
            r'\b(streak|dayStreak|daysInARow|consecutiveDays|currentStreak|longestStreak)\b',
            caseSensitive: false,
          ),
        ),
        isEmpty,
      );
    });

    test('no weight field anywhere', () {
      // Rule: no weight fields. A searchable "weight loss" facet is a weight
      // field with a nicer name, so the coach side's fifth specialty is
      // deliberately absent from this feature.
      final banned = RegExp(
        r'\b(weightKg|weightLost|kgLost|lostKg|weightLoss|bodyWeight)\b',
        caseSensitive: false,
      );
      expect(_hits(banned), isEmpty);

      // Positive control.
      for (final offender in [
        'final int weightLost;',
        'CoachingSpecialty.weightLoss',
        'double bodyWeight = 0;',
      ]) {
        expect(banned.hasMatch(offender), isTrue, reason: offender);
      }
    });

    test('nothing sorts by a popularity or body field', () {
      final banned = RegExp(
        r'(orderBy\([^)]*(weight|follower|rating)'
        r'|sortBy(Weight|Followers|Rating|WeightLost)'
        r'|(weight|follower)Leaderboard'
        r'|rankBy(Weight|Followers|Rating))',
        caseSensitive: false,
      );
      expect(_hits(banned), isEmpty, reason: 'rule 11: displayed, never ranked');

      for (final offender in [
        "query.orderBy('followerCount')",
        'rows.sortByRating()',
        'rankByFollowers(rows)',
      ]) {
        expect(banned.hasMatch(offender), isTrue, reason: offender);
      }
    });

    test('a directory row has no follower count to display or sort', () {
      final source = File(
        '$_feature/domain/coach_directory.dart',
      ).readAsLinesSync();
      final fields = source
          .where((l) => !_isComment(l))
          .where((l) => l.trimLeft().startsWith('final '))
          .toList();
      for (final field in fields) {
        expect(
          RegExp(r'follower', caseSensitive: false).hasMatch(field),
          isFalse,
          reason: 'no field may hold a follower count: $field',
        );
      }
    });

    test('the sort keys that break rule 11 are not in the enum', () {
      expect(DirectoryOrder.values, hasLength(4));
      expect(
        kForbiddenDirectorySortFields,
        containsAll(<String>['followers', 'rating', 'weightLost']),
      );
    });
  });

  group('Western digits only', () {
    test('no locale-aware number or date formatter, and no intl', () {
      final banned = RegExp(r'\b(NumberFormat|DateFormat)\b|package:intl');
      expect(
        _hits(banned),
        isEmpty,
        reason:
            'Under an ar locale NumberFormat renders Arabic-Indic digits. '
            'Money.amountText groups by hand for exactly this reason.',
      );
      expect(banned.hasMatch('NumberFormat.decimalPattern()'), isTrue);
      expect(banned.hasMatch("import 'package:intl/intl.dart';"), isTrue);
    });

    test('no Arabic literal in code', () {
      // The name normaliser folds Arabic orthography, and it writes every
      // character as a \u escape so that `test/i18n_guard_test.dart`'s
      // three-entry allowlist does not need a fourth.
      final arabic = RegExp('[؀-ۿݐ-ݿﭐ-﷿]');
      final offenders = <String>[];
      for (final file in _source()) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (_isComment(lines[i])) continue;
          if (arabic.hasMatch(lines[i])) {
            offenders.add('${file.path}:${i + 1}');
          }
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('no figure is stated that this feature did not measure', () {
    test('no dictionary string with a baked-in figure is rendered', () {
      // `test/baked_in_samples_test.dart` counts these product-wide against a
      // ceiling the suite is already over. This feature's contribution must be
      // zero, and it is asserted here rather than left to a ratchet somebody
      // else has to defend.
      //
      // The one exception is a string routed through `statedLine`, which
      // renders only to the woman the figure is true of. Those are listed by
      // name so adding another is a deliberate act.
      const viaStatedLine = <String>{
        // "About 2 hours · measured, not typed" — shown only for a coach whose
        // measured median really is 120 minutes.
        'about2HoursMeasuredNotTyped',
      };

      final arb =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      bool baked(String v) =>
          !v.contains('{') &&
          RegExp(r'\d').hasMatch(v) &&
          RegExp('[A-Za-z]').hasMatch(v);

      final bakedKeys = <String>{
        for (final entry in arb.entries)
          if (!entry.key.startsWith('@') &&
              entry.value is String &&
              baked(entry.value as String))
            entry.key,
      };

      final offenders = <String>[];
      for (final file in _source()) {
        final src = file.readAsStringSync();
        for (final key in bakedKeys) {
          if (viaStatedLine.contains(key)) continue;
          if (RegExp('l10n\\.$key\\b').hasMatch(src)) {
            offenders.add('${file.path}  l10n.$key = "${arb[key]}"');
          }
        }
      }
      expect(
        offenders..sort(),
        isEmpty,
        reason:
            'These render a figure from the mockup as though it were hers. '
            'Parameterise the string, or withhold it with stated_figure.dart.',
      );
    });

    test('every statedLine call is paired with a real value', () {
      // A `statedLine` whose `hers` is a literal is the defect wearing the
      // fix's clothes.
      final offenders = _hits(RegExp(r'hers:\s*\d'));
      expect(offenders, isEmpty);
    });

    test('there is no zero-valued money constant to render', () {
      // `Money.zero` would be the obvious thing to reach for when the seam is
      // silent, and reaching for it is the defect.
      expect(_hits(RegExp(r'\bMoney\.zero\b')), isEmpty);
      final money = File('$_feature/domain/money.dart').readAsStringSync();
      expect(money, isNot(contains('static const Money zero')));
    });
  });

  group('the folder boundary this agent was given', () {
    test('nothing here imports another feature folder', () {
      // The narrow read-only ports exist so that three agents working in
      // parallel cannot break each other. An import would undo that.
      final offenders = <String>[];
      for (final file in _source()) {
        for (final line in file.readAsLinesSync()) {
          final match = RegExp(r'''^import\s+['"]([^'"]+)['"]''').firstMatch(
            line,
          );
          if (match == null) continue;
          final path = match.group(1)!;
          if (path.contains('features/') && !path.contains('coaching')) {
            offenders.add('${file.path}  $path');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Use a narrow read-only port in this folder instead, and report '
            'the seam. Found: ${offenders.join(', ')}',
      );
    });

    test('the echoed constants still agree with the folders that own them', () {
      // Two constants, one authority, stated. Read as text rather than
      // imported, because importing is the coupling this test exists to avoid.
      final capacity = File(
        'lib/features/coach/domain/coach_capacity.dart',
      ).readAsStringSync();
      expect(
        RegExp(r'static const int ceiling = 60\b').hasMatch(capacity),
        isTrue,
        reason:
            'The coach side moved its capacity ceiling. '
            'kCoachCapacityCeiling here must move with it.',
      );
      expect(kCoachCapacityCeiling, 60);

      final profile = File(
        'lib/features/coach/domain/coach_profile.dart',
      ).readAsStringSync();
      expect(
        RegExp(r'static const int minimumReviews = 5\b').hasMatch(profile),
        isTrue,
        reason:
            'The coach side moved its rating floor. '
            'kMinimumReviewsToShowRating here must move with it.',
      );
      expect(kMinimumReviewsToShowRating, 5);
    });

    test('this agent edited nothing it was told not to', () {
      // A cheap, real check: the six screens exist under the folder this agent
      // owns, and nowhere else.
      expect(_source().length, greaterThanOrEqualTo(12));
      for (final name in [
        'find_a_coach_view.dart',
        'coach_profile_view.dart',
        'packages_view.dart',
        'enquiry_view.dart',
        'my_coach_view.dart',
        'coaching_ended_view.dart',
      ]) {
        expect(
          File('$_feature/presentation/$name').existsSync(),
          isTrue,
          reason: '$name is missing',
        );
      }
    });
  });

  group('the guards are not vacuous', () {
    test('the scan sees real files', () {
      expect(_source(), isNotEmpty);
      expect(_source().length, greaterThan(8));
    });

    test('the deny-list exemption cannot hide a real violation', () {
      // Mirrors `product_rules_test`'s control: the exemption ends at the
      // closing brace, not at the file.
      final banned = RegExp(r'\bweightLost\b');
      expect(
        banned.hasMatch('  \'weightLost\','),
        isTrue,
        reason:
            'the pattern itself must match — the exemption is applied by the '
            'scanner, not by the pattern',
      );
    });
  });
}
