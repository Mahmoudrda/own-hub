"""Staff moderation of coaching reports."""

import copy
import datetime as dt

import pytest


from coaching import errors, moderation
from console import access
from tests import fake_firestore
from tests.coaching_helpers import _txn  # noqa: F401

NOW = dt.datetime(2026, 11, 1, 12, tzinfo=dt.timezone.utc)
REL = "coach1__client1"
MSG = f"relationships/{REL}/messages/m1"


def base(minutes=0):
    return NOW - dt.timedelta(days=1) + dt.timedelta(minutes=minutes)


def make_db():
    db = fake_firestore.FakeFirestore()
    db.document(f"relationships/{REL}").set(
        {"coachUid": "coach1", "clientUid": "client1", "status": "active", "activeSubId": "sub1"}
    )
    db.document(MSG).set({"senderUid": "coach1", "type": "text", "text": "pay me on instapay"})
    db.document("relationships/coach1__client1/messages/m2").set(
        {"senderUid": "client1", "type": "text", "text": "rude words"}
    )
    db.document("coaches/coach1").set({"displayName": "Coach One", "headline": "Strength"})
    db.document("plans/client1/coachPlans/p1").set(
        {"name": "Phase one", "kind": "workout", "coachUid": "coach1", "body": {"secret": 1}}
    )
    return db


def report(db, rid, kind="coachMessage", ref=MSG, minutes=0, state="submitted", **extra):
    db.collection("reports").document(rid).set(
        {"reporterUid": "client1", "subjectUid": "coach1", "subjectKind": kind, "subjectRef": ref,
         "reason": "spam", "note": "bad", "state": state, "createdAt": base(minutes), **extra}
    )


def listing(db, **data):
    return moderation.list_for_staff(db, "staff1", data, now=NOW)


def logs(db):
    return [v for k, v in db.docs.items() if k.startswith(access.COLLECTION + "/")]


# ---------------------------------------------------------------------- list --

def test_a_list_shows_submitted_coaching_reports_with_their_subjects():
    db = make_db()
    report(db, "r1", minutes=0)
    report(db, "r2", "coachProfile", "coaches/coach1", minutes=1)
    report(db, "r3", "coachPlan", "plans/client1/coachPlans/p1", minutes=2)
    out = listing(db)
    assert out["next"] is None
    assert [i["reportId"] for i in out["items"]] == ["r1", "r2", "r3"]
    assert out["items"][0]["subject"] == {"type": "text", "hidden": False, "text": "pay me on instapay"}
    assert out["items"][1]["subject"] == {"displayName": "Coach One", "headline": "Strength"}
    assert out["items"][2]["subject"] == {"name": "Phase one", "kind": "workout"}
    first = out["items"][0]
    assert first["subjectKind"] == "coachMessage" and first["reason"] == "spam"
    assert first["createdAt"] == base().isoformat() and first["state"] == "submitted"
    assert "reporterUid" not in first and "subjectUid" not in first


def test_oldest_first_whatever_the_ids_say():
    db = make_db()
    report(db, "a", minutes=5)
    report(db, "b", minutes=1)
    report(db, "c", minutes=3)
    assert [i["reportId"] for i in listing(db)["items"]] == ["b", "c", "a"]


def test_other_kinds_and_other_states_are_left_out():
    db = make_db()
    report(db, "ok")
    report(db, "post", "post", "posts/p1", minutes=1)
    report(db, "gone", state="decided", minutes=2)
    assert [i["reportId"] for i in listing(db)["items"]] == ["ok"]
    assert [i["reportId"] for i in listing(db, state="decided")["items"]] == ["gone"]


def test_pages_of_25_with_a_cursor():
    db = make_db()
    for n in range(30):
        report(db, f"r{n:02d}", minutes=n)
    first = listing(db)
    assert len(first["items"]) == 25 and first["next"]
    second = listing(db, after=first["next"])
    assert [i["reportId"] for i in second["items"]] == [f"r{n:02d}" for n in range(25, 30)]
    assert second["next"] is None


def test_the_cursor_does_not_repeat_or_skip_reports_sharing_a_time():
    db = make_db()
    for n in range(27):
        report(db, f"r{n:02d}", minutes=0)
    first = listing(db)
    second = listing(db, after=first["next"])
    ids = [i["reportId"] for i in first["items"] + second["items"]]
    assert ids == sorted(ids) and len(set(ids)) == 27


def test_exactly_25_has_no_next_page():
    db = make_db()
    for n in range(25):
        report(db, f"r{n:02d}", minutes=n)
    assert listing(db)["next"] is None


@pytest.mark.parametrize("data", [{"state": "open"}, {"after": "junk"}, {"after": 5}, {"after": "2026-01-01T00:00:00|r1"}])
def test_a_bad_filter_is_refused(data):
    db = make_db()
    with pytest.raises(errors.CoachingError) as caught:
        listing(db, **data)
    assert caught.value.reason == errors.BAD_REQUEST
    assert logs(db) == []


def test_a_list_leaves_one_access_line_with_no_uid():
    db = make_db()
    report(db, "r1")
    listing(db)
    [line] = logs(db)
    assert line["action"] == "coaching.reports.list"
    assert line["admin"] == access.short_ref("staff1")
    assert "staff1" not in str(line) and "client1" not in str(line)


def test_a_missing_subject_is_marked_missing():
    db = make_db()
    report(db, "r1", ref=f"relationships/{REL}/messages/ghost")
    assert listing(db)["items"][0]["subject"] == {"missing": True}


@pytest.mark.parametrize(
    "kind,ref",
    [
        ("coachMessage", "users/client1"),
        ("coachMessage", "coaches/coach1"),
        ("coachMessage", f"relationships/{REL}/messages"),
        ("coachMessage", f"relationships/{REL}/messages/m1/extra/x"),
        ("coachMessage", "relationships//messages/m1"),
        ("coachProfile", "users/client1"),
        ("coachProfile", "coaches/coach1/packages/p"),
        ("coachProfile", "coachPrivate/coach1"),
        ("coachPlan", "users/client1/consents/x"),
        ("coachPlan", "plans/client1"),
        ("coachMessage", None),
        ("coachMessage", 5),
    ],
)
def test_a_subject_ref_of_the_wrong_shape_is_never_followed(kind, ref):
    db = make_db()
    db.document("users/client1").set({"phone": "secret"})
    db.document("coachPrivate/coach1").set({"payout": "secret"})
    report(db, "r1", kind, ref)
    out = listing(db)
    assert out["items"][0]["subject"] == {"missing": True}
    assert "secret" not in str(out)


def test_only_whitelisted_fields_of_a_subject_are_shown():
    db = make_db()
    report(db, "r1", "coachPlan", "plans/client1/coachPlans/p1")
    assert "body" not in str(listing(db)) and "secret" not in str(listing(db))


# -------------------------------------------------------------------- decide --

class Calls:
    def __init__(self):
        self.suspended, self.ended = [], []

    def suspend(self, uid):
        self.suspended.append(uid)

    def end_early(self, sub_id):
        self.ended.append(sub_id)


def decide(db, calls=None, actor="staff1", **over):
    calls = calls or Calls()
    data = {"reportId": "r1", "decision": "dismiss", "note": ""}
    data.update(over)
    out = moderation.decide(db, actor, data, now=NOW, suspend=calls.suspend, end_early=calls.end_early)
    return out, calls


def stays(db, reason, calls=None, **over):
    before = copy.deepcopy(db.docs)
    calls = calls or Calls()
    with pytest.raises(errors.CoachingError) as caught:
        decide(db, calls, **over)
    assert caught.value.reason == reason
    assert calls.suspended == [] and calls.ended == []
    assert {k: v for k, v in db.docs.items() if not k.startswith(access.COLLECTION)} == {
        k: v for k, v in before.items() if not k.startswith(access.COLLECTION)
    }


def test_dismiss_only_records_the_decision():
    db = make_db()
    report(db, "r1")
    out, calls = decide(db, note="not a breach")
    assert out == {"state": "decided"}
    row = db.docs["reports/r1"]
    assert row["state"] == "decided" and row["decision"] == "dismiss"
    assert row["decidedBy"] == access.short_ref("staff1") and row["decidedAt"] == NOW
    assert "decisionNote" not in row and row["note"] == "bad"
    assert "hidden" not in db.docs[MSG]
    assert calls.suspended == [] and calls.ended == []
    assert len(logs(db)) == 1 and "staff1" not in str(logs(db))


def test_hide_message_hides_it():
    db = make_db()
    report(db, "r1")
    decide(db, decision="hide_message")
    assert db.docs[MSG]["hidden"] is True and "hiddenReason" not in db.docs[MSG]
    assert db.docs[MSG]["text"] == ""
    assert db.docs["reports/r1"]["decision"] == "hide_message"


def test_hide_message_on_a_missing_message_still_records():
    db = make_db()
    report(db, "r1", ref=f"relationships/{REL}/messages/ghost")
    decide(db, decision="hide_message")
    assert db.docs["reports/r1"]["state"] == "decided"
    assert f"relationships/{REL}/messages/ghost" not in db.docs


def test_hide_message_needs_a_message_report():
    db = make_db()
    report(db, "r1", "coachProfile", "coaches/coach1")
    stays(db, errors.BAD_REQUEST, decision="hide_message")


@pytest.mark.parametrize(
    "kind,ref",
    [("coachMessage", MSG), ("coachProfile", "coaches/coach1"), ("coachPlan", "plans/client1/coachPlans/p1")],
)
def test_suspend_coach_suspends_the_coach_the_report_is_about(kind, ref):
    db = make_db()
    report(db, "r1", kind, ref, subjectUid="somebody_else")
    _, calls = decide(db, decision="suspend_coach")
    assert calls.suspended == ["coach1"] and calls.ended == []
    assert db.docs["reports/r1"]["state"] == "decided"


def test_the_reporters_own_claim_of_who_is_reported_is_not_trusted():
    db = make_db()
    report(db, "r1", subjectUid="client1")
    _, calls = decide(db, decision="suspend_coach")
    assert calls.suspended == ["coach1"]


def test_a_clients_message_does_not_get_the_coach_suspended():
    db = make_db()
    report(db, "r1", ref=f"relationships/{REL}/messages/m2")
    stays(db, errors.BAD_REQUEST, decision="suspend_coach")


def test_end_coaching_ends_the_active_subscription():
    db = make_db()
    report(db, "r1")
    _, calls = decide(db, decision="end_coaching")
    assert calls.ended == ["sub1"] and calls.suspended == []
    assert db.docs["reports/r1"]["decision"] == "end_coaching"


def test_end_coaching_from_a_plan_report_finds_the_relationship():
    db = make_db()
    report(db, "r1", "coachPlan", "plans/client1/coachPlans/p1")
    _, calls = decide(db, decision="end_coaching")
    assert calls.ended == ["sub1"]


def test_end_coaching_without_an_active_subscription_is_wrong_status():
    db = make_db()
    db.document(f"relationships/{REL}").update({"activeSubId": None})
    report(db, "r1")
    stays(db, errors.WRONG_STATUS, decision="end_coaching")


def test_end_coaching_needs_a_relationship_to_end():
    db = make_db()
    report(db, "r1", "coachProfile", "coaches/coach1")
    stays(db, errors.BAD_REQUEST, decision="end_coaching")


def test_a_failing_action_leaves_the_report_open():
    db = make_db()
    report(db, "r1")

    def boom(uid):
        raise RuntimeError("auth down")

    with pytest.raises(RuntimeError):
        moderation.decide(db, "staff1", {"reportId": "r1", "decision": "suspend_coach"},
                          now=NOW, suspend=boom, end_early=lambda s: None)
    assert db.docs["reports/r1"]["state"] == "submitted"


def test_a_report_is_decided_once():
    db = make_db()
    report(db, "r1")
    decide(db)
    stays(db, errors.REPORT_NOT_FOUND)


@pytest.mark.parametrize("rid", ["ghost", "post1"])
def test_a_missing_or_non_coaching_report_is_not_found(rid):
    db = make_db()
    report(db, "post1", "post", "posts/p1")
    stays(db, errors.REPORT_NOT_FOUND, reportId=rid)


def test_a_coaching_report_with_a_broken_ref_is_not_found():
    db = make_db()
    report(db, "r1", ref="users/client1")
    stays(db, errors.REPORT_NOT_FOUND)


@pytest.mark.parametrize(
    "over",
    [{"decision": "ban"}, {"decision": None}, {"note": "x" * 501}, {"note": 5}, {"reportId": ""}, {"reportId": "a/b"}, {"reportId": None}],
)
def test_bad_input_is_refused(over):
    db = make_db()
    report(db, "r1")
    stays(db, errors.BAD_REQUEST, **over)
    assert logs(db) == []


def test_a_note_of_500_is_fine():
    db = make_db()
    report(db, "r1")
    decide(db, note="x" * 500)
    assert db.docs["reports/r1"]["state"] == "decided"


def test_a_report_decided_meanwhile_is_not_decided_twice():
    db = make_db()
    report(db, "r1")

    def other_reviewer_wins(uid):
        db.document("reports/r1").update({"state": "decided", "decision": "dismiss"})

    with pytest.raises(errors.CoachingError) as caught:
        moderation.decide(db, "staff1", {"reportId": "r1", "decision": "suspend_coach"},
                          now=NOW, suspend=other_reviewer_wins, end_early=lambda s: None)
    assert caught.value.reason == errors.REPORT_NOT_FOUND
    assert db.docs["reports/r1"]["decision"] == "dismiss"


# ---------------------------------------- a stranger's chat or plan is not shown


def test_a_message_is_shown_only_when_the_reporter_belongs_to_the_relationship():
    db = make_db()
    report(db, "r1", reporterUid="stranger")
    report(db, "r2", reporterUid="coach1", minutes=1)
    report(db, "r3", reporterUid="client1", minutes=2)
    items = {i["reportId"]: i["subject"] for i in listing(db)["items"]}
    assert items["r1"] == {"notParty": True}
    assert items["r2"]["text"] == "pay me on instapay" and items["r3"]["text"] == "pay me on instapay"


def test_a_plan_is_shown_to_its_client_or_its_coach_only():
    db = make_db()
    ref = "plans/client1/coachPlans/p1"
    report(db, "r1", "coachPlan", ref, reporterUid="stranger")
    report(db, "r2", "coachPlan", ref, reporterUid="client1", minutes=1)
    report(db, "r3", "coachPlan", ref, reporterUid="coach1", minutes=2)
    items = {i["reportId"]: i["subject"] for i in listing(db)["items"]}
    assert items["r1"] == {"notParty": True}
    assert items["r2"] == {"name": "Phase one", "kind": "workout"} == items["r3"]


def test_a_published_coach_page_is_shown_whoever_reported_it():
    db = make_db()
    report(db, "r1", "coachProfile", "coaches/coach1", reporterUid="stranger")
    assert listing(db)["items"][0]["subject"] == {"displayName": "Coach One", "headline": "Strength"}


# ---------------------------------------- staff never decide a case about themselves


@pytest.mark.parametrize(
    "actor,extra",
    [
        ("client1", {}),                                 # the reporter
        ("coach1", {}),                                  # the reported subject
        ("someone", {"subjectUid": "someone"}),          # the uid the report names
        ("coach1", {"subjectUid": "other"}),             # the coach who wrote the message, whatever the report says
    ],
)
def test_staff_never_decide_a_report_they_made_or_are_about(actor, extra):
    db = make_db()
    report(db, "r1", **extra)
    stays(db, errors.STAFF_IS_SUBJECT, actor=actor, decision="suspend_coach")


def test_the_coach_of_a_reported_profile_cannot_dismiss_it():
    db = make_db()
    report(db, "r1", "coachProfile", "coaches/coach1", subjectUid="other")
    stays(db, errors.STAFF_IS_SUBJECT, actor="coach1")


def _count_reads(monkeypatch):
    reads = []
    real = fake_firestore.DocumentRef.get

    def counting(self, transaction=None):
        reads.append(self.path)
        return real(self, transaction)

    monkeypatch.setattr(fake_firestore.DocumentRef, "get", counting)
    return reads


def test_a_plan_is_read_once_to_show_it(monkeypatch):
    db = make_db()
    report(db, "r1", "coachPlan", "plans/client1/coachPlans/p1")
    reads = _count_reads(monkeypatch)
    listing(db)
    assert reads.count("plans/client1/coachPlans/p1") == 1


@pytest.mark.parametrize(
    "decision,subject",
    [("suspend_coach", "coachPlan"), ("end_coaching", "coachPlan"), ("suspend_coach", "coachMessage")],
)
def test_the_subject_is_read_once_to_decide(monkeypatch, decision, subject):
    db = make_db()
    ref = {"coachPlan": "plans/client1/coachPlans/p1", "coachMessage": MSG}[subject]
    report(db, "r1", subject, ref)
    reads = _count_reads(monkeypatch)
    decide(db, decision=decision)
    assert reads.count(ref) == 1
