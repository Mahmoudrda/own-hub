# Reconciliation — fifteen plans into one buildable spec

**All fifteen plans are in** (G1–G15, ~10,000 lines). Stage 2 is complete.

This is the bridge between planning and implementation. Independently-written plans are not a
specification until their conflicts are resolved and their arithmetic is added up. Read
`../../DECISIONS.md` first — it is authoritative and overrides anything here.

---

## 1. Defects found in the fixed inputs — all corrected

Every one was found by an agent reading the inputs critically rather than implementing them
obediently. This is the return on writing a spine and a rejection contract before any code.

| Found by | Defect | Fix |
|---|---|---|
| G2, G8 | **Per-group security rules cannot work.** Firestore grants access *"if any of the conditions is true"* and a specific rule cannot revoke what a broader one granted — so one permissive `match /users/{uid}` defeats the server-only guard on `verification.status`, the line that makes this women-only. **Verified against the official docs.** | G8 authors the single `users/{uid}` ruleset. |
| G13 | **The identical hazard on `coaches/{coachUid}`, owned by nobody** — three groups write under it. | G8 authors that ruleset too; invariants AND-ed outside the OR-ed slices. |
| G6 | **G8's first ruleset left points, weeks and tiers forgeable.** | G6 filed a delta; G8 adopted all of it. |
| G6 | **Spine C4 conflated commutative with idempotent** — an increment replayed offline pays twice. | Every increment travels with a deterministic id in the same transaction. |
| G5, G8 | **Spine C3 was wrong about same-slot merges** — two devices would lose a meal log. | `arrayUnion` + `increment`. |
| G4, G6, G10 | **Rule 11 would be false in production.** Firestore auto-indexes map subfields and array elements, so `sets.actualWeight`, `measurements.weightKg` and `followerCount` are queryable unless exempted. **Verified against the official docs.** | Single-field index exemptions are deployment artifacts, with a post-deploy query that must fail. |
| G4 | **My spine amendment introduced a scoring bug** — `unplanned` sessions earned full points. | The test is `!= 'live'`, so any future source is reduced-credit by default. |
| G9 | **`users/{uid}/cycle` is an odd-segment path** — Firestore reads it as a collection, so it could not hold the settings document. | `users/{uid}/cycle/current`. |
| G11 | **`relId` had three incompatible spellings** across parallel plans — load-bearing, because the Storage rules parse the id to decide who may read a shared file, so two spellings means a rule matching nothing. | Exactly `{coachUid}__{clientUid}`. |
| G12 | **G11's message rules did a parent `get()`** — one billed read per message read *and* write. | Denormalised uids; zero extra reads. |
| G14, G5 | **The libraries have no safety tags.** Without `exercises[].contraindicationTags[]` and `foods.allergens[]`, the avoid list, every `refer` outcome and the allergy guard are displayed but unenforceable — the filter has nothing to filter on. Found independently from opposite ends of the product. | Both are now mandatory fields, and a content obligation in the runbook. |
| G6 | **The P01 read budget was understated eightfold** — a range read bills per document. | A fixed 8-element array on a document already read at Home. |
| G9 | **The cycle sharing grant had two owners.** | It lives once, on the relationship, carrying `grantedForRelId`, so it dies with the relationship even offline. |
| G1 | **C13 greets her by name; no name field existed.** | `profile.firstName`, typed by her, never lifted off the ID. |
| G13 | **`app_routes.dart` declares routes for all six first-run states**, contradicting rule 16. | The router excludes them: 155 destinations of 161 screens, asserted by test. |
| G10 | **G4 said user media stays on Firebase Storage** — wrong by ~$708/month. | Community media follows the R2 + CDN path. |
| G1, G8 | **Two screens had zero coverage** — a regex that could not match an apostrophe dropped C03 and C13 silently. | Fixed; in-scope was 59, not 57. |
| *(coordination)* | **Three groups numbered their rule guards from 12**, so six real guards were dropped as duplicates — a suite that looked complete while missing coverage. | The generator **remaps** colliding ids instead of dropping them, and logs every remap. |

**Suite: 713 cases — 183 P0, 44 P1, 486 P2.** All ids unique, all rows 10 fields, no per-screen or
per-path gaps. 204 generated from the inventory, 509 specified by the plans and merged automatically.
**Regenerate with `python3 6-v2/scripts/build_testcases.py`.**

---

## 2. Conflicts the agents resolved between themselves

- **One undo implementation.** G3 owns `UndoableLog`/`LogCommandBus`; G4, G5 and G10 conformed.
- **The undo lives in a local draft, not Firestore's queue** — the documentation offers no way to
  cancel a queued write, so an offline undo would otherwise resurface on reconnect.
- **G8 conceded G4's signed-URL objection** — a signed URL is unique per request, collapsing the
  cache hit rate the zero-egress design depends on. Public, content-addressed, immutable URLs.
- **G6 declined G8's bucketed week sweep and G8 accepted** — bucketing splits an unbounded scan into
  60 slices rather than removing it.
- **G8 adopted G7's enum-typed analytics API** — no free-text property exists, so a privacy leak is a
  compile error rather than a review failure.
- **G11 recorded eight reconciliations** with the groups that converged on collections it owns,
  adopting their names wherever they were the consumer.

**Still genuinely conflicting, and it is a business question rather than a technical one:** G12
assumes authorise-then-capture on acceptance; G11 shows that is **impossible on Fawry and mobile
wallets**, which take the money up front. Two screens therefore promise different things. This is
rail-dependent and is now an owner decision in the runbook.

---

## 3. What this actually costs to run

Every group passed its own scalability gate. The sum tells a different story than any single plan.

| Line | Monthly at 35k DAU |
|---|---|
| G8 platform | ≈ $40 |
| G10 community | ≈ $25–30 |
| G5 eat | ≈ $19 (+ up to $420 if cloud speech is enabled) |
| G4 train, **including all video** | ≈ $8 |
| G3 today / G6 progress | ≈ $5 each |
| G12 coach app | ≈ $3 |
| G2 onboarding / G11 coaching | ≈ $2.60 / $2.10 |
| G7 / G13 / G14 / G9 | ≈ $2 / $1.20 / $0.58 / $0.51 |
| **Infrastructure total** | **≈ $115–145** |
| **The assistant (G15)** | **$4,860** |
| **ID-verification provider** | **$2,600 – $8,500** |
| **Amplitude at 100k MTU** | **$1,000 – $2,500** |
| **Phone-auth SMS** | **$250 – $3,750** |
| **Fixed recurring total** | **≈ $8,800 – $19,800** |
| *Payment processing (Paymob)* | *≈ $5,100 on 9.0M EGP of coaching GMV — scales with revenue, not a fixed cost* |

**Three conclusions.**

1. **Infrastructure is about 1% of the bill.** Optimising Firestore is misdirected effort; the
   leverage is in four third-party contracts. Video — long assumed to be the threat — is **$8**,
   because G4 and G8 independently chose R2 behind Cloudflare at $0 egress against $1,352 from
   Firebase.
2. **The assistant is the largest fixed line and nobody had costed it.** $4,860/month at an assumed
   15% adoption, swinging from $1,600 at 5% to $11,700 at 40%. G15 enforces a $5,000 ceiling with a
   four-step degrade ladder. **The model choice is an owner decision G15 deliberately did not take.**
3. **The read/write budget in the brief is obsolete at full scope.** G10 measures ~90 reads per
   community-active day against a figure of ~8 for the whole product. **Re-baseline it explicitly**
   rather than contorting designs around a number that no longer describes the product.

---

## 4. Open questions for the owner

Answered in `DECISIONS.md`: scope (D1), Firebase (D2), early editable intake (D3), rest weeks versus
skipping (D5, D5a), splits for both roles (D7), rejected-verification copy (D8), **Own Hub** and
`com.ownhub.app` (D9).

**Open, in order of what they block.** All are runbook rows marked **DECIDE NOW**.

1. **Apple may classify coaching as digital content** — then it must use Apple's payment system at
   30%, and an 80% coach share becomes arithmetically impossible on iPhone. **Get it in writing
   before the payment screens are built.**
2. **The payment rail decides what two screens may promise** — "pay only when she accepts" cannot be
   built on Fawry or wallets.
3. **The platform is merchant of record** — commercial registration plus ETA e-invoicing.
4. **The assistant's model and adoption assumption** — a $1,600-to-$11,700 monthly swing.
5. **Amplitude's tier** at 100k MTU.
6. **"Review" names two different things** — the weekly check-in, and a public star rating that has
   no home in the schema. H01/H02 already display 4.8★ that nothing stores, and rule 11 makes a
   public rating awkward.
7. **Offers are authored in three unreconciled places** (K04, B06, K18).
8. **Public immutable CDN URLs are capability URLs** — a leaked link is fetchable by anyone. The
   signed-cookie alternative is $20–40/month and must be decided **before** the CDN contract.
9. **Community voice notes are entirely unowned** — no storage, playback or moderation story.
10. **The Y11 care directory cites NHS guidance, which is British** — it needs an Egyptian clinical
    reviewer.
11. **Minimum age, visible follower counts, the before/after guardrail, the trans-women policy,**
    moderation and reviewer staffing. Policy, not engineering.

## 5. Honest limits, recorded rather than hidden

- **"Revokes immediately" cannot be true offline.** The copy says "as soon as you have signal".
- **Deletion cannot reach an encrypted on-device photo store on a second handset**; the wipe is
  eventual, and A02's "download everything" is narrower than the words.
- **P04 progress photos are local-only** — they do not survive a reinstall and cannot be exported.
- **Blur cannot be proved server-side.** The device is trusted to have applied it.
- **An already-exported ad file cannot be recalled** when consent is withdrawn.
- **Progression provenance is unowned** — R07's "so we added 2 kg" has no authored source.
- **On-device reel blur speed on budget Android is unmeasured.**

## 6. The architecture was checked, not recalled

`app/ARCHITECTURE.md` records the implementation decisions and the official sources each was verified
against: Flutter's layering and MVVM guidance, Firestore rule composition, index exemptions, and
offline write semantics. Two spine constraints exist *because* of what the documentation says rather
than despite it — last-write-wins is the only documented conflict strategy, and no API is documented
for cancelling a queued write.

## 7. State of the build

Flutter 3.47.4 / Dart 3.13.3. `flutter analyze` clean, `flutter test` green, **both platforms build**
as `com.ownhub.app` / **Own Hub**. `flutter doctor` reports no issues on any line.

Built so far: design tokens, localisation with RTL, the font pipeline, routing for all 155
destinations, and the first domain primitives — the week model (rule 3), prescribed-versus-actual
(rule 1), and the logging command bus (rule 9) — each with tests citing the case ids they implement.
The 161 screens, the data layer and the backend are next.
