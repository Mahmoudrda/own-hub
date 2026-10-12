"""R5: booking, rejection and expiry each write the flag and her state in ONE
transaction keyed on flag state == PENDING_REVIEW.

Before: schedule read the flag, then mark_scheduled did a plain update and a
separate set_verification_state wrote `pending`. A reject or an expiry landing
between the two was overwritten, which reopened a rejected account.
"""

from __future__ import annotations

import datetime as dt

import pytest

from identity import config, decisions, reasons, review, store
from tests import fake_firestore
from tests.fake_review_store import FakeReviewStore

WHEN = "2026-10-05T10:00:00+02:00"


class RacingStore(FakeReviewStore):
    """get_flag returns what the reviewer saw; then, before the booking is
    written, a concurrent request decides or expires the flag."""

    def __init__(self, race):
        super().__init__()
        self.race = race
        self.racing = False

    def get_flag(self, flag_id):
        snapshot = super().get_flag(flag_id)
        if self.racing:
            self.racing = False
            self.race(self, flag_id)
        return snapshot


def _reject(fake, flag_id):
    fake.flags[flag_id]["route"] = "video"
    review.decide(fake, "rev2", flag_id, False)


def _expire(fake, flag_id):
    later = fake.flags[flag_id]["slaExpiresAt"] + dt.timedelta(minutes=1)
    assert review.expire(fake, later) == 1


@pytest.mark.parametrize(
    "race, final",
    [(_reject, review.STATE_REJECTED), (_expire, review.STATE_RETRY)],
)
def test_a_booking_never_overwrites_a_concurrent_decision(race, final):
    fake = RacingStore(race)
    flag_id = review.request(fake, "her", "niqab").flag_id
    fake.racing = True
    with pytest.raises(review.ReviewError) as caught:
        review.schedule(fake, "rev", flag_id, "video", WHEN)
    assert caught.value.reason == reasons.REVIEW_NOT_PENDING
    assert fake.states["her"]["state"] == final
    assert fake.flags[flag_id]["state"] != decisions.PENDING_REVIEW
    assert ("rev", flag_id, "schedule:video") not in fake.access


def test_reject_writes_her_state_inside_the_close():
    fake = FakeReviewStore()
    flag_id = review.request(fake, "her", "niqab").flag_id
    review.schedule(fake, "rev", flag_id, "video", WHEN)
    fake.set_verification_state = lambda *a, **k: pytest.fail(
        "rejection must not depend on a write after the transaction"
    )
    review.decide(fake, "rev", flag_id, False)
    assert fake.states["her"]["state"] == review.STATE_REJECTED


def test_expiry_writes_her_state_inside_the_expire():
    fake = FakeReviewStore()
    flag_id = review.request(fake, "her", "error").flag_id
    fake.set_verification_state = lambda *a, **k: pytest.fail(
        "expiry must not depend on a write after the transaction"
    )
    later = fake.flags[flag_id]["slaExpiresAt"] + dt.timedelta(minutes=1)
    assert review.expire(fake, later) == 1
    assert fake.states["her"]["state"] == review.STATE_RETRY


# --------------------------------------------- the Firestore store, for real


@pytest.fixture
def fs(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    monkeypatch.setattr(store.firestore, "transactional", fake_firestore.transactional)
    committed = []
    real_commit = fake_firestore.Transaction.commit

    def commit(self):
        committed.append(
            sorted({w.update.name.rsplit("/documents/", 1)[-1] for w in self.writes if w.update.name})
        )
        real_commit(self)

    monkeypatch.setattr(fake_firestore.Transaction, "commit", commit)
    db.committed = committed
    return db


def _seed(fs, state=decisions.PENDING_REVIEW, sla=None):
    fs.collection(config.COL_FLAGS).document("f1").set(
        {"uid": "her", "state": state, "slaExpiresAt": sla or fs.now}
    )
    fs.collection(config.COL_VERIFICATION_JOBS).document("f1").set(
        {"uid": "her", "state": decisions.PENDING_REVIEW}
    )
    fs.collection(config.COL_LEDGER).document("her").set({"openFlagId": "f1"})
    fs.collection(config.COL_USERS).document("her").set(
        {"verification": {"state": "pending"}}
    )


def _user(fs):
    return fs.docs[f"{config.COL_USERS}/her"]["verification"]


def test_mark_scheduled_books_flag_and_state_in_one_transaction(fs):
    _seed(fs)
    when = fs.now + dt.timedelta(days=1)
    sla = when + dt.timedelta(hours=2)
    refusal = store.FirestoreReviewStore().mark_scheduled("f1", "video", when, "rev", sla)
    assert refusal is None
    flag = fs.docs[f"{config.COL_FLAGS}/f1"]
    assert flag["route"] == "video" and flag["slaExpiresAt"] == sla
    assert _user(fs)["state"] == "pending"
    assert _user(fs)["reviewRoute"] == "video"
    assert _user(fs)["reviewScheduledFor"] == when
    assert fs.committed[-1] == sorted([f"{config.COL_FLAGS}/f1", f"{config.COL_USERS}/her"])


@pytest.mark.parametrize("state", [decisions.REJECTED_FAILED, decisions.RETRY_REQUIRED, decisions.APPROVED])
def test_mark_scheduled_refuses_a_decided_flag_and_writes_nothing(fs, state):
    _seed(fs, state=state)
    fs.collection(config.COL_USERS).document("her").set(
        {"verification": {"state": "rejected"}}
    )
    before = {k: dict(v) for k, v in fs.docs.items()}
    refusal = store.FirestoreReviewStore().mark_scheduled(
        "f1", "video", fs.now, "rev", fs.now
    )
    assert refusal == reasons.REVIEW_NOT_PENDING
    assert fs.docs == before


def test_reject_commits_her_rejected_state_with_the_flag(fs):
    _seed(fs)
    refusal = store.FirestoreReviewStore().close_flag(
        "f1", uid="her", state=decisions.REJECTED_FAILED, reviewer_uid="rev",
        reviewer_reason=reasons.REVIEWER_REJECTED, user_state=review.STATE_REJECTED,
    )
    assert refusal is None
    assert _user(fs)["state"] == "rejected" and _user(fs)["decidedAt"] == fs.now
    assert f"{config.COL_USERS}/her" in fs.committed[-1]
    assert f"{config.COL_FLAGS}/f1" in fs.committed[-1]


def test_expire_commits_her_retry_state_with_the_flag(fs):
    _seed(fs)
    fs.collection(config.COL_USERS).document("her").set(
        {"verification": {"state": "pending", "reviewRoute": "video", "reviewScheduledFor": fs.now}}
    )
    assert store.FirestoreReviewStore().expire_flag("f1", "her", fs.now + dt.timedelta(hours=1))
    assert _user(fs)["state"] == "retry"
    assert _user(fs)["reviewRoute"] is None and _user(fs)["reviewScheduledFor"] is None
    assert f"{config.COL_USERS}/her" in fs.committed[-1]
    assert f"{config.COL_FLAGS}/f1" in fs.committed[-1]


def test_a_refused_expiry_leaves_her_state_alone(fs):
    _seed(fs, state=decisions.REJECTED_FAILED)
    fs.collection(config.COL_USERS).document("her").set(
        {"verification": {"state": "rejected"}}
    )
    assert not store.FirestoreReviewStore().expire_flag(
        "f1", "her", fs.now + dt.timedelta(hours=1)
    )
    assert _user(fs)["state"] == "rejected"
