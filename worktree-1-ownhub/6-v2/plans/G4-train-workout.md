# G4 — Train & workout player

**Screens (13):** R01 Train, R02 Program, R03 Workout day, R04 Exercise video, R05 Swap a move,
R06 Follow-along move, R07 Mid-set, R08 Change a set, R09 Resting, R10 Finished, R11 Workout library,
R12 Logged from memory, R13 Move logged.

**Owns:** `users/{uid}/sessions/{sessionId}` (the only collection G4 writes), the live-session state
machine, the logging loop, and video delivery.

**Reads only:** `plans/**` (G2), `users/{uid}` root + `weeks/*` + `bests/*` (G1/G6),
`checkins/{today}` (G3), the read-only libraries.

**Three decisions everything else follows from:**

| # | Decision | Why |
|---|---|---|
| D1 | The five-second undo window is held in a **local draft store**, not in Firestore's offline queue | A Firestore `update()` cannot be cancelled once issued. If the undo window sat after the write, an undo made offline would still sync a set she deleted. Undo must therefore precede the write — which also gives D2 for free. |
| D2 | Server flush is **per move**, not per set (sets still embedded, C2 intact) | Per-set flushing costs 16 writes/session = 76% of the whole product's §3 write budget. Per-move costs 7 and is indistinguishable to her, because durability is already local at the instant of the tap. |
| D3 | The 124-video library and its posters are **bundled/cached client-side**; R01, R03, R04, R05 and R11 issue **zero** Firestore reads | Spine §4: the libraries are the difference between 7 reads a day and 40. It also makes R11's filtering a local list operation, so there is no library query to index. |

---

## 1. Data model

### 1.1 The one document G4 writes

`users/{uid}/sessions/{sessionId}`. Sets are **embedded** (C2). Two ID schemes, both idempotent (C1):

| Session kind | `sessionId` | Why |
|---|---|---|
| `live` | client UUIDv4, generated once at start, reused for every retry | the spine's explicit allowance for `sessions` |
| `recalled` / `unplanned` | **deterministic**: `recalled-{dateKey}-{assignmentId \| activity}` | **G3 requires this** (its §7 request and Q9): a recalled session is written optimistically offline, and a replayed retry must overwrite itself rather than create a second session and double-increment the week |

| Field | Type | Null? | Notes |
|---|---|---|---|
| `planVersion` | string | **yes** (spine amended) | Pinned at start from the assignment; `null` for a library workout, a class or a detected walk. A plan republished mid-session never reaches this doc (HANDOFF rule 2). |
| `assignmentId` | string | **yes** (spine amended) | The assignment's `yyyy-MM-dd` key. `null` off-plan. |
| `dateKey` | string | no | `yyyy-MM-dd` in **Africa/Cairo**, not UTC. The only range-queryable field. Extension to the spine, inside my own collection. |
| `startedAt` | timestamp | no | Server-resolved at create. |
| `completedAt` | timestamp | yes | Written once, never rewritten. |
| `durationSec` | int | no | 0 until finished. |
| `source` | `'live' \| 'recalled' \| 'unplanned'` | no | Spine amended: `unplanned` now gives a walk or a studio class somewhere to live. Immutable after create. R12's rule keys off `recalled`; **neither `recalled` nor `unplanned` may set a personal best.** |
| `recallMethod` | `'plan' \| 'history'` | yes | Extension, narrowed: which of T02's two rows she tapped. `timeOnly`/`detected` are no longer needed here — they are `source: 'unplanned'` + `activity`. |
| `endedReason` | `'finished' \| 'abandoned'` | yes | `null` while running. |
| `deviceId` | string | no | Single-writer guard (see §4.2). Immutable. |
| `workoutId` | string | yes | Set when the session came from R11, not from the plan. |
| `activity` | string | yes | Spine's own name (amended). `'walk' \| 'class' \| 'other'` for `unplanned` sessions. `sets` is `[]` for these. |
| `loggedSetCount` | int | no | `FieldValue.increment` only (C4). Lets G6 count credit and adherence **without reading `sets`**. |
| `swaps` | list ≤10 | no | `{ fromExerciseId, toExerciseId, reason }` — R05's output. |
| `sets` | list ≤60 | no | Embedded. Shape below. |

`sets[i]`:

| Field | Type | Null? | Notes |
|---|---|---|---|
| `exerciseId` | string | no | |
| `order`, `setIndex` | int | no | `order` = move position in the day; `setIndex` = set within the move. |
| `prescribedWeight` | double | **yes** (spine amended) | Copied from G2's `prescribedLoad`. G2's fixed mapping writes `0` for `kind:'bodyweight'` and `kind:'seconds'`; the spine now permits `null`. I accept **either** and render both as "bodyweight", never "0 kg" (see OQ-6 — the two documents disagree). |
| `prescribedReps` | int | **yes** (spine amended) | `null` for a timed hold — G2's contract writes `prescribedReps: null` for `kind:'seconds'`. This makes OQ-5 pressing, not cosmetic. |
| `unit` | `'reps' \| 'seconds'` | no | Extension, derived from G2's `prescribedLoad.kind`. R03's "3 × 30 seconds". |
| `perSide` | bool | no | Copied from G2's `moves[].perSide`. "3 × 10 each side". |
| `prescribedSeconds` | int | yes | From G2's `prescribedLoad.value` when `kind:'seconds'`. |
| `actualWeight` | double | **yes — starts null** | **C8.** |
| `actualReps` | int | **yes — starts null** | **C8.** The single adherence marker. Timed sets also write it (see OQ-5). |
| `actualSeconds` | int | yes | Companion to `actualReps` for holds. |
| `skipped` | bool | no | Defaults false. A skipped set is not a logged set. |
| `loggedAt` | timestamp | yes | Client clock. Presence mirrors `actualReps != null`. |

**Document size:** 30 sets × ~140 B + header ≈ **5 KB**. Firestore's limit is 1 MiB, so a session is
never at risk, and a finished session is 1 read as C2 promises.

### 1.2 Indexes

| Collection | Field(s) | Kind | Used by |
|---|---|---|---|
| `users/{uid}/sessions` | `dateKey` ASC | single-field, **automatic** | R02 week marks, G6 week credit, P01's 8-week range |
| `users/{uid}/sessions` | `completedAt` DESC | single-field, **automatic** | R01 "resume?" / last-session fallback |
| `users/{uid}/sessions` | **`sets` → indexing DISABLED** | single-field **exemption** (`fieldOverrides`) | see below |
| — | — | **composite: none** | — |

The `sets` exemption is not an optimisation, it is **C7 compliance**. Firestore auto-indexes map
subfields inside arrays, so without the exemption `sets.actualWeight` would carry a live index and
Rule 11's "no index on weight" would be false in the deployed project. The exemption also removes 30
index entries per set write.

### 1.3 Read/write pattern per screen

| Screen | Reads | Writes |
|---|---|---|
| R01 Train | user doc + `weeks/{thisWeek}` + `assignments/{today}` — all **already live listeners from T01**; library from bundle | none |
| R02 Program | `versions/{v}` (immutable, cache-forever) + `assignments` week range + `sessions` week range | none |
| R03 Workout day | 0 — assignment is in cache; move metadata from bundle | none (pre-start swaps go to the local draft only) |
| R04 Exercise video | 0 Firestore; 1 CDN GET (demo loop) | none |
| R05 Swap a move | 0 — candidates filtered locally from the bundle + `assignment.approvedAlternatives` | local draft `swaps` |
| R06 Follow-along | 0 Firestore; 1 CDN stream | 1 flush per move (timer is the log) |
| R07 Mid-set | 0 — local draft | 1 flush per move |
| R08 Change a set | 0 — chips come from the assignment (`prescribedWeight` ± one step, `lastActual`) | mutates the staged set; folded into the next flush |
| R09 Resting | 0 — local timer | 0 (the write already happened at the move boundary, or is staged) |
| R10 Finished | own session doc (local) + `rewards`/`weeks` listeners + `bests/{exerciseId}` for the PB card | 1 finish update |
| R11 Workout library | **0** — bundled library, local filter | none |
| R12 Logged from memory | `rewards`/`weeks` listeners | 1 create (already complete) |
| R13 Move logged | 0 — local draft | 1 flush |

---

## 2. The query for every screen, with index and cost

At §3's numbers: 35,000 DAU, 2 sessions/active/week → **10,000 sessions/day**; 40% of traffic in the
four hours 19:00–23:00 Cairo.

| Screen | Query | Index | Reads | Writes | Fleet/day |
|---|---|---|---|---|---|
| R01 | `get users/{uid}`; `get users/{uid}/weeks/{yyyy-Www}`; `get plans/{uid}/assignments/{today}` | doc get ×3 | 3 cold, **0 incremental** (T01 holds the same listeners) | 0 | ~0 incremental |
| R02 | `get plans/{uid}/versions/{v}`; `where dateKey >= wkStart && <= wkEnd` on `sessions`; `where __name__ >= wkStart && <= wkEnd` on `assignments` | `dateKey` ASC (auto); `__name__` (auto) | 1 + ≤3 + ≤7 = **≤11**, once per week, cached after | 0 | ~4k reads/day (opened ~1×/week/active) |
| R03 | none — assignment served from the offline cache | — | **0** | 0 | 0 |
| R04 | none — `exercises/{id}` from bundle; video from CDN | — | **0** | 0 | 0 Firestore |
| R05 | none — local filter over the bundle on `{primaryMuscle, equipment, quiet, floorOnly}` | — | **0** | 0 | 0 |
| R06 | none | — | 0 | 1/move | ~30k |
| R07 | none | — | 0 | 1/move (D2) | ~50k |
| R08 | none | — | 0 | 0 (folded) | 0 |
| R09 | none | — | 0 | 0 | 0 |
| R10 | `get users/{uid}/bests/{exerciseId}` for each measured PB candidate (≤5, deterministic id, **no query** — spine §1) | doc get | ≤5, usually 1 | 1 finish | ~20k reads, 10k writes |
| R11 | none — local filter + count over 124 bundled rows | — | **0** | 0 | 0 |
| R12 | none new (listeners) | — | 0 | 1 create | ~2k writes |
| R13 | none | — | 0 | 1 flush | folded into R07's 50k |
| R01 resume banner | `where completedAt == null orderBy startedAt desc limit 1` | `completedAt` (auto) | ≤1 | 0 | ~5k |

**Per active day, G4's share**

| | Training day (2 in 7) | Rest day | Amortised |
|---|---|---|---|
| Reads | 3–5 (≈1 incremental over T01) | 0–1 | **~0.9** |
| Writes | 7–8 | 0 | **~2.1** |

**Fleet/day:** 10,000 sessions × 7–8 writes = **70,000–80,000 writes/day = 33–38% of the 210k budget**;
≈ **20,000 reads/day = 7% of the 280k budget**. Inside §4's "R03→R10 = 2 + 1 read, 1 write per set"
allowance on reads, and *below* it on writes because of D2.

Rejected alternative, stated for the record: per-set server flushing is 16 writes/session =
**160,000/day = 76% of the entire product's write budget for one screen group.** Not taken.

**Peak (19:00–23:00):** 4,000 sessions in 4 h → 28,000–32,000 writes / 14,400 s ≈ **2.2 writes/s
fleet-wide**, spread across 4,000 distinct document paths. Per document: one write per 3–5 minutes,
three orders of magnitude under the 1 write/s per-document ceiling. Session IDs are UUIDv4 under
per-user paths, so there is no monotonically increasing key and no 500-writes/s hotspot range.

**Firestore money (G4 only):** 2.4M writes/mo × $0.18/100k = **$4.32**; 0.6M reads × $0.06/100k =
**$0.36**; storage grows 4.3 GB/month (866k sessions × 5 KB) ≈ **$0.78/mo rising ~$9/mo after a year**.
Total ≈ **$6/month at launch scale.**

---

## 3. State machines

### 3.1 Live session — `SessionController`

Persisted markers: `startedAt`, `completedAt`, `endedReason`, `loggedSetCount`.
Runtime-only: `resting`, `paused` (they live in the local draft, not Firestore — a rest timer has no
business making a server round-trip, but it must survive an app kill, so the draft stores `restEndsAt`
and `pausedAt`).

| From | Event | To | Persisted effect | Screen |
|---|---|---|---|---|
| `notStarted` | open assignment | `notStarted` | none | R03 |
| `notStarted` | swap a move | `notStarted` | local draft only | R05 |
| `notStarted` | tap Start | `running` | **create** doc: uuid, `planVersion`, `assignmentId`, `dateKey`, `startedAt`, `source:'live'`, `deviceId`, sets with **all actuals null**, `loggedSetCount:0` | R03→R07/R06 |
| `running` | log set (1 tap) | `resting` | stage locally + 5 s undo; flush at move end | R07→R09 |
| `resting` | undo (<5 s) | `running` | **nothing sent, ever** | R09→R07 |
| `resting` | timer end / "I'm ready" | `running` | none | R09→R07 |
| `running` | "I did all 3 sets" | `running` (next move) | stage 3 sets, 1 flush, **session does not end** | R07→R13 |
| `running` | tap pause | `paused` | local `pausedAt` | R07 |
| `paused` | resume | `running` | none | R07 |
| `running`/`resting`/`paused` | last move done / "Finish here" | `finished` | flush + `completedAt`, `durationSec`, `endedReason:'finished'` | R10 |
| `running`/`paused` | 6 h idle, or explicit discard | `abandoned` | flush + `endedReason:'abandoned'`, `completedAt:now` | R01 banner |
| `notStarted` | recall from T02 | `finished` (`recalled`) | **create already complete** under the deterministic ID: `source:'recalled'`, `recallMethod`, actuals copied, PB-ineligible | R12 |
| `notStarted` | T02 time chip, or a confirmed Health Connect / HealthKit proposal | `finished` (`unplanned`) | create already complete: `source:'unplanned'`, `activity`, `sets: []`, `durationSec`, `planVersion`/`assignmentId` null | R12 |
| `finished`/`abandoned` | — | terminal | immutable but for sync | — |

An abandoned session with `loggedSetCount > 0` **still counts toward the week** ("ten minutes counts",
F25). Nothing red, no "you didn't finish" copy (OQ-10 confirms the 6 h threshold).

### 3.2 A set — `SetLifecycle`

| State | Persisted shape | UI |
|---|---|---|
| `prescribed` | `actualWeight == null && actualReps == null && !skipped` | hollow ring (R07 `setRow` 'next') |
| `staged` | local draft only, nothing on the server | check + snackbar with Undo, 5 s |
| `logged` | actuals non-null, `loggedAt` set, flush pending | filled check (R07 'done') |
| `synced` | same, `hasPendingWrites == false` | identical to `logged` — she is never shown a sync distinction she did not ask about |
| `skipped` | `skipped == true`, actuals stay null | struck through, **not** counted in adherence |
| `changed` | `staged` again via R08, then `logged` | chips reflect the new value |

Terminal: `synced`, `skipped`. `prescribed → logged` is only reachable through `staged`, and `staged`
is only reachable from a user gesture — that is the mechanical form of Rule 1.

### 3.3 Video asset — `DownloadState`

`absent → queued → downloading(progress) → ready → stale(libVersion bumped) → evicted`, plus
`failed → queued` (exponential backoff, 5 attempts). Eviction keeps the current week + next week and
**never evicts while a session is running**. `ready` assets are what make §4 true offline.

---

## 4. Offline behaviour

### 4.1 What is writable offline

**Everything G4 writes.** A whole session — create, every set, swaps, move logs, finish, and a recalled
session — is writable with no signal, because all of it is `users/{uid}/sessions/**` and D1 puts the
undo window ahead of the write.

**Not writable offline:** nothing in this group. G4 never writes `plans/**` (server-authored) or any
other group's collection.

**The one genuine offline gap, and its designed fallback:** if she has never opened today's assignment
while online, R03 has no plan to render. `AssignmentCacheGuard` then offers the bundled library (R11)
and starts an **off-plan** session (`assignmentId: null`, `workoutId` set), which still counts toward
her week. The copy states she is training from the library, not from her plan. QA tests this path, not
just the happy one.

**Video offline:** a downloaded workout plays from the device file; R02's download action fetches the
week. With `ready` assets and a cached assignment, a full session including its video needs no signal
at any point.

### 4.2 Conflict resolution

| Conflict | Resolution |
|---|---|
| Same device retries after reconnect | Idempotent: `sessionId` is fixed (C1) — UUIDv4 for live, **deterministic** for recalled/unplanned, which is what G3's optimistic week credit depends on — `setIndex` is fixed, and `loggedSetCount` uses `FieldValue.increment` (C4). A replay cannot duplicate a set or a session. |
| Two devices in the same workout | Cannot collide: `sessionId` is generated per device, so two devices produce two sessions, not two writers on one document. `deviceId` is embedded at create and immutable in the rules; `SessionOwnershipGuard.assertWritableOnThisDevice()` refuses to write into another device's session and opens a new one instead. |
| Why this guard is load-bearing | Firestore has no field path to an **array element**, so updating one set rewrites the whole `sets` array (read-modify-write from the local cache). That is safe *only* under a single writer. The guard is what makes it safe. OQ-7 asks the spine to consider `sets` as a map keyed by index, which would allow true field-level merges. |
| Counters | `loggedSetCount` increments only; rules enforce monotonicity. |
| Single-owner scalars | `completedAt`, `endedReason`: first write wins, enforced in rules (`prev().completedAt == null`). |

### 4.3 What the UI shows while queued

- The snackbar after a log is **byte-identical online and offline** (R09, R13). No spinner, no error,
  no "will sync later" scare.
- A "saved on your phone" chip appears on the affected row only when the session document has
  `metadata.hasPendingWrites == true` **and** more than 10 minutes have passed — below that threshold
  it is noise about something that is about to resolve itself.
- R01 shows one quiet line, "1 session waiting for signal", only when that condition holds.
- Nothing in this group ever blocks on the network. Failure is not a state the logging loop has.

---

## 5. §2 rules G4 owns, and exactly where each is enforced

Domain layer, named. No widget enforces a rule.

| Rule | Own? | Enforcement point |
|---|---|---|
| **§2.1 A prescribed value is never a result** (C8) | **OWN** | Four layers: (a) **type separation** — `PrescribedSet` (in `domain/train/models/`) carries only `prescribedWeight`/`prescribedReps`/`prescribedSeconds` and **no actual fields at all**, so no widget can bind an actual to a prescription; `ActualSet` holds the nullable actuals. Nullability is no longer the guard (the spine now allows null prescriptions for bodyweight and timed moves) — **the separation of the two types is**, which is what C8's last sentence calls "the rule that matters". G2's assignment document reinforces it by omission: it contains no `actual*` key at all. (b) `LogSetUseCase.call({sessionId, setIndex, outcome})` takes a **required, non-defaulted** `SetOutcome`; there is no code path that copies prescribed→actual except `SetOutcome.fromPrescription(gesture)`, which requires a user-gesture token. (c) `StartSessionUseCase.assertNoPrefill()` asserts every set on a newly created session has both actuals null. (d) `AdherenceCalculator.loggedSetCount()` / `.adherenceFor(session)` count **non-null `actualReps` only**, never `prescribedReps`. Also enforced in the security rules (`noPrefillOnCreate()`) and by the Cloud Function validator. |
| **§2.9 Undo, not confirmation** | **OWN** for R07/R08/R09/R13 | Every G4 log routes through G3's shared `UndoableLog` / `LogCommandBus` — G3's plan states rule 9 is one implementation, not one per feature, and G4 conforms rather than duplicating it. `LogUndoWindow` holds the single constant `Duration(seconds: 5)`. `UndoableLogger.stage() / commit() / revert()`: `stage()` writes the local draft and returns an `UndoToken`; `SessionRepository.flush()` is reachable **only** from `commit()`. `RevertLogUseCase.call(token)` mutates the draft and nothing else. No dialog exists in the feature: `no_dialogs_in_train_test` fails if `showDialog(` or `AlertDialog` appears anywhere under the train feature. R07 logs in one tap, R13 logs a move in one tap and returns to the list, R08 changes a value with chips and no keyboard (`ChangeSetSheet` exposes a keyboard only behind an explicit "Type a different number"). |
| **R12: a recalled session awards fewer points and never sets a personal best** | **OWN** | `SessionRepository.logRecalled()` sets `source: 'recalled'` + `recallMethod`. `PersonalBestEligibility.isEligible(session) => session.source == live` — expressed as **`!= 'live'` rather than `== 'recalled'`**, so the newly added `unplanned` (a walk, a class) is suppressed by construction rather than by a second clause someone must remember. G6 currently tests `== 'recalled'`; see OQ-17. Enforced **twice**: in the domain layer, and server-side in the `onSessionCompleted` function that G6's bests/points depend on — because a client could otherwise lie about `source`. Rules make `source` immutable after create, so a recalled session cannot be promoted to farm a PB. |
| **§2.3 Weeks, not days; no streak** (C6) | share (G6 owns) | My obligation: the session schema has **no** consecutive-day field, and `WeekCreditContract` (§7) emits week increments only. `session_schema_no_streak_test` fails if any field name matches `streak` or `consecutive`. |
| **§2.11 Nothing ranked by weight** (C7) | share | My obligation: the `sets` **index exemption** in §1.2, so `actualWeight` carries no index and the sort is unexecutable; and the security rules permit no cross-user session read. |
| **§2.2 A message never changes a plan** | honour, don't own | `StartSessionUseCase` pins `planVersion` at start and `ResumeSessionUseCase` **never re-reads** the current version (HANDOFF rule 2). `SessionRepository` has no write path to `plans/**`, and the rules deny it. |
| **§2.4/2.5 Suggestions follow logged symptoms** | not mine (G3) | I read `checkins/{today}` for one purpose: `TrainSuggestionGate.shouldOfferGentler(checkin)` decides whether R01 shows the "Not feeling it today?" row. It **cannot** alter a prescription — the method returns a bool and has no repository. |
| **"A hard set never lowers her weight"** (R08 copy) | share — see OQ-2 | `ChangeSetUseCase` writes **actuals only**, never a prescription (`change_set_never_writes_prescription_test`). The monotonic floor itself lives in `ProgressionFloor.nextPrescription()` wherever progression is computed, which is `plans/**` and therefore not mine to write. |

---

## 6. Security rules

**Scope, per the ratified reconciliation.** G2 found that per-group rulesets cannot work: Firestore
ORs `allow` across `match` blocks, so one permissive block defeats every sibling's denial — including
C5's server-only guard on `verification.status`. `users/{uid}` and its subcollections are therefore
authored **once, by G8**, and groups supply requirements. What follows is the `sessions` block to be
merged verbatim into G8's single ruleset, plus my read requirements stated as requirements rather
than as rules I author. I have deliberately **removed** the `allow write: if false` blocks I first
wrote for `plans/**`, `bests/*` and the libraries: they are not mine to author, and as separate
blocks they would have been the exact defect G2 identified.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isOwner(uid) {
      return request.auth != null && request.auth.uid == uid;
    }

    // ---------- G4: the only collection G4 writes ----------
    match /users/{uid}/sessions/{sessionId} {
      function d()    { return request.resource.data; }
      function prev() { return resource.data; }

      function shapeOk() {
        return d().keys().hasAll(['dateKey','startedAt','source',
                                  'sets','loggedSetCount','deviceId','durationSec'])
          && d().keys().hasOnly(['planVersion','assignmentId','dateKey','startedAt','completedAt',
                                 'durationSec','source','recallMethod','endedReason','deviceId',
                                 'workoutId','activity','loggedSetCount','swaps','sets','appVersion'])
          && (!('planVersion'  in d()) || d().planVersion  == null || d().planVersion  is string)
          && (!('assignmentId' in d()) || d().assignmentId == null || d().assignmentId is string)
          && (!('activity'     in d()) || d().activity     == null || d().activity in ['walk','class','other'])
          && d().dateKey is string && d().dateKey.matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
          && d().startedAt is timestamp && d().startedAt <= request.time
          && d().source in ['live','recalled','unplanned']
          && (!('recallMethod' in d()) || d().recallMethod == null
              || d().recallMethod in ['plan','history'])
          && (!('endedReason' in d()) || d().endedReason == null
              || d().endedReason in ['finished','abandoned'])
          && d().deviceId is string && d().deviceId.size() <= 64
          && d().sets is list && d().sets.size() <= 60
          && d().swaps is list && d().swaps.size() <= 10
          && d().loggedSetCount is int
          && d().loggedSetCount >= 0 && d().loggedSetCount <= d().sets.size()
          && d().durationSec is int && d().durationSec >= 0 && d().durationSec <= 43200
          && (!('completedAt' in d()) || d().completedAt == null || d().completedAt is timestamp);
      }

      // C8 at the storage boundary: a live session cannot be born with anything logged.
      function noPrefillOnCreate() {
        return d().source == 'recalled'
          || (d().loggedSetCount == 0 && d().completedAt == null && d().durationSec == 0);
      }

      // A live session arrives empty; recalled and unplanned arrive already finished.
      // An unplanned session (a walk, a class) has no plan, no assignment and no sets.
      function createConsistent() {
        return d().source == 'live'
          ? (d().completedAt == null && d().endedReason == null)
          : d().source == 'recalled'
            ? (d().completedAt is timestamp && d().recallMethod in ['plan','history'])
            : (d().completedAt is timestamp && d().activity != null
               && d().sets.size() == 0 && d().durationSec > 0
               && d().get('planVersion', null) == null
               && d().get('assignmentId', null) == null);
      }

      // Provenance and single-writer identity are immutable; counters only grow;
      // completedAt is write-once.
      function immutableOk() {
        return d().get('planVersion', null) == prev().get('planVersion', null)
          && d().source       == prev().source
          && d().startedAt    == prev().startedAt
          && d().deviceId     == prev().deviceId
          && d().dateKey      == prev().dateKey
          && d().get('assignmentId', null) == prev().get('assignmentId', null)
          && d().get('workoutId',    null) == prev().get('workoutId',    null)
          && (prev().completedAt == null || d().completedAt == prev().completedAt)
          && d().loggedSetCount >= prev().loggedSetCount
          && d().sets.size() == prev().sets.size();
      }

      allow get:    if isOwner(uid);
      allow list:   if isOwner(uid) && request.query.limit <= 50;   // no unbounded scan, ever
      allow create: if isOwner(uid) && shapeOk() && noPrefillOnCreate() && createConsistent();
      allow update: if isOwner(uid) && shapeOk() && immutableOk();
      allow delete: if false;   // see OQ-14: G3 assumes an onDelete trigger; D1 makes deletes unnecessary
    }

    // ---------- NOT authored here ----------
    // G4 reads plans/{uid}/versions/*, plans/{uid}/assignments/*, users/{uid}/bests/*,
    // users/{uid}/checkins/{today} and the libraries. Those match blocks belong to their
    // owners and are integrated by G8 into this one file. G4's requirements on them:
    //   1. owner-only read on plans/**, bests/*, checkins/*          (no cross-user read)
    //   2. NO client write path to plans/** from any block            (version pinning, HANDOFF r2)
    //   3. NO client write path to bests/*  from any block            (R12's rule cannot be farmed)
    //   4. authenticated read on exercises/*, programs/* (+ workouts/* if OQ-1 is granted)
    // Stated as requirements precisely because a second `allow` block for the same path
    // would OR with the owner's and could grant what the owner denied.
  }
}
```

**Stated limitation, not a workaround:** the rules language has no iteration, so per-element validation
of `sets` (every `prescribedWeight` non-null, no actual pre-filled on create) **cannot** be expressed
above. It is enforced in three other places: the `loggedSetCount == 0` create guard (a proxy the client
cannot lie about without also lying about the counter, which rules pin to `sets.size()`), the
`validateSessionWrite` Cloud Function trigger, and `StartSessionUseCase.assertNoPrefill()` with
P1-RULE-01 as its executable test. Training is deliberately **not** gated on
`verification.status`: the research is explicit that an unverified visitor may see workouts and
exercise videos, and her own logs are hers.

---

## 7. Interface to the other groups

### 7.1 Consumed

| From | Path / surface | Contract |
|---|---|---|
| G1 | `request.auth.uid`, `users/{uid}` exists | read only |
| G2 | `plans/{uid}/assignments/{yyyy-MM-dd}` | **Contract now published by G2 §1.3 — I conform to it verbatim**, no longer a request. I read `workout.moves[]` in `order` and copy `prescribedReps` + `prescribedLoad` into my set fields. G2's fixed mapping: `kind:'kg'` → the number; `kind:'bodyweight'` → `0`; `kind:'seconds'` → `0` plus duration from `value`. I also read `title`, `minutes`, `quiet`, `equipment`, `weekIndex`, `planVersion`, `sessionTemplateId`. **Absence of the document means rest** — never an error, never a spinner. G2 writes no `actual*` key, ever. Two things R07/R08 need are **absent** from that contract: `progressionReason` (R07's "Last Tuesday: 10 kg × 10 … so we added 2 kg") and `lastActual` (R08's third chip) — see OQ-2. |
| G2 | `plans/{uid}/versions/{version}` | immutable; cache forever; R02's header |
| G3 | `users/{uid}/checkins/{today}` | read only, for R01's gentler-option row. Never alters a prescription. |
| G6 | `users/{uid}.rewards`, `users/{uid}/weeks/{yyyy-Www}`, `users/{uid}/bests/{exerciseId}` | read only; R01/R10/R12 render them, G4 never writes them |
| G8 | offline persistence (unbounded cache), connectivity stream, `deviceId`, the single `users/{uid}` ruleset, background-download channels, `library_version` bundle + CDN manifest, Amplitude wrapper | G4 emits screen ID + coarse outcome only; **never** weight, reps, or any measurement (spine §6) |
| G8 | **`lowData` flag** — G8 owns it ("user toggle **or** metered connection → ABR capped at 360p, no prefetch, no autoplay"); **G7's A03 hosts the toggle** | My `VideoPolicy` **consumes** that flag and applies it to the player rather than owning the mode. I withdraw any claim to the setting surface. |
| G8 | **`HealthChannel`** — `requestPermissions()`, `readSteps(day)`, `readWorkouts(range)`, `writeWorkout(session)` | G8 owns the platform channel; **G4 owns the domain mapping** from a confirmed proposal to a `source:'unplanned'` session. §4's detection row is mine at the domain layer, G8's at the channel. |
| content | `exercises/*` (+ proposed `workouts/*`) | bundled at build, invalidated by `libraryVersion` |

### 7.2 Published

**One thing:** `users/{uid}/sessions/{sessionId}`. Nothing else, anywhere.

**Contract to G6 — `SessionFinished`.** Derived **server-side** by the `onSessionCompleted` Cloud
Function on any write where `completedAt` transitions null → non-null, so G6 never depends on a client
call arriving:

```
SessionFinished {
  sessionId, uid, dateKey, isoWeek,           // isoWeek computed in Africa/Cairo
  source: 'live'|'recalled'|'unplanned', recallMethod, activity,
  endedReason: 'finished'|'abandoned',
  durationSec, loggedSetCount, planVersion, assignmentId|null,
  measuredSets: [ { exerciseId, actualWeight, actualReps, actualSeconds } ]  // empty when recalled
}
```

| G6 concern | Contract (reconciled against G6's own plan) |
|---|---|
| Week counting | **G6's plan is authoritative and I conform: G4 calls `WeekService.creditSession(session)` on finish**, which does one batched `increment(sessionsLogged)` + `arrayUnion(creditedSessionIds)` on `weeks/{key}`; G6's Function reconciles `sessionsLogged = creditedSessionIds.length` as the backstop. This supersedes my first draft, which had G6 deriving credit from a trigger alone. My guarantee in exchange: the **deterministic recall ID**, so a replayed offline write cannot double-credit. Credit fires when `completedAt != null && (loggedSetCount > 0 \|\| durationSec >= 600)` — which is what makes "ten minutes counts", a time-only class, and an *abandoned* session with real sets all count. |
| Points | G6 owns the numbers (`AwardTable.pointsFor()`): `'live'` → 30 (R10), `'recalled'` → 15 (R12). |
| Personal bests | Only when `source == 'live'`. `measuredSets` is empty for recalled and unplanned payloads, so a PB is unconstructible from them. `bests/{exerciseId}` is a deterministic id — no query, no index. |
| **Defect I am flagging, not working around** | G6's `AwardTable.pointsFor()` and `PersonalBestDetector.detect()` both key off **`source == 'recalled'`**. The spine gained `'unplanned'` after that was written, so **a logged walk currently falls through to the full 30-point award and into PB detection.** Both must test `source != 'live'`. See OQ-17. |
| Adherence | From `loggedSetCount` / `sets.size()`, i.e. non-null `actualReps` only. G6 need not read the `sets` array to count a week. |

**Requested of G6 (does not exist in the spine):** nothing on my side writes `bests`, but R10's
"two kilos more than your best" needs `bests/{exerciseId}` to carry `{ weight, reps, dateKey }`, and
`users/{uid}.rewards` to carry `{ points, level, pointsToNextLevel }` so R10/R12 render without
arithmetic in a widget.

**Handed to G3 — the exposed command G3's plan names.** `SessionRepository.logRecalled()` is the
published entry point for T02's two Save buttons (and `logUnplanned()` for its time chips and a
confirmed Health Connect / HealthKit proposal); both land on R12. G3 owns the T02 sheet and the day
state; G4 owns the command, the `source` decision, the deterministic ID, and the R12 screen. In the
other direction G4 **consumes** G3's `DayStateResolver` at R01/R03 so Home and Train never disagree
about today, and G3's `UndoableLog` / `LogCommandBus` for every log in the group.

**Personal-best eligibility, stated against the amended enum:** only `source == 'live'`. Both
`recalled` and `unplanned` carry an empty or copied `measuredSets`, so a PB is not merely discouraged
from those payloads, it is unconstructible.

**Handed to community (post-MVP):** R10's "Share the squat with your group" passes an intent
`{ exerciseId, actualWeight, actualReps }` only. No fan-out write leaves G4 (see §9).

**Consumed by the assistant (post-MVP):** `propose_swap` calls `SwapMoveUseCase`, which writes a
**today-only** swap into the session/draft and never touches `plans/**`.

### 7.3 Platform table for this group (§4 policy)

| Capability | Android | iOS | Fallback if absent |
|---|---|---|---|
| **Step/workout detection** (§4 row — **channel G8's, domain mapping mine**) | Health Connect (`androidx.health.connect`), `StepsRecord` + `ExerciseSessionRecord`; Android 14+ has it in the OS, 9–13 needs the HC app; Play requires a Health Connect declaration | HealthKit `HKQuantityTypeIdentifierStepCount` + `HKWorkoutType`, `HKObserverQuery`, `NSHealthShareUsageDescription` | G8's `HealthChannel` provides it; my `ActivityImportUseCase` turns a **confirmed** proposal into a `source:'unplanned'` session. Both platforms degrade identically (G8's wording): absent or refused → **no step surface at all**, never a zero that reads as failure, and credit comes from T02's "a class or a walk — counts by time alone". A detected activity is **always a proposal with one confirming tap**, never a silent log (research §5 reframe). G8's channel exposes `writeWorkout(session)`; G4 **chooses not to call it** at MVP, so the parity gap is a decision, not an oversight. |
| Rest timer while backgrounded (R09) | foreground service or scheduled notification | local notification scheduled at `restEndsAt` (iOS grants no background timers) | Timer is recomputed from `restEndsAt` on resume, so accuracy never depends on the process staying alive. |
| Background video download (F23) | WorkManager + progressive-MP4 HTTP download | `URLSession` background configuration | Downloads resume; queue survives a kill. |
| Keep screen on during a session | `WakelockPlus` / `FLAG_KEEP_SCREEN_ON` | `isIdleTimerDisabled` | Released on `finished`/`abandoned`. |
| Adaptive-bitrate cap (low-data mode) | ExoPlayer track selection `maxVideoHeight` | `AVPlayerItem.preferredMaximumResolution` + `preferredPeakBitRate` | Both implemented; one `VideoPolicy` decides, the channels only obey. |

---

## 8. Video — the money question

### 8.1 Two traffic classes, which is why the estimate has a range

| Class | What | Per item | Where |
|---|---|---|---|
| A — demo loops | 124 moves × ~24 s (R04 shows `0:24`) | 1–2 MB at 540p | R04, R05, R07 thumbnails |
| B — follow-along / workout videos | 10–20 min | 26–80 MB depending on rendition | R06, R11, R02 |

A **self-guided** session (R03→R07→R09) streams class A only: 5 moves × ~1.5 MB ≈ **8 MB**.
A **follow-along** session streams class B: **26–80 MB**.

### 8.2 Ladder (fixed camera, single subject, low motion — CRF-capped VBR, H.264 High, AAC 48 kbps mono)

| Profile | Resolution | Measured video rate | MB / 15-min session | Served when |
|---|---|---|---|---|
| 240p | 426×240 | ~0.20 Mbps | ~28 MB | hard cap on a stalling cellular link |
| 360p | 640×360 | ~0.35 Mbps | **~39 MB** | **low-data mode default (cellular)** |
| 540p | 960×540 | ~0.70 Mbps | ~79 MB | Wi-Fi default |
| 720p | 1280×720 | ~1.30 Mbps | ~146 MB | Wi-Fi, large screen, explicit |
| MP4-offline | 640×360 or 960×540 | same as above | 39 / 79 MB | download-for-offline (see 8.4) |

§3's "~40 MB adaptive" corresponds to **360p for a 15-minute session**, which is exactly the low-data
profile. H.264 rather than AV1/HEVC because F76 targets budget Android hardware decoders.

### 8.3 Egress, three ways, and the recommendation

§3's arithmetic reproduced: 35,000 actives × 2 sessions/week × 4.33 weeks × 40 MB ≈ **12.1 TB/month**
(the brief says ~11 TB; I plan against 12). With the class A/B mix at 50/50 the realistic figure is
**~7.2 TB**; if 540p became the default everywhere it would be **~24 TB**. I size for 24 TB.

| Architecture | 12 TB egress | Storage | Notes |
|---|---|---|---|
| Firebase Storage **direct** | ~**$1,352/mo** ($0.12/GB) | $1.04 (40 GB) | What §7 of the brief forbids ("not straight out of Storage"). Rejected. |
| Cloudflare **Stream** | ~**$2,750/mo** (2.75M delivered minutes × $1/1,000) | $6.20 (1,240 min × $5/1,000) | Per-minute delivery pricing is *worse* than raw egress at this volume. Rejected. |
| Bunny.net CDN in front of Storage | **$240–720/mo** ($0.02–0.06/GB, Middle East & Africa) | $1.04 | Viable fallback, priced in. |
| **Cloudflare R2 + Cloudflare CDN** ✅ | **$0** — R2 has no egress charge, and R2-origin delivery is the compliant path for video through Cloudflare (no Business plan required) | 50 GB × $0.015 = **$0.75/mo** | **Recommended.** |

**G8 reached the same conclusion independently**, which is the strongest evidence this is right: its
plan states "media on Cloudflare R2 + CDN, **never** Firebase Storage egress", prices the same 11 TB
at **~$5/month**, and warns that "any group that reaches for a Firebase Storage download URL for
video has broken the budget". G4 conforms. **One disagreement remains:** G8 specifies "HLS ABR from
R2/CDN with **short-lived signed URLs**"; I argue below for immutable public URLs, because signing
defeats edge caching and makes a downloaded file unplayable once its URL expires. See OQ-18.

**Recommended architecture:** immutable, content-addressed objects in R2, served by Cloudflare CDN at
`https://cdn.<domain>/v/{libVersion}/{assetId}/{profile}/index.m3u8`, with
`Cache-Control: public, max-age=31536000, immutable`. The version lives **in the path**, so the library
is invalidated by bumping `libVersion` in Remote Config and there is never a purge — purges are the
usual way a video CDN goes wrong. Posters are 640 px AVIF (~30 KB, ~4 MB for all 124) bundled with the
app, so R01 and R11 render their lists with zero network. Encoding is a Cloud Run ffmpeg job triggered
on upload: 124 titles × 4 renditions + 1 offline MP4 ≈ **$15 one-off**. User media (community photos,
voice notes) stays on Firebase Storage — small volume, different access rules.

**No DRM and no signed URLs at MVP.** The library is not secret (unverified visitors may see it), and
signing defeats edge caching. If the owner ever gates video behind a subscription, the change is token
auth on a path prefix — priced and named in OQ-8, not discovered later.

### 8.4 Download-for-offline and low-data mode

- **Stream HLS, download progressive MP4.** Offline HLS requires ExoPlayer `DownloadManager` on Android
  and `AVAssetDownloadTask` (`.movpkg`) on iOS — two native stacks that Flutter's `video_player`
  exposes on neither. One extra MP4 rendition per title (+11 GB storage = **$0.17/mo**) makes F23 a
  plain HTTP download and a file-URI playback that works identically on both platforms. This is the
  decision that keeps download-for-offline shippable rather than aspirational.
- **R02 is the download surface** (its app bar already carries a download action): "save this week"
  fetches the week's distinct assets — 3 workouts ≈ 120 MB at 360p, 240 MB at 540p. Eviction keeps the
  current and next week and never evicts a running session's assets.
- **Low-data mode is a launch state, not a setting.** `VideoPolicy.resolve(connectivity, userPref,
  downloadState)` returns `{maxHeight, allowPrefetch, allowAutoplay}` and is the *only* place the
  decision is made. On cellular: 360p cap, no prefetch, no autoplay, posters instead of loops, and
  R06's follow-along offers "download it first" before it streams. On Wi-Fi: 540p and the day's 5 demo
  loops prefetch (~8 MB).
- **Why optimise traffic that costs us nothing?** Because egress is free to us and expensive to *her*.
  At Egyptian prepaid rates (~EGP 100 / 10 GB), a 40 MB session is ~EGP 0.40 and a three-session week
  ~EGP 1.20; at 540p it is three times that. Low-data mode and downloads protect her bill, not ours —
  which is why they are launch requirements in Egypt and why the setting is not buried in A02.

### 8.5 Cost envelope — G4's monthly figure

| Line | At 35,000 DAU | At 3× |
|---|---|---|
| Video egress (R2 + Cloudflare) | **$0** | $0 |
| Video storage (50 GB incl. offline MP4s) | $0.75 | $0.90 (library growth) |
| Firestore reads + writes + storage | $6 | $18 |
| Encoding (amortised) | ~$1 | ~$1 |
| **G4 total** | **≈ $8/month** | **≈ $20/month** |
| If the owner rejects R2 and serves from Storage | **≈ $1,360/month** | ≈ $4,000/month |

This is the line the reconciliation log is waiting on: it lists G1 identity (~$2.6k–8.5k in provider
fees) as the largest operating expense and "video egress (G4, not yet reported)" as the other. **The
answer is that video is not the other — it is ~$1 of storage, because the egress is zero-rated.** The
heaviest cost line in the business turns out to be the cheapest one to fix, and identity verification
stands alone as the expense that matters.

**Ceiling G4 commits to: under $50/month at 35,000 DAU, and under $150/month at 100,000 DAU.** The
architecture is justified against it by a single fact: the heaviest cost line in the business is
zero-rated at the origin, so the video budget is dominated by storage of 124 titles — a number that
does not scale with users at all. Peak load is ~**89 Mbps average / ~300 Mbps at the 20:00 spike**
(4,000 sessions × 40 MB over 4 hours), which is unremarkable for any CDN.

---

## 9. Scalability gate — self-check

| Gate | Result | Evidence |
|---|---|---|
| **Unbounded collection scan** | **PASS** | Every query is a document `get`, a bounded `dateKey` range (≤7 docs), or `limit 1`. The 124-item library is filtered **client-side from a bundle**, so R11 — the one screen that looks like a search — issues no query at all. Rules cap `list` at `limit <= 50`, so even a compromised client cannot scan. |
| **Per-user fan-out write that grows with followers** | **PASS** | G4 writes exactly one path: `users/{uid}/sessions/{sessionId}`. Zero fan-out. R10's share action hands an intent to the community group and writes nothing itself. Week credit is one `increment` on one week document. |
| **Unindexed query on a hot path** | **PASS** | Two single-field indexes, both automatic (`dateKey`, `completedAt`). **Zero composite indexes.** The design that *would* have needed one — `array-contains(exerciseIds) + orderBy(completedAt)` to find her last performance — is explicitly rejected in favour of `assignment.lastActual` authored upstream (§7.1). Plus a deliberate index *exemption* on `sets`. |
| **Migration needed to reach 100k MAU** | **PASS** | No sharding, no counter documents, no collection-group queries. Session docs are ~5 KB against a 1 MiB limit with ≤60 sets. IDs are UUIDv4 under per-user paths, so no sequential-key hotspot. Storage grows 4.3 GB/month (~$9/mo after a year) with no archive needed. The video tier is identical at 10× library size. The only shape change I would *want* later — `sets` as a map instead of a list — is raised now as OQ-7, precisely so it is not a migration. |

---

## 10. Test cases G4 is accountable for

**P0 — owned outright**

| ID | Screens | What it pins |
|---|---|---|
| `P0-LOG-01` | R07, R09 | one tap logs a set; rest timer self-starts; snackbar names the same numbers, with Undo |
| `P0-LOG-02` | R09, R07 | undo inside 5 s; no dialog at any point (and, per D1, nothing ever reached the server) |
| `P0-LOG-03` | R07, R13 | whole move in one tap; returns to the move list; **session does not end** |
| `P0-LOG-05` | R08 | change a value with chips, two taps, no keyboard; a hard set never lowers her weight |

**P0 — shared, G4 owns the named half**

| ID | Screens | G4's half |
|---|---|---|
| `P0-ONB-03` | O02, O05, **R03** | **New in the amended suite.** G2 owns the intake and the prescription; G4 owns R03 rendering it — no move requiring absent equipment ever appears in the day list, and R05's swap candidates are filtered by the same `equipment` constraint. |
| `P0-LOG-04` | T01, T02, **R12** | the recall use case, `source: 'recalled'`, fewer points, and "no personal best" — G3 owns the T02 sheet |
| `P0-LOG-09` | T01, E01, **R07** | a set logged in airplane mode appears instantly, syncs once, no duplicate |
| `P0-NAV-01` | all in-scope | tap depth for R01–R13 (R05/R08/R09 are depth-3 mid-workout states and correct by design) |
| `P0-A11Y-01` | all in-scope | Arabic RTL on R01–R13; `play`, `skip`, `swap`, `chevron` mirror; Western numerals in "12 kg × 10" |
| `P0-WEEK-01` | T01, P01 | contributing only — the `SessionFinished` week-credit contract in §7.2; G6 owns the ID |

**P1**

| ID | Screens | G4's accountability |
|---|---|---|
| `P1-RULE-01` | G06, **R07** | every "you did" field empty; no actual ever pre-populated; adherence counts logged sets only. The executable form of §5 row 1 (G06 is the coached variant, shared with that group). |
| `P1-RULE-09` | **R07**, **R09**, E04, T02 | no logging action in the train feature raises a confirmation dialog; every one carries a 5-second undo |
| `P1-RULE-03` | T01/T04/T05/P01/T07 | no screen of mine, but the schema obligation is mine: no day counter exists in `sessions` (C6) |
| `P1-RULE-11` | M01/M06/M07/P01 | likewise: the `sets` index exemption means no weight index exists to sort on (C7) |

**P2 (mine by screen, listed so the omission is not silent):** `P2-RTL-R01…R13`, `P2-TXT-R01…R13`,
`P2-OFF-R07`, `P2-OFF-R08`, `P2-OFF-R09`, `P2-ERR-R07`, `P2-ERR-R08`, `P2-ERR-R09`.

**Checked against the amended suite (196 cases — 31 P0, 11 P1, 154 P2).** Two P1s were strengthened in
a way that lands directly on this plan, and I welcome both: `P1-RULE-03` now searches "every in-scope
screen, **and the schema**, for a consecutive-day counter", which is exactly the C6 obligation in §5;
and `P1-RULE-11` now inspects "**the index configuration**" and asserts "the composite index that
would allow it is absent", which is precisely what the `sets` field exemption in §1.2 delivers. Both
are now mechanically checkable rather than matters of good intent.

**A coverage gap I am naming rather than inheriting.** The spine was amended mid-planning to add
`source: 'unplanned'` so that T02's "a class or a walk" and F15's detected walk would have somewhere
to live — and **no P0 or P1 case exercises that path.** A grep of the suite for walk, class, unplanned
or detected returns only an incidental match. The ledger's "no coverage gaps" is true per *screen*
but not per *path*: the newest thing in my schema is the least tested thing in the product. Proposed,
for whoever owns the suite: **`P0-LOG-12` — "Log a class by time alone"** (precondition: no session
today; steps: T02 → tap a time chip → Save; expected: a `source:'unplanned'` session with `sets: []`,
week credit applies, **15 points not 30**, no personal best, `planVersion`/`assignmentId` null).
That case would also have caught OQ-17 on its own.

**Tests this plan adds, because a rule with no failing test is a wish:** `session_schema_no_streak_test`,
`no_dialogs_in_train_test`, `change_set_never_writes_prescription_test`,
`start_session_asserts_no_prefill_test`, `recalled_session_is_pb_ineligible_test`,
`undo_never_issues_a_firestore_write_test`, `sets_field_index_exemption_deployed_test`.

---

## 11. Open questions

| # | Question | Why it matters | My working assumption |
|---|---|---|---|
| OQ-1 | **Is "124" moves or workouts?** The spine calls `exercises` "the 124-move library", but R01 says "All workouts · 124 videos" and R11 says "Search 124 workouts" with rows that are clearly session templates (`Floor legs, no jumping · 10 min · beginner · Nour`). | R11, R01's short sessions and R06 need a workout-level entity; `exercises` cannot hold a coach name and a duration. | I need a read-only `workouts/{workoutId}` library (content pipeline, bundled), referencing `exerciseId`s. **This is a requested addition to the spine's library list, not a change to its paths.** If refused, R11 must be re-modelled onto `programs/{programId}`. |
| OQ-2 | **Half resolved, half open.** The assignment *shape* is settled — G2's plan §1.3 publishes it and I conform verbatim. Still open: **nobody authors progression provenance.** G2's document has no `progressionReason` and no `lastActual`, yet F11 "Automatic progression" is filed under *Today and logging* with screen R07 (mine), and `prescribedWeight` lives in `plans/**`, which only G2 and Cloud Functions may write. | Without them, R07's sage note ("Last Tuesday: 10 kg × 10 … so we added 2 kg") and R08's third chip ("what she did last time") have **no authored source**, and the only client-side way to get them back is the `array-contains + orderBy` query I rejected at the scalability gate. | Add both to G2's `workout.moves[]`, written by whichever function resolves the prescription. If G2 declines, the R07 sentence and R08's third chip must be cut from the MVP rather than recovered with a composite index. **Blocks F11. Needs G2 + spine owner before Stage 3.** |
| OQ-3 | ~~`assignmentId` non-nullable~~ — **RESOLVED by the spine amendment** made during planning: `planVersion` and `assignmentId` are now nullable. | Three logging paths (R11's library workout, T02's time chips, a Health Connect proposal) produce off-plan sessions. | Adopted. My schema and rules treat both as nullable, and `createConsistent()` *requires* them to be null when `source == 'unplanned'`. |
| OQ-4 | ~~`source` has no value for a detected activity or a time-only class~~ — **RESOLVED by the spine amendment**: `source` gains `'unplanned'` and an `activity?` field, which G3 raised as its blocking Q1 too. | T01's "Count it" and T02's time chips had nowhere to live. | Adopted in preference to my own `recallMethod: 'detected'\|'timeOnly'` workaround, which I have withdrawn — `recallMethod` now narrows to `'plan'\|'history'`. One shared spine value beats two groups' extensions. |
| OQ-5 | **C8 says "adherence counts non-null `actualReps` only", but R03 prescribes "3 × 30 seconds" — and G2's contract writes `prescribedReps: null` for `kind:'seconds'`.** The amendment made this sharper, not softer: a timed move now has no prescribed reps *and* no actual reps. | Read literally, every follow-along and every hold scores zero adherence, and R06 — the screen whose whole promise is "logs itself" — would log nothing that counts. | I keep `actualReps` as the single adherence marker and write it for timed sets too (the completed hold counts as its rep), alongside `actualSeconds`, so C8's sentence stays literally true. The cleaner fix is one clause in C8 admitting `actualSeconds`. **Flagged, not worked around — owner's call.** |
| OQ-6 | **Three documents now disagree in wording.** The spine's §1 says `prescribedWeight` is *nullable* for bodyweight and timed moves (amended); **C8's own text, eight lines later, still says it is non-null**; and G2's published contract writes `0` with `prescribedLoad.kind: 'bodyweight'`. | Not cosmetic: a reader implementing from C8 writes a non-null field, a reader implementing from §1 writes null, and they disagree about what "no load" looks like in the same array. | I accept **either** on read and render both as "bodyweight", never "0 kg" (G2's §9 Q6 asks me to confirm exactly this — **confirmed**). Adherence never divides by the load. **Requesting that C8's sentence be amended to match §1, so the spine stops contradicting itself.** |
| OQ-7 | **`sets` as a list forces a whole-array rewrite per flush**, because Firestore has no field path to an array element. | It is safe only under the single-writer guard in §4.2. A map keyed by `setIndex` would allow true field-level merges, matching C3's own merge reasoning. | I implement the list as written, plus the `deviceId` guard. Requesting a spine ruling on the map form — asked **now** so it never becomes a migration. |
| OQ-8 | **Is the video library free, or behind a subscription?** | Public immutable CDN URLs are what make caching, offline files and the $0 egress line true. Signed URLs would undo all three. | Free at MVP (the verification research says unverified visitors may see workouts). If gating is coming, say so before the CDN contract. **Coupled to OQ-18** — the commercial answer decides the technical one. |
| OQ-9 | Does a **paused** session survive a change of device? | `deviceId` is immutable, so today it does not: the other device starts a new session. | Accepted as correct (one body, one phone, one workout). Confirm. |
| OQ-10 | **Abandonment threshold and its week credit.** | I propose: auto-abandon after 6 h with no set, and an abandoned session with `loggedSetCount > 0` still counts toward the week ("ten minutes counts"). | Owner to confirm 6 h and the credit. It determines whether a woman interrupted at set 4 sees her week move. |
| OQ-11 | **Health Connect is an owner-track dependency.** Android 9–13 needs the Health Connect app installed, and Play requires a Health Connect declaration form plus review. iOS write-back of a finished session as an `HKWorkout` is deferred. | §4 forbids shipping one platform a capability the other silently lacks. | Read-only on both sides at MVP, the manual time-chip fallback on both, and the write-back parity gap named rather than shipped one-sided. |
| OQ-12 | The UX review's MAJOR 12/13 fixes appear **already applied** in `screens-train.mjs` (R07 → R13, T02 → R12), but MAJOR's R01 finding is not: R01's "Continue — from Sara" still routes to `G06`, the coached screen, for every user. | It decides which screen actually starts a G4 session for a woman with no coach. | Not mine to fix; it changes my entry point, so Stage 3 needs the default (non-coached) variant of R01 to route to R03. |
| OQ-13 | §3 says ~11 TB/month; the same inputs give me 12.1 TB, and the class A/B mix gives 7.2 TB while a 540p default gives 24 TB. | It is the single heaviest cost line, so the figure should be one number everyone uses. | I plan against **12 TB** and size the CDN for **24 TB**. Both are $0 egress on the recommended tier, so the choice is not load-bearing — but the brief's number should be corrected to 12. |
| OQ-14 | **G3's optimistic week credit assumes a Cloud Function on `sessions` create **and delete**; my rules say `allow delete: if false`.** | If undo of a recalled session is expected to delete the document, my rules break G3's design; if it is not, G6 should not write an `onDelete` trigger that can never fire. | Resolved my way, needing G3/G6's agreement: **D1 puts the 5-second undo ahead of the write**, so an undone recall never reaches Firestore and no delete is ever required. `onCreate` alone is sufficient. Deletion stays function-only for account deletion (A02). **Confirm with G3 and G6 before Stage 3.** |
| OQ-15 | **G2's contract says `frozen` is "set true when G4 starts a session on this date" — but `plans/**` is G2-write-only and my own rules deny it.** | Two groups writing one field is a rejected plan by the spine's own §2, and version pinning (HANDOFF r2) depends on the flag actually being set. | G4 does not write it. Either the `onSessionCreated` Cloud Function sets `frozen`, or G2 exposes a command and owns the write. My session already pins `planVersion` at start, so correctness does not depend on the flag — only G2's guarantee not to rewrite that date does. **G2 + spine owner to pick one.** |
| OQ-16 | **How does G3 find today's *live* session "via the assignment + arc, never a scan"?** Recalled and unplanned sessions have deterministic IDs, so G3 can `get` them. A live session's ID is a UUIDv4 that only G4's local draft knows. | G3's `inProgress` day state depends on reading `completedAt`/`source` of today's session without a query, and it lists that dependency as "exists". | Either G4 also derives the live ID deterministically (`live-{dateKey}-{assignmentId}`, which would forfeit the ability to train the same plan twice in one day), or G3 consumes `DayStateResolver` from G4's local draft instead of Firestore. I prefer the second. **Needs G3's agreement — as written, its "exists" is not yet true.** |
| OQ-17 | **G6 suppresses points and personal bests on `source == 'recalled'`, which no longer covers every non-measured case.** `'unplanned'` entered the spine after G6's plan was written, so as specified today a logged walk or studio class awards the **full 30 points instead of 15** and is passed to `PersonalBestDetector`. | It silently breaks two §2-adjacent promises at once — the reward economy ("points only for goal-moving behaviour, capped") and R12's rule that copied numbers never set a best. It is also the single cheapest bug to fix in this whole set. | Change both `AwardTable.pointsFor()` and `PersonalBestDetector.detect()` to test **`source != 'live'`**. I have written my own `PersonalBestEligibility` that way already. **G6 to confirm; the proposed `P0-LOG-12` would catch it in CI.** |
| OQ-18 | **Signed URLs or immutable public URLs for video?** G8's plan specifies "HLS ABR from R2/CDN with short-lived signed URLs"; my §8.3 specifies content-addressed public URLs with `max-age=31536000, immutable`. | Three consequences, not one: a signed URL is unique per request so the **edge cache hit rate collapses** (and with it the $0-egress argument that both our plans depend on); a **downloaded offline file becomes unplayable** when its signature expires, which breaks F23; and signing buys nothing today because the library is content the research says unverified visitors may see. | Public immutable URLs for the **library**, signed URLs reserved for user-generated media (where G8 is right). If the owner gates video commercially (OQ-8), revisit with token auth on a path prefix and accept the cache cost knowingly. **G8 + owner to settle before the CDN contract.** |
| OQ-19 | **Who adds the missing `unplanned` test case, and does the suite's "no coverage gaps" claim get restated per path rather than per screen?** | The path the spine was just amended to support has no P0/P1 coverage (§10). A screen-based completeness claim will keep hiding path-based gaps as the schema grows. | I have drafted `P0-LOG-12` in §10 for whoever owns `scripts/build_testcases.py`. G4 will implement against it either way. |
