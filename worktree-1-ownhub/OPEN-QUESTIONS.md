# Everything waiting on you, to close Phase 1 and 2

**19 September 2026.** Nothing here is a bug. Each item is a place where the code is built and tested
and something was **withheld rather than invented** — a decision, an install, or content nobody has
authored.

**Section A is now closed.** You answered all eight on 19 September; what follows records each answer,
what I built from it, and where it lives, so nobody re-opens a settled decision. Sections B and C are
still open, and both are genuinely yours — an install and content nobody has written.

The code state, for context: 1,626 tests passing, `flutter analyze` clean, iOS and Android both
building, P0-NAV-01 met at 86% (49 of 57).

---

## A. Decisions — settled by you, 19 September 2026

### A1 → D13. The cycle sharing grant is hers, and she can change her mind
> *"she consents and share her data and she should be able to update it later"*

Settled in G9's favour: `sharing{}` lives on `cycle/current`, written by Y12, and **is editable after the
fact**. The second half of your sentence is the load-bearing half — a consent record you cannot withdraw
is not consent — so revocation is a first-class path, not a support ticket.

### A2 → D14. The tier ladder is authored, and it counts the barbell
> *"each tier should be based on the gym logs weights lifted and this should be shown to everyone…
> you think about the threshold for each tier for women"*

Five rungs, in `TierPolicy.shipped`:

| Tier | Counted weeks | Personal bests | Recency floor (of 8) |
|---|---|---|---|
| First steps | 1 | 0 | 0 |
| Showing up | 4 | 0 | 2 |
| Regular | 12 | 3 | 4 |
| Strong | 26 | 8 | 5 |
| Unshakeable | 52 | 15 | 6 |

**Why this does not break rule 11.** Rule 11 forbids ranking women by body weight, weight lost or
followers. A tier counts **weeks she showed up and lifts she beat** — `loadKg` is the dumbbell, and
cannot be mistaken for the woman. Nothing here reads her bodyweight, and a heavier woman and a lighter
one reach Strong by the same route.

The thresholds are mine, as you asked, and they are conservative on purpose: Unshakeable takes a year,
so it means something, and First steps arrives after **one** counted week so nobody stares at an empty
shelf. Changing any number is a one-line edit with no code change — the guard test asserts the *shape*
(five rungs, thresholds only rise, first tier unfallable, no bodyweight field), not the values.

### A3 → D15. NHS guidance stands, signed off
> *"i will provide the resources later make it as done for now or consider it signed off"*

Taken as your explicit sign-off, and recorded as such. Y05/Y11 keep the NHS copy. When you send the
Egyptian source it is a content swap, not a code change. **This remains the highest-liability copy in
the app**, and it is now signed off by name rather than by silence.

### A4 → D16. Planned rest is capped at 2 per week
> *"yes one or 2 weeks max"*

Read as **up to two**, so `markPlannedRest` caps at 2 in any one week. I took the more generous reading
because the failure modes are asymmetric: a cap that is too tight makes an honest rest look like a miss,
and a cap that is too loose costs nothing this product measures. It is one constant if you meant one.

### A5 → D17. The week follows the phone she is holding
> *"the application should be used internationally so the day should be based on the user location from
> the phone timezone should be respected"*

Already true of the boundary — `WeekKey.of` reads local calendar fields and **nothing in the app calls
`toUtc()`** — but nothing stated it and no test held it. Now `WeekKey.current()` says so, and a test
fails the moment anyone "fixes" it by converting to UTC first, which is the edit that would misfile the
Gulf diaspora by a whole week.

One deliberate exception: a **closed** week keeps the boundary it was closed under, so flying Cairo→Dubai
never re-files last month's sessions. New weeks follow her phone; history stays where it was earned.

### A6 → D18. Both — one at a time *and* in bulk
> *"both once at a time or bulk exports should be options"*

Two new screens, **Z12 (edit a recipe)** and **Z13 (edit a programme)**, reachable from Z06/Z07, beside
the CSV importer that already exists. Recipes and programmes are no longer import-only.

### A7 → D19. Both schema additions ratified
> *"don't understand just fix it and make sure it is working"*

Fair — this one was mine to decide, not yours. Both are in:
* **`weeklyGoal.restWeekProgress`** (int 0–3), kept as its own counter because deriving it from
  `countedWeeks` would let a repaired week fund the next repair.
* **`actualHoldSec`** on `measuredSets`, so P03's plank branch has something to render.

### A8 → D20. All four smaller calls confirmed as I made them
> *"agree"*

Logged days for Y10's caption; no third sleep word; `dietTags` required but not a safety tag; `{n} rows`
accepted without ICU plurals.

### A9. Content — use the researched data, swap later
> *"for the content use the data you planned and searched for now and i will update the content later"*

Applied to the seed library. Section C below still lists what is **not** covered by it, because seeded
placeholder data must never be mistaken for authored clinical content — particularly allergens and
contraindications, where a wrong value is a safety failure, not a cosmetic one.

---

## B. Installs and dependencies — only you can do these

### B1. A JDK — **the single largest verification gap**
`firebase.json` now exists and points at the rules and indexes. It cannot start: the Firestore emulator
is a **Java process and this machine has no Java runtime**. The consequence is blunt — **no security
rule in this project has ever been executed.** They are asserted as text, which can prove a line is
present and cannot prove it allows or denies anything.

```bash
brew install --cask temurin      # any JDK 11+
npm install -g firebase-tools
firebase emulators:start --project demo-own-hub   # demo- needs no real project
```

### B2. Cloud Functions — `functions/` does not exist
Three are specified and none is written: the **account-deletion callable** (`P0-DEL-01` is NOT COVERED
without it), the notification writer, and `getCycleProjection`. Every repository in the app is in-memory
today; **nothing persists across a restart.**

### B3. Two pubspec dependencies for content management
* **`file_picker` or `image_picker`** — without one, no CSV can be chosen and **no video or image can be
  uploaded**. A seam with an honest "unavailable" implementation is being built so the buttons never
  silently do nothing, but real picking needs the package.
* **`archive`** — for the export **bundle**. Today the export produces a file list and CSV bytes with no
  way to zip or download them. Version 3.6.1 is already in your local pub cache, so this one may not
  even need network.

### B4. A contradiction between the spec and the rules — needs your call, and the emulator

**New, 19 September. This one blocks a screen that already ships.**

`weekly_goal.dart` says — citing G6 §6 item 3 — that three fields are hers to write: `sessionsTarget`,
`tz`, `goalKind`. The deployed rules forbid all three, twice over (`rewardsUntouched()` blocks anything
touching `weeklyGoal`, and `users/{uid}`'s update allows only `profile`/`privacy`/`notify`/`updatedAt`).

**Consequence:** T05 offers her a one-tap way to shrink this week's goal, and the server would reject it.

**Which is wrong is your call:**

* **If G6 is right** — she owns her target — the rule needs a narrow widening: admit a `weeklyGoal` diff
  that touches only those three keys, with `sessionsTarget` held to 2–4, and **no counter reachable**.
* **If the rules are right** — nothing about the goal document is client-writable — then changing a
  target is a Cloud Function, and `weekly_goal.dart`'s comment should be corrected so the next person
  does not build against a permission that does not exist.

I did not pick one. Widening a rule is a security change, and **no rule in this project has ever been
executed** (B1) — so I could not prove the widened version denies what it should. The riskiest part is
the create path, where `resource` is null; that is exactly where this repo already had a rule that could
never have succeeded.

Do B1 first and this becomes one reviewed change with a test behind it.

---

---

## C. Content nobody has authored

These are why several screens show less than the mockups. In each case the app withholds rather than
invents.

**Updated 19 September — D20 seeded the library, and that moved several of these rather than closing
them.** 56 rows now ship (20 foods, 23 exercises, 9 recipes, 4 programmes), every one proven to survive
the real importer. But seeding the **admin** store did not feed the **member-facing** features, and it
is important not to read the counts as safety.

| Content | What it blocks |
|---|---|
| **`foods.allergens[]` reaching Eat** | Seeded foods now carry allergens — but **no `ImportRow` → `Food` adapter exists in `lib/`**, `eat_sample_library.dart` still ships `allergens: null` on all 8 sample foods, and `eatConstraints` is still pinned to `DietaryConstraints.none` because there is no allergy capture surface. `AllergyGuard` is built and correct; it still protects nobody. **`P0-EAT-01` still cannot pass** — the blocker moved from "unwritten" to "not carried across" |
| **`exercises.contraindicationTags` being read** | 23 seeded exercises carry G14 §1.5 tags. **`ExerciseCandidateFilter` does not exist anywhere in `lib/`** — the filter is not inert for want of tags, it is unbuilt. The tags are ready for it |
| **The 124-move exercise library** | 23 of 124 seeded, and they are **researched placeholders under D20, not the founder's library**. Train's "124 videos" still counts content that does not exist. Every media column is blank, because no video or image has been uploaded and the importer refuses a row naming an absent file |
| **4 of 12 milestones** | The catalogue holds 8; P02's "Twelve in all" heading checks itself against the real count and therefore does not draw |
| **An Egyptian clinical source + named reviewer** | Y11's route to care. `CareDirectory.bundled` is null; `P0-CYC-07/08` are NOT COVERED |
| **Month names beyond June and September** | Y08's calendar falls back to `2027-04`; P03's milestone dates do not render |
| **Exercise names for 120 of 124 moves** | The library browse list |

---

## D. What is NOT on you

So the division is clear — I am continuing with all of this and none of it needs your input:

* ~~Wiring the content repository so the console actually stores what it is given.~~ **Done** — and it
  now ships seeded, and a stored row can be opened and edited, which it could not before.
* The remaining admin prose: empty-state paragraphs, Z09's per-row reasons, the Z08 note.
* The 160 counted "mockup number" strings **where the data exists** to replace them. A large share do
  not — Home's week badge, the walk minutes and the meal-card calories each need a data source that
  does not exist yet (`TodayDay` carries no programme week; `walkToCount` is a bool; `MealCard` gets no
  meal data). Those need plumbing, and for the walk, a HealthKit/Google Fit integration.
* Moving `weightLabel` into `lib/domain/format/` beside `countLabel`.
