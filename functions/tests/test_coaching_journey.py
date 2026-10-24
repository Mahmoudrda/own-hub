"""One coaching relationship from the first application to the coach's payout,
through the pure modules on one fake Firestore and one fake bucket, with a
clock the test moves by hand. Each step checks what the step before left."""

from __future__ import annotations

import datetime as dt
import json
import os

import pytest

from coaching import applications, chat, common, errors, packages, payouts, profiles, proofs, refunds
from coaching import plans, sessions, subscriptions
from tests import fake_firestore
from tests.coaching_helpers import Pushes, _txn  # noqa: F401
from tests.fake_blobs import FakeBlobs
from tests.test_coaching_applications import all_paths, valid
from tests.test_coaching_plans import IDS, meal, workout
from tests.test_coaching_subscriptions import (
    codes,
    consent,
    intake,
    keep,
    make_jpeg,
    refuse,
)

T0 = dt.datetime(2026, 10, 20, 12, tzinfo=dt.timezone.utc)
COACH = "coach-1"
CLIENT = "client-a"
SECOND = "client-b"
THIRD = "client-c"
REVIEWER = "reviewer-1"
FINANCE = "finance-1"
REL = f"{COACH}__{CLIENT}"

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
with open(os.path.join(ROOT, "contracts", "coaching_price_vectors.json"), encoding="utf-8") as handle:
    VECTORS = json.load(handle)["vectors"]


def at(**delta):
    return T0 + dt.timedelta(**delta)


class Claims:
    def __init__(self):
        self.calls = []

    def __call__(self, uid, changes):
        self.calls.append((uid, changes))


class World:
    def __init__(self):
        self.db = fake_firestore.FakeFirestore()
        self.blobs = FakeBlobs()
        self.pushes = Pushes()
        self.claims = Claims()
        for path in all_paths(valid(COACH)):
            self.blobs.put(path, b"file", "image/jpeg")
        self.db.document("coachingConfig/receivingAccounts").set(
            {
                "instapay": {"address": "ownhub@instapay", "holderName": "Own Hub", "enabled": True},
                "vodafoneCash": {"address": "01012345678", "holderName": "Own Hub", "enabled": False},
                "version": 1,
            }
        )
        self.db.document("coachingConfig/seller").set(
            {
                "companyNameEn": "Own Hub LLC", "companyNameAr": "اون هب", "addressEn": "1 Street, Cairo",
                "addressAr": "شارع 1 القاهرة", "commercialRegistration": "CR-1", "taxCard": "TC-1",
                "vatRatePercent": 14, "supportEmail": "help@ownhub.app", "supportPhone": "",
            }
        )

    # -- steps ------------------------------------------------------------
    def become_a_coach(self, price=1000):
        applications.submit(
            self.db, COACH, valid(COACH), live=True, verified=True, coach_v=None, blobs=self.blobs, now=T0,
            payments_live=True,
        )
        applications.decide(
            self.db, REVIEWER,
            {"uid": COACH, "decision": "approve", "checkedCertificates": ["nasm-cpt"], "note": ""},
            merge_claims=self.claims, blobs=self.blobs, notify=self.pushes, reencode=lambda raw, long_side=None: raw, now=T0,
        )
        profiles.confirm_payout(self.db, FINANCE, {"uid": COACH, "decision": "confirm"}, now=T0)
        return packages.save(
            self.db, COACH,
            {
                "title": "Strong in four weeks", "description": "A plan, live calls and daily support for a month.",
                "durationDays": 28, "includes": ["Workout plan", "Meal plan"], "liveSessionsPerMonth": 4,
                "sessionMinutes": 45, "checkInsPerWeek": 2, "coachPriceEgp": price, "active": True, "order": 0,
            },
            live=True, coach_v="active", now=T0,
        )

    def request(self, uid, package_id, now=T0):
        source = codes()
        return subscriptions.request(
            self.db, uid, {"coachUid": COACH, "packageId": package_id, "intake": intake(), "consent": consent(name="Mona"), "locale": "en"},
            live=True, payments_live=True, verified=True, now=now, notify=self.pushes, code=lambda: next(source),
        )

    def pay(self, uid, sub_id, *, reference, image, amount, now=T0):
        return proofs.submit(
            self.db, uid,
            {
                "subId": sub_id, "rail": "instapay", "reference": reference, "amountEgp": amount,
                "paidAt": now.date().isoformat(), "senderName": "Client Name", "locale": "en",
            },
            image, live=True, now=now, blobs=self.blobs, reencode=keep,
        )

    def decide(self, proof_id, decision="approve", now=T0, **extra):
        return proofs.decide(
            self.db, FINANCE, {"proofId": proof_id, "decision": decision, **extra},
            now=now, blobs=self.blobs, notify=self.pushes,
        )

    def doc(self, path):
        return self.db.document(path).get().to_dict()


@pytest.fixture
def world():
    return World()


# ---------------------------------------------------------------- the journey


def test_the_whole_journey(world):
    w, db = world, world.db

    # Apply, get approved: the claim is minted after the decision commits.
    package = w.become_a_coach()
    assert w.doc(f"coachApplications/{COACH}")["status"] == "approved"
    assert w.claims.calls == [(COACH, {"coachV": "active"})]
    private = w.doc(f"coachPrivate/{COACH}")
    assert private["claimPending"] is False and private["suspended"] is False
    assert private["payoutState"] == "confirmed"
    assert package["priceFinalEgp"] == 1150 and package["youReceiveEgp"] == 1000
    page = w.doc(f"coaches/{COACH}")
    assert page["published"] is True and page["fromPriceEgp"] == 1150

    # A request is accepted by the coach's auto-accept.
    first = w.request(CLIENT, package["packageId"])
    sub_id = first["subId"]
    assert first["status"] == "awaiting_payment"
    assert (COACH, "coachingRequest") in w.pushes

    # Proof, then approval: receipt, pending ledger line, screenshot gone.
    shot = make_jpeg(1)
    proof = w.pay(CLIENT, sub_id, reference="TRANSFER-A1", image=shot, amount=1150)
    assert w.doc(f"subscriptions/{sub_id}")["status"] == "payment_review"
    assert len(w.blobs.objects) > 0
    assert w.decide(proof["proofId"]) == {"status": "approved"}
    sub = w.doc(f"subscriptions/{sub_id}")
    assert sub["status"] == "active" and sub["endsAt"] == T0 + dt.timedelta(days=28)
    assert db.document(f"receipts/{sub_id}").get().exists
    ledger = w.doc(f"coachPrivate/{COACH}/ledger/{sub_id}")
    assert ledger["status"] == "pending" and ledger["coachAmountEgp"] == 1000 and ledger["clientLabel"] == f"#{sub_id[-4:]}"
    assert [p for p in w.blobs.objects if p.startswith("payment-proofs/")] == []
    stored = w.doc(f"paymentProofs/{proof['proofId']}")
    assert stored["imagePath"] is None and stored["imageDeletePending"] is False
    assert (CLIENT, "paymentApproved") in w.pushes and (COACH, "coachingStarted") in w.pushes
    assert w.doc(f"coaches/{COACH}")["activeClients"] == 1
    assert w.doc(f"relationships/{REL}")["status"] == "active"

    # Plans: a workout and a meal plan reach the client with a chat card each.
    for kind, body in (("workout", workout()), ("meal", meal())):
        out = plans.publish(
            db, COACH, {"subId": sub_id, "kind": kind, "name": f"My {kind} plan", "body": body},
            live=True, coach_v="active", now=at(hours=1), notify=w.pushes, content_ids=IDS,
        )
        assert out["revision"] == 1
        assert w.doc(f"plans/{CLIENT}/coachPlans/{out['planId']}")["kind"] == kind
    cards = [m.to_dict()["type"] for m in db.collection(f"relationships/{REL}/messages").stream()]
    assert "workoutPlan" in cards and "mealPlan" in cards

    # A live session: schedule, confirm, both mark it done.
    start = at(days=2)
    session = sessions.schedule(
        db, COACH, {"subId": sub_id, "startsAt": start.isoformat(), "minutes": 45, "link": "https://meet.google.com/abc-defg-hij"},
        live=True, coach_v="active", now=at(hours=2), notify=w.pushes,
    )
    sessions.respond(db, CLIENT, {"subId": sub_id, "sessionId": session["sessionId"], "decision": "confirm"},
                     live=True, now=at(hours=3))
    ids = {"subId": sub_id, "sessionId": session["sessionId"]}
    after = start + dt.timedelta(hours=1)
    assert sessions.mark_done(db, COACH, ids, live=True, now=after) == {"status": "confirmed", "sessionsUsed": 0}
    assert sessions.mark_done(db, CLIENT, ids, live=True, now=after) == {"status": "done", "sessionsUsed": 1}
    assert w.doc(f"coaches/{COACH}")["stats"]["sessionsDone"] == 1

    # The message trigger: a clean message pushes, a phone number is hidden.
    w.pushes.clear()
    rel_messages = db.collection(f"relationships/{REL}/messages")
    clean = rel_messages.document("m-clean")
    clean.set({"senderUid": COACH, "type": "text", "text": "Great session, see you Thursday", "createdAt": after})
    outcome = chat.on_message(db, REL, "m-clean", clean.get().to_dict(), now=after, notify=w.pushes)
    assert outcome == {"hidden": False, "reason": None, "pushed": True}
    assert w.pushes == [(CLIENT, "newMessage")]
    dirty = rel_messages.document("m-dirty")
    dirty.set({"senderUid": CLIENT, "type": "text", "text": "call me on 01012345678", "createdAt": after})
    outcome = chat.on_message(db, REL, "m-dirty", dirty.get().to_dict(), now=after, notify=w.pushes)
    assert outcome["hidden"] is True and outcome["reason"] == "contact" and outcome["pushed"] is False
    assert dirty.get().to_dict()["hidden"] is True
    assert w.pushes == [(CLIENT, "newMessage")]

    # She cancels inside the window: the refund is the server's figure.
    ask_at = at(days=3)
    request = refunds.request(db, CLIENT, {"subId": sub_id, "reason": "plans changed"}, live=True, now=ask_at)
    assert request == {"state": "requested", "refundEgp": 863}
    refuse(
        lambda: refunds.record(db, FINANCE, {"subId": sub_id, "decision": "refund", "rail": "instapay",
                                             "reference": "REFUND-A1", "amountEgp": 1150}, now=at(days=3, hours=1), notify=w.pushes),
        errors.INVALID, errors.BAD_REQUEST,
    )
    refuse(
        lambda: sessions.schedule(db, COACH, {"subId": sub_id, "startsAt": at(days=5).isoformat(), "minutes": 45,
                                              "link": "https://meet.google.com/abc-defg-hij"},
                                  live=True, coach_v="active", now=ask_at, notify=w.pushes),
        errors.PRECONDITION, errors.WRONG_STATUS,
    )
    w.pushes.clear()
    refunds.record(db, FINANCE, {"subId": sub_id, "decision": "refund", "rail": "instapay",
                                 "reference": "REFUND-A1", "amountEgp": 863}, now=at(days=3, hours=2), notify=w.pushes)
    ended = w.doc(f"subscriptions/{sub_id}")
    assert ended["status"] == "ended_early" and ended["refund"]["amountEgp"] == 863
    assert sorted(w.pushes) == sorted([(CLIENT, "coachingEnded"), (COACH, "coachingEnded")])
    assert w.doc(f"coaches/{COACH}")["activeClients"] == 0

    # The coach's share after the refund (one of four sessions held) is due now.
    share = w.doc(f"coachPrivate/{COACH}/ledger/{sub_id}")
    assert share["coachAmountEgp"] == 250 and share["status"] == "eligible"
    assert w.doc(f"coachPrivate/{COACH}")["owedEgp"] == 250

    # A second client pays in full; the sweeper makes her line eligible after 14 days.
    second = w.request(SECOND, package["packageId"], now=at(days=4))["subId"]
    near = w.pay(SECOND, second, reference="TRANSFER-B1", image=make_jpeg(1, noise=3), amount=1150, now=at(days=4))
    flags = w.doc(f"paymentProofs/{near['proofId']}")["flags"]
    assert flags == ["nearImage"]
    w.decide(near["proofId"], now=at(days=4, hours=1))
    assert w.doc(f"coachPrivate/{COACH}/ledger/{second}")["status"] == "pending"
    w.pushes.clear()
    quiet = subscriptions.sweep(db, now=at(days=10), notify=w.pushes, blobs=w.blobs, payments=True)
    assert quiet["ledgerEligible"] == 0 and quiet["staleProofImages"] == 0
    swept = subscriptions.sweep(db, now=at(days=19), notify=w.pushes, blobs=w.blobs, payments=True)
    assert swept["ledgerEligible"] == 1 and swept["staleProofImages"] == 0 and swept["ended"] == 0
    assert w.doc(f"coachPrivate/{COACH}/ledger/{second}")["status"] == "eligible"
    assert w.doc(f"coachPrivate/{COACH}")["owedEgp"] == 1250

    # Finance record the payout; the server adds the lines up itself.
    owed = payouts.owed(db, FINANCE, {}, now=at(days=20))["coaches"]
    assert [(row["coachUid"], row["amountEgp"]) for row in owed] == [(COACH, 1250)]
    paid = payouts.record(
        db, FINANCE,
        {"coachUid": COACH, "entryIds": sorted([sub_id, second]), "rail": "instapay",
         "reference": "PAYOUT-0001", "paidAt": at(days=20).date().isoformat()},
        now=at(days=20), notify=w.pushes,
    )
    assert paid["amountEgp"] == 1250
    private = w.doc(f"coachPrivate/{COACH}")
    assert private["owedEgp"] == 0 and private["paidEgp"] == 1250
    assert (COACH, "payoutRecorded") in w.pushes
    for line in (sub_id, second):
        assert w.doc(f"coachPrivate/{COACH}/ledger/{line}")["status"] == "paid"
    assert subscriptions.sweep(db, now=at(days=21), notify=w.pushes, blobs=w.blobs, payments=True)["staleProofImages"] == 0


def test_a_reference_used_by_one_client_is_refused_for_another_and_leaves_nothing(world):
    package = world.become_a_coach()
    first = world.request(CLIENT, package["packageId"])["subId"]
    world.pay(CLIENT, first, reference="SHARED-REF-7", image=make_jpeg(1), amount=1150)
    other = world.request(SECOND, package["packageId"])["subId"]
    files = dict(world.blobs.objects)
    refuse(
        lambda: world.pay(SECOND, other, reference="shared-ref-7", image=make_jpeg(5), amount=1150),
        errors.PRECONDITION, errors.REFERENCE_USED,
    )
    assert world.blobs.objects == files
    assert world.doc(f"subscriptions/{other}")["status"] == "awaiting_payment"


def test_the_same_screenshot_for_another_subscription_is_flagged(world):
    package = world.become_a_coach()
    first = world.request(CLIENT, package["packageId"])["subId"]
    world.pay(CLIENT, first, reference="SAME-SHOT-1", image=make_jpeg(3), amount=1150)
    other = world.request(SECOND, package["packageId"])["subId"]
    out = world.pay(SECOND, other, reference="SAME-SHOT-2", image=make_jpeg(3), amount=1150)
    assert "sameImage" in world.doc(f"paymentProofs/{out['proofId']}")["flags"]


def test_a_different_picture_is_not_flagged(world):
    package = world.become_a_coach()
    first = world.request(CLIENT, package["packageId"])["subId"]
    world.pay(CLIENT, first, reference="FAR-SHOT-1", image=make_jpeg(3), amount=1150)
    other = world.request(SECOND, package["packageId"])["subId"]
    out = world.pay(SECOND, other, reference="FAR-SHOT-2", image=make_jpeg(9), amount=1150)
    assert world.doc(f"paymentProofs/{out['proofId']}")["flags"] == []


@pytest.mark.parametrize("row", VECTORS, ids=lambda r: str(r["coach"]))
def test_every_price_vector_runs_through_the_whole_pipeline(world, row):
    package = world.become_a_coach(price=row["coach"])
    assert package["priceFinalEgp"] == row["final"] and package["youReceiveEgp"] == row["coach"]
    sub_id = world.request(CLIENT, package["packageId"])["subId"]
    sub = world.doc(f"subscriptions/{sub_id}")
    assert sub["priceFinalEgp"] == row["final"]
    assert world.doc(f"subscriptions/{sub_id}/private/terms")["coachPriceEgp"] == row["coach"]
    proof = world.pay(CLIENT, sub_id, reference="VECTOR-REF-1", image=make_jpeg(2), amount=row["final"])
    assert world.doc(f"paymentProofs/{proof['proofId']}")["flags"] == []
    world.decide(proof["proofId"])
    ledger = world.doc(f"coachPrivate/{COACH}/ledger/{sub_id}")
    assert ledger["coachAmountEgp"] == row["coach"]
    refund = refunds.request(world.db, CLIENT, {"subId": sub_id}, live=True, now=at(days=1))["refundEgp"]
    assert refund == common.refund_amount(row["final"], 0, 4) == row["final"]
