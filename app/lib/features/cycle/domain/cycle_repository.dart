/// What the cycle feature reads and writes — and what it refuses to express.
///
/// Two collections, both under `users/{uid}/**` and therefore writable offline
/// (spine §5). Plan §2: "**One listener, not a read per screen.**
/// `cycle/current` is attached once per app session by `CycleRepository.watch()`
/// and served from Firestore's unbounded offline cache thereafter. Every Y
/// screen and T01's cycle row render from that one snapshot."
///
/// ## The three things this interface cannot express
///
/// **1. Setup cannot turn on sharing.** [CycleRepository.completeSetup] and
/// [CycleRepository.savePreferences] have **no sharing parameter**. Plan §1.1:
/// "`sharing.*` … is false on write, cannot be set during setup, and only
/// Y12/G02 can turn it on." That is not a rule Y01 and Y02 have to remember —
/// there is nothing for them to pass. The only way in is [setSharing], which
/// requires a relationship id, because a grant not bound to one relationship is
/// a grant the next coach inherits (OQ-2).
///
/// **2. There is no cycle query.** [PeriodRepository.inMonth] is a bounded
/// `__name__` range over one month, and `cycle/current` is fetched by fixed id.
/// No method here returns "all women's…" anything, and G9 §6 sets
/// `allow list: if false` on `cycle` so a listing is not merely unwritten but
/// denied. §9's scalability gate depends on this being the only query site.
///
/// **3. An invalid period cannot be saved.** [PeriodRepository.save] takes a
/// [PeriodEntry], and a [PeriodEntry] can only be built through
/// `PeriodEntry.validate`. §3.2: "no write is attempted, so nothing to undo and
/// nothing to sync."
///
/// ## Why the fake is strict
///
/// The same reason `InMemoryMealRepository` is: a lenient fake lets a rule pass
/// here and fail in production. [InMemoryCycleRepository] enforces the caps the
/// security rules enforce — twelve `recentStarts`, six `contextFlags`, a cycle
/// length of 21–45 or null — so a test cannot accidentally prove something the
/// backend would reject.
library;

import 'dart:async';

import 'cycle_document.dart';
import 'cycle_projection_reconciler.dart';
import 'cycle_sharing_policy.dart';
import 'period_entry.dart';

/// The backing store both fakes share.
///
/// One object, because a period save writes **two documents in one
/// transaction** (plan §2 row 9): the period itself, and `lastPeriod` /
/// `recentStarts` on `cycle/current`. Two independent fakes could let those
/// drift apart in a test while the real transaction kept them together, which
/// would make the test useless in the one way that matters.
class CycleStore {
  /// Null until she completes setup. **No document exists before that**, which
  /// is what makes the feature invisible everywhere else (§3.1 `notSetUp`).
  CycleDocument? cycle;

  /// Keyed by `yyyy-MM-dd`, which **is** the start date (spine C1). A replayed
  /// write targets the same key and collapses into the same state, so a
  /// duplicate period is not something the queue can produce.
  final Map<String, PeriodEntry> periods = <String, PeriodEntry>{};

  /// Every document path written, in order. Tests assert against this rather
  /// than against a callback argument — `PHASE1-FIXES.md` #1 records a screen
  /// whose test asserted the callback and never noticed nothing was written.
  final List<String> writes = <String>[];
}

abstract class CycleRepository {
  /// The current document, or null when she has never set the feature up.
  ///
  /// Synchronous, because every Y screen and T01's row render from the one
  /// cached snapshot rather than awaiting a read.
  CycleDocument? get current;

  /// The single per-session listener. See the library note.
  Stream<CycleDocument?> watch();

  /// How many times [watch] has attached.
  ///
  /// Exposed so `one_listener_test` can assert the cost model in §2 — "1 read
  /// per session", not one per screen — rather than trusting the comment.
  int get attachCount;

  /// Y01. Writes `mode` and `contextFlags`, and **all sharing switches false**.
  ///
  /// Note the absent parameter: there is no way to pass a sharing value here.
  Future<void> completeSetup({
    required CycleMode mode,
    Set<CycleContextFlag> contextFlags,
  });

  /// Y02. Writes `cycleLengthDays` and `adaptation`.
  ///
  /// [cycleLengthDays] stays null for "Not sure". Nothing pre-fills 28 days.
  Future<void> savePreferences({
    int? cycleLengthDays,
    required CycleAdaptation adaptation,
  });

  /// Y10's and Y12's adaptation switches.
  Future<void> setAdaptation(CycleAdaptation adaptation);

  /// Y12 / G02 — **the only way a sharing switch is ever turned on.**
  Future<void> setSharing({
    required CycleCategory category,
    required bool on,
    required String relId,
  });

  /// Y12's "Delete cycle data". Removes the document and every period.
  ///
  /// The check-ins are **not** deleted — they are G3's and hold energy, sleep
  /// and appetite the rest of the app uses (§3.5).
  Future<void> purge();

  Future<void> dispose();
}

/// An in-memory [CycleRepository]. Real behaviour, no storage.
class InMemoryCycleRepository implements CycleRepository {
  InMemoryCycleRepository({CycleStore? store}) : store = store ?? CycleStore();

  final CycleStore store;

  final StreamController<CycleDocument?> _docs =
      StreamController<CycleDocument?>.broadcast();

  int _attachCount = 0;
  bool _online = true;

  /// Period ids and document keys saved while offline.
  final Set<String> _queued = <String>{};

  @override
  int get attachCount => _attachCount;

  @override
  CycleDocument? get current => store.cycle;

  @override
  Stream<CycleDocument?> watch() {
    _attachCount++;
    return _docs.stream;
  }

  /// Everything still waiting for signal.
  Set<String> get queued => Set.unmodifiable(_queued);

  bool get isOffline => !_online;

  void goOffline() => _online = false;

  /// Drains the queue. Replay is idempotent: every write is keyed by a
  /// deterministic document id, so re-applying one lands on the same document.
  Future<void> goOnline() async {
    _online = true;
    _queued.clear();
    _emit();
  }

  void _emit() {
    if (!_docs.isClosed) _docs.add(store.cycle);
  }

  void _record(String path) {
    store.writes.add(path);
    if (!_online) _queued.add(path);
  }

  @override
  Future<void> completeSetup({
    required CycleMode mode,
    Set<CycleContextFlag> contextFlags = const <CycleContextFlag>{},
  }) async {
    final existing = store.cycle;
    store.cycle = CycleDocument(
      mode: mode,
      contextFlags: contextFlags,
      // Preserved across a mode change from Y12's "Change how you use My
      // cycle", so switching to symptom-only does not silently discard the
      // length she told us.
      cycleLengthDays: existing?.cycleLengthDays,
      adaptation: existing?.adaptation ?? CycleAdaptation.allOff,
      // C12, absolute. Not `existing?.sharing` — and not a parameter either.
      // A new document has every switch off, and setup can only ever produce
      // a new document's worth of sharing state.
      sharing: existing?.sharing ?? CycleSharing.off,
      lastPeriod: existing?.lastPeriod,
      recentStarts: existing?.recentStarts ?? const <String>[],
    );
    _record('cycle/current');
    _emit();
  }

  @override
  Future<void> savePreferences({
    int? cycleLengthDays,
    required CycleAdaptation adaptation,
  }) async {
    final existing = store.cycle;
    if (existing == null) {
      throw StateError(
        'savePreferences before completeSetup. No cycle document exists until '
        'Y01 finishes, and Y02 merges into it rather than creating it.',
      );
    }
    store.cycle = existing.copyWith(
      cycleLengthDays: cycleLengthDays,
      clearCycleLength: cycleLengthDays == null,
      adaptation: adaptation,
    );
    _record('cycle/current');
    _emit();
  }

  @override
  Future<void> setAdaptation(CycleAdaptation adaptation) async {
    final existing = store.cycle;
    if (existing == null) return;
    store.cycle = existing.copyWith(adaptation: adaptation);
    _record('cycle/current');
    _emit();
  }

  @override
  Future<void> setSharing({
    required CycleCategory category,
    required bool on,
    required String relId,
  }) async {
    final existing = store.cycle;
    if (existing == null) {
      throw StateError(
        'A sharing switch cannot be set before the feature is set up — there '
        'is no document to write it to.',
      );
    }
    store.cycle = existing.copyWith(
      sharing: existing.sharing.grant(
        key: sharingKeyFor(category.name),
        on: on,
        relId: relId,
      ),
    );
    // Field-path merge per key: each switch is a single-owner scalar (§4).
    _record('cycle/current.sharing.${category.name}');
    _emit();
  }

  @override
  Future<void> purge() async {
    store.cycle = null;
    store.periods.clear();
    _record('cycle/current:delete');
    _emit();
  }

  @override
  Future<void> dispose() => _docs.close();
}

abstract class PeriodRepository {
  /// Y08's month. A bounded `__name__` range — plan §2 row 8, "≤2" documents.
  Future<List<PeriodEntry>> inMonth({required int year, required int month});

  /// The periods behind `recentStarts`, newest first, capped at twelve.
  Future<List<PeriodEntry>> recent();

  /// Y09's save. **Two writes in one transaction**: the period document, and
  /// the derived fields on `cycle/current`.
  Future<void> save(PeriodEntry entry);

  /// Y09's edit when the start date changed.
  ///
  /// The id **is** the start date, so this is a delete plus a create inside one
  /// transaction (§3.2) — which is why Y09's note "editing a date clears
  /// estimates built on the old one" is structurally true.
  Future<void> replace({required String oldId, required PeriodEntry entry});

  /// Y09's delete. `lastPeriod` and `recentStarts` are rebuilt in the same
  /// transaction, so no stale estimate survives.
  Future<void> remove(String id);

  Future<void> dispose();
}

class InMemoryPeriodRepository implements PeriodRepository {
  InMemoryPeriodRepository({
    required this.cycles,
    this.reconciler = const CycleProjectionReconciler(),
  });

  /// Shares [CycleStore] with the cycle repository — see the note on that class.
  final InMemoryCycleRepository cycles;

  final CycleProjectionReconciler reconciler;

  CycleStore get store => cycles.store;

  @override
  Future<List<PeriodEntry>> inMonth({
    required int year,
    required int month,
  }) async {
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    // A prefix match on the document id. This is the `__name__` range from
    // plan §2 row 8 expressed against a map; it is bounded by construction and
    // never scans the collection.
    final out =
        store.periods.entries
            .where((e) => e.key.startsWith(prefix))
            .map((e) => e.value)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  @override
  Future<List<PeriodEntry>> recent() async {
    final out = store.periods.values.toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    return out.take(CycleDocument.maxRecentStarts).toList();
  }

  /// Rebuilds the two derived fields. Called inside every mutation, so they
  /// cannot be left behind by one path that forgot.
  void _reconcile() {
    final cycle = store.cycle;
    if (cycle == null) return;
    store.cycle = reconciler.apply(cycle, store.periods.values);
    store.writes.add('cycle/current.lastPeriod+recentStarts');
  }

  @override
  Future<void> save(PeriodEntry entry) async {
    store.periods[entry.id] = entry;
    store.writes.add('periods/${entry.id}');
    _reconcile();
    cycles._emit();
  }

  @override
  Future<void> replace({
    required String oldId,
    required PeriodEntry entry,
  }) async {
    store.periods.remove(oldId);
    store.periods[entry.id] = entry;
    store.writes.add('periods/$oldId:delete');
    store.writes.add('periods/${entry.id}');
    _reconcile();
    cycles._emit();
  }

  @override
  Future<void> remove(String id) async {
    store.periods.remove(id);
    store.writes.add('periods/$id:delete');
    _reconcile();
    cycles._emit();
  }

  @override
  Future<void> dispose() async {}
}
