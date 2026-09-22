/// The month, read and written — W03 through W07.
///
/// One document `get` by a deterministic id, and one write per debounce burst.
/// There is no `.where()` and no `.orderBy()` in this interface, which is what
/// keeps the whole planner off the index budget: G14 §2 costs W03 at **1 read**
/// and W04, W05 and W06 at **0**, because they are all the same document.
///
/// ## What the strict fake refuses, and why each one is a rule
///
///  * **A status other than `draft`.** "A DRAFT can never claim to be
///    published: only the callable writes that word." Publishing is the only
///    act that changes a plan, and it happens server-side.
///  * **A result-shaped key at any depth.** §2.1, via
///    `PrescriptionOnlyValidator`.
///  * **An id that is not `{clientUid}__{yyyy-MM}`.** Spine C1: a replayed
///    offline save must overwrite itself rather than create a second month.
///  * **A conflicting allergen.** The domain layer refuses and names it. There
///    is no "assign it anyway" on a coach screen.
///  * **A document over the cap.** 700 KB, asserted before the write, because
///    the 1 MiB limit is a cliff and hitting it loses a month of work.
///
/// ## Meals without constraints are refused, not written
///
/// A repository built without [MealSafety] will store a workout month happily
/// and refuse any day carrying a *filled* meal slot. That asymmetry is
/// deliberate: you cannot plan somebody's food without knowing what she cannot
/// eat, and the honest failure is a refusal rather than a plan written blind.
library;

import '../meal/meal_slot_planner.dart';
import '../prescription_only_validator.dart';
import 'plan_draft.dart';

/// The size cap, in bytes of canonical wire text. G14 §1.2's 700 KB.
const int kMaxDraftBytes = 700 * 1024;

/// Refused because the draft claimed a state only the server may write.
class DraftNotWritable implements Exception {
  const DraftNotWritable(this.status);

  final PlanDraftStatus status;

  @override
  String toString() =>
      'DraftNotWritable(${status.wireName}) — only the publish callable writes '
      'that word';
}

/// Refused because the id is not the deterministic one.
class DraftIdNotDeterministic implements Exception {
  const DraftIdNotDeterministic({required this.given, required this.expected});

  final String given;
  final String expected;

  @override
  String toString() => 'DraftIdNotDeterministic($given, expected $expected)';
}

/// Refused because the document would be too large to write safely.
class DraftTooLarge implements Exception {
  const DraftTooLarge(this.bytes);

  final int bytes;

  @override
  String toString() => 'DraftTooLarge($bytes bytes > $kMaxDraftBytes)';
}

/// Refused because a meal was planned with no knowledge of her allergies.
class MealPlannedWithoutConstraints implements Exception {
  const MealPlannedWithoutConstraints();

  @override
  String toString() =>
      'MealPlannedWithoutConstraints — a meal cannot be prescribed before her '
      'constraints can be read. An unknown constraint is not an absent one.';
}

abstract class PlanDraftRepository {
  /// The whole month, in one document.
  Future<PlanDraft?> draftFor({
    required String clientUid,
    required String month,
  });

  /// Creates or replaces. Refuses everything in the library note.
  Future<void> save(PlanDraft draft);

  Future<void> delete({required String clientUid, required String month});
}

/// The strict fake.
class InMemoryPlanDraftRepository implements PlanDraftRepository {
  InMemoryPlanDraftRepository({
    List<PlanDraft> drafts = const <PlanDraft>[],
    this.safety,
  }) {
    for (final draft in drafts) {
      _store[draft.draftId] = draft;
    }
  }

  /// Null means her constraints cannot be read on this device right now.
  final MealSafety? safety;

  final Map<String, PlanDraft> _store = <String, PlanDraft>{};

  int reads = 0;
  int writes = 0;

  /// Every id this repository was asked for, so a test can show that opening
  /// W04, W05 and W06 after W03 asked for nothing new.
  final List<String> readIds = <String>[];

  @override
  Future<PlanDraft?> draftFor({
    required String clientUid,
    required String month,
  }) async {
    final id = planDraftId(clientUid: clientUid, month: month);
    readIds.add(id);
    final found = _store[id];
    if (found != null) reads += 1;
    return found;
  }

  @override
  Future<void> save(PlanDraft draft) async {
    assertWritable(draft, safety: safety);
    _store[draft.draftId] = draft;
    writes += 1;
  }

  @override
  Future<void> delete({
    required String clientUid,
    required String month,
  }) async {
    _store.remove(planDraftId(clientUid: clientUid, month: month));
    writes += 1;
  }

  Map<String, PlanDraft> get contents =>
      Map<String, PlanDraft>.unmodifiable(_store);

  /// The checks the real repository runs too, kept in one place so the fake
  /// and the backend cannot disagree about what is writable.
  static void assertWritable(PlanDraft draft, {MealSafety? safety}) {
    if (draft.status != PlanDraftStatus.draft) {
      throw DraftNotWritable(draft.status);
    }

    final expected = planDraftId(
      clientUid: draft.clientUid,
      month: draft.month,
    );
    if (draft.draftId != expected) {
      throw DraftIdNotDeterministic(given: draft.draftId, expected: expected);
    }

    final wire = draft.toWire();
    PrescriptionOnlyValidator.assertPrescriptionOnly(wire);

    final bytes = wire.toString().length;
    if (bytes > kMaxDraftBytes) throw DraftTooLarge(bytes);

    final hasPlannedMeal = draft.days.values.any(
      (day) => (day.meal?.filledCount ?? 0) > 0,
    );
    if (!hasPlannedMeal) return;

    if (safety == null) throw const MealPlannedWithoutConstraints();
    MealSlotPlanner(safety).assertWritable(draft);
  }
}
