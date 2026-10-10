# UI/UX review — pass 2

Measured against the built source at `/Users/mahmoudreda/womens-fitness-app-wireframe/6-v2/src/`, 146 screens
across 15 flows. Navigation was extracted from `data-go` attributes via `linkReport()` and measured with
breadth-first search from the tab roots. Every finding below is anchored to a screen ID and a file:line.

---

## Verdict

The logging design is the best thing in this product and it delivers on its promise: a set is one tap, a
whole move is one tap, a session trained without the phone is two, a usual meal is one. That part is ready.

The coach side is not. It contains **two parallel coach applications** that were built at different times
and never reconciled — the `coach` flow (K07–K18) and the `coachplan` flow (W01–W10) implement the same four
jobs with different screens, and the coach's own Today screen routes two identical-looking rows into two
different check-in reviewers. On top of that, the owner's suspicion is correct on both counts: **training
splits do not exist as a first-class concept anywhere in the product**, and **assessments are entirely
absent** — no intake owned by the coach, no movement screening, no health history, no re-assessment. For a
product whose flagship specialty is postpartum training, the second gap is a safety gap, not a feature gap.

"Everything is 2 clicks away" is true for about two thirds of the app, not all of it, and the misses cluster
in exactly the places that matter commercially: the recipe library (unreachable from its own tab), Groups,
and the coach's plan and portfolio builders.

Four screens are unreachable from any tab root in the shipped graph: K12, K13, T04, T05.

---

## Tap-depth measurement

**Method.** Multi-source BFS from the tab roots of each role — client roots T01, R01, M01, E01, H01, H05;
coach roots K07, K10, K15, K17 — over the `outgoing` adjacency from `linkReport()`. Depth 0 is a tab root.
Because the bottom nav is present on every screen that renders `navBar()`, reaching another root costs 1 tap,
so "minimum taps from the nearest in-role root" is the correct measure of "how far away is this from
wherever she is". Script: `/Users/mahmoudreda/.claude/jobs/9eda914b/tmp/tapdepth.mjs`.

### Raw distribution, all 146 screens

| Depth | Screens |
|---|---|
| 0 (tab root) | 10 |
| 1 | 32 |
| 2 | 38 |
| 3 | 27 |
| 4 | 4 |
| 5 | 2 |
| 6 | 2 |
| Unreachable from any in-role root | 31 |

### The fair reading

27 of the 31 unreachable screens are legitimately pre-navigation one-time flows that exist before a tab bar
is ever drawn: sign-up (C01–C16, 16 screens), client setup (O01–O05, 5) and coach setup (K01–K06, 6).
Three more — G01, G02, G03 — are a one-time post-purchase intake wizard, reached by completing payment at
H04, and counting them against a 2-tap rule is unfair for the same reason.

Excluding those 30 one-time screens leaves **116 recurring in-app screens**:

| | Count | Share |
|---|---|---|
| Within 2 taps of a tab root | **80** | **69%** |
| 3 taps | 27 | 23% |
| 4+ taps | 5 | 4% |
| Unreachable | 4 | 3% |

**Answer to the owner's question: "everything is 2 clicks away" currently holds for 69% of the app.**

### Unreachable in-app (the real defects)

| Screen | Title | Why |
|---|---|---|
| K12 | Workout plan builder | Only inbound edge is K06 (coach setup step 6). No coach tab reaches it. |
| K13 | Pick a move | Only reachable from K12. |
| T04 | After a quiet week | No inbound edge at all. Monday scenario screen. |
| T05 | When a tier slips | No inbound edge at all. Monday scenario screen. |

T04/T05 were deliberately left as scenario screens in pass 1 and are reachable in the prototype viewer's
chapter index (`build-prototype.mjs:231`), which is a mockup affordance, not in-app navigation. K12/K13 are
a genuine defect — see BLOCKER 1 and MAJOR 7.

### Every screen at depth 3 or more

| Depth | ID | Title | Shortest path |
|---|---|---|---|
| 6 | E08 | Grocery list | T01→Y03→Y07→E06→E05→E07→E08 |
| 6 | G03 | Preparing your plan | H01→H02→H03→H04→G01→G02→G03 |
| 5 | E07 | Week plan | T01→Y03→Y07→E06→E05→E07 |
| 5 | G02 | Support and sharing | H01→H02→H03→H04→G01→G02 |
| 4 | E05 | Recipes | T01→Y03→Y07→E06→E05 |
| 4 | G01 | Coaching intake | H01→H02→H03→H04→G01 |
| 4 | M04 | Groups | T01→A01→M06→M05→M04 |
| 4 | Y02 | Dates and preferences | T01→Y03→Y12→Y01→Y02 |
| 3 | A03 | Privacy | T01→A01→A02→A03 |
| 3 | A04 | Safety Centre | T01→A01→A02→A04 |
| 3 | B03 | Add a section | K07→B01→B02→B03 |
| 3 | B04 | Edit the cover | K07→B01→B02→B04 |
| 3 | B05 | Your look | K07→B01→B02→B05 |
| 3 | B07 | How I work | K07→B01→B02→B07 |
| 3 | B11 | Publish | K07→B01→B10→B11 |
| 3 | B13 | Your media | K07→B01→B02→B13 |
| 3 | E06 | Recipe | T01→Y03→Y07→E06 |
| 3 | G09 | Session done | T01→G06→G07→G09 |
| 3 | G15 | Voice note | T01→G06→G14→G15 |
| 3 | G16 | When coaching ends | H05→G04→G05→G16 |
| 3 | H04 | Pay | H01→H02→H03→H04 |
| 3 | M05 | Group | T01→A01→M06→M05 |
| 3 | R05 | Swap a move | R01→R03→R04→R05 |
| 3 | R08 | Change a set | R01→R03→R07→R08 |
| 3 | R09 | Resting | R01→R03→R07→R09 |
| 3 | W04 | Edit a session | K07→W09→W03→W04 |
| 3 | W05 | Copy a week | K07→W09→W03→W05 |
| 3 | W07 | Create a meal | K07→W09→W06→W07 |
| 3 | W08 | Publish the plan | K07→W09→W03→W08 |
| 3 | W10 | Coach inbox | K07→W09→W01→W10 |
| 3 | Y01 | Set up My cycle | T01→Y03→Y12→Y01 |
| 3 | Y09 | Log a period | T01→Y03→Y08→Y09 |
| 3 | Y11 | When it is severe | T01→Y03→Y04→Y11 |
| 3 | Y13 | About cycle phases | T01→Y03→Y08→Y13 |
| 3 | Y14 | Symptom-only mode | T01→Y03→Y12→Y14 |

Several depth-3 entries are correct by design and should not be "fixed": R08 and R09 are mid-workout states
you arrive at by training, not by navigating; G09 and G15 likewise. The ones that represent real burial are
E05–E08, M04/M05, Y01/Y02, and the coach builders W04–W08 and B03–B13.

### One-way corridors

81 of 146 screens render no bottom nav bar. That is mostly correct — wizards, sheets and canvases should
trap focus. But it means 39 screens at depth ≥2 have no 1-tap route back to a root, and 15 of those are on
the coach side (B02–B13, W03–W08, K14). A coach three levels into the page builder must tap Back three times
to answer a waiting client. See MINOR 14.

---

## Journey traces

Counts are taps from the stated starting point. "From anywhere" adds 1 for the tab hop.

### Logging — client

| Journey | Trace | Taps |
|---|---|---|
| Log one set mid-workout (coached) | T01 → *Start — everything's ready* → G06 → *Complete set 2* | **2** |
| Log one set mid-workout (self-guided) | R01 → R03 → *Start* → R07 → *Done — 12 kg × 10* | **4** |
| Each subsequent set | R09 → *I'm ready, next set* → R07 → *Done* | **2** |
| Log a whole move | R07 → *I did all 3 sets — log them* | **1** ⚠ lands on R10, see MAJOR 12 |
| Session trained without the phone | T01 → *I already did it* → T02 → *Save* | **2** ✅ meets the promise |
| Log a usual meal (from Home) | T01 → tap a plate on the meal card → E04 | **1** ✅ |
| Log a usual meal (from Eat) | E01 → *Log* on a meal row → E04 | **1** ✅ |
| Log a meal by typing | E01 → box → E02 → *Log both — 696 kcal* → E04 | **2** |
| Log a meal by voice | E01 → box → E02 → mic → E03 → *That's right* → E04 | **3** ⚠ see MINOR 20 |
| Log a planned meal from a coach plan | G04 → *Log* → G10 → *Ate this* → G11 | **2** ✅ |

The set-logging path is genuinely excellent: `R07` (screens-train.mjs:107) states the value on the button
itself — `bigBtn('Done — 12 kg × 10', 'Rest starts itself')` — so confirming and logging are one action, and
`R09` (screens-train.mjs:126) carries a 5-second undo inside the confirmation with no dialog. This is the
settled logging rule implemented exactly as written.

### Coach — portfolio

| Journey | Trace | Taps |
|---|---|---|
| Open portfolio | K07 → B01 | **1** |
| Edit a section's content | K07 → B01 → *Design it* → B02 → block → B04/B06/B07 | **3** |
| Restyle the whole page | B01 → B02 → *Your look* → B05 | **3** from root |
| Preview as a client | K07 → B01 → *Preview* → B10 | **2** |
| Publish it | B02 → *Publish* → B11 → *Publish version 4* → B12 | **2** from B02 |
| Design an ad | K07 → B01 → B09 | **2** ⚠ its *Share* goes to B11, see MAJOR 8 |

### Coach — plans

| Journey | Trace | Taps |
|---|---|---|
| Open a client's 30-day workout planner | K10 → K11 → W03 | **2** (crosses K→W systems) |
| Build a workout week | K07 → W09 → W03 → *Add workout* → W04 → *Save to Tuesday* | **4** |
| Copy a week | W03 → *Copy this week* → W05 → *Copy and replace those 2 days* | **2** from W03 |
| Build a 30-day meal plan | K07 → W09 → W06 | **2** |
| Create a meal | W06 → *Create meal* → W07 → *Save to my meals and assign* | **2** from W06 |
| Publish a plan | W03 → *Preview and publish* → W08 → *Publish plan* | **2** from W03 |
| Answer a check-in (route A) | K07 → W09 → *Save feedback and publish changes* | **2** |
| Answer a check-in (route B) | K07 → K08 → *Send reply and plan change* | **2** ⚠ two different screens for one job |
| Adjust a client's plan | W09 → *Adjust workouts* → W03 → W04 → save | **4** |
| **Create a training split** | — | **does not exist** |
| **Run a client assessment** | — | **does not exist** |

### Client — buying coaching

| Journey | Trace | Taps |
|---|---|---|
| Find a coach → see offers → pay | H01 → H02 → *See her packages* → H03 → *Continue* → H04 → *Pay 1,800 EGP* | **4** ✅ |
| Then: intake | → G01 → G02 → G03 | +3, one-time |

This journey is clean and well-judged. `H02` puts the verified-certificates card above the sales copy
(screens-coaching.mjs:34) and `H04` states the refund promise *before* payment (screens-coaching.mjs:65).

---

## Capability coverage

| # | Owner requirement | Status | Evidence |
|---|---|---|---|
| 1 | Everything 2 clicks away | **Partial** | 80 of 116 recurring screens (69%) at ≤2 taps. 32 at ≥3. 4 unreachable (K12, K13, T04, T05). |
| 2 | Logs as easy as possible | **Present** | Set 1 tap (R07, screens-train.mjs:107); whole move 1 tap (same line); session without phone 2 taps (T02, screens-today.mjs:42); usual meal 1 tap (T01/E01); planned meal 2 taps (G10→G11). Undo-not-confirm honoured at R09:126, E04:71, G11:176. |
| 3 | Coaches create their portfolio easily | **Present** | 13 screens B01–B13, depth 1 from K07. Blocks are chosen and ordered (B02), 12 section types (B03), her own look with contrast validation (B05), real client preview (B10), versioned publish with rollback (B11), insights (B12). Genuinely strong. |
| 4 | Coaches create their program and offers | **Partial** | Offers exist but are authored in three unreconciled places (K04, B06, K18:192). "Program" exists only as a per-client 30-day calendar (W03/W04) — there is no reusable program object, and the copy promising "start from a template" (screens-coach.mjs:46, :119, :210) has no template picker behind it. |
| 5a | Coaches design meal plans | **Present** (duplicated) | W06 30-day meal planner + W07 create-a-meal, with allergies pinned on screen (W06:83) and no invented nutrition totals (W07:100). But K14 is a second, incompatible meal builder and K11:105 links to it. |
| 5b | Coaches design **splits** | **Absent** | No split object anywhere. See BLOCKER 2. |
| 5c | Coaches design **assessments** | **Absent** | No assessment anywhere. See BLOCKER 3. |

---

## Findings

### BLOCKER 1 — Two parallel coach applications ship side by side

The `coach` flow and the `coachplan` flow implement the same four jobs with different screens, and they are
cross-wired, so a coach meets both in one session without any signal that they are different systems.

| Job | K-flow screen | W-flow screen |
|---|---|---|
| Client list | K10 `Clients` (screens-coach.mjs:86) | W01 `Clients and queue` (screens-coachplan.mjs:13) |
| Client detail | K11 `Client` (screens-coach.mjs:98) | W02 `Client overview` (screens-coachplan.mjs:26) |
| Check-in review | K08 (screens-coach.mjs:65) | W09 `Review and adjust` (screens-coachplan.mjs:115) |
| Workout builder | K12/K13 (screens-coach.mjs:110, :123) | W03/W04 (screens-coachplan.mjs:41, :53) |
| Meal builder | K14 (screens-coach.mjs:135) | W06/W07 (screens-coachplan.mjs:79, :91) |
| Message threads | K15/K16 (screens-coach.mjs:148, :159) | W10 `Coach inbox` (screens-coachplan.mjs:127) |

The cross-wiring is the damaging part:

- **K07 routes two identical-looking rows to two different reviewers.** screens-coach.mjs:55 sends
  "Nour Adel · Review due" to `W09`; screens-coach.mjs:56 sends "Sara Adel · Check-in" to `K08`. Same list,
  same job, one tap apart, two different screens with different reply mechanics.
- **K11 splits one client across both systems.** screens-coach.mjs:104 sends "Her 30-day plan" to `W03`
  (W-flow) while screens-coach.mjs:105 sends "Her meals" to `K14` (K-flow). The workouts and the meals for
  one client live in two different applications.
- **The W-flow renders a nav bar that cannot return to it.** W01, W02, W05 and W10 all call
  `navBar('Clients', 'coach')` or `navBar('Chats', 'coach')` (screens-coachplan.mjs:24, :39, :69, :137), but
  `COACH_TABS` (kit.mjs:35–38) points Clients at `K10` and Chats at `K15`. A coach on the queue screen taps
  the highlighted "Clients" tab and lands on a *different* client list.

**Fix.** Keep the W-flow (it is the better and more recent design: it has drafts, gap counting, overwrite
summaries and a publish step) and delete the K-flow duplicates.

1. Delete K08, K10, K12, K13, K14 from `inventory.mjs` and `screens-coach.mjs`.
2. Repoint `COACH_TABS` in `kit.mjs:35–38` to `Today → K07`, `Clients → W01`, `Chats → W10`,
   `Earnings → K17`.
3. In K07 (screens-coach.mjs:56) repoint the "Sara Adel · Check-in" row from `K08` to `W09` so both
   check-in rows use one reviewer.
4. Merge K11 into W02: move the adherence ring and personal-bests card (screens-coach.mjs:102–103) onto W02,
   then delete K11 and repoint K16's `person` action (screens-coach.mjs:161) to `W02`.
5. Repoint K09's accept action (screens-coach.mjs:84) from `K16` to `W10`.

### BLOCKER 2 — Training splits do not exist as a first-class concept

Verified by searching all 14 screen files for `split`, `mesocycle`, `periodi`, `push.pull`, `upper/lower`,
`training block`. There are no hits that denote a product concept. The only occurrences are free-text session
names typed into a day slot: `'Full-body strength · 35 min'` and `'Upper body · 20 min'`
(screens-coachplan.mjs:47), and `field({ label: 'Session name', value: 'Full-body strength' })`
(screens-coachplan.mjs:57).

What this means concretely: **W04 has exactly one structural field — a free-text session name.** There is no
split object, no day pattern, no reusable week shape, no library of the coach's own sessions, and nothing
that survives one client. A coach running push/pull/legs with fifteen clients must retype it fifteen times,
day by day, into a 30-day calendar.

The product also promises a template system it does not have. K06 tells a waiting coach to "build a plan
template" (screens-coach.mjs:46); K12's note says "start from a template, drag, change the numbers that
matter, send" (screens-coach.mjs:210); F66 in `features.mjs:81` says "Start from a template, pick moves from
the video library, send." No template picker exists anywhere in the product. K13 is a *move* picker, not a
session or split picker.

**Fix.** Introduce a split as a saved, reusable object owned by the coach, and make the 30-day planner
assign from it rather than author into it.

1. New screen **K19 `My splits`** — a list of the coach's saved splits, each showing its name, its day
   pattern and how many clients are on it. Reached from a new row on W01 next to "Build a plan"
   (screens-coachplan.mjs:22) and from the Clients tab.
2. New screen **K20 `Build a split`** — name it (e.g. "Push / Pull / Legs"), choose a cycle length
   (3, 4, 5, 6 or 7 days), and for each slot in the cycle either name a session or mark it a rest day. Each
   session slot opens the existing W04 editor, which is already the right screen for "her order, her sets,
   her rest, her note".
3. Change **W03** (screens-coachplan.mjs:48) so the row currently reading
   `btn('Add workout') + btn('Copy this week')` becomes
   `btn('Apply a split') + btn('Add workout') + btn('Copy this week')`. "Apply a split" opens K19, and
   choosing one writes the pattern across the remaining days of the month, reusing W05's existing overwrite
   summary (screens-coachplan.mjs:74) to state exactly how many days it writes and which assignments it
   replaces.
4. Change **K06** (screens-coach.mjs:48) so "Build my first plan" opens K20, not the deleted K12.
5. Add a `Save as a split` text button to W03's footer so a month a coach has already built by hand becomes
   reusable without retyping.

### BLOCKER 3 — Assessments are entirely absent

There is no client intake owned by the coach, no movement screening, no health or injury history, no
contraindication capture, no baseline measurement and no periodic re-assessment anywhere in 146 screens.

The word "assessment" appears exactly once in the entire product, and it appears as a designer's note
explaining why the concept was *avoided*: screens-coachbrand.mjs:203 — *"The builder asks for those names
instead of imposing 'Assessment, Programming, Delivery'."* That note is about naming a coach's marketing
copy, and it is a reasonable decision for a portfolio page. It is not a decision to omit clinical intake, but
it is the only place the idea is mentioned.

What exists and is *not* an assessment:

- **G01/G02 "Coaching intake"** (screens-coached.mjs:18, :33) is client-facing and collects preferences only:
  goal, training days, minutes per session, equipment, reminder time, and cycle-sharing switches. No health
  question, no injury, no surgery, no medication, no pregnancy or postpartum clearance.
- **W09 "Review and adjust"** (screens-coachplan.mjs:115) is a weekly adherence review written from logs —
  sessions completed, days logged, how manageable it felt. It re-tests nothing.
- **W02** (screens-coachplan.mjs:30) *displays* `kv('Avoid', 'High impact, deep knee bends')` and
  `Food: no nuts · vegetarian on weekdays`. **No screen in the product ever captures those values.** They
  appear on the coach's screen having come from nowhere.

This is a safety gap, not a feature gap. The flagship specialty across this product is postpartum training —
K01:14 ("I take women back to lifting after birth"), K03:22, B04:64, H01:15. R02:35 states sessions are
"cleared for postpartum from week six, with your doctor's go-ahead", and B07:107 has a coach advertising
"Back under a weight — slowly, with your doctor's clearance". The product repeatedly asserts medical
clearance that it never collects or records.

**Fix.** Add a coach-owned assessment that gates plan publication.

1. New screen **K21 `Assessment`**, opened from W02 as the first row above the constraints card, and
   automatically queued on W01 as a "Assessment needed" filter chip next to the existing "Needs reply /
   Reviews due / Plan needed" chips (screens-coachplan.mjs:17). Sections:
   - *Health and clearance* — pregnancy/postpartum stage and weeks, caesarean or tear, doctor's clearance
     yes/no/date, diastasis or pelvic-floor symptoms, blood pressure or cardiac flags, medication,
     current pain. Use the existing `field()` and `chipRow()` components.
   - *Injuries and what to avoid* — free text plus chips. **This is what populates W02's `Avoid` row**, which
     today has no source.
   - *Movement screening* — a short list of screens (overhead reach, sit-to-stand, single-leg balance,
     hinge) each recorded as pass / modify / refer, with an optional form clip reusing the existing
     `G15` voice-and-clip capture.
   - *Baseline* — the numbers she will be re-tested against, reusing the `P03` personal-best vocabulary so
     re-tests feed the same ladder.
2. New screen **K22 `Re-assessment`** — the same form pre-filled with the previous answers and the baseline
   values side by side, exactly the prescribed-vs-actual pattern already used well at
   `setRow()` in screens-coached.mjs:6–11. Queue it on W01 every 4 weeks.
3. Gate publication: in **W08** (screens-coachplan.mjs:108–109), add a row to the "What Nour will get" card
   and an amber warning matching the existing empty-meal-slot warning — *"No assessment on file. Publish
   anyway, or complete it first."* Do not hard-block; match the product's existing tone of naming the gap and
   letting her decide.
4. Add the assessment to the client's side as a read-only record on G04 so she can see what her coach
   recorded about her, consistent with the product's privacy posture.

### BLOCKER 4 — The recipe library is unreachable from the Eat tab

`E01` (screens-eat.mjs:16–30) links to G10, E04, E02, T01, R01, M01, H01. **It does not link to E05.** The
only inbound edges to `E05 Recipes` are E06, E07 and — remarkably — `C14 "Waiting for a reviewer"`
(screens-signup.mjs:173).

Measured shortest path from a tab root: **T01 → Y03 → Y07 → E06 → E05 = 4 taps**, routed through My cycle.
`F80` (features.mjs:88) makes My cycle explicitly optional — *"Skipping it leaves the rest of the app exactly
as it was."* For any woman who skips it, four features become unreachable: F34 recipe library (Launch),
F35 cooked-it-logged-it (Launch), F36 week plan, F37 grocery list — screens E05, E06, E07, E08.

**Fix.** Add a Recipes row to E01 directly above `boxRow()` at screens-eat.mjs:28:

```js
+ listItem({ lead: icon('menu_book', { size: 24, color: C.primaryDim }), title: 'Recipes',
    sub: 'Egyptian dishes with portions and cost per serving',
    trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'E05' })
```

This puts E05 at depth 1, E06 at 2, E07 at 3, E08 at 4. Also add the same row to E04 so it is reachable
after a log, and repoint E06's "Cooked it — log my bowl" so the recipe→log loop returns to E04 (it already
does, screens-eat.mjs:98 — correct).

### MAJOR 5 — "I already did it" lands on the personal-best celebration, contradicting a stated rule

T02's save buttons (screens-today.mjs:42–43) both go to `R10`. R10 renders a personal-best card —
`strong('A personal best') ... 'Goblet squat, 12 kg × 10 — two kilos more than your best.'`
(screens-train.mjs:146) — and awards `+30 points` with `'Session 20 · personal best 10'`
(screens-train.mjs:141–142).

But P03 states the opposite rule in its own copy: *"Sessions you logged as 'I already did it' never set a
best, because the numbers were copied."* (screens-progress.mjs:47). T02's own note repeats it —
*"recalled sessions never set a personal best"* (screens-today.mjs:97).

A developer wiring this from the mockup would ship the rule violation.

**Fix.** Add a recall variant, `R10b`, and point T02's two Save buttons at it. It keeps the "That's Tuesday
done" header, the week card and the points card, and drops the amber personal-best card
(screens-train.mjs:146) entirely. Change the points line from `+30 points` to the logging-only award and
replace the PB row with a plain line: *"Logged from memory, so it does not set a personal best."*

### MAJOR 6 — Logging a whole move ends the session

`R07`'s "I did all 3 sets — log them" (screens-train.mjs:107) goes to `R10` — the session-finished
celebration. Logging move 2 of 5 should return her to the move list with move 2 ticked so she can carry on;
instead it declares Tuesday done with three moves untrained.

F10 (features.mjs:19) describes the intent correctly: *"Did all three sets without the phone? One tap logs
the move."* — the move, not the session.

**Fix.** Repoint screens-train.mjs:107 from `go: 'R10'` to `go: 'R03'`, and in R03 mark the goblet-squat row
`{ done: true }` with the next move carrying `{ now: true }` (the `moveRow` helper at screens-train.mjs:4
already supports both states). Keep R10 reachable from the last move only.

### MAJOR 7 — Coach onboarding sends a new coach into a dead builder

`K06 "Being checked"` ends with `btn('Build my first plan', { go: 'K12' })` (screens-coach.mjs:48). K12 has
no inbound edge from any coach tab root, so the very first thing a new coach is invited to do takes her to a
screen she can never find again. K06's own note calls this out as the design intent — *"Waiting for
verification comes with work she can do"* (screens-coach.mjs:204) — which makes the broken destination worse,
not better.

**Fix.** Once BLOCKER 2 is implemented, repoint screens-coach.mjs:48 to the new K20 `Build a split`, which is
the correct object for a coach with no clients yet. Until then, repoint to `W03`.

### MAJOR 8 — The ad designer's primary action publishes the portfolio

`B09 Design an ad` has one filled primary action: `canvasBar('Design an ad', { right: [{ label: 'Share',
v: 'filled', go: 'B11' }] })` (screens-coachbrand.mjs:131). `B11` is **Publish**, which shows "What changed
since version 3", lists the cover photo replacement and the `1,650 → 1,800 EGP` price change, and publishes
version 4 of her page (screens-coachbrand.mjs:161–170).

Tapping *Share* on an ad publishes a portfolio version. Wrong object, and the label does not say what will
happen — which is the product's own stated standard.

**Fix.** Repoint screens-coachbrand.mjs:131 to a share destination, not a publish one. Minimum viable: change
the label to `Save to my media` and `go: 'B13'`, which is where her reusable assets live and is where an
exported ad belongs. If a true share sheet is wanted, add it as a `sheet()` over B09 offering the three sizes
as downloads plus a copy-link action.

### MAJOR 9 — Offers are authored in three unreconciled places

A coach can set her prices and packages in three different screens, with three different field sets and only
one of them versioned:

| Screen | What it collects | Publish step? |
|---|---|---|
| K04 `Your packages` (screens-coach.mjs:27–30) | Monthly price, plan-only price, **client capacity** | None — onboarding only |
| B06 `What I offer` (screens-coachbrand.mjs:85–99) | Her own offer name, price, **her own bullet lines, a badge** | Yes, via B11 with versioning |
| K18 `Public profile` (screens-coach.mjs:192) | Shows `Packages · 1,800 EGP monthly · 900 EGP plan only`, links to B06 | Inherited |

K04 collects capacity that B06 does not; B06 collects authored lines and a badge that K04 does not. K18
displays a summary of both. A price changed in B06 goes through B11's careful versioning and its promise that
*"your price change applies to new clients only"* (screens-coachbrand.mjs:168). A price changed in K04 goes
through nothing.

**Fix.** Make B06 the single author of offers and reduce K04 to capacity only.

1. Strip the two price cards from K04 (screens-coach.mjs:28–29), keeping
   `field({ label: 'How many clients can you take?' })` and retitling the step "How many clients can you
   take?".
2. Move the capacity field into B06 as a row beneath the offers list so one screen owns the commercial terms.
3. Leave K18:192 as a read-only summary linking to B06 — that part is already correct.

### MAJOR 10 — The coached intake visibly skips its middle step

`G01` renders `segs(3, 1)` and the label "Step 1 of 3 — saved as you go" (screens-coached.mjs:24–25). Its
Continue button goes to `G02`, which renders `segs(3, 3)` and "Step 3 of 3" (screens-coached.mjs:37–38).
Step 2 has no screen. F91 (features.mjs:100) names what is missing: *"Three short steps: training, food,
support."* — the **food** step is absent, which is also the step that would collect the allergy and
vegetarian constraints that W02:31 displays as though they had been captured.

**Fix.** Add `G01b "Your food"` between them: allergies (chips, with "no nuts" as an example), dietary
pattern (vegetarian / no pork / none), cooking time available, and who cooks. Render `segs(3, 2)` and label
it "Step 2 of 3". Repoint G01's Continue to G01b and G01b's Continue to G02. This screen is also the only
honest source for W02's `Food: no nuts · vegetarian on weekdays` row and W06's allergy warning banner
(screens-coachplan.mjs:83).

### MAJOR 11 — K08 merges a message and a plan change into one unpreviewed action

`K08` offers `chipRow(['Keep weight', 'Add reps', 'Add a day'], 1)` under the label "Adjust her plan", then a
single button `btn('Send reply and plan change')` that returns to K07 (screens-coach.mjs:71–73). There is no
preview of what the plan becomes and no publish step.

This sits against the settled rule that *a coach's message never changes a plan — publishing does*. The
W-flow gets this right: W09's `btn('Save feedback and publish changes')` (screens-coachplan.mjs:125) sits
behind W03/W08, which have a draft state, a gap check and a preview; and G13 shows the client a labelled
"Plan updated" card that points at a real change (screens-coached.mjs:201).

**Fix.** Resolved by deleting K08 under BLOCKER 1. If K08 is kept for any reason, the chips must open W04 and
the button must route through W08.

### MAJOR 12 — Home and Train hard-wire every user into the coached flow

`workoutCard()` (screens-today.mjs:8–12) is used by T01, T02, T04 and T05. It **always** renders
`pill('From Sara', { ic: 'sports' })` and its primary action is `btn("Start — everything's ready",
{ go: 'G06' })` — the coached assigned-workout screen. R01 does the same:
`btn('Continue — from Sara', { go: 'G06' })` (screens-train.mjs:20).

No self-guided variant of either hub is drawn. For a woman with no coach — the majority of users, and the
entire free tier — Home's primary action points into a coaching relationship she does not have. Her actual
route to logging is T01 → R01 → R03 → R07, which is 4 taps and never surfaced on Home.

**Fix.** Draw the self-guided variants and make them the default state.

1. Add `T01b` — identical to T01 but with the workout card showing her program name instead of
   `pill('From Sara')`, and `btn("Start — everything's ready", { go: 'R07' })`.
2. Add `R01b` with `btn('Continue — week 3, day 2', { go: 'R03' })` replacing screens-train.mjs:20.
3. Treat T01/R01 as the coached state and T01b/R01b as the default, since 4 of the 5 `workoutCard()` callers
   are non-coaching contexts.

---

### MINOR 13 — Two orphan screens referenced by the feature list

`H07` and `H08` are fully written (screens-coaching.mjs:93, :105) but are not in the `screens` export array
(screens-coaching.mjs:116–123) and not in `inventory.mjs`. They are dead code. Yet `features.mjs:71` maps
F57 "One-minute check-in" to `H07` and `features.mjs:72` maps F58 "Coach feedback" to `H08` — so two Launch
features point at screens that do not ship. Both jobs are covered by G12 and G13.

**Fix.** Delete H07/H08 from screens-coaching.mjs and repoint F57 to `['G12']` and F58 to `['G13', 'W09']`.

### MINOR 14 — The coach's builders trap her away from waiting clients

15 coach screens at depth ≥2 render no nav bar: B02–B13, W03–W08, K14. The coach app's entire value is
responsiveness — K07 leads with "3 check-ins waiting · Oldest: 19 hours · you promise 24"
(screens-coach.mjs:54) — yet from three levels inside the page builder she needs three Back taps to reach it.

**Fix.** Add a persistent waiting-count chip to `canvasBar()` (kit.mjs:218) that renders when the coach has
anything queued and routes to K07. This keeps the builder focused while making the promise visible.

### MINOR 15 — No empty states on the coach side

K10 and W01 always show a populated client list; B01 always shows a published version 3 with 1,204 views
(screens-coachbrand.mjs:14, :17); K17 always shows 21,600 EGP earned. Nothing is drawn for a coach on day one
— zero clients, unpublished page, zero earnings — which is every coach's first week and the moment she
decides whether to stay.

**Fix.** Draw three empty states: W01 with no clients (offer "Build a split" and "Design your page" as the
two things she can do before clients arrive), B01 unpublished (lead with "Design it"), K17 at zero (state the
payout date and the 80% share).

### MINOR 16 — No error states are drawn

`H04` has no declined-payment screen; `C12 Checking` has no verification-failure screen (C14/C15 is the
niqab/manual-review path, which is a designed alternative, not a failure); W08 and B11 have no publish
failure. Pass 1 flagged this and it is still open.

**Fix.** At minimum draw payment-declined on H04 (with Fawry and wallet offered as the retry, since card
decline rates are the relevant Egyptian failure mode) and verification-failed after C12.

### MINOR 17 — A section can be hidden but never deleted

B02 offers the eye to hide a block and says so — *"The eye hides a section without deleting what is in it."*
(screens-coachbrand.mjs:37). B03 adds sections. No screen deletes one. A coach who adds "Numbers" to try it
accumulates hidden blocks forever.

**Fix.** Add a delete action to the block editors (B04's `canvasBar` right actions, screens-coachbrand.mjs:59)
with the product's standard undo-not-confirm treatment.

### MINOR 18 — Voice meal logging sits behind the typing screen

E01's `boxRow()` renders a mic icon but the whole card routes to `E02` (screens-eat.mjs:10). Only E02's field
trailing icon reaches `E03` (screens-eat.mjs:36). So the voice path costs 3 taps where it should cost 2, and
the mic on the Eat hub is decorative.

**Fix.** Wrap the mic glyph in `boxRow()` in its own `data-go="E03"` span, exactly as E02:36 already does.

### MINOR 19 — Five screens are delivered by no feature

C01, C03, C08, R03 and Y05 are referenced by no entry in `features.mjs`. R03 `Workout day` is the notable one
— it is the spine of self-guided training and carries both logging entry points (screens-train.mjs:56), yet
no feature claims it.

**Fix.** Add R03 to F19 and F18's screen lists; the rest are scaffolding and can stay unclaimed.

### NOTE 20 — Cycle sub-screens cluster at depth 3–4

Y01, Y02, Y09, Y11, Y13 and Y14 all sit at 3 or 4. Given the flow is optional and its hub Y03 is 1 tap from
Home, this is acceptable — but Y09 `Log a period` at depth 3 (T01→Y03→Y08→Y09) is the one worth pulling
forward, since it is the flow's most repeated action. Adding a "Log a period" row to Y03 would put it at 2.

### NOTE 21 — The five-tab client bar is at the Material limit

`CLIENT_TABS` (kit.mjs:30–34) carries five labelled tabs at 12px. Pass 1 defended this and the defence holds.
The fix for the recipe burial in BLOCKER 4 is a row on E01, not a sixth tab.

---

## What is genuinely good

**The logging model is the product's strongest idea and it is executed consistently.** The app writes the
entry and she confirms it: `bigBtn('Done — 12 kg × 10', 'Rest starts itself')` (screens-train.mjs:107) names
the exact value it will save, so confirming and logging are one action rather than two. `R08` holds the three
likeliest values as chips and puts the keyboard behind an explicit request (screens-train.mjs:115–119).
`R06` logs timed moves with zero taps and says so on screen — `pill('logs itself')` (screens-train.mjs:92) —
which is the right call, because silence after an automatic action reads as a missed log.

**Undo instead of confirmation is applied without exception.** R09:126, E04:71 and G11:176 all carry a
5-second snackbar undo and there is not a single "are you sure" dialog in 146 screens. The one place a
confirmation-style sheet appears — W05 `Copy a week` — is correct judgment rather than a violation, because
it is destructive, it is not a log, and it names the damage precisely: `kv('Existing assignments replaced',
'2 · Sun 20, Tue 22')` (screens-coachplan.mjs:74).

**The prescribed-versus-actual distinction is honoured in the one place it matters most.** `setRow()`
(screens-coached.mjs:6–11) shows the coach's prescription beside what she actually did, renders untouched
sets as `—` rather than pre-filling them, and G09 states the rule in the client's own words: *"Prescribed
values are never counted as completed work."* (screens-coached.mjs:146).

**The portfolio builder answers its brief completely.** B02 is a stack of blocks she chose and ordered, not a
template (screens-coachbrand.mjs:30–37); B03 offers twelve section types addable more than once; B05
restyles the whole page with contrast validated so freedom cannot produce unreadable text
(screens-coachbrand.mjs:81); B10 is the real client rendering rather than an approximation; B11 versions the
publish, keeps the previous version, and promises price rises apply only to new clients
(screens-coachbrand.mjs:168). This is the requirement the product delivers best.

**Consent is designed rather than asserted.** B08 gates client results behind in-app consent the client picks
the pictures for and can withdraw (screens-coachbrand.mjs:117), and it supports numbers-only or a sentence
when she declines photos (screens-coachbrand.mjs:123). B13 keeps blur on for any client in shot unless she
consented (screens-coachbrand.mjs:193). G02 separates coaching consent from cycle consent and previews
exactly what the coach would see before anything is shared (screens-coached.mjs:41–46).

**Honesty about missing data is unusually disciplined.** W07 refuses to invent nutrition totals — *"this meal
uses ingredients without verified values, so no totals are shown"* (screens-coachplan.mjs:100). W09 labels
unlogged days as unlogged rather than counting them as failures (screens-coachplan.mjs:121). W02 states that
"not shared" is not "no symptoms". G03 shows nothing as assigned while a plan is being written
(screens-coached.mjs:58). Each of these is a place where a lesser product would fabricate a plausible number.

**The coach's queue is sorted by obligation, not by vanity.** K07 and W01 both open on who has waited
longest, measured against the reply time she promised (screens-coach.mjs:54, screens-coachplan.mjs:21), with
money present but below the work. "Quiet" is a client state rather than a failure
(screens-coach.mjs:208) — the category that actually saves retention.

**Link integrity is clean.** Zero broken `data-go` targets and zero dead-end screens across all 146.
