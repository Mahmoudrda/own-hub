"""Findings of the review of commit b2f449a (27 Oct 2026). Each test failed on the code as committed."""

from __future__ import annotations

import datetime as dt

import pytest

from coaching import dhash
from payments import activation, engine, errors, model, proof, risk, states, staff, timers
from coaching import common
from tests.payments_helpers import (  # noqa: F401
    AMOUNT, CLIENT, COACH, NOW, PAY, REVIEWER, SUB, Notes, _txn, db, events, later, make_payment, notes, payment_of,
    refusal, seed_world,
)
from tests.test_payments_hardening import sub_of
from tests.test_payments_proof import DETAILS, INSTAPAY_FIRST, WRONG_AMOUNT_TXT, Reader, blobs, send  # noqa: F401
from tests.test_payments_staff import REASON, decide, in_review


def lapse(db):
    """The sweeper ended a provisional stay at its limit: ended, provisionalUntil kept (activation.lapsed)."""
    db.document(f"subscriptions/{SUB}").update(
        {"status": "ended", "provisionalUntil": later(days=-1), "endsAt": later(days=-1), "startsAt": later(days=-8)})


def lapsed_review(db):
    in_review(db, "silent_proof_submitted", outcome="green")
    lapse(db)


# ------------------------------------------------ 1. restarting a lapsed provisional subscription

def test_a_lapsed_coaching_does_not_restart_past_the_coachs_client_cap(db, notes):
    lapsed_review(db)
    db.document(f"coaches/{COACH}").update({"activeClients": 15, "maxActiveClients": 15})
    decide(db, notes, "resolved_paid")
    assert payment_of(db)["status"] == "resolved_paid" and payment_of(db)["access"]["state"] == "none"   # settled, but no place to start
    assert sub_of(db)["status"] == "ended"
    assert db.document(f"coaches/{COACH}").get().to_dict()["activeClients"] == 15


@pytest.mark.parametrize("pair", [(COACH, CLIENT), (CLIENT, COACH)])
def test_a_lapsed_coaching_does_not_restart_across_a_block(db, notes, pair):
    lapsed_review(db)
    db.document(f"users/{pair[0]}/blocks/{pair[1]}").set({"at": NOW})
    decide(db, notes, "resolved_paid")
    assert sub_of(db)["status"] == "ended"
    assert db.document(f"coaches/{COACH}").get().to_dict()["activeClients"] == 0


def test_a_lapsed_coaching_does_not_restart_beside_a_newer_one_for_the_same_pair(db, notes):
    lapsed_review(db)
    db.document("subscriptions/sub-2").set({"coachUid": COACH, "clientUid": CLIENT, "relId": f"{COACH}__{CLIENT}", "status": "active",
                                            "package": {"durationDays": 28}, "endsAt": later(days=20)})
    db.document(f"relationships/{COACH}__{CLIENT}").update({"status": "active", "chatOpen": True, "activeSubId": "sub-2"})
    db.document(f"coaches/{COACH}").update({"activeClients": 1})
    decide(db, notes, "resolved_paid")
    assert sub_of(db)["status"] == "ended"
    assert db.document("subscriptions/sub-2").get().to_dict()["status"] == "active"
    rel = db.document(f"relationships/{COACH}__{CLIENT}").get().to_dict()
    assert rel["activeSubId"] == "sub-2"
    assert db.document(f"coaches/{COACH}").get().to_dict()["activeClients"] == 1


def test_nothing_in_the_way_still_restarts_a_lapsed_coaching(db, notes):
    lapsed_review(db)
    decide(db, notes, "resolved_paid")
    assert sub_of(db)["status"] == "active"
    assert db.document(f"coaches/{COACH}").get().to_dict()["activeClients"] == 1


# ------------------------------------------------ 2. a refund the client never received

def refund_not_received(db, **over):
    in_review(db, "refund_not_received", feeState="disputed", feePiasters=0, feeOwedAt=later(days=-2),
              coachDecision={"confirmedAt": later(days=-3), "receivedPiasters": AMOUNT},
              refund={"txnNumber": "400000000001", "txnKey": "400000000001", "amountPiasters": AMOUNT, "recordedAt": later(days=-1)}, **over)
    db.document(f"subscriptions/{SUB}").update({"status": "ended_early", "endReason": "refund"})


def test_no_refund_owed_after_a_refund_the_client_disputed_returns_to_refunded_with_no_fee_and_no_access(db, notes):
    refund_not_received(db)
    out = decide(db, notes, "no_refund")
    pay = payment_of(db)
    assert out["status"] == "refunded" and pay["status"] == "refunded"
    assert pay["access"]["state"] == "none" and pay["feeState"] != "owed"
    assert events(db)[-1] == ("in_review", "refunded", "staff")
    assert sub_of(db)["status"] == "ended_early"
    assert (CLIENT, "instapayReviewDecided") in notes.sent and (COACH, "instapayCoachReviewDecided") in notes.sent


def test_a_refund_dispute_cannot_be_resolved_as_paid_or_unpaid(db, notes):
    refund_not_received(db)
    for outcome in ("resolved_paid", "resolved_unpaid"):
        assert refusal(lambda: decide(db, notes, outcome)) == (errors.PRECONDITION, errors.ILLEGAL_TRANSITION)
    assert payment_of(db)["status"] == "in_review"


def test_a_partial_refund_keeps_the_fee_on_what_she_kept(db, notes):
    refund_not_received(db)
    db.document(f"payments/{PAY}").update({"feePiasters": 3000})
    decide(db, notes, "no_refund")
    assert payment_of(db)["status"] == "refunded"
    assert payment_of(db)["feeState"] == "owed" and payment_of(db)["feePiasters"] == 3000


# ------------------------------------------------ 3. coach_not_received

def test_coach_not_received_is_a_waiting_state_with_a_clock():
    assert "coach_not_received" in model.ESCALATE_STATES
    assert model.escalate_at("coach_not_received", NOW) == NOW + dt.timedelta(hours=72)


def test_a_coach_not_received_row_listed_by_the_queue_can_be_decided(db, notes):
    seed_world(db)
    make_payment(db, status="coach_not_received", coachDecision={"notReceivedAt": NOW, "reasonCode": "not_seen"})
    assert [i["paymentId"] for i in staff.queue(db, REVIEWER, {}, now=NOW)["items"]] == [PAY]
    out = decide(db, notes, "resolved_paid")
    assert out["status"] == "resolved_paid" and payment_of(db)["status"] == "resolved_paid"
    assert sorted(e[:2] for e in events(db)) == [("coach_not_received", "in_review"), ("in_review", "resolved_paid")]   # one instant


def test_a_coach_not_received_row_nobody_decides_goes_to_review_by_the_clock(db, notes):
    seed_world(db)
    make_payment(db, status="proof_submitted")

    def body(transaction):
        ref, cur = engine.load(transaction, db, PAY)
        engine.move(transaction, db, ref, cur, "coach_not_received", states.COACH, COACH, NOW, code="coach_not_received")

    common.run(db, body)
    assert payment_of(db)["escalateAt"] == NOW + dt.timedelta(hours=72)
    assert timers.sweep(db, NOW + dt.timedelta(hours=73), notes)["escalated"] == 1
    assert payment_of(db)["status"] == "in_review"


# ------------------------------------------------ 4. the fraud signals do not reach the parties

def test_a_red_proof_tells_the_client_only_that_it_is_under_review(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    res = send(db, blobs, notes, Reader(WRONG_AMOUNT_TXT))
    assert res["outcome"] == "red" and res["reasons"] == ["review"]
    pay = payment_of(db)
    assert pay["hint"] == "review" and "amountDiffers" not in str(pay)
    assert db.document(f"payments/{PAY}/staff/review").get().to_dict()["reasons"] == ["amountDiffers"]
    replay = send(db, blobs, notes, Reader(WRONG_AMOUNT_TXT))
    assert replay["reasons"] == ["review"]


FIXABLE = {"needDetails", "amountUnreadable", "wrongMessage", "someoneElsePaid", "referenceMissing", "unclear"}


def test_an_amber_answer_names_only_what_an_honest_payer_can_fix(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    res = send(db, blobs, notes, Reader("hello"), images=[phone()])
    assert res["outcome"] == "amber" and res["reasons"] and set(res["reasons"]) <= FIXABLE
    assert payment_of(db).get("hint") in (None, *FIXABLE)


def phone():
    from tests.payments_helpers import phone_jpeg
    return phone_jpeg(1)


def test_the_staff_document_keeps_which_earlier_payment_a_picture_matched(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    first = phone()
    db.document("paymentImageHashes/prior-sha").set({"paymentId": "other", "createdAt": NOW, "dHash": dhash.to_text(dhash.dhash(first))})
    send(db, blobs, notes, Reader(INSTAPAY_FIRST, DETAILS), images=[first, phone()])
    assert db.document(f"payments/{PAY}/staff/review").get().to_dict()["uniq"]["nearImageOf"] == "other"


# ------------------------------------------------ 8. the documented behaviour of risk.decide

def test_the_docstring_of_decide_says_a_screenshot_check_can_make_amber():
    assert "screenshot" in risk.decide.__doc__.lower() and "amber" in risk.decide.__doc__.lower()
    assert "Tamper flags change the score only" not in risk.decide.__doc__
