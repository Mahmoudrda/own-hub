"""Marketing videos: upload checks, Cairo months, staff decisions, the 20th reminder."""

from __future__ import annotations

import datetime as dt

import pytest

from coaching import errors, promo
from tests import fake_firestore
from tests.coaching_helpers import Notes, _txn, refusal  # noqa: F401
from tests.fake_blobs import FakeBlobs

COACH = "coach-1"
OTHER = "coach-2"
STAFF = "staff-1"
UTC = dt.timezone.utc
NOW = dt.datetime(2026, 10, 12, 9, 0, tzinfo=UTC)


@pytest.fixture
def db():
    database = fake_firestore.FakeFirestore()
    for uid, name in ((COACH, "Rahma"), (OTHER, "Mona")):
        database.document(f"coachPrivate/{uid}").set({"suspended": False, "fullName": name})
        database.document(f"coaches/{uid}").set({"displayName": name, "published": True})
    return database


@pytest.fixture
def blobs():
    return FakeBlobs()


def path(name="a1", uid=COACH, ext="mp4"):
    return f"coach-docs/{uid}/promo/{name}.{ext}"


def send(db, blobs, name="a1", *, uid=COACH, now=NOW, size=5000, ctype="video/mp4", **over):
    blobs.put(path(name, uid), b"x" * size, ctype)
    data = {"mediaRef": path(name, uid), "topic": "workout_tip", "durationSeconds": 60, **over}
    return promo.add(db, uid, data, live=True, coach_v="active", blobs=blobs, now=now)


def docs(db, uid=COACH):
    return {s.id: s.to_dict() for s in db.collection(f"coachPrivate/{uid}/promoVideos").stream()}


def test_a_video_is_kept_waiting_for_its_cairo_month_and_locked(db, blobs):
    assert send(db, blobs) == {"videoId": "a1", "status": "waiting"}
    row = docs(db)["a1"]
    assert (row["status"], row["month"], row["topic"], row["durationSeconds"]) == ("waiting", "2026-10", "workout_tip", 60)
    assert row["path"] == path() and row["coachUid"] == COACH
    assert blobs.locked == [path()]
    assert not [p for p in db.docs if p.startswith(f"coaches/{COACH}/media")]


def test_the_same_upload_sent_twice_is_one_video(db, blobs):
    send(db, blobs)
    send(db, blobs)
    assert list(docs(db)) == ["a1"]


@pytest.mark.parametrize(
    "moment, month",
    [
        (dt.datetime(2026, 10, 31, 21, 59, tzinfo=UTC), "2026-10"),
        (dt.datetime(2026, 10, 31, 22, 30, tzinfo=UTC), "2026-11"),  # Cairo is UTC+2 after DST ends
        (dt.datetime(2026, 4, 30, 21, 30, tzinfo=UTC), "2026-05"),  # UTC+3 in summer
        (dt.datetime(2026, 12, 31, 22, 0, tzinfo=UTC), "2027-01"),
    ],
)
def test_the_month_follows_cairo_time(moment, month):
    assert promo.month_key(moment) == month


def test_a_video_sent_just_after_midnight_in_cairo_counts_for_the_new_month(db, blobs):
    send(db, blobs, "late", now=dt.datetime(2026, 10, 31, 22, 30, tzinfo=UTC))
    assert docs(db)["late"]["month"] == "2026-11"


@pytest.mark.parametrize(
    "over",
    [
        {"topic": "cats"}, {"topic": None},
        {"durationSeconds": 29}, {"durationSeconds": 181}, {"durationSeconds": "60"}, {"durationSeconds": True},
        {"mediaRef": "coach-docs/coach-2/promo/a1.mp4"},  # someone else's folder
        {"mediaRef": f"coach-docs/{COACH}/gallery/a1.mp4"},
        {"mediaRef": f"coach-docs/{COACH}/promo/a1.exe"},
        {"mediaRef": f"coach-docs/{COACH}/promo/../x.mp4"},
        {"mediaRef": 7},
    ],
)
def test_a_malformed_request_is_refused_and_nothing_is_kept(db, blobs, over):
    blobs.put(path(), b"x", "video/mp4")
    data = {"mediaRef": path(), "topic": "workout_tip", "durationSeconds": 60, **over}
    assert refusal(lambda: promo.add(db, COACH, data, live=True, coach_v="active", blobs=blobs, now=NOW)) == (
        errors.INVALID, errors.BAD_REQUEST)
    assert docs(db) == {}


def test_a_file_that_is_not_there_too_big_or_not_a_video_is_refused_and_dropped(db, blobs):
    data = {"mediaRef": path("ghost"), "topic": "introduction", "durationSeconds": 90}
    assert refusal(lambda: promo.add(db, COACH, data, live=True, coach_v="active", blobs=blobs, now=NOW)) == (
        errors.INVALID, errors.FILE_NOT_UPLOADED)
    big = refusal(lambda: send(db, blobs, "big", size=promo.MAX_BYTES + 1))
    pdf = refusal(lambda: send(db, blobs, "pdf", ctype="application/pdf"))
    empty = refusal(lambda: send(db, blobs, "empty", size=0))
    assert big == pdf == empty == (errors.INVALID, errors.FILE_NOT_UPLOADED)
    assert docs(db) == {} and sorted(blobs.deleted) == [path("big"), path("empty"), path("pdf")]


def test_a_month_holds_at_most_six_and_the_next_month_starts_again(db, blobs):
    for n in range(promo.MAX_PER_MONTH):
        send(db, blobs, f"v{n}")
    assert refusal(lambda: send(db, blobs, "v9")) == (errors.EXHAUSTED, errors.TOO_MANY_MEDIA)
    assert send(db, blobs, "v9", now=dt.datetime(2026, 11, 3, tzinfo=UTC))["status"] == "waiting"


def test_who_may_upload(db, blobs):
    ok = {"mediaRef": path(), "topic": "myth", "durationSeconds": 60}
    blobs.put(path(), b"x", "video/mp4")
    call = lambda **kw: promo.add(db, COACH, {**ok, "topic": "training_myth"}, **{"live": True, "coach_v": "active", **kw}, blobs=blobs, now=NOW)  # noqa: E731
    assert refusal(lambda: call(live=False)) == (errors.PRECONDITION, errors.COACH_APP_CLOSED)
    assert refusal(lambda: call(coach_v=None)) == (errors.PERMISSION, errors.NOT_A_COACH)
    db.document(f"coachPrivate/{COACH}").update({"suspended": True})
    assert refusal(call) == (errors.PERMISSION, errors.COACH_SUSPENDED)
    db.document(f"coachPrivate/{COACH}").update({"suspended": False, "hold": {"reason": "fee"}})
    assert call()["status"] == "waiting"  # a coach on hold may still upload


def test_my_videos_show_this_month_with_status_and_reason(db, blobs):
    notes = Notes()
    send(db, blobs, "a1")
    send(db, blobs, "a2", now=NOW + dt.timedelta(hours=1))
    send(db, blobs, "old", now=dt.datetime(2026, 9, 5, tzinfo=UTC))
    promo.decide(db, STAFF, {"coachUid": COACH, "videoId": "a1", "decision": "approve"}, notify=notes, now=NOW)
    promo.decide(
        db, STAFF, {"coachUid": COACH, "videoId": "a2", "decision": "changes", "reason": "The sound is too low."},
        notify=notes, now=NOW)
    out = promo.mine(db, COACH, live=True, coach_v="active", now=NOW)
    assert (out["month"], out["target"], out["approved"]) == ("2026-10", 2, 1)
    assert [(i["id"], i["status"], i["reason"]) for i in out["items"]] == [
        ("a1", "approved", ""), ("a2", "changes", "The sound is too low.")]
    assert notes.sent == [(COACH, "promoDecision")] * 2


def test_staff_decisions_need_a_reason_for_changes_and_only_apply_to_a_waiting_video(db, blobs):
    notes = Notes()
    send(db, blobs)
    ask = lambda **kw: promo.decide(db, STAFF, {"coachUid": COACH, "videoId": "a1", **kw}, notify=notes, now=NOW)  # noqa: E731
    assert refusal(lambda: ask(decision="changes")) == (errors.INVALID, errors.BAD_REQUEST)
    assert refusal(lambda: ask(decision="changes", reason="x" * 201)) == (errors.INVALID, errors.BAD_REQUEST)
    assert refusal(lambda: ask(decision="maybe")) == (errors.INVALID, errors.BAD_REQUEST)
    assert refusal(lambda: promo.decide(db, STAFF, {"coachUid": COACH, "videoId": "nope", "decision": "approve"},
                                        notify=notes, now=NOW)) == (errors.NOT_FOUND, errors.MEDIA_NOT_FOUND)
    assert notes.sent == []
    assert ask(decision="approve") == {"status": "approved"}
    assert docs(db)["a1"]["status"] == "approved" and docs(db)["a1"]["reason"] is None
    assert refusal(lambda: ask(decision="approve")) == (errors.PRECONDITION, errors.WRONG_STATUS)
    assert refusal(lambda: promo.decide(db, COACH, {"coachUid": COACH, "videoId": "a1", "decision": "approve"},
                                        notify=notes, now=NOW)) == (errors.PERMISSION, errors.STAFF_IS_SUBJECT)


def test_the_staff_month_view_counts_every_coach_and_lists_the_waiting(db, blobs):
    notes = Notes()
    send(db, blobs, "a1")
    send(db, blobs, "a2")
    send(db, blobs, "b1", uid=OTHER)
    send(db, blobs, "sep", now=dt.datetime(2026, 9, 20, tzinfo=UTC))
    promo.decide(db, STAFF, {"coachUid": COACH, "videoId": "a1", "decision": "approve"}, notify=notes, now=NOW)
    promo.decide(db, STAFF, {"coachUid": COACH, "videoId": "a2", "decision": "changes", "reason": "Dark."}, notify=notes, now=NOW)
    out = promo.list_for_staff(db, STAFF, {}, now=NOW)
    by = {c["uid"]: c for c in out["coaches"]}
    assert (out["month"], out["target"]) == ("2026-10", 2)
    assert (by[COACH]["approved"], by[COACH]["changes"], by[COACH]["waiting"]) == (1, 1, 0)
    assert (by[OTHER]["approved"], by[OTHER]["waiting"], by[OTHER]["name"]) == (0, 1, "Mona")
    assert [(w["coachUid"], w["id"], w["path"]) for w in out["waiting"]] == [
        (COACH, "sep", path("sep")), (OTHER, "b1", path("b1", OTHER))]
    sept = promo.list_for_staff(db, STAFF, {"month": "2026-09"}, now=NOW)
    assert {c["uid"]: c["waiting"] for c in sept["coaches"]}[COACH] == 1
    for bad in ("2026-13", "oct", 7):
        assert refusal(lambda m=bad: promo.list_for_staff(db, STAFF, {"month": m}, now=NOW)) == (
            errors.INVALID, errors.BAD_REQUEST)


def test_the_reminder_goes_to_coaches_below_the_target_once_a_month(db, blobs):
    notes = Notes()
    day20 = dt.datetime(2026, 10, 20, 7, 0, tzinfo=UTC)
    for n in ("a1", "a2"):
        send(db, blobs, n)
        promo.decide(db, STAFF, {"coachUid": COACH, "videoId": n, "decision": "approve"}, notify=notes, now=NOW)
    send(db, blobs, "b1", uid=OTHER)  # waiting does not count
    db.document("coachPrivate/coach-3").set({"suspended": True})
    db.document("coachPrivate/coach-4").set({"suspended": False, "hold": {"reason": "fee"}})
    db.document("coaches/coach-4").set({"displayName": "Dina", "published": True})
    db.document("coachPrivate/coach-5").set({"suspended": False})  # approved, no page yet: not reminded
    db.document("coachPrivate/coach-6").set({"suspended": False})  # a page that is not published: not reminded
    db.document("coaches/coach-6").set({"displayName": "Mai", "published": False})
    notes.sent.clear()

    assert promo.remind(db, day20, notes) == 2
    assert sorted(notes.sent) == [("coach-2", "promoReminder"), ("coach-4", "promoReminder")]
    assert promo.remind(db, day20 + dt.timedelta(hours=1), notes) == 0
    assert len(notes.sent) == 2
    # Next month the marker no longer matches.
    assert promo.remind(db, dt.datetime(2026, 11, 20, 7, tzinfo=UTC), notes) == 3
    assert sorted(set(u for u, _ in notes.sent[2:])) == [COACH, "coach-2", "coach-4"]


def test_one_failing_reminder_does_not_stop_the_others(db):
    db.document("coachPrivate/coach-3").set({"suspended": False})
    db.document("coaches/coach-3").set({"displayName": "Sara", "published": True})
    sent = []

    def flaky(uid, kind):
        if uid == COACH:
            raise RuntimeError("push service down")
        sent.append(uid)

    assert promo.remind(db, dt.datetime(2026, 10, 20, 7, tzinfo=UTC), flaky) == 2  # the failed one is not counted
    assert sorted(sent) == ["coach-2", "coach-3"]
