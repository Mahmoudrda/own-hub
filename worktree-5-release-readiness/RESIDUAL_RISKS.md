# Residual risks

Spec §12 requires this file to cover at least five named risks. It covers those
and four more that came out of building the thing.

Nothing here is hypothetical hedging. Each item is something this system will
not stop, or will stop badly, stated so that nobody discovers it at launch.

---

## 1. A forged card carrying a man's photo and an even 13th digit

**Spec §12 names this one, and it is the one that defeats the design.**

The women-only gate rests entirely on the printed card. Two signals are checked
and they can both be forged at once: digit 13 is a digit on a plastic card, and
the printed النوع word is ink. A convincing forgery with a man's photograph, an
even 13th digit and أنثى printed on the back passes the sex gate, passes the
face match (the photograph IS him), and passes liveness (he is live).

**Nothing in this system detects a forged card.** There is no hologram check, no
UV feature check, no microprint check, no government database lookup. Egypt has
no public API for validating a national ID, so the card cannot be checked
against the register that issued it.

**What partially bounds it:** the one-card-one-account rule means one forgery
opens one account, not many; the cross-account flag signals surface a card that
has been tried repeatedly; and a forger has to make a physical artefact good
enough to photograph, which is a materially higher bar than typing a number.

**What would actually fix it:** a government verification API, if one is ever
offered. Until then this is the accepted ceiling on the product's central claim,
and the claim should be worded accordingly — "we check a government ID", not "we
guarantee every member is a woman".

---

## 2. A verified account handed to someone else after sign-up

**Spec §12 names this one.** Verification happens once, at sign-up. Nothing
re-checks who is holding the phone afterwards.

A woman can verify and then give, sell or lend the account. A husband, brother
or employer can stand over her while she verifies and then take the phone. The
second case is the one that matters in this product's context and the one the
system is least able to see.

**Not mitigated.** Periodic re-verification would help and would also be a
recurring, intrusive demand on every legitimate woman; that is a product
decision, not a technical one. Behavioural signals would mean profiling her,
which is a different and worse trade.

What the system does record: the `verificationBehaviour` and
`verificationInstalls` counters surface one install attempting several cards,
which is the sign-up-time version of this. They see nothing after approval.

---

## 3. Provider outages

**Spec §12 names this one.** Cloud Vision is the only external dependency left
after the AWS decision, and if it is down, nobody can verify.

**Mitigated in the direction that matters:** a failed provider call is NOT
charged to her ledger (`pipeline.run` only calls `spend` after a successful
result), so an outage cannot silently consume the four attempts she is allowed.
She gets `RETRY_CAPTURE` and keeps her budget. There is a test for this.

**Not mitigated:** there is no fallback OCR. An extended Vision outage stops
sign-ups entirely. The self-hosted liveness and face match keep working, which
is an accidental benefit of the no-AWS decision — two of the three stages have
no vendor to be down.

---

## 4. Threshold drift — **the most likely cause of a silent false accept**

**Spec §12 names this one and the coordinator asked for it to be made loud.**

Spec §3 starts the dials at `LIVENESS_PASS 90`, `LIVENESS_FLAG 70`,
`MATCH_PASS 90`, `MATCH_FLAG 75`. **Those are AWS Rekognition confidence units,
describing a provider this project will never call.** Carrying them across to
our own scores would not crash, would not fail a test, and would quietly change
what every decision means.

There are THREE score scales in this system, not two:

| Scale | What it is | Where |
|---|---|---|
| `rekognition-confidence-0-100` | AWS's calibrated confidence | never used |
| `sface-cosine-mapped-0-100` | a SFace cosine put through a linear map | face match |
| `selfhosted-challenge-composite-0-100` | a weighted sum of pose, frame consistency and blink | liveness |

**Enforced in code, not by discipline.** `config.ThresholdSet` carries a
`liveness_scale` and a `match_scale`; `for_providers` raises
`ThresholdScaleMismatch` rather than judging a score on the wrong scale, and the
decision engine calls it on every decision. Three tests hold it, including one
that proves our own two scales are not interchangeable with each other.

**That last test exists because the bug had already happened, in this very
file's configuration.** `config.py` claimed `match_pass = 80` was "cosine ~0.45"
when the mapping puts 0.45 at 72.5. A test caught it. The corrected values are
`match_pass = 72.5` (cosine 0.45) and `match_flag = 64.0` (cosine 0.28), and a
test now asserts the mapping rather than trusting the comment.

**THE UNCALIBRATED PART, stated plainly:** all four live thresholds are
DERIVED, NOT MEASURED. No false-accept rate and no false-reject rate has been
measured for this model on this population. The published SFace accuracy of
0.9940 is on a benchmark of ordinary photograph pairs, not on the
card-portrait-to-live-selfie problem, which is materially harder: a laminated
sub-300-DPI print of a photograph up to seven years old, re-photographed through
a reflective surface, against a live capture in whatever light is in her room —
and for many women a hijab in one image and not the other.

**Spec §10's pilot has not been run.** Until it is, these numbers are an
engineer's reasoning, not evidence.

---

## 5. Dependence on a third-party Flutter liveness bridge

**Spec §12 names this one. It has been eliminated rather than mitigated.**

The risk was `face_liveness_detector` v0.2.11 — five likes, six months stale, no
named publisher — holding the camera in a KYC flow. The owner's decision to
self-host liveness removes the dependency entirely. There is no third-party
liveness SDK on the client.

**The risk it was traded for** is item 6.

---

## 6. Our own liveness is weaker than a commercial passive-liveness model

The honest accounting for the decision in item 5.

**What the challenge-response scheme stops:**
- a printed photograph held to the camera — it cannot turn its head;
- a single still image on a phone screen, same reason;
- the same frame submitted N times;
- a mid-capture swap between the card's portrait and a live face;
- a generic pre-recorded "turn your head" clip, which will not match a randomly
  ordered challenge.

**What it does NOT stop:**
- **A video replay by someone who fetched the challenge first.** The challenge
  is issued before capture. An attacker with a screen and a clip library can
  read the demanded sequence and play the matching motions. Randomisation raises
  preparation cost; it does not defeat a prepared attacker.
- **A live person performing the challenge.** Only the face match stands between
  them and an account.
- **A 3D mask or a real-time deepfake.** No texture analysis, no depth, no
  reflectance model.
- **A screen replay identified by artefacts.** No moiré or screen-edge detection
  is implemented. A half-working one was deliberately not shipped, because it
  would create false confidence.

**Entropy:** three action steps drawn from three kinds is 27 orderings, halved
to about 13 distinguishable ones by the mirror ambiguity (front cameras mirror,
so the matcher accepts one global sign flip). Roughly 1 in 13 for a blind guess.
A speed bump, not a lock.

**Design consequence, already applied:** the uncertain band is wide and falls
through to a human. A pattern failure scores in the flag band, not the reject
band, so a genuine woman with an ambiguous capture reaches a reviewer rather
than a rejection.

Spec §9.8's adversarial checklist has "a video of a woman replayed on a phone
screen" as an explicit pass/fail item. **It has not been run.** Expect it to be
the hardest one.

---

## 7. Review capacity — **an operational number nobody should discover at launch**

No image is ever stored, so a reviewer cannot look at a photograph. Review is a
live encounter: a video call with a woman reviewer, or a ladies-only gym visit.

**The arithmetic:**

| Flag rate | Reviews at 50,000 sign-ups | Reviewer-hours at 15 min each |
|---|---|---|
| 1% | 500 | 125 |
| 5% | 2,500 | 625 |
| **10% (spec §10's target ceiling)** | **5,000** | **1,250** |
| 20% | 10,000 | 2,500 |

**Every percentage point of flag rate is 500 video calls.**

**Modelled, 25 September 2026, and the model is not a measurement.** Every
FLAG signal was re-classified against one question — would a human learn
something a retake would not? — and the four thresholds were set from published
benchmarks. The full arithmetic and every assumption are in
VERIFICATION_REPORT.md under "Human review volume". The result:

| Where the genuine score distribution really sits | Flag rate before | After |
|---|---|---|
| optimistic (LFW-like) | 22.0% | **8.2%** |
| central (AgeDB-30-like, cross-age) | 46.3% | **20.9%** |
| pessimistic (CFP-FP-like) | 55.8% | **27.1%** |

That is a 51% to 63% cut in the queue. **It is not enough on its own.** Two
women reviewers can absorb a flag rate of about 11.2% at 15 minutes a call and a
x1.5 allowance for no-shows and reschedules; one can absorb about 5.6%. Only the
optimistic column fits, and only just.

Three things about that range that matter more than the midpoint:

- **It is 3x wide, and only spec §10's pilot narrows it.** Nothing published
  tells us where an Egyptian ID card photographed on an Egyptian phone lands,
  and DocFace+ (arXiv:1809.05620) is the warning: a general face matcher reaches
  a true accept rate of only 59.29% at a 0.1% false accept rate on
  ID-document-to-selfie pairs. If the pilot lands near that, the answer is a
  different matcher, not a different threshold, and that is a spec §13
  escalation.

- **The floor is about 6%, whatever the match threshold does.** Even at a
  genuine mean cosine better than LFW's, the total only falls to 8.5%, because
  the rest is the liveness band, the niqab route and the OCR flags. The face
  match dial cannot take this below one full-time reviewer.

- **The cheapest untried lever is not a threshold.** `WORKING_LONG_EDGE = 1024`
  leaves a card portrait at roughly 60-150 px against SFace's 112x112 input, so
  our own downscale is depressing the genuine distribution before any threshold
  sees it. Every +0.05 of genuine mean cosine is worth about 5 points of flag
  rate in the central case, which is 2,500 video calls. It is not changed here
  because the gain cannot be estimated without measuring it.

The trade behind all of this is unchanged and unavoidable: widening the
uncertain band to protect real women from false rejects is the right instinct
and it directly multiplies the reviewer-hours. It now has numbers attached to
both sides instead of only to the instinct.

**Also:** the `womanReviewer` claim means reviewers must themselves be women,
which is correct and non-negotiable, and means the pool cannot be expanded by
hiring generically.

**Mitigated only by:** a 72-hour SLA after which the case becomes
`RETRY_REQUIRED` rather than sitting forever. That protects her from an
unbounded wait; it does not create reviewer capacity.

---

## 8. A leaked pepper makes the registry reversible

`id_hmac = HMAC-SHA256(key = ID_PEPPER, message = the 14 digits)`, per spec §4.

An Egyptian national ID is fourteen digits but nowhere near 10^14
possibilities: roughly 36,500 plausible birth dates x 27 governorate codes x
10,000 sequence numbers is about **10^10**. A consumer GPU computes 10^10
HMAC-SHA256 operations in well under a minute.

So if the pepper leaked alongside a database dump, **every hash in `nidRegistry`
becomes reversible to a real person's ID number in about a minute.** The
pepper's secrecy is the entire defence, and Secret Manager plus least-privilege
IAM is the entire mechanism.

**Proposed hardening, NOT implemented, for the owner to accept or decline:**
replace HMAC-SHA256 with scrypt (n=2^14, r=8, p=1) keyed on the pepper. Cost to
us: about 50 ms and 16 MB per verification, which is roughly **six cents in
total across all 50,000 verifications**. Cost to an attacker holding both the
dump and the pepper: that one-minute GPU run becomes years, because scrypt's
memory-hardness is what defeats parallel hardware.

It is not implemented because spec §4 names HMAC-SHA256 explicitly and rule of
engagement 2 forbids substituting my own judgement for a stated requirement.
`pepper_version` is already stored beside every hash, so a migration is possible
without losing the one-card-one-account rule.

---

## 9. The whole-app gate has a release-ordering trap

The `verified` claim now gates her logs, her plans, the community, the coaching
surfaces and the content library. Four paths escape it by design — her own
`users/{uid}` document, consents, deletion requests and the safety collections
— because gating those would deadlock sign-up or remove a right.

**THE TRAP: turning the client-side `accountRequired` flag on is the LAST change
in this programme, not an early one.** Until the backend can actually approve a
woman, flipping it locks out every user including the owner, and it locks them
out silently: a permission denial on the first screen after sign-up looks like a
network problem, not a policy change.

Ordering: deploy functions → provision App Check, the pepper and the TTL policy
→ verify a real account end to end → *then* flip `accountRequired`.

A second trap in the same area: the four exempt paths are marked with a named
predicate (`isSelfVerified`) and a long comment explaining the deadlock. If
someone "tidies" that into a uniform gate, sign-up breaks for every new account
and the cause is invisible from the rule that causes it.

---

## 10. Apple App Store guideline 5.1.1(v)

Accepted risk, recorded at the owner's instruction.

Requiring a government ID to use a fitness app is exposure under App Review
guideline 5.1.1(v), which restricts apps from requiring personal information
that is not directly relevant. The women-only product claim is the
justification, and it may not be accepted on first submission.

**The answer to guideline 2.1(a)** (the reviewer must be able to use the app) is
spec §5's reviewer allowlist: a server-side list of specific uids marked
verified, configurable and removable. **NOT IMPLEMENTED** — it needs the uid of
a real review account, which does not exist yet. It must never be a client flag
or a hidden gesture, because either is a bypass anyone can find.
