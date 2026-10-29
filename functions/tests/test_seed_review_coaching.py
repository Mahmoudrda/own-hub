import datetime as dt

import pytest

from payments import create
from tests import fake_firestore
from tests.coaching_helpers import _txn  # noqa: F401  (runs transactions on the fake)
from tools import seed_review_coaching as seed

NOW = dt.datetime(2026, 11, 2, 9, 0, tzinfo=dt.timezone.utc)
OWNER = ["--client-uid", "reviewer1", "--project", "own-hub", "--i-am-the-owner"]


@pytest.fixture
def db():
    return fake_firestore.FakeFirestore()


@pytest.mark.parametrize("flags", [[], ["--project", "own-hub"], ["--i-am-the-owner"], ["--project", "other", "--i-am-the-owner"]])
def test_without_the_owner_flags_nothing_is_written(db, flags):
    lines = []
    assert seed.main(["--client-uid", "reviewer1", *flags], db=db, now=NOW, out=lines.append) == 2
    assert not list(db.collection("coaches").stream()) and not list(db.collection("subscriptions").stream())


def test_it_prints_then_writes_a_coach_with_two_live_sessions_and_a_waiting_request(db):
    lines = []
    assert seed.main(OWNER, db=db, now=NOW, out=lines.append) == 0
    assert "Will write 8 documents" in lines[0] and any("cannot receive money" in line for line in lines)
    package = db.document(f"coaches/{seed.COACH_UID}/packages/{seed.PACKAGE_ID}").get().to_dict()
    assert package["liveSessionsPerMonth"] >= 2 and package["active"] is True
    coach = db.document(f"coaches/{seed.COACH_UID}").get().to_dict()
    assert coach["acceptingClients"] is False  # real members cannot ask her
    assert coach["published"] and coach["instapayReady"] and coach["displayName"] == "Own Hub Review Coach"
    sub = db.document(f"subscriptions/{seed.SUB_ID}").get().to_dict()
    assert (sub["clientUid"], sub["status"]) == ("reviewer1", "awaiting_payment")
    assert sub["payBy"] == NOW + dt.timedelta(days=30)
    assert seed.main(OWNER, db=db, now=NOW, out=lambda *_: None) == 0  # safe to run twice


def test_the_reviewer_can_start_the_payment_from_the_seeded_request(db):
    seed.main(OWNER, db=db, now=NOW, out=lambda *_: None)
    out = create.create(db, "reviewer1", {"subId": seed.SUB_ID, "idempotencyKey": "k" * 16}, now=NOW, on=True)
    assert out["paymentId"]
    assert seed.ADDRESS in str(db.collection("payments").document(out["paymentId"]).get().to_dict())
