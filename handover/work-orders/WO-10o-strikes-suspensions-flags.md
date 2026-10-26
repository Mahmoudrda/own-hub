# WO-10o: Strikes, suspensions, dispute-rate flags and two-staff approval
Depends on: WO-10b4, WO-10n
Size: L
Reads first: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` 4.1, 4.2, 4.11, 13.5, 13.6, 13.7; `functions/payments/staff.py` (`resolve`, the `on_decision` hook); `functions/payments/profile.py`; `functions/coaching/claims.py` lines 27-46 (`suspend`, the older coach suspension, for the style of a suspension record); `functions/coaching/common.py` lines 238-262; `functions/main.py` (the `staff_resolve_payment` wrapper added by WO-10b4)

## Why
Rules without consequences do not stop fraud. A coach who loses a "not received" dispute gets a strike automatically; a client whose proof staff find false gets one; two strikes in 90 days remove the client's InstaPay payments at once and flag the coach, whose suspension is a staff decision recorded with a reason and approved by two different staff. A coach's rate of lost disputes is tracked and flagged over a threshold. Strikes attach to the woman (every account is a verified woman, 13.7), so a new account does not wipe a record. A decision a second reviewer reverses removes its strike.

## Final result
No screen for staff here (the dashboard is another order). Server behaviour:
- After `staff_resolve_payment`: `resolved_paid` on a `not_received` dispute = a coach strike (`lost_dispute`) and her `disputesLost` +1; `resolved_unpaid` on a `not_received` or `proof_red` dispute with `proofFalse: true` = a client strike (`false_proof`); `reopen` reverses the strikes of that payment. Her `paymentsConfirmed` counts every payment that reached access.
- Two live strikes (not reversed, inside 90 days) for a client: `paymentStanding/{uid}.clientSuspended = true` and a push `instapayPaused`. For a coach: `coachFlagged = true`; nothing else happens until two staff approve.
- Dispute rate: with at least 10 confirmed payments (owner-tunable in `coachingConfig/instapay`: `disputeRateMinPayments`, `disputeRatePercent`) and lost disputes at or over 10 percent of them, `coachFlagged = true`, `flagReason = "disputeRate"`.
- Callables `staff_set_coach_payment_status` `{coachUid, action: "suspend"|"lift", reason (10 to 500)}` and `staff_list_payment_flags` `{}`.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `functions/payments/strikes.py` | create | strikes, standing, rate, suspension |
| `functions/main.py` | edit | two callables, `_payments_after_decision`, wire it into `staff_resolve_payment` |
| `functions/tests/test_entrypoints.py` | edit | two names and one claim test |
| `functions/tests/test_payments_strikes.py` | create | tests |

## Steps
1. File `functions/payments/strikes.py`, create:
```python
"""Strikes, suspensions and the dispute rate (spec 13.5, 13.6, 13.7)."""

from __future__ import annotations

import datetime as dt
from typing import Optional

from google.cloud import firestore

from coaching import common

from . import errors, model, profile

LIMITS = model.LIMITS
APPROVALS_NEEDED = 2
PROPOSAL_DAYS = 7


def strike_id(payment_id: str, role: str) -> str:
    return f"{payment_id}__{role}"


def rate_flag(confirmed: int, lost: int, minimum: int, percent: int) -> bool:
    """True when she has at least `minimum` payments and `lost` is `percent`
    percent or more of `confirmed` (integers only, no float)."""
    return confirmed >= minimum and confirmed > 0 and lost * 100 >= percent * confirmed


def live_strikes(transaction, db, uid: str, role: str, now: dt.datetime, *, skip: Optional[str] = None) -> int:
    """Strikes of this woman in this role inside the window and not reversed.
    `skip` is a strike id not to count (the one being written again)."""
    since = now - model.days(LIMITS["strikeWindowDays"])
    query = db.collection("paymentStrikes").where("uid", "==", uid).where("role", "==", role).where("at", ">=", since)
    return sum(1 for s in query.stream(transaction=transaction)
               if not (s.to_dict() or {}).get("reversedAt") and s.id != skip)


def after_decision(db, payment_id: str, *, outcome: str, kind: Optional[str], proof_false: bool,
                   now: dt.datetime, notify) -> None:
    """Called by staff.resolve after its transaction commits. Idempotent: a
    strike has one document per payment and role."""
    pay_ref = db.collection("payments").document(payment_id)
    cfg = model.config(db)
    notices = []

    def body(transaction):
        pay = common.read(pay_ref, transaction)
        if pay is None:
            return
        if outcome == "reopen":
            for role in ("coach", "client"):
                doc = db.collection("paymentStrikes").document(strike_id(payment_id, role))
                row = common.read(doc, transaction)
                if row is not None and not row.get("reversedAt"):
                    transaction.update(doc, {"reversedAt": now})
                    if role == "coach":
                        transaction.update(profile.profile_ref(db, pay["coachUid"]), {"disputesLost": firestore.Increment(-1)})
            return
        role = uid = reason = None
        if outcome == "resolved_paid" and kind == "not_received":
            role, uid, reason = "coach", pay["coachUid"], "lost_dispute"
        elif outcome == "resolved_unpaid" and kind in ("not_received", "proof_red") and proof_false:
            role, uid, reason = "client", pay["clientUid"], "false_proof"
        prof_ref = profile.profile_ref(db, pay["coachUid"])
        prof = common.read(prof_ref, transaction) or {}
        standing_ref = profile.standing_ref(db, uid) if uid else None
        doc = db.collection("paymentStrikes").document(strike_id(payment_id, role)) if role else None
        existing = common.read(doc, transaction) if doc is not None else None
        others = live_strikes(transaction, db, uid, role, now, skip=strike_id(payment_id, role)) if role else 0

        confirmed, lost = prof.get("paymentsConfirmed", 0), prof.get("disputesLost", 0)
        counters = {}
        if outcome == "resolved_paid":
            counters["paymentsConfirmed"] = firestore.Increment(1)
            confirmed += 1
        if role == "coach" and existing is None:
            counters["disputesLost"] = firestore.Increment(1)
            lost += 1
        if counters:
            transaction.update(prof_ref, counters)
        if role and existing is None:
            transaction.set(doc, {"uid": uid, "role": role, "paymentId": payment_id, "reason": reason, "at": now})
            total = others + 1
            field = "clientStrikes" if role == "client" else "coachStrikes"
            changes = {field: total}
            if total >= LIMITS["strikesToSuspend"]:
                if role == "client":
                    changes.update(clientSuspended=True, clientSuspendedAt=now)
                    notices.append((uid, "instapayPaused"))
                else:
                    changes.update(coachFlagged=True, flagReason="twoStrikes", flaggedAt=now)
            transaction.set(standing_ref, changes, merge=True)
        if rate_flag(confirmed, lost, cfg["disputeRateMinPayments"], cfg["disputeRatePercent"]):
            transaction.set(profile.standing_ref(db, pay["coachUid"]),
                            {"coachFlagged": True, "flagReason": "disputeRate", "flaggedAt": now}, merge=True)

    common.run(db, body)
    for uid, kind_ in notices:
        try:
            notify(uid, kind_)
        except Exception:  # noqa: BLE001
            pass


def set_coach_status(db, actor: str, data: dict, *, now: dt.datetime, notify) -> dict:
    """Suspend needs two different staff within 7 days, each with a reason.
    Lifting needs one. A suspension stops NEW payments only: running coachings
    are never cut off (4.11); staff decide those one by one."""
    coach_uid = common.text(data.get("coachUid"), max_len=128)
    action = common.one_of(data.get("action"), ("suspend", "lift"))
    reason = common.text(data.get("reason"), min_len=10, max_len=500, reason=errors.REASON_REQUIRED)
    common.refuse_if_subject(actor, coach_uid)
    common.log_access(db, actor, f"payments.coach.{action}", coach_uid, now)
    standing_ref = profile.standing_ref(db, coach_uid)
    prof_ref = profile.profile_ref(db, coach_uid)
    coach_ref = db.collection("coaches").document(coach_uid)
    proposal_ref = db.collection("paymentAlerts").document(f"suspend__{coach_uid}")
    who = common.staff_ref(actor)
    state = {}

    def body(transaction):
        standing = common.read(standing_ref, transaction) or {}
        prof = common.read(prof_ref, transaction)
        coach = common.read(coach_ref, transaction)
        proposal = common.read(proposal_ref, transaction) or {}
        if prof is None:
            raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
        suspended = bool(standing.get("coachSuspended"))
        if action == "lift":
            if not suspended:
                return {"status": "active"}
            transaction.set(standing_ref, {"coachSuspended": False, "coachFlagged": False, "liftedAt": now}, merge=True)
            transaction.update(prof_ref, {"status": "ok"})
            if coach is not None:
                transaction.update(coach_ref, {"instapayReady": bool(prof.get("address"))})
            transaction.set(proposal_ref, {"closed": True, "at": now, "liftedBy": who, "reasonText": reason})
            return {"status": "active"}
        if suspended:
            return {"status": "suspended"}
        fresh = common.as_utc(proposal.get("at")) and now <= common.as_utc(proposal["at"]) + model.days(PROPOSAL_DAYS) and not proposal.get("closed")
        approvals = list(proposal.get("approvals") or []) if fresh else []
        if who in approvals:
            raise common.refuse(errors.PRECONDITION, errors.SAME_STAFF)
        approvals.append(who)
        if len(approvals) < APPROVALS_NEEDED:
            transaction.set(proposal_ref, {"type": "suspend", "coachRef": common.staff_ref(coach_uid), "approvals": approvals,
                                           "at": now if not fresh else proposal["at"], "reasons": list(proposal.get("reasons") or []) + [reason] if fresh else [reason]})
            return {"status": "awaiting_second_approval"}
        transaction.set(standing_ref, {"coachSuspended": True, "coachSuspendedAt": now, "coachFlagged": False}, merge=True)
        transaction.update(prof_ref, {"status": "suspended"})
        if coach is not None:
            transaction.update(coach_ref, {"instapayReady": False})
        transaction.set(proposal_ref, {"type": "suspend", "closed": True, "approvals": approvals, "at": now,
                                       "reasons": list(proposal.get("reasons") or []) + [reason] if fresh else [reason]})
        state["suspended"] = True
        return {"status": "suspended"}

    result = common.run(db, body)
    if state.get("suspended"):
        try:
            notify(coach_uid, "instapaySuspended")
        except Exception:  # noqa: BLE001
            pass
    return result


def list_flags(db, actor: str, data: dict, *, now: dt.datetime) -> dict:
    """Flagged women, open suspension proposals and address-change alerts, newest first."""
    common.log_access(db, actor, "payments.flags", "flags", now)
    flagged = [{"uid_ref": common.staff_ref(s.id), "uid": s.id, **{k: common.plain(v) for k, v in (s.to_dict() or {}).items()
               if k in ("coachFlagged", "flagReason", "flaggedAt", "coachStrikes", "clientStrikes", "clientSuspended", "coachSuspended")}}
               for s in db.collection("paymentStanding").stream() if (s.to_dict() or {}).get("coachFlagged") or (s.to_dict() or {}).get("clientSuspended")]
    alerts = []
    for s in db.collection("paymentAlerts").stream():
        row = s.to_dict() or {}
        if row.get("closed"):
            continue
        alerts.append({"id": s.id, **{k: common.plain(v) for k, v in row.items()}})
    alerts.sort(key=lambda a: str(a.get("at")), reverse=True)
    return {"flagged": flagged[:100], "alerts": alerts[:100]}
```
(The `reasons` expression `list(...) + [reason] if fresh else [reason]` binds as `(list(...) + [reason]) if fresh else [reason]`, which is what is wanted. Write it with explicit parentheses in the file to be safe.)
2. File `functions/main.py`. (i) Anchor: `_payments_notify` (WO-10b2). After it add:
```python
def _payments_after_decision(db, payment_id, **kwargs) -> None:
    """Strikes and counters after a staff decision. A failure is logged and
    never undoes the decision (the strike is idempotent, a retry via reopen repairs it)."""
    from payments import strikes

    try:
        strikes.after_decision(db, payment_id, **kwargs)
    except Exception:
        logs.error("payments_after_decision_failed")
```
   (ii) In `staff_resolve_payment` (WO-10b4) change the call to `staff.resolve, store.db(), actor, data, now=_coaching_now(), notify=_payments_notify, on_decision=_payments_after_decision`.
   (iii) After `staff_resolve_payment` add:
```python
@https_fn.on_call()
def staff_set_coach_payment_status(request: https_fn.CallableRequest) -> dict:
    actor = _require_woman_reviewer(request, allow_admin=True)
    data = _body(request)
    from payments import strikes

    return _coaching_call(strikes.set_coach_status, store.db(), actor, data, now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def staff_list_payment_flags(request: https_fn.CallableRequest) -> dict:
    actor = _require_woman_reviewer(request, allow_admin=True)
    data = _body(request)
    from payments import strikes

    return _coaching_call(strikes.list_flags, store.db(), actor, data, now=_coaching_now())
```
3. File `functions/tests/test_entrypoints.py`: add `"staff_set_coach_payment_status", "staff_list_payment_flags",` to `CALLABLES`, and the test:
```python
@pytest.mark.parametrize("name", ["staff_set_coach_payment_status", "staff_list_payment_flags"])
def test_the_payment_flag_callables_refuse_a_member(name, stubbed):
    raises(lambda: inner(name)(request({})), https_fn.FunctionsErrorCode.PERMISSION_DENIED)
```
4. File `functions/tests/test_payments_strikes.py`, create. Helper `decide(db, outcome, kind, proof_false=False, now=NOW, notes=None)` = `strikes.after_decision(db, PAY, outcome=..., kind=..., proof_false=..., now=now, notify=notes or Notes())`. The payment is `make_payment(db, status="resolved_paid")` and `seed_world(db)`.
| test | arrange, act, assert |
|---|---|
| `test_rate_flag_is_integer_maths` | `(10, 1, 10, 10)` True; `(9, 9, 10, 10)` False (too few payments); `(20, 1, 10, 10)` False; `(10, 0, 10, 10)` False; `(0, 0, 10, 10)` False |
| `test_a_lost_not_received_dispute_strikes_the_coach_once` | `decide("resolved_paid", "not_received")` twice -> one strike doc `pay-1__coach` with reason `lost_dispute`, `coachStrikes == 1`, profile `disputesLost == 1` and `paymentsConfirmed` up by exactly 1 (the second call changes nothing; see step 5) |
| `test_a_paid_service_dispute_is_not_a_strike` | `decide("no_refund", "service")`, `decide("resolved_paid", "proof_red")` -> no strike docs |
| `test_false_proof_strikes_the_client_only_when_staff_say_so` | `resolved_unpaid`, kind `not_received`, `proof_false=False` -> none; `True` -> client strike `false_proof` |
| `test_two_client_strikes_in_90_days_pause_her_payments_and_tell_her` | strikes on two payments `pay-1`, `pay-2` -> `clientSuspended True`, push `instapayPaused`; a third `create_payment` is refused `CLIENT_PAYMENTS_SUSPENDED` |
| `test_the_second_strike_after_91_days_does_not_count` | first at NOW, second at NOW+91 days -> `clientStrikes == 1`, not suspended |
| `test_two_coach_strikes_flag_but_do_not_suspend` | two lost disputes -> `coachFlagged True`, `flagReason == "twoStrikes"`, `coachSuspended` absent, her existing running subscription untouched |
| `test_dispute_rate_flags_a_coach_over_the_threshold` | profile `paymentsConfirmed 9, disputesLost 0`; one lost dispute -> confirmed 9 (no paid increment on a strike path? the paid outcome adds 1) so 10 payments and 1 lost = 10 percent -> flagged `disputeRate`; with `coachingConfig/instapay.disputeRatePercent = 20` -> not flagged |
| `test_reopen_reverses_the_strike_and_the_lost_count` | strike, then `decide("reopen", "not_received")` -> strike doc has `reversedAt`, `disputesLost == 0`; a later strike for another payment counts again from zero |
| `test_suspend_needs_two_different_staff` | `set_coach_status(REVIEWER, suspend)` -> `awaiting_second_approval`, `coachSuspended` absent; the same reviewer again -> `(PRECONDITION, SAME_STAFF)`; `REVIEWER2` -> `suspended`, `coachSuspended True`, profile `status suspended`, `coaches/COACH.instapayReady False`, push `instapaySuspended`; the alert doc holds both reasons and short refs, no uid |
| `test_a_stale_proposal_restarts_after_7_days` | first approval at NOW, second by another at NOW+8 days -> `awaiting_second_approval` again |
| `test_reason_and_subject_rules` | reason `"short"` -> `REASON_REQUIRED`; actor equals the coach -> `STAFF_IS_SUBJECT`; unknown coach -> `PAYMENT_NOT_FOUND` |
| `test_lift_needs_one_staff_and_restores_the_address_flag` | suspended -> `lift` by one -> `coachSuspended False`, profile `ok`, `instapayReady True`; lifting an active coach is harmless |
| `test_a_suspended_coach_cannot_take_a_new_payment_but_the_running_one_can_be_resolved` | suspended: `create.create` -> `COACH_PAYMENTS_SUSPENDED`; an existing `in_review` payment of hers can still be resolved by staff (`staff.resolve` works) |
| `test_list_flags_shows_flagged_women_and_open_alerts_only` | one flagged standing, one closed alert, one open alert -> the answer has one and one; the read is logged |
5. Counting each paid payment once. File `functions/payments/strikes.py`: in `after_decision`, replace the block
```python
        if outcome == "resolved_paid":
            counters["paymentsConfirmed"] = firestore.Increment(1)
            confirmed += 1
```
with (and add the line `counted_ref = pay_ref.collection("staff").document("counted")` before it, and `counted = common.read(counted_ref, transaction)` among the reads above it):
```python
        if outcome == "resolved_paid" and counted is None:
            counters["paymentsConfirmed"] = firestore.Increment(1)
            confirmed += 1
            transaction.set(counted_ref, {"at": now})
```
   (All reads must stay before the first write: put the `counted_ref` and `counted` lines next to the other reads, above the first `transaction.update`.)
Command: `cd functions && venv/bin/python -m pytest tests/test_payments_strikes.py tests/test_entrypoints.py tests/test_payments_staff.py -q`

## Strings to add
None. Push kinds used: `instapayPaused` (client), `instapaySuspended` (coach), both defined in WO-10a2. Standing fields the app reads from `paymentStanding/{uid}`: `clientSuspended`, `coachSuspended`, `clientStrikes`, `coachStrikes`.

## Tests to add or change
As above.

## Verify
The command ends with `N passed`, no `failed`.

## Do not
- Do not suspend a coach on one person's say. Do not let the same staff member approve twice.
- Do not cut off running coachings when a coach is suspended.
- Do not put a uid or a typed reason into the alert document's public-looking fields: only short refs and reason text, and the whole collection is closed to clients (WO-10a).
- Do not count a strike twice for one payment, and do not keep a strike a second reviewer reversed.

## Done checklist
- [ ] strikes.py created, main edited and wired into `staff_resolve_payment`
- [ ] two callables registered and listed
- [ ] all tests pass

## If stuck
Anchor missing or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
