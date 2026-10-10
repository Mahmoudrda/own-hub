# G8 — Platform foundations

Owns no screens and everything under all **59** of them: offline sync, i18n/RTL, theming, routing,
analytics, error handling, platform channels, Remote Config, **the single `users/{uid}` ruleset**, cost.

**Rejection-contract map** — 1 data model §3 · 2 library caching §4 · 3 state machines §6 · 4 offline
contract §7 · 5 owned rules §8 · 6 security rules as code §9 · 7 group interface §10 · 8 test IDs §11 ·
9 open questions §14. Scalability gate §12. Cost §5. Toolchain/DoD §13.

Written **last** of the eight, so this plan reconciles rather than assumes: every sibling plan and
`RECONCILIATION.md` were read before writing, and §2 lists what that changed.

---

## 1. Verified ground truth (measured, not assumed)

| Check | Result |
|---|---|
| Flutter | **3.47.4** stable, Dart 3.13.3 (at `~/development/flutter`, **not on `PATH`**) |
| ARB parity | 1,789 strings, `en`/`ar` key sets identical, **0** missing either side, **0** placeholder mismatches |
| ARB key scheme | semantic slugs (`coaching`, `eat`, `train`) — regenerated and **in sync** with `build-flutter.mjs` |
| Slug keys needing `_n` | **19** (`train_2`, `done_2`, `today_2`, `now_2`, `mon_2`, …) — order-dependent, see §14-10 |
| Strings with no Latin chars | **1**, key `blank`: `"الفصحى — كل شيء في التطبيق"` sits in the **English** dictionary (defect, §14-9) |
| `en == ar` values | 14, all legitimately identical (`+20`, `1½`, `12 × 10`, `84%`, `4.8 ★ (126)`, `Aa`, `NASM CPT`, `0:12 / 1:00`) — exactly the isolated numeric spans needing LTR isolation |
| RTL mirror list (`i18n.mjs` `RTL_CSS`) | 8 selectors: `arrow_back`, `arrow_forward`, `chevron_right`, `chevron_left`, `send`, `play_arrow`, `skip_next`, `swap_horiz` |
| `app_routes.dart` | 161 routes / 16 flows |
| Test suite | **205 cases** — 36 P0, 11 P1, 158 P2 |
| In-scope screens | **59** (`P2-RTL-*` census): C01–C16 (all 16), O01–O05, T01–T08, R01–R13, E01–E09, P01–P04, A01–A04 |
| Writing screens (`P2-OFF`/`P2-ERR`) | **20**: A01, A02, A03, A04, C06, C07, C10, C11, E01–E04, O01, O05, P04, R07, R08, R09, T01, T02 — A01 and A04 added after G7 and I independently reported the gap |

**Stack (owned, decided once):** Flutter 3.x / Material 3 `useMaterial3: true`, Rubik both scripts ·
Firebase Auth (phone), Firestore, Functions gen2, Remote Config, Crashlytics, App Check ·
`go_router` · `flutter_localizations` + gen_l10n · Amplitude · **video on Cloudflare R2 + CDN, never
Firebase Storage egress** · local queue in `sqflite` · `timezone` (IANA) for all date keys.

---

## 2. What reading the other seven plans changed in this one

Recorded because a plan that silently contradicts its siblings is worse than one that is late.

| # | Correction | Where |
|---|---|---|
| 1 | **The in-scope count is 59, not 57.** C03 and C13 were dropped by a generator regex that could not match an apostrophe. My golden matrix is 236 images, not 228 | §1, §11 |
| 2 | **Spine C3 is corrected: same-slot writes need `arrayUnion` + `increment`, not `merge`.** My v1 conflict policy said distinct-key merge was sufficient — true only *across* slots. `P0-LOG-11` exists to catch exactly the regression I would have shipped | §7 |
| 3 | **I now author the one `users/{uid}` ruleset.** Seven groups each wrote a `match /users/{uid}` with a permissive `allow update`; Firestore ORs them, so G1's `hasOnly([… 'rewards' …])` would have defeated G6's `rewardsUntouched()` and let a client mint its own points | §9 |
| 4 | **There is no single pinned clock.** My v1 pinned `Africa/Cairo` for everything, which contradicts G5 (device tz per document) and G6 (`weeklyGoal.tz`, a property of the woman). There are **two** clocks and they are different on purpose | §6.4 |
| 5 | **Embedded arrays are not field-mergeable.** Firestore has no field path to an array element, so G4's `sets` flush is a whole-array rewrite, safe only under its single-writer `deviceId` guard | §7 |
| 6 | **Video is 12.1 TB/month** (G4's arithmetic) and G4 already commits to R2 + Cloudflare at **$0 egress**. I price the platform around that rather than re-deriving it | §5 |
| 7 | **Week closing is G6's, already solved lazily.** My v1 claimed the thundering-herd fix as my design; G6 had already specified client `closeRequestedAt` + a Function decision + a `lastClosedWeek` watermark | §12 |
| 8 | **G7's enum-typed analytics API is stronger than my string allowlist.** `Map<AnalyticsProp, AnalyticsValue>` with no `Map<String, dynamic>` overload makes a bad property a *compile* error. Adopted verbatim | §16 |
| 9 | Three new `devices` fields requested by G3 and G7; four new user subcollections (`notices`, `firstWeek`, `eatPrefs`, `mealPlans`, `awards`, `consents`, `notifications`, …) that my ruleset and the deletion manifest must both cover | §3, §9 |
| 10 | **Index *exemptions* are mandatory, not a cost optimisation.** New spine constraint raised by G4: Firestore auto-indexes every field including members of the embedded `sets` array, so without an explicit exemption `sets.actualWeight` **is** indexed and rule 11 is simply false in the deployed project no matter what the code says. Absence of a composite index is not sufficient | §8, §9.3, §12 |
| 11 | **I conceded G4's OQ-18 on video URLs.** My v1/v2 specified short-lived *signed* URLs for the library. G4 is right: a signed URL is unique per request, so the edge cache hit rate collapses — and with it the $0-egress argument **both** plans depend on — while a downloaded offline file becomes unplayable when its signature expires, breaking download-for-offline. Public content-addressed immutable URLs for the library; signed URLs reserved for user-generated media | §4, §5, §18 |
| 12 | **`setting_key` removed from the analytics allowlist.** G7 owns the permitted column and dropped it deliberately: per-switch telemetry on a privacy screen edges toward cycle-sharing and coach-sharing posture. My draft still listed it, contradicting the owner of that column | §16 |
| 13 | **G6 overruled my "no per-write Firestore trigger", and is right.** I optimised invocations; G6 showed the arithmetic lands at ~1.8 M/month — inside gen2's free tier and inside my own §5 line — and that **client-written points cannot be secured at any price**. Rules cannot validate an increment's justification, so the currency must be Function-written | §5 |
| 14 | **`measurements` needed a key whitelist, which mine lacked.** Without one, a `sharedWith`, `public` or `rank` field can come into existence, and rule 11 stops being a storage-layer property. G6 supplied it; adopted | §9.1 |
| 15 | **My offline table wrongly listed `weeks` as offline-writable.** Under the reconciled design `weeks`, `bests`, `awards` and `rewards` are not client-written at all, so they cannot be written offline either. What waits offline is the *bookkeeping*, and no screen waits for it | §7 |
| 16 | **I withdrew the bucketed close sweep.** G6 accepted the lazy close and declined the sweep on three disqualifying grounds — it needs an unbounded scan to find its victims, timezones fan it out into 24 waves, and at 35% DAU two-thirds of its writes are dead. My own gate forbids the first | §12 |

---

## 3. Data model — my collections + the cross-cutting conventions

### `users/{uid}/devices/{deviceId}` — G8 writes, G8 reads

| Field | Type | Notes |
|---|---|---|
| `deviceId` | string | doc id; stable install id, never IDFA/AAID |
| `pushToken` | string | FCM |
| `platform` | `'android'\|'ios'` | |
| `osVersion`, `appVersion`, `buildNumber` | string | |
| `locale` | `'en'\|'ar'` | server-side notification language (G6 reads) |
| `tz` | string | IANA name, e.g. `Africa/Cairo` |
| `analyticsId` | string | random UUID — the Amplitude identity, **never** the uid |
| `lowDataMode` | bool | feeds G4's `VideoPolicy` |
| `libraryVersion` | int | which content bundle this install holds |
| `lastSeenAt` | timestamp | server |
| `schemaV` | int | |
| **`notifPermission`** | enum | **requested by G7** — per-device permission state machine |
| **`notifPermissionUpdatedAt`** | timestamp | **requested by G7** |
| **`nudge.ignoredRun`** | int | **requested by G3 (Q7)** — consecutive *ignored notifications*, never training days, never displayed. **Granted, and flagged to the spine owner** (§14-6): it is consecutive-shaped, and C6 is absolute. If refused, G3 falls back to a decaying send-probability |

Capped at **5 devices**; `onDeviceRegister` evicts the oldest `lastSeenAt`. Bounded by construction.
Registration also calls **G1's `requestReverification(uid, 'new_device')`** (function-to-function; I
never read G1's collections and G1 never reads `devices`).

### `users/{uid}/syncQueue/{opId}` — local-only shadow ledger

**Named conflict with the spine (§14-1).** The spine fixes this path *and* calls it "local-only; never
uploaded". A Firestore write is uploaded on reconnect by definition, so both cannot hold. Resolution,
changing no spine path or field name: the path is the record's **logical identity**, stored verbatim in
a local `sqflite` table; the Firestore path is **denied outright in rules**, so if any group ever writes
it, the write is rejected instead of silently syncing a device's queue. G2 and G6 both already treat it
as "G8's, and local" — this only makes it true.

| Field | Type | Notes |
|---|---|---|
| `opId` | string | key; UUIDv4 minted once, reused on every retry |
| `path` | string | target doc path |
| `op` | `'set'\|'merge'\|'update'\|'transform'` | |
| `payloadJson` | text | the mutation, transforms named not pre-applied |
| `state` | enum | §6.1 |
| `attempts`, `nextAttemptAt` | int | backoff |
| `clientWrittenAt` | int ms | ordering key while `serverTimestamp` is unresolved |
| `undoUntil` | int ms | `pendingUndo` deadline |
| `lastError` | string? | coarse class only, never payload |
| `screenId` | string | for the queued-row UI and analytics |

**Why it exists:** the Firestore SDK exposes no per-write state, and on a rules rejection it rolls the
local mutation back *silently*. G6 correctly reads `hasPendingWrites` from snapshot metadata for its own
optimistic surfaces and adds no second store — that is right for *rendering*. The ledger exists for what
metadata cannot give: a **rejected** write that needs surfacing and retrying, and the `pendingUndo` gate.

### Cross-cutting conventions — binding on all groups

| # | Convention | Enforcement |
|---|---|---|
| K1 | Deterministic ids (C1) from `DocIds` only: `DocIds.day()`, `DocIds.isoWeek()`, `DocIds.exercise()`; `DocIds.session()` mints a UUID **once** and reuses it on every retry | rules regex per collection; `docid_test.dart` |
| K2 | No group touches `FirebaseFirestore.instance` outside `lib/data/`; writes go through `Repository.write(WriteIntent)` | `chokepoint_test.dart` (AST, single import site) |
| K3 | Every write carries `schemaV:int`, `updatedAt: serverTimestamp()`, `clientWrittenAt:int`, `opId` | rules require `updatedAt == request.time` (G5's `freshStamp()`, adopted globally) |
| K4 | **Never sort on `updatedAt` while a write is pending** — `serverTimestamp()` is `null` locally then fills on ack, so rows jump. Sort on `clientWrittenAt` | `pending_order_test.dart` |
| K5 | Counters only via `FieldValue.increment` (**spine C4, corrected**). An increment **never travels alone**: it travels with the creation of a deterministic id — `awardId`, `weekId` — *inside the same transaction*, so a replay fails on the duplicate id instead of succeeding twice. Commutative is not idempotent, and conflating the two is the difference between a safe counter and one that double-pays | `no_rmw_counter` lint **scoped to `lib/` only, never `functions/`** (G6: a server-side daily cap must *compare* against a counter inside a transaction, which is correct there and wrong on a client) + `increment_guard_test.dart` + **`P0-RWD-01`** |
| K6 | Day/week-keyed docs use `set(merge: true)`; a bare `set()` clobbers a sibling slot offline | `merge_only_test.dart` |
| K7 | **Same-slot collection writes use `arrayUnion`/`arrayRemove` + `increment`, never a value overwrite** (corrected C3) | `P0-LOG-11` |
| K8 | An **embedded array** (G4's `sets`) is rewritten wholesale and is therefore single-writer only, guarded by an immutable `deviceId` | G4's rules `immutableOk()` |
| K9 | No `streak`/`dayStreak`/`consecutiveDays`/`currentStreak`/`daysInARow`/`missedDays`/`streakDays`/`dailyStreak` anywhere — the union of all seven groups' ban lists, in one helper | rules `noStreak()` + lint |
| K10 | Two clocks, never conflated — §6.4 | `clock_test.dart` with fixed clocks either side of both Cairo DST transitions |
| K11 | Schema evolution is **additive only**; readers tolerate unknown and absent fields. No backfill migration is permitted | `schema_forward_compat_test.dart` |
| K12 | Any new collection is added to G7's machine-readable deletion manifest **in the same change** | build-breaking manifest check (G7's check (e)) |

---

## 4. Read-only libraries — cost and caching (the 7-vs-40 difference)

`exercises` (124), `foods` (~4,100), `recipes`, `programs`, `workouts` are immutable content. **No client
reads them from Firestore on any journey.** Firestore holds them only as the pipeline's source of truth;
the rules in §9 are an admin/fallback path, not the hot path.

| Layer | Mechanism |
|---|---|
| Ship | `assets/library/v{N}/*.json` bundled in the binary, emitted by `gen:library` |
| Version stamp | Remote Config `library_version:int` + manifest URL; RC fetched ≤1×/12 h, free |
| Update | download one gzipped bundle from the CDN, verify `sha256`, swap atomically, keep the old bundle until the swap succeeds. `libVersion` is **bumped, never purged** (G4) |
| Query | local `sqflite` **FTS5** — E02 typing does zero network calls, which is what makes `P0-LOG-07` "resolves with no network" true |
| Arabic search | `FoodSearchNormalizer`: fold أ/إ/آ→ا, ة→ه, ى→ي, strip tashkīl (U+064B–U+0652) before indexing *and* querying |
| Partial packs | E02 shows **the count actually loaded**, never 4,100, until the full pack lands (G5's Q9) |
| Video | never bundled. **Public, content-addressed, immutable URLs** (`max-age=31536000, immutable`) at `cdn.<domain>/v/{libVersion}/{assetId}/…`; HLS for streaming, progressive MP4 for offline (G4). **Not signed URLs** — see §2-11 |

**Firestore reads for libraries: 0 per session, 0 per day.** Holds the typical day at the spine's ~7
reads instead of ~40; the cost of getting this wrong is ~34.6 M extra reads/month (+$10–21) and, worse,
a dead Eat search on a microbus.

---

## 5. Cost envelope at §3's numbers (35,000 DAU; 280k reads / 210k writes per day; 12.1 TB/month video)

Assumptions stated: Firestore **regional** (`europe-west1`) at $0.03/100k reads, $0.09/100k writes,
$0.15/GiB-month. Multi-region roughly doubles ops.

### 5.1 Platform lines (mine)

| Line | Volume / month | Cost |
|---|---|---|
| Firestore reads | 8.4 M | $2.52 |
| Firestore writes | 6.3 M | $5.67 |
| Firestore storage + indexes | ~170 GB in year 1 | ~$26 |
| Cloud Functions gen2 | ~1.5 M invocations, ~75k GB-s | ~$5 (largely free tier) |
| R2 storage + Cloudflare CDN egress (G4's tier) | 50 GB stored, **12.1 TB egress** | **$0.75** |
| — *conditional on cacheability* | the $0 egress line holds **only** while library URLs stay public and immutable; per-request signed URLs would collapse the edge hit rate and put real traffic back on the origin | — |
| FCM · Remote Config · Crashlytics · App Check | — | $0 |
| **Platform subtotal** | | **≈ $40/month** |

**The read budget survived a correction that could have understated it 8×.** Spine §4 originally costed
P01's "last 8 weeks" as one range read. Firestore bills **per document returned**, so it was 8 reads, not
1. G6 replaced the range with a fixed 8-element `weeklyGoal.recent8` array on the user document — already
fetched at T01 — bringing P01 to 2 reads and **0** additional network reads when reached from Home. The
typical day stays at ~7, so the 8.4 M reads/month and the $2.52 line above are unchanged. Recorded
because it is the exact shape of error my own scalability gate is meant to catch: a "single range read"
is never one read, and pricing it as one hides a factor of eight until the bill arrives.

**On Firestore triggers — I was overruled, and the correction is recorded.** I argued for no per-write
trigger on invocation cost, reasoning that 6.3 M writes/month would mean 6.3 M invocations. G6 showed the
real figure is **~1.8 M/month** (triggers fire on session and meal *completion*, not on every set flush)
— inside gen2's free tier and inside the line above — and made the argument that settles it: **rules
cannot validate an increment's justification, so a client-written `rewards.points` cannot be secured at
any price.** Awards are therefore Function-written, transactionally bound to a deterministic `awardId`,
and the client's own `increment` survives only where it is evidence (`sessions`, `meals`), never where it
is currency. Cost was never the deciding axis; forgeability was.

### 5.2 The assembled product (from the reporting plans)

| Group | Monthly |
|---|---|
| G8 platform | ≈ $40 |
| G4 train (incl. all video) | ≈ $8 |
| G5 eat | ≈ $19 (+ up to $420 if cloud STT is enabled) |
| G3 today | ≈ $5 |
| G2 onboarding | ≈ $2.60 |
| G6 progress | within the Firestore lines above |
| G1 identity — Firestore | ≈ $0.13 |
| **Infrastructure total** | **≈ $75–95/month at 35,000 DAU** |
| **G1 identity — ID-verification provider fees** | **$2,600 – $8,500** |
| **Firebase phone-auth SMS** (~25k SMS; Egypt tier unverified) | **$250 – $3,750** |
| **Amplitude at 100k MTU** (exceeds the 50k free tier) | **$1,000 – $2,500** |

**Stated envelope: $1,500/month for everything G8 controls** — and the platform comes in at **~$40**,
two orders of magnitude inside it.

**Saying it now, not at the end: the product's cost is not its infrastructure, and the plan exceeds a
sane MVP budget on three lines, none of them architectural.** Realistic all-in is **$3,900–14,800/month**
against ~$90 of infrastructure. Ranked:

1. **ID verification ($2.6k–8.5k)** — ~97% of G1's line and the single largest operating expense. A
   contract negotiation (§10 of the brief), not a design choice.
2. **Phone-auth SMS ($250–3,750)** — scales with *acquisition*, not MAU. I own the mitigations: App
   Check on the Identity Platform endpoint (the SMS-pumping defence), 60 s resend lock, per-number and
   per-IP quotas, long-lived refresh tokens. Designed fallback if the tier lands high: keep Firebase Auth
   but move the **OTP transport** to an Egyptian aggregator (~$0.003–0.006/SMS) behind a custom-token
   Function — ~20× cheaper, at the cost of owning OTP brute-force and replay defence ourselves.
3. **Amplitude ($1k–2.5k)** — ~25× the infrastructure. Mandated by the brief, so I have not silently
   substituted anything; it needs an owner decision (§14-4).

**The one architectural decision that pays for everything:** video never leaves Firebase Storage. At
$0.12/GB, 12.1 TB is **~$1,352/month**; on R2 + Cloudflare it is **$0** egress and $0.75 storage.
Cloudflare Stream was rejected by G4 (per-minute delivery ≈ $2,750/month at this volume). Any group that
reaches for a Firebase Storage download URL for video has broken the budget by ~15× the whole stack.

---

## 6. State machines

### 6.1 Sync record (`syncQueue.state`) — 8 states

| State | Meaning | → on |
|---|---|---|
| `pendingUndo` | in the local cache, UI already shows it, **not released to the network**; 5 s window open | expiry → `queued`; Undo → `discarded` |
| `queued` | released, awaiting connectivity/flush | flush → `inFlight` |
| `inFlight` | in the Firestore write stream | ack → `synced`; transient → `retryBackoff`; rules/invalid → `rejected` |
| `synced` | server acked — terminal | purged after 24 h |
| `retryBackoff` | `unavailable` / `deadline-exceeded` / `aborted` | `nextAttemptAt` → `inFlight` |
| `rejected` | `permission-denied` / `invalid-argument`; the SDK has already rolled the local mutation back | Retry → `queued`; dismiss → `parked` |
| `discarded` | undone inside the window, never left the device — terminal | purged at once |
| `parked` | acknowledged failure, kept 7 days for diagnostics — terminal | purged at 7 d |

`pendingUndo` is load-bearing: the mutation has not been released, so **undo needs no compensating
delete and no round-trip**. This is what lets G3's `LogCommandBus` have *deferred-write* semantics, which
G5's cost model and G6's once-a-day points hook both depend on (G5 Q14) — an undone log costs **zero**
writes. Backoff is exponential with jitter, 1 s → 300 s cap.

### 6.2 Session / auth + verification gate (`SessionState`) — 9 states

| State | Router lands on | Leaves on |
|---|---|---|
| `booting` | splash | cache hydrated, token read |
| `unauthenticated` | C01 | phone submitted → `otpSent` |
| `otpSent` | C07 | code verified → `authedUnverified`; timeout → `unauthenticated` |
| `authedUnverified` | C09 (or O01) | provider decision |
| `authedPendingReview` | C14 | Function decision |
| `authedVerified` | T01 (O01 if intake incomplete) | sign-out, revoke, deletion |
| `authedRejected` | C12-rejected → C15 | route to the woman-reviewer path |
| `reauthRequired` | C06 | refresh failed / tokens revoked |
| `deleted` | C01 | terminal; local stores wiped |

**Verification is read from G1's custom claims only** — `{verified, vexp, pledgeV, role, adult}`, minted
server-side, **zero document reads**. I copy G1's `isVerified()` / `pledgeAccepted()` /
`canEnterCommunity()` / `isAdult()` verbatim and never re-implement them with a rules `get()`, because a
`get()` is a billed read on every gated call at 100k MAU.

**Critical routing consequence, from G1's published contract:** `authedUnverified` and
`authedPendingReview` must still render **R01/E05/H01 and the whole training and recipe surface**. Only
community waits. `P0-VER-04` fails if my redirect guard treats "not verified" as "not allowed in".

### 6.3 Connectivity (`ConnectivityState`) — 4 states, orthogonal to 6.2

| State | Trigger | Effect |
|---|---|---|
| `online` | transport up + a write acked in the last 60 s | normal |
| `offline` | no transport | nothing releases; queued convention (§7) |
| `lowData` | user toggle **or** metered connection | feeds G4's `VideoPolicy.resolve()`: 360p cap, no prefetch, no autoplay, posters not loops |
| `serverDegraded` | ≥3 consecutive non-permission failures while transport is up | banner + backoff; writes still queue |

`offline` and `serverDegraded` are distinct on purpose: one is her signal, the other is our fault, and
`P2-OFF-*` and `P2-ERR-*` test them separately.

### 6.4 The two clocks — resolved, not pinned

My v1 pinned `Africa/Cairo` for everything. That was wrong, and it contradicted two plans. There are two
clocks, they disagree by design, and conflating them corrupts either a day or a week:

| Clock | Used for | Zone | Owner's reason |
|---|---|---|---|
| `AppClock.dayKey()` | `meals/{yyyy-MM-dd}`, `checkins/{…}`, `sessions.dateKey` | **device-local at the moment of the action**, with `tz` recorded in the document (G5) | a woman logging breakfast in Cairo and dinner in Dubai should see each meal on the day she ate it |
| **`AppClock.isoWeek(tz)`** — signature required by G6, zone always explicit | `weeks/{yyyy-Www}`, all week arithmetic | **`weeklyGoal.tz`** — a property of the woman, default `Africa/Cairo` (G6) | if the week boundary followed the handset, a Sunday-night flight could reopen a closed week or file a session into a week that no longer exists. The zone is a parameter, never a constant: a Cairo-hardcoded boundary misfiles the Gulf diaspora's evening sessions, which is a market and not an edge case |

Both use the **IANA database via the `timezone` package**, bundled, with a Remote Config version stamp —
never a fixed `+02:00`, because Cairo is UTC+2/+3 (DST last Friday of April → last Thursday of October,
reinstated 2023) and a fixed offset misfiles a Sunday-23:30 session twice a year. The visible
consequence is stated rather than hidden: a session logged in Toronto at Sunday 20:00 EDT is Monday 02:00
Cairo and counts toward the **new** week. When the device zone differs from `weeklyGoal.tz` for 3+
consecutive days, I surface G6's single explicit "move your week to this timezone?" action, applying from
the next boundary only.

---

## 7. The offline contract (the seven other groups implement this verbatim)

**Setup.** `Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED)` in
`FirebaseBootstrap.init()`, before any other Firestore call. G4's and G6's cost models both state they
depend on the unbounded cache being on.

| Writable offline | Not writable offline |
|---|---|
| **Every** `users/{uid}/**` write that a client owns — meals, checkins, sessions, measurements, devices, profile, privacy, notify, and `weeklyGoal.{sessionsTarget, tz, goalKind}`. Logging never requires signal | `verification` (live provider; C5) — C10/C11/C12 refuse to open the camera offline and show the explicit offline state (`P0-VER-07`), never a queued write |
| | **`weeks/*`, `bests/*`, `awards/*`, `rewards.*` — not client-written at all**, so not offline-writable either (G6's correction to my draft). What waits offline is the *bookkeeping*, and no screen waits for it: every number on P01 is computed locally by `WeekRollup` from documents already in cache |
| G2's O01–O04 per-step profile merges | `plans/**` — server-authored; O05's publish is a **queued intent** in `syncQueue`, and the plan appears when it lands |
| | account deletion (Function), `awards`, `bests`, `rewards`, `counted`/`closedAt` (all Function-only) |

### Conflict policy (corrected)

| Shape | Policy | Why |
|---|---|---|
| Distinct map keys (`slots.breakfast` vs `.dinner`; `privacy` vs `notify`) | field-level merge, `set(merge:true)` | commutative across keys |
| **Same** collection key (two devices into `slots.lunch`) | **`arrayUnion` / `arrayRemove` transforms, never a value write** | a plain merge overwrites the whole array and loses a log — **corrected C3**, `P0-LOG-11` |
| Counters (`points`, `sessionsLogged`, `totals.kcal`) | `FieldValue.increment`, **always paired** with a deterministic doc create or a bounded `arrayUnion` guard | commutative but *not* idempotent (K5) |
| Embedded arrays (`sessions.sets`) | whole-array rewrite under a **single-writer immutable `deviceId`** guard | Firestore has no field path to an array element (G4 OQ-7) |
| Absolute-keyed rollups (`plates.<id>.d.<date>`) | idempotent per (key, date) | replay-safe by construction |
| Single-owner scalars (`profile.goal`, `ramadanMode`) | last-write-wins | one owner, one device |
| Prescribed vs actual | never merged — separate, differently-typed fields (C8) | no single field for a widget to pre-fill (rule 1) |
| Two corrections of the same item | both transforms apply → duplicate `itemId` | `MealDayReader.dedupe()` resolves deterministically at read time (G5 §4.5) |

### Idempotency — why C1 makes a retry safe

A queued write is replayed after reconnect and must not create a second document. Because `checkins`,
`meals`, `weeks`, `measurements`, `bests` and `assignments` are keyed by **date, ISO week or exercise**,
the replay targets the *same* document and collapses into the same state. `sessions` uses a client UUID
minted **once** at session start and reused for every retry, giving the same property — which is also
what lets G6 recognise a replay and refuse to double-credit a week. A random id per attempt would produce
a duplicate session; duplicate sessions inflate `sessionsLogged`; an inflated count corrupts week
counting and therefore the reward economy. `DocIds` is the only sanctioned source of an id.

### The queued-not-synced UI convention — binding on all groups

| Rule | Detail |
|---|---|
| Render the value immediately at **full opacity** | from her point of view it *is* saved; greying it out says "maybe" |
| Row affordance | trailing 16 dp `cloud_queue` glyph, `onSurfaceVariant` at 60% |
| Semantics | `l10n.syncQueued` — "Saved on your phone. It will sync when you're back online." |
| During `pendingUndo` | **no** glyph — otherwise every log flickers queued→synced |
| On `rejected` only | row background `errorContainer`, inline Retry, copy from a fixed localised set |
| Long queue | after 24 h, one quiet inline line ("waiting for signal to save 3 meals") — informational, never blocking (G5) |
| App level | one "N changes waiting" chip on **A02 only** |
| Projected values | may be shown when computed by the **same** table the server uses, marked syncing, so it converges rather than corrects (G6's `AwardTable.preview()`) |
| **Forbidden** | a blocking spinner on any write · "failed to save" for anything that will sync · a disabled log button while offline · a confirmation dialog for logging (rule 9) |

API: `SyncStatusScope.of(context).watch(logicalPath) → Stream<SyncState>` and `SyncBadge(path:)`.
Nobody hand-rolls it. Groups rendering their own optimistic state from `hasPendingWrites` is fine and
expected; the badge and the **rejected** path must still come from here.

---

## 8. §2 rules I own, and the exact enforcement point (domain layer, never a widget)

| Rule | Enforcement point | Mechanism |
|---|---|---|
| **6** Face blur on by default, applied on-device before upload | `MediaUploadGateway.upload(MediaDraft)` | throws `BlurNotAppliedError` unless `draft.blurApplied == true`; the only path to Storage/R2, and it calls `FaceBlurChannel.blur()` first. The *default* resolution is G7's `MediaBlurPolicy.resolve()`; I enforce the upload boundary |
| **8** No AI face-gender classification | `FaceBlurChannel` surface + CI | the channel exposes **only** `blur()`. I run G1's `tools/lint_no_face_gender.sh` in the shared pipeline and add the ML Kit/Vision symbol list. **Face *detection* for blur is explicitly allowed; *classification* is not** — the distinction G1 and G7 both call out so QA does not false-positive |
| **3 / C6** Weeks, not days | `WriteIntentValidator.validate()` + rules `noStreak()` | the union of all seven ban lists in one helper; unstorable, therefore unrenderable |
| **9** Undo, not confirmation | `OfflineWriteQueue.enqueue(intent, undo: 5s)` → `pendingUndo` | the platform primitive behind G3's `UndoableLog`/`LogCommandBus`, which G4 and G5 both route through. Deferred-write, so an undone log is zero writes |
| **11 / C7** Nothing ranked | `firestore.indexes.json` (single source) + `index_allowlist_test.dart` + **mandatory single-field index exemptions** | asserts no composite index mentions `weight`, `weightLost`, `followers`, `followerCount` — **and** that the exemptions on `sessions.sets` and `measurements` are declared. Firestore auto-indexes every field by default, including members of the embedded `sets` array, so without the exemption `sets.actualWeight` is indexed and rule 11 is false in the deployed project however careful the code is. Absence of a composite index is **not** sufficient |
| **7** ID/selfie deleted | Storage rules + GCS lifecycle (§9.2) | `verification/**`, `id/**`, `selfie/**`, `kyc/**` denied by name; 1-day lifecycle as the backstop if G1's purge fails. A03's *claim* derives from `verification.imagesDeletedAt` (G7), never a hardcoded sentence |
| **C5** `verification` is Function-write-only | the composed ruleset (§9.1) — `!changed().hasAny(['verification'])` **outside** every group's fragment | a client cannot write its own gate under **any** composition of fragments |
| **Spine §6** analytics PII boundary | `AnalyticsGateway.emit()` | §16; the permitted set is G7's, the gateway and transport are mine |
| **§7** every string localised | `no_raw_user_text` lint + `tool/i18n_guard.dart` | §15 |

Rules 1, 2, 4, 5, 10 belong to G4/G2/G3/G5 — I provide the primitives, they own enforcement.

---

## 9. Security rules as code

### 9.1 The one `users/{uid}` block, composed

Per the spine amendment, **G8 authors this once**. Firestore evaluates `allow` as a logical **OR** across
every matching block, so seven per-group blocks do not compose — they union into the most permissive
one. Composing them revealed two live holes, fixed here:

- G1's fragment allowed `changed().hasOnly([… 'rewards', 'weeklyGoal'])`, which OR-ed against G6's
  `rewardsUntouched()` would let a client **mint its own points**. `rewards` is now globally denied.
- G3's fragment allowed any `profile` write, which OR-ed against G2's `profileWriteOk()` would let a
  client write `profile.activePlanVersion` — a server-only pointer. Every profile write now goes through
  G2's validator.

The shape is: **global invariants AND-ed outside, group slices OR-ed inside.** Each slice constrains
`hasOnly` to its own top-level keys, so the OR is safe; a single write can only satisfy one slice.

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ───────── G8 helpers ─────────
    function signedIn()  { return request.auth != null; }
    function isSelf(uid) { return signedIn() && request.auth.uid == uid; }
    function changed()   { return request.resource.data.diff(resource.data).affectedKeys(); }
    function keys()      { return request.resource.data.keys(); }
    function freshStamp(){ return request.resource.data.updatedAt == request.time; }

    // ───────── G1's published claim helpers — copied verbatim, ZERO reads ─────────
    // A rules get() would be a billed read on every gated call at 100k MAU.
    function claim(k)         { return signedIn() && (k in request.auth.token); }
    function isVerified()     { return claim('verified') && request.auth.token.verified == true
                                    && claim('vexp') && request.auth.token.vexp > request.time.toMillis(); }
    function pledgeAccepted() { return claim('pledgeV') && request.auth.token.pledgeV >= 1; }
    function canEnterCommunity() { return isVerified() && pledgeAccepted(); }
    function isAdult()        { return claim('adult') && request.auth.token.adult == true; }

    // C6 — the union of all seven groups' ban lists, in one place.
    function noStreak() {
      return !keys().hasAny(['streak','streakDays','dayStreak','daysStreak','dailyStreak',
                             'currentStreak','consecutiveDays','daysInARow','missedDays']);
    }
    function isDay(id)  { return id.matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}$'); }
    function isWeek(id) { return id.matches('^[0-9]{4}-W[0-9]{2}$'); }

    match /users/{uid} {

      // ---- G2's slice: the intake profile ----
      function g2ProfileKeys() {
        return ['firstName','goal','place','equipment','days','sessionLength','lifeStage',
                'allergies','dietary','language','intake'];
      }
      function g2ServerOnlyProfileKeys() {
        return ['activePlanVersion','planPublishedAt','horizonThrough','progression'];
      }
      function g2Slice() {
        return changed().hasOnly(['profile','updatedAt','schemaV'])
          && request.resource.data.profile.diff(resource.data.profile).affectedKeys()
               .hasOnly(g2ProfileKeys())
          && !request.resource.data.profile.diff(resource.data.profile).affectedKeys()
               .hasAny(g2ServerOnlyProfileKeys())
          && request.resource.data.profile.days is int
          && request.resource.data.profile.days >= 2
          && request.resource.data.profile.days <= 5
          && request.resource.data.profile.sessionLength in [10,15,20,30]
          && request.resource.data.profile.goal in
               ['stronger','feel_better','lose_steadily','back_into_it']
          && request.resource.data.profile.place in ['home','ladies_gym','both']
          && request.resource.data.profile.lifeStage in
               ['none','postpartum','pregnant','pain_injury']
          && request.resource.data.profile.language in ['en','ar']
          && request.resource.data.profile.equipment.size() <= 8
          && request.resource.data.profile.allergies.size() <= 40;
      }

      // ---- G1's slice: role, locale mirror, pledge ----
      function g1Slice() {
        return changed().hasOnly(['role','locale','pledge','updatedAt','schemaV'])
          && (!changed().hasAny(['role'])
              || (!('role' in resource.data)
                  && request.resource.data.role in ['client','coach']))
          && (!changed().hasAny(['locale']) || request.resource.data.locale in ['ar','en'])
          && (!changed().hasAny(['pledge'])
              || (request.resource.data.pledge.acceptedAt == request.time
                  && request.resource.data.pledge.version is int
                  && (!('pledge' in resource.data)
                      || request.resource.data.pledge.version > resource.data.pledge.version)));
      }

      // ---- G6's slice: exactly four weeklyGoal sub-keys are hers ----
      // Exactly three sub-keys are hers. `slipAckedWeek` was in my draft and is
      // REMOVED at G6's request: the tier-slip acknowledgement goes through
      // WeekService.ackTierSlip(), a callable, so the counters stay unforgeable.
      function g6Slice() {
        return changed().hasOnly(['weeklyGoal','updatedAt','schemaV'])
          && request.resource.data.weeklyGoal.diff(resource.data.weeklyGoal).affectedKeys()
               .hasOnly(['sessionsTarget','tz','goalKind'])
          && request.resource.data.weeklyGoal.sessionsTarget is int
          && request.resource.data.weeklyGoal.sessionsTarget >= 2
          && request.resource.data.weeklyGoal.sessionsTarget <= 4;
      }

      // ---- G7's slice: privacy + notify ----
      function g7Slice() {
        return changed().hasOnly(['privacy','notify','updatedAt','schemaV'])
          && (!changed().hasAny(['privacy']) || (
               request.resource.data.privacy.keys().hasOnly(
                 ['profileVisible','showBests','blurFacesDefault','shareLogsWithCoach',
                  'policyVersion','updatedAt'])
               && request.resource.data.privacy.profileVisible     is bool
               && request.resource.data.privacy.showBests           is bool
               && request.resource.data.privacy.blurFacesDefault    is bool
               && request.resource.data.privacy.shareLogsWithCoach  is bool))
          && (!changed().hasAny(['notify']) || (
               request.resource.data.notify.keys().hasOnly(
                 ['push','mealNudge','quietStart','quietEnd','kinds',
                  'usualMealHour','lastNudgeOutcomes'])
               && request.resource.data.notify.push      is bool
               && request.resource.data.notify.mealNudge is bool
               && request.resource.data.notify.quietStart is int
               && request.resource.data.notify.quietStart >= 0
               && request.resource.data.notify.quietStart <= 1439
               && request.resource.data.notify.quietEnd   is int
               && request.resource.data.notify.quietEnd   >= 0
               && request.resource.data.notify.quietEnd   <= 1439
               // C6: a bounded outcome log, never a counter.
               && request.resource.data.notify.lastNudgeOutcomes.size() <= 3));
      }

      allow get:    if isSelf(uid);
      allow list:   if false;    // no cross-user query exists anywhere (C7, rule 11)
      allow create: if false;    // onAuthUserCreate (G1) only
      allow delete: if false;    // A02 deletion runs as admin (P0-DEL-01)

      allow update: if isSelf(uid)
        // ── GLOBAL INVARIANTS: true for every fragment, no exceptions ──
        && !changed().hasAny(['verification'])   // C5 — the one line that makes this women-only
        && !changed().hasAny(['rewards'])        // G6: a client-writable currency is one-line inflation
        && noStreak()                            // C6
        && freshStamp()                           // K3
        // ── GROUP SLICES, OR-ed: a write satisfies exactly one ──
        && (g1Slice() || g2Slice() || g6Slice() || g7Slice());

      // ───────── subcollections, by owner ─────────
      match /devices/{deviceId} {                                  // G8
        allow read: if isSelf(uid);
        allow create, update: if isSelf(uid) && noStreak() && freshStamp()
          && keys().hasOnly(['deviceId','pushToken','platform','osVersion','appVersion',
                             'buildNumber','locale','tz','analyticsId','lowDataMode',
                             'libraryVersion','lastSeenAt','schemaV',
                             'notifPermission','notifPermissionUpdatedAt','nudge'])
          && request.resource.data.platform in ['android','ios']
          && request.resource.data.locale in ['en','ar']
          && request.resource.data.analyticsId is string
          && (!('nudge' in request.resource.data)
              || (request.resource.data.nudge.keys().hasOnly(['ignoredRun'])
                  && request.resource.data.nudge.ignoredRun is int
                  && request.resource.data.nudge.ignoredRun >= 0
                  && request.resource.data.nudge.ignoredRun <= 3));
        allow delete: if isSelf(uid);
      }

      // Local-only ledger. If it ever reaches the server, reject it. (§14-1)
      match /syncQueue/{opId} { allow read, write: if false; }

      match /checkins/{day}     { allow read: if isSelf(uid);
                                  allow write: if false; }  // G3's validator block
      match /meals/{day}        { allow read: if isSelf(uid);
                                  allow write: if false; }  // G5's validator block
      match /sessions/{sid}     { allow read: if isSelf(uid);
                                  allow write: if false; }  // G4's validator block
      match /weeks/{week}       { allow read: if isSelf(uid);
                                  allow write: if false; }  // G6's validator block
      // Client-written (correct), but key-whitelisted — this is rule 11 at the
      // storage layer: no `sharedWith`, `public` or `rank` field can ever come
      // into existence, so there is nothing to expose by accident. The K3
      // metadata fields are inside the whitelist; omitting them would reject
      // every conformant write. (Gap in my draft, supplied by G6.)
      match /measurements/{day} {
        allow read: if isSelf(uid);
        allow create, update: if isSelf(uid) && isDay(day) && freshStamp()
          && keys().hasOnly(['weightKg','waistCm','hipsCm','armCm','thighCm',
                             'takenAt','note',
                             'schemaV','updatedAt','clientWrittenAt','opId']);
        allow delete: if isSelf(uid);
      }
      match /bests/{exerciseId} { allow read: if isSelf(uid); allow write: if false; }  // Function only
      match /awards/{awardId}   { allow read: if isSelf(uid); allow write: if false; }  // append-only ledger
      match /consents/{cid}     { allow get, list: if isSelf(uid); allow write: if false; }
      match /notifications/{n}  { allow get, list: if isSelf(uid);
                                  allow create, delete: if false; }
      match /notices/{nid}      { allow read: if isSelf(uid); allow write: if false; }
      match /firstWeek/{d}      { allow read: if isSelf(uid); allow write: if false; }
      match /eatPrefs/{d}       { allow read: if isSelf(uid); allow write: if false; }
      match /mealPlans/{w}      { allow read: if isSelf(uid); allow write: if false; }
      match /blocks/{b}         { allow read: if isSelf(uid); allow write: if false; }
      match /blockedBy/{b}      { allow read: if isSelf(uid); allow write: if false; }
      match /myReports/{r}      { allow read: if isSelf(uid); allow write: if false; }
    }
```

> **Assembly note, stated so it cannot be missed.** The `allow write: if false` lines above are
> **placeholders for each owner's validator block**, not the final posture. At deploy, each group's
> validated `create/update` conditions are pasted into its own `match` above, *unchanged*. They are safe
> to OR **because each is a different `match` path** — the OR hazard exists only where two blocks match
> the *same* path, which is why `users/{uid}` itself is the one composed block. A CI check asserts every
> subcollection listed here has exactly one owning validator and that no second `match` for
> `users/{uid}` exists anywhere in the deployed ruleset.

```js
    // ───────── C7 / rule 11, stated as a deliberate ABSENCE ─────────
    // There must be NO `match /{path=**}/bests/{id}` and NO
    // `match /{path=**}/measurements/{id}`. Without one, a collectionGroup query
    // across users is denied by default. A "deny" rule would be worse than
    // useless: rules are a permissive union, so an added deny cannot revoke the
    // owner's allow — only the absence works. Do not add one. (G6, item 8.)

    // ───────── server-authored ─────────
    match /plans/{uid}/{doc=**}          { allow read: if isSelf(uid); allow write: if false; }
    match /verificationJobs/{jobId}      { allow read, write: if false; }
    match /nidRegistry/{nidHash}         { allow read, write: if false; }
    match /reports/{reportId}            { allow read: if false; allow create: if signedIn(); }
    match /deletionRequests/{uid}        { allow get: if isSelf(uid); allow write: if false; }

    // ───────── immutable content ─────────
    // Readable pre-auth because C04 "look around first" has no account yet (G1).
    // Abuse control is App Check at the service level, which rules cannot express.
    // These are a fallback path: every journey reads the bundle (§4).
    match /exercises/{id} { allow read: if true; allow write: if false; }
    match /foods/{id}     { allow read: if true; allow write: if false; }
    match /recipes/{id}   { allow read: if true; allow write: if false; }
    match /programs/{id}  { allow read: if true; allow write: if false; }
    match /workouts/{id}  { allow read: if true; allow write: if false; }

    // Deny-by-default is structural: absence of an `allow` IS a denial, and rules are a
    // permissive union, so this clause grants nothing and denies nothing. It documents
    // intent and makes a reviewer who adds a broad rule above it think twice. The real
    // guarantee is the emulator suite.
    match /{document=**} { allow read, write: if false; }
  }
}
```

### 9.2 Storage

```js
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isSelf(uid) { return request.auth != null && request.auth.uid == uid; }

    // Rule 7, made structural: there is no legitimate ID or selfie object in this
    // bucket, so the paths an implementer would reach for are denied BY NAME as well
    // as by the default deny. A 1-day GCS lifecycle rule is the backstop if G1's
    // purge Function ever fails.
    match /verification/{p=**} { allow read, write: if false; }
    match /id/{p=**}           { allow read, write: if false; }
    match /selfie/{p=**}       { allow read, write: if false; }
    match /kyc/{p=**}          { allow read, write: if false; }

    // Rule 6: an unblurred image cannot be stored. The metadata flag is required at
    // the door and MediaUploadGateway is the only writer. The uid prefix is what makes
    // P0-DEL-01 provable — an object outside it cannot be enumerated (G7).
    match /user-media/{uid}/{p=**} {
      allow read:  if isSelf(uid);
      allow write: if isSelf(uid)
                   && request.resource.metadata.blurApplied == 'true'
                   && request.resource.size < 25 * 1024 * 1024;
    }
    match /user-exports/{uid}/{p=**} {
      allow read:  if isSelf(uid);
      allow write: if false;                 // Function-generated only
    }

    match /{allPaths=**} { allow read, write: if false; }
  }
}
```

**App Check** enforced on Firestore, Storage, Functions **and the Identity Platform phone endpoint** —
Play Integrity on Android, DeviceCheck/App Attest on iOS. The last one is the SMS-pumping defence that
protects §5's second-largest line, and G1's plan depends on it.

**Emulator tests shipped with the rules** (the last six are G6's required set): an unauthorised read of
another uid; a client write to `verification`; to `profile.activePlanVersion`; a `streak` key in every
collection; a `syncQueue` write; a malformed day/week id; a `plans/**` write; a second
`match /users/{uid}` block appearing in the deployed file; **a client write to `rewards` fails; to
`weeks/*` fails; to `bests/*` fails; to `awards/*` fails; a `measurements` write carrying `sharedWith`
fails; a write carrying `missedDays` fails; a collectionGroup query on `bests` or `measurements` fails.**

### 9.3 `firestore.indexes.json` — exemptions are part of the ruleset, not tuning

```jsonc
{
  "indexes": [],                    // none required on any P0 journey (spine §4)
  "fieldOverrides": [
    // C7 / rule 11. Firestore auto-indexes EVERY field, including members of an
    // embedded array, so `sets.actualWeight` is indexed by default and a
    // weight-ordered query would simply work. The exemption is what makes the
    // sort impossible; "we wrote no such query" is not an enforcement mechanism.
    { "collectionGroup": "sessions", "fieldPath": "sets",
      "indexes": [] },
    { "collectionGroup": "measurements", "fieldPath": "weightKg",
      "indexes": [] },
    { "collectionGroup": "measurements", "fieldPath": "waistCm",
      "indexes": [] }
  ]
}
```

**Checked at deploy, not assumed:** `firebase firestore:indexes` is diffed against this file in CI,
and a post-deploy assertion queries `sessions` ordered by `sets.actualWeight` and requires it to
**fail**. A rule 11 that depends on nobody writing the query is not enforcement; a missing index is.

---

## 10. Interface to the other groups

### I provide

| Surface | Contract |
|---|---|
| `AppTheme` / `AppText` / `AppRadius` / `AppMotion` | generated from `tokens.mjs`; `AppTypography.of(context)` returns the locale-correct `TextTheme` (§17) |
| `AppLocalizations` + `l10n` | 1,789 keys, en/ar parity guaranteed by test |
| `AppNumbers.format()` / `.ltr()` | Western digits in both locales, FSI/PDI isolation |
| `DirectionalIcon` | the 8-icon mirror list, applied automatically |
| `Repository.write(WriteIntent)` | the only write path: undo window, queue, idempotent ids, `schemaV`/stamps |
| `OfflineWriteQueue` + `pendingUndo` | the deferred-write primitive behind G3's `LogCommandBus` |
| `SyncStatusScope` / `SyncBadge` | the queued convention, including the `rejected` path |
| `DocIds` | deterministic ids (C1) |
| `AppClock.dayKey()` / `WeekClock.isoWeek()` | the two clocks (§6.4), IANA-backed |
| `SessionState` / `ConnectivityState` | streams + router guards, incl. the unverified-still-sees-training rule |
| `lowDataMode` flag | **three-way split, agreed:** G8 owns the flag and the metered-connection detection (`devices/{deviceId}.lowDataMode`), **G7's A03 hosts the toggle**, G4's `VideoPolicy` consumes it and applies it to the player. Nobody else owns the mode |
| `AnalyticsGateway.emit()` | the only emitter; enum-typed API (§16) |
| `ErrorPresenter.of(context)` | failure class → localised copy + retry; owns `P2-ERR-*` behaviour |
| `LibraryRepository` | bundled libraries + local FTS, zero Firestore reads |
| Platform channels | `HealthChannel`, `SmsRetrieverChannel`, `NudgeChannel`, `FaceBlurChannel`, `AppCheckChannel`, `BillingChannel` (§18) |
| `logMealFromNudge` callable | one idempotent Function keyed `{uid, date, slot}` — **resolves G3's Q8**; the lock-screen action needs a server endpoint because an iOS extension cannot safely touch the Firestore cache |
| Remote Config registry | §10.1 — one owner for every key |
| **The composed `users/{uid}` ruleset + `firestore.indexes.json`** | groups supply field-level requirements; I author the file |
| `onDeviceRegister` → `G1.requestReverification(uid,'new_device')` | function-to-function; G1 never reads `devices` |
| Deletion rows 8, 9, 27, 28 | `devices/**` recursive **+ FCM token invalidation**; `syncQueue` cleared via `clearPersistence()`; Amplitude deletion API; Crashlytics installation delete |
| `P0-DEL-01` split with G7 (agreed) | **G8 builds** the callable, the Function runtime and the local-wipe plumbing; **G7 owns** the manifest, the ordering guarantee, the state machine, the offline refusal and the on-screen claims. Neither half passes the test alone |

### 10.1 Remote Config key registry (consolidated, one owner each)

| Key | Owner | Purpose |
|---|---|---|
| `library_version`, `library_manifest_url` | G8 | content bundle stamp (§4) |
| `videoPolicy` | G4 | ABR caps, prefetch, autoplay |
| `tzdata_version` | G8 | IANA data without a store release |
| `verification_provider`, `pledge_version`, `min_age`, `c04_preview_manifest` | G1 | |
| `voiceCloudFallbackEnabled` | G5 | `false` at launch |
| `ramadan_window`, `protein_target_by_lifestage` | G5 | |
| `min_supported_build`, `kill_switches.*` | G8 | forced-update floor |

### I require

| From | What |
|---|---|
| **All groups** | conform to K1–K12; no direct Firestore access; every string through `l10n`; no `fontSize:`/`Color(` literals in presentation; `SyncBadge` for queued rows; supply rule *requirements*, not rule files; add every new collection to the deletion manifest in the same change |
| **G1** | the claim contract as published (`{verified, vexp, pledgeV, role, adult}`) + a `verificationChanged` FCM data message so I can force `getIdToken(refresh: true)`; `onAccountDelete(uid)`; the ban list applied in my gateway |
| **G2** | `plans/**` stays server-authored; `profile.language` is written **through `ProfileRepository.setLanguage`** — I own the locale *choice* (C02) and never write G2's field directly |
| **G3** | `LogCommandBus` keeps **deferred-write** semantics (not write-then-delete), which my queue provides and G5's cost model requires |
| **G4** | single-writer `deviceId` guard on `sessions`; download/ABR decisions only through `VideoPolicy` |
| **G5** | `arrayUnion`/`increment` for same-slot writes; `tz` recorded per meal document |
| **G6** | week arithmetic stays in `WeekRollup`/`TierPolicy`/`AwardTable`; any Monday push is **content-free** and the app computes the rollup on open |
| **G7** | the `AnalyticsProp` enum contents + the failing PDPL test (I own the gateway code); `MediaBlurPolicy.resolve()` as the default resolver; `MeasurementsRepository.purgeLocal()` called during deletion |
| **Translation pipeline** | ~12 new strings in `i18n/msa/` — the dictionary today has `Undo` and several "saved" strings but **no** offline/sync/error vocabulary: `sync.queued`, `sync.retrying`, `sync.failed`, `sync.retry`, `sync.pending_count`, `offline.banner`, `offline.verification_needs_network`, `error.server_generic`, `error.retry`, `lowdata.on`, `download.offline_ready`, `library.updating`. I must not invent Arabic and no widget may hardcode it |

---

## 11. Test IDs I am accountable for — 160

| Group | Count | IDs |
|---|---|---|
| `P2-RTL-*` | **59** | every in-scope screen: C01–C16, O01–O05, T01–T08, R01–R13, E01–E09, P01–P04, A01–A04 |
| `P2-TXT-*` | **59** | the same 59, OS text size at maximum |
| `P2-OFF-*` | **20** | A01, A02, A03, A04, C06, C07, C10, C11, E01–E04, O01, O05, P04, R07, R08, R09, T01, T02 |
| `P2-ERR-*` | **20** | the same 20 writing screens |
| `P0-A11Y-01` | 1 | Arabic RTL across every in-scope screen |
| `P0-LOG-09` | 1 | log offline, sync later, no duplicates, no loss |

Notes that change how three of these pass:

- **`P2-OFF-C10`/`C11`** — verification is *not* writable offline. Passing behaviour is the explicit
  offline message with retry and no partial upload treated as success, **not** a queued write.
- **`P2-OFF-O05`** — the plan publish is a queued *intent*; the screen must not claim a published plan.
- **`P0-LOG-09`** is jointly owned: G4's set half, G5's meal half, my queue and idempotency.

**How they run.** `P2-RTL-*`/`P2-TXT-*` as **golden tests** — 2 locales × 2 text scales × 59 screens =
**236 goldens** from one parameterised harness over the route table, so a new screen adds its goldens
automatically. `P2-OFF-*`/`P2-ERR-*` as widget tests against a fake Firestore with a controllable
transport. `P0-LOG-09` as an emulator integration test.

**Shared, mechanism mine:** P0-VER-02 (SMS Retriever **and** the assertion that `READ_SMS`/`RECEIVE_SMS`
never appears in the manifest — a manifest test I own), P0-VER-03 (iOS AutoFill), P0-VER-07 (offline
mid-check), P0-VER-08 (six-digit code — the ARB says four, §14-3), P0-DEL-01 (rows 8/9/27/28 + local
wipe), P0-NAV-01 (router/tap depth), P0-LOG-11 (the transform policy), P1-RULE-03 (no streak: rules +
lint), P1-RULE-06 (face-blur channel), P1-RULE-08 (the detection-vs-classification CI lint),
P1-RULE-11 (no ranking indexes).

**Three of G6's new reward cases rest entirely on my mechanisms**, so I carry the platform half of each:

| Case | The mechanism it actually tests |
|---|---|
| `P0-RWD-01` | award not granted twice by an offline **replay** — deterministic ids (K1) + "an increment never travels alone" (K5, corrected C4). This is the single test that proves my idempotency story; if it fails, `P0-LOG-09` is passing by luck |
| `P0-RWD-02` | the daily cap holds when several offline sessions sync **at once** — queue replay ordering plus the `no_rmw_counter` scoping that lets the cap compare server-side |
| `P0-RWD-03` | measurement undo with no dialog (`pendingUndo`, rule 9) **and** P04's privacy resting on the single-field index exemption (§9.3) — the one case that would fail silently if the exemption were dropped from `firestore.indexes.json` |

---

## 12. Scalability gate — self-check, stated explicitly

| Gate | Result | Evidence |
|---|---|---|
| Unbounded collection scan | **PASS** | every read is a doc get or a bounded range; `devices` ≤5; `syncQueue` local and self-purging; libraries never queried server-side; `users` has `allow list: if false`, and G4 caps its only `list` at `limit <= 50`. **A range read is billed per document**, so a "1 read" range is a scan in disguise — the P01 correction above is the worked example, and it is why the remaining ranges are fixed-size arrays on documents already in cache rather than queries |
| Per-user fan-out write growing with followers | **PASS** | G8 owns no social write. I **impose** on the future community group: fan-out-on-read (pull), never a write per follower, and G7's block mirror is bounded by *her own* block count, not by followers |
| Unindexed query on a hot path | **PASS** | zero composite indexes on any P0 journey; my only query is the ≤5-doc `devices` get |
| Needs a migration to reach 100k MAU | **PASS, with two named risks** | additive-only schema (K11), deterministic ids, per-user counters at ≤1 write/90 s (far inside the ~1 write/s/doc soft limit), so no sharding ever. **Risk 1 — closed, and my own proposal withdrawn.** The Monday close is lazy: the client invokes `closeStaleWeeks()` on app open when `weeklyGoal.lastClosedWeek < AppClock.isoWeek(tz)`, and the session/meal triggers run it inline on a stale watermark. I had additionally proposed a sweep bucketed by `hash(uid) % 60`; **G6 declined it and I withdraw it**, because a sweep must still *discover* whom to sweep — a query over 100k `users` documents every Monday, growing with registrations, which is this gate's first failure condition wearing a hat. Two further objections settle it: "Monday 00:00" is not one instant once `weeklyGoal.tz` is honoured, so it fans out into 24 waves; and at 35% DAU two-thirds of the writes are for women who will not open the app that day. The lazy close has no scan, no fan-out, no dead writes, and is the only version that works offline — which T04 requires, since "your 14 weeks are safe" must render on a microbus. **Risk 2:** G4's OQ-7 and G5's Q11 both want an array→map shape change (`sets` by index, `slots.<slot>` by `itemId`). Both are raised **now**, pre-launch, precisely so they are a decision and not a migration; if the owner defers them past launch they become one |

---

## 13. Toolchain reality, and what it does to §9's definition of done

Measured here, and it differs from the brief I was given — worth correcting:

| Component | Actual state |
|---|---|
| Flutter | **3.47.4** stable, Dart 3.13.3, at `~/development/flutter` — **not on `PATH`** (`flutter` is "command not found" in a fresh shell) |
| Android SDK | present, v36.0.0; **`cmdline-tools/latest` IS installed** (the brief said missing); platforms 35 + 36.1, build-tools 34 + 36 |
| **Java / JDK** | **absent entirely** — no system JDK, no Android Studio JBR. `flutter doctor`: "Could not determine java version" |
| Android emulator | **no AVDs defined** |
| Xcode | incomplete — only `/Library/Developer/CommandLineTools`; no `Xcode.app` |
| CocoaPods | not installed |
| Node (generators) | v25.9.0 ✓ |

`flutter analyze` and `flutter test` run, so the work that matters most here is achievable locally: all
156 of my test IDs as widget/golden tests, the rules suite on the emulator, and every domain-rule test.

Not achievable here, and not to be reported as done:

- **`flutter build apk`/`appbundle` cannot run at all** — no JDK means Gradle cannot start. A harder
  blocker than the missing `cmdline-tools` the brief flagged, and it also blocks `sdkmanager` licence
  acceptance.
- **No iOS build, no simulator, no CocoaPods** → every iOS channel (HealthKit, Vision, Notification
  Content Extension, StoreKit 2, App Attest) can be written but not compiled or run. Each ships with
  `// TODO(owner): unverified on device — no Xcode on this host`.
- **`P0-VER-03` and the whole iOS column of §18 are UNVERIFIED.** The iOS *fallbacks* are exactly what
  brief §4 says QA must test, so this is a real coverage hole, not a formality.
- No AVD means even a fixed JDK leaves Android integration tests without a device.

**Amended definition of done, honestly stated:** §9's "builds for both an Android emulator and an iOS
simulator" is satisfiable on **neither** target from this machine. The only place it can be met is CI —
a runner with a JDK for Android, and a macOS runner with Xcode + CocoaPods for iOS. I recommend that CI
job be part of G8's scope and stood up **before** Stage 3 declares done; until it exists, the correct
status for both store artifacts is "not attempted", not "passing". (Related owner-track blocker already
on the reconciliation list: the bundle identifier is still `com.example`, which both stores reject.)

---

## 14. Open questions — named, because silence is a defect

1. **`syncQueue` is a contradiction in the spine.** Declared "local-only; never uploaded" at a Firestore
   path. Resolution: logical path in local `sqflite` + a rules deny. Needs the spine owner's confirmation.
2. **Firestore region.** `europe-west1` (~70–90 ms to Cairo) vs `me-central1` (~30 ms) vs multi-region:
   doubles ops cost and changes latency on the core loop. Firestore/Functions availability in
   `me-central1` needs verifying. Owner decision.
3. **The SMS code is six digits; C06/C07 and the ARB say four.** Already the reconciliation's #1 owner
   decision, and it is mine to implement either way: change the copy (a dictionary change, then
   regenerate) or contract a custom gateway. `P0-VER-08` locks it afterwards. **Blocks the first screen
   a woman ever sees.**
4. **Amplitude at 100k MTU** ($1k–2.5k/month, ~25× infrastructure). Owner contract decision; I have not
   substituted a cheaper tool because the brief mandates Amplitude.
5. **Spine §6 bans check-in and cycle data from analytics**, so G3/G6 get no event-level funnel data on
   the product's core logging loop. Accept the blindness, or approve a server-side aggregate (counts
   only) computed inside the trust boundary?
6. **`devices.nudge.ignoredRun` vs C6.** Granted as a device concern (it counts ignored *notifications*,
   never training days, and is never displayed), but it is consecutive-shaped and C6 is absolute. G3
   asked for a spine ruling; I am the collection owner and cannot grant myself the exemption.
7. **Stale `verified` claim offline.** G1's `vexp` is checked inside the rule, so an *expiry* cannot be
   outlived — but a moderation revocation still has up to 1 h of claim lag, and offline it is unbounded.
   My default is to honour the cached claim (refusing would lock out every offline user). Security
   sign-off needed.
8. **MVP bottom-nav composition.** The mockup's nav includes Community and Coaching, both out of the cut,
   and the ARB already carries their labels. My assumption: Home, Train, Eat, Progress, Profile. G3 +
   owner must confirm — it is the one piece of chrome on 59 screens.
9. **`app_en.arb` contains an Arabic string.** `"الفصحى — كل شيء في التطبيق"` is in the English
   dictionary (it is the single entry with no Latin characters, so it slugs to the key `blank`), meaning
   an English screen renders Arabic. Needs a source fix in `i18n/`, which is not mine to edit.
10. **ARB key stability.** Keys are derived from the English source text, so a copy edit renames the key
    and orphans the translation; and the 19 `_n` keys (`train_2`, `done_2`, `today_2`, …) are ordered by
    dictionary insertion, so reordering `i18n/msa/*.json` can silently reassign them and break
    referencing Dart. Proposed fix: an append-only `i18n/key-lock.json` (source → stable key) with the
    generator reusing locked keys and reporting a changed source as *stale translation*. Changes the
    generator contract, so it needs sign-off — and it interacts with #3, because fixing the four/six-digit
    copy is exactly the kind of edit that would churn keys today.
11. **MSA second-person-feminine correctness is not machine-checkable.** Who is the Arabic reviewer, and
    is there budget for a professional pass over 1,789 strings? A lint cannot catch a masculine verb form.
12. **Array vs map shapes (G4 OQ-7, G5 Q11).** Both groups want `sets` and `slots.<slot>` keyed by id so
    merges are exact instead of convergent-at-read. As the offline-contract owner I support both, and
    they must be decided **before launch** or they become the migration the gate forbids.
13. **Timezone data size — resolved toward the full database.** I had proposed trimming to a single
    zone to save ~500 KB. **G6 objected and is right:** a Cairo-only dataset misfiles the evening
    sessions of the Gulf diaspora, which is a market rather than an edge case, and `AppClock.isoWeek(tz)`
    takes a zone precisely so it is never assumed. Ship the full IANA database with the Remote Config
    version stamp. What remains for the owner is only the ~500 KB binary-size acceptance.
14. **iOS meal-nudge latency.** A Content Extension cannot reliably write Firestore, so iOS either uses
    my `logMealFromNudge` callable (needs signal) or defers to an App Group inbox drained on next launch.
    T03's promise is that the app stays closed, so if the callable is declined the screen copy must change.
    Product sign-off.
15. **Face blur with zero faces detected.** If blur is on and the detector finds no face, my gateway
    blocks the upload and offers manual region blur or an explicit per-image opt-out (which rule 6
    permits). Confirm, rather than silently uploading an unblurred image.
16. **CI runners.** Neither store artifact can be built on this machine (§13). Who provisions them?
17. **`users/{uid}.privacy` / `.notify` — RESOLVED while this plan was being written.** G7's Q19 noted I
    had no recorded basis for admitting its validators into the ruleset I author. The spine's collection
    layout now carries both maps under G7, so the basis exists and the validators stand. One residual
    tidiness point for the spine owner: the §2 **ownership table** row still reads "G1 (create), G2
    (profile), G6 (rewards, weeklyGoal)" and does not yet list G7.
18. **`P2-OFF/ERR-A01` and `P2-OFF/ERR-A04` — RESOLVED while this plan was being written.** G7 and I
    independently reported that A01 (notification inbox) and A04 (Safety Centre) both write yet had no
    offline or server-error coverage. The suite has since added all four; the writing-screen set is now
    20 and my P2 tier is 158, so my accountable total moved 156 → **160**. Recorded because the queued
    *report* state on A04 is arguably the most misleading state in the product to have left untested.
19. **Who owns the iOS Notification Content Extension build configuration** (G7's Q13) — a separate
    target, an App Group and its own provisioning profile, none of which the Android action button
    needs. My assumption: G8, as part of the platform channel. If it lands nowhere, §4's parity row
    silently ships on Android only.
20. **Video URL policy — resolved in G4's favour, recorded for the CDN contract.** Public
    content-addressed immutable URLs for the library; signed URLs only for user-generated media. The
    one thing that would reopen it is OQ-8 (is the video library free, or behind a subscription?) —
    if gating is coming, it must be said **before** the CDN contract is signed, because token auth on
    a path prefix costs edge-cache efficiency and that is what funds the $0 egress line.

---

## 15. Generation, not retyping — and how "no hardcoded strings" is enforced

Generators live in `tool/gen/` (Node; the sources are `.mjs`), each emitting `*.g.dart` with a
`// GENERATED … do not edit by hand` header. Part of the build, not a one-off:

| Target | From |
|---|---|
| `lib/theme/app_tokens.g.dart` | `src/tokens.mjs` |
| `lib/l10n/app_en.arb`, `app_ar.arb` | `i18n/ar.json` (+ the proposed `key-lock.json`) |
| `lib/router/app_routes.g.dart` | `src/inventory.mjs`, filtered to the 59-screen cut |
| `lib/theme/directional_icons.g.dart` | the `RTL_CSS` mirror list |
| `assets/library/v{N}/*.json` + manifest | content pipeline |
| `docs/tracking-plan.json` | the Dart event registry (reverse direction) |

**CI gate `verify-generated`:** re-run every generator, then `git diff --exit-code`. A hand-edited or
stale generated file fails the build. That is *why* these cannot drift from the mockup — the ARB pair is
in sync today (1,789/1,789), and this gate is what keeps it so.

**No hardcoded English or Arabic — three layers, none a convention:**

1. **Custom lint `no_raw_user_text`** (`custom_lint`): flags a `StringLiteral` in `Text`, `Text.rich`,
   `TextSpan.text`, `SelectableText`, `Semantics.label/hint`, `SnackBar.content`, `Tooltip.message`,
   `AppBar.title`, `InputDecoration.label/hint/error` and dialog titles. Run as `dart run custom_lint`
   in CI so it **fails the build** rather than decorating an IDE.
2. **Backstop `tool/i18n_guard.dart`** (`package:analyzer` AST over `lib/**`): catches what the widget
   list misses — any literal containing an Arabic codepoint (U+0600–U+06FF), or two or more Latin words,
   anywhere outside `lib/l10n/`. Exit non-zero.
3. **`arb_parity_test.dart`**: identical key sets, identical placeholders per key, no empty values, and
   no `en == ar` except an explicit 14-entry allowlist of legitimately identical strings.

Companion lints: no `fontSize:` literal and no `Color(0x…)` literal in `lib/**/presentation/**`.

---

## 16. Analytics — a legal boundary

Tracking plan written **before** any event is emitted, generated to `docs/tracking-plan.json` from the
registry so plan and code cannot diverge.

**Ownership, resolving G7's Q9:** G7 owns the **permitted set** (`AnalyticsProp` enum contents) and the
failing PDPL test; **G8 owns the gateway, the transport and the choke-point test.** An unowned allowlist
grows by accident, which is the failure spine §6 exists to prevent.

**Identity:** Amplitude receives the random `analyticsId` from `devices/{deviceId}` — never the uid,
never the phone number. Cost of that choice, stated: cross-device identity is lost and MTU counts
inflate slightly. Correct under PDPL.

**The structural control (G7's design, adopted verbatim because it is stronger than a string allowlist):**
`AnalyticsEvent` accepts `Map<AnalyticsProp, AnalyticsValue>`. **There is no `Map<String, dynamic>`
overload anywhere in the API**, so a property that is not an enum member **does not compile**. The enum
*is* the allowlist. Values are `bool`, bucketed `int`, or a declared enum — **no free-text strings at
all**, which is what makes leakage structurally impossible: a phone number, a name, a food name or a
transcript is free text, and free text cannot be sent.

**Permitted (23 keys):** `screen_id`, `flow`, `outcome` (ok/blocked/error/cancelled), `step_index`,
`source`, `slot`, `offline_queued`, `connection`, `locale`, `dir`, `text_scale_bucket`, `platform`,
`os_version`, `app_version`, `build_number`, `duration_bucket`, `error_class`, `retry_count`,
`library_version`, `undo_used`, `fallback_used`, `capability`, `install_id`.

**Two changes agreed with G7, which owns this column:**

- **`notif_permission_state` — granted** (closes G7's Q9). A closed enum with no personal content;
  without it A01's permission funnel, including "denied forever", is unmeasurable.
- **`setting_key` — removed.** G7 dropped it deliberately and is right to: per-switch telemetry on a
  privacy screen is adjacent to sensitive state, because knowing *which* switch she changed edges
  toward cycle-sharing and coach-sharing posture. A03 emits `screen_id` + `outcome` only.

**Never sent, at any time** (spine §6, plus G1's and G5's ban lists): phone number · name · **ID
verification result or status** (so no `is_verified` property exists) · `providerRef` · `nidHash` ·
weight · any measurement · any photo/media reference or storage path · any check-in, cycle or symptom
datum · any food name, kcal, protein, allergen or transcript · national ID · date of birth · email ·
location · uid.

**How a test proves it:**

| Test | Asserts |
|---|---|
| `analytics_enum_golden_test.dart` | the enum's exact member list — adding a property is a reviewed change, not a commit |
| `analytics_no_freetext_test.dart` | no event schema declares a plain `String` property |
| `analytics_pdpl_test.dart` (G7's) | events constructed carrying every forbidden value serialise to a payload containing none of them |
| `analytics_chokepoint_test.dart` | no `amplitude` import outside `lib/analytics/`; `AnalyticsGateway` is the sole caller of the transport |
| `tracking_plan_sync_test.dart` | regenerating the plan from the registry yields no diff, so the DPO reviews a document that provably matches the code |

Runtime: unknown key → debug `assert` throws; release drops the key, still sends the event, and reports
`AnalyticsSchemaViolation` to Crashlytics.

---

## 17. i18n, RTL and theming — the specification

**Locale-aware type.** Arabic renders **+2 pt with +4 pt leading**, applied by
`AppTypography.of(context)`, generated into `app_tokens.g.dart` — never per screen:

| Style | en (size/leading) | ar (size/leading) |
|---|---|---|
| display | 32 / 40 | 34 / 44 |
| headline | 26 / 33 | 28 / 37 |
| titleL | 20 / 26 | 22 / 30 |
| titleM | 17 / 23 | 19 / 27 |
| titleS | 15 / 20 | 17 / 24 |
| body | 16 / 24 | 18 / 28 |
| bodyM | 15 / 22 | 17 / 26 |
| label | 15 / 20 | 17 / 24 |
| nav | 12 / 16 | 14 / 20 |

**Direction.** `supportedLocales: [en, ar]`, `Directionality` from the locale. The 8 mirrored icons go
through `DirectionalIcon`, generated from `RTL_CSS` — Flutter's `Icon` does **not** auto-mirror, so a raw
`Icon(Icons.arrow_back)` in an RTL layout is a defect the goldens catch.

**Numbers stay Western — the trap worth naming.** `intl` with locale `ar` emits Arabic-Indic digits
(٠١٢٣) **by default**, which would violate the handoff on every screen and every one of the 14
identical-by-design strings (`+20`, `84%`, `12 × 10`, `0:12 / 1:00`). So `AppNumbers.format()` always
formats with the `latn` numbering system, and isolated numeric spans are wrapped in U+2068 FSI … U+2069
PDI (or `Directionality(ltr)` when standalone). Dates get the same treatment: Arabic month names, Western
digits. Enforced by a lint banning `NumberFormat(`/`DateFormat(` outside `lib/l10n/`, plus a test
asserting no rendered Arabic screen contains U+0660–U+0669.

**Large text (`P2-TXT-*`).** Body content is **never** clamped and every screen scrolls; `maxLines` is
banned on body copy. Only dense chrome — nav labels, chips, badges — clamps, via `DenseText` at
`textScaler.clamp(maxScaleFactor: 1.3)`, because a 2.0-scaled nav label fits no phone. Touch targets stay
≥48 dp (`MaterialTapTargetSize.padded`), satisfying the ≥44 pt the test asks for.

**Routing.** `go_router`; **57 `GoRoute`s for 59 in-scope screens** — per HANDOFF rules 16/17, **T06 and
E09 are empty-state branches inside `/today/t01` and `/eat/e01`**, chosen when the underlying collection
is empty, with no route and no navigation to them. A `ShellRoute` carries the tab bar; `redirect` maps
`SessionState` (§6.2) to a destination, and must keep training/recipes open while verification is pending.
`routes_mvp_test.dart` asserts the route set is exactly the expected 57 names and that **no** route
resolves to `t06` or `e09` — the rule is enforced by a test, not a comment.

**Error handling.** `ErrorPresenter` maps a coarse failure class to localised copy plus a retry, and owns
the distinction `P2-ERR-*` depends on: a server error says "our fault, try again", while an offline write
says nothing beyond the queued badge, because it is not a failure.

---

## 18. §4's platform-capability table, owned end to end

Every capability gets a channel, both sides, and a **designed** fallback. QA tests the fallback.

| Capability | Channel + interface | Android | iOS | Fallback (what QA tests) |
|---|---|---|---|---|
| Step/workout detection | `HealthChannel`: `requestPermissions()`, `readSteps(day)`, `readWorkouts(range)`, `writeWorkout(session)` — **channel mine, domain mapping G4's** | Health Connect (`androidx.health.connect`), `StepsRecord` + `ExerciseSessionRecord` | HealthKit `HKQuantityTypeIdentifierStepCount` + `HKWorkoutType`, `HKObserverQuery` | **Read-only on both sides at MVP** (G4 OQ-11); Android 9–13 needs the Health Connect app installed and Play requires a declaration form. Absent or refused → no step surface at all (never a zero that reads as failure); credit comes from T02's manual time chip, present on both platforms. A detected activity is **always a proposal with one confirming tap**, never a silent log. The channel exposes `writeWorkout()`; **G4 chooses not to call it at MVP**, so the write-back parity gap is a recorded decision rather than an oversight |
| SMS code autofill | `SmsRetrieverChannel.listen() → Stream<String>` | SMS Retriever API — **no `READ_SMS`**; the SMS body must carry the 11-char app hash, and there is a **different hash per signing key** (debug, upload, Play App Signing), so all three go in the template or autofill fails in production only | empty stream; `TextField(autofillHints:[AutofillHints.oneTimeCode])` | iOS never asks for SMS read permission (`P0-VER-03`). `P0-VER-02` additionally asserts `READ_SMS`/`RECEIVE_SMS` never appear in the manifest — a manifest test, not a manual check. Manual entry always available. **Digit count is blocked on §14-3** |
| Meal-nudge notification action | `NudgeChannel.schedule()`, `.actions → Stream<NudgeAction>`; `logMealFromNudge` callable | notification action button; a background isolate writes Firestore directly | `UNNotificationCategory` action + Notification Content Extension | An extension cannot safely touch the Firestore cache, so iOS calls the idempotent callable (keyed `{uid,date,slot}`) or, offline, writes to a shared **App Group** inbox drained by `SyncQueueDrainer.drainPlatformInbox()` on next launch. Android logs immediately; iOS may lag. §14-14 |
| On-device face blur | `FaceBlurChannel.blur(bytes, radius) → BlurResult{bytes, facesFound, applied}` | ML Kit face detection, bundled model — **detection only, no classification API exposed** | Vision `VNDetectFaceRectanglesRequest` | `facesFound == 0` with blur on → `MediaUploadGateway` **blocks** the upload and offers manual region blur or an explicit per-image opt-out. Interface built now (rule 6 and `P1-RULE-06` exist); implementation activates with community |
| Video download + ABR cap | `VideoDownloadChannel`, driven by G4's `VideoPolicy` | WorkManager + progressive-MP4 HTTP; ExoPlayer `maxVideoHeight` | `URLSession` background config; `preferredMaximumResolution` + `preferredPeakBitRate` | **Progressive MP4, not offline HLS**, on both platforms deliberately — offline HLS needs two divergent native stacks, and this is the decision that keeps download-for-offline shippable. One policy decides; the channels only obey. URLs are **public and immutable**, not signed: a signature that expires makes a file she already downloaded unplayable (§2-11) |
| App integrity | `AppCheckChannel` | Play Integrity | DeviceCheck / App Attest | Unavailable (rooted, old OS) → degraded mode: reads allowed, phone auth rate-limited harder. Protects §5's SMS line and G1's `C06` |
| Store billing | `BillingChannel` — interface only, not implemented in the cut | Play Billing | StoreKit 2 | Payments (H04) are out of the cut; Egypt rails (Fawry, wallets) are off-store, which raises an Apple digital-vs-physical-service question for the owner track |
