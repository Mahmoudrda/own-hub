/// Where splits are read and written — K19 and K20.
///
/// One interface, two collections: `coaches/{coachUid}/splits/*` and, per D7,
/// `users/{uid}/splits/*`. G4 owns the client's repository and entry point; the
/// model, the validator and this contract are shared so the two role copies
/// cannot drift.
///
/// ## Why the fake is strict
///
/// `InMemoryTrainRepository`'s lesson, applied again: a fake that accepts what
/// the backend refuses lets a P0 pass here and fail in production. So this one
/// enforces what the ruleset enforces — the validator, no result-shaped key at
/// any depth, no field naming a client, and above all that **a device may never
/// move `appliedCount`**. That field is written by the publish Function with
/// `FieldValue.increment`, travelling with the version id in the same
/// transaction; a read-modify-write from a phone is exactly how it
/// double-counts on a replay.
///
/// ## K19 sorts by `updatedAt`, and that is a rule
///
/// Rule 11: `appliedCount` is "on 7 clients" on a card, displayed and never an
/// `orderBy`. [SplitRepository.splits] therefore returns newest-edited first
/// and offers no sort parameter at all — there is no argument a caller could
/// pass to rank her splits by how many women are on them.
library;

import '../prescription_only_validator.dart';
import 'split.dart';
import 'split_validator.dart';

/// Refused because a device tried to move a Function-written field.
class AppliedCountNotWritable implements Exception {
  const AppliedCountNotWritable({required this.was, required this.attempted});

  final int was;
  final int attempted;

  @override
  String toString() =>
      'AppliedCountNotWritable($was → $attempted) — the publish Function '
      'increments it; nothing on a device may.';
}

/// Refused because a template named a person.
class TemplateNamesAClient implements Exception {
  const TemplateNamesAClient(this.key);

  final String key;

  @override
  String toString() =>
      'TemplateNamesAClient("$key") — a split is a template, not a plan';
}

/// Keys that would turn a template into a plan. Named as a deny list so the
/// product-rule scanner reads this as the enforcement it is.
const Set<String> kForbiddenTemplateKeys = <String>{
  'clientUid',
  'assignedTo',
  'clients',
};

abstract class SplitRepository {
  /// K19's list: newest-edited first, capped. **No sort parameter.**
  Future<List<Split>> splits({int limit = 50});

  /// K20 arriving from K19's cache costs nothing; this is for a cold open.
  Future<Split?> byId(String splitId);

  /// Creates or updates. Validates first, and refuses the writes above.
  Future<void> save(Split split);

  Future<void> delete(String splitId);
}

/// The strict fake. See the library note.
class InMemorySplitRepository implements SplitRepository {
  InMemorySplitRepository({List<Split> splits = const <Split>[]}) {
    for (final split in splits) {
      _store[split.splitId] = split;
    }
  }

  final Map<String, Split> _store = <String, Split>{};
  final SplitValidator _validator = const SplitValidator();

  /// Document reads, so a test can measure the claim rather than assert it.
  int reads = 0;
  int writes = 0;

  @override
  Future<List<Split>> splits({int limit = 50}) async {
    final all = _store.values.toList()
      ..sort((a, b) {
        final left = a.updatedAt;
        final right = b.updatedAt;
        if (left == null && right == null) return 0;
        if (left == null) return 1;
        if (right == null) return -1;
        return right.compareTo(left);
      });
    final page = all.take(limit).toList(growable: false);
    reads += page.length;
    return page;
  }

  @override
  Future<Split?> byId(String splitId) async {
    final found = _store[splitId];
    if (found != null) reads += 1;
    return found;
  }

  @override
  Future<void> save(Split split) async {
    _validator.assertValid(split);

    final wire = split.toWire();
    PrescriptionOnlyValidator.assertPrescriptionOnly(wire);
    for (final key in wire.keys) {
      if (kForbiddenTemplateKeys.contains(key)) {
        throw TemplateNamesAClient(key);
      }
    }

    final existing = _store[split.splitId];
    final was = existing?.appliedCount ?? 0;
    if (split.appliedCount != was) {
      throw AppliedCountNotWritable(was: was, attempted: split.appliedCount);
    }

    _store[split.splitId] = split;
    writes += 1;
  }

  @override
  Future<void> delete(String splitId) async {
    _store.remove(splitId);
    writes += 1;
  }

  /// What the publish Function does, reproduced so a test can exercise the
  /// increment without pretending a device performed it.
  void serverIncrementAppliedCount(String splitId) {
    final split = _store[splitId];
    if (split == null) return;
    _store[splitId] = Split(
      splitId: split.splitId,
      name: split.name,
      cycleLength: split.cycleLength,
      daySlots: split.daySlots,
      ownerKind: split.ownerKind,
      source: split.source,
      carryApproved: split.carryApproved,
      appliedCount: split.appliedCount + 1,
      updatedAt: split.updatedAt,
    );
  }

  /// Everything stored, for assertions about what a write touched.
  Map<String, Split> get contents => Map<String, Split>.unmodifiable(_store);
}
