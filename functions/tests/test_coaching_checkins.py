"""C3: weekly check-ins, Monday follow-up, submitting answers and the coach's
'Needs attention' list."""

from __future__ import annotations

import datetime as dt

import pytest

import coaching
from coaching import checkins, common, errors
from tests import fake_firestore
from tests.coaching_helpers import Pushes, _txn, refusal  # noqa: F401
from tests.test_coaching_subscriptions import COACH, seed

# 2026-10-30 is Friday of ISO week 2026-W44; 2026-11-02 is the Monday after.
FRIDAY = dt.datetime(2026, 10, 30, 7, 0, tzinfo=dt.timezone.utc)
MONDAY = dt.datetime(2026, 11, 2, 7, 0, tzinfo=dt.timezone.utc)


@pytest.fixture
def db():
    return fake_firestore.FakeFirestore()


@pytest.fixture
def pushes():
    return Pushes()


def _sub(
    db,
    sub_id: str,
    client_uid: str,
    *,
    status: str = "active",
    per_week: int = 1,
    client_name: str = "Mona",
    intake: dict | None = None,
    unread: int = 0,
) -> str:
    rel_id = common.rel_id(COACH, client_uid)
    db.document(f"relationships/{rel_id}").set(
        {
            "coachUid": COACH,
            "clientUid": client_uid,
            "status": "active" if status == "active" else "ended",
            "chatOpen": status == "active",
            "activeSubId": sub_id,
            "unreadFor": {COACH: unread},
        }
    )
    db.document(f"subscriptions/{sub_id}").set(
        {
            "coachUid": COACH,
            "clientUid": client_uid,
            "relId": rel_id,
            "status": status,
            "clientName": client_name,
            "package": {"checkInsPerWeek": per_week},
            "intake": intake or {},
        }
    )
    return rel_id


def test_friday_opens_one_card_a_message_and_a_push_per_active_coaching(db, pushes):
    r1 = _sub(db, "s1", "c1", per_week=1)
    r2 = _sub(db, "s2", "c2", per_week=1)
    _sub(db, "s3", "c3", status="ended", per_week=1)
    _sub(db, "s4", "c4", per_week=0)

    assert checkins.send_cards(db, FRIDAY, pushes) == 2
    for rel_id, client in ((r1, "c1"), (r2, "c2")):
        card = db.document(f"relationships/{rel_id}/checkIns/2026-W44").get().to_dict()
        assert card == {
            "clientUid": client,
            "coachUid": COACH,
            "weekKey": "2026-W44",
            "state": "open",
            "createdAt": FRIDAY,
        }
        msgs = [m.to_dict() for m in db.collection(f"relationships/{rel_id}/messages").stream()]
        assert len(msgs) == 1
        assert msgs[0]["systemKind"] == "checkIn"
        assert msgs[0]["weekKey"] == "2026-W44"
    assert pushes == [("c1", "checkInDue"), ("c2", "checkInDue")]


def test_running_friday_twice_adds_nothing(db, pushes):
    rel_id = _sub(db, "s1", "c1", per_week=1)
    assert checkins.send_cards(db, FRIDAY, pushes) == 1
    assert checkins.send_cards(db, FRIDAY, pushes) == 0
    msgs = [m.to_dict() for m in db.collection(f"relationships/{rel_id}/messages").stream()]
    assert len(msgs) == 1
    assert len(pushes) == 1


def test_monday_follow_up_is_sent_once_and_only_for_an_open_card(db, pushes):
    r1 = _sub(db, "s1", "c1", per_week=1)
    _sub(db, "s2", "c2", per_week=1)
    checkins.send_cards(db, FRIDAY, pushes)
    pushes.clear()

    checkins.submit(
        db,
        "c1",
        {
            "relId": r1,
            "weekKey": "2026-W44",
            "answers": {"training": "all", "energy": 4, "food": 4, "pain": False, "note": ""},
        },
        live=True,
        now=FRIDAY + dt.timedelta(hours=2),
    )

    assert checkins.follow_up(db, MONDAY, pushes) == 1
    assert pushes == [("c2", "checkInFollowUp")]
    assert checkins.follow_up(db, MONDAY, pushes) == 0
    assert len(pushes) == 1


def test_the_client_answers_once_with_checked_values(db, pushes):
    rel_id = _sub(db, "s1", "c1", per_week=1)
    checkins.send_cards(db, FRIDAY, pushes)

    good = {"training": "most", "energy": 4, "food": 3, "pain": True, "note": "knee a bit sore"}
    ans = checkins.submit(
        db,
        "c1",
        {"relId": rel_id, "weekKey": "2026-W44", "answers": good},
        live=True,
        now=FRIDAY + dt.timedelta(hours=1),
    )
    assert ans == {"ok": True}
    card = db.document(f"relationships/{rel_id}/checkIns/2026-W44").get().to_dict()
    assert card["state"] == "answered"
    assert card["answers"] == good

    assert refusal(
        lambda: checkins.submit(
            db,
            "c1",
            {"relId": rel_id, "weekKey": "2026-W44", "answers": good},
            live=True,
            now=FRIDAY + dt.timedelta(hours=2),
        )
    ) == (errors.PRECONDITION, errors.WRONG_STATUS)

    assert refusal(
        lambda: checkins.submit(
            db,
            "stranger",
            {"relId": rel_id, "weekKey": "2026-W44", "answers": good},
            live=True,
            now=FRIDAY + dt.timedelta(hours=2),
        )
    ) == (errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)

    r2 = _sub(db, "s2", "c2", per_week=1)
    checkins.send_cards(db, FRIDAY, pushes)
    for bad_answers in (
        {**good, "energy": 6},
        {**good, "training": "x"},
        {**good, "pain": "no"},
        {**good, "extra": 1},
        {**good, "note": "a" * 301},
    ):
        assert refusal(
            lambda b=bad_answers: checkins.submit(
                db,
                "c2",
                {"relId": r2, "weekKey": "2026-W44", "answers": b},
                live=True,
                now=FRIDAY + dt.timedelta(hours=1),
            )
        ) == (errors.INVALID, errors.BAD_REQUEST)


def test_needs_attention_lists_reasons(db, pushes):
    seed(db)
    # 1. Training 'none' + unread 1 (2 reasons -> sorted first)
    r_missed = _sub(db, "s_missed", "c_missed", client_name="Aya", unread=1)
    db.document(f"relationships/{r_missed}/checkIns/2026-W44").set(
        {
            "clientUid": "c_missed",
            "coachUid": COACH,
            "weekKey": "2026-W44",
            "state": "answered",
            "createdAt": FRIDAY - dt.timedelta(days=1),
            "answeredAt": FRIDAY,
            "answers": {"training": "none", "energy": 3, "food": 3, "pain": False, "note": ""},
        }
    )

    # 2. Open card created 4 days ago -> noCheckIn
    r_late = _sub(db, "s_late", "c_late", client_name="Basma")
    db.document(f"relationships/{r_late}/checkIns/2026-W44").set(
        {
            "clientUid": "c_late",
            "coachUid": COACH,
            "weekKey": "2026-W44",
            "state": "open",
            "createdAt": FRIDAY - dt.timedelta(days=4),
        }
    )

    # 3. Unread 2 -> unread
    _sub(db, "s_unread", "c_unread", client_name="Dina", unread=2)

    # 4. intake.health.heart true and no healthReviewedAt -> healthFlag
    _sub(
        db,
        "s_health",
        "c_health",
        client_name="Hana",
        intake={"health": {"heart": True}},
    )

    # 5. Clean client -> absent
    _sub(db, "s_clean", "c_clean", client_name="Sara")

    res = checkins.needs_attention(db, COACH, live=True, coach_v="active", now=FRIDAY)
    clients = res["clients"]
    assert [c["subId"] for c in clients] == ["s_missed", "s_late", "s_unread", "s_health"]
    by_sub = {c["subId"]: c["reasons"] for c in clients}
    assert by_sub == {
        "s_missed": ["missedSessions", "unread"],
        "s_late": ["noCheckIn"],
        "s_unread": ["unread"],
        "s_health": ["healthFlag"],
    }


def test_the_switch_is_on_and_off_refuses_both_callables(db):
    assert coaching.CHECK_INS_LIVE is True
    assert refusal(
        lambda: checkins.submit(
            db,
            "c1",
            {
                "relId": "coach-uid-1__c1",
                "weekKey": "2026-W44",
                "answers": {"training": "all", "energy": 5, "food": 5, "pain": False, "note": ""},
            },
            live=False,
            now=FRIDAY,
        )
    ) == (errors.PRECONDITION, errors.COACH_APP_CLOSED)
    assert refusal(
        lambda: checkins.needs_attention(db, COACH, live=False, coach_v="active", now=FRIDAY)
    ) == (errors.PRECONDITION, errors.COACH_APP_CLOSED)


GOOD = {"training": "most", "energy": 4, "food": 3, "pain": True, "note": "knee a bit sore"}


def _submit(db, uid, rel_id, week, answers=GOOD):
    return checkins.submit(
        db, uid, {"relId": rel_id, "weekKey": week, "answers": answers}, live=True, now=FRIDAY + dt.timedelta(hours=1)
    )


def test_a_malformed_rel_id_or_week_key_is_a_bad_request_not_a_path_error(db, pushes):
    rel_id = _sub(db, "s1", "c1", per_week=1)
    checkins.send_cards(db, FRIDAY, pushes)
    for rel, week in (
        ("a/b", "2026-W44"),
        ("../x", "2026-W44"),
        ("nodoubleunderscore", "2026-W44"),
        (rel_id + "/messages/x", "2026-W44"),
        (rel_id + "\n", "2026-W44"),
        (7, "2026-W44"),
        (rel_id, "2026-W44/x"),
        (rel_id, "W44"),
        (rel_id, "2026-W4"),
        (rel_id, None),
    ):
        assert refusal(lambda r=rel, w=week: _submit(db, "c1", r, w)) == (errors.INVALID, errors.BAD_REQUEST), (rel, week)
    assert _submit(db, "c1", rel_id, "2026-W44") == {"ok": True}


def test_answers_are_refused_once_the_coaching_has_ended(db, pushes):
    rel_id = _sub(db, "s1", "c1", per_week=1)
    checkins.send_cards(db, FRIDAY, pushes)
    db.document(f"relationships/{rel_id}").update({"status": "ended"})
    assert refusal(lambda: _submit(db, "c1", rel_id, "2026-W44")) == (errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    assert db.document(f"relationships/{rel_id}/checkIns/2026-W44").get().to_dict()["state"] == "open"


def test_one_failing_client_does_not_stop_the_friday_batch(db, pushes, monkeypatch):
    r_ok1 = _sub(db, "s1", "c1", per_week=1)
    r_bad = _sub(db, "s2", "c2", per_week=1)
    r_ok2 = _sub(db, "s3", "c3", per_week=1)
    real = checkins._open_card

    def flaky(database, row, key, now):
        if row["clientUid"] == "c2":
            raise RuntimeError("transaction aborted")
        return real(database, row, key, now)

    monkeypatch.setattr(checkins, "_open_card", flaky)
    assert checkins.send_cards(db, FRIDAY, pushes) == 2
    assert sorted(pushes) == [("c1", "checkInDue"), ("c3", "checkInDue")]
    assert db.document(f"relationships/{r_ok1}/checkIns/2026-W44").get().exists
    assert db.document(f"relationships/{r_ok2}/checkIns/2026-W44").get().exists
    assert not db.document(f"relationships/{r_bad}/checkIns/2026-W44").get().exists


def test_a_failing_push_does_not_stop_the_batch(db):
    _sub(db, "s1", "c1", per_week=1)
    _sub(db, "s2", "c2", per_week=1)
    sent = []

    def notify(uid, kind):
        if uid == "c1":
            raise RuntimeError("push service down")
        sent.append((uid, kind))

    assert checkins.send_cards(db, FRIDAY, notify) == 2
    assert sent == [("c2", "checkInDue")]


def test_one_failing_client_does_not_stop_the_monday_follow_up(db, pushes, monkeypatch):
    _sub(db, "s1", "c1", per_week=1)
    _sub(db, "s2", "c2", per_week=1)
    _sub(db, "s3", "c3", per_week=1)
    checkins.send_cards(db, FRIDAY, pushes)
    pushes.clear()

    def notify(uid, kind):
        if uid == "c1":
            raise RuntimeError("push service down")
        pushes.append((uid, kind))

    assert checkins.follow_up(db, MONDAY, notify) == 3
    assert sorted(pushes) == [("c2", "checkInFollowUp"), ("c3", "checkInFollowUp")]


def test_the_coach_gets_the_latest_answers_and_a_note_alone_is_listed(db, pushes):
    seed(db)
    r_pain = _sub(db, "s_pain", "c_pain", client_name="Aya")
    r_note = _sub(db, "s_note", "c_note", client_name="Basma")
    _sub(db, "s_quiet", "c_quiet", client_name="Dina")
    checkins.send_cards(db, FRIDAY, pushes)
    _submit(db, "c_pain", r_pain, "2026-W44", {**GOOD, "note": "my knee hurts when I squat"})
    _submit(
        db, "c_note", r_note, "2026-W44",
        {"training": "all", "energy": 5, "food": 5, "pain": False, "note": "loved the new plan"},
    )

    clients = checkins.needs_attention(db, COACH, live=True, coach_v="active", now=FRIDAY + dt.timedelta(days=1))["clients"]

    assert [c["subId"] for c in clients] == ["s_pain", "s_note"]
    pain, note = clients
    assert "healthFlag" in pain["reasons"]
    assert pain["checkIn"]["weekKey"] == "2026-W44"
    assert pain["checkIn"]["answers"]["note"] == "my knee hurts when I squat"
    assert pain["checkIn"]["answers"]["pain"] is True
    assert note["reasons"] == []
    assert note["checkIn"]["answers"]["note"] == "loved the new plan"
