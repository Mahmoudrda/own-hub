"""Events: seats (register, cancel, account deletion) and the owner's editor."""

from __future__ import annotations

import datetime as dt

import pytest
from firebase_functions import https_fn

import main
from account import deletion
from events import admin as events_admin
from events import seats
from tests import fake_firestore
from tests.fake_firestore import FakeFirestore
from tests.test_entrypoints import inner, raises, request

HER = "uid-her"
OTHER = "uid-two"
VERIFIED = {"verified": True}
ADMIN = {"admin": True}
FUTURE = dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=5)
PAST = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=5)


def event(**changes):
    row = {
        "titleEn": "Stretch",
        "titleAr": "تمدد",
        "startsAt": FUTURE,
        "endsAt": FUTURE + dt.timedelta(hours=1),
        "mode": "place",
        "placeName": "Zamalek gym",
        "audience": "all",
        "status": "published",
        "capacity": 2,
        "seatsTaken": 0,
    }
    row.update(changes)
    return row


@pytest.fixture
def db(monkeypatch):
    fake = FakeFirestore()
    monkeypatch.setattr(main.store, "db", lambda: fake)
    monkeypatch.setattr(seats.firestore, "transactional", fake_firestore.transactional)
    fake.docs["events/e1"] = event()
    return fake


def register(uid=HER, event_id="e1", **kw):
    return inner("register_for_event")(
        request({"eventId": event_id}, uid=uid, token=kw.pop("token", VERIFIED), **kw)
    )


def cancel(uid=HER, event_id="e1", **kw):
    return inner("cancel_event_registration")(
        request({"eventId": event_id}, uid=uid, token=kw.pop("token", VERIFIED), **kw)
    )


# ------------------------------------------------------------- registering


def test_she_takes_a_seat(db):
    assert register() == {"registered": True, "seatsTaken": 1, "capacity": 2}
    assert db.docs["events/e1"]["seatsTaken"] == 1
    attendee = db.docs[f"events/e1/attendees/{HER}"]
    assert attendee["uid"] == HER and attendee["status"] == "registered"
    assert attendee["joinedAt"] is not None


def test_a_second_tap_changes_nothing(db):
    register()
    assert register() == {"registered": True, "seatsTaken": 1, "capacity": 2}
    assert db.docs["events/e1"]["seatsTaken"] == 1


def test_the_last_seat_goes_and_the_next_woman_is_refused(db):
    register()
    register(uid=OTHER)
    error = raises(
        lambda: register(uid="uid-three"), https_fn.FunctionsErrorCode.FAILED_PRECONDITION
    )
    assert error.message == "event_full"
    assert db.docs["events/e1"]["seatsTaken"] == 2
    assert "events/e1/attendees/uid-three" not in db.docs


def test_a_woman_who_holds_a_seat_is_not_told_the_event_is_full(db):
    register()
    register(uid=OTHER)
    assert register()["registered"] is True


@pytest.mark.parametrize(
    "changes",
    [
        {"status": "draft"},
        {"status": "cancelled"},
        {"startsAt": PAST - dt.timedelta(hours=1), "endsAt": PAST},
        {"capacity": None},
        {
            "startsAt": dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=10),
            "endsAt": FUTURE,
        },
    ],
)
def test_a_closed_event_takes_no_seat(db, changes):
    db.docs["events/e1"] = event(**changes)
    error = raises(lambda: register(), https_fn.FunctionsErrorCode.FAILED_PRECONDITION)
    assert error.message == "event_closed"
    assert not [p for p in db.docs if "attendees" in p]


def test_a_started_event_still_lets_her_cancel_a_seat_she_holds(db):
    register()
    db.docs["events/e1"]["startsAt"] = dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=10)
    assert register()["registered"] is True
    assert cancel()["registered"] is False
    assert db.docs["events/e1"]["seatsTaken"] == 0


def test_an_event_that_does_not_exist(db):
    error = raises(lambda: register(event_id="nope"), https_fn.FunctionsErrorCode.NOT_FOUND)
    assert error.message == "event_not_found"


@pytest.mark.parametrize("event_id", [None, "", "a/b", "x" * 101, 7, ["e1"]])
def test_a_bad_event_id_is_refused(db, event_id):
    raises(
        lambda: inner("register_for_event")(request({"eventId": event_id}, token=VERIFIED)),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )


@pytest.mark.parametrize("name", ["register_for_event", "cancel_event_registration"])
def test_an_unverified_account_is_refused_and_nothing_moves(db, name):
    for token in (None, {}, {"verified": False}, {"admin": True}):
        raises(
            lambda: inner(name)(request({"eventId": "e1"}, token=token)),
            https_fn.FunctionsErrorCode.PERMISSION_DENIED,
        )
    assert db.docs["events/e1"]["seatsTaken"] == 0


@pytest.mark.parametrize("name", ["register_for_event", "cancel_event_registration"])
def test_no_app_check_no_seat(db, name):
    raises(
        lambda: inner(name)(request({"eventId": "e1"}, token=VERIFIED, app=False)),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert db.docs["events/e1"]["seatsTaken"] == 0


@pytest.mark.parametrize("name", ["register_for_event", "cancel_event_registration"])
def test_signed_out_is_refused(db, name):
    raises(
        lambda: inner(name)(request({"eventId": "e1"}, uid=None)),
        https_fn.FunctionsErrorCode.UNAUTHENTICATED,
    )


# -------------------------------------------------------------- cancelling


def test_cancelling_gives_the_seat_back(db):
    register()
    assert cancel() == {"registered": False, "seatsTaken": 0, "capacity": 2}
    assert db.docs["events/e1"]["seatsTaken"] == 0
    assert f"events/e1/attendees/{HER}" not in db.docs


def test_cancelling_twice_changes_nothing(db):
    register()
    register(uid=OTHER)
    cancel()
    assert cancel() == {"registered": False, "seatsTaken": 1, "capacity": 2}
    assert db.docs["events/e1"]["seatsTaken"] == 1


def test_cancelling_without_a_seat_never_goes_below_zero(db):
    assert cancel()["seatsTaken"] == 0
    assert db.docs["events/e1"]["seatsTaken"] == 0


def test_a_drifted_count_is_clamped_at_zero(db):
    db.docs["events/e1"]["seatsTaken"] = 0
    db.docs[f"events/e1/attendees/{HER}"] = {"uid": HER, "status": "registered"}
    assert cancel()["seatsTaken"] == 0
    assert db.docs["events/e1"]["seatsTaken"] == 0


def test_she_can_still_give_a_seat_back_after_the_event_closes(db):
    register()
    db.docs["events/e1"]["status"] = "cancelled"
    assert cancel()["registered"] is False
    assert db.docs["events/e1"]["seatsTaken"] == 0


def test_cancelling_for_an_unknown_event(db):
    raises(lambda: cancel(event_id="nope"), https_fn.FunctionsErrorCode.NOT_FOUND)


def test_she_cancels_only_her_own_seat(db):
    register()
    register(uid=OTHER)
    cancel(uid=HER)
    assert f"events/e1/attendees/{OTHER}" in db.docs
    assert db.docs["events/e1"]["seatsTaken"] == 1


# ------------------------------------------------------- the owner's editor


def body(**changes):
    row = {
        "titleEn": "Stretch",
        "titleAr": "تمدد",
        "descriptionEn": "Quiet.",
        "descriptionAr": "هادئ.",
        "startsAt": "2030-03-01T16:00:00Z",
        "endsAt": "2030-03-01T18:00:00Z",
        "mode": "place",
        "placeName": "Zamalek gym",
        "locationAddress": "12 Road 9, Maadi",
        "locationUrl": "https://maps.app.goo.gl/abc",
        "capacity": 20,
        "imageFiles": ["a_1.webp", "b_2.jpg"],
        "videoFiles": ["tour_1.mp4"],
        "status": "draft",
    }
    row.update(changes)
    return row


def save(data, token=ADMIN, **kw):
    return inner("save_event")(request(data, uid="uOwner", token=token, **kw))


def test_the_owner_creates_an_event(db):
    result = save(body(eventId="ev_one"))
    assert result == {"ok": True, "eventId": "ev_one"}
    doc = db.docs["events/ev_one"]
    assert doc["seatsTaken"] == 0 and doc["audience"] == "all"
    assert doc["timeZone"] == "Africa/Cairo"
    assert doc["startsAt"] == dt.datetime(2030, 3, 1, 16, tzinfo=dt.timezone.utc)
    assert doc["imageFiles"] == ["a_1.webp", "b_2.jpg"]
    assert doc["videoFiles"] == ["tour_1.mp4"]
    assert "link" not in doc
    assert doc["createdAt"] is not None and doc["updatedAt"] is not None


def test_an_event_with_no_id_gets_one(db):
    result = save(body())
    assert result["ok"] and result["eventId"].startswith("ev_")
    assert f"events/{result['eventId']}" in db.docs


def test_an_online_event_needs_an_https_link_and_drops_the_place(db):
    assert save(body(mode="online", eventId="o1", link="http://x.example.com/a"))["ok"] is False
    result = save(body(mode="online", eventId="o1", link="https://meet.example.com/a"))
    assert result["ok"]
    doc = db.docs["events/o1"]
    assert doc["link"] == "https://meet.example.com/a"
    assert "placeName" not in doc and "locationUrl" not in doc


@pytest.mark.parametrize(
    "changes",
    [
        {"locationUrl": "https://evil.example.com/maps"},
        {"locationUrl": "http://maps.google.com/x"},
        {"locationUrl": "https://maps.google.com.evil.example/x"},
        {"locationUrl": "https://goo.gl@evil.example/x"},
        {"locationUrl": "https://www.google.com/search?q=x"},
        {"locationUrl": "https://maps.google.com/x\n"},
        {"locationUrl": "https://goo.gl/abc"},
        {"locationUrl": "https://goo.gl/mapsevil"},
        {"mode": "online", "link": "https://meet.example.com/a\n"},
        {"imageFiles": ["a.webp"] * 7},
        {"imageFiles": ["a.webp", "a.webp"]},
        {"imageFiles": ["a.mp4"]},
        {"imageFiles": ["../a.webp"]},
        {"imageFiles": "a.webp"},
        {"videoFiles": ["a.mp4", "b.mp4", "c.mp4"]},
        {"videoFiles": ["a.webm"]},
        {"locationAddress": "x" * 301},
        {"placeName": ""},
        {"titleEn": ""},
        {"titleAr": "x" * 121},
        {"descriptionEn": "x" * 2001},
        {"capacity": 0},
        {"capacity": 100001},
        {"capacity": True},
        {"capacity": "20"},
        {"status": "live"},
        {"mode": "zoom"},
        {"startsAt": "2030-03-01T16:00:00"},
        {"startsAt": "soon"},
        {"endsAt": "2030-03-01T15:00:00Z"},
        {"eventId": "a/b"},
    ],
)
def test_a_bad_event_is_refused_and_nothing_is_written(db, changes):
    before = dict(db.docs)
    result = save(body(**changes))
    assert result["ok"] is False and result["problems"]
    assert db.docs == before


@pytest.mark.parametrize(
    "url",
    [
        "https://maps.google.com/?q=maadi",
        "https://www.google.com/maps/place/x",
        "https://goo.gl/maps/abc",
        "https://maps.app.goo.gl/abc",
    ],
)
def test_the_allowed_map_hosts(db, url):
    assert save(body(locationUrl=url, eventId="m1"))["ok"] is True


def test_the_cover_file_is_kept_when_the_request_leaves_it_out(db):
    assert save(body(eventId="c1", coverFile="cover_1.webp"))["ok"]
    assert db.docs["events/c1"]["coverFile"] == "cover_1.webp"
    assert save(body(eventId="c1", titleEn="Renamed"))["ok"]
    assert db.docs["events/c1"]["coverFile"] == "cover_1.webp"
    assert save(body(eventId="c1", coverFile=None))["ok"]
    assert "coverFile" not in db.docs["events/c1"]


def test_six_pictures_and_two_clips_are_the_limit(db):
    names = [f"p{i}.webp" for i in range(6)]
    assert save(body(eventId="m1", imageFiles=names, videoFiles=["a.mp4", "b.mp4"]))["ok"]


def test_seatsTaken_in_the_request_is_ignored(db):
    save(body(eventId="e9", seatsTaken=15))
    assert db.docs["events/e9"]["seatsTaken"] == 0
    db.docs["events/e9"]["seatsTaken"] = 3
    save(body(eventId="e9", seatsTaken=0, titleEn="Renamed"))
    assert db.docs["events/e9"]["seatsTaken"] == 3
    assert db.docs["events/e9"]["titleEn"] == "Renamed"


def test_editing_keeps_the_creation_time_and_the_seats(db):
    save(body(eventId="e9"))
    created = db.docs["events/e9"]["createdAt"]
    db.docs["events/e9"]["seatsTaken"] = 4
    assert save(body(eventId="e9", capacity=4))["ok"]
    assert db.docs["events/e9"]["createdAt"] == created
    assert db.docs["events/e9"]["seatsTaken"] == 4


def test_seats_cannot_go_below_those_booked(db):
    db.docs["events/e9"] = event(seatsTaken=5, capacity=10)
    for capacity in (4, None):
        result = save(body(eventId="e9", capacity=capacity))
        assert result["ok"] is False
    assert db.docs["events/e9"]["capacity"] == 10


def test_an_edit_replaces_cleared_fields(db):
    save(body(eventId="e9"))
    save(body(eventId="e9", locationUrl=None, locationAddress="", imageFiles=[]))
    doc = db.docs["events/e9"]
    assert "locationUrl" not in doc and "locationAddress" not in doc
    assert doc["imageFiles"] == []


def test_the_owner_lists_events_soonest_first_with_seats(db):
    db.docs["events/late"] = event(
        startsAt=FUTURE + dt.timedelta(days=9), endsAt=FUTURE + dt.timedelta(days=9, hours=1),
        capacity=8, seatsTaken=3, status="draft",
    )
    db.docs["events/e1"]["seatsTaken"] = 1
    answer = inner("list_events_admin")(request({}, uid="uOwner", token=ADMIN))
    rows = answer["events"]
    assert [r["eventId"] for r in rows] == ["e1", "late"]
    assert (rows[0]["seatsTaken"], rows[0]["capacity"], rows[0]["status"]) == (1, 2, "published")
    assert (rows[1]["seatsTaken"], rows[1]["capacity"], rows[1]["status"]) == (3, 8, "draft")
    assert rows[0]["startsAt"].endswith("Z")


@pytest.mark.parametrize("name", ["save_event", "list_events_admin"])
def test_the_editor_is_for_the_admin_only(db, name):
    before = dict(db.docs)
    for token in (None, VERIFIED, {"womanReviewer": True}, {"verified": True, "admin": False}):
        raises(
            lambda: inner(name)(request(body(), token=token)),
            https_fn.FunctionsErrorCode.PERMISSION_DENIED,
        )
    raises(
        lambda: inner(name)(request(body(), token=ADMIN, app=False)),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    raises(
        lambda: inner(name)(request(body(), uid=None)),
        https_fn.FunctionsErrorCode.UNAUTHENTICATED,
    )
    assert db.docs == before


def test_the_dashboard_admin_signs_in_with_a_password(db):
    password = {**ADMIN, "firebase": {"sign_in_provider": "password"}}
    assert save(body(eventId="pw"), token=password)["ok"] is True
    assert inner("list_events_admin")(request({}, uid="uOwner", token=password))["events"]


def test_validate_returns_what_the_rules_would_accept():
    row, problems = events_admin.validate(body(mode="online", link="https://meet.example.com/a"))
    assert problems == []
    assert row["placeName"] is None and row["imageFiles"] == ["a_1.webp", "b_2.jpg"]


# ------------------------------------------------------ account deletion


def test_deleting_her_account_gives_every_seat_back(db, monkeypatch):
    from identity import store

    monkeypatch.setattr(store, "db", lambda: db)
    monkeypatch.setattr(store.firestore, "transactional", fake_firestore.transactional)
    db.docs["events/e2"] = event(capacity=5)
    db.docs["events/e3"] = event(capacity=5)
    register()
    register(uid=OTHER)
    inner("register_for_event")(request({"eventId": "e2"}, uid=HER, token=VERIFIED))
    assert db.docs["events/e1"]["seatsTaken"] == 2

    assert deletion.FirebaseBackend().purge_group_hook(HER) is True

    assert db.docs["events/e1"]["seatsTaken"] == 1
    assert db.docs["events/e2"]["seatsTaken"] == 0
    assert db.docs["events/e3"]["seatsTaken"] == 0
    assert f"events/e1/attendees/{HER}" not in db.docs
    assert f"events/e2/attendees/{HER}" not in db.docs
    assert f"events/e1/attendees/{OTHER}" in db.docs


def test_deletion_clamps_a_drifted_count_and_is_idempotent(db):
    db.docs["events/e1"]["seatsTaken"] = 0
    db.docs[f"events/e1/attendees/{HER}"] = {"uid": HER}
    assert seats.release_all(db, HER) == 1
    assert db.docs["events/e1"]["seatsTaken"] == 0
    assert seats.release_all(db, HER) == 0
    assert db.docs["events/e1"]["seatsTaken"] == 0
