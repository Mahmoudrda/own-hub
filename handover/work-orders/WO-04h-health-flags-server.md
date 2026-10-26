# WO-04h: health, pregnancy and eating-history flags that hold plans until the coach has read them (C9, server)
Depends on: none (WO-04d reads `healthReviewedAt`; step 7 here updates its check)
Size: M
Reads first: `functions/coaching/subscriptions.py` lines 25-75 (`HEALTH_KEYS`, `intake_of`) and 300-335 (the request, `auto`); `functions/coaching/plans.py` lines 257-330 (`publish`); `functions/coaching/errors.py` (whole, reasons list around lines 20-70); `functions/main.py` lines 1798-1818 (callable pattern) and the publish callable (`grep -n "plans.publish" functions/main.py`); `functions/tests/test_coaching_plans.py` first 60 lines

## Why
Most of C9 exists: the join sheet (`app/lib/features/private_coaching/presentation/member/join_coach_sheet.dart`) asks seven PAR-Q style yes/no questions (heart, chest pain, dizziness, long-term condition, daily medication, bone or joint problem, doctor said supervised only: `HEALTH_KEYS`, `coaching_contract.json` `healthQuestions`), makes the client tick "I will check with my doctor" on any yes (`subscriptions.py:55`), blocks auto-accept on any yes (`subscriptions.py:319`), and K07 (`coach_desk_view.dart:394-406`) shows "Health answers to read first" on the request and sends Accept through the details sheet. What is missing, checked 26 Oct:
1. No question about pregnancy or a baby in the last year (the field `lifeStage` exists in `intake_of`, free text up to 30 characters, but nothing asks it) and none about eating history.
2. A flag does not limit anything after Accept: `plans.publish` (`plans.py:257`) checks only that the subscription is active, so Rahma can send a workout or a meal plan to a flagged client without reading her answers.
3. There is no record that she read them.
This order does the server half. WO-04i does the app half. Old builds (1.0.0) send neither new field, so both are optional and default to "no flag".

## Final result
- Intake accepts two optional things: `lifeStage` set by the new question to `"pregnant"` or `"postpartum"` (anything else keeps today's meaning), and `eatingHistory` true/false (default false).
- A subscription is FLAGGED when any health answer is yes, or `lifeStage` is `pregnant` or `postpartum`, or `eatingHistory` is true. A flagged request needs `doctorAck` (as today for health) and never auto-accepts.
- New callable `review_client_health` `{subId}` -> `{ok: true}`: the coach of that subscription records `healthReviewedAt` (server time) and `healthReviewedBy` (her uid). Idempotent.
- `plans.publish` refuses a flagged subscription with no `healthReviewedAt`: code `FAILED_PRECONDITION` (existing PRECONDITION), reason `health_not_reviewed`. Both workout and meal plans. Live sessions and chat are not blocked.
- The coach's "Needs attention" list (WO-04d) uses the same flagged rule.
- Nutrition: coach plans already carry no calories or macros (`plans.py:54 NUTRITION_KEYS` is refused). The client-side calorie target must not be shown for `eatingHistory` (owned by task F3 in the production plan, Phase 3); this order stores the flag so F3 can read it: `subscriptions/{subId}.intake.eatingHistory`.

## Files to edit or create
| path | action | what changes |
|---|---|---|
| `functions/coaching/errors.py` | edit | `HEALTH_NOT_REVIEWED` |
| `functions/coaching/subscriptions.py` | edit | `intake_of`, `intake_flagged`, auto-accept rule, `review_health` |
| `functions/coaching/plans.py` | edit | refuse in `publish` |
| `functions/main.py` | edit | callable `review_client_health` |
| `functions/coaching/checkins.py` | edit | use `intake_flagged` |
| `contracts/coaching_contract.json` and `functions/coaching/coaching_contract.json` | edit (identical) | reason, callable name |
| `functions/tests/test_coaching_health_flags.py` | create | tests |

## Steps
1. `errors.py`: next to `WRONG_STATUS = "wrong_status"` (line 62) add `HEALTH_NOT_REVIEWED = "health_not_reviewed"`. If the file also keeps a list or set of all reasons (UNVERIFIED: `grep -n "WRONG_STATUS" functions/coaching/*.py functions/tests/*.py`), add it there too.
2. `subscriptions.py`, directly under `HEALTH_KEYS = ...` (line 25) add:
```python
FLAGGED_STAGES = ("pregnant", "postpartum")


def intake_flagged(intake: dict) -> bool:
    """Anything that makes her coach read her answers before a plan goes out."""
    return (
        any((intake.get("health") or {}).values())
        or intake.get("lifeStage") in FLAGGED_STAGES
        or intake.get("eatingHistory") is True
    )
```
3. Same file, `intake_of`: replace
```python
    ack = raw.get("doctorAck", False)
    if not isinstance(ack, bool):
        raise common.bad()
    if any(health.values()) and not ack:
        raise common.bad()
```
with
```python
    ack = raw.get("doctorAck", False)
    if not isinstance(ack, bool):
        raise common.bad()
    eating = raw.get("eatingHistory", False)
    if not isinstance(eating, bool):
        raise common.bad()
```
and move the ack rule below the point where `life_stage` is read (after the `life_stage = ...` block), then:
```python
    flagged = (
        any(health.values())
        or life_stage in FLAGGED_STAGES
        or eating
    )
    if flagged and not ack:
        raise common.bad()
```
In the returned dict add `"eatingHistory": eating,` after `"lifeStage": life_stage,`.
4. Same file, the `auto = (` expression (about line 316-321): replace `and not any(intake["health"].values())` with `and not intake_flagged(intake)`.
5. Same file, new function at the end of the module (match the style of the other coach functions, e.g. `_warn`):
```python
def review_health(db, uid: str, data: dict, *, live: bool, coach_v, now: dt.datetime) -> dict:
    """The coach records that she has read the client's health answers."""
    common.require_clients_live(live)
    common.require_active_coach(db, uid, coach_v)
    sub_id = _id(data.get("subId"))
    ref = db.collection("subscriptions").document(sub_id)

    def body(transaction):
        sub = common.read(ref, transaction)
        if sub is None or sub.get("coachUid") != uid:
            raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
        if not sub.get("healthReviewedAt"):
            transaction.update(ref, {"healthReviewedAt": now, "healthReviewedBy": uid})
        return {"ok": True}

    return common.run(db, body)
```
(`_id`, `common.*`, `errors.*` are the ones already used in this file; `dt` is imported at the top: UNVERIFIED, `grep -n "^import\|^from" functions/coaching/subscriptions.py | head`.)
6. `plans.py`, function `publish`, inside `txn` after the `if sub.get("status") != "active": ...` lines (about line 291) add:
```python
        intake = sub.get("intake") or {}
        if subscriptions.intake_flagged(intake) and not sub.get("healthReviewedAt"):
            raise common.refuse(errors.PRECONDITION, errors.HEALTH_NOT_REVIEWED)
```
`subscriptions` is already used in `plans.py` (`subscriptions.blocked_either`, line ~286), so it is imported.
7. `checkins.py` (WO-04d), in `needs_attention`, replace
```python
        if any((intake.get("health") or {}).values()) and not row.get("healthReviewedAt"):
```
with
```python
        if subscriptions.intake_flagged(intake) and not row.get("healthReviewedAt"):
```
and add `from . import subscriptions` to its imports. (If WO-04d is not done yet, put this in your report and skip.)
8. `functions/main.py`, after `accept_coach_invite`:
```python
@https_fn.on_call()
def review_client_health(request: https_fn.CallableRequest) -> dict:
    """C9: the coach has read this client's health answers. `{subId}`."""
    uid = _require_auth(request)
    data = _body(request)
    import datetime as dt

    import coaching
    from coaching import subscriptions

    return _coaching_call(
        subscriptions.review_health,
        store.db(),
        uid,
        data,
        live=coaching.COACH_CLIENTS_LIVE,
        coach_v=_claim(request, "coachV"),
        now=dt.datetime.now(dt.timezone.utc),
    )
```
9. Both contract JSON files: add `"health_not_reviewed"` where the reasons list holds `"wrong_status"` (UNVERIFIED location: `grep -n "wrong_status" contracts/coaching_contract.json`) and keep the two files identical; add callable `review_client_health` wherever `create_coach_invite` is listed (`grep -n "create_coach_invite" contracts/coaching_contract.json`). Mirror the reason in `app/lib/features/private_coaching/domain/coaching_contract.dart` as `healthNotReviewed('health_not_reviewed'),` after `wrongStatus('wrong_status'),` (line 625) and in its reasons list if one exists. Then `cd app && flutter test test/contracts/coaching_contract_test.dart`.

## Strings to add
None (server). App strings are in WO-04i.

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| `functions/tests/test_coaching_health_flags.py` | `intake_flags_by_stage_and_eating_history` | `intake_of` with all-false health and `lifeStage: "pregnant"` and `doctorAck: False` raises; with ack True returns `lifeStage "pregnant"` and `eatingHistory False`; `eatingHistory: True` without ack raises; `eatingHistory: "yes"` raises; old shape (no new keys) returns `eatingHistory False` |
| same | `a flagged request is never auto accepted` | coach with `autoAccept` true; client intake `eatingHistory` true with ack: subscription stays `requested` (copy the arrangement from `test_coaching_free.py` for an auto-accepting coach) |
| same | `publish refuses a flagged client until the coach has read her answers` | active subscription with `intake.lifeStage = "postpartum"`; `plans.publish(...)` raises `(errors.PRECONDITION, errors.HEALTH_NOT_REVIEWED)` for kind workout and for kind meal; after `review_health` it succeeds |
| same | `an unflagged client is never held` | health all false, no stage, no eating history: publish succeeds with no review |
| same | `only her own coach can mark it read, and twice is fine` | another coach uid -> `(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)`; own coach twice -> `ok`, `healthReviewedAt` unchanged the second time |
Use `refusal(...)` and the `_txn` fixture from `tests/coaching_helpers.py`. Run: `cd functions && python3 -m pytest tests/test_coaching_health_flags.py tests/test_coaching_plans.py tests/test_coaching_free.py tests/test_coaching_contract.py -q`

## Verify
- That command prints `passed` and no `failed`.
- `cd app && flutter test test/contracts/coaching_contract_test.dart` passes.

## Do not
- Do not make the new fields required (build 1.0.0 would stop being able to ask to join). Do not block chat or live sessions. Do not weaken the doctor tick. Do not deploy; deploy order is in `docs/owner/LAUNCH-GUIDE.md` (functions first).
- Do not let a client write `healthReviewedAt` (only this callable; check `firebase/firestore.rules` subscriptions match stays server-write: UNVERIFIED, `grep -n "subscriptions" firebase/firestore.rules`).

## Done checklist
- [ ] intake + flagged + auto rule
- [ ] publish gate + review callable
- [ ] contract copies identical, Dart enum updated
- [ ] tests pass

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
