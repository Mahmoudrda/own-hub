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
    `skip` is a strike id not to count (the one being written or reversed)."""
    since = now - model.days(LIMITS["strikeWindowDays"])
    query = db.collection("paymentStrikes").where("uid", "==", uid).where("role", "==", role).where("at", ">=", since)
    return sum(1 for s in query.stream(transaction=transaction) if not (s.to_dict() or {}).get("reversedAt") and s.id != skip)


def _standing_changes(role: str, total: int, now: dt.datetime, *, suspend: bool) -> dict:
    """The standing fields for `total` live strikes. At the limit a client is
    paused at once; a coach is only flagged for two staff to decide (13.5)."""
    if role == "client":
        return {"clientStrikes": total, **({"clientSuspended": True, "clientSuspendedAt": now} if suspend else {})}
    return {"coachStrikes": total, **({"coachFlagged": True, "flagReason": "twoStrikes", "flaggedAt": now} if suspend else {})}


def after_decision(db, payment_id: str, *, outcome: str, kind: Optional[str], proof_false: bool,
                   now: dt.datetime, notify) -> None:
    """Called by staff.resolve after its transaction commits. Idempotent: a
    strike has one document per payment and role."""
    pay_ref = db.collection("payments").document(payment_id)
    cfg = model.config(db)
    notices = []

    def reopen(transaction, pay):
        """A second reviewer reopens: the strikes of this payment are reversed and the counts follow."""
        rows = {}
        for role in ("coach", "client"):
            doc = db.collection("paymentStrikes").document(strike_id(payment_id, role))
            rows[role] = (doc, common.read(doc, transaction))
        uids = {"coach": pay["coachUid"], "client": pay["clientUid"]}
        standing = {role: common.read(profile.standing_ref(db, uids[role]), transaction) or {} for role in rows}
        left = {role: live_strikes(transaction, db, uids[role], role, now, skip=strike_id(payment_id, role))
                for role, (_, row) in rows.items() if row is not None and not row.get("reversedAt")}
        for role, (doc, row) in rows.items():
            if role not in left:
                continue
            transaction.update(doc, {"reversedAt": now})
            changes = {"clientStrikes" if role == "client" else "coachStrikes": left[role]}
            if left[role] < LIMITS["strikesToSuspend"]:
                if role == "client" and standing[role].get("clientSuspendedAt"):
                    changes["clientSuspended"] = False  # the pause came from these strikes, not from a person
                if role == "coach" and standing[role].get("flagReason") == "twoStrikes":
                    changes["coachFlagged"] = False
            transaction.set(profile.standing_ref(db, uids[role]), changes, merge=True)
            if role == "coach":
                transaction.update(profile.profile_ref(db, pay["coachUid"]), {"disputesLost": firestore.Increment(-1)})

    def body(transaction):
        pay = common.read(pay_ref, transaction)
        if pay is None:
            return
        if outcome == "reopen":
            reopen(transaction, pay)
            return
        role = uid = reason = None
        if outcome == "resolved_paid" and kind == "not_received":
            role, uid, reason = "coach", pay["coachUid"], "lost_dispute"
        elif outcome == "resolved_unpaid" and kind in ("not_received", "proof_red") and proof_false:
            role, uid, reason = "client", pay["clientUid"], "false_proof"
        prof_ref = profile.profile_ref(db, pay["coachUid"])
        prof = common.read(prof_ref, transaction) or {}
        doc = db.collection("paymentStrikes").document(strike_id(payment_id, role)) if role else None
        existing = common.read(doc, transaction) if doc is not None else None
        counted_ref = pay_ref.collection("staff").document("counted")
        counted = common.read(counted_ref, transaction)
        others = live_strikes(transaction, db, uid, role, now, skip=strike_id(payment_id, role)) if role else 0

        confirmed, lost = prof.get("paymentsConfirmed", 0), prof.get("disputesLost", 0)
        counters = {}
        if outcome == "resolved_paid" and counted is None and not (pay.get("coachDecision") or {}).get("confirmedAt"):
            counters["paymentsConfirmed"] = firestore.Increment(1)  # a payment the coach never confirmed herself, counted once
            confirmed += 1
            transaction.set(counted_ref, {"at": now})
        if role == "coach" and existing is None:
            counters["disputesLost"] = firestore.Increment(1)
            lost += 1
        if counters:
            transaction.set(prof_ref, counters, merge=True)
        if role and existing is None:
            transaction.set(doc, {"uid": uid, "role": role, "paymentId": payment_id, "reason": reason, "at": now})
            total = others + 1
            at_limit = total >= LIMITS["strikesToSuspend"]
            transaction.set(profile.standing_ref(db, uid), _standing_changes(role, total, now, suspend=at_limit), merge=True)
            if at_limit and role == "client":
                notices.append((uid, "instapayPaused"))
        if rate_flag(confirmed, lost, cfg["disputeRateMinPayments"], cfg["disputeRatePercent"]):
            transaction.set(profile.standing_ref(db, pay["coachUid"]),
                            {"coachFlagged": True, "flagReason": "disputeRate", "flaggedAt": now}, merge=True)

    common.run(db, body)
    for target, kind_ in notices:
        try:
            notify(target, kind_)
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
        when = common.as_utc(proposal.get("at"))
        fresh = bool(when is not None and now <= when + model.days(PROPOSAL_DAYS) and not proposal.get("closed"))
        approvals = list(proposal.get("approvals") or []) if fresh else []
        if who in approvals:
            raise common.refuse(errors.PRECONDITION, errors.SAME_STAFF)
        approvals.append(who)
        reasons = (list(proposal.get("reasons") or []) + [reason]) if fresh else [reason]
        if len(approvals) < APPROVALS_NEEDED:
            transaction.set(proposal_ref, {"type": "suspend", "coachRef": common.staff_ref(coach_uid), "approvals": approvals,
                                           "at": proposal["at"] if fresh else now, "reasons": reasons, "closed": False})
            return {"status": "awaiting_second_approval"}
        transaction.set(standing_ref, {"coachSuspended": True, "coachSuspendedAt": now, "coachFlagged": False}, merge=True)
        transaction.update(prof_ref, {"status": "suspended"})
        if coach is not None:
            transaction.update(coach_ref, {"instapayReady": False})
        transaction.set(proposal_ref, {"type": "suspend", "coachRef": common.staff_ref(coach_uid), "closed": True,
                                       "approvals": approvals, "at": now, "reasons": reasons})
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
    keep = ("coachFlagged", "flagReason", "flaggedAt", "coachStrikes", "clientStrikes", "clientSuspended", "coachSuspended")
    flagged = []
    for s in db.collection("paymentStanding").stream():
        row = s.to_dict() or {}
        if row.get("coachFlagged") or row.get("clientSuspended") or row.get("coachSuspended"):  # a suspended coach stays listed so staff can lift
            flagged.append({"uid": s.id, **{k: common.plain(v) for k, v in row.items() if k in keep}})
    coaches = None
    alerts = []
    for s in db.collection("paymentAlerts").stream():
        row = s.to_dict() or {}
        if row.get("closed"):
            continue
        item = {"id": s.id, **{k: common.plain(v) for k, v in row.items()}}
        if row.get("coachRef"):  # the alert holds only a short reference; staff need the woman to act, so match it here
            if coaches is None:
                coaches = {common.staff_ref(c.id): c.id for c in db.collection("coachPaymentProfiles").select([]).stream()}
            item["coachUid"] = coaches.get(row["coachRef"])
        alerts.append(item)
    alerts.sort(key=lambda a: str(a.get("at")), reverse=True)
    return {"flagged": flagged[:100], "alerts": alerts[:100]}
