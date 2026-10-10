# G11 — Coaching relationship & marketplace (CLIENT side)

**Screens (23):** `H01`–`H06` (finding and choosing a coach) · `G01`–`G17` (life as a coached client).
**Inputs treated as fixed:** `DECISIONS.md` (D1 — all 161 screens ship; no deferrals proposed below),
`BUILD-BRIEF.md` §2/§3/§4/§6 (§0 ignored per D1), `SCHEMA-SPINE.md` incl. §8, `flutter/HANDOFF.md`,
`plans/RECONCILIATION.md` (settled). Cost figures are against §3: **35,000 DAU, ~8 reads / ~6 writes per
active day, 40% of traffic 19:00–23:00 Cairo**, re-baselined by `RECONCILIATION.md` §3.

> **Naming hazard, stated once.** `G07` is *my screen* "Rest between sets"; `G7` is the *profile/privacy
> group*. Throughout this file screens are always two digits (`G07`, `H02`) and groups never are (`G7`, `G4`).

---

## The answer to the rule this group exists to protect

**§2.2 — a coach's message never changes a plan; publishing does.**

| Enforcement point | Class · method | Mechanism |
|---|---|---|
| **The only write path for a message** | **`MessageRepository.send(RelationshipRef, MessageDraft) → MessageId`** | `lib/features/coached/domain/message_repository.dart`. It builds exactly one `WriteIntent` whose `scope` is the sealed `WriteScope.relationshipMessage(relId, msgId)`. There is **no overload, no flag and no second parameter** that can address `plans/**`. `message_repo_has_no_plan_path_test.dart` is an AST test: it fails if the string `plans/` or the identifier `PlanRepository` appears anywhere in the file or its imports. |
| **The only transition into PUBLISHED** | `PlanPublisher.publish()` (G2's, widened to "self or the assigned coach") called **only** by the callable `publishCoachPlan` | G2 §3.1's table is authoritative: `DRAFT → PUBLISHED` requires an explicit human act, and `PUBLISHED → PUBLISHED` is illegal. `plans/**` is `allow write: if false` for every client including coaches (G2 §6), so a message *cannot* reach a plan even with a forged client. |
| **The card that says "plan updated"** | **`PlanUpdateCard.resolve(relId, since) → List<PlanChange>`** | `G13`'s "Plan updated · Thursday 18 September" and `G14`'s inline system chip are built **only** from `plans/{uid}/versions/*` where `publishedAt > since`. Message text is never parsed, and a `MessageDraft` has no field a card could be synthesised from. A coach who types "I've shortened Thursday" and does not publish produces **no card and no plan change**. |
| **The running session** | `CoachedPlanReader.pinnedVersion(sessionId)` delegates to G4's `StartSessionUseCase` | pins `planVersion` at start; `ResumeSessionUseCase` never re-reads (HANDOFF rule 2). A publish mid-session changes nothing that is running or logged. |
| **The review** | `ReviewRepository.save()` (HANDOFF 15) | same `WriteScope` construction; a saved review records, it never revises. |

There is **no auto-publish anywhere in G11**, and no code path in this group writes `plans/**`.
Test: `P1-RULE-02B` (client side) pairs with the existing `P1-RULE-02` (coach side).

---

## 1. Data model

### 1.1 Consumed unchanged (not mine to write)

| Path | Owner | What I take |
|---|---|---|
| `users/{uid}.profile.{goal,days,sessionLength,place,equipment,allergies,dietary,lifeStage,firstName,language}` | G2 | `G01`/`G17` **reuse** these rather than asking twice; `G17` writes them **through `ProfileRepository`**, never directly (D3: editable forever in My Profile) |
| `users/{uid}.privacy.shareLogsWithCoach`, `.blurFacesDefault` | G7 | the app-level log-sharing switch and the blur default |
| `users/{uid}.verification.status` / auth claims `{verified,vexp,pledgeV,role,adult}` | G1 | browse is open to the unverified (research §7b); **purchase is gated** — see OQ-10 |
| `plans/{uid}/versions/{v}`, `plans/{uid}/assignments/{yyyy-MM-dd}` | G2 | **one plan, one set of logs** (research §4). A coached plan is the same collection with `source:'coach'`, `authorUid: coachUid`. G2 already reserved this shape ("keeping the coach case possible without a migration") |
| `users/{uid}/sessions/*`, `meals/{date}`, `checkins/{date}`, `weeks/{isoWeek}` | G4, G5, G3, G6 | `G06`–`G11` write through **their** repositories. G11 creates no second workout history and no second food diary |
| `coaches/{coachUid}`, `…/portfolio/{version}`, `…/offers/{offerId}`, `…/results/{resultId}` | G12, G13 | public read; `H01`–`H03` render them |
| `assessments/{assessmentId}` | G14 | read-only, the coach-authored half of `ClientConstraints` (HANDOFF 13) |
| `followGraph/**` | G10 | `H02`'s follow button. **Counts displayed, never ranked** (rule 11) |

### 1.2 Collections G11 owns

`relId` is **deterministic**: `relId = "{coachUid}__{clientUid}"` (C1). Both parties can compute the path,
so no screen in this group needs a query to find the relationship, and an offline-retried create collapses
onto the same document instead of forking the thread.

> **Format reconciled (§11-R1).** I first wrote `{clientUid}__{coachUid}`; G12 published
> `{coachUid}_{clientUid}` and G14 explicitly requested `{coachUid}__{clientUid}`. Coach-first wins on a
> two-to-one vote of the consumers, and the **double** underscore stays: Firebase Auth uids are 28
> alphanumeric characters, so a single `_` would parse ambiguously the day a provider widens that
> alphabet. The order is load-bearing — my Storage rules derive party membership by splitting this id.

```
relationships/{relId}                                  owner: G11   (spine §8, extended)
  { coachUid, clientUid, status, startedAt, endsAt,     ← spine fields, unchanged
    offerId,
    sharing{ logs, energyAppetite, symptoms, datesAndPatterns,   // all bool, ALL DEFAULT FALSE
             grantedForRelId },                         // ← spine §8 amendment: the grant lives ONCE,
                                                        //   here, and dies with this relationship so it
                                                        //   can never be inherited by the next coach.
                                                        //   G9 READS this map and never writes it.
    engagementId,                 // current engagement, null when status=='enquiry'
    priceEGP,                     // the AGREED price, copied at acceptance (G13 requires this: a later
                                  // price rise must not reach an existing client — B11's promise)
    serviceHours{ days[], from, to, tz },               // denormalised from coaches/{c}, for G14's header
    replyWindowMins,                                    // her stated promise; drives the refund clock
    enquiredAt, lastActivityAt,                         // G12 §7.3 request
    enquiry{ situation, herWords, joinedAt },           // denormalised for K09 — a coach may not read
                                                        //   users/{clientUid}, so this is the only way
                                                        //   her own words reach the enquiry screen
    lastMessageAt, lastMessageSenderUid,                // Function-maintained, debounced 60 s
    readCursor{ <uid>: timestamp },                     // two parties write two distinct keys → mergeable
    queue{ oldestUnansweredAt, unreadForCoach, reviewDueAt,      // G14 §7.4: ONE indexed query serves
           planNeededAt, assessmentDueAt, latestAssessmentId },  //   W01's four chips, W10 and W11
    schemaV, updatedAt }

relationships/{relId}/messages/{msgId}                  msgId = DocIds.message()  (UUID minted once)
  { coachUid, clientUid,        // DENORMALISED — G12 was right: without these the security rule needs a
                                // get() on the parent, i.e. ONE BILLED READ PER MESSAGE READ AND WRITE.
                                // On the chat hot path that is the single most expensive line I had.
                                // Immutable after create; the rules check them instead of joining.
    senderUid, kind:'text'|'voice'|'image'|'clip'|'attachment',
    body?,                                              // ≤4000 chars; immutable after create
    attachments[]: { storagePath, mime, bytes, durationMs?, blurApplied },
    contextRef?: { kind:'assignment'|'session'|'meal'|'review', id },   // G14's "opens the record"
    createdAt, deliveredAt?, readAt?, schemaV }

relationships/{relId}/reviews/{yyyy-Www}                deterministic = ISO week (C1)
  { dueAt, answers{ manageable, worked?, change[] , weightOptIn:false },
    fromLogs{ sessionsDone, sessionsTarget, foodDaysLogged, sharedKeys[] },
    planVersion,                                        // IMMUTABLE after create (HANDOFF 15)
    submittedAt, coachResponse?{ body?, voicePath?, agreed[], respondedAt },
    schemaV }

relationships/{relId}/intake/current                    single doc, deterministic id
  { goalNote, avoid[], cookMinutes, familyPot:bool,
    reminderLocalTime, dailyCheckin:bool,
    profileEcho{ goal, days, sessionLength, place, equipment[], allergies[], dietary[] },
    step:'training'|'food'|'support'|'done', submittedAt, schemaV }
      profileEcho is a READ-ONLY COPY for the coach's convenience; the authority is
      users/{uid}.profile (G2). CoachIntakeReader prefers the live profile and uses the
      echo only when the profile read is denied. Two sources, one authority, stated.

relationships/{relId}/engagements/{engId}               engId = 'e1','e2',…  (G16 "work with her again")
  { offerId, priceEGP, currency:'EGP', startsAt, endsAt, days:30,
    paymentId, state, acceptedAt?, declinedAt?, refundedAt?, schemaV }

relationships/{relId}/payments/{providerTxnId}          id = PROVIDER's txn id → replay-proof (C1)
  { engagementId, provider:'paymob', rail:'card'|'wallet'|'fawry',
    amountEGP, feeEGP?, state, createdAt, paidAt?, failedAt?, failureCode?,
    expiresAt?,                                          // Fawry reference TTL
    refund{ state, amountEGP, requestedAt, settledAt?, reason }?,
    providerOrderId, providerRef?,                       // the Fawry code shown on H04
    hmacVerifiedAt, schemaV }
      SERVER-WRITE ONLY. The client never sends a price and never marks anything paid.

relationships/{relId}/shared/constraints                Function-written   → G14's W02, W04, W06
  { allergies[], dietary[], goal, days, sessionLength, place, equipment[],
    lifeStage, avoid[], sharingV, updatedAt, schemaV }
      NEVER cycle data, under any switch. Rewritten when her profile or intake changes.
      This is the client-authored half of HANDOFF 13.

relationships/{relId}/rollups/{yyyy-Www}                Function-written   → G14's W02 ring, W09
  { sessionsPlanned, sessionsLogged, mealDaysLogged, swapsUsed, bests[],
    sharingV, builtAt, schemaV }
      Present ONLY while sharing.logs is on. Week-keyed ⇒ idempotent (C1).

relationships/{relId}/clientView/current                Function-written   → G12's K07, K16 banner
  { lastSessionAt, adherencePct, quietWeeks, restWeekUsed,
    energyAppetite?{…}, symptoms?{…}, datesAndPatterns?{…},   // ONLY per sharing switches
    sharingV, builtAt, schemaV }
      Cycle-derived keys arrive ONLY via G9's CycleSharingPolicy.projectionFor().

      THESE THREE ARE "the coach's derived panels" of HANDOFF rule 6, and they replace
      the single dated panels/{yyyy-MM-dd} of my first draft. G12 and G14 had already
      specified these paths and built screens on them; theirs are also cheaper (constraints
      change rarely; a rollup is week-keyed, so it is idempotent rather than one write a
      day). Adopted verbatim rather than making two groups rewrite. §11-R3.

      An ABSENT key means "Not shared" and must never render as a zero, a blank, or
      "no symptoms" (research §5). Revocation DELETES the key rather than filtering it:
      the projection IS the security boundary (G12's phrase, adopted), so a withheld
      field never reaches the coach's device for a widget to hide.

coaches/{coachUid}/ratings/{clientUid}                  NEW — see OQ-8 (name collision with `reviews`)
  { stars:1..5, text?, engagementId, createdAt, editedAt? }
      id == clientUid ⇒ one rating per client per coach. Ballot-stuffing is unrepresentable.
```

**`users/{uid}.coaching` — a new map on the user document, Function-written (requested of G8, OQ-7).**

| Field | Type | Why on the user doc |
|---|---|---|
| `activeRelId`, `coachUid`, `status`, `endsAt` | string / ts | `T01` and `H05` already read `users/{uid}`, so "does she have a coach" costs **0 incremental reads** — the same argument G7 used for `privacy`/`notify` |
| `unread` | int | badge on the Coaching tab without touching `messages` |
| `relIds[]` | array, capped 50 | G7's deletion manifest needs the list; overflow falls back to the Function's own index |

It is **not** in any client-writable slice. It joins `verification` and `rewards` in G8's **global deny**
list: a client-writable relationship pointer is a one-line way to attach yourself to a coach.

### 1.3 The coach directory pack — not a Firestore collection

`H01` is **the one search surface in the product**, so it gets the treatment `exercises`/`foods` already
get: a CDN artefact, not a per-open query.

| Property | Value |
|---|---|
| Artefact | `directory/coaches.v{n}.json.gz` on R2 behind Cloudflare, built by scheduled Function `buildCoachDirectory` every 15 min and on `coaches/*` publish |
| Row | `{coachUid, displayName, photoRef, city, specialties[≤3], languages[], priceFromEGP, ratingAvg, ratingCount, replyMinsP50, spotsLeft, acceptingClients, verifiedCertsAt, portfolioV}` ≈ 240 B |
| Size | 2,000 coaches ≈ 480 KB raw, **≈110 KB gzipped**; 6,000 coaches ≈ 330 KB gz (the shard ceiling, §9) |
| Freshness | Remote Config `coach_directory_version` (registered with G8, §10.1). Stale ≤15 min — and `acceptingClients`/`spotsLeft` are **re-checked server-side at purchase**, so staleness can never oversell a coach |
| Cost | **0 Firestore reads.** ~10k device fetches/day × 110 KB ≈ 1.1 GB/day ≈ 33 GB/month at **$0 egress** on R2 |
| Search | local. Facet filters (specialty / language / city / price band / accepting) + name substring over an **Arabic-normalised** key (alef/hamza folded, ta-marbuta → ha, tatweel and diacritics stripped) — the same local-FTS pattern G5 uses for foods |

### 1.4 Indexes and field exemptions

| Collection | Index | Why |
|---|---|---|
| `relationships/{relId}/messages` | automatic `createdAt` (single-field, scoped to one relationship) | `orderBy(createdAt,desc).limit(30)` + cursor |
| `relationships/{relId}/reviews` | automatic `__name__` | ISO-week key range, ≤6 docs |
| `relationships/**` | **no collection-group index, ever** | a CG query would cross the two-party boundary; denied in rules *and* unindexed |
| `coaches` (**cold fallback only**) | composite `acceptingClients ASC, specialties ARRAY_CONTAINS, priceFromEGP ASC` | used only when the directory pack is unavailable; `limit(20)` + cursor |
| `coaches` (**cold fallback only**) | composite `acceptingClients ASC, city ASC, priceFromEGP ASC` | second facet shape; one `array-contains` per query is the Firestore limit |
| `relationships` | **composite `coachUid ASC, status ASC, queue.oldestUnansweredAt ASC`** | **the one composite index on a hot path in this plan, and it is the coach's, not the client's.** G14's W01/W10/W11 share a single `limit(20)` listener over it and filter the four chips client-side; the alternative — four queries, four indexes, four times the reads — is worse. Declared, not incidental. §11-R4 |
| **Client hot path** | **no composite index** | every hot read on a client screen is a point get on a deterministic id — spine §4 satisfied |

**`firestore.indexes.json` field exemptions G11 adds (rule 11 / C7 at the storage layer):**

```jsonc
{ "collectionGroup": "coaches",  "fieldPath": "followerCount", "indexes": [] },
{ "collectionGroup": "results",  "fieldPath": "numbers",       "indexes": [] },
{ "collectionGroup": "clientView", "fieldPath": "datesAndPatterns", "indexes": [] },
{ "collectionGroup": "clientView", "fieldPath": "symptoms",         "indexes": [] },
{ "collectionGroup": "clientView", "fieldPath": "energyAppetite",   "indexes": [] },
{ "collectionGroup": "messages", "fieldPath": "body",          "indexes": [] }
```

Line 2 is the sharp one: `coaches/**/results/*.numbers` holds **weight lost**. Without the exemption
Firestore indexes it by default and "order coaches by how much weight their clients lost" is a query that
simply works. Rule 11 is enforced by making the sort **unexecutable**, exactly as G4 did for `sets`.
Post-deploy assertion (CI): a query ordering `coaches` by `followerCount` must **fail**.

### 1.5 Storage

```
relationship-media/{relId}/{senderUid}/{msgId}.{ext}     voice notes, form clips, photos
```

`user-media/{uid}/**` is `isSelf` read-only (G8 §9.2), so a coach could never open a client's voice note
there. The uid stays **inside** the object path so G7's deletion manifest keeps a prefix to delete, and
the new prefix is added to that manifest in the same change (K12). Blur is enforced at the door by
`MediaUploadGateway.upload()` — a clip of her squatting is coach media and rule 6 does not care who the
audience is (C11).

---

## 2. The query for every screen, with index and cost

Assumptions, stated so they can be argued with: **5% of MAU are in an active relationship** → 5,000 live
relationships, **1,750 coached actives/day**; **8% of DAU browse** → 2,800 browsers/day; ~170 purchases/day
(30-day cycles). "Cached" means Firestore's unbounded local cache (G8 §7) or the CDN pack.

| Screen | Query | Index | Billed reads | Writes | Notes |
|---|---|---|---|---|---|
| `H01` Find a coach | **local filter over the directory pack**; fallback `coaches.where(acceptingClients==true).where(specialties array-contains s).orderBy(priceFromEGP).limit(20)` | none / the declared composite | **0** (fallback: 20) | 0 | the one search surface; 0 Firestore reads by construction |
| `H02` Coach profile | **G13's `PublishedPortfolioReader.watch(coachUid)` → CDN `GET /p/{coachUid}/live.json` + N × `/r/{coachUid}/{id}.json`**; Firestore only on a CDN 5xx | — | **0 on hit** (fallback 1 + results) | 1 batched beacon | **corrected §11-R6**: I had costed this at 2–8 Firestore reads, duplicating a delivery path G13 had already solved. I render G13's `PortfolioView` widget and own the chrome only |
| `H03` Packages | offers come from the portfolio `offers` block already in memory | — | **0** | 0 | price re-priced server-side at checkout |
| `H04` Pay | callable `createCheckout{coachUid, offerId, idemKey}` → hosted page; app then **polls/listens `payments/{txnId}`** | `__name__` | **1–3** (listener on one doc) | 0 client | app never marks paid; the webhook does |
| `H05` My coach | `users/{uid}` (cached, read by `T01`) + `get relationships/{relId}` + `get reviews/{lastReviewKey}` | `__name__` | **1–2** | 1 (`readCursor`) | `coaching` map means no query to find her coach |
| `H06` Chat (pre-purchase) | `messages.orderBy(createdAt,desc).limit(30)` + listener | automatic | **30 first open/device, then deltas** | 1/msg | same collection as `G14`; status `enquiry` |
| `G01` Intake · training | `users/{uid}` cached + `get intake/current` | `__name__` | **0–1** | 1 merge | answers reused from `profile` |
| `G17` Intake · food | same doc | — | **0** | 1 merge + 1 `ProfileRepository.setDietary()` | the **only** client-side source of allergies |
| `G02` Intake · support | same doc | — | **0** | 1 merge + 1 `relationships.sharing` | switches default OFF |
| `G03` Preparing | `get relationships/{relId}`; absence of `plans/{uid}/versions/*` published by the coach | `__name__` | **0–1** | 0 | nothing faked, nothing scheduled |
| `G04` Coaching plan (tab root) | `plans/{uid}/assignments/{today}` (G2's read, shared with `T01`) + `relationships/{relId}` + `meals/{today}` (G5's) | `__name__` | **+1 incremental** | 1 (`readCursor`) | one plan, one set of logs |
| `G05` Your 30 days | `get plans/{uid}/versions/{v}` → `calendar[30]` summary (**field request to G2**) | `__name__` | **1** (cached: 0) | 0 | a 30-doc range read would have cost 30; see §9 |
| `G06` Assigned workout | G4's `StartSessionUseCase`; assignment already in memory | — | **0** | 1 per move flush (G4's) | coach note + rest seconds come off the assignment |
| `G07` Rest between sets | in-memory | — | **0** | 0 | rest seconds are the coach's, from the assignment |
| `G08` Swap an exercise | `moves[].alternatives[]` on the assignment (**field request to G2**) | — | **0** | 0 (recorded on the session by G4's `SwapMoveUseCase`) | approved-first, ask-second |
| `G09` Session done | G4's session doc in memory | — | **0** | 1 (G4's) + 0 mine | her actual numbers reach the coach via the panel, not a copy |
| `G10` Log a planned meal | `assignments/{today}.meal` (in memory) + `foods` pack | — | **0** | 0 | `AllergyGuard` runs before the write |
| `G11` Meal logged | `meals/{today}` (G5's, already read at `T01`) | — | **0** | 1 (G5's) | correction vs second helping is G5's |
| `G12` Weekly review | **`ReviewPrefill.build()` reads the local cache only** | — | **0** | 1 (`reviews/{isoWeek}`) | no range query over weeks |
| `G13` Coach replied | `get reviews/{key}` + `PlanUpdateCard.resolve()` → `get plans/{uid}/versions/{v}` | `__name__` | **1–2** | 1 (`readAt`) | the card comes from the version, never the text |
| `G14` Chat | as `H06` | automatic | **deltas** | 1/msg + 1 debounced Function write | attachments open their record |
| `G15` Voice note | none (record → preview → send) | — | **0** | 1 Storage + 1 message | nothing sends on selection |
| `G16` Coaching ended | `get relationships/{relId}` | `__name__` | **1** | 0 | history readable, sharing already off |

### 2.1 Cost per active day, and the fleet

| Line | Per **coached** active/day | Per **fleet** active/day |
|---|---|---|
| Reads | 12–14 | **+0.9** |
| Client writes | 5–7 | **+0.30** |
| Function writes (projections, cursors, money) | 4–6 | **+0.25** |

Fleet totals: **≈31k reads/day** and **≈22k writes/day** on top of the existing envelope. Against
`RECONCILIATION.md` §3's re-baselined 318–363k writes/day this is a **~6% increase**, and against 280k
reads a **~11%** increase. It does not move the shape of the bill.

| Monthly at 35,000 DAU | Figure |
|---|---|
| Firestore reads (930k/mo @ $0.06/100k) | **$0.56** |
| Firestore writes (660k/mo @ $0.18/100k) | **$1.19** |
| Firestore storage (messages + reviews, ~1.3 GB after a year) | **$0.23** |
| R2: directory pack + voice notes (33 GB/mo egress, ~6 GB/mo growth) | **$0.09** (egress $0) |
| Cloud Functions (~900k invocations/mo, under the 2M free tier) | **$0** |
| **G11 infrastructure total** | **≈ $2.10 / month** |
| **Payment processing — the line that actually costs** | **≈ $5,100 / month** |

The processing line: 5,000 active relationships × 1,800 EGP ≈ **9.0M EGP/month GMV** (~$187k). Paymob card
~2.75% + fixed, Fawry ~1–2% + per-transaction EGP fee, wallets in between → **≈247k EGP ≈ $5,150/month**,
about **14% of the platform's 20% share**. This is `RECONCILIATION.md` §3's finding repeating itself:
G11's infrastructure is **1/2,400th** of G11's third-party bill. Optimising Firestore here is misdirected
effort; negotiating the Paymob rate is not.

### 2.2 Peak (40% of traffic in 4 hours, 19:00–23:00 Cairo)

Peak G11 write rate ≈ 22k × 0.4 / 14,400 s ≈ **0.6 writes/s** fleet-wide; the hottest single document is a
relationship's `lastMessageAt`, which is why the Function debounces it to **≤1 write/60 s per thread** —
two women typing quickly would otherwise approach Firestore's 1 write/s per-document soft ceiling. Messages
themselves are separate documents and have no per-document ceiling. `buildCoachDirectory` runs off-peak-
agnostic (every 15 min, ~1.4 MB of reads per build over ≤6,000 coach docs = 6,000 reads/build ≈ 576k
reads/day — **too expensive**, so the builder reads an **incremental changed-since query**
(`coaches.where(updatedAt > lastBuild)`, typically <50 docs) and patches the previous artefact. Full rebuild
nightly. Corrected here rather than discovered in the bill.

---

## 3. State machines

### 3.1 Relationship lifecycle — `RelationshipStateMachine` (10 states)

```
                    ┌──────────── H06 first message ────────────┐
                    ▼                                           │
(none) ──────► ENQUIRY ──coach declines (K09)──► DECLINED (terminal)
   │               │
   │               └─coach accepts (K09)─► AWAITING_PAYMENT ─┐
   │                                                          │
   └─H03→H04 buy direct──► AWAITING_PAYMENT ──────────────────┤
                                  │                            │
                      payment.paid│                            │
                                  ▼                            │
                          AWAITING_ACCEPTANCE ──declined/timeout──► REFUNDING ──► REFUNDED (terminal)
                                  │ coach accepts
                                  ▼
                            INTAKE  (G01→G17→G02)
                                  │ intake submitted
                                  ▼
                            PREPARING (G03) ──coach publishes plan──► ACTIVE (G04)
                                                                        │
                                              endsAt − 5d ──────────────┤
                                                                        ▼
                                                                  ENDING_SOON
                                                                        │ endsAt
                                                                        ▼
                                                                     ENDED (G16, terminal-readable)
                                                                        │ renew (G16 → H03)
                                                                        └──► AWAITING_PAYMENT (new engagement)
   any state ──report upheld / block (G7) ──► SUSPENDED ──► REFUNDING or ENDED
```

| From | To | Trigger | Guard | Effect |
|---|---|---|---|---|
| none | `ENQUIRY` | `EnquiryService.start(coachUid)` from `H02` "Message before you decide" | coach `acceptingClients`; not blocked either way (G7) | creates `relationships/{relId}` (Function), 0 money |
| `ENQUIRY` | `DECLINED` | coach at `K09` | — | thread stays readable; client may enquire again after 7 days |
| `ENQUIRY`/none | `AWAITING_PAYMENT` | `createCheckout` callable | verified (OQ-10); `spotsLeft > 0` **re-read server-side**; no other `AWAITING_*` engagement | creates `engagements/{engId}` + `payments/{txnId}` in one transaction |
| `AWAITING_PAYMENT` | `AWAITING_ACCEPTANCE` | **webhook** `payment.paid` | HMAC valid, amount matches the server-priced offer | decrements `spotsLeft`; notifies the coach |
| `AWAITING_PAYMENT` | `ENQUIRY`/none | `payment.failed` / `expired` | — | `H04` shows the failure state; nothing is charged |
| `AWAITING_ACCEPTANCE` | `INTAKE` | coach accepts (`K09`) | within her reply window | `acceptedAt`; the client is routed to `G01` |
| `AWAITING_ACCEPTANCE` | `REFUNDING` | coach declines, **or** the clock (`replyWindowMins × 2`, floored 24 h, capped 72 h — OQ-2) | — | full refund; `spotsLeft` restored; `H05` explains without blaming |
| `INTAKE` | `PREPARING` | `IntakeService.submit()` at `G02` | all three steps complete | `G03` renders; nothing is faked |
| `PREPARING` | `ACTIVE` | `publishCoachPlan` **only** | ≥1 published version with `effectiveFrom ≤ today+1` | `G04` becomes the tab root |
| `ACTIVE` | `ENDING_SOON` | scheduler at `endsAt − 5d` | — | one notification; renewal offered, never auto-charged |
| `ENDING_SOON`/`ACTIVE` | `ENDED` | `endsAt`, or either party ends early | — | **`sharing` is cleared and `shared/`, `rollups/*` and `clientView/current` are deleted**; messages/reviews/plan become read-only (`G16`) |
| any | `SUSPENDED` | G7 upheld report / block | — | messages closed both ways; refund pro-rata (OQ-11) |

**Illegal by construction:** `ENDED → ACTIVE` (renewal creates a *new engagement*, never resurrects one),
and any transition into `ACTIVE` that is not `publishCoachPlan`. A message can reach **no** transition in
this table.

### 3.2 Payment lifecycle — `PaymentStateMachine` (8 states)

Egypt rails via **Paymob**: card (Visa/Mastercard/**Meeza**), mobile wallet (Vodafone Cash, Orange Money,
Etisalat, **InstaPay**), and **Fawry** reference codes.

| State | Reached by | What `H04`/`H05` shows |
|---|---|---|
| `created` | `createCheckout` callable priced the offer server-side | "Preparing your payment…" (≤2 s) |
| `awaiting_provider` | hosted checkout opened / wallet push sent / **Fawry code issued** | card+wallet: the provider's page in a **platform tab**; Fawry: the code, the expiry, and *how* to pay it, with the app fully usable meanwhile |
| `paid` | **webhook only**, HMAC-verified | "Paid — 1,800 EGP" + receipt; relationship advances |
| `failed` | webhook decline / provider error | the reason in plain words, the same three rails offered again, **nothing charged**. Never a dead end |
| `expired` | Fawry code TTL elapsed (typically 24–72 h) | "That code expired. Here is a new one." One tap re-issues; the old code is dead server-side |
| `refund_pending` | coach declined / timed out / `SUSPENDED` | "Your money is on its way back — wallets 1–3 days, cards 5–14." A real range, not "immediately" |
| `refunded` | webhook refund settled | receipt updated; `H05` returns to the un-coached state |
| `disputed` | card chargeback notification | client sees nothing new; ops-only. Payout to the coach is frozen |

Four properties this design commits to:

1. **The app never handles card details.** Checkout opens the provider's hosted page in **Chrome Custom
   Tabs / `ASWebAuthenticationSession`** — *not* an in-app `WebView`, where in-process JS could observe the
   form and which drags the app into PCI scope. Return is a deep link that only triggers a **read** of the
   payment document.
2. **A redirect is not a receipt.** `paid` is written by the webhook after HMAC verification; the deep link
   only makes the app listen. An app that trusts its own return URL can be paid with a bookmark.
3. **Idempotent by id.** The payment document id **is** the provider transaction id, so a replayed webhook
   (Paymob retries) lands on the same document (C1). `hmacVerifiedAt` is set once; a second create fails.
4. **Capture, then refund — one semantics for three rails.** Fawry and wallets cannot be authorised and
   held, so an authorise/capture design would give card buyers one refund experience and everyone else
   another. Money is captured at purchase; the **payout** is what is held (H04: "Your coach is paid after
   your first check-in"). This is what makes `K09`'s "She pays only once you accept" true on the enquiry
   path and **false on the buy-direct path** — OQ-1.

### 3.3 Message delivery — `MessageDeliveryState` (5 states)

`composing → queued(local, deterministic msgId) → sent(server ack) → delivered(recipient device ack) →
read(recipient opens the thread)`; plus `failed(rejected)` with an inline Retry that **reuses the same
msgId**, so `G15`'s promise ("a failed send retries without duplicating the message") is structural.
`delivered`/`read` come from `readCursor` comparison — **no per-message receipt write**.

### 3.4 Weekly review — `ReviewState` (4 states)

`due (scheduler at day 7k) → drafted (local, prefilled) → submitted (immutable answers) → answered (coach
response)`. `planVersion` is stamped at `submitted` and is immutable. `answers` cannot be edited after
`submitted` — a review that can be rewritten after the coach replies is not a record.

### 3.5 Sharing switch — `SharingSwitchState` (3 states × N independent keys)

`off (default) → on → revoked(=off)`. Keys: `logs`, `energyAppetite`, `symptoms`, `datesAndPatterns`
(G9's category names, adopted verbatim so the switch and the projection cannot drift). Independent booleans
in a map — there is **no "share everything" master switch to build**, which is HANDOFF rule 6 made
unrepresentable rather than merely respected. `sharing.grantedForRelId == relId` is enforced in the rules,
so a grant **dies with the relationship** and is never inherited by the next coach (spine §8 amendment).

---

## 4. Offline behaviour

| Surface | Offline? | Conflict resolution | UI while queued |
|---|---|---|---|
| Send a message (`H06`,`G14`,`G15`) | **yes** | deterministic `msgId` minted once (C1/K1) → replay collapses | G8's queued convention: full opacity + `cloud_queue` glyph, "Saved on your phone…". **No undo window** — send is already a deliberate two-step (record → preview → send) |
| Attach voice/photo/clip | **yes, queued** | the Storage upload is queued with the message; the bubble shows an upload progress ring, not a spinner over the screen | fails → inline Retry, same `msgId` |
| Intake `G01`/`G17`/`G02` | **yes** | distinct map keys merge; `profile` writes are G2's single-owner scalars (LWW) | "saved as you go" is literally true offline |
| Sharing switches (`G02`) | **yes** | distinct keys in `sharing{}` merge | flips locally at once — **and see the honesty note below** |
| Weekly review (`G12`) | **yes** | deterministic ISO-week id → idempotent | queued chip; the coach sees it when it lands |
| Workout/meal logging (`G06`–`G11`) | **yes** | G4's single-writer `deviceId` on `sessions`; G5's `arrayUnion`+`increment` on `meals` | unchanged from G4/G5 — G11 adds nothing and breaks nothing |
| Mark thread read | **yes** | two parties write two distinct `readCursor` keys | immediate |
| **Buy coaching (`H03`,`H04`)** | **no — hard requirement** | — | "You need a connection to pay." No optimistic state, no local "pending purchase", no queued charge. Same posture G7 takes for account deletion |
| **Coach's panel** | server-derived | — | offline, the coach's app shows the last panel it fetched, timestamped |
| **Plan publish** | **no** | — | `plans/**` is server-authored (spine §5); `G03` says plainly that nothing is scheduled yet |

### HANDOFF rule 6, and what "immediately" actually means

> *Sharing switches are independent, default off, and revoke the coach's derived panels when turned off.*

G7 recorded the honest limit and I inherit it, so here is the mechanism in full:

| When she revokes | What actually happens |
|---|---|
| **Online** | `RelationshipSharingService.setSwitch()` writes `relationships/{relId}.sharing.{key}=false`; the `onSharingChanged` Function **rebuilds `clientView/current` and `rollups/*` with that key deleted**. Typical end-to-end **< 2 s**. The coach's open screen updates on its live listener. |
| **Offline** | The switch flips **on her handset at once** and the UI tells the truth about it. The server has not heard, so the coach's panel still carries yesterday's projection until the write syncs. **A server cannot deny a read it has not been told about.** Copy says *"applies everywhere as soon as you have signal"* — never *"immediately"*. |
| **Belt and braces** | Panel reads are additionally gated on `relationships/{relId}.status` being live, and the panel carries `sharingV`. A coach client holding a stale panel renders **"Not shared"** for any key absent from the current `sharing` map — never "no symptoms" (research §5). |
| **On end of coaching** | `onRelationshipEnded` clears `sharing{}` and deletes `shared/`, `rollups/*` and `clientView/current`. `G16`'s "Cycle sharing switched itself off when the coaching ended" is a Function, not a sentence. `sharing.grantedForRelId` makes it true a second way: the grant is bound to a relationship that no longer exists. |

Tests: `P0-SHARE-02` (online, panel gone), `P0-SHARE-03` (**offline — asserts the copy does not say
"immediately"** and that the panel persists until sync), `P0-SHARE-04` (ended → cleared).

---

## 5. Rules G11 owns, and the exact domain-layer enforcement point

No rule below is enforced in a widget. Every row names a class and a method.

| Rule | Own? | Class · method | Mechanism |
|---|---|---|---|
| **§2.2 A message never changes a plan — publishing does** | **OWN (primary)** | `MessageRepository.send()` · `PlanUpdateCard.resolve()` · `CoachedPlanReader.pinnedVersion()` · `ReviewRepository.save()` | See the box at the top. Four layers: a sealed `WriteScope` with no plan path; an AST test banning the literal `plans/`; the card derived only from published versions; rules denying `plans/**` writes to everyone. `P1-RULE-02B`. |
| **HANDOFF 6 Sharing switches independent, default OFF, revocation removes derived panels** | **OWN** | `RelationshipSharingService.setSwitch(relId, SharingKey, bool)` + `CoachProjectionWriter.rebuild(relId, trigger)` | Four independent booleans, no master switch in the type. The writer is the **only** writer of `shared/`, `rollups/` and `clientView/`, reads `sharing{}` at projection time, never a cached copy, and **deletes** withheld keys rather than filtering them. Cycle categories enter only through G9's `CycleSharingPolicy.projectionFor({relId, category})`. Offline limit stated in §4 and asserted by `P0-SHARE-03`. |
| **HANDOFF 13 The `avoid` list and allergies come from the assessment or her own intake — never a coach screen** | **OWN (the client half)** | I publish the **`relationships/{relId}/shared/constraints`** projection; **G14's `ClientConstraintResolver.resolve(clientUid)` is the only constructor** of `ClientConstraints` and merges it with the assessment. I withdraw my `ClientConstraintsView` name in favour of theirs — one rule, one resolver (§11-R5). Plus `CoachPlanConstraintValidator.assertSafe(plan, constraints)` | `ClientConstraints` is assembled from exactly three sources — `users/{uid}.profile.allergies/dietary` (G2, written by **her** at `G17`), `relationships/{relId}/intake/current.avoid[]` (written by **her**), `assessments/*` (G14, written by the coach about movement, never about allergies). The view is **read-only**: it exposes no setter, so a coach screen has no API to type into. The validator runs **inside the publish callable**, so a conflicting meal cannot be published at all — `AllergyGuard` (G5) is then the second line at log time. `P1-HRULE-13`, `P0-INTAKE-01`. |
| **HANDOFF 15 Saving a review never edits a published plan** | **OWN** | `ReviewRepository.save()` | Same `WriteScope` construction as messages; `planVersion` is stamped once and made immutable by rules. `P1-HRULE-15`. |
| **§2.11 Nothing ranked by weight, weight lost or followers** | **OWN for discovery** | `DiscoveryRanker.rank(List<DirectoryRow>, DiscoveryQuery)` | Sort keys are a sealed enum `DiscoveryKey { match, replySpeed, priceAsc, priceDesc, rating }` — `followers`, `weight` and `weightLost` are **not constructible**. Backed by the three field exemptions in §1.4, so even a hand-written query cannot execute the sort. A rating is only *displayed* at `ratingCount ≥ 5`. `P1-RULE-11B`. |
| **HANDOFF 10 / C10 A client result is publishable only while consent is active** | **OWN at the render** | `ClientResultReader.visible(resultId) → Result?` | Consent is checked **at read time**, never copied at publish time; the security rule below denies the read outright when `consentState != 'active'`, so a withdrawn result disappears from `H02` even from a cached portfolio version. `P1-HRULE-10`. |
| **§2.1 A prescribed value is never a result** | share (G4 owns) | `AssignedMoveMapper.toPrescribedSet(move)` · `ReviewPrefill.build()` | The mapper's return type is G4's `PrescribedSet`, which has **no actual fields**; there is no method that maps an assignment to an `ActualSet`. `ReviewPrefill` counts non-null `actualReps` only, so `G12`'s "3 of 3" can never be inflated by a prescription. |
| **§2.9 Undo, not confirmation** | share (G3 owns) | every log on `G06`–`G11` routes through G3's `LogCommandBus`; `no_dialogs_in_coached_test` | **Two deliberate exceptions, named so QA does not read them as violations** (the precedent is G7's): *paying* and *ending coaching* may confirm. They are destructive, non-logging, irreversible acts — the same carve-out `P1-RULE-09` already grants deletion and block. |
| **§2.6 / C11 Face blur on by default, applied on-device** | share (G8/G7 own) | `MediaUploadGateway.upload(MediaDraft)` with `MediaBlurPolicy.resolve()` | `G15`'s form clip and photo take the identical path as a community post. Coach media is not an exception (C11). |
| **§2.3 / C6 Weeks, not days; no streak** | share (G6 owns) | schema holds none | No field in any G11 document is a consecutive-day count. Reply-time is a **p50 in minutes**, not a run. `noStreak()` rejects the shapes at the rules layer anyway. |
| **§2.10 The assistant selects, never generates** | honour | `SwapMoveUseCase` (G4) | `propose_swap` writes a today-only swap on the session. There is no publish tool, and G11 exposes none. |
| **§2.4 / §2.5 Symptoms, not an inferred phase; severe symptoms replace the suggestion** | honour (G3/G9 own) | `CoachApprovedOption.offer()` | The coach-approved easier session is *offered*, never imposed, and **coach approval is never required to stop** (research §5): `StopSessionUseCase` is reachable from `G06`/`G07` without a message. |
| **C12 Cycle data never reaches a coach without the switch; never reaches analytics** | **OWN at the boundary** | `CyclePanelProjector.build(uid, sharing)` (calls G9's projection) | The projector is the only code that can place cycle-derived keys in a panel, and it takes `sharing` as a **required** parameter. G8's `AnalyticsGateway` enum has no property that can carry it. |
| **HANDOFF 16/17 First-run is a state; the empty state is the onboarding** | **OWN** | `CoachingTabState.resolve()` | `H05`/`G03`/`G04` are branches on `users/{uid}.coaching.status`, not routes. The un-coached Coaching tab renders `H01` with a one-line statement of what a coach adds — no tour, no overlay. |

---

## 6. Security rules, as code

Per the ratified composition rule, **`users/{uid}` is authored once by G8**; below, `users/{uid}` appears
only as a *requirement*. `relationships/**` and `coaches/**` are top-level and are **mine to deploy**.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn()  { return request.auth != null; }
    function isSelf(uid) { return signedIn() && request.auth.uid == uid; }
    function changed()   { return request.resource.data.diff(resource.data).affectedKeys(); }
    function keys()      { return request.resource.data.keys(); }
    function freshStamp(){ return request.resource.data.updatedAt == request.time; }
    // G1's published claim helpers, copied verbatim — ZERO reads, never a get().
    function claim(k)     { return signedIn() && (k in request.auth.token); }
    function isVerified() { return claim('verified') && request.auth.token.verified == true
                                && claim('vexp') && request.auth.token.vexp > request.time.toMillis(); }
    function isCoachRole(){ return claim('role') && request.auth.token.role == 'coach'; }
    function noStreak()   { return !keys().hasAny(['streak','streakDays','dayStreak','daysStreak',
                              'dailyStreak','currentStreak','consecutiveDays','daysInARow','missedDays']); }

    // ─────────────────────────────────────────────────────────────────────────
    // relationships/{relId} — THE TWO PARTIES, AND NOBODY ELSE.
    // relId is "{coachUid}__{clientUid}", so membership is checkable without a join.
    // ─────────────────────────────────────────────────────────────────────────
    match /relationships/{relId} {

      function rel()      { return resource.data; }
      function isClient() { return signedIn() && rel().clientUid == request.auth.uid; }
      function isCoach()  { return signedIn() && rel().coachUid  == request.auth.uid; }
      function isParty()  { return isClient() || isCoach(); }
      function live()     { return rel().status in ['enquiry','awaiting_acceptance','intake',
                                                    'preparing','active','ending_soon']; }

      allow get:    if isParty();
      // The CLIENT never lists: she reaches her relationship through
      // users/{uid}.coaching.activeRelId, a point get.
      // The COACH must list — W01's queue, W10's inbox and W11's empty state are one
      // listener over her own clients (G14 §7.4). The guard is that every document the
      // query can return is already hers, and the page is bounded. A rules `list` is
      // evaluated per returned document, so a query that could return someone else's
      // relationship fails as a whole rather than leaking a row. §11-R4.
      allow list:   if signedIn() && isCoachRole()
                    && request.query.limit <= 30
                    && resource.data.coachUid == request.auth.uid;
      // Money, capacity and status are decided server-side. A client-created relationship
      // is a free coaching subscription.
      allow create: if false;
      allow delete: if false;

      // The client may flip her own sharing switches and her own read cursor. Nothing else.
      function clientSlice() {
        return isClient()
          && changed().hasOnly(['sharing','readCursor','updatedAt','schemaV'])
          && (!changed().hasAny(['sharing']) || (
                request.resource.data.sharing.keys()
                  .hasOnly(['logs','energyAppetite','symptoms','datesAndPatterns',
                            'grantedForRelId'])
                && request.resource.data.sharing.logs             is bool
                && request.resource.data.sharing.energyAppetite   is bool
                && request.resource.data.sharing.symptoms         is bool
                && request.resource.data.sharing.datesAndPatterns is bool
                // Spine §8 amendment: a grant is bound to THIS relationship, so it dies
                // with it and can never be inherited by the next coach — true even on a
                // device that was offline when the relationship ended.
                && request.resource.data.sharing.grantedForRelId == relId))
          && (!changed().hasAny(['readCursor']) || request.resource.data.readCursor
                .diff(resource.data.readCursor).affectedKeys().hasOnly([request.auth.uid]));
      }
      // The coach may move only her own read cursor here. Accepting, declining and
      // publishing are callables — they touch money, capacity and plans.
      function coachSlice() {
        return isCoach()
          && changed().hasOnly(['readCursor','updatedAt','schemaV'])
          && request.resource.data.readCursor
               .diff(resource.data.readCursor).affectedKeys().hasOnly([request.auth.uid]);
      }

      allow update: if live() && noStreak() && freshStamp()
                    && !changed().hasAny(['coachUid','clientUid','status','startedAt','endsAt',
                                          'offerId','engagementId','lastMessageAt','reviewDueAt'])
                    && (clientSlice() || coachSlice());

      // ── messages ──────────────────────────────────────────────────────────
      match /messages/{msgId} {
        // ZERO-READ RULES. G12 caught the defect in my first draft: a get() on the parent
        // relationship costs ONE BILLED READ per message read AND per message write, on the
        // hottest path in the group. Both uids are denormalised onto every message and
        // frozen at create, so membership is decided from the document in hand.
        function mine() { return signedIn()
                          && (resource.data.clientUid == request.auth.uid
                           || resource.data.coachUid  == request.auth.uid); }
        function minePending() { return signedIn()
                          && (request.resource.data.clientUid == request.auth.uid
                           || request.resource.data.coachUid  == request.auth.uid); }
        allow read:   if mine();
        allow create: if minePending()
                      && relId == request.resource.data.coachUid + '__'
                                + request.resource.data.clientUid      // the id cannot lie
                      && request.resource.data.senderUid == request.auth.uid
                      && request.resource.data.createdAt == request.time
                      && request.resource.data.kind in ['text','voice','image','clip','attachment']
                      && (!('body' in request.resource.data)
                          || request.resource.data.body.size() <= 4000)
                      && request.resource.data.attachments.size() <= 4
                      && noStreak();
        // A message is a record. Only the RECIPIENT may stamp readAt; the body never changes.
        allow update: if mine()
                      && resource.data.senderUid != request.auth.uid
                      && changed().hasOnly(['readAt'])
                      && request.resource.data.readAt == request.time;
        allow delete: if false;
      }

      // ── weekly reviews ────────────────────────────────────────────────────
      match /reviews/{weekKey} {
        function parent() {
          return get(/databases/$(database)/documents/relationships/$(relId)).data;
        }
        allow read:   if signedIn() && (parent().clientUid == request.auth.uid
                                     || parent().coachUid  == request.auth.uid);
        allow create: if signedIn() && parent().clientUid == request.auth.uid
                      && weekKey.matches('^[0-9]{4}-W[0-9]{2}$')       // C1, deterministic
                      && request.resource.data.planVersion is string
                      && request.resource.data.submittedAt == request.time
                      && noStreak();
        // HANDOFF 15: a review records; it never revises. The client cannot rewrite her
        // answers after the coach has replied, and neither party can move planVersion.
        allow update: if signedIn()
                      && !changed().hasAny(['planVersion','answers','fromLogs','submittedAt'])
                      && ((parent().coachUid == request.auth.uid
                           && changed().hasOnly(['coachResponse','schemaV']))
                          || (parent().clientUid == request.auth.uid
                              && changed().hasOnly(['readAt','schemaV'])));
        allow delete: if false;
      }

      // ── her intake: hers to write, the coach's to read ────────────────────
      match /intake/{docId} {
        function parent() {
          return get(/databases/$(database)/documents/relationships/$(relId)).data;
        }
        allow read: if signedIn() && (parent().clientUid == request.auth.uid
                                   || parent().coachUid  == request.auth.uid);
        // HANDOFF 13, as a rule: the coach can read the avoid list and never write it.
        allow create, update: if signedIn() && parent().clientUid == request.auth.uid
                      && keys().hasOnly(['goalNote','avoid','cookMinutes','familyPot',
                                         'reminderLocalTime','dailyCheckin','profileEcho',
                                         'step','submittedAt','schemaV','updatedAt'])
                      && request.resource.data.avoid.size() <= 30
                      && noStreak() && freshStamp();
        allow delete: if false;
      }

      // ── the three derived projections: Function-written, coach-readable while live ───
      // relId is "{coachUid}__{clientUid}", so both parties are derivable from the PATH
      // with no parent read at all. This is the cheapest correct rule in the file.
      function coachOfPath()  { return relId.split('__')[0]; }
      function clientOfPath() { return relId.split('__')[1]; }
      function partyByPath()  { return signedIn()
                                && (request.auth.uid == coachOfPath()
                                 || request.auth.uid == clientOfPath()); }

      match /shared/{doc}      { allow read: if partyByPath();  allow write: if false; }
      match /rollups/{isoWeek} { allow read: if partyByPath();  allow write: if false; }
      match /clientView/{doc}  { allow read: if partyByPath();  allow write: if false; }
      // The projections ARE the security boundary (G12's phrase, adopted): a withheld
      // field is absent from the document, so there is nothing for a rule to hide and
      // nothing for a stale client to render. Revocation deletes keys; it does not
      // filter them. This is HANDOFF rule 6's teeth.

      // ── money: read by both, written by nobody ────────────────────────────
      match /payments/{txnId}      { allow read: if signedIn()
                                       && (get(/databases/$(database)/documents/relationships/$(relId))
                                             .data.clientUid == request.auth.uid
                                        || get(/databases/$(database)/documents/relationships/$(relId))
                                             .data.coachUid  == request.auth.uid);
                                     allow write: if false; }
      match /engagements/{engId}   { allow read: if signedIn()
                                       && (get(/databases/$(database)/documents/relationships/$(relId))
                                             .data.clientUid == request.auth.uid
                                        || get(/databases/$(database)/documents/relationships/$(relId))
                                             .data.coachUid  == request.auth.uid);
                                     allow write: if false; }
    }

    // Any other shape under relationships is denied, including a collection-group read.
    match /relationships/{relId}/{document=**} { allow read, write: if false; }

    // ─────────────────────────────────────────────────────────────────────────
    // coaches/** — public shopfront. Read rules are G11's requirement; G12/G13 own the writes.
    // ─────────────────────────────────────────────────────────────────────────
    match /coaches/{coachUid} {
      allow get, list: if true;                       // public profile (spine §8 ownership table)
      allow write: if false;                          // G12's validated block / callables only
    }
    match /coaches/{coachUid}/portfolio/{version} {
      allow get:  if resource.data.published == true || isSelf(coachUid);
      allow list: if isSelf(coachUid);                // clients fetch the pointer version, never a list
      allow write: if false;                          // G13's block
    }
    match /coaches/{coachUid}/offers/{offerId} {
      allow get, list: if true;
      allow write: if false;                          // price is authoritative server-side
    }
    // C10 / HANDOFF 10 AS A RULE: withdrawal hides a result everywhere, at READ time,
    // including from a portfolio version that was published while consent was active.
    match /coaches/{coachUid}/results/{resultId} {
      allow get:  if resource.data.consentState == 'active' || isSelf(coachUid)
                  || resource.data.clientUid == request.auth.uid;
      allow list: if false;
      allow write: if false;
    }
    // (The coaches/{c}/clients/* index collection of my first draft is WITHDRAWN. It existed
    //  only so `relationships` could keep `allow list: if false`; G14's guarded, indexed,
    //  limit-30 coach query serves W01, W10 and W11 from one listener instead. §11-R4.)
    match /coaches/{coachUid}/ratings/{clientUid} {
      allow get, list: if true;                       // public; the aggregate lives on the coach doc
      allow create, update: if isSelf(clientUid) && isVerified()
                  && keys().hasOnly(['stars','text','engagementId','createdAt','editedAt'])
                  && request.resource.data.stars is int
                  && request.resource.data.stars >= 1 && request.resource.data.stars <= 5
                  && (!('text' in request.resource.data) || request.resource.data.text.size() <= 800);
      allow delete: if false;
    }
  }
}
```

**Storage (merged into G8's file):**

```javascript
match /relationship-media/{relId}/{senderUid}/{p=**} {
  // The two parties, read straight off the deterministic relId "{coachUid}__{clientUid}".
  // Storage rules cannot query Firestore at all, so an id that carries both parties is
  // what makes this enforceable rather than advisory.
  function partyByPath() {
    return request.auth != null
      && (request.auth.uid == relId.split('__')[0]      // the coach
       || request.auth.uid == relId.split('__')[1]);    // the client
  }
  allow read:  if partyByPath();
  allow write: if partyByPath() && senderUid == request.auth.uid
               && request.resource.metadata.blurApplied == 'true'     // rule 6 / C11, at the door
               && request.resource.size < 25 * 1024 * 1024;
}
```

**Requirements handed to G8 for the single `users/{uid}` block** (not rules I deploy):

1. Add `'coaching'` to the **global deny** alongside `verification` and `rewards`:
   `&& !changed().hasAny(['coaching'])`. A client-writable relationship pointer is free coaching.
2. `g2Slice()` already covers `allergies`/`dietary`, which is what `G17` writes — **no new slice needed**
   for the intake, and that is the point: the allergy list has exactly one writer.
3. No G11 rule grants a coach any read of `users/{clientUid}/**`. Her window is `shared/constraints`,
   `rollups/{isoWeek}` and `clientView/current` — and nothing else, ever.

**Emulator tests shipped with these rules:** a third party reading a relationship (denied); a coach reading
`users/{clientUid}/sessions/*` (denied); a coach writing `intake/current` (denied — HANDOFF 13); a client
writing `status` or `endsAt` (denied); a client writing `payments/*` (denied); a client updating another
woman's `readCursor` key (denied); editing `answers` after `submittedAt` (denied); a `collectionGroup`
query on `messages` (denied); reading a `result` with `consentState:'withdrawn'` (denied); reading a
`clientView/current` after `status:'ended'` (denied); a coach `list` with `limit > 30` or without her own
`coachUid` (denied); a Storage write with `blurApplied != 'true'` (denied);
ordering `coaches` by `followerCount` (**fails — no index**).

---

## 7. Interface to the other groups

### 7.1 Consumed

| From | Surface | Contract |
|---|---|---|
| G1 | auth claims `{verified, vexp, role, adult}` | zero-read gates. Browse open to the unverified (research §7b); purchase gated pending OQ-10 |
| G2 | `plans/{uid}/versions/*`, `assignments/{date}`, `PlanPublisher.publish()` | **I conform verbatim.** A coached plan is `source:'coach'`, `authorUid:coachUid`. Absence of an assignment means rest, never an error |
| G3 | `LogCommandBus`, `UndoableLog`, `DayStateResolver` | every log on `G06`–`G11` uses them; G11 writes no undo of its own |
| G4 | `StartSessionUseCase`, `SwapMoveUseCase`, `SessionRepository`, `PersonalBestEligibility` | `G06`–`G09` are G4's player with coach decorations; G11 owns none of the session schema |
| G5 | `MealLogService`, `AllergyGuard`, `MealDayReader` | `G10`/`G11` are G5's logging path with the coach's planned item |
| G6 | `WeekService`, `AwardTable`, `weeklyGoal.recent8` | `G12`'s prefill reads them from cache; coaching **never** changes the reward economy |
| G7 | `privacy.shareLogsWithCoach`, `MediaBlurPolicy.resolve()`, block/report, `onAccountDelete(uid)` | the app-level log switch gates `rollups/*`; a block suspends a relationship |
| G8 | `Repository.write(WriteIntent)`, `DocIds`, `SyncBadge`, `AppClock`, `ErrorPresenter`, `MediaUploadGateway`, `AnalyticsGateway`, Remote Config | K1–K12 conformance. **No `BillingChannel`** — Egypt rails are off-store (see OQ-4) |
| G9 | `CycleSharingProjection.build(uid, switches)` (**requested**) | the only way cycle-derived values enter a panel; absent switch ⇒ absent key (C12) |
| G10 | `followGraph/**`, `FollowService` | `H02`'s follow button. Counts displayed, never ranked |
| G12 | `coaches/{coachUid}` + `offers/*`; `K09` accept/decline; `K17` earnings | my `createCheckout` prices from **her** offer document; my Function writes her `clients/*` index and her earnings events |
| G13 | `coaches/**/portfolio/{version}` + `results/*` | `H02` renders the block list, full stop |
| G14 | `assessments/*`, `publishCoachPlan`, `splits/*` | the coach's half of the constraint view and the only path into `PUBLISHED` |

### 7.2 Published

| To | Surface | Guarantee |
|---|---|---|
| G12/G14 | **`relationships/{relId}/shared/constraints`** — the projection, not a class | the client-authored source of `avoid[]` + allergies for every coach planning screen (`W02`, `W03`, `W04`, `W06`, `K21`, `K26`, `K27`). **G14's `ClientConstraintResolver.resolve()` is the only constructor** of `ClientConstraints` and merges this with the assessment; I withdrew my competing `ClientConstraintsView` (§11-R5). No setter exists on either side — HANDOFF 13 |
| G12/G14 | **`CoachPlanConstraintValidator.assertSafe()`** | the publish callable must call it; a plan carrying a conflicting item cannot become `PUBLISHED` |
| G12/G14 | `relationships/{relId}/{shared,rollups,clientView}` + `relationships/{relId}.queue` | the coach's *only* window into a client's logs, gated by `sharing` and `status`; `queue` is what makes W01's four chips one indexed query instead of four |
| G12 | `PaymentSettled{relId, engagementId, coachUid, grossEGP, shareEGP, paidAt}` | the event `K17` (earnings) aggregates. G11 emits; G12 owns the screen and the aggregate document |
| G13 | `PortfolioRenderSpec` — the block types `H02` actually renders, and their contracts | a new block type must ship a renderer here **before** the builder offers it |
| G2 | the coach publish path exercising `source:'coach'` | G2's "keeping the coach case possible without a migration" is now exercised rather than reserved |
| G5 | `assignments.nutrition.proteinTargetG` **for coached clients** | **resolves half of G5's Q1**: in a coached plan the coach authors the protein target at `W06`. For self-serve it remains unowned |
| G3 | `users/{uid}.coaching.{status, coachUid, unread}` | `T01`'s coach card and the Coaching tab badge, at 0 incremental reads |
| G7 | deletion manifest rows: `relationships/{relId}/**` for every `relId` in `coaching.relIds[]`, and Storage prefix `relationship-media/{relId}/**` | added in the same change (K12) |
| G8/Amplitude | `coach_browse{screen, filterCount, resultBucket}`, `coach_profile_open{screen}`, `checkout_result{rail, outcome}`, `message_sent{kind, queued}`, `review_submitted{onTime}`, `sharing_changed{key, enabled}` | **Never**: a coach's name or uid, a price, a message body or transcript, an attachment ref, an allergy, or any cycle-derived value. Spine §6 |

### 7.3 Fields G11 requests (does not add)

| From | Field | Blocking |
|---|---|---|
| **G2** | `assignments.workout.coachNote`, `moves[].coachNote`, `moves[].restSec`, `moves[].alternatives[]` | `G06` shows her note, `G07` runs *her* rest seconds, `G08` lists coach-approved swaps. Without them these screens are fiction |
| **G2** | `assignments.meal{ slots{}, items[]{foodId|recipeId, servings, coachNote, alternatives[]} }`, `assignments.nutrition.proteinTargetG` | `G10`/`G11` and the protein bar |
| **G2** | `versions/{v}.calendar[30]` — a 30-element `'train'\|'rest'\|'free'` summary | `G05` costs **1 read instead of 30** |
| **G12** | on `coaches/{coachUid}`: `specialties[]`, `city`, `languages[]`, `priceFromEGP`, `ratingAvg`, `ratingCount`, `replyMinsP50`, `capacity`, `spotsLeft`, `publishedPortfolioVersion` | the spine gives me only `{displayName, verifiedCerts, serviceHours, acceptingClients}`; `H01` and `H02` render all of the above. `spotsLeft` and `replyMinsP50` must be **Function-written** or "12 spots left" and "replies in ~2h" are marketing |
| **G8** | `coaching` in the global deny list; Remote Config keys `coach_directory_version`, `payments_provider`, `refund_window_hours` | §6 requirement 1 and §1.3 |
| **G9** | `CycleSharingProjection.build(uid, switches)` | C12 |

---

## 8. Test cases G11 specifies

Rows in the exact format of `tests/TEST-CASES.csv`
(`id,priority,journey,screens,precondition,steps,expected,rule_protected,platform,scope`). **The CSV is not
edited by this plan.** The existing 205 cases cover none of these screens.

> **Scope column.** D1 withdrew the MVP cut, so `MVP`/`Post-MVP` no longer partition anything. These rows
> use `Launch` — the vocabulary `features.mjs` already uses. Whoever owns the CSV should re-scope the five
> existing `Post-MVP` rows (including `P1-RULE-02`) in the same pass. Named again in OQ-14.

```csv
id,priority,journey,screens,precondition,steps,expected,rule_protected,platform,scope
P0-COACH-01,P0,Find and choose a coach,"H01,H02,H03",Verified account with no coach. Directory pack cached,Open Coaching > filter Postpartum + Arabic + under 2000 EGP > open a coach > open her packages,"Results filter locally with zero Firestore reads. Her profile renders from her published portfolio blocks — cover, method, offers, consented results — not a fixed template. Packages show price in EGP and what she gets weekly.",,both,Launch
P0-COACH-02,P0,Coach profile renders the block list she built,H02,"Coach published a portfolio with cover, about, method, offers, results and a hidden video block",Open her profile > scroll to the end,"Every visible block renders in her order; the hidden block does not appear and is not downloaded as a gap. Two different coaches produce visibly different pages. No hand-built layout exists to fall out of sync.",HANDOFF: H02 renders the portfolio block list,both,Launch
P0-COACH-03,P0,Directory pack unavailable — the fallback is designed,H01,Fresh install with no cached pack and CDN unreachable,Open Coaching,"A bounded indexed Firestore query returns the first 20 accepting coaches with a cursor for more. Never an unbounded scan, never an empty screen with no explanation.",Scalability: no unbounded scan,both,Launch
P0-COACH-04,P0,Stale pack cannot oversell a coach,"H01,H03,H04",Coach shows spots left in the pack but is full server-side,Open her from the list > choose a package > continue to pay,"Checkout is refused server-side with a clear message and no charge. The pack is refreshed. Capacity is re-read at purchase, never trusted from the client.",,both,Launch
P0-COACH-05,P0,Enquire before buying,"H02,H06",Verified account with no coach,Tap Message before you decide > send a question,"A relationship in enquiry status is created, the thread opens, and no money has moved. The coach sees a new enquiry.",,both,Launch
P0-COACH-06,P0,Intake then preparing then active,"G01,G17,G02,G03,G04",Payment succeeded and coach accepted,Complete the three intake steps > submit,"G03 states plainly that nothing is scheduled yet and offers the library, My cycle and an example day. No assignment is invented. G04 becomes reachable only once the coach publishes.",A message never changes a plan — publishing does,both,Launch
P0-COACH-07,P0,The month view costs one read,G05,Active 30-day plan,Open Your 30 days,"The 30-day grid renders from the plan version summary. Firestore reads for this screen are 1 or 0 (cached), never 30.",,both,Launch
P0-COACH-08,P0,Coaching ends without breaking the app,"G16,G05,G14,T01",Relationship reaches its end date,Wait for or force the end date > open Coaching,"Plan, conversation and reviews stay readable. New assignments and messages are closed. Self-guided training, recipes, logs and My cycle continue unchanged. Cycle sharing has switched itself off.",HANDOFF 6: revocation on end of relationship,both,Launch
P0-COACH-09,P0,Work with her again starts a new engagement,"G16,H03,H04",Ended relationship,Tap Work with Sara again > buy the package,"A new engagement is created on the same thread. The old conversation and reviews are still there. No duplicate relationship document is created.",Spine C1: deterministic relationship id,both,Launch
P0-PAY-01,P0,Pay by card,"H04,H05",Coach accepted; test card available,Choose Card > complete the hosted checkout > return to the app,"The card form is the provider's hosted page in a platform browser tab, never an in-app WebView and never a field in our UI. Paid state appears only after the signed webhook lands, not on return.",Never handle card details in-app,both,Launch
P0-PAY-02,P0,Pay by mobile wallet,H04,Coach accepted,Choose Mobile wallet > complete the wallet flow,"Vodafone Cash / Orange / Etisalat / InstaPay are all offered. Payment completes and the relationship advances.",,both,Launch
P0-PAY-03,P0,Pay with a Fawry code,H04,Coach accepted,Choose Fawry > read the reference code,"A reference code and its expiry are shown with how to pay it. The app stays fully usable while it is pending. Nothing claims paid until the webhook lands.",,both,Launch
P0-PAY-04,P0,A Fawry code expires,"H04,H05",Fawry code issued and its TTL elapsed,Wait for the TTL > reopen the payment,"State reads expired, not failed, with one tap to issue a new code. The old code is dead server-side. No double charge is possible.",,both,Launch
P0-PAY-05,P0,Payment fails,H04,Card that will be declined,Attempt payment,"A plain-words reason, all three rails offered again, nothing charged, no dead end and no relationship left half-created.",,both,Launch
P0-PAY-06,P0,Coach never replies — the refund promise is real,"H04,H05",Paid; the coach neither accepts nor declines within her window,Let the refund clock elapse,"An automatic full refund is initiated, the client is told without blaming her, her spot is released, and H05 returns to the un-coached state. This is the promise H04 makes before payment.",,both,Launch
P0-PAY-07,P0,A replayed webhook cannot pay twice,H04,A successful payment,Replay the provider webhook with the same transaction id,"The payment document is unchanged and no second engagement, charge or notification is created. The document id is the provider transaction id.",Spine C1: idempotent retries,both,Launch
P0-PAY-08,P0,Buying offline is refused honestly,"H03,H04",Airplane mode,Choose a package > continue,"You need a connection to pay. No queued purchase, no optimistic paid state, no local pending charge. Retry available when signal returns.",Spine §5: payment is not offline-writable,both,Launch
P0-PAY-09,P0,The client never sends the price,"H03,H04",Instrumented client,Tamper with the request body to halve the amount,"The checkout callable prices the offer from the coach's own offer document and ignores any client-sent amount. The charge is the real price.",,both,Launch
P0-MSG-01,P0,Send a message offline and reconnect,"G14,G15",Active coaching. Airplane mode,Type a message > send > restore the network,"The bubble appears immediately at full opacity with the queued glyph, then syncs. Exactly one message exists afterwards. No blocking spinner and no failed-to-save for something that will sync.",Spine C1 + G8 queued convention,both,Launch
P0-MSG-02,P0,A failed send retries without duplicating,G15,Server rejects the first attempt,Send > observe the failure > tap Retry,"The retry reuses the same message id. One message, never two. The row shows the rejected treatment and an inline Retry.",,both,Launch
P0-MSG-03,P0,"Voice note: record, preview, send",G15,Active coaching,Hold to record > preview > send; then repeat and cancel,"Nothing is sent on selection or on release. Cancel discards. The sent note plays on both sides and is never transcribed for the coach.",,both,Launch
P0-MSG-04,P0,An attached form clip is blurred before upload,G15,Active coaching; a clip with a face in frame,Attach a form clip without touching the blur switch > send,"The uploaded object is already blurred; an unblurred file never reaches storage. Coach media follows the same rule as a community post.",Rule 6 / C11: blur before upload,both,Launch
P0-MSG-05,P0,Attachments open the record they refer to,G14,A message with a workout attachment,Tap the attachment,"It opens that assignment or session as its own record, not a picture of one. Delivery state is visible on the bubble.",,both,Launch
P0-MSG-06,P0,An ended relationship is read-only,"G16,G14",Ended relationship,Open the conversation > attempt to send,"History is fully readable. The composer is closed with a plain explanation. The security rules reject a forced write.",,both,Launch
P0-SHARE-01,P0,Sharing switches start off and are independent,"G02,W02",Coaching intake step 3,Open step 3 > turn on only Energy and appetite > send,"All switches start off. Turning one on does not turn on another. The coach sees energy and appetite only; symptoms and dates read Not shared, never no symptoms.",HANDOFF 6: independent switches default off,both,Launch
P0-SHARE-02,P0,Revoking online removes the coach's projection,"G02,A03,W02",A sharing switch is on and the coach's client view shows it,Turn the switch off with a connection,"Within seconds the key is ABSENT from clientView/current and from rollups — deleted, not filtered — and the coach's open screen updates to Not shared. Inspecting the raw document server-side shows no withheld field.",HANDOFF 6: revocation removes derived panels,both,Launch
P0-SHARE-03,P0,Revoking offline — what actually happens,"G02,A03",A sharing switch is on. Airplane mode,Turn the switch off while offline > read the on-screen wording > reconnect,"The switch flips locally at once. The copy says it applies everywhere as soon as she has signal and does NOT say immediately. The coach's panel still carries the data until the revocation syncs, and is revoked on sync.",HANDOFF 6 stated honestly (G7 Q2),both,Launch
P0-SHARE-04,P0,Ending coaching switches sharing off by itself,"G16,W02",Active relationship with sharing on,End or expire the relationship,"Sharing is cleared and shared/ rollups/ and clientView/ are deleted. A grant cannot survive because grantedForRelId names a relationship that has ended. Starting a NEW relationship with the same coach begins with every switch off again.",C12: cycle sharing ends with the relationship,both,Launch
P0-REVIEW-01,P0,The weekly review is filled from her logs,G12,Active coaching with three sessions and five food days logged,Open the weekly review,"Workouts completed and food days are read from her own logs and match them exactly. Unlogged days are labelled unlogged, never counted as failures. Only how it felt and what to change are new input. Zero extra Firestore reads.",A prescribed value is never a result,both,Launch
P0-REVIEW-02,P0,Saving a review changes nothing about the plan,"G12,G05",Active published plan,Submit the review > inspect the plan,"The published plan is byte-identical. No assignment changed. The review records, and nothing else.",HANDOFF 15: a review never edits a published plan,both,Launch
P0-REVIEW-03,P0,The coach's reply and a real plan update,"G13,G05,G14",Coach answered and published a revision effective Thursday,Open the reply,"The agreed points appear, plus a plan-updated card that points at a revision that actually exists. Yesterday's logs and any session already started keep their version. A reply with no publish behind it produces no card.",A message never changes a plan — publishing does,both,Launch
P0-INTAKE-01,P0,Allergies stated once reach the coach,"G17,W02,W06",Coaching intake step 2,Enter no nuts and vegetarian on weekdays > continue > view what the coach sees,"The coach's client view and meal planner show exactly those constraints. They came from her intake, and no coach screen offers a way to type them.",HANDOFF 13: the client is the source of her constraints,both,Launch
P0-INTAKE-02,P0,Every intake answer is editable later,"G17,A02,G02",Intake completed,Open My Profile > change the allergy list,"The change is editable in My Profile and reaches the coach's planning screens. Nothing collected at intake is frozen.","DECISIONS D3: ask early, editable forever",both,Launch
P0-INTAKE-03,P0,A coach plan cannot publish a conflicting meal,"W06,W08,G10",Client allergic to sesame; coach assigns a sesame dish,Attempt to publish the plan,"Publication is refused server-side naming the conflict. If one ever arrives anyway, the planned row is disabled with its reason at G10 and the log is blocked behind an explicit acknowledgement.",HANDOFF 13 + G5 AllergyGuard,both,Launch
P0-INTAKE-04,P0,Constraints unknown fails closed,"G10,G17",Brand-new install with no cached profile,Open a planned meal before the profile loads,"An unknown constraint is treated as unknown, not as absent. Logging requires the acknowledgement path until the profile is available.",G5 §5.1 fail-closed,both,Launch
P0-ASSIGN-01,P0,Her coach's session runs with her numbers,"G04,G06,G07,G08,G09",Active coaching with a published session,Start the session > complete a set > swap a move > finish,"The coach's order, sets, reps, rest seconds and note are used. Prescribed and actual sit side by side and untouched sets stay empty. A coach-approved swap completes the session without waiting for a reply, and skipping never needs approval.",Rule 1 + coach approval is never required to stop,both,Launch
P0-ASSIGN-02,P0,A revision published mid-session changes nothing running,"G06,G13,G05",Session in progress; coach publishes a revision now,Publish the revision while the session is open > finish the session,"The running session keeps its version and its prescribed numbers. The revision applies to future dates only. Already-saved logs are untouched.",HANDOFF 2: a revision applies to future dates,both,Launch
P1-RULE-02B,P1,Product rule guard,"G14,G13,G05,H06",Active coaching. A plan is published,"As the client, receive a coach message describing a change; the coach does not publish",The client's plan is byte-identical afterwards and no plan-updated card appears. Only an explicit publish alters a plan. MessageRepository.send has no write path to plans and the AST test proves it.,A message never changes a plan — publishing does,both,Launch
P1-RULE-01B,P1,Product rule guard,"G06,G09,G12",Assigned session with prescribed values,Open the session and log nothing,"Every actual field is empty; nothing is pre-filled from the prescription. The session summary and the weekly review count non-null actuals only.",A prescribed value is never a result,both,Launch
P1-RULE-09B,P1,Product rule guard,"G06,G07,G09,G10,G11",Active coaching,Log a set and a planned meal,"Each logs in one tap with a five-second undo and no confirmation dialog. Paying and ending coaching MAY confirm — destructive non-logging acts, the same carve-out block and deletion already have.",Undo not confirmation,both,Launch
P1-RULE-11B,P1,Product rule guard,"H01,H02",Directory with coaches of varying follower counts and client results,Apply every available sort and filter,"No sort by followers, weight, or weight lost exists or can be constructed. A post-deploy query ordering coaches by follower count FAILS because no index exists. Follower counts are displayed, never ranked.","Nothing is ranked by weight, weight lost or followers",both,Launch
P1-HRULE-06,P1,Product rule guard,"G02,A03,W02",Coaching active with switches on,Turn each sharing switch off one at a time,"Each switch is independent, defaults off, and its revocation removes exactly its own derived panel and nothing else. The on-screen wording never promises immediacy that offline cannot deliver.","HANDOFF 6: independent, default off, revokes derived panels",both,Launch
P1-HRULE-13,P1,Product rule guard,"W02,W06,K21,G17",Coach planning screens open,Attempt to edit the avoid list or the allergies from any coach screen,"No coach screen offers an editable control for either. ClientConstraints has no public setter, the shared/constraints projection is Function-written, and the security rules reject a forced write to the client's intake.",The client's constraints come from her intake or the assessment,both,Launch
P1-HRULE-15,P1,Product rule guard,"G12,G13,W09",A published plan and a review due,Submit the review and have the coach save feedback,"Neither act changes a published plan. Only an explicit publish does. The review's linked plan revision is immutable after submission.",Saving a review never edits a published plan,both,Launch
P1-HRULE-10,P1,Product rule guard,"H02,B08",A coach profile showing a consented client result,Have the client withdraw consent > reload the coach profile and any ad creative,"The result disappears everywhere at once, including from an already-published portfolio version and from rendered ads. Consent is checked at read time, never copied at publish time.",A client result is publishable only while consent is active,both,Launch
P2-OFF-H04,P2,Offline handling,H04,Airplane mode,Open Pay and attempt to pay,"Explicit offline state, no queued charge, retry offered.",,both,Launch
P2-ERR-H04,P2,Server error handling,H04,Provider returns an error,Attempt to pay,"Localised failure copy with a retry; nothing charged and no half-created relationship.",,both,Launch
P2-OFF-H06,P2,Offline handling,H06,Airplane mode,Send an enquiry message,"Queued at full opacity with the sync glyph; sends on reconnect exactly once.",,both,Launch
P2-ERR-H06,P2,Server error handling,H06,Write rejected,Send a message,"Rejected row treatment with an inline Retry that reuses the same id.",,both,Launch
P2-OFF-G01,P2,Offline handling,G01,Airplane mode,Answer the training step,"Saved on this phone; the step advances with no spinner.",,both,Launch
P2-ERR-G01,P2,Server error handling,G01,Write rejected,Answer the training step,"Localised error with retry; answers are not lost.",,both,Launch
P2-OFF-G17,P2,Offline handling,G17,Airplane mode,Enter allergies and continue,"Saved locally and synced later; the allergy guard treats unsynced-but-entered as known.",,both,Launch
P2-ERR-G17,P2,Server error handling,G17,Profile write rejected,Enter allergies,"Explicit error; the guard fails closed rather than treating unknown as none.",,both,Launch
P2-OFF-G02,P2,Offline handling,G02,Airplane mode,Toggle a sharing switch,"Flips locally with the honest wording about signal; syncs later.",,both,Launch
P2-ERR-G02,P2,Server error handling,G02,Write rejected,Toggle a sharing switch,"The switch returns to its real state with a localised error; it never displays a state the server did not accept.",,both,Launch
P2-OFF-G06,P2,Offline handling,G06,Airplane mode,Log a set in an assigned session,"Logged with undo and queued; never blocked.",,both,Launch
P2-ERR-G06,P2,Server error handling,G06,Session write rejected,Log a set,"Rejected treatment on that row with retry; the session continues.",,both,Launch
P2-OFF-G07,P2,Offline handling,G07,Airplane mode,Complete a set and let the rest timer run,"Timer is recomputed from its end time and is unaffected by connectivity.",,both,Launch
P2-ERR-G07,P2,Server error handling,G07,Write rejected mid-rest,Complete a set,"Error is shown on the set row only; the timer is not disturbed.",,both,Launch
P2-OFF-G08,P2,Offline handling,G08,Airplane mode,Swap to a coach-approved option,"The approved alternatives are available offline because they travel with the assignment.",,both,Launch
P2-ERR-G08,P2,Server error handling,G08,Swap write rejected,Swap a move,"Localised error and retry; the original move is still usable.",,both,Launch
P2-OFF-G09,P2,Offline handling,G09,Airplane mode,Finish the session and send,"Summary saves and queues; nothing claims the coach has received it yet.",,both,Launch
P2-ERR-G09,P2,Server error handling,G09,Write rejected,Finish the session,"Error with retry; completed sets are not lost.",,both,Launch
P2-OFF-G10,P2,Offline handling,G10,Airplane mode,Log the planned lunch,"Logs with undo and queues; the allergy guard still runs from cached constraints.",,both,Launch
P2-ERR-G10,P2,Server error handling,G10,Meal write rejected,Log the planned lunch,"Rejected row with retry; no double log on retry.",,both,Launch
P2-OFF-G11,P2,Offline handling,G11,Airplane mode,Correct the portion,"The correction merges into the same item; a second helping stays a separate action.",,both,Launch
P2-ERR-G11,P2,Server error handling,G11,Write rejected,Correct the portion,"Error with retry; totals never show a value the server refused.",,both,Launch
P2-OFF-G12,P2,Offline handling,G12,Airplane mode,Submit the weekly review,"Queued under its ISO-week id; submitting twice cannot create two reviews.",,both,Launch
P2-ERR-G12,P2,Server error handling,G12,Write rejected,Submit the weekly review,"Error with retry; answers are preserved.",,both,Launch
P2-OFF-G14,P2,Offline handling,G14,Airplane mode,Open the thread and send,"Cached history renders; the new message queues.",,both,Launch
P2-ERR-G14,P2,Server error handling,G14,Write rejected,Send a message,"Rejected row with retry; the thread is otherwise usable.",,both,Launch
P2-OFF-G15,P2,Offline handling,G15,Airplane mode,Record and send a voice note,"Recording and preview work; upload and message queue together and arrive once.",,both,Launch
P2-ERR-G15,P2,Server error handling,G15,Upload rejected,Send a voice note,"Upload error on the bubble with retry; the same message id is reused.",,both,Launch
P2-OFF-G16,P2,Offline handling,G16,Airplane mode,Open the ended-coaching screen,"History renders from cache; renewal states that it needs a connection.",,both,Launch
P2-ERR-G16,P2,Server error handling,G16,Read error,Open the ended-coaching screen,"Localised error with retry; never a blank screen.",,both,Launch
P2-RTL-H01,P2,Arabic RTL rendering,H01,Language set to Arabic,Open H01 in Arabic,"Mirrored layout, chips and chevrons flipped, prices in Western digits inside Arabic text, no clipping.",,both,Launch
P2-RTL-H02,P2,Arabic RTL rendering,H02,Language set to Arabic,Open H02 in Arabic,"Every portfolio block mirrors correctly, including cover overlay text and the offers row.",,both,Launch
P2-RTL-H03,P2,Arabic RTL rendering,H03,Language set to Arabic,Open H03 in Arabic,"Package cards mirror; the price stays LTR-isolated.",,both,Launch
P2-RTL-H04,P2,Arabic RTL rendering,H04,Language set to Arabic,Open H04 in Arabic,"Payment methods mirror; the amount and any Fawry code stay LTR-isolated and selectable.",,both,Launch
P2-RTL-H05,P2,Arabic RTL rendering,H05,Language set to Arabic,Open H05 in Arabic,"Coach card, review-due card and history row mirror correctly.",,both,Launch
P2-RTL-H06,P2,Arabic RTL rendering,H06,Language set to Arabic,Open H06 in Arabic,"Bubbles swap sides, the tail corners mirror, and the send and play icons flip.",,both,Launch
P2-RTL-G01,P2,Arabic RTL rendering,G01,Language set to Arabic,Open G01 in Arabic,"Stepper, chips and the package summary mirror; no truncation.",,both,Launch
P2-RTL-G02,P2,Arabic RTL rendering,G02,Language set to Arabic,Open G02 in Arabic,"Switch rows mirror with the control on the correct side.",,both,Launch
P2-RTL-G03,P2,Arabic RTL rendering,G03,Language set to Arabic,Open G03 in Arabic,"Waiting card and the three alternative rows mirror.",,both,Launch
P2-RTL-G04,P2,Arabic RTL rendering,G04,Language set to Arabic,Open G04 in Arabic,"Date strip runs right to left; the session card and notices mirror.",,both,Launch
P2-RTL-G05,P2,Arabic RTL rendering,G05,Language set to Arabic,Open G05 in Arabic,"The 30-day grid fills right to left with Western day numbers.",,both,Launch
P2-RTL-G06,P2,Arabic RTL rendering,G06,Language set to Arabic,Open G06 in Arabic,"Prescribed and actual columns mirror without swapping their meanings; labels stay attached to their values.",,both,Launch
P2-RTL-G07,P2,Arabic RTL rendering,G07,Language set to Arabic,Open G07 in Arabic,"Ring, timer and next-set card mirror; the timer digits stay LTR.",,both,Launch
P2-RTL-G08,P2,Arabic RTL rendering,G08,Language set to Arabic,Open G08 in Arabic,"The swap sheet mirrors; the selected check sits on the correct side.",,both,Launch
P2-RTL-G09,P2,Arabic RTL rendering,G09,Language set to Arabic,Open G09 in Arabic,"Summary key-value rows mirror; the note field is RTL.",,both,Launch
P2-RTL-G10,P2,Arabic RTL rendering,G10,Language set to Arabic,Open G10 in Arabic,"Food card, coach note and the three actions mirror.",,both,Launch
P2-RTL-G11,P2,Arabic RTL rendering,G11,Language set to Arabic,Open G11 in Arabic,"Slot strip, protein bar and the undo snackbar mirror.",,both,Launch
P2-RTL-G12,P2,Arabic RTL rendering,G12,Language set to Arabic,Open G12 in Arabic,"Prefilled figures mirror with Western digits; chips wrap correctly.",,both,Launch
P2-RTL-G13,P2,Arabic RTL rendering,G13,Language set to Arabic,Open G13 in Arabic,"Voice bubble, agreed list and the plan-updated card mirror.",,both,Launch
P2-RTL-G14,P2,Arabic RTL rendering,G14,Language set to Arabic,Open G14 in Arabic,"Bubbles, attachment chips, delivery states and the composer mirror.",,both,Launch
P2-RTL-G15,P2,Arabic RTL rendering,G15,Language set to Arabic,Open G15 in Arabic,"Waveform direction mirrors and the duration stays LTR.",,both,Launch
P2-RTL-G16,P2,Arabic RTL rendering,G16,Language set to Arabic,Open G16 in Arabic,"Ended banner and the three history rows mirror.",,both,Launch
P2-RTL-G17,P2,Arabic RTL rendering,G17,Language set to Arabic,Open G17 in Arabic,"Allergy chips wrap right to left; the family-pot switch row mirrors.",,both,Launch
P2-TXT-H01,P2,Large text accessibility,H01,OS font size at maximum,Open H01,"No truncated sentence, no control off screen, touch targets at least 44pt.",,both,Launch
P2-TXT-H02,P2,Large text accessibility,H02,OS font size at maximum,Open H02,"Cover headline and every block stay readable; the certificates card never clips.",,both,Launch
P2-TXT-H03,P2,Large text accessibility,H03,OS font size at maximum,Open H03,"Package lines wrap rather than truncate; the price stays visible.",,both,Launch
P2-TXT-H04,P2,Large text accessibility,H04,OS font size at maximum,Open H04,"Every payment method and the refund sentence stay fully readable.",,both,Launch
P2-TXT-H05,P2,Large text accessibility,H05,OS font size at maximum,Open H05,"Cards stack without overlap; the review-due action stays reachable.",,both,Launch
P2-TXT-H06,P2,Large text accessibility,H06,OS font size at maximum,Open H06,"Bubbles grow and the composer stays on screen above the keyboard.",,both,Launch
P2-TXT-G01,P2,Large text accessibility,G01,OS font size at maximum,Open G01,"Chips wrap; the continue button stays reachable.",,both,Launch
P2-TXT-G02,P2,Large text accessibility,G02,OS font size at maximum,Open G02,"Switch labels wrap without pushing the control off screen.",,both,Launch
P2-TXT-G03,P2,Large text accessibility,G03,OS font size at maximum,Open G03,"The waiting explanation wraps fully; every alternative row is reachable.",,both,Launch
P2-TXT-G04,P2,Large text accessibility,G04,OS font size at maximum,Open G04,"The date strip remains usable and the start button is not pushed off screen.",,both,Launch
P2-TXT-G05,P2,Large text accessibility,G05,OS font size at maximum,Open G05,"Grid cells grow without overlapping; labels stay legible.",,both,Launch
P2-TXT-G06,P2,Large text accessibility,G06,OS font size at maximum,Open G06,"Prescribed and actual stay side by side and legible; the coach note wraps.",,both,Launch
P2-TXT-G07,P2,Large text accessibility,G07,OS font size at maximum,Open G07,"The timer and next-set card stay on one screen.",,both,Launch
P2-TXT-G08,P2,Large text accessibility,G08,OS font size at maximum,Open G08,"Sheet scrolls; every option and the skip action stay reachable.",,both,Launch
P2-TXT-G09,P2,Large text accessibility,G09,OS font size at maximum,Open G09,"Summary rows wrap; the send action stays reachable.",,both,Launch
P2-TXT-G10,P2,Large text accessibility,G10,OS font size at maximum,Open G10,"The coach note and ingredient chips wrap; Ate this stays reachable.",,both,Launch
P2-TXT-G11,P2,Large text accessibility,G11,OS font size at maximum,Open G11,"Slot cards and the protein row stay legible; the snackbar does not cover the action.",,both,Launch
P2-TXT-G12,P2,Large text accessibility,G12,OS font size at maximum,Open G12,"Questions and chips wrap; the optional field is reachable.",,both,Launch
P2-TXT-G13,P2,Large text accessibility,G13,OS font size at maximum,Open G13,"The agreed list wraps and the plan-updated card stays tappable.",,both,Launch
P2-TXT-G14,P2,Large text accessibility,G14,OS font size at maximum,Open G14,"Bubbles and the service-hours banner wrap; the composer stays visible.",,both,Launch
P2-TXT-G15,P2,Large text accessibility,G15,OS font size at maximum,Open G15,"Recording controls stay on screen at maximum text size.",,both,Launch
P2-TXT-G16,P2,Large text accessibility,G16,OS font size at maximum,Open G16,"The ended explanation wraps fully and every history row is reachable.",,both,Launch
P2-TXT-G17,P2,Large text accessibility,G17,OS font size at maximum,Open G17,"Allergy chips wrap onto multiple lines without clipping; the source sentence stays readable.",,both,Launch
```

**Totals: 121 rows — 37 P0, 8 P1, 76 P2** (76 P2 = 30 offline/error on the 15 writing screens + 46
RTL/large-text on all 23). Counts machine-verified against the block above, not estimated. `P1-RULE-02B` is the client-side twin of the existing `P1-RULE-02`; the `P1-HRULE-*` prefix is new
and deliberately distinct so it cannot collide with a future §2 rule number.

---

## 9. Scalability gate — self-check, with the result stated

| Gate | Result | Evidence |
|---|---|---|
| **Unbounded collection scan** | **PASS** | `H01`, the one search surface, reads **zero** Firestore documents — it filters a CDN artefact locally. The cold fallback is `limit(20)` + cursor on a declared composite index. Chat is `limit(30)` + cursor. `G05` is one document, not a 30-document range. `relationships` is `allow list: if false`, so an unbounded scan is not expressible even by a malicious client. No collection-group query and no collection-group index exists on anything of mine. |
| **Fan-out write that grows with followers** | **PASS** | Nothing is copied into anyone's feed (C9). The derived writes are `shared/constraints` (on profile/intake change — rare), `rollups/{isoWeek}` (**week-keyed, so idempotent**) and `clientView/current` (debounced). All three are **one document per relationship**, and a coach's write set is bounded by the capacity *she* declares (~20–50, `K04`). Nothing grows with followers, audience or time. Adopting G12/G14's paths **removed** my per-day panel write, which is why §2.1's Function-write line fell from 6–8 to 4–6. `lastMessageAt` is debounced to ≤1 write/60 s per thread, keeping the hottest document two orders of magnitude below Firestore's per-document ceiling. |
| **Unindexed hot-path query** | **PASS — with one composite index declared, not hidden** | Every hot read on a **client** screen is a point `get` on a deterministic id (`relId`, ISO week, date). **Three** composite indexes exist: two on `coaches` for the cold discovery fallback, and one on `relationships` (`coachUid, status, queue.oldestUnansweredAt`) which **is** on a hot path — the coach's W01/W10/W11 listener. I state that plainly rather than claiming none: spine §4's warning is that a hot-path composite signals a wrong access pattern, and here the alternative (four queries, four indexes, four times the reads) is measurably worse. It is declared in `firestore.indexes.json`, bounded at `limit(30)`, and the rules refuse any query that is not the coach's own. §11-R4. |
| **Needs a migration to reach 100k MAU** | **PASS, with the growth path named** | `relId` is deterministic and stable; renewals become `engagements/*` rather than new relationship documents. Payments are keyed by the provider's transaction id. The one growth boundary is the directory pack: above **~6,000 coaches** (≈330 KB gz) it shards to `directory/{city}.json` — a **content-pipeline change in the builder Function, not a schema change**: no document moves, no field changes type, and `coaches/**` is untouched. The Firestore fallback query is already city-faceted for exactly this. |

**One thing I corrected in my own design while checking it** (§2.2): `buildCoachDirectory` as first drafted
re-read every coach document every 15 minutes — 576k reads/day, **twice the entire product's read budget**,
to serve a screen whose whole purpose was to cost nothing. It is now an incremental
`where(updatedAt > lastBuild)` patch with a nightly full rebuild: ~50 reads per build, ~5k/day.

---

## 10. Open questions — named, because silence is a defect

| # | Question | Who decides | Why it matters |
|---|---|---|---|
| **OQ-1** | **`K09` says "She pays only once you accept"; `H04` charges before the coach has accepted.** Two purchase paths exist (enquire-then-pay, and buy-direct) and one sentence describes only the first. | Owner + the coach-side group | The copy is currently false on the buy-direct path. Either the sentence changes, or buy-direct is removed from `H03`/`H04`. |
| **OQ-2** | **How long does a coach have before the money goes back?** I propose `replyWindowMins × 2`, floored at 24 h and capped at 72 h. | Owner | `H04` promises "if she never replies, you get your money back" before payment. A promise with no clock is not a promise. |
| **OQ-3** | **Who bears the processing fee on a refund?** Paymob generally retains its fee on refunded transactions, so a full refund costs the platform ~2.75%. | Owner | At 170 purchases/day a 2% decline-and-refund rate is ~EGP 3,400/month of pure loss. It is budgetable, but only once it is decided. |
| **OQ-4** | **Apple: is coaching a real-world service (IAP-exempt) or digital content (StoreKit mandatory, 15–30%)?** G8 raised this and it is unresolved. | Owner + legal | If Apple rules it digital, the 80/20 split is arithmetically impossible on iOS and the Egypt rails cannot be used there. This is a launch blocker, not a detail. |
| **OQ-5** | **Merchant of record.** The platform collects 1,800 EGP and pays out 80% — that makes it the merchant, requiring commercial registration, a tax card, and ETA e-invoicing for both the client's receipt and the coach's payout. | Owner (runbook §10) | No amount of code removes it. |
| **OQ-6** | **`coaches/{coachUid}` is missing every field `H01`/`H02` render** (specialties, city, languages, priceFrom, ratingAvg/Count, replyMinsP50, capacity, spotsLeft, publishedPortfolioVersion). The spine gives four fields. | G12 + spine owner | Without them the marketplace has no facets and `H02` has no header. |
| **OQ-7** | **`users/{uid}.coaching` needs a G8 ruleset change** (global deny for client writes, Function-written) and an ownership-table row. | G8 + spine owner | Without it, finding her own coach costs a composite-indexed query on a tab root. |
| **OQ-8** | **"Review" means two different things.** The spine's `relationships/**/reviews/*` is the *weekly check-in*; `F60` ("rate a coach after a month; reviews show on her profile") and `H01`'s "4.8 ★ (126)" are a *public rating*, which has no home in the spine. I propose `coaches/{c}/ratings/{clientUid}`. | Spine owner | Two objects sharing a word is how a field ends up with two writers. |
| **OQ-9** | **"Replies in ~2h" and "12 spots left" must be measured, not typed.** `K18` says the reply time is platform-measured; nothing defines the percentile, the window, or the value for a coach with no history. | Owner + G12 | A typed claim on a marketplace listing is an advertising problem, not a UI one. |
| **OQ-10** | **May an unverified woman buy coaching?** Research §7b says she may *browse* coach profiles while waiting for a reviewer. I propose browse yes, **purchase requires verified**, because payment opens a private 1:1 channel. | Owner | Currently an assumption in my `createCheckout` guard. |
| **OQ-11** | **A client deletes her account; her coach keeps business records.** I delete `relationships/{relId}/**` and `relationship-media/{relId}/**`, leaving only pseudonymous money rows under `coaches/{c}/earnings/*`. Is that the right PDPL/commercial balance? Also: is a suspended relationship refunded pro-rata? | Legal + owner | G7's deletion promise and a coach's tax records point in opposite directions. |
| **OQ-12** | **Voice-note retention.** ~157k notes/month. Keep forever, or expire with the engagement + N months? | Owner | Storage is cheap; indefinite retention of a woman's voice is a privacy decision, not a cost one. |
| **OQ-13** | **Minimum age and paying.** The open age question (16 vs 18) collides with a minor entering a paid contract. | Legal | If 16 ships, a paid coaching contract may need guardian consent in Egypt. |
| **OQ-14** | **The CSV `scope` column is obsolete after D1.** My rows use `Launch`; the five existing `Post-MVP` rows should be re-scoped in the same pass. | CSV owner | Three vocabularies in one column is how a QA matrix goes wrong. |
| **OQ-15** | **`G12`'s "Add weight or photos?" toggle.** Weight is G6's `measurements`, which G7 states is private, local-only for photos, and never shared. If a client opts in, what exactly reaches the coach? | G6 + G7 + owner | The switch exists on the screen today; nothing behind it is specified, and the wrong answer puts scale weight in front of a coach the product otherwise refuses to rank anyone by. |
| **OQ-16** | **`G02` previews cycle sharing via `Y12`** (G9's screen). The preview must be generated by the same projector that builds the real projection, or the preview lies. | G9 | "See exactly what she would see" is a guarantee, not a label. |

---

## 11. Reconciliation with the six plans written in parallel

G9–G15 were written while this one was. They are consumers of the collection I own, so where we
disagreed I resolved it here rather than leaving two plans that cannot both be built. **Adopting a
consumer's name cost me nothing; making two groups rewrite would have cost the build.**

| # | Conflict | Resolution |
|---|---|---|
| **R1** | **`relId` had three formats.** Mine `{clientUid}__{coachUid}`, G12's `{coachUid}_{clientUid}`, G14's requested `{coachUid}__{clientUid}`. My Storage rules *parse* this id, so it is load-bearing, not cosmetic. | **`{coachUid}__{clientUid}`.** Coach-first on a 2:1 vote of consumers; double underscore kept because a single `_` parses ambiguously if uid alphabets ever widen. Applied to §1.2, §6 and the Storage rule. |
| **R2** | **The spine was amended mid-flight** (after I had read it): the sharing grant "lives ONCE" on the relationship carrying `grantedForRelId`; G9 reads and never writes it. G9's own OQ-2 proposes the opposite split — cycle categories to G9's map, the rest to mine. | **The spine amendment wins**; G9's OQ-2 is superseded and should be closed. One map, on the relationship, with `grantedForRelId == relId` enforced in rules. I adopted G9's category name `datesAndPatterns` over my `cycleDates` so the switch and the projection cannot drift. |
| **R3** | **Three names for one projection:** my `panels/{yyyy-MM-dd}`, G12's `clientView/current`, G14's `shared/constraints` + `rollups/{isoWeek}`. | **Theirs, all three, verbatim.** Also cheaper than mine: constraints change rarely and a rollup is week-keyed (idempotent), which **removed a per-client-per-day write** — §2.1's Function-write line fell from 6–8 to 4–6. |
| **R4** | **G14 needs a query my rules forbade.** W01/W10/W11 run one `limit(20)` listener over `relationships where coachUid==me && status==… orderBy queue.oldestUnansweredAt`; I had written `allow list: if false`. | **Guarded list granted** (coach role, `limit ≤ 30`, `coachUid == auth.uid`), `queue{}` added to the relationship, composite index declared, and my `coaches/{c}/clients/*` index collection **withdrawn** as redundant. §9's gate row restated honestly: there *is* one hot-path composite index and it is the coach's. |
| **R5** | **Two constraint APIs.** My `ClientConstraintsView.of(relId)` vs G14's `ClientConstraintResolver.resolve(clientUid)`, which HANDOFF 13 requires to be *the only* constructor. | **G14's.** I publish the `shared/constraints` **projection**; they own the resolver that merges it with the assessment. Two constructors of one safety object is exactly the drift rule 13 exists to prevent. |
| **R6** | **H02's delivery.** I costed it at 2–8 Firestore reads; G13 already serves published portfolios from a CDN at **0 Firestore reads**, with consent enforced by object existence. | **G13's path.** I render their `PortfolioView` widget, own the chrome only, must handle `hidden`/`notBuilt` as states rather than errors, copy the agreed price onto the relationship at acceptance (`priceEGP` — so B11's "price rises apply to new clients only" is true), and emit the enquiry/view beacons B12 needs. |
| **R7** | **The money model genuinely conflicts.** G12 §3.3 says an enquiry is *authorised, not captured*, captured on accept, voided on decline/expire/withdraw. My §3.2 argued capture-always-refund-on-decline **because Fawry and wallets cannot authorise-and-hold**. | **Both are right, per rail, and neither may be averaged.** Card → authorise, capture on accept, void on decline (G12's model exactly). Fawry/wallet → capture, refund on decline. The *user-visible* promise is identical, which is what H04 states. **G12 must not assume a void is always available** — on a Fawry code there is nothing to void, only money to send back. Raised to G12 as a blocking correction; tests `P0-PAY-06`/`P0-PAY-07` cover both rails. |
| **R8** | **G12 caught a real cost defect in my rules.** My `messages` rules did `get(parent)` — **one billed read per message read and per message write**, on the hottest path in the group. | **Fixed.** `coachUid`/`clientUid` are denormalised onto every message, frozen at create, and the rules decide membership from the document in hand. Zero-read rules. The same trick made the three projection blocks zero-read by splitting the relId in the path. |
| **R9** | **HANDOFF 13 is now tested three times** — my `P1-HRULE-13`, G12's `P1-RULE-12`, G14's `P1-RULE-19`. | Not a defect, but the CSV owner should keep **one** and cross-reference the others; three tests of one rule drift apart. Flagged, not silently deduped, because deleting another group's test is not mine to do. |

**Still unresolved and owned by someone else:** G12 asserts `coachEnquiryDecision` is the sole writer of
`status` for `enquiry→accepted|declined` — **confirmed** here (my rules make every `status` write
Function-only). G13's Q11 asks G11 to emit portfolio view/enquiry beacons — **accepted**, listed in §7.2.
