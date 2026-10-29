"""The chat screen and the trigger that applies it."""

import datetime as dt
import json
import pathlib

import pytest

from coaching import chat, common, push
from tests import fake_blobs, fake_firestore
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


# ------------------------------------------------------- media and rate limits

def test_a_good_image_is_kept_and_reencoded():
    db = _db()
    blobs = fake_blobs.FakeBlobs()
    path = f"chat-media/{REL}/client1/a.jpg"
    blobs.put(path, b"raw", "image/jpeg")
    row = _add(db, "m1", senderUid="client1", type="image", mediaPath=path)
    notes = Notes()
    result = chat.on_message(
        db, REL, "m1", row, now=NOW, notify=notes, blobs=blobs,
        reencode=lambda raw, long_side=None: b"clean:" + raw,
    )
    assert result["hidden"] is False
    assert blobs.objects[path][0] == b"clean:raw"
    assert notes.sent == [("coach1", "newMessage")]


def test_media_from_the_wrong_path_is_hidden_and_deleted():
    db = _db()
    blobs = fake_blobs.FakeBlobs()
    wrong_owner = f"chat-media/{REL}/coach1/a.jpg"
    blobs.put(wrong_owner, b"raw", "image/jpeg")
    row1 = _add(db, "m1", senderUid="client1", type="image", mediaPath=wrong_owner)
    notes = Notes()
    result1 = chat.on_message(db, REL, "m1", row1, now=NOW, notify=notes, blobs=blobs)
    assert result1["hidden"] is True and result1["reason"] == "media" and notes.sent == []

    traversal = f"chat-media/{REL}/client1/../a.jpg"
    blobs.put(traversal, b"raw", "image/jpeg")
    row2 = _add(db, "m2", senderUid="client1", type="image", mediaPath=traversal)
    result2 = chat.on_message(db, REL, "m2", row2, now=NOW, notify=notes, blobs=blobs)
    assert result2["hidden"] is True and result2["reason"] == "media"
    assert traversal in blobs.deleted
    assert notes.sent == []


def test_missing_file_oversize_and_wrong_type_are_hidden():
    db = _db()
    blobs = fake_blobs.FakeBlobs()
    p1 = f"chat-media/{REL}/client1/missing.jpg"
    p2 = f"chat-media/{REL}/client1/big.jpg"
    p3 = f"chat-media/{REL}/client1/png.png"
    blobs.put(p2, b"x" * 3_000_001, "image/jpeg")
    blobs.put(p3, b"x", "image/png")
    for idx, path in enumerate((p1, p2, p3), start=1):
        row = _add(db, f"m{idx}", senderUid="client1", type="image", mediaPath=path)
        result = chat.on_message(db, REL, f"m{idx}", row, now=NOW, notify=Notes(), blobs=blobs)
        assert result["reason"] == "media"


def test_video_and_audio_need_a_sane_duration():
    db = _db()
    blobs = fake_blobs.FakeBlobs()
    v1 = f"chat-media/{REL}/client1/v1.mp4"
    v2 = f"chat-media/{REL}/client1/v2.mp4"
    a1 = f"chat-media/{REL}/client1/a1.m4a"
    a2 = f"chat-media/{REL}/client1/a2.m4a"
    blobs.put(v1, b"x", "video/mp4")
    blobs.put(v2, b"x", "video/mp4")
    blobs.put(a1, b"x", "audio/mp4")
    blobs.put(a2, b"x", "audio/mp4")

    r_v1 = chat.on_message(
        db, REL, "mv1",
        _add(db, "mv1", senderUid="client1", type="video", mediaPath=v1, durationMs=31600),
        now=NOW, notify=Notes(), blobs=blobs,
    )
    r_v2 = chat.on_message(
        db, REL, "mv2",
        _add(db, "mv2", senderUid="client1", type="video", mediaPath=v2, durationMs=30000),
        now=NOW, notify=Notes(), blobs=blobs,
    )
    r_a1 = chat.on_message(
        db, REL, "ma1",
        _add(db, "ma1", senderUid="client1", type="audio", mediaPath=a1, durationMs=0),
        now=NOW, notify=Notes(), blobs=blobs,
    )
    r_a2 = chat.on_message(
        db, REL, "ma2",
        _add(db, "ma2", senderUid="client1", type="audio", mediaPath=a2, durationMs=120000),
        now=NOW, notify=Notes(), blobs=blobs,
    )
    assert r_v1["hidden"] is True and r_v1["reason"] == "media"
    assert r_v2["hidden"] is False
    assert r_a1["hidden"] is True and r_a1["reason"] == "media"
    assert r_a2["hidden"] is False


def test_hold_before_hides_media_with_reason_held(monkeypatch):
    monkeypatch.setattr(chat, "CHAT_MEDIA_HOLD", "before")
    db = _db()
    blobs = fake_blobs.FakeBlobs()
    path = f"chat-media/{REL}/client1/a.jpg"
    blobs.put(path, b"raw", "image/jpeg")
    row = _add(db, "m1", senderUid="client1", type="image", mediaPath=path)
    result = chat.on_message(db, REL, "m1", row, now=NOW, notify=Notes(), blobs=blobs)
    assert result["reason"] == "held"
    # Held is not refused: the file and the pointer stay for the release.
    assert blobs.deleted == [] and path in blobs.objects
    assert db.document(f"relationships/{REL}/messages/m1").get().to_dict()["mediaPath"] == path


def test_the_21st_message_in_a_minute_is_hidden_as_rate():
    db = _db()
    for i in range(1, 21):
        row = _add(db, f"m{i}", senderUid="client1", type="text", text="ok", createdAt=NOW)
        res, _ = _run(db, f"m{i}", row)
        assert res["hidden"] is False
    row21 = _add(db, "m21", senderUid="client1", type="text", text="ok", createdAt=NOW)
    res21, _ = _run(db, "m21", row21)
    assert res21["reason"] == "rate"


def test_the_31st_media_line_in_an_hour_is_hidden():
    db = _db()
    blobs = fake_blobs.FakeBlobs()
    for i in range(30, 0, -1):
        path = f"chat-media/{REL}/client1/{i}.jpg"
        blobs.put(path, b"raw", "image/jpeg")
        at = NOW - dt.timedelta(seconds=100 * i)
        row = _add(db, f"m{i}", senderUid="client1", type="image", mediaPath=path, createdAt=at)
        res = chat.on_message(db, REL, f"m{i}", row, now=at, notify=Notes(), blobs=blobs)
        assert res["hidden"] is False
    path31 = f"chat-media/{REL}/client1/31.jpg"
    blobs.put(path31, b"raw", "image/jpeg")
    row31 = _add(db, "m31", senderUid="client1", type="image", mediaPath=path31, createdAt=NOW)
    res31 = chat.on_message(db, REL, "m31", row31, now=NOW, notify=Notes(), blobs=blobs)
    assert res31["reason"] == "rate"
    # A flood must not fill the bucket with files no line points to.
    assert path31 in blobs.deleted
    assert path31 not in blobs.objects
    assert db.document(f"relationships/{REL}/messages/m31").get().to_dict()["mediaPath"] is None


def test_a_media_line_after_a_text_flood_loses_its_file():
    db = _db()
    blobs = fake_blobs.FakeBlobs()
    for i in range(1, 21):
        _run(db, f"t{i}", _add(db, f"t{i}", senderUid="client1", type="text", text="ok", createdAt=NOW))
    path = f"chat-media/{REL}/client1/late.m4a"
    blobs.put(path, b"x", "audio/mp4")
    row = _add(db, "a1", senderUid="client1", type="audio", mediaPath=path, durationMs=5000, createdAt=NOW)
    result = chat.on_message(db, REL, "a1", row, now=NOW, notify=Notes(), blobs=blobs)
    assert result["reason"] == "rate"
    assert blobs.deleted == [path]


def test_first_name_mode_names_only_the_coach(monkeypatch):
    monkeypatch.setattr(push, "NEW_MESSAGE_TEXT_MODE", "first_name")
    db = _db()
    db.collection("coaches").document("coach1").set({"displayName": "Rahma Mohsen"})
    _, coach_notes = _run(db, "m1", _add(db, "m1", senderUid="coach1", type="text", text="Hello"))
    assert coach_notes.sent == [("client1", "newMessageFrom:Rahma")]
    _, client_notes = _run(db, "m2", _add(db, "m2", senderUid="client1", type="text", text="Hi"))
    assert client_notes.sent == [("coach1", "newMessage")]



# ---------------------------------------------- contact privacy: split numbers, attempts

def _msg(db, mid, text, at, sender="client1"):
    return _add(db, mid, senderUid=sender, type="text", text=text, createdAt=at)


def test_a_number_split_over_two_messages_is_hidden_on_the_second():
    db = _db()
    _run(db, "m1", _msg(db, "m1", "my number is 0101 234", NOW), now=NOW)
    assert "hidden" not in db.docs[f"relationships/{REL}/messages/m1"]
    at = NOW + dt.timedelta(minutes=2)
    result, _ = _run(db, "m2", _msg(db, "m2", "5678", at), now=at)
    assert result["hidden"] and result["reason"] == "contact"


def test_halves_more_than_ten_minutes_apart_or_from_two_senders_are_not_joined():
    db = _db()
    _run(db, "m1", _msg(db, "m1", "0101 234", NOW), now=NOW)
    late = NOW + dt.timedelta(minutes=11)
    assert _run(db, "m2", _msg(db, "m2", "5678", late), now=late)[0]["hidden"] is False
    db = _db()
    _run(db, "m1", _msg(db, "m1", "0101 234", NOW), now=NOW)
    at = NOW + dt.timedelta(minutes=1)
    assert _run(db, "m2", _msg(db, "m2", "5678", at, sender="coach1"), now=at)[0]["hidden"] is False


def _private(db):
    return db.docs[f"relationships/{REL}/private/contact"]


def _reports(db):
    return [v for k, v in db.docs.items() if k.startswith("reports/")]


def test_each_hidden_attempt_is_counted_and_the_third_in_30_days_opens_one_report():
    db = _db()
    for i in range(3):
        at = NOW + dt.timedelta(days=i)
        _run(db, f"m{i}", _msg(db, f"m{i}", "call 01012345678", at), now=at)
        assert _private(db)["client1"]["count"] == i + 1
        assert len(_reports(db)) == (1 if i == 2 else 0)
    report = _reports(db)[0]
    assert report["reason"] == "contact_sharing" and report["state"] == "submitted"
    assert report["reporterUid"] == chat.AUTO_REPORTER and report["subjectUid"] == "client1"
    assert report["subjectRef"] == f"relationships/{REL}/messages/m2"
    at = NOW + dt.timedelta(days=3)
    _run(db, "m3", _msg(db, "m3", "call 01012345678", at), now=at)
    assert len(_reports(db)) == 1, "one report per 30 days"


def test_attempts_older_than_30_days_do_not_count_and_the_other_sender_has_her_own_count():
    db = _db()
    for i, who in enumerate(["client1", "client1", "coach1", "client1"]):
        at = NOW + dt.timedelta(days=i * 20 if i < 2 else 41)
        _run(db, f"m{i}", _msg(db, f"m{i}", "t.me/x", at, sender=who), now=at)
    assert _reports(db) == []
    assert _private(db)["coach1"]["count"] == 1 and _private(db)["client1"]["count"] == 3


def test_a_trigger_run_twice_counts_once_and_other_hides_are_not_counted():
    db = _db()
    row = _msg(db, "m1", "call 01012345678", NOW)
    _run(db, "m1", row)
    _run(db, "m1", row)
    assert _private(db)["client1"]["count"] == 1
    db = _db()
    _run(db, "m2", _msg(db, "m2", "you idiot", NOW))
    assert f"relationships/{REL}/private/contact" not in db.docs


def test_a_stranger_leaves_no_counter():
    db = _db()
    _run(db, "m1", _msg(db, "m1", "call 01012345678", NOW, sender="stranger"))
    assert f"relationships/{REL}/private/contact" not in db.docs


def test_an_automatic_report_is_visible_to_staff_with_no_words():
    from coaching import moderation

    db = _db()
    for i in range(3):
        at = NOW + dt.timedelta(minutes=i)
        _run(db, f"m{i}", _msg(db, f"m{i}", "call 01012345678", at), now=at)
    rid = next(k.split("/")[1] for k in db.docs if k.startswith("reports/") and k.count("/") == 1)
    assert moderation.on_report(db, rid, db.docs[f"reports/{rid}"], now=NOW, per_day=5) is True
    page = moderation.list_for_staff(db, "staff1", {}, now=NOW)
    item = page["items"][0]
    assert item["reason"] == "contact_sharing" and item["subject"].get("hidden") is True
    assert "text" not in item["subject"] or item["subject"]["text"] == ""


def test_a_number_in_three_pieces_hides_all_three():
    db = _db()
    for i, (mid, text) in enumerate([("m1", "010"), ("m2", "1234"), ("m3", "5678")]):
        at = NOW + dt.timedelta(minutes=i)
        result, _ = _run(db, mid, _msg(db, mid, text, at), now=at)
    assert result["hidden"] and result["reason"] == "contact"
    for mid in ("m1", "m2", "m3"):
        row = db.docs[f"relationships/{REL}/messages/{mid}"]
        assert row["hidden"] is True and row["text"] == ""


def test_only_the_pieces_of_the_number_are_hidden():
    db = _db()
    for i, (mid, text) in enumerate([("m1", "see you tomorrow"), ("m2", "0101 234"), ("m3", "5678")]):
        at = NOW + dt.timedelta(minutes=i)
        _run(db, mid, _msg(db, mid, text, at), now=at)
    assert "hidden" not in db.docs[f"relationships/{REL}/messages/m1"]
    assert db.docs[f"relationships/{REL}/messages/m2"]["hidden"] is True


@pytest.mark.parametrize("text", [
    "Day 5 01012345678", "5 10 1234 5678", "my id 2 20 1012345678", "٥ ١٠ ١٢٣٤ ٥٦٧٨",
    "r a h m a @ gmail . com", "w h a t s a p p", "tele gram",
])
def test_a_short_number_in_front_does_not_hide_a_contact(text):
    assert chat.screen(text) == "contact"


@pytest.mark.parametrize("text", [
    "بقبل انستاباي", "We accept InstaPay", "انستا باي", "insta pay is fine", "Pay with Vodafone Cash",
])
def test_payment_names_are_fine_in_free_text(text):
    assert chat.has_contact_detail(text) is False


def test_naming_instapay_is_hidden_but_never_counts_toward_a_report():
    db = _db()
    for i in range(4):
        at = NOW + dt.timedelta(minutes=i)
        result, _ = _run(db, f"m{i}", _msg(db, f"m{i}", "pay me on instapay", at), now=at)
        assert result["reason"] == "payment"
    assert f"relationships/{REL}/private/contact" not in db.docs and _reports(db) == []


@pytest.mark.parametrize("sender,role", [("client1", "client"), ("coach1", "coach")])
def test_the_automatic_report_names_who_it_is_about(sender, role):
    db = _db()
    for i in range(3):
        at = NOW + dt.timedelta(minutes=i)
        _run(db, f"m{i}", _msg(db, f"m{i}", "call 01012345678", at, sender=sender), now=at)
    report = _reports(db)[0]
    assert report["subjectUid"] == sender and report["subjectRole"] == role and role in report["note"]


@pytest.mark.parametrize("text", [
    "Thanks.To be honest", "Done.Me too", "Good.Fit is fine", "Ok.Page 2", "Yes.Bio class today",
])
def test_a_sentence_without_a_space_after_the_full_stop_is_not_a_link_anywhere(text):
    assert chat.screen(text) is None and chat.has_contact_detail(text) is False
