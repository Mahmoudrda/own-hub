# Decisions needed from the owner

Spec §12: this file must be empty or explicitly accepted before the work is
done. **Three items are open.** Five have been closed by the owner since the first
draft and are kept below, marked CLOSED, so the reasoning is not lost.

---

# OPEN

## D4 — Does the $0.05 ceiling include the phone-auth SMS? **UNVERIFIED COST.**

Spec §2 step 0 requires sign-in by a **free** method (email link, Google, Apple)
before any paid step, and requires the per-SMS cost for Egyptian numbers to be
reported if phone auth is used. Real Firebase phone OTP has landed in the app
from another worker, so the app uses phone auth, not a free method. **That is a
violation of §2 step 0 as written.**

**Neither I nor the coordinator could confirm the price.** The Firebase limits
page carries no pricing and defers to Identity Platform; the coordinator fetched
both `https://firebase.google.com/pricing` and the Cloud Identity Platform
pricing page and neither yielded the regional table. My web-search budget was
exhausted. Recorded as unverified rather than estimated.

It could plausibly exceed every other line in the pipeline. The rest of the
verification measures at **$0.0031**; a single international SMS is commonly of
the same order or larger.

**Decision, two parts:**
1. Is the SMS inside the $0.05 cap or outside it? The ledger currently does NOT
   count it, and structurally cannot: the SMS is spent before `verify_identity`
   is ever called.
2. Does §2 step 0's "free method" requirement stand? If it does, phone auth as
   the sign-in method is a violation and email-link, Google or Apple sign-in
   must come first.

---

## D5 — No pilot data exists. Nothing is calibrated.

Spec §10 requires a staging pilot — 50 genuine female verifications across the
device matrix, 20 male attempts, 20 impostor attempts, 20 spoof attempts —
before production.

**It has not been run.** Consequently:

- no false-accept rate exists;
- no false-reject rate exists;
- no flag rate has been observed, only modelled;
- all four live thresholds are CHOSEN FROM PUBLISHED BENCHMARKS, NOT MEASURED.

The four are now set, and set from sources rather than from intuition:
`match_pass` 71.0 is cosine 0.42, the false-match-rate = 0.1% point of an
impostor model solved from OpenCV's published LFW accuracy for this exact ONNX
graph; `match_flag` 64.0 is cosine 0.28, OpenCV's published best-accuracy cut on
AgeDB-30; `liveness_pass` 75.0 and `liveness_flag` 55.0 are arithmetic over our
own confidence weighting, and **no published benchmark exists for that composite
at all** — we wrote it. The derivation, the sources and the sensitivity are in
VERIFICATION_REPORT.md and repeated in `config.py` above the values themselves.

Reasoning is not evidence. The published SFace accuracy figures are on ordinary
photograph pairs, not on a laminated sub-300-DPI print of a seven-year-old
photograph against a live capture, and DocFace+ (arXiv:1809.05620) measures that
exact gap: a public general face matcher reaches a true accept rate of 59.29% at
a 0.1% false accept rate on ID-document-to-selfie pairs, against better than 99%
on ordinary ones.

`config.THRESHOLDS_SELF_HOSTED.calibrated_from` opens with the word
PROVISIONAL, and a test asserts that it keeps doing so.

**Decision:** schedule the pilot, or accept launching on unmeasured thresholds
and say so explicitly. I will not assert an FAR/FRR I have not measured.

---

## D9 — Review capacity is short, and the shortfall is a staffing decision

Reviewers must be women, and review is a live video call or a ladies-only gym
visit, because no image is ever stored (D3). At 50,000 sign-ups over six months
every percentage point of flag rate is 500 calls.

The flag rate has now been modelled rather than left unknown. Every FLAG signal
was re-classified, the thresholds were set from published sources, and the
result is a **51% to 63% cut in the queue**:

| Genuine score distribution | Before | After | Calls | Women reviewers |
|---|---|---|---|---|
| optimistic (LFW-like) | 22.0% | **8.2%** | 4,084 | 1.5 |
| central (AgeDB-30-like) | 46.3% | **20.9%** | 10,466 | 3.7 |
| pessimistic (CFP-FP-like) | 55.8% | **27.1%** | 13,572 | 4.9 |

Two women reviewers absorb about 11.2%; one absorbs about 5.6%, at 15 minutes a
call and a x1.5 allowance for no-shows and reschedules. **Only the optimistic
column fits inside two people.** The model's own floor is about 6% whatever the
match threshold does, because the remainder is the liveness band, the niqab
route and the OCR flags, so the thresholds cannot get this below one full-time
reviewer.

**Decision, four options, and they combine:**

1. **Run the pilot first** (D5) and staff against a measured number rather than
   a 3x-wide range. This is the recommendation.
2. **Ramp sign-ups behind the flag rate.** The queue is a problem at 273
   sign-ups a day, not at 50. Even the pessimistic 27% is 13 calls a day at 50
   a day. Costs launch pace, not safety.
3. **Fund the capture-quality work.** `WORKING_LONG_EDGE = 1024` leaves a card
   portrait at roughly 60-150 px against SFace's 112x112 input. Every +0.05 of
   genuine mean cosine is worth about 5 points of flag rate, which is 2,500
   calls. Cheapest lever in the system and it is not a threshold.
4. **Staff three to four women reviewers** and accept the cost.

What is NOT on this list, deliberately: lowering `match_pass` further to shrink
the queue. At cosine 0.363 the expected admissions across the launch go from 1.1
to 4.0 men inside a women-only community, and spec §10 ranks a false accept
above every other failure.

---

# CLOSED BY THE OWNER

## D1 — AWS account. **CLOSED: no AWS.**
Liveness is our own server-side challenge response; the face match is our own
SFace comparison. No AWS account will be opened. The `LivenessProvider` and
`FaceMatchProvider` interfaces remain so a future provider drops in; the AWS
classes were deleted rather than left as stubs.
Consequence: liveness and face match now cost **$0**; the only paid call is
Cloud Vision. Worst case fell from 44,000 to 12,000 µUSD. The 50,000 ceiling was
**not** relaxed.

## D2 — The unmaintained Flutter liveness bridge. **CLOSED: not used.**
`face_liveness_detector` v0.2.11 (5 likes, 6 months stale, no named publisher)
is not a dependency. The risk is eliminated rather than mitigated; the risk
traded for it is RESIDUAL_RISKS #6.

## D3 — Flag evidence bundle. **CLOSED: never store an image.**
Stronger than my escalation asked for. The bundle write path, the dedicated
bucket, the lifecycle rule, the signed-URL admin callable and the hourly purge
job were built and then **deleted**, not left behind a disabled flag — a dormant
path that writes ID images to a bucket is what gets switched on by accident.
`EVIDENCE_BUNDLE_ENABLED` does not exist and a test asserts it does not.
Consequence, and it is a real one: **human review cannot be a desk review of a
photograph.** It is a live video call with a woman reviewer or a ladies-only gym
visit. The queue was rebuilt around scheduling. Capacity: RESIDUAL_RISKS #7.

## D6 — What "app data" means behind the verified gate. **CLOSED.**
The whole app is gated, minus four named exceptions, because applying §5
literally deadlocks sign-up: the verification flow writes `users/{uid}`, so
requiring the claim to write it means the claim can never be earned.
Exempt: `users/{uid}` itself, consents, deletion requests, and the safety
collections (blocks, blockedBy, myReports, reports). Implemented as
`isSelfVerified(uid)` with a comment explaining the deadlock, so nobody tidies
it into a uniform gate.

## D7 — Claim naming. **CLOSED: keep `verified` and `coachV`.**
§5's `vf`/`vstatus` are explicitly illustrative. The existing rules already read
`request.auth.token.verified` and `request.auth.token.coachV == 'active'`.

---

# D8 — Deploy-time configuration (work, not decisions)

None of this is visible in a code review, and none of it can be done from here.

- **Firestore TTL policy** on `verificationSessions.expiresAt`. The field is
  written; the policy is a project setting. A TTL field with no policy behind it
  is a document that lives forever while looking like it does not (§4 row 4 caps
  these at one hour).
- **Secret Manager**: `nid-hash-pepper` must exist, and the function's service
  account needs `roles/secretmanager.secretAccessor` on it. The code reads the
  secret over the API rather than through a Firebase secret binding, because the
  provisioned secret id contains dashes and Firebase maps secret names onto
  environment variable names.
- **App Check**: Play Integrity and App Attest must be provisioned before the
  first client ships. `ENFORCE_APP_CHECK` is already `True`, which is safe today
  only because the Flutter app makes zero callable calls yet.
- **`FLAG_WEBHOOK_URL`** env var (§5). Absent, notifications are skipped
  silently; the flag document is still written.
- **Budget alerts** (§6). Not created. The Cloud Billing API is disabled on
  `own-hub` — confirmed by a real 403 — so I could not read the billing
  catalogue either.
- **Firestore composite index** on `verification_flags (state, createdAt)` and
  `(state, slaExpiresAt)`, which the queue and the SLA job will need at volume.
- **Reviewer claims**: `admin` and `womanReviewer` are minted out of band by
  staff. There is no self-service path, by design.
- **Git-history secret scan** (§5). Not run.

## RELEASE ORDERING — the one that bites

Turning the client-side `accountRequired` flag on is the **LAST** change in this
programme, not an early one. Until the backend can actually approve a woman,
flipping it locks out every user including the owner, and it does so silently: a
permission denial on the first screen after sign-up looks like a network
problem.

    deploy functions
      -> provision App Check, the pepper grant, the TTL policy
      -> verify one real account end to end in staging
      -> run the §10 pilot
      -> THEN flip accountRequired
