"""N7: asking for a woman reviewer records a server-side review-route consent,
users/{uid}/consents/review-v2 = {version, at, path, flagId}. N3: it names the
flag it was given for, so it is written once that flag's id exists."""

from __future__ import annotations

import pytest

from identity import config, review, store
from tests import fake_firestore
from tests.fake_review_store import FakeReviewStore


class OrderedFake(FakeReviewStore):
    def __init__(self):
        super().__init__()
        self.events = []

    def write_review_consent(self, uid, path, flag_id):
        self.events.append("consent")
        super().write_review_consent(uid, path, flag_id)

    def open_flag(self, *args, **kwargs):
        self.events.append("flag")
        return super().open_flag(*args, **kwargs)


@pytest.mark.parametrize("path", ["niqab", "declined", "error"])
def test_requesting_review_records_the_consent_for_the_flag(path):
    fake = OrderedFake()
    flag_id = review.request(fake, "her", path).flag_id
    assert fake.review_consents == {"her": {"path": path, "flagId": flag_id}}
    assert fake.events == ["flag", "consent"]


def test_no_consent_is_recorded_when_nothing_is_opened():
    fake = FakeReviewStore()
    with pytest.raises(review.ReviewError):
        review.request(fake, "her", "gym")
    fake.set_verification_state("her", review.STATE_APPROVED)
    review.request(fake, "her", "niqab")
    fake.set_verification_state("her", review.STATE_REJECTED)
    with pytest.raises(review.ReviewError):
        review.request(fake, "her", "niqab")
    assert fake.review_consents == {}


def test_the_firestore_store_writes_exactly_version_at_path(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    store.write_review_consent("her", "declined", "f1")
    doc = db.docs[f"{config.COL_USERS}/her/{config.COL_CONSENTS}/review-v2"]
    assert doc == {
        "version": config.REVIEW_CONSENT_VERSION,
        "at": db.now,
        "path": "declined",
        "flagId": "f1",
    }
    assert config.REVIEW_CONSENT_VERSION == 2


def test_the_consent_lives_under_users_so_account_deletion_takes_it(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    store.write_review_consent("her", "niqab", "f1")
    db.recursive_delete(db.collection(config.COL_USERS).document("her"))
    assert not any(path.startswith(f"{config.COL_USERS}/her") for path in db.docs)
