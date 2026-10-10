# Phase 3 — plan, acceptance suite and QA

**19 September 2026.** Phase 3 is "everything involving another person": community, the coaching
marketplace, the coached life, the coach's own app, her portfolio, her planning tools, and the
assistant.

**This document is the plan. It is not a promise that Phase 3 can start on Monday.** Phase 1 and
Phase 2 could be built because their blockers were content. Phase 3's blockers are **money, ownership
and clinical safety**, and three of them are not engineering problems at all.

Read §1 first. If §1's items are not settled, building §5 in order produces screens that look finished
and are fiction.

---

## 1. Start here — what Phase 3 is actually blocked on

> **AMENDED 19 September 2026, after the owner answered.** Most of this section is now settled, and
> the build has started. The reasoning below is kept because it explains *why* each answer matters,
> but read these resolutions first:
>
> | | Was | Now |
> |---|---|---|
> | **§1.1 Apple** | "a launch blocker" | **Resolved.** 3.1.3(d) names fitness training; 1:1 coaching may use Egyptian rails. One-to-many would still need IAP |
> | **§1.2 Money** | unowned | **Unblocked for building, not for shipping (D21).** Built against a `PaymentProvider` seam that refuses honestly; **nothing ever fakes a successful payment**. Refund window 48h, platform absorbs the fee, buy-direct removed. Merchant-of-record registration is still owed before real money moves |
> | **§1.3 Safety chain** | four links missing | **Being built now** in `lib/domain/safety/` |
> | **§1.4 Pregnancy** | "the most serious silence" | **Closed, more strictly than the spec (D22).** `LifeStageSafetyPolicy` derives avoid-tags automatically and blocks publishing while clearance is refused in the 0–6 week window — **and she can declare her life stage in her own profile**, with the more protective reading winning where a coach's assessment disagrees |
> | **§1.5 Assistant** | Opus 5 vs Sonnet 5, ~$4,860/mo | **Neither — Gemini Flash (D23).** Provider goes behind a seam. The structural guarantees are vendor-independent and must survive the change: key never in the app, ids-and-template-keys on the wire, classifier first, subject bound from auth, and the assistant cannot write |
> | **§1.6 Ownership** | six conflicts | **All six settled.** One composed `coaches/{coachUid}` ruleset; K27 drafts land in `planDrafts.origin='assistant'`; **K04 is the only writer of offers**; `publicProfiles` and `media/*` approved; `insights/*` deferred so B12 cannot render zeros |
>
> **Community's launch scope narrowed (D24):** photos and text only, likes and comments visible,
> follower counts hidden, **video and voice notes deferred**. Not a cut for its own sake — reel blur
> export is unmeasured on a budget handset, and a slow export makes women switch blur off, which is a
> rule 6 failure by user experience rather than by code.
>
> **Everything ships behind feature flags (D25)**, Phase 3 defaulting off, so a half-built flow can be
> merged without reaching a woman.
>
> **Still open, and it blocks the store rather than the build (D26): the minimum age, 16 or 18.**


### 1.1 RESOLVED TODAY — Apple does **not** force in-app purchase on 1:1 coaching

`PHASES.md` names this as one of two questions that could reshape the phase, and `G11` OQ-4 calls it
"**a launch blocker, not a detail**": if Apple classified coaching as digital content, IAP's commission
would make an 80/20 coach split arithmetically impossible on iPhone.

**It does not.** App Store Review Guideline **3.1.3(d) Person-to-Person Services**, retrieved
19 September 2026 from `developer.apple.com/app-store/review/guidelines/`:

> "If your app enables the purchase of real-time person-to-person services between two individuals
> (for example tutoring students, medical consultations, real estate tours, or **fitness training**),
> you may use purchase methods other than in-app purchase to collect those payments. **One-to-few and
> one-to-many real-time services must use in-app purchase.**"

Fitness training is named. So H03/H04 may charge through Egyptian rails, and the 80/20 split survives.

**Three consequences that must be designed in, not discovered later:**

1. **One-to-one only.** The moment coaching becomes one-to-many — a group programme, a live class, a
   paid challenge, a cohort — the same clause forces IAP and the 80/20 split breaks *for that product*.
   Any future group offering needs its own commercial model. Worth writing into `DECISIONS.md` now,
   while it is cheap.
2. **3.1.3 forbids in-app steering.** The same guideline says apps in that section "cannot, within the
   app, encourage users to use a purchasing method other than in-app purchase," with a US-storefront
   carve-out. The payment screens must present the rails plainly, not as an *alternative to* Apple.
3. **This is a reading of a public guideline, not a ruling.** `RECONCILIATION.md` asks for it "in
   writing". The wording is now clear enough to build against; an App Review escalation is still the
   cheapest insurance before H04 ships.

### 1.2 NOT RESOLVED — the money side of the product has no owner

This is now the single largest hole in Phase 3, and it is worse than the Apple question because no
external body can answer it for us.

* **The 80/20 split is specified nowhere mechanically.** It appears as an OQ, and as `shareEGP` inside
  a `PaymentSettled` event. **Nothing specifies where 80% is configured, computed, audited, or
  reconciled.** G12 Q7 states it plainly: "payments, escrow, the 80% split and payouts are absent from
  the spine entirely… the money side of the product is unowned."
* **The platform becomes the merchant of record.** G11 OQ-5: collecting 1,800 EGP and paying out 80%
  "makes it the merchant, requiring commercial registration, a tax card, and ETA e-invoicing for both
  the client's receipt and the coach's payout. **No amount of code removes it.**"
* **Two specs promise different payment mechanics and neither may be averaged.** G12 assumes
  authorise-then-capture on acceptance; G11 shows that is impossible on Fawry and mobile wallets.
  G11 §11-R7's resolution — card → authorise/capture/void; Fawry and wallet → capture/refund — is
  correct and **G12's text has not absorbed it**. Until it does, K09 and H04 promise different things.
* **The refund clock has no value** (OQ-2) and **the refund fee has no bearer** (OQ-3, ~EGP 3,400/month
  of pure loss at the modelled volume).
* **K09/H04's copy is currently false on one path.** OQ-1: "She pays only once you accept" is true on
  the enquiry path and false on buy-direct. Either the sentence changes or buy-direct is removed.

**Rails, for when this is settled.** Paymob lists 2.75% + 3 EGP for local sales and ships an explicit
**MarketPlace** product for sub-merchant split payouts — which is the shape this product needs, and
worth evaluating before anything bespoke is built. Fawry quotes roughly 1.5–2.5% depending on method
and volume. Both retrieved 19 September 2026; treat as indicative and confirm in a contract.

### 1.3 NOT RESOLVED — the safety chain is four links short

The chain that makes an avoid list real runs:

```
admin content (contraindicationTags)  →  ClientConstraintResolver  →  ClientConstraints
      →  ExerciseCandidateFilter  →  W04 / K20 / SplitApplicator / the assistant's tool
```

**Link 1 is done.** `contraindicationTags` exists in `content_schema.dart`, and the seeded library
carries per-exercise values in exactly G14 §1.5's ten-token vocabulary. G14's OQ-1 is stale on the
content side — a real improvement since it was written.

**Links 2–5 do not exist.** `ClientConstraintResolver`, `ClientConstraints`, `ExerciseCandidateFilter`,
`PrescriptionOnlyValidator`, `SplitApplicator` and `ReferralRegistry` have **zero implementations**.

G14's own gate — "ship nothing that claims to honour an avoid list until the tags exist" — now reads
**"until the filter exists."** Any coach screen that shows an avoid list before then is a safety claim
the product cannot keep.

### 1.4 NOT RESOLVED, AND NOT FLAGGED BY ANY SPEC — pregnancy and postpartum

The most serious silence found while planning this phase.

G14 records `lifeStage ∈ pregnant | p0_6w | p6w_1y | over_1y | none`, `birthType`, and
`clearance{granted}`. **None of them restricts what may be prescribed.**

* `lifeStage` is not an input to `ExerciseCandidateFilter`; the filter's only inputs are
  `avoid ∪ ReferralRegistry.activeTags(latestAssessment)`.
* `clearance.granted == false` is recorded and displayed. It gates nothing and blocks no publish.
* **G15 assumes a `lifeStage → avoid[]` derivation exists** ("reaches the model only as derived tokens
  inside `avoid[]`"). **G14 never specifies it and no component owns it.**
* `painNotes` is deliberately inert — a coach writing "diastasis, 4-finger gap" changes nothing.
* **No clinical review is required anywhere in G14** — not for the exercise pack, not for the
  `suppresses[]` mappings, not for postpartum progressions. The word "clinical" appears once, in a
  non-blocking OQ about who may clear a referral.

So for a pregnant or postpartum client the only operative safety mechanism is the coach manually
ticking avoid chips. That may be a defensible product position. **It has never been stated as a
decision, it is untested, and it contradicts what G15 believes.** Raise it as blocking.

### 1.5 NOT RESOLVED — the assistant's cost and model choice

Verified against `claude.com/pricing`, 19 September 2026: **Opus 5 $5/$25 per MTok · Sonnet 5 $2/$10 ·
Haiku 4.5 $1/$5 · Batch API −50%.** G15's figures are correct.

G15 models **≈$4,860/month** at 220,000 questions — "the second-largest operating cost in the product,
~50× the entire Firebase and CDN bill" — and states that **nobody has supplied an adoption rate**
(at 40% it is $11,700/month; at 5% it is $1,600).

The concrete lever, now that pricing is confirmed: **Sonnet 5 is 2.5× cheaper than Opus 5 on input and
output.** G15 declines to make that call — "this plan does not downgrade a model to save money — that
is the owner's call, not an implementer's" — and that is the right instinct. It is an owner decision
worth roughly $3,800/month.

The architecture already protects the downside: a hard $5,000/month ceiling, per-woman and per-coach
daily caps enforced *before* any model call, and a four-step degrade ladder ending in a kill switch
that leaves X03 readable so the honest description survives the feature being off.

### 1.6 Ownership conflicts that must be settled before code

| # | Conflict | Who settles it |
|---|---|---|
| 1 | **`coaches/{coachUid}` ruleset has no owner.** G13 flags the hazard, G14 avoids it by matching three distinct sub-paths, **G15 reintroduces it** with a fourth block. Firestore ORs `allow` across blocks, so one permissive rule silently defeats the consent guard and the certificate guard | Spine owner, before any coach rules deploy |
| 2 | **K27's meal draft has two destinations.** G15 writes `coaches/{coachUid}/mealDrafts/{draftId}`; G14 routes both K26 and K27 into `planDrafts.origin='assistant'` and never grants `mealDrafts`. G14 has declined by silence | G14 + G15 owners |
| 3 | **Offers are authored in three unreconciled places** — K04, B06 and K18. Two screens writing one field is a rejected plan | Before B06 or K04 |
| 4 | **`publicProfiles/{uid}` is not in the spine.** Without it "no woman can render another woman's name, and M07 is unbuildable" | Spine owner |
| 5 | **`media/*` and `insights/*` are G13 inventions with no home.** B12 and B13 are unimplementable as specified | Spine owner |
| 6 | **Coach root fields don't exist.** `coaches/{coachUid}` is "missing every field H01/H02 render" — specialties, city, price, rating, spots, reply speed | G12 |

---

## 2. The acceptance suite — and the fact that it is incomplete

Extracted mechanically from `TEST-CASES.csv` (714 rows: 183 P0, 44 P1, 486 P2) by classifying each
row's `screens` column.

**151 P0/P1 cases are Phase-3-only. 15 more also touch a Phase 1/2 screen.**

| Journey | P0 | P1 | | Journey | P0 | P1 |
|---|---|---|---|---|---|---|
| `ASK` assistant | 16 | — | | `PLAN` planning | 5 | — |
| `COM` community | 16 | 9 | | `SPLIT` splits | 5 | — |
| `PORT` portfolio | 10 | — | | `MEAL` coach meals | 4 | — |
| `PAY` payments | 9 | — | | `ADS` ads | 3 | — |
| `COACH` marketplace | 8 | — | | `INTAKE` | 3 | — |
| `CONSENT` | 6 | — | | `REVIEW` | 3 | — |
| `MSG` messaging | 6 | — | | `ASSIGN`/`CSCALE`/`PUB`/`QUEUE`/`SHARE` | 2 each | — |
| `ASMT` assessment | 5 | — | | `CCHAT`/`CDAY` | 1 each | — |
| `CVER` coach verification | 5 | — | | `RULE` product rules | — | 18 |
| `ENQ` enquiry | 5 | — | | `HRULE` | — | 3 |

**Totals: 121 P0 + 30 P1.** Against Phase 2's 34, this is **4.4× the acceptance load.**

### 2.1 Two corrections to that number, in opposite directions

**It overstates the new work.** Of the 18 `P1-RULE` rows, most are existing global guards re-applied to
new screens: `-09B` is rule 9 on coached screens, `-11B` is rule 11 on marketplace screens, `-01B` is
rule 1 on coached screens. `product_rules_test.dart` enforces rules 3, 7, 8, 9 and 11 by **source scan
across `lib/`**, so those extend to Phase 3 files automatically as they appear. Genuinely new rule
assertions are needed mainly for the assistant (`-10A`, `-10B`).

**A claim to distrust — checked, and it is false.** G13 and G15 both state that their rows are *not*
in the CSV: G13:646 says "`tests/TEST-CASES.csv` covers **none** of B01–B14", and G15:454 says "**The
CSV is not edited by this plan**". Taken at face value, that would mean ~108 missing rows and zero
portfolio coverage, and the first job of Phase 3 would be to merge them.

**Both statements are stale.** Verified directly against the file:

* `P0-ASK-01` … `P0-ASK-18` in the CSV match G15's own ids **exactly — all eighteen**.
* G13's families are present too: **`PORT` 10, `ADS` 3, `PUB` 2**.

So the rows were merged after those sentences were written, and the specs describe the moment before.
**Do not re-merge them** — that would duplicate ids and corrupt the census.

What remains true is the paperwork around them: `tests/README.md` is **stale**, describing a scope the
merged rows no longer use and saying "those eleven tests" for a P1 tier the CSV now carries **26** rows
for. A suite whose README describes a different scope than its rows is how a QA pass silently skips a
tier. Fix the README and the two spec sentences; leave the rows alone.

**The census above is therefore the real figure, not a floor.**

### 2.2 Cases that reach across phases

15 rows touch a Phase 1/2 screen as well. Verify the Phase 3 half and mark the rest **not yet
reachable**, never failed — the convention Phase 2 used.

Notably `P0-CYC-13`, `-14`, `-15` and `P0-SHARE-02/03` all land on **G02 (support and sharing)** and
**W02/W09** — the cycle-sharing grant Phase 2 settled as D13. These are the rows that finally prove
D13 end to end, and they cannot pass until G9's `CycleSharingProjection.build()` exists, which it
does not.

---

## 3. Baseline — what exists today

Measured, not assumed:

* **Zero of Phase 3's screens have a route builder.** All of them fall through to "Not built yet".
  Every route id already exists in the generated `app_routes.dart` (174 screens), and every screen
  exists in the prototype — so this is wiring and implementation, not design.
* **`lib/features/` has nine folders** — account, admin, cycle, eat, onboarding, progress, signup,
  today, train. Phase 3 adds **seven more**: community, coaching, coached, coach, coachbrand,
  coachplan, assistant.
* **No Phase 3 collection is referenced anywhere in `lib/`** — `planDrafts`, `assessments`,
  `mealDrafts`, `assistantQuota`, `portfolio` all have zero string references; `splits` has one.
* **`AllergyGuard` exists and is tested** — G14's "reuse, don't rebuild" is actionable today, and must
  be honoured: "a safety rule with two implementations has one that is weaker."
* **No Cloud Functions exist at all.** Phase 3 needs, at minimum: `createCheckout`, an HMAC-verified
  payment webhook, refund initiation, `onSharingChanged`, `onRelationshipEnded`, the queue maintainer,
  the debounced `lastMessageAt` writer, `buildCoachDirectory`, `publishPortfolio`, `publishCoachPlan`,
  the recount task, the followGraph mirrors, `assistantAsk` and `assistantDraft`.

---

## 4. The domain rules Phase 3 must enforce

These become assertions. They are quoted because precision matters more than brevity.

**Community.** Fan-out on read, never on write — "a post is written once, whatever the author's
follower count"; `P0-COM-02` asserts one document write for 0 followers and for 5,000. Blur is on by
default, applied **on-device before upload**, and a draft with `blurApplied == false` cannot be
constructed without an explicit per-image opt-out token that is itself recorded; the next composition
starts with blur on again. Nothing is ranked — enforced by **single-field index exemptions**, because
Firestore auto-indexes every field and the absence of a composite index is not sufficient;
`FollowerCount` deliberately does not implement `Comparable`. No roster surfaces: "4,210 women are not
a roster to scrape." Report copy offline must read "Not sent yet… the hour starts then" and **never**
"a moderator is reading it."

**The honest limits, which must be tested as limits:** blur cannot be proven server-side — the device
is trusted; blocking is "a contact and experience boundary, not a confidentiality one"; and community
media is deliberately never cached offline, because "it is other women's bodies."

**Marketplace.** A coach's message never changes a plan — enforced four ways, including an **AST test**
that fails if the string `plans/` appears anywhere in the message repository or its imports. Sharing is
four independent booleans, **all defaulting false**, with no master switch to build. A grant dies with
the relationship and can never be inherited by the next coach. `shared/constraints` carries **never
cycle data, under any switch**. A coach's window is exactly three documents "and nothing else, ever."
The app never handles card details — a hosted page in a Custom Tab, never an in-app WebView. **A
redirect is not a receipt**: `paid` is written by the webhook after HMAC verification. Payments are
idempotent by provider transaction id. Buying offline is a hard no.

**Planning tools.** A split is a template, not a plan — copied **by value**, so there is "no code path
by which editing a split reaches a published plan — not a guard, an absence." The assessment is the
only source of constraints, and **no coach screen has a text input for `avoid` or allergies**. A coach
may not override an allergy — "she is the authority on her own body; a coach is not." No invented
nutrition: one unresolved ingredient means **no numbers at all, not a partial total**. Free prose is
never a safety input. `refer` is an outcome, never a failure, and **a referral cannot expire, decay, or
be cleared by silence**. Publishing is the only act that changes a plan, and W09 and K22 both end at
DRAFT. No `actual*` field exists at any depth — rule 1 is "not a discipline, it is a shape."

**Portfolio.** Consent is checked at **read time, never copied at publish**. A coach cannot author a
result: rules reject her writing `mediaIds`, `quote`, `numbers`, `scope` or `consentState`. Numbers are
derived, never typed, from an allowlist that **excludes weight and weight-lost**. No free-text
certificates. Offline ad export is refused, because a stale-consent export is the one irreversible
action in the group. Contrast thresholds are exact (3.0:1 for display/headline only, 4.5:1 for
everything else) with a shared Dart/Node fixture so the two implementations cannot drift.

**Assistant.** The Function never writes Firestore on the assistant's behalf — "there is no server path
from a model token to a published plan," enforced three ways including an IAM permission the service
account does not have. The model returns **ids and a template key, never a number** — so an invented
quantity is unrenderable because no field on the wire can carry one. The cheap classifier runs first
and the expensive model is never called on a medical question. The subject is bound from `request.auth`,
never a tool argument — "no tool takes a uid." Server-side model fallbacks are deliberately **off**,
recorded so a future engineer does not "fix" the refusal rate by enabling them. And when it does not
know, every path lands on the same answer: **return nothing and say so.**

---

## 5. Build order

`PHASES.md` fixes the sequence inside a flow: repository + fake → domain rules + tests → view models →
screens → P0 cases as executable tests → rules and indexes. Phase 3 changes nothing about that. What it
adds is that **three things must precede all seven flows**, because every flow needs them and building
them seven times is how they drift.

**Step 0 — before any flow.**

1. **Fix `tests/README.md`, and correct G13:646 and G15:454.** The rows themselves are already merged
   (§2.1) — what is broken is the documentation around them, which currently tells the next reader the
   suite is missing 108 rows that are in fact present.
2. **Build the safety chain: `ClientConstraintResolver` → `ClientConstraints` → `ExerciseCandidateFilter`.**
   Links 2–4 of §1.3. It is a domain-only piece, needs no screens, is fully testable today against the
   seeded library, and **four separate surfaces depend on it**. Filter before selection, never validate
   after — matching `AllergyGuard.screen()`, deliberately, because "two safety guards with different
   shapes is how one of them ends up weaker." Include the fail-closed path: unresolved constraints
   yield the quiet, low-impact, floor-based subset, because "an unknown constraint is not an absent one."
3. **Settle the `coaches/{coachUid}` ruleset ownership** (§1.6 #1) before a single coach rule deploys.

**Then, in this order.**

| # | Flow | Screens | Why here |
|---|---|---|---|
| 1 | **Coach app** | K01–K07, K09, K16–K18, K24, K25 | Nothing else in Phase 3 works without a coach record. It also owns the missing `coaches/{coachUid}` fields that H01/H02 render, and coach verification — which must never be automated |
| 2 | **Planning tools** | W01–W11, K19–K23 | Consumes step 0's filter. Largest spec, highest safety surface, and independent of payment |
| 3 | **Community** | M01–M17 | Fully independent of money. Highest read volume, so its cost model wants proving early. Needs ~40 Arabic strings and curated group content that nobody owns yet |
| 4 | **Portfolio** | B01–B14 | Depends on the coach record; H02 renders the same widget |
| 5 | **Coached life** | G01–G17 | Depends on `publishCoachPlan` and on G2 assignment fields that do not exist — "these screens are fiction" without them |
| 6 | **Marketplace + payments** | H01–H06 | Deliberately last: it is blocked on §1.2, which is commercial, not technical |
| 7 | **Assistant** | X01–X03, K26, K27 | Last because it consumes every other library, and because its model choice is an open owner decision worth ~$3,800/month |

Community could move earlier if the money questions drag — it is the only large flow with no financial
dependency.

---

## 6. QA plan

### 6.1 What Phase 1 and 2 taught, applied here

Six defects in Phase 2 were found **by looking at the app while the suite was green**, and several more
by reading rather than running. Phase 3 is more exposed to both, because it has more surfaces and more
cross-group seams. Concretely:

* **Router journey tests are mandatory per flow, not optional.** Phase 2 shipped 331 green admin tests
  over a console whose rows could not be opened, because every test built the screen directly and
  handed it data. Each Phase 3 flow gets a `*_router_journey_test.dart` that drives the **real** router.
* **Every safety guard needs a negative control.** The Phase 2 seed proved its allergens by blanking one
  and asserting the validator rejects it. Without that, a guard test can pass over a guard that never
  fires.
* **Mutation-test the safety chain.** For `ExerciseCandidateFilter` specifically: break it three ways —
  return the unfiltered list, ignore referral tags, drop the fail-closed subset — and confirm distinct
  tests go red. Assert nothing about test quality that has not been demonstrated.
* **Read the generated getter names.** Never infer a localisation symbol from its English text.

### 6.2 Assertions that need a shape, not a check

Several Phase 3 rules are specified as **structural impossibilities**, and testing them as behaviour
would be weaker than the spec:

| Rule | Test it as |
|---|---|
| A message cannot reach a plan | An **AST/source test** — the string `plans/` absent from the message repository and its imports |
| No `actual*` in a prescription | A **schema scan at every depth**, plus `PrescriptionOnlyValidator` throwing |
| Nothing ranked | **Index-exemption deploy assertions** — `P1-COM-01` requires an `orderBy followerCount` query to *fail* |
| No API key in the app | **Unzip the APK and IPA**, grep every asset, string table, native library and Remote Config default |
| The assistant cannot publish | **CI import-graph assertion** plus the absent IAM permission |
| The word "AI" is off-screen | **Dictionary lint**, not review |

### 6.3 What QA must refuse to sign off

* Any screen rendering an avoid list before `ExerciseCandidateFilter` exists (§1.3).
* Any prescribing surface for a pregnant or postpartum client until §1.4 is decided by a named owner.
* Any payment screen before §1.2's merchant-of-record and split questions are answered — the code can
  be written; it must not be shipped.
* Any coach rules deploy before §1.6 #1 names one owner for `coaches/{coachUid}`.
* **Anything at all in the Firestore rules**, until the emulator runs. No rule in this project has ever
  been executed; Phase 3 roughly doubles the ruleset and adds the first rules where one permissive
  clause silently defeats a consent guard.

### 6.4 Verdict format

Same as Phase 2: judge each case **PASS / FAIL / NOT COVERED**. "Not covered" is a real result and is
never rounded up to a pass. A phase is not finished while anything is red.

---

## 7. Content and staffing obligations that are not engineering

Listed because the build cannot create them and will otherwise silently ship without them.

1. **Curated groups** — M04 is "never empty (curated groups ship with the app)" and `groups` is
   Function-written by a content pipeline no spec owns. No group list, no slugs, no Arabic blurbs exist.
2. **~40 Arabic community strings** — G10 explicitly will not invent them.
3. **Moderator tooling and rostering.** Moderation is "Admin SDK only": no console, no reviewer queue,
   no SLA owner, no appeals, and no enumeration of which report classes hide on sight. A04 promises a
   one-hour response; code cannot keep that promise, only rostered people can.
4. **A reported story can expire before it is read** — 24h TTL against a one-hour promise that only
   holds during staffed hours. "Evidence disappears exactly when it matters." A 30-day moderation hold
   is proposed and has PDPL implications.
5. **Community voice notes are entirely unowned** — a whole content type with no moderation story.
6. **Clinical review** — see §1.4. Nothing in the specs requires it.
7. **Commercial registration, tax card, ETA e-invoicing** — see §1.2.
