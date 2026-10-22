"""The hourly sweeper: every branch."""

from __future__ import annotations

import datetime as dt

from coaching import subscriptions
from tests import fake_firestore
from tests.coaching_helpers import _txn  # noqa: F401
from tests.test_coaching_subscriptions import (  # noqa: F401
    CLIENT,
    COACH,
    COACH_PRICE,
    NOW,
    active,
    ask,
    blobs,
    db,
    later,
    pushes,
    seed,
    sub_of,
)



def test_requests_expire_after_the_answer_window(db, pushes):
    seed(db, auto=False)
    fresh = ask(db, pushes, now=later(hours=-71))["subId"]
    old = db.collection("subscriptions").document()
    old.set({"status": "requested", "coachUid": COACH, "clientUid": "x", "createdAt": later(hours=-73), "statusAt": later(hours=-73)})
    counts = subscriptions.sweep(db, now=NOW, notify=pushes, payments=True)
    assert counts["expiredRequests"] == 1
    assert old.get().to_dict()["status"] == "expired"
    assert sub_of(db, fresh)["status"] == "requested"


def test_unpaid_subscriptions_expire_at_pay_by(db, pushes):
    seed(db)
    overdue = ask(db, pushes, now=later(hours=-73))["subId"]
    still = ask(db, pushes, uid="client-2", now=later(hours=-71))["subId"]
    counts = subscriptions.sweep(db, now=NOW, notify=pushes, payments=True)
    assert counts["expiredPayments"] == 1
    assert sub_of(db, overdue)["status"] == "expired" and sub_of(db, still)["status"] == "awaiting_payment"


def test_a_finished_subscription_ends(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    pushes.clear()
    counts = subscriptions.sweep(db, now=later(days=28, minutes=1), notify=pushes, payments=True)
    assert counts["ended"] == 1
    assert sub_of(db, sub_id)["status"] == "ended"
    rel = db.document(f"relationships/{COACH}__{CLIENT}").get().to_dict()
    assert rel["status"] == "ended" and rel["chatOpen"] is False
    assert db.document(f"coaches/{COACH}").get().to_dict()["activeClients"] == 0
    messages = [m.to_dict().get("systemKind") for m in db.collection(f"relationships/{COACH}__{CLIENT}/messages").stream()]
    assert messages.count("ended") == 1
    assert sorted(pushes) == sorted([(CLIENT, "coachingEnded"), (COACH, "coachingEnded")])
    assert subscriptions.sweep(db, now=later(days=29), notify=pushes, payments=True)["ended"] == 0


def test_ends_soon_is_pushed_once(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    pushes.clear()
    assert subscriptions.sweep(db, now=later(days=24), notify=pushes, payments=True)["endsSoon"] == 0
    assert subscriptions.sweep(db, now=later(days=25, hours=1), notify=pushes, payments=True)["endsSoon"] == 1
    assert pushes == [(CLIENT, "endsSoon")]
    assert sub_of(db, sub_id)["endsSoonSent"] is True
    assert subscriptions.sweep(db, now=later(days=26), notify=pushes, payments=True)["endsSoon"] == 0
    assert pushes == [(CLIENT, "endsSoon")]


def test_ledger_turns_eligible_after_the_wait(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    path = f"coachPrivate/{COACH}/ledger/{sub_id}"
    assert subscriptions.sweep(db, now=later(days=13), notify=pushes, payments=True)["ledgerEligible"] == 0
    assert db.document(path).get().to_dict()["status"] == "pending"
    assert subscriptions.sweep(db, now=later(days=14, minutes=1), notify=pushes, payments=True)["ledgerEligible"] == 1
    assert db.document(path).get().to_dict()["status"] == "eligible"
    assert db.document(f"coachPrivate/{COACH}").get().to_dict()["owedEgp"] == COACH_PRICE
    assert subscriptions.sweep(db, now=later(days=15), notify=pushes, payments=True)["ledgerEligible"] == 0
    assert db.document(f"coachPrivate/{COACH}").get().to_dict()["owedEgp"] == COACH_PRICE


def test_her_share_waits_while_a_refund_request_is_open(db, pushes, blobs):
    # Asked on day 13, decided after the payout delay: nothing may be paid
    # that the refund could take back.
    from coaching import payouts

    sub_id = active(db, pushes, blobs)
    db.document(f"subscriptions/{sub_id}").update(
        {"cancellation": {"state": "requested", "requestedAt": later(days=13), "refundEgp": 1}}
    )
    path = f"coachPrivate/{COACH}/ledger/{sub_id}"
    assert subscriptions.sweep(db, now=later(days=15), notify=pushes, payments=True)["ledgerEligible"] == 0
    assert db.document(path).get().to_dict()["status"] == "pending"

    # A line made eligible some other way is still not paid out.
    db.document(path).update({"status": "eligible"})
    db.document(f"coachPrivate/{COACH}").set(
        {"payoutState": "confirmed", "payout": {"rail": "instapay", "account": "coach@instapay"}}, merge=True
    )
    refused = None
    try:
        payouts.record(
            db, "staff-9",
            {"coachUid": COACH, "entryIds": [sub_id], "rail": "instapay", "reference": "PAYOUT-0001", "paidAt": "2026-10-06"},
            now=later(days=15), notify=pushes,
        )
    except Exception as error:  # noqa: BLE001
        refused = getattr(error, "reason", None)
    assert refused == "wrong_status"

    # Once staff decline the request, the share is released on the next pass.
    db.document(path).update({"status": "pending"})
    db.document(f"subscriptions/{sub_id}").update({"cancellation.state": "declined"})
    assert subscriptions.sweep(db, now=later(days=16), notify=pushes, payments=True)["ledgerEligible"] == 1


def test_old_proof_images_are_counted(db, pushes):
    seed(db)
    for name, age, path, status in [
        ("old", 8, "payment-proofs/a/1.jpg", "pending"),
        ("fresh", 6, "payment-proofs/a/2.jpg", "pending"),
        ("gone", 9, None, "approved"),
    ]:
        db.document(f"paymentProofs/{name}").set(
            {"status": status, "imagePath": path, "createdAt": NOW - dt.timedelta(days=age), "subId": name}
        )
    assert subscriptions.sweep(db, now=NOW, notify=pushes, payments=True)["staleProofImages"] == 1


def test_the_sweep_reads_only_the_subscriptions_that_are_due(db, monkeypatch):
    far = NOW + dt.timedelta(days=30)
    for index in range(40):
        db.document(f"subscriptions/r{index}").set(
            {"status": "requested", "coachUid": COACH, "clientUid": "x", "statusAt": later(hours=-1)}
        )
        db.document(f"subscriptions/p{index}").set(
            {"status": "awaiting_payment", "coachUid": COACH, "clientUid": "x", "payBy": far, "statusAt": NOW}
        )
        db.document(f"subscriptions/a{index}").set(
            {"status": "active", "coachUid": COACH, "clientUid": "x", "relId": "r", "endsAt": far, "statusAt": NOW}
        )
    db.document("subscriptions/due-request").set(
        {"status": "requested", "coachUid": COACH, "clientUid": "x", "statusAt": later(hours=-80)}
    )
    db.document("subscriptions/due-payment").set(
        {"status": "awaiting_payment", "coachUid": COACH, "clientUid": "x", "payBy": later(hours=-1), "statusAt": NOW}
    )
    streamed = []
    real = fake_firestore.CollectionRef.stream

    def counting(self, transaction=None):
        rows = list(real(self, transaction))
        if self.path == "subscriptions":
            streamed.extend(row.id for row in rows)
        return iter(rows)

    monkeypatch.setattr(fake_firestore.CollectionRef, "stream", counting)
    counts = subscriptions.sweep(db, now=NOW, notify=lambda *_: None, payments=True)
    assert (counts["expiredRequests"], counts["expiredPayments"], counts["ended"]) == (1, 1, 0)
    assert sorted(streamed) == ["due-payment", "due-request"]


def test_a_subscription_ending_within_three_days_is_warned_once(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    pushes.clear()
    near = later(days=26)
    assert subscriptions.sweep(db, now=near, notify=pushes, payments=True)["endsSoon"] == 1
    assert pushes == [(CLIENT, "endsSoon")]
    assert subscriptions.sweep(db, now=near, notify=pushes, payments=True)["endsSoon"] == 0
    assert sub_of(db, sub_id)["status"] == "active"
