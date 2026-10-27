"""The clock: reminders, silences, AMBER access, bounded access running out, addresses coming due (WO-10c on timers.py)."""

from __future__ import annotations

import datetime as dt

from payments import coach, engine, model, profile, timers
from tests.payments_helpers import (  # noqa: F401
    AMOUNT, CLIENT, COACH, NOW, PAY, SUB, Notes, _txn, db, events, later, make_payment, notes, payment_of, seed_world,
)
from tests.test_payments_hardening import sub_of
from tests.test_payments_proof import DETAILS, INSTAPAY_FIRST, Reader, blobs, send  # noqa: F401

H = dt.timedelta(hours=1)


def at(**kw):
    return NOW + dt.timedelta(**kw)


def test_the_12_hour_reminder_is_sent_once_and_only_in_the_second_half_of_the_day(db, notes):
    seed_world(db)
    make_payment(db, expiresAt=at(hours=24))
    timers.hourly(db, at(hours=11), notes)
    assert notes.sent == []
    counts = timers.hourly(db, at(hours=13), notes)
    assert notes.sent == [(CLIENT, "instapayReminder")] and counts["clientReminded"] == 1 and payment_of(db)["reminded12h"] is True
    timers.hourly(db, at(hours=14), notes)
    assert notes.sent == [(CLIENT, "instapayReminder")]


def test_no_reminder_for_a_request_that_already_expired_or_was_paid(db, notes):
    seed_world(db)
    make_payment(db, "p-old", expiresAt=at(hours=-1), clientUid="c2")
    make_payment(db, "p-paid", status="proof_submitted", expiresAt=at(hours=5), clientUid="c3")
    timers.hourly(db, NOW, notes)
    assert (CLIENT, "instapayReminder") not in notes.sent and ("c2", "instapayReminder") not in notes.sent and ("c3", "instapayReminder") not in notes.sent


def test_at_48_hours_the_coach_is_reminded_once(db, notes):
    seed_world(db)
    make_payment(db, status="proof_submitted", proofSubmittedAt=NOW, outcome="green", escalateAt=at(hours=72))
    timers.half_hourly(db, at(hours=47), notes)
    assert notes.sent == []
    counts = timers.half_hourly(db, at(hours=49), notes)
    assert notes.sent == [(COACH, "instapayCoachReminder")] and counts["coachReminded"] == 1 and payment_of(db)["reminded48h"] is True
    timers.half_hourly(db, at(hours=50), notes)
    assert notes.sent == [(COACH, "instapayCoachReminder")] and payment_of(db)["status"] == "proof_submitted"


def test_at_72_hours_a_silent_coach_sends_it_to_review_and_the_clients_bounded_access_stays_bounded(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    send(db, blobs, notes, Reader(INSTAPAY_FIRST, DETAILS))
    sent_at = at(minutes=10)
    notes.sent.clear()
    timers.half_hourly(db, sent_at + dt.timedelta(hours=73), notes)
    pay = payment_of(db)
    assert pay["status"] == "in_review" and pay["dispute"]["kind"] == "silent_proof_submitted"
    assert pay["access"]["state"] == "provisional" and pay["access"]["until"] == sent_at + dt.timedelta(days=7)   # never open-ended (M1)
    assert sub_of(db)["status"] == "active" and sub_of(db)["provisionalUntil"] == sent_at + dt.timedelta(days=7)
    assert events(db)[-1] == ("proof_submitted", "in_review", "system")
    assert (CLIENT, "instapayReviewStarted") in notes.sent and (COACH, "instapayDisputeOpened") in notes.sent


def test_an_amber_nobody_objected_to_for_24_hours_gives_bounded_access_and_the_fee(db, notes):
    seed_world(db)
    make_payment(db, status="proof_submitted", outcome="amber", proofSubmittedAt=NOW, amberUntil=at(hours=24), escalateAt=at(hours=72))
    timers.half_hourly(db, at(hours=23), notes)
    assert payment_of(db)["access"]["state"] == "none" and sub_of(db)["status"] == "awaiting_payment"
    counts = timers.half_hourly(db, at(hours=25), notes)
    pay = payment_of(db)
    assert counts["amberGranted"] == 1 and pay["access"] == {"state": "provisional", "until": at(hours=25, days=7)}
    assert pay["feeState"] == "owed" and pay["feePiasters"] == 7500
    sub = sub_of(db)
    assert sub["status"] == "active" and sub["provisionalUntil"] == at(hours=25, days=7)
    assert db.document(f"coaches/{COACH}").get().to_dict()["activeClients"] == 1
    timers.half_hourly(db, at(hours=26), notes)
    assert db.document(f"coaches/{COACH}").get().to_dict()["activeClients"] == 1       # once


def test_an_amber_the_coach_already_answered_is_not_given_access(db, notes):
    seed_world(db)
    make_payment(db, status="coach_not_received", outcome="amber", amberUntil=at(hours=24))
    make_payment(db, "p2", status="different_amount", outcome="amber", amberUntil=at(hours=24), clientUid="c2")
    timers.half_hourly(db, at(hours=30), notes)
    assert sub_of(db)["status"] == "awaiting_payment"


def test_nothing_happens_before_48_hours(db, notes):
    seed_world(db)
    make_payment(db, status="proof_submitted", proofSubmittedAt=NOW, outcome="green", escalateAt=at(hours=72))
    before = payment_of(db)
    timers.half_hourly(db, at(hours=47), notes)
    assert payment_of(db) == before


def test_a_coach_report_the_client_never_answers_goes_to_review_after_72_hours_also_from_expired(db, notes):
    from payments import report

    seed_world(db)
    make_payment(db)
    report.coach_report(db, COACH, {"reference": "OH-4821", "txnNumber": "301234567890123"}, coach_v="active", now=NOW, notify=notes)
    timers.half_hourly(db, at(hours=23), notes)
    assert payment_of(db)["status"] == "awaiting_payment"
    timers.hourly(db, at(hours=25), notes)
    assert payment_of(db)["status"] == "expired"         # the report keeps its own clock through the expiry
    timers.half_hourly(db, at(hours=71), notes)
    assert payment_of(db)["status"] == "expired"
    timers.half_hourly(db, at(hours=73), notes)
    assert payment_of(db)["status"] == "in_review" and payment_of(db)["dispute"]["kind"] == "silent_expired"


def test_a_different_amount_unanswered_for_72_hours_goes_to_review(db, notes):
    seed_world(db)
    make_payment(db, status="different_amount", escalateAt=at(hours=72), coachDecision={"differentAmountPiasters": 40000, "acceptLower": False})
    timers.half_hourly(db, at(hours=73), notes)
    assert payment_of(db)["status"] == "in_review"


def test_a_refund_request_unanswered_for_3_days_goes_to_review(db, notes):
    seed_world(db)
    make_payment(db, status="refund_requested", escalateAt=at(days=3), refund={"requestedAt": NOW, "coachDueAt": at(days=3)})
    timers.half_hourly(db, at(days=2), notes)
    assert payment_of(db)["status"] == "refund_requested"
    timers.half_hourly(db, at(days=3, hours=1), notes)
    assert payment_of(db)["status"] == "in_review"
    assert (CLIENT, "instapayReviewStarted") in notes.sent and (COACH, "instapayDisputeOpened") in notes.sent


def test_one_day_before_bounded_access_ends_the_client_is_warned_once(db, notes):
    seed_world(db)
    make_payment(db, status="in_review", access={"state": "provisional", "until": at(days=7)})
    timers.hourly(db, at(days=5), notes)
    assert notes.sent == []
    counts = timers.hourly(db, at(days=6, hours=1), notes)
    assert notes.sent == [(CLIENT, "instapayAccessEndsSoon")] and counts["accessWarned"] == 1
    timers.hourly(db, at(days=6, hours=3), notes)
    assert notes.sent == [(CLIENT, "instapayAccessEndsSoon")]


def test_bounded_access_that_ran_out_only_changes_the_payment_so_a_paid_decision_can_still_restart_the_coaching(db, blobs, notes):
    from tests.test_payments_staff import decide
    from coaching import subscriptions

    seed_world(db)
    make_payment(db)
    send(db, blobs, notes, Reader(INSTAPAY_FIRST, DETAILS))
    end = at(minutes=10, days=7)
    subscriptions.sweep(db, now=end + H, notify=notes)
    counts = timers.hourly(db, end + H, notes)
    assert counts["accessLapsed"] == 1 and payment_of(db)["access"] == {"state": "none", "until": None}
    assert sub_of(db)["status"] == "ended" and sub_of(db)["provisionalUntil"] is not None      # still revivable
    db.document(f"payments/{PAY}").update({"status": "in_review", "dispute": {"kind": "silent_proof_submitted", "openedBy": "system", "openedAt": NOW}})
    decide(db, notes, "resolved_paid", now=end + 2 * H)
    assert sub_of(db)["status"] == "active"


def test_bounded_access_of_a_paid_payment_is_left_alone(db, notes):
    seed_world(db)
    make_payment(db, status="confirmed", access={"state": "provisional", "until": at(days=-1)})
    timers.hourly(db, NOW, notes)
    assert payment_of(db)["access"]["state"] == "provisional" and notes.sent == []


def test_a_pending_address_comes_due_exactly_once(db, notes):
    seed_world(db)
    db.document(f"coachPaymentProfiles/{COACH}").update(
        {"pending": {"address": "new@instapay", "accountName": "New Name", "requestedAt": NOW, "effectiveAt": at(hours=24)}})
    assert timers.hourly(db, at(hours=23), notes)["addresses"] == 0
    assert db.document(f"coachPaymentProfiles/{COACH}").get().to_dict()["address"] == "rahma@instapay"
    assert timers.hourly(db, at(hours=25), notes)["addresses"] == 1
    row = db.document(f"coachPaymentProfiles/{COACH}").get().to_dict()
    assert row["address"] == "new@instapay" and row["accountName"] == "New Name" and row["pending"] is None
    assert timers.hourly(db, at(hours=26), notes)["addresses"] == 0


def test_the_pass_is_safe_when_a_party_acts_at_the_same_moment(db, notes):
    seed_world(db)
    make_payment(db, status="confirmed", proofSubmittedAt=NOW, outcome="amber", amberUntil=at(hours=24), escalateAt=at(hours=72))
    assert timers.remind_coach(db, PAY, at(hours=49)) is None
    assert timers.grant_amber(db, PAY, at(hours=30), model.config(db)) is False
    assert payment_of(db)["status"] == "confirmed" and sub_of(db)["status"] == "awaiting_payment"


def test_a_missing_switch_document_changes_nothing_about_the_clock(db, notes):
    seed_world(db)
    make_payment(db, status="proof_submitted", proofSubmittedAt=NOW, outcome="green", escalateAt=at(hours=72))
    assert not db.document("config/payments").get().exists
    assert timers.half_hourly(db, at(hours=73), notes)["escalated"] == 1
