# G7 — Profile, privacy & safety

Screens: **A01** Notifications · **A02** Profile and settings · **A03** Privacy · **A04** Safety Centre.

Fixed inputs obeyed verbatim: `SCHEMA-SPINE.md` §1 paths, §2 ownership, §3 constraints C1–C8, §5 offline
contract, §6 analytics ban. Costs are against `BUILD-BRIEF.md` §3 — 35,000 DAU, ~8 reads / ~6 writes per
active day, 40% of traffic 19:00–23:00 Cairo.

**Reconciled against all seven sibling plans** (G1–G6, G8) and `RECONCILIATION.md`, in three passes as
they landed. That reconciliation changed this plan materially: nine paths added to the deletion manifest
(§7.3), G1's `onAccountDelete(uid)` hook adopted, G6's on-device photo store brought in scope, §6
reframed as **requirements to G8** now that G8 authors the single `users/{uid}` ruleset, §5.1 aligned to
G8's actual analytics gateway, two new G7 obligations accepted from G8, and three open questions resolved.
Every path claimed by another plan is now enumerated; the manifest closes clean.

**Peak arithmetic used throughout:** 280k reads/day → 112k in 4h → **7.8 reads/s**; 210k writes/day →
84k in 4h → **5.8 writes/s** aggregate. Firestore's aggregate ceiling is not the risk at this scale;
**per-document write rate is** (~1 sustained write/s/doc). Every G7 document is written at most a few
times a day by exactly one woman, so no G7 document is a hotspot.

---

## 1. Data model

### 1.1 Extensions to `users/{uid}` (two new maps, G7-owned)

Placed on the root user document on purpose: `T01` already reads it (spine §4), so A02/A03/A04 read the
settings for **0 incremental reads**. A separate `settings` document would add a read per screen.

| Path | Field | Type | Default | Notes |
|---|---|---|---|---|
| `users/{uid}.privacy` | `profileVisible` | bool | **false** until C16 pledge, then true | A03 row 1 |
| | `showBests` | bool | true | numbers only; never scale weight (C7, rule 11) |
| | `blurFacesDefault` | bool | **true** | rule 6 / HANDOFF 8 |
| | `shareLogsWithCoach` | bool | **false** | HANDOFF 6 — independent, default OFF |
| | `policyVersion` | int | current | which privacy text she agreed to |
| | `updatedAt` | timestamp | server | |
| `users/{uid}.notify` | `push` | bool | false | her switch, not the OS state |
| | `mealNudge` | bool | true | the one-a-day nudge |
| | `quietStart` / `quietEnd` | int (minutes 0–1439) | 1320 / 480 | A02 copy: "quiet 10pm–8am" |
| | `kinds` | map<string,bool> | all true | `coachReply`, `groupMilestone`, `reaction`, `weekClosed`, `verification` |
| | `usualMealHour` | int 0–23 | null | **computed on-device** from the locally cached `meals/*` — costs zero reads |
| | *(no nudge-outcome field — removed)* | — | — | **Removed after the spine's C3 correction.** A 3-element array here is clobbered when two of her devices both answer the same nudge. The last three outcomes are read from the `notifications` docs of kind `mealNudge`, which already carry `outcome` under a deterministic id |

**Two conventions G8 imposes on every write to this document** (its `requiredMeta()` rule): each write
must carry `schemaV` as an int and set `updatedAt == request.time`. Both `privacy` and `notify` writes
therefore go through a repository that stamps them; a raw `set` on a map will be rejected at the door.
G8's `noStreak()` rule also rejects any key named `streak`, `dayStreak`, `consecutiveDays` or
`missedDays`; G7 stores no field of any of those shapes, so the design passes it structurally rather
than by inspection.

> **C6 compliance, deliberately.** A01's promise "ignore three and they stop by themselves" is naturally a
> consecutive-ignored counter, and C6 forbids a daily-consecutive counter *anywhere*. So nothing counts:
> the scheduler reads the **last three `notifications` docs of kind `mealNudge`** and suppresses when all
> three have `outcome == 'ignored'`. Those documents already exist, are keyed deterministically per day
> and slot, and are TTL-bounded at 30 days. No counter, no run, no array to clobber, and nothing a screen
> could render as a streak even by mistake. Q1 asks the spine owner to ratify the *intent*, since
> enforcement is now structural.

### 1.2 New G7-owned collections

| Path | ID scheme | Writer | Fields |
|---|---|---|---|
| `users/{uid}/notifications/{notifId}` | deterministic per event, e.g. `week-2026-W38-closed`, `nudge-2026-09-18-breakfast` | **Function** (create), client (update `read`,`readAt`,`outcome` only) | `kind`, `title`Key, `bodyKey`, `args` map, `deepLink` (screen ID), `createdAt`, `read` bool, `readAt`, `outcome`, `expiresAt` |
| `users/{uid}/blocks/{blockedUid}` | **= blocked uid** (C1 idempotent) | client (offline-writable) | `createdAt`, `source` ∈ `post\|profile\|message\|safety_centre` |
| `users/{uid}/blockedBy/{blockerUid}` | = blocker uid | **Function mirror only**; **not client-readable at all** | `createdAt` |
| `users/{uid}/myReports/{reportId}` | = report id | **Function mirror only** | `subjectKind`, `reason`, `createdAt`, `reporterState`, `firstResponseMins`, `closedAt` |
| `reports/{reportId}` | random (server-resolvable) | client **create only**, moderators via Admin SDK | `reporterUid`, `subjectUid`, `subjectKind`, `subjectRef`, `reason`, `note` (≤1000), `state`, `createdAt` (must equal `request.time`), `slaDueAt`, `firstResponseAt`, `triagedBy`, `outcome`, `closedAt`, `locale`, `appVersion` |
| `deletionRequests/{uid}` | **= uid** | **Function only**; client `get` for progress | `state`, `requestedAt`, `steps` map (per-path done flags), `attempts`, `lastError`, `authDeletedAt`, `completedAt` |

`expiresAt` carries a **Firestore TTL policy of 30 days** on `notifications` — this is what keeps the
inbox bounded without a cleanup job, and it is why A01 can never become an unbounded scan.

### 1.3 Storage layout G7 depends on (not currently in the spine — Q4)

| Prefix | Owner | Deletion |
|---|---|---|
| `user-media/{uid}/**` | community / coach media / G6 | deleted by prefix on account deletion |
| `user-exports/{uid}/**` | G7 | deleted by prefix; objects also expire after 24h |
| `verification/{jobId}/**` | G1, no client access | deleted at decision (rule 7), never reachable by deletion because it is already gone |

**The rule G7 publishes to every group:** *any* user-generated object must live under a
`{uid}`-prefixed path. A single object stored outside a uid prefix makes P0-DEL-01 unprovable, because
there is no way to enumerate it.

### 1.4 Indexes

| Query | Index | Where |
|---|---|---|
| `notifications` order by `createdAt` desc, limit 15 | **single-field, automatic** | client hot-ish path |
| `blocks` order by `createdAt` desc, limit 50 | **single-field, automatic** | A04 |
| `myReports` order by `createdAt` desc, limit 20 | **single-field, automatic** | A04 |
| `reports` where `state == 'submitted'` order by `slaDueAt` asc | **composite (state ASC, slaDueAt ASC)** | **moderation console + SLA sweeper only — never the app** |

**Composite indexes on a client hot path: none.** The one composite exists for the back office, which is
exactly the exemption spine §4 allows. Per C7, no index exists anywhere on weight, weight lost or
follower count, so A03's "show my bests" cannot be turned into a ranking even by a later developer.

### 1.5 Read/write pattern per screen

| Screen | Reads | Writes | Pattern |
|---|---|---|---|
| A01 | `notifications` limit 15, **cache-first then server**; `users/{uid}` already cached | mark-read (1 update), nudge outcome (1 update) | no snapshot listener, no polling |
| A02 | `users/{uid}` (cached from T01 → 0 incremental) | pref writes route to the owning group's repository | export/delete are **callables**, not writes |
| A03 | `users/{uid}` (0 incremental) + `users/{uid}.verification.imagesDeletedAt` (same doc) | 1 field-path merge per toggle | `update` on `privacy.<key>` only |
| A04 | `users/{uid}` (0) + `blocks` limit 50 + `myReports` limit 20 | block = 1 create; report = 1 create (online only) | typical real docs: 0–3 blocks, 0–1 reports |

**Two rows G8 requires my screens to host**, accepted: **A02** carries the single app-level *"N changes
waiting"* sync chip (G8 is explicit that this exists on A02 **only** — never a per-screen counter), and
**A03** carries the **low-data mode** switch, backed by G8's `devices/{deviceId}.lowDataMode`. Low-data
mode is a §3 launch requirement for Egypt, so A03 gains a row that is G7-rendered and G8-owned: G7 must
not write that field directly.

---

## 2. Query cost per screen at §3 numbers

| Screen | Opens / active day | Reads per open (realistic / worst) | Reads / active day | Writes / active day |
|---|---|---|---|---|
| A01 Notifications | 0.20 | 4 / 15 | **0.8 / 3.0** | 0.2 mark-read + ≤1 nudge outcome |
| A02 Profile & settings | 0.15 | 0 / 1 | **0.0 / 0.15** | ~0.02 |
| A03 Privacy | 0.03 | 0 / 1 | **0.0 / 0.03** | ~0.01 |
| A04 Safety Centre | 0.01 | 2 / 5 | **0.02 / 0.05** | ~0.001 block, ~0.0005 report |
| **G7 total** | | | **≈0.8 reads (worst 3.2)** | **≈0.7 writes** |

Against the 8-read / 6-write allowance, and against the spine's measured ~7-read typical day, G7 fits in
the slack: **≈0.8 reads and ≈0.7 writes per active day.**

**The honest warning.** A01 is the only screen in this group that can break the budget. At 15 docs a page,
if A01 became a once-a-day habit it would spend 15 of the 8-read allowance **by itself**. Three things
prevent that and all three are requirements, not optimisations: page size capped at 15, TTL of 30 days,
and **no snapshot listener** (a live listener on a notification inbox re-reads on every server-side write
and is the standard way this goes wrong). A01 reads cache-first and only hits the server on explicit
pull-to-refresh or cold open.

**Peak share.** G7 contributes ≈0.8 × 35,000 = 28k reads/day → 11.2k in the 4-hour peak → **0.8 reads/s**,
and ≈0.7 writes/s. Roughly 10% of the peak envelope, spread across 35,000 distinct documents.

**Monthly cost of G7** (Firestore list prices $0.06/100k reads, $0.18/100k writes, $0.02/100k deletes —
verify at contract time): 840k reads ≈ $0.50, 735k writes ≈ $1.32, deletion/export Functions ≈ $0.20.
**G7 ≈ $2 / month at 100k MAU.** The §3 budget pressure in this product is the ~11 TB/month of video, not
privacy; G7 is rounding error and should never be optimised at the cost of the guarantees below.

---

## 3. State machines

### 3.1 Notification permission (A01, §4 platform row)

Owner: `NotificationPermissionController.transition(event)`. Permission is a **device** fact, so it lives
in `users/{uid}/devices/{deviceId}` (G8's collection — field requested, §7), never in the user doc.

| State | Android | iOS | What A01 shows | What the app does |
|---|---|---|---|---|
| `notDetermined` | pre-33 auto-granted → `granted` | `.notDetermined` | one row: "Turn on the daily nudge" | **never prompts at launch** — prompts after her first log |
| `prompting` | system dialog | system dialog | disabled row | transient only |
| `granted` | `POST_NOTIFICATIONS` granted | `.authorized` | switches active | register FCM token to `devices/{deviceId}` |
| `provisional` | *n/a* | `.provisional` | "quiet delivery on" + one-tap keep | iOS-only; designed fallback is that it behaves as granted, delivered quietly |
| `deniedSoft` | denied once, rationale still available | *n/a* | "Not now. You can turn it on any time." | may ask **once** more, at a moment of value |
| `deniedTerminal` | denied twice / `shouldShowRequestPermissionRationale == false` | `.denied` | row deep-links to **OS settings** | **never prompts again**; T01 shows the in-app nudge card instead |
| `revokedInSettings` | detected `onResume` | detected on `applicationDidBecomeActive` | same as terminal | invalidate token, stop scheduling, keep her `notify` prefs intact |
| `unavailable` | no Play services / token failure | token failure | "Reminders are not available on this phone" | in-app nudge only; **no silent failure** |

Transitions: `notDetermined→prompting→{granted, deniedSoft}`; `deniedSoft→prompting` (once only);
`{deniedSoft,prompting}→deniedTerminal`; `granted→revokedInSettings`; `revokedInSettings→granted` (via
settings, re-detected on resume); any→`unavailable`. **"Denied forever" is a first-class state**, and its
designed fallback — the in-app card on T01 — is a deliverable, not a note (§4: QA tests the fallback).

**The meal-nudge action, both platforms (§4).** Android: a notification **action button** ("Log it") →
broadcast receiver → headless invocation of G5's `LogUsualMeal` use-case. iOS: `UNNotificationAction`
(non-foreground) plus a **Notification Content Extension** for the richer body; the extension cannot
safely drive the Firestore SDK with offline persistence, so it writes the intent into the shared **App
Group** container and the app drains it on next launch, with the in-notification confirmation shown
immediately. Both paths call the same use-case and both are **idempotent** by C1/C3: the meal document
is `meals/{yyyy-MM-dd}` and the write is a merge into `slots.<slot>`, so a double-tap or a replayed
action cannot double-log. One-a-day and quiet hours are enforced **server-side** in
`scheduleMealNudges` — a client-side cap is unenforceable once the process is killed.

### 3.2 Report lifecycle (A04)

Owner: `ReportService.file()` / `ReportProjection.forReporter()`.

| State | Set by | Reporter sees (A04) | Note |
|---|---|---|---|
| `queuedLocal` | client, offline | **"Not sent yet — the hour starts when it sends."** | the one state that must never look successful |
| `submitted` | client create; `createdAt == request.time` | "Sent · a moderator is reading it" | **SLA clock starts here**, server-stamped, unforgeable |
| `triaged` | moderator | "A moderator has it" | `firstResponseAt` written |
| `actioned` | moderator | "Action taken" | may trigger G1 re-verification of the subject |
| `dismissed` | moderator | "Reviewed — no action" | never blames the reporter |
| `escalated` | moderator | "With the safety lead" | |
| `closed` | moderator/Function | "Resolved in 40 minutes" | `closedAt`; feeds A04's stated time |

`slaBreached` is a **boolean flag, not a state** — otherwise every state doubles. The sweeper Function
queries the one composite index (`state`,`slaDueAt`) and pages the on-call moderator; it cannot make
anyone answer.

**Blocking is a separate, two-state, offline-capable relationship** (`BlockService.block/unblock`) and is
deliberately *not* part of this machine: blocking is the protection she gets instantly, reporting is the
slower one. A04 must say so in those terms.

### 3.3 Account deletion (A02) — `AccountDeletionService`

| State | Who | Client shows | Guarantee |
|---|---|---|---|
| `idle` | — | the ordinary settings row | |
| `confirming` | client | what will be deleted, what is kept and why, typed confirmation | the one allowed confirmation dialog (§5 below) |
| `requested` | **callable `requestAccountDeletion`** | "Deleting your account" | **callable fails offline**, so success cannot be faked |
| `authLocked` | Function | client is signed out; local cache cleared | refresh tokens revoked + Auth user disabled **first** |
| `purgingFirestore` | Function | progress, resumable | recursive delete per manifest §7.3 |
| `purgingStorage` | Function | progress | prefix delete |
| `purgingGroupHooks` | Function | progress | **calls G1's published `onAccountDelete(uid)` hook** and asserts its completion — G1 closes `nidRegistry`, purges `consents` and `verificationJobs`. G7 does not reach into G1's collections itself |
| `purgingThirdParty` | Function | progress | Amplitude deletion request, Crashlytics, FCM tokens |
| `authDeleted` | Function | — | Auth record deleted **last** |
| `done` | Function | "Your account is gone." | `deletionRequests/{uid}` retains only state + timestamps |
| `failedRetryable` | Function | "Still finishing — we will complete this" | never reports success |
| `reconciling` | scheduled sweeper | — | re-runs any request not `done` after 15 min |

**Order matters and is the guarantee.** Auth is locked before any data is touched (so nothing can be
written back mid-purge) and the Auth record is deleted last (so the request is always attributable and
resumable). **Firestore does not cascade-delete subcollections**, so every path is deleted by explicit
enumeration against the manifest in §7.3, using the Admin SDK's recursive delete per parent path — there
is no "delete the user document and hope". The `steps` map records each path as done, which is what makes
a retry idempotent rather than destructive.

**The client-side half that is easy to miss:** on `authLocked` the app must sign out, then `terminate()`
and `clearPersistence()` the Firestore instance. Without that, the woman's data is still readable from the
unbounded offline cache on that handset and P0-DEL-01 fails on-device while passing on the server. It must
**also** call G6's `MeasurementsRepository.purgeLocal()` and destroy the photo store's Keychain/Keystore
key (manifest rows 33–34) — those progress photos have no server copy, so a server-only purge leaves the
most intimate data in the product sitting on the phone.

**The honest limit on P0-DEL-01, stated rather than discovered.** Rows 33–34 can only run on **the handset
executing the deletion**. If she deletes her account from a second phone, the first phone's encrypted photo
store survives until that installation next launches, notices the account is gone, and self-wipes. The
server-side guarantee is complete; the on-device guarantee is eventual, and A02's copy must not claim
otherwise. Q17.

---

## 4. Offline behaviour

| Action | Offline? | Conflict resolution | UI while queued |
|---|---|---|---|
| Privacy toggle (A03) | **yes** | field-path merge on `privacy.<key>`; last-write-wins per key (spine §5, single-owner scalar) | the row shows its new position with a "saved on this phone" chip; **never a spinner** |
| Notification prefs (A01/A02) | **yes** | same, per key | as above |
| Permission state | **yes** | OS fact, no network needed | immediate |
| Mark notification read | **yes** | LWW on `read` | immediate |
| Nudge outcome | **yes** | written to that nudge's **own** `notifications` doc (deterministic id), so two devices answering the same nudge converge on one document instead of clobbering a shared array — the C3 correction applied to my own collection | immediate |
| Block someone (A04) | **yes** | deterministic doc id = blocked uid → replay-safe (C1) | **takes effect locally at once** (the local feed filter reads local `blocks`); server mirror + rule enforcement on sync |
| Unblock | **yes** | delete by same id | immediate |
| **File a report (A04)** | **queued, explicitly not sent** | server sets `createdAt`; no local clock | **"Not sent yet. It will send when you have signal, and the hour starts then."** A queued report must never render as "a moderator is reading it" |
| **Download my data** | **no** | — | "You need a connection for this." |
| **Delete my account** | **no — hard requirement** | — | callable returns `unavailable`; UI says "You need a connection to delete your account", offers retry. **No optimistic state, no local tombstone, no progress bar that is not backed by a server ack** |

**The one place the offline contract and a product rule genuinely collide** (Q2): HANDOFF rule 6 says
revoking a sharing switch "immediately revokes the coach's derived panels". Offline, the revocation exists
only on her handset; the server cannot deny a read it has not heard about. G7's position: the switch flips
locally at once, the coach-facing read is denied by security rules **as soon as the revocation syncs**, and
A03's copy must say "applies everywhere as soon as you have signal" rather than "immediately". Overstating
this is exactly the kind of false promise this group exists to prevent.

---

## 5. §2 rules G7 owns, and where each is enforced

Domain layer only. No rule below is enforced in a widget; every one has a named class and method.

| Rule | Owned as | Class · method | Enforcement mechanism |
|---|---|---|---|
| **6** Face blur defaults on, applied on-device before upload | **default + control** (the blur itself is the media group's) | `MediaBlurPolicy.resolve(perImage, settings)` | returns `perImage ?? settings.blurFacesDefault`; the stored default is `true` and there is **no code path that reads a null default as false**. Flipping A03's switch off opens a sheet stating the consequence and is recorded with `policyVersion` |
| **7** ID and selfie deleted, only the result kept | **the honest claim on A03** (deletion is G1's) | `VerificationClaim.imagesDeletedStatement(record)` | returns a **sealed state derived from `verification.imagesDeletedAt`**, never a hardcoded sentence. If that field is null, A03 renders "deletion pending" — the screen cannot claim a deletion that has not happened |
| **8** No AI face-gender classification | negative assertion in my layer | — | G7 ships no image classification and no copy implying a face check; A03/A04 wording states the gate is the ID number |
| **9** Undo, not confirmation | the **exception boundary** | `PrivacySettingsService.setSwitch` (no dialog, re-toggle is the undo) | toggles are not logging and raise no dialog; **account deletion and block may confirm** — P1-RULE-09 explicitly exempts destructive non-logging actions. Stated here so QA does not read A02's confirmation as a violation |
| **11** Nothing ranked by weight, weight lost or followers | the **projection** | `PublicProfileProjection.build(user)` | builds from an allowlisted field set that **structurally cannot contain** weight or measurements; backed by C7 (no such index exists) |
| **3 / C6** No streak, no daily-consecutive counter | my schema holds none | `NudgeOutcomeLog.record(outcome)` | bounded 3-element array, never rendered; A01–A04 render no consecutive-day figure |
| **17 / 16** Empty state is the onboarding; first-run is a state not a route | A01's empty state | `NotificationsInboxState.empty` | a branch inside A01, not a route: says what will appear, why it is empty, offers one action (turn on the daily nudge) |
| **PDPL** analytics minimisation (spine §6) | the **privacy requirements on the allowlist** (the gateway, registry and tests are G8's) | `AnalyticsGateway.track(AnalyticsEvent)` | see §5.1 |

### 5.1 The analytics allowlist — an allowlist, not a denylist

**Reconciled with G8, which owns the implementation.** G8's plan §15 independently arrived at the same
choke-point design and went further in the one way that matters most: **no event property may be a
free-text string at all** — every property is a `bool`, a bucketed `int`, or a declared enum. That is a
stronger guarantee than key-filtering, because a phone number, a name, a moderation note or a symptom is
free text, and text that cannot be sent cannot leak. G7 adopts G8's design as the implementation
(`AnalyticsGateway.track()`, the event registry, `docs/tracking-plan.json`, and its five tests including
`analytics_banned_keys_test.dart` and `analytics_no_freetext_test.dart`) and contributes the privacy
requirements below rather than a second mechanism.

**Two corrections to G7's first draft, made against G8's actual 23-key allowlist:**

| G7 had proposed | Resolution |
|---|---|
| `setting_key` (a privacy-settings enum) | **Dropped by G7, deliberately.** It is absent from G8's allowlist, and per-switch telemetry on a privacy screen is both unnecessary and adjacent to sensitive state — knowing *which* switch she changed edges toward cycle-sharing and coach-sharing posture. A03 emits `screen_id` + `outcome` only |
| `notif_permission_state` | **Raised as a request to G8.** Not in the 23 keys, but it is a closed enum with no personal content, and without it the A01 permission funnel (including "denied forever") is unmeasurable. Q9 |

The four enforcement layers below describe the shape of the guarantee; G8's code and tests are the
authority for it:

1. **No free text, at all.** Every property is a `bool`, a bucketed `int`, or a declared enum — G8's
   event registry admits no plain `String` property, proven by `analytics_no_freetext_test.dart`. This is
   the layer that actually holds, because the forbidden values in the table below are *all* free text.
2. **The registry is the allowlist.** A key absent from the declared set is denied by default and never
   reaches the transport; `analytics_allowlist_test.dart` asserts every registered event's keys are in
   the allowlist and every value type is `bool`/`int`/enum.
3. **One choke point.** `AnalyticsGateway.track()` is the only emitter and the Amplitude SDK is imported
   in exactly one file, asserted by `analytics_chokepoint_test.dart`. On an unknown key: debug asserts,
   release drops the key and reports `AnalyticsSchemaViolation` to Crashlytics.
4. **Banned keys are tested by name.** `analytics_banned_keys_test.dart` attempts `track()` with each of
   ~40 banned keys and asserts none reaches the fake transport, and `tracking_plan_sync_test.dart` proves
   the document the owner and DPO review matches the code. G7's contribution is the *contents* of the
   banned list — every item in the right-hand column below — not a second mechanism.

| Permitted keys (from G8's allowlist) | Forbidden, per spine §6 — G7 owns this column |
|---|---|
| From G8's 23 keys, the ones G7's screens use: `screen_id`, `flow`, `outcome`, `locale`, `dir`, `platform`, `app_version`, `connection`, `offline_queued`, `duration_bucket`, `error_class`, `text_scale_bucket`. Requested addition: `notif_permission_state` | phone number · name · **verification result or status** (so no `is_verified` property exists) · weight · any measurement · any photo, media reference or storage path · any check-in, cycle or symptom datum · national ID · date of birth · email · location · **uid** (G8 sends a random per-install `analyticsId` from `devices/{deviceId}` instead) |

The user identifier sent to Amplitude is a **random internal id**, never the uid and never the phone
number, matching the runbook's instruction that this be written down as a rule so it survives staff
changes.

---

## 6. Security rules (Firestore rules syntax, spine paths)

**Composition — superseded, and this section is now split in two.** G2 found that per-group rules cannot
work (Firestore ORs `allow` across blocks, so one permissive block defeats every sibling denial,
including C5's guard on `verification`). `RECONCILIATION.md` resolved it: **`users/{uid}` is authored
once, by G8, and groups supply requirements rather than rules.** So:

- **`match /users/{uid}` and its subcollections below are a requirements statement handed to G8**, not a
  file G7 deploys. G8's authored version already has the C5 denial (`!touched().hasAny(['verification'])`),
  `noStreak()` and `requiredMeta()`; what it does **not** yet have is key-level validation of the
  `privacy` and `notify` maps, or any of my four subcollections. `validPrivacy()`, `validNotify()` and
  the `notifications` / `blocks` / `blockedBy` / `myReports` blocks are what G7 asks G8 to merge in
  verbatim.
- **`reports/**` and `deletionRequests/**` are top-level and remain G7's own**, deployed by G7.

Where a rule needs to know whether she is verified it **copies G1's published helpers** (`isVerified()`,
`pledgeAccepted()`, `canEnterCommunity()`, `isAdult()`) verbatim — G1 mints those from custom claims at
**zero reads** and forbids re-implementing them with `get()`. G7 adds no verification gate of its own.

```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn()      { return request.auth != null; }
    function isSelf(uid)     { return signedIn() && request.auth.uid == uid; }
    function changedKeys()   { return request.resource.data.diff(resource.data).affectedKeys(); }
    function serverStamped(f){ return request.resource.data[f] == request.time; }

    // True when `other` has blocked the caller. Costs ONE billed document read per
    // evaluation, which is why it guards documents, never list queries (see note below).
    function notBlockedBy(other) {
      return !exists(/databases/$(database)/documents/users/$(other)/blocks/$(request.auth.uid));
    }

    // ---------- users/{uid} : G7 owns only .privacy and .notify ----------
    function validPrivacy() {
      return !changedKeys().hasAny(['privacy'].toSet()) || (
        request.resource.data.privacy.keys().hasOnly(
          ['profileVisible','showBests','blurFacesDefault','shareLogsWithCoach',
           'policyVersion','updatedAt'])
        && request.resource.data.privacy.profileVisible      is bool
        && request.resource.data.privacy.showBests           is bool
        && request.resource.data.privacy.blurFacesDefault    is bool
        && request.resource.data.privacy.shareLogsWithCoach  is bool
      );
    }

    function validNotify() {
      return !changedKeys().hasAny(['notify'].toSet()) || (
        request.resource.data.notify.keys().hasOnly(
          ['push','mealNudge','quietStart','quietEnd','kinds','usualMealHour'])
        && request.resource.data.notify.push       is bool
        && request.resource.data.notify.mealNudge  is bool
        && request.resource.data.notify.quietStart is int
        && request.resource.data.notify.quietStart >= 0
        && request.resource.data.notify.quietStart <= 1439
        && request.resource.data.notify.quietEnd   is int
        && request.resource.data.notify.quietEnd   >= 0
        && request.resource.data.notify.quietEnd   <= 1439
        // C6: there is no outcome counter and no outcome array to validate —
        // suppression is derived from the notifications subcollection.
      );
    }

    // The G7 fragment. G8 composes the final rule as:
    //   allow update: if g1CanUpdate() || g2CanUpdate() || g6CanUpdate() || g7CanUpdate();
    function g7CanUpdate(uid) {
      return isSelf(uid)
        && changedKeys().hasOnly(['privacy','notify'].toSet())   // G7's slice, nothing else
        && !changedKeys().hasAny(['verification'].toSet())       // C5, belt and braces
        && validPrivacy() && validNotify();
    }

    match /users/{uid} {
      allow get, list: if isSelf(uid);
      allow update:    if g7CanUpdate(uid);   // OR-composed with the other groups' fragments
      allow create:    if false;              // G1's to grant
      allow delete:    if false;              // deletion is Function-only, never a client delete

      // ---------- C5: verification is server-write-only, restated at the leaf ----------
      // No client may write users/{uid}.verification under any composition of fragments.

      // ---------- A01 inbox ----------
      match /notifications/{notifId} {
        allow get, list: if isSelf(uid);
        allow create, delete: if false;                       // Function only (+ 30-day TTL)
        allow update: if isSelf(uid)
          && changedKeys().hasOnly(['read','readAt','outcome'].toSet())
          && (!changedKeys().hasAny(['outcome'].toSet())
              || request.resource.data.outcome in ['logged','ignored','dismissed']);
      }

      // ---------- A04 blocking ----------
      match /blocks/{blockedUid} {
        allow get, list: if isSelf(uid);
        allow create, update: if isSelf(uid)
          && blockedUid != uid                                 // she cannot block herself
          && request.resource.data.keys().hasOnly(['createdAt','source'])
          && request.resource.data.source in ['post','profile','message','safety_centre']
          && serverStamped('createdAt');
        allow delete: if isSelf(uid);                          // unblock
      }

      // Mirror consulted by the rules engine and Functions only.
      // Deliberately NOT readable by the woman herself: nobody learns who blocked them.
      match /blockedBy/{blockerUid} {
        allow read, write: if false;
      }

      // ---------- A04 "Reports you made" ----------
      match /myReports/{reportId} {
        allow get, list: if isSelf(uid);
        allow write: if false;                                 // Function mirror
      }
    }

    // ---------- A04 reporting ----------
    match /reports/{reportId} {
      allow get, list: if false;              // she reads the mirror; the queue is never client-readable
      allow create: if signedIn()
        && request.resource.data.reporterUid == request.auth.uid
        && request.resource.data.subjectUid  != request.auth.uid
        && request.resource.data.state == 'submitted'
        && serverStamped('createdAt')         // the one-hour clock cannot be forged
        && request.resource.data.note.size() <= 1000
        && request.resource.data.reason in
             ['harassment','man_account','nudity','spam','impersonation','self_harm','other']
        && request.resource.data.keys().hasOnly(
             ['reporterUid','subjectUid','subjectKind','subjectRef','reason','note',
              'state','createdAt','locale','appVersion']);
      allow update, delete: if false;         // moderators act through the Admin SDK
    }

    // ---------- A02 deletion ----------
    match /deletionRequests/{uid} {
      allow get: if isSelf(uid);              // she may watch her own progress
      allow list: if false;
      allow write: if false;                  // callable + Function only; a client cannot fake `done`
    }

    // ---------- Read-only content libraries (spine §1) ----------
    match /exercises/{id} { allow read: if signedIn(); allow write: if false; }
    match /foods/{id}     { allow read: if signedIn(); allow write: if false; }
    match /recipes/{id}   { allow read: if signedIn(); allow write: if false; }
    match /programs/{id}  { allow read: if signedIn(); allow write: if false; }

    match /verificationJobs/{jobId} { allow read, write: if false; }   // spine: no client access
  }
}
```

```
service firebase.storage {
  match /b/{bucket}/o {
    match /user-media/{uid}/{allPaths=**} {
      allow read:  if request.auth != null && request.auth.uid == uid;   // others via signed CDN URLs
      allow write: if request.auth != null && request.auth.uid == uid
                   && request.resource.size < 12 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*|video/.*');
    }
    match /user-exports/{uid}/{allPaths=**} {
      allow read:  if request.auth != null && request.auth.uid == uid;
      allow write: if false;                                             // Function only
    }
    match /verification/{allPaths=**} { allow read, write: if false; }   // provider + Function only
  }
}
```

### 6.1 What a blocked woman can and cannot read

| She can | She cannot |
|---|---|
| Her own `users/{uid}/**` in full — logs, meals, sessions, measurements, bests | The blocker's profile document, posts, media or messages (post-MVP community paths must call `notBlockedBy(authorUid)`) |
| All four read-only libraries (`exercises`, `foods`, `recipes`, `programs`) | Learn that she has been blocked: `blockedBy` is `read: if false` for everyone including its owner, and a blocked read returns the ordinary "not available" state, never "you are blocked" |
| File her own reports (create-only) | Read `reports/**`, or anyone else's `myReports` |
| Her own `deletionRequests/{uid}` | Any other woman's deletion state |

**Scalability caveat stated plainly:** `notBlockedBy()` costs one billed document read per rule
evaluation, so it is correct for guarding an individual document and **wrong for a feed**. When community
lands (post-MVP), feed exclusion must be denormalised server-side at fan-out/read time, not evaluated per
document in rules. Designing the feed around `exists()` in rules is how a rules bill becomes the largest
line item.

---

## 7. Interface to the other groups

### 7.1 What G7 consumes

| From | Path / field | Use |
|---|---|---|
| G1 | `users/{uid}.verification.{status, method, decidedAt}` | A02 "Verified woman" badge, A04 "every member is verified" |
| **G1 — confirmed, contract agreed** | `users/{uid}.verification.imagesDeletedAt` (timestamp, Function-written) | **A03's rule-7 claim is derived from this field.** G1's plan §1 already defines it as "rule 7's evidence field — null is an alarm, not a state", and `PurgeReconciler.sweep()` pages on any job decided over an hour ago with a null value. A03 therefore renders a fact, not a promise: null ⇒ "deletion pending", never the deletion claim |
| G2 | `users/{uid}.profile.{firstName, language, goal, days}` | A02's header name and setting rows; **G7 renders, G2 writes**. `firstName` was added to the spine after G1's planning and is typed by her, never lifted off the ID |
| G6 | `users/{uid}.rewards.{level, tier}` | A02 header "Regular · level 7" |
| G6 | `users/{uid}/bests/*` | A03's `showBests` switch governs the projection of these, never their storage |
| G8 | `users/{uid}/devices/{deviceId}` — `pushToken`, `platform`, `locale`, `tz`, `analyticsId`, `lowDataMode` | A01's delivery, A03's low-data row, server-side notification language |
| **G8 — fields still requested** | `devices/{deviceId}.{notifPermission, notifPermissionUpdatedAt}` | **G8's published `devices` schema does not include them.** The §3.1 state machine is per-device and `devices` is G8's collection, so G7 requests rather than adds. Without them, "denied forever" is unknown to the server and the scheduler will keep queueing nudges for handsets that can never show one |
| G8 | `NudgeChannel.schedule(...)` / `NudgeChannel.actions` and `SyncQueueDrainer.drainPlatformInbox()` | G8 owns the platform channel for the meal-nudge action on both OSes; G7 consumes it rather than writing its own (§3.1) |
| G8 | `SyncBadge`, and the app-level "N changes waiting" chip on A02 | G8 mandates one shared queued-state widget; G7's offline rows in §4 use it |
| G3/G5 | locally cached `checkins/*`, `meals/*` | on-device computation of `notify.usualMealHour` only — **read from cache, zero server reads, never uploaded** |

**Writes G7 does not make, by ownership.** A02 hosts the language row, the cycle row and the coach row,
but the writes go through the owning group's repository (`ProfileRepository.setLanguage` for
`profile.language`, the cycle group for `Y12`, the coaching group for `G04`). G7 owns the screen, not the
field — two groups writing one field is a rejected plan.

### 7.2 What G7 publishes

| Published | Consumers | Contract |
|---|---|---|
| `users/{uid}.privacy.blurFacesDefault` | community / coach media / follow-ups | the upload path must call `MediaBlurPolicy.resolve()`; it may not read the flag directly |
| `users/{uid}.privacy.shareLogsWithCoach` | coaching (post-MVP) | independent, default OFF; revocation removes derived panels — the coach's read is denied by rules once synced |
| `users/{uid}.privacy.{profileVisible, showBests}` | community, progress | consumed **only** through `PublicProfileProjection.build()` |
| `users/{uid}/blocks/*` + `blockedBy/*` mirror | community feed, messaging | both directions available; feed must denormalise, not use rules `exists()` |
| `notifications/{notifId}` write contract | every group that raises an event | deterministic id, `bodyKey` + `args` (localised at render, never a stored sentence), `expiresAt` mandatory |
| The **banned-key list** and the PDPL requirements behind it (§5.1) | G8 | G8 owns the gateway, the event registry and all five allowlist tests; G7 publishes what may never be sent and reviews additions. Outstanding G7 request: add `notif_permission_state` (Q9) |
| **The uid-prefixed Storage rule** | every group storing media | any object outside `user-media/{uid}/**` makes P0-DEL-01 unprovable |
| `reports` → G1 re-verification | G1 | an upheld report is a re-verification trigger (research §5); the write to `verification` stays **Function-only** (C5) |

### 7.3 Deletion manifest — every group's collections

Deletion touches everything. Firestore does not cascade, so this table *is* the implementation, and the
test asserts the emptiness of every row by path.

**The numbers are enumeration keys, not an execution order** — execution order is the state machine in
§3.3 (Auth locked first, Auth deleted last).

Rows 10–14 and 23 were **added after reading the G1, G3 and G5 plans**, and rows 32–34 after **G4 and
G6** landed — all of which declared paths that do not appear in the spine. That is the failure mode this
manifest exists to survive, and it has now happened twice in one sitting. The lesson is row (e) below:
this must be a build-breaking check, because a human reconciling plans by eye missed it on the first pass.

| # | Path | Owner | Method |
|---|---|---|---|
| 1 | `users/{uid}` (incl. maps `profile`, `verification`, `rewards`, `weeklyGoal`, `privacy`, `notify`) | G1/G2/G6/G7 | recursive delete of the document and every subcollection |
| 2 | `users/{uid}/weeks/**` | G6 | recursive |
| 3 | `users/{uid}/checkins/**` | G3 | recursive |
| 4 | `users/{uid}/sessions/**` (sets are embedded — C2, so no deeper level) | G4 | recursive |
| 5 | `users/{uid}/meals/**` | G5 | recursive |
| 6 | `users/{uid}/bests/**` | G6 | recursive |
| 7 | `users/{uid}/measurements/**` | G6 | recursive |
| 8 | `users/{uid}/devices/**` | G8 | recursive **+ FCM token invalidation** |
| 9 | `users/{uid}/syncQueue/**` | G8 | local-only; cleared by `clearPersistence()` on the handset |
| **10** | `users/{uid}/consents/{purpose}_{version}` | **G1** | performed by G1's `onAccountDelete(uid)` hook; G7 calls it and asserts completion (row 26) |
| **11** | `users/{uid}/notices/{kind}-{yyyy-Www}` | **G3** | recursive |
| **12** | `users/{uid}/firstWeek/arc` | **G3** | recursive |
| **13** | `users/{uid}/eatPrefs/current` | **G5** | recursive |
| **14** | `users/{uid}/mealPlans/{week}` | **G5** | recursive |
| 15 | `users/{uid}/notifications/**` | G7 | recursive |
| 16 | `users/{uid}/blocks/**` | G7 | recursive, **after** row 17 has read it |
| 17 | `users/{other}/blockedBy/{uid}` for every `other` in her `blocks` | G7 | reverse cleanup, bounded by her own block count (not by followers) |
| 18 | `users/{uid}/blockedBy/**` | G7 | recursive |
| 19 | `users/{uid}/myReports/**` | G7 | recursive |
| 20 | `plans/{uid}/versions/**` | G2 | recursive |
| 21 | `plans/{uid}/assignments/**` | G2 | recursive |
| 22 | `verificationJobs` where `uid == {uid}` | G1 | via G1's hook (row 26); images are already gone (rule 7) |
| **23** | `nidRegistry/{nidHash}` | **G1** | **not deleted — closed.** G1's proposal: keep the hash with `state:'closed'`, `uid:null`, so a removed woman cannot re-register while no personal data stays linked. Same legal sign-off as Q5 |
| 24 | Storage `user-media/{uid}/**` | media groups | prefix delete |
| 25 | Storage `user-exports/{uid}/**` | G7 | prefix delete |
| **26** | **G1's `onAccountDelete(uid)` hook** | G1, **called by G7** | G1 publishes it for exactly this purpose and states G7 must call it; covers rows 10, 22, 23 |
| 27 | Amplitude | G8 | user deletion request via the deletion API |
| 28 | Crashlytics | G8 | delete the installation's records |
| 29 | Firebase Auth | G1 | revoke tokens + disable **first**; delete the record **last** |
| 30 | **`reports/**` where `reporterUid == uid` or `subjectUid == uid`** | G7 | **not deleted — pseudonymised.** `reporterUid`/`subjectUid` replaced with a salted token; the safety record survives. A02's copy must say this plainly. Legal sign-off needed — Q5 |
| 31 | `deletionRequests/{uid}` | G7 | retained, reduced to state + timestamps, as the proof of erasure |
| **32** | `users/{uid}/awards/{awardId}` | **G6** | recursive. This is G6's append-only points ledger (rules deny update/delete; TTL on `expiresAt`), so only an admin delete can clear it |
| **33** | **The encrypted on-device progress-photo store** (P04) | **G6, wiped by G7** | `MeasurementsRepository.purgeLocal()` — G6 publishes this call for exactly this reason: the photos are local-only, with **no Storage object and no Firestore reference**, so *no server-side delete can reach them*. See the handset caveat below |
| **34** | The photo store's key in **Keychain / Android Keystore** | G6, destroyed by G7 | destroyed in the same step as row 33; wiping ciphertext while leaving the key is not deletion |
| **35** | `users/{uid}/cycle/**` | **G9** | recursive. Her cycle setup and sharing switches |
| **36** | `users/{uid}/periods/**` | **G9** | recursive. Every period date she recorded |
| **37** | `users/{uid}/splits/**` | **G4/G14** | recursive. Splits she authored herself (D7, `ownerKind: 'self'`). A coach's own splits live under `coaches/{coachUid}/splits` and are not hers to delete |

**Fourth pass — and it did not close clean. Rows 35–37 were added by the machine, not by a reader.**
The paragraph below claimed completeness after a third human pass. It was wrong: `users/{uid}/cycle`,
`users/{uid}/periods` and `users/{uid}/splits` were all declared in the deployed rules and enumerated
nowhere here, so account deletion would have left **her cycle data** — the most sensitive in the product
— sitting on the server behind a screen promising her it was gone. Nothing caught it in three passes by
eye; check (e), the moment it became a test, caught all three on its first run.

That is the argument for (e) restated as fact rather than as prediction. Read the paragraph below as a
record of how confident the third pass felt, not as a status.

**Third pass, and the manifest now closes clean.** All seven sibling plans have been read: G8 declares
**no new user subcollection beyond `devices` and `syncQueue`** (rows 8–9) and no new top-level collection,
G4 declares no new user subcollection and keeps **no per-user Storage objects** (its video library is
content-addressed in R2 with no uid in the path), and G6 contributed rows 32–34. Every path any plan
claims is enumerated here.

**Residual risk, named:** this held only because one agent re-read six plans by eye, and it missed rows on
the first pass. Nothing about that repeats itself for free. Check (e) must therefore **break the build**:
any `users/{uid}/*` subcollection, top-level collection or Storage prefix that appears in the codebase
without a manifest row fails CI. Post-MVP community, coaching and coach-media groups have not been
planned at all, and they are the ones that will hold the photos.

**How completeness is verified, not asserted.** (a) The manifest is a single machine-readable list; the
deletion Function iterates it rather than naming paths inline, so a new collection added without a
manifest entry is a visible omission. (b) An integration test seeds a user with at least one document in
every row 1–19 plus one Storage object, runs the callable, and asserts each path is empty and the Auth
record is gone. (c) The same test then signs up again **with the same phone number** and asserts a
different uid and an empty dataset — which holds because the Auth record was deleted, so phone re-auth
mints a fresh uid. (d) A scheduled reconciler fails loudly on any `deletionRequests` document not `done`
after 15 minutes. (e) A CI check fails if a group adds a `users/{uid}/*` subcollection to the spine
without a manifest row.

---

## 8. Test IDs G7 is accountable for

**Primary owner**

| ID | Why it is mine |
|---|---|
| **P0-DEL-01** | Account and data deletion actually deletes — §3.3 + §7.3. **Shared with G8**, which also claims it for "deletion Function + local wipe". The split: **G8 builds** the callable, the Function runtime and the local-wipe plumbing; **G7 owns** the manifest, the ordering guarantee, the state machine, the offline refusal and the on-screen claims. Neither half passes the test alone |
| **P0-NAV-01** | A01–A04 reachability (see the caveat below) |
| **P0-A11Y-01** | Arabic RTL on A01–A04 |
| **P1-RULE-03** | No streak on A01–A04, and no consecutive-day counter in the G7 schema (C6) |
| **P1-RULE-11** | A03's bests projection cannot carry weight; no ranking index exists (C7) |

**Co-owner — I own the surface and the claim; another group owns the mechanism**

| ID | My half | Their half |
|---|---|---|
| **P1-RULE-06** | A03 stores and defaults `blurFacesDefault = true`; `MediaBlurPolicy.resolve()` | on-device blur before upload (community / coach media) |
| **P1-RULE-07** | A03's statement is derived from `verification.imagesDeletedAt`, never hardcoded | G1 deletes the images and writes that field |
| **P1-RULE-09** | toggles raise no dialog; the delete/block confirmations are the documented exemption | logging screens' 5-second undo |
| **P1-RULE-08** | A03/A04 copy names the ID-digit gate, never a face check | G1's implementation |

**P2 in my group:** P2-RTL-A01, P2-TXT-A01, P2-RTL-A02, P2-TXT-A02, P2-RTL-A03, P2-TXT-A03, P2-RTL-A04,
P2-TXT-A04, P2-OFF-A02, P2-ERR-A02, P2-OFF-A03, P2-ERR-A03.

**Gap in the suite I am reporting rather than quietly covering (Q14):** the CSV has offline and
server-error cases for A02 and A03 only. **A01 writes** (mark-read, prefs, nudge outcome) and **A04
writes** (block, report) and neither has a `P2-OFF-*` or `P2-ERR-*` row. Per the README's own rule —
offline and error coverage for *every screen that writes* — `P2-OFF-A01`, `P2-ERR-A01`, `P2-OFF-A04` and
`P2-ERR-A04` are missing. A04's is the one that matters: the queued-report state in §4 is the single most
misleading thing this group could ship, and nothing in the suite currently tests it.

**Reachability caveat for P0-NAV-01.** The measured UX review puts **A03 at depth 3** (T01→A01→A02→A03)
and **A04 at depth 3** (T01→A01→A02→A04). Both exceed the ≤2-tap target and both count against the 80%
threshold. G7 does not propose new navigation to fix this (rule 16 forbids turning states into routes and
the fix is not mine to make unilaterally) — it is named here so the number is a decision rather than a
regression. A02 itself is depth 2 and A01 depth 1.

---

## 9. Scalability gate — self-check

| Gate | Result | Evidence |
|---|---|---|
| **Unbounded collection scan** | **PASS** | Every query is bounded: `notifications` limit 15 **and** a 30-day TTL; `blocks` limit 50; `myReports` limit 20. The only unbounded iteration is the deletion Function's recursive delete, which is a one-off batch job over a single woman's data, not a client query. The moderation sweeper is bounded by `state == 'submitted'` on an index |
| **Per-user fan-out write that grows with followers** | **PASS** | G7 contains no follower fan-out at all. The block mirror is **exactly one** extra write regardless of audience. `notifications` are written per recipient by the event's own owner (a week closing writes one doc to one woman). Nothing in G7 writes N documents for N followers |
| **Unindexed query on a hot path** | **PASS** | A01/A04 use single-field automatic indexes only. The single composite (`reports`: state, slaDueAt) serves the moderation console and the SLA sweeper, never the app — which is the exemption spine §4 allows |
| **Migration needed to reach 100k MAU** | **PASS** | No counter needs sharding (every G7 document is written a few times a day by one woman, orders of magnitude below the ~1 write/s/doc ceiling). No document grows without bound: G7 stores no array or counter on the user document at all, and the one collection that accumulates (`notifications`) is capped by a 30-day TTL and a 15-doc page. Deterministic IDs mean no key redistribution. TTL is a policy, not a migration. The one item to watch is `reports` as a top-level collection, at an expected tens-to-hundreds of writes a day — three orders of magnitude inside limits |

**Budget:** G7 costs ≈ **$2/month at 100k MAU** (§2). It does not approach any stated ceiling and it is
not where this product's money goes.

---

## 10. Open questions

Named, because silence is a defect.

| # | Question | Blocked on | Consequence if unresolved |
|---|---|---|---|
| **Q1** | Does deriving "three ignored" from the last three `mealNudge` notification documents satisfy **C6**, or does *any* consecutive-ignored logic breach the rule's intent? No counter, run or array now exists, so enforcement is structural and this is purely a question of **intent** | spine owner | either ratify the derivation or drop A01's "ignore three and they stop" promise |
| **Q19** | **The ownership table has no row for `users/{uid}.privacy` or `.notify`.** Both are G7 maps on a document the spine assigns to G1, and §2 says a group requests rather than adds. The spine's own `firstName` precedent shows these additions get recorded in the file | spine owner | until the row exists, G7 is writing two maps the ownership table does not grant it — and G8, which now authors the one ruleset, has no recorded basis for admitting my validators |
| **Q18** | `RECONCILIATION.md` §4.2 nominates **A02** as the possible capture surface for allergies and dietary preferences, which nothing in the MVP cut collects and Eat's fail-closed guard depends on. A02 is my screen | owner, with G2 | if A02 is chosen, G7 hosts the row and **G2 writes the field** (`profile.allergies`, `profile.dietary`) — G7 must not write it. Until then allergies are *unknown*, not empty, and the guard interrupts women who have no allergy |
| **Q2** | HANDOFF rule 6 says revocation is **immediate**. Offline it cannot be. Is "applies everywhere as soon as you have signal" acceptable wording? | owner + the rule's author | A03 either overstates a guarantee or states a latency |
| **Q3** | May `blurFacesDefault` ever be **globally off**? Rule 6 says blur defaults on and HANDOFF 8 says turning it off is an explicit **per-image** action — which reads as *no global off switch*, yet A03 renders one as a toggle | owner | if no global off is allowed, A03's row becomes a statement plus a per-image explanation, not a switch |
| **Q4** | **Narrowed after reading G1.** G1's Storage rules already default-deny the whole bucket with "G5/G7 open their own prefixes", and G5 confirms it writes nothing to Storage — so G7's `user-media/{uid}/**` and `user-exports/{uid}/**` prefixes compose cleanly today. G4 confirms the video library lives in R2 behind a CDN with **no per-user objects**, and that "user media (community photos, voice notes) stays on Firebase Storage". What remains open is whether those **media-owning groups** (community, coach media, follow-ups, voice notes — all post-MVP) will honour the uid prefix | spine amendment + the media groups | any object stored outside a `{uid}` prefix makes P0-DEL-01 unprovable, because it cannot be enumerated |
| **Q5** | **Reports by or about a deleted account**: erase, or retain pseudonymised as a safety record? PDPL erasure vs legitimate interest. **This is the same question as G1's open question 6** (`nidRegistry` retention after deletion) and both propose the same answer — keep a pseudonymous token, drop the uid link. Send the lawyer **one** question, not two | Egyptian lawyer | §7.3 rows 23 and 30 are currently "pseudonymise"; if erasure is required, the safety record and the re-registration block are both lost |
| **Q6** | **A04 contradicts itself**: "a woman moderator reads it within an hour" alongside "talk to a human, 9am–9pm". One hour for 24 hours a day, or only in staffed hours? | owner (§10 blocker) | as written, a 02:00 report breaks the on-screen promise. The runbook already says change the number rather than break it — **code cannot keep this promise; only rostered people can** |
| **Q7** | **Minimum age, 16 or 18** | legal | affects consent validity, deletion handling for minors, and the store data-safety answers |
| **Q8** | **Download-my-data**: delivery channel (in-app signed URL vs another channel), file format, and the PDPL response window the export must meet | owner + legal | A02 promises "download everything" with no defined artefact |
| **Q9** | **Mostly resolved.** G8 owns the gateway, the event registry and the five allowlist tests; G7 supplies the privacy requirements (§5.1). What remains is one concrete request: **add `notif_permission_state`** to G8's 23-key allowlist, a closed enum with no personal content, without which A01's permission funnel — including "denied forever" — cannot be measured at all | G8 | either the key is added or A01's drop-off is permanently invisible |
| **Q10** | An upheld report is a **re-verification trigger** (research §5). Which Function writes it, given C5 makes `verification` Function-only? | G1 | either the coupling is specified or an upheld report has no teeth |
| **Q11** | A01's rows deep-link to **G13, M06, M02** — all post-MVP. What is the MVP inbox event set? (proposed: week closed, tier change, verification decided, nudge receipt) | owner | A01 ships with dead links or an unexplained empty state |
| **Q12** | Does deleting an account remove data **already shared with a coach** (derived panels, exports the coach made)? | owner + legal | consent model must be right now even though coaching is out of the cut — retrofitting consent is the leak |
| **Q13** | The **iOS Notification Content Extension** needs a separate target, an App Group and provisioning; the Android action button does not. Who owns that build configuration? | G8 / implementation | the §4 parity row silently ships on Android only |
| **Q14** | Missing test cases **P2-OFF-A01, P2-ERR-A01, P2-OFF-A04, P2-ERR-A04** (§8). **Confirmed against the regenerated suite** (197 rows, 31 P0): the gap survived the rebuild, and G8's plan independently lists the same 16 writing screens — A01 and A04 are in neither list despite both writing | Stage 1 suite owner | the queued-report state, the most misleading state in this group, is untested by two plans' reckoning rather than one |
| **Q15** | ~~`verification.imagesDeletedAt` is requested from G1~~ — **RESOLVED.** G1's plan defines the field, treats null as an alarm rather than a state, and reconciles every 15 minutes. A03 derives its rule-7 sentence from it | — | kept as a numbered row so the resolution is visible rather than silently dropped |
| **Q16** | G1's plan notes that **`C13` carries the deletion promise and has no P2 coverage**, and G7 has the same gap on A01/A04 (Q14). The three screens that make this product's data promises are the three least covered by the suite | Stage 1 suite owner | the promises most expensive to break are the ones no test renders in Arabic at large text |
| **Q17** | **A02's two promises do not hold for P04's progress photos.** G6 made them local-only and encrypted (its own OQ-10), so: (a) "Download everything" **cannot include them** — the export is server-built and the photos have no server copy; (b) deletion reaches them only on the handset that runs it (§3.3). G6 already flags that the photos do not survive a lost phone or a reinstall and that P04 does not say so | owner, with G6 | A02 currently promises an export and a deletion that are both narrower than the words suggest. Either A02 and P04 gain a line each, or the photos need a server copy — which would reverse G6's privacy decision and is an owner call, not an engineering one |
