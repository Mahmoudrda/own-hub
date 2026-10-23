"""Cancelling inside the window and recording the refund."""

from __future__ import annotations

import datetime as dt

import pytest

from coaching import common, errors, refunds
from tests.coaching_helpers import _txn  # noqa: F401
from tests.test_coaching_subscriptions import (  # noqa: F401
    CLIENT,
    COACH,
    COACH_PRICE,
    FINAL,
    NOW,
    STAFF,
    active,
    blobs,
    db,
    later,
    pushes,
    refuse,
    sub_of,
)


def used(db, sub_id, count):
    db.document(f"subscriptions/{sub_id}").update({"sessionsUsed": count})


def ask_refund(db, sub_id, *, uid=CLIENT, now=None, **over):
    data = {"subId": sub_id, "reason": "changed my mind"}
    data.update(over)
    return refunds.request(db, uid, data, live=True, now=now or later(days=2))


def record(db, pushes, sub_id, **over):
    data = {"subId": sub_id, "decision": "refund", "rail": "instapay", "reference": "REFUND-0001", "amountEgp": 863}
    data.update(over)
    return refunds.record(db, STAFF, data, now=later(days=3), notify=pushes)


def test_the_refund_maths_match_the_contract():
    assert common.refund_amount(FINAL, 0, 4) == FINAL
    assert common.refund_amount(FINAL, 1, 4) == 863
    assert common.refund_amount(FINAL, 4, 4) == 0
    assert common.coach_share_after_refund(COACH_PRICE, 1, 4) == 250


@pytest.mark.parametrize("sessions,expected", [(0, 1150), (1, 863), (2, 575), (4, 0)])
def test_the_request_shows_the_refund(db, pushes, blobs, sessions, expected):
    sub_id = active(db, pushes, blobs)
    used(db, sub_id, sessions)
    assert ask_refund(db, sub_id) == {"state": "requested", "refundEgp": expected}
    cancellation = sub_of(db, sub_id)["cancellation"]
    assert cancellation == {
        "state": "requested", "requestedAt": later(days=2), "refundEgp": expected, "reason": "changed my mind",
    }
    assert sub_of(db, sub_id)["status"] == "active"


def test_the_window_is_fourteen_days(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    refuse(lambda: ask_refund(db, sub_id, now=later(days=14, minutes=1)), errors.PRECONDITION, errors.CANCEL_WINDOW_CLOSED)
    assert ask_refund(db, sub_id, now=later(days=14))["state"] == "requested"


def test_only_one_open_request_and_only_her_active_subscription(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    ask_refund(db, sub_id)
    refuse(lambda: ask_refund(db, sub_id), errors.PRECONDITION, errors.WRONG_STATUS)
    refuse(lambda: ask_refund(db, sub_id, uid="stranger"), errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    refuse(lambda: ask_refund(db, "missing"), errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    db.document(f"subscriptions/{sub_id}").update({"status": "ended", "cancellation": {}})
    refuse(lambda: ask_refund(db, sub_id), errors.PRECONDITION, errors.WRONG_STATUS)
    refuse(lambda: refunds.request(db, CLIENT, {"subId": sub_id}, live=False, now=NOW), errors.PRECONDITION, errors.COACH_APP_CLOSED)


def test_the_reason_is_bounded(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    refuse(lambda: ask_refund(db, sub_id, reason="x" * 301), errors.INVALID, errors.BAD_REQUEST)
    assert ask_refund(db, sub_id, reason=None)["state"] == "requested"


def test_staff_queue_is_oldest_first(db, pushes, blobs):
    first = active(db, pushes, blobs)
    used(db, first, 1)
    ask_refund(db, first, now=later(days=3))
    out = refunds.list_for_staff(db, STAFF, {}, now=NOW)
    assert [item["subId"] for item in out["items"]] == [first] and out["next"] is None
    item = out["items"][0]
    assert item["rail"] == "instapay" and item["senderName"] == "Client Name"
    assert item["sessionsUsed"] == 1 and item["cancellation"]["refundEgp"] == 863
    assert item["coachName"] == "Coach One" and item["priceFinalEgp"] == FINAL


def test_recording_a_refund_ends_the_coaching_and_settles_the_coach(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    used(db, sub_id, 1)
    ask_refund(db, sub_id)
    pushes.clear()
    assert record(db, pushes, sub_id) == {"status": "ended_early"}

    sub = sub_of(db, sub_id)
    assert sub["status"] == "ended_early" and sub["endReason"] == "refund"
    assert sub["refund"] == {"amountEgp": 863, "rail": "instapay", "reference": "REFUND-0001", "at": later(days=3)}
    assert sub["cancellation"]["state"] == "refunded"
    rel = db.document(f"relationships/{COACH}__{CLIENT}").get().to_dict()
    assert rel["status"] == "ended" and rel["chatOpen"] is False
    assert db.document(f"coaches/{COACH}").get().to_dict()["activeClients"] == 0
    ledger = db.document(f"coachPrivate/{COACH}/ledger/{sub_id}").get().to_dict()
    assert ledger["coachAmountEgp"] == 250 and ledger["status"] == "eligible" and ledger["eligibleAt"] == later(days=3)
    assert db.document(f"coachPrivate/{COACH}").get().to_dict()["owedEgp"] == 250
    assert db.document(f"receipts/{sub_id}").get().to_dict()["refund"] == {"amountEgp": 863, "at": later(days=3)}
    assert sorted(pushes) == sorted([(CLIENT, "coachingEnded"), (COACH, "coachingEnded")])
    kinds = [m.to_dict()["systemKind"] for m in db.collection(f"relationships/{COACH}__{CLIENT}/messages").stream()]
    assert kinds.count("ended") == 1


def test_no_sessions_held_reverses_the_coach_line(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    ask_refund(db, sub_id)
    record(db, pushes, sub_id, amountEgp=FINAL)
    ledger = db.document(f"coachPrivate/{COACH}/ledger/{sub_id}").get().to_dict()
    assert ledger["status"] == "reversed" and ledger["coachAmountEgp"] == 0
    assert db.document(f"coachPrivate/{COACH}").get().to_dict()["owedEgp"] == 0


def test_a_line_that_was_already_eligible_is_adjusted_in_what_is_owed(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    db.document(f"coachPrivate/{COACH}/ledger/{sub_id}").update({"status": "eligible"})
    db.document(f"coachPrivate/{COACH}").update({"owedEgp": COACH_PRICE})
    used(db, sub_id, 1)
    ask_refund(db, sub_id)
    record(db, pushes, sub_id)
    assert db.document(f"coachPrivate/{COACH}").get().to_dict()["owedEgp"] == 250


def test_declining_keeps_the_subscription_running(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    ask_refund(db, sub_id)
    pushes.clear()
    assert record(db, pushes, sub_id, decision="decline") == {"status": "active"}
    sub = sub_of(db, sub_id)
    assert sub["status"] == "active" and sub["cancellation"]["state"] == "declined"
    assert db.document(f"relationships/{COACH}__{CLIENT}").get().to_dict()["chatOpen"] is True
    assert pushes == []


@pytest.mark.parametrize(
    "over",
    [
        {"decision": "maybe"},
        {"rail": "paypal"},
        {"reference": "short"},
        {"amountEgp": -1},
        {"amountEgp": FINAL + 1},
        {"amountEgp": 10.5},
        {"amountEgp": None},
    ],
)
def test_bad_refund_input_is_refused(db, pushes, blobs, over):
    sub_id = active(db, pushes, blobs)
    ask_refund(db, sub_id)
    refuse(lambda: record(db, pushes, sub_id, **over), errors.INVALID, errors.BAD_REQUEST)
    assert sub_of(db, sub_id)["status"] == "active"


def test_recording_needs_an_open_request_on_an_active_subscription(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    refuse(lambda: record(db, pushes, sub_id), errors.PRECONDITION, errors.WRONG_STATUS)
    refuse(lambda: record(db, pushes, "missing"), errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    ask_refund(db, sub_id)
    record(db, pushes, sub_id, amountEgp=FINAL)
    refuse(lambda: record(db, pushes, sub_id, amountEgp=FINAL), errors.PRECONDITION, errors.WRONG_STATUS)


# -- the server decides the amount and the rail ------------------------------------


@pytest.mark.parametrize("amount", [0, 1, 862, 864, FINAL])
def test_a_refund_amount_other_than_the_servers_is_refused(db, pushes, blobs, amount):
    sub_id = active(db, pushes, blobs)
    used(db, sub_id, 1)
    ask_refund(db, sub_id)
    before = dict(db.docs)
    refuse(lambda: record(db, pushes, sub_id, amountEgp=amount), errors.INVALID, errors.BAD_REQUEST)
    assert sub_of(db, sub_id)["status"] == "active" and "refund" not in sub_of(db, sub_id)


def test_the_refund_must_go_back_by_the_rail_she_paid_with(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    ask_refund(db, sub_id)
    refuse(lambda: record(db, pushes, sub_id, amountEgp=FINAL, rail="vodafoneCash", reference="01012345678"),
           errors.INVALID, errors.BAD_REQUEST)
    assert sub_of(db, sub_id)["status"] == "active"
    assert record(db, pushes, sub_id, amountEgp=FINAL) == {"status": "ended_early"}


def test_the_server_amount_follows_the_sessions_held_when_the_refund_is_recorded(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    ask_refund(db, sub_id)
    used(db, sub_id, 2)
    refuse(lambda: record(db, pushes, sub_id, amountEgp=FINAL), errors.INVALID, errors.BAD_REQUEST)
    assert record(db, pushes, sub_id, amountEgp=575)["status"] == "ended_early"


@pytest.mark.parametrize("actor", [CLIENT, COACH])
def test_staff_never_record_a_refund_on_their_own_subscription(db, pushes, blobs, actor):
    sub_id = active(db, pushes, blobs)
    ask_refund(db, sub_id)
    data = {"subId": sub_id, "decision": "refund", "rail": "instapay", "reference": "REFUND-0001", "amountEgp": FINAL}
    refuse(lambda: refunds.record(db, actor, data, now=later(days=3), notify=pushes),
           errors.PERMISSION, errors.STAFF_IS_SUBJECT)
    refuse(lambda: refunds.record(db, actor, {"subId": sub_id, "decision": "decline"}, now=later(days=3), notify=pushes),
           errors.PERMISSION, errors.STAFF_IS_SUBJECT)
    assert sub_of(db, sub_id)["cancellation"]["state"] == "requested"


def test_a_requested_cancellation_is_not_ended_by_the_sweeper(db, pushes, blobs):
    from coaching import subscriptions

    sub_id = active(db, pushes, blobs)
    ask_refund(db, sub_id, now=later(days=10))
    counts = subscriptions.sweep(db, now=later(days=40), notify=pushes, payments=True)
    assert counts["ended"] == 0 and sub_of(db, sub_id)["status"] == "active"
    assert record(db, pushes, sub_id, amountEgp=FINAL)["status"] == "ended_early"


def test_a_cancellation_requested_after_the_sweep_looked_is_still_not_ended(db, pushes, blobs):
    from coaching import subscriptions

    sub_id = active(db, pushes, blobs)
    ask_refund(db, sub_id, now=later(days=10))
    assert subscriptions._finish(db, sub_id, later(days=40)) is None
    assert sub_of(db, sub_id)["status"] == "active"
