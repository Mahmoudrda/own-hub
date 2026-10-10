# Phase 2 — QA verdict

**Date:** 19 September 2026
**Suite:** 1,759 tests, 0 failing · `flutter analyze lib test` clean · `dart format` clean · iOS simulator and Android debug **both build**
**P0-NAV-01:** 51/59 recurring screens within two taps — **86.4%, target met** (Z12 and Z13 both arrived reachable)
**Scope:** 174 screens across 17 flows

This is the honest state. It separates *built and proven*, *built and blocked on content or data*, and
*not covered* — and names the reason for every item in the third column. Nothing here is rounded up.

---

## 1. What was delivered

| Flow | Screens | Tests | Analyze |
|---|---|---|---|
| Progress and rewards (G6) | P01–P04 | 230 | clean |
| Profile, privacy, safety (G7) | A01–A04 | 150 | clean |
| My cycle (G9) | Y01–Y13 | 143 | clean |
| Admin content console (G16, D12, D18) | Z01–Z13 | 331 | clean |

All are wired into `AppRouter._built` and reachable in the running app. **D12 is served both ways for
every collection**: in bulk through Z08/Z09's dry-run import, and one at a time through Z03 and Z05 for
exercises and foods, and — since D18 — through **Z12 and Z13** for recipes and programmes, which
previously could be authored by CSV only.

The library no longer starts empty: 56 seeded rows (20 foods, 23 exercises, 9 recipes, 4 programmes),
every one of which is proven to survive the *real* `parseCsv` + `validateImport` rather than a
restatement of their rules.

## 2. Defects found, and how

**Six were found by looking at the app while the suite was green.** That is the most important line in
this document.

| Defect | Found by | Suite at the time |
|---|---|---|
| **Y03 rendered a blank screen** for a woman who had not set up | screenshot | 115 cycle tests green |
| **T01 showed a cycle card** to a woman who had declined the feature | screenshot + review | green, with a test *asserting* the wrong behaviour |
| **E01 reported boiled eggs as 540 kcal** — koshari's figure, via a `_ =>` default | screenshot | green; one test documented the defect and worked around it |
| **Home told everyone "Level 7 · Regular"** while P01 correctly showed no tier | screenshot | green, test pinned the constant |
| **P04's measurement chips overflowed by 66px** at phone width | rendered test | would have clipped on a real handset |
| **`RestWeekRepair` repaired the wrong weeks** — the oldest missed week spent the bank first | reading the mechanic | green |

Found by reading rather than running:

* **`allow create` on `users/{uid}` could never have succeeded.** `resource` is null on a create, so the
  invariants errored and denied the first write the app ever makes.
* **The deletion manifest omitted `cycle`, `periods` and `splits`** — three collections that would have
  survived account deletion, including the most sensitive data in the product.
* **Seven of G9's nine index exemptions were missing**, including `periods.stillBleeding` — a boolean
  true for exactly the women currently bleeding, auto-indexed and queryable across every user.
* **`consents`, `notices` and `firstWeek` had no rules at all**, so all three were denied in both
  directions. For `consents` that blocked her PDPL right of access, not merely writes.
* **`AppField.textDirection` was declared and never passed to the `TextField`** — inert for every caller,
  including the phone field its own doc comment cites.
* **Z05 authored foods its own importer refused.** `carbsG`/`fatG` are required and had no label, so the
  fields were not drawn and every food went out incomplete.
* **The content console could add a row and could not open one.** `CollectionView.onOpenRow` fires on
  every row tap and **no route builder passed it**, so `_isEditing` could never be true and "Edit a
  food" was a string with no path to it. 331 admin tests were green, because every one of them built
  the screen directly and handed it rows it had made itself.
* **`WorkoutDay.id` carried the mockup slug `day-2`** into every session's `dateKey`. P03 sorts bests
  by that string, and `'d' > '2'`, so each best she set in the running app would have pinned itself
  above every real dated one, permanently, with nothing throwing.
* **The exercise CSV template staff are handed disagreed with the validator** — `dumbbell` where the
  enum says `dumbbells`, and `knee_pain`, which is not in the contraindication vocabulary at all. A
  blank safety tag fails closed and is caught; a **misspelt** one fails open and is not.
* **`PersonalBestDetector` had no caller in `lib/`.** `bestsCount` could never rise, so three of the
  five tiers were unreachable however long she trained.

Four latent bugs surfaced while wiring the cycle check-in, the sharpest being that every row rebuilt the
draft from three fields, **silently dropping** sleep/bloating/bleeding — harmless until bleeding became
loggable, at which point a later tap would have cleared `bleeding == heavy` and taken the suppression
with it.

**One was found by a negative control, which is worth its own line.** Wiring the row-edit journey created
a fresh defect: `adminEditingRow` is shared module state cleared only by the form's close button, so
leaving by the system back gesture and then tapping **Add** opened a form pre-filled with the row last
viewed — in whichever collection she was now in. The test that caught it existed to stop the edit
assertions passing over a form that said "Edit" regardless. It earned its place by failing for an
entirely different reason than the one it was written for.

## 3. Not covered — and why

| Case | Status | Reason |
|---|---|---|
| `P0-DEL-01` end to end | **NOT COVERED** | `firebase.json` now exists, but the Firestore emulator is a **Java process and this machine has no JDK**. The deletion Cloud Function does not exist either |
| Any Firestore rules *behaviour* | **NOT COVERED** | Same. Rules are asserted as text, which cannot prove a single allow or deny |
| `P0-CYC-07` / `P0-CYC-08` route to care | **NOT COVERED** | No Egyptian clinical source and no named reviewer. `CareDirectory.bundled` is null rather than invented |
| `P0-CYC-18` cycle-aware meals | **NOT COVERED** | G5's `EatSuggestionRanker.rank({SymptomContext})` does not exist |
| `P0-A11Y-01` on device | **PARTIAL** | Widget-tested under `ar` at 1.6× with Eastern-digit scans; not run on a simulator, so per `README.md` it is untested |
| Persistence, anywhere | **NOT COVERED** | There is no writer in this repo. Z03/Z05 and the import commit all emit rather than write |
| Media upload | **NOT COVERED** | No `file_picker` dependency; `onUpload` is a callback. Content-only **export** is built and proven |

## 4. Blocked on content or data, not on code

Roughly 70 strings were minted this phase, which lit up P04's measurement control, Y04's sleep/bloating/
bleeding rows, Z03 and Z05, and most of Z01/Z08/Z09/Z10/Z11. What remains blocked splits in two, and the
distinction matters:

**Blocked on copy** — a string away from working: recipe and programme forms (`Portions`, `Ingredients`,
`Weeks`…), Z09's per-row reasons, Z10's size unit, Y08's month names, P03's detail lines.

**Blocked on DATA** — the string exists and there is nothing to put in it:

* `week3Of8` → `WorkoutCard` receives no programme week, and `TodayDay` carries none.
* `walkThisMorning32Min` → `walkToCount` is a **bool**; minutes need HealthKit or Google Fit.
* `n410Kcal`/`n290Kcal` → `MealCard`'s plates are hardcoded; it receives no meal data.

`test/baked_in_samples_test.dart` counts every rendered string stating a figure with no placeholder form
and **ratchets it at 160 so it can only fall**. Six such defects were found by accident before it existed.

## 5. Decisions the owner still has to make

**All five that stood here are settled.** The owner answered them on 19 September and they are recorded
as D13–D20 in `DECISIONS.md`: the cycle sharing grant is hers and revocable (D13); the tier ladder is
authored and counts weeks and lifts, never bodyweight (D14); the NHS citations are signed off pending an
Egyptian source (D15); planned rest caps at two per week (D16); the week follows the phone she is holding
(D17); and recipes and programmes are authored both one at a time and in bulk (D18).

**One new decision has taken their place, and it blocks a screen that already ships.**

`weekly_goal.dart` says — citing G6 §6 — that `sessionsTarget`, `tz` and `goalKind` are hers to write. The
deployed rules forbid all three, twice over: `rewardsUntouched()` blocks anything touching `weeklyGoal`,
and `users/{uid}`'s update allows only `profile`/`privacy`/`notify`/`updatedAt`. So **T05's one-tap goal
change would be denied by the server**, and a goal she can meet beats a goal she abandons.

Either G6 is right and the rule needs a narrow widening that admits those three keys and no counter, or
the rules are right and changing a target is a Cloud Function — in which case the comment in
`weekly_goal.dart` should be corrected so nobody else builds against a permission that is not there.

It was not resolved here on purpose. Widening a rule is a security change, and **no rule in this project
has ever been executed**, so the widened version could not be proven to deny what it should. Written up
as `OPEN-QUESTIONS.md` B4 with the concrete change ready.

## 6. What would raise confidence most, in order

1. **A JDK and a Firebase project.** Every rules case, `P0-DEL-01` and the index exemptions are
   unprovable without them. `HOW-TO-RUN.md` §6b has the exact commands.
2. **A persistence layer.** Three finished surfaces emit rows that nothing writes.
3. **The authored content** — tier thresholds, the four remaining milestones, `foods.allergens[]`.
4. **Device runs for `P0-A11Y-01`.**
