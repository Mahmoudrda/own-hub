"""The chat screen and the trigger that applies it."""

import datetime as dt
import json
import pathlib

import pytest

from coaching import chat, common
from tests import fake_firestore
from tests.coaching_helpers import Notes, _txn  # noqa: F401

VECTORS = json.loads(
    (pathlib.Path(__file__).resolve().parents[2] / "contracts" / "coaching_chat_screen_vectors.json")
    .read_text(encoding="utf-8")
)["cases"]
NOW = dt.datetime(2026, 11, 1, 12, tzinfo=dt.timezone.utc)
REL = "coach1__client1"


@pytest.mark.parametrize("case", VECTORS, ids=[c["text"][:40] for c in VECTORS])
def test_screen_matches_the_shared_vectors(case):
    assert chat.screen(case["text"]) == case["reason"]


@pytest.mark.parametrize(
    "text,reason",
    [
        ("call 0100 123 4567", "contact"),
        ("call 0100.123.4567", "contact"),
        ("call 0100-123-4567", "contact"),
        ("0020 100 123 4567", "contact"),
        ("٠١١١٢٢٣٣٤٤٥", "contact"),
        ("۰۱۱۱۲۲۳۳۴۴۵", "contact"),
        ("1 2 3 4 5 6 7 8 9 0 1", "contact"),
        ("0 1 0 1 2 3 4 5 6 7 8", "contact"),
        ("phone 01​012​345678", "contact"),
        ("Etisalat Cash please", "payment"),
        ("orange  cash", "payment"),
        ("INSTAPAY", "payment"),
        ("insta pay me", "payment"),
        ("@instapay", "payment"),
        ("we pay later", "payment"),
        ("fawry", "payment"),
        ("فوري", "payment"),
        ("انستا باي", "payment"),
        ("فودافون  كاش", "payment"),
        ("HTTP://x.y", "link"),
        ("see example.org", "link"),
        ("wa.me/chatwithme", "link"),
        ("Visit WWW.Example.COM", "link"),
        ("you idiot", "abuse"),
        ("يا حماره", "abuse"),
        ("مرحبا يا بطل", None),
        ("rest 90 seconds between sets 3.5 kg", None),
        ("see you at 6:30 on 24.10.2026", None),
        ("12 reps, 3 sets, 60 s rest, 45 min total", None),
        ("a classic. Then more", None),
        ("", None),
    ],
)
def test_screen_extra_cases(text, reason):
    assert chat.screen(text) == reason


def test_screen_of_a_non_string_is_allowed():
    assert chat.screen(None) is None
    assert chat.screen(12345678901) is None


def test_contact_wins_over_the_other_reasons():
    assert chat.screen("pay me on instapay 01012345678 www.x.com you idiot") == "contact"


# ------------------------------------------------------------------ trigger --

def _db(**rel):
    db = fake_firestore.FakeFirestore()
    db.collection("relationships").document(REL).set(
        {"coachUid": "coach1", "clientUid": "client1", "status": "active", **rel}
    )
    return db


def _add(db, mid, **row):
    row.setdefault("createdAt", NOW)
    db.collection("relationships").document(REL).collection("messages").document(mid).set(row)
    return row


def _run(db, mid, row, now=NOW, notes=None):
    notes = notes if notes is not None else Notes()
    return chat.on_message(db, REL, mid, row, now=now, notify=notes), notes


def _rel(db):
    return db.docs[f"relationships/{REL}"]


def test_a_clean_message_sets_the_time_and_pushes_the_other_party():
    db = _db()
    row = _add(db, "m1", senderUid="client1", type="text", text="See you tomorrow")
    result, notes = _run(db, "m1", row)
    assert result == {"hidden": False, "reason": None, "pushed": True}
    assert notes.sent == [("coach1", "newMessage")]
    assert _rel(db)["lastMessageAt"] == NOW
    assert _rel(db)["lastPushAt"]["coach1"] == NOW
    assert "hidden" not in db.docs[f"relationships/{REL}/messages/m1"]


def test_the_coach_message_pushes_the_client():
    db = _db()
    row = _add(db, "m1", senderUid="coach1", type="text", text="Hello")
    _, notes = _run(db, "m1", row)
    assert notes.sent == [("client1", "newMessage")]


def test_a_second_message_inside_the_window_is_not_pushed():
    db = _db()
    row = _add(db, "m1", senderUid="client1", type="text", text="one")
    _run(db, "m1", row)
    later = NOW + dt.timedelta(minutes=2)
    row2 = _add(db, "m2", senderUid="client1", type="text", text="two")
    result, notes = _run(db, "m2", row2, now=later)
    assert result["pushed"] is False and notes.sent == []
    assert _rel(db)["lastMessageAt"] == later
    assert _rel(db)["lastPushAt"]["coach1"] == NOW


def test_after_the_window_it_pushes_again():
    db = _db()
    _run(db, "m1", _add(db, "m1", senderUid="client1", type="text", text="one"))
    later = NOW + dt.timedelta(minutes=3)
    _, notes = _run(db, "m2", _add(db, "m2", senderUid="client1", type="text", text="two"), now=later)
    assert notes.sent == [("coach1", "newMessage")]


def test_the_throttle_is_per_recipient():
    db = _db()
    _run(db, "m1", _add(db, "m1", senderUid="client1", type="text", text="one"))
    _, notes = _run(
        db, "m2", _add(db, "m2", senderUid="coach1", type="text", text="two"),
        now=NOW + dt.timedelta(minutes=1),
    )
    assert notes.sent == [("client1", "newMessage")]


@pytest.mark.parametrize(
    "text,reason",
    [("call 01012345678", "contact"), ("instapay me", "payment"),
     ("see www.x.com", "link"), ("you are stupid", "abuse")],
)
def test_a_failing_message_is_hidden_and_never_pushed(text, reason):
    db = _db()
    row = _add(db, "m1", senderUid="client1", type="text", text=text)
    result, notes = _run(db, "m1", row)
    assert result == {"hidden": True, "reason": reason, "pushed": False}
    assert notes.sent == []
    message = db.docs[f"relationships/{REL}/messages/m1"]
    assert message["hidden"] is True and message["hiddenReason"] == reason
    system = db.docs[f"relationships/{REL}/messages/hidden_m1"]
    assert system["type"] == "system" and system["systemKind"] == "hidden"
    assert "lastPushAt" not in _rel(db)
    assert _rel(db)["lastMessageAt"] == NOW


def test_a_hidden_message_does_not_use_up_the_throttle():
    db = _db()
    _run(db, "m1", _add(db, "m1", senderUid="client1", type="text", text="01012345678"))
    _, notes = _run(
        db, "m2", _add(db, "m2", senderUid="client1", type="text", text="fine"),
        now=NOW + dt.timedelta(seconds=30),
    )
    assert notes.sent == [("coach1", "newMessage")]


def test_a_recipe_message_with_text_is_screened_too():
    db = _db()
    row = _add(db, "m1", senderUid="coach1", type="recipe", recipeId="r1", text="pay instapay")
    result, _ = _run(db, "m1", row)
    assert result["hidden"] is True


def test_a_message_already_marked_hidden_is_not_pushed():
    db = _db()
    row = _add(db, "m1", senderUid="client1", type="text", text="hi", hidden=True)
    _, notes = _run(db, "m1", row)
    assert notes.sent == []


def test_a_server_message_only_moves_the_last_message_time():
    db = _db()
    row = _add(db, "m1", senderUid="coach1", type="workoutPlan", planId="p", text="01012345678")
    result, notes = _run(db, "m1", row)
    assert result == {"hidden": False, "reason": None, "pushed": False}
    assert notes.sent == []
    assert _rel(db)["lastMessageAt"] == NOW and "lastPushAt" not in _rel(db)
    assert "hidden" not in db.docs[f"relationships/{REL}/messages/m1"]


def test_a_sender_who_is_not_a_party_changes_nothing():
    db = _db()
    row = _add(db, "m1", senderUid="stranger", type="text", text="hi")
    result, notes = _run(db, "m1", row)
    assert result == {"hidden": False, "reason": None, "pushed": False}
    assert notes.sent == [] and "lastMessageAt" not in _rel(db)


def test_a_missing_relationship_changes_nothing():
    db = fake_firestore.FakeFirestore()
    result, notes = _run(db, "m1", {"senderUid": "client1", "type": "text", "text": "hi"})
    assert result["pushed"] is False and notes.sent == [] and db.docs == {}


def test_a_screened_message_loses_its_words_but_keeps_the_reason():
    db = fake_firestore.FakeFirestore()
    db.document(f"relationships/{REL}").set({"coachUid": "coach1", "clientUid": "client1", "status": "active"})
    row = _add(db, "m1", senderUid="client1", type="text", text="call 01012345678")
    _run(db, "m1", row)
    message = db.docs[f"relationships/{REL}/messages/m1"]
    assert message["text"] == "" and message["hiddenReason"] == "contact"


# ------------------------------------------------------------ the chat rules tick

def _hash(locale):
    return common.sha(common.CONTRACT["consentTexts"]["chatRules1"][locale][0])


def _rules(**over):
    data = {"version": 1, "textHash": _hash("ar"), "locale": "ar", "appVersion": "1.1.0+5"}
    data.update(over)
    return data


def test_the_first_rules_tick_is_recorded_and_a_second_changes_nothing():
    db = fake_firestore.FakeFirestore()
    assert chat.accept_rules(db, "u1", _rules(), live=True, now=NOW) == {"ok": True}
    later = NOW + dt.timedelta(days=1)
    chat.accept_rules(db, "u1", _rules(locale="en", textHash=_hash("en")), live=True, now=later)
    record = db.document("users/u1/consents/chat-rules-v1").get().to_dict()
    assert record == {"version": 1, "at": NOW, "locale": "ar", "textHash": _hash("ar"), "appVersion": "1.1.0+5"}


@pytest.mark.parametrize("locale", ["en", "ar"])
def test_every_listed_rules_text_is_accepted(locale):
    for text in common.CONTRACT["consentTexts"]["chatRules1"][locale]:
        db = fake_firestore.FakeFirestore()
        data = _rules(locale=locale, textHash=common.sha(text))
        assert chat.accept_rules(db, "u1", data, live=True, now=NOW) == {"ok": True}


@pytest.mark.parametrize(
    "bad",
    [{"version": 2}, {"version": True}, {"textHash": "short"}, {"textHash": "G" * 64}, {"textHash": "c" * 64}, {"textHash": _hash("en")}, {"locale": "fr"}, {"appVersion": "x" * 33}],
)
def test_a_wrong_rules_tick_is_refused_and_writes_nothing(bad):
    db = fake_firestore.FakeFirestore()
    with pytest.raises(Exception):
        chat.accept_rules(db, "u1", _rules(**bad), live=True, now=NOW)
    assert db.document("users/u1/consents/chat-rules-v1").get().to_dict() is None
