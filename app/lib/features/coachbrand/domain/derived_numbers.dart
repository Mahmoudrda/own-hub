/// The figures on a client result, and the fact that a coach cannot type one.
///
/// G13 §1.6.2: *"Numbers are derived, never typed. `deriveResultNumbers` reads
/// `users/{clientUid}/bests/*` and `weeks/*` **with the client's approval inside
/// the consent sheet**, so a coach cannot invent '12 weeks, 20 kg down'."*
///
/// Two separate guarantees, and they fail in different ways:
///
///  1. **No coach call site exists.** [ResultNumbers.derive] takes the client's
///     own bests, not a map a screen could assemble. `ResultsRepository` has no
///     method that accepts numbers at all, so there is nothing for B08 to call.
///  2. **The allowlist excludes weight.** Even the Function cannot derive a
///     body weight, because [DerivableMeasures.allowed] does not contain one and
///     [DerivableMeasures.isDerivable] refuses anything that looks like one.
///
/// ## Lifted load is not body weight
///
/// `squatLoadKg` is on the allowlist and `bodyWeightKg` is not, and the
/// difference is the whole of rule 11. A barbell going from 12 kg to 30 kg is a
/// personal best this product already celebrates — measured against her own
/// history, never against another woman's. A number on a bathroom scale is the
/// thing the product refuses to be about. The dictionary says it in her words:
/// *"Numbers only, never a weight from the scale."*
///
/// ## Why there is also a pattern guard
///
/// A closed allowlist is enough today. It is not enough on the day somebody adds
/// `weightLostKg` to it in a hurry, so [DerivableMeasures.isDerivable] refuses
/// any id matching [DerivableMeasures.forbiddenPattern] **even if it is on the
/// list** — and a test asserts the list and the pattern do not contradict each
/// other. Two halves, neither sufficient, exactly as `ARCHITECTURE.md` §5 puts
/// it for the index exemptions.
library;

import 'package:meta/meta.dart';

/// Thrown when something tries to put a figure on a result that did not come
/// from the client's own logs.
class NumbersNotDerivableError extends Error {
  NumbersNotDerivableError(this.measureId);

  final String measureId;

  @override
  String toString() =>
      'NumbersNotDerivableError($measureId): a result figure is derived from '
      'the client\'s own logged bests, never typed. Weight and weight-lost are '
      'not derivable at all (rule 11 / C7).';
}

/// What may appear as a number on a client result.
abstract final class DerivableMeasures {
  /// The closed set, all of them performance measures from her own logs.
  ///
  /// Every entry answers "what can she do now that she could not do then". None
  /// of them answers "what does she weigh".
  static const Set<String> allowed = <String>{
    'sessionsLogged',
    'countedWeeks',
    'personalBests',
    'plankSec',
    'deadHangSec',
    'wallSitSec',
    'pushUpReps',
    'squatReps',
    'lungeReps',
    'squatLoadKg',
    'deadliftLoadKg',
    'rowLoadKg',
    'pressLoadKg',
    'walkMinutes',
  };

  /// Ids that are refused whatever else says otherwise.
  ///
  /// `weight` catches `weightKg`, `weightLost`, `weightLostKg` and
  /// `startWeight`; `loadKg` measures do not contain it. `bmi`, `fat`, `size`,
  /// `waist`, `hips`, `thigh` and `arm` are her private body measurements —
  /// they live behind A03 and belong on nobody's public page.
  static final RegExp forbiddenPattern = RegExp(
    r'weight|bmi|bodyfat|fat[_a-z]*pct|dresssize|size|waist|hips?|thigh|arm|'
    r'chest|bust|scale|slim|lost',
    caseSensitive: false,
  );

  /// True when [measureId] may be derived onto a result.
  ///
  /// Both halves must agree: on the list **and** not matching the guard.
  static bool isDerivable(String measureId) {
    final id = measureId.replaceAll('_', '');
    if (forbiddenPattern.hasMatch(id)) return false;
    return allowed.contains(measureId);
  }

  /// The ids that would be refused by the guard even if somebody listed them.
  /// Used by the test that proves the two halves do not contradict each other.
  static Iterable<String> get allowedButGuarded =>
      allowed.where((id) => forbiddenPattern.hasMatch(id.replaceAll('_', '')));
}

/// One of her own bests, as G6's `BestsRepository` reports it.
///
/// Read-only here. G13 never writes a best and has no method that could.
@immutable
class ClientBest {
  const ClientBest({
    required this.measureId,
    required this.from,
    required this.to,
    this.unit = '',
  });

  final String measureId;

  /// Where she started and where she is. Both come from her logs.
  final num from;
  final num to;

  /// `s`, `kg`, `reps`, or empty for a bare count.
  final String unit;

  @override
  String toString() => 'ClientBest($measureId $from→$to$unit)';
}

/// A figure that reached a result. Same shape, but it has been through the
/// allowlist, so its existence is the proof.
@immutable
class DerivedNumber {
  const DerivedNumber._({
    required this.measureId,
    required this.from,
    required this.to,
    required this.unit,
  });

  final String measureId;
  final num from;
  final num to;
  final String unit;

  Map<String, Object?> toJson() => <String, Object?>{
    'measureId': measureId,
    'from': from,
    'to': to,
    'unit': unit,
  };

  @override
  String toString() => 'DerivedNumber($measureId $from→$to$unit)';
}

/// The `deriveResultNumbers` Function, as a pure rule.
///
/// The server runs this; the app runs the same code so B08 can show the client
/// exactly what she is agreeing to before she agrees to it. Neither one is a
/// place a coach can reach.
abstract final class ResultNumbers {
  /// Her bests, filtered to what a result may carry.
  ///
  /// Returns an empty map when the client did not grant numbers — [scopeNumbers]
  /// false means the consent sheet's "numbers" switch is off, and an empty map
  /// is the honest rendering of that, not a missing feature.
  ///
  /// Throws [NumbersNotDerivableError] when [strict] and a best is not
  /// derivable, so the Function fails loudly rather than silently dropping a
  /// figure somebody expected. The app path passes `strict: false` and simply
  /// shows fewer rows.
  static Map<String, DerivedNumber> derive({
    required Iterable<ClientBest> bests,
    required bool scopeNumbers,
    bool strict = false,
  }) {
    if (!scopeNumbers) return const <String, DerivedNumber>{};

    final out = <String, DerivedNumber>{};
    for (final best in bests) {
      if (!DerivableMeasures.isDerivable(best.measureId)) {
        if (strict) throw NumbersNotDerivableError(best.measureId);
        continue;
      }
      out[best.measureId] = DerivedNumber._(
        measureId: best.measureId,
        from: best.from,
        to: best.to,
        unit: best.unit,
      );
    }
    return Map.unmodifiable(out);
  }
}
