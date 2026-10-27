"""Tests for create_payment, cancel_payment, activation and coaching request hooks."""

from __future__ import annotations

import random
import re

import pytest

from coaching import common, subscriptions
from payments import activation, cancel, create, engine, errors, model, profile, states
from tests.coaching_helpers import Pushes
from tests.payments_helpers import (  # noqa: F401
    CLIENT, COACH, NOW, PAY, REVIEWER, SUB, _txn, db, events, later, make_payment, payment_of, refusal, seed_world,
)
from tests.test_coaching_subscriptions import PACKAGE, consent, intake, seed


def go(db, **over):
    payload = {"subId": SUB, "idempotencyKey": "key-0001-abcd", **over}
    return create.create(db, CLIENT, payload, now=NOW, on=True, rng=random.Random(1))


def test_create_makes_one_payment_with_a_unique_amount_and_a_copy_of_the_address(db):
    seed_world(db)
    res = go(db)
    assert res["status"] == "awaiting_payment"
    assert 50001 <= res["amountPiasters"] <= 50099
    assert re.match(r"^OH-[A-Z2-9]{6}$", res["reference"])
    assert not any(c in res["reference"][3:] for c in "01OIL")

    stored = payment_of(db, res["paymentId"])
    assert stored["addressSnapshot"] == {"address": "rahma@instapay", "accountName": "Rahma Mohsen"}
    assert stored["expiresAt"] == later(hours=24)
    assert stored["lateUntil"] == later(days=7)
    assert stored["lockId"] == f"{COACH}__{res['amountPiasters']}"
    assert stored["staffVisible"] is True

    evs = events(db, res["paymentId"])
    assert evs == [(None, "awaiting_payment", "client")]

    lock = db.document(f"paymentAmountLocks/{stored['lockId']}").get().to_dict()
    assert lock["amountPiasters"] == res["amountPiasters"]
    assert lock["paymentId"] == res["paymentId"]

    prof = db.document(f"coachPaymentProfiles/{COACH}").get().to_dict()
    assert prof["paymentsCreated"] == 1

    sub = db.document(f"subscriptions/{SUB}").get().to_dict()
    assert sub["payment"]["paymentId"] == res["paymentId"]


def test_a_repeat_with_the_same_key_returns_the_first_answer_and_makes_no_second_payment(db):
    seed_world(db)
    res1 = go(db)
    res2 = go(db)
    assert res1["paymentId"] == res2["paymentId"]
    assert len(list(db.collection("payments").stream())) == 1


def test_switch_off_refuses_and_writes_nothing(db):
    seed_world(db)
    err = refusal(lambda: create.create(db, CLIENT, {"subId": SUB, "idempotencyKey": "key-0001-abcd"}, now=NOW, on=False))
    assert err == (errors.PRECONDITION, errors.PAYMENTS_OFF)
    assert len(list(db.collection("payments").stream())) == 0


def test_someone_elses_subscription_and_a_wrong_status_are_refused(db):
    seed_world(db)
    err1 = refusal(lambda: create.create(db, "other", {"subId": SUB, "idempotencyKey": "key-0001-abcd"}, now=NOW, on=True))
    assert err1 == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)

    db.document(f"subscriptions/{SUB}").update({"status": "active"})
    err2 = refusal(lambda: go(db))
    assert err2 == (errors.PRECONDITION, errors.WRONG_STATUS)


def test_coach_not_ready_when_she_has_no_address_or_is_suspended(db):
    seed_world(db)
    db.document(f"coachPaymentProfiles/{COACH}").update({"address": None})
    assert refusal(lambda: go(db)) == (errors.PRECONDITION, errors.COACH_NOT_READY)

    db.document(f"coachPaymentProfiles/{COACH}").update({"address": "rahma@instapay"})
    db.document(f"coachPrivate/{COACH}").update({"suspended": True})
    assert refusal(lambda: go(db)) == (errors.PRECONDITION, errors.COACH_PAYMENTS_SUSPENDED)


def test_a_suspended_client_cannot_start_a_payment(db):
    seed_world(db)
    db.document(f"paymentStanding/{CLIENT}").set({"clientSuspended": True})
    assert refusal(lambda: go(db)) == (errors.PRECONDITION, errors.CLIENT_PAYMENTS_SUSPENDED)


def test_a_pending_address_is_used_only_after_its_delay(db):
    seed_world(db)
    db.document(f"coachPaymentProfiles/{COACH}").update({
        "pending": {"address": "new@instapay", "accountName": "N", "effectiveAt": later(hours=1)}
    })
    res1 = go(db)
    stored1 = payment_of(db, res1["paymentId"])
    assert stored1["addressSnapshot"]["address"] == "rahma@instapay"

    # Effective in the past
    db.document(f"coachPaymentProfiles/{COACH}").update({
        "pending": {"address": "new@instapay", "accountName": "N", "effectiveAt": later(hours=-1)}
    })
    cancel.cancel(db, CLIENT, {"paymentId": res1["paymentId"]}, now=NOW)
    res2 = go(db, idempotencyKey="key-0002-abcd")
    stored2 = payment_of(db, res2["paymentId"])
    assert stored2["addressSnapshot"]["address"] == "new@instapay"


def test_price_over_the_limit_is_refused(db):
    seed_world(db)
    db.document("coachingConfig/instapay").set({"maxAmountEgp": 400})
    assert refusal(lambda: go(db)) == (errors.PRECONDITION, errors.AMOUNT_OVER_LIMIT)


def test_one_open_payment_per_client_and_package(db):
    seed_world(db)
    res = go(db)
    assert refusal(lambda: go(db, idempotencyKey="key-0002-abcd")) == (errors.PRECONDITION, errors.OPEN_PAYMENT_EXISTS)
    cancel.cancel(db, CLIENT, {"paymentId": res["paymentId"]}, now=NOW)
    res2 = go(db, idempotencyKey="key-0003-abcd")
    assert res2["paymentId"] != res["paymentId"]


def test_three_requests_per_day_then_refused(db):
    seed_world(db)
    for i in range(3):
        sub_id = f"sub-{i}"
        db.document(f"subscriptions/{sub_id}").set({
            "coachUid": COACH, "clientUid": CLIENT, "relId": f"{COACH}__{CLIENT}", "packageId": "pk0",
            "package": {"title": "P0", "durationDays": 28}, "priceFinalEgp": 500,
            "status": "awaiting_payment", "statusAt": NOW,
        })
        p = create.create(db, CLIENT, {"subId": sub_id, "idempotencyKey": f"key-000{i}-abcd"}, now=NOW, on=True, rng=random.Random(i))
        cancel.cancel(db, CLIENT, {"paymentId": p["paymentId"]}, now=NOW)

    sub4 = "sub-4"
    db.document(f"subscriptions/{sub4}").set({
        "coachUid": COACH, "clientUid": CLIENT, "relId": f"{COACH}__{CLIENT}", "packageId": "pk0",
        "package": {"title": "P0", "durationDays": 28}, "priceFinalEgp": 500,
        "status": "awaiting_payment", "statusAt": NOW,
    })
    assert refusal(lambda: create.create(db, CLIENT, {"subId": sub4, "idempotencyKey": "key-0004-abcd"}, now=NOW, on=True)) == (errors.EXHAUSTED, errors.TOO_MANY_REQUESTS)
    # 25 hours later works
    p4 = create.create(db, CLIENT, {"subId": sub4, "idempotencyKey": "key-0004-abcd"}, now=later(hours=25), on=True)
    assert p4["status"] == "awaiting_payment"


def test_first_payment_is_the_shortest_package_unless_allowed(db):
    seed_world(db, durations=(28, 56))
    db.document(f"subscriptions/{SUB}").update({"package": {"title": "P1", "durationDays": 56}})
    assert refusal(lambda: go(db)) == (errors.PRECONDITION, errors.FIRST_PAYMENT_SHORTEST_ONLY)

    # Allowed by coach
    db.document(f"coachPaymentProfiles/{COACH}").update({"allowLongFirst": True})
    assert go(db)["status"] == "awaiting_payment"


def test_a_collision_cannot_happen_two_clients_same_coach(db):
    seed_world(db)
    sub2 = "sub-2"
    db.document(f"subscriptions/{sub2}").set({
        "coachUid": COACH, "clientUid": "client-2", "relId": f"{COACH}__client-2", "packageId": "pk0",
        "package": {"title": "P0", "durationDays": 28}, "priceFinalEgp": 500,
        "status": "awaiting_payment", "statusAt": NOW,
    })
    p1 = go(db)
    p2 = create.create(db, "client-2", {"subId": sub2, "idempotencyKey": "key-client2-abc"}, now=NOW, on=True, rng=random.Random(1))
    assert p1["amountPiasters"] != p2["amountPiasters"]


def test_the_third_payment_of_a_new_coach_is_staff_visible_the_fourth_is_not(db):
    seed_world(db)
    db.document(f"coachPaymentProfiles/{COACH}").update({"paymentsCreated": 2})
    p3 = go(db)
    assert payment_of(db, p3["paymentId"])["staffVisible"] is True

    cancel.cancel(db, CLIENT, {"paymentId": p3["paymentId"]}, now=NOW)
    p4 = go(db, idempotencyKey="key-new4-000000")
    assert payment_of(db, p4["paymentId"])["staffVisible"] is False


def test_cancel_ends_the_request_frees_the_amount_and_is_safe_to_repeat(db):
    seed_world(db)
    p = go(db)
    c1 = cancel.cancel(db, CLIENT, {"paymentId": p["paymentId"]}, now=NOW)
    assert c1 == {"status": "cancelled"}
    c2 = cancel.cancel(db, CLIENT, {"paymentId": p["paymentId"]}, now=NOW)
    assert c2 == {"status": "cancelled"}
    lock = db.document(f"paymentAmountLocks/{payment_of(db, p['paymentId'])['lockId']}").get().to_dict()
    assert lock["heldUntil"] == NOW
    evs = events(db, p["paymentId"])
    assert set(evs) == {(None, "awaiting_payment", "client"), ("awaiting_payment", "cancelled", "client")}

    assert refusal(lambda: cancel.cancel(db, "stranger", {"paymentId": p["paymentId"]}, now=NOW)) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)


def test_grant_starts_the_coaching_and_provisional_becomes_full(db):
    seed_world(db)
    def body(t):
        seen = activation.read_for_start(t, db, SUB)
        return activation.grant(t, db, seen, NOW, provisional_until=later(days=7))

    res1 = common.run(db, body)
    assert res1 == "started"
    sub = db.document(f"subscriptions/{SUB}").get().to_dict()
    assert sub["status"] == "active"
    assert sub["provisionalUntil"] == later(days=7)
    coach = db.document(f"coaches/{COACH}").get().to_dict()
    assert coach["activeClients"] == 1

    # Upgrade to full
    def body2(t):
        seen = activation.read_for_start(t, db, SUB)
        return activation.grant(t, db, seen, NOW, provisional_until=None)

    res2 = common.run(db, body2)
    assert res2 == "upgraded"
    sub2 = db.document(f"subscriptions/{SUB}").get().to_dict()
    assert sub2["provisionalUntil"] is None

    # Third call is unchanged
    res3 = common.run(db, body2)
    assert res3 == "unchanged"
    assert db.document(f"coaches/{COACH}").get().to_dict()["activeClients"] == 1


def test_end_stops_a_running_coaching_and_frees_the_place(db):
    seed_world(db)
    common.run(db, lambda t: activation.grant(t, db, activation.read_for_start(t, db, SUB), NOW))
    assert db.document(f"coaches/{COACH}").get().to_dict()["activeClients"] == 1

    def body(t):
        read = activation.read_for_end(t, db, SUB)
        return activation.end(t, db, SUB, read, "dispute", NOW)

    ended = common.run(db, body)
    assert ended is True
    sub = db.document(f"subscriptions/{SUB}").get().to_dict()
    assert sub["status"] == "ended_early"
    assert sub["endReason"] == "dispute"
    assert db.document(f"coaches/{COACH}").get().to_dict()["activeClients"] == 0

    assert common.run(db, body) is False


def test_grant_refuses_a_subscription_that_is_not_waiting(db):
    seed_world(db)
    db.document(f"subscriptions/{SUB}").update({"status": "ended"})
    err = refusal(lambda: common.run(db, lambda t: activation.grant(t, db, activation.read_for_start(t, db, SUB), NOW)))
    assert err == (errors.PRECONDITION, errors.WRONG_STATUS)


# Hook tests
def test_respond_with_instapay_waits_for_payment_without_payto(db):
    seed(db, auto=False, accounts=False)
    db.document(f"coaches/{COACH}").update({"instapayReady": True})
    req = subscriptions.request(
        db, CLIENT,
        {"coachUid": COACH, "packageId": PACKAGE, "consent": consent(), "intake": intake(), "locale": "en"},
        live=True, verified=True, now=NOW, notify=Pushes(), instapay=True, payments_live=False,
    )
    sub_id = req["subId"]
    subscriptions.respond(
        db, COACH, {"subId": sub_id, "decision": "accept"},
        live=True, coach_v="active", now=NOW, notify=Pushes(), instapay=True, payments_live=False,
    )
    sub = db.document(f"subscriptions/{sub_id}").get().to_dict()
    assert sub["status"] == "awaiting_payment"
    assert "payTo" not in sub
    assert sub["paymentCode"] is None
    assert sub["payBy"] == later(days=7)


def test_respond_refuses_when_the_coach_has_no_address(db):
    seed(db, auto=False, accounts=False)
    req = subscriptions.request(
        db, CLIENT,
        {"coachUid": COACH, "packageId": PACKAGE, "consent": consent(), "intake": intake(), "locale": "en"},
        live=True, verified=True, now=NOW, notify=Pushes(), instapay=False, payments_live=False,
    )
    sub_id = req["subId"]
    err = refusal(lambda: subscriptions.respond(
        db, COACH, {"subId": sub_id, "decision": "accept"},
        live=True, coach_v="active", now=NOW, notify=Pushes(), instapay=True, payments_live=False,
    ))
    assert err == (errors.PRECONDITION, "coach_not_ready")


def test_request_auto_accept_with_instapay_waits_for_payment(db):
    seed(db, auto=True, accounts=False)
    db.document(f"coaches/{COACH}").update({"instapayReady": True})
    req = subscriptions.request(
        db, CLIENT,
        {"coachUid": COACH, "packageId": PACKAGE, "consent": consent(), "intake": intake(), "locale": "en"},
        live=True, verified=True, now=NOW, notify=Pushes(), instapay=True, payments_live=False,
    )
    sub = db.document(f"subscriptions/{req['subId']}").get().to_dict()
    assert sub["status"] == "awaiting_payment"

    db.document(f"coaches/{COACH}").update({"instapayReady": False})
    err = refusal(lambda: subscriptions.request(
        db, "client-uid-2",
        {"coachUid": COACH, "packageId": PACKAGE, "consent": consent(), "intake": intake(), "locale": "en"},
        live=True, verified=True, now=NOW, notify=Pushes(), instapay=True, payments_live=False,
    ))
    assert err == (errors.PRECONDITION, "coach_unavailable")


def test_with_the_switch_off_acceptance_is_free_as_today(db):
    seed(db, auto=True, accounts=False)
    req = subscriptions.request(
        db, CLIENT,
        {"coachUid": COACH, "packageId": PACKAGE, "consent": consent(), "intake": intake(), "locale": "en"},
        live=True, verified=True, now=NOW, notify=Pushes(), instapay=False, payments_live=False,
    )
    sub = db.document(f"subscriptions/{req['subId']}").get().to_dict()
    assert sub["status"] == "active"


def test_sweep_expires_an_unpaid_instapay_acceptance_after_seven_days(db):
    seed(db, auto=True, accounts=False)
    db.document(f"coaches/{COACH}").update({"instapayReady": True})
    req = subscriptions.request(
        db, CLIENT,
        {"coachUid": COACH, "packageId": PACKAGE, "consent": consent(), "intake": intake(), "locale": "en"},
        live=True, verified=True, now=NOW, notify=Pushes(), instapay=True, payments_live=False,
    )
    sub_id = req["subId"]
    subscriptions.sweep(db, now=later(days=8), notify=Pushes(), payments=True)
    assert db.document(f"subscriptions/{sub_id}").get().to_dict()["status"] == "expired"
