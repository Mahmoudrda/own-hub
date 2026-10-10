# G3 — Today & logging

Stage 2 plan. Screens: **T01** Today, **T02** I already did it, **T03** From the lock screen,
**T04** After a quiet week, **T05** When a tier slips, **T06** Day one, **T07** Your first week,
**T08** First week done.

Written against `SCHEMA-SPINE.md` (paths verbatim, nothing renamed), `BUILD-BRIEF.md` §2/§3/§4/§6,
`flutter/HANDOFF.md` rules 1–17, `tests/TEST-CASES.csv`.

Feature folder: `lib/features/today/{presentation,domain,data}`.

---

## 1. Data model

### 1.1 Collections I own (spine, unchanged)

| Path | Owner | ID rule | Fields | Notes |
|---|---|---|---|---|
| `users/{uid}/checkins/{yyyy-MM-dd}` | **G3** | date (C1) | `energy?, cramps?, appetite?, sleep?, bloating?, bleeding?` — all nullable | Merge-write per field. Read by G3, G4. |

### 1.2 Collections I add, inside my own group (permitted extension)

| Path | ID rule | Fields | Why it exists |
|---|---|---|---|
| `users/{uid}/notices/{kind}-{yyyy-Www}` | deterministic: kind + ISO week (C1) | `kind: 'quietWeek'\|'tierSlip'`, `forWeek: string`, `seenAt: timestamp` | "Shown once, never again that week" (P0-WEEK-03) becomes **structural**: the key already encodes the week, so a replayed offline write cannot re-show a notice. No read-modify-write, no flag on someone else's doc. |
| `users/{uid}/firstWeek/arc` | fixed single doc id `arc` | `hasAnyLog: bool`, `steps: {logSet, logMeal, finishSession, joinGroup, followUp}` (bool each), `completedAt?: timestamp` | Backs T06 branch detection, T07 and T08 **without a query**. Booleans only — see §5 for why there is no count of days here. |

Both are `users/{uid}/**`, so they inherit the spine §5 offline contract automatically.

### 1.3 Collections I read but never write

| Path | Owner | What I take from it |
|---|---|---|
| `users/{uid}` root | G1/G2/G6 | `profile.*` (days, sessionLength, language), `rewards.{points,level,tier}` (T01 pill, T05, T07, T08), `weeklyGoal.{sessionsTarget,countedWeeks,restWeeksBanked,currentRun}` |
| `users/{uid}/weeks/{yyyy-Www}` | G6 | `sessionsTarget, sessionsLogged, counted, repairedByRestWeek` |
| `plans/{uid}/assignments/{yyyy-MM-dd}` | G2 | today's workout + meal assignment, `planVersion` |
| `users/{uid}/sessions/{sessionId}` | G4 | existence/`completedAt` of today's session — via the assignment + arc, never a scan |
| `users/{uid}/meals/{yyyy-MM-dd}` | G5 | `slots`, `totals` for the T01 meal card and the T03 payload |

### 1.4 Indexes

**Composite indexes required: none.** Every G3 read is a direct `doc().get()`/`snapshots()` on a
deterministic ID. There is no `where`, no `orderBy` and no range scan anywhere in this group — which
is also why C7 (no index on weight/followers) is impossible to breach from here.

### 1.5 Read/write pattern per screen

| Screen | Reads | Writes |
|---|---|---|
| T01 | 4 doc listeners (+1 conditional, §2) | 0 on open |
| T02 | 0 new (reuses T01's listeners) | 1 (G4 session, via G4 command) |
| T03 | 0 in-app (payload travels in the push) | 1 (G5 meal, via G5 command) |
| T04 | T01's 4, +1 notice doc on the Monday only | 1 notice `seenAt` |
| T05 | T01's 4, +1 notice doc on the Monday only | 1 notice `seenAt` (+1 G6 command if she shrinks the goal) |
| T06 | T01's 4 + arc | 1 arc create (once per account) |
| T07 | user doc (cached) + arc | 1 arc step merge |
| T08 | T07's, no new | 1 arc `completedAt` |

---

## 2. The query for every screen, with index and cost

§3 numbers: 35,000 DAU, ~8 reads / ~6 writes per active day, 40% of traffic 19:00–23:00 Cairo.

| # | Screen | Query | Index | Reads | Cost at 35k DAU |
|---|---|---|---|---|---|
| 1 | T01 | `users/{uid}` | primary key | 1 | 35k/day |
| 2 | T01 | `plans/{uid}/assignments/{today}` | primary key | 1 | 35k/day |
| 3 | T01 | `users/{uid}/checkins/{today}` | primary key | 1 | 35k/day |
| 4 | T01 | `users/{uid}/weeks/{thisWeek}` | primary key | 1 | 35k/day |
| 5 | T01 | `users/{uid}/meals/{today}` | primary key | 1 | 35k/day — **net zero, see below** |
| 6 | T01/T06 | `users/{uid}/firstWeek/arc` | primary key | 1 | only while arc incomplete |
| 7 | T02 | none — renders from #1/#2 already live | — | 0 | 0 |
| 8 | T03 | none — payload is in the FCM/APNs message | — | 0 | 0 |
| 9 | T04 | `users/{uid}/notices/quietWeek-{week}` | primary key | 1 | Mondays, conditional |
| 10 | T05 | `users/{uid}/notices/tierSlip-{week}` | primary key | 1 | Mondays, conditional |
| 11 | T07/T08 | #1 (cached) + #6 | primary key | 0–1 | first week only |

**Holding the 4-read line on T01.** Reads #1–#4 are exactly the spine §4 budget. Two deviations, both
justified rather than smuggled:

- **#5 `meals/{today}` is an addition the spine's T01 line omits.** T01 draws a meal card with two
  plates and a logged-at time (`screens-today.mjs:14–17`), and that data lives only in G5's day
  document. **It is net zero against the day**: the same listener serves E01, whose spine budget is 2
  (meal doc + suggestion source). T01 pays 1 and E01 then pays 0 from the warm listener, so the day
  is still 4 + 2 = 6 for these two screens. It is a reallocation of the per-screen line item, not new
  traffic. Flagged in §9 for the spine owner to bless.
- **#6 the arc doc is read only while `completedAt == null` and the account is under 14 days old.**
  T01 is 5 reads in a new woman's first days and 4 for the rest of her life. The overage is bounded,
  self-extinguishing and lands on the cohort furthest from the 8-read ceiling.
- The "usual plates" suggestion list is **long-TTL cached** with a Remote Config version stamp, the
  same treatment the spine §4 gives the libraries. It is never read per open.

**Day total for G3: ~4–6 reads, ~1–2 writes.** Steady state is 4 reads (T01) + the day's check-in
write. Within the 8/6 envelope, and T01's share leaves room for R03→R10 and E01.

**Volume and peak.**

| Metric | Value | Working |
|---|---|---|
| G3 reads/day | ~175,000 | 35,000 × 5 (steady 4 + meal doc) |
| G3 writes/day | ~45,000 | check-in ~1.0 + recall ~0.2 + notice ~0.02 + arc ~0.1 |
| Peak reads | ~12–16 /sec | 40% of 175k in 4h = 70k/4h ≈ 4.9/s mean, ×3 burst headroom |
| Peak writes | ~4–5 /sec | 40% of 45k in 4h ≈ 1.25/s mean, ×3 burst |
| Hot-document risk | **none** | every write is under `users/{uid}`; no shared counter, so Firestore's per-document 1-write/sec sustained guidance is never approached |
| Indicative spend | **~$5/month** | 175k reads/day ≈ 5.3M/mo at $0.06/100k ≈ $3.2; 45k writes/day ≈ 1.4M/mo at $0.18/100k ≈ $2.4. List prices to be re-verified against the chosen region at build time. |

G3 is a rounding error next to the ~11 TB/month of video egress §3 names as the real cost. Nothing in
this group touches video.

---

## 3. State machines

Two **orthogonal** machines. The day's state drives the body of T01; the notice machine drives the
T04/T05 sheet. Keeping them separate is deliberate — a quiet-week notice must not be a sixth value of
the day state, or every T01 render would have to re-answer a Monday question.

### 3.1 `DayState` — `DayStateResolver.resolve()`

States: `dayOne` · `nothingDone` · `inProgress` · `done` · `recalled` · `restDay`.

| From | Event | To | Notes |
|---|---|---|---|
| `dayOne` | first log of any kind | `inProgress` | also ticks the arc; T06 stops rendering permanently |
| `nothingDone` | G4 session started | `inProgress` | |
| `nothingDone` | T02 recall saved | `recalled` | |
| `nothingDone` | local clock passes 20:00 Cairo | `nothingDone` | **presentation-only flip**: CTA becomes "Did it — log Legs and glutes". Not a state; a rendering of the same state, so it cannot desync. |
| `inProgress` | session `completedAt` set | `done` | |
| `inProgress` | date rollover | `nothingDone` | abandoned sessions never carry over |
| `recalled` / `done` | undo inside 5 s | previous state | §5, rule 9 |
| any | `assignment.kind == 'rest'` | `restDay` | logging stays enabled — T04's shortest session "counts toward your week like any session" |
| any | local midnight Cairo | recompute | single timezone authority, `Africa/Cairo` |

`dayOne` is a **branch, not a route** (HANDOFF rule 16): `TodayRoute` builds T06's tree when
`arc.hasAnyLog == false`, inside `/today/t01`. No navigation targets T06 — `app_routes.dart:37`
exists as a generated inventory entry and is never pushed.

### 3.2 `NoticeState` — `NoticeLedger`

States: `notApplicable` → `pending` → `shown` → `acknowledged`.

| From | Event | To |
|---|---|---|
| `notApplicable` | G6 sets `weeklyGoal.lastRepairedWeek` / tier drop (§7) | `pending` |
| `pending` | T04/T05 sheet rendered | `shown` |
| `shown` | sheet dismissed → write `notices/{kind}-{week}` | `acknowledged` |
| `acknowledged` | any re-open in the same ISO week | `acknowledged` (silent) |

Because the document key contains the week, `acknowledged` is idempotent under offline replay — the
mechanism P0-WEEK-03's "never shown again that week" actually needs.

### 3.3 `QueuedLog` — `UndoableLog`

States: `pendingUndo` (≤5 s) → `queuedLocal` → `synced`, with `pendingUndo` → `reverted`.

| From | Event | To | UI |
|---|---|---|---|
| — | log tapped | `pendingUndo` | row updated **immediately**, snackbar with Undo, same numbers the button named |
| `pendingUndo` | 5 s elapse | `queuedLocal` | snackbar gone |
| `pendingUndo` | Undo tapped | `reverted` | compensating write; state returns to pre-save; **no dialog at any point** |
| `queuedLocal` | reconnect | `synced` | "Saved on this phone" chip clears |
| `queuedLocal` | app killed | `queuedLocal` | survives — the write already went to the local cache |

---

## 4. Offline behaviour

**Logging never requires signal.** Every G3 write goes to Firestore's local cache first and is
readable from it immediately; the network is a synchronisation detail, not a precondition.

| Action | Offline? | ID | Conflict resolution |
|---|---|---|---|
| Daily check-in field (T01) | ✅ | `checkins/{date}` (C1) | field-level merge on distinct keys; two devices logging different symptoms both survive |
| T02 recall (G4 session) | ✅ | deterministic `recalled-{date}-{assignmentId\|kind}` (§7 request) | idempotent — a replayed retry overwrites itself instead of creating a second session |
| T03 meal from lock screen | ✅ (Android) / deferred (iOS, §4.2) | `meals/{date}`, merge into `slots.<slot>` | C3 commutative slot merge |
| Notice `seenAt` | ✅ | `notices/{kind}-{week}` | last-write-wins on a single-owner scalar |
| Arc step | ✅ | `firstWeek/arc` | booleans only, monotonic false→true; two devices cannot disagree destructively |
| Week credit | ❌ client | — | G6/Cloud Function owns the increment; T01 shows it **optimistically** from local session state and reconciles when the server increment lands |

**Why optimistic week credit is safe.** A recalled session written offline fires no Cloud Function
until it syncs, so the authoritative `weeks/*` increment is late by design. T01 renders
`local sessions ∪ weeks.sessionsLogged`, de-duplicated by session ID — so the count never
double-counts and never shows a regression when the server catches up. Undo before sync means the
function never fires at all; undo after sync fires the symmetric `onDelete` decrement (C4 increments,
never read-modify-write).

**What the UI shows while queued:** a "Saved on this phone" chip on the affected row. Never a
blocking spinner, never an error for something that will sync (spine §5, P2-OFF-T01, P2-OFF-T02).
A genuine server rejection (P2-ERR-T01/T02) surfaces a human sentence naming the problem and the
recovery — never raw exception text, and never a corrupted local state.

### 4.2 T03 — the lock-screen action, both platforms (§4 of the brief)

| | Android | iOS |
|---|---|---|
| Surface | FCM data message → `NotificationCompat.Action` button "Log it" | APNs with `UNNotificationCategory` action + **Notification Content Extension** for the T03 card UI |
| Handler process | app's own process (BroadcastReceiver → WorkManager) | action handled **in-app** by `UNUserNotificationCenterDelegate.didReceive`, which iOS launches into the background |
| Can write Firestore directly | ✅ same process, shares the offline cache | ⚠️ only from the app process — **the Content Extension is a separate sandbox and must never write Firestore**, or it forks the local cache |
| Extension's job | n/a | render the card only; forward the tap via a shared **App Group** intent record |
| Deferred path | WorkManager retry | `NudgeIntentInbox` drains the App Group record on next app launch |
| Immediate path when online | direct write | extension calls an **idempotent Cloud Function** keyed `{uid, date, slot}` so the meal lands even if she never opens the app |

**Designed fallback, tested per §4's "QA tests the fallback".** If the background write cannot happen
at all — action unhandled, extension unavailable, permissions withheld, or the OS kills the handler —
the notification deep-links to T01 with the plate **pre-armed**, so the journey degrades to one in-app
tap and never to a lost log. Double-application is harmless: `meals/{date}` + slot merge is idempotent
(C1/C3), so the Cloud Function path and the drained inbox path converge on the same document.

---

## 5. §2 rules I own, and exactly where each is enforced

Domain layer, not widgets. Every one has a test in §8.

| Rule | Class · method | Enforcement |
|---|---|---|
| **§2.3 — Weeks, not days. No daily streak counter, ever.** | `DayStateResolver.resolve()` · `lib/features/today/domain/day_state_resolver.dart` | **Enforced by absence of capability.** `resolve()` accepts `WeekRollup` and today's documents only — there is no parameter carrying a list of dates, so a consecutive-day count is not computable at the one place T01's body is decided. `FirstWeekArc` stores five booleans, never a day count. |
| | `NoStreakGuard` · `test/rules/no_streak_test.dart` | static assertion over `lib/` and `firestore.rules` for `streak`/`consecutiveDays`/`dayStreak`; fails the build on reintroduction (C6, P1-RULE-03) |
| | `firestore.rules` · `noStreak()` | server-side denial of any document carrying a streak-shaped key — a field the schema cannot hold is a UI that cannot render it |
| **§2.9 — Undo, not confirmation. Five seconds, no dialogs for logging.** | `UndoableLog<T>.execute()` / `.undo()` · `lib/features/today/domain/undoable_log.dart` | single entry point for every G3 log; writes **immediately** (so offline and app-kill both keep the log) and exposes a 5 s compensating `undo()`. `UndoWindow = Duration(seconds: 5)` is one constant. |
| | `LogCommandBus.submit()` · `lib/features/today/domain/log_command_bus.dart` | the API has **no confirmation hook to call** — no `confirm` callback, no `Future<bool>` gate. A widget cannot add an "are you sure" without changing the domain signature, which the test catches. |
| | `NoConfirmDialogGuard` · `test/rules/no_confirm_dialog_test.dart` | asserts no `showDialog`/`AlertDialog` on any path reachable from `LogCommandBus` (P1-RULE-09) |
| **T04/T05 corollary — nothing earned is taken away, and a slip is shown once.** | `QuietWeekNotice`, `TierSlipNotice`, `NoticeLedger.markSeen()` · `lib/features/today/domain/notices/` | T04 asserts the repaired-week copy and renders **no** count of what was missed; T05 emits the kept-items list from `rewards` and writes the week-keyed notice key (P0-WEEK-02, P0-WEEK-03) |
| **HANDOFF 16 — first-run screens are states, not routes.** | `TodayRoute.build()` · `lib/features/today/presentation/today_route.dart` | T06 is a branch on `arc.hasAnyLog`; `app_routes.dart` T06 is never pushed. A navigation-graph test asserts no inbound edge. |
| **HANDOFF 17 — the arc has no timer, no streak, no failure state.** | `FirstWeekArc.steps()` · `lib/features/today/domain/first_week_arc.dart` | returns `done`/`now`/`waiting` only. There is **no** `expired` or `failed` value to construct, and no deadline field on the document (P0-FR-02) |

Rules I explicitly do **not** own but whose data I consume: §2.1 (C8, prescribed ≠ actual) is G4's;
§2.4/§2.5 (symptom-driven suggestions) are the cycle group's, reading my `checkins`; §2.11 is G6's.

---

## 6. Security rules (code)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isOwner(uid) {
      return request.auth != null && request.auth.uid == uid;
    }

    // C6 — a streak is not merely unrendered, it is unstorable.
    function noStreak(d) {
      return !d.keys().hasAny([
        'streak', 'streakDays', 'currentStreak', 'dayStreak',
        'consecutiveDays', 'daysInARow'
      ]);
    }

    function isDateId(id) { return id.matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}$'); }
    function isWeekId(id) { return id.matches('^[0-9]{4}-W[0-9]{2}$'); }

    // ---------- G3: daily check-in ----------
    function checkinFieldsOk(d) {
      return d.keys().hasOnly(['energy','cramps','appetite','sleep','bloating','bleeding'])
        && (!d.keys().hasAny(['energy'])   || d.energy   in ['low','ok','high'])
        && (!d.keys().hasAny(['appetite']) || d.appetite in ['low','ok','high'])
        && (!d.keys().hasAny(['sleep'])    || d.sleep    in ['poor','ok','good'])
        && (!d.keys().hasAny(['cramps'])   || d.cramps   in ['none','mild','moderate','severe'])
        && (!d.keys().hasAny(['bloating']) || d.bloating in ['none','mild','moderate','severe'])
        && (!d.keys().hasAny(['bleeding']) || d.bleeding in ['none','spotting','light','medium','heavy']);
    }

    match /users/{uid}/checkins/{day} {
      allow read: if isOwner(uid);
      allow create, update: if isOwner(uid)
        && isDateId(day)
        && noStreak(request.resource.data)
        && checkinFieldsOk(request.resource.data);
      allow delete: if isOwner(uid);   // the 5-second undo (rule 9)
    }

    // ---------- G3: shown-once notices ----------
    match /users/{uid}/notices/{noticeId} {
      allow read: if isOwner(uid);
      allow create, update: if isOwner(uid)
        && noStreak(request.resource.data)
        && request.resource.data.keys().hasOnly(['kind','forWeek','seenAt'])
        && request.resource.data.kind in ['quietWeek','tierSlip']
        && isWeekId(request.resource.data.forWeek)
        && noticeId == request.resource.data.kind + '-' + request.resource.data.forWeek
        && request.resource.data.seenAt == request.time;
      allow delete: if false;   // acknowledgement is not retractable
    }

    // ---------- G3: first-week arc ----------
    match /users/{uid}/firstWeek/{docId} {
      allow read: if isOwner(uid);
      allow create, update: if isOwner(uid)
        && docId == 'arc'
        && noStreak(request.resource.data)
        && request.resource.data.keys().hasOnly(['hasAnyLog','steps','completedAt'])
        && request.resource.data.hasAnyLog is bool
        && request.resource.data.steps.keys().hasOnly([
             'logSet','logMeal','finishSession','joinGroup','followUp'
           ])
        // HANDOFF 17 — no deadline, no expiry, so no failure state can be stored.
        && !request.resource.data.keys().hasAny(['expiresAt','deadline','failedAt']);
      allow delete: if false;
    }

    // ---------- what G3 reads and must never write ----------
    match /users/{uid}/weeks/{week} {
      allow read: if isOwner(uid);
      allow write: if false;        // G6 + Cloud Functions only
    }

    match /plans/{uid}/assignments/{day} {
      allow read: if isOwner(uid);
      allow write: if false;        // G2, server-authored (spine §5)
    }

    match /plans/{uid}/versions/{version} {
      allow read: if isOwner(uid);
      allow write: if false;
    }

    // C5 — restated here because G3 renders gated surfaces and must not be the hole.
    match /users/{uid} {
      allow read: if isOwner(uid);
      allow update: if isOwner(uid)
        && noStreak(request.resource.data)
        && !request.resource.data.diff(resource.data).affectedKeys()
              .hasAny(['verification', 'rewards', 'weeklyGoal']);
    }
  }
}
```

The `users/{uid}` block is written so G3's own client build cannot touch `rewards` or `weeklyGoal`
even by accident — the spine's ownership table made G6 the writer, and rules make that true rather
than hoped-for. `verification` is denied to every client (C5).

---

## 7. Interface to the other groups

### What I consume

| From | Path / field | Why | Status |
|---|---|---|---|
| **G2** | `plans/{uid}/assignments/{yyyy-MM-dd}` — needs `kind: 'workout'\|'rest'`, `title`, `durationMin`, `moveCount`, `planVersion`, `mealSlots` | T01's workout card, `restDay` state, T06's "Start day 1" | `kind` is a **request** — the spine lists the doc but not a rest marker |
| **G6** | `users/{uid}/weeks/{yyyy-Www}` — `sessionsTarget, sessionsLogged, counted, repairedByRestWeek` | T01 week card, T04 | exists |
| **G6** | `users/{uid}.weeklyGoal` — needs **`lastRepairedWeek: string?`** and **`tierSlippedWeek: string?`** | lets T04/T05 detect a pending notice from the user doc I already read, instead of a 5th read of *last* week's document | **request** — this is what holds T01 at 4 reads on a Monday |
| **G6** | `users/{uid}.rewards.{points,level,tier}` | T01 pill, T05 kept-list, T07, T08 | exists |
| **G4** | `users/{uid}/sessions/*` — `completedAt`, `source` | `inProgress`/`done`/`recalled` | exists |
| **G5** | `users/{uid}/meals/{yyyy-MM-dd}` — `slots`, `totals`; plus a **cacheable `usualPlates` list with a version stamp** | T01 meal card, T03 payload | `usualPlates` is a **request** — see §9 Q2 |
| **G8** | device push token, `Africa/Cairo` clock authority, connectivity state, Health Connect / HealthKit channel | T03 delivery, date rollover, queued chips, T01 walk card | exists |

### What I publish

| Path / API | Consumers |
|---|---|
| `users/{uid}/checkins/{yyyy-MM-dd}` | G4 (session suggestion), cycle group (rules §2.4/§2.5) |
| `users/{uid}/notices/*` | G3 only |
| `users/{uid}/firstWeek/arc` | G6 (T08 summary), G5/community tick their own arc steps through my command |
| `UndoableLog` / `LogCommandBus` | **G4 and G5 must route every log through these** — rule 9 is a single implementation, not one per feature |
| `DayStateResolver` | G4's R01/R03 entry points, so Home and Train agree on the day |

### Commands I must call rather than write directly

Because the spine forbids two groups writing one field, three of my screens' primary actions are
other groups' writes and need an exposed domain command:

| Screen | Action | Command owner |
|---|---|---|
| T02 | save a recalled session (+ week credit) | **G4** `SessionRepository.logRecalled()`; week increment by Cloud Function on `sessions` create/delete (C4) |
| T03 | log the nudged meal | **G5** `MealRepository.logItem()` |
| T05 | "Make this week 2 sessions" | **G6** `WeeklyGoalService.setTarget()` — I must not write `weeklyGoal` |

---

## 8. Test IDs I am accountable for

**P0 — sole or primary owner**

| ID | Screens | Note |
|---|---|---|
| `P0-FR-02` | T07 | sole owner — no timer, no expiry, no failure state |
| `P0-WEEK-02` | T04, P01 | repaired week, no red, no count of what was missed |
| `P0-WEEK-03` | T05, P01 | slip shown once, everything kept |

**P0 — co-accountable (my screen, another group's write)**

| ID | Screens | Split |
|---|---|---|
| `P0-LOG-04` | T01, T02, R12 | G3 owns the two taps and the state; G4 owns the session + no-personal-best |
| `P0-LOG-09` | T01, E01, R07 | G3 owns T01's offline logging and the queued chip |
| `P0-WEEK-01` | T01, P01 | G6 counts; G3 guarantees no daily streak appears on T01 |
| `P0-FR-01` | T06, E09, M17 | G3 owns T06 as a branch, not a route |
| `P0-NAV-01` | all in-scope | G3 owns depth from the T01 tab root |
| `P0-A11Y-01` | all in-scope | G3 owns Arabic RTL on T01–T08 |

**P1 — rule guards**

| ID | Rule | Ownership |
|---|---|---|
| `P1-RULE-03` | No daily streak exists anywhere | **primary owner** — T01, T04, T05, T07 (+P01 with G6) |
| `P1-RULE-09` | Undo, never a confirmation dialog | **primary owner** of the domain guarantee — T02 is mine, R07/R09/E04 route through my `LogCommandBus` |

**P2 touching my screens** (state coverage, not the accountable set): `P2-RTL-T01`…`P2-RTL-T08`,
`P2-TXT-T01`…`P2-TXT-T08`, `P2-OFF-T01`, `P2-ERR-T01`, `P2-OFF-T02`, `P2-ERR-T02`.

---

## 9. Open questions

| # | Question | Why it is not mine to settle | Proposal |
|---|---|---|---|
| **Q1** | **A walk or a class has nowhere to live.** T01's "Count it" walk card and T02's "A class or a walk — counts by time alone" both produce an activity with no `assignmentId`, no `planVersion` and no sets. The spine's `sessions` shape requires the first two and its `source` enum is only `'live'\|'recalled'`. | `sessions/*` is G4's; the enum is spine text I may not edit. | Ask G4 + spine owner to widen `source` to `'live'\|'recalled'\|'device'\|'timeOnly'`, make `assignmentId`/`planVersion` nullable, and allow `sets: []`. **Blocks F15 and half of T02.** |
| **Q2** | **T01's meal card has no budgeted data source.** The spine gives T01 4 reads and none of them is the meal document, yet T01 draws two plates and a logged-at time. | The reallocation touches both G5's collection and the spine's §4 table. | Accept §2's net-zero argument (T01 pays 1, E01 pays 0) and have G5 publish a cacheable `usualPlates` list with a version stamp, so the *suggestion* half costs nothing per open. |
| **Q3** | **T04/T05 need a repair/slip marker on the user doc**, or Monday costs a 5th read of *last* week's document. | `weeklyGoal` is G6-written; I cannot add `lastRepairedWeek` / `tierSlippedWeek` myself. | G6 adds both as nullable ISO-week strings. If refused, T01 is 5 reads on Mondays only — state it rather than hide it. |
| **Q4** | **Who creates `firstWeek/arc`?** T06's branch reads it before any log exists. | Account creation is G1; onboarding completion is G2. | G2 creates it with `hasAnyLog: false` at the end of O05. Fallback: I create it lazily on first T01 open (1 write, once per account). |
| **Q5** | **T07 cannot be completed inside the MVP cut.** Steps 4 (join a group) and 5 (add a follow-up picture) depend on community, which §0 puts out of the MVP — so the arc stalls at 3 of 5 and **T08 is unreachable at launch**. | A scope decision, not a schema one. | Either ship a 3-step arc for the MVP, or keep 5 steps with the community pair visibly `waiting` — which HANDOFF 17 permits, since nothing expires. Owner's call; I will not silently drop steps. |
| **Q6** | **The check-in symptom enums are invented above.** I wrote conservative value sets into the security rules because no group has published them. | The Y-screens (cycle) define these; cycle is post-MVP and has no Stage 2 agent. | Ratify my sets or supply the real ones **before** the rules deploy — a wrong enum in `allow` is a silent write rejection on a hot path. |
| **Q7** | **"Three ignored nudges in a row stops them" is a consecutive counter.** T03's own copy promises it (`app_en.arb:838`). It counts *notification dismissals*, never training days, and is never displayed — but it is consecutive-shaped and C6 is absolute. | C6 is spine text; I will not reinterpret it myself. | Name it `nudge.ignoredRun` on `users/{uid}/devices/{deviceId}` (G8's collection, a device concern, not a progress one) and have the spine owner confirm it is outside C6. If refused: fall back to a decaying send-probability, which needs no counter. |
| **Q8** | **Does the T03 lock-screen write need a Cloud Function?** The iOS Content Extension cannot safely touch the Firestore cache, so "log without opening the app" needs a server endpoint that the spine does not list. | Cloud Functions surface is shared; G8 owns platform. | One idempotent callable keyed `{uid, date, slot}`. If the owner declines the endpoint, iOS degrades to the deferred App Group inbox and the log lands on next launch — which must then be stated on screen, because T03's promise is that the app stays closed. |
| **Q9** | **Whose Cloud Function increments `weeks.sessionsLogged`?** My optimistic week credit assumes an `onCreate`/`onDelete` pair on `sessions`. | G6 owns week counting, G4 owns sessions. | G6 writes the trigger; G4 guarantees the deterministic recall ID so a replayed offline write cannot double-increment. |

**Resolved while reading, recorded so nobody re-opens them:** `ux-review-pass-2.md` MAJOR 5 (T02
landing on the personal-best celebration) and MAJOR 12 (T01 hard-wiring the coached flow) are both
already fixed in the current source — `screens-today.mjs:42–43` points at R12 "Logged from memory",
and `workoutCard()` renders `Week 3 of 8` with `go: 'R07'`. No action needed.

---

## Scalability gate — self-check

| Gate | Result | Evidence |
|---|---|---|
| Unbounded collection scan | **PASS** | Zero queries in this group. Every read is a `doc()` get on a deterministic ID (C1). The two places a scan was tempting — "her usual meal at this hour" and "which first-week steps are done" — are both answered by a consumed rollup and a single boolean document, specifically so neither becomes `collection.where(...)` over a growing history. |
| Per-user fan-out write growing with followers | **PASS** | G3 writes nothing outside `users/{uid}/**`. There is no social surface, no follower list and no shared document, so no write's cost varies with anyone else's graph. |
| Unindexed query on a hot path | **PASS** | T01 is the hottest path in the product and issues four primary-key gets. No composite index is required anywhere in G3 — consistent with spine §4. |
| Needs a migration to reach 100k MAU | **PASS** | Date- and week-keyed documents shard naturally by `uid`; no counter is shared between women, so there is no hot document to re-shard. Every field I add is additive and nullable, and both new collections are keyed deterministically from day one — 35k DAU and 350k DAU differ only in document count. |

**Cost envelope:** ~175k reads and ~45k writes per day, ~$5/month at list price, ~4–6 reads and ~1–2
writes per active day against §3's 8/6 allowance. Within budget.
