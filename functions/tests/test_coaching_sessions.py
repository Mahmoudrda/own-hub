"""Live sessions: proposing, answering, marking done."""

import copy
import datetime as dt

import pytest

from coaching import errors, sessions
from tests import fake_firestore
from tests.coaching_helpers import Notes, _txn  # noqa: F401

NOW = dt.datetime(2026, 11, 1, 12, tzinfo=dt.timezone.utc)
START = NOW + dt.timedelta(days=2)
ENDS = NOW + dt.timedelta(days=20)
LINK = "https://meet.google.com/abc-defg-hij"
REL = "coach1__client1"


def make_db(status="active", included=4, used=0):
    db = fake_firestore.FakeFirestore()
    db.collection("subscriptions").document("sub1").set(
        {"coachUid": "coach1", "clientUid": "client1", "relId": REL, "status": status,
         "sessionsIncluded": included, "sessionsUsed": used, "endsAt": ENDS}
    )
    db.collection("coaches").document("coach1").set({"displayName": "C", "stats": {"sessionsDone": 0}})
    db.collection("coachPrivate").document("coach1").set({"payoutState": "confirmed"})
    return db


def add_session(db, sid="s1", status="proposed", starts=START, **extra):
    db.collection("subscriptions").document("sub1").collection("sessions").document(sid).set(
        {"startsAt": starts, "minutes": 45, "link": LINK, "status": status, "proposedBy": "coach1", **extra}
    )


def session_doc(db, sid="s1"):
    return db.docs[f"subscriptions/sub1/sessions/{sid}"]


def messages(db):
    return [v for k, v in db.docs.items() if k.startswith(f"relationships/{REL}/messages/")]


def schedule(db, uid="coach1", notes=None, live=True, coach_v="active", **over):
    data = {"subId": "sub1", "startsAt": START.isoformat(), "minutes": 45, "link": LINK}
    data.update(over)
    notes = notes if notes is not None else Notes()
    return sessions.schedule(db, uid, data, live=live, coach_v=coach_v, now=NOW, notify=notes), notes


def refuses(fn, reason, db):
    before = copy.deepcopy(db.docs)
    with pytest.raises(errors.CoachingError) as caught:
        fn()
    assert caught.value.reason == reason
    assert db.docs == before
    return caught.value


# ------------------------------------------------------------------ schedule --

def test_a_proposal_writes_the_session_a_card_and_a_push():
    db = make_db()
    out, notes = schedule(db)
    row = session_doc(db, out["sessionId"])
    assert row == {"startsAt": START, "minutes": 45, "link": LINK, "status": "proposed",
                   "proposedBy": "coach1", "createdAt": NOW, "statusAt": NOW}
    card = messages(db)[0]
    assert card["type"] == "session" and card["sessionId"] == out["sessionId"]
    assert card["startsAt"] == START and card["minutes"] == 45 and card["createdAt"] == NOW
    assert "link" not in card
    assert notes.sent == [("client1", "sessionProposed")]


def test_an_offset_time_is_stored_as_utc():
    db = make_db()
    out, _ = schedule(db, startsAt="2026-11-03T16:00:00+02:00")
    assert session_doc(db, out["sessionId"])["startsAt"] == dt.datetime(2026, 11, 3, 14, tzinfo=dt.timezone.utc)


def test_the_coach_app_must_be_live():
    db = make_db()
    refuses(lambda: schedule(db, live=False), errors.COACH_APP_CLOSED, db)


@pytest.mark.parametrize("coach_v,reason", [("suspended", errors.COACH_SUSPENDED), (None, errors.NOT_A_COACH)])
def test_only_an_active_coach_proposes(coach_v, reason):
    db = make_db()
    refuses(lambda: schedule(db, coach_v=coach_v), reason, db)


def test_another_coach_or_a_missing_subscription_is_not_found():
    db = make_db()
    db.collection("coachPrivate").document("coach2").set({"payoutState": "confirmed"})
    refuses(lambda: schedule(db, uid="coach2"), errors.REQUEST_NOT_FOUND, db)
    refuses(lambda: schedule(db, subId="ghost"), errors.REQUEST_NOT_FOUND, db)


@pytest.mark.parametrize("status", ["requested", "awaiting_payment", "payment_review", "ended", "cancelled", "ended_early"])
def test_only_an_active_subscription_takes_a_session(status):
    db = make_db(status)
    refuses(lambda: schedule(db), errors.WRONG_STATUS, db)


@pytest.mark.parametrize(
    "over",
    [
        {"startsAt": "tomorrow"}, {"startsAt": None}, {"startsAt": 5},
        {"startsAt": "2026-11-03T16:00:00"},
        {"startsAt": (NOW + dt.timedelta(minutes=14, seconds=59)).isoformat()},
        {"startsAt": NOW.isoformat()},
        {"startsAt": (NOW - dt.timedelta(days=1)).isoformat()},
        {"startsAt": (ENDS + dt.timedelta(seconds=1)).isoformat()},
        {"minutes": 50}, {"minutes": 45.0}, {"minutes": "45"}, {"minutes": None}, {"minutes": True},
        {"subId": ""},
    ],
)
def test_a_bad_time_or_length_is_refused(over):
    db = make_db()
    refuses(lambda: schedule(db, **over), errors.BAD_REQUEST, db)


def test_the_time_limits_are_inclusive():
    db = make_db()
    schedule(db, startsAt=(NOW + dt.timedelta(minutes=15)).isoformat())
    schedule(db, startsAt=ENDS.isoformat())


@pytest.mark.parametrize("minutes", [30, 45, 60])
def test_each_allowed_length_works(minutes):
    schedule(make_db(), minutes=minutes)


@pytest.mark.parametrize(
    "link",
    [
        "https://meet.google.com/abc-defg-hij",
        "https://zoom.us/j/123456789",
        "https://us02web.zoom.us/j/123456789?pwd=abc",
        "https://teams.microsoft.com/l/meetup-join/abc",
        "https://teams.live.com/meet/123",
        "HTTPS://Meet.Google.com/x",
    ],
)
def test_allowed_hosts_pass(link):
    db = make_db()
    out, _ = schedule(db, link=link)
    assert session_doc(db, out["sessionId"])["link"] == link


@pytest.mark.parametrize(
    "link",
    [
        "http://meet.google.com/abc",
        "ftp://meet.google.com/abc",
        "//meet.google.com/abc",
        "meet.google.com/abc",
        "https://meet.google.com.evil.com/abc",
        "https://evil.com/meet.google.com",
        "https://evilmeet.google.com.attacker.io/",
        "https://notmeet.google.com/abc",
        "https://evilzoom.us/j/1",
        "https://zoom.us.evil.com/j/1",
        "https://zoom.us.evil.com@zoom.us/j/1",
        "https://user@meet.google.com/abc",
        "https://user:pass@meet.google.com/abc",
        "https://meet.google.com@evil.com/abc",
        "https://evil.com\\@meet.google.com/",
        "https://evil.com#@meet.google.com/",
        "https://meet.google.com:8443/abc",
        "https://meet.google.com./abc",
        "https://.zoom.us/j/1",
        "https://meet.google.com /abc",
        "https://meet.google.com/abc\nx",
        "https://meet.gооgle.com/abc",
        "https://google.com/abc",
        "https://teams.microsoft.com.evil.com/",
        "https://sub.teams.microsoft.com/",
        "https://sub.meet.google.com/",
        "javascript:alert(1)",
        "https://",
        "",
        None,
        12,
        "https://meet.google.com/" + "a" * 280,
    ],
)
def test_other_links_are_refused(link):
    db = make_db()
    refuses(lambda: schedule(db, link=link), errors.SESSION_LINK_INVALID, db)


def test_a_link_of_exactly_300_characters_is_fine():
    link = "https://meet.google.com/" + "a" * (300 - len("https://meet.google.com/"))
    assert len(link) == 300
    schedule(make_db(), link=link)


def test_the_package_session_count_limits_proposals():
    db = make_db(included=2)
    schedule(db)
    schedule(db)
    refuses(lambda: schedule(db), errors.WRONG_STATUS, db)


def test_cancelled_and_declined_sessions_do_not_count():
    db = make_db(included=2)
    add_session(db, "a", "cancelled")
    add_session(db, "b", "declined")
    add_session(db, "c", "done")
    schedule(db)
    refuses(lambda: schedule(db), errors.WRONG_STATUS, db)


def test_a_package_with_no_live_sessions_takes_none():
    db = make_db(included=0)
    refuses(lambda: schedule(db), errors.WRONG_STATUS, db)


# ------------------------------------------------------------------- respond --

def respond(db, uid="client1", decision="confirm", live=True, **over):
    data = {"subId": "sub1", "sessionId": "s1", "decision": decision}
    data.update(over)
    return sessions.respond(db, uid, data, live=live, now=NOW)


def test_the_client_confirms_and_the_chat_says_so():
    db = make_db()
    add_session(db)
    assert respond(db) == {"status": "confirmed"}
    row = session_doc(db)
    assert row["status"] == "confirmed" and row["statusAt"] == NOW
    card = messages(db)[0]
    assert card["type"] == "system" and card["systemKind"] == "sessionConfirmed"
    assert card["sessionId"] == "s1" and card["senderUid"] == "client1"


def test_the_client_declines_without_a_system_message():
    db = make_db()
    add_session(db)
    assert respond(db, decision="decline") == {"status": "declined"}
    assert session_doc(db)["status"] == "declined"
    assert messages(db) == []


def test_a_declined_session_frees_its_place():
    db = make_db(included=1)
    out, _ = schedule(db)
    respond(db, sessionId=out["sessionId"], decision="decline")
    schedule(db)


def test_respond_refusals():
    db = make_db()
    add_session(db)
    refuses(lambda: respond(db, live=False), errors.COACH_APP_CLOSED, db)
    refuses(lambda: respond(db, uid="coach1"), errors.REQUEST_NOT_FOUND, db)
    refuses(lambda: respond(db, uid="stranger"), errors.REQUEST_NOT_FOUND, db)
    refuses(lambda: respond(db, subId="ghost"), errors.REQUEST_NOT_FOUND, db)
    refuses(lambda: respond(db, sessionId="ghost"), errors.SESSION_NOT_FOUND, db)
    refuses(lambda: respond(db, decision="maybe"), errors.BAD_REQUEST, db)
    refuses(lambda: respond(db, decision=None), errors.BAD_REQUEST, db)


@pytest.mark.parametrize("status", ["confirmed", "declined", "done", "cancelled"])
def test_only_a_proposed_session_can_be_answered(status):
    db = make_db()
    add_session(db, status=status)
    refuses(lambda: respond(db), errors.WRONG_STATUS, db)


def test_a_session_of_an_ended_subscription_cannot_be_answered():
    db = make_db(status="ended")
    add_session(db)
    refuses(lambda: respond(db), errors.WRONG_STATUS, db)


# ----------------------------------------------------------------- mark_done --

def done(db, uid="coach1", live=True, now=NOW, **over):
    data = {"subId": "sub1", "sessionId": "s1"}
    data.update(over)
    return sessions.mark_done(db, uid, data, live=live, now=now)


AFTER = START + dt.timedelta(minutes=1)


@pytest.mark.parametrize("first,second", [("coach1", "client1"), ("client1", "coach1")])
def test_a_session_is_done_only_when_both_have_marked_it(first, second):
    db = make_db(used=1)
    add_session(db, status="confirmed")
    assert done(db, uid=first, now=AFTER) == {"status": "confirmed", "sessionsUsed": 1}
    row = session_doc(db)
    assert row["status"] == "confirmed" and row["doneBy"] == [first]
    assert db.docs["subscriptions/sub1"]["sessionsUsed"] == 1
    assert db.docs["coaches/coach1"]["stats"]["sessionsDone"] == 0
    assert messages(db) == []
    later_ = AFTER + dt.timedelta(minutes=5)
    assert done(db, uid=second, now=later_) == {"status": "done", "sessionsUsed": 2}
    row = session_doc(db)
    assert row["status"] == "done" and row["doneBy"] == [first, second] and row["statusAt"] == later_
    assert db.docs["subscriptions/sub1"]["sessionsUsed"] == 2
    assert db.docs["coaches/coach1"]["stats"]["sessionsDone"] == 1
    card = messages(db)[0]
    assert card["type"] == "system" and card["systemKind"] == "sessionDone" and card["sessionId"] == "s1"


def test_it_can_be_marked_at_the_exact_start():
    db = make_db()
    add_session(db, status="confirmed")
    done(db, uid="coach1", now=START)
    assert done(db, uid="client1", now=START)["sessionsUsed"] == 1


def test_before_the_start_it_is_refused():
    db = make_db()
    add_session(db, status="confirmed")
    refuses(lambda: done(db, now=START - dt.timedelta(seconds=1)), errors.SESSION_NOT_STARTED, db)


def test_marking_twice_by_one_party_is_a_no_op():
    db = make_db()
    add_session(db, status="confirmed")
    done(db, now=AFTER)
    before = copy.deepcopy(db.docs)
    assert done(db, now=AFTER) == {"status": "confirmed", "sessionsUsed": 0}
    assert db.docs == before
    done(db, uid="client1", now=AFTER)
    assert done(db, uid="client1", now=AFTER) == {"status": "done", "sessionsUsed": 1}
    assert db.docs["subscriptions/sub1"]["sessionsUsed"] == 1
    assert db.docs["coaches/coach1"]["stats"]["sessionsDone"] == 1


def _requested(db):
    db.collection("subscriptions").document("sub1").update({"cancellation": {"state": "requested"}})


def test_every_session_step_is_frozen_while_a_cancellation_is_requested():
    db = make_db()
    add_session(db, status="proposed")
    add_session(db, sid="s2", status="confirmed")
    _requested(db)
    refuses(lambda: schedule(db), errors.WRONG_STATUS, db)
    refuses(lambda: respond(db), errors.WRONG_STATUS, db)
    refuses(lambda: done(db, sessionId="s2", now=AFTER), errors.WRONG_STATUS, db)


def test_a_declined_cancellation_unfreezes_the_sessions():
    db = make_db()
    add_session(db, status="confirmed")
    db.collection("subscriptions").document("sub1").update({"cancellation": {"state": "declined"}})
    assert done(db, now=AFTER)["status"] == "confirmed"


def test_a_suspended_coach_cannot_schedule_even_with_a_valid_claim():
    db = make_db()
    db.collection("coachPrivate").document("coach1").update({"suspended": True})
    refuses(lambda: schedule(db), errors.COACH_SUSPENDED, db)


@pytest.mark.parametrize("status", ["proposed", "declined", "cancelled", "done"])
def test_only_a_confirmed_session_can_be_marked_done(status):
    db = make_db()
    add_session(db, status=status)
    refuses(lambda: done(db, now=AFTER), errors.WRONG_STATUS, db)


def test_mark_done_refusals():
    db = make_db()
    add_session(db, status="confirmed")
    refuses(lambda: done(db, live=False, now=AFTER), errors.COACH_APP_CLOSED, db)
    refuses(lambda: done(db, uid="stranger", now=AFTER), errors.REQUEST_NOT_FOUND, db)
    refuses(lambda: done(db, subId="ghost", now=AFTER), errors.REQUEST_NOT_FOUND, db)
    refuses(lambda: done(db, sessionId="ghost", now=AFTER), errors.SESSION_NOT_FOUND, db)
    refuses(lambda: done(db, subId=""), errors.BAD_REQUEST, db)


def test_a_session_of_an_ended_subscription_cannot_be_marked():
    db = make_db(status="ended")
    add_session(db, status="confirmed")
    refuses(lambda: done(db, now=AFTER), errors.WRONG_STATUS, db)


# ----------------------------------------------------------- nextSessionAt --

def next_at(db):
    return db.docs["subscriptions/sub1"].get("nextSessionAt")


def test_scheduling_sets_the_next_session_to_the_earliest_upcoming_one():
    db = make_db()
    schedule(db)
    assert next_at(db) == START
    sooner = NOW + dt.timedelta(days=1)
    schedule(db, startsAt=sooner.isoformat())
    assert next_at(db) == sooner
    schedule(db, startsAt=(NOW + dt.timedelta(days=5)).isoformat())
    assert next_at(db) == sooner


def test_declining_the_earliest_moves_it_to_the_next_and_the_last_clears_it():
    db = make_db()
    add_session(db, "s1", starts=START)
    add_session(db, "s2", starts=START + dt.timedelta(days=3))
    sessions.respond(db, "client1", {"subId": "sub1", "sessionId": "s1", "decision": "decline"}, live=True, now=NOW)
    assert next_at(db) == START + dt.timedelta(days=3)
    sessions.respond(db, "client1", {"subId": "sub1", "sessionId": "s2", "decision": "decline"}, live=True, now=NOW)
    assert next_at(db) is None


def test_confirming_keeps_it_and_marking_done_clears_it():
    db = make_db(used=0)
    add_session(db, status="proposed")
    respond(db)
    assert next_at(db) == START
    done(db, uid="coach1", now=AFTER)
    done(db, uid="client1", now=AFTER)
    assert session_doc(db)["status"] == "done"
    assert next_at(db) is None


@pytest.mark.parametrize("blocker, blocked", [("client1", "coach1"), ("coach1", "client1")])
def test_a_block_either_way_stops_a_proposal(blocker, blocked):
    db = make_db()
    db.collection("users").document(blocker).collection("blocks").document(blocked).set({})
    refuses(lambda: schedule(db), "coach_unavailable", db)


@pytest.mark.parametrize("link", [
    "https://zoom.us/j/81234567890",
    "https://meet.google.com/abc-defg-hij?authuser=1",
])
def test_a_meeting_id_of_many_digits_is_still_fine(link):
    assert sessions.check_link(link) == link


@pytest.mark.parametrize("link", [
    "https://zoom.us/j/123?phone=01012345678",
    "https://meet.google.com/abc?contact=mona@gmail.com",
    "https://zoom.us/j/123?wa=whatsapp",
])
def test_a_meeting_link_carrying_contact_details_is_refused(link):
    with pytest.raises(errors.CoachingError) as caught:
        sessions.check_link(link)
    assert caught.value.reason == errors.CONTAINS_CONTACT
