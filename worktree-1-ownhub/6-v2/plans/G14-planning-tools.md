# G14 — The coach's planning tools

Splits, assessments, meal plans, re-assessments, and the publish step.

**Screens (16):** `W01` `W02` `W03` `W04` `W05` `W06` `W07` `W08` `W09` `W10` `W11` `K19` `K20` `K21`
`K22` `K23`. `K26`/`K27` are G15's. `K24`/`K25` are flow `coach`, not `coachplan`, and are G12's.

**Features covered:** F58, F63, F65, F66, F67, F68, F94, F96, F97, F99, F100, F101, F102, F103, F121,
F122, F123, F126 (W11 half).

**Inputs obeyed:** `DECISIONS.md` (authoritative; D1, D7), `SCHEMA-SPINE.md` §1–§8 (fixed),
`HANDOFF.md` rules 1–17, `BUILD-BRIEF.md` §2/§3/§4/§6 (§0 ignored — withdrawn by D1),
`plans/RECONCILIATION.md`. I write no file but this one.

**What I write:** `coaches/{coachUid}/splits/*`, `assessments/*` (spine §8 ownership table), plus two
extensions inside my own namespace: `coaches/{coachUid}/planDrafts/*` and `coaches/{coachUid}/meals/*`.
**What I never write:** `plans/**` (G2), `relationships/**` (G11), `users/**` (G1/G2/G4/G6/G7),
`foods`/`exercises` (content pipeline).

---

## 0. The four things that shape every decision below

| # | Consequence |
|---|---|
| 1 | **A split is a template, not a plan** (r12). The template is copied **by value** into a draft; the published version keeps `templateRef` as *provenance only* and never dereferences it. There is therefore no code path by which editing a split reaches a published plan — not a guard, an absence. |
| 2 | **The assessment is the only source of constraints** (r13). No coach screen has a text input for `avoid` or allergies. W02/W06 render them from `assessments/*` and the client's own intake; both are read-only on every coach surface. |
| 3 | **`refer` is not failure** (r14). It is an outcome that *suppresses* tagged exercises and survives into re-assessment until explicitly cleared. It never blocks publishing and never shows as an error. |
| 4 | **Publishing is the only act that changes a plan** (r2, r15). I produce content and call G2's publisher. My screens can reach `draft` and nothing else. |

---

## 1. Data model

Against the spine. Extensions are inside my own collections only; every request of another group's
collection is in §7 and is flagged, never assumed.

### 1.1 `coaches/{coachUid}/splits/{splitId}` — the template (spine §8, G14 writes)

Spine declares `{ name, cycleLength, daySlots[], carryApproved }`. Filled in:

| Field | Type | Null? | Notes |
|---|---|---|---|
| `splitId` | string | no | Client UUIDv4 minted once, reused on retry (C1 allowance, same as `sessions`) |
| `name` | string ≤60 | no | K20 "Name it" |
| `cycleLength` | int 3–7 | no | K20 chip row. Hard-bounded; `daySlots.size() == cycleLength` |
| `daySlots` | list, size == `cycleLength` | no | Ordered. Shape below |
| `carryApproved` | bool | no | K20's "Keep her easier options" toggle. Default **false** |
| `source` | `'library' \| 'own'` | no | Mirrors the client field (D7 parity, §1.3) |
| `appliedCount` | int | no | K19's "on 7 clients". `FieldValue.increment` from the publish Function only (C4), and it travels with the version id in the same transaction (C4 as corrected) |
| `ownerKind` | `'coach'` | no | Discriminator that makes the two paths one model (§1.3) |
| `updatedAt`, `schemaV`, `clientWrittenAt`, `opId` | — | no | G8 K3 convention |

`daySlots[i]`:

| Field | Type | Null? | Notes |
|---|---|---|---|
| `dayIndex` | int 1..`cycleLength` | no | |
| `kind` | `'session' \| 'rest'` | no | K20's rest rows |
| `title` | string ≤60 | yes | `null` when `kind == 'rest'` |
| `minutes` | int 10\|15\|20\|30\|35\|45 | yes | |
| `moves` | list ≤20 | yes | Prescriptions only, shape identical to G2's `assignment.workout.moves[]` (§7.1) so materialisation is a copy, not a translation |
| `restBetweenSetsSec` | int 30\|45\|60 | yes | W04 |
| `approvedAlternatives` | list ≤5 of `{exerciseId, forExerciseId}` | yes | W04's "easier option"; carried only when `carryApproved` |

**No `actual*` key exists in this document, at any depth.** Enforced by `PrescriptionOnlyValidator`
(§5) and asserted in rules (§6). **No `clientUid`** — a template is not about a person.

**Size:** 7 slots × 20 moves × ~120 B ≈ **17 KB**, far inside 1 MiB.

### 1.2 `coaches/{coachUid}/planDrafts/{clientUid}__{yyyy-MM}` — the month being authored

**This document is the whole of W03/W04/W05/W06 and it is the reason a coach can plan a month with no
signal.** `plans/**` is server-authored and not writable offline (spine §5), so the work-in-progress
cannot live there. It lives in a document the coach owns.

Deterministic id (C1): `{clientUid}__{yyyy-MM}`. Sharded by month so the document cannot grow without
bound and so a 90-day plan is 3 documents, not one oversized one.

| Field | Type | Notes |
|---|---|---|
| `clientUid`, `coachUid` | string | Denormalised for per-document rule checks (§6) |
| `month` | `yyyy-MM` | |
| `status` | `draft \| publishing \| published` | §3.4 |
| `days` | **map** keyed `yyyy-MM-dd` | **A map, not a list.** See the conflict note below |
| `basedOnVersion` | string\|null | The published version this draft was opened from |
| `lastPublished` | map `{version, at, dayCount, mealSlotCount}` \| null | Written back by the publish callable. The spine's amended §2 now lets a coach read `plans/**` under an active relationship, so this is **a cost and offline choice, not a permission one**: W03/W08 render "already published" from a document she already holds — 0 extra reads, and correct with no signal, where a `plans/**` read is only available offline if it happens to be in cache |
| `templateRef` | `coaches/{coachUid}/splits/{splitId}` \| null | Provenance of a split application. **Never dereferenced at render or publish time** (r12) |
| `origin` | `'blank' \| 'split' \| 'assistant' \| 'copy'` | `assistant` when K26/K27 handed it over (§7.6) |
| `effectiveFrom` | `yyyy-MM-dd` | Clamped `max(requested, today)` at publish, by G2 |
| `updatedAt`, `schemaV`, `clientWrittenAt`, `opId`, `lastEditedByDevice` | — | G8 K3 |

`days["2026-09-16"]`:

```jsonc
{
  "kind": "workout",                    // workout | rest
  "workout": { "sessionTemplateId": "…", "title": "Full-body strength", "minutes": 35,
               "restBetweenSetsSec": 45, "note": "Keep 12 kg and aim for 12 reps.",
               "moves": [ /* G2 §1.3 shape verbatim — prescribed* only */ ],
               "approvedAlternatives": [ { "exerciseId": "box_squat", "forExerciseId": "goblet_squat" } ] },
  "meal": { "slots": { "breakfast": { "source": "library", "foodIds": ["ful_medames"], "servings": 1 },
                       "lunch":     { "source": "coach",   "coachMealId": "m_42", "servings": 1 },
                       "dinner":    { "freeChoice": true },
                       "snack":     null } },          // null = an unfilled gap, counted on W06/W08
  "fromSplit": { "splitId": "…", "dayIndex": 2 }       // provenance only
}
```

**Why `days` is a map and not an array.** G8's finding, generalised: Firestore has no field path to an
array element, so an array makes every edit a whole-document rewrite and two devices editing different
days lose one of them. As a map, `days.2026-09-16` is a field path, so distinct days merge
commutatively — exactly the correction the spine already applied to `meals.slots` in C3. Two devices
editing the *same* day is last-write-wins on that one day and nothing else (§4.2).

**Size:** 31 days × ~2 KB ≈ **62 KB**. A 12-move day with notes is ~2.5 KB; the worst realistic month
is ~90 KB. Hard cap asserted at 700 KB by `PlanDraftRepository.save()` before the write.

### 1.3 `users/{uid}/splits/{splitId}` — the same model, the client's copy (D7)

Spine §8 declares `{ name, cycleLength, daySlots[], source: 'library'|'own' }` and the ownership table
gives the **write to G4**. That stands. **I own the model; G4 owns the client's repository and entry
point.** The document shape is §1.1 with three differences, and no fourth:

| | Coach copy | Client copy |
|---|---|---|
| Path | `coaches/{coachUid}/splits/{splitId}` | `users/{uid}/splits/{splitId}` |
| `ownerKind` | `'coach'` | `'self'` |
| `appliedCount` | present, Function-written | **absent** — nothing to count |
| `approvedAlternatives` | present | **absent** — "approved" means approved *by a coach*; a woman choosing her own easier move is just editing her own split |
| May be assigned to another person | yes, via §3.3 | **never** — no code path, and rules forbid it (§6) |

### 1.4 `assessments/{assessmentId}` — the source of constraints (spine §8, G14 writes)

Spine declares `{ coachUid?, clientUid, takenAt, stage, birthType, clearance{}, avoid[], painNotes,
screening[], baseline{} }`. Filled in, with one naming correction.

**Document id:** `{scopeKey}__{takenAtIso}` where `scopeKey = "{coachUid}_{clientUid}"` (coach-authored)
or `"self_{clientUid}"`. Deterministic (C1): a two-step form saved offline and replayed overwrites
itself instead of creating a second assessment. ISO timestamps sort lexicographically, so "latest" is a
`__name__` range when needed — but the hot path never needs one (§2).

| Field | Type | Null? | Notes |
|---|---|---|---|
| `coachUid` | string | yes | `null` for a self-authored assessment. See OQ-7 |
| `clientUid` | string | no | |
| `takenAt` | timestamp | no | |
| **`lifeStage`** | `pregnant \| p0_6w \| p6w_1y \| over_1y \| none` | no | **Renamed from the spine's `stage`.** K21's chip row is the woman's life stage; `stage` reads like a workflow state and two readers already misread it. Workflow state is `status`. Flagged as OQ-6, not a silent divergence |
| `birthType` | `vaginal \| caesarean \| undisclosed` | yes | K21 |
| `clearance` | map `{ granted: bool, recordedAt: date, note?: string }` | no | K21's toggle. `granted:false` is a valid recorded answer, not a missing one |
| `avoid` | list ≤12 of `ContraindicationTag` | no | **A controlled vocabulary, not free text** (§1.5). K21's chips |
| `painNotes` | string ≤500 | yes | K21's free-text field. **Displayed to the coach; never parsed, never used to filter** — a filter driven by prose is a safety claim the product cannot honour |
| `screening` | list ≤12 of `ScreeningItem` | no | §1.5 |
| `baseline` | map `{ [measureId]: {value: num, unit: string} }` | no | K23. **No weight key of any kind** (C7) — asserted in rules |
| `parentAssessmentId` | string | yes | Set on a re-assessment (K22). Makes the chain readable without a query |
| `status` | `recorded \| superseded` | no | §3.1. `superseded` is set only by the child's write, in the same transaction |
| `schemaV`, `updatedAt`, `clientWrittenAt`, `opId` | — | no | G8 K3 |

`screening[i]` = `{ id, label, outcome: 'pass'|'modify'|'refer', clearedAt?: ts, clearedReason?: string, suppresses: [ContraindicationTag] }`.

### 1.5 `ContraindicationTag` — one vocabulary, two consumers

The avoid list (r13) and a `refer` outcome (r14) both mean *"do not let a session prescribe this"*.
They must therefore resolve into the **same** vocabulary, or the two will disagree — the exact failure
r13 was written to close.

```
high_impact · jumping · deep_knee_flexion · loaded_twisting · pelvic_floor_load
breath_hold_valsalva · prone_position · supine_load · overhead_load · wrist_load
```

Fixed, versioned with the exercise pack. `ScreeningItem.suppresses` maps an outcome to tags (pelvic
floor `refer` → `pelvic_floor_load`, `jumping`, `high_impact`). **This vocabulary must also exist on
the exercise library as `exercises[].contraindicationTags[]`, and today it does not — see OQ-1, which
is blocking and is a safety gap of the same class as G5's missing `foods.allergens[]`.**

### 1.6 `coaches/{coachUid}/meals/{mealId}` — W07, the coach's own collection

`{ name, ingredients[ {text, foodId?, grams?} ], servings, prepMinutes, labels[], note, nutrition }`.

`nutrition` is `{ resolved: bool, kcal?, proteinG? }`. **`resolved` is true only when every ingredient
carries a `foodId` from G5's verified pack.** One unresolved ingredient ⇒ `resolved:false` and *no
numbers are stored at all* — not a partial total, not an estimate. W07's card ("Nutrition details
unavailable") renders from that flag. This is rule 10's principle applied to a human author: the
product does not invent a quantity, and neither does a screen on the product's behalf.

**Never written to `foods`.** W07 says so on screen ("not added to the app's public library") and the
rules deny the client write anyway (G5 §6).

### 1.7 Indexes

| Collection | Index | Hot path? | Why |
|---|---|---|---|
| `coaches/{c}/splits` | `updatedAt` (automatic single-field) | no | K19 list, `limit 50` |
| `coaches/{c}/planDrafts` | `__name__` (automatic) | yes | Direct `get` by `{clientUid}__{month}` |
| `coaches/{c}/meals` | `updatedAt` (automatic) | no | W06 picker, `limit 50` |
| `assessments` | **composite (`coachUid` asc, `clientUid` asc, `takenAt` desc)** | **no** | K22's history action only, `limit 5`. The hot path (W02's "latest") is a direct `get` via a pointer — §2 |
| `relationships` | **composite (`coachUid`, `status`, `queue.oldestUnansweredAt`)** — G11's collection, requested §7.5 | yes | W01/W10/W11, one listener, `limit 20` |

**Composite indexes on a client P0 journey: none.** The two above are coach-side; one is off the hot
path entirely. **No index mentions weight, weight lost or followers** (C7, rule 11), and `appliedCount`
is never an `orderBy` — K19 sorts by `updatedAt`, so "on 7 clients" is a count displayed, never a
ranking (rule 11).

---

## 2. The query for every screen, with index and cost

Costed at `BUILD-BRIEF.md` §3. §3 gives no coach population, so it is derived and flagged (**OQ-5**):
100k MAU, assume **8%** are coached ⇒ 8,000 coached clients; median **12** active clients per coach
(W01 caps at 20) ⇒ **≈670 coaches**, 40% daily active ⇒ **≈270 daily active coaches**. Every fleet
figure below scales linearly with that number and is stated so it can be re-derived when the owner
supplies the real one.

**One listener serves three screens.** W01, W10 and W11 are the same `relationships` query with
different client-side sorts and filters. Opening the inbox after the client list costs **0** reads.
Stated because the naive build issues three queries and triples the coach-side read budget.

| Screen | Query | Index | Reads | Writes | Fleet/day |
|---|---|---|---|---|---|
| `W01` Clients & queue | `relationships where coachUid==me && status=='active' orderBy queue.oldestUnansweredAt asc limit 20` — **snapshot listener**; the four chips are client-side filters over the same 20 docs, not four queries | composite (G11, §7.5) | 20 first open, then deltas only ≈ **24/coach/day** | 0 | ~6,500 reads |
| `W11` Clients, none yet | Same listener, 0 documents returned | same | **0** | 0 | 0 |
| `W02` Client overview | `get relationships/{relId}` (0 — in the listener's cache) + `get relationships/{relId}/shared/constraints` + `get assessments/{rel.latestAssessmentId}` (**pointer, no query**) + `get relationships/{relId}/rollups/{isoWeek}` | `__name__` ×3 | **3** | 0 | ~2,400 reads |
| `W03` Workout planner | `get coaches/{me}/planDrafts/{clientUid}__{month}` — the whole month in **one** document. Exercise metadata from G4's bundled pack: **0** | `__name__` | **1** | ~1 per 2 s debounce burst, ≤40/session | ~1,600 reads, 5,400 writes |
| `W04` Edit a session | **0** — the draft is in memory, the 124-move library is bundled (G4 D3) | — | **0** | 1 on "Save to Tuesday" (folded into W03's) | 0 |
| `W05` Copy a week | **0** — the overwrite summary ("10 days written, 2 replaced") is computed in memory from `days` | — | **0** | 1 on confirm | 0 |
| `W06` Meal planner | **0** — same draft document as W03; constraints already loaded at W02; food pack bundled (G5) | — | **0** | 1 per burst | folded |
| `W07` Create a meal | **0** — pack only | — | **0** | 1 → `coaches/{me}/meals/{id}` | ~200 writes |
| `W08` Publish | **0** reads. Calls `publishCoachPlan` (G2 callable) | — | **0** + 1 callable | server: 1 version + N assignments | see §9 |
| `W09` Review & adjust | `get relationships/{relId}/reviews/{reviewId}` + rollup (0, cached from W02) | `__name__` | **1** | 1 `coachResponse` **via G11's API** | ~800 reads |
| `W10` Coach inbox | **0** — reuses W01's listener, sorted client-side by waiting time | same | **0** | 0 | 0 |
| `K19` My splits | `coaches/{me}/splits orderBy updatedAt desc limit 50` — cached, ~8 real documents. `appliedCount` is a stored field, **not** a cross-client count | `updatedAt` | **≤8**, ~4/coach/day amortised | 0 | ~1,100 reads |
| `K20` Build a split | `get coaches/{me}/splits/{splitId}` — **0** when arrived from K19's cache | `__name__` | **0–1** | 1 on save | ~300 writes |
| `K21` Assessment step 1 | `get assessments/{rel.latestAssessmentId}` for pre-fill — **0** when arrived from W02 | `__name__` | **0–1** | **0** (the two steps are one document, written once at K23) | ~150 reads |
| `K23` Movement screening | **0** — step 2 of the same in-memory form | — | **0** | **1** — one document for the whole assessment | ~150 writes |
| `K22` Re-assessment | `get assessments/{parentId}` (pre-fill) + history action `where coachUid==me && clientUid==X orderBy takenAt desc limit 5` | `__name__`; composite for history | **1** (+≤5 on the history tap) | 1 new doc + 1 `status` flip on the parent, same transaction | ~200 reads, 150 writes |

**Per active coach, per day:** ≈ **40 reads, 25 writes**.
**Fleet:** ≈ **13,000 reads/day (4.6% of the 280k budget)** and ≈ **7,000 writes/day (3.3% of 210k)**,
plus the publish fan-out in §9. G14 is a rounding error against the client-side budget, which is the
correct outcome — 270 coaches cannot cost what 35,000 women cost.

**Firestore cost:** ~390k reads + ~210k writes per month ⇒ **≈ $0.31/month**. Consistent with
`RECONCILIATION.md` §3: infrastructure is not what this product costs.

---

## 3. State machines

### 3.1 Assessment — `AssessmentStatus` (workflow), distinct from `lifeStage` (§1.4)

```
        ┌──────────────── K21 opened ────────────────┐
NONE ──►│ IN_PROGRESS(step1) ──Continue──► IN_PROGRESS(step2 = K23) │
        └────────────────────┬───────────────────────┘
                             │ "Save assessment" / "Save only"
                             ▼
                        RECORDED ──(K22 child saved)──► SUPERSEDED  (terminal)
IN_PROGRESS ──abandon / app killed──► DISCARDED   (local draft only; nothing was ever written)
```

| From | To | Trigger | Guard | Writes |
|---|---|---|---|---|
| NONE | IN_PROGRESS | K21 opened | coach is party to an `active` relationship | **0** — held in memory + a local autosave row |
| IN_PROGRESS(1) | IN_PROGRESS(2) | "Continue" | `lifeStage` and `clearance` answered | 0 |
| IN_PROGRESS(2) | RECORDED | "Save assessment" | every `screening[i].outcome` set; `avoid[]` tags all in the vocabulary | **1** document |
| RECORDED | SUPERSEDED | child re-assessment saved | child's `parentAssessmentId` == this id | 1, **same transaction as the child** |
| any | DISCARDED | abandon | — | 0 — nothing partial ever reaches Firestore |

**Two steps, one document.** K21 and K23 never write independently. A half-saved assessment is a
half-stated constraint, and r13 makes the assessment the *only* source — a partial source is worse than
none.

### 3.2 Screening outcome — `ScreeningOutcome`, per item (rule 14)

```
UNSET ──coach answers──► PASS
                       ├► MODIFY
                       └► REFER ──carried into every re-assessment, visibly──► REFER
                                 └──coach clears, with a reason──► CLEARED (terminal)
```

| State | Suppresses exercises? | Shown on K22? | Blocks publish? |
|---|---|---|---|
| `PASS` | no | as a before/after row | no |
| `MODIFY` | no — surfaces `approvedAlternatives` on W04 | as a before/after row | no |
| `REFER` | **yes**, via `suppresses[]` tags | **yes, prominently, until cleared** (K22's amber card) | **no — it is not a failure state** |
| `CLEARED` | no | as history, with the reason | no |

`REFER → CLEARED` is the **only** exit, it is an explicit coach action carrying a reason, and it is
recorded on a new assessment document — never by editing the old one. A referral cannot expire, decay,
or be cleared by silence.

### 3.3 Split → plan application — `SplitApplication` (rule 12)

```
TEMPLATE  (coaches/**/splits/{id}, or users/**/splits/{id})
   │
   │  SplitApplicator.materialise(split, clientUid, dateRange)   ── DEEP COPY, by value
   ▼
DRAFT_MATERIALISED  (planDrafts/{clientUid}__{month}.days, templateRef = provenance only)
   │
   │  CoachPlanPublisher.publish()  →  G2 PlanPublisher
   ▼
PUBLISHED  (plans/{clientUid}/versions/vN, source:'split', templateRef)

TEMPLATE ──edited afterwards──► TEMPLATE'      ZERO writes to any draft, version or assignment.
```

| From | To | Trigger | Guard | Effect |
|---|---|---|---|---|
| TEMPLATE | DRAFT_MATERIALISED | K20 "Save and apply to Nour", or W03 "Apply a split" | coach owns the split; an `active` relationship exists; `dateRange.start >= today` | Writes `days.*` in the draft. Existing days are **named before replacement** (W05's summary), never silently overwritten |
| DRAFT_MATERIALISED | PUBLISHED | W08 | §3.4 | G2 writes the version + assignments |
| TEMPLATE | TEMPLATE' | K20 edit | — | **Nothing else transitions.** No listener, no cascade, no job |
| PUBLISHED | — | split deleted | — | Published plans are unaffected; `templateRef` becomes a dangling provenance string and **is never dereferenced**, so nothing breaks |

**This is r12 as a structural property, not a check.** `materialise()` returns a new value object; the
draft holds no pointer to the split. There is no function that takes a `splitId` and mutates a plan.

**The client's split (D7) uses the same machine minus the first arrow's destination:** she materialises
into **her own** plan draft, and `SplitAssignmentGuard.assertMayAssign(actor, targetUid)` throws
`NotYourClient` unless `actor` is a coach with an `active` relationship to `targetUid`. A client
applying her own split to herself passes; applying it to anyone else has no code path and is denied in
rules (§6).

### 3.4 Draft / publish cycle — `PlanDraftStatus` (rules 2, 15)

```
ABSENT ──first edit──► DRAFT ⇄ DRAFT (autosave, 2 s debounce)
DRAFT ──W08 "Publish plan"──► PUBLISHING ──callable ok──► PUBLISHED(vN)
                                  │
                                  └──offline / error──► DRAFT  (intent queued; never a failure toast)
PUBLISHED ──any further edit──► DRAFT (basedOnVersion = vN)
        ──publish──► PUBLISHED(vN+1), and G2 marks vN SUPERSEDED in the same transaction
```

| From | To | Trigger | Guard | Not permitted |
|---|---|---|---|---|
| ABSENT/PUBLISHED | DRAFT | any edit on W03–W07, K26/K27 handover, split application | coach is party | — |
| DRAFT | PUBLISHING | **W08's button, and nothing else** | — | No auto-publish. No timer. No "save implies publish". **No assistant path** (r10) |
| PUBLISHING | PUBLISHED | callable returns | G2 clamps `effectiveFrom = max(requested, today)`; never rewrites a `frozen` or past-dated assignment | Rewriting a running session or a logged day (r2) |
| PUBLISHING | DRAFT | offline or error | intent queued, deterministic `opId` | A spinner, or a "failed to save" (G8's forbidden list) |
| DRAFT | DRAFT | **W09 saving feedback**, **K22 saving a re-assessment** | — | **Neither publishes.** r15, and r2's twin |

**W09 and K22 both end at DRAFT, never at PUBLISHED.** Saving a review or a re-assessment records; the
coach then revises and presses publish. See OQ-10 on W09's single button, which today implies otherwise.

---

## 4. Offline behaviour — a coach plans a month on a microbus

The demanding case is not a coach with no signal for a minute. It is a coach who opens a client, plans
thirty days, saves a split and takes an assessment, entirely offline, over forty minutes.

### 4.1 What is writable offline

| Write | Offline? | Mechanism |
|---|---|---|
| `planDrafts/*` — **the entire month** | **yes** | Her own document, Firestore offline persistence (spine §5). Deterministic id, so a replay overwrites itself |
| `splits/*` (coach and client alike) | **yes** | Own document, UUID minted once |
| `assessments/*` | **yes** | Deterministic id `{scopeKey}__{takenAtIso}` — a replayed two-step save cannot create a second assessment |
| `coaches/**/meals/*` | **yes** | Own document |
| **Publishing** | **no** | `plans/**` is server-authored (spine §5). Intent queued with `opId = 'publishCoachPlan:{clientUid}:{month}:{draftHash}'`. W08's button reads *"We'll publish the moment you're back online"* — G2's precedent, never a spinner, never a failure |
| `relationships/**` (W09 feedback, W10 messages) | G11's call | I queue the intent through G11's API and render G8's badge |

Everything a coach authors is writable offline; only the act that changes someone else's plan is not.
That is the same boundary the client side draws, for the same reason.

### 4.2 Conflict resolution

| Conflict | Resolution |
|---|---|
| Two devices editing **different days** of the same draft | Field-level merge on `days.{yyyy-MM-dd}` — clean, because `days` is a map (§1.2) |
| Two devices editing the **same day** | Last-write-wins on that one day. `lastEditedByDevice` is stamped; on divergence W03 shows one quiet line naming the other device. No other day is affected |
| `appliedCount` | `FieldValue.increment`, Function-only, travelling with the version id in the same transaction (C4 as corrected) — never read-modify-write, never double-counted on replay |
| Assessment saved twice offline | Same deterministic id ⇒ idempotent overwrite. A *re*-assessment is a different id (different `takenAt`), so it is correctly a second document |
| Publish intent replayed | `publishCoachPlan` is keyed on `{clientUid, month, draftHash}` (G2's `intakeHash` pattern). Three retries ⇒ exactly one version |
| Split edited on one device, applied on another | No conflict by construction — the application copied by value (§3.3) |

### 4.3 What the UI shows while queued

Per G8's binding convention: full opacity, trailing `cloud_queue` glyph at 60%, `l10n.syncQueued`,
`SyncStatusScope.of(context).watch(path)` / `SyncBadge(path:)` — nobody hand-rolls it.

Specific to my screens:

- **W03/W06** show the badge on the month header, not on every day row — thirty badges is noise.
- **W08** replaces its primary button's label, does **not** disable it. A disabled publish button on a
  coach who has just planned a month reads as lost work.
- **K23** shows the badge after "Save assessment" and returns to W02 immediately. The assessment is
  hers the moment she saves it; the network is not her problem.
- **Forbidden on every screen of mine:** a blocking spinner on a write, "failed to save" for anything
  that will sync, a disabled editor while offline.
- **W05's overwrite confirmation stays** even offline. `P1-RULE-09` explicitly exempts destructive bulk
  actions from the no-dialog rule ("those are not logging"), and copying a week over existing work is
  the definition of one.

---

## 5. §2 rules I own, and the exact domain-layer enforcement point

Never a widget. Every class below lives in `features/coachplan/domain/`.

| Rule | Owner | Class · method | Mechanism |
|---|---|---|---|
| **§2.1** A prescribed value is never a result | **G14** (authoring half) | `PrescriptionOnlyValidator.assert(node)`, called by `PlanDraftRepository.save()`, `SplitRepository.save()` and `SplitApplicator.materialise()` | Walks the document and throws `ActualFieldInPrescription` on any of `actualWeight`, `actualReps`, `actualSeconds`, `actualHoldSec`, `done`, `completed`, `adherence`, `loggedAt`. **No document I write has an `actual*` field at any depth**, so rule 1 is not a discipline, it is a shape |
| **§2.2** A message never changes a plan — publishing does | **G14** (coach half; G2 owns the writer) | `CoachPlanPublisher.publish()` — the sole caller of G2's `publishCoachPlan` | Every other path (`PlanDraftRepository`, `ReviewFeedbackService.save()`, `ReassessmentService.save()`, `AssistantDraftIntake.accept()`) can reach `status:'draft'` and nothing else. There is no auto-publish transition (§3.4) |
| **§2.9** Undo, not confirmation | **G14** (boundary) | `CopyWeekPlanner.summarise()` → `OverwriteSummary` | Authoring is not logging; W05 and the publish step **do** confirm, which `P1-RULE-09` explicitly permits for destructive bulk actions. No *logging* action exists on any G14 screen, so there is nothing here for the undo rule to govern — stated so QA does not read the confirmation as a violation |
| **§2.10** Selects, never generates | **G14** (intake boundary; G15 owns the assistant) | `AssistantDraftIntake.accept(draft)` | Accepts `status:'draft'` only, and re-validates **every** `exerciseId` against G4's pack and every `foodId` against G5's pack before the draft is written. An id outside the packs is rejected, not rendered. I expose no publish tool and G15 is not given one |
| **§2.11** Nothing ranked | **G14** | `SplitUsageCounter` | `appliedCount` is displayed on K19 and is never an `orderBy`; K19 sorts by `updatedAt`. No index supports the other sort (C7). `baseline{}` rejects any weight key in rules (§6) |
| **HANDOFF 12** A split is a template | **G14** | `SplitApplicator.materialise()` returns a **new value object**; `PlanDraft.templateRef` is provenance | No function accepts a `splitId` and mutates a plan. Editing a split writes zero documents elsewhere (§3.3). Test `P1-RULE-18` |
| **HANDOFF 13** The assessment is the only source of constraints | **G14** | `ClientConstraintResolver.resolve(clientUid)` → `ClientConstraints{avoid[], allergies[], dietary[], referrals[]}` | **The only** constructor of `ClientConstraints`. Sources: the latest `assessments/*` and G11's `shared/constraints` projection of the client's own intake. `ClientConstraints` has **no public setter and no coach-writable field**; W02/W06 render it read-only and no coach screen has an input that reaches it. Test `P1-RULE-19` |
| **HANDOFF 14** `refer` is not a failure state | **G14** | `ReferralRegistry.activeTags(assessment)` feeding `ExerciseCandidateFilter.screen()` | A `refer` contributes its `suppresses[]` tags to the filter and is re-rendered on K22 until `CLEARED`. It never sets an error state, never blocks `CoachPlanPublisher.publish()`, and never colours a screen as a failure. Test `P1-RULE-20` |
| **HANDOFF 15** A re-assessment never edits a published plan | **G14** | `ReassessmentService.save()` | Writes the assessment document and flips the parent to `superseded`. It returns a `PlanRevisionSuggestion` the coach may open; it **cannot** call `CoachPlanPublisher`. K22's "Save and adjust her plan" navigates to W03 — it does not publish. Test `P1-RULE-21` |
| **HANDOFF 16** First-run is a state, not a route | **G14** | `ClientsScreen` branches on `relationshipCount == 0` | **W11 is a branch inside W01's route.** `app_routes.dart` gains no destination for it and nothing navigates to it |
| **HANDOFF 17** The empty state is the onboarding | **G14** | `ClientsEmptyStateBuilder` | W11 names what will appear, why it is empty, and offers three real actions (page, splits, assessment). No tour, no overlay, no coach-mark on any G14 screen |
| **C6** No streak | **G14** | `PrescriptionOnlyValidator` ban list + rules `noStreak()` | Unstorable in every document I write |
| **C7** Nothing ranked at the storage layer | **G14** | rules + `index_allowlist_test.dart` (G8's) | `baseline` rejects `weightKg`/`weight`/`bmi`; no composite index names `appliedCount` |
| **C8** Prescribed and actual are differently-typed | **G14** | `PrescriptionOnlyValidator` | There is no single field a widget could pre-fill, because the actual field does not exist in my schema |

### 5.1 `ExerciseCandidateFilter` — the move half of "filter before selection"

G5 established the principle for food: `AllergyGuard.screen()` removes conflicting foods **before**
ranking, rather than validating after. Moves get the identical treatment, and the symmetry is
deliberate — two safety guards with different shapes is how one of them ends up weaker.

```dart
ExerciseCandidateFilter.screen(ClientConstraints c) → List<Exercise>
  // removes every exercise whose contraindicationTags[] intersects
  //   c.avoid  ∪  ReferralRegistry.activeTags(latestAssessment)
  // BEFORE the candidate list is built, on W04, K20 and the assistant's tool schema.
```

Applied at: W04's move picker, K20's day-slot editor, `SplitApplicator.materialise()` (a split applied
to a *different* client is re-screened against **her** constraints, never the previous client's), and
G15's `search_exercise_library` tool.

**Fail-closed.** If `ClientConstraints` cannot be resolved (no cache, cold start, projection missing),
the filter returns the **quiet, low-impact, floor-based** subset only and W04 shows one line: *her
constraints haven't loaded — showing the safest moves*. An unknown constraint is not an absent one.
This mirrors G5 §5.1's third property verbatim.

### 5.2 `MealSlotPlanner` — allergies before selection, on the coach's screen

W06's picker is built from `AllergyGuard.screen(clientConstraints)` — **the client's constraints, not
the coach's**. A conflicting food is therefore never offered, which is what W06's note ("an
incompatible ingredient blocks assignment rather than warning afterwards") promises.

If one arrives by another route (an assistant draft, a coach meal whose ingredient list changed, a
constraint recorded after the slot was filled), `AllergyGuard.assess()` returns `blocked` and
`PlanDraftRepository.save()` **refuses the write**, naming the allergen. There is no "log it anyway" on
a coach screen: the override in G5 §5.1 exists because *she is the authority on her own body* — a coach
is not, and prescribing around someone else's allergy is not hers to override.

Every quantity on W06 comes from `foods[].sizes[]` in G5's verified pack. W07's unverified path stores
no numbers at all (§1.6).

---

## 6. Security rules, as code

G8 authors the single composed `users/{uid}` block (spine §2). **`users/{uid}/splits/*` is inside it**,
so I supply the validator below as a requirement and do not author that match. My own collections are
outside `users/{uid}`, are matched at distinct paths, and are therefore safe to OR (G8's assembly note).

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ── shared helpers (G8's global block; repeated here for a reviewable fragment) ──
    function signedIn()   { return request.auth != null; }
    function me()         { return request.auth.uid; }
    function d()          { return request.resource.data; }
    function freshStamp() { return d().updatedAt == request.time; }                 // G8 K3
    function noStreak()   { return !d().keys().hasAny(['streak','dayStreak','consecutiveDays',
                                                       'currentStreak','daysInARow']); }  // C6
    function meta()       { return ['schemaV','updatedAt','clientWrittenAt','opId']; }

    // ── G14 helpers ──
    // Rule 1 / C8, at the storage layer: no document G14 writes may name an actual.
    function noActuals(m) {
      return !m.keys().hasAny(['actualWeight','actualReps','actualSeconds','actualHoldSec',
                               'done','completed','adherence','loggedAt']);
    }
    function isTag(t) {
      return t in ['high_impact','jumping','deep_knee_flexion','loaded_twisting','pelvic_floor_load',
                   'breath_hold_valsalva','prone_position','supine_load','overhead_load','wrist_load'];
    }
    // C7 / rule 11: a baseline can never hold a weight, so it can never be ranked by one.
    function baselineClean(b) {
      return !b.keys().hasAny(['weightKg','weight','bmi','bodyFat','weightLost']);
    }
    function isDay(s)  { return s.matches('^\\d{4}-\\d{2}-\\d{2}$'); }
    function isMonth(s){ return s.matches('^\\d{4}-\\d{2}$'); }

    // ═══════════════════ coaches/{coachUid} — G14's three subcollections ═══════════════════
    // The coaches/{coachUid} ROOT document and portfolio/offers/results/ads are G12's and G13's.
    // G14 matches only these three paths, so no OR hazard with their blocks exists.

    match /coaches/{coachUid}/splits/{splitId} {
      // Private to its author. A client never reads a template; she reads published assignments.
      allow get, list: if signedIn() && me() == coachUid && request.query.limit <= 50;

      allow create, update: if signedIn() && me() == coachUid
        && freshStamp() && noStreak() && noActuals(d())
        && d().keys().hasOnly(['splitId','name','cycleLength','daySlots','carryApproved',
                               'source','appliedCount','ownerKind'].concat(meta()))
        && d().ownerKind == 'coach'
        && d().name is string && d().name.size() > 0 && d().name.size() <= 60
        && d().cycleLength is int && d().cycleLength >= 3 && d().cycleLength <= 7
        && d().daySlots is list && d().daySlots.size() == d().cycleLength
        && d().carryApproved is bool
        && d().source in ['library','own']
        // A template is never about a person: no client can be named on it. (r12)
        && !d().keys().hasAny(['clientUid','assignedTo','clients'])
        // appliedCount is Function-only; a client-side write may not move it.
        && (!('appliedCount' in d())
            || (resource == null ? d().appliedCount == 0
                                 : d().appliedCount == resource.data.appliedCount));

      allow delete: if signedIn() && me() == coachUid;
    }

    match /coaches/{coachUid}/planDrafts/{draftId} {
      allow get: if signedIn() && me() == coachUid;
      allow list: if signedIn() && me() == coachUid && request.query.limit <= 30;

      allow create, update: if signedIn() && me() == coachUid
        && freshStamp() && noStreak() && noActuals(d())
        && d().keys().hasOnly(['clientUid','coachUid','month','status','days','basedOnVersion',
                               'lastPublished','templateRef','origin','effectiveFrom',
                               'lastEditedByDevice'].concat(meta()))
        && d().coachUid == coachUid
        && isMonth(d().month)
        && draftId == d().clientUid + '__' + d().month          // deterministic id (C1)
        && d().days is map && d().days.size() <= 31
        // A DRAFT can never claim to be published: only the callable writes that word.
        && d().status == 'draft'
        && d().origin in ['blank','split','assistant','copy']
        && (!('effectiveFrom' in d()) || isDay(d().effectiveFrom))
        // lastPublished is written by the Function only.
        && (!('lastPublished' in d())
            || (resource != null && d().lastPublished == resource.data.lastPublished));

      allow delete: if signedIn() && me() == coachUid;
    }

    match /coaches/{coachUid}/meals/{mealId} {
      allow get, list: if signedIn() && me() == coachUid && request.query.limit <= 50;
      allow create, update: if signedIn() && me() == coachUid
        && freshStamp() && noStreak()
        && d().keys().hasOnly(['name','ingredients','servings','prepMinutes','labels',
                               'note','nutrition'].concat(meta()))
        && d().ingredients is list && d().ingredients.size() <= 30
        && d().nutrition.resolved is bool
        // No invented numbers: totals may exist ONLY when every ingredient resolved. (§1.6)
        && (d().nutrition.resolved == true
            || !d().nutrition.keys().hasAny(['kcal','proteinG']));
      allow delete: if signedIn() && me() == coachUid;
    }

    // ═══════════════════ assessments — the source of constraints (r13) ═══════════════════
    // Party-checked on the document itself: no cross-document get(), so no extra billed read
    // and no dependence on G11's relId format.

    match /assessments/{assessmentId} {
      function isParty() {
        return signedIn()
            && (me() == resource.data.clientUid
                || (resource.data.coachUid != null && me() == resource.data.coachUid));
      }
      allow get: if isParty();

      // A list is allowed ONLY when the query names the caller, so rules are provably
      // satisfiable for every document returned. K22's history is the only caller.
      allow list: if signedIn() && request.query.limit <= 25;

      allow create: if signedIn()
        && freshStamp() && noStreak() && noActuals(d())
        && d().keys().hasOnly(['coachUid','clientUid','takenAt','lifeStage','birthType','clearance',
                               'avoid','painNotes','screening','baseline','parentAssessmentId',
                               'status'].concat(meta()))
        // The author is one of the two named parties, and cannot forge the other.
        && (me() == d().coachUid || (d().coachUid == null && me() == d().clientUid))
        && d().clientUid is string
        && d().status == 'recorded'
        && d().lifeStage in ['pregnant','p0_6w','p6w_1y','over_1y','none']
        && (!('birthType' in d()) || d().birthType in ['vaginal','caesarean','undisclosed'])
        && d().clearance.granted is bool
        && d().avoid is list && d().avoid.size() <= 12
        && d().screening is list && d().screening.size() <= 12
        && (!('painNotes' in d()) || d().painNotes.size() <= 500)
        && baselineClean(d().baseline)                                    // C7 / rule 11
        // Deterministic id (C1): the scope prefix must match the named parties.
        && assessmentId.split('__')[0] == (d().coachUid == null
                                           ? 'self_' + d().clientUid
                                           : d().coachUid + '_' + d().clientUid);

      // An assessment is a record. The ONLY permitted update is the supersede flip,
      // written by the child's transaction. Nothing else about a recorded answer may change.
      allow update: if isParty()
        && freshStamp()
        && request.resource.data.diff(resource.data).affectedKeys()
             .hasOnly(['status','updatedAt'])
        && resource.data.status == 'recorded'
        && d().status == 'superseded';

      // A constraint record is never deleted. Correcting it means recording a new one.
      allow delete: if false;
    }

    // ═══════════ requirement handed to G8 for the composed users/{uid} block (D7) ═══════════
    // G14 does NOT author this match. G4 owns the write; the validator shape is mine so the
    // two role copies of one model cannot drift.
    //
    //   match /users/{uid}/splits/{splitId} {
    //     allow get, list: if isSelf(uid) && request.query.limit <= 50;
    //     allow create, update: if isSelf(uid)
    //       && freshStamp() && noStreak() && noActuals(d())
    //       && d().keys().hasOnly(['splitId','name','cycleLength','daySlots','source','ownerKind']
    //                             .concat(meta()))
    //       && d().ownerKind == 'self'
    //       && d().cycleLength is int && d().cycleLength >= 3 && d().cycleLength <= 7
    //       && d().daySlots is list && d().daySlots.size() == d().cycleLength
    //       && d().source in ['library','own']
    //       // D7: only a coach may assign. A client split names nobody and counts nothing.
    //       && !d().keys().hasAny(['clientUid','assignedTo','appliedCount','approvedAlternatives']);
    //     allow delete: if isSelf(uid);
    //   }

    // plans/** stays server-authored: no client or coach may WRITE it, ever.
    // The spine's amended §2 grants a coach READ under an active relationship. That match is
    // G2's and G8's to widen, not G14's. G14 reads plans/** on no hot path — W03/W08 render
    // from planDrafts.lastPublished — so this fragment neither needs nor asserts the grant.
  }
}
```

**Negative tests shipped with these rules:** a coach reading another coach's `splits`; a coach writing
`planDrafts` with `status:'published'`; a coach writing `lastPublished` directly; a client writing
`users/{self}/splits` with `ownerKind:'coach'` or with `appliedCount`; a client writing
`users/{other}/splits/*`; an assessment created with a `coachUid` the caller does not own; an
assessment id whose prefix does not match its parties; an assessment `update` touching `avoid` or
`screening`; an assessment `delete`; a `baseline` carrying `weightKg`; any document of mine carrying
`actualReps` or `streak`; a coach reading `plans/{clientUid}/versions/v1`; an unbounded `list` on
`assessments`.

---

## 7. Interface to the other groups

### 7.1 G2 — publishing. **I produce content; G2 writes every plan document.**

I call **one** thing, and it is the only way a plan changes:

```dart
// Callable, server-side. G2 owns the implementation and every write it performs.
publishCoachPlan({
  clientUid:      String,
  draftId:        String,        // coaches/{me}/planDrafts/{clientUid}__{yyyy-MM}
  effectiveFrom:  String,        // yyyy-MM-dd; G2 clamps to max(requested, today)
  source:         'coach' | 'split',
  templateRef:    String?,       // coaches/{me}/splits/{id} — PROVENANCE ONLY, never dereferenced
  idempotencyKey: String,        // 'publishCoachPlan:{clientUid}:{month}:{draftHash}'
}) → { version: String, assignmentsWritten: int, mealSlotsWritten: int, supersededVersion: String? }
```

G2's guarantees I rely on, all already in its plan: authorisation widened from "self" to "self or the
assigned coach"; `source` already distinguishes `self_serve | coach | split`; `authorUid` and
`templateRef` already exist; `effectiveFrom`/`supersedes` already express a revision; **a past-dated or
`frozen` assignment is never rewritten** (r2); the callable is idempotent on its key. G2 states that
"applying a split runs the same `PlanPublisher.publish()`… while editing `splits/*` touches no version"
— that is exactly this interface, and I conform to it rather than extend it.

**I conform to G2's `assignments/{yyyy-MM-dd}` contract (its §1.3) verbatim**, including `prescribedLoad.kind`
of `kg | bodyweight | seconds`, the `moves[]` ordering, and *absence means rest*.

**On the spine's amended read grant.** `SCHEMA-SPINE.md` §2 now lists *"a coach under an active
relationship (G11, G12, G14)"* among the readers of `plans/**`. G14 accepts the grant and **uses it on
no hot path**: every screen of mine renders from `planDrafts`, which is a document the coach owns, so
W03 stays at 1 read and works with no signal. The grant's value to me is a reconciliation fallback — if
`lastPublished` is ever stale, W08 can re-read the authoritative version before publishing. Widening
the `plans/**` match is G2's and G8's to do; §6 neither asserts nor depends on it. **This does not
relieve OQ-2**, which is about `users/{clientUid}/**` — a different path, still correctly closed.

**One request, and it blocks W06/W08 (OQ-3).** G2's assignment carries `"meal": null` and its plan says
"coach-planned meals only; null through the MVP". D1 withdrew that cut, so the field now needs a shape.
Proposed, matching the draft's (§1.2):

```jsonc
"meal": { "slots": { "breakfast": { "source":"library", "foodIds":["ful_medames"], "servings":1, "note":null },
                     "lunch":     { "source":"coach", "name":"…", "ingredients":[…], "servings":1,
                                    "nutrition": {"resolved":false} },
                     "dinner":    { "freeChoice": true },
                     "snack":     null } }
```

**A coach meal must be EMBEDDED by value, not referenced.** A reference to
`coaches/{coachUid}/meals/{id}` would force the client to read another user's document, which the
ruleset denies and should keep denying. Embedding also means a later edit to the coach's meal does not
silently change a published day — the same property as r12.

### 7.2 G4 — the move library, and the client-authored split (D7)

**Consumed:** the bundled 124-move pack (G4's D3 — zero Firestore reads on W04/K20), filtered on
`{primaryMuscle, equipment, quiet, floorOnly}`, and `libraryVersion` for cache invalidation.

**Published to G4:** the shared split model. `Split`, `SplitDraft`, `SplitValidator`,
`SplitDaySlotEditor` and `SplitApplicator` live in `features/coachplan/domain/split/` and are consumed
by G4 unchanged. **G4 owns `ClientSplitRepository` (the `users/{uid}/splits/*` write) and the client's
entry point; G14 owns the model, the builder controller and the validator.** One model, two
repositories, selected by `ownerKind`. `SplitAssignmentGuard` is the only asymmetry (§3.3).

**Two requests:**
- **`exercises[].contraindicationTags[]`**, drawn from §1.5's vocabulary. **Blocking — OQ-1.** Without
  it, K21's avoid chips are decorative: the coach records "no deep knee bends" and nothing in the
  system can act on it. This is the same defect class as G5's missing `foods.allergens[]`.
- **I second G4's OQ-1** — a read-only `workouts/{workoutId}` session-template library. K20's day slots
  and W04's "Session name" are session-level entities; `exercises` cannot hold a title or a duration.
  Two groups now need it.

### 7.3 G5 — foods, and the guard I reuse rather than rebuild

**Consumed:** the signed food pack (zero Firestore reads), `foods[].sizes[]` for every quantity, and
**`AllergyGuard.screen()` / `.assess()` unchanged** — called with the *client's* `DietaryConstraints`
(§5.2). I write no second allergy implementation; a safety rule with two implementations has one that
is weaker.

**I second G5's blocking Q10:** `foods.allergens[]` and `foods.dietTags[]`. Without them W06's
"allergies on screen while editing" cannot filter, only display. **OQ-4.**

**Published to G5:** nothing. Coach meals never enter `foods` (§1.6), and G5's E01 renders a planned
coach meal from G2's assignment, not from my collection.

### 7.4 G11 — the coaching relationship. **The largest interface, and it is blocking.**

**The finding.** Under the deployed ruleset a coach can read **nothing** under `users/{clientUid}` —
`profile`, `sessions/*`, `meals/*`, `weeks/*` are all `isSelf(uid)`. That is correct and must stay.
But W02's constraint card, W02's adherence ring, W09's week summary and W06's allergy strip all read
client data today. **OQ-2, blocking.** The scalable resolution is a Function-maintained projection, not
a rules relaxation (a `get()` in rules costs a billed read on every access and leaks the whole document):

| Path (G11 writes, Function-only) | Contents | My screens |
|---|---|---|
| `relationships/{relId}/shared/constraints` | `{ allergies[], dietary[], goal, days, sessionLength, place, equipment[], lifeStage, updatedAt }` — **only fields the client's sharing switches permit** (r6, C12); **never cycle data** | W02, W06, W04 |
| `relationships/{relId}/rollups/{isoWeek}` | `{ sessionsPlanned, sessionsLogged, mealDaysLogged, swapsUsed, bests[] }` | W02 ring, W09 |
| `relationships/{relId}.queue` | `{ oldestUnansweredAt, unreadForCoach, reviewDueAt, planNeededAt, assessmentDueAt, latestAssessmentId }` | **W01's four chips, W10's ordering, W02's pointer — one indexed query serves all three** |

Plus the composite index `(coachUid, status, queue.oldestUnansweredAt)` (§1.7).

**Why `queue` as a map rather than four queries.** W01's chips are *Needs reply · Reviews due · Plan
needed · Assessment due*. Four queries means four composite indexes and four times the reads; one
document map filtered client-side over ≤20 documents means one index and one listener that W10 and W11
reuse for free. It also makes the re-assessment reminder **lazy** — `assessmentDueAt` is a field the
chip reads, not a cron job (consistent with G6/G8's agreement that week closing is lazy with no
scheduler).

**I never write `relationships/**`.** W09's feedback and W10's threads go through G11's API;
`ReviewFeedbackService.save()` delegates and returns `DRAFT` (§3.4), never publishing.

**I read from G11:** `relationships/{relId}.status` (an `active` relationship is the authorisation for
every coach action of mine), `reviews/{reviewId}` (W09), `messages` metadata (W10 ordering only —
message bodies are K16's, which is G11's screen).

**Request:** a deterministic `relId`. `{coachUid}__{clientUid}` removes a lookup from every screen of
mine and makes the projection paths derivable client-side.

### 7.5 G12 — the coach app shell

**Consumed:** `coaches/{coachUid}` root (`displayName`, `acceptingClients`, `serviceHours` — W01's
"12 of 20" and its reply-time promise), the coach navigation shell, and the coach verification state.

**Proposed rule, for G12 to confirm (OQ-12):** a coach whose certificates are still under review (K24's
amber card) **may author everything and may publish nothing.** Authoring is how she fills the wait —
K24 explicitly tells her to. Publishing puts a prescription in front of a woman on the strength of
credentials nobody has checked yet. `CoachPlanPublisher.publish()` checks `coachVerification.status ==
'verified'` and W08's button carries the reason when it does not.

**Published to G12:** W11's empty state is a branch of W01's route (r16), so G12's route table gains no
destination for it. K24's three todo rows link to K19, W07 and B14 — I own the first two targets.

### 7.6 G13 — the portfolio

Almost none. `coaches/**/results/*` and `ads/*` are G13's; my screens neither read nor write them. The
one touch: K19 and W07 are linked from K24/B14 as "worth doing before a first client", which is
navigation, not data.

### 7.7 G15 — the assistant (K26, K27)

**The boundary is mine, the assistant is G15's.** K26 ("Draft it for me", from W03) and K27 ("Draft a
week", from W06) hand back a draft. `AssistantDraftIntake.accept(draft)`:

1. Rejects anything whose `status` is not `draft` — **there is no publish tool and I expose none** (r10).
2. Re-validates **every** `exerciseId` against G4's pack and **every** `foodId` against G5's pack. An id
   outside the packs is dropped, never rendered.
3. Re-runs `ExerciseCandidateFilter.screen()` and `AllergyGuard.screen()` against
   `ClientConstraints` — **server-side filtering is not trusted as the last word**, because the draft
   may have been produced before the latest assessment was recorded.
4. Writes `planDrafts.origin = 'assistant'` and sets `status: 'draft'`. The coach opens W03/W06 and
   publishes herself, or does not.

**What I give G15:** `get_client_context` is `ClientConstraintResolver.resolve(clientUid)` (§5), which
is the single source r13 requires — so the assistant and the coach screens cannot disagree about an
allergy. Data minimisation per HANDOFF: the question, equipment and the avoid list. **Never** the name,
photos, weight, ID result or cycle data.

### 7.8 G8 — platform

**Consumed:** offline persistence (unbounded cache), `SyncStatusScope` / `SyncBadge`, the connectivity
stream, `deviceId`, the composed `users/{uid}` ruleset (into which my §6 comment block is pasted),
`firestore.indexes.json` + `index_allowlist_test.dart`, the ARB/RTL layer, the Amplitude wrapper.

**Published:** my §6 rule fragments for three non-`users` paths (safe to OR — distinct match paths), my
two composite index declarations, and the `users/{uid}/splits` validator requirement.

**Analytics (spine §6, PDPL).** Coach-side events carry screen id and coarse outcome only:
`coach_plan_published{screen, dayCount, source}`, `coach_split_applied{screen, cycleLength, clientCount}`,
`coach_assessment_saved{screen, hasReferral:bool}`. **Never** a client uid, a client name, an allergen,
an avoid tag, a `painNotes` string, a baseline value, or any measurement. An assessment is health data
about a named woman; none of it leaves the device.

### 7.9 Platform table (§4 policy)

| Capability | Android | iOS | Fallback |
|---|---|---|---|
| Re-assessment reminder | local notification from `assessmentDueAt` | local notification, same source | **Lazy by design** — W01's "Assessment due" chip is computed from the field on every open, so the reminder is a convenience, never the mechanism. Nothing is missed if notifications are denied on either platform |
| Voice reply on W09 | record + upload (G11's path) | record + upload | Text reply always present; the mic is never the only way to answer |

No G14 screen needs a platform channel. Health Connect / HealthKit, SMS, face blur and the meal nudge
are all client-side surfaces owned by G4/G1/G7/G8.

---

## 8. Test cases my screens need

**Status at the time of writing: these 81 rows have been merged into `tests/TEST-CASES.csv` by a
reconciliation pass, which grew the suite from 206 to 593 rows.** 77 arrived byte-identical. **The four
P1 rows were renumbered on merge** — `P1-RULE-12/13/14/15` were taken by other groups (G13 consent,
G12 first-run routes, G12 blur, G11 sharing), and mine became **`P1-RULE-18` (r12), `P1-RULE-19` (r13),
`P1-RULE-20` (r14), `P1-RULE-21` (r15)**. The IDs below and in §5 use the merged numbering, so this
plan and the suite agree. Rows are in that file's exact format and column order:

`id,priority,journey,screens,precondition,steps,expected,rule_protected,platform,scope`

**One note on the `scope` column.** Every row is `MVP` because D1 withdrew the cut and all 161 screens
ship. The five `Post-MVP` rows I originally flagged **have since been re-tagged** — the suite is now
592 `MVP` and zero `Post-MVP`. The stale description of that column has moved to `tests/README.md`,
which still defines `Post-MVP` against the withdrawn `BUILD-BRIEF.md` §0 cut (OQ-13).

**Existing rows I am also accountable for on my screens:** `P1-RULE-01` (W03, W04, K20 — no `actual*`
in anything I write), `P1-RULE-02` (W08, W09 — already lists them), `P1-RULE-09` (W05's confirmation is
a permitted destructive-bulk exception, not a violation), **`P1-RULE-10A` and `P1-RULE-10B`** (the
K26/K27 handover boundary — the single rule-10 guard was split in two on merge, 10A for the invented
quantity and 10B for the absent publish tool; both name K26/K27 and both are mine at that boundary),
`P1-RULE-11` (K19's `appliedCount` is displayed, never sorted).

```csv
P1-RULE-18,P1,Product rule guard,"K19,K20,W03,W08",A split has been applied to a client and her plan published,"Edit the split on K20 — rename it, change a day slot, toggle carry-approved; save; inspect the client's published version and every assignment",The published version and every assignment are byte-identical afterwards. Zero documents were written outside coaches/{me}/splits. templateRef is unchanged and is never dereferenced at read time.,"HANDOFF 12: a split is a template, not a plan",both,MVP
P1-RULE-19,P1,Product rule guard,"W02,W04,W06,K21",A client has a recorded assessment with avoid=[deep_knee_flexion] and allergies=[nuts],"Search every coach screen for an input that writes avoid, allergies or dietary; then change the assessment and reopen W02 and W06",No coach screen has an editable control for any of the three. Both screens re-render from the assessment and the client's intake within one read. ClientConstraints has no public setter. The two sources never disagree because there is only one.,HANDOFF 13: the assessment is the only source of a client's constraints,both,MVP
P1-RULE-20,P1,Product rule guard,"K23,K22,W04,W08",Pelvic floor screening answered 'refer',"Open W04's move picker; then open K22; then attempt to publish on W08","Exercises tagged pelvic_floor_load/jumping/high_impact are absent from the picker — filtered before the list is built, not greyed out afterwards. K22 shows the referral prominently. Publishing is NOT blocked and no screen renders refer as an error or failure state.",HANDOFF 14: a screening outcome of refer is not a failure state,both,MVP
P1-RULE-21,P1,Product rule guard,"K22,W03,W08",A published plan exists and a re-assessment is due,"Save a re-assessment on K22 with changed baselines and a cleared referral; do not publish",The published version and all assignments are unchanged. The draft's status is 'draft'. No callable was invoked. 'Save and adjust her plan' navigates to W03 and publishes nothing.,HANDOFF 15: saving a re-assessment never edits a published plan,both,MVP
P0-SPLIT-01,P0,Coach builds a split,"K19,K20",Coach signed in with zero splits,"Open K19 > Build a split > name it > choose 4 days > fill 3 session slots and 1 rest > save",One document at coaches/{me}/splits/{id} with daySlots.size()==cycleLength==4 and ownerKind 'coach'. K19 lists it. No clientUid field exists on it. appliedCount is 0.,"A split is a template, not a plan",both,MVP
P0-SPLIT-02,P0,Trainee builds her own split (D7),"K20",Client signed in with no coach; 124-move library available,"Open the split builder from the client entry point > design a 5-day split from the library > save",One document at users/{uid}/splits/{id} with ownerKind 'self' and source 'own'. The identical builder and validator ran. No appliedCount and no approvedAlternatives field exists. She can apply it to her own plan.,D7: the trainee builds splits too — one model two entry points,both,MVP
P0-SPLIT-03,P0,Only a coach may assign,"K20",Client has authored her own split,"Attempt via the app and via a direct Firestore write to apply the client's split to another uid",No UI path exists. The direct write is denied by rules. SplitAssignmentGuard throws NotYourClient. A client split can only ever reach her own plan.,D7: only the coach can assign a split to a client,both,MVP
P0-SPLIT-04,P0,Apply a split to a month,"K20,W03,W08",Coach has a 4-day split and an active client with an empty September,"Tap 'Save and apply to Nour' > review W03 > publish on W08",The draft's days map is filled by value from the template. Existing days would have been named before replacement. The published version carries source 'split' and templateRef. Assignments exist only for dates >= today.,"HANDOFF 12; rule 2: publishing is the act that changes a plan",both,MVP
P0-SPLIT-05,P0,Split applied at scale,"K20,W08",Coach with 60 active clients (see OQ-9) and one saved split,"Apply the split to all 60 and publish each","Server writes ~31 docs per client in chunked batched commits of <=500 ops; ~1,860 writes total, idempotent on {clientUid,month,draftHash}. Replaying all 60 creates zero extra versions. No client-side loop issues the writes. Editing the split afterwards writes 0 documents.",Scalability gate: the fan-out is bounded and one-time,both,MVP
P0-PLAN-01,P0,Plan a month with no signal,"W03,W04,W06,W08",Airplane mode from before the client is opened,"Open W03 > fill 20 training days and 30 meal days across W04/W06 > press Publish on W08 > restore signal","Every edit saves to the local cache at full opacity with a queued badge; no spinner and no failure message appears. Publish shows 'We'll publish the moment you're back online'. On reconnect exactly ONE version is created after three retries.",Offline-first authoring; spine C1 idempotency,both,MVP
P0-PLAN-02,P0,Copy a week names its overwrites,"W03,W05",Week 2 is planned; weeks 3 and 4 contain 2 existing assignments,"Tap 'Copy this week' > select weeks 3 and 4 > read the summary before confirming","The sheet states '10 days written' and names the 2 assignments that would be replaced, by date, BEFORE the action. Cancelling writes nothing. Confirming replaces exactly those 2.",Destructive bulk actions are named before they happen (P1-RULE-09 exception),both,MVP
P0-PLAN-03,P0,Publishing with gaps,"W06,W08",4 meal slots of 120 are unassigned,"Open W08 > read the warning > publish anyway",W08 counts the 4 empty slots before publishing. Publishing marks them explicitly as free choice rather than leaving them undefined. The client's Eat screen renders free choice — never an empty planned row and never an error.,Nothing publishes half-planned by accident,both,MVP
P0-PLAN-04,P0,A revision never rewrites finished work,"W03,W08",A plan is published; the client has logged Monday and has a session running now,"Revise the plan on W03 and publish on W08 mid-session",effectiveFrom is clamped to today. Monday's assignment and the running session's planVersion are untouched. Only future dates change. The running session finishes on the version it started on.,"HANDOFF 2: a plan revision applies to future dates",both,MVP
P0-PLAN-05,P0,Two devices plan the same month,"W03",Coach signed in on two devices; both offline,"Edit Tuesday on device A and Thursday on device B; reconnect both",Both edits survive: days is a map so distinct dates merge at field level. Editing the SAME day is last-write-wins on that day alone and W03 names the other device. No other day is lost.,"Spine C3 as generalised: an array would lose a day",both,MVP
P0-ASMT-01,P0,The two-step assessment is one document,"K21,K23",Coach opens an assessment for a client with none,"Fill step 1 > Continue > fill step 2 > Save assessment; then kill the app mid-step-2 on a second attempt","One document is written, at the end. Killing the app during step 2 writes nothing — no partial assessment exists. The id is deterministic, so a replayed save overwrites itself rather than creating a second.",HANDOFF 13: a partial source of constraints is worse than none,both,MVP
P0-ASMT-02,P0,The avoid list suppresses moves before selection,"K21,W04","Assessment records avoid=[high_impact,deep_knee_flexion]","Open W04 and browse the full move picker; search explicitly for a jumping move",Matching exercises are ABSENT from the candidate list — removed before it was built. They are not shown greyed out and not shown with a warning. Nothing the coach can tap prescribes one.,"HANDOFF 13; filter before selection, never validate after",both,MVP
P0-ASMT-03,P0,Constraints cannot be resolved,"W02,W04,W06",Cold start with no cache and the constraints projection unavailable,Open W02 then W04,"The picker returns only the quiet, low-impact, floor-based subset and one line says her constraints haven't loaded. No unrestricted list is ever shown. An unknown constraint is treated as present, not absent.",Fail closed — mirrors G5 AllergyGuard 5.1,both,MVP
P0-ASMT-04,P0,A referral survives re-assessment,"K23,K22",A refer outcome was recorded four weeks ago and is unresolved,"Open K22 > review > save without clearing it",The referral is rendered prominently and its suppression is still active afterwards. It cannot expire or be cleared by silence. Clearing requires an explicit action with a reason and writes a new document.,HANDOFF 14,both,MVP
P0-ASMT-05,P0,An assessment is a record,"K21,K22",An assessment is recorded,"Attempt to edit avoid or screening on the existing document, via the app and directly",No UI path edits a recorded assessment. A direct write is denied by rules; the only permitted update is the status flip to superseded. Deletion is denied outright. Correcting means recording a new one.,HANDOFF 13: the source of constraints is append-only,both,MVP
P0-MEAL-01,P0,Allergies filter before selection,"W06",Client's constraints record a nut allergy and weekday vegetarian,Open W06 and browse every meal picker and alternative list,"No nut-containing food appears anywhere in the candidate lists — filtered at the source. Non-vegetarian items are excluded from suggestions with no warning and no override. No coach screen offers 'assign it anyway' for an allergen.","Allergies respected BEFORE selection, not validated afterwards",both,MVP
P0-MEAL-02,P0,A conflicting item arriving by another route,"W06,K27",A slot was filled before the allergy was recorded,"Record the allergy on K21, reopen W06, then attempt to save the draft",The domain layer refuses the write and names the allergen. The slot is shown blocked with the reason and alternatives. It is never auto-logged and never silently dropped.,G5 AllergyGuard.assess blocks at the domain layer,both,MVP
P0-MEAL-03,P0,No invented nutrition,"W07",Coach creates a meal with an ingredient absent from the verified food library,"Enter 'grandmother's mix 200 g' among resolvable ingredients > save",nutrition.resolved is false and NO kcal or protein figure is stored or displayed — not a partial total and not an estimate. The screen states nutrition is unavailable. The meal stays in the coach's own collection and never enters foods.,"§2.10: the product never invents a quantity",both,MVP
P0-MEAL-04,P0,Every quantity comes from the library,"W06",Client's plan is being written,Inspect every gram and serving figure rendered on W06 and in the published assignment,Each traces to a foods[].sizes[] entry in the verified pack. No free-text quantity can be assigned. A coach meal is embedded by value in the assignment so the client needs no cross-user read.,G5 owns foods; quantities are never authored,both,MVP
P0-QUEUE-01,P0,The queue is ordered by waiting time,"W01,W10",Three clients waiting 19 h/6 h/1 h; one review due; one assessment due,"Open W01 > apply each of the four chips > open W10","One query with one listener serves W01, W10 and W11; the chips filter the same <=20 documents client-side with no additional reads. Order is longest-waiting first on both screens. Opening W10 after W01 costs 0 reads.",Scalability: four chips are not four indexed queries,both,MVP
P0-QUEUE-02,P0,A coach with no clients,"W11,W01",New coach; zero relationships,Open the Clients tab,"W11 renders as a BRANCH of W01's route — no route exists for it and nothing navigates to it. It names what will appear, why it is empty, and offers three real actions. No tour and no overlay appears.","HANDOFF 16 and 17",both,MVP
P0-PUB-01,P0,Only publishing changes a plan,"W03,W08,W09,K22,K26",A plan is published and a draft has unpublished edits,"Save feedback on W09; save a re-assessment on K22; accept an assistant draft from K26 — publish none of them",The published version is byte-identical after all three. Each leaves status 'draft'. No callable was invoked. No screen exposes a publish action other than W08's explicit button.,"Rule 2 and HANDOFF 15: publishing is the only act that changes a plan",both,MVP
P0-PUB-02,P0,The assistant cannot publish,"K26,K27,W03,W06",Assistant drafting is available,"Ask for a 30-day plan and a meal week; inspect every tool definition and the accepted draft","No publish tool exists in any tool schema. The draft lands as status 'draft'. Every exerciseId and foodId is re-validated against the packs on acceptance and ids outside them are dropped. Constraints are re-applied on acceptance, not trusted from the draft.","§2.10 and HANDOFF: there is deliberately no publish tool",both,MVP
P2-RTL-W01,P2,Arabic RTL rendering,W01,Language set to Arabic,Open W01 (Clients and queue) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,MVP
P2-TXT-W01,P2,Large text / accessibility,W01,OS font size set to largest,Open W01 (Clients and queue) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,MVP
P2-RTL-W02,P2,Arabic RTL rendering,W02,Language set to Arabic,Open W02 (Client overview) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,MVP
P2-TXT-W02,P2,Large text / accessibility,W02,OS font size set to largest,Open W02 (Client overview) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,MVP
P2-RTL-W03,P2,Arabic RTL rendering,W03,Language set to Arabic,Open W03 (30-day workout planner) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,MVP
P2-TXT-W03,P2,Large text / accessibility,W03,OS font size set to largest,Open W03 (30-day workout planner) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,MVP
P2-OFF-W03,P2,Offline behaviour,W03,Airplane mode,Edit several days on W03 while offline,"Values render at full opacity with a queued badge on the month header, not on every row. No spinner, no failure message, no disabled editor.",,both,MVP
P2-ERR-W03,P2,Error state,W03,Draft document fails to load,Open W03 for a client,"A stated error with a retry, not an empty planner. Nothing is silently presented as an empty month, which would invite the coach to plan over existing work.",,both,MVP
P2-RTL-W04,P2,Arabic RTL rendering,W04,Language set to Arabic,Open W04 (Edit a session) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,MVP
P2-TXT-W04,P2,Large text / accessibility,W04,OS font size set to largest,Open W04 (Edit a session) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,MVP
P2-OFF-W04,P2,Offline behaviour,W04,Airplane mode,Add moves and save the session to a day,"Saves to the local draft at full opacity with a queued badge. The move library is bundled, so the picker is fully functional offline.",,both,MVP
P2-ERR-W04,P2,Error state,W04,Exercise pack missing or its version stamp is stale,Open the move picker,"A stated error with a retry. The picker never falls back to an unfiltered or partial list, because an unscreened move list is a safety failure.",,both,MVP
P2-RTL-W05,P2,Arabic RTL rendering,W05,Language set to Arabic,Open W05 (Copy a week) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,MVP
P2-TXT-W05,P2,Large text / accessibility,W05,OS font size set to largest,Open W05 (Copy a week) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,MVP
P2-OFF-W05,P2,Offline behaviour,W05,Airplane mode,Copy a week onto two other weeks,The overwrite summary is computed in memory and is exact offline. The copy applies to the local draft and syncs later.,,both,MVP
P2-ERR-W05,P2,Error state,W05,Target weeks extend beyond the loaded month,Copy week 4 onto the following month,"The second month's draft is created or loaded first; the summary covers both. The copy never partially applies, leaving half a week written.",,both,MVP
P2-RTL-W06,P2,Arabic RTL rendering,W06,Language set to Arabic,Open W06 (30-day meal planner) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,MVP
P2-TXT-W06,P2,Large text / accessibility,W06,OS font size set to largest,Open W06 (30-day meal planner) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt. The allergy strip stays visible while editing.",,both,MVP
P2-OFF-W06,P2,Offline behaviour,W06,Airplane mode,Fill meal slots offline,"The food pack is bundled so every picker works. Slots save to the local draft with a queued badge. The allergy filter is fully functional offline, because constraints are cached.",,both,MVP
P2-ERR-W06,P2,Error state,W06,Client constraints cannot be resolved,Open W06,"The allergy strip states that constraints have not loaded and the pickers fail closed to items with no allergens at all. It never shows an unrestricted list.",,both,MVP
P2-RTL-W07,P2,Arabic RTL rendering,W07,Language set to Arabic,Open W07 (Create a meal) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,MVP
P2-TXT-W07,P2,Large text / accessibility,W07,OS font size set to largest,Open W07 (Create a meal) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,MVP
P2-OFF-W07,P2,Offline behaviour,W07,Airplane mode,Create and save a meal,Saves to the coach's own collection with a queued badge. Ingredient resolution against the bundled pack works offline.,,both,MVP
P2-ERR-W07,P2,Error state,W07,Save rejected by rules,Save a meal carrying nutrition figures while an ingredient is unresolved,The write is refused and the screen states nutrition is unavailable rather than storing a partial total. No estimate is ever written.,,both,MVP
P2-RTL-W08,P2,Arabic RTL rendering,W08,Language set to Arabic,Open W08 (Publish the plan) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,MVP
P2-TXT-W08,P2,Large text / accessibility,W08,OS font size set to largest,Open W08 (Publish the plan) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,MVP
P2-OFF-W08,P2,Offline behaviour,W08,Airplane mode,Press Publish plan,"The button stays ENABLED and its label becomes 'We'll publish the moment you're back online'. No spinner, no failure. The intent is queued idempotently and publishes exactly once on reconnect.",,both,MVP
P2-ERR-W08,P2,Error state,W08,The publish callable returns an error,Press Publish plan,"The draft returns to 'draft' with its content intact and a stated reason with a retry. No partial version exists: the version and its assignments are written in one transaction or not at all.",,both,MVP
P2-RTL-W09,P2,Arabic RTL rendering,W09,Language set to Arabic,Open W09 (Review and adjust) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,MVP
P2-TXT-W09,P2,Large text / accessibility,W09,OS font size set to largest,Open W09 (Review and adjust) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,MVP
P2-OFF-W09,P2,Offline behaviour,W09,Airplane mode,Save feedback on a review,Feedback queues through G11 with a badge. Saving it publishes nothing either online or offline.,,both,MVP
P2-ERR-W09,P2,Error state,W09,The weekly rollup is unavailable,Open W09,"Days without a food log are labelled 'not logged', never counted as meals skipped. A missing rollup is stated, not rendered as zeroes, which would read as failure.",,both,MVP
P2-RTL-W10,P2,Arabic RTL rendering,W10,Language set to Arabic,Open W10 (Coach inbox) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,MVP
P2-TXT-W10,P2,Large text / accessibility,W10,OS font size set to largest,Open W10 (Coach inbox) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,MVP
P2-RTL-W11,P2,Arabic RTL rendering,W11,Language set to Arabic; coach has no clients,Open the Clients tab in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved. It renders as a branch of W01's route.",,both,MVP
P2-TXT-W11,P2,Large text / accessibility,W11,OS font size set to largest; coach has no clients,Open the Clients tab at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,MVP
P2-RTL-K19,P2,Arabic RTL rendering,K19,Language set to Arabic,Open K19 (My splits) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,MVP
P2-TXT-K19,P2,Large text / accessibility,K19,OS font size set to largest,Open K19 (My splits) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,MVP
P2-RTL-K20,P2,Arabic RTL rendering,K20,Language set to Arabic,Open K20 (Build a split) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,MVP
P2-TXT-K20,P2,Large text / accessibility,K20,OS font size set to largest,Open K20 (Build a split) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,MVP
P2-OFF-K20,P2,Offline behaviour,K20,Airplane mode,Build and save a split,Saves with a queued badge. 'Save and apply to Nour' materialises into the local draft offline; only the publish step waits for signal.,,both,MVP
P2-ERR-K20,P2,Error state,K20,Save rejected because daySlots does not match cycleLength,Change the cycle length and save without filling the new slot,The write is refused with a stated reason naming the unfilled slot. A split with a missing day is never saved.,,both,MVP
P2-RTL-K21,P2,Arabic RTL rendering,K21,Language set to Arabic,Open K21 (Assessment) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,MVP
P2-TXT-K21,P2,Large text / accessibility,K21,OS font size set to largest,Open K21 (Assessment) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,MVP
P2-OFF-K21,P2,Offline behaviour,K21,Airplane mode,Fill step 1 and continue,Nothing is written yet; the form is held locally and survives a background/foreground cycle. No network is required to take an assessment.,,both,MVP
P2-ERR-K21,P2,Error state,K21,The previous assessment cannot be loaded for pre-fill,Open K21 for a client with a prior assessment,"A stated error with a retry. The form never opens blank in a way that implies no prior constraints existed, which would invite the coach to re-enter them from memory.",,both,MVP
P2-RTL-K22,P2,Arabic RTL rendering,K22,Language set to Arabic,Open K22 (Re-assessment) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved. The intake/now comparison columns mirror correctly.",,both,MVP
P2-TXT-K22,P2,Large text / accessibility,K22,OS font size set to largest,Open K22 (Re-assessment) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt. The before/after pair stays readable.",,both,MVP
P2-OFF-K22,P2,Offline behaviour,K22,Airplane mode,Save a re-assessment,"Writes the new document with a queued badge and flips the parent to superseded in the same transaction. Publishing nothing, online or offline.",,both,MVP
P2-ERR-K22,P2,Error state,K22,The parent assessment cannot be loaded,Open K22,"A stated error with a retry. The re-assessment never opens without its parent, because 'filled in from her intake' is the screen's whole premise.",,both,MVP
P2-RTL-K23,P2,Arabic RTL rendering,K23,Language set to Arabic,Open K23 (Movement screening) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved. The pass/modify/refer control mirrors.",,both,MVP
P2-TXT-K23,P2,Large text / accessibility,K23,OS font size set to largest,Open K23 (Movement screening) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. The three outcome options stay at least 44pt and none is truncated.",,both,MVP
P2-OFF-K23,P2,Offline behaviour,K23,Airplane mode,Complete screening and save the assessment,"One document is written with a queued badge and the screen returns to W02 immediately. The assessment is hers the moment she saves it.",,both,MVP
P2-ERR-K23,P2,Error state,K23,Save rejected because a screening item is unanswered,Leave one item unset and save,The write is refused and the unanswered item is named. A partial assessment is never recorded because it is the only source of constraints.,,both,MVP
```

**Totals: 4 P1, 23 P0, 54 P2 — 81 rows across 16 screens.** Every screen has RTL and large-text
coverage; all 11 writing screens (W03–W09, K20–K23) additionally have an offline and an error case, per
the gap G7/G8 found and closed on the client side.

---

## 9. Scalability gate — self-check, with the fan-out costed

| Gate | Verdict | Evidence |
|---|---|---|
| **Unbounded collection scan** | **PASS** | Every read is a document `get`, a `__name__` lookup, or a `limit`-bounded query (20 relationships, 50 splits, 50 meals, 5 assessments). Rules cap every `list`, so a compromised client cannot scan. The 124-move and food libraries are bundled and issue **zero** queries |
| **Fan-out write that grows with followers** | **PASS** | See below |
| **Unindexed hot-path query** | **PASS** | The one hot query (W01/W10/W11) has its composite index declared (§1.7) and is requested of G11 explicitly. Every other hot read is a direct `get`. The only other composite serves K22's history — off the hot path, `limit 5` |
| **Migration needed to reach 100k MAU** | **PASS** | G2 already ships the coach-shaped model (`status:'draft'`, `source:'coach'|'split'`, `authorUid`, `templateRef`), so no plan-side migration exists. My own collections are new. `planDrafts` is sharded by month from day one, so no document grows without bound |

### 9.1 Applying a split to 60 clients — costed, as required

| Quantity | Value |
|---|---|
| Assignments per client per month | ~30 (a meal-bearing day exists even on a rest day; workout days ~20) |
| Documents per client | 30 assignments + 1 version = **31** |
| 60 clients | **1,860 writes**, in 4 chunked batched commits (Firestore's 500-op limit) |
| Cost | 1,860 × $0.09/100k = **$0.0017** |
| Wall time | ~4 s server-side; the coach sees a per-client progress list, not a modal |
| Replay of all 60 | **0 extra documents** — idempotent on `{clientUid, month, draftHash}` |
| **Editing the split afterwards** | **0 writes. To anyone. Ever.** (r12, §3.3) |

**Why this is not the fan-out the gate rejects.** The rejected pattern is a write whose size grows with
an audience the author does not control and which recurs on every subsequent edit — a post copied into
followers' feeds (C9). This fails every clause:

1. **Bounded by a hard cap,** not by followers. W01 reads "12 of 20": a coach has at most 20 active
   clients, so 60 is already three coaches' full books (**OQ-9** — the gate asked for 60, the product
   caps at 20; both are costed and both pass).
2. **One-time, not on edit.** The fan-out happens once, at publish. Editing the template afterwards
   writes nothing, because the materialisation was by value. This is r12 paying for itself in
   scalability as well as in safety.
3. **Human-initiated per client,** with an explicit publish each time. There is no automatic
   propagation to cost.
4. **Server-side, chunked, idempotent** — never a client-side loop.

Fleet-wide: 8,000 coached clients × 31 writes/month ≈ **8,300 writes/day, 4% of the 210k budget.**

### 9.2 Cost envelope

| Line | Monthly |
|---|---|
| G14 Firestore reads (~390k) | $0.12 |
| G14 Firestore writes (~460k, incl. publish fan-out) | $0.41 |
| Cloud Functions (publishes ~8k/month) | < $0.05 |
| **G14 total** | **≈ $0.58/month** |

Consistent with `RECONCILIATION.md` §3: infrastructure is not what this product costs. The coach side
adds nothing material to a $75–95 infrastructure bill dwarfed 40×–150× by verification, SMS and
analytics.

---

## 10. Open questions — named

Silence is a defect. Four are blocking.

| # | Question | Blocking? | My assumption until answered |
|---|---|---|---|
| **OQ-1** | **`exercises[].contraindicationTags[]` does not exist.** G4's pack carries `{primaryMuscle, equipment, quiet, floorOnly}` only. Without the §1.5 vocabulary on the library, K21's avoid chips and every `refer` outcome are **displayed but unenforceable** — the coach records "no deep knee bends" and nothing in the system can act on it. Same defect class as G5's missing `foods.allergens[]`, and it is the one that makes HANDOFF 13 and 14 real rather than decorative | **YES — safety** | `ExerciseCandidateFilter` fails closed to the quiet/low-impact/floor subset (§5.1). Ship nothing that claims to honour an avoid list until the tags exist |
| **OQ-2** | **A coach can read nothing under `users/{clientUid}`** — `profile`, `sessions`, `meals`, `weeks` are all `isSelf(uid)` and must stay that way. Yet W02's constraint card and ring, W06's allergy strip and W09's summary all need client data. Proposed: G11's Function-maintained `shared/constraints` and `rollups/{isoWeek}` projections (§7.4), gated by the client's own sharing switches | **YES** | Screens render the projection; where it is absent they state so and fail closed. **No rules relaxation is acceptable** |
| **OQ-3** | **`assignment.meal` has no shape.** G2 writes `"meal": null` "through the MVP"; D1 withdrew that cut. W06 and W08 cannot publish a meal plan into an undefined field. Shape proposed in §7.1, including embedding coach meals **by value** | **YES** | W06 plans into my draft; publishing meals waits on G2's field |
| **OQ-4** | **`foods.allergens[]` and `foods.dietTags[]`** — seconding G5's Q10. Without them the coach-side allergy filter can display a restriction but not enforce one | **YES** | `AllergyGuard` fails closed (G5 §5.1) |
| **OQ-5** | **How many coaches?** §3 gives no coach population. Every cost figure in §2 derives from 8% coached / 12 clients per coach / ≈670 coaches / 270 daily active. Stated so it can be re-derived, not so it can be believed | no | The derived figures; G14 has ~30× headroom before it is material |
| **OQ-6** | **`stage` is an overloaded name.** The spine's `assessments.stage` is the woman's *life stage*; two readers took it for a workflow state. Renamed to `lifeStage`, workflow is `status`. **Flagged, per spine §7.3, rather than diverged quietly** | no | `lifeStage`; needs the spine owner's nod |
| **OQ-7** | **Does a client-only assessment exist?** The spine's `coachUid?` is optional, implying yes, but no self-assessment screen exists among the 161. D3 puts allergies in intake; D7 gives her the split builder. Either make `coachUid` required and drop the `?`, or name the screen | no | Both supported; `self_` scope prefix reserved |
| **OQ-8** | **Who may clear a `refer`, and on what basis?** The coach recorded the referral because it was outside her scope; letting her clear it alone re-imports the judgement she just declined. Options: coach with a recorded reason (implemented), or a required note that the client confirmed clearance. **A clinical and liability question, not an engineering one** | no | Coach, with a mandatory reason, recorded on a new document |
| **OQ-9** | **20 clients or 60?** W01 and W11 both say "of 20"; the scalability gate asks for 60. Both costed in §9.1 and both pass. Which is the product's rule? | no | Cap 20; 60 costed for the gate |
| **OQ-10** | **W09's button does two things.** "Save feedback and publish changes" implies saving feedback publishes — which would violate rule 2 the moment a coach has unpublished edits. Proposal: split into *Save feedback* (always, never publishes) and *Publish changes* (shown only when the draft is dirty) | no | Split; `ReviewFeedbackService` cannot publish regardless of the label |
| **OQ-11** | **The four-week re-assessment reminder.** HANDOFF lists it as something to build; G6/G8 agreed there is no scheduler. Proposal: keep it **lazy** — `assessmentDueAt` on the relationship drives W01's chip, with an optional local notification. No cron, no sweep, nothing to run at 100k MAU | no | Lazy; the chip is the mechanism, the notification is a convenience |
| **OQ-12** | **May an unverified coach publish?** K24 tells her to build while her certificates are checked. Building, yes. Putting a prescription in front of a woman on unchecked credentials is a different act. Proposed in §7.5: author everything, publish nothing, with the reason on W08's button | no | Author yes, publish no — G12 to confirm |
| **OQ-13** | **`tests/README.md` still describes the withdrawn cut.** The CSV half of this is fixed — the `Post-MVP` rows were re-tagged and the suite is now 592 `MVP`, 0 `Post-MVP`. But the README still defines the `scope` column against `BUILD-BRIEF.md` §0 ("`MVP` applies to the recommended cut"), which D1 withdrew, and still says "those **eleven** tests" for the P1 tier when the merged suite carries **22** (`P1-RULE-01`–`21`, with `10` split into `10A`/`10B`). A suite whose README describes a different scope than its rows is how a QA pass silently skips a tier. Flagged, not edited — I modify no existing file | no | My rows are `MVP`; the README needs the §0 reference and the count corrected by whoever owns `tests/` |
| **OQ-14** | **W02's "8 weeks with you · 21 of 25 planned sessions · Bests: squat 12 kg".** Bests are `users/{uid}/bests/*`, G6-owned and coach-unreadable. Either the rollup projection carries them (with the client's consent) or W02 drops the line. **It must not become a second, coach-side computation of a number the client already sees** — two sources, one disagreement | no | Via the rollup, consent-gated; otherwise the line is removed |
