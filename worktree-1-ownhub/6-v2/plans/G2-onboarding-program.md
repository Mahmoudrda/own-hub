# G2 — Onboarding & program selection

Screens: `O01` Her goal, `O02` Where and with what, `O03` Days and minutes, `O04` Life stage,
`O05` Your starting program. Owns `plans/**` (published plan + dated assignments).

Costed against `BUILD-BRIEF.md` §3: 35,000 DAU, ~8 reads / ~6 writes per active day
(~280k reads / ~210k writes a day), 40% of traffic 19:00–23:00 Cairo.

Spine compliance: paths, field names and the eight constraints are used verbatim. Extensions are
confined to `plans/{uid}/versions/*`, `plans/{uid}/assignments/*` and named fields inside
`users/{uid}.profile` (G2's own map per the ownership table). Conflicts are in §9, not worked around.

---

## 1. Data model

### 1.1 `users/{uid}.profile` — G2's map inside G1's document

| Field | Type | Written by | Source screen | Notes |
|---|---|---|---|---|
| `goal` | string enum `stronger` \| `feel_better` \| `lose_steadily` \| `back_into_it` | client (owner) | O01 | Default `stronger` (O01 preselects it) |
| `place` | string enum `home` \| `ladies_gym` \| `both` | client | O02 | Default `home` |
| `equipment` | array<string enum `none`\|`mat`\|`dumbbells`\|`bands`> | client | O02 | Default `['none']` |
| `days` | int 2–5 | client | O03 | Default 3 (`chipRow(['2','3','4','5'], 1)`) |
| `sessionLength` | int minutes 10\|15\|20\|30 | client | O03 | Default 15 |
| `lifeStage` | string enum `none` \| `postpartum` \| `pregnant` \| `pain_injury` | client | O04 | Default `none`. Private; drives the safety filter |
| `allergies` | array<string foodTagId> | client | **no screen in the cut — §9 Q1** | Consumed by G5. Safety-critical |
| `dietary` | array<string enum> | client | **no screen in the cut — §9 Q1** | Consumed by G5 |
| `language` | `en` \| `ar` | client (G8 sets) | C02 | G8's write, listed for completeness |
| `intake` | map `{ status, lastStep, completedAt, intakeHash }` | client | O01–O05 | State machine §3.2 |
| `activePlanVersion` | string | **Function only** | O05 | Pointer every other group reads |
| `planPublishedAt` | timestamp | **Function only** | O05 | |
| `horizonThrough` | string `yyyy-MM-dd` | **Function only** | O05 / top-up | Last materialized date |

Field-level writer split inside one map is deliberate and is enforced in rules (§6). No field named
`streak` and no consecutive-day counter exists here or anywhere in `plans/**` (C6). No `targetWeight`,
no weight of any kind (C7, §2 rule 11) — `lose_steadily` is a goal string, never a number.

### 1.2 `plans/{uid}/versions/{version}` — immutable once published

Document id: `v1`, `v2`, … monotonic. Server-authored (spine §5).

```jsonc
{
  "version": "v1",
  "status": "published",              // draft | published | superseded | discarded  (§3.1)
  "source": "self_serve",             // self_serve | coach | split   ← coach path, unused in MVP
  "authorUid": "<uid>",               // the woman herself in MVP; the coach's uid later
  "templateRef": null,                // splits/{splitId} when source == 'split'  (HANDOFF r12)
  "programId": "beginner_foundations",
  "effectiveFrom": "2026-09-21",      // revisions never precede today (HANDOFF r2)
  "supersedes": null,                 // "v1" on a revision
  "supersededBy": null,
  "intakeHash": "sha256:…",           // idempotency key (§4)
  "weekPattern": { "1": "full_body_a", "2": "legs_glutes", "4": "upper_body" },  // ISO weekday → template
  "weeks": 8,
  "daysPerWeek": 3,
  "sessionLength": 15,
  "publishedAt": "<ts>",
  "publishedBy": "fn:publishStartingPlan"
}
```

### 1.3 `plans/{uid}/assignments/{yyyy-MM-dd}` — the dated contract G3/G4/G5 read

Document id is the Cairo-local date (C1 — deterministic, so a retry is idempotent).
**A training day has a document; a rest day has none.** Absence is the rest state, which keeps the
collection at ~3 docs/week instead of 7 and leaves T01's read at 1 either way.

```jsonc
{
  "planVersion": "v1",
  "programId": "beginner_foundations",
  "weekIndex": 1, "isoWeek": "2026-W39", "dayIndex": 2,
  "kind": "workout",
  "workout": {
    "sessionTemplateId": "legs_glutes",
    "title": "Legs and glutes",          // T01/R03 app-bar title
    "minutes": 15, "place": "home", "quiet": true, "equipment": ["none"],
    "moves": [
      { "exerciseId": "glute_bridge", "order": 1, "sets": 3, "prescribedReps": 12,
        "prescribedLoad": { "kind": "bodyweight", "value": 0 }, "perSide": false },
      { "exerciseId": "goblet_squat", "order": 2, "sets": 3, "prescribedReps": 10,
        "prescribedLoad": { "kind": "kg", "value": 12 }, "perSide": false },
      { "exerciseId": "hip_thrust_hold", "order": 4, "sets": 3, "prescribedReps": null,
        "prescribedLoad": { "kind": "seconds", "value": 30 }, "perSide": false }
    ]
  },
  "meal": null,                          // coach-planned meals only; null through the MVP (§7)
  "prescribedResolvedAt": "<ts>",
  "materializedAt": "<ts>",
  "materializedBy": "fn:ensurePlanHorizon",
  "frozen": false                        // set true when G4 starts a session on this date
}
```

**C8 is honoured by omission**: there is no `actualWeight`, `actualReps`, `done`, `completed` or
`adherence` key in this document, and the materializer asserts their absence. Actuals exist only in
G4's `sessions/*`. `prescribedLoad.kind` carries `bodyweight` explicitly so no widget renders "0 kg"
(see §9 Q6).

### 1.4 Indexes

| Collection | Index | Why |
|---|---|---|
| `plans/{uid}/assignments` | `__name__` (automatic) | date-keyed range for a week; no composite |
| `plans/{uid}/versions` | `__name__` (automatic) | direct get by pointer; no listing on a hot path |
| `programs` | **none** | never queried — loaded in-memory, §2.6 |

**Composite indexes required: none.** Every read is a document get or a `__name__` range, matching
spine §4.

---

## 2. Query per screen, with index and cost

`U` = `users/{uid}` document, already in cache from G1's sign-in bootstrap → counted 0 here.

| Screen | Read | Index | Reads | Write | Writes |
|---|---|---|---|---|---|
| O01 | none (draft held locally; `U` cached) | — | 0 | `set(users/{uid}, {profile.goal}, merge)` | 1 |
| O02 | none | — | 0 | `set(…, {profile.place, profile.equipment}, merge)` | 1 |
| O03 | none | — | 0 | `set(…, {profile.days, profile.sessionLength}, merge)` | 1 |
| O04 | none | — | 0 | `set(…, {profile.lifeStage}, merge)` | 1 |
| O05 | callable `publishStartingPlan` returns the version + week payload; card renders from the bundled catalogue | — | 0 | server: 1 version + 3 assignments + 1 profile pointer | 5 |
| O05 (offline) | bundled catalogue only | — | 0 | queued intent in `users/{uid}/syncQueue/{opId}` (G8, local-only) | 0 |
| R02 / week strip (consumer surface) | `assignments` where `__name__` in [weekStart, weekEnd] | `__name__` | 3–4 | — | 0 |

**Why a write per step instead of one write at the end:** every O screen carries `Skip` and a close
(`X` → T01), so abandonment is a designed path. Per-step merge writes to one deterministic document
keep partial intake, are commutative on distinct field keys, and are offline-safe. Four extra writes
happen once in a lifetime.

### 2.1 Once-per-lifetime vs per-active-day

| Bucket | Reads | Writes | Frequency |
|---|---|---|---|
| Intake O01–O04 | 0 | 4 | once |
| Publish O05 (server) | 1 | 5 | once |
| Weekly horizon top-up | 3–4 | 3–4 | once per user per week |
| **G2 share of a steady active day** | **~0** | **~0.5** | assignment reads are already inside T01's 4 (spine §4) |

### 2.2 Daily totals at §3 scale

Assume 3,000 new verified women/day (aggressive for 100k MAU).

| Item | Per day | Share of budget |
|---|---|---|
| Onboarding writes | 3,000 × 9 = **27,000** | 12.9% of 210k |
| Horizon top-up writes | 35,000 ÷ 7 × 3.5 ≈ **17,500** | 8.3% of 210k |
| G2 reads (O05 + week strips) | ≈ **12,000** | 4.3% of 280k |
| **G2 total** | **44,500 writes / 12,000 reads** | **21.2% writes, 4.3% reads** |

### 2.3 Peak (40% in 4 hours)

Writes 44,500 × 0.4 ÷ 14,400 s ≈ **1.2 writes/s**; callables ≈ **0.1/s**. Both are three orders of
magnitude below Firestore's per-collection ceiling, and no two writes contend on one document: every
write is to a distinct `uid` subtree or a distinct date key.

### 2.4 Cost envelope

Indicative Firestore pricing ($0.18/100k writes, $0.06/100k reads), Functions inside the 2M free
invocations: G2's marginal spend is **~1.34M writes and ~0.36M reads a month ≈ $2.60/month**, plus
~240k invocations ≈ $0. G2 is not a material line in the budget; video egress (~11 TB/month) is, and
it belongs to G4. G2 adds **zero** video egress — O05 shows one still, not a video.

### 2.5 Program generation: client, Function, or lazy per day?

**Decision: in a Cloud Function, materialized one ISO week at a time.** Not the client, not per day.

| Option | Verdict |
|---|---|
| Client-generated | **Rejected.** Spine §5 makes `plans/**` server-authored and rules deny client writes. A client that can write its own plan can also write its own prescribed weights, and rule 2 becomes unenforceable. |
| Whole program up front (8 weeks × 3 = 24 docs) | **Rejected.** 72,000 writes/day at 3,000 signups (34% of budget) and it freezes week 8's prescribed weights against week 1's data. |
| Lazy per day, on read | **Rejected.** Puts a Function on T01 — the hottest screen at 19:00–23:00 — and breaks offline: tomorrow's session would not exist on a microbus. |
| **One ISO week at a time, topped up at the week boundary** | **Chosen.** 3–4 writes per user per week (17.5k/day, 8%). The current week is fully cached for offline. Progression resolves on the Monday, when last week's logs are complete — which is also what "weeks, not days" (rule 3) means arithmetically. |

Top-up trigger is **client-initiated, server-executed**: the app calls `ensurePlanHorizon` when its
cached `horizonThrough` is less than 7 days out. There is no scheduled sweep over `users` — that
would be the unbounded scan the gate forbids.

### 2.6 The `programs` catalogue is never queried

`programs/{programId}` is immutable content (~12–20 documents). It is bundled with the app and loaded
into the Function's memory at cold start, stamped with a Remote Config version (spine §4). Selection
is a pure in-memory filter, so there is no Firestore query, no composite index and no scan. Threshold:
if the catalogue ever exceeds ~200 programs, selection moves to a served index — not before.

---

## 3. State machines

### 3.1 Plan version — draft / published / superseded

```
                 (coach only, post-MVP)
  ┌──────────────────────────────────────┐
  │                                      ▼
(none) ──publishStartingPlan──►  PUBLISHED  ──another publish──►  SUPERSEDED  (terminal)
  │                                  ▲
  └──draftPlan──►  DRAFT  ──publish──┘
                     │
                     └──discard──►  DISCARDED  (terminal)
```

| From | To | Trigger | Guard | Effect on `assignments` |
|---|---|---|---|---|
| none | PUBLISHED | `PlanPublisher.publish` (self-serve, O05) | intake resolvable; no prior published version with same `intakeHash` | materialize current ISO week forward |
| none | DRAFT | `PlanDraftService.create` (coach/assistant) | author is the client's coach | none |
| DRAFT | PUBLISHED | `PlanPublisher.publish` | explicit human act; every day resolvable | materialize dates ≥ max(today, `effectiveFrom`) only |
| DRAFT | DISCARDED | `PlanDraftService.discard` | — | none |
| PUBLISHED | SUPERSEDED | side effect of the next publish, same transaction | new version's `effectiveFrom` ≥ today | **past and in-flight dates are never rewritten** |
| PUBLISHED | PUBLISHED | — | **illegal.** Content is immutable; only `status`/`supersededBy` may change | — |
| SUPERSEDED | any | — | **illegal** (terminal) | — |

This table *is* HANDOFF rule 2 and rule 12. A chat message, a split edit, a re-assessment or an
assistant draft can reach `DRAFT` and nothing else; only `publish` crosses into `PUBLISHED`. There is
no auto-publish transition and no publish tool exposed to the assistant.

### 3.2 Intake completeness

```
NOT_STARTED ──O01 answered──► IN_PROGRESS(step n) ──O05 published──► COMPLETE
     │                              │
     │                              └──X / Skip to T01──► DEFAULTED ──re-entered──► IN_PROGRESS
     └──X on O01──────────────────────────────────────────► DEFAULTED
```

`DEFAULTED` still publishes a plan, from `IntakeDefaults` (the options O01–O04 already preselect:
stronger / home / none / 3 days / 15 min / no life-stage flag). This is load-bearing for rule 17:
T06's one filled card is the program, so an intake that publishes nothing leaves day one empty and
`P0-FR-01` fails. See §9 Q10.

### 3.3 Assignment lifecycle

| State | Meaning | Who moves it |
|---|---|---|
| ABSENT | rest day, or beyond the horizon | — |
| MATERIALIZED | prescribed values resolved, actuals untouched | `AssignmentMaterializer` |
| FROZEN | a session started against this date; `planVersion` pinned | G4 sets `frozen` via callable |
| SUPERSEDED-FUTURE | rewritten by a later version, only for dates ≥ `effectiveFrom` | `PlanRevisionService` |

A FROZEN or past-dated assignment is never rewritten by any transition (rule 2).

---

## 4. Offline behaviour

| Surface | Offline | Conflict resolution | UI while queued |
|---|---|---|---|
| O01–O04 answers | **Writable.** Merge into the cached `users/{uid}` doc | Distinct field keys merge commutatively; per-scalar last-write-wins (spine §5) | Step advances immediately; no spinner. A "saved on this phone" marker on the answer row |
| O05 publish | **Not writable** — `plans/**` is server-authored (spine §5) | — | Program card renders from the bundled catalogue; primary button reads "We'll build it the moment you're back online", never a spinner and never a failure. Intent queued in `users/{uid}/syncQueue/{opId}` with `opId = 'publishPlan:' + intakeHash` |
| Reading today's/this week's assignment | **Readable from cache** — a full ISO week is materialized ahead | — | Normal render; no offline chrome needed |
| Horizon top-up | Deferred | Idempotent on re-run | Silent; the cached week is still valid |

**Idempotency is the whole design.** `publishStartingPlan` is keyed on `(uid, intakeHash)`: a replayed
callable returns the *existing* version instead of creating `v2`. Without this, one flaky reconnect
publishes a second version, supersedes the first, and re-materializes assignments — corrupting exactly
what rule 2 protects. Two devices finishing the same intake converge on one version; genuinely
different answers create `v2` with `effectiveFrom = tomorrow`, leaving today's logged work untouched.

---

## 5. §2 rules I own, and where they are enforced

Domain/Function layer, never a widget. Flutter classes under
`lib/features/onboarding/domain/` and `lib/features/plans/domain/`; the server half under
`functions/src/plans/`.

| Rule | Owner | Enforced in | How |
|---|---|---|---|
| **1. A prescribed value is never a result** | shared with G4 | `AssignmentMaterializer.materialize()` | Emits `prescribedReps` / `prescribedLoad` only; asserts the emitted map contains no `actual*`, `done` or `adherence` key and throws if it does. Rules reject such a document (§6) |
| **2. A message never changes a plan — publishing does** | **G2** | `PlanPublisher.publish()` — the *only* writer of `status: 'published'` | Every other path (`PlanDraftService`, `PlanRevisionService.prepare`) can reach `DRAFT` only. `PlanRevisionService.applyRevision()` clamps `effectiveFrom = max(requested, today)` |
| **3. Weeks, not days — no streak** | shared with G6 | `IntakeValidator.validate()`, `WeeklyGoalHandoff.emit()` | O03 writes `profile.days` (a weekly quantity) and nothing per-day. Validator rejects any payload key matching `/streak|consecutive|dayCount/`. C6 makes it unstorable |
| **11. Nothing ranked by weight, weight lost or followers** | shared with G6 | `IntakeValidator.validate()`, `StartingProgramSelector.select()` | `lose_steadily` stays an enum; no `targetWeight`, no weight input to selection, no sort key on weight. C7 keeps the index absent |
| **17. The empty state is the onboarding** | **G2** | `IntakeDefaults.resolve()` + `PlanPublisher.publish()` | These five screens are real intake, not a tour. A `DEFAULTED` intake still publishes, so T06/E09 render a real program instead of a tutorial overlay. No G2 screen may add a tour, overlay or coach-mark |
| Life-stage adaptation, not diagnosis | **G2** | `LifeStageSafetyFilter.apply()` | `pregnant` / `postpartum` / `pain_injury` remove candidate programs and moves *before* selection, never warn afterwards. Mirrors HANDOFF r13/r14's "constraints applied before selection" |

**Server is authoritative.** Because `plans/**` is server-authored, `PlanPublisher`,
`AssignmentMaterializer` and `LifeStageSafetyFilter` are TypeScript in the Function. The Flutter
classes of the same name are a **pure preview** used only to draw O05's card offline, and a shared
fixture test asserts both produce byte-identical output for the same intake. Two implementations with
one test is the honest trade; one implementation is impossible while the client may not write plans.

---

## 6. Security rules (code, against the spine's exact paths)

```javascript
rules_version = '2';
service cloud.firestore {
  function isOwner(uid)      { return request.auth != null && request.auth.uid == uid; }
  function isVerifiedWoman() { return request.auth != null; } // onboarding is open while
                                                              // verification is pending (P0-VER-04)

  // Keys a client may write inside users/{uid}.profile
  function clientIntakeKeys() {
    return ['goal','place','equipment','days','sessionLength','lifeStage',
            'allergies','dietary','language','intake'];
  }
  function serverOnlyProfileKeys() {
    return ['activePlanVersion','planPublishedAt','horizonThrough'];
  }
  function noBannedCounters(m) {
    return !m.keys().hasAny(['streak','streakDays','consecutiveDays','dayStreak',
                             'targetWeight','weightGoal']);
  }
  function profileWriteOk() {
    return !request.resource.data.profile.diff(resource.data.profile)
              .affectedKeys().hasAny(serverOnlyProfileKeys())
        &&  request.resource.data.profile.diff(resource.data.profile)
              .affectedKeys().hasOnly(clientIntakeKeys())
        &&  noBannedCounters(request.resource.data.profile)
        &&  request.resource.data.profile.days is int
        &&  request.resource.data.profile.days >= 2
        &&  request.resource.data.profile.days <= 5
        &&  request.resource.data.profile.sessionLength in [10,15,20,30]
        &&  request.resource.data.profile.goal in
              ['stronger','feel_better','lose_steadily','back_into_it']
        &&  request.resource.data.profile.place in ['home','ladies_gym','both']
        &&  request.resource.data.profile.lifeStage in
              ['none','postpartum','pregnant','pain_injury']
        &&  request.resource.data.profile.equipment.size() <= 8
        &&  request.resource.data.profile.allergies.size() <= 40;
  }

  match /databases/{database}/documents {

    // G2's slice of G1's document. MUST be merged with G1's and G6's blocks into ONE
    // match statement before deploy — Firestore ORs `allow` across blocks, so a
    // permissive peer rule would silently defeat these restrictions (§9 Q3).
    match /users/{uid} {
      allow update: if isOwner(uid)
                    && profileWriteOk()
                    // verification stays Cloud-Function-only (C5); G2 never relaxes it
                    && !request.resource.data.diff(resource.data)
                          .affectedKeys().hasAny(['verification']);
    }

    // ---- plans/** : read-your-own, write nobody. Functions use the Admin SDK and
    //      bypass these rules, which is what "server-authored" means (spine §5).
    match /plans/{uid}/versions/{version} {
      allow get, list: if isOwner(uid);
      allow create, update, delete: if false;
    }

    match /plans/{uid}/assignments/{date} {
      allow get, list: if isOwner(uid);
      allow create, update, delete: if false;
    }

    // Defence in depth: nothing may create a plan document carrying an actual value
    // or a streak, even if a future rule block turns client writes on (C6, C8, rule 1).
    match /plans/{uid}/{document=**} {
      allow write: if false;
    }

    // Starting-program catalogue: immutable content, read by any signed-in client.
    match /programs/{programId} {
      allow get, list: if isVerifiedWoman();
      allow write: if false;
    }
  }
}
```

Negative tests to ship with these rules: a client writing `profile.activePlanVersion`; a client
writing `plans/{ownUid}/versions/v1`; a client reading `plans/{otherUid}/assignments/2026-09-21`;
a client writing `profile.streak`; a client writing `profile.days = 9`; a client writing
`verification.status`.

---

## 7. Interface to the other groups

### What G2 consumes

| From | Path / signal | Use | Note |
|---|---|---|---|
| G1 | `request.auth.uid`, `users/{uid}` exists | owner of the intake | O01 is reached from C16 |
| G1 | `users/{uid}.verification.status` | **read-only, and G2 does not gate on it** | Workouts stay open while verification is pending (`P0-VER-04`); only community waits |
| G8 | offline persistence, `syncQueue`, locale, connectivity | queued publish, RTL, "saved on this phone" | G2 writes no `syncQueue` schema of its own |
| G6 | `users/{uid}.profile.progression` (**requested — does not exist yet, §9 Q2**) | resolve next week's prescribed load | G2 must not read `bests/*` or `sessions/*`: the ownership table lists them as G6-read only |
| content | `programs/{programId}` | the catalogue | bundled + Remote Config stamp, never read per session |

### What G2 publishes

| Path | Consumers | Guarantee |
|---|---|---|
| `users/{uid}.profile.{goal,place,equipment,days,sessionLength,lifeStage,allergies,dietary}` | G3, G4, G5, G6, G7 | Always present after intake, defaults included. Never null once `intake.status != NOT_STARTED` |
| `users/{uid}.profile.activePlanVersion` | G3, G4, G5 | Points at a `published` version; changes only on publish |
| `plans/{uid}/versions/{version}` | G4 (R02 week strip), G3 | Immutable once published; `status` and `supersededBy` are the only mutable keys |
| `plans/{uid}/assignments/{yyyy-MM-dd}` | **G3, G4, G5** | Contract below |

### The assignment contract — G3, G4, G5 (precise)

1. **Read pattern.** `get(plans/{uid}/assignments/{today})` — 1 read, already counted inside T01's 4
   (spine §4). A week strip is a `__name__` range over 7 keys, 3–4 docs. Never a collection listing
   without a date bound.
2. **Absence means rest.** A missing document is a valid, expected state and renders the rest day. It
   is never an error and never a loading state.
3. **G3 (T01, T02)** reads `workout.title`, `workout.minutes`, `workout.moves.size()`,
   `workout.quiet`, `workout.equipment`, plus `weekIndex`/`weeks` for "Week 3 of 8". For
   `P0-LOG-04` ("I already did it") G3 stamps the recalled session with this document's
   `planVersion` and its id as `assignmentId` — the two fields the spine already reserves on
   `sessions/*`.
4. **G4 (R02, R03, R07)** reads `workout.moves[]` in `order` and copies `prescribedReps` and
   `prescribedLoad` into the session's `prescribedReps` / `prescribedWeight`. Mapping is fixed:
   `kind:'kg'` → the number; `kind:'bodyweight'` → `0` with the label "bodyweight";
   `kind:'seconds'` → `prescribedWeight = 0` and duration from `value`. G4 writes `actual*`; **G2
   never does, and no `actual*` key exists in a G2 document** (C8, rule 1).
5. **Version pinning.** A session copies `planVersion` at start and keeps it for its whole life. A
   plan revision published mid-session changes nothing that is running or already logged
   (HANDOFF r2). G2 guarantees it never rewrites an assignment whose date is past or whose `frozen`
   is true.
6. **Swaps (R05) are G4's, not G2's.** A today-only swap is recorded on the *session*, never by
   editing the assignment — the same reason the assistant has `propose_swap` but no publish tool.
7. **G5 (E01, E07)** reads `meal`, which is **`null` for the whole MVP** (there is no coach to plan
   meals; E01's "Lunch, from your plan / From Sara" is a coaching surface, out of the cut). G5 must
   render its own suggestion path when `meal == null` and must take `profile.allergies` and
   `profile.dietary` from G2's map — subject to §9 Q1.
8. **G6** derives `weeklyGoal.sessionsTarget` from `profile.days`. **G2 never writes `weeklyGoal`**
   (ownership table). T05's "Make this week 2 sessions" is G6 writing a per-week override and must
   not write back to `profile.days` (§9 Q7).

### Keeping the coach case possible without a migration

The MVP ships the coach-shaped model and simply never exercises it: `status` already contains
`draft`; `source` already distinguishes `self_serve | coach | split`; `authorUid` and `templateRef`
already exist; `effectiveFrom`/`supersedes` already express a revision. Adding the coach app later
means (a) a `draftPlan` Function that writes `status: 'draft'`, (b) widening `PlanPublisher`'s
authorization guard from "self" to "self or the assigned coach", (c) a `splits/*` collection the
coach owns. Assignments, the read contract, the indexes and every consumer stay byte-identical.
HANDOFF r12 holds by construction: applying a split runs the same `PlanPublisher.publish()` and
writes future-dated assignments, while editing `splits/*` touches no version — a published version
is immutable, so there is no path by which a template edit can reach back into it.

---

## 8. Test IDs G2 is accountable for

**P1 — owned (rule guards):**

| ID | G2's accountability |
|---|---|
| `P1-RULE-01` | The assignment carries prescribed values only; no `actual*` key exists in any G2 document (C8) |
| `P1-RULE-02` | Owned outright: `PlanPublisher.publish()` is the only writer of a published version; drafts and revisions cannot mutate one; no auto-publish transition exists (§3.1) |
| `P1-RULE-03` | O03 writes a weekly quantity only; `IntakeValidator` and the rules reject every streak-shaped key (C6) |
| `P1-RULE-11` | No weight anywhere in intake or selection; no `targetWeight`; no weight sort key (C7) |

**P0 — shared, G2 is the upstream dependency:**

| ID | G2's part |
|---|---|
| `P0-FR-01` | "setup complete" must yield a published plan + today's assignment, so T06/E09 render a real program and not a tour (rule 17) |
| `P0-LOG-04` | `plans/{uid}/assignments/{today}` supplies "Legs and glutes, today's plan · 15 min · 5 moves" and the `planVersion`/`assignmentId` stamped on the recalled session |
| `P0-LOG-01` | Supplies the prescribed weight and reps the one-tap button names |
| `P0-WEEK-01` | "Weekly goal is 3 sessions" originates in O03 → `profile.days` → G6's `sessionsTarget` |
| `P0-WEEK-02` | Rest-week repair must not require a plan change; G2 guarantees the horizon keeps advancing through an unmet week |
| `P0-LOG-09` | Intake answers queue and sync without duplicates; the publish intent is idempotent on `intakeHash` |
| `P0-NAV-01` | O01–O05 are one-time pre-navigation screens (UX review §"fair reading"); they are excluded from the 2-tap denominator, and G2 must not add a recurring entry point that changes that |
| `P0-A11Y-01` | O01–O05 mirror in Arabic; step counters and day/minute chips keep Western numerals |

**P2 — G2's screens (state coverage, not claimed as P0/P1):**
`P2-RTL-O01`…`P2-RTL-O05`, `P2-TXT-O01`…`P2-TXT-O05`.

**Coverage gap G2 is reporting, not hiding:** the CSV contains **no P0 or P1 case that exercises
O01–O05 directly** — the only onboarding-specific rows are the ten P2 RTL/large-text cases above.
Safety-critical intake (life stage → what a pregnancy or postpartum program may contain; allergies →
what G5 may suggest) therefore has zero P0 coverage. Requested additions, for Stage 1 to accept or
reject by ID: `P0-ONB-01` intake completes and publishes a plan (happy path, 5 screens);
`P0-ONB-02` every screen skipped → defaults publish a valid plan and T06 renders;
`P0-ONB-03` intake offline, publish on reconnect, exactly one version created after three retries;
`P1-RULE-12` a `pregnant` life stage never yields an excluded move, checked at the materializer not
the widget; `P1-RULE-13` a plan revision leaves past dates and a running session byte-identical.

---

## 9. Open questions

1. **Nothing in the MVP cut captures `allergies` or `dietary`, yet the spine assigns both to G2 and
   G5 depends on them.** O01–O04 ask goal, place, equipment, days, minutes and life stage — not food.
   The only capture surface in the product is `G17` ("This is the only place your allergies come
   from", `screens-coached.mjs:259`), which is coaching intake and **out of the cut**; `Y02` (cycle,
   also out) links to `A02` saying "Already saved — edit in your profile", and `A02` has no such row
   (`screens-account.mjs:18–31`). An ARB string already exists (`samaj7e`). This is safety-critical
   and unresolvable inside G2's mandate. Options: (a) a sixth intake step in G2, (b) a row on `A02`
   owned by G7, (c) G5 captures it at first meal log. **Recommendation: (a), because §2 rule 17 makes
   intake the place this belongs and G5 should not have to ask twice.** Until it is decided, G5 must
   treat `allergies` as unknown rather than empty — "no allergies recorded" is not "no allergies".
2. **G2 cannot legally read what progression needs.** T01 and R03 promise "last week's weights", but
   the ownership table gives `bests/*` and `sessions/*` reads to G6 only. G2's materializer needs one
   of them. Proposal: G6 publishes a derived, read-only `users/{uid}.profile.progression`
   (`{exerciseId: lastPrescribed}`); failing that, the table widens to let G2's Function read
   `bests/*`. Not a workaround G2 will take unilaterally — until resolved, week 1 prescribes the
   catalogue's starting loads and week 2+ repeats them.
3. **`users/{uid}` rules must be authored once, jointly.** Firestore ORs `allow` across match blocks,
   so G1's or G6's block for the same path can silently defeat G2's field-level restrictions in §6 —
   including `serverOnlyProfileKeys` and the C5 verification denial. Needs one owner for a single
   merged `match /users/{uid}` statement, with the negative tests in §6 run against the merged file.
4. **O05's "Pick a different program" goes to the wrong screen.** It routes to `R11`
   (`screens-onboarding.mjs:37`), which the inventory and `P2-RTL-R11` both name **"Workout
   library"** — 124 videos with quiet/no-equipment filters, not a list of programs. There is no
   program-picker screen anywhere in the inventory. Either add one (G2), or point the button at `R02`
   and accept that changing program means re-running intake.
5. **No one has signed off what a `pregnant` program may contain.** O04 captures it and F24 promises
   life-stage programs, but HANDOFF r13/r14 (assessment as the only source of constraints, `refer` as
   a first-class outcome) are coach-side and out of the cut. `LifeStageSafetyFilter` therefore has no
   authored source for its exclusion list, and O04's copy already promises "we avoid what hurts, we do
   not diagnose". This is an owner-track item (clinical review + disclaimer copy), not a code gap.
6. **C8 says `prescribedWeight` is non-null, but "Glute bridge · bodyweight" has no weight.** G2
   stores `prescribedLoad.kind` and maps `bodyweight` → `0`. Confirm G4 renders `0` as "bodyweight"
   and that adherence never divides by it.
7. **Two writers near the weekly target.** O03 sets `profile.days`; T05's "Make this week 2 sessions"
   has G6 writing `weeklyGoal.sessionsTarget`. Confirm the per-week override never writes back to
   `profile.days` — otherwise a bad week permanently shrinks her program.
8. **The `programs` catalogue does not exist yet.** Three names appear in copy (Beginner foundations,
   Postpartum rebuild, Ramadan training) and `R03` shows the shape of a day, but no program content is
   authored. `publishStartingPlan` cannot publish anything without ~12 programs × weeks × day
   templates with prescribed sets. This is the same owner-track content dependency as the 124 videos,
   and it blocks O05 end to end — not just its visuals.
9. **Is Ramadan a plan revision or a per-day override?** `E01` shows a "Ramadan mode" pill and F24
   names a Ramadan program. If it is a new version, rule 2 applies and mid-Ramadan revisions must be
   future-dated; if it is an override, it needs a home that is not the immutable version document.
   G2 assumes a **new version with `effectiveFrom`** and flags it.
10. **Does closing intake (the `X` → T01) still publish a default plan?** G2 assumes yes, since every
    O screen preselects a valid answer, and `P0-FR-01` needs T06's program card. If the owner wants a
    truly empty day one, rule 17 needs re-reading and `P0-FR-01`'s expectation changes.

---

## Scalability gate — self-check

| Gate | Result | Evidence |
|---|---|---|
| Unbounded collection scan | **PASS** | Program selection is an in-memory filter over a ≤20-doc bundled catalogue (§2.6), never a Firestore query. Assignment reads are `__name__` ranges bounded to 7 keys. No scheduled sweep over `users` — the horizon top-up is client-initiated per user (§2.5) |
| Per-user fan-out write growing with followers | **PASS** | Every G2 write lands in one `uid`'s own subtree (`users/{uid}`, `plans/{uid}/**`). G2 touches no follow graph, no group, no feed. Fan-out is 1 |
| Unindexed query on a hot path | **PASS** | Zero composite indexes. Every read is a document `get` or an automatically-indexed `__name__` range. The hot path (T01's assignment) is a single `get` by date key |
| Migration needed to reach 100k MAU | **PASS** | Version ids are monotonic, assignments date-keyed, horizon bounded at one ISO week. The coach path's fields (`draft`, `source`, `authorUid`, `templateRef`, `supersedes`) ship in the MVP document shape and are simply unused, so adding the coach app is additive. One named caveat: a catalogue beyond ~200 programs moves selection to a served index — a config change, not a data migration |

Budget: **21.2% of the daily write allowance, 4.3% of reads, ~$2.60/month, zero video egress**
(§2.2–2.4). Inside budget, and G2 adds no composite index to the hot path, as spine §4 requires.
