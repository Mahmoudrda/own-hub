"""Strikes, the dispute rate, suspensions with two staff (WO-10o, spec 13.5, 13.7)."""

from __future__ import annotations

import datetime as dt

import pytest

from coaching import errors as c_errors
from payments import create, errors, staff, strikes
from tests.payments_helpers import (  # noqa: F401
    CLIENT, COACH, NOW, PAY, REVIEWER, REVIEWER2, SUB, Notes, _txn, db, events, later, make_payment, notes, payment_of,
    refusal, seed_world,
)
from tests.test_payments_staff import REASON, in_review

DAYS = dt.timedelta(days=1)


def decide(db, outcome, kind, *, proof_false=False, now=NOW, notes=None, pay=PAY):
    notes = notes if notes is not None else Notes()
    strikes.after_decision(db, pay, outcome=outcome, kind=kind, proof_false=proof_false, now=now, notify=notes)
    return notes


def profile(db):
    return db.document(f"coachPaymentProfiles/{COACH}").get().to_dict()


def standing(db, uid):
    snap = db.document(f"paymentStanding/{uid}").get()
    return snap.to_dict() if snap.exists else {}


def world(db, **over):
    seed_world(db)
    make_payment(db, **{"status": "resolved_paid", **over})


@pytest.mark.parametrize("args,want", [((10, 1, 10, 10), True), ((9, 9, 10, 10), False), ((20, 1, 10, 10), False),
                                       ((10, 0, 10, 10), False), ((0, 0, 10, 10), False), ((10, 2, 10, 20), True)])
def test_rate_flag_is_integer_maths(args, want):
    assert strikes.rate_flag(*args) is want


def test_a_lost_not_received_dispute_strikes_the_coach_once(db):
    world(db)
    decide(db, "resolved_paid", "not_received")
    decide(db, "resolved_paid", "not_received")
    doc = db.document(f"paymentStrikes/{PAY}__coach").get().to_dict()
    assert doc["reason"] == "lost_dispute" and doc["uid"] == COACH
    assert standing(db, COACH)["coachStrikes"] == 1
    assert profile(db)["disputesLost"] == 1 and profile(db)["paymentsConfirmed"] == 1


def test_a_payment_the_coach_already_confirmed_is_not_counted_again(db):
    world(db, coachDecision={"confirmedAt": NOW})
    decide(db, "resolved_paid", "service")
    assert profile(db)["paymentsConfirmed"] == 0


def test_a_paid_service_dispute_and_a_red_proof_paid_are_not_strikes(db):
    world(db)
    decide(db, "no_refund", "service")
    decide(db, "resolved_paid", "proof_red")
    assert not list(db.collection("paymentStrikes").stream()) and profile(db)["disputesLost"] == 0


def test_false_proof_strikes_the_client_only_when_staff_say_so(db):
    world(db, status="resolved_unpaid")
    decide(db, "resolved_unpaid", "not_received")
    assert not list(db.collection("paymentStrikes").stream())
    decide(db, "resolved_unpaid", "not_received", proof_false=True)
    doc = db.document(f"paymentStrikes/{PAY}__client").get().to_dict()
    assert doc["uid"] == CLIENT and doc["reason"] == "false_proof" and standing(db, CLIENT)["clientStrikes"] == 1


def second_payment(db, pay="pay-2"):
    make_payment(db, pay, status="resolved_unpaid")


def test_two_client_strikes_in_90_days_pause_her_payments_and_tell_her(db):
    world(db, status="resolved_unpaid")
    second_payment(db)
    first = decide(db, "resolved_unpaid", "proof_red", proof_false=True)
    assert first.sent == [] and not standing(db, CLIENT).get("clientSuspended")
    second = decide(db, "resolved_unpaid", "proof_red", proof_false=True, pay="pay-2", now=NOW + 5 * DAYS)
    assert standing(db, CLIENT)["clientSuspended"] is True and second.sent == [(CLIENT, "instapayPaused")]
    assert second.refs == [(CLIENT, "instapayPaused", "pay-2")]
    db.document(f"subscriptions/{SUB}").update({"status": "awaiting_payment"})
    assert refusal(lambda: create.create(db, CLIENT, {"subId": SUB, "idempotencyKey": "key-0001-abcd"}, now=NOW + 6 * DAYS, on=True)) == (
        errors.PRECONDITION, errors.CLIENT_PAYMENTS_SUSPENDED)


def test_the_second_strike_after_91_days_does_not_count(db):
    world(db, status="resolved_unpaid")
    second_payment(db)
    decide(db, "resolved_unpaid", "proof_red", proof_false=True)
    decide(db, "resolved_unpaid", "proof_red", proof_false=True, pay="pay-2", now=NOW + 91 * DAYS)
    assert standing(db, CLIENT)["clientStrikes"] == 1 and not standing(db, CLIENT).get("clientSuspended")


def test_two_coach_strikes_flag_but_do_not_suspend(db):
    world(db)
    make_payment(db, "pay-2", status="resolved_paid")
    db.document(f"subscriptions/{SUB}").update({"status": "active"})
    decide(db, "resolved_paid", "not_received")
    decide(db, "resolved_paid", "not_received", pay="pay-2", now=NOW + DAYS)
    state = standing(db, COACH)
    assert state["coachFlagged"] is True and state["flagReason"] == "twoStrikes" and "coachSuspended" not in state
    assert db.document(f"subscriptions/{SUB}").get().to_dict()["status"] == "active"


def test_dispute_rate_flags_a_coach_over_the_threshold(db):
    world(db)
    db.document(f"coachPaymentProfiles/{COACH}").update({"paymentsConfirmed": 9})
    decide(db, "resolved_paid", "not_received")
    assert profile(db)["paymentsConfirmed"] == 10 and standing(db, COACH)["coachFlagged"] is True

    world(db)
    db.document("coachingConfig/instapay").set({"disputeRatePercent": 20})
    db.document(f"paymentStanding/{COACH}").delete()
    db.document(f"paymentStrikes/{PAY}__coach").delete()
    db.document(f"payments/{PAY}/staff/counted").delete()
    db.document(f"coachPaymentProfiles/{COACH}").update({"paymentsConfirmed": 9, "disputesLost": 0})
    decide(db, "resolved_paid", "not_received")
    assert standing(db, COACH).get("flagReason") != "disputeRate"


def test_reopen_reverses_the_strike_the_lost_count_and_the_pause(db):
    world(db, status="resolved_unpaid")
    second_payment(db)
    decide(db, "resolved_unpaid", "proof_red", proof_false=True)
    decide(db, "resolved_unpaid", "proof_red", proof_false=True, pay="pay-2")
    assert standing(db, CLIENT)["clientSuspended"] is True
    decide(db, "reopen", "proof_red", now=NOW + DAYS)
    assert db.document(f"paymentStrikes/{PAY}__client").get().to_dict()["reversedAt"] == NOW + DAYS
    assert standing(db, CLIENT)["clientStrikes"] == 1 and standing(db, CLIENT)["clientSuspended"] is False

    world(db)
    decide(db, "resolved_paid", "not_received")
    assert profile(db)["disputesLost"] == 1
    decide(db, "reopen", "not_received", now=NOW + DAYS)
    assert profile(db)["disputesLost"] == 0 and standing(db, COACH)["coachStrikes"] == 0
    decide(db, "reopen", "not_received", now=NOW + 2 * DAYS)    # twice changes nothing
    assert profile(db)["disputesLost"] == 0


def test_reopen_reads_everything_before_it_writes(db, monkeypatch):
    """Real Firestore refuses a read after a write inside a transaction; the fake does not, so watch the order."""
    from tests import fake_firestore

    world(db)
    decide(db, "resolved_paid", "not_received")
    log = []
    real_update, real_set, real_get = fake_firestore.Transaction.update, fake_firestore.Transaction.set, fake_firestore.DocumentRef.get
    monkeypatch.setattr(fake_firestore.Transaction, "update", lambda self, *a, **k: (log.append("w"), real_update(self, *a, **k))[1])
    monkeypatch.setattr(fake_firestore.Transaction, "set", lambda self, *a, **k: (log.append("w"), real_set(self, *a, **k))[1])
    monkeypatch.setattr(fake_firestore.DocumentRef, "get", lambda self, *a, **k: (log.append("r") if k.get("transaction") is not None else None, real_get(self, *a, **k))[1])
    decide(db, "reopen", "not_received", now=NOW + DAYS)
    assert "w" in log and "r" in log and log.index("w") > max(i for i, x in enumerate(log) if x == "r")


# ---------------------------------------------------------------- suspension

def suspend(db, who, notes, **over):
    return strikes.set_coach_status(db, who, {"coachUid": COACH, "action": "suspend", "reason": "two lost disputes in a month", **over},
                                    now=over.pop("now", NOW), notify=notes)


def test_suspend_needs_two_different_staff(db):
    seed_world(db)
    notes = Notes()
    assert suspend(db, REVIEWER, notes) == {"status": "awaiting_second_approval"}
    assert "coachSuspended" not in standing(db, COACH)
    assert refusal(lambda: suspend(db, REVIEWER, notes)) == (errors.PRECONDITION, errors.SAME_STAFF)
    assert suspend(db, REVIEWER2, notes) == {"status": "suspended"}
    assert standing(db, COACH)["coachSuspended"] is True and profile(db)["status"] == "suspended"
    assert db.document(f"coaches/{COACH}").get().to_dict()["instapayReady"] is False
    assert notes.sent == [(COACH, "instapaySuspended")]
    alert = db.document(f"paymentAlerts/suspend__{COACH}").get().to_dict()
    assert len(alert["reasons"]) == 2 and len(alert["approvals"]) == 2 and COACH not in str(alert) and REVIEWER not in str(alert)


def test_a_stale_proposal_restarts_after_7_days(db):
    seed_world(db)
    suspend(db, REVIEWER, Notes())
    again = strikes.set_coach_status(db, REVIEWER2, {"coachUid": COACH, "action": "suspend", "reason": "two lost disputes in a month"},
                                     now=NOW + 8 * DAYS, notify=Notes())
    assert again == {"status": "awaiting_second_approval"} and "coachSuspended" not in standing(db, COACH)


def test_reason_and_subject_rules(db):
    seed_world(db)
    assert refusal(lambda: suspend(db, REVIEWER, Notes(), reason="short")) == (errors.INVALID, errors.REASON_REQUIRED)
    assert refusal(lambda: suspend(db, COACH, Notes())) == (c_errors.PERMISSION, c_errors.STAFF_IS_SUBJECT)
    assert refusal(lambda: strikes.set_coach_status(db, REVIEWER, {"coachUid": "nobody-uid", "action": "suspend", "reason": "ten or more chars"},
                                                    now=NOW, notify=Notes())) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)


def test_lift_needs_one_staff_and_restores_the_address_flag(db):
    seed_world(db)
    suspend(db, REVIEWER, Notes())
    suspend(db, REVIEWER2, Notes())
    out = strikes.set_coach_status(db, REVIEWER, {"coachUid": COACH, "action": "lift", "reason": "the decision was reviewed"}, now=NOW + DAYS, notify=Notes())
    assert out == {"status": "active"} and standing(db, COACH)["coachSuspended"] is False
    assert profile(db)["status"] == "ok" and db.document(f"coaches/{COACH}").get().to_dict()["instapayReady"] is True
    assert strikes.set_coach_status(db, REVIEWER, {"coachUid": COACH, "action": "lift", "reason": "lifting an active coach"}, now=NOW, notify=Notes()) == {"status": "active"}


def test_a_suspended_coach_cannot_take_a_new_payment_but_the_running_one_can_be_resolved(db):
    in_review(db, "not_received")
    suspend(db, REVIEWER, Notes())
    suspend(db, REVIEWER2, Notes())
    db.document(f"subscriptions/{SUB}").update({"status": "awaiting_payment"})
    make_payment(db, "pay-new", status="cancelled", clientUid="client-uid-7")
    assert refusal(lambda: create.create(db, CLIENT, {"subId": SUB, "idempotencyKey": "key-0001-abcd"}, now=NOW, on=True)) == (
        errors.PRECONDITION, errors.COACH_PAYMENTS_SUSPENDED)
    out = staff.resolve(db, "reviewer-uid-3", {"paymentId": PAY, "outcome": "resolved_paid", "reason": REASON}, now=NOW, notify=Notes())
    assert out["status"] == "resolved_paid"


def test_list_flags_shows_flagged_women_and_open_alerts_only(db):
    db.document("paymentStanding/w1").set({"coachFlagged": True, "flagReason": "twoStrikes", "coachStrikes": 2})
    db.document("paymentStanding/w2").set({"clientSuspended": True, "clientStrikes": 2})
    db.document("paymentStanding/w3").set({"coachStrikes": 1})
    db.document("paymentAlerts/a1").set({"type": "addressChange", "at": NOW, "coachRef": "ref1"})
    db.document("paymentAlerts/a2").set({"type": "suspend", "closed": True, "at": NOW})
    out = strikes.list_flags(db, REVIEWER, {}, now=NOW)
    assert sorted(f["uid"] for f in out["flagged"]) == ["w1", "w2"]
    assert [a["id"] for a in out["alerts"]] == ["a1"]
    logged = [r.to_dict() for r in db.collection("adminAccessLog").stream()]
    assert any("payments.flags" in str(r) for r in logged)


def test_a_suspended_coach_stays_on_the_flag_list_and_an_address_alert_names_the_woman_to_staff(db):
    from coaching import common

    seed_world(db)
    suspend(db, REVIEWER, Notes())
    suspend(db, REVIEWER2, Notes())
    db.document("paymentAlerts/addr1").set({"type": "addressChange", "at": NOW, "coachRef": common.staff_ref(COACH), "firstTime": False})
    db.document("paymentAlerts/addr2").set({"type": "addressChange", "at": NOW, "coachRef": common.staff_ref("someone-unknown")})
    out = strikes.list_flags(db, REVIEWER, {}, now=NOW)
    assert [f["uid"] for f in out["flagged"]] == [COACH] and out["flagged"][0]["coachSuspended"] is True
    assert {a["id"]: a.get("coachUid") for a in out["alerts"]} == {"addr1": COACH, "addr2": None}
    lifted = strikes.set_coach_status(db, REVIEWER, {"coachUid": COACH, "action": "lift", "reason": "the decision was reviewed"}, now=NOW, notify=Notes())
    assert lifted == {"status": "active"} and strikes.list_flags(db, REVIEWER, {}, now=NOW)["flagged"] == []
