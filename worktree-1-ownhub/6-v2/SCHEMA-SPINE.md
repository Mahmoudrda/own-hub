# Data spine — fixed input to every planning agent

**Status: decided. A planning agent may not renegotiate this file.** It may *extend* its own group's
collections, and it must flag a conflict rather than quietly diverge — but the paths, the ownership
table and the eight hard constraints below are settled.

## Why this exists

Groups 1–7 all read and write the same woman's data. Eight agents each inventing a Firestore layout
produces eight incompatible schemas, and the implementation agent can then consume none of them. That
is the failure the §6 rejection contract's *"explicit interface to the other groups"* clause was
written to prevent, so the interface is fixed here first rather than negotiated afterwards.

Every cost figure below is against `BUILD-BRIEF.md` §3: **35,000 DAU, ~8 reads / ~6 writes per active
day, 40% of traffic between 19:00 and 23:00 Cairo.**

---

## 1. Collection layout

```
users/{uid}                                   owner: G1    the woman's own document
  ├─ roles          { held: ['trainee'|'coach'], active: 'trainee'|'coach' }    G1
  │                 REPLACES the single immutable `role` enum — DECISIONS.md D11.
  │                 She picks trainee, coach or both at C08, and one who holds
  │                 both switches the whole app by tapping her profile picture.
  │
  │                 The split is the security design, not bookkeeping.
  │                 `held` is SERVER-WRITE ONLY: a trainee must not be able to
  │                 grant herself coach privileges by writing her own document,
  │                 and earning 'coach' still goes through the coach application
  │                 and its certificate checks. `active` is CLIENT-WRITABLE,
  │                 because choosing which of her own apps to look at is not a
  │                 privilege. G1's old "role is unwritable a second time" rule
  │                 is rewritten to keep the first half and drop the second.
  │
  │                 Readers must treat `active` as a preference, never as an
  │                 entitlement: `held` can shrink (a lapsed certification), so
  │                 anything authorising on role checks `held`.
  ├─ profile        { firstName, goal, days, sessionLength, place, equipment[],
  │                   allergies[], dietary[], language, lifeStage }             G2
  │                 firstName ADDED after G1 planning: C13 greets her by name and
  │                 no field existed to hold one. She types it herself — it is
  │                 never read off the ID, because the ID images are deleted (rule
  │                 7) and lifting a legal name onto a social profile is not what
  │                 she consented to.
  ├─ verification   { status, method, decidedAt, reviewerPath }  SERVER-WRITE ONLY   G1
  ├─ rewards        { points, level, tier }                                     G6
  ├─ privacy        { blurDefault, shareWithCoach{}, discoverable }             G7
  ├─ notify         { mealNudge, sessionReminder, permissionState }             G7
  └─ weeklyGoal     { sessionsTarget, countedWeeks, restWeeksBanked, currentRun } G6

                    privacy/notify ADDED after G7 planning: the ownership table
                    had no row for either, so two groups could each have claimed
                    them. Every sharing switch is independent and defaults to OFF
                    (HANDOFF rule 6), and `blurDefault` is on (rule 6). Note the
                    honest limit G7 recorded: "revokes immediately" cannot be true
                    on a device that is offline, so the copy must not promise it.

users/{uid}/weeks/{yyyy-Www}                  owner: G6    e.g. 2026-W38
      { sessionsTarget, sessionsLogged, counted, repairedByRestWeek, closedAt }

users/{uid}/checkins/{yyyy-MM-dd}             owner: G3
      { energy?, cramps?, appetite?, sleep?, bloating?, bleeding? }   all nullable

users/{uid}/sessions/{sessionId}              owner: G4
      { planVersion?, assignmentId?, startedAt, completedAt?, durationSec,
        source: 'live'|'recalled'|'unplanned', activity?,
        sets: [ { exerciseId, order,
            prescribedWeight?, prescribedReps?,
            actualWeight?, actualReps?, skipped } ] }        sets are EMBEDDED

      AMENDED after G3/G4 planning: `planVersion` and `assignmentId` are nullable
      and `source` gains `unplanned`, so a walk or a studio class has somewhere to
      live. T02 offers exactly that and the original shape made it unstorable.
      `prescribedWeight`/`prescribedReps` are nullable for bodyweight and
      time-based moves — C8 still forbids one shared field for prescribed and
      actual, which is the rule that matters.

      **Consequence of that amendment, and a bug it introduced.** The reduced-credit
      rule was written as `source == 'recalled'`, so adding `unplanned` silently made
      a logged walk earn *full* points and become eligible for a personal best. The
      test is **`source != 'live'`**: only a session logged live, as it happened,
      earns full credit or sets a personal best. Any new `source` value is therefore
      reduced-credit by default rather than by amendment. Test `P0-LOG-12` covers it.

users/{uid}/meals/{yyyy-MM-dd}                owner: G5    ONE doc per day
      { slots: { breakfast: [item], lunch: [...], dinner: [...], snack: [...] },
        totals: { kcal, protein } }
      item = { foodId, servings, size, loggedAt, source: 'planned'|'search'|'voice' }

users/{uid}/bests/{exerciseId}                owner: G6    deterministic id, no query
users/{uid}/measurements/{yyyy-MM-dd}         owner: G6    weight/measurements, private
users/{uid}/devices/{deviceId}                owner: G8    push token, locale, platform

  NOT A FIRESTORE PATH — corrected after G8 planning. The outbound write queue was
  written above as `users/{uid}/syncQueue/{opId}`, which contradicted its own
  annotation: a path under `users/{uid}` is a Firestore collection by definition, so
  "local-only, never uploaded" could not be true of it. The queue is a **local
  sqflite table**, it has no Firestore path at all, and the rules deny one.

plans/{uid}/versions/{version}                owner: G2    published plan, immutable once published
plans/{uid}/assignments/{yyyy-MM-dd}          owner: G2    dated workout + meal assignment

exercises/{exerciseId}   ADMIN-WRITE   the 124-move library
      { name, equipment[], pattern, media{}, contraindicationTags[] }
foods/{foodId}           ADMIN-WRITE   verified Egyptian food library
      { name, portions[], macros{}, allergens[], dietTags[] }
recipes/{recipeId}       ADMIN-WRITE   { ..., allergens[], dietTags[] }
programs/{programId}     ADMIN-WRITE   starting programs for O05

      AMENDED by DECISIONS.md D12 (admin content console, plan G16). These four
      were READ-ONLY to every client and writable only by the Admin SDK, which
      left **no way to author the library from anywhere** — and the library is
      empty, which is precisely why `P0-EAT-01` cannot pass and why the exercise
      safety filter has nothing to filter on.

      They are now **admin-write, everyone-else-read**, gated on
      `request.auth.token.admin == true` — the same custom-claim pattern
      `token.verified` and `token.coachV` already use. A member still cannot
      write them, and the claim is server-set, so nobody can grant it to
      herself. Read stays `signedIn()`: the library is behind the women-only
      gate like everything else.

      **`contraindicationTags[]`, `allergens[]` and `dietTags[]` are mandatory, not
      enrichment.** Raised independently by G14 (exercises) and G5 (foods), which is
      what makes it certain rather than an opinion. Without them the safety rules
      are decorative: rule 13's avoid list and rule 14's `refer` outcome have
      nothing to filter on, and the allergy guard cannot tell whether a dish
      contains nuts. Both filters run BEFORE selection and fail closed, so a
      missing tag must read as "unknown, therefore unsafe" — never as "safe".
      Knowing a dish is koshari does not tell the app whether it contains nuts, and
      knowing a move is a squat does not tell it whether it loads the pelvic floor.
      **This is a content obligation with a code deadline**, tracked in the
      deployment runbook.

verificationJobs/{jobId}                      NO CLIENT ACCESS    G1, functions only
```

---

## 2. Ownership — who writes what

| Collection | Writes | Reads |
|---|---|---|
| `users/{uid}` root | G1 (create), G2 (profile), G6 (rewards, weeklyGoal) | all |
| `users/{uid}.verification` | **Cloud Function only** | G1, G8 (gate) |
| `weeks/*` | G6 | G3, G6 |
| `checkins/*` | G3 | G3, G4 |
| `sessions/*` | G4 | G4, G6 |
| `meals/*` | G5 | G5, G6 |
| `bests/*`, `measurements/*` | G6 | G6 |
| `devices/*` | G8 | G8 |
| `plans/**` | G2 | G2, G3, G4, G5, **and a coach under an active relationship** (G11, G12, G14) |
| libraries | nobody (content pipeline) | all |

A group that needs a field in another group's collection **requests it in its plan**; it does not add
it. Two groups writing the same field is a rejected plan.

> **The `users/{uid}` security rules are authored ONCE, by G8, as a single block.** Raised by G2 and
> it is the most consequential correction to this file. Firestore evaluates `allow` statements as a
> logical **OR** across every matching rule block: one permissive block anywhere grants access no
> matter how carefully a sibling block denies it. Per-group rulesets would therefore let an innocuous
> `allow update` on a profile field silently defeat C5's server-only guard on `verification.status` —
> and C5 is the line that makes this a women-only app. Groups supply their field-level *requirements*
> to G8; G8 writes the one ruleset, and `P1-RULE-07`/`P1-RULE-08` plus an unauthorised-write test
> prove it.
>
> **The same hazard applies to `coaches/{coachUid}`, and nobody owned it.** Raised by G13. Three
> groups write rules under that path — G12 (profile, offers), G13 (portfolio, results, ads) and G14
> (splits, assessments) — so one permissive `allow` among them grants what the other two deny, exactly
> as it did for `users/{uid}`. **G8 authors the single `coaches/{coachUid}` ruleset too**, on the same
> terms: the three groups supply field-level requirements, G8 composes them, and the global invariants
> are AND-ed *outside* the OR-ed per-group slices. A published portfolio is world-readable; everything
> else under that path is hers alone.

---

## 3. Eight hard constraints

**C1 — Deterministic document IDs on everything a woman writes offline.** `checkins`, `meals`,
`weeks`, `measurements`, `bests` and `assignments` are keyed by date, ISO week or exercise. This is
not tidiness: it is what makes an offline retry idempotent. A random ID replayed after a reconnect
creates a duplicate log, and duplicate logs corrupt week counting. `sessions` may use a client-side
UUID generated once at session start and reused for every retry.

**C2 — Sets are embedded in the session document, not a subcollection.** A session has at most ~30
sets. Embedded, opening a finished session is 1 read; as a subcollection it is 30. Logging a set is
one `update` to one document roughly once every 60–90 seconds, which is far inside Firestore's
per-document write ceiling.

**C3 — One meal document per day, not one per meal.** The Eat screen shows today's whole day, so
per-meal documents would make it an N-read query. Keyed by date it is **1 read**, and the running
total lives in the same document.

> **CORRECTED after G5 planning.** The original claim — that writing into `slots.<slot>` merges
> commutatively — is only true *across different slots*. Two devices offline writing into the **same**
> slot would have one overwrite the other's array, losing a log. Same-slot writes must therefore use
> `arrayUnion` for items and `FieldValue.increment` for the totals, or key the items by `itemId` in a
> map rather than holding them in an array. Test `P0-LOG-11` exists to catch this specific regression.

**C4 — Counters use `FieldValue.increment`, never read-modify-write.** Points, counted weeks and
sessions logged are commutative and offline-safe only as increments. A read-then-write counter loses
data on a reconnect race.

> **CORRECTED after G6 planning: commutative is not idempotent.** The original wording conflated the
> two, which is the difference between a safe counter and one that double-pays. An increment applied
> twice adds twice, so an offline write that replays on reconnect awards the points again. **Every
> increment must travel with the creation of a deterministic id — `awardId`, `weekId` — inside the
> same transaction**, so the replay fails on the duplicate id instead of succeeding twice. "An
> increment never travels alone." Test `P0-RWD-01` exists to catch exactly this.

**C5 — `verification.status` is written by a Cloud Function and by nothing else.** If a client can
write its own verification flag, a women-only app has a one-line bypass. Security rules must deny
client writes to that map outright, and every gated read must check it server-side too. This is the
single most security-critical line in the schema.

**C6 — No field named `streak`, and no daily-consecutive counter, exists anywhere.** Rule 3 is
enforced by making it unstorable. A UI cannot render what the schema cannot hold. Any plan that
introduces one is rejected.

**C7 — No composite index on weight, weight lost, or follower count.** Rule 11 is likewise enforced
at the storage layer: the sort cannot be executed because the index does not exist. `measurements` is
private to its owner and is never queried across users.

> **A single-field index *exemption* on `sessions.sets` is mandatory, not optional.** Raised by G4.
> Firestore auto-indexes every field by default, including the members of the embedded `sets` array —
> so without an explicit exemption, `sets.actualWeight` *is* indexed and rule 11 is simply false in
> the deployed project no matter what the code says. Absence of a composite index is not sufficient;
> the exemption has to be declared in `firestore.indexes.json` and checked as part of deployment.
> The same applies to `measurements`.

**C8 — Prescribed and actual are separate, differently-typed fields.** `prescribedWeight` is
non-null; `actualWeight` is nullable and starts null. Rule 1 cannot be violated by a widget because
there is no single field for a widget to pre-fill. Adherence counts non-null `actualReps` only.

---

## 4. Read budget for the P0 journeys

The §3 allowance is ~8 reads per active day. Measured against this layout:

| Screen | Reads | Detail |
|---|---|---|
| `T01` Today | 4 | user doc, today's assignment, today's check-in, current week |
| `R03`→`R10` a full session | 2 + 1 | assignment, exercise metadata (cached), 1 write per set |
| `E01` Eat | 2 | today's meal doc, suggestion source (cached) |
| `P01` Progress | 2 | user doc, current week — see the correction below |
| **Typical day** | **~7** | inside budget, with the libraries served from cache |

> **CORRECTED after G6 planning: a range read is not one read.** The original budget costed P01's
> "last 8 weeks" as a single range read. Firestore bills **per document returned**, so that query is
> 8 reads, not 1 — the line item was understated by a factor of eight. G6 replaced it with a fixed
> 8-element `weeklyGoal.recent8` array on the user document, which is already read at T01, bringing
> P01 to 2 reads and 0 additional network reads when reached from Home.

The libraries (`exercises`, `foods`, `recipes`, `programs`) are immutable content. Bundle them or
cache them with a long TTL and a Remote Config version stamp — **never read them per session.** They
are the difference between 7 reads a day and 40.

Composite indexes required by this design: **none on the hot path.** Every hot read is a direct
document get or a single-field range on a date-keyed collection. If a plan needs a composite index on
a P0 journey, that is a signal the access pattern is wrong — say so in the plan.

---

## 5. Offline contract (G8 owns; every group conforms)

- Firestore offline persistence is **on**, unbounded cache.
- Writable offline: every `users/{uid}/**` write. Logging never requires signal.
- Not writable offline: verification (needs a live provider), anything under `plans/**`
  (server-authored).
- Conflict policy: field-level merge on distinct keys (C3), increments for counters (C4),
  last-write-wins only for single-owner scalars like `profile.goal`.
- The UI shows queued-not-synced state on the affected row, never a blocking spinner, and never a
  failure for something that will sync.

## 6. Analytics (G8 owns)

Amplitude, tracking plan written before any event is emitted. **Never sent, at any time:** phone
number, name, ID verification result, weight, any measurement, any photo or media reference, any
cycle or check-in data. This is a PDPL constraint, not a preference. Events carry the screen ID and
a coarse outcome only.

---

## 7. What a planning agent must do with this file

1. Use these paths and names verbatim.
2. Extend only inside its own collections.
3. Name any conflict, missing field or wrong assumption in its **Open questions** section — the
   rejection contract makes silence a defect.
4. State its own read/write cost against §4 and say plainly if it exceeds the budget.
5. Write its security rules as code against these exact paths.

---

## 8. Extension — the full product (added after the owner removed the MVP cut)

`DECISIONS.md` D1 puts all 161 screens and 131 features in scope. These collections complete the
layout. **Everything in §1–§7 still holds**; this extends it, and the same rule applies — a group may
extend inside its own collections and must flag a conflict rather than diverge quietly.

```
# Community — owner: G10
posts/{postId}               { authorUid, groupId?, kind: 'photo'|'reel'|'story'|'best',
                               media[], blurred, caption, parentPostId?, createdAt,
                               counts: { likes, comments } }
posts/{postId}/comments/{id} { authorUid, body, createdAt }
followGraph/{followerUid}/following/{followeeUid}   { createdAt }
followGraph/{followeeUid}/followers/{followerUid}   { createdAt }
groups/{groupId}             { name, kind, memberCount, createdAt }
groups/{groupId}/members/{uid}
reports/{reportId}           owner: G7   { reporterUid, targetRef, reason, state, createdAt }

# Cycle — owner: G9.  The most sensitive data in the product.
users/{uid}/cycle/current    { mode, contextFlags, adaptation{} }   default OFF
users/{uid}/periods/{yyyy-MM-dd}   { start, end?, stillBleeding, editedAt }
      Daily symptoms already live in users/{uid}/checkins/{yyyy-MM-dd} (G3).

      CORRECTED after G9 planning. This was written as `users/{uid}/cycle`, which
      is an ODD number of segments — Firestore alternates collection/document, so
      that path names a *collection* and cannot hold a settings document at all.
      The document is `users/{uid}/cycle/current`. Same defect class as the
      `syncQueue` path G8 caught; both are now fixed and no other §8 path has it.

      OWNERSHIP, also raised by G9: the sharing map had two owners — this entry and
      `relationships/{relId}.sharing` (G11). One switch with two homes drifts. The
      grant lives ONCE, on the relationship, carrying `grantedForRelId`, so a grant
      dies with the relationship even on a device that is offline. G9 reads it; G9
      never writes it.

# Coaching relationship — owner: G11
coaches/{coachUid}           { displayName, verifiedCerts, serviceHours, acceptingClients }
relationships/{relId}        { coachUid, clientUid, status, startedAt, endsAt,
                               sharing{}, grantedForRelId, offerId }
      relId is EXACTLY `{coachUid}__{clientUid}` — double underscore. Fixed after
      G11 found three incompatible spellings across the parallel plans. This is
      load-bearing rather than cosmetic: the Storage rules parse the id to decide
      who may read a shared file, so two spellings means a rule that silently
      matches nothing. Deterministic, so a relationship cannot be created twice.
relationships/{relId}/messages/{msgId}   { senderUid, body, attachments[], readAt }
relationships/{relId}/reviews/{reviewId} { dueAt, answers{}, coachResponse?, planVersion }

# Coach authoring — owner: G12 (app), G13 (portfolio), G14 (planning tools)
coaches/{coachUid}/portfolio/{version}   { published, theme{}, blocks[] }   see HANDOFF.md
coaches/{coachUid}/offers/{offerId}      { name, price, currency, lines[], badge? }
coaches/{coachUid}/splits/{splitId}      { name, cycleLength, daySlots[], carryApproved }
coaches/{coachUid}/results/{resultId}    { clientUid, consentState, consentedAt,
                                           withdrawnAt?, media[], blurred, numbers{}, quote }
coaches/{coachUid}/ads/{adId}            { portfolioRef, format, headline, body, cta, media }
assessments/{assessmentId}   { coachUid?, clientUid, takenAt, stage, birthType,
                               clearance{}, avoid[], painNotes, screening[], baseline{} }

# Splits belong to whoever authored them — D7 makes this both roles
users/{uid}/splits/{splitId}             { name, cycleLength, daySlots[], source: 'library'|'own' }

# The assistant stores nothing. Drafts land in the author's own draft collection.
```

### Ownership additions

| Collection | Writes | Reads |
|---|---|---|
| `posts/**`, `groups/**`, `followGraph/**` | G10 | G10, G11 |
| `reports/**` | G7 | G7 |
| `users/{uid}/cycle`, `periods/*` | G9 | G9 only — never a coach unless sharing is on |
| `coaches/{coachUid}` root, `offers/*` | G12 | all (public profile) |
| `coaches/**/portfolio/*` | G13 | all |
| `coaches/**/splits/*`, `assessments/*` | G14 | G14, G11 |
| `coaches/**/results/*`, `ads/*` | G13 | all, **only while consent is active** |
| `relationships/**` | G11 | G11, the two parties only |
| `users/{uid}/splits/*` | G4 (client-authored, D7) | G4, G11 |

### Four more hard constraints

**C9 — Fan-out on READ, never on write.** A post is never copied into followers' feeds. A feed is
assembled by reading the authors she follows. A write that grows with follower count is the exact
failure the scalability gate rejects, and it is unfixable after launch without a migration.

**C10 — A client result is publishable only while consent is active.** `consentState` is checked at
read time, not copied at publish time. Withdrawal hides it immediately and everywhere, including
inside already-rendered ad creatives (HANDOFF rule 10).

**C11 — Blur is applied on-device before upload, and defaults on.** No unblurred image ever reaches
Storage. This holds for community posts, follow-ups, coach media and client results alike (rule 6).

**C12 — Cycle data is never readable by a coach unless she has turned that sharing switch on**, and
turning it off revokes the coach's derived panels. Switches are independent and default OFF
(HANDOFF rule 6). Cycle data is never sent to analytics under any circumstance.
