"""N3: her review consent covers ONE flag, the one she asked about.

It was permanent per account: one users/{uid}/consents/review-v1 document,
and contact() looked only at whether it existed. A later automatic flag then
let a reviewer fetch her phone number while the app told her a reviewer only
calls after she asks. Now request_review stores the flag id on the consent,
contact() requires consent.flagId == the flag being contacted, the queue's
consentGiven is the same per-flag match, and closing or expiring the flag
deletes the consent in the same transaction.
"""

from __future__ import annotations

import datetime as dt

import pytest

from identity import config, decisions, reasons, review, store
from tests import fake_firestore
from tests.fake_review_store import FakeReviewStore

CONSENT = f"{config.COL_USERS}/her/{config.COL_CONSENTS}/review-v3"


def _machine_flag(fake, uid="her"):
    decision = decisions.Decision(
        decisions.PENDING_REVIEW, (reasons.MATCH_FLAG_BAND,), (reasons.MATCH_FLAG_BAND,)
    )
    flag_id, created = fake.open_flag(
        uid, {"uid": uid}, review.flag_payload(uid, None, decision, id_hmac="h1")
    )
    assert created
    fake.set_verification_state(uid, review.STATE_PENDING, reset_booking=True)
    return flag_id


# ------------------------------------------------------------ review module


def test_request_binds_the_consent_to_the_new_flag():
    fake = FakeReviewStore()
    result = review.request(fake, "her", "niqab")
    assert fake.review_consents == {"her": {"path": "niqab", "flagId": result.flag_id}}


def test_request_on_an_open_machine_flag_binds_the_consent_to_it():
    fake = FakeReviewStore()
    flag_id = _machine_flag(fake)
    review.request(fake, "her", "error")
    assert fake.review_consents["her"]["flagId"] == flag_id


def test_a_consent_for_an_earlier_flag_does_not_open_a_later_one():
    fake = FakeReviewStore()
    later = _machine_flag(fake)
    # A consent left over from an earlier review, bound to another flag.
    fake.review_consents["her"] = {"path": "niqab", "flagId": "earlier-flag"}
    looked_up = []
    fake.phone_for = lambda uid: looked_up.append(uid) or "+201005550132"
    with pytest.raises(review.ReviewError) as caught:
        review.contact(fake, "rev", later)
    assert caught.value.reason == reasons.REVIEW_CONSENT_MISSING
    assert looked_up == []
    rows = review.list_open(fake, "rev")
    assert [row["consentGiven"] for row in rows] == [False]


def test_after_expiry_a_new_automatic_flag_needs_her_to_ask_again():
    fake = FakeReviewStore()
    first = review.request(fake, "her", "niqab").flag_id
    assert review.contact(fake, "rev", first) == {"phone": "+201005550132"}
    later = dt.datetime(2100, 1, 1, tzinfo=dt.timezone.utc)
    assert review.expire(fake, later) == 1
    assert "her" not in fake.review_consents, "expiry clears the consent"
    second = _machine_flag(fake)
    with pytest.raises(review.ReviewError) as caught:
        review.contact(fake, "rev", second)
    assert caught.value.reason == reasons.REVIEW_CONSENT_MISSING
    review.request(fake, "her", "error")
    assert review.contact(fake, "rev", second) == {"phone": "+201005550132"}


def test_closing_the_flag_clears_the_consent():
    fake = FakeReviewStore()
    flag_id = review.request(fake, "her", "niqab").flag_id
    fake.flags[flag_id]["route"] = "video"
    review.decide(fake, "rev", flag_id, False)
    assert "her" not in fake.review_consents


# --------------------------------------------------------- Firestore store


@pytest.fixture
def fs(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    monkeypatch.setattr(store.firestore, "transactional", fake_firestore.transactional)
    return db


def _seed_flag(fs, sla=None):
    fs.collection(config.COL_FLAGS).document("f1").set(
        {"uid": "her", "state": decisions.PENDING_REVIEW, "slaExpiresAt": sla or fs.now}
    )
    fs.collection(config.COL_LEDGER).document("her").set({"openFlagId": "f1"})


def test_the_store_writes_the_flag_id_on_the_consent(fs):
    store.write_review_consent("her", "declined", "f1")
    assert fs.docs[CONSENT] == {
        "version": config.REVIEW_CONSENT_VERSION,
        "at": fs.now,
        "path": "declined",
        "flagId": "f1",
    }


def test_the_store_matches_consent_per_flag(fs):
    reviews = store.FirestoreReviewStore()
    assert reviews.review_consented_flags([("her", "f1")]) == set()
    store.write_review_consent("her", "niqab", "f1")
    assert reviews.review_consented_flags([("her", "f1"), ("her", "f2")]) == {"f1"}
    assert reviews.review_consented_flags([("her", "f2")]) == set()
    assert reviews.review_consented_flags([("other", "f1")]) == set()
    assert reviews.review_consented_flags([]) == set()


def test_close_flag_deletes_the_consent_in_its_transaction(fs):
    _seed_flag(fs)
    store.write_review_consent("her", "niqab", "f1")
    refusal = store.FirestoreReviewStore().close_flag(
        "f1", uid="her", state=decisions.REJECTED_FAILED, reviewer_uid="rev",
        reviewer_reason=reasons.REVIEWER_REJECTED, user_state=review.STATE_REJECTED,
    )
    assert refusal is None
    assert CONSENT not in fs.docs


def test_a_refused_close_leaves_the_consent(fs):
    _seed_flag(fs)
    fs.docs[f"{config.COL_FLAGS}/f1"]["state"] = decisions.APPROVED
    store.write_review_consent("her", "niqab", "f1")
    refusal = store.FirestoreReviewStore().close_flag(
        "f1", uid="her", state=decisions.REJECTED_FAILED, reviewer_uid="rev",
        reviewer_reason=reasons.REVIEWER_REJECTED,
    )
    assert refusal == reasons.REVIEW_NOT_PENDING
    assert CONSENT in fs.docs


def test_expire_flag_deletes_the_consent_in_its_transaction(fs):
    _seed_flag(fs)
    store.write_review_consent("her", "niqab", "f1")
    later = fs.now + dt.timedelta(hours=1)
    assert store.FirestoreReviewStore().expire_flag("f1", "her", later) is True
    assert CONSENT not in fs.docs


def test_an_expiry_that_does_not_fire_leaves_the_consent(fs):
    _seed_flag(fs, sla=fs.now + dt.timedelta(hours=5))
    store.write_review_consent("her", "niqab", "f1")
    assert store.FirestoreReviewStore().expire_flag("f1", "her", fs.now) is False
    assert CONSENT in fs.docs
