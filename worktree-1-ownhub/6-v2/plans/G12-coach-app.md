# G12 — Coach application core

Her sign-up, her certificates, her verification, her clients, her day, her conversations, her
enquiries. **13 screens: `K01`–`K06`, `K07`, `K09`, `K16`, `K17`, `K18`, `K24`, `K25`.**

Inputs obeyed: `DECISIONS.md` (authoritative; D1 — everything ships, no MVP cut), `BUILD-BRIEF.md`
§2/§3/§4/§6 (§0 ignored per D1), `SCHEMA-SPINE.md` incl. §8, `flutter/HANDOFF.md` 17 rules,
`plans/RECONCILIATION.md`, `tests/TEST-CASES.csv`.

**The one-line posture:** a coach passes **two** verifications — G1's identity check (she is a woman)
and G12's credential check (a human cleared her certificates) — and the second mints a separate
server-only claim `coachV`. She cannot accept a client without it, and she never reads a client
document: everything she sees about a client is a **Cloud-Function-materialised projection filtered by
the client's own sharing switches**, so a rules mistake cannot leak what the switch denies.

---

## 0. Scope — planned against what exists, not against a stale reference

Verified against `src/inventory.mjs`, `src/all-screens.mjs` and `flutter/app_routes.dart`.

| | Screens | Where the markup lives |
|---|---|---|
| **Mine (13)** | `K01`–`K06`, `K07`, `K09`, `K16`, `K17`, `K18` | `src/screens-coach.mjs` |
| | `K24` (state) | `src/screens-firstrun.mjs` |
| | `K25` | `src/screens-firstweek.mjs` |
| **Not mine — G14** | `W01`–`W11`, `K19`–`K23`, `K26`, `K27` | `screens-coachplan.mjs` |
| **Not mine — G13** | `B01`–`B14` | `screens-coachbrand.mjs`, `screens-coachbuild.mjs` |
| **Not mine — G11** | `H01`–`H06`, `G01`–`G17` | `screens-coaching.mjs`, `screens-coached.mjs` |

**`K08` and `K10`–`K15` do not exist.** The consolidation onto the W-flow retired them; they are
absent from the inventory, the routes file and every source module. There is no coach-side inbox,
client list or planner in this plan — `W10`, `W01` and `W03`–`W09` are G14's, and this plan links to
them rather than duplicating them. A plan that revives `K10`–`K15` is planning a screen that has no
markup, no route and no ARB string.

There is no `src/screens-coach-setup.mjs`. `coach-setup` is a **flow id**, not a file: `K01`–`K06`
live in `screens-coach.mjs`.

---

## 1. Data model

### 1.1 Spine paths I own, verbatim (§8 ownership table)

```
coaches/{coachUid}                  writes: G12   reads: all (public profile)
coaches/{coachUid}/offers/{offerId} writes: G12   reads: all (public profile)
```

### 1.2 `coaches/{coachUid}` — the public root

Everything in this document is world-readable once `listed == true`. Nothing sensitive may live here.

| Field | Type | Writer | Notes |
|---|---|---|---|
| `displayName`, `city`, `tagline` | string | coach | `K01` |
| `photoRef` | string? | coach | content-addressed, immutable URL (G4/G8 CDN convention) |
| `photoBlurred` | bool | coach | **defaults `true`** (rule 6). Unblurring is an explicit named action, `K01` |
| `specialties` | string[] | coach | `K03`, **max 3** — enforced in rules |
| `languages`, `clientPlaces` | string[] | coach | `K03` |
| `capacity` | `{ max:int, taken:int }` | `max` coach, **`taken` CF only** | `K04`; `max` ≤ 200 |
| `acceptingClients` | bool | coach | may only be `true` when `coachV` is held |
| `serviceHours` | map | coach | spine field; the reply-time promise `K07` measures against |
| `replyTimeP50Mins` | int | **CF only** | `K18` "measured, not typed" — 30-day rolling p50 |
| `verifiedCerts` | bool | **CF only** | the badge `H02` renders |
| `listed` | bool | **CF only** | false until verified; gates the public read |
| `updatedAt` | Timestamp | both | `freshStamp()` (G8 convention) |

**No rating, follower or weight field exists on this document** — rule 11 enforced as unstorable
(§1.5, §6).

### 1.3 Extensions inside my own collections (declared, not smuggled — spine §7.2)

| Path | Access | Why it is not on the root |
|---|---|---|
| `coaches/{c}/certificates/{certId}` | self read, self create, **CF-only state** | `K02`. `{ body, title, issuedAt, expiresAt?, mediaRef, state, decidedAt, failReason }` |
| `coaches/{c}/private/desk` | **self read, CF write only** | `K07`/`K24`/`K25`/`K06` in **one** document. `{ queue[≤30], overflowCount, oldestWaitingSince, verification{}, firstWeek{}, earningsSummary{}, builtAt }` |
| `coaches/{c}/private/payout` | **self read, CF write only** | `K05`. `{ method, providerToken, holderName, maskedTail, updatedAt }` — the raw wallet number never reaches Firestore |
| `coaches/{c}/earnings/{yyyy-MM}` | self read, **CF write only** | `K17`. `{ gross, share, lines[], payoutDate, payoutState, asOf }` |

**`verification` and `firstWeek` are deliberately NOT on the public root.** `K25`'s own copy —
*"no client sees your progress through it"* — is a schema requirement, not a UI preference, and
`verification.failReason` on a world-readable document would publish a rejection.

### 1.4 What I read and never write

| Path | Owner | Screen |
|---|---|---|
| `users/{coachUid}` (own `verification`, `role`, `locale`) | G1 | gate before `K01` |
| `relationships/{relId}` | **G11** | `K09`, `K07` queue items |
| `relationships/{relId}/messages/{msgId}` | **G11** | `K16` |
| `relationships/{relId}/clientView/current` | **G11** (requested, §7.3) | `K16` banner, `K07` rows |
| `coaches/{c}/portfolio/{version}` | G13 | `K18` → `B01` |
| `assessments/{assessmentId}` | G14 | constraints, read-only (HANDOFF 13) |

**I never read `users/{clientUid}/**` from a coach session.** Not "should not" — the rules deny it
(§6). This is the mechanism that makes HANDOFF rule 6 and spine C12 true rather than promised.

### 1.5 Indexes

| Index | Fields | Serves | Hot path? |
|---|---|---|---|
| composite | `relationships`: `coachUid ASC, status ASC, lastActivityAt DESC` | roster page ≥2 (`W01`, `K07` overflow) | no — warm |
| composite | `relationships`: `coachUid ASC, status ASC, enquiredAt ASC` | enquiry queue, oldest first (`K09`) | no — warm |
| automatic | `certificates.state`, `earnings` doc id | `K02`, `K17` | yes, ≤6 docs |
| **exemption** | `coaches`: `capacity.taken`, `replyTimeP50Mins`, and any future numeric | rule 11 / C7 | — |

**The exemption is mandatory, for the reason G4 found and `RECONCILIATION.md` row 7 records.**
Firestore auto-indexes every field, so "we never sort coaches by X" is false in the deployed project
unless `firestore.indexes.json` says so. A single-field index on `capacity.taken` is a ready-made
"least busy coach" leaderboard; on a rating field it would be a ranking of women. Declared and
CI-checked at deploy, exactly like `sessions.sets` and `measurements`.

**`K07` and `K24` — the only screens a coach opens every day — need zero composite indexes.** Both
are two direct document gets. Per spine §4 that is the signal the access pattern is right.

### 1.6 Population assumptions (stated, because §3 counts clients only)

| Quantity | Assumption | Basis |
|---|---|---|
| Coached clients | 5% of 100k MAU = **5,000** | marketplace conversion; owner to confirm (Q10) |
| Listed coaches | **1,000** (headroom; ~420 at a 12-client average) | `K07`/`K18` show 12 of 20 |
| Applications | **2,000** (2× listed — some never clear) | |
| Daily active coaches | 60% of 1,000 = **600**, ~3 opens/day | desk-bound, not microbus-bound |

Coaches are **1.7% of the 35,000 daily actives**. Their traffic is a rounding error; the design
constraint is not aggregate cost, it is that *one* coach with many clients must not fan out.

---

## 2. The query for every screen, with index and cost

Reads are billed **per document returned** (the correction `RECONCILIATION.md` row 9 records — a
range read is not one read).

| Screen | Query | Index | Cold reads | Warm | Writes |
|---|---|---|---|---|---|
| `K01` | `get coaches/{me}` | — | 1 | 0 | 0 (local draft) |
| `K02` | `get coaches/{me}` + `list certificates limit 10` | auto | 1+n (n≤5) | 0 | 1 create/cert + Storage put |
| `K03` | cached from `K01` | — | 0 | 0 | 0 (local draft) |
| `K04` | cached from `K01` | — | 0 | 0 | 0 (local draft) |
| `K05` | `get private/payout` | — | 1 | 1 | 1 callable (`setPayoutMethod`) |
| `K06` | `watch private/desk` → `verification` | — | 1 | 0 (listener) | 0 |
| **`K07`** | `get coaches/{me}` + `watch private/desk` | — | **2** | **0–1** | 0 |
| **`K24`** | identical — same route, empty branch | — | **2** | **0–1** | 0 |
| `K09` | `get relationships/{relId}` | — | 1 | 0 | 1 callable (`coachEnquiryDecision`) |
| `K16` | `get clientView/current` + `messages orderBy createdAt DESC limit 20` | auto | 21 | deltas only | 1/message |
| `K17` | `get earnings/{yyyy-MM}` | — | 1 | 0 | 0 |
| `K18` | `coaches/{me}` (cached) + `list offers limit 20` | auto | 0+m (m≤6) | 0 | 1/edit |
| `K25` | `private/desk.firstWeek` (cached from `K07`) | — | **0** | 0 | 0 |
| **Setup, once** | `K01`→`K06` end to end | | **~8** | | ~5 |
| **Typical evening session** | `K07` → 2 chats → `K17` | | **~45** | **~8** | ~20 |

`K16` dominates and is the only place worth optimising: message history is `limit(20)` with a cursor,
and Firestore's offline persistence means a re-opened thread pays **deltas, not 20**.

### 2.1 The client-list query, and what happens at 200 clients

This is the question the group exists to answer. **A coach with 60 clients must never trigger 60
reads on screen open, and she does not.**

`private/desk.queue` is a **CF-maintained aggregate**: at most 30 items, each ~200 B, each carrying
only what a row renders (`relId`, initial, display name, one waiting-reason string, `waitingSince`).
Everything below the cap collapses into `overflowCount`.

| Roster size | `K07` reads | queue items | full list (`W01`, G14) | desk doc size |
|---|---|---|---|---|
| 0 (`K24`) | 2 | 0 | — | ~1 KB |
| 12 | 2 | 12 | 1 page | ~3 KB |
| 60 | **2** | 30 + overflow 30 | 3 pages × 20 | ~7 KB |
| 200 (product cap) | **2** | 30 + overflow 170 | 10 pages × 20 | ~7 KB |

Reads on `K07` are **constant at 2, independent of roster size.** The paginated list is a warm path
behind the composite index in §1.5, 20 documents per page, cursor-based — never a full-collection
read and never an `offset`.

**The write-rate question, which is the real limit.** The desk document is a single document, and a
coach with 200 clients receives 200× the event rate of a coach with one. Firestore's sustained
soft limit is ~1 write/second/document.

- **Rebuilds are debounced to at most one write per 60 s per coach**, via a Cloud Tasks dedup key
  `desk_{coachUid}_{minuteBucket}`. Ceiling: **1,440 writes/day/coach regardless of client count.**
  Realistic: ~40.
- Verification and earnings changes bypass the debounce (they are rare and must be immediate) and
  write disjoint fields with `merge`.
- At 200 clients × 5 evening messages = 1,000 events in the 4-hour peak, the debounce emits **240
  writes**, i.e. 0.017/s — 60× under the limit. The bound holds because it is a function of *time*,
  not of client count. No sharding is needed, and none is designed in: sharding would add reads to
  `K07`, which is the one screen that must stay at 2.

### 2.2 Monthly figure

| Line | Volume/month | Cost |
|---|---|---|
| Reads | 600 coaches × 45 × 30 ≈ 810k (worst, no cache) | $0.49 |
| CF writes (desk, earnings) | 1,000 × 40 × 30 = 1.2M | $2.16 |
| Coach writes (profile, offers, messages counted by G11) | ~90k | $0.16 |
| Certificate images (2 MB × 3 × 2,000, retained) | 12 GB | $0.26 |
| **G12 total** | | **≈ $3 / month** |

Against `RECONCILIATION.md` §3's ≈$75–95 infrastructure total, G12 is noise. **The coach side's real
costs are not infrastructure**: human certificate review (Q4) and payment-processing fees (Q2) are,
like verification and SMS on the client side, orders of magnitude larger.

---

## 3. State machines

### 3.1 Coach verification — `CoachVerificationStateMachine.transition(current, event, ctx)`

Eight states. A **pure function**, in `functions/src/coach/verification_state_machine.ts`, and the
**only** code path that writes `private/desk.verification`, `coaches.verifiedCerts`,
`coaches.listed` or the `coachV` claim. No callable, console or webhook touches them — the same
posture G1 took for `users/{uid}.verification`, for the same reason (spine C5).

| State | Meaning | `listed` | `acceptingClients` allowed | Can accept an enquiry |
|---|---|---|---|---|
| `setup_incomplete` | `K01`–`K05` unfinished | false | false | **no** |
| `submitted` | ≥1 certificate uploaded, `K06` | false | false | **no** |
| `docs_checking` | automated issuing-body lookup | false | false | **no** |
| `human_review` | a woman reviewer has claimed it | false | false | **no** |
| `verified` | cleared | **true** | true | **yes** |
| `rejected` | not cleared | false | false | **no** |
| `expired` | every certificate lapsed | **true** (page stays) | false | **no** |
| `suspended` | report upheld / payout fraud | false | false | **no** |

| From | Event | To | Side effects |
|---|---|---|---|
| `setup_incomplete` | `SETUP_COMPLETED` (≥1 cert + payout + `capacity.max`) | `submitted` | desk rebuild; `K06` |
| `submitted` | `LOOKUP_STARTED` | `docs_checking` | watchdog armed T+24 h |
| `docs_checking` | `LOOKUP_PASS` (all certs `verified`) | `verified` | `verifiedCerts=true`, `listed=true`, **`coachV` claim minted**, `firstWeek.certsCleared=true` |
| `docs_checking` | `LOOKUP_UNDECIDED` / any cert needs eyes | `human_review` | reviewer queue (women reviewers only, D8 wording) |
| `human_review` | `REVIEWER_PASS` | `verified` | as above |
| `human_review` / `docs_checking` | `REVIEWER_FAIL(code)` | `rejected` | `failReason` coarse code; re-upload path stays open |
| `rejected` | `CERT_REPLACED` | `submitted` | attempt counter++, ceiling 3 then `suspended` |
| `verified` | `ALL_CERTS_EXPIRED` | `expired` | **claim revoked**; existing clients keep their coach; no new enquiries |
| `expired` | `CERT_RENEWED` → pass | `verified` | claim re-minted |
| `verified` | `REPORT_UPHELD` / `PAYOUT_FRAUD` | `suspended` | `listed=false`, claim revoked, G7 notified |
| any | `ACCOUNT_DELETED` | — | G1's `onAccountDelete(uid)` hook (G7's convention) |

**`expired` deliberately keeps her page live and her clients intact.** Revoking a coach mid-plan
would punish the client for the coach's paperwork. She loses *new* clients, not current ones.

### 3.2 A certificate — `CertificateStateMachine`

| State | Set by | Notes |
|---|---|---|
| `local_pending` | device | offline; file queued, nothing uploaded yet |
| `uploaded` | device | bytes in Storage under `coach-docs/{coachUid}/` |
| `checking` | CF | issuing-body lookup |
| `verified` | CF | `expiresAt` recorded if the body issues one |
| `rejected` | CF | coarse `failReason`; she may replace it |
| `expired` | CF (scheduled) | lazily, on read — no sweeper (G6/G8's "lazy, no scheduler" precedent) |

### 3.3 The enquiry lifecycle

The document is G11's (`relationships/{relId}`, `relId = {coachUid}_{clientUid}`, deterministic → C1
idempotent). **G12 owns the coach-side transitions only**, through one callable.

| State | Meaning | Capacity | Money |
|---|---|---|---|
| `enquiry` | she asked; `K09` shows it | not held | authorised, **not captured** |
| `accepted` | coach said yes | **`taken`++** | captured into escrow |
| `active` | intake done, plan published (G11) | held | released per `H04`'s promise |
| `declined` | coach said no | unchanged | authorisation voided |
| `expired` | 72 h with no decision | unchanged | authorisation voided |
| `withdrawn` | client pulled out first | unchanged | authorisation voided |

| From | Event | To | Side effects (one transaction) |
|---|---|---|---|
| `enquiry` | `COACH_ACCEPT` | `accepted` | assert `coachV` ∧ `taken < max` ∧ `status == 'enquiry'`; `taken` increment; capture; desk rebuild; `firstWeek.firstClient=true`; notify client |
| `enquiry` | `COACH_DECLINE` | `declined` | void authorisation; neutral copy (`K09` "Not a fit for me"); no capacity change |
| `enquiry` | `TTL_72H` | `expired` | void; client told, coach's reply-time stat unaffected by an expiry she never saw |
| `enquiry` | `CLIENT_WITHDRAW` | `withdrawn` | void (G11) |
| `accepted` | `INTAKE_DONE` | `active` | G11 |

**The guard is the transition, not a counter.** `status == 'enquiry'` is asserted inside the same
transaction as the increment, so a replayed accept fails on the state test rather than incrementing
twice — spine C4 as corrected: *an increment never travels alone*.

### 3.4 `CoachTodayState.resolve(desk, coachDoc)` — three states, one route

| State | Rendering | Condition |
|---|---|---|
| `dayOneUnverified` | `K24` with the amber "checking your certificates" card | roster empty ∧ verification ∉ {`verified`} |
| `dayOneVerified` | `K24` without the amber card | roster empty ∧ `verified` |
| `working` | `K07` | roster non-empty |

**`K24` is a state, not a route (HANDOFF 16).** `app_routes.dart` has a `K24` entry because the
prototype needs one per screen; the Flutter app must **not** add navigation to it. Accepting a first
client flips the same route from one branch to the other. `P1-RULE-13` fails if a route or any
`Navigator.push` to a day-one destination exists.

---

## 4. Offline behaviour

Spine §5: persistence on, unbounded cache; every `users/{uid}/**` write is offline-writable. The
coach's shell is different — three of her actions **must not** be queued.

| Screen / action | Offline | Mechanism |
|---|---|---|
| `K01`, `K03`, `K04` edits | **writable** | local draft → one `update()` on `coaches/{me}` keyed by her uid (deterministic, C1). Field-scoped so a CF field is never clobbered |
| `K02` certificate | **not writable** | file queued locally, state `local_pending`, row reads "waiting for signal". Never shown as uploaded |
| `K05` payout | **not writable** | tokenisation is a network round-trip by definition. Refused with a reason, not a spinner |
| `K06`, `K07`, `K24`, `K25` | read-only from cache | desk doc cached; header states "as of HH:MM" |
| `K09` accept / decline | **not writable, by design** | it holds a capacity slot and captures money. The button is disabled with explicit copy. **Queuing it would let two coaches accept the last spot, or take money for a spot that no longer exists** |
| `K16` send | **writable** | queued with local echo; `msgId` is a client UUID generated once and reused on retry (C1); row shows "queued", never a failure |
| `K17` | read-only | `asOf` shown; a stale figure is never rendered as live |
| `K18` edits | **writable** | as `K01` |

**Conflict policy.** `coaches/{me}` is single-writer in practice but not by guarantee, so:
coach-editable scalars are last-write-wins; `capacity.taken`, `replyTimeP50Mins`, `verifiedCerts` and
`listed` are CF-only and **excluded from the client's write mask in the rules** — which is what stops
LWW from resurrecting a stale `taken` and inventing a spot. Messages merge by document id. The desk
document is never written by a device.

**The honest limit, recorded as G7 recorded its own.** A client who revokes a sharing switch while
the coach is offline does not revoke the coach's *cached* panel until the coach reconnects. The
server-side projection is emptied immediately and the coach's next read returns nothing, but a cached
screen already rendered on her device is beyond reach. Copy must not promise otherwise.

---

## 5. §2 rules I own, and the exact domain-layer enforcement point

| Rule | Where it is enforced (domain, never a widget) | Second line |
|---|---|---|
| **2 — a message never changes a plan** | `CoachChatService.send(relId, CoachMessageDraft)`. `CoachMessageDraft` has fields `body`, `attachments`, `replyTo` and **no plan fields**; the class has **no constructor dependency on any plan repository**, so there is no call path from chat to `plans/**` — a compile-time guarantee, not a review one | rules: `plans/**` is `allow write: if false` for every client (G8 §9). Publishing is G14's `PlanPublisher`, reachable only from `W08` |
| **6 — face blur defaults on** | `CoachMediaUploader.upload(bytes, purpose)` calls G7/G8's `MediaBlurPolicy.resolve()` before any byte leaves the device. `photoBlurred` defaults `true` | `K01` must render an **explicit** "show my face" action with its consequence stated. See Q1 — the screen's "Face visible" copy and rule 6 collide, and the resolution is an explicit action, not a silent default flip |
| **8 — no AI face-gender classification** | G12 adds **no image classifier of any kind**. Coach sex comes from G1's 13th-digit gate, already decided before `K01`. Certificate review is a human reading a document | `P1-RULE-08`'s grep covers `functions/src/coach/**` |
| **11 — nothing ranked by weight or followers** | `CoachProfileRepository` rejects any write whose keys intersect the banned list; the `coaches` collection has no rankable field to sort | rules `noRankableKeys()` (§6) + the §1.5 index exemption |
| **HANDOFF 13 — client constraints are read-only** | `ClientConstraintsReader.forRelationship(relId) → ClientConstraints`, an **immutable value object with no setters and no repository write method**. No G12 screen binds a text field to `avoid` or `allergies` | rules deny a coach write to `users/{clientUid}/**` and to `assessments/*` outside G14's assessment flow. The only two sources stay the assessment and her intake |
| **HANDOFF 16 — first-run screens are states** | `CoachTodayState.resolve()` (§3.4) | `P1-RULE-13` asserts no route and no push |
| **HANDOFF 17 — the empty state is the onboarding** | `K24` and `K06` each state what will appear, why it is empty, and offer one action. No tour, no overlay | `P0-CDAY-01` |
| **HANDOFF 6 / spine C12 — sharing switches** | `ClientConstraintsReader` reads **only** `relationships/{relId}/clientView/current`; there is no code path from a coach session to `users/{clientUid}/**` or to cycle data | rules (§6): the projection *is* the security boundary |

---

## 6. Security rules, as code

Composed against G8's single ruleset. **Nothing here is a second `match /users/{uid}`** — that is the
OR hazard `RECONCILIATION.md` row 3 records, and G12 adds no block under `users/`. These are disjoint
top-level paths, safe to OR because no other group matches them.

```js
// ───────── G12: the coach's shell ─────────
// Party uids are denormalised into every subdocument so NO rule needs a get().
// A rules get() is a billed read; G1 established the zero-read claim posture and
// this follows it. `coachV` is minted only by CoachVerificationStateMachine.
function isCoachVerified() {
  return claim('coachV') && request.auth.token.coachV == true;
}
function coachEditable() {
  return ['displayName','city','tagline','photoRef','photoBlurred','specialties',
          'languages','clientPlaces','acceptingClients','capacity','serviceHours','updatedAt'];
}
function coachServerOnly() {
  return ['verifiedCerts','listed','replyTimeP50Mins','verification','firstWeek'];
}
// Rule 11, enforced by making it unstorable — the C6 pattern applied to coaches.
function noRankableKeys() {
  return !keys().hasAny(['followers','followerCount','following','followingCount',
                         'ratingAvg','ratingCount','weightKg','weightLost',
                         'clientWeightLost','bodyFat','rank','score']);
}

match /coaches/{coachUid} {

  // Public profile — H01/H02 render this. Unlisted coaches are invisible.
  allow get:  if resource.data.listed == true || isSelf(coachUid);
  allow list: if false;          // discovery is a server-side query (G11), never an open scan

  allow create: if isSelf(coachUid) && isVerified()                 // G1: she is a verified woman
                && request.auth.token.role == 'coach'
                && keys().hasOnly(coachEditable())
                && request.resource.data.capacity.taken == 0
                && request.resource.data.photoBlurred == true       // rule 6: default on
                && noRankableKeys() && noStreak() && freshStamp();

  allow update: if isSelf(coachUid)
                && changed().hasOnly(coachEditable())
                && !changed().hasAny(coachServerOnly())
                && request.resource.data.specialties.size() <= 3    // K03
                && request.resource.data.capacity.max <= 200        // §2.1 product cap
                && request.resource.data.capacity.taken == resource.data.capacity.taken
                && (request.resource.data.acceptingClients == false || isCoachVerified())
                && noRankableKeys() && noStreak() && freshStamp();

  allow delete: if false;                                            // G1's onAccountDelete hook

  // Offers — public, hers. No personal data, so no parent get() is worth a billed read.
  match /offers/{offerId} {
    allow get:    if signedIn();
    allow list:   if signedIn() && request.query.limit <= 20;
    allow create, update: if isSelf(coachUid) && isCoachVerified()
                  && request.resource.data.price is number           // never free text
                  && request.resource.data.price >= 0
                  && request.resource.data.currency == 'EGP'
                  && noRankableKeys() && freshStamp();
    allow delete: if isSelf(coachUid);
  }

  // Certificates — private evidence. She uploads; only the Function decides.
  match /certificates/{certId} {
    allow get, list: if isSelf(coachUid) && request.query.limit <= 20;
    allow create: if isSelf(coachUid)
                  && request.resource.data.state == 'uploaded'
                  && request.resource.data.mediaRef.matches('^coach-docs/' + coachUid + '/.*');
    allow update: if false;                                          // state is CF-only
    allow delete: if isSelf(coachUid)
                  && resource.data.state in ['uploaded','rejected'];  // never mid-review
  }

  // The desk: queue, verification, firstWeek, earnings summary. CF-written, self-read.
  match /private/{doc}   { allow get: if isSelf(coachUid); allow write: if false; }
  match /earnings/{month}{ allow get: if isSelf(coachUid);
                           allow list: if isSelf(coachUid) && request.query.limit <= 12;
                           allow write: if false; }
}

// ───────── the coach's view of a client — the whole of §6's requirement ─────────
// "A coach may read ONLY her own clients' shared data, and only what the sharing
// switches permit." Both halves are enforced HERE, and the second half is enforced
// by ABSENCE: clientView contains a field only while the switch is on. The CF
// deletes the field on revocation, so a rules error cannot leak a closed switch —
// there is nothing in the document to leak.
match /relationships/{relId} {
  allow get:  if signedIn()
              && (resource.data.coachUid == request.auth.uid      // zero reads: denormalised
                  || resource.data.clientUid == request.auth.uid);
  allow list: if signedIn()
              && request.query.limit <= 20
              && resource.data.coachUid == request.auth.uid;
  allow write: if false;                                           // G11 + the G12 callable only

  match /clientView/{doc} {
    allow get:   if signedIn() && resource.data.coachUid == request.auth.uid;
    allow write: if false;                                         // CF projection only
  }
  match /messages/{msgId} {
    allow get, list: if signedIn() && request.query.limit <= 50
                 && (resource.data.coachUid == request.auth.uid
                     || resource.data.clientUid == request.auth.uid);
    // Rule 2, at the storage layer: a message document may carry no plan field.
    allow create: if signedIn()
                 && request.resource.data.senderUid == request.auth.uid
                 && request.resource.data.keys().hasOnly(
                      ['senderUid','coachUid','clientUid','body','attachments',
                       'replyTo','createdAt','readAt'])
                 && !request.resource.data.keys().hasAny(
                      ['planVersion','assignmentId','sets','publish','applyToPlan']);
    allow update: if signedIn() && changed().hasOnly(['readAt']);
    allow delete: if false;
  }
}

// A coach has NO read of a client's own documents. Stated as an absence, for the
// reason G6 recorded about rule 11: rules are a permissive union, so a `deny` block
// cannot revoke someone else's `allow`. There must be no `match /users/{uid}` that
// grants a non-self reader, and no collectionGroup match on `clientView` or
// `messages` — without one, a cross-coach collectionGroup query is denied by default.
```

```js
// ───────── Storage ─────────
match /coach-docs/{coachUid}/{p=**} {          // certificates: reviewer-only
  allow read:  if false;                        // reviewers read via admin credentials
  allow write: if isSelf(coachUid)
               && request.resource.size < 8 * 1024 * 1024
               && request.resource.contentType.matches('image/.*|application/pdf');
}
match /coach-public/{coachUid}/{p=**} {         // her profile photo, content-addressed
  allow read:  if true;
  allow write: if isSelf(coachUid) && request.resource.size < 4 * 1024 * 1024
               && request.resource.contentType.matches('image/.*');
}
```

**Requirements filed to G8 (rules are authored once, by G8 — spine §2):**
1. Add `coachV` to the minted-claim set and to the emulator suite's forgery tests.
2. **`plans/{uid}/{doc=**}` currently reads `allow read: if isSelf(uid)` — which denies a coach any
   read of her own client's plan.** `W03`, `W08`, `W09` and `K16`'s context are unbuildable as
   written. Amendment requested: `allow read: if isSelf(uid) || isActiveCoachOf(uid)`, implemented
   with a denormalised `coachUid` on the plan document so it stays a zero-read check. Raised as Q3.

---

## 7. Interface to the other groups

### 7.1 I consume

| From | What | Path / API |
|---|---|---|
| G1 | identity verification, `role == 'coach'`, `isVerified()` claim | `users/{coachUid}`, Auth claims |
| G1 | account deletion hook | `onAccountDelete(uid)` |
| G7/G8 | blur policy, analytics gateway | `MediaBlurPolicy.resolve()`, `AnalyticsGateway.track()` |
| G8 | offline queue, rules composition, CDN URL convention | `OfflineWriteQueue.enqueue()` |
| G11 | the relationship document, messages, the client-view projection | `relationships/**` |
| G13 | portfolio published flag (for `K18` and `firstWeek`) | `coaches/{c}/portfolio/{version}.published` |
| G14 | assessment existence + `avoid`/allergies, split count | `assessments/*`, `coaches/{c}/splits/*` |

### 7.2 I publish

| To | What |
|---|---|
| **all** | `coaches/{coachUid}` public root + `offers/*` — the spine gives me both. `H02` and G13's portfolio render from these |
| **G11** | `isCoachVerified()` claim; `capacity.{max,taken}` ("12 spots left" is a real number); `replyTimeP50Mins` ("replies in ~2h", measured) |
| **G13** | `OfferRepository` — the **single** source of offers |
| **G14** | `CoachDeskReader.watch()`; `coachEnquiryDecision` callable; `ClientConstraintsReader` |
| **G8** | the `coaches/**` and `coach-docs/**` rule blocks above, and the §1.5 index exemptions |

### 7.3 Field requests to other groups (not added by me — spine §2)

| To | Request | Why |
|---|---|---|
| **G11** | `relationships/{relId}` must carry `coachUid`, `clientUid`, `status`, `enquiredAt`, `lastActivityAt`, and a denormalised enquiry payload (`situation`, `herWords`, `joinedAt`) | `K09` renders her situation and her own words; without denormalisation it is a read of `users/{clientUid}`, which the rules deny |
| **G11** | every `messages/*` document carries `coachUid` + `clientUid` | zero-read rules; no billed `get()` on the chat hot path |
| **G11** | materialise `relationships/{relId}/clientView/current` from the sharing switches, **deleting** fields on revocation | the projection is the security boundary for HANDOFF 6 / C12 |
| **G11** | confirm G12's `coachEnquiryDecision` is the **sole** writer of `status` for `enquiry→accepted|declined` | two groups writing one field is a rejected plan |
| **G13** | the portfolio `offers` block must hold **`offerIds`, not embedded name/price copies** | `HANDOFF.md`'s block example embeds `{name, price, lines}`, which duplicates my `offers/*` collection — a price edit would then require a portfolio republish and the two would silently disagree. Raised as Q5 |
| **G14** | expose `PlanPublisher` as the only plan mutation, and keep it unreachable from chat | rule 2 |
| **G8** | the two items in §6 |

---

## 8. Test cases my screens need

**Rows for `tests/TEST-CASES.csv` — not written into it.** Format is the file's exact ten columns:
`id,priority,journey,screens,precondition,steps,expected,rule_protected,platform,scope`.
`P1-RULE-01`–`11` exist, so mine begin at `12`. Scope is `Post-MVP` to match the three existing coach
rows, though D1 makes that column vestigial (Q9).

**Already written, and I am accountable for the coach half:** `P1-RULE-02` (`K16`), `P1-RULE-10`,
`P1-RULE-11`.

```csv
P0-CVER-01,P0,Coach cannot take a client before her certificates clear,"K02,K06,K09","Coach account, identity verified, certificates uploaded but not yet cleared",Complete K01-K05 > open K06 > open a pending enquiry and attempt to accept,"Accepting is refused. K06 states the check is in progress and offers real work instead of a dead end. The coachV claim is absent and the server rejects the callable even if the button is forced.",A coach is verified more strictly than a client,both,Post-MVP
P0-CVER-02,P0,Certificates clear and the page goes live,"K06,K18,K25","Coach in docs_checking with all certificates valid",Let the check pass > reopen the app,"verifiedCerts and listed become true, coachV is minted, the profile becomes publicly readable, K25 step marks certificates cleared. She can now accept.",,both,Post-MVP
P0-CVER-03,P0,A rejected certificate is not a dead end,"K02,K06","Certificate the issuing body does not recognise",Submit it > let the check fail,"Non-accusatory copy per D8. A replace-and-resubmit path is offered. failReason is a coarse code, never raw provider text, and never appears on the public profile document.",D8: reviewing to keep the community safe,both,Post-MVP
P0-CVER-04,P0,An expired certificate keeps her clients but stops new ones,"K06,K09","Verified coach with 12 active clients; every certificate passes its expiry date",Let the certificates expire > open K09 with a pending enquiry,"State is expired. Existing clients and their plans are untouched and her page stays live. coachV is revoked so no new enquiry can be accepted. acceptingClients cannot be set true.",A coach's paperwork never punishes her client,both,Post-MVP
P0-CVER-05,P0,Certificate upload with no signal,K02,Airplane mode,Choose a certificate image and confirm,"Queued locally as local_pending and labelled waiting for signal. It is never shown as uploaded or checking. It uploads on reconnect exactly once.",,both,Post-MVP
P0-ENQ-01,P0,Accept an enquiry,"K09,K07","Verified coach, 12 of 20 spots taken, one enquiry open",Open the enquiry > tap Accept and send a welcome,"capacity.taken becomes 13 in the same transaction as the status change. Payment is captured, not before. The client appears in the queue and K07 re-renders.",,both,Post-MVP
P0-ENQ-02,P0,Decline an enquiry,K09,One enquiry open,Tap 'Not a fit for me',"Status becomes declined, the payment authorisation is voided, capacity is unchanged, and the copy is neutral rather than a rejection notice.",,both,Post-MVP
P0-ENQ-03,P0,Two accepts race for the last spot,K09,"19 of 20 taken, two enquiries open, accepted from two devices at once",Accept both within the same second,"Exactly one succeeds. The other fails on the status assertion inside the transaction, not on a counter read, and reports that the spot is gone. taken never exceeds max.",Spine C4: an increment never travels alone,both,Post-MVP
P0-ENQ-04,P0,Accepting is refused offline rather than queued,K09,Airplane mode with an enquiry open,Attempt to accept,"Refused with an explicit reason. It is NOT queued: a queued accept could take money for a spot that no longer exists, or let two coaches take the same last spot.",,both,Post-MVP
P0-ENQ-05,P0,An undecided enquiry expires,"K09,K07","Enquiry open and untouched for 72 hours",Let the TTL elapse,"Status becomes expired, the authorisation is voided and the client is told. Capacity is unchanged and the coach's measured reply time is not penalised for it.",,both,Post-MVP
P0-CDAY-01,P0,Coach day one,"K24,K07","Newly verified coach with no clients",Open the coach Today tab,"K24 renders as a branch of the K07 route: the verification card if still checking, the empty roster explained in one line, and three pieces of real work. No tour and no overlay. Accepting a first client flips the same route to K07 with no navigation.",HANDOFF rules 16 and 17,both,Post-MVP
P0-CCHAT-01,P0,Send a message with no signal,K16,Airplane mode mid-conversation,Type a reply and send > re-enable network,"Appears immediately marked queued, never as failed. Sends exactly once on reconnect because msgId is a client UUID generated once and reused on retry.",Offline-first requirement,both,Post-MVP
P0-CSCALE-01,P0,A 200-client coach opens Today,"K07,K24","Coach with 200 active clients and 40 items waiting",Open the coach Today tab and count the document reads,"Exactly 2 document reads regardless of roster size. The queue is capped at 30 with an overflow count. A 60-client or 200-client roster never causes a per-client read on screen open.",Scalability gate: no unbounded scan,both,Post-MVP
P0-CSCALE-02,P0,The client list paginates and is indexed,"K07,W01",Coach with 200 active clients,Open the full client list and page through it,"20 documents per page, cursor-based, served by the coachUid+status+lastActivityAt composite index. No offset paging, no full-collection read, and the query fails loudly if the index is missing.",Scalability gate: no unindexed hot-path query,both,Post-MVP
P1-RULE-12,P1,Product rule guard,"K16,K07,W02",App built and running,"Search every coach screen for an editable control bound to a client's avoid list or allergies, then attempt a direct write to users/{clientUid} and to assessments from a coach session","No coach screen can type a constraint: the value object is immutable and has no write method. Both direct writes are denied by rules. The assessment and her own intake remain the only two sources.",HANDOFF rule 13: the assessment is the only source of a client's constraints,both,Post-MVP
P1-RULE-13,P1,Product rule guard,"K24,W11,B14",App built and running,Inspect the route table and every Navigator call for a day-one destination,"No route resolves to a first-run screen and no push targets one. Each is a branch inside Today, Clients and the portfolio, chosen when the underlying collection is empty.",HANDOFF rule 16: first-run screens are states not routes,both,Post-MVP
P1-RULE-14,P1,Product rule guard,K01,App built and running,Upload a coach profile photo without touching the blur control; inspect the stored object,"The stored file is blurred. photoBlurred defaults true. Showing her face is an explicit named action with its consequence stated on screen, never a silent default.",Face blur is on by default and applied before upload,both,Post-MVP
P1-RULE-15,P1,Product rule guard,"K16,K07",App built and running,"Turn off a client's sharing switches, then read everything the coach session can reach about her","The coach reads only relationships/{relId}/clientView, and the withheld fields are absent from the document rather than filtered in the UI. Every direct read of users/{clientUid} is denied. Cycle data is unreachable unless that switch is on.",HANDOFF rule 6 and spine C12,both,Post-MVP
P2-RTL-K01,P2,Arabic RTL rendering,K01,Language set to Arabic,Open K01 (Your basics) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-K01,P2,Large text / accessibility,K01,OS font size set to largest,Open K01 (Your basics) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-OFF-K01,P2,Offline behaviour,K01,Airplane mode,Attempt the primary action on K01 with no network,"Either completes locally and queues, or is refused with a clear message. Never a silent failure, never an endless spinner.",,both,Post-MVP
P2-ERR-K01,P2,Server error handling,K01,Backend returns a 500,Trigger the primary action on K01 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.,,both,Post-MVP
P2-RTL-K02,P2,Arabic RTL rendering,K02,Language set to Arabic,Open K02 (Certificates) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-K02,P2,Large text / accessibility,K02,OS font size set to largest,Open K02 (Certificates) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-OFF-K02,P2,Offline behaviour,K02,Airplane mode,Attempt the primary action on K02 with no network,"Either completes locally and queues, or is refused with a clear message. Never a silent failure, never an endless spinner.",,both,Post-MVP
P2-ERR-K02,P2,Server error handling,K02,Backend returns a 500,Trigger the primary action on K02 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.,,both,Post-MVP
P2-RTL-K03,P2,Arabic RTL rendering,K03,Language set to Arabic,Open K03 (What you coach) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-K03,P2,Large text / accessibility,K03,OS font size set to largest,Open K03 (What you coach) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-OFF-K03,P2,Offline behaviour,K03,Airplane mode,Attempt the primary action on K03 with no network,"Either completes locally and queues, or is refused with a clear message. Never a silent failure, never an endless spinner.",,both,Post-MVP
P2-ERR-K03,P2,Server error handling,K03,Backend returns a 500,Trigger the primary action on K03 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.,,both,Post-MVP
P2-RTL-K04,P2,Arabic RTL rendering,K04,Language set to Arabic,Open K04 (Your packages) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-K04,P2,Large text / accessibility,K04,OS font size set to largest,Open K04 (Your packages) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-OFF-K04,P2,Offline behaviour,K04,Airplane mode,Attempt the primary action on K04 with no network,"Either completes locally and queues, or is refused with a clear message. Never a silent failure, never an endless spinner.",,both,Post-MVP
P2-ERR-K04,P2,Server error handling,K04,Backend returns a 500,Trigger the primary action on K04 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.,,both,Post-MVP
P2-RTL-K05,P2,Arabic RTL rendering,K05,Language set to Arabic,Open K05 (Getting paid) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-K05,P2,Large text / accessibility,K05,OS font size set to largest,Open K05 (Getting paid) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-OFF-K05,P2,Offline behaviour,K05,Airplane mode,Attempt the primary action on K05 with no network,"Either completes locally and queues, or is refused with a clear message. Never a silent failure, never an endless spinner.",,both,Post-MVP
P2-ERR-K05,P2,Server error handling,K05,Backend returns a 500,Trigger the primary action on K05 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.,,both,Post-MVP
P2-RTL-K06,P2,Arabic RTL rendering,K06,Language set to Arabic,Open K06 (Being checked) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-K06,P2,Large text / accessibility,K06,OS font size set to largest,Open K06 (Being checked) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-RTL-K07,P2,Arabic RTL rendering,K07,Language set to Arabic,Open K07 (Today) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-K07,P2,Large text / accessibility,K07,OS font size set to largest,Open K07 (Today) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-RTL-K09,P2,Arabic RTL rendering,K09,Language set to Arabic,Open K09 (New enquiry) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-K09,P2,Large text / accessibility,K09,OS font size set to largest,Open K09 (New enquiry) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-OFF-K09,P2,Offline behaviour,K09,Airplane mode,Attempt the primary action on K09 with no network,"Either completes locally and queues, or is refused with a clear message. Never a silent failure, never an endless spinner.",,both,Post-MVP
P2-ERR-K09,P2,Server error handling,K09,Backend returns a 500,Trigger the primary action on K09 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.,,both,Post-MVP
P2-RTL-K16,P2,Arabic RTL rendering,K16,Language set to Arabic,Open K16 (Conversation) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-K16,P2,Large text / accessibility,K16,OS font size set to largest,Open K16 (Conversation) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-OFF-K16,P2,Offline behaviour,K16,Airplane mode,Attempt the primary action on K16 with no network,"Either completes locally and queues, or is refused with a clear message. Never a silent failure, never an endless spinner.",,both,Post-MVP
P2-ERR-K16,P2,Server error handling,K16,Backend returns a 500,Trigger the primary action on K16 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.,,both,Post-MVP
P2-RTL-K17,P2,Arabic RTL rendering,K17,Language set to Arabic,Open K17 (Earnings) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved. EGP amounts stay in Western numerals.",,both,Post-MVP
P2-TXT-K17,P2,Large text / accessibility,K17,OS font size set to largest,Open K17 (Earnings) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-RTL-K18,P2,Arabic RTL rendering,K18,Language set to Arabic,Open K18 (Public profile) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-K18,P2,Large text / accessibility,K18,OS font size set to largest,Open K18 (Public profile) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-OFF-K18,P2,Offline behaviour,K18,Airplane mode,Attempt the primary action on K18 with no network,"Either completes locally and queues, or is refused with a clear message. Never a silent failure, never an endless spinner.",,both,Post-MVP
P2-ERR-K18,P2,Server error handling,K18,Backend returns a 500,Trigger the primary action on K18 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.,,both,Post-MVP
P2-RTL-K24,P2,Arabic RTL rendering,K24,"Language set to Arabic, coach with no clients",Open the coach Today tab in its day-one state in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-K24,P2,Large text / accessibility,K24,"OS font size set to largest, coach with no clients",Open the coach Today tab in its day-one state at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-RTL-K25,P2,Arabic RTL rendering,K25,Language set to Arabic,Open K25 (Coach first week) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-K25,P2,Large text / accessibility,K25,OS font size set to largest,Open K25 (Coach first week) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
```

**60 rows: 14 P0, 4 P1, 42 P2.** Every one of my 13 screens has RTL and large-text coverage; all 8
writing screens (`K01`–`K05`, `K09`, `K16`, `K18`) have offline and server-error coverage — the gap
G7/G8 found on `A01`/`A04` and which I have deliberately not repeated.

---

## 9. Open questions — named, because silence is a defect

| # | Question | Owner | Cost of leaving it |
|---|---|---|---|
| **Q1** | **`K01` says "Face visible. Clients pick a person, not a logo" — rule 6 says blur defaults on.** Resolved here as: default blurred, with an explicit "show my face" action. Confirm the copy reflects a choice, not an instruction | owner + G7 | either the screen silently bypasses rule 6, or every coach's photo ships blurred and the marketplace fails |
| **Q2** | **`K09` says "She pays only when you accept"; `H04` takes payment before `G01`.** Resolved here as authorise-at-`H04`, capture-on-accept, void on decline/expiry. **This needs a payment provider that supports authorisation holds in Egypt** — Fawry and wallet rails may not | owner + G11 | the two screens contradict each other, and refunds become manual |
| **Q3** | `plans/{uid}` is readable only by `isSelf(uid)` in G8's deployed ruleset, so **a coach cannot read her client's plan at all** | G8 + G14 | `W03`, `W08`, `W09` and `K16`'s context are unbuildable as written |
| **Q4** | **Certificate images are retained; ID images are deleted (rule 7).** Different basis, different data — but retention period, lawful basis and the reviewer-access audit trail are unwritten. Certificates carry her full legal name | owner + legal | a PDPL exposure on a document set no one decided to keep |
| **Q5** | `HANDOFF.md`'s portfolio `offers` block embeds `{name, price, lines}`, duplicating the spine's `coaches/{c}/offers/*` which I own | G13 + spine owner | a price edited in one place and stale in the other, on the screen that takes money |
| **Q6** | **Who reviews certificates, and how fast?** `K02` promises "usually the same day"; at 2,000 applications that is a staffing commitment, exactly like the Safety Centre's one hour | owner | an on-screen promise with nobody behind it |
| **Q7** | `K17`'s earnings are rendered from a collection **no group owns** — payments, escrow, the 80% split and payouts are absent from the spine entirely | owner + a new group | `K17`, `K05` and `H04` have no write path; the money side of the product is unowned |
| **Q8** | Can a client become a coach later? G1 makes `role` immutable after first write and routes changes through support | G1 + owner | a woman who signs up as a client must delete her account to coach |
| **Q9** | The CSV `scope` column still means "the recommended cut", which D1 withdrew. My rows use `Post-MVP` for consistency with the three existing coach rows | Stage-1 owner | the column now sorts by nothing meaningful |
| **Q10** | The 5%-coached and 1,000-coach assumptions in §1.6 are mine, not the owner's | owner | every cost figure in §2.2 scales linearly off them |
| **Q11** | `H01`/`H02` show a **4.8★ rating** on every coach. Nothing in the spine stores one, I deliberately banned the field (rule 11), and ranking women by rating is adjacent to what rule 11 forbids | owner + G11 | either the screens show a number nothing computes, or a ranking lands without a decision |
| **Q12** | `K07` shows "3 check-ins waiting … Start → `W09`" while G14 owns `W09`/`W10`. The queue item model is mine, the destination is hers | G14 | duplicated queue logic, or a dead link |

---

## 10. Scalability gate — self-check

| Gate | Result | Evidence |
|---|---|---|
| **Unbounded collection scan** | **PASS** | `K07`/`K24` are 2 direct gets. Every list is `limit`-capped **in the security rules** (`request.query.limit <= 20`), so an unbounded query is denied by the server, not merely un-written. `allow list: if false` on `coaches` makes a full-collection scan impossible |
| **Fan-out write that grows with followers/clients** | **PASS** | Nothing is copied into per-client documents. Her name and price live in one document each and are read-joined (spine C9 applied to coaches). The one aggregate — `private/desk` — is a **single document per coach**, debounced to ≤1 write/60 s, so its write rate is bounded by time and is **independent of roster size** (§2.1) |
| **Unindexed hot-path query** | **PASS** | The daily hot path needs **zero composite indexes**. The two composites serve warm, paginated lists and are declared in §1.5 |
| **Migration needed to reach scale** | **PASS** | No shape changes between 1 and 200 clients. `relId` is deterministic from day one, the queue cap and overflow exist from the first write, and the index exemptions ship with the first deploy rather than being retrofitted after a rule-11 violation is already live |

**Stated plainly:** the design holds at 200 clients per coach, which is the product cap enforced in
`capacity.max`. Beyond 200 the desk document is still far from Firestore's 1 MiB limit (~7 KB), and
the binding constraint would remain the per-document write rate — already solved by the time-based
debounce rather than by client count. There is no number of clients at which this plan needs a
migration.
