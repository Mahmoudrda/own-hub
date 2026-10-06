"""A woman reviewer approves her, and the phones she registered on C14 hear
about it. Nothing is sent to a phone that did not say yes, nothing in the push
names the check, and a failed push never undoes the approval."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

from identity import config, decisions, push, review
from tests import fake_firestore
from tests.fake_review_store import FakeReviewStore


def _booked(fake):
    flag_id = review.request(fake, "her", "niqab").flag_id
    fake.flags[flag_id]["id_hmac"] = "h1"
    review.schedule(fake, "rev", flag_id, "video", "2026-10-05T10:00:00+02:00")
    return flag_id


def test_an_approval_pushes_once():
    fake = FakeReviewStore()
    review.decide(fake, "rev", _booked(fake), True)
    assert fake.approved_pushes == ["her"]


def test_a_rejection_pushes_nothing():
    fake = FakeReviewStore()
    review.decide(fake, "rev", _booked(fake), False)
    assert fake.approved_pushes == []


def test_a_push_that_fails_leaves_the_approval_standing():
    class Broken(FakeReviewStore):
        def notify_approved(self, uid):
            raise RuntimeError("push service down")

    fake = Broken()
    result = review.decide(fake, "rev", _booked(fake), True)
    assert result.outcome == decisions.APPROVED
    assert fake.verification_state("her") == review.STATE_APPROVED
    assert fake.minted == ["her"]


def test_a_mint_retried_later_pushes_when_it_lands(monkeypatch):
    class FlakyMint(FakeReviewStore):
        def __init__(self):
            super().__init__()
            self.fail = True

        def mint_verified(self, uid):
            if self.fail:
                raise RuntimeError("auth down")
            super().mint_verified(uid)

    fake = FlakyMint()
    monkeypatch.setattr(review, "_sleep", lambda s: None)
    review.decide(fake, "rev", _booked(fake), True)
    assert fake.approved_pushes == []
    fake.fail = False
    assert review.retry_pending_mints(fake) == 1
    assert fake.approved_pushes == ["her"]


# ------------------------------------------------------------- the sender


@dataclass
class _Result:
    success: bool
    exception: Optional[Exception] = None


@dataclass
class _Response:
    responses: list


class _Messaging:
    class UnregisteredError(Exception):
        pass

    @dataclass
    class Notification:
        title: str
        body: str

    @dataclass
    class MulticastMessage:
        tokens: list
        notification: object
        data: dict = field(default_factory=dict)

    def __init__(self, gone=()):
        self.sent = []
        self.gone = set(gone)

    def send_each_for_multicast(self, message):
        self.sent.append(message)
        return _Response(
            [
                _Result(False, self.UnregisteredError()) if t in self.gone else _Result(True)
                for t in message.tokens
            ]
        )


def _devices(db, uid, rows):
    for device_id, data in rows.items():
        db.collection(config.COL_USERS).document(uid).collection(push.DEVICES).document(
            device_id
        ).set(data)


def test_each_phone_hears_in_its_own_language():
    db = fake_firestore.FakeFirestore()
    _devices(
        db,
        "her",
        {
            "phone": {"token": "t-ar", "platform": "android", "locale": "ar"},
            "tablet": {"token": "t-en", "platform": "ios", "locale": "en"},
        },
    )
    messaging = _Messaging()
    assert push.send_approved("her", db, messaging) == 2
    bodies = {m.tokens[0]: m.notification.body for m in messaging.sent}
    assert bodies == {
        "t-ar": push.APPROVED_TEXT["ar"][1],
        "t-en": push.APPROVED_TEXT["en"][1],
    }
    for message in messaging.sent:
        assert message.data == {"kind": push.DATA_KIND}


def test_no_registered_phone_means_no_push():
    db = fake_firestore.FakeFirestore()
    messaging = _Messaging()
    assert push.send_approved("her", db, messaging) == 0
    assert messaging.sent == []


def test_a_token_the_service_has_forgotten_is_deleted():
    db = fake_firestore.FakeFirestore()
    _devices(db, "her", {"old": {"token": "gone", "locale": "ar"}})
    push.send_approved("her", db, _Messaging(gone={"gone"}))
    assert f"{config.COL_USERS}/her/{push.DEVICES}/old" not in db.docs


def test_the_text_names_no_check_and_no_document():
    for title, body in push.APPROVED_TEXT.values():
        text = (title + " " + body).lower()
        for word in ("id", "selfie", "face", "woman", "verified", "بطاقة", "هوية", "امرأة"):
            assert f" {word} " not in f" {text} ", word
    assert push.approved_text("fr") == push.APPROVED_TEXT["ar"]
