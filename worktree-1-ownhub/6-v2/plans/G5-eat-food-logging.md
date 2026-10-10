# G5 — Eat & food logging

Screens: `E01` Eat, `E02` Type it, `E03` Say it, `E04` After a log, `E05` Recipes, `E06` Recipe,
`E07` Week plan, `E08` Grocery list, `E09` Eat, day one.

Written against `SCHEMA-SPINE.md` (paths and names verbatim), `BUILD-BRIEF.md` §2/§3/§4,
`flutter/HANDOFF.md` rules 1–3, 7, 9, 16, 17, and `tests/TEST-CASES.csv`.

**One-line summary of the architecture:** the food library never leaves the device, so parsing costs
nothing and works on a microbus; the day is one document keyed by date, so the Eat screen is one
read; and the 5-second undo happens *before* the write, so undo costs nothing either.

---

## 1. Data model

### 1.1 Collections G5 owns

`users/{uid}/meals/{yyyy-MM-dd}` — **spine C3, one document per day.** Source of truth for a day.

| Field | Type | Null | Notes |
|---|---|---|---|
| `slots.breakfast` | `array<item>` | yes | spine shape kept verbatim; absent until first log |
| `slots.lunch` | `array<item>` | yes | |
| `slots.dinner` | `array<item>` | yes | |
| `slots.snack` | `array<item>` | yes | |
| `totals.kcal` | `int` | no | **denormalised cache**, maintained by `increment` (C4) |
| `totals.protein` | `int` | no | grams, same |
| `firstLogAt` | `timestamp` | yes | written once; the once-a-day points hook (→ §7 G6) |
| `tz` | `string` | no | IANA zone at the moment of the action, e.g. `Africa/Cairo` |
| `libVersion` | `int` | no | `foods` pack version that produced the macros |
| `updatedAt` | `timestamp` | no | `request.time`, asserted in rules |

`item` — extends the spine's `item` **without changing its declared fields or its `source` enum**:

| Field | Type | Null | Notes |
|---|---|---|---|
| `foodId` | `string` | no | spine. Must exist in the local `foods` pack |
| `servings` | `number` | no | spine |
| `size` | `string` | no | spine. `'S'|'M'|'L'` or a food-specific size id |
| `loggedAt` | `timestamp` | no | spine |
| `source` | `string` | no | spine enum, unchanged: `'planned'|'search'|'voice'` |
| `itemId` | `string` | no | **G5 extension.** Identity for correction/dedupe (§1.4) |
| `origin` | `string` | no | **G5 extension.** `plan|suggestion|recipe|search|voice|nudge` — the finer provenance E01/E04/E06 need, kept off `source` so the spine's enum is untouched |
| `kcal` | `int` | no | resolved at log time from the pack, frozen |
| `proteinG` | `int` | no | frozen, same reason |
| `planRef` | `map` | yes | `{assignmentId, slot, idx}` when `origin == 'plan'`. **Dormant in the MVP** — G2's plan confirms `assignment.meal` is `null` for the whole cut (no coach exists to plan meals), so nothing writes this field until coaching ships. The field, the correction path and its test are built now regardless (§1.4) |
| `helpingOf` | `string` | yes | `itemId` of the first helping (HANDOFF rule 3) |
| `allergenOverride` | `array<string>` | yes | allergens she explicitly acknowledged (§5, §1.5) |

`users/{uid}/eatPrefs/current` — **single fixed document id** (C1: deterministic, offline-idempotent).
The "suggestion source" the spine's §4 budgets for E01. Bounded by construction.

| Field | Type | Notes |
|---|---|---|
| `plates.<plateId>.d.<yyyy-MM-dd>` | `int` | times eaten that day. **Absolute per (plate, date) → idempotent on replay, commutative across devices (distinct keys).** Rolling 28-day window, older keys deleted on write |
| `plates.<plateId>.slots.<slot>` | `int` | histogram, for "what she eats at this hour" |
| `plates.<plateId>.dow.<0-6>` | `int` | histogram, for "Tuesdays" (E04) |
| `plates.<plateId>.items` | `array` | `[{foodId, size, servings}]` — the plate definition |
| `plates.<plateId>.lastAt` | `timestamp` | tie-break and eviction key |
| `ramadanMode` | `string` | `auto|on|off` (E01 pill). Display-only (§1.6) |
| `proteinTargetGOverride` | `int?` | null normally; target comes from G2 (→ §9 Q1) |
| `libVersion` | `int` | |

`plateId = sha1(sorted(foodId + ':' + size).join('|')).substring(0,16)` — deterministic, so the same
plate from two devices lands on the same key. Cap **40 plates**; evict lowest `(28-day count, lastAt)`.
A plate is created when a combination is logged the **second** time (E09's promise: "log something
twice and it becomes a one-tap plate").

`users/{uid}/mealPlans/{yyyy-Www}` — E07 + E08, one document per ISO week (C1).

| Field | Type | Notes |
|---|---|---|
| `dinners.<mon..sun>` | `string?` | `recipeId`, from recipes she has logged before |
| `groceries.<itemKey>` | `map` | `{qty, unit, ticked: bool, tickedAt}`. Distinct keys → commutative |
| `recipeVersion` | `int` | pack version the list was generated from |
| `updatedAt` | `timestamp` | |

`itemKey = sha1(ingredientId + ':' + unit).substring(0,12)` — so a tick from two devices converges.

### 1.2 Content G5 reads but never writes

`foods/{foodId}`, `recipes/{recipeId}` are immutable, read-only, and **never read from Firestore on
any hot path** (spine §4). They are the *authoring* store. A content pipeline builds a signed pack:

| Artefact | Contents | Size | Delivery |
|---|---|---|---|
| Bundled pack | top ~1,500 Egyptian foods + 120 recipes, SQLite/FlatBuffer + FTS index | ~550 KB | `pubspec.yaml` asset, ships in the binary |
| Full pack | all 4,100 foods + all recipes + alias/Franco index | ~1.8 MB gz | one CDN download on first run, `ETag`-cached |
| Version stamp | `foodsLibraryVersion`, `recipesLibraryVersion` | — | Remote Config; a bump triggers one background re-download |

Firestore reads of `foods`/`recipes` per session: **0**. Naïve per-session library reads would add
~33 reads/user/day — the spine's "difference between 7 reads a day and 40".

**Fields G5 requires on `foods`** (a request to the content pipeline owner, not an addition by G5 —
see §9 Q10, which is blocking): `names{ar, en, franco, aliases[]}`, `allergens[]`, `dietTags[]`,
`sizes[{id, label, grams}]`, `kcal`, `proteinG`, `costEGP`, `verified: bool`, `popularity: int`.
Without `allergens[]` and `dietTags[]` the allergy guard in §5 cannot function.

### 1.3 Indexes

**Composite indexes required: none.** Every G5 access is a document `get` by deterministic id. There
is no `.where()` and no `.orderBy()` against Firestore anywhere in this group; frequency questions
are answered from the bounded `eatPrefs/current` rollup, never by scanning `meals`.

What *is* needed is the opposite — three **single-field index exemptions**, because Firestore
auto-indexes every nested map path and `plates` has ~1,100 leaf paths:

```json
// firestore.indexes.json → fieldOverrides
{ "collectionGroup": "eatPrefs",  "fieldPath": "plates",    "indexes": [] },
{ "collectionGroup": "meals",     "fieldPath": "slots",     "indexes": [] },
{ "collectionGroup": "mealPlans", "fieldPath": "groceries",  "indexes": [] }
```

This removes ~1,100 index-entry writes per `eatPrefs` write and keeps every document far below the
40,000-index-entries-per-document ceiling.

### 1.4 Identity, correction and the second helping (HANDOFF rule 3)

Two different user intents, kept apart **structurally** so they cannot collapse:

| Intent | `itemId` | Write | Result |
|---|---|---|---|
| Log a planned meal | `sha1(planRef)` — **deterministic** | `arrayRemove(old)` + `arrayUnion(new)` | replaces → **corrects** |
| Log the same planned meal again | same deterministic id | same | corrects again, still one item |
| "Another helping" | fresh UUIDv4, `helpingOf: <first itemId>` | `arrayUnion(new)` | **a second item** |
| Free log (search/voice/recipe) | fresh UUIDv4 | `arrayUnion(new)` | a new item |

Domain layer exposes two methods with no shared entry point: `MealLogService.correctPlannedLog()`
and `MealLogService.addHelping()`. The UI affordances are separate too — E04's row action is *Edit*
(correct), and *Another helping* is its own action. There is no code path where re-tapping *Log*
silently doubles a serving, and none where a helping overwrites the first.

### 1.5 The running total, and why a countdown is unrepresentable

The domain model is:

```
class DayTotals { int kcalSoFar; int proteinSoFar; int proteinTargetG; }
```

There is **no `kcalRemaining`, no `kcalTarget`, no `deficit`, no `over` field anywhere in the G5
domain or data model** — the same technique C6 uses against `streak`. A widget cannot render a
calorie countdown because nothing computes one. E01/E04 render `kcalSoFar` as prose ("About 1,106
kcal so far today") and protein as a bar that fills. Protein is the only target.

### 1.6 Ramadan mode is a label, not a schema

Slot keys stay `breakfast|lunch|dinner|snack` forever. `RamadanSlotLabeller` maps
`breakfast→suhoor`, `dinner→iftar` for display when `ramadanMode` resolves true. Adding `suhoor`/
`iftar` keys would break C3's merge, G6's reads, and every historical document — so it is not done.
(→ §9 Q3 for the Hijri source.)

---

## 2. Query, index and cost per screen

Budget basis: 35,000 DAU, ~8 reads / ~6 writes per active day, 40% of traffic 19:00–23:00 Cairo.
`R` = Firestore reads, `W` = writes. "shared" = the document is already read by another group in the
same session and served from the same cache, so the marginal cost to G5 is zero.

| Screen | Operation | Index | R | W |
|---|---|---|---|---|
| `E01` Eat | `get users/{uid}/meals/{today}` (snapshot listener while mounted) | doc id | 1, or **0 if T01 was opened first** — G3's plan pays this read at T01 for its meal card, and the document is then warm in the same cache | 0 |
| | `get users/{uid}/eatPrefs/current` | doc id | 1 | 0 |
| | `get users/{uid}` for `profile.allergies`/`dietary` | doc id | shared (G3 T01) | 0 |
| | `get plans/{uid}/assignments/{today}` for the planned meal | doc id | shared (G3/G4) | 0 |
| | "Yesterday's lunch again": `get meals/{yesterday}` **cache-only** (`Source.cache`); absent → row omitted | doc id | 0 | 0 |
| | Suggestion ranking: in-memory over ≤40 plates | none | 0 | 0 |
| `E02` Type it | Parse + match: **on-device** against the local pack | local FTS | 0 | 0 |
| | History row + "one you've had before": already-loaded `eatPrefs` | none | 0 | 0 |
| | "All foods, 4,100": local pack paging | local | 0 | 0 |
| | Commit on log | — | 0 | 1 (see E04) |
| `E03` Say it | STT: on-device `ar-EG`; fallback = 1 HTTPS call to a Function (§6 of this table's notes) | — | 0 | 0 |
| | Transcript → the **same** on-device parser as E02 | local FTS | 0 | 0 |
| `E04` After a log | Commit: one `set(merge:true)` on `meals/{today}` with `arrayUnion` + `increment` | doc id | 0 | 1 |
| | Rollup: debounced `set(merge:true)` on `eatPrefs/current`, ≤1×/day | doc id | 0 | ≤1/day |
| | Re-render from the live listener attached by E01 | — | 0 | 0 |
| | Undo within 5 s → **nothing was written** (§4.2) | — | 0 | 0 |
| `E05` Recipes | Filter/search recipes in the local pack | local | 0 | 0 |
| `E06` Recipe | Read one recipe from the local pack | local | 0 | 0 |
| | "Cooked it — log my bowl" | doc id | 0 | 1 (an E04 commit) |
| `E07` Week plan | `get users/{uid}/mealPlans/{isoWeek}` | doc id | 1 | 0 |
| | Candidate dinners = plates she has logged, from the already-loaded rollup | none | 0 | 0 |
| | Swap a dinner (debounced 2 s) | doc id | 0 | 1 |
| `E08` Grocery list | Same document as E07, already in cache | doc id | 0 | 0 |
| | Ticks: local-first, debounced flush on 2 s idle / screen exit / background | doc id | 0 | 1 per shop |
| `E09` Eat, day one | `get meals/{today}` → absent ⇒ render the day-one branch of E01 (HANDOFF rule 16: a state, not a route) | doc id | 1 (the same read as E01) | 0 |
| | Three starters = the top-`popularity` Egyptian foods from the local pack | local | 0 | 0 |

### Cost per active day

| | Amount | Working |
|---|---|---|
| Reads | **1.9** | 1 `eatPrefs/current` + 0.4 `meals/{today}` (0 on the ~60% of days she opens Home before Eat, which G3 pays for at T01) + 0.35 listener re-attach on a second session + 0.15 amortised `mealPlans` (E07/E08 opened ~1 active day in 7) |
| Writes | **4.1** | 2.6 committed meal logs + 1.0 debounced rollup + 0.3 `mealPlans` + 0.2 corrections |

Against the spine §4 line for `E01` (2 reads) and the §3 allowance (~8 reads / ~6 writes for *all*
groups): G5 is **inside budget on reads** and consumes roughly two thirds of the day's write
allowance, which is correct — meals are the most frequent write in this product.

### Fleet cost at 100k MAU / 35k DAU

| Line | Volume/day | Monthly | Cost |
|---|---|---|---|
| Reads | 67k | 2.0M | $1.2 |
| Writes | 144k | 4.3M | $7.8 |
| Storage | `meals` ~1.2 KB × 365/user/yr; `eatPrefs` ~20 KB | ~46 GB at year one | $8.4 |
| Functions (once-a-day points hook) | 35k | 1.05M | ~$0.2 |
| Food-pack CDN | 1.8 MB × new installs only (~20k/mo) | 36 GB | ~$1.0 |
| **G5 subtotal** | | | **~$19 / month** |
| Voice tier 2 (cloud STT), if fully on | 3,500 calls × ~10 s | ~290 h audio | **~$420 / month** |

Cloud STT is the only material variable cost in this group and it is gated behind Remote Config
(`voiceCloudFallbackEnabled`) so it can be switched off without a release. The ~11 TB/month video
egress in §3 belongs to G4, not here.

### Peak (19:00–23:00 Cairo)

Dinner sits inside the peak window, so G5 concentrates worse than the fleet average: assume **55%**
of meal writes in those 4 hours → 79k writes / 14,400 s ≈ **5.5 writes/s fleet-wide**. Trivial for
Firestore. The relevant limit is per-document (~1 sustained write/s) and the hot document is
`users/{uid}/meals/{date}` — **3 writes per day on one document**, so there is no contention.

Sequential document ids (dates) do not create an index hotspot here because the collection is nested
under `users/{uid}`: the index range is prefixed by `uid`, so 35,000 writers land on 35,000 distinct
key ranges rather than one monotonically advancing tail.

---

## 3. State machines

### 3.1 Meal slot

States: `empty → planned → logged → corrected`, plus `skipped`, plus the day-one `absent`.
`queued` is **not** a state — it is an orthogonal sync flag rendered as a badge on the row (§4.3).

| From | Event | To | Effect |
|---|---|---|---|
| `absent` | day document does not exist | `absent` | E09 branch renders |
| `absent` / `empty` | an assignment exists for this slot | `planned` | row shows the prescription; **nothing is written** (§2 rule 1). **Unreachable in the MVP** — G2 publishes `meal: null` for the whole cut, so E01 renders the free-log path. Implemented and tested now so coaching does not have to retrofit rule 1 |
| `empty` | `logItems()` commits | `logged` | `arrayUnion` + `increment` |
| `planned` | `logItems()` on the planned item | `logged` | item carries `planRef`, deterministic `itemId` |
| `planned` | `skipSlot()` | `skipped` | `slots.<slot> = []` + `skippedAt`; no penalty anywhere |
| `logged` | `correctPlannedLog()` / `Edit` | `corrected` | `arrayRemove(old)` + `arrayUnion(new)` + `increment(delta)` |
| `logged` | `addHelping()` | `logged` | a **second** item; slot stays `logged` |
| `corrected` | `correctPlannedLog()` again | `corrected` | idempotent on the same `itemId` |
| `logged` / `corrected` | `undoPending()` within 5 s | previous state | pending buffer discarded, **no write ever issued** |
| `logged` / `corrected` | remove the last item | `empty` (or `planned` if an assignment exists) | `increment(-kcal, -protein)` |
| `skipped` | `logItems()` | `logged` | skip is never final |

Illegal transitions (asserted in `MealSlotStateMachine`, unit-tested): `absent → logged` without a
day document; `planned → logged` with an item whose `foodId` is absent from the pack;
`* → logged` while an unacknowledged allergen verdict is outstanding (§5).

### 3.2 A pending log item (the undo window)

`parsed → confirmed → pending(5 s) → committed`, with `pending → discarded` on undo and
`pending → committed` on app background, navigation away, or expiry — whichever comes first.

| From | Event | To | Notes |
|---|---|---|---|
| `parsed` | below confidence threshold | `unresolved` | rendered as a tappable chip; never a guessed food |
| `parsed` / `unresolved` | she picks a food and size | `confirmed` | |
| `confirmed` | allergen hit | `blocked` | sheet; `blocked → confirmed` only on explicit acknowledgement |
| `confirmed` | tap *Log* | `pending` | optimistic render + snackbar with *Undo*; **durably** journalled locally |
| `pending` | *Undo* < 5 s | `discarded` | zero writes, zero sync traffic |
| `pending` | 5 s elapse / background / route change | `committed` | one Firestore write |
| `pending` | process death | `pending` | the local journal replays on next launch, then commits |
| `committed` | — | terminal | further changes go through correction |

### 3.3 Voice capture (E03)

`idle → recording → transcribing → transcript-shown → parsed → …(3.2)`, with
`transcribing → failed` on a timeout and `failed → idle` with the *Say it again* action.
`transcript-shown` is mandatory and non-skippable (P0-LOG-08). `recording → refused` when no
`ar-EG` model and no signal, which routes to E02 with an explanation rather than a spinner
(P2-OFF-E03).

### 3.4 Food pack

`bundled → downloading → full(v) → stale(v) → downloading → full(v+1)`. `stale` is fully usable;
the re-download is background-only and never blocks logging. A failed download leaves `bundled`
usable forever.

---

## 4. Offline behaviour

### 4.1 What is writable offline

| Path | Offline | Why |
|---|---|---|
| `users/{uid}/meals/{date}` | **yes** | logging never requires signal (§3 of the brief) |
| `users/{uid}/eatPrefs/current` | **yes** | increments/absolute map keys, both offline-safe |
| `users/{uid}/mealPlans/{week}` | **yes** | E08 must survive being closed mid-shop |
| `plans/{uid}/assignments/*` | no (server-authored) | read from cache; a missing assignment renders the free-log path, not an error |
| `foods` / `recipes` | n/a | local pack, always available |
| Cloud STT fallback | no | queued audio is **not** kept; E03 refuses clearly and offers E02 |

Everything on E01/E02/E04/E05/E06/E07/E08/E09 works with the radio off. E03 works offline only when
the on-device `ar-EG` model is present.

### 4.2 Undo costs nothing offline either

Because the 5-second undo happens *before* the Firestore write (§3.2), an undo offline is not a
compensating write sitting in the sync queue — it is the absence of a write. This matters: a
write-then-delete design would push two operations through a reconnect and could fire G6's
once-a-day points hook for a log she cancelled.

### 4.3 What the UI shows while queued

- The logged row appears **immediately**, with its real numbers, and the day total moves.
- A small "not synced yet" mark sits on the affected row only. No blocking spinner, no dialog, no
  failure message for something that will sync (spine §5).
- The protein bar and the kcal line are computed from local state, so they are never stale-looking.
- If the sync queue is older than 24 h the Eat screen shows one quiet inline line ("waiting for
  signal to save 3 meals") — informational, never an error, never blocking.

### 4.4 Conflict resolution

| Conflict | Mechanism | Converges? |
|---|---|---|
| Two devices, **different** slots | distinct map keys under `slots` merge field-level (C3) | yes, exactly |
| Two devices, **same** slot | `FieldValue.arrayUnion(item)` — a transform, not a value overwrite, so both items survive | yes (see 4.5) |
| Day totals | `FieldValue.increment` on `totals.kcal`/`totals.protein` (C4) | yes, commutative |
| Correction vs. helping on two devices | `arrayRemove(old)+arrayUnion(corrected)` and `arrayUnion(helping)` compose | yes → `{corrected, helping}` |
| Two different corrections of the **same** item | both transforms apply → two entries with the same `itemId` | **read-time dedupe** (4.5) |
| Plate rollup | `plates.<id>.d.<date>` is absolute per (plate, date) — idempotent on replay, distinct keys across devices | yes |
| Grocery ticks | `groceries.<itemKey>.ticked` — distinct keys, LWW per key | yes |
| `ramadanMode`, `proteinTargetGOverride` | single-owner scalars, LWW (spine §5) | yes |

### 4.5 The two-devices-offline case, explicitly

Scenario: phone and tablet both offline. Phone logs *koshari + 2 eggs* to `lunch` (696 kcal).
Tablet logs *molokhia* to `lunch` (460 kcal). Both reconnect.

Each device issues the same shaped write:

```dart
// MealLogService._commit — one set, three transforms
await mealsRef.doc(dayId).set({
  'slots': { slot: FieldValue.arrayUnion(newItems) },   // merges, does not overwrite
  'totals': { 'kcal': FieldValue.increment(dKcal),
              'protein': FieldValue.increment(dProtein) },
  'firstLogAt': FieldValue.serverTimestamp(),           // see note
  'tz': tzName, 'libVersion': libVersion,
  'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
```

Result after both sync: `slots.lunch` holds **all three items** and `totals.kcal == 1,156`. Neither
device clobbered the other, and no read-modify-write was involved, so the order of arrival does not
matter.

Two things this design is honest about:

1. **`arrayUnion` cannot enforce uniqueness by `itemId`** — it dedupes by whole-element equality. Two
   *different* corrections of the same planned item therefore produce two entries sharing an
   `itemId`. `MealDayReader.dedupe()` resolves this deterministically at read time (keep the entry
   with the greatest `loggedAt`; ties broken by the lexicographically greater `itemId` hash), so
   every device renders the same day, and the next write rewrites the canonical array. A map keyed by
   `itemId` would make this exact instead of convergent-at-read — that is §9 Q11, raised rather than
   worked around, because the spine declares `slots.<slot>` as an array.
2. **`totals` is a cache, not truth.** The item list is truth. If read-time dedupe drops an entry,
   `DayTotals.recompute(items)` disagrees with the stored `totals`; the reader then renders the
   recomputed value and the next write repairs `totals` with an absolute set. Self-healing, no
   migration, no background job.

`firstLogAt` with a server timestamp resolves LWW across two devices on the same day, which is
harmless — it is only used to mean "she logged something today", and C3 already guarantees one
document per day.

---

## 5. §2 rules G5 owns, and where each is enforced

All in `lib/features/eat/domain/`. Every one has a unit test; none is enforced in a widget.

| Rule | Owner class · method | Enforcement |
|---|---|---|
| §2.1 A prescribed value is never a result | `MealSlotStateMachine.resolve()` | A slot with an assignment renders `planned` and writes **nothing**. `slots.<slot>` is absent until she acts. The planned item is a separate object from a logged item and has no `loggedAt` |
| §2.9 Undo, not confirmation (5 s) | **G3's shared `UndoableLog` / `LogCommandBus`**, with `MealLogCommand` as G5's payload | G3's plan claims rule 9 as one shared implementation for G4 and G5 rather than one per feature, which is correct — **G5 conforms and drops its own `PendingLogBuffer`**. G5 supplies the command (§3.2's durable pending semantics are the bus's), and `MealLogService` exposes **no** `confirm*` API, so no logging path can raise a dialog. Asserted by `P1-RULE-09`. → §9 Q14 |
| Calm running total, never a countdown | `DayTotals` (the type itself) | No `remaining`/`target-kcal`/`deficit` field exists in the model (§1.5). Unrepresentable, like C6's `streak` |
| §2.3 Weeks, not days (G5's share) | `MealDayReader`, `PlateRollup` | No consecutive-day field in any G5 document; the rollup keys are *dates in a set*, never a run length. Rules deny `streak`-shaped keys (§6) |
| HANDOFF 3 Correct vs. second helping | `MealLogService.correctPlannedLog()` vs `.addHelping()` | Two methods, two `itemId` strategies (§1.4). Neither can express the other |
| §2.10 Selects, never generates (food half) | `MealSentenceParser.parse()`, `FoodLibrary.resolve()` | The parser can only emit `foodId`s that exist in the signed pack, and quantities only from `sizes[]`. An unmatched fragment becomes an `unresolved` chip — **never** an invented food or an invented gram figure |
| §2.11 Nothing ranked by weight/lost/followers | `PlateRollup.rank()` | Ranks a woman's *own* 28-day frequency. No cross-user read exists in G5, and no index supports one (C7) |
| HANDOFF 16 First-run is a state | `EatScreen` branch on `MealDayReader.isFirstDay` | `E09` is a branch inside the Eat route; `app_routes.dart` gains no destination for it |
| HANDOFF 17 The empty state is the onboarding | `EatEmptyStateBuilder` | E09 states what will appear, why it is empty, and offers one action. No tour, no overlay |
| Allergies and dietary preferences (safety-critical) | `AllergyGuard` | §5.1 below |

### 5.1 `AllergyGuard` — the safety path

Input: `DietaryConstraints{ allergies[], dietary[] }` read from G2's `users/{uid}.profile`, plus
`foods[].allergens[]` / `dietTags[]` from the pack. Two severities, deliberately different:

| Class | Source | Where applied | UI on conflict |
|---|---|---|---|
| **Allergy** (safety) | `profile.allergies[]` | `AllergyGuard.screen()` removes matching foods from every candidate list **before** ranking — suggestions (E01/E09), parser output (E02), voice resolution (E03), recipes (E05/E06), week plan (E07). Filtering at the source, not validating after (the rule K27 states) | If she nonetheless reaches a conflicting food by name, by coach plan, or by voice: `AllergyGuard.assess()` returns `AllergyVerdict.blocked` and the domain layer **refuses the write**. A modal sheet names the allergen ("This has sesame — you told us sesame") with *Not this* and *Log it anyway*. *Log it anyway* is an explicit tap and stamps `allergenOverride: ['sesame']` on the item. She is the authority on her own body; she is never surprised by it |
| **Dietary preference** (not safety) | `profile.dietary[]` | Same `screen()` call — excluded from suggestions and recipe lists | **No sheet, no override, no warning.** Logging a non-vegetarian item is not a safety event; it simply is not suggested. Treating a preference like an allergy trains her to dismiss the sheet that matters |

Three properties of this placement:

1. It sits **in the domain layer before the write**, so every entry point hits it — including the
   lock-screen meal nudge action (`T03`, platform-specific per §4 of the brief). A notification
   quick-action can therefore never one-tap-log a conflicting planned meal: the action defers to the
   app, which opens the sheet.
2. A **coach-planned** item that conflicts is blocked upstream at `W06` ("an incompatible ingredient
   blocks assignment rather than warning afterwards"). If one arrives anyway, E01 renders the planned
   row **disabled with the reason** and offers alternatives. It is never auto-logged and never
   silently dropped. (→ §9 Q5.)
3. If `profile.allergies` cannot be read (cold start, no cache, brand-new install), `AllergyGuard`
   **fails closed for the allergy class**: suggestions render, but any log requires the sheet's
   acknowledgement path until the profile is available. An unknown constraint is not an absent one.

---

## 6. Security rules

Against the spine's exact paths. Note deliberately: G5's paths require **auth only, not
verification** — `P0-VER-04` requires that workouts and recipes stay open while only the community
waits. C5's gate belongs on community paths, not here.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isOwner(uid) {
      return request.auth != null && request.auth.uid == uid;
    }
    function freshStamp() {
      return request.resource.data.updatedAt == request.time;
    }
    // C6: rule 3 is enforced by making a streak unstorable.
    function noStreakKeys() {
      return !request.resource.data.keys().hasAny(
        ['streak', 'streakDays', 'consecutiveDays', 'daysInARow', 'currentStreak']);
    }

    // ---------- G5: one meal document per day (spine C3) ----------
    match /users/{uid}/meals/{dayId} {

      function idIsIsoDate() {
        // C1: deterministic, date-keyed id. Lexicographic == chronological on padded ISO dates,
        // so this also bounds the id to a plausible range. Exact "not after today" is asserted in
        // the domain layer, because rules cannot zero-pad request.time.month.
        return dayId.matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
          && dayId >= '2026-01-01'
          && dayId <= string(request.time.year + 1) + '-12-31';
      }
      function docKeysOk() {
        return request.resource.data.keys().hasOnly(
          ['slots', 'totals', 'firstLogAt', 'tz', 'libVersion', 'updatedAt', 'skippedAt']);
      }
      function slotKeysOk() {
        return !('slots' in request.resource.data)
          || request.resource.data.slots.keys().hasOnly(
               ['breakfast', 'lunch', 'dinner', 'snack']);
      }
      // Post-transform sizes. Explicit per slot: rules have no loops.
      function slotSizesOk() {
        return !('slots' in request.resource.data) || (
          (!('breakfast' in request.resource.data.slots)
            || request.resource.data.slots.breakfast.size() <= 24)
          && (!('lunch' in request.resource.data.slots)
            || request.resource.data.slots.lunch.size() <= 24)
          && (!('dinner' in request.resource.data.slots)
            || request.resource.data.slots.dinner.size() <= 24)
          && (!('snack' in request.resource.data.slots)
            || request.resource.data.slots.snack.size() <= 24));
      }
      function totalsOk() {
        return !('totals' in request.resource.data) || (
          request.resource.data.totals.keys().hasOnly(['kcal', 'protein'])
          && request.resource.data.totals.kcal is number
          && request.resource.data.totals.kcal >= 0
          && request.resource.data.totals.kcal <= 30000
          && request.resource.data.totals.protein is number
          && request.resource.data.totals.protein >= 0
          && request.resource.data.totals.protein <= 2000);
      }
      function metaOk() {
        return request.resource.data.tz is string
          && request.resource.data.libVersion is int
          && (!('firstLogAt' in request.resource.data)
              || request.resource.data.firstLogAt is timestamp);
      }

      allow get, list: if isOwner(uid);
      allow create, update: if isOwner(uid)
        && idIsIsoDate() && docKeysOk() && slotKeysOk() && slotSizesOk()
        && totalsOk() && metaOk() && noStreakKeys() && freshStamp();
      // Deletion only via the account-deletion path (P0-DEL-01), which runs as admin.
      allow delete: if false;
    }

    // ---------- G5: bounded suggestion rollup, one fixed document ----------
    match /users/{uid}/eatPrefs/{docId} {
      allow get: if isOwner(uid);
      allow create, update: if isOwner(uid)
        && docId == 'current'
        && request.resource.data.keys().hasOnly(
             ['plates', 'ramadanMode', 'proteinTargetGOverride', 'libVersion', 'updatedAt'])
        && (!('plates' in request.resource.data)
            || request.resource.data.plates.keys().size() <= 40)   // hard cap, no unbounded growth
        && (!('ramadanMode' in request.resource.data)
            || request.resource.data.ramadanMode in ['auto', 'on', 'off'])
        && noStreakKeys() && freshStamp();
      allow delete: if false;
    }

    // ---------- G5: week plan + grocery list ----------
    match /users/{uid}/mealPlans/{weekId} {
      allow get, list: if isOwner(uid);
      allow create, update: if isOwner(uid)
        && weekId.matches('^[0-9]{4}-W[0-9]{2}$')                  // C1: ISO week id
        && request.resource.data.keys().hasOnly(
             ['dinners', 'groceries', 'recipeVersion', 'updatedAt'])
        && (!('dinners' in request.resource.data)
            || request.resource.data.dinners.keys().hasOnly(
                 ['mon','tue','wed','thu','fri','sat','sun']))
        && (!('groceries' in request.resource.data)
            || request.resource.data.groceries.keys().size() <= 120)
        && noStreakKeys() && freshStamp();
      allow delete: if isOwner(uid);                               // discarding a week is hers
    }

    // ---------- Read-only content the client normally never reads ----------
    match /foods/{foodId}   { allow read: if request.auth != null; allow write: if false; }
    match /recipes/{recipeId} { allow read: if request.auth != null; allow write: if false; }

    // G5 never writes rewards, weeklyGoal, verification, or anything under plans/**.
    // Those denials live in G6's, G1's and G2's rule blocks; G5 asserts only that it does not.
  }
}
```

Negative tests G5 supplies to the rules test suite: a second uid writing `users/{A}/meals/*`; a
`meals` write carrying `streak: 3`; `slots.suhoor`; `totals.kcal: -50`; a 25th item in a slot; a
`meals` doc id of `2026-6-1` or `9999-01-01`; `eatPrefs/other`; a 41st plate; an unauthenticated
read of `foods`; any client write to `foods`.

---

## 7. Interface to the other groups

Per the spine's ownership table. G5 writes `meals/*` and its own two extension collections, and
nothing else, ever.

### Consumes

| From | Path · field | Use | Failure mode |
|---|---|---|---|
| **G2** | `users/{uid}.profile.allergies[]` | **safety-critical.** Excludes foods before ranking; blocks a conflicting log behind an explicit acknowledgement (§5.1) | unavailable ⇒ **fail closed** for the allergy class |
| **G2** | `users/{uid}.profile.dietary[]` | excludes from suggestions and recipes; no sheet, no override | unavailable ⇒ suggestions unfiltered, no block |
| **G2** | `plans/{uid}/assignments/{date}.meal` | the `planned` slot state on E01, `planRef` on the logged item | **G2 publishes `null` for the entire MVP** (no coach to plan meals; E01's "From Sara" is a coaching surface, out of cut). G5 renders its own suggestion path — which is the default path, not a fallback |
| **G2** | `plans/{uid}/assignments/{date}.nutrition.proteinTargetG` | the protein bar's denominator (E01's "95 g") | **G2's plan contains no nutrition field at all**, so this is unowned rather than merely unwritten → §9 Q1. Remote Config constant until it is assigned |
| **G2** | `users/{uid}.profile.language`, `lifeStage` | MSA vs English strings; Ramadan default | — |
| **content pipeline** | `foods`, `recipes` → signed pack | every resolution, every macro, every price | pack missing ⇒ bundled 1,500 foods still work |
| **G8** | offline persistence, sync-badge widget, device locale/TZ, Remote Config, Amplitude client | as the platform | — |

### Publishes

| To | What | Contract |
|---|---|---|
| **G6** | `users/{uid}/meals/{date}` exists, and `firstLogAt` | **The +5 points, once a day, is awarded by a Cloud Function on `onCreate` of the meal document** — so C3's one-document-per-day *is* the once-a-day guarantee. G5 never writes `rewards`. Never per item, so there is no reason to split a plate |
| **G6** | `totals.protein`, `totals.kcal`, item count | read-only, for Progress. G6 must treat `totals` as a cache and prefer `DayTotals.recompute(items)` (§4.5) |
| **G3** | `MealDayReader.todaySummary()` — the "Breakfast: ful and baladi / Lunch: now" strip and whether anything is logged today | in-process domain call on the document G3 already read for T01. G3 owns T01's layout, G5 owns the numbers |
| **G3** | **`usualPlates`** — a cacheable ranked plate list with a `version` stamp, served from `eatPrefs/current` | **Granted: this resolves G3's §9 Q2 at zero marginal cost**, because the rollup already exists and is already bounded at 40 plates. G3 reads the version stamp, not the plates, to decide whether its cached copy is stale. G5 bumps `version` on every rollup flush |
| **G3 / G8** | `MealRepository.logItem(planRef)` (G3's name for it, adopted) | the lock-screen meal-nudge action. Routed through `AllergyGuard` and G3's `LogCommandBus` like every other path — §4 of the brief requires an Android notification action **and** an iOS Notification Content Extension, both landing on this one method. G3's plan defers the iOS side; the guard behaves identically on both |
| **G7** | the list of G5 paths for account deletion: `users/{uid}/meals/**`, `users/{uid}/eatPrefs/**`, `users/{uid}/mealPlans/**` | `P0-DEL-01`. No G5 data lives outside `users/{uid}/**`, and G5 writes nothing to Storage |
| **Assistant (post-MVP)** | the pack as the backing store for `search_food_library`, with `allergens[]` applied **server-side before selection** | HANDOFF's tool contract. No `foodId` outside the pack can be returned; there is no publish tool |
| **G8 / Amplitude** | `eat_log_committed{screen, origin, itemCount, undone}`, `eat_parse_result{resolved, unresolved}`, `eat_voice{tier, refused}` | **Never** a food name, a kcal figure, a protein figure, an allergen, or any transcript. Spine §6 (PDPL): coarse outcome and screen id only |

### Fields G5 requests (does not add)

1. `plans/{uid}/assignments/{date}.nutrition.proteinTargetG` — **from G2**.
2. `foods.allergens[]`, `foods.dietTags[]`, `foods.sizes[]`, `foods.names.franco`,
   `foods.popularity` — **from the content pipeline owner**. Blocking for §5.1.

---

## 8. Test cases G5 is accountable for

### Owned outright

| ID | Screens | What G5 must make true |
|---|---|---|
| `P0-LOG-06` | E01, E04 | One tap on the top suggestion. Slot fills, protein bar animates, running total updates, snackbar with Undo, **no calorie countdown anywhere** |
| `P0-LOG-07` | E02, E04 | "koshari and 2 eggs" parses into two items with sizes pre-picked; sizes adjustable as chips on the row without opening an item |
| `P0-LOG-08` | E03, E04 | Transcript shown before saving; interface stays MSA while speech input accepts Egyptian dialect |
| `P1-RULE-09` | E04 (with R07, R09, T02) | No logging action in Eat raises a confirmation dialog; every one offers a 5-second undo |

### Shared — G5 owns the Eat portion

| ID | G5's portion |
|---|---|
| `P0-LOG-09` | the meal half: logged offline, visible immediately, syncs on reconnect with **no duplicates** (deterministic ids + `arrayUnion` + absolute rollup keys) and no loss |
| `P0-FR-01` | `E09`: states what will appear, why it is empty, one smallest action; a branch of the Eat route, not a destination |
| `P0-NAV-01` | E01–E09 within 2 taps of the Eat tab root; E02 and E03 reachable in 1 tap from E01's box |
| `P0-A11Y-01` | E01–E09 mirror in Arabic; `swap_horiz`/`chevron_right` flip; kcal, grams and EGP stay Western |
| `P0-DEL-01` | the three G5 paths are removed by the deletion routine |
| `P1-RULE-03` | no consecutive-day field in any G5 document; rules deny `streak`-shaped keys |
| `P1-RULE-10` | post-MVP: `search_food_library` returns only pack `foodId`s, no invented quantity, allergens excluded server-side |
| `P1-RULE-11` | no ranking surface in Eat; plate order is her own frequency, and no cross-user query exists |

### P2 covered by G5's screens (not P0/P1, listed for completeness)

`P2-RTL-E01…E09`, `P2-TXT-E01…E09`, `P2-OFF-E01…E04`, `P2-ERR-E01…E04`.

### Gaps in the suite G5 found (requests to the Stage 1 owner, not claimed as covered)

| Proposed | Why it is missing and needed |
|---|---|
| `P1-RULE-12` | **No test exists for HANDOFF rule 3.** Logging twice on a planned meal must correct, and a second helping must be a separate item. This is exactly the rule an implementer would innocently collapse into one action |
| `P0-EAT-10` | **No test exists for the allergy conflict path** — the one safety-critical behaviour in this group. Should assert: a conflicting food never appears in suggestions; reaching it by name blocks the write behind a named sheet; a dietary preference does *not* raise a sheet |
| `P0-EAT-11` | No test for the two-devices-offline same-slot merge (§4.5). The property is worth asserting because `arrayUnion` vs. a plain array `set` is invisible in review |

---

## 9. Open questions

| # | Question | Blocking? | G5's working assumption |
|---|---|---|---|
| Q1 | **Where does the protein target (E01's "95 g") come from? Confirmed unowned.** G2's plan defines the assignment contract with no `nutrition` field, and the target needs body mass, which lives in G6's private `measurements` and must not spread. So no group currently computes it. Proposal unchanged: G2 computes it at plan publish and writes `plans/{uid}/assignments/{date}.nutrition.proteinTargetG`; G6 supplies mass to G2 without it reaching G5 | yes, for E01/E04's bar | Remote Config constant by `lifeStage`. The bar renders and fills; only its denominator is provisional |
| Q2 | **Macro authority over time.** Items freeze `kcal`/`proteinG` at log time with `libVersion`. If the library corrects a food's macros, history does not change. Confirm history is never retro-recomputed | no | freeze; never recompute |
| Q3 | **Ramadan mode**: display-only relabel (G5's assumption) vs. real extra slots; which Hijri source; and does the toggle belong in G2's `profile` or G5's `eatPrefs`? Currently in `eatPrefs` to avoid a cross-group write | no | display-only, `eatPrefs.ramadanMode`, Hijri window from Remote Config |
| Q4 | **Cloud STT for Egyptian Arabic**: vendor, PDPL data-processing agreement, consent copy, whether audio may leave Egypt, and retention. This is an owner-track item (§10), not solvable in code. It gates E03's fallback and is the single largest variable cost here | yes, for E03 tier 2 | ship tier 1 (on-device) only; `voiceCloudFallbackEnabled = false` at launch |
| Q5 | **A published assignment that conflicts with an allergy.** `W06` claims assignment is blocked. If a legacy or already-published assignment conflicts, who wins? G5 renders the row disabled with the reason and never auto-logs — confirm with G2/coach-plan | no | disable the row, offer alternatives |
| Q6 | **"Ranked by how often, with the count shown"** (E01's note). The rollup window is 28 days, so the count is "8 times this month", not lifetime. Is that the copy the owner wants, or does she expect a lifetime figure (which needs an unbounded rollup)? | no | 28-day window, copy says so |
| Q7 | **Which clock defines the day?** G5 stamps the device-local date at the moment of the *action* (not the commit) and records `tz`. Confirm with G8 whether the app pins `Africa/Cairo` or follows the device for a traveller | no | device TZ, recorded per document |
| Q8 | **E08's share action.** The app bar has a share icon. OS share sheet with generated text (no server, no link, nothing leaves the device unless she chooses) — confirm that is the intent | no | OS share sheet, plain text |
| Q9 | **E02's "All foods, 4,100 in the list".** If the full pack has not downloaded she has 1,500. The count must not lie — show what is actually loaded, or hide the count until the pack lands | no | show the loaded count |
| Q10b | **Allergy capture has no screen in the MVP — now confirmed from both sides.** G2's plan states that nothing in the cut captures `allergies`/`dietary` (the only capture surface is `G17`, a coaching screen, out of cut) and independently instructs G5 to treat them as *unknown rather than empty*, which is exactly §5.1's fail-closed behaviour. **G2 and G5 agree; the decision is the owner's.** G2 offers three homes: (a) intake, (b) G7 profile, (c) G5 captures it at first meal log. G5 supports (a) — asking at the first meal log puts a safety question in the middle of a one-tap action | **yes** — shared with G2's §9 Q1 | fail closed until a capture surface exists |
| Q10 | **`foods` schema.** The spine declares `foods` read-only but not its fields. G5 requires `allergens[]`, `dietTags[]`, `sizes[]`, `names{ar,en,franco,aliases[]}`, `kcal`, `proteinG`, `costEGP`, `verified`, `popularity`. **Without `allergens[]` the safety guard in §5.1 cannot function at all** | **yes, highest priority** | assume present; fail closed if absent |
| Q11 | **Spine C3 vs. same-slot offline merge.** C3 says "distinct slot keys merge commutatively, so two devices offline do not clobber each other" — true across slots, but `slots.<slot>` is an *array*, and a plain merge overwrites it wholesale. G5 stays inside the declared shape using `arrayUnion` plus deterministic read-time dedupe (§4.5). **Recommendation: change `slots.<slot>` to a map keyed by `itemId`**, which makes the merge exact and removes the dedupe entirely. Raised, not worked around, per the spine's §7.3 | no (mitigated) | array + `arrayUnion` + read-time dedupe |
| Q12 | **`origin` vs. the spine's `source` enum.** The screens need six provenances (`plan`, `suggestion`, `recipe`, `search`, `voice`, `nudge`); the spine's `source` enumerates three. G5 keeps `source` byte-identical to the spine and carries the finer value in a new `origin` field. Confirm that is preferred over widening `source` | no | two fields |
| Q14 | **Who owns the 5-second undo?** G3's plan claims a shared `UndoableLog`/`LogCommandBus` that G4 and G5 must both route through; G5 had specified its own `PendingLogBuffer`. G5 has conceded to G3 (§5), because one implementation of rule 9 is genuinely better than three. What still needs confirming is that G3's bus defers the *write* rather than writing-then-deleting — G5's cost model and the once-a-day points hook both depend on an undone log producing **zero** writes (§4.2) | no, but it changes G5's write cost if refused | G3's bus, deferred-write semantics |
| Q15 | **Does `usualPlates` need its own document?** G5 serves it from `eatPrefs/current`, which means G3 reading the version stamp pulls the whole 40-plate map. If T01 wants the stamp without the payload, that needs a second tiny document and a second read. G5's view: not worth it — G3 already has the document in cache from E01, or pays 1 read it was already budgeting | no | serve from `eatPrefs/current` |
| Q16 | **A 5-second undo window that is never closed.** If she force-quits inside the window, the journalled pending log commits on next launch — which means the +5 points may land the next day even though the meal document is stamped with the original date. Acceptable, or should the hook key on the document date rather than creation time? | no | commit with the original date; ask G6 to key on `dayId` |

---

## Scalability gate — self-check

| Gate | Result | Evidence |
|---|---|---|
| Unbounded collection scan | **PASS** | No `.where()`, no `.orderBy()`, no `collectionGroup` query anywhere in G5. Every access is a document `get` by a deterministic id. Frequency and history questions are answered from `eatPrefs/current`, which is capped at 40 plates × 28 days; `meals` is never queried as a set, so its size is irrelevant to read cost |
| Per-user fan-out write growing with followers | **PASS** | G5 writes only inside `users/{uid}/**` for the woman doing the logging. There is no social surface, no feed, no shared counter document, no cross-user write of any kind |
| Unindexed query on a hot path | **PASS** | There are no queries on the hot path, so nothing can be unindexed. Composite indexes required by G5: **zero**, which matches the spine §4. The only index configuration needed is three *exemptions* to stop auto-indexing map subfields (§1.3) |
| Needs a migration to reach 100k MAU | **PASS** | Growth is linear in users with no cross-user index and no global document. Per-document size is bounded regardless of tenure — the 40-plate cap and the 28-day window mean a five-year user's `eatPrefs` document is the same size as a one-month user's. `meals` documents accumulate (365/user/year) but are only ever fetched by id, so their count does not affect read cost; a 24-month TTL is optional housekeeping, not a migration. The pack is versioned by Remote Config, so a library change is a download, not a data migration |

Two scale risks that are **not** on the gate list but are named here rather than at the end:

1. **Cloud STT is the only cost line in G5 that scales with usage rather than with users** (~$420/month
   at full adoption vs. ~$19/month for everything else). It is behind a Remote Config flag for that
   reason, and tier 1 is on-device and free.
2. **Dinner sits inside the 19:00–23:00 peak**, so G5 concentrates at ~55% rather than 40%. The
   absolute number (5.5 writes/s fleet-wide, 3 writes/day on the hottest document) leaves that
   without consequence.
