"""Either party ends a free coaching, and a block ends it too."""

from __future__ import annotations

import pytest

from coaching import common, errors, subscriptions
from tests.coaching_helpers import _txn  # noqa: F401
from tests.test_coaching_free import answer, ask, coach, messages, rel
from tests.test_coaching_subscriptions import (  # noqa: F401
    CLIENT, COACH, NOW, db, later, pushes, refuse, seed, sub_of,
)


def leave(db, pushes, sub_id, uid, *, live=True, **extra):
    return subscriptions.end_mine(
        db, uid, {"subId": sub_id, **extra}, live=live, now=later(days=1), notify=pushes
    )


def running(db, pushes):
    seed(db, auto=False)
    sub_id = ask(db, pushes)["subId"]
    answer(db, pushes, sub_id)
    pushes.clear()
    return sub_id


@pytest.mark.parametrize("who, why, other", [(CLIENT, "client_left", COACH), (COACH, "coach_left", CLIENT)])
def test_either_party_ends_a_running_coaching(db, pushes, who, why, other):
    sub_id = running(db, pushes)
    assert leave(db, pushes, sub_id, who, reason="moving on") == {"status": "ended_early"}
    row = sub_of(db, sub_id)
    assert row["status"] == "ended_early" and row["endReason"] == why and row["nextSessionAt"] is None
    assert rel(db)["status"] == "ended" and rel(db)["chatOpen"] is False
    assert coach(db)["activeClients"] == 0
    assert sorted(m["systemKind"] for m in messages(db)) == ["ended", "started"]
    assert pushes == [(other, "coachingEnded")]


@pytest.mark.parametrize("who", [CLIENT, COACH])
def test_a_request_not_yet_answered_is_cancelled(db, pushes, who):
    seed(db, auto=False)
    sub_id = ask(db, pushes)["subId"]
    assert leave(db, pushes, sub_id, who) == {"status": "cancelled"}
    assert sub_of(db, sub_id)["status"] == "cancelled" and coach(db)["activeClients"] == 0


def test_a_coaching_waiting_for_the_transfer_ends_without_touching_a_place(db, pushes):
    seed(db)
    sub_id = ask(db, pushes, payments=True)["subId"]
    assert sub_of(db, sub_id)["status"] == "awaiting_payment"
    assert leave(db, pushes, sub_id, CLIENT) == {"status": "ended_early"}
    assert sub_of(db, sub_id)["endReason"] == "client_left" and coach(db)["activeClients"] == 0


def test_a_stranger_or_a_missing_coaching_is_not_found(db, pushes):
    sub_id = running(db, pushes)
    for uid, sid in (("stranger", sub_id), (CLIENT, "gone")):
        refuse(lambda: leave(db, pushes, sid, uid), errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    assert sub_of(db, sub_id)["status"] == "active"


@pytest.mark.parametrize("status", ["ended", "ended_early", "declined", "cancelled", "expired", "payment_review"])
def test_only_an_open_coaching_can_be_ended_by_a_party(db, pushes, status):
    sub_id = running(db, pushes)
    db.document(f"subscriptions/{sub_id}").update({"status": status})
    refuse(lambda: leave(db, pushes, sub_id, CLIENT), errors.PRECONDITION, errors.WRONG_STATUS)
    assert pushes == []


def test_a_cancellation_waiting_for_staff_is_not_ended_by_leaving(db, pushes):
    sub_id = running(db, pushes)
    db.document(f"subscriptions/{sub_id}").update({"cancellation": {"state": "requested"}})
    refuse(lambda: leave(db, pushes, sub_id, CLIENT), errors.PRECONDITION, errors.WRONG_STATUS)


def test_leaving_needs_the_clients_switch_and_a_sub_id(db, pushes):
    sub_id = running(db, pushes)
    refuse(lambda: leave(db, pushes, sub_id, CLIENT, live=False), errors.PRECONDITION, errors.COACH_APP_CLOSED)
    refuse(lambda: subscriptions.end_mine(db, CLIENT, {}, live=True, now=NOW, notify=pushes), errors.INVALID, errors.BAD_REQUEST)
    refuse(lambda: leave(db, pushes, sub_id, CLIENT, reason=5), errors.INVALID, errors.BAD_REQUEST)


# ----------------------------------------------------------------- blocks


@pytest.mark.parametrize("blocker, blocked", [(CLIENT, COACH), (COACH, CLIENT)])
def test_a_block_ends_the_running_coaching_for_safety_and_pushes_nobody(db, pushes, blocker, blocked):
    sub_id = running(db, pushes)
    assert subscriptions.end_for_block(db, blocker, blocked, now=later(days=1)) == 1
    row = sub_of(db, sub_id)
    assert row["status"] == "ended_early" and row["endReason"] == "safety"
    assert rel(db)["chatOpen"] is False and coach(db)["activeClients"] == 0
    assert pushes == []


def test_a_block_cancels_a_request_and_leaves_other_pairs_alone(db, pushes):
    seed(db, auto=False)
    mine = ask(db, pushes)["subId"]
    other = ask(db, pushes, uid="client-2")["subId"]
    assert subscriptions.end_for_block(db, CLIENT, COACH, now=NOW) == 1
    assert sub_of(db, mine)["status"] == "cancelled" and sub_of(db, other)["status"] == "requested"


def test_a_block_between_two_people_with_no_coaching_does_nothing(db, pushes):
    seed(db, auto=False)
    assert subscriptions.end_for_block(db, "a", "b", now=NOW) == 0
    assert subscriptions.end_for_block(db, CLIENT, COACH, now=NOW) == 0


def test_a_block_does_not_end_money_in_review(db, pushes):
    sub_id = running(db, pushes)
    db.document(f"subscriptions/{sub_id}").update({"status": "payment_review"})
    assert subscriptions.end_for_block(db, CLIENT, COACH, now=NOW) == 0
    assert sub_of(db, sub_id)["status"] == "payment_review"


def test_blocked_either_sees_both_directions(db):
    assert common.run(db, lambda t: subscriptions.blocked_either(t, db, "a", "b")) is False
    db.document("users/b/blocks/a").set({})
    assert common.run(db, lambda t: subscriptions.blocked_either(t, db, "a", "b")) is True
    assert common.run(db, lambda t: subscriptions.blocked_either(t, db, "b", "a")) is True
