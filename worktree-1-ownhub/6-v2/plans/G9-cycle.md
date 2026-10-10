# G9 — My Cycle

Screens: **Y01** Set up · **Y02** Dates and preferences · **Y03** Hub (today) · **Y04** Check-in sheet ·
**Y05** Why this suggestion · **Y06** Choose what feels right · **Y07** Meals for today · **Y08** Calendar ·
**Y09** Log a period · **Y10** Your patterns · **Y11** When it is severe · **Y12** Settings and sharing ·
**Y13** About cycle phases · **Y14** Symptom-only mode.

Features: F80–F90. Rules owned: **§2.4**, **§2.5**, **HANDOFF 6 / spine C12** (sharing), and the
**PDPL analytics ban** on cycle data.

Written against `DECISIONS.md` (D1 — everything ships), `SCHEMA-SPINE.md` §1–§8 including the new §8,
`flutter/HANDOFF.md`, and `plans/RECONCILIATION.md`. Costs are against `BUILD-BRIEF.md` §3 — 35,000 DAU,
~8 reads / ~6 writes per active day, 40% of traffic 19:00–23:00 Cairo — at the effective unit prices G6
used ($0.30/M reads, $0.90/M writes), so the line is comparable with the other eight plans.

**The premise of this plan.** This is the most sensitive data in the product and the group most able to
do harm. Three things follow, and they shape every section below:

1. **A date never changes what the app suggests.** Only what she logged today does (§2.4). The design
   makes a phase *uncomputable* at the point where a suggestion is decided, rather than merely unused.
2. **Severe symptoms remove the workout, they do not soften it** (§2.5). The suppressed result is a type
   that has no workout field, so there is nothing for a widget to render.
3. **Cycle data leaves the device in exactly two directions**: to her own Firestore documents, and — only
   if she turned a switch on, only for the coach she turned it on for, and only while that relationship
   is live — to a server-computed projection. It goes to analytics **never**, under any circumstance.

---

## 1. Data model, against the spine

Spine §8 gives G9 `users/{uid}/cycle` and `users/{uid}/periods/*`. **One correction is required before
either can be built** (see OQ-1): `users/{uid}/cycle` is an odd-segment path and is therefore a Firestore
*collection*, not a document, so it cannot hold `{ mode, contextFlags, adaptation{}, sharing{} }`. This is
the same defect class G8 found in `syncQueue`. I resolve it the way G5 resolved `eatPrefs`: **a single
fixed document id** — `users/{uid}/cycle/current` — which keeps the spine's path prefix verbatim, keeps the
sensitive data in its own document instead of on the root user document that six groups read, and makes
Y12's "Delete cycle data" a document delete rather than a field surgery on `users/{uid}`.

### 1.1 `users/{uid}/cycle/current` — one document, fixed id (C1)

| Field | Type | Default | Written by | Read by |
|---|---|---|---|---|
| `mode` | enum `datesAndSymptoms` \| `symptomsOnly` | *absent* (= never set up) | Y01 | Y03, Y08, Y10, Y12, Y14, T01 |
| `contextFlags` | list\<enum\> ≤6 — `irregular`, `hormonalContraception`, `perimenopause`, `pregnantOrPostpartum`, `preferNotToSay`, `none` | `[]` | Y01 | `ForecastPolicy` |
| `cycleLengthDays` | int? 21–45 | **null** | Y02 | Y08 estimate |
| `adaptation` | map: `{ workoutSuggestions, mealSuggestions, homeCard, easierWhenLowEnergy }` all bool | all **false** until she saves Y02 | Y02, Y10, Y12 | Y03, Y06, Y07, T01 |
| `sharing` | map: `{ energyAppetite, symptoms, datesAndPatterns }` all bool + `grantedForRelId: string?` | all **false** (C12) | Y12, G02 | `CycleSharingPolicy` only |
| `lastPeriod` | map? `{ startDate, endDate?, stillBleeding }` | null | Y09 (same transaction as the period doc) | Y03, Y08, T01 |
| `recentStarts` | list\<string\> **≤12**, newest first, `yyyy-MM-dd` | `[]` | Y09 | Y08 estimate, Y10 |
| `schemaV, updatedAt, clientWrittenAt, opId` | K3 metadata | — | every write | — |

**Not stored, deliberately:**

| Not a field | Why |
|---|---|
| `phase`, `cycleDay`, `predictedOvulation`, `fertileWindow` | §2.4 is enforced by making a phase *unstorable*, the way C6 makes a streak unstorable. `PhaseEstimator` is a presentation-layer function of `recentStarts` used only by Y08's dashed cells and Y13's copy; no suggestion path can reach a phase because no document carries one. |
| `forecastEnabled` | derived, never stored — `ForecastPolicy.isEnabled(cycle)` returns false whenever `mode != datesAndSymptoms` or any of `irregular` / `hormonalContraception` / `perimenopause` / `pregnantOrPostpartum` is set. A stored derived flag is a flag that goes stale offline. |
| any symptom value | they live in G3's `checkins/{yyyy-MM-dd}`. G9 stores **no** symptom, ever, and duplicating the check-in is the failure this line exists to prevent. |
| any `streak`-shaped key | C6 / K9. |

**Two defaults that look contradictory and are not.** The spine annotates the cycle document *"default
OFF"*, while Y02 renders its three adaptation toggles pre-checked. Both are honoured: **no document exists
until she finishes setup**, so before that everything is off and the feature is invisible; Y02's Save
writes whatever the form shows. `sharing.*` is different and absolute — it is false on write, cannot be
set during setup, and only Y12/G02 can turn it on (C12, HANDOFF 6).

### 1.2 `users/{uid}/periods/{yyyy-MM-dd}` — id is the **start** date (C1)

| Field | Type | Constraint |
|---|---|---|
| `start` | string `yyyy-MM-dd` | **must equal the document id** — makes an offline retry idempotent and a duplicate impossible |
| `end` | string? | `>= start`, `<= today`; null means still bleeding |
| `stillBleeding` | bool | **must equal `end == null`** — enforced in rules, so the two can never disagree |
| `editedAt` | timestamp | Y09 |
| `schemaV, updatedAt, clientWrittenAt, opId` | K3 metadata | |

~13 documents per user per year, ~0.3 KB each. She is the only writer and the only reader.

### 1.3 Indexes — and the exemptions that are the actual control

Composite indexes required: **none.** The only query in the group is a document-id range (§2).

**Single-field index exemptions are mandatory deployment artifacts**, for the C7 reason G4 and G6
established: Firestore auto-indexes every field, so absence of a composite index proves nothing. Here the
argument is stronger than rule 11's, because an indexed `contextFlags` is a cross-user segment of
pregnant and perimenopausal women that exists in the deployed project whether or not anyone queries it.

```jsonc
// firestore.indexes.json — fieldOverrides. Every one of these is required, not optional.
{ "collectionGroup": "cycle",   "fieldPath": "contextFlags",    "indexes": [] },
{ "collectionGroup": "cycle",   "fieldPath": "recentStarts",    "indexes": [] },
{ "collectionGroup": "cycle",   "fieldPath": "mode",            "indexes": [] },
{ "collectionGroup": "cycle",   "fieldPath": "cycleLengthDays", "indexes": [] },
{ "collectionGroup": "cycle",   "fieldPath": "sharing",         "indexes": [] },
{ "collectionGroup": "cycle",   "fieldPath": "lastPeriod",      "indexes": [] },
{ "collectionGroup": "periods", "fieldPath": "start",           "indexes": [] },
{ "collectionGroup": "periods", "fieldPath": "end",             "indexes": [] },
{ "collectionGroup": "periods", "fieldPath": "stillBleeding",   "indexes": [] }
```

**The rule G9 asks the deployment to hold: no field of `cycle` or `periods` carries an index of any kind.**
Document-id lookups and `__name__` ranges still work — they are all this group needs — and a collection-group
query over cycle data becomes unexecutable in the deployed project rather than merely denied by a rule
someone could later loosen. `index_exemption_test.dart` (extending G4/G6's) asserts all nine.

### 1.4 Read/write per screen

| Screen | Reads | Writes |
|---|---|---|
| Y01 | `cycle/current` from the session listener | 1 — `set(merge)` `mode`, `contextFlags` |
| Y02 | 0 | 1 — `merge` `cycleLengthDays`, `adaptation`; +1 period doc if she gives a start date (one transaction, 2 writes) |
| Y03 | 0 incremental (listener + G3's `checkins/{today}` + G2's assignment, all already in cache) | 0 |
| Y04 | 0 | 1 — **G3's** `checkins/{today}`, through G3's command (counted in G3's budget, not mine) |
| Y05 | 0 — renders the resolver's own output plus bundled guidance | 0 |
| Y06 | 0 — assignment is cached; the alternative is bundled or from `assignment.approvedAlternatives` | 1 on "Use this option" — **G4's** today-only write |
| Y07 | 0 — G5's `eatPrefs/current` is cached | 1 on Add — **G5's** write |
| Y08 | ≤2 — `periods` `__name__` range over the displayed month | 0 |
| Y09 | 0 | 2 in one transaction — the period doc + `lastPeriod`/`recentStarts` on `cycle/current` |
| Y10 | ≤6 `checkins/{date}` gets, cache-first, hard-capped | 0–1 (the `easierWhenLowEnergy` toggle) |
| Y11 | 0 (a branch of Y03) | 0 |
| Y12 | 0 incremental + G11's relationship doc if she has a coach | 1 per switch, field-path merge |
| Y13 | 0 — bundled content | 0 |
| Y14 | 0 (a branch of Y03) | 0 |

---

## 2. The query for every screen, its index, and its cost at §3's numbers

**One listener, not a read per screen.** `cycle/current` is attached once per app session by
`CycleRepository.watch()` and served from Firestore's unbounded offline cache thereafter. Every Y screen
and T01's cycle row render from that one snapshot. Cold attach costs 1 read per session (~1.15
sessions/active day); a woman who never set up My Cycle costs **zero**, because the listener is not
attached at all — the `adaptation.homeCard` value is mirrored into local device storage at write time, so
the app knows at cold start whether to attach it without reading anything.

| # | Screen | Query | Index | Reads | Writes | Notes |
|---|---|---|---|---|---|---|
| 1 | Y01 | `get users/{uid}/cycle/current` (listener) | doc id | 1/session | 1 | first attach only |
| 2 | Y02 | none | doc id | 0 | 1–2 | transaction when a start date is given |
| 3 | Y03 | none — listener + `checkins/{today}` (G3 read at T01) + `assignments/{today}` (G2, cached) | doc id | **0** | 0 | the hot path is three cache hits |
| 4 | Y04 | none | doc id | 0 | 1 (G3's) | |
| 5 | Y05 | none | — | 0 | 0 | bundled guidance, `careContentVersion` in Remote Config |
| 6 | Y06 | none | — | 0 | 1 (G4's) | alternative from the bundle or the cached assignment |
| 7 | Y07 | none | — | 0 | 1 (G5's) | G5 ranks over its cached `eatPrefs/current` |
| 8 | Y08 | `where(__name__ >= 'users/{uid}/periods/{yyyy-MM}-01' && __name__ <= '…-31')` | `__name__` (automatic) | **≤2** | 0 | bounded by construction; ~1–2 period docs exist in any month |
| 9 | Y09 | none | doc id | 0 | 2 | one transaction, deterministic ids |
| 10 | Y10 | `recentStarts[0..1]` from the listener → **≤6** `get checkins/{date}` | doc ids | ≤6, cache-first | 0–1 | hard cap in `PatternWindow.maxDays = 6`; never a range, never a scan |
| 11 | Y11 | none | — | 0 | 0 | branch of Y03 |
| 12 | Y12 | listener + `get relationships/{relId}` (G11, cached) | doc ids | 0–1 | 1/switch | |
| 13 | Y13 | none | — | 0 | 0 | bundled |
| 14 | Y14 | none | — | 0 | 0 | branch of Y03 |

### Cost per active day

| Line | Per active day | Basis |
|---|---|---|
| `cycle/current` listener attach | **1.0** | 1.15 sessions/day, ~0.85 served from cache after the first |
| Y08 calendar | **0.18** | opened ~0.15 days × 1.2 docs |
| Y10 patterns | **0.15** | opened ~0.05 days × ≤6 gets, mostly cache hits |
| Y12 relationship read | **0.01** | settings are rare |
| **Reads — a woman who uses My Cycle** | **≈ 1.3** | **0 for one who does not** |
| Period create/edit/close | **0.21** | ~3 period events per 28 days × 2 writes |
| Toggles (adaptation + sharing) | **0.05** | |
| **Writes (G9's own)** | **≈ 0.3** | the Y04 check-in write is G3's and is counted there |

**Blended at an assumed 60% adoption: ~0.8 reads and ~0.18 writes per active day.**

| Monthly at 35,000 DAU | |
|---|---|
| Reads 35,000 × 30 × 0.8 ≈ 840k | $0.25 |
| Writes 35,000 × 30 × 0.18 ≈ 189k | $0.17 |
| Storage ~5 KB/user/yr × 100k ≈ 0.5 GB | $0.09 |
| **G9 total** | **≈ $0.51/month** |

**Against the §3 envelope.** G9 adds ~1 read per active day for a user who has set the feature up, taking
the spine §4 typical day from ~7 to ~8 — at the ceiling, inside it, and stated plainly rather than hidden.
I rejected the cheaper design (mirroring `homeCard`/`lastPeriod` onto the root `users/{uid}` document, which
T01 already reads, for 0 incremental reads) for two reasons: it puts cycle state on the one document every
other group reads, which is the wrong direction for this data class; and it would make two groups the writer
of one fact, which the spine's ownership table rejects. **Peak:** 40% of a 0.3-write day in 4 hours is ~1.2
writes/s aggregate across 35k women, and no G9 document is written more than a few times a day by exactly
one woman — no hotspot, no sharding, ever.

---

## 3. State machines

### 3.1 `CycleSetupState` — the feature's own lifecycle (5 states)

| State | Condition | Screen |
|---|---|---|
| `notSetUp` | no `cycle/current` document | Y01 reachable from T01; **no cycle card on Home, no check-in prompt, no trace anywhere else** |
| `datesAndSymptoms` | `mode == datesAndSymptoms` | Y03 hub with the calendar tab and estimates |
| `symptomsOnly` | `mode == symptomsOnly` | **Y14 — a branch of the Y03 route**, no calendar tab, no estimate, no phase name |
| `forecastSuppressed` | `mode == datesAndSymptoms` **and** `ForecastPolicy.isEnabled == false` | calendar shows logged days only; dashed cells and the "next period" line are absent, with the reason on screen |
| `purged` | Y12 "Delete cycle data" completed | returns to `notSetUp`; the rest of the app is untouched |

```
notSetUp ──Y01 dates────► datesAndSymptoms ──context flag / mode change──► forecastSuppressed
    ▲     ──Y01 symptoms─► symptomsOnly ◄────────Y12 "change how you use it"────────┘
    └──────────────────── purged ◄── Y12 delete ── any state
```

`forecastSuppressed` is a state and not a variant because Y01's context chips must **remove** forecasting
rather than degrade it: irregular cycles, hormonal contraception, perimenopause and pregnancy all make an
estimate from dates meaningless, and the screen says so instead of quietly widening the range.

### 3.2 `PeriodEntry` (5 states)

| State | Condition | Transitions |
|---|---|---|
| `draft` | Y09 sheet open, nothing written | Save → `open`/`closed`; Cancel → gone |
| `open` | doc exists, `stillBleeding == true`, `end == null` | set an end date → `closed`; edit start → `open` (id changes: delete + create in one transaction) |
| `closed` | `end != null` | edit → `closed`/`open`; delete → `deleted` |
| `deleted` | document removed | `lastPeriod` and `recentStarts` are rebuilt in the same transaction |
| `invalid` | never persisted — future date, `end < start`, or `stillBleeding` disagreeing with `end` | the sheet refuses with the reason on screen; **no write is attempted**, so nothing to undo |

**Editing a start date rewrites the id**, because the id *is* the start date (C1). That is a delete plus a
create inside one transaction, and it is why Y09's note "editing a date clears estimates built on the old
one" is structurally true: `recentStarts` is rebuilt from the collection inside the same transaction.

### 3.3 `DaySuggestionState` — where §2.4 and §2.5 live (6 states)

The **only** input is today's check-in. There is no date input and no phase input.

| State | Condition (today's check-in only) | What Y03 renders |
|---|---|---|
| `noCheckIn` | no `checkins/{today}` document, or every field null | "How are you feeling?" and **her plan, unchanged**. Never a suggestion. |
| `usual` | logged, and no qualifying symptom | her planned session, unchanged, no gentler card |
| `gentlerOffered` | `energy == low` **or** `cramps in [mild, moderate]` **or** `bloating in [moderate]`, and `adaptation.workoutSuggestions` | the "A gentler option today" card, with the reason naming what she logged (Y03 → Y05, Y06) |
| `gentlerTaken` | she tapped "Use this option" | today only; the week and the plan are untouched (G4's write) |
| `keptMine` | she tapped "Keep mine" | the card collapses for the rest of today; her plan stands |
| `suppressed` | **`cramps == severe` or `bleeding == heavy`** | **Y11** — medical guidance, a route to care, a rest row. **No workout is offered anywhere on the screen.** |

```
noCheckIn ──save check-in──► usual ──────────────► (no card)
                       │
                       ├─ qualifying symptom ──► gentlerOffered ──┬─ use ─► gentlerTaken
                       │                                          └─ keep ─► keptMine
                       └─ severe symptom ──────► suppressed  (Y11; no workout, at all)
```

Three transitions that matter and are easy to get wrong:

- **`suppressed` is reversible within the day.** If she edits cramps from `severe` to `mild` later the same
  day, the state recomputes to `gentlerOffered`. Rule 4 says today's symptoms — not today's *first* symptoms.
- **Selecting "Severe" on Y04 shows the Y11 content immediately but writes nothing until Save.** An unsaved
  severe selection is `severeSelectedUnsaved`, a sheet-local flag; backing out stores nothing and leaves the
  day at `noCheckIn`. Persisting a symptom she did not save would be a lie in a symptom diary.
- **A new day always starts at `noCheckIn`.** Nothing is carried over (Y04's own copy). `TodayCheckIn.absent`
  is a first-class value and the reader is forbidden from falling back to yesterday's document — a diary that
  assumes continuity has stopped being a diary, and a carried-over severe symptom would suppress a workout
  on a day she feels fine.

### 3.4 `SharingGrant` — one machine per switch (4 states)

| State | Condition | Coach sees |
|---|---|---|
| `off` | `sharing.<key> == false` | `CycleCategory.notShared` — an explicit marker, **never an empty panel or a zero** |
| `granted` | `true` and `grantedForRelId == the reading relationship` and that relationship is `active` | the projection for that category only |
| `revoked` | she turned it off | `notShared` on the coach's next read; the derived panel disappears |
| `orphaned` | `true` but the relationship ended, or `grantedForRelId` names a different relationship | `notShared` — **a grant never survives into a new coaching relationship** |

`orphaned` is the state that makes the product's own promise true: *"Cycle sharing switched itself off when
the coaching ended."* It is evaluated **at read time**, exactly as C10 evaluates result consent, so it holds
even when her handset is offline and no revocation write has synced. Y12 additionally clears the map lazily
on next open so the switches *show* off, but the honest guarantee is the read-time check, not the write.

### 3.5 `CycleDeletion` (Y12) — 5 states

`idle → confirming → purgingLocal → purgingRemote → done`, with `failed → retry`. Deletion is destructive
and not logging, so it **may** confirm (the exemption G7 recorded against P1-RULE-09). `purgingLocal` clears
the local Firestore cache entries and the `homeCard` device mirror; `purgingRemote` deletes `cycle/current`
and every `periods/*` document via a callable so a half-deleted state cannot survive a lost connection.
**The check-ins are not deleted** — they are G3's and hold energy, sleep and appetite that the rest of the
app uses; Y12's copy must say exactly that, and OQ-8 asks the owner to confirm the wording.

---

## 4. Offline behaviour

Every G9 write is under `users/{uid}/**` and is therefore writable offline (spine §5). Nothing in this
group requires signal. She can log a period on a microbus.

| Action | Offline? | Id | Conflict resolution |
|---|---|---|---|
| Y01/Y02 setup | ✅ | `cycle/current` | field-level merge on distinct keys; `mode` is a single-owner scalar, last-write-wins |
| Y04 check-in | ✅ | `checkins/{date}` (G3, C1) | G3's field-level merge — two devices logging different symptoms both survive |
| Y09 period create/edit/delete | ✅ | `periods/{start}` (C1) | the id **is** the start date, so a replayed retry targets the same document and collapses into the same state |
| `recentStarts` | ✅ | — | **`arrayUnion` for additions** (K7), never a value overwrite; the ≤12 trim is applied by the reconciler, idempotently |
| `lastPeriod` | ✅ | — | a **cache** of the newest period document; if two devices disagree, `CycleProjectionReconciler.rebuild()` re-derives it from a bounded `__name__` range (≤12 docs) on reconnect. A derived field that can self-heal is never a conflict |
| Y12 sharing switches | ✅ | — | field-path merge per key; each switch is a single-owner scalar |
| Y12 delete | ❌ | — | needs the callable. The UI says so and offers to run it when signal returns; it never claims a deletion it has not performed |

**No counter exists in this group**, so C4/K5's "an increment never travels alone" has nothing to apply to.
That is deliberate: `recentStarts` is a bounded set, not a count, and there is no cycle metric anywhere in
the product that accumulates.

**What the UI shows while queued.** G8's convention verbatim — the value renders at full opacity with a
trailing `cloud_queue` glyph and `l10n.syncQueued`; no spinner, no "failed to save", no disabled control.
Y09's saved period appears on Y08's calendar immediately, marked queued, because from her point of view it
is saved. Y12's sharing switches are the one place I add a sentence: a switch turned **off** offline shows
*"Saved on your phone. Sara stops seeing this when you're back online."* — because G7 recorded that "revokes
immediately" cannot be true on an offline device, and this group must not be the one that promises it.

**Two honest limits, recorded rather than discovered:**

1. A revocation written offline does not reach the coach until it syncs. The read-time `orphaned` check
   covers the *ended relationship* case offline; it does not cover a live relationship whose switch she just
   turned off on a plane.
2. The Y11 route to care needs signal for maps; the fallback (§6 of the brief's platform table) is a bundled
   emergency number rendered offline, so the screen never dead-ends.

---

## 5. The §2 rules I own, and the exact enforcement point

Domain layer, never a widget. Each has a test in §8.

| Rule | Class · method | How it is enforced |
|---|---|---|
| **§2.4 — Suggestions follow the symptoms she logged today, never an inferred cycle phase.** | `SymptomSuggestionResolver.resolve(TodayCheckIn) → DaySuggestion` · `lib/features/cycle/domain/symptom_suggestion_resolver.dart` | **Enforced by absence of capability**, the pattern G3 used for the streak. The method takes **one** parameter — today's check-in — and its signature carries no date, no `CycleDocument`, no phase and no clock. A phase cannot influence a suggestion because a phase cannot be passed to the only function that produces one. |
| | `SymptomContext` · same folder | The value object published to G4, G5 and G3 has fields for logged symptoms **only**: no `cycleDay`, no `phase`, no `startDate`. A consumer cannot render "because you are on day 2" because it is never given a day 2. |
| | `PhaseEstimator` · `lib/features/cycle/presentation/calendar/phase_estimator.dart` | Physically confined to the calendar's presentation folder. `cycle_phase_import_test.dart` fails the build if anything under `domain/` or any other feature imports it (P1-CYC-01). |
| | `DaySuggestion.reason` | A non-null list of the **logged symptoms** that produced the suggestion, which is what Y03's card and Y05's "What you logged" render. A suggestion with no logged reason is unconstructible, so "a date alone changed it" cannot be expressed. |
| **§2.5 — Severe symptoms suppress the training suggestion and show medical guidance plus a route to care.** | `SevereSymptomGate.evaluate(TodayCheckIn) → bool` · `lib/features/cycle/domain/severe_symptom_gate.dart` | The single definition of severe: **`cramps == 'severe'` or `bleeding == 'heavy'`**. Evaluated before any suggestion is built; the resolver calls it first and returns immediately. |
| | `DaySuggestion` is a **sealed** type: `NoSuggestion` \| `KeepPlan` \| `GentlerOption(alternative)` \| `Suppressed(guidance, careRoute)` | `Suppressed` **has no workout, alternative or session field at all.** There is nothing for Y11 to render even if a widget tried, and adding one is a compile-time change that the review sees (the same type-separation argument C8 makes for prescribed vs actual). |
| | `no_workout_in_suppressed_test.dart` + a widget test over Y11 | asserts no workout affordance is reachable in the `Suppressed` branch, including the Train tab's entry row (P1-CYC-02, P1-RULE-05). |
| **HANDOFF 6 / spine C12 — sharing switches are independent, default OFF, and turning one off revokes the coach's derived panels.** | `CycleSharingPolicy.projectionFor({relId, category}) → CycleCategoryProjection` · `lib/features/cycle/domain/cycle_sharing_policy.dart` | The **only** function that can turn cycle data into something a coach sees. Returns `notShared` unless `sharing.<category> == true` **and** `grantedForRelId == relId` **and** the relationship is `active`. Evaluated at read time (C10's pattern), so revocation and a finished relationship both take effect without a revocation write. |
| | `CycleCategoryProjection.notShared` | An explicit value, not an empty list — W02's panel must be able to say "not shared", because "not shared" is not "no symptoms" and a coach reading absence as wellness is a clinical error the UI would have caused. |
| | The callable `getCycleProjection(relId)` (Cloud Function) | Re-checks the same policy server-side. A client-supplied projection is never trusted, and the coach app has **no** read path to `users/{uid}/cycle/**` in the security rules (§6). |
| | `sharing_default_off_test.dart`, `sharing_independence_test.dart`, `sharing_revocation_test.dart` | new document ⇒ all three false; setting one never sets another; revocation flips the projection to `notShared` in the same test (P1-CYC-03). |
| **Spine §6 / C12 — cycle data is never sent to analytics, under any circumstance.** | **`lib/features/cycle/` contains zero `AnalyticsGateway` call sites.** | The strongest available form: the feature does not emit events at all. Screen views come from G8's router, which sends `screen_id` and nothing else. There is no G9-owned event, no G9 property request, and nothing to review. |
| | `cycle_no_analytics_call_sites_test.dart` (AST over the feature folder) + G8's existing `analytics_no_freetext_test` | a call site introduced later fails the build (P1-CYC-04). G8's enum-typed API already makes a symptom value unsendable — there is no free-text property — so this test closes the remaining path, which is sending a *bucketed* symptom as an int. |
| **Rules I honour but do not own** | | §2.9 undo — Y04 routes through **G3's** `LogCommandBus`; Y09's save carries the same 5 s undo; Y09's delete and Y12's delete may confirm (the destructive exemption G7 recorded). §2.3 no streak — this group counts no consecutive days and stores no counter; `recentStarts` is a bounded set of dates, asserted by `no_streak_test`. HANDOFF 16 — **Y11 and Y14 are states of the Y03 route, not destinations**; a navigation-graph test asserts no inbound edge to either. HANDOFF 17 — `notSetUp` and "no periods logged yet" each state what will appear and offer one action. |

---

## 6. Security rules — my slice, as code

**G8 authors the single `users/{uid}` ruleset** (spine §2). The blocks below are `users/{uid}`
*subcollections*, supplied as requirements to be merged verbatim into G8's file. They use G8's helpers
(`isSelf`, `freshStamp`, `noStreak`) rather than redefining them, because a redefined helper in an OR-ed
block is how the last set of holes got in.

```javascript
// ---------- G9: cycle configuration. One document, fixed id. ----------
match /users/{uid}/cycle/{docId} {

  function cycleOk(d) {
    return d.keys().hasOnly(['mode','contextFlags','cycleLengthDays','adaptation','sharing',
                             'lastPeriod','recentStarts',
                             'schemaV','updatedAt','clientWrittenAt','opId'])
      && (!d.keys().hasAny(['mode'])
          || d.mode in ['datesAndSymptoms','symptomsOnly'])
      && (!d.keys().hasAny(['contextFlags'])
          || (d.contextFlags is list && d.contextFlags.size() <= 6))
      && (!d.keys().hasAny(['recentStarts'])
          || (d.recentStarts is list && d.recentStarts.size() <= 12))
      && (!d.keys().hasAny(['cycleLengthDays'])
          || d.cycleLengthDays == null
          || (d.cycleLengthDays is int && d.cycleLengthDays >= 21 && d.cycleLengthDays <= 45))
      && (!d.keys().hasAny(['adaptation'])
          || d.adaptation.keys().hasOnly(['workoutSuggestions','mealSuggestions',
                                          'homeCard','easierWhenLowEnergy']))
      && (!d.keys().hasAny(['sharing'])
          || d.sharing.keys().hasOnly(['energyAppetite','symptoms',
                                       'datesAndPatterns','grantedForRelId']))
      // no phase, no cycle day, no prediction is storable — §2.4 at the storage layer
      && !d.keys().hasAny(['phase','cycleDay','predictedOvulation','fertileWindow','forecast']);
  }

  allow get:    if isSelf(uid);
  allow list:   if false;                    // there is no cycle query, for anyone, ever
  allow create,
        update: if isSelf(uid)
                && docId == 'current'        // exactly one document; no second store
                && noStreak()                // C6 / K9
                && freshStamp()              // K3
                && cycleOk(request.resource.data);
  allow delete: if isSelf(uid);              // Y12 "Delete cycle data"
}

// ---------- G9: periods. Document id IS the start date (C1). ----------
match /users/{uid}/periods/{day} {

  function asDate(s) {
    return timestamp.date(int(s[0:4]), int(s[5:7]), int(s[8:10]));
  }

  function periodOk(d) {
    return d.keys().hasOnly(['start','end','stillBleeding','editedAt',
                             'schemaV','updatedAt','clientWrittenAt','opId'])
      && d.start == day                                   // id and field can never disagree
      && day.matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
      && d.stillBleeding is bool
      && d.stillBleeding == (d.end == null)               // the two can never contradict
      && (d.end == null || (d.end is string
                            && d.end.matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
                            && d.end >= d.start))         // ISO dates compare lexicographically
      // no future bleeding: server-side with a day of slack for the device timezone
      && asDate(d.start) <= request.time + duration.value(1, 'd')
      && (d.end == null || asDate(d.end) <= request.time + duration.value(1, 'd'));
  }

  allow get:    if isSelf(uid);
  allow list:   if isSelf(uid);              // Y08's bounded __name__ range, owner only
  allow create,
        update: if isSelf(uid) && noStreak() && freshStamp() && periodOk(request.resource.data);
  allow delete: if isSelf(uid);              // Y09 delete
}
```

**Four requirements to G8 that are not expressible inside my own blocks**, and which are the whole point
of supplying requirements rather than a file:

| # | Requirement | Why |
|---|---|---|
| **R1** | **No `match` under `users/{uid}/` may ever grant read on the basis of a `relationships/*` membership, an `exists()` on a coaching document, or any custom claim.** The coach's access to cycle data is the server projection and nothing else. | This is C12's real attack surface. Firestore ORs `allow` across blocks, so a single coach-friendly read rule added later for messages or logs would silently open cycle data too. A negative test — a coach with an active, *fully shared* relationship attempting a direct `get` on `users/{client}/cycle/current` — must fail. |
| **R2** | The nine index exemptions in §1.3 are deployment artifacts, checked by the same gate as G4's `sets` and G6's `measurements`. | Absence of a composite index is not sufficient; auto-indexing makes `contextFlags` a cross-user segment of pregnant and perimenopausal women in the deployed project. |
| **R3** | `users/{uid}/cycle/**` and `users/{uid}/periods/**` are added to **G7's deletion manifest** (K12) in the same change, plus the Y12 callable as a partial-purge path. | Otherwise A02's deletion promise is false for the most sensitive collection in the product. |
| **R4** | The Cloud Function `getCycleProjection(relId)` is the only server code permitted to read `users/{uid}/cycle/**`, and it re-evaluates `CycleSharingPolicy` rather than trusting a client-supplied flag. | Admin SDK bypasses rules entirely; the policy must therefore exist server-side, not only in Dart. |

**Storage:** G9 writes nothing to Storage. No photo, no voice note, no export artifact. There is no G9
Storage rule because there is no G9 object.

**Negative tests to ship with these rules:** a client writing `cycle/other`; a client writing
`cycle/current.phase`; a client writing `sharing.grantedForRelId` for a relationship it is not a party to;
a client writing `periods/2099-01-01`; a client writing `periods/2026-09-15` with `end: '2026-09-10'`;
a client writing `stillBleeding: true` together with an `end`; a 13th entry in `recentStarts`; a coach
reading `users/{client}/cycle/current` directly; a `collectionGroup('periods')` query from any client.

---

## 7. Interface to the other groups

### 7.1 Consumed

| From | Path / API | Use | Status |
|---|---|---|---|
| **G3** | `users/{uid}/checkins/{yyyy-MM-dd}` | the **only** input to §2.4 and §2.5 | exists |
| **G3** | `LogCommandBus` / `UndoableLog` | Y04's save — rule 9 is one implementation, not one per feature | exists |
| **G3** | a command to merge check-in fields | Y04 writes G3's document and must not touch Firestore directly | **request** — G3 publishes the path but has not named the command. Proposed: `CheckInRepository.merge(Map<CheckInField, Object?>)`, routed through `LogCommandBus`, mirroring the three commands G3 itself had to request (OQ-3) |
| **G3** | `DayStateResolver` | so Y03's day and T01's day never disagree | exists |
| **G2** | `plans/{uid}/assignments/{yyyy-MM-dd}` — `workout.title`, `minutes`, `quiet`, `equipment`, `approvedAlternatives` | Y06's "Planned:" row and Y14's unchanged-plan card. **Absence means rest** | exists |
| **G2** | a session-level **`workout.easierOption`** | Y06 offers a whole alternative session ("gentle mobility, 15 min, floor only, coach-approved"), not a per-move swap | **request** (OQ-4). Fallback if declined: `GentlerSessionSelector` picks from the bundled library and the card is labelled **"App suggestion"**, which is the distinction Y03 and Y06 already draw on screen |
| **G2** | `users/{uid}.profile.{allergies, dietary, lifeStage, language}` | passed to G5 for Y07; `lifeStage` pre-selects Y01's context chips | exists |
| **G4** | a today-only apply for a whole alternative session | Y06's "Use this option" | **request** (OQ-4) — G4 publishes `SwapMoveUseCase` for a per-move, today-only swap; a session-level alternative has no published entry point yet |
| **G4** | `TrainSuggestionGate.shouldOfferGentler(checkin)` | R01's "Not feeling it today?" row | exists — **and I propose it delegate to `SymptomSuggestionResolver`** so rule 4 has one implementation, the way rule 9 has one undo (OQ-5) |
| **G5** | `EatSuggestionRanker` + `AllergyGuard.screen()` | Y07's three options, allergies applied **before** ranking | **request** — G5 publishes `MealDayReader` and `usualPlates` but not the ranker; Y07 needs `rank({SymptomContext})` (OQ-6) |
| **G6** | nothing read, nothing written | — | Y11's "it costs you nothing" is a **week-accounting claim I cannot honour myself** (OQ-7) |
| **G7** | `users/{uid}.privacy`, `AccountDeletionService` | A02 hosts the cycle row; G7 states plainly that the cycle group owns Y12's writes | exists |
| **G8** | `Repository.write`, `DocIds.day()`, `AppClock.dayKey()`, `SyncStatusScope`/`SyncBadge`, `ErrorPresenter`, offline persistence, the single ruleset, Remote Config (`careContentVersion`) | K1–K12 conformance | exists |
| **G8** | `AnalyticsGateway` | **not consumed — deliberately.** G9 has zero call sites | by design |
| **G11** (coaching, not yet planned) | `relationships/{relId}.{status, coachUid, clientUid}` | the read-time check behind `granted` vs `orphaned` | **forward interface**, published below |

### 7.2 Published

| Published | Consumers | Contract |
|---|---|---|
| `users/{uid}/cycle/current`, `users/{uid}/periods/*` | **nobody.** No group reads these paths directly, including the coach app | the ownership table says "G9 only — never a coach unless sharing is on", and §6 R1 makes that true in rules |
| **`SymptomContext`** (domain value object) | G3 (T01 cycle row), G4 (R01 gentler row), G5 (Y07 ranking) | today's logged symptoms **only**. No date, no phase, no cycle day — so no consumer can reintroduce §2.4's violation downstream |
| **`SymptomSuggestionResolver.resolve()`** | G4 | the single implementation of rule 4, offered so R01 and Y03 cannot drift apart |
| **`SevereSymptomGate.evaluate()`** | G4, G5 | a severe day suppresses the Train row and the meal-suggestion card too, not only Y03's. Y11's note — "never a meal-based answer" — is this call |
| **`CycleSharingPolicy.projectionFor({relId, category})`** + the `getCycleProjection` callable | G11, G12/G14 (W02's constraints panel, W09's "Shared wellbeing" row) | three independent categories; each returns either the projection or `notShared`. Contract below |
| **`CycleDeletionService.purge(uid)`** + the paths `users/{uid}/cycle/**`, `users/{uid}/periods/**` | G7 | A02's account deletion and Y12's feature-only deletion run the same purge |
| **Ratification of G3's check-in enums** (their Q6) | G3 | below — this closes a question that blocks their rules deploy |

**The coach projection contract** (what W02 and W09 may render):

| Category | Switch | Contains | Never contains |
|---|---|---|---|
| `energyAppetite` | `sharing.energyAppetite` | last 7 days of `energy` and `appetite`, coarse values only | a date, a phase, a period day |
| `symptoms` | `sharing.symptoms` | last 7 days of `cramps`, `bloating`, `sleep`, coarse | free text, a severity trend line, any inference |
| `datesAndPatterns` | `sharing.datesAndPatterns` | current period day, `recentStarts` (≤12) | an ovulation date, a fertile window, a prediction |
| any, when off | — | `notShared` | an empty panel, a zero, or a blank that reads as "no symptoms" |

**Answering G3's Q6 — the check-in enums, ratified.** G3 wrote conservative value sets into its rules
because no group had published them, and asked the cycle group to ratify or replace them before deploy.
**Ratified verbatim, with no change**, against Y04's chips:

| Field | G3's rule enum | Y04's chips | Verdict |
|---|---|---|---|
| `energy` | `low \| ok \| high` | Low · Okay · High | ✅ |
| `cramps` | `none \| mild \| moderate \| severe` | None · Mild · Moderate · Severe | ✅ — `severe` is half of §2.5's gate |
| `appetite` | `low \| ok \| high` | Less hungry · Usual · More hungry | ✅ values, display mapping `low→less`, `ok→usual`, `high→more` |
| `sleep` | `poor \| ok \| good` | behind "More to log" | ✅ |
| `bloating` | `none \| mild \| moderate \| severe` | behind "More to log" | ✅ |
| `bleeding` | `none \| spotting \| light \| medium \| heavy` | behind "More to log" | ✅ — `heavy` is the other half of §2.5's gate |

Two requirements attached to that ratification: **(a)** every field stays nullable and a check-in with no
fields is a valid document — `noCheckIn` is a state, not an error; **(b)** the reader must never fall back
to a previous day. Both are Y04's on-screen promise and §3.3's first transition.

---

## 8. Test cases — rows in the exact format of `tests/TEST-CASES.csv`

Columns: `id,priority,journey,screens,precondition,steps,expected,rule_protected,platform,scope`.
**63 rows: 18 P0, 5 P1, 40 P2.** `scope` is `Post-MVP` to match the five cycle rows already in the file
(`P1-RULE-04`, `P1-RULE-05` among them); see OQ-9 — D1 removed the cut, so that column's vocabulary is now
stale for the whole suite and should be re-labelled once, globally, not just for my rows.

**Already in the suite and mine to answer for:** `P1-RULE-04` (Y03, Y05, Y06) and `P1-RULE-05` (Y04, Y11).
The `P1-CYC-*` rows below do not replace them — they test the *structural* guarantees (an import graph, a
sealed type, an index exemption) that make the behavioural rows hard to break by accident.

```csv
P0-CYC-01,P0,Set up My cycle — dates and symptoms,"Y01,Y02,Y03",Verified account with no cycle document,Open My cycle from Home > choose 'Track periods and symptoms' > continue > enter a last period start > save preferences,"Y03 opens showing the day she logged, labelled 'Logged by you'. Usual cycle length stays 'Not sure' — nothing pre-fills 28 days. All three sharing switches are off.",Sharing switches default off; no invented cycle length,both,Post-MVP
P0-CYC-02,P0,Set up My cycle — symptom-only mode,"Y01,Y14,Y08",Verified account with no cycle document,Open My cycle > choose 'Track symptoms only' > continue,"The hub renders the symptom-only state: no calendar tab, no estimate, no phase name, no cycle ring. Her planned workout is shown unchanged. Y14 is a state of the hub route, never a separate destination.",No phase and no forecast without dates,both,Post-MVP
P0-CYC-03,P0,Skipping setup leaves the app exactly as it was,"Y01,T01",Verified account with no cycle document,Open My cycle > tap 'Skip setup' > return to Home,"No cycle document is written. Home shows no cycle card, no check-in prompt and no trace of the feature. Nothing elsewhere in the app changes.","F80: My cycle is optional, and skipping costs nothing",both,Post-MVP
P0-CYC-04,P0,Daily check-in — three taps and nothing carried over,"Y04,Y03","Cycle set up; a check-in with severe cramps was saved yesterday",Open 'How are you feeling?' > observe the initial state > log energy okay and cramps none > save,"Every chip starts unselected — yesterday's severe cramps do not prefill today. The save takes three taps, all optional, and the hub returns to her unchanged plan.",Nothing is carried over from yesterday,both,Post-MVP
P0-CYC-05,P0,A logged symptom changes the suggestion — a date never does,"Y03,Y05,Y06",Cycle set up with a period logged as starting yesterday,Log low energy and mild cramps > open the gentler card > tap 'Why this suggestion?',"The gentler option appears and its reason names what she logged — low energy, mild cramps, today only. The period day is stated as a fact and never given as a reason. 'Keep mine' leaves the planned session untouched.","Suggestions follow logged symptoms, never an inferred phase",both,Post-MVP
P0-CYC-06,P0,Severe symptoms remove the workout suggestion entirely,"Y04,Y11,Y03",Cycle set up,Log severe cramps > save the check-in,"The hub shows medical guidance and a route to care. No workout, no gentler option and no meal-based answer appears anywhere on the screen, including the Train entry row. A rest row is offered and is not framed as a failure.",Severe symptoms replace the workout suggestion,both,Post-MVP
P0-CYC-07,P0,Route to care — Android including the fallback,Y11,Android device with severe symptoms logged,Tap 'Find care near you' > then repeat with no maps application installed and with no network,"With maps present it opens a geo intent. With none, or offline, a bundled list with an emergency number renders in-app and is dialable. The screen never dead-ends and never shows a raw error.",A route to care always exists,android,Post-MVP
P0-CYC-08,P0,Route to care — iOS including the fallback,Y11,iOS device with severe symptoms logged,Tap 'Find care near you' > then repeat with Maps restricted by Screen Time and with no network,"Maps opens when available; otherwise the same bundled in-app list and dialable emergency number render. Parity with Android is verified, not assumed.",A route to care always exists,ios,Post-MVP
P0-CYC-09,P0,Log a period then correct it,"Y08,Y09",Cycle set up in dates-and-symptoms mode,Log a period starting three days ago with 'still bleeding' > save > reopen it > set an end date of yesterday > save,"Both saves land. The calendar shows the days as logged. The still-bleeding flag clears when the end date is set — the two can never disagree. Estimates are recomputed from the corrected dates.",A period can be added and edited,both,Post-MVP
P0-CYC-10,P0,Impossible dates are refused rather than stored,Y09,Cycle set up,Attempt a start date in the future > then an end date earlier than the start,"Each is refused on screen with the reason, before any write is attempted. No document is created, so there is nothing to undo and nothing to sync.",Future dates and end-before-start are rejected,both,Post-MVP
P0-CYC-11,P0,Delete a period and the estimates built on it,"Y09,Y08",A period logged two cycles ago,Open that period > delete it > return to the calendar,"The period disappears from the calendar and the next-period estimate is recomputed without it. The pattern counts on Your patterns fall accordingly. No stale estimate survives.",Editing or deleting a date clears estimates built on it,both,Post-MVP
P0-CYC-12,P0,Logged and estimated are distinguishable without colour,Y08,Two cycles of logged periods,View the month > enable grayscale and a screen reader,"Logged days are solid with a text label, estimates are dashed and labelled 'est.'. Colour is never the only signal. The estimate is stated as a range with its reason, and no day is labelled confirmed ovulation.","Estimates are never presented as facts",both,Post-MVP
P0-CYC-13,P0,Sharing is off by default and each switch is independent,"Y12,G02",Active coaching relationship; cycle set up,Open cycle settings > observe > turn on 'Energy and appetite' only,"All three start off. Turning one on leaves the other two off. The preview states exactly what the coach would see. Coaching never required any of them.","Sharing switches are independent and default off",both,Post-MVP
P0-CYC-14,P0,Revoking a switch removes the coach's derived panel,"Y12,W02,W09","Cycle sharing on for energy and appetite; coach signed in",Turn the switch off > reload the coach's client screen and her weekly review,"The coach's wellbeing panel shows 'not shared' rather than an empty panel or a zero. The derived row disappears from the weekly review. Nothing cached on the coach's device still renders the old values.",Turning a switch off revokes the coach's derived panels,both,Post-MVP
P0-CYC-15,P0,Cycle sharing ends with the coaching relationship,"G16,Y12,W02",A finished coaching relationship that had cycle sharing on,End or expire the relationship > open the coach's view of that client > open cycle settings as the client,"The coach sees 'not shared' with no further action by the client. The client's settings show the switches off. A new relationship with a different coach does not inherit the grant.",A grant never survives the relationship it was given for,both,Post-MVP
P0-CYC-16,P0,Delete cycle data without touching the rest of the app,Y12,Cycle set up with periods and check-ins logged,Open cycle settings > 'Delete cycle data' > confirm,"The cycle document and every period are deleted. Workouts, meals, rewards and week counting are untouched. The screen states plainly what was deleted and what was kept, and the feature returns to its not-set-up state.",F88: cycle data is deletable on its own,both,Post-MVP
P0-CYC-17,P0,Offline — a period and a check-in save with no signal,"Y04,Y09,Y08",Airplane mode,Log a period > log a check-in > reopen the calendar > restore the network,"Both save locally and render at full opacity with a queued glyph. No spinner, no error, no disabled control. Both sync on reconnect with no duplicate document and no second period.",Logging never requires signal; a replay creates no duplicate,both,Post-MVP
P0-CYC-18,P0,Meal options follow symptoms and adding is not eating,Y07,"Cycle set up; sesame allergy recorded; more hunger logged today",Open the meal options from the cycle hub > add one to the plan,"At most three options, none containing sesame, each with its reason written on the card. Adding updates today's plan and does not log the meal as eaten — the count of logged meals is unchanged.",Allergies are applied before ranking; adding is not logging,both,Post-MVP
P1-CYC-01,P1,Product rule guard,"Y03,Y05,Y06,Y08",App built and running,"Inspect the import graph and the signature of the only function that produces a suggestion, then log high energy and no cramps on period day 2","No suggestion path can reach a cycle phase: the resolver takes today's check-in and nothing else, and the phase estimator is not importable outside the calendar's presentation folder. The usual strength session stays.",A cycle phase is not an input to any suggestion,both,Post-MVP
P1-CYC-02,P1,Product rule guard,"Y04,Y11",App built and running,Log severe cramps and inspect the suppressed result type,"The suppressed result carries no workout, alternative or session field, so no workout affordance can be rendered even by a widget that tried. Adding one is a compile-time change.",Severe symptoms suppress the training suggestion,both,Post-MVP
P1-CYC-03,P1,Product rule guard,"Y12,G02,W02",App built and running,"Create a fresh cycle document; then grant one switch, revoke it, and end the relationship","A new document has every sharing switch false. Setting one never sets another. Revocation and a finished relationship both make the projection 'not shared' at read time, with no revocation write required.","Sharing switches are independent, default off, and revoke on the way out",both,Post-MVP
P1-CYC-04,P1,Product rule guard,"Y03,Y04,Y08,Y09,Y10,Y12",App built and running with a network capture attached,"Exercise every cycle screen — set up, check in, log a period, open patterns, change sharing — and inspect every analytics payload and the feature's call sites","No cycle or symptom datum reaches analytics in any form, including as a bucketed integer. The cycle feature contains zero analytics call sites; only G8's router screen views are emitted.",PDPL: cycle data is never sent to analytics under any circumstance,both,Post-MVP
P1-CYC-05,P1,Product rule guard,"Y08,Y10",Deployed Firestore project,"Inspect firestore.indexes.json, then attempt a collection-group query over periods and a cross-user read of another woman's cycle document","All nine single-field exemptions are deployed, so no cycle field carries an index. The collection-group query is unexecutable and the cross-user read is denied. A coach with an active, fully shared relationship is also denied a direct read.",Cycle data is not queryable across users at the storage layer,both,Post-MVP
P2-RTL-Y01,P2,Arabic RTL,Y01,App language set to Arabic,Open Y01 and inspect layout and mirrored icons,"Layout mirrors, directional icons flip, numerals stay Western, no clipped or overlapping text.",,both,Post-MVP
P2-TXT-Y01,P2,Large text,Y01,System text scale at maximum,Open Y01 at the largest text size,"No clipping, no overlap, no unreachable control. Every action stays tappable.",,both,Post-MVP
P2-OFF-Y01,P2,Offline behaviour,Y01,Airplane mode,Complete setup on Y01 with no network,"Saves locally and queues, with a queued indicator. Never a silent failure, never an endless spinner.",,both,Post-MVP
P2-ERR-Y01,P2,Server error handling,Y01,Backend rejects the write,Complete setup on Y01 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.,,both,Post-MVP
P2-RTL-Y02,P2,Arabic RTL,Y02,App language set to Arabic,Open Y02 and inspect layout and mirrored icons,"Layout mirrors, dates read correctly, numerals stay Western, no clipped text.",,both,Post-MVP
P2-TXT-Y02,P2,Large text,Y02,System text scale at maximum,Open Y02 at the largest text size,"No clipping, no overlap, no unreachable control.",,both,Post-MVP
P2-OFF-Y02,P2,Offline behaviour,Y02,Airplane mode,Save preferences on Y02 with no network,"Saves locally and queues, with a queued indicator. Never a silent failure.",,both,Post-MVP
P2-ERR-Y02,P2,Server error handling,Y02,Backend rejects the write,Save preferences on Y02 against a failing backend,A human-readable error naming the problem and the recovery. State is not corrupted.,,both,Post-MVP
P2-RTL-Y03,P2,Arabic RTL,Y03,App language set to Arabic,Open Y03 and inspect layout and mirrored icons,"Layout mirrors, tabs and chevrons flip, numerals stay Western.",,both,Post-MVP
P2-TXT-Y03,P2,Large text,Y03,System text scale at maximum,Open Y03 at the largest text size,"No clipping, no overlap, the suggestion card and its reason both stay readable.",,both,Post-MVP
P2-RTL-Y04,P2,Arabic RTL,Y04,App language set to Arabic,Open the check-in sheet in Arabic,"Chip rows mirror, the sheet reads right to left, nothing is clipped.",,both,Post-MVP
P2-TXT-Y04,P2,Large text,Y04,System text scale at maximum,Open the check-in sheet at the largest text size,"Every chip stays tappable and legible; the sheet scrolls rather than clipping.",,both,Post-MVP
P2-OFF-Y04,P2,Offline behaviour,Y04,Airplane mode,Save a check-in with no network,"Saves locally and queues with a queued indicator; the undo window still works. Never a failure message.",,both,Post-MVP
P2-ERR-Y04,P2,Server error handling,Y04,Backend rejects the write,Save a check-in against a failing backend,A human-readable error with a retry. No raw exception text. The local value is not silently lost.,,both,Post-MVP
P2-RTL-Y05,P2,Arabic RTL,Y05,App language set to Arabic,Open the 'Why this suggestion?' sheet in Arabic,"Layout mirrors, the source link and arrow flip, nothing is clipped.",,both,Post-MVP
P2-TXT-Y05,P2,Large text,Y05,System text scale at maximum,Open the sheet at the largest text size,"The logged-symptom card and the guidance both stay fully readable.",,both,Post-MVP
P2-RTL-Y06,P2,Arabic RTL,Y06,App language set to Arabic,Open the gentler-option screen in Arabic,"Layout mirrors, the planned and option rows read correctly, numerals stay Western.",,both,Post-MVP
P2-TXT-Y06,P2,Large text,Y06,System text scale at maximum,Open the screen at the largest text size,"Both choices and 'Rest today' stay visible and tappable without scrolling past them.",,both,Post-MVP
P2-RTL-Y07,P2,Arabic RTL,Y07,App language set to Arabic,Open the meal options in Arabic,"Layout mirrors, filter chips flip, minutes and counts stay Western.",,both,Post-MVP
P2-TXT-Y07,P2,Large text,Y07,System text scale at maximum,Open the meal options at the largest text size,"Each card's reason line stays readable; no action is pushed off screen.",,both,Post-MVP
P2-RTL-Y08,P2,Arabic RTL,Y08,App language set to Arabic,Open the calendar in Arabic,"The month grid mirrors correctly, weekday initials are localised, day numbers stay Western, navigation chevrons flip.",,both,Post-MVP
P2-TXT-Y08,P2,Large text,Y08,System text scale at maximum,Open the calendar at the largest text size,"Day cells keep their text labels — 'day 1' and 'est.' remain legible rather than clipped, since colour is never the only signal.",,both,Post-MVP
P2-RTL-Y09,P2,Arabic RTL,Y09,App language set to Arabic,Open the period sheet in Arabic,"Fields mirror, the date picker opens in Arabic, dates render correctly.",,both,Post-MVP
P2-TXT-Y09,P2,Large text,Y09,System text scale at maximum,Open the period sheet at the largest text size,"Save, delete and cancel all stay reachable; the validation message is fully visible.",,both,Post-MVP
P2-OFF-Y09,P2,Offline behaviour,Y09,Airplane mode,Save a period with no network,"Saves locally and queues with a queued indicator; the calendar shows it immediately. Never a silent failure.",,both,Post-MVP
P2-ERR-Y09,P2,Server error handling,Y09,Backend rejects the write,Save a period against a failing backend,A human-readable error with a retry. The calendar does not show a period that was refused.,,both,Post-MVP
P2-RTL-Y10,P2,Arabic RTL,Y10,App language set to Arabic,Open Your patterns in Arabic,"The chart mirrors, labels are localised, counts stay Western, the described sentence reads naturally.",,both,Post-MVP
P2-TXT-Y10,P2,Large text,Y10,System text scale at maximum,Open Your patterns at the largest text size,"Bar labels and the counts sentence stay legible; the toggle row does not clip.",,both,Post-MVP
P2-OFF-Y10,P2,Offline behaviour,Y10,Airplane mode,Open Your patterns and change the adaptation toggle with no network,"The chart renders from cached check-ins or states plainly that some days are not available. The toggle saves locally and queues.",,both,Post-MVP
P2-ERR-Y10,P2,Server error handling,Y10,Backend rejects the write,Change the adaptation toggle against a failing backend,A human-readable error and the switch returns to its true position. No silent disagreement between the switch and the stored value.,,both,Post-MVP
P2-RTL-Y11,P2,Arabic RTL,Y11,App language set to Arabic,Open the severe-symptom state in Arabic,"Layout mirrors, the support card and its actions read correctly, nothing is clipped.",,both,Post-MVP
P2-TXT-Y11,P2,Large text,Y11,System text scale at maximum,Open the severe-symptom state at the largest text size,"The guidance text and both care actions stay fully visible — this is the one screen that must never truncate its advice.",,both,Post-MVP
P2-RTL-Y12,P2,Arabic RTL,Y12,App language set to Arabic,Open cycle settings in Arabic,"Switch rows mirror, the coach preview reads correctly, nothing is clipped.",,both,Post-MVP
P2-TXT-Y12,P2,Large text,Y12,System text scale at maximum,Open cycle settings at the largest text size,"Every switch label and the preview sentence stay readable; no switch is pushed off screen.",,both,Post-MVP
P2-OFF-Y12,P2,Offline behaviour,Y12,Airplane mode,Turn a sharing switch off with no network,"The switch saves locally and queues, and the copy states that the coach stops seeing it once back online — it never claims immediate revocation.",Copy must not promise revocation that cannot happen offline,both,Post-MVP
P2-ERR-Y12,P2,Server error handling,Y12,Backend rejects the write,Turn a sharing switch against a failing backend,A human-readable error and the switch returns to its true stored position. A sharing switch never shows a state the server did not accept.,,both,Post-MVP
P2-RTL-Y13,P2,Arabic RTL,Y13,App language set to Arabic,Open the phases sheet in Arabic,"Layout mirrors and the four explanations read naturally in Modern Standard Arabic.",,both,Post-MVP
P2-TXT-Y13,P2,Large text,Y13,System text scale at maximum,Open the phases sheet at the largest text size,"All four cards stay readable and the sheet scrolls rather than clipping.",,both,Post-MVP
P2-RTL-Y14,P2,Arabic RTL,Y14,App language set to Arabic,Open symptom-only mode in Arabic,"Layout mirrors, the planned workout row reads correctly, nothing is clipped.",,both,Post-MVP
P2-TXT-Y14,P2,Large text,Y14,System text scale at maximum,Open symptom-only mode at the largest text size,"The mode explanation and the planned workout card stay fully readable.",,both,Post-MVP
```

---

## 9. Scalability gate — my own result

| Gate | Result | Evidence |
|---|---|---|
| **Unbounded collection scan** | **PASS** | One query exists in the group: a `__name__` range over `periods` bounded to a displayed month, ≤2 documents. Y10 is ≤6 document gets from a ≤12-element bounded array, hard-capped in `PatternWindow.maxDays`. `PeriodRepository` is the only query site (G8's `chokepoint_test`), and `cycle` has `allow list: if false` so a listing is not merely unwritten, it is denied. |
| **Per-user fan-out write growing with followers** | **PASS** | G9 writes only to the woman's own two paths. The coach panel is **fan-out on read** (C9) — a projection computed when the coach opens the screen, never a copy pushed anywhere. No write in this group depends on any other user's existence. |
| **Unindexed query on a hot path** | **PASS** | The hot path (Y03, and T01's cycle row) performs **zero** queries — it is one cached document plus G3's and G2's already-read documents. The only query is `__name__`, which is always indexed, on a cold path opened ~0.15 days. |
| **A design needing a migration to reach 100k MAU** | **PASS, with one named condition** | Additive-only schema (K11); deterministic ids; `recentStarts` bounded at 12 and `contextFlags` at 6, so no document grows without limit; each document written a few times a day by exactly one woman, far inside the ~1 write/s/doc ceiling — no sharding, ever. **The condition:** OQ-1 must be settled *before* Stage 3, because choosing `users/{uid}/cycle/current` versus a map on the root user document is exactly the kind of change that becomes a migration of the most sensitive collection in the product if it is decided after launch. It is raised now so that it is a decision and not a migration. |

**Cost envelope:** ≈ **$0.51/month** at 35,000 DAU — reads $0.25, writes $0.17, storage $0.09. Against
`RECONCILIATION.md` §3's ≈$75–95 infrastructure total, G9 is rounding error, and no effort should be spent
optimising it at the cost of any guarantee in §5.

---

## 10. PDPL statement — what is stored, what leaves the device, what the retention is

Egypt's PDPL (Law 151/2018, Executive Regulation Decree 816/2025) treats health data as **sensitive
personal data**: it requires a separate, explicit, purpose-specific consent, a written basis for any
transfer, and it carries the higher penalty tier. Stated plainly, as the brief requires:

| Question | Answer |
|---|---|
| **What is stored** | Her chosen mode, her context flags, an optional usual cycle length, four on/off switches for her own screens, three sharing switches, the dates of her periods, and a bounded list of the last 12 period start dates. **Symptoms are not stored by G9** — they are G3's daily check-in, which the rest of the app already uses. |
| **What leaves the device** | Those documents, to her own Firestore user subtree, encrypted in transit and at rest. Nothing else. A coach receives a **derived projection** — never the documents — only for a category she switched on, only for the relationship she switched it on for, and only while that relationship is live. |
| **What never leaves the device** | Any cycle or symptom datum to analytics, in any form, at any time. There is no G9 analytics event, no G9 property, and no call site in the feature (§5). The assistant is sent the question, equipment and the avoid list only (HANDOFF's data-minimisation clause). No third party, advertiser or content pipeline receives any of it. |
| **Consent** | Setup (Y01) is the separate, purpose-specific consent for processing; each sharing switch (Y12/G02) is a separate consent for disclosure, granular by category and revocable in one tap. Nothing is bundled with the coaching contract — *"Coaching never requires it"* is on screen and is true in the rules. |
| **Retention** | Until she deletes it. Y12 deletes cycle data on its own without touching the rest of the account; A02's account deletion removes it with everything else (§6 R3). There is **no** archival copy, no analytics warehouse copy, no backup that outlives the deletion, and no pseudonymised residue — unlike `reports/**`, which G7 retains for safety reasons, cycle data has no such justification and is removed outright. |
| **Where it is processed** | Firestore in the project's region, plus one Cloud Function that computes the coach projection. If the region is outside Egypt, PDPL requires a cross-border transfer basis — a legal item, named in OQ-10, not an engineering one. |

---

## 11. Open questions

| # | Question | Why it is not mine to settle | Proposal |
|---|---|---|---|
| **OQ-1** | **`users/{uid}/cycle` is not a valid document path.** It has an odd number of segments, so it is a collection; it cannot hold `{ mode, contextFlags, adaptation{}, sharing{} }`. Same defect class as G8's `syncQueue`. | Spine text, which I may not edit. | Ratify **`users/{uid}/cycle/current`** — a single fixed document id, the shape G5 used for `eatPrefs/current`. I have planned against it throughout. The alternative (a map on the root `users/{uid}` document) is cheaper by ~1 read/session but puts cycle state on the document six groups read, and the choice must be made **before** Stage 3 or it becomes a migration. |
| **OQ-2** | **Two homes for one sharing switch.** Spine §8 gives `relationships/{relId}.sharing{}` to G11 *and* `users/{uid}/cycle.sharing{}` to G9. Two groups writing one consent is a rejected plan, and worse, a consent with two sources of truth is a consent that can disagree with itself. | `relationships/**` is G11's and G11 has no Stage 2 plan yet. | **G9's map is authoritative for cycle categories; G11's covers non-cycle coaching consents** (logs, results, messages). Add `sharing.grantedForRelId` so a grant is bound to one relationship and can never be inherited by the next coach. G11 must not write cycle sharing. |
| **OQ-3** | **G3 publishes the check-in path but not a command to write it.** Y04 is my screen and G3's document; the spine forbids me writing it directly. | `checkins/*` is G3's. | `CheckInRepository.merge(Map<CheckInField, Object?>)` routed through `LogCommandBus`, mirroring the three commands G3 itself had to request from G4/G5/G6. Blocks Y04 until it exists. (G3's own Q6 is **answered** in §7.2 — enums ratified verbatim.) |
| **OQ-4** | **Y06 offers a whole alternative session; nothing publishes one.** G2's assignment has `moves[]` and G4 publishes a per-*move* today-only swap, but Y06's "gentle mobility, 15 min, floor only, **coach-approved**" is a session-level alternative with a provenance label. | `plans/**` is G2's; the apply path is G4's. | G2 adds `workout.easierOption` (a session shape) and G4 publishes a today-only apply for it. If either declines, `GentlerSessionSelector` picks from the bundled library and the card is labelled **"App suggestion"** — which Y03 and Y06 already distinguish on screen — and the words "coach-approved" must then be cut rather than faked. |
| **OQ-5** | **Rule 4 risks two implementations.** G4's `TrainSuggestionGate.shouldOfferGentler(checkin)` decides R01's row; my `SymptomSuggestionResolver` decides Y03's. Two implementations of one rule drift, and the reconciliation already established one implementation per rule for undo. | G4's class. | G4's gate delegates to `SymptomSuggestionResolver`. One rule, one implementation, one test. |
| **OQ-6** | **Y07's ranker is unpublished.** G5 publishes `MealDayReader` and `usualPlates` but not the suggestion ranker, and Y07 needs it parameterised by symptoms with `AllergyGuard.screen()` applied **before** ranking. | G5's domain. | `EatSuggestionRanker.rank({SymptomContext ctx})`. The allergy guard ordering is already G5's stated design; this only needs the entry point exposed. |
| **OQ-7** | **Y11 promises "Rest today · marked as planned rest — it costs you nothing", and nothing makes that true.** D5 says skipping training days has a consequence at the week level; G2 says absence of an assignment is rest, but this is rest on a *training* day. As built, resting here costs her the week's adherence and the copy is false. | Week accounting is G6's; the promise is the owner's. | Either G6 publishes `WeeklyGoalService.markPlannedRest(date)` which reduces that week's `sessionsTarget` by one — **capped**, or it becomes an unlimited exemption — or the copy changes to what is true: "your plan is still there; the week counts sessions, not days." **A false promise on the severe-symptom screen is the worst place in the product to have one.** |
| **OQ-8** | **Y12's "Delete cycle data" cannot delete the symptoms**, because they live in G3's check-ins and carry energy, sleep and appetite that Today, Train and Eat all use. A woman tapping it will reasonably expect her symptom history to go. | The wording is the owner's; the data is G3's. | Y12 states exactly what is deleted (mode, settings, period dates, patterns) and what is kept and why, with a second explicit action to clear the symptom fields of past check-ins if she wants that. Needs copy and an Arabic translation — I must not invent either. |
| **OQ-9** | **The `scope` column in the test suite is stale.** It reads `MVP` / `Post-MVP`, a vocabulary D1 withdrew. My 63 rows use `Post-MVP` only to match the five cycle rows already in the file. | The suite is the Stage 1 owner's. | One global re-label after all Stage 2b plans land — not a per-group fix, or the column will end up meaning three different things. |
| **OQ-10** | **Cross-border transfer basis.** If the Firestore region is outside Egypt, PDPL requires a documented transfer basis for sensitive personal data, and the same applies to the Cloud Function that computes the coach projection. | Legal and infrastructure, not engineering. | Name the region in the runbook and obtain the basis before launch. Already adjacent to the existing PDPC registration row in the owner track. |
| **OQ-11** | **The care directory for Y11 has no content owner.** "Find care near you" needs an Egyptian source; the product currently cites NHS guidance, which is British. | Content and clinical sign-off. | Bundle a short, versioned, clinically reviewed list (including the national ambulance number) behind `careContentVersion` in Remote Config, plus a maps intent. The guidance text needs a named clinical reviewer — the screen gives medical advice, and an unreviewed sentence there is the highest-liability string in the app. |
| **OQ-12** | **Adaptation defaults.** The spine annotates the cycle document "default OFF"; Y02 renders its three adaptation toggles pre-checked. I read the spine's annotation as binding on `sharing.*` (C12/HANDOFF 6) and the prototype as binding on `adaptation.*`, with no document existing until she completes setup. | A product intent question. | Confirm the reading. If "default OFF" was meant to cover adaptation too, Y02's toggles must ship unchecked and the screen's meaning changes materially. |

---

## 12. What this plan does not do, stated so it is not mistaken for an oversight

- **No prediction beyond a stated range.** No ovulation day, no fertile window, no "you are here" ring, no
  hormone curve. Y13 explains the phases in words precisely because a calendar cannot measure them, and
  §1.1 makes a predicted phase unstorable rather than merely unused.
- **No contraceptive claim, anywhere.** Y05's standing note — *"for general wellbeing, not diagnosis or
  contraception"* — is a required string, not decoration.
- **No cycle data in the community, in a feed, in a ranking, or in an ad.** There is no path: the data is
  self-read only, and `allow list: if false` means no cross-user query exists to build one from.
- **No daily streak, no adherence score, no "readiness".** C6, and Y10's own copy: it describes her logs
  and does not explain a cause.
