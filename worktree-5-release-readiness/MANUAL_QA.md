# MANUAL QA

Spec §9.7 and §9.8. **NOTHING IN THIS FILE HAS BEEN EXECUTED.**

Every row is NOT EXECUTED. This is a checklist for a human with real devices and
real cards, not a record of results. Fill the Result column in; do not delete
rows that fail.

Before starting: the backend is not deployed. These require a staging deploy,
App Check provisioned, and the Secret Manager grant in place (DECISIONS_NEEDED
D8).

---

## §9.7 Device end-to-end

| # | Case | Expected | Result |
|---|---|---|---|
| 1 | Low-end Android, 2-3 GB RAM | Full flow completes. Watch for an OOM during frame capture; the server downscales but the client holds several frames at once. | NOT EXECUTED |
| 2 | Mid-range Android | Full flow completes | NOT EXECUTED |
| 3 | Oldest supported iOS | Full flow completes | NOT EXECUTED |
| 4 | Current iPhone | Full flow completes | NOT EXECUTED |
| 5 | Arabic locale, RTL | Every screen correct RTL; challenge prompts legible | NOT EXECUTED |
| 6 | English locale | As above | NOT EXECUTED |
| 7 | Low light | Either completes or returns `retake_*`; never a silent failure | NOT EXECUTED |
| 8 | Strong glare on the card | Expect `RETRY_CAPTURE`. Glare over the portrait is the commonest real failure | NOT EXECUTED |
| 9 | Airplane mode mid-flow | Honest error; no charge recorded; attempts not consumed | NOT EXECUTED |
| 10 | Kill the app during the challenge | Session is single-use; a restart must mint a NEW session, not reuse | NOT EXECUTED |
| 11 | Deny then grant camera permission | Recovers without a dead end | NOT EXECUTED |

## §9.8 Adversarial

Each needs a pass/fail before launch.

| # | Attack | Expected | Result |
|---|---|---|---|
| 1 | A man with his own card | `REJECTED_NOT_ELIGIBLE`. **Also assert: zero liveness and zero face-match calls, spend exactly $0.003** | NOT EXECUTED |
| 2 | A man with a consenting female colleague's card | Face match fails → `RETRY_CAPTURE`, then `REJECTED_FAILED`. **The case the threshold exists for** | NOT EXECUTED |
| 3 | A printed photo held to liveness | Fail. Yaw spread is what it cannot cross | NOT EXECUTED |
| 4 | A video of a woman replayed on a phone screen | **Expect this to be the hardest one.** RESIDUAL_RISKS #6 says a prepared attacker who fetched the challenge first can beat it | NOT EXECUTED |
| 5 | The ID shown on a screen, not the physical card | Not specifically detected. Record what happens | NOT EXECUTED |
| 6 | A photocopy of the ID | Likely passes OCR; the face match still has to succeed | NOT EXECUTED |
| 7 | A modified client sending "approved" | No effect. Decision is server-side | NOT EXECUTED |
| 7b | A modified client sending `liveness.outcome = "pass"` | No effect. Field is ignored | NOT EXECUTED |
| 8 | Two accounts, same card | Second gets `REJECTED_DUPLICATE` | NOT EXECUTED |
| 9 | A woman whose card photo is many years old | **The false-reject case that matters most.** Expect the uncertain band → review | NOT EXECUTED |
| 10 | Glasses | Should pass. Note the effect on the blink proxy | NOT EXECUTED |
| 11 | Hijab in the selfie, not on the card (and the reverse) | Expect lower similarity. Record the scores; this directly informs the threshold | NOT EXECUTED |
| 12 | Niqab flow | Routes to `PENDING_REVIEW` with `niqab_path_requested`, makes no face-match call, and the copy explains respectfully that the face must be visible privately for a few seconds and nothing is stored | NOT EXECUTED |

## Additions not in the spec, worth running

| # | Case | Why |
|---|---|---|
| 13 | A woman born abroad, governorate 88 | Common among Egyptian women born in the Gulf, and invisible to anyone testing only in Cairo |
| 14 | A card with a governorate code not in our list | Must FLAG, never reject |
| 15 | A woman born on 29 February | Leap-year handling |
| 16 | A woman whose 18th birthday is today | MIN_AGE boundary; she must pass |
| 17 | Re-verify on a new phone after reinstalling | Must be a re-verification, not a duplicate |
| 18 | Two women in one household, one phone | Must not trip the install flag at 2 |
| 19 | A card back photographed too dark to read النوع | Should ask for a retake first, and only FLAG after the attempts are used |
