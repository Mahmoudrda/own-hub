"""N10 leftover: a failed mint after an approval commits is retried in-process,
then recorded as mintPending on the flag and finished by the hourly job."""

from __future__ import annotations

import pytest

from identity import approvals, config, decisions, review, store
from tests import fake_firestore
from tests.fake_review_store import FakeReviewStore


@pytest.fixture(autouse=True)
def no_sleep(monkeypatch):
    monkeypatch.setattr(review, "_sleep", lambda seconds: None)


def _booked(fake):
    flag_id = review.request(fake, "her", "niqab").flag_id
    fake.flags[flag_id]["id_hmac"] = "h1"
    review.schedule(fake, "rev", flag_id, "video", "2026-10-05T10:00:00+02:00")
    return flag_id


class FlakyMint(FakeReviewStore):
    def __init__(self, failures):
        super().__init__()
        self.failures = failures
        self.attempts = 0

    def mint_verified(self, uid):
        self.attempts += 1
        if self.failures > 0:
            self.failures -= 1
            raise RuntimeError("auth outage")
        super().mint_verified(uid)


def test_a_transient_mint_failure_is_retried_in_process():
    fake = FlakyMint(failures=config.MINT_ATTEMPTS - 1)
    flag_id = _booked(fake)
    assert review.decide(fake, "rev", flag_id, True).outcome == decisions.APPROVED
    assert fake.minted == ["her"]
    assert fake.states["her"]["state"] == review.STATE_APPROVED
    assert not fake.flags[flag_id].get("mintPending")


def test_a_persistent_failure_is_recorded_and_the_hourly_job_finishes_it():
    fake = FlakyMint(failures=config.MINT_ATTEMPTS)
    flag_id = _booked(fake)
    result = review.decide(fake, "rev", flag_id, True)
    assert result.outcome == decisions.APPROVED
    assert fake.minted == []
    assert fake.flags[flag_id]["state"] == decisions.APPROVED
    assert fake.flags[flag_id]["mintPending"] is True
    assert fake.states["her"]["state"] == review.STATE_PENDING

    assert review.retry_pending_mints(fake) == 1
    assert fake.minted == ["her"]
    assert fake.states["her"]["state"] == review.STATE_APPROVED
    assert not fake.flags[flag_id].get("mintPending")
    assert review.retry_pending_mints(fake) == 0


def test_a_failed_retry_leaves_it_pending_for_the_next_hour():
    fake = FlakyMint(failures=config.MINT_ATTEMPTS + 1)
    flag_id = _booked(fake)
    review.decide(fake, "rev", flag_id, True)
    assert review.retry_pending_mints(fake) == 0
    assert fake.flags[flag_id]["mintPending"] is True
    assert review.retry_pending_mints(fake) == 1
    assert fake.minted == ["her"]


def test_the_hourly_job_runs_the_retry(monkeypatch):
    import main

    fake = FlakyMint(failures=config.MINT_ATTEMPTS)
    flag_id = _booked(fake)
    review.decide(fake, "rev", flag_id, True)
    monkeypatch.setattr(main.store, "FirestoreReviewStore", lambda: fake)
    monkeypatch.setattr(approvals, "revoked_since_approval", lambda uid: False)
    purged = []
    monkeypatch.setattr(approvals, "_live_preapproved", lambda: purged.append(1) or [])
    main.expire_stale_reviews.__wrapped__(None)
    assert fake.minted == ["her"]
    assert not fake.flags[flag_id].get("mintPending")
    assert purged, "removed pre-approved numbers are purged by the hourly job"


def test_the_firestore_store_marks_lists_and_clears(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    db.collection(config.COL_FLAGS).document("f1").set(
        {"uid": "her", "state": decisions.APPROVED}
    )
    db.collection(config.COL_FLAGS).document("f2").set(
        {"uid": "x", "state": decisions.PENDING_REVIEW}
    )
    s = store.FirestoreReviewStore()
    s.mark_mint_pending("f1")
    assert s.mint_pending_flags(10) == [("f1", "her")]
    s.clear_mint_pending("f1")
    assert s.mint_pending_flags(10) == []
    assert "mintPending" not in db.docs[f"{config.COL_FLAGS}/f1"]


class _Auth:
    def __init__(self, claims):
        self.claims = dict(claims)

    def get_user(self, uid):
        from types import SimpleNamespace

        return SimpleNamespace(custom_claims=dict(self.claims))

    def set_custom_user_claims(self, uid, claims):
        self.claims = dict(claims)


@pytest.fixture
def auth(monkeypatch):
    import firebase_admin.auth as real

    fake = _Auth({})
    monkeypatch.setattr(real, "get_user", fake.get_user)
    monkeypatch.setattr(real, "set_custom_user_claims", fake.set_custom_user_claims)
    return fake


def test_taking_verification_back_suspends_an_active_coach_claim(auth):
    auth.claims = {"verified": True, "coachV": "active", "womanReviewer": True}
    store.mint_claims("her", False)
    assert auth.claims == {"verified": False, "coachV": "suspended", "womanReviewer": True}


def test_taking_verification_back_leaves_other_coach_states_alone(auth):
    auth.claims = {"verified": True}
    store.mint_claims("her", False)
    assert auth.claims == {"verified": False}
    auth.claims = {"verified": True, "coachV": "suspended"}
    store.mint_claims("her", False)
    assert auth.claims["coachV"] == "suspended"


def test_giving_verification_keeps_the_coach_claim_as_it_is(auth):
    auth.claims = {"verified": False, "coachV": "suspended"}
    store.mint_claims("her", True)
    assert auth.claims == {"verified": True, "coachV": "suspended"}
