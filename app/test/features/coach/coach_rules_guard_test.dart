// Executable guards over this feature's own source, for the four rules whose
// whole value is that they cannot be broken quietly.
//
// The idiom is `product_rules_test.dart`'s: scan lines, skip comments, and prove
// each pattern bites before trusting it against a tree that must not match. A
// guard that matches nothing is indistinguishable from one whose regex is
// broken, and this repository has already shipped one of those.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

const String _feature = 'lib/features/coach';
const String _paymentsSeam = 'lib/features/coach/domain/payments.dart';

List<File> _coachSource() =>
    Directory(_feature)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('///') || t.startsWith('*');
}

/// `path:line` for every non-comment line matching [pattern], skipping any file
/// whose path contains one of [except].
List<String> _hits(RegExp pattern, {List<String> except = const []}) {
  final out = <String>[];
  for (final file in _coachSource()) {
    if (except.any(file.path.contains)) continue;
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

/// Constructing a successful money outcome, or a statement of earnings.
///
/// Refusals are not matched: [CaptureUnavailable], [EarningsUnavailable] and
/// friends are the honest answers and exist to be built.
final RegExp _fabricatedMoney = RegExp(
  r'\b('
  r'Captured\s*\('
  r'|CaptureOutcome\.captured\s*\('
  r'|EarningsStatement\s*\('
  r'|EarningsState\.statement\s*\('
  r'|VoidOutcome\.voided\s*\('
  r'|PayoutMethodState\.set\s*\('
  r'|PayoutMethodSet\s*\('
  r')',
);

void main() {
  group('money is never fabricated', () {
    test('nothing outside the seam constructs a successful money outcome', () {
      expect(
        _hits(_fabricatedMoney, except: const [_paymentsSeam]),
        isEmpty,
        reason:
            'There is no payment provider (G12 §9 Q7). A file that built a '
            'Captured, an EarningsStatement or a set PayoutMethod would be '
            'reporting money that did not move. Only the provider adapter may '
            'construct these, and there is not one yet.',
      );
    });

    test('the guard would actually bite — a positive control', () {
      for (final offender in [
        "return CaptureOutcome.captured(receiptId: 'r', at: now);",
        'const Captured(receiptId: "r", at: now)',
        "EarningsStatement(monthKey: '2026-09', grossPiastres: 0,",
        'return PayoutMethodState.set(destination);',
      ]) {
        expect(
          _fabricatedMoney.hasMatch(offender),
          isTrue,
          reason: 'the guard must catch: $offender',
        );
      }
    });

    test('and must not fire on an honest refusal', () {
      for (final allowed in [
        'return EarningsState.unavailable(reason);',
        'return CaptureOutcome.unavailable(reason);',
        'if (!capture.didCapture) return refused;',
        'final destination = payout is PayoutMethodSet ? payout.destination : null;',
        'if (current is PayoutMethodSet) _kind = current.destination.kind;',
      ]) {
        expect(
          _fabricatedMoney.hasMatch(allowed),
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
    });
  });

  group('K04 is the single writer of offers', () {
    test('no screen can reach an OfferWriter', () {
      final offenders = _hits(RegExp(r'\bOfferWriter\b'))
          .where((h) => h.contains('/presentation/'))
          .toList();

      expect(
        offenders,
        isEmpty,
        reason:
            'Every screen is handed an OfferReader. A presentation file that '
            'named OfferWriter would be a second write path, and G12 §9 Q5 '
            'records what that costs: a price edited in one place and stale in '
            'the other, on the screen that takes money. Found: '
            '${offenders.join(', ')}',
      );
    });

    test('the write path is named, and there is one of it', () {
      final editors = _hits(RegExp(r'^class PackagesEditor\b'));
      expect(editors, hasLength(1));
    });

    test('the guard would bite on a screen that reached for one', () {
      expect(
        RegExp(r'\bOfferWriter\b').hasMatch('final OfferWriter writer;'),
        isTrue,
      );
      expect(
        RegExp(r'\bOfferWriter\b').hasMatch('final OfferReader reader;'),
        isFalse,
      );
    });
  });

  group('a coach session never reaches a client document', () {
    test('no path to users/{clientUid} exists in this feature', () {
      final offenders = _hits(RegExp(r'''users/|\bforClient\s*\('''));
      expect(
        offenders,
        isEmpty,
        reason:
            'HANDOFF 6 and spine C12. Everything about a client is read from '
            'relationships/{relId}/clientView, and the rules deny the rest. A '
            'path here would be code the rules exist to stop. Found: '
            '${offenders.join(', ')}',
      );
    });

    test('the guard would bite', () {
      final pattern = RegExp(r'''users/|\bforClient\s*\(''');
      expect(pattern.hasMatch("final doc = 'users/\$clientUid';"), isTrue);
      expect(pattern.hasMatch('Future<X> forClient(String uid);'), isTrue);
      expect(
        pattern.hasMatch('Future<ClientView> forRelationship(String relId);'),
        isFalse,
      );
    });
  });

  group('rule 2 — chat has no route to a plan', () {
    test('nothing in this feature names a plan writer', () {
      final offenders = _hits(
        RegExp(
          r'\b(PlanPublisher|PlanRepository|publishPlan|applyToPlan)\s*[(<.]',
        ),
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'CoachChatService has no constructor dependency on any plan '
            'repository, and this proves nothing else in the feature grew one. '
            'Found: ${offenders.join(', ')}',
      );
    });

    test('the guard would bite', () {
      expect(
        RegExp(
          r'\b(PlanPublisher|PlanRepository|publishPlan|applyToPlan)\s*[(<.]',
        ).hasMatch('final PlanPublisher publisher;'),
        isFalse,
        reason:
            'a field declaration has no paren — the call form is what '
            'matters, and the next control covers the type form',
      );
      expect(
        RegExp(r'\bPlanPublisher\b').hasMatch('final PlanPublisher publisher;'),
        isTrue,
      );
    });

    test('no plan type is even declared as a dependency', () {
      final offenders = _hits(RegExp(r'\b(PlanPublisher|PlanRepository)\b'));
      expect(offenders, isEmpty);
    });
  });

  group('Western digits only', () {
    test('nothing in this feature reaches for NumberFormat or intl', () {
      final offenders = _hits(
        RegExp(r'\bNumberFormat\b|\bDateFormat\b|package:intl'),
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'P0-A11Y-01 requires Western numerals in Arabic, and intl switches '
            'to Eastern digits under an Arabic locale. Counts go through '
            'countLabel. Found: ${offenders.join(', ')}',
      );
    });
  });

  group('P1-RULE-13 — K24 is a state, not a route', () {
    test('it is a first-run state and not a destination', () {
      expect(firstRunStates, contains('K24'));
      expect(appDestinations.containsKey('K24'), isFalse);
      expect(screenIdForRoute(appRoutes['K24']!.name), isNull);
    });

    test('nothing in this feature navigates to it', () {
      final offenders = _hits(RegExp(r"""goToScreen\(\s*context,\s*'K24'"""));
      expect(
        offenders,
        isEmpty,
        reason:
            'Accepting a first client flips the K07 route from one branch to '
            'the other. A push to K24 would render "Today, empty" over a Today '
            'that is not. Found: ${offenders.join(', ')}',
      );
    });

    test('the guard would bite on a push to a day-one destination', () {
      final pattern = RegExp(r"""goToScreen\(\s*context,\s*'K24'""");
      expect(
        pattern.hasMatch("goToScreen(context, 'K24', onSeeToday)"),
        isTrue,
      );
      expect(
        pattern.hasMatch("goToScreen(context, 'K07', onSeeToday)"),
        isFalse,
      );
    });

    test('B14 and W11 are not navigated to either', () {
      // The other two coach-side first-run states. K24's neighbours in
      // `firstRunStates`, and the same rule applies to them.
      for (final id in ['B14', 'W11']) {
        expect(firstRunStates, contains(id));
        expect(
          _hits(RegExp("""goToScreen\\(\\s*context,\\s*'$id'""")),
          isEmpty,
          reason: '$id is a state of another screen, not a destination',
        );
      }
    });
  });

  test('the scanner is looking at a real tree', () {
    // The vacuous-guard control. Every check above is an assertion that
    // something is ABSENT, and all of them pass trivially against an empty
    // file list.
    final files = _coachSource();
    expect(files.length, greaterThan(15));
    expect(
      files.any((f) => f.path.endsWith('payments.dart')),
      isTrue,
      reason:
          'the seam must be in the scanned set for its exemption to mean '
          'anything',
    );
  });
}
