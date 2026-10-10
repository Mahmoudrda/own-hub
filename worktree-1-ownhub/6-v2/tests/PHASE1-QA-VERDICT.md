# QA verdict — Phase 1 and Phase 2 Flow 1 (Eat)

Independent QA pass, 2026-09-18, against `PHASE1-ACCEPTANCE.md` (32 cases) and the Eat
section of `PHASE2-ACCEPTANCE.md` (6 cases). Supersedes the 11:16 `PHASE1-QA-REPORT.md`,
which predates twelve fixes.

**Verified true:** `flutter analyze` clean · `flutter test` 772 passing, 0 failing · 48
screens with real builders, the rest rendering `NotBuiltYet`.

## Verdict

**Phase 1: not done. Eat: not done.**

| | PASS | FAIL | NOT COVERED |
|---|---|---|---|
| Phase 1 (32) | 22 | 2 | 8 |
| Eat (6) | 3 | 1 | 2 |

---

## D1 — the blocking defect: four screens state the prototype's numbers as her facts

**This is the third occurrence of a defect class already fixed twice** — C13's invented
"74 seconds" (fix #3) and R07's fixed "Done — 12 kg × 10" (fix #8).

`eat_view.dart:382–386` renders her calorie and protein totals from fixed dictionary
constants, switching on **whether a log just happened** rather than on what she ate:

```dart
proteinLabel: justLogged == null ? l10n.n22Of95G : l10n.n53Of95G,
kcalLabel:    justLogged == null ? l10n.about410KcalSoFarToday
                                 : l10n.about1106KcalSoFarToday,
```

Meanwhile `eat_widgets.dart:192` fills the bar from `totals.proteinPercent` — the real
computed value. **The bar and the sentence beside it come from different sources and
disagree for every woman.** She logs a 460 kcal molokhia and reads "About 1,106 kcal so
far today".

Same shape, Phase 1:

| Screen | What it states as fact |
|---|---|
| `today_view.dart:206–208` | week sentence picked by `sessionsLogged == 0` while the ring uses her real target — a woman whose goal is 4 reads "0 of 3" |
| `quiet_week_view.dart:116,156` | "Your 14 weeks are safe" — T04 accepts no week count |
| `tier_slip_view.dart:169–171` | "Your 14 counted weeks", "Level 7 and every point" — **contradicts D6**, which says no tier number is authoritative |

**The parameterised strings already exist** and are simply unused:
`l10n.sofarOfTargetG(soFar, target)`, `l10n.aboutKcalKcalSoFarToday(kcal)`,
`l10n.gramsG(grams)`. The Eat flow was built before they were minted.

---

## Tests judged vacuous

The highest-value section of the report.

1. **`eat_view_test.dart:227`** — "there is no calorie countdown anywhere on the screen"
   asserts `textContaining('so far today')`, which passes identically for a hardcoded
   constant. **This is the test that should have caught D1 and structurally cannot.**
2. **`day_totals_test.dart:44`** — hand-feeds `kcalSoFar: 1106` and asserts it reads back
   as `1106`, using the mockup's own sample number, so it reads as though it validates
   E04's figure.
3. **`selectStartingProgram` is entirely unexecuted** — no test passes a catalogue with
   more than one entry, so every branch of the scoring function is dead in the suite. O05
   looks driven by her four answers and, with a one-entry catalogue, cannot be.
4. **Rule 11's guard is weaker than its name** — it catches `orderBy(...weight...)` but not
   `..sort((a, b) => a.weightKg.compareTo(b.weightKg))`. The rule is really protected by
   spine C7's missing index, not by this scan.
5. **Rule 7 has no source guard at all.** Rules 3, 8, 9 and 11 each get an executable
   source scan; rule 7 gets copy assertions on three screens. Nothing stops someone adding
   `String? idPhotoUrl` to `VerificationResult` with the suite fully green. **The most
   valuable missing guard in the codebase**, and it protects the promise the product
   restates at the moment it is most believed.

---

## The eight NOT COVERED

`P1-RULE-07`, `P0-ONB-01`, `P0-ONB-02`, `P0-RWD-02`, `P0-VER-01`, `P0-VER-02`,
`P0-VER-03`, `P0-VER-07`.

Two of these are **unimplemented, not merely untested**: `publishStartingPlan` exists only
as a TODO in a doc comment, and there is no `DailyCap` or `AwardLedger` anywhere in `lib/`.

---

## D3 — the allergy ordering hazard

`app_router.dart:567` sets `eatConstraints = DietaryConstraints.none`, which means
`allergies: {}` — "asked and named nothing". `allergy_guard.dart:191` short-circuits on
it: `if (allergies.isEmpty) return AllergyAssessment.clear`.

**Today the risk is contained** — no food carries allergens, so neither `none` nor
`unknown` is informative.

**The hazard is ordering.** The moment `foods.allergens[]` lands — D12's admin console is
the mechanism, and it is on the critical path — but *before* a capture screen exists, the
guard has real allergen data plus a fabricated claim that she has no allergies. It will
**clear a dish containing nuts for a woman with a nut allergy, silently, with no sheet.**
That is worse than today and worse than `unknown`, because the guard now looks live.

**Mitigation, cheap and self-expiring:** a test that fails the moment any `Food` in the
shipped pack has non-null `allergens` while `eatConstraints` is still `none`. Same
technique as `_awaitingInboundScreen` in `nav_reachability_test.dart`.

---

## P0-NAV-01 — judged honest, with a caveat

QA's words: honest engineering, not a dodge — "a dodge would have been
`_measuredFloor = 79.2`". The number is measured from the router's own graph, printed on
every run, found three real defects (63% → 79.2%), and its exclusions expire by themselves
with tests proving the expiry.

**The caveat stands:** the gap is 0.8 points over a population of 24, so a single screen
decides it. QA endorses option 1 in `DECISIONS.md` — measure **destinations**, not steps
she is carried through. "Resting" is not a destination and no design should make it one.

---

## What QA judged genuinely good

`P0-LOG-11` and `P0-LOG-10`'s domain tests — particularly pinning the *fake's* strictness
so a case cannot pass in memory and fail on a phone. `AllergyGuard` fails closed on all
three unknowns. The nav test's self-expiring exemptions are a pattern worth reusing. And
the decision not to invent a single allergen tag — with a deliberately-passing test that
states a failure — was the right call made for the right reason.
