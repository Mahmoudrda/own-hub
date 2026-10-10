# G1 — Identity & verification

Stage 2 plan. Screens `C01`–`C16`. Owner of `users/{uid}` creation, the `verification` map,
`verificationJobs/**`, and the gate every other group consumes.

Fixed inputs honoured verbatim: `SCHEMA-SPINE.md` §1 paths, §2 ownership, §3 constraints C1–C8;
`BUILD-BRIEF.md` §2 rules 7 and 8, §3 numbers, §4 platform table, §6 output contract.

**The one-line summary of the security posture:** `verification.status` is written by one Cloud
Function through one state machine; the gate other groups read is a **server-minted Auth custom
claim**, not a client-readable flag and not a rules `get()`. A client cannot set, forge or
lie about its own verified state, and no gated read costs an extra document read.

---

## 1. Data model

### 1.1 What I add, against the spine

Nothing in the spine is renamed or moved. Three additions, all inside my own ownership area:

| Path | Status | Why |
|---|---|---|
| `users/{uid}` root fields `role`, `locale`, `pledge`, `createdAt` | extension, G1-owned | `C08`, `C02`, `C16` have no home in the spine's four maps |
| `users/{uid}/consents/{purpose}_{version}` | new subcollection, G1-owned | PDPL requires an auditable consent record for `C09`; deterministic ID = idempotent (C1) |
| `nidRegistry/{nidHash}` | new top-level, **no client access** | one ID = one account; without it a rejected woman re-registers forever. **Declared, not smuggled — see Open question 6** |

`verificationJobs/{jobId}` is the spine's own path; I only define its fields.

### 1.2 `users/{uid}` — fields I own

| Field | Type | Writer | Notes |
|---|---|---|---|
| `createdAt` | Timestamp | CF | set by `onAuthUserCreate` |
| `role` | `'client'\|'coach'` | client, once | `C08`. Immutable after first write (rules); changes go through support, as the screen says |
| `locale` | `'ar'\|'en'` | client | `C02` mirror only. **Not** authoritative — `profile.language` (G2) is. See Open question 2 |
| `pledge` | `{ version:int, acceptedAt:Timestamp }` | client, monotonic | `C16`. Version floor lives in Remote Config + rules |
| `verification` | map, below | **Cloud Function only (C5)** | client writes denied outright |

There is deliberately **no `phone`, no `name`, no `nationalId`, no `dob`, no `sex` field.** The
number lives only in Firebase Auth; the ID number never reaches Firestore or the app.

### 1.3 `users/{uid}.verification` — the spine's four keys plus my own

| Field | Type | Values | Purpose |
|---|---|---|---|
| `status` | string | `unverified` `submitted` `checking` `pending_review` `verified` `rejected` `expired` `reverify_required` `blocked` | §3 state machine |
| `method` | string | `id_selfie` `reviewer_video` `partner_gym` | which path decided it |
| `decidedAt` | Timestamp | | `C13` "Verified in 74 seconds" = `decidedAt − submittedAt` |
| `reviewerPath` | string? | `null` `video` `gym` | spine key; null when the automated check decided |
| `submittedAt` | Timestamp? | | mine; feeds the `C13` duration and the provider watchdog |
| `expiresAt` | Timestamp? | | 12-month re-verification (research §5) |
| `attempts` | int | 0–3 | retry ceiling before `blocked` |
| `jobId` | string | `{uid}_{attempts}` | pointer into `verificationJobs`; the client never reads the job |
| `adult` | bool | | ≥18, derived from the document, kept as a boolean only |
| `ageMet` | bool | | ≥ configured minimum (Open question 3) |
| `failReason` | string? | coarse code | drives `C12`'s rejected copy; never free text from the provider |

Derived age/sex are stored as **booleans, not values**. The ID number, the date of birth and the
sex marker are read once, in memory, inside a Cloud Function, and discarded with the images.

### 1.4 `verificationJobs/{jobId}` — no client access

`jobId = {uid}_{attempt}`, deterministic, so an offline retry or a duplicated webhook cannot create
a second job or a second billable provider check.

| Field | Type | Notes |
|---|---|---|
| `uid`, `attempt` | string, int | |
| `state` | string | `created` `provider_pending` `provider_returned` `reviewer_queued` `reviewer_claimed` `decided` |
| `method`, `reviewerPath` | string | |
| `providerName` | `'valify'\|'uqudo'` | Remote Config selected; recorded per job for failover audit |
| `providerRef` | string | the provider's transaction id — our only handle for the purge call |
| `outcome` | `'pass'\|'fail'\|'undecided'` | |
| `failReason` | string | `doc_unreadable` `no_match` `liveness_fail` `doc_sex_marker_odd` `underage` `duplicate_nid` `doc_expired` `provider_timeout` |
| `nidHash` | string | HMAC-SHA256 of the 14-digit number with a Secret Manager key. **Never the number** |
| `reviewerId`, `reviewerDecidedAt` | string?, Timestamp? | never exposed to the client |
| `scheduledFor` | Timestamp? | `C15` video-check slot |
| `imagesDeletedAt` | Timestamp? | **rule 7's evidence field** — null is an alarm, not a state |
| `createdAt`, `updatedAt`, `ttlAt` | Timestamp | Firestore TTL on `ttlAt` keeps the collection bounded |

No image, no image URL, no face template, no bounding box, no provider raw payload is ever stored.

### 1.5 `nidRegistry/{nidHash}` — no client access

`{ uid: string|null, state: 'active'|'closed'|'banned', claimedAt, closedAt? }`. Written inside the
same transaction as a `verified` decision. Keyed by hash, so it is a document get, never a query.

### 1.6 Indexes

| Index | Type | Used by | Hot path? |
|---|---|---|---|
| `users/{uid}` doc id | none needed | every screen | yes — direct get |
| `verification.expiresAt` ASC | single-field (automatic) | daily expiry sweep, `limit 200` + cursor | no |
| `verificationJobs` (`state` ASC, `createdAt` ASC) | **composite** | reviewer console queue, `limit 50` + cursor | no — admin only |
| `nidRegistry/{nidHash}` doc id | none needed | decision transaction | no |
| `consents/{purpose}_{version}` doc id | none needed | audit | no |

**Composite indexes on a client hot path: zero**, as spine §4 requires. The one composite index
exists for a back-office console that no member's device ever calls.

---

## 2. The query for every screen, with index and cost

`R` = client document read, `W` = client write, `sW` = server (Cloud Function) write, `CF` = callable.
All costs are **once per account lifetime** unless stated.

| Screen | Operation | Path | Index | Cost |
|---|---|---|---|---|
| `C01` Welcome | none | — | — | 0 |
| `C02` Language | write device prefs | `SharedPreferences` | — | 0 |
| `C03` What's inside | none (static copy) | — | — | 0 |
| `C04` Look around first | read the bundled preview manifest | Remote Config + bundled `exercises`/`recipes` | — | **0 reads** — see note |
| `C05` Join to save this | none (bottom sheet on `C04`) | — | — | 0 |
| `C06` Phone number | `verifyPhoneNumber(+20…)` | Firebase Auth | — | 0 Firestore |
| `C07` The code | confirm code → Auth user created → `onAuthUserCreate` | `users/{uid}` | doc id | 1 sW, then **1 R** + one snapshot listener held to `C16` |
| `C08` Client or coach | `update({role})` | `users/{uid}` | doc id | 1 W |
| `C09` Why we check | `recordConsent(purpose,version)` | `users/{uid}/consents/biometric_v1` | doc id | 1 CF, 1 sW |
| `C10` Scan your ID | `startVerification(method)` → session token | `verificationJobs/{uid}_{n}`, `users/{uid}` | doc id | 1 CF, 2 sW, 1 listener push (1 R) |
| `C11` Quick selfie | same provider session, no backend call | — | — | 0 |
| `C12` Checking | provider webhook → decision transaction | job + `users/{uid}` + `nidRegistry` | doc ids | 3–4 sW, 1–2 listener pushes (1–2 R) |
| `C13` You're in | render from the cached doc; force ID-token refresh | — | — | **0 R** |
| `C14` Waiting for a reviewer | render from the cached doc + listener | `users/{uid}` | doc id | 0 R (push only when the reviewer decides) |
| `C15` Woman reviewer | `chooseHumanPath(video\|gym)` | job + `users/{uid}` | doc ids | 1 CF, 2 sW, 1 R |
| `C16` Community pledge | `update({pledge})`; text + version from Remote Config | `users/{uid}` | doc id | 1 W, **0 R** |
| **Signup total** | | | | **4–5 R, 2 W client · 8–9 sW · 4 CF** |
| **Every day after** | the gate is an Auth claim; the doc is already `T01`'s read #1 | | | **0 R, 0 W** |

**`C04` reads nothing.** An unauthenticated marketing surface that queries Firestore is an
unbounded, unauthenticated read path. The six preview cards come from a Remote Config manifest
pointing at bundled library entries, so a scraper hitting `C04` costs us CDN bytes, not reads.
This also keeps spine §4's "never read the libraries per session" true at the very first screen.

### 2.1 Cost at §3's numbers

| Quantity | Figure | Working |
|---|---|---|
| Steady-state G1 reads per active day | **0 of the 8** | gate = custom claim; `users/{uid}` is already read by `T01` |
| Steady-state G1 writes per active day | **0 of the 6** | nothing in my group is written after signup |
| New accounts / month at 100k MAU | ~8,000 | 8% monthly joiner assumption — state it, don't hide it |
| Firestore / month | ~40k R, ~88k W | 8,000 × (5 R, 11 W) → **≈ $0.13/month** |
| Callables / month | ~32,000 | inside the free tier |
| Peak, 19:00–23:00 Cairo (40%) | ~107 signups in 4 h ≈ 0.008/s | trivial for Firestore |
| Launch-spike scenario | 10,000 signups/day → 4,000 in the peak window ≈ 0.28/s, bursts to ~5/s | **the provider's contracted TPS is the constraint, not Firestore** |
| SMS | 8,000 × ~$0.02–0.06 | ≈ $160–480/month, **confirm with the Firebase Egypt rate** |
| ID checks | 8,000 × $0.30–1.00 (unpublished) | **≈ $2,400–8,000/month — the whole cost of this group** |
| Human review | 8% (undecided + niqab) = 640/month, ~21/day, ~15 in the evening window, ~3 min each | ≈ 32 h/month, but the 2-hour promise on `C14` needs **≥2 women reviewers on the evening shift**, not 32 hours spread anywhere |

**Budget verdict:** G1's infrastructure cost is rounding error; G1's *contract* cost is the
dominant line item in the whole MVP after video egress. §3 asks the plan to respect a monthly
ceiling — **no ceiling figure was ever given** (Open question 12), so I state my group's envelope:
**$2.6k–8.5k/month at 100k MAU, ~97% of it the provider's per-check fee.** If the ceiling is below
that, the lever is the provider contract, not the architecture.

---

## 3. State machine — `verification.status`

Nine states, so this is the machine the contract asks for. It is implemented as a **pure function**,
`VerificationStateMachine.transition(current, event, ctx) → next | IllegalTransition`, in
`functions/src/verification/state_machine.ts`, and it is the **only** code path that writes
`users/{uid}.verification`. No callable, webhook or console touches the map directly.

### 3.1 The four outcomes the brief names, mapped

| Outcome | State | Screen | Method |
|---|---|---|---|
| pass | `verified` | `C13` | `id_selfie` |
| pending-reviewer | `pending_review` | `C14` | `id_selfie`, `reviewerPath=video` |
| niqab path | `pending_review` | `C15` → `C14` | `reviewer_video` or `partner_gym`, **no selfie ever requested** |
| rejected | `rejected` | `C12` rejected state → route to `C15` | any |

### 3.2 Transitions

| From | Event | To | Side effects |
|---|---|---|---|
| `unverified` | `SESSION_MINTED` (requires a consent doc) | `submitted` | job `created`, `submittedAt`, `attempts++` |
| `submitted` | `CAPTURE_RECEIVED` (provider ack) | `checking` | job `provider_pending`, watchdog armed T+5 min |
| `submitted` | `SESSION_ABANDONED` / app killed | `unverified` | job kept; same `jobId` on resume (no second charge) |
| `checking` | `PROVIDER_PASS` | `verified` | `NidRegistry.claim`, `expiresAt=+12mo`, claim minted, **purge requested** |
| `checking` | `PROVIDER_FAIL(reason)` | `rejected` | purge requested; `failReason` set |
| `checking` | `PROVIDER_UNDECIDED` | `pending_review` | job `reviewer_queued`, purge requested |
| `checking` | `PROVIDER_TIMEOUT` (T+10 min) | `pending_review` | **an outage becomes a human review, never an error** |
| `unverified` \| `rejected` \| `checking` | `HUMAN_PATH_CHOSEN(video\|gym)` | `pending_review` | `method`, `reviewerPath`, `scheduledFor` |
| `pending_review` | `REVIEWER_PASS` | `verified` | as `PROVIDER_PASS`, `method` = reviewer path |
| `pending_review` | `REVIEWER_FAIL` | `rejected` | |
| `rejected` | `RETRY_REQUESTED` (`attempts < 3`) | `submitted` | new `jobId` = `{uid}_{n+1}` |
| `rejected` | `ATTEMPTS_EXHAUSTED` (`attempts = 3`) | `blocked` | only route out is a human reviewer |
| `verified` | `EXPIRY_ELAPSED` | `expired` | claim re-minted with `verified:false` |
| `verified` | `REVERIFY_REQUESTED(new_device\|report_upheld)` | `reverify_required` | |
| `expired` \| `reverify_required` | `SESSION_MINTED` | `submitted` | `attempts` reset to 0 |
| any | `ACCOUNT_CLOSED` | terminal | `nidRegistry` → `closed`, consents and jobs purged |

Illegal pairs are rejected and logged, not coerced. `verified → unverified` does not exist: losing
verification degrades to `expired`, which keeps her training data reachable.

### 3.3 Capability matrix — the contract every other group reads

Never re-derived in a widget. One call: `VerificationGate.capabilitiesFor(status, pledge)`.

| status | libraries, workouts, recipes | her own logs | browse coach profiles | community read/write | coach chat + purchase |
|---|---|---|---|---|---|
| `unverified` `submitted` `checking` | yes | yes | yes | **no** | **no** |
| `pending_review` (incl. niqab) | yes | yes | yes | **no** | **no** |
| `rejected` `expired` `reverify_required` | yes | yes | yes | **no** | **no** |
| `verified`, pledge current | yes | yes | yes | **yes** | yes (+ `adult` for purchase) |
| `verified`, pledge stale | yes | yes | yes | **no** — `C16` first | yes |
| `blocked` | read own data, export, delete | yes | no | no | no |

This is `C14`'s promise expressed as data: a pending check is never a dead end, and the only thing
that waits is the community. It is also the research file's rule — *never* member posts, member
profiles, chats or challenge boards before `verified`.

---

## 4. Offline behaviour

Spine §5 says verification is **not** writable offline. This group is the one place in the product
where "it will sync later" is the wrong answer, and the UI must say so out loud.

| Surface | Writable offline | What the UI shows |
|---|---|---|
| `C02` locale | yes (device prefs) | nothing; it is local |
| `C06` `C07` phone + code | **no** — Auth needs a live channel | "You need a connection to get your code." Retry button. Never an endless spinner (`P2-OFF-C06/C07`) |
| `C08` role | **yes** — queued write to `users/{uid}` | flow continues immediately; no queued badge, it is not a log |
| `C09` consent | **no** — callable | blocks with the same connection state; the next step needs the network anyway |
| `C10` `C11` `C12` | **no** — live provider required | connectivity is checked **before the camera opens**. If it drops mid-capture the session is abandoned, the job stays `submitted`, and resuming reuses `jobId={uid}_{n}` so there is no duplicate and no second provider charge (`P0-VER-07`) |
| `C13` `C14` | read-only, fully renderable from cache | `C14` shows "last checked HH:mm" from `decidedAt`; a reviewer decision arrives as a listener push when signal returns |
| `C15` | **no** — callable | as `C09` |
| `C16` pledge | **yes** — queued write | accepted immediately in the UI; the community still does not open until the server re-mints the claim |

**Conflict resolution.** The `verification` map has exactly one writer, so a conflict is structurally
impossible. `role` is immutable after first write. `locale` and `pledge` are single-owner scalars →
last-write-wins per spine §5, with `pledge.version` required to increase monotonically.

**The offline pledge cannot be an exploit.** `C16` writing offline does not grant community access,
because access is decided by a server-minted claim. Queue the write, keep the door shut.

---

## 5. §2 rules I own, and where each is enforced

Domain and Cloud Function layers. No widget decides any of this.

| Rule | Enforcement point | Mechanism |
|---|---|---|
| **Rule 7** — ID and selfie deleted, only the result kept | `VerificationDecisionService.finalise(job)` → `ProviderPurge.request(job)` (`functions/src/verification/decision_service.ts`, `provider_purge.ts`) | Every terminal decision calls the provider's delete endpoint and stamps `imagesDeletedAt`. `PurgeReconciler.sweep()` (scheduled, 15 min) retries failures and **pages on any job decided >1 h ago with a null `imagesDeletedAt`** |
| Rule 7, structurally | Storage rules, §6.2 | No bucket path can hold an ID or a selfie. Our backend never receives image bytes at all: the provider SDK uploads device→provider under a one-time session token minted by `VerificationSessionService.start()`. There is no upload function to audit because there is no upload function |
| **Rule 8** — no AI face-gender classification | `NationalIdGate.sexFromNid(nid)` (`functions/src/verification/national_id_gate.ts`) | Validates 14 digits and the check digit, reads **digit 13 (index 12)**: odd → male, even → female. This is the single sex determination in the system. The selfie result the provider returns is consumed only as `match: bool` and `liveness: bool` |
| Rule 8, structurally | `tools/lint_no_face_gender.sh` in CI | Fails the build on `genderClassif`, `faceGender`, `classifyGender`, ML Kit face *classification* options and `VNDetectFaceCaptureQuality`-style gender inference. **Distinction QA must not false-positive on:** G7's on-device face *detection* for blur (rule 6) is allowed; *classification* is not |
| Rule 11 — nothing ranked | C7 applied to my fields | No index on any G1 field permits a cross-user sort; `nidRegistry` is keyed by hash and never queried |
| Rule 3 / C6 — no streak | schema | No field named `streak` and no consecutive-day counter exists in any G1 collection |
| Spine **C5** | `VerificationStateMachine` is the sole writer + rules deny `verification` outright + the gate is a server-minted claim | The one-line bypass the brief warns about is closed on three independent layers |
| Spine §6 — analytics | `VerificationAnalytics.emit()` allowlist | Emits `{screen, step}` and a coarse funnel outcome (`self_serve` / `human_path` / `abandoned`) only. Never the phone number, never `verified`/`rejected` per user, never a provider reference. Asserted in a unit test, not trusted to reviewers |
| PDPL consent | `ConsentService.record()` (callable, server timestamp + server-side policy-text hash) | `startVerification` **refuses** to mint a session if `consents/biometric_v{n}` is absent. Consent is a precondition in code, not a checkbox in a widget |

---

## 6. Security rules, as code

### 6.1 Firestore

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() { return request.auth != null; }
    function isSelf(uid) { return signedIn() && request.auth.uid == uid; }
    function claim(k) { return signedIn() && (k in request.auth.token); }

    // ---- PUBLISHED TO G2–G8. Zero document reads. ----
    // The claim is minted only by G1's Cloud Function after the state machine
    // writes `verified`, so it cannot be forged by a client (spine C5).
    // Deliberately NOT a get() on users/{uid}: a rules get() is a billed read,
    // which would double the cost of every community read at 100k MAU.
    function isVerified() {
      return claim('verified') && request.auth.token.verified == true
          && claim('vexp')     && request.auth.token.vexp > request.time.toMillis();
    }
    function pledgeAccepted() {
      // Floor is bumped in this file when the pledge text changes.
      return claim('pledgeV') && request.auth.token.pledgeV >= 1;
    }
    function canEnterCommunity() { return isVerified() && pledgeAccepted(); }
    function isAdult() { return claim('adult') && request.auth.token.adult == true; }

    match /users/{uid} {
      function changed() {
        return request.resource.data.diff(resource.data).affectedKeys();
      }
      function roleOk() {
        return !changed().hasAny(['role'])
            || (!('role' in resource.data)
                && request.resource.data.role in ['client', 'coach']);
      }
      function localeOk() {
        return !changed().hasAny(['locale'])
            || request.resource.data.locale in ['ar', 'en'];
      }
      function pledgeOk() {
        return !changed().hasAny(['pledge'])
            || (request.resource.data.pledge.acceptedAt == request.time
                && request.resource.data.pledge.version is int
                && (!('pledge' in resource.data)
                    || request.resource.data.pledge.version
                       > resource.data.pledge.version));
      }

      allow get:    if isSelf(uid);
      allow list:   if false;            // no cross-user query exists (C7)
      allow create: if false;            // onAuthUserCreate only
      allow delete: if false;            // A02 deletion is server-side (P0-DEL-01)

      allow update: if isSelf(uid)
        // spine C5 — the single most security-critical line in this file
        && !changed().hasAny(['verification'])
        // spine C6 — rule 3 made unstorable
        && !changed().hasAny(['streak'])
        && roleOk() && localeOk() && pledgeOk()
        // G1 keys + the keys G2/G6 own; their VALUE validators are theirs to add
        && changed().hasOnly(['role', 'locale', 'pledge', 'updatedAt',
                              'profile', 'rewards', 'weeklyGoal']);

      match /consents/{consentId} {
        allow get, list: if isSelf(uid);   // she can read her own consent trail
        allow write:     if false;         // ConsentService callable only
      }
    }

    // Functions only. No client, no reviewer console via the client SDK,
    // no admin UI on a phone. Ever.
    match /verificationJobs/{jobId} { allow read, write: if false; }
    match /nidRegistry/{nidHash}    { allow read, write: if false; }

    // Immutable content. Readable before sign-in because C04 has no account yet.
    // Abuse control is App Check enforcement (service level, not expressible
    // in rules) plus the fact that C04 reads a bundled manifest, not this.
    match /exercises/{id} { allow read: if true;  allow write: if false; }
    match /foods/{id}     { allow read: if true;  allow write: if false; }
    match /recipes/{id}   { allow read: if true;  allow write: if false; }
    match /programs/{id}  { allow read: if true;  allow write: if false; }

    // NOT G1's collections. Shown to fix the contract the other groups consume:
    // a women-only app whose posts are readable before `verified` is not
    // women-only, and C04's own note says so on screen.
    // match /posts/{postId}   { allow read: if canEnterCommunity(); ... }
    // match /profiles/{other} { allow read: if canEnterCommunity(); ... }
  }
}
```

### 6.2 Storage — rule 7 made structural

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // There is no legitimate ID or selfie object in this bucket, so the
    // paths an implementer would reach for are denied by name as well as
    // by the default deny below. Rule 7 cannot be broken by accident.
    match /verification/{p=**} { allow read, write: if false; }
    match /id/{p=**}           { allow read, write: if false; }
    match /selfie/{p=**}       { allow read, write: if false; }
    match /kyc/{p=**}          { allow read, write: if false; }

    match /{allPaths=**}       { allow read, write: if false; }  // G5/G7 open their own prefixes
  }
}
```

### 6.3 Claim mechanics, stated honestly

| Property | Value | Consequence |
|---|---|---|
| Claim payload | `{ verified, vexp, pledgeV, role, adult }` | ~80 bytes of the 1000-byte ceiling |
| Minted by | `VerificationStateMachine` commit, via `auth().setCustomUserClaims` | server-only, unforgeable |
| Propagation | next token refresh, ≤1 h | `C13` calls `getIdToken(refresh: true)` the moment the doc listener reports `verified`, so the wait is ~0 in practice |
| Revocation lag | up to 1 h on `expired` / `rejected` | `vexp` is checked **inside** the rule, so an expiry cannot be outlived by a stale token. For a moderation ban, `revokeRefreshTokens(uid)` plus the `blocked` state |
| Source of truth | `users/{uid}.verification` | the claim is a cache; a mismatch is resolved by re-minting, never by trusting the claim |

---

## 7. Interface to the other groups

### 7.1 What G1 consumes

| From | What | Contract |
|---|---|---|
| G8 | App Check + Play Integrity / DeviceCheck attestation | enforced on Auth, Firestore and all four callables; without it, `C06` is an SMS-pump billing hole |
| G8 | connectivity state | `C10`–`C12` refuse to open the camera offline |
| G8 | Remote Config | `verification_provider`, `pledge_version`, `min_age`, the `C04` preview manifest |
| G8 | **a re-verification signal** (requested) | G8's `onDeviceRegister` function calls my exported `requestReverification(uid, 'new_device')`. G8 keeps sole ownership of `devices/**`; I never read it. Function-to-function, no schema crossing (F07) |
| G8 | analytics client | with my allowlist in §5 applied |
| G2 | `profile.language` as the authoritative locale | I write only the pre-auth `locale` mirror; G2 owns the field |
| G2 | **`profile.firstName`** (requested field) | `C13` renders "You're in, Mai". No name exists anywhere in the spine — Open question 1 |

### 7.2 What G1 publishes

| Artefact | Consumers | Guarantee |
|---|---|---|
| `users/{uid}.verification` (read-only) | all | Cloud-Function-written, spine C5 |
| Auth custom claims `{verified, vexp, pledgeV, role, adult}` | all, in rules | server-minted, 0 reads to check |
| Rules functions `isVerified()`, `pledgeAccepted()`, `canEnterCommunity()`, `isAdult()` | G3–G7 | copy verbatim; do not re-implement with `get()` |
| `VerificationGate.capabilitiesFor()` | every feature widget | the single place the app decides what is open (§3.3) |
| `onAccountDelete(uid)` hook | G7 (`A02`, `P0-DEL-01`) | closes the `nidRegistry` entry, purges consents and jobs; G7 must call it |
| Route contract | G2 `C16`→`O01`; coach setup `C13`→`K01`; G4/G5/coach `C14`→`R01`/`E05`/`H01` | **those three destinations must render for an unverified account** — `C14`'s promise depends on it |
| Ban list | G8 | never emit the phone number, the verification result, `providerRef` or `nidHash` to Amplitude (spine §6) |

Nothing in G1 writes another group's field. Nothing outside G1 writes `verification`, `role`,
`pledge`, `verificationJobs` or `nidRegistry`.

---

## 8. Test IDs I am accountable for

**P0 — owned outright**

| ID | What it pins |
|---|---|
| `P0-VER-01` | happy path `C06`→`C13`, under ~2 min, `C13` states deletion, community opens |
| `P0-VER-02` | Android code auto-retrieval, 4th digit self-submits |
| `P0-VER-03` | iOS AutoFill, and the app **never** asks for SMS read permission |
| `P0-VER-04` | undecided → `C14`, not a rejection; workouts, recipes and coach profiles stay open |
| `P0-VER-05` | niqab path: no selfie requested at any point, reaches `C14` |
| `P0-VER-06` | rejected: non-accusatory, routes to `C15`, never a dead end |
| `P0-VER-07` | network lost mid-check: explicit, nothing lost, retry, no partial upload counted as success |

**P1 — owned outright**

| ID | What it pins |
|---|---|
| `P1-RULE-07` | no ID or selfie exists anywhere after the check, **including in the provider's logs** — `imagesDeletedAt` plus a provider-side assertion |
| `P1-RULE-08` | no gender inference call exists in app or backend; sex comes only from digit 13 |

**P0 — shared, my slice named**

| ID | My slice |
|---|---|
| `P0-NAV-01` | tap depth across `C01`–`C16` |
| `P0-A11Y-01` | Arabic RTL across `C01`–`C16` |
| `P0-DEL-01` | deletion removes the consent trail, the jobs and the claim; `nidRegistry` closes (see Open question 6) |

**P2 touching my screens: 36 rows** (`P2-RTL-*`, `P2-TXT-*` for 14 screens, `P2-OFF-*`/`P2-ERR-*`
for `C06`, `C07`, `C10`, `C11`). Gap found: **`C03` and `C13` have no `P2-RTL`/`P2-TXT` row** while
all fourteen other screens do — Open question 8.

---

## 9. Scalability gate — my own plan checked against the four rejection criteria

| Criterion | Result | Evidence |
|---|---|---|
| Unbounded collection scan | **PASS** | Two queries exist in the whole group, both internal: the reviewer queue (composite index, `limit 50`, cursor) and the expiry sweep (single-field range on `verification.expiresAt`, `limit 200`, cursor, ~275 documents/day at 100k accounts on a 12-month cycle). Client code issues **zero queries** — every client access is a document get by a known id |
| Per-user fan-out write growing with followers | **PASS** | A verification writes exactly 3 documents (`users/{uid}`, one job, one registry entry) regardless of account count. There is no fan-out and no follower-shaped write anywhere in G1 |
| Unindexed query on a hot path | **PASS** | The hot path has no query at all. The gate is an Auth claim (0 reads), and `users/{uid}` is already `T01`'s first read. Had the gate been a rules `get()`, every community read would have cost a second billed read — that is the specific mistake this design exists to avoid |
| Migration needed to reach 100k MAU | **PASS** | No single-document counter, no sequential ids, deterministic job ids, Firestore TTL on `verificationJobs.ttlAt` bounds the only monotonically growing collection, and the claim-based gate is in from day one rather than retrofitted. The one change that would need a migration is adding `nidRegistry` later — which is why it is in this plan now |

---

## 10. The third-party dependency, named honestly

ID verification is **contracted, not built**: Valify first (Egyptian, licensed, checks against the
National Registry, data stays in Egypt), uqudo as the failover and for non-Egyptian documents.
Per-check pricing is published by neither.

### 10.1 What the app does vs what the provider does vs what we keep

| Step | Our app | The provider | Stored by us |
|---|---|---|---|
| Consent (`C09`) | shows the text, records the act | — | `consents/biometric_v1` (purpose, version, text hash, time, locale) |
| Session mint | calls `startVerification` | issues a one-time session token | `verificationJobs/{uid}_{n}`, `providerRef` |
| ID capture (`C10`) | hosts the provider SDK; frames the card; **no bytes touch our backend** | auto-capture, OCR, document authenticity, National Registry check | **nothing** |
| Selfie (`C11`) | hosts the SDK | passive liveness + match to the card photo | **nothing** |
| Sex determination | — | returns the parsed ID number | **nothing** — `NationalIdGate` reads digit 13 in memory and discards it |
| Decision (`C12`) | listens to its own user document | returns `pass`/`fail`/`undecided` + reasons | `status`, `method`, `decidedAt`, `reviewerPath`, `adult`, `ageMet`, `failReason`, `nidHash` |
| Deletion | calls the purge endpoint, stamps `imagesDeletedAt`, reconciles every 15 min | deletes images and face template | the timestamp, as evidence for `P1-RULE-07` |
| Niqab path (`C15`) | books the slot, shows the copy | **not involved** — a woman reviewer, live, recording disabled by configuration | decision + `reviewerId` (never shown to her) |

### 10.2 When the provider is down

| Failure | Detection | Behaviour |
|---|---|---|
| Session mint returns 5xx | `startVerification` | camera never opens; `C10` shows "the check is unavailable right now", offers `C15`. **Never a rejection** |
| SDK fails mid-capture | SDK callback | job stays `submitted`; resume reuses the same `jobId` — no duplicate, no second billable check |
| Webhook never arrives | watchdog at T+5 min, escalation at T+10 min | `PROVIDER_TIMEOUT` → `pending_review` → she lands on `C14`. **A provider outage degrades into the woman-reviewer queue, which is a product we already have** |
| Provider degraded for hours | Remote Config `verification_provider` | flip to `uqudo`; the job records which provider decided it |
| Both providers down | Remote Config `verification_provider = reviewer_only` | every new account goes to `pending_review`; training, recipes and coach browsing stay open; only the community waits — exactly `C14`'s designed state |
| Purge endpoint down | `PurgeReconciler` | retries with backoff; **pages a human after 1 h**, because an un-purged image is a rule-7 breach and a PDPL incident, not a backlog |

### 10.3 PDPL

Law 151/2020 + Executive Regulations (Decree 816, 1 Nov 2025); full enforcement ~Oct 2026. A face
template is biometric data: processing needs **explicit consent and a licence/permit from the
Personal Data Protection Centre**. The provider is the processor performing the match; **we are the
controller**, and the controller's licence obligation is not delegated by using an SDK.

Launch blockers, owner track, no amount of code removes them: the PDPC licence/registration, a
signed DPA with the provider, and a cross-border transfer basis if uqudo processes outside Egypt.
Built into the design already: explicit separate consent before the ID step, on-screen retention
statement, provider-side deletion with our own evidence field, and no biometric data on our
infrastructure at any point.

---

## 11. Platform policy (§4) — the SMS row, both sides built

| | Android | iOS |
|---|---|---|
| Mechanism | Firebase Auth auto-retrieval over the **SMS Retriever API** | `AutofillHints.oneTimeCode` + `textContentType: .oneTimeCode` |
| Permission | **none** — SMS Retriever requires no runtime permission and no `READ_SMS` | none exists; iOS grants no SMS read at all |
| Behaviour | code is read and the 4th digit self-submits (`P0-VER-02`); Play Services may complete **instant verification with no SMS at all**, so `C07` must be skippable and must not claim "we sent four digits" when it was never sent | the OS offers the code above the keyboard; she taps once (`P0-VER-03`) |
| Designed fallback | manual entry with the same auto-submit | manual entry; resend after a 30 s cooldown with exponential backoff |
| Abuse control, both | App Check + Play Integrity / DeviceCheck on the mint, per-number and per-device cooldowns — SMS is billed per message | |

**The app must never request `READ_SMS` on either platform.** It is unnecessary, it breaks the Play
data-safety declaration, and `P0-VER-02`'s precondition currently says otherwise — Open question 9.

---

## 12. Open questions — named, because silence is a defect

1. **`C13` greets her by name ("You're in, Mai"), and no name field exists anywhere in the spine.**
   `A02` shows "Mai Farouk" too. Research §4 says store only outcome, reference, sex, age and date —
   so reading the name off the ID contradicts our own minimisation promise. **My proposal:** she
   types a first name in G2's setup (`profile.firstName`); G1 never touches it. Needs G2 to accept
   the field and the owner to accept that `C13` says "You're in" until she has typed one.
2. **`C02` chooses a language before an account exists, but `profile.language` is G2's field.**
   Two writers on one field is a rejected plan, so G1 keeps a device-local choice plus a root
   `locale` mirror, and G2's setup seeds `profile.language` from it. **Needs G2's confirmation that
   `profile.language` is authoritative and that G1 may create `locale`.**
3. **Minimum age: 16 or 18?** Blocks `AgeGate`, the `ageMet` claim and the under-18 coaching-purchase
   rule. Legal sign-off, owner track. Research recommends 16+ with no coaching purchases under 18.
4. **Trans women.** The gate follows the document marker, which is a policy decision with legal
   exposure (*Tickle v Giggle*, Full Federal Court, May 2026 — direct discrimination on
   gender-related appearance). The policy must be written, applied consistently and reviewed by an
   Egyptian lawyer. I have implemented the document-marker gate as instructed by rule 8 and research
   §1; **I cannot choose this policy.**
5. **Non-Egyptian residents.** In or out of MVP? A passport path needs MRZ parsing (sex field, not
   digit 13), which is a second branch in `NationalIdGate` and a second provider capability.
6. **`nidRegistry` retention after account deletion.** PDPL gives a deletion right; the safety
   purpose needs a lasting block so a removed woman cannot re-register. **My proposal:** on deletion
   keep the hash with `state:'closed'` and `uid:null` — pseudonymous, no linked personal data,
   justified as a safety measure. **Needs legal sign-off, and it is a declared addition to the
   spine's collection layout that the spine owner must accept.**
7. **The rejected state has no screen and no copy.** `P0-VER-06` names `C12`, but `screens-signup.mjs`
   renders only the in-progress state and `app_en.arb` contains no rejection, retry or
   provider-unavailable strings. I have specified it as a **state of `C12`** (per handoff rule 16:
   states, not routes) with a route to `C15`. Needs copy in both languages, plus copy for
   provider-down and for offline-during-check.
8. **`C03` and `C13` are missing from P2 coverage.** Every other screen in my group has a `P2-RTL-*`
   and `P2-TXT-*` row; these two do not. `C13` in particular carries the deletion promise, which is
   long copy in Arabic at large text. Requesting two rows.
9. **`P0-VER-02`'s precondition, "SMS permission granted", is wrong** and will make an implementer
   request `READ_SMS`. SMS Retriever needs no permission. Requesting a CSV correction.
10. **Firebase phone auth sends a 6-digit code; `C06`, `C07` and the ARB all say four.** The length
    is not configurable. Either the design moves to six boxes (≈4 strings and one widget), or we
    leave Firebase phone auth for a custom SMS gateway plus custom tokens — which loses Android
    instant verification, adds an auth surface to secure, and makes `C07`'s "0 extra taps" claim
    harder. **My recommendation: six digits.** Owner decision, and it changes copy, so it is not mine.
11. **The reviewer console does not exist and is not in any group's scope.** `C14` promises "usually
    under two hours" and "only women review". That needs: a console, an auth model that proves a
    reviewer is a woman on the team, staffing cover across the 19:00–23:00 peak (my estimate: ≥2
    reviewers on the evening shift at 100k MAU), and an escalation when the 2-hour promise is missed.
    Who builds and staffs it?
12. **No budget ceiling was ever stated**, though §3 requires the plan to respect one. My envelope is
    in §2.1: **$2.6k–8.5k/month at 100k MAU, ~97% of it the provider's per-check fee.** Needs the
    Valify/uqudo quotes and the Firebase Egypt SMS rate to become a real number.
13. **`C15`'s "Book the video check" has no booking backend** and no named WebRTC vendor, and
    "nothing is recorded" must be technically enforced (recording disabled by configuration, proven
    in a test), not merely promised in copy. `C15` also claims **12 partner gyms** in Cairo, Giza and
    Alexandria — `brief.mjs` still marks those cities `[CONFIRM]`.
14. **Does the SDK's on-device liveness make us a joint processor of biometric data** for PDPL
    licensing purposes, even though no template reaches our servers? Counsel's call; it changes the
    licence scope, not the design.
15. **Re-verification (F07, release "Launch") needs G8's device signal** and a decision on whether it
    is in the MVP cut. It reuses `C11` with no new screen, and the `reverify_required` state is
    already in §3.
16. **`C08`'s coach branch leads to `K02`/`K06`, a certificate check that is a different
    verification with a different provider relationship.** It is outside my 16 screens, but it will
    want to write `verification.method` or a parallel map. Naming it so two groups do not both write
    the map: **G1 owns the map; coach certification must request its own field, not reuse mine.**
