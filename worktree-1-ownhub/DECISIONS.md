# Decisions — Own Hub

Settled answers from the product owner. **This file is authoritative.** Where it contradicts
`BUILD-BRIEF.md`, an agent plan, or a code comment, this file wins and the other should be corrected.

Recorded 2026-09-18.

---

## D1 — Scope: every feature ships. There is no MVP cut.

All **161 screens across 16 flows** and all **131 registered features**, both roles — client and
coach. Community, My Cycle, the coaching marketplace, the whole coach application, the portfolio
builder, the planning tools and the assistant are **in**.

This supersedes `BUILD-BRIEF.md` §0, which recommended a 59-screen client-only cut. That
recommendation is withdrawn — do not re-propose it.

**Consequences that follow automatically, and are therefore also decided:**
- The first-week arc keeps all five steps. T07 steps 4 and 5 ("join a group", "add a follow-up
  picture") work, because Community ships. T08 is reachable.
- The `avoid` list and allergies displayed on coach screens have a real source.
- Anything previously deferred "post-MVP" in a plan is now in scope and must be planned.

## D2 — Backend: Firebase

Whatever works on Firebase. Auth (phone), Firestore, Cloud Functions, Storage, Remote Config,
Crashlytics. Media behind a CDN — Cloudflare R2 for video, which two independent plans converged on
at $0 egress versus ~$1,352/month served straight from Storage.

## D2a — The verification code is six digits

Settled by the owner's answer to "six-digit or four-digit?": **whatever works on Firebase.**

Firebase phone auth sends a six-digit code and the length is not configurable. So the product takes
six, and the alternative — contracting an Egyptian SMS provider directly to send four — is rejected.

**This was a copy change, not just a code change** — and it is now **done**. Changing the widget alone
would have left the app telling her to expect four digits while sending six; test `P0-VER-08` exists
to catch exactly that mismatch, since the number of boxes on screen must equal the number of digits
sent.

What changed, on 2026-09-18:

| Where | What |
|---|---|
| `i18n/msa/04.json`, `i18n/msa/06.json` | three strings, English **and** Arabic together ("أربعة أرقام" → "ستة أرقام", "الرقم الرابع" → "الرقم السادس") |
| `src/screens-signup.mjs` | C07 renders **six** `digitBox`es, not four; C06/C07 copy and the C07 design note |
| `src/features.mjs`, `src/build-wireframe.mjs` | feature F03's description, and the wireframe table |
| regenerated | `i18n/strings.json` → `i18n/ar.json` → the ARB files → `AppL10n` |

Two notes for whoever touches this pipeline next. The Arabic dictionary is **generated**:
`merge-i18n.mjs` builds `i18n/ar.json` from `i18n/msa/*.json`, so editing `ar.json` directly is
silently overwritten. And `merge-i18n.mjs` reports "missing" against **`i18n/strings.json`**, a
snapshot produced by `extract-strings.mjs` — not against the screens. A stale snapshot keeps reporting
strings that no longer exist on any screen, which is misleading rather than wrong; re-run the
extractor. It now reports **0 missing across 1,684 strings**.

`i18n/ar-base.json` and `i18n/ar-part*.json` are legacy Egyptian-dialect sources superseded by
`i18n/msa/`. Nothing in the live path reads them. Leave them alone.

## D3 — Intake: ask early, editable forever

Collect what the product needs about her **as soon as possible** — at sign-up/setup, not later — and
put every one of those answers behind an edit control in **My Profile**. This resolves the
safety gap where the Eat screens checked allergies that no screen ever collected.

Applies to: goal, days, session length, place, equipment, **allergies**, **dietary preferences**,
life stage. Nothing collected once is permanently frozen.

## D4 — See D1.

## D5 — Rest weeks are free; skipping costs

A banked **rest week protects her completely** and must never reduce a reward. **Skipping training
days or meals does have a consequence.**

**How this is implemented, and why:** the consequence is applied at the **week** level, and it is
"she does not *earn*", never "something is taken away". A rest week repairs a missed week and the
counted-week total is untouched. Adherence — training days logged, meals logged — drives what she
earns that week.

There is deliberately **no daily streak and no daily failure indicator**, because the cited health-app
evidence behind this product is that visible daily failure erodes the motivation it is built to
create. The owner's intent (skipping is not free) is fully honoured; the mechanism is weekly.
*If the owner ever wants a visible daily penalty instead, that is a deliberate reversal of a
research-backed rule and must be recorded here before it is built.*

### D5a — Medically-indicated rest is never "skipping"

Raised by the Cycle planning pass, and it needed settling because D5 made an existing screen lie.
`Y11` tells a woman with severe symptoms *"rest today — it costs you nothing."* Once skipping carries
a cost, that sentence is false, and the severe-symptom screen is the single worst place in this
product to carry a false promise.

**Ruling:** when the app itself advises rest — a severe-symptom suppression under rule 5, or a rest
day the plan prescribes — that day is recorded as **planned rest** and is not a skip. It costs her
nothing, exactly as the screen says. Only an *unexplained* absence counts toward the week's
adherence.

This needs a capped `markPlannedRest` from the rewards group so it cannot be used to excuse every
day. The cap is a number to be set during implementation and recorded here.

## D6 — Tier thresholds: decided by the build, from research

Delegated. To be researched, decided, written down here, and then made consistent across `P01` and
`T05`, which currently contradict each other. Until written here, no tier number is authoritative.

## D7 — Splits: pick one, or build your own

The trainee can **choose a predefined split** *or* **design her own** from the 124-move workout
library. The split builder is therefore not coach-only; the same domain model serves both roles, with
the coach's version additionally able to assign a split to a client.

## D8 — Rejected verification: the words

She is told, in substance: *we are reviewing your application to make sure this community stays safe
and private.* Not an accusation, not a rejection notice. Routes to the woman-reviewer path.

## D9 — Product name: **Own Hub**

Bundle identifier: **`com.ownhub.app`** on both stores unless the owner supplies a domain to reverse.
This replaces `com.example.fitness_app`, which both stores reject. It can be changed now; it can
**never** be changed after the first store release.

## D10 — Quality bar, stated by the owner

- Ready to deploy and publish. No follow-up fix-and-patch round expected.
- The experience already designed in the prototype, exactly.
- Clean, scalable code that is easy to edit and extend.
- **Test cases written before the implementation they cover**, so tests cannot be shaped to fit the
  code that happens to have been written.
- Behaviour verified against official documentation, not assumed.
- Everything green in the build.
- Documented well enough that an AI agent picking this project up later has full context.

## D11 — She chooses train, coach, or both — and the navigation follows

**This overturns D-era behaviour and C08's own on-screen promise.** The role was a write-once,
immutable `client | coach` choice that could only be changed by messaging support. It is now a
**capability set**, chosen at sign-up and changeable afterwards:

| She picks | Bottom navigation | |
|---|---|---|
| **I'm here to train** | Home · Train · Community · Eat | 4 tabs |
| **I coach women** | Today · Clients · Chats · Earnings | 4 tabs |
| **Both** | Either of the above, whichever role is active | switchable |

A woman who picks **both** switches the entire app between her trainee side and her coach side by
tapping **her profile picture**. Each side keeps its own navigation and its own experience; neither is
a subset of the other, and neither is a mode indicator bolted onto a shared shell.

### Coaching leaves the trainee's tab bar. It does not leave the product.

The fifth client tab was `H01`, which is `F53 — Find a coach`: filter verified women coaches by
specialty, language, city and price. That is a **Client** feature, released at launch, and deleting it
along with the tab would quietly remove a launch capability nobody asked to lose. So the *tab* goes
and the *capability* moves to her profile. Being coached and being a coach are different things, and
only the second one is a role.

### What this costs in the schema

`users/{uid}.role` cannot stay a single immutable enum. It becomes a set of roles plus the currently
active one, and G1's rule making `role` unwritable a second time has to be rewritten to keep the part
that matters — **a woman cannot grant herself coach privileges by editing her own document** — while
allowing her to switch between roles she already holds. Becoming a coach still requires the coach
application and its certificate checks; switching to a coach role she has already earned does not.

## D12 — An admin console inside the app, for content

The owner asked for meals and workouts to be addable **from within the app**, with a bulk option for
CSVs, videos and pictures. Nothing like this existed: every privileged operation in this product is
server-side Admin SDK code, and none of the 161 screens is an admin screen.

### Admin is a third role, not a mode

It reuses D11 exactly. `roles.held` is **server-write-only**, so a woman cannot grant herself admin
any more than she can grant herself coach — the console is reachable only for an account whose claim
says so, through the same profile-picture switcher, with its own bottom navigation. Rules gate on
`request.auth.token.admin == true`, the same custom-claim pattern already used for
`token.verified` and `token.coachV`.

**An admin is staff, not a member.** The console manages the *content library*. It is not a window
into anyone's account.

### What it is for, and why it is on the critical path

`SCHEMA-SPINE.md` marks `exercises`, `foods`, `recipes` and `programs` READ-ONLY, and states that
`contraindicationTags[]`, `allergens[]` and `dietTags[]` are **"mandatory, not enrichment… without
them the safety rules are decorative."** Those tags do not exist, which is exactly why `P0-EAT-01`
cannot pass and why the exercise safety filter is inert. **This console is how that content arrives.**
It is not an accessory to Phase 2; it unblocks it.

Consequence to record: those four collections stop being READ-ONLY and become
**admin-write, everyone-else-read**. `SCHEMA-SPINE.md` is amended accordingly.

### Bulk means import as well as export

The request said "bulk export". Adding 124 exercise videos and an Egyptian food library one form at a
time is not a feature, so **bulk import is what "add from the admin section" requires**, and bulk
export is what was asked for literally. Both ship. Stated here as an assumption rather than decided
silently.

**Import is dry-run then commit, and is never partially applied.** A half-imported food library where
some rows lack `allergens[]` is worse than no import at all, because the gaps are invisible and the
guard reads a missing tag as *unknown, therefore unsafe*. Rows missing a mandatory safety tag are
**rejected at validation**, named row by row, and nothing is written until the whole file passes.

### The export contains content. It never contains her.

This is the constraint that matters most and is not negotiable. "Videos and pictures" in this product
could mean exercise demonstrations and recipe photos — or it could mean a woman's progress photos and
her logs. The export is scoped to the **content library only**: exercises, foods, recipes, programmes
and their media.

**No export path may reach** `users/**`, cycle data, check-ins, measurements, progress photos, meal or
session logs, phone numbers, names or verification results. This product tells her that her ID photo
and selfie are deleted and that her logs are never shown to members; an admin bulk-export of user
media would make both statements false. Under PDPL this is also the difference between exporting a
content catalogue and exporting regulated personal data, some of it biometric. A test asserts the
export manifest contains no `users/` path.

If an export of user data is ever genuinely needed — a data-subject request under PDPL, for example —
that is `A02`'s "download everything", it belongs to the woman herself, and it is not an admin
feature.

---

## Release 2, 25 September to 6 October 2026

Decided by the owner during the launch work, or by the build where the owner asked for it. Branch
`council/2026-10-02` holds the code for all of these. Full detail: `COUNCIL_REPORT.md` in that
worktree and `docs/release/OWN-HUB-BEFORE-PROD.xlsx`.

## D28 — Release 2 is the launch build. Sign-up and verification are on.

The owner asked for no cut-down 1.0. The shipped flags turn on `accountRequired`, `signUp` and
`verification`. Community, coaching, marketplace, payments and the assistant stay switched off, and
no screen may promise a switched-off feature. Each promise comes back by itself when its flag is
turned on.

## D29 — Verification is self-hosted and costs at most USD 0.05

Didit (USD 15.5k a year) was rejected. Cloud Vision OCR plus on-server face match and a server-chosen
liveness challenge run in Frankfurt. ID and selfie images are never stored. Only a keyed hash of the
ID number is kept, so one card cannot open two accounts. When the check is unsure, a woman reviewer
does a video call, but only after the woman asks for it. Her consent is recorded for that review
only.

## D30 — Members sign in by phone only

Google and Apple sign-in are to be switched off. Email and password exist only for women reviewers.
The server and the rules refuse every non-phone account on the women-facing features. SMS to Egypt
costs USD 0.13 each, so SMS is limited to +20 numbers.

## D31 — Health data stays on her phone unless she opts in

Cycle, check-ins, measurements, life stage, allergies and weight never leave the phone by default.
"Back up my health data" has its own consent. Turning it off deletes the cloud copy. Training and
meal logs sync once she is verified.

## D32 — Deleting an account erases everything on the server

That covers her data, her login, her files, community, coach and assistant data, and counters. A
second sweep runs an hour later. The ID-number hash stays closed, so the same card cannot rejoin
(pending counsel).

## D33 — The owner's original illustrations ship, and the logo is the Concept 02 monogram

Chosen on 1 October 2026 over the painted replacements. No licence record exists, and the owner
accepts that risk. The wordmark reads OWN HUB (the sheet's OWN FIT was a placeholder).

## D34 — Free at launch. Pro later, only after a price test.

Proposed: EGP 99 a month or EGP 699 a year, adding new things only (more recipes, extra
programmes, deeper history and export, priority coaching). Nothing free today becomes paid,
including the week plan and the grocery list. Billing is built only if real users commit in a
price test.

## D35 — Both stores launch together, after Google's 14-day closed test

A new personal Play account must run a 14-day test with 12 testers. That test is also the
verification pilot and the reviewer rehearsal. The launch date is set by the stores, not the code.

## D36 — A waitlist before launch, kept at most 180 days

A phone number or email, with consent. 50 sign-ups per IP address a day, because Egyptian mobile
networks share addresses. Used once at launch, then deleted.

## Still genuinely open

These block launch, not the build, and are not engineering decisions:

- Minimum age: the build enforces 18; counsel to confirm.
- Visible follower counts — reverses an earlier "no follower counts" decision.
- The before/after guardrail for coach marketing versus client results.
- The trans-women policy. The document-marker gate is implemented as instructed; the policy itself is
  the owner's and is not chosen here.
- Amplitude tier at 100k MTU ($1,000–2,500/month).
- Moderation and reviewer staffing — the Safety Centre's on-screen promise is a staffing commitment.
- Data protection permit (PDPC) before processing, individual or company — counsel, first question.
- Whether a deleted account keeps a hidden marker so attempt limits cannot be reset — counsel.
- The store reviewers' test-account tool — waiting on the owner's yes or no.
- Whether the women-only pledge screen is reworded while community is off — owner.

### Blocking Phase 2, found while planning it

These are **content obligations, not engineering tasks**. Each blocks a named P0 case, and none may
be invented — a plausible-looking guess in any of these four reaches a woman's phone as fact.

- **`foods.allergens[]` and `foods.dietTags[]` do not exist.** `SCHEMA-SPINE.md` calls them
  "mandatory, not enrichment", and a missing tag must read as *unknown, therefore unsafe*. Without
  them `AllergyGuard` cannot function and **`P0-EAT-01` cannot pass**.
- **No screen anywhere collects allergies**, although D3 says they are collected at sign-up and
  editable in My Profile. Until one exists the guard fails closed for *every* woman — interrupting
  those who have no allergy at all. If A02 is chosen to host it, G7 owns the row and G2 writes the
  field; two groups writing one field is a rejected plan.
- **The Y11 care directory cites British NHS guidance**, with no Egyptian source and no named
  clinical reviewer. That screen gives medical advice to a woman reporting severe symptoms; it is
  the highest-liability string in the product. **`P0-CYC-07` and `P0-CYC-08` cannot pass.**
- **Y12's "what was deleted and what was kept" copy**, including its Arabic. The check-ins survive a
  cycle delete because they belong to G3, and Y12 must say so. **`P0-CYC-16` cannot fully pass.**

### A shipped string that is currently false

**Y11 says "Marked as planned rest — it costs you nothing."** D5a requires a capped
`WeeklyGoalService.markPlannedRest(date)` to back that promise, and says the cap is "a number to be
set during implementation and recorded here". **That method exists nowhere** — not in G6's published
API, not in the code — and the cap was never recorded. As built, resting on Y11 costs her the week's
adherence and the sentence is untrue. Either G6 publishes the capped method and the cap is written
into this file, or Y11's copy changes. A false promise on the severe-symptom screen is the worst
place in this product to have one.

### Open, and waiting on you — the five the agents refused to invent

Each of these was reached honestly: the code is built and tested, and a value was withheld rather than
guessed, so nothing ships a number nobody decided. They are listed together because each is one sentence
from you and none can be settled from the repository.

| # | Decision | What is blocked today |
|---|---|---|
| **1** | ~~**The planned-rest cap.**~~ **Settled by D16: two per week.** `WeeklyGoalService.markPlannedRest` now exists and enforces it. | Y11's rest row still ships **with no subtitle** — for a different and better-understood reason, below |
| **2** | **The tier ladder.** Three of five tiers — *First steps*, *Strong*, *Unshakeable* — have no authored name, and D6 says no ladder is authoritative. | P01 renders **no tier at all**, and T05's sheet does not open. `TierPolicy` is complete and tested against ladders supplied by tests |
| **3** | **The NHS citations.** Y05 and Y11 render `nhsPeriodPain` and `readNhsGuidanceOnPeriodPain` — **British clinical guidance shown to Egyptian women on the severe-symptom screen.** Approved dictionary copy, so no agent would remove it. | The highest-liability copy in the app. It needs either an Egyptian source or your explicit sign-off |
| **4** | **Cycle sharing ownership** — `SCHEMA-SPINE.md` §8 versus G9 §1.1. Consent data, so settling it later is a migration. | Recorded in full above |
| **5** | **`WeekKey` has no timezone.** G6 §3.1 requires `WeekKey.current(tz)` and the full IANA database; a Cairo-hardcoded boundary misfiles the Gulf diaspora's late-evening sessions into the wrong week. | Weeks are the product's only unit, so this decides what "this week" means for anyone outside Egypt |

Two schema notes needing the same ratification: **`weeklyGoal.restWeekProgress`** (int 0–3) is described in
G6 §3.1's prose but missing from its field table, and it **cannot** be derived from `countedWeeks` —
deriving it would let a rest week fund its own repair. And **`actualHoldSec`** is absent from G4's
`measuredSets`, so P03's "Plank hold" branch is implemented, tested, and populated by nothing.

### The mockup's numbers are still all over the app, and now they are counted

**Six of these were found by accident. This is the deliberate search, and it is the largest single piece
of work left in the product.**

Every defect of this class has the same shape: a sentence from the prototype, with the prototype's
figures inside it, frozen into the dictionary and then rendered as though it were hers.
`level7Regular`, `n22Of95G`, `thisWeekDoneOfTarget`, `myCyclePeriodDay2`, `lunch540Kcal18GProtein`,
`n540Kcal18GProtein` — each was found while looking at something else.

A sweep of the dictionary for **number-bearing strings with no placeholder form that are actually
rendered** gives the real size of it. The worst of what it turned up:

| String | Where | What it tells her |
|---|---|---|
| `week3Of8` | Home's workout badge, and `train_view` as a **fallback** (`programWeek ?? week3Of8`) | She is in week 3 of 8 — and it lies *precisely when* the real value is missing |
| `walkThisMorning32Min` | Home's walk card | She walked 32 minutes |
| `n410Kcal`, `n290Kcal` | Home's meal card | What breakfast contained |
| `session20PersonalBest10`, `n490Total`, `n70PointsToLevel8` | Finished a session | Her session count, points and level |
| `n2Of5DoneNothingExpires`, `n3Of3ItCounted`, `n35PointsSoFar` | First week | How far through she is |
| `tuesday16September` | Lock-screen nudge | Today's date |

A distinct sub-class states things about the **product** that are false rather than about her:
`n124Videos`, `search124Workouts`, `all124IncludingTheQuietOnes`, `allFoods4100InTheList`,
`n18WorkoutsQuietAndNoEquipment` and `n4210WomenInTheBeginnersGroup`. The admin console's own notes
confirm the 124-move library does not exist and no food carries allergens, so these count content that
has not been authored.

**Plenty are legitimate and must not be "fixed":** `step1Of2` and `step1Of4` really are those steps, the
three pledge items really are numbered, `add30Seconds` really adds thirty, and "call 122" is a real
Egyptian emergency number. A blanket ban would be wrong; this needs judgement per string.

So it is **ratcheted rather than swept**: a guard counts them and the count may only fall. That stops new
ones arriving while the existing ones are worked through, which is the failure mode that produced six
of them already. `stated_figure.dart` — render a line only to the woman it is true of — and the
parameterised-string route are both proven; what remains is applying them, screen by screen, with the
owner's content decisions where a figure has no source yet.

### Three collections were denied in both directions, and one of them is a PDPL right

**Found by asking the deletion guard the opposite question.**

`deletion_manifest_test`'s check (e) asks: is every subcollection the *rules* declare enumerated in the
manifest? That catches a collection shipping with no deletion row. It is blind to the reverse — a
manifest row whose path has **no rules block at all**, which falls through to the catch-all
`allow read, write: if false`.

Three were in that state:

| Path | Owner | What deny-all actually cost |
|---|---|---|
| `users/{uid}/consents/{purpose}_{version}` | G1 | **PDPL gives her a right of access to her own consent trail.** Deny-all blocked her from reading it — G1 §6 grants `get, list` to her and keeps writes to the ConsentService callable |
| `users/{uid}/notices/{kind}-{week}` | G3 | T04 and T05's shown-once notices. Six references in `lib/` today |
| `users/{uid}/firstWeek/arc` | G3 | The first-week arc. `FirstWeekArc` is a live domain model with a `withStep` transition |

All three are now merged **verbatim from the owning plans** — nothing invented, only names adapted to
this file's helpers (`isOwner`→`isSelf`, `noStreak(d)`→`noRunCounter()`, `isWeekId`→`isWeek`). G3's
notice rule is worth noting: it requires the document id to equal `kind + '-' + forWeek`, which makes
"shown once, never again that week" a property of the database rather than a flag somebody checks.

`syncQueue` is the fourth row without rules and is **correct** — it is a local sqflite table, not a
Firestore path. The new guard exempts it by its `localOnly` method rather than by name, so the exemption
states a reason instead of listing a special case.

**A fourth gap, found while reading the same plan:** `checkins` was a bare `allow read, write`, with
G3's `checkinFieldsOk` validator merged nowhere. That mattered this week in particular — Y04 is gaining
the sleep, bloating and bleeding controls, and `bleeding == 'heavy'` is half the severe-symptom gate. A
value the gate could not recognise would not fail loudly; it would simply never suppress, and she would
be offered a workout on a day the product promised not to.

### D13–D20 — the owner's answers, 19 September 2026

Recorded verbatim in substance, with how each was implemented, because several of these unblock guards
that were deliberately written to fail until a person decided.

**D13 — Cycle sharing consent is hers to give and to change later.** She consents, she shares, and she
can update it afterwards. That settles the §8-versus-G9 contradiction in favour of **G9's reading**: the
grant lives on `cycle/current` and is written by Y12, which is the screen she can return to. The code is
already built that way, and `CycleSharingPolicy` already re-evaluates at read time so a revocation takes
effect without a write.

**D14 — Tiers come from her gym logs and the weights she has lifted, and every woman sees her own.**
Implemented as **counted weeks + personal bests**, which is exactly what `TierRung` already carries.
Deliberately *not* body weight: `SCHEMA-SPINE.md` C7 and rule 11 forbid ranking women by weight or
weight lost, and `loadKg` is "the dumbbell, and cannot be mistaken for the woman". A personal best IS a
weight lifted, so the owner's intent and the rule agree.

"Shown to everyone" is read as **stop hiding it** — today P01 renders no tier to anyone because no
ladder exists. It does not mean tiers appear on other women's profiles; that would be a different
decision touching the privacy defaults, and it has not been made.

**D15 — The NHS citations are signed off.** Egyptian sources to follow; until they do, Y05 and Y11 keep
the NHS guidance with the owner's explicit sign-off rather than as an unreviewed default.

**D16 — Planned rest is capped at two per week.** D5a's missing number. Y11's rest row can now carry its
subtitle truthfully.

**D17 — The app is international; the week follows the phone's timezone.** A session logged late on a
Sunday evening belongs to the week it was Sunday in *for her*, not in Cairo. Weeks are the product's
only unit, so this is a correctness decision, not a preference.

**D18 — Content is authored both one at a time and in bulk, for every collection.** So recipes and
programmes get add/edit forms like exercises and foods, and the missing screens are added rather than
the collections being left import-only.

**D19 — `restWeekProgress` and `actualHoldSec` are to work, not to be debated.** The first already
exists on `WeeklyGoal` and drives `RestWeekRepair`; what was missing was its row in G6's field table.
The second is readable by `PersonalBestDetector` and unpopulated, because G4's `sets[]` does not surface
it.

**D20 — Seed the library content now; the owner replaces it later.** Allergens, contraindication tags
and the rest are authored as working seed data so the safety guards have something to read, rather than
staying inert. **This is data, not the founder's voice** — no script, caption or coaching copy is
written on his behalf.

### D17 in practice — the week already followed her phone; the label lied

**The investigation changed the shape of the fix, so it is worth recording what was actually wrong.**

G6 §3.1 asks for the full IANA database, and the obvious reading of "respect the phone's timezone" is a
large piece of work. It was not needed. `WeekKey.of` reads a moment's **calendar** year, month and day,
every caller hands it a device-local `DateTime`, and **nothing in the app calls `toUtc()`**. So a session
logged at 01:00 on a Monday in Dubai already filed into Monday's week, not Sunday's.

What was wrong was `kDefaultTimezone = 'Africa/Cairo'` reading as *her* zone — so every `WeeklyGoal`
asserted Cairo whether or not she had ever been there — and the same literal appearing twice more, in
`InMemoryMealRepository` and `MealLogService`. Three copies of a claim nobody had checked.

Fixed by naming it for what it is: **`WeekKey.fallbackTimezone`**, one constant, beside `WeekKey` rather
than in the rewards domain — because Eat needs the same fallback for a meal's day key and should not
import `weekly_goal.dart` to get it. And **`WeekKey.current()`** now states the invariant that was true
and unwritten; every call site said `WeekKey.of(DateTime.now())`, which is correct and silent about why.

**The half that pulls the other way, kept deliberately.** `WeeklyGoal.tz` stays *stored* rather than
re-read, and `WeekKey.of`'s own doc explains it: "the boundary is a property of the woman, not of the
server… a woman who flies to Cairo does not gain or lose a week in transit." Recomputing history when
she travels would move last month's sessions between weeks. So **new weeks follow her phone; closed
weeks keep the boundary they were closed under.** If the owner wants past weeks to re-file on travel,
that is a different decision and this is the paragraph to revisit.

The guard is machine-independent on purpose: a test cannot choose the runner's timezone, so asserting
"23:30 in Dubai lands in Monday" would pass or fail by where it ran. It asserts the *contract* instead —
two moments with the same calendar date, one local and one UTC, must be the same week — plus a source
scan for `toUtc()` with a positive control. Both fail the instant someone "fixes" the boundary by
converting first, which is the exact edit that would break the Gulf diaspora.

### The content console could add a row and could not open one

Found while wiring Z12 and Z13, with 331 admin tests green.

`CollectionView` has exposed an `onOpenRow` callback since it was built, and it fires on every row tap
(`collection_view.dart:165`). **No route builder passed it.** So `AppRouter.adminEditingRow` was only
ever read or cleared and never populated, `ContentFormView._isEditing` is `values.isNotEmpty` and could
therefore never be true, and "Edit a food" was a string the running app had no path to.

Every admin test built `CollectionView` or `ContentFormView` directly and handed it rows it had made
itself. That proves a screen renders what it is given and says nothing about what the router gives it —
the same blind spot that hid P01's empty milestone catalogue and Y04's missing `onSaved`. It is now
covered the same way, by `admin_router_journey_test.dart` driving the real router.

The console is for managing content. "You cannot open the row you just saved" is not a small gap in
that, and no screenshot shows it, because the list looks perfect.

### Wiring the edit created a second defect, and the negative control caught it

`adminEditingRow` is shared module state cleared only by the form's own close button. The Android system
back gesture pops the route without calling `onClose` — so after wiring `onOpenRow`, opening a food,
backing out, and tapping **Add** opened a blank-titled form pre-filled with the food's values, in
whichever collection she was now in.

It was caught within a minute of existing, by the negative control asserting that Add says *Add*. That
test was written to stop the edit assertions passing over a form that said "Edit" regardless; it earned
its place by failing for a completely different reason.

Fixed at the source: `onAdd` clears the row before navigating, on all four collections. Not in the form,
because a form that defends itself against its caller's leftovers is a form nobody can reason about.

Both fixes are mutation-checked. Removing `onOpenRow`'s values turns two tests red; removing `onAdd`'s
clearing line turns exactly one red; restoring returns 6/6.

### D16 in practice — the cap exists, the promise still cannot be kept

`WeeklyGoalService` now exists, and `markPlannedRest` caps at two per ISO week. The cap is real:
dedupe runs *before* the cap, so a double tap on the severe-symptom screen reports no refusal she did
not earn; rollover compares week **ids** rather than elapsed time; and the marked days live in an
unordered `Set` bounded by the cap, so "how many in a row" is not a question the type can be asked.
`setTarget` refuses out-of-range rather than clamping, because clamping 7 to 4 hands her a goal she did
not choose and calls it success.

**Y11's rest row still carries no subtitle, and that is now the considered answer rather than a gap.**
Marking rest changes nothing about what the week counts: adherence lives on `users/{uid}/weeks/{id}`,
which is `allow write: if false`, and `WeekDoc` has no planned-rest field at all. The cap holds inside
the domain layer and nothing downstream honours it. Rendering "it costs you nothing" over that would be
G9 OQ-7's exact failure — a false promise on the worst screen in the product to have one. The string
exists and is deliberately unused.

The server half of D16 does not exist. An app-advised rest day still reads as an unexplained absence.

### The rules contradict the spec about what is hers to write, and I did not resolve it

Found while building the above, and it is the sharpest thing on this page.

`weekly_goal.dart` documents — citing G6 §6 item 3 — that exactly three fields are client-writable:
`sessionsTarget`, `tz`, `goalKind`. **The deployed rules forbid all three.** Verified directly:

* `rewardsUntouched()` is `!touches(['rewards', 'weeklyGoal'])`, AND-ed into `clientInvariants()`;
* `users/{uid}`'s `allow update` additionally requires `onlyTouches(['profile','privacy','notify','updatedAt'])`.

Doubly blocked. So **T05's "shrink this week's goal in one tap" — a shipped screen — would be denied by
the server.** A goal she can meet beats a goal she abandons, and today she cannot change it.

**I have not widened the rule, deliberately.** The fix is small to write and easy to get subtly wrong:
it means relaxing `rewardsUntouched()` and adding a nested diff over `weeklyGoal` that admits those
three keys and no counter — on a ruleset **no line of which has ever been executed**, because there is
still no JDK and therefore no emulator. The create path is where `resource` is null, which is precisely
where this file already recorded a rule that could never have succeeded. Loosening the document that
holds her tier and her points, unverifiably, to fix a screen, is the wrong trade to make quietly.

It is written up in `OPEN-QUESTIONS.md` as B4, with the concrete change ready, so it is one reviewed
step once the emulator runs.

### D21–D26 — the owner's answers on Phase 3, 19 September 2026

Asked before building, so that none of it is discovered halfway through.

**D21 — Payments are built behind a seam; Paymob is integrated later.**
> *"i will integrate a payment gateway later like paymob do the build now and leave me minmal work when i have the paymob account created"*

So H03/H04, the eight payment states, refunds and the split are real code with real tests, running
against a `PaymentProvider` seam whose only implementation refuses honestly — the same shape as
`UnavailableCaptureService`. **Nothing ever fakes a successful payment**, because a fake success is the
one defect that would reach a woman's bank. Swapping in Paymob is one class.

Settled with it: refund window **48 hours**; the **platform absorbs** the refund fee; **buy-direct is
removed** in favour of enquiry-first, which makes "she pays only once you accept" true on every path
instead of false on one.

**D22 — Life stage restricts what may be prescribed, and she can declare it herself.**
> *"do the recommendation and resarach this and finish it the user should be able to tell this in thier profile"*

G14 records `lifeStage`, `birthType` and `clearance` and then lets **none of them restrict anything** —
a coach could record `pregnant` and the move picker would be unchanged. That hole is now closed:
`LifeStageSafetyPolicy` derives avoid-tags automatically (pregnant and 0–6 weeks post-birth suppress
`pelvic_floor_load`, `high_impact`, `jumping`, `supine_load`, `breath_hold_valsalva`), and publishing is
**blocked** while `clearance.granted == false` in the 0–6 week window.

The owner's addition is the better half: **she states her life stage in her own profile**, not only
through a coach's assessment. Where a self-declaration and an assessment disagree, the **more
protective** union wins — a coach does not get to overrule a woman about her own body, which is the
same principle that already forbids a coach overriding an allergy.

**D23 — The assistant runs on Gemini Flash.**
> *"i will use gimini flash build the infa now i will provide the api later"*

G15 is written around Claude (Opus 5 for answers, Haiku 4.5 for the guardrail) and its cost model —
~$4,860/month — was the second-largest line in the product. Gemini Flash replaces that choice.

**What does not change, and must not:** the key never ships in the app (an APK is a zip), the Function
returns **ids and a template key, never a number**, the cheap classifier runs before the expensive
model, the subject is bound from the caller's auth and never from a tool argument, and the assistant
**cannot write anything**. Those are structural properties, not vendor features, so the provider goes
behind a seam and the guarantees survive a change of model.

**D24 — Community launches as photos and text.**
> *"yes hide the follow count but leave the the likes the comments i want this community at lauch to only be able to post photos and text leave videos for a later stage"*

Likes and comments **visible**. Follower counts **hidden**. **No video, no reels, no voice notes** at
launch. This is not a scope cut for its own sake: on-device reel blur is unmeasured on a budget Android
handset, and "if a 60-second reel takes 3 minutes to export, women will turn blur off" — a rule 6
failure by user experience rather than by code. Voice notes have no moderation story at all.

All four are flags, not deletions: the code ships dark and is switched on when it is ready.

**D25 — Feature flags across all three phases.**
> *"for the feautre flags yes do the best practices and recommendation"*

`lib/domain/flags/feature_flags.dart`. A closed enum rather than string keys, because a typo in a
string-keyed map is a silent "off", and silent-off on a safety surface is this product's worst failure
mode. Flags have **parents**: `isOn` walks the chain, so "community is off but community video is on"
is not a state the type can hold. Phase 1 and 2 default on; every Phase 3 feature defaults off.

**D25 in practice — the gate, and the two flows that are never gated.**

A flag nothing consults is a claim, not a mechanism. `AppRouter.onGenerateRoute` now asks
`featureForFlow` before it looks in the built-screens map, so a switched-off screen renders `FeatureOff`
and **cannot be reached even by deep link**. Until this existed, every Phase 3 screen was one link away
from a woman the moment it compiled.

`FeatureOff` is deliberately distinct from `NotBuiltYet`: "we have not built this" and "this is built
and currently off" are different facts, and collapsing them makes the switchboard impossible to reason
about during a release.

**Two flows are never gated, and that is load-bearing:**

* **`account`** — the privacy centre, her export and account deletion live here. A flag flip must never
  trap a woman inside an app she cannot leave, and PDPL erasure is not a feature to toggle.
* **`onboarding`** — gating the setup questions could strand a half-registered woman with no way
  forward and no way back.

A test asserts every flow in the route table appears in the switchboard, so a new flow cannot become
ungated by being forgotten. It immediately earned its place: it found `coach-setup` (K01–K06), which a
hyphen-blind search had missed, leaving the coach's own setup screens ungated while her desk was dark.

**D27 — Every screen carries one or two illustrations, chosen for what it is for.**

58 illustrations from the owner's two artwork files, extracted per-illustration at 600px and masked to
each drawing's own pixels, so no neighbour bleeds into a crop. Shipped as WebP at three densities
(4.8 MB). All placements live in one table, `lib/theme/screen_art.dart`, so the whole set can be read
and audited in one place; `AppScaffold` draws the entry for whichever screen it is showing.

The rules the table follows:

* **Purpose first.** A food screen shows food, a workout screen shows that kind of work, a coach screen
  shows coaching.
* **The sensitive screens stay calm.** Her cycle, her privacy, the safety centre, her body measurements,
  and every screen where she waits all use the meditating woman, a stretch or the yoga mat.
* **No treats on food screens.** Cake, cupcakes, cookies and fries appear nowhere a food is logged or
  planned -- a picture there would imply a judgement the product refuses to make.
* **Never the same picture twice on one screen.**

Verified by opening every built screen through the real router and counting what is drawn: all 161
show one or two. The first version of that check was hollow -- it reused one navigator, so it opened
the first screen 167 times -- and the same flaw was in the earlier navigation smoke test. Both now build
a fresh navigator per screen.

**Three images are held back for the owner, not shipped:**

* **A carrot holding an "EAT HEALTHY FOOD" sign.** The English is part of the artwork. In a bilingual
  app with right-to-left Arabic, that is untranslatable English inside an Arabic screen.
* **Sliced cured meat.** It reads visually as ham, in an app built for women in Egypt.
* **A water bottle with "Stay Hydrated!" on a sticky note.** The same baked-English problem as the
  carrot, and caught only by looking at the running app rather than the counts. It is a genuinely good
  fit for the rest screens, so it is the easiest of the three to bring back -- one line each in
  `screen_art.dart`. It also appears in the feature video, which was rendered before this was found.

Both are in `docs/artwork-held-for-owner/` pending a decision.

**Known limitation:** the artwork has nothing for messaging, payment, notifications or settings -- no
phone, chat bubble or wallet. Those screens carry a neutral on-brand image rather than a literal one.

**D26 — Minimum age: still unanswered.**

Asked, not answered. It does not block the build — it blocks the **store submission**, because the
privacy policy, the terms, the in-app gate and both stores' age ratings must all carry the same number,
and the repo currently has it both ways (16 and 18). Kept flag-driven. Re-raise before submission.

### D18 in practice — Z12 and Z13, and the two lists that could not author a row

The gap was not the form. `ContentFormView` has been able to draw a complete recipe and a complete
programme since Z03/Z05 landed — it is parameterised by collection and draws whichever columns the
schema can label. What was missing was **a screen id to put it on and a way in**.

The markup contradicted itself about this, which is how it survived review: Z06's add action opened a
**food** form, and Z07's opened the **importer**. So "add a meal from inside the app" was true of foods
and false of recipes, and nobody could see it from either screen alone.

Both now exist, and both are reachable: `Z06.onAdd -> Z12`, `Z07.onAdd -> Z13`. Two-tap reachability
went 49/59 to **51/59 (86.4%)**, so neither arrived stranded. `_title`'s switch is now exhaustive with
no `_` arm — a fifth collection added tomorrow fails to compile rather than quietly titling itself
"Edit" and looking finished.

Six strings were minted for it. The other labels — `Recipe id`, `Weeks`, `Days a week`,
`Session length` — already existed, which is the schema-driven form paying for itself.

### `day-2` would have pinned every real personal best below a mockup

Found while wiring the personal-best detector, and worth recording because the suite was green
throughout and no screenshot would have shown it either.

`WorkoutDay.id` is documented as "the assignment's `yyyy-MM-dd` key", and `startSession` copies it
straight into the session's `dateKey`. R03's sample day carried the mockup slug **`day-2`**.
`progress_repository.dart` sorts her bests "newest first by `dateKey`" with a bare `String.compareTo` —
and `'d'` is greater than `'2'`, so **every best she set in the running app would have pinned itself
above every real dated one, permanently**, with nothing throwing.

Fixed by giving the sample day today's key. The formatter went to `lib/domain/format/day_key.dart`
rather than inline, because four places in `lib/` had already written their own `padLeft(2, '0')` and
this would have been the fifth. A test pins the exact comparison — `'day-2' > '2099-12-31'` — so the
next person to put a slug in a date field is told which sort they broke.

Note what the test does **not** do: assert a timezone. `dayKey` reads local calendar fields, matching
D17, and the guard is written so it holds wherever it runs.

### Arabic in the seed library stays `\u`-escaped

`i18n_guard_test.dart` fails on any Arabic character in a non-comment line under `lib/`, and its
allowlist is hard-capped at three entries. The seeded content library holds 56 `name_ar` values, so it
escaped them all, with readable Arabic in a comment above every row.

The offer was to allowlist the file and raise the cap to four. **Declined.** The cap is a ratchet, and
the whole point of a ratchet is that it is inconvenient exactly when you want to move it. The founder
replaces this content by CSV import, not by hand-editing a Dart file, so the escapes cost nobody
anything real. If seeded content ever becomes something people edit in place, that is the moment to
revisit — and the argument then will be about editing, not about the guard.

### The template staff are handed disagreed with the validator

`6-v2/content/templates/exercises.csv` shipped `equipment=dumbbell` where the enum declares
`dumbbells('dumbbells')`, and `contraindicationTags=knee_pain`, which is not in G14 §1.5's controlled
vocabulary at all.

The second is the dangerous one. `ExerciseCandidateFilter` intersects tags against a closed set, so
`knee_pain` **matches nothing** — a row tagged that way reads as authored and protects nobody. A blank
tag fails closed and is caught; a misspelt tag fails *open* and is not. `content_schema_test` compares
headers only, so both survived. Fixed to `dumbbells` and `deep_knee_flexion`.

### Recipes and programmes can now have a form, and there is no screen to put it on

**Resolved by D18 — Z12 and Z13 now exist. Kept for the reasoning that led there.**

**Needs your word, and it decides whether meals and recipes can be managed one at a time or only in bulk.**

`ContentFormView` is parameterised by collection and draws whichever columns it can label. With the
recipe and programme labels now minted — `Recipe id`, `Minutes`, `Ingredients`, `Photo file`,
`Programme id`, `Weeks`, `Session length` — it can render a complete form for **all four** collections.

What does not exist is anywhere to route it. The design has eleven admin screens: Z03 is "Edit an
exercise" and Z05 is "Edit a food", and there is no Z-screen for a recipe or a programme. The markup is
also inconsistent about it: **Z06's add action opens Z05 — a food form — and Z07's opens Z08, the
importer.** Neither is what a person would expect from "add a recipe".

So Z06 and Z07 currently have **no add action at all**, which is honest: no dead button is drawn. The
options:

| | What it means |
|---|---|
| **Add two screens** (Z12, Z13) to the inventory and the markup | Recipes and programmes become manageable one at a time, like exercises and foods. Costs two screen ids and two entries in `screens-admin.mjs`, and changes the route count again |
| **Leave them import-only** | Recipes and programmes are authored by CSV and never by hand. Defensible — a recipe has ingredients and a photo, which is bulk-shaped work — but it means "add a meal from inside the app" is true of foods and not of recipes |

I have not invented the two screens. Adding screens the design never drew is a product decision, and the
inconsistency in the markup suggests this was never settled rather than deliberately decided.

### Minting a string is half the change

**Z05 was reported as "two strings short". It was two strings and two lines short, and the difference
mattered.**

`carbsG` and `fatG` are `required: true` food columns with no label, so `ContentFormView` did not draw
them, a food authored on Z05 went out with both empty, and `validateImport` refused the row — a form
that looked like it worked and could not produce an importable food. The obvious fix was to mint the two
labels, and that is what I did.

**It changed nothing.** `_labelFor` reads like a dynamic lookup and is a hardcoded `switch` over column
names ending `_ => null`. A column with a perfectly good dictionary entry and no case in that table is
still invisible. The fields only appeared once the two cases were added beside the strings.

The general form, worth remembering because this codebase has several tables like it: **a string existing
and a string being reachable are different facts.** The same applied to `_title`, which fell back to the
generic `Edit` with a comment explaining that "Edit an exercise" and "Edit a food" were not in the
dictionary — while `app_routes.dart` had been titling those very screens with exactly those two phrases.
The route table and the screen called themselves different things, and the dictionary agreed with
neither.

This is also why the check was worth making rather than assuming: nothing would have failed. The form
would have kept saving incomplete foods, the importer would have kept refusing them, and both would have
been behaving exactly as written.

### Three of the mockup's numbers are blocked on DATA, not on copy

**This changes what the remaining work is.** Having minted the parameterised forms for the three most
visible baked-in strings, I went to wire them and found the same wall behind all three:

| String | Parameterised form minted | Why it still cannot be used |
|---|---|---|
| `week3Of8` — Home's badge | `weekWeekOfTotal` | `WorkoutCard` takes `onStart`, `onRecall`, `evening`. **Nothing in `TodayDay` carries a programme week at all** |
| `walkThisMorning32Min` | `walkThisMorningMinutesMin` | `TodayDay.walkToCount` is a **bool**. Minutes would come from HealthKit or Google Fit; neither is integrated |
| `n410Kcal` / `n290Kcal` — Home's meal card | `kcalKcal` | `MealCard`'s plates are **hardcoded** (`name: l10n.fulAndBaladi, kcal: l10n.n410Kcal`). The card receives no meal data |

One was fixable without new data and is fixed: `train_view` read `programWeek ?? l10n.week3Of8`, so it
stated a week **precisely when the real one was unknown**. The fallback is gone; it now says nothing.

So the 160 counted strings are not one job. A large share need a screen to be **given her data**, which
is plumbing and in some cases an integration that does not exist. Minting copy for them first would move
the invention rather than remove it — the value would still be the prototype's, now wearing a
placeholder. The parameterised forms are minted and waiting; the guard stops the count growing meanwhile.

### A missing import in one folder makes every other folder look broken

**Worth knowing before someone spends an afternoon on it.** Four agents worked in disjoint folders at
once. Mid-session the Cycle agent reported **25 failures in `admin/` and `progress/`**, checked
carefully that no cycle code referenced either, and correctly concluded they were not its doing.

They were not anyone's doing. `lib/features/admin/presentation/import_check_view.dart` was momentarily
missing one import while it was being written. Dart compiles the **package**, so a single unresolved
import anywhere fails compilation everywhere, and unrelated suites report failures that have nothing to
do with them. It self-resolved within minutes.

The lesson for parallel work: **a red suite in someone else's folder is not evidence until the tree
compiles.** Check `flutter analyze` before attributing a failure — and when reporting across agents, say
what was running at the time, as both agents did here.

### Two things the Progress agent found that are not in its folder

* **P04's measurement control is below the fold** on a 390×844 phone — two of its own tests needed
  `ensureVisible` to reach it. It is reachable only by scrolling, which is a layout decision nobody
  made deliberately. Flagged, not silently designed around.
* **`weightLabel` lives in `lib/features/train/domain/weight_label.dart`** and Progress now imports it
  across feature boundaries. It belongs in `lib/domain/format/` beside `countLabel`, which is exactly
  where its sibling already is. Reported rather than moved, because a cross-cutting file move during
  four-way parallel work is how the phantom failures above happen.

### Home told every woman she was "Level 7 · Regular"

**Sixth baked-in mockup string, and the first where two screens contradicted each other about the same
woman.**

`TodayGreeting` rendered `l10n.level7Regular` — the literal "Level 7 · Regular" — in the pill beside the
day name. On the first screen after sign-up, a woman on level 1 was told she was on level 7. It also
named a **tier**, while P01, reading the same data, correctly showed none, because D6 records that no
tier ladder is authoritative.

Fixed in two parts, and the second matters more than the first:

* The level is now hers, via the newly minted `Level {n}` and `countLabel` for Western digits. Unknown
  renders **no pill at all** rather than a default.
* The tier half is **removed, not parameterised.** There is no authoritative ladder, so there is no true
  tier name to show. Home and Progress now agree, and both agree with what is actually known.

It is supplied from `AppRouter.progressSummary.level` — the *same derivation P01 uses* — rather than
from the stored `rewards.level`. Two screens computing one number two ways is how they drift apart, and
this defect is what that looks like when it has already happened.

The old test asserted `find.text('Level 7 · Regular')`, pinning it in place. The replacement uses a
fixture of **level 3**: a fixture equal to the mockup's own number passes whether the value is computed
or frozen, which is precisely why the original assertion could never have caught this.

### E01 told a woman that boiled eggs were a 540-calorie lunch

**The fifth baked-in mockup string, and the first one that misstates nutrition.**

Two functions in `eat_view.dart` chose a macro line by switching on `foodId` over a handful of
hardcoded cases, each ending `_ => l10n.n540Kcal18GProtein`. So **every food outside the list reported
koshari's 540 kcal and 18 g.** Two boiled eggs — genuinely 156 kcal and 13 g — rendered as 540 and 18 on
the screen where she decides what to eat. The dictionary already held `n156Kcal13GProtein`, the correct
figure, unused.

`_metaOf` carried a doc comment claiming the macros were "picked from the dictionary by the row it
describes, **so the row and its macros cannot disagree**". That was the one thing it could not
guarantee.

Both now compute from `ParsedItem` (`size × servings`, summed across a multi-food suggestion) through
two newly minted parameterised strings, with `countLabel` keeping the digits Western under `ar`. The
slot comes from the slot she is logging into — the one Log writes to — rather than a guess about when a
food is usually eaten.

`type_it_view_test.dart` had **documented this defect and worked around it**: "the row's line is a fixed
dictionary string with no placeholder form, so it reads the same whichever size is selected — asserting
on it would pass for a chip that does nothing." Correct at the time, and it means the project knew, in
writing, that a displayed number was decorative. That note is now updated: the line moves with the chip.

**The class, five times now:** `level7Regular`, `n22Of95G`, `thisWeekDoneOfTarget`, `myCyclePeriodDay2`,
and this. Every one is a mockup's sample frozen into the dictionary and rendered as though it were hers.

### Y03 rendered a blank screen, with 115 tests passing

**The clearest case yet for looking at the app.**

`CycleHubView`'s `notSetUp` branch was `const [SizedBox.shrink()]`. A woman who skipped cycle setup and
then tapped **My cycle** in My profile got a title bar, a settings gear, a navigation bar, and nothing
whatsoever between them — the "running, responsive and completely empty" page `main.dart`'s own comment
records as having shipped once before.

**Every cycle test passed.** All 115 of them supply a cycle document, because a null one was understood
to mean "this screen is never shown". That is true of Home's row, which is gated on exactly that state,
and false of the route, which My profile links to unconditionally. The view-model was correct, the view
was empty, and no assertion in the project looked at the pair.

Fixed by giving the branch a real empty state — Y01's own heading, subtitle and first option, so no copy
was invented — plus `onSetUp` wired to Y01. Four guards now cover it, including one that the branch
claims no date, phase or day number, since an empty state is the easiest place for a fabricated "period
day 2" to appear as filler. It also gave Y01 its first inbound edge, at depth 2.

**The pattern, three times in one sitting:** a green suite is evidence that the cases someone thought of
hold. E01 rendered its day-one branch for weeks; T01 showed a cycle card to women who had declined the
feature; Y03 rendered nothing at all. None was catchable without a screenshot, and each took one look.

### P0-NAV-01 is met — 82.6%, and the floor moved up twice with it

**Closed.** It stood at 79.2% against a target of 80%, was recorded here as an open shortfall, and fell
to **71.7%** when Phase 2's twenty-one screens joined the population. It now measures **37/46 = 80.4%**.

It was closed by building the design, not by moving the threshold. Two real defects:

1. **`AppAvatar` was rendered on no screen in the running app.** D11 says her profile picture is the way
   into My profile and the way a two-role woman switches between the trainee and coach apps. The
   component existed, had its own passing tests, and appeared only *inside* A02 — so `onOpenProfile` was
   passed by nobody, and **the coach side was unreachable for exactly the women who chose both roles.**
   That is D11 not actually shipped, hiding behind a green component test.
2. **My cycle's tab edges were invisible to the graph.** Y08 and Y10 hang off Y03's tab bar; the mapping
   lived first in a private helper, then in a `switch` expression passed as an argument. Both run
   correctly and both hide the literal screen ids from the reachability parser, so the same four screens
   were reported stranded twice for one cause in two costumes.

`_measuredFloor` moved 79.0 → **80.0**. Still beyond two taps: `R08 R09 R10 R13 E08` — the workout player,
which is a sequence and cannot be flattened without breaking the session model — plus `Y01 Y05 Y09 Y13`.

### `allow create` on `users/{uid}` could never have succeeded

**A deploy-blocking bug in the most security-critical file, found by reading rather than by running.**

`clientInvariants()` is AND-ed into `allow create`, and it calls `verificationUntouched()` → `touches()`
→ `changed()` → `request.resource.data.diff(resource.data)`. **`resource` is null during a create**, so
that expression errors, and an error in a rule denies the request. Creating her user document — the
first write this app ever makes, on the first screen after sign-up — would have been refused for every
woman, every time.

Firebase's field-level guide splits its own examples for this reason: `request.resource.data.keys()
.hasOnly(...)` for create, `request.resource.data.diff(resource.data).affectedKeys().hasOnly(...)` for
update. `changed()` now branches on `resource == null`, which also makes the invariants bite on create:
a document *born* with a `verification` map is refused, not only one that grows one later.

Nothing caught it because **the rules have never been executed.** There is no `firebase.json`, no
`functions/`, and no Java runtime on this machine, so no emulator can run. That is the same absence that
makes `P0-DEL-01` untestable, and it is now the single largest verification gap in the project.

### `eatConstraints` stays `DietaryConstraints.none` — re-verified, not inherited

The proposal was to derive it from the new `DietaryProfileRepository`. **Checked before doing it, and it
would have broken logging.** `DietaryProfile.unasked.toConstraints()` yields `unknown`, `AllergyGuard`
then fails closed on every dish, and §5.1 requires an acknowledgement sheet before logging under unknown
constraints. The three strings for that sheet — `thisDishHasAllergenYouToldUs`, `notThis`,
`logItAnyway` — exist **in the dictionary and in no widget anywhere.** The sheet is not built.

So the blocker did not disappear, it moved: from "the copy is missing" to "the screen is missing". Until
that sheet exists, deriving the value would make the Eat tab unable to log food at all.

### Who owns the cycle sharing grant — the spine and G9 disagree, and it is consent data

**Needs the owner, and it is not a detail.** `SCHEMA-SPINE.md` §8: the grant "lives ONCE, on the
relationship… G9 reads it; **G9 never writes it**". G9 §1.1/§7.2/OQ-2: `sharing{}` lives on
`cycle/current`, written by Y12. The Cycle flow is built to G9's reading.

Both are defensible. What makes it urgent is that this is a record of **what she consented to share about
her cycle**, so settling it after launch is a data migration of consent records, not a refactor.

### The deletion manifest is incomplete — three collections survive account deletion

**Safety finding, and it needs three rows added to a plan I do not own.**

`G7-profile-privacy-safety.md` §7.3's manifest is what `P0-DEL-01` deletes against — G7 is explicit
that it *is* the implementation, because **Firestore does not cascade-delete subcollections** and
every path must be enumerated. Its 34 rows do **not** include:

| Path | Owner | What survives |
|---|---|---|
| `users/{uid}/cycle/{docId}` | G9 | her cycle setup and sharing switches |
| `users/{uid}/periods/{day}` | G9 | every period date she logged |
| `users/{uid}/splits/{splitId}` | G4/G14 (D7) | the splits she authored herself |

All three are declared in the deployed `firebase/firestore.rules`. So as specified, **deleting her
account leaves her cycle data behind** — the most sensitive data in the product, on a screen that
tells her deletion means nothing survives.

This is now enforced rather than noted: `deletion_manifest_test.dart` parses the `users/{uid}` block
out of the real rules file and diffs it against the manifest, asserting the gap is **exactly** those
three. A fourth omission turns the build red instead of widening silently. The three rows were
**not** invented — the manifest still says 34, and the gap is named.

**What is needed:** G7 §7.3 gains three rows, with the owners above.

### P0-DEL-01 cannot be proven end to end in this repo

The case requires that the Auth record, the Firestore documents and the Storage files are all gone,
and that re-signing up with the same number gives a fresh account. **There is no `firebase.json`, no
`functions/` and no emulator configuration** — `firebase/` holds only rules and indexes. G7's own
integration test cannot be written here, let alone run.

The client half is built and tested: order is structural (`authLocked` ranks below every purge, which
ranks below `authDeleted`, and a server state moving backwards is rejected rather than believed),
deletion refuses to run offline with no optimistic state and no local tombstone, and the handset wipe
runs as an exact ordered list. But the end-to-end case stays **NOT COVERED** until there is a project
to run it against.

### T04 and T05 state facts the app cannot know — a copy decision, not a code fix

Found while fixing the same defect class on Eat and T01. Three screens rendered the
prototype's sample numbers as her personal facts; two of them cannot be fixed by
parameterising, because **there is no data to put in the placeholder**.

- **T01 is fixed.** `_day.week` already carried her real `sessionsLogged` and
  `sessionsTarget` — they were feeding the ring two lines below the hardcoded sentence, so
  a woman whose goal was 4 read "This week, 0 of 3". Now parameterised.
- **T04 ("After a quiet week")** renders *"Your 14 weeks are safe"* and passes literal
  `total: 3, filled: 0`. `QuietWeekView` receives a repository, a date and callbacks —
  **no week count of any kind**.
- **T05 ("When a tier slips")** renders *"Your 14 counted weeks"*, *"Level 7 and every
  point"*, *"Everything Regular opened"*. `TierSlipView` receives no tier, no level, no
  week count, and `TodayRepository` exposes none of them.

**T05 also contradicts D6 directly**, which says no tier number is authoritative until it
is written in this file. It currently ships three.

Both screens need the rewards engine that Phase 2 Flow 2 (Progress) builds — `WeekRollup`,
`TierPolicy`, the counted-week total. Until then the honest options are:

1. **Say less.** Drop the specific numbers and keep the reassurance: "Your counted weeks
   are safe", "You kept your level and every point". True for everyone, no invented data.
2. **Leave them until Flow 2 lands**, and parameterise once the numbers exist.

Option 1 is a copy change and needs your word, since it alters what two screens say. I have
not made it unilaterally. Recorded here rather than silently parameterised with fabricated
values — the defect being fixed is *exactly* the invention of plausible numbers.

### P0-NAV-01 does not meet its own 80% bar, and needs your call

Measured, not estimated: **19 of 24 reachable screens are within two taps of a tab root — 79.2%**,
against the case's 80%. `app/test/nav_reachability_test.dart` prints this on every run, pass or fail.

Everything that could be fixed by wiring has been. Three real defects came out of measuring it: the
bottom navigation bar on **Home did nothing at all** (`onSelectTab` was never passed to `TodayView`,
so tapping Train, Community or Eat from the landing tab was inert), **T07** was built and reachable by
nobody because `onOpenFirstWeek` was unwired, and **R06** was unreachable because all three "Short
ones that still count" tiles rendered without an `onTap`.

What remains is not a wiring gap. The screens still beyond two taps are `E08(3)`, and `R08(3)`,
`R09(3)`, `R10(4)`, `R13(3)` — the workout player. A session is a **sequence**: Train → Workout day →
Mid-set → Resting → Finished. No navigation design puts "Resting" two taps from a tab root without
breaking the session model.

So the choice is yours, and it is between two honest options:

1. **Accept it.** Deep in-flow steps are correct for a workout player, and the case's intent —
   "everything is two taps away" — is about *destinations*, not steps she is carried through. If so,
   the case should measure destinations only, and the 80% would be comfortably met.
2. **Change the navigation.** Give the session player more direct entries.

The suite currently defends a floor of 79% so regressions are caught — the case's own second clause,
"re-measure; regressions are defects" — and the floor may only ever move up. It has deliberately
**not** been lowered to 79.2% to manufacture a pass.

### An unresolved contradiction with a number attached

G9 states that **Y11 and Y14 are states of the Y03 route, not destinations**, and requires a
navigation-graph test proving no inbound edge to either. The router disagrees: `firstRunStates`
holds six ids and neither of these, so both are routable, and `routing_test.dart` pins
`appDestinations.length == 155` plus that exact six-member set. Honouring G9 makes it 153 and breaks
both assertions. Settle this **before** Cycle's screens are built, not during.
