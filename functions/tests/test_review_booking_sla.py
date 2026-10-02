"""N6: a booked review cannot expire before the call, a booking cannot be
pushed past the horizon, and expiry clears the booking from her state."""

from __future__ import annotations

import datetime as dt

import pytest

from identity import config, reasons, review, store
from tests import fake_firestore
from tests.fake_review_store import FakeReviewStore

NOW = dt.datetime(2026, 10, 2, 12, tzinfo=dt.timezone.utc)


def _open(fake):
    return review.request(fake, "her", "niqab").flag_id


def test_a_booking_after_the_sla_moves_the_sla_past_the_call():
    fake = FakeReviewStore()
    flag_id = _open(fake)
    when = NOW + dt.timedelta(days=5)
    review.schedule(fake, "rev", flag_id, "video", when.isoformat(), now=NOW)
    sla = fake.flags[flag_id]["slaExpiresAt"]
    assert sla == when + dt.timedelta(hours=config.REVIEW_BOOKING_GRACE_HOURS)
    # The hourly sweep the day before the call leaves it alone.
    assert review.expire(fake, when - dt.timedelta(hours=1)) == 0
    assert fake.states["her"]["reviewScheduledFor"] == when


def test_a_booking_never_shortens_the_sla():
    fake = FakeReviewStore()
    flag_id = _open(fake)
    before = fake.flags[flag_id]["slaExpiresAt"]
    review.schedule(fake, "rev", flag_id, "video", NOW.isoformat(), now=NOW)
    assert fake.flags[flag_id]["slaExpiresAt"] >= before


def test_a_booking_past_the_horizon_is_refused():
    fake = FakeReviewStore()
    flag_id = _open(fake)
    too_far = NOW + dt.timedelta(days=config.REVIEW_BOOKING_MAX_DAYS, minutes=1)
    with pytest.raises(review.ReviewError) as caught:
        review.schedule(fake, "rev", flag_id, "video", too_far.isoformat(), now=NOW)
    assert caught.value.kind == review.INVALID
    assert caught.value.reason == reasons.REVIEW_TIME_OUT_OF_RANGE
    assert fake.flags[flag_id]["route"] is None


def test_expiry_clears_the_booking_from_her_state():
    fake = FakeReviewStore()
    flag_id = _open(fake)
    review.schedule(fake, "rev", flag_id, "gym", NOW.isoformat(), now=NOW)
    later = fake.flags[flag_id]["slaExpiresAt"] + dt.timedelta(minutes=1)
    assert review.expire(fake, later) == 1
    assert fake.states["her"]["state"] == review.STATE_RETRY
    assert fake.states["her"]["reviewRoute"] is None
    assert fake.states["her"]["reviewScheduledFor"] is None


def test_the_firestore_store_writes_the_new_sla(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    db.collection(config.COL_FLAGS).document("f-1").set({"state": "PENDING_REVIEW"})
    sla = NOW + dt.timedelta(days=3)
    store.FirestoreReviewStore().mark_scheduled("f-1", "video", NOW, "rev", sla)
    flag = db.docs[f"{config.COL_FLAGS}/f-1"]
    assert flag["slaExpiresAt"] == sla and flag["route"] == "video"
