# G6 — Progress & rewards

**Screens:** `P01` Your progress · `P02` Milestones · `P03` Personal bests · `P04` Body, privately
**Owns:** `users/{uid}.rewards`, `users/{uid}.weeklyGoal`, `users/{uid}/weeks/*`, `users/{uid}/bests/*`,
`users/{uid}/measurements/*`, and one new G6 collection `users/{uid}/awards/*` (§1.3).
**Owns rules 3 and 11**, plus "nothing earned is ever taken away" and "a recalled session never sets a best".

Two sentences carry the plan:

1. **Derive for display, record for reward.** One pure domain function computes a week's state and its
   awards. The client runs it to render — instantly, offline — and a Cloud Function runs it to write the
   currency, authoritatively and idempotently. Both read the same documents, so they cannot disagree.
2. **The client never writes currency.** `weeks/*`, `bests/*`, `awards/*` and every `rewards` field are
   Function-written. What a woman writes is *evidence* (sessions, meals, measurements); what the server
   writes is the *score*. A reward a client can write is a reward that is not earned.

> **Revised twice: once against G2–G5/G7, once against G8 and `RECONCILIATION.md`.** §7.4 and §7.5 log
> every change. Two findings dominate. (a) I originally let the client write `weeks/*`; G3 and G4 both
> published `allow write: if false` there, so I yielded — their design is better and mine would not have
> deployed. (b) `RECONCILIATION.md` §1 rules that **`users/{uid}` rules are authored once, by G8**, and
> groups supply requirements rather than rules. So §6 is now a **requirements delta against G8's
> ruleset**, and it closes three holes in that ruleset that would otherwise make the reward economy
> forgeable.

---

## 1. Data model

### 1.1 Spine fields, unchanged

| Path | Field | Type | Writer |
|---|---|---|---|
| `users/{uid}` | `rewards.points` | int, `increment` | **Function** |
| `users/{uid}` | `rewards.level` | int | **Function** |
| `users/{uid}` | `rewards.tier` | string (= displayTier) | **Function** |
| `users/{uid}` | `weeklyGoal.sessionsTarget` | int 2–4 | client (its only field here) |
| `users/{uid}` | `weeklyGoal.countedWeeks` | int, `increment`, monotonic | **Function** |
| `users/{uid}` | `weeklyGoal.restWeeksBanked` | int 0–2 | **Function** |
| `users/{uid}` | `weeklyGoal.currentRun` | int (weeks, resettable) | **Function** |
| `users/{uid}/weeks/{yyyy-Www}` | `sessionsTarget`, `sessionsLogged`, `counted`, `repairedByRestWeek`, `closedAt` | per spine | **Function** (all five) |

**Every field has exactly one writer.** "Function" is the Admin SDK inside G6's Cloud Functions, which
bypasses rules; the client SDK is denied by the rules delta in §6.

### 1.2 Extensions inside G6-owned collections (declared, not smuggled)

| Path | Field | Type | Why | Writer |
|---|---|---|---|---|
| `rewards` | `earnedTier` | string | monotonic tier floor; unlocks read this, never `tier` | Function |
| `rewards` | `pointsToNextLevel` | int | **G4's request** — R10/R12 render without arithmetic | Function |
| `rewards` | `sessionsLogged` | int, `increment` | P02 "50 sessions", R10 "Session 20" | Function |
| `rewards` | `bestsCount` | int, `increment` | P01 tile "8 so far", tier input | Function |
| `rewards` | `milestones` | map<id, timestamp>, **≤12 keys** | P02 at zero extra reads | Function |
| `rewards` | `pointsToday`, `pointsDayKey` | int, string | the daily cap | Function |
| `weeklyGoal` | `recent8` | array, **≤8** of `{w,s,t,c,r}` | collapses P01's 8-doc range read to 0 | Function |
| `weeklyGoal` | `bestRun` | int, monotonic | P01 "best run 9" | Function |
| `weeklyGoal` | `lastClosedWeek` | string `yyyy-Www` | the lazy close's watermark | Function |
| `weeklyGoal` | `lastRepairedWeek`, `tierSlippedWeek` | string `yyyy-Www`? | **granted to G3 (their Q3)** — T04/T05 detect a pending notice from the user doc they already read, saving a 5th Monday read | Function |
| `weeklyGoal` | `tz` | string IANA, default `Africa/Cairo` | the week boundary is hers, not the device's (§3.1) | client |
| `weeklyGoal` | `goalKind` | `'sessions'\|'foodDays'` | F38 offers a food-day goal | client |
| `weeks/*` | `creditedSessionIds` | string[], **≤20**, `arrayUnion` | the idempotency key set (§4.2); G3 renders against it | Function |
| `weeks/*` | `foodDaysLogged` | int, `increment` | `goalKind: 'foodDays'` | Function |
| `bests/{exerciseId}` | `{ metric, loadKg?, reps?, holdSec?, rank?, dateKey, sessionId, previous{} }` | | P03's four kinds of best | Function |
| `measurements/{yyyy-MM-dd}` | `{ weightKg?, waistCm?, hipsCm?, armCm?, thighCm?, takenAt, note? }` + **`schemaV`, `updatedAt`, `clientWrittenAt`, `opId`** (G8 K3) | all nullable | P04 | **client** |

All extensions are fixed-size (8, 12, 20) or monotonic scalars. Nothing grows with time or population.

**`loadKg`, not `weight`.** G4 asked for `bests.{weight, reps, dateKey}`; I grant the shape but rename
the first field, because G7 projects bests publicly behind `privacy.showBests` and warns "numbers only;
never scale weight (C7, rule 11)". A field called `weight` inside a record G7 may publish is one careless
line from publishing body weight. `loadKg` is the dumbbell, and cannot be mistaken for the woman.
`dateKey` (`yyyy-MM-dd`) sorts lexicographically, so P03 needs no timestamp field and no extra index.

**The K3 metadata fields are not optional.** G8's `requiredMeta()` rejects any write lacking
`schemaV:int` and `updatedAt == request.time`. My first draft's `measurements` key whitelist omitted
them, so a K3-conformant write would have been **rejected by my own rule** — a real bug, fixed here and
in §6.

### 1.3 New G6 collection — the award ledger

```
users/{uid}/awards/{awardId}      owner G6    NO CLIENT WRITE    TTL 400 days
  { kind, points, awardedAt, expiresAt, ref, schemaV }
```

`awardId` is **deterministic and semantic**, which is the entire idempotency mechanism:

| Kind | `awardId` | Points | Under daily cap? |
|---|---|---|---|
| session, `source == 'live'` | `session:{sessionId}` | 30 | yes |
| session, any other source (`recalled`, `unplanned`) | `session:{sessionId}` | **15** | yes |
| personal best | `best:{exerciseId}:{sessionId}` | 10 | yes (≤3/day) |
| food day | `meal:{yyyy-MM-dd}` | **5** (G5's published figure) | yes |
| week counted | `week:{yyyy-Www}` | 40 | **no** — unrepeatable by key |
| milestone | `milestone:{milestoneId}` | 25 | **no** — 12 in a lifetime |
| protein target hit | — | **deferred, not built** (§9.6) | — |
| opening the app, posting, inviting, completing a profile | *no key exists* | **0** | — |

Daily cap **60 points**, on the repeatable kinds only. The cap stops grinding; a thing that happens once
cannot be ground, so week and milestone awards sit outside it. The last row is enforced by absence —
`AwardTable` has no case for those events, so no code path pays for them (research §7).

**Points cannot fall:** `rewards.points` is `increment`-only and the ledger is append-only (no client
write, and no update or delete for anyone). `level = floor(points / 80) + 1`, so the level cannot fall
either. The TTL bounds ledger storage permanently; milestone state is mirrored in `rewards.milestones`,
so expiry loses nothing a screen reads.

### 1.4 Indexes

**Composite indexes required: zero.** Two automatic single-field indexes (`bests.dateKey`,
`measurements.__name__`), both per-user subcollections. I add nothing to `sessions`.

**C7 is enforced by four absences, not a check:** no composite index on weight, weight lost or follower
count (G8's `index_allowlist_test.dart` asserts this); no `/{path=**}/` rule for `bests` or
`measurements`, so collection-group queries are denied by default; no query method on
`MeasurementsRepository` at all — `latest()` and `historyForOwner()` only, both scoped to
`request.auth.uid`; and no weight parameter anywhere in `TierPolicy`. P1-RULE-11 now inspects "the index
configuration" explicitly, which the first absence answers.

**An absence of *composite* indexes is not sufficient, and my first two drafts were wrong about this.**
The spine's C7 amendment (raised by G4 against `sessions.sets`) applies to me with equal force and says
so: **Firestore auto-indexes every field by default**, so in a deployed project
`measurements.weightKg` **is** a live, queryable single-field index unless an exemption is declared. On
that index `orderBy('weightKg')` executes, and rule 11 is false in production no matter what my domain
layer says. Required, and not optional:

| Exemption in `firestore.indexes.json` | Why |
|---|---|
| `users/*/measurements` — **all fields**, ascending + descending + array-contains disabled | kills `orderBy(weightKg)` and every other body-measurement sort at the storage layer. `__name__` (the date key) is all P04 needs |
| `users/*/bests` — `loadKg` disabled; keep `dateKey` | P03 sorts by date only. An index on lifted load is a ranking surface waiting for a future developer |

This is a **deployment** artifact, not code: it must be asserted in CI and re-checked after every
`firebase deploy`, because a project can silently regain the index if the exemption is dropped. I hand
this to G8 as a §6 requirement, alongside their existing `index_allowlist_test.dart`.

---

## 2. Queries and cost

Budget: 35,000 DAU, ~8 reads / ~6 writes per active day, 40% of traffic 19:00–23:00 Cairo.

### 2.1 Reads per screen

| Screen | Query | Index | Billed reads | Network, warm |
|---|---|---|---|---|
| **P01** | `users/{uid}`.get() + `users/{uid}/weeks/{currentKey}`.get() | none (2 point gets) | **2** | **0–1** |
| **P02** | `users/{uid}` (already in memory) + optional `plans/{uid}/versions/{v}` | none | **0–1** | 0–1 |
| **P03** | `users/{uid}/bests` `.orderBy('dateKey','desc').limit(50)` | auto `dateKey` | n, typ. **8–20**, hard bound 124 | 0–n |
| **P04** | `users/{uid}/measurements` `.orderBy(__name__,'desc').limit(24)` | auto `__name__` | ≤24, typ. **6–12** | 0 (she wrote them) |

**P01 holds the 3-read budget at 2, and the change is a reduction.** The spine budgets "user doc, current
week, last 8 weeks (1 range read)" — but Firestore bills per document returned, so that range read is 8
billed documents and the literal design costs 9. `weeklyGoal.recent8` (a fixed 8-element array the
Function rewrites wholesale at each close, from data already in hand) carries the eight bars of
`weekBars([2,2,0,2,2,2,2,1])`, the tier-hold sentence and both tier progress bars. The `weeks`
collection stays the source of truth; `recent8` is a derived cache inside a document P01 must load
anyway. The current week is read live and separately because "This week, 2 of 3" must be instant —
`recent8` holds only **closed** weeks. Arriving from T01, both documents are already on G3's snapshot
(their reads #1 and #4), so **P01 typically costs 0 additional network reads.** With Progress as a tab
root (G8 §12-7), P01 is 1 tap from anywhere and P02–P04 are 2, which is my half of P0-NAV-01.

Amortised: P01 ~0.6, P02 ~0.1, P03 ~1.2 (opened ~10% of days), P04 ~0.2 (~2×/month) → **≈2 client reads
per active day.**

### 2.2 Writes

| Trigger | Who | Writes |
|---|---|---|
| add weight / measurement (P04) | **client** | 1 merge write to `measurements/{date}` |
| change weekly goal (T05) | **client** | 1 write to `weeklyGoal.sessionsTarget` |
| session completed | Function, on G4's `SessionFinished` | 1 user doc + 1 week doc + 1–7 award/best docs |
| meal created | Function, on G5's `onCreate`/`firstLogAt` | 1 user doc + 1 award + (if `goalKind: 'foodDays'`) 1 week doc |
| first app open in a new week | Function, via callable `closeStaleWeeks()` | 1–8 week docs + 1 user doc + ≤2 awards |

Client writes ≈ **0.1 per active day** — G6 is almost entirely a read surface for the client, which is
the point of moving the counters server-side. Function writes ≈ **2.5**. Total ≈ **2.6 writes** against
the 6-write allowance.

**Honest note on reads:** Function reads are billed too. The session trigger reads ≤6 `bests` + 1 week +
1 user doc ≈ 8, at ~0.3 sessions/active day ≈ **2.4 server reads per active day**. Client ~2 + server
~2.4 = **~4.4 reads per active day**, inside the 8-read envelope with room for the rest of the app.

### 2.3 Answering G8's "no per-write Firestore trigger"

G8 §4 states: *"A Function on every meal/session write would be 6.3M invocations/month. Rewards and week
counting are client-side `increment`s (C4) plus a bucketed server reconciliation sweep."* Two responses,
and the second is the decisive one.

**On cost — the 6.3M figure does not apply to my design.** I do not trigger on every write. I trigger on
the `completedAt` null→non-null **transition** (skipping the ~14 set updates C2 puts inside one session
document) and on meal **create** only:

| Trigger | Volume / month |
|---|---|
| session completions (35k DAU × 2/week ÷ 7) | ~300k |
| meal creations — **already in G5's budget**, not new | ~1.05M |
| week closes (100k MAU × 1/week) | ~430k |
| **Total** | **~1.8M** |

Cloud Functions gen2 bills nothing on the first 2M invocations a month, so this lands **inside the free
tier and inside G8's own §4 line** ("~1.5M inv … largely free tier"). At 3M it would cost $0.40. Cost is
not a reason to prefer client increments.

**On security — client-side reward increments cannot be secured, at any price.** If the client writes
`rewards.points`, no rule can validate the amount: a rooted device writes `increment(1000000)` and the
rule sees a well-formed increment. Rules cannot express "this increment is justified by a session that
really happened". C5's own reasoning — *"if a client can write its own verification flag, a women-only
app has a one-line bypass"* — applies verbatim to the currency. The Function is not an optimisation; it
is the only design in which a point means anything. **I therefore decline client-side reward increments
and require the rules delta in §6.** C4 still governs *how* the Function writes counters: increments,
never read-modify-write.

### 2.4 Monthly figure

Firestore: 35k × 30 × (4.4 reads + 2.6 writes) ≈ 4.6M reads + 2.7M writes ≈ $1.38 + $2.43 at G8's
regional rates ($0.03/100k reads, $0.09/100k writes). Functions ~1.8M invocations ≈ **$0** (free tier).
Ledger storage settles near 6 GB under the TTL ≈ $0.90. **≈ $5/month at 100k MAU**, inside G8's $1,500
ceiling and immaterial beside the SMS and Amplitude lines that dominate it. G6 is not where this
product's money goes.

---

## 3. State machines

### 3.1 A week — `users/{uid}/weeks/{yyyy-Www}`

**Boundary (product decision): Monday 00:00:00 → Sunday 23:59:59.999 in `weeklyGoal.tz`, default
`Africa/Cairo`; the key is the ISO-8601 week, `yyyy-Www`.** Monday because T04 and T05 are written as
Monday screens — Monday is when the app speaks.

| State | Predicate | Entered by |
|---|---|---|
| **open** | `closedAt == null && sessionsLogged < sessionsTarget` | first credit of the week, or the previous week's close |
| **met** | `closedAt == null && sessionsLogged >= sessionsTarget` | the credit that crosses the target → `counted = true` **and the week award fires immediately** (P0-WEEK-01: "Points award once") |
| **closed · counted** | `closedAt != null && counted && !repairedByRestWeek` | close of a `met` week |
| **closed · repaired** | `closedAt != null && counted && repairedByRestWeek` | close of an `open` week while `restWeeksBanked > 0` |
| **closed · missed** | `closedAt != null && !counted` | close of an `open` week with an empty bank |

```
            credit crosses target
  open ───────────────────────────► met ──── close ───► closed·counted
    │                                                    (counted, no repair flag)
    ├── close, restWeeksBanked > 0 ──► closed·repaired   (counted = true, bank −1, NO points)
    └── close, bank empty ───────────► closed·missed      (currentRun → 0; countedWeeks unchanged)
```

| To | `countedWeeks` | `restWeeksBanked` | `currentRun` | `bestRun` | points |
|---|---|---|---|---|---|
| counted | +1 | +1 every 4th **earned** counted week, cap 2 | +1 | `max(bestRun, currentRun)` | +40 at the crossing |
| repaired | +1 | −1, and `lastRepairedWeek = key` for G3's T04 | unchanged — the run survives, which *is* the repair | unchanged | **0** |
| missed | unchanged | unchanged | **0** | unchanged | 0 |

`counted` is irreversible and `closedAt` write-once, so a late-syncing session can never un-count or
reopen a week.

**Repair is automatic and unasked.** `RestWeekRepair.decide()` runs inside the close transaction — no
prompt, no confirmation, no permission sought. T04 reports what already happened. Repaired weeks do
**not** earn toward the next rest week (only `counted && !repairedByRestWeek` advances
`restWeekProgress`), so repair cannot fund itself. With several weeks missed and two banked, repair
applies **most-recent-first**, because both `currentRun` and the tier's recency floor weight recency.

**A woman who crosses a timezone — and my one objection to G8 K8.** The week key is computed **only**
from `weeklyGoal.tz`, a property of the woman, never of the handset. If the key followed the device, a
Cairo→Toronto flight on a Sunday night would recompute a boundary that had already passed: a closed week
could gain sessions after `closedAt`, or a session could be filed to a week that no longer exists. The
visible consequence, stated rather than hidden: a session logged in Toronto at Sunday 20:00 EDT is
Monday 02:00 Cairo and credits the **new** week. When the device zone differs from `tz` for 3+ days the
app offers one explicit "move your week to this timezone?"; accepting applies **from the next boundary
only** and never recomputes a past week.

G8 K8 hardcodes `AppClock.today()` to Africa/Cairo and their §12-13 proposes trimming the tz database to
a single zone. **I require `AppClock.isoWeek(tz)` to take a zone parameter and the full IANA database to
ship.** The reason is not travel as a luxury case: there is a very large Egyptian population in the Gulf
(UAE, Saudi, Kuwait — all UTC+3/+4), and a Cairo-hardcoded boundary silently misfiles their
late-evening sessions into the wrong week, corrupting the product's core unit for an entire market.
~500 KB in a binary that already ships video-capable code is the cheaper error. DST is the second trap
and G8 has it right: Cairo is UTC+2/+3 (DST last Friday of April → last Thursday of October, reinstated
2023 after the 2014 suspension), so a fixed `+02:00` offset misfiles a Sunday-23:30 log twice a year —
their `cairo_dst_test.dart` is the correct test and I adopt it.

**How a week closes.** See §10 for the agreement with G8, which is the lazy close without their sweep.

### 3.2 A tier

Five tiers on **two axes**, which reconciles P01 ("Next: Strong · Counted weeks 14 of 20 · Personal
bests 8 of 10") with T05 ("Regular asks for four of your last eight weeks"): promotion is cumulative and
therefore permanent; holding is recent and therefore losable by one step.

| Tier | Promote at cumulative `countedWeeks` | and `bestsCount` | Holds while, of last 8 closed weeks |
|---|---|---|---|
| First steps | 0 | 0 | — |
| Showing up | 1 | 0 | ≥1 counted |
| Regular | 6 | 3 | **≥4 counted** |
| Strong | **20** | **10** | ≥4 counted |
| Unshakeable | 40 | 20 | ≥6 counted |

```
earnedTier  = max(earnedTier, highest tier whose cumulative thresholds are met)   // monotonic
displayTier = recencyFloorMet(earnedTier) ? earnedTier : oneStepDown(earnedTier)  // slip ≤1 by construction
```

| Transition | Condition | Effect |
|---|---|---|
| promote | cumulative thresholds met | `earnedTier` and `displayTier` rise; an unlock opens |
| slip | recency floor fails | `displayTier = earnedTier − 1` (floor: First steps); `tierSlippedWeek = key` for G3; **`earnedTier` untouched, no unlock closes, no points removed** |
| return | one counted week restores the floor | `displayTier = earnedTier`, silently — no fanfare on the way back |

**This is where "nothing earned is ever taken away" stops being copy and becomes structure.**
`UnlockPolicy.isUnlocked(feature)` reads `earnedTier`, which is monotonic; only the rendered label moves.
T05's "Everything Regular opened" list is true by construction, not by remembering to be kind. Slip is
capped at one step because the formula subtracts one — no code path subtracts two.

**"Shown once" is G3's.** I publish `tierSlippedWeek`; G3's `notices/tierSlip-{yyyy-Www}` ledger and
`NoticeLedger.markSeen()` decide and record whether it was shown. My first draft's competing
`weeklyGoal.slipAckedWeek` is withdrawn. One mechanism, in the group that owns the screen.

### 3.3 A personal best

| State | Meaning | Where |
|---|---|---|
| **predicted** | detector ran on-device at session end; R10's amber card shows it | local only, marked pending |
| **confirmed** | Function wrote `bests/{exerciseId}` and created `best:{…}` in the ledger | P03 lists it |
| **superseded** | a later session beat it; old values move into `previous` | one doc per exercise, never a history scan |
| **suppressed** | `source != 'live'` | `detect()` returns `none()` on its first line |

**Detection without scanning history.** The maximum is *materialised*: `bests/{exerciseId}` **is** the
running best, so detection is a point lookup, not an aggregation.

1. G4's `SessionFinished` carries `measuredSets`, `loggedSetCount`, `source` and `activity`, so I never
   read the `sets` array. `measuredSets` is empty for `recalled` and `unplanned`, so — in G4's words — a
   best is "not merely discouraged, it is impossible from that payload".
2. A session spans ≤6 distinct `exerciseId`s. Point-get those `bests/{exerciseId}` docs **by
   deterministic ID — no query, no index**.
3. Compare on the metric named by the bundled `exercises/{exerciseId}.metric`: `load` → `actualWeight`,
   then `actualWeight × actualReps`; `reps` → `actualReps` at ≥ the stored load; `hold` →
   `actualHoldSec` (**requested of G4, §7.3 — absent today, so P03's "Plank hold · 45 seconds" cannot
   currently be detected**).
4. Variation ("moved to the harder version"): read `progressionFamily`, `progressionRank`, `siblings[]`
   from the cached exercise doc, point-get the ≤4 sibling bests, and if a best exists at a lower rank and
   none at this rank or above, record `metric: 'variation'`.
5. Write only improvements. Bounded by a session's move count and a family's size — single digits both,
   neither growing with her history or the user base.

Only non-null `actualWeight`/`actualReps`/`actualHoldSec` are compared, so C8 and rule 1 hold: a
prescribed value can never become a best because the detector never reads a `prescribed*` field. The
spine's amendment making `prescribed*` nullable changes nothing, for the same reason.

---

## 4. Offline behaviour

### 4.1 What is writable offline

| Writable offline (client) | Not client-writable at all (Function; lands on sync) |
|---|---|
| `measurements/{date}` — all of P04 | `rewards.*` (points, level, tier, milestones) |
| `weeklyGoal.{sessionsTarget, tz, goalKind}` | all of `weeks/*` |
| | `bests/*`, `awards/*` |

**This corrects G8 §6's offline table**, which lists `weeks` and `bests` as offline-writable. Under the
reconciled design they are not client-written at all, so they cannot be written offline either.

Nothing a woman does is blocked by signal — the evidence lives in G4's `sessions` and G5's `meals`, both
offline-writable, plus her own `measurements`. What waits is the *bookkeeping*, and no screen waits for
it: every number on P01 — this week, the eight bars, the counted-week total, the tier sentence — is
computed by `WeekRollup` from documents already in the local cache. Rule 3's unit is visible offline; the
currency reconciles when there is signal.

| Surface | While queued |
|---|---|
| P01 this-week segments | instant, from local session state unioned with `weeks.sessionsLogged`, **de-duplicated by session ID** — the same projection G3 renders on T01, so Home and Progress cannot disagree |
| P01 points / level | last synced total **plus** `AwardTable.preview()` deltas, with G8's `SyncBadge`; the projection uses the server's own table, so it converges rather than corrects |
| P03 | predicted best inline, badged pending; confirmed on sync |
| P02 | progress bars move; the earned tick waits for the ledger |
| P04 | saves and renders immediately at full opacity — it is her own private document |

I conform to G8 §6's convention verbatim: full opacity, trailing `cloud_queue` glyph, `l10n.syncQueued`,
no glyph during `pendingUndo`, and never a blocking spinner or a failure for something that will sync.
P04's 5-second undo is **G8's `pendingUndo` state**, not a mechanism of mine: the write is not released
for 5 s, so undo is a local cancel needing no compensating delete — routed through G3's `LogCommandBus`
per `RECONCILIATION.md` §2, so rule 9 has one implementation, not three.

### 4.2 Idempotency of awards — the argument

**`FieldValue.increment` is commutative but *not* idempotent.** C4 gets replays right for ordering and
wrong for duplication, so an increment must never travel alone. The spine's own C3 correction — same-slot
writes need `arrayUnion` plus `increment`, with `P0-LOG-11` written to catch the regression — is the same
lesson on G5's surface. Three layers:

1. **Every award is bound to the creation of a deterministically-keyed document.** The transaction
   creates `awards/{awardId}` *and* applies `increment(points)` atomically. If the award doc exists, the
   transaction aborts and **the increment never executes**. A week cannot pay twice because
   `awards/week:2026-W38` can be created exactly once, ever. This matters more than it looks: Cloud
   Functions are **at-least-once**, so retries are normal rather than exceptional, and the ledger is what
   makes a retried trigger free of consequence.
2. **Week credit is a set, not a tally.** `creditedSessionIds` uses `arrayUnion(sessionId)` — idempotent
   *and* commutative, bounded at 20 — and `sessionsLogged` is reconciled to `creditedSessionIds.length`
   on every run. Session IDs are deterministic for `recalled`/`unplanned` and a once-minted UUID for
   `live` (C1, G4 §1, G8 K1), so a replayed `SessionFinished` re-unions the same element and changes
   nothing.
3. **The client cannot double-credit even in principle**, because it cannot write `weeks/*`. The one
   write path is the Function, idempotent by (1) and (2).

Commutativity from the increment, idempotency from the key, convergence from reconciliation. C4 needs all
three. G5's Q16 (a force-quit inside the undo window committing a journalled log on next launch) is
covered by the same key: `meal:{yyyy-MM-dd}` can be created once that day.

**One deliberate exception to G8's `no_rmw_counter` lint (K5).** The daily cap must *compare* against a
ceiling, so `pointsToday`/`pointsDayKey` is a read-then-write — inside a single-document server
transaction, in Function code, never on a client. C4's rationale is the offline reconnect race, which
does not exist here. I require the lint be scoped to `lib/` and not applied to `functions/`.

### 4.3 Conflict resolution

| Field | Policy |
|---|---|
| `creditedSessionIds` | set union — commutative, order-free |
| `sessionsLogged` | increment, reconciled to the array length |
| `closedAt`, `counted` | write-once, Function-only; no client can race them |
| `weeklyGoal.sessionsTarget` | last-write-wins (single-owner scalar, spine §5) |
| `weeks/*.sessionsTarget` | copied in at creation, then **lowered only while open** |
| `measurements/{date}` | per-date doc, field-level merge on distinct keys via `set(merge:true)` (G8 K6) — two devices adding weight and waist the same day both survive |
| `rewards.*` | single writer, no conflict possible |

**Target change mid-week.** T05's "Make this week 2 sessions" routes through
`WeeklyGoalService.setTarget()` (G3 calls it; they must not write `weeklyGoal`). The week doc's
`sessionsTarget` may only **decrease** while open, and freezes once `counted` — raising it mid-week could
un-count a counted week, the one thing this group must never permit. A goal she can meet beats a goal she
abandons.

---

## 5. Rules I own, and where each is enforced

Domain layer only. Widgets read state; they never decide it.

| Rule | Enforcement point | Mechanism |
|---|---|---|
| **3 — weeks, not days. No daily streak, ever.** | `WeekKey.of(instant, tz)` / `WeekKey.current(tz)` | the only time→bucket function in G6; it can produce **nothing but** `yyyy-Www`. There is no day-granularity type for consistency to be expressed in. |
| | `WeekRollup.evaluate({week, restWeeksBanked, now, tz})` | the single place a week's state is decided; five states, none counting days |
| | schema (C6) | no `streak` field exists; a UI cannot render what the schema cannot hold |
| | G8's `noStreak()` rules + `WriteIntentValidator` + K7 lint | banned key set rejected client- and server-side. **I require `missedDays`, `dailyStreak`, `daysStreak` added to their set** — a *count of missed days* is precisely what P0-WEEK-02 forbids, and their current list would allow it |
| | `RestWeekRepair.decide()` | the shortfall is repaired unasked — the documented way to remove the sting (Silverman & Barasch 2023, *JCR* 49(6)) |
| **11 — nothing ranked by weight, weight lost or followers.** | `TierPolicy.evaluate(last8Weeks, bestsCount)` | weight is **not a parameter**; structurally unable to influence a tier |
| | `AwardTable.pointsFor(event)` | no case keyed to weight, weight change or any social count |
| | `MeasurementsRepository` | `latest()` / `historyForOwner()` only; **no query method exists** |
| | G8's `index_allowlist_test.dart` (theirs) + no collection-group allow (mine) | the sort cannot execute because the index does not exist, and no cross-user surface exists to sort |
| | `bests.loadKg` naming | the field G7 may project cannot be confused with body weight |
| **Nothing earned is ever taken away.** | `TierPolicy.earnedTier` + `UnlockPolicy.isUnlocked()` | unlocks read the monotonic `earnedTier`; only the label slips |
| | `AwardLedger` | append-only; no update, no delete, `increment`-only points |
| **A recalled session awards fewer points and never sets a best.** | `AwardTable.pointsFor()` | `source != 'live'` → 15, not 30 (R12 vs R10) |
| | `PersonalBestDetector.detect()` | `if (session.source != 'live') return BestOutcome.none();` — first line, one test asserts it; G4's empty `measuredSets` makes it doubly impossible |
| **Points only for goal-moving behaviour, capped daily.** | `AwardTable` + `DailyCap` | 60/day on repeatable kinds; no award key exists for opening the app, posting, inviting or completing a profile |

**Shared with G8, split explicitly:** for P1-RULE-03 they own the lint and the rules predicate, I own the
schema and the domain; for P1-RULE-11 they own `index_allowlist_test.dart`, I own `TierPolicy`,
`MeasurementsRepository` and the award table. Rule 9 on P04 is G3/G8's mechanism, my conformance.

Measurements emit **no analytics event of any kind** — not even a count. Spine §6 bans weight and
measurement data outright, and G8's allowlist has no key that could carry it.

---

## 6. Security requirements handed to G8 (as code)

`RECONCILIATION.md` §1 rules that `users/{uid}` and its subcollections are authored **once, by G8**,
because Firestore ORs `allow` across blocks — so a permissive sibling block silently defeats every
denial, which is exactly how C5 could be bypassed. I therefore do not author a competing block. What
follows is the **delta I require against G8 §8**, as rules code. Without it, my reward economy is
forgeable, and G3's and G4's published `write: if false` on `weeks`/`bests` do not hold either.

```js
// ─────────── G6's required changes to G8's single ruleset ───────────

// 1. noStreak() — add the three keys that let rule 3 be violated by another
//    name. A "count of missed days" is what P0-WEEK-02 forbids on screen.
function noStreak() {
  return !keys().hasAny(['streak', 'dayStreak', 'consecutiveDays', 'streakCount',
                         'daysStreak', 'dailyStreak', 'missedDays']);   // +3
}

match /users/{uid} {

  // 2. THE INFLATION HOLE. G8's line protects `verification` only, so a client
  //    can write its own `rewards.points`. Rules cannot validate an increment's
  //    justification, so the map must be denied outright — C5's pattern, C5's
  //    reasoning, applied to the currency.
  allow update: if isSelf(uid)
                && !touched().hasAny(['verification', 'rewards'])      // +rewards
                && weeklyGoalOk()                                       // new, below
                && noStreak() && requiredMeta();

  // 3. Of weeklyGoal, exactly three sub-keys are hers; the counters are not.
  function weeklyGoalOk() {
    return !touched().hasAny(['weeklyGoal'])
      || ( request.resource.data.weeklyGoal
             .diff(resource.data.weeklyGoal).affectedKeys()
             .hasOnly(['sessionsTarget', 'tz', 'goalKind'])
           && request.resource.data.weeklyGoal.sessionsTarget is int
           && request.resource.data.weeklyGoal.sessionsTarget >= 2
           && request.resource.data.weeklyGoal.sessionsTarget <= 4 );
  }

  // 4. weeks — Function-written in full. G8 currently grants create+update to
  //    the client, which would defeat the `write: if false` that G3 and G4 both
  //    published for this same path. A client that can write a week can declare
  //    itself counted and mint 40 points.
  match /weeks/{week} {
    allow read:  if isSelf(uid);
    allow write: if false;              // was: create, update if isSelf(uid)
  }

  // 5. bests — Function-only. G8 currently grants create+update to the client.
  //    A fabricated best buys points AND a tier, and G4's own rules comment
  //    requires "NO client write path to bests/* from any block".
  match /bests/{exerciseId} {
    allow read:  if isSelf(uid);
    allow write: if false;              // was: create, update if isSelf(uid)
  }

  // 6. measurements — client-written (correct), but key-whitelisted. This is
  //    rule 11 at the storage layer: no `sharedWith`, `public` or `rank` field
  //    can ever come into existence, so there is nothing to expose by accident.
  //    The K3 metadata fields are inside the whitelist — omitting them would
  //    reject every conformant write.
  match /measurements/{day} {
    allow read: if isSelf(uid);
    allow create, update: if isSelf(uid) && isDay(day) && requiredMeta()
      && keys().hasOnly(['weightKg','waistCm','hipsCm','armCm','thighCm',
                         'takenAt','note',
                         'schemaV','updatedAt','clientWrittenAt','opId']);
    allow delete: if isSelf(uid);
  }

  // 7. awards — the append-only points ledger. Denied by default today, which
  //    is correct; make it explicit so nobody later adds a permissive block.
  //    Read is granted because it is hers; write is denied to everyone, which
  //    is what makes "nothing earned is taken away" a property of the database.
  match /awards/{awardId} {
    allow read:  if isSelf(uid);
    allow write: if false;
  }
}

// 8. C7 / rule 11, stated as a deliberate ABSENCE: there must be NO
//    `match /{path=**}/bests/{id}` and NO `match /{path=**}/measurements/{id}`.
//    Without one, a collectionGroup query is denied by default. A "deny" rule
//    would be worse than useless — rules are a permissive union, so an added
//    deny cannot revoke the owner allow. Only the absence works. Do not add one.
```

**What stops points inflation, in order:** (1) `rewards` is unwritable by any client; (2) awards are
created only by a Function, transactionally bound to a deterministic `awardId`, so they cannot repeat;
(3) `weeks/*` is unwritable by any client, so the *evidence* of a counted week cannot be forged either;
(4) `counted` and `closedAt` are write-once; (5) the daily cap bounds the repeatable kinds; (6) the
ledger is append-only. A rooted device can at most fabricate **sessions** — G4's surface, under G4's
rules — and even then earns 15 points, not 30, unless it also forges `source: 'live'`.

**Tests I require in G8's `rules_test.ts`:** a client write to `rewards` fails; a client write to
`weeks/*` fails; a client write to `bests/*` fails; a client write to `awards/*` fails; a `measurements`
write carrying `sharedWith` fails; a write carrying `missedDays` fails; a collection-group query on
`bests` fails.

---

## 7. Interface to the other groups

### 7.1 I consume

| From | Path / API | What I read |
|---|---|---|
| G4 | **`SessionFinished`** (their §7.2, server-derived: `sessionId`, `source`, `recallMethod`, `activity`, `dateKey`, `loggedSetCount`, `measuredSets`) | the trigger for session awards, week credit, best detection — I never read `sets` and never trust a client |
| G5 | `users/{uid}/meals/{yyyy-MM-dd}` + `firstLogAt` | the once-a-day food award, on their `onCreate` hook |
| G2 | `users/{uid}.profile.days` | initial `weeklyGoal.sessionsTarget`; G2 never writes `weeklyGoal` |
| G2 | `plans/{uid}/versions/{version}` | P02's "day 11 of 18" only |
| G3 | `WeeklyGoalService.setTarget()` calls from T05 | the only mutation path for the weekly goal |
| G8 | `Repository.write`, `SyncStatusScope`/`SyncBadge`, `DocIds`, **`AppClock.isoWeek(tz)`**, `ErrorPresenter`, `AppNumbers`, base rules | K1–K9 conformance; §3.1 requires the zone parameter |
| content | `exercises/{exerciseId}`: `metric`, `progressionFamily`, `progressionRank`, `siblings[]` | bundled (G8 §3), zero Firestore reads |

### 7.2 I publish

| To | Path / API | Contract |
|---|---|---|
| G3 | `weeklyGoal.{countedWeeks, restWeeksBanked, currentRun, bestRun, recent8}` | T01 week card, T04, T08 |
| G3 | **`weeklyGoal.lastRepairedWeek`, `weeklyGoal.tierSlippedWeek`** | **granted, their Q3** — saves a 5th Monday read |
| G3 | `rewards.{points, level, tier, earnedTier, milestones}` | T01 pill, T05 kept-list, T07, T08 |
| G3 | `users/{uid}/weeks/{yyyy-Www}` (read-only) | T01, T04 |
| G4 | `bests/{exerciseId}.{loadKg, reps, dateKey, previous}` + `rewards.{points, level, pointsToNextLevel}` | **granted, their §7.2 request** — R10/R12 render without arithmetic. Note the `loadKg` rename |
| G2 | **`ProgressionAdvisor.nextLoad(exerciseId)`** | **resolves their Q2 with no new field.** G2 needs next week's load but must not read `bests/*`; an in-process domain API reads my own bests and returns a load. No cross-group read, ownership table intact |
| G7 | `MeasurementsRepository.purgeLocal()` + paths `users/{uid}/{weeks,bests,measurements,awards}` | A02 deletion; **already adopted as their rows 32–34** |
| G8 | the §6 rules delta, the `AppClock.isoWeek(tz)` signature, the `no_rmw_counter` scoping, the corrected offline table, and the close agreement (§10) | requirements, not rules |
| G3 / G4 | `WeekRollup`, `TierPolicy`, `AwardTable`, `UnlockPolicy`, `PersonalBestDetector` as **pure domain classes** | so T01/T04/T05/R10/R12 render my arithmetic rather than reimplement it |

### 7.3 Field requests to other groups

1. **G4** — `sets[].actualHoldSec?: int`, surfaced in `measuredSets`. Absent today, so P03's "Plank hold ·
   45 seconds" **cannot be detected**. The one request that blocks shipped behaviour.
2. **G4** — confirm a harder variation is a **distinct `exerciseId`**, not a set flag.
3. **Content pipeline** — `exercises/{exerciseId}.{metric, progressionFamily, progressionRank, siblings[]}`.
4. **G2 / G5** — a protein target. G5's Q1 confirms it **unowned**; until it exists the protein award is
   not built.
5. ~~G7 — add `awards/**` to A02's delete order~~ — **resolved**: G7 added rows 32 (`awards`), 33 (the
   on-device photo store via `purgeLocal()`) and 34 (its Keystore key).

### 7.4 Changed after reading G2–G5 and G7

| Conflict | Resolution |
|---|---|
| I let the client write `weeks/*`; **G3 and G4 both published `write: if false`** | **Yielded.** Function-written in full; adopts G3's dedupe-by-session-ID optimistic render, which already solved the offline display problem my client write existed for |
| I invented `weeklyGoal.slipAckedWeek`; G3 owns `notices/{kind}-{week}` | **Withdrawn.** I publish `tierSlippedWeek`; G3 records "shown once" |
| Spine adds `source: 'unplanned'`; G4 initially had `live\|recalled` | **Resolved** — G4's revision adopts the amended enum with `activity` and `sets: []`; my table keys on `source == 'live'`, correct either way |
| I awarded 10 for a food day; **G5 published +5** | **Adopted G5's figure** |
| I specified a protein award; **G5 confirms the target unowned** | **Deferred, not specified** |
| G2 must not read `bests/*` but needs progression | **Offered `ProgressionAdvisor.nextLoad()`** rather than a new field |
| G4 asked for `bests.weight`; G7 publishes bests and warns "never scale weight" | **Granted as `loadKg`** |

### 7.5 Changed after reading G8 and `RECONCILIATION.md`

**Status: G8's revision adopted every requirement below.** The three security holes are closed in their
single ruleset. §6 is retained as the record of what was required and why, because it is the argument a
future reviewer needs before touching those four lines.

| Finding | Resolution | G8's revision |
|---|---|---|
| Per-group rules cannot work (rules OR); `users/{uid}` authored once by G8 | §6 rewritten as a **requirements delta**, not a competing ruleset | now in the spine §2 too |
| G8 protected only `verification`, leaving `rewards` client-writable | §6 item 2 | **adopted** — `!changed().hasAny(['rewards'])`, annotated "a client-writable currency is one-line inflation". They also caught that G1's fragment allowed `hasOnly([… 'rewards'])`, which would have OR-ed the hole back open |
| G8 granted clients `create, update` on `weeks/*` | §6 item 4 | **adopted** — `allow write: if false` |
| G8 granted clients `create, update` on `bests/*` | §6 item 5 | **adopted** — `allow write: if false` |
| `awards/*` undeclared | §6 item 7 | **adopted** — read-own, `write: if false`, append-only |
| G8's `noStreak()` omitted a missed-day counter | §6 item 1 | **adopted** — K9 is now the union of all seven ban lists, including `missedDays` and `dailyStreak` |
| G8's `requiredMeta()` vs my `measurements` key whitelist | **My bug** — `schemaV`/`updatedAt`/`clientWrittenAt`/`opId` added (§1.2, §6 item 6) | whitelist accepted |
| G8 §4: "no per-write trigger; rewards are client-side increments" | **Declined, with arithmetic** (§2.3): ~1.8M invocations/month, inside gen2's free tier and their own §4 line — and client-written points cannot be secured at any price | rules now match mine; one stale sentence remains in their §4 prose (§9.17) |
| G8 K5 `no_rmw_counter` would block the daily cap | Scope the lint to `lib/`, not `functions/` (§4.2) | **generalised** — their K5 now reads "an increment **never travels alone**: paired with a deterministic doc creation or a bounded `arrayUnion` guard", which is my §4.2 argument promoted to a project-wide convention |
| G8 K8 hardcoded Africa/Cairo; §12-13 proposed a single-zone tz db | Require a zone parameter and the full IANA db (§3.1) | **adopted** — `WeekClock.isoWeek()` keys off **`weeklyGoal.tz`, "a property of the woman"**, and they surface my "move your week to this timezone?" action |
| G8 §6 listed `weeks`/`bests` as offline-writable | Corrected in §4.1 | **adopted** — their offline table now lists `awards`, `bests`, `rewards`, `counted`/`closedAt` as Function-only |
| G8 §12-12 asked G6 to agree the close strategy | **Agreed on lazy; declined the sweep** (§10) | **adopted** — "week closing is G6's, already solved lazily" |
| Spine C7 amended: auto-indexing makes absence-of-composite insufficient | **My gap.** Single-field exemptions on `measurements` and `bests` now required (§1.4) | new requirement to G8 |

---

## 8. Test IDs I am accountable for

**Owned outright**

| ID | What I must make true |
|---|---|
| `P0-WEEK-01` | the third session flips the week to counted; the week award fires **once**; no day counter anywhere |
| `P0-WEEK-02` | a banked rest week repairs the missed week automatically at close; `countedWeeks` does not fall; no red, no zero, no count of what was missed |
| `P0-WEEK-03` | slip shown once per week (`tierSlippedWeek` + G3's notice ledger); `earnedTier` and every unlock kept |
| `P1-RULE-03` | no consecutive-day counter in schema, domain, rules or UI — **P01 is mine**; G3 is primary for T01/T04/T05/T07, G8 owns the lint and rules predicate |
| `P1-RULE-11` | nothing in G6 sorts by weight, weight lost or followers — G8 owns the index test, I own the domain and the absent query path |

**Shared — my half named**

| ID | My half |
|---|---|
| `P0-LOG-04` | R12 awards 15 not 30 and sets no best, while the week still gets credit |
| **`P0-LOG-12`** | **new, and it lists P01.** An unplanned walk or class scores as unplanned: `source != 'live'` → 15 points, no personal best, full week credit. My `AwardTable` and `PersonalBestDetector` already key on `!= 'live'`, which is precisely the bug the spine amendment names — adding `unplanned` to the enum would have silently made a logged walk earn full points had the test been written as `== 'recalled'` |
| `P0-LOG-09` | offline session/meal replay produces no duplicate week credit and no double award (§4.2) |
| `P0-FR-02` | three idle days change no G6 number; nothing expires; no rest week is spent on an unmet *first* week |
| `P0-DEL-01` | `weeks`, `bests`, `measurements`, `awards` and the on-device photo store all gone (G7 rows 2, 6, 7, 32–34) |
| `P0-NAV-01` | P01 one tap from a tab root, P02–P04 two |
| `P0-A11Y-01` | P01–P04 mirror in Arabic; Western numerals for every points, kg and week figure |

**P2 for my screens** (`P2-RTL/TXT-P01…P04`, `P2-OFF-P04`, `P2-ERR-P04`): G8 executes these as goldens
and widget tests; I supply the states and the expected numbers.

`P0-LOG-11` is G5's, but its lesson is mine: the same increment-is-not-idempotent failure my ledger
exists to prevent.

---

## 9. Open questions

1. **Level curve.** `level = floor(points/80) + 1` fits both mockup anchors — R10's "490 total, 70 to
   level 8" and T08's "90 points, level 2" — but R10 draws its bar at 50% where the formula gives 12.5%.
   I treat the formula as authoritative; G4 confirms, since they render `pointsToNextLevel` from it.
2. **Tier thresholds.** §3.2's table is inferred from P01 and T05. T05's copy — "Regular asks for four of
   your last eight weeks, **and three counted**" — contradicts P01's "holds while four of your last eight
   weeks count". I implemented P01's reading; T05's copy needs an edit.
3. **Does a repaired week award its 40 points?** I say **no** — no goal-moving behaviour occurred, and
   T04's copy is "nothing changed", not "you earned". The count and the run are preserved; the points are
   not.
4. **Does a repaired week earn toward the next rest week?** I say **no**, so repair cannot fund itself.
5. **Repair order** with several weeks missed and two banked: most-recent-first. Confirm.
6. **Protein award blocked.** G5's Q1 confirms the target is unowned. F40 promises points for "hitting
   protein", so either a target gets an owner or the feature copy drops the claim.
7. **Food-day award: 5 or 10?** I adopted G5's published +5. If 10 was intended, both plans change.
8. **The food-day *goal*.** F38 offers "food logged on four days" but the spine's week doc counts
   sessions. I added `goalKind` and `foodDaysLogged`. Can both units count in one week, or does she pick
   one, and which does T01's segment bar show?
9. **`rewards` writer.** The ownership table says "G6 (rewards, weeklyGoal)" without distinguishing
   client from Function. I read it as **Function-only**, and G8's ruleset currently disagrees (§6 item 2).
   This needs an explicit ruling: it is the difference between a reward economy and a suggestion.
10. **`rewards.tier` is one field where I need two.** `tier` = `displayTier` for spine compatibility, plus
    `earnedTier`. "Nothing earned is taken away" is unimplementable with one field.
11. **P04 photos.** The screen promises "stored on your phone and encrypted in the app", so they are
    local-only: no Storage object, no Firestore reference, key in Keychain/Keystore. Consequences: they
    **do not survive a lost phone or a reinstall**, and — as G7's Q17 independently found — A02's
    "download everything" **cannot include them**. Either the copy gains a line or the promise changes.
12. **Timezone.** Per-user `weeklyGoal.tz` requires `AppClock.isoWeek(tz)` and the full IANA database
    against G8's §12-13 single-zone proposal. Owner call on ~500 KB of binary vs a wrong week boundary
    for the Gulf diaspora.
13. **Long absence.** A close reconciles at most the **8** most recent unclosed weeks; an older gap is
    skipped entirely — no doc created, not counted, not repaired — so a two-year absence cannot fan out
    104 writes. The return is rewarded by the "Came back" milestone. Confirm gaps beat rows of `missed`.
14. **Twelve milestones.** P02 names eight; I inferred four (first meal logged, 10 personal bests, first
    rest week banked, 100 sessions). Sign-off needed on the list and on 25 points each.
15. **Test coverage gaps.** No P0/P1 case covers award idempotency on an offline replay, the 60-point
    daily cap, or a repaired week awarding no points. `P1-RULE-09` lists `R07,R09,E04,T02` but not P04,
    whose add-weight is a log. I recommend four additions; I did not modify the CSV.
16. **Analytics blindness (G8 §12-5).** Spine §6 leaves G6 with no event-level data on weeks or rewards
    beyond `week_counted{outcome}`. I accept it for measurements unconditionally — those must never emit
    an event — but whether the *reward economy* can be tuned with no funnel data is an owner question.
17. **Two small residues in G8's revision, neither blocking.** (a) Their §4 prose still reads "awards and
    week credit are client `increment`s" while their own ruleset now denies exactly that; the rules are
    authoritative, the sentence is stale. (b) They describe my close as "client `closeRequestedAt` + a
    Function decision", which was my *first* draft — now that `weeks/*` is `write: if false`, a client
    cannot write `closeRequestedAt` at all, so the **`closeStaleWeeks()` callable is the only viable
    mechanism** (§10). Their `g6Slice()` also grants four `weeklyGoal` sub-keys where I specified three
    (`sessionsTarget`, `tz`, `goalKind`); the fourth needs naming, since anything beyond those three is
    a counter and belongs to the Function.

---

## 10. Scalability gate — self-assessment

| Gate | Result | Evidence |
|---|---|---|
| Unbounded collection scan | **PASS** | Every read is a point get or a bounded, date-key-ordered range. Largest: P03 `limit(50)`, hard-bounded by the 124-move library; P04 `limit(24)`. No `collectionGroup`, no cross-user query, no aggregation over history — the rollup reads ≤8 docs and a best is a point lookup because the maximum is materialised. |
| Per-user fan-out growing with followers | **PASS** | No follower concept exists, and rule 11 forbids one. Every write targets one woman's own documents. Worst case per event: 1 user doc + 1 week doc + 1 award + ≤6 bests = **≤9 writes, independent of population**. A close is ≤8 doc creations however long she was away. |
| Unindexed query on a hot path | **PASS** | **Zero composite indexes.** P01 is two point gets. Only automatic single-field indexes, both on cold screens. My rules delta calls no `get()`, so security adds no reads at peak. |
| Migration to reach 100k MAU | **PASS** | Every structure is fixed-size (`recent8`=8, `milestones`=12, `creditedSessionIds`≤20) or a monotonic scalar; additive-only per G8 K9. The one growing collection is the award ledger — ~150 docs/user/year, never queried in aggregate, bounded permanently by a 400-day TTL. |

### Is week closing a per-user scheduled Function? — and the agreement G8 asked for

**No, and G8 and I agree on the half that matters.** Their §11 proposes "a week closes **lazily on first
read after its end**, plus a sweep bucketed by `hash(uid) % 60` spread across the hour", and their §12-12
asks for my agreement. My answer:

**Agreed: the lazy close.** It is the same design I specified. `closeStaleWeeks()` is a callable the
client invokes on app open when `weeklyGoal.lastClosedWeek < WeekKey.current(tz)`, and the session and
meal triggers run it inline when they see a stale watermark. `WeekRollup` + `RestWeekRepair` +
`TierPolicy` + the awards run in **one transaction**. Cost: one callable per user per week ≈ 0.14 per
active day.

**Declined: the bucketed sweep.** Bucketing solves the burst but not the scan. A sweep must still
*discover* whom to sweep, which is a query over `users` — 100k documents a week, growing linearly with
registrations, divided into 60 slices rather than removed. That is the gate's first failure condition
wearing a hat. And the work is dead: nothing reads a closed week until she opens the app, and when she
does, the lazy close handles up to 8 weeks at once. The sweep's only real customer would be a Monday
push — which §7.2 already requires to be **content-free**, precisely so that no scheduled job needs to
know her week state. If the owner later wants a data-carrying Monday push, the sweep becomes justifiable,
but it must then be a batched FCM topic send, not a per-user Firestore sweep, and it should be costed as
an acquisition feature rather than a correctness one.

**What 100,000 scheduled closes at once on a Monday would cost, since the question is fair:** in money,
almost nothing — 100k × (2 reads + 3 writes) = 200k reads + 300k writes ≈ $0.06 + $0.27 ≈ **$0.33 per
Monday** at G8's regional rates, plus ~$0.04 of invocations. Money is not the objection. The objections
are architectural and all three are disqualifying:

1. **It needs an unbounded scan to find its victims** — 100k user documents every Monday, growing with
   registrations.
2. **Timezones fan it out.** "Monday 00:00" is not one instant. Honouring `weeklyGoal.tz` means 24 hourly
   waves with a query each, or one wrong boundary for everyone outside Cairo — and §3.1 shows that is a
   whole market, not an edge case.
3. **Most of the work is dead.** At 35% DAU, two thirds of those writes are for women who will not open
   the app that day, so the burst buys nothing and still concentrates ~1,700 writes/s into one minute.

The lazy close inverts all three: no scan (the client knows its own key), no fan-out (the key is computed
in her own zone, on her device), no dead writes (only women who show up are processed), no burst (35k
callables spread over a Monday morning ≈ 2.4/s). It is also the only version that works offline, which
T04 requires: she may read "your 14 weeks are safe" on a microbus with no signal, computed locally by the
same `WeekRollup` the server will later confirm.
