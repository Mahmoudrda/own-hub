"""N10: decide and expire re-check the flag inside one transaction keyed on
state == PENDING_REVIEW; nothing is minted or written to her state unless that
transaction commits."""

from __future__ import annotations

import datetime as dt

import pytest

from identity import config, decisions, dedupe, reasons, review, store
from tests import fake_firestore
from tests.fake_review_store import FakeReviewStore

FEMALE_ADULT = "29901012345628"


class RacingStore(FakeReviewStore):
    """get_flag returns the snapshot the reviewer saw; by the time the close
    runs, another request has changed the real flag."""

    def __init__(self, race_to):
        super().__init__()
        self.race_to = race_to
        self.racing = False

    def get_flag(self, flag_id):
        snapshot = super().get_flag(flag_id)
        if self.racing:
            self.flags[flag_id]["state"] = self.race_to
        return snapshot


def _booked(fake, id_hmac="h1"):
    flag_id = review.request(fake, "her", "niqab").flag_id
    fake.flags[flag_id]["id_hmac"] = id_hmac
    review.schedule(fake, "rev", flag_id, "video", "2026-10-05T10:00:00+02:00")
    return flag_id


@pytest.mark.parametrize("approve", [True, False])
def test_a_flag_decided_meanwhile_is_not_decided_twice(approve):
    fake = RacingStore(decisions.APPROVED)
    flag_id = _booked(fake)
    state_before = dict(fake.states["her"])
    fake.racing = True
    with pytest.raises(review.ReviewError) as caught:
        review.decide(fake, "rev", flag_id, approve)
    assert caught.value.reason == reasons.REVIEW_NOT_PENDING
    assert fake.minted == []
    assert fake.states["her"] == state_before
    assert fake.registry == {}
    assert fake.flags[flag_id]["state"] == decisions.APPROVED


def test_approval_mints_only_after_the_close_commits():
    fake = FakeReviewStore()
    flag_id = _booked(fake)
    order = []
    real_close, real_mint = fake.close_flag, fake.mint_verified
    fake.close_flag = lambda *a, **k: (order.append("close"), real_close(*a, **k))[1]
    fake.mint_verified = lambda uid: (order.append("mint"), real_mint(uid))[1]
    review.decide(fake, "rev", flag_id, True)
    assert order == ["close", "mint"]
    assert fake.states["her"]["state"] == review.STATE_APPROVED


def test_expiry_skips_a_flag_booked_or_decided_after_the_query():
    fake = FakeReviewStore()
    flag_id = review.request(fake, "her", "error").flag_id
    later = fake.flags[flag_id]["slaExpiresAt"] + dt.timedelta(minutes=1)
    stale = fake.stale_flags(later, 10)
    # Booked meanwhile: the SLA moved past `later`.
    fake.flags[flag_id]["slaExpiresAt"] = later + dt.timedelta(days=1)
    fake.stale_flags = lambda now, limit: stale
    assert review.expire(fake, later) == 0
    assert fake.states["her"]["state"] == review.STATE_PENDING
    assert fake.ledgers["her"].get("bonusOcrSubmissions", 0) == 0
    assert fake.flags[flag_id]["state"] == decisions.PENDING_REVIEW


# ----------------------------------------- the Firestore store, transactional


@pytest.fixture
def fs(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    monkeypatch.setattr(store.firestore, "transactional", fake_firestore.transactional)
    return db


def _seed(fs, state=decisions.PENDING_REVIEW, sla=None):
    fs.collection(config.COL_FLAGS).document("f1").set(
        {"uid": "her", "state": state, "slaExpiresAt": sla or fs.now}
    )
    fs.collection(config.COL_VERIFICATION_JOBS).document("f1").set(
        {"uid": "her", "state": decisions.PENDING_REVIEW}
    )
    fs.collection(config.COL_LEDGER).document("her").set({"openFlagId": "f1", "spent_micro_usd": 7})


def _close(fs, id_hmac=None, state=decisions.APPROVED):
    return store.FirestoreReviewStore().close_flag(
        "f1", uid="her", state=state, reviewer_uid="rev",
        reviewer_reason=reasons.REVIEWER_APPROVED, id_hmac=id_hmac,
    )


def test_close_writes_flag_job_ledger_and_registry_together(fs):
    _seed(fs)
    assert _close(fs, id_hmac="h1") is None
    assert fs.docs[f"{config.COL_FLAGS}/f1"]["state"] == decisions.APPROVED
    assert fs.docs[f"{config.COL_VERIFICATION_JOBS}/f1"]["state"] == decisions.APPROVED
    assert fs.docs[f"{config.COL_LEDGER}/her"] == {"openFlagId": None, "spent_micro_usd": 7}
    assert fs.docs[f"{config.COL_NID_REGISTRY}/h1"]["uid"] == "her"


def test_close_refuses_a_flag_no_longer_pending_and_writes_nothing(fs):
    _seed(fs, state=decisions.RETRY_REQUIRED)
    before = {k: dict(v) for k, v in fs.docs.items()}
    assert _close(fs, id_hmac="h1") == reasons.REVIEW_NOT_PENDING
    assert fs.docs == before


def test_close_refuses_a_card_registered_to_someone_else_and_writes_nothing(fs):
    _seed(fs)
    fs.collection(config.COL_NID_REGISTRY).document("h1").set(dedupe.registry_document("other"))
    before = {k: dict(v) for k, v in fs.docs.items()}
    assert _close(fs, id_hmac="h1") == reasons.DUPLICATE_ID
    assert fs.docs == before


def test_expire_is_conditional_on_pending_and_past_the_sla(fs):
    now = fs.now
    _seed(fs, sla=now + dt.timedelta(hours=1))
    assert store.FirestoreReviewStore().expire_flag("f1", "her", now) is False
    assert fs.docs[f"{config.COL_FLAGS}/f1"]["state"] == decisions.PENDING_REVIEW
    later = now + dt.timedelta(hours=2)
    assert store.FirestoreReviewStore().expire_flag("f1", "her", later) is True
    assert fs.docs[f"{config.COL_FLAGS}/f1"]["state"] == decisions.RETRY_REQUIRED
    assert fs.docs[f"{config.COL_LEDGER}/her"]["openFlagId"] is None
    assert store.FirestoreReviewStore().expire_flag("f1", "her", later) is False
