# Delta notes — server side

Per-worker notes against `VERIFICATION_SPEC.md`, which is the owner's document
and is not edited here. Decisions are in `DECISIONS_NEEDED.md`, risks in
`RESIDUAL_RISKS.md`, the gap table in `AUDIT.md`.

## Owner decisions applied

| Item | Spec said | Now | Where |
|---|---|---|---|
| Liveness provider | AWS Rekognition Face Liveness, ~$0.015 | self-hosted challenge response, $0 | `providers_selfhosted.SelfHostedLiveness` |
| Face match | AWS CompareFaces, ~$0.001 | self-hosted SFace 1:1, $0 | `providers_selfhosted.SelfHostedFaceMatch` |
| AWS slot | build the interface, leave AWS unimplemented | **class deleted entirely** — no AWS account will be opened | `providers.py` |
| §4 flag evidence bundle | permitted for flagged cases, 72 h | **never store an image**; path built then deleted, not flagged off | `identity/evidence.py` removed |
| §5 admin evidence signed URL | required | deleted; access log kept | `main.py` |
| Human review | look at evidence | **live video call or ladies-only gym visit**, scheduled and recorded | `schedule_verification_review` |
| §5 app-data gate | deny all unless verified | whole app, minus 4 named exceptions | `isSelfVerified` in rules |
| §6 worst case | 4x3,000 + 2x16,000 = 44,000 | 4x3,000 + 2x0 = **12,000** | `ledger.worst_case_micro_usd()` |
| §6 ceiling | 50,000 µUSD | **unchanged** — a safety rail, not an estimate | `config.COST_CAP_MICRO_USD` |
| §5 claim names | "for example `vf`, `vstatus`" | `verified` / `coachV`, matching the existing 864-line rules file | `store.mint_claims` |
| §1 MIN_AGE | 18 | 18 | `config.MIN_AGE` |
| §1 digit 14 | do not validate | checksum code deleted; a test greps the module to keep it deleted | `test_nid.py` |
| §1 governorate | unknown code is a FLAG | **recorded and counted, no review** | `decisions._score_stage`, `store.record_unknown_governorate` |

## Wire contract, reconciled with the Flutter worker

Adopted as proposed: callable names `verify_identity` and `record_consent`;
region `europe-west3`.

Two items were **actively wrong** and were corrected rather than adopted:

1. **`liveness: {outcome, sessionId}`** — a client reporting its own liveness
   outcome is the cheapest bypass of the whole product and violates rule of
   engagement 3. The envelope is accepted so the client shape does not change;
   `liveness.outcome` is **not read, not logged, not stored**. Only `sessionId`
   is used. Held by an AST test that fails if anyone adds a read of that key.

2. **`{outcome, reasons}` carrying internal reason codes** — spec §3 forbids
   telling her which check failed. Key names kept; `reasons` now carries a
   separate 5-value user-safe vocabulary (`retake_front`, `retake_back`,
   `retake_selfie`, `try_again_later`, `contact_support`), mapped many-to-few so
   it cannot be inverted. The sex gate, the age gate and every FLAG signal map
   to nothing at all. 9 tests.

Added to the contract: **`start_verification`** returning
`{sessionId, steps, expiresInSec}`. `liveness.sessionId` has to come from
somewhere, and it cannot come from the client or the randomised challenge is
worthless. One captured frame per step, submitted in order; frame count must
equal step count.

Response also carries `refreshToken: true` on approval — custom claims only
reach the ID token on refresh.

## Score scales

Three, not one, each named and part of the `ThresholdSet` type:

- `rekognition-confidence-0-100` — spec §3's four numbers. **Never active.**
  Kept only so the guard has a second scale to refuse.
- `sface-cosine-mapped-0-100` — the face match.
- `selfhosted-challenge-composite-0-100` — liveness.

`ThresholdSet.for_providers` raises `ThresholdScaleMismatch` rather than judging
a score on the wrong scale. Two real instances of this bug have now been found.

1. `config.py` described `match_pass = 80` as "cosine ~0.45" when the mapping
   puts 0.45 at 72.5. Caught by a test.
2. `SelfHostedLiveness.score_scale` declared `sface-cosine-mapped-0-100` while
   `THRESHOLDS_SELF_HOSTED.liveness_scale` has always been
   `selfhosted-challenge-composite-0-100`. `pipeline.run` reads the scale off
   the live provider, so **every real verification reaching step 8 would have
   raised `ThresholdScaleMismatch` and failed**, while the suite stayed green
   because its tests build `Signals` with matching scales by hand. The guard was
   working; the wiring was aimed at ourselves. Fixed, plus five tests that take
   the scale straight off the live provider objects.

## Not implemented, and why

- **Printed birth-date cross-check** (§2 step 3). The decision path exists and
  is now classified as a bad read before it is a flag; extracting a printed date
  from OCR does not exist. It needs a survey of how the date is actually laid
  out on real cards, in both scripts, before a parser is worth writing. Guessing
  a format would produce false flags on genuine cards.
- **Reviewer allowlist** (§5, for App/Play review). Needs the uid of a real
  review account, which does not exist.

## §3's FLAG list, re-classified

Set by the owner, 25 September 2026: flag anything that might be suspicious,
without reviewing every application. Those are only compatible if fewer things
flag at all. The test applied to every signal: **would a human learn something a
retake would not?** Review here is a live video call with a woman reviewer and
no image exists by the time she dials in, so a reviewer learns a great deal
about who someone is and nothing about how a card photographed.

| §3 FLAG signal | Now | Where |
|---|---|---|
| digit 13 and the printed النوع disagree | FLAG, unchanged | `decisions._early`, `_score_stage` |
| the same `id_hmac` failed more than twice across accounts | FLAG, unchanged | `decisions._score_stage` |
| one install tried more than two different `id_hmac` values | FLAG, unchanged | `decisions._score_stage` |
| liveness confidence between FLAG and PASS | **retake while attempts remain**, FLAG once used | `decisions._score_stage` |
| similarity between FLAG and PASS | **retake while attempts remain**, FLAG once used | `decisions._score_stage` |
| the النوع word is unreadable after retries | FLAG, and the retry now applies whichever way digit 13 reads | `decisions._early` |
| the printed birth date disagrees with the encoded date | **retake while OCR retries remain**, FLAG once used | `decisions._early`, `_score_stage` |
| the governorate code is unknown | **recorded and counted, no review at all** | `decisions._score_stage` |

Nothing that used to be refused is now approved: a band score never approves on
any attempt, and every deferred flag still fires once the free remedy is
exhausted. What an attacker gains from each downgrade is tabulated in
VERIFICATION_REPORT.md and argued again at each line in `decisions.py`.

`Signals.sex_word_retries_exhausted` was renamed `ocr_retries_exhausted`, because
it now gates two bad-read signals rather than one and it was always computed
from the OCR submission budget.

## Thresholds

| Dial | Spec §3 start | Previous | Now | Unit |
|---|---|---|---|---|
| `MATCH_PASS` | 90 | 72.5 (cosine 0.45) | **71.0 (cosine 0.42)** | mapped SFace cosine |
| `MATCH_FLAG` | 75 | 64.0 (cosine 0.28) | **64.0 (cosine 0.28)** | mapped SFace cosine |
| `LIVENESS_PASS` | 90 | 82.0 | **75.0** | our own challenge composite |
| `LIVENESS_FLAG` | 70 | 55.0 | **55.0** | our own challenge composite |

Spec §3's four numbers are Rekognition confidences and remain unusable here;
they live on in `THRESHOLDS_REKOGNITION`, which is never active and exists so
the scale guard has a second scale to refuse.

Sources, derivations and the queue arithmetic: VERIFICATION_REPORT.md, "The
thresholds, and why" and "Human review volume". Provenance also lives in
`config.py` immediately above the values, and
`calibrated_from` opens with PROVISIONAL because none of the four has been
measured on an Egyptian card photographed on an Egyptian phone.
