"""What staff see and decide (WO-10b4, spec 13.6), the party image read, and the timers that
send a silent party's payment to staff."""

from __future__ import annotations

import datetime as dt

import pytest

from coaching import common, errors as c_errors
from payments import activation, coach, errors, report, staff, timers
from tests.fake_blobs import FakeBlobs
from tests.payments_helpers import (  # noqa: F401
    AMOUNT, CLIENT, CLIENT2, COACH, NOW, PAY, REVIEWER, REVIEWER2, SUB, Notes, _txn, db, events, later, make_payment,
    notes, payment_of, refusal, seed_world,
)
from tests.test_payments_hardening import green_proof, sub_of
from tests.test_payments_proof import blobs  # noqa: F401

SHOT = f"payment-proofs/{PAY}/client-abc-1.jpg"
REASON = "the bank statement line shows the transfer"


def in_review(db, kind="proof_red", **over):
    """A RED proof waiting for staff, with its staff-only review document."""
    seed_world(db)
    row = dict(status="in_review", outcome="red", dispute={"kind": kind, "openedBy": "system", "openedAt": NOW},
               proof={"screenshotCount": 1, "amberAttempts": 0, "screenshotPaths": [SHOT], "imageFlags": [], "txnNumber": "301234567890123"})
    row.update(over)
    make_payment(db, **row)
    db.document(f"payments/{PAY}/staff/review").set({"riskScore": 40, "flags": [], "reasons": ["amountDiffers"], "checks": {"amount": "different"}})


def decide(db, notes, outcome="resolved_paid", who=REVIEWER, now=NOW, **extra):
    return staff.resolve(db, who, {"paymentId": PAY, "outcome": outcome, "reason": REASON, **extra}, now=now, notify=notes)


# ---------------------------------------------------------------- recommend

@pytest.mark.parametrize("evidence,outcome,why", [
    ({"coachStatement": {"amountFound": True}}, "resolved_paid", "statement_contradicts_claim"),
    ({"coachStatement": {"txnFound": True}, "dispute": {"kind": "not_received"}}, "resolved_paid", "statement_contradicts_claim"),
    ({"dispute": {"kind": "proof_red"}, "clientProof": {"reasons": ["txnReused"]}}, "resolved_unpaid", "proof_reused"),
    ({"dispute": {"kind": "proof_red"}, "clientProof": {"reasons": ["sameImage"]}}, "resolved_unpaid", "proof_reused"),
    ({"dispute": {"kind": "not_received"}, "clientProof": {"outcome": "green"}}, "resolved_paid", "green_proof_no_statement"),
    ({"dispute": {"kind": "silent_proof_submitted"}, "clientProof": {"outcome": "green"}}, "resolved_paid", "green_proof_coach_silent"),
    ({"dispute": {"kind": "service", "serviceFacts": {"sessionsUsed": 0, "sessionsIncluded": 4}}}, "refund_owed", "nothing_delivered"),
    ({"dispute": {"kind": "service", "serviceFacts": {"sessionsUsed": 2, "sessionsIncluded": 4}}}, "no_refund", "sessions_delivered"),
    ({"dispute": {"kind": "refund_not_received", "serviceFacts": {}}}, "refund_owed", "refund_unconfirmed"),
    ({"dispute": {"kind": "proof_red"}, "clientProof": {"reasons": ["amountDiffers"]}}, None, "ask_for_bank_statement_line"),
    ({}, None, "ask_for_bank_statement_line"),
])
def test_the_recommendation_follows_the_rule_set_and_never_decides(evidence, outcome, why):
    assert staff.recommend(evidence) == {"outcome": outcome, "why": why}


# ---------------------------------------------------------------- queue

def test_the_queue_lists_payments_in_review_and_not_received_oldest_first_with_the_risk_score(db):
    in_review(db)
    make_payment(db, "pay-nr", status="coach_not_received", statusAt=NOW - dt.timedelta(hours=5), reference="OH-9999")
    make_payment(db, "pay-open", status="awaiting_payment")
    out = staff.queue(db, REVIEWER, {}, now=NOW + dt.timedelta(hours=2))
    assert [i["paymentId"] for i in out["items"]] == ["pay-nr", PAY]
    first, second = out["items"]
    assert first["lane"] == "review" and first["status"] == "coach_not_received" and first["waitingHours"] == 7
    assert second["kind"] == "proof_red" and second["riskScore"] == 40 and second["amountPiasters"] == AMOUNT
    assert out["next"] is None


def test_the_queue_lists_a_payment_whose_silent_party_ran_out_of_time(db):
    seed_world(db)
    make_payment(db, "pay-silent", status="proof_submitted", escalateAt=NOW - dt.timedelta(hours=1))
    make_payment(db, "pay-patient", status="proof_submitted", escalateAt=NOW + dt.timedelta(hours=30))
    make_payment(db, "pay-done", status="confirmed", escalateAt=None)
    items = staff.queue(db, REVIEWER, {}, now=NOW)["items"]
    assert [(i["paymentId"], i["lane"], i["kind"]) for i in items] == [("pay-silent", "escalated", "silent_proof_submitted")]


def test_the_queue_pages_and_logs_the_read(db, monkeypatch):
    seed_world(db)
    monkeypatch.setattr(staff, "PAGE", 2)
    for i in range(5):
        make_payment(db, f"pay-{i}", status="in_review", statusAt=NOW + dt.timedelta(minutes=i))
    page1 = staff.queue(db, REVIEWER, {}, now=NOW + dt.timedelta(hours=1))
    page2 = staff.queue(db, REVIEWER, {"after": page1["next"]}, now=NOW + dt.timedelta(hours=1))
    page3 = staff.queue(db, REVIEWER, {"after": page2["next"]}, now=NOW + dt.timedelta(hours=1))
    assert [i["paymentId"] for p in (page1, page2, page3) for i in p["items"]] == [f"pay-{i}" for i in range(5)]
    assert page3["next"] is None
    assert len(list(db.collection("adminAccessLog").stream())) == 3


# ---------------------------------------------------------------- evidence

def test_the_evidence_has_the_seven_items_in_order_and_a_recommendation(db):
    in_review(db)
    db.document(f"coachPaymentProfiles/{COACH}").update({"paymentsConfirmed": 4, "disputesLost": 1})
    db.document(f"paymentStanding/{COACH}").set({"coachStrikes": 1})
    db.collection(f"payments/{PAY}/events").document("e1").set({"at": NOW, "from": "proof_submitted", "to": "in_review", "role": "system", "code": "proof_red"})
    ev = staff.get_evidence(db, REVIEWER, {"paymentId": PAY}, now=NOW)
    assert [k for k in ev if k[0].isdigit()] == ["1_amountAndReference", "2_transactionNumber", "3_ocr", "4_flags", "5_timeline", "6_history", "7_statementRequest"]
    assert ev["1_amountAndReference"] == {"amountPiasters": AMOUNT, "reference": "OH-4821"}
    assert ev["2_transactionNumber"] == {"txnNumber": "301234567890123", "digits": 15}
    assert ev["3_ocr"]["riskScore"] == 40 and ev["4_flags"]["reasons"] == ["amountDiffers"]
    assert ev["5_timeline"][0]["code"] == "proof_red"
    assert ev["6_history"]["coach"] == {"paymentsConfirmed": 4, "disputesLost": 1, "strikes": 1}
    assert ev["clientProof"] == {"outcome": "red", "reasons": ["amountDiffers"]}
    assert ev["recommended"]["why"] == "ask_for_bank_statement_line"
    assert "images" not in ev


def test_the_pictures_come_only_when_asked_for_and_only_those_that_exist(db):
    in_review(db)
    blobs = FakeBlobs({SHOT: (b"jpeg-bytes", "image/jpeg")})
    db.document(f"payments/{PAY}").update({"proof.screenshotPaths": [SHOT, f"payment-proofs/{PAY}/client-gone.jpg"]})
    ev = staff.get_evidence(db, REVIEWER, {"paymentId": PAY, "withImages": True}, now=NOW, blobs=blobs)
    assert list(ev["images"]) == [SHOT]


def test_staff_never_open_a_case_about_themselves_and_an_unknown_payment_is_not_found(db):
    in_review(db)
    assert refusal(lambda: staff.get_evidence(db, CLIENT, {"paymentId": PAY}, now=NOW)) == (c_errors.PERMISSION, c_errors.STAFF_IS_SUBJECT)
    assert refusal(lambda: staff.get_evidence(db, REVIEWER, {"paymentId": "nope"}, now=NOW)) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)


# ---------------------------------------------------------------- decisions

def test_resolved_paid_starts_the_coaching_owes_the_fee_and_tells_both_women(db, notes):
    in_review(db)
    assert decide(db, notes, "resolved_paid") == {"status": "resolved_paid", "outcome": "resolved_paid"}
    pay = payment_of(db)
    assert pay["status"] == "resolved_paid" and pay["access"] == {"state": "full", "until": None}
    assert pay["feeState"] == "owed" and pay["feePiasters"] == 7500 and pay["dispute"]["staffDecision"] == "resolved_paid"
    assert sub_of(db)["status"] == "active"
    assert {(CLIENT, "instapayReviewDecided"), (COACH, "instapayCoachReviewDecided")} <= set(notes.sent)
    assert ("in_review", "resolved_paid", "staff") in events(db)
    log = [d.to_dict() for d in db.collection(f"payments/{PAY}/staff/decisions/log").stream()]
    assert len(log) == 1 and log[0]["reasonText"] == REASON and REVIEWER not in str(log)


def test_resolved_unpaid_ends_the_coaching_and_waives_the_fee(db, notes):
    in_review(db)
    common.run(db, lambda t: activation.grant(t, db, activation.read_for_start(t, db, SUB), NOW, provisional_until=later(days=7)))
    db.document(f"payments/{PAY}").update({"feeState": "disputed", "feeOwedAt": NOW, "feePiasters": 7500})
    decide(db, notes, "resolved_unpaid", proofFalse=True)
    pay = payment_of(db)
    assert pay["status"] == "resolved_unpaid" and pay["access"]["state"] == "none" and pay["feeState"] == "waived"
    assert sub_of(db)["status"] == "ended_early" and sub_of(db)["endReason"] == "dispute"
    assert db.document(f"coaches/{COACH}").get().to_dict()["activeClients"] == 0
    log = [d.to_dict() for d in db.collection(f"payments/{PAY}/staff/decisions/log").stream()]
    assert log[0]["proofFalse"] is True


def test_no_refund_puts_a_disputed_paid_payment_back_to_confirmed(db, notes):
    in_review(db, kind="service", status="in_review", access={"state": "full", "until": None}, feeState="disputed")
    decide(db, notes, "no_refund")
    pay = payment_of(db)
    assert pay["status"] == "confirmed" and pay["access"]["state"] == "full" and pay["feeState"] == "owed"


def test_refund_owed_keeps_the_payment_in_review_until_the_coach_records_it(db, notes):
    in_review(db, kind="service")
    assert refusal(lambda: decide(db, notes, "refund_owed")) == (c_errors.INVALID, c_errors.BAD_REQUEST)
    decide(db, notes, "refund_owed", refundPiasters=30000, now=NOW + dt.timedelta(hours=1))
    pay = payment_of(db)
    assert pay["status"] == "in_review"
    assert pay["dispute"]["refundOwedPiasters"] == 30000 and pay["dispute"]["refundDueAt"] == NOW + dt.timedelta(days=7, hours=1)
    assert ("in_review", "in_review", "staff") in events(db)


def test_a_decision_needs_a_reason_of_at_least_ten_characters_and_a_known_outcome(db, notes):
    in_review(db)
    assert refusal(lambda: staff.resolve(db, REVIEWER, {"paymentId": PAY, "outcome": "resolved_paid", "reason": "short"}, now=NOW, notify=notes)) == (
        c_errors.INVALID, errors.REASON_REQUIRED)
    assert refusal(lambda: decide(db, notes, "delete_it"))[0] == c_errors.INVALID
    assert payment_of(db)["status"] == "in_review"


def test_a_decision_is_possible_only_from_review_and_never_about_the_deciders_own_payment(db, notes):
    in_review(db, status="confirmed")
    assert refusal(lambda: decide(db, notes, "resolved_paid")) == (errors.PRECONDITION, errors.ILLEGAL_TRANSITION)
    in_review(db)
    assert refusal(lambda: decide(db, notes, "resolved_paid", who=CLIENT)) == (c_errors.PERMISSION, c_errors.STAFF_IS_SUBJECT)


def test_a_second_reviewer_reopens_and_the_same_one_cannot(db, notes):
    in_review(db)
    decide(db, notes, "resolved_paid", who=REVIEWER)
    assert refusal(lambda: decide(db, notes, "reopen", who=REVIEWER, now=NOW + dt.timedelta(hours=1))) == (errors.PRECONDITION, errors.SAME_STAFF)
    decide(db, notes, "reopen", who=REVIEWER2, now=NOW + dt.timedelta(hours=2))
    pay = payment_of(db)
    assert pay["status"] == "in_review" and pay["dispute"]["staffDecision"] is None


def test_a_decision_is_handed_to_the_strike_hook_after_it_is_final(db, notes):
    in_review(db)
    seen = {}
    staff.resolve(db, REVIEWER, {"paymentId": PAY, "outcome": "resolved_unpaid", "reason": REASON, "proofFalse": True}, now=NOW, notify=notes,
                  on_decision=lambda *a, **kw: seen.update(kw, args=a))
    assert seen["outcome"] == "resolved_unpaid" and seen["kind"] == "proof_red" and seen["proof_false"] is True
    assert seen["args"][1] == PAY


def test_a_decision_frees_the_amount_lock_the_payment_still_owns(db, notes):
    in_review(db, lockId=f"{COACH}__{AMOUNT}")
    db.document(f"paymentAmountLocks/{COACH}__{AMOUNT}").set({"coachUid": COACH, "paymentId": PAY, "amountPiasters": AMOUNT, "heldUntil": later(days=30)})
    decide(db, notes, "resolved_unpaid", now=NOW + dt.timedelta(hours=3))
    assert db.document(f"paymentAmountLocks/{COACH}__{AMOUNT}").get().to_dict()["heldUntil"] == NOW + dt.timedelta(hours=3)


# ---------------------------------------------------------------- the clock

def test_a_proof_starts_the_coach_clock_and_a_confirmation_stops_it(db, blobs, notes):
    green_proof(db, blobs, notes)
    sent = NOW + dt.timedelta(minutes=10)
    assert payment_of(db)["escalateAt"] == sent + dt.timedelta(hours=72)
    coach.confirm(db, COACH, {"paymentId": PAY}, coach_v="active", now=sent + dt.timedelta(hours=1), notify=notes)
    assert payment_of(db)["escalateAt"] is None


def test_timers_send_an_overdue_payment_to_staff_and_tell_both_women(db, notes):
    seed_world(db)
    make_payment(db, status="proof_submitted", escalateAt=NOW + dt.timedelta(hours=72))
    assert timers.due(db, NOW + dt.timedelta(hours=71)) == []
    assert timers.escalate(db, PAY, NOW + dt.timedelta(hours=71), notes) is False
    assert timers.escalate(db, PAY, NOW + dt.timedelta(hours=73), notes) is True
    pay = payment_of(db)
    assert pay["status"] == "in_review" and pay["dispute"]["kind"] == "silent_proof_submitted" and pay["escalateAt"] is None
    assert ("proof_submitted", "in_review", "system") in events(db)
    assert {(CLIENT, "instapayReviewStarted"), (COACH, "instapayDisputeOpened")} <= set(notes.sent)
    assert timers.escalate(db, PAY, NOW + dt.timedelta(hours=74), notes) is False


def test_staff_can_decide_an_overdue_payment_before_the_schedule_has_run(db, notes):
    seed_world(db)
    make_payment(db, status="proof_submitted", outcome="green", escalateAt=NOW + dt.timedelta(hours=72))
    t = NOW + dt.timedelta(hours=80)
    decide(db, notes, "resolved_paid", now=t)
    assert payment_of(db)["status"] == "resolved_paid" and sub_of(db)["status"] == "active"
    assert {e[:2] for e in events(db)} == {("proof_submitted", "in_review"), ("in_review", "resolved_paid")}
    # the same decision on a payment that is not overdue is refused
    make_payment(db, "pay-fresh", status="proof_submitted", escalateAt=t + dt.timedelta(hours=10))
    with pytest.raises(c_errors.CoachingError):
        staff.resolve(db, REVIEWER, {"paymentId": "pay-fresh", "outcome": "resolved_paid", "reason": REASON}, now=t, notify=notes)


def test_a_report_the_client_never_answers_goes_to_staff_even_after_the_request_expired(db, notes):
    seed_world(db)
    make_payment(db, status="awaiting_payment", expiresAt=NOW + dt.timedelta(hours=24))
    report.coach_report(db, COACH, {"reference": "OH-4821", "txnNumber": "301234567890123"}, coach_v="active", now=NOW, notify=notes)
    assert payment_of(db)["escalateAt"] == NOW + dt.timedelta(hours=72)
    assert timers.expire(db, PAY, NOW + dt.timedelta(hours=25)) == "expired"
    assert payment_of(db)["escalateAt"] == NOW + dt.timedelta(hours=72)
    assert timers.due(db, NOW + dt.timedelta(hours=73)) == [PAY]
    assert timers.escalate(db, PAY, NOW + dt.timedelta(hours=73), notes) is True
    assert payment_of(db)["status"] == "in_review"


def test_staff_deciding_paid_after_provisional_access_lapsed_starts_the_coaching_again(db, blobs, notes):
    green_proof(db, blobs, notes)
    sent = NOW + dt.timedelta(minutes=10)
    from coaching import subscriptions
    subscriptions.sweep(db, now=sent + dt.timedelta(days=8), notify=notes)
    assert sub_of(db)["status"] == "ended"
    t = sent + dt.timedelta(days=9)             # the coach stayed silent past 72 hours
    decide(db, notes, "resolved_paid", now=t)
    sub = sub_of(db)
    assert sub["status"] == "active" and sub["endsAt"] == t + dt.timedelta(days=28) and sub["provisionalUntil"] is None


def test_timers_expire_a_request_then_close_it_when_the_late_window_ends(db):
    seed_world(db)
    make_payment(db, status="awaiting_payment", expiresAt=NOW + dt.timedelta(hours=24), lateUntil=NOW + dt.timedelta(days=7))
    assert timers.expire(db, PAY, NOW + dt.timedelta(hours=23)) is None
    assert timers.expire(db, PAY, NOW + dt.timedelta(hours=25)) == "expired"
    assert timers.expire(db, PAY, NOW + dt.timedelta(days=6)) is None
    assert timers.expire(db, PAY, NOW + dt.timedelta(days=8)) == "cancelled"
    assert [e[:2] for e in events(db)] == [("awaiting_payment", "expired"), ("expired", "cancelled")]


def test_one_sweep_escalates_expires_and_closes(db, notes):
    seed_world(db)
    make_payment(db, "p1", status="proof_submitted", escalateAt=NOW - dt.timedelta(hours=1))
    make_payment(db, "p2", status="awaiting_payment", expiresAt=NOW - dt.timedelta(hours=1), clientUid=CLIENT2)
    make_payment(db, "p3", status="expired", lateUntil=NOW - dt.timedelta(hours=1), clientUid="client-3")
    make_payment(db, "p4", status="awaiting_payment", expiresAt=NOW + dt.timedelta(hours=1), clientUid="client-4")
    assert timers.sweep(db, NOW, notes) == {"escalated": 1, "expired": 1, "cancelled": 1}
    assert [payment_of(db, p)["status"] for p in ("p1", "p2", "p3", "p4")] == ["in_review", "expired", "cancelled", "awaiting_payment"]


# ---------------------------------------------------------------- reading a picture

def test_each_party_reads_her_own_payments_picture_through_the_server_only(db):
    seed_world(db)
    make_payment(db, proof={"screenshotCount": 1, "amberAttempts": 0, "screenshotPaths": [SHOT], "imageFlags": []},
                 coachDecision={"statementPaths": [f"payment-proofs/{PAY}/coach-1.jpg"]})
    blobs = FakeBlobs({SHOT: (b"abc", "image/jpeg"), f"payment-proofs/{PAY}/coach-1.jpg": (b"xyz", "image/jpeg"), "payment-proofs/other/x.jpg": (b"no", "image/jpeg")})
    assert staff.party_image(db, CLIENT, {"paymentId": PAY, "path": SHOT}, blobs=blobs) == {"imageB64": "YWJj"}
    assert staff.party_image(db, COACH, {"paymentId": PAY, "path": f"payment-proofs/{PAY}/coach-1.jpg"}, blobs=blobs) == {"imageB64": "eHl6"}
    for who, path in ((CLIENT2, SHOT), (CLIENT, "payment-proofs/other/x.jpg"), (CLIENT, f"payment-proofs/{PAY}/client-gone.jpg")):
        assert refusal(lambda: staff.party_image(db, who, {"paymentId": PAY, "path": path}, blobs=blobs)) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    assert refusal(lambda: staff.party_image(db, CLIENT, {"paymentId": "nope", "path": SHOT}, blobs=blobs)) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
