"""Coaching pushes: generic text, the kind and nothing else in the payload."""

from dataclasses import dataclass, field

import pytest

from coaching import common, push
from identity import config
from identity import push as identity_push
from tests import fake_firestore


@dataclass
class _Result:
    success: bool
    exception: object = None


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
        self.sent, self.gone = [], set(gone)

    def send_each_for_multicast(self, message):
        self.sent.append(message)

        class _R:
            responses = [
                _Result(False, self.UnregisteredError()) if t in self.gone else _Result(True)
                for t in message.tokens
            ]

        return _R()


def _device(db, uid, device, **row):
    db.collection(config.COL_USERS).document(uid).collection(identity_push.DEVICES).document(
        device
    ).set(row)


def test_every_contract_kind_has_english_and_arabic_text():
    assert set(push.TEXT) == set(common.ENUMS["pushKinds"]) | {"newMessageFrom"}
    for kind, by_locale in push.TEXT.items():
        assert set(by_locale) == {"en", "ar"}, kind
        for title, body in by_locale.values():
            assert title == "Own Hub" and body.strip()


def test_text_is_generic_and_free_of_em_dashes():
    for by_locale in push.TEXT.values():
        for _, body in by_locale.values():
            assert "—" not in body and "–" not in body
            assert not any(ch.isdigit() for ch in body)
            assert "{" not in body.replace("{name}", "")


def test_each_phone_hears_its_own_language_and_only_the_kind_travels():
    db = fake_firestore.FakeFirestore()
    _device(db, "her", "a", token="t-ar", locale="ar")
    _device(db, "her", "b", token="t-en", locale="en")
    messaging = _Messaging()
    assert push.send_kind("her", "planShared", db=db, messaging=messaging) == 2
    bodies = {m.tokens[0]: m.notification.body for m in messaging.sent}
    assert bodies == {
        "t-ar": push.TEXT["planShared"]["ar"][1],
        "t-en": push.TEXT["planShared"]["en"][1],
    }
    assert all(m.data == {"kind": "planShared"} for m in messaging.sent)


def test_a_phone_with_no_locale_uses_the_given_one_else_arabic():
    db = fake_firestore.FakeFirestore()
    _device(db, "her", "a", token="t1")
    messaging = _Messaging()
    push.send_kind("her", "newMessage", db=db, messaging=messaging, locale="en")
    assert messaging.sent[0].notification.body == push.TEXT["newMessage"]["en"][1]
    messaging = _Messaging()
    push.send_kind("her", "newMessage", db=db, messaging=messaging)
    assert messaging.sent[0].notification.body == push.TEXT["newMessage"]["ar"][1]


def test_no_phone_or_an_unknown_kind_sends_nothing():
    db = fake_firestore.FakeFirestore()
    messaging = _Messaging()
    assert push.send_kind("her", "newMessage", db=db, messaging=messaging) == 0
    _device(db, "her", "a", token="t1", locale="en")
    assert push.send_kind("her", "bogus", db=db, messaging=messaging) == 0
    assert messaging.sent == []


def test_a_forgotten_token_is_deleted():
    db = fake_firestore.FakeFirestore()
    _device(db, "her", "old", token="gone", locale="ar")
    push.send_kind("her", "newMessage", db=db, messaging=_Messaging(gone={"gone"}))
    assert f"{config.COL_USERS}/her/{identity_push.DEVICES}/old" not in db.docs


def test_send_to_user_sends_one_text_to_every_phone():
    db = fake_firestore.FakeFirestore()
    _device(db, "her", "a", token="t1", locale="en")
    _device(db, "her", "b", token="t2", locale="ar")
    messaging = _Messaging()
    assert identity_push.send_to_user("her", "T", "B", {"k": "v"}, db, messaging) == 2
    assert {m.notification.body for m in messaging.sent} == {"B"}
    assert all(m.data == {"k": "v"} for m in messaging.sent)


def test_first_name_variant_fills_the_name():
    assert push.text_for("newMessageFrom", "en", "Rahma")[1] == "Rahma sent you a message."
    assert push.text_for("newMessageFrom", "ar", "Rahma")[1] == "Rahma بعتتلك رسالة."


def test_default_mode_is_generic():
    assert push.NEW_MESSAGE_TEXT_MODE == "generic"


def test_send_kind_with_a_name_suffix():
    db = fake_firestore.FakeFirestore()
    _device(db, "her", "a", token="t1")
    messaging = _Messaging()
    push.send_kind("her", "newMessageFrom:Rahma", db=db, messaging=messaging, locale="en")
    assert messaging.sent[0].notification.body == "Rahma sent you a message."

