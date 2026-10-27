"""The world every payments test starts from. Import what you use. The autouse
`_txn` fixture must be imported by name so pytest runs it in your module."""

from __future__ import annotations

import datetime as dt

import cv2
import numpy as np
import pytest

from tests import fake_firestore
from tests.coaching_helpers import Notes, Pushes, _txn, refusal  # noqa: F401

NOW = dt.datetime(2026, 11, 10, 12, 0, tzinfo=dt.timezone.utc)
CLIENT = "client-uid-1"
CLIENT2 = "client-uid-2"
COACH = "coach-uid-1"
COACH2 = "coach-uid-2"
REVIEWER = "reviewer-uid-1"
REVIEWER2 = "reviewer-uid-2"
FINANCE = "finance-uid-1"
SUB = "sub-1"
PAY = "pay-1"
ADDRESS = "rahma@instapay"
ACCOUNT_NAME = "Rahma Mohsen"
BASE = 50000          # 500.00 EGP in piasters
AMOUNT = 50037        # the unique amount to pay


@pytest.fixture
def db():
    return fake_firestore.FakeFirestore()


@pytest.fixture
def notes():
    return Notes()


def later(**kw):
    return NOW + dt.timedelta(**kw)


def seed_world(db, *, durations=(28,), suspended=False, ready=True):
    """A coach with a confirmed InstaPay address, her packages, and one client
    subscription waiting for payment."""
    db.document(f"coaches/{COACH}").set(
        {"displayName": "Coach One", "published": True, "acceptingClients": True,
         "maxActiveClients": 15, "activeClients": 0, "instapayReady": ready,
         "stats": {"clientsCoached": 0}}
    )
    for i, d in enumerate(durations):
        db.document(f"coaches/{COACH}/packages/pk{i}").set(
            {"title": f"P{i}", "durationDays": d, "priceFinalEgp": 500, "active": True, "order": i}
        )
    db.document(f"coachPrivate/{COACH}").set({"suspended": False})
    db.document(f"coachPaymentProfiles/{COACH}").set(
        {"address": ADDRESS, "accountName": ACCOUNT_NAME, "verifiedAt": NOW, "status": "ok",
         "paymentsCreated": 0, "cleanConfirmed": 0, "autoConfirmGreen": False, "allowLongFirst": False,
         "paymentsConfirmed": 0, "disputesLost": 0}
    )
    if suspended:
        db.document(f"paymentStanding/{COACH}").set({"coachSuspended": True, "coachStrikes": 2})
    db.document(f"subscriptions/{SUB}").set(
        {"coachUid": COACH, "clientUid": CLIENT, "relId": f"{COACH}__{CLIENT}", "packageId": "pk0",
         "package": {"title": "P0", "durationDays": durations[0]}, "priceFinalEgp": 500,
         "status": "awaiting_payment", "statusAt": NOW, "payBy": later(days=7),
         "payment": {"state": "awaiting", "attempts": 0, "lastReason": None, "proofId": None}}
    )
    db.document(f"relationships/{COACH}__{CLIENT}").set(
        {"coachUid": COACH, "clientUid": CLIENT, "status": "none", "chatOpen": False}
    )


def make_payment(db, payment_id=PAY, *, with_created_event=False, **over):
    """A payments/{id} document written straight into the fake, in any status."""
    row = {
        "clientUid": CLIENT, "coachUid": COACH, "subId": SUB, "packageId": "pk0",
        "baseAmountPiasters": BASE, "amountPiasters": AMOUNT, "reference": "OH-4821",
        "addressSnapshot": {"address": ADDRESS, "accountName": ACCOUNT_NAME},
        "status": "awaiting_payment", "statusAt": NOW, "createdAt": NOW,
        "expiresAt": later(hours=24), "lateUntil": later(days=7),
        "proof": {"screenshotCount": 0, "amberAttempts": 0, "screenshotPaths": [], "imageFlags": []}, "outcome": None, "access": {"state": "none", "until": None},
        "feePiasters": 0, "feeState": None, "feeOwedAt": None,
    }
    row.update(over)
    db.document(f"payments/{payment_id}").set(row)
    if with_created_event:
        db.collection(f"payments/{payment_id}/events").document("e0").set(
            {"at": row["createdAt"], "from": None, "to": row["status"], "role": "client", "code": "created"}
        )
    return row


def events(db, payment_id=PAY):
    """[(from, to, role)] of the payment's timeline, oldest first."""
    rows = [r.to_dict() for r in db.collection(f"payments/{payment_id}/events").stream()]
    rows.sort(key=lambda r: r["at"])
    return [(r["from"], r["to"], r["role"]) for r in rows]


def payment_of(db, payment_id=PAY):
    return db.document(f"payments/{payment_id}").get().to_dict()


def phone_jpeg(seed_value: int, noise: int = 0) -> bytes:
    """A blocky 720x1560 picture: the shape of a phone screenshot, so the proof
    checks that ask for a screenshot are met. Equal seeds give equal pictures."""
    base = np.random.default_rng(seed_value).integers(0, 255, (8, 9), dtype=np.uint8)
    image = cv2.resize(base, (720, 1560), interpolation=cv2.INTER_NEAREST)
    if noise:
        image = np.clip(image.astype(int) + np.random.default_rng(99).integers(-noise, noise + 1, image.shape), 0, 255).astype(np.uint8)
    ok, out = cv2.imencode(".jpg", image)
    assert ok
    return out.tobytes()
