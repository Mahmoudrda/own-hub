"""The owner's console callables: admin_dashboard and admin_logs.

Three promises, each held here:

  * only an admin, signed in by phone, behind App Check, gets an answer;
  * nothing in an answer names a person: no uid, phone, name, flag or job id,
    national ID or health field, at any depth;
  * every read leaves a line in adminAccessLog, and a read that cannot be
    recorded is refused rather than served.
"""

from __future__ import annotations

import datetime as dt
import re

import pytest
from firebase_functions import https_fn

import main
from console import access, dashboard, oplog
from identity import decisions, reasons
from tests.fake_firestore import FakeFirestore
from tests.test_entrypoints import inner, raises, request

NOW = dt.datetime(2026, 10, 7, 12, tzinfo=dt.timezone.utc)

HER_UID = "uHerAccount0001"
OTHER_UID = "uOtherAccount002"
PHONE = "+201001234567"
FLAG_ID = "flagDocId0001"
JOB_ID = "jobDocId0002"

ADMIN = {"admin": True}


def _seed(db: FakeFirestore) -> None:
    def put(path, data):
        db.docs[path] = data

    put(f"users/{HER_UID}", {"firstName": "Mona", "verification": {"state": "approved"}})
    put(f"users/{OTHER_UID}", {"firstName": "Salma", "verification": {"state": "pending"}})
    put(
        f"verification_flags/{FLAG_ID}",
        {
            "uid": OTHER_UID,
            "state": decisions.PENDING_REVIEW,
            "createdAt": NOW - dt.timedelta(hours=80),
            "slaExpiresAt": NOW - dt.timedelta(hours=8),
            "reasons": [sorted(reasons.ALL)[0]],
            "id_hmac": "f" * 64,
        },
    )
    put(
        f"verificationJobs/{JOB_ID}",
        {
            "uid": HER_UID,
            "state": decisions.APPROVED,
            "reasons": [sorted(reasons.ALL)[0], "made_up_free_text"],
            "decidedAt": NOW - dt.timedelta(days=2),
            "spent_micro_usd": 1500,
        },
    )
    put(
        "verificationJobs/jobOld",
        {
            "uid": OTHER_UID,
            "state": decisions.REJECTED_NOT_ELIGIBLE,
            "reasons": [],
            "decidedAt": NOW - dt.timedelta(days=20),
        },
    )
    put(
        "verificationReviewAccess/a1",
        {
            "flagId": FLAG_ID,
            "reviewerUid": "uReviewer0003",
            "action": "schedule:video",
            "at": NOW - dt.timedelta(hours=1),
        },
    )
    put(
        f"deletionRequests/{HER_UID}",
        {
            "state": "done",
            "requestedAt": NOW - dt.timedelta(days=1),
            "updatedAt": NOW - dt.timedelta(days=1),
            "doneAt": NOW - dt.timedelta(days=1),
        },
    )
    put(
        f"deletionRequests/{OTHER_UID}",
        {"state": "purgingStorage", "updatedAt": NOW - dt.timedelta(minutes=3)},
    )
    put("waitlist/w1", {"contact": PHONE, "at": NOW - dt.timedelta(hours=2)})
    put("waitlist/w2", {"contact": "she@example.com", "at": NOW - dt.timedelta(days=3)})
    put(
        "events/e1",
        {"status": "published", "endsAt": NOW + dt.timedelta(days=4)},
    )
    put("events/e2", {"status": "published", "endsAt": NOW - dt.timedelta(days=4)})
    put("events/e3", {"status": "draft", "endsAt": NOW + dt.timedelta(days=9)})
    put("recipes/r1", {"titleEn": "Lazy Cake"})
    put("exercises/x1", {"name_en": "Glute bridge"})
    put(
        "opsErrors/2026-10-06",
        {"day": "2026-10-06", "counts": {"account_deletion_failed": 2, "Bad Text 12345678": 1}},
    )


@pytest.fixture
def db(monkeypatch):
    fake = FakeFirestore()
    _seed(fake)
    monkeypatch.setattr(main.store, "db", lambda: fake)
    dashboard.clear_cache()
    yield fake
    dashboard.clear_cache()


# ---------------------------------------------------------------- the guards


@pytest.mark.parametrize("name", ["admin_dashboard", "admin_logs"])
def test_an_ordinary_account_is_refused(name, db):
    raises(
        lambda: inner(name)(request({"kind": "decisions"}, uid=HER_UID)),
        https_fn.FunctionsErrorCode.PERMISSION_DENIED,
    )
    assert not _access_lines(db)


@pytest.mark.parametrize("name", ["admin_dashboard", "admin_logs"])
def test_a_woman_reviewer_is_not_an_admin(name, db):
    raises(
        lambda: inner(name)(
            request({"kind": "decisions"}, token={"womanReviewer": True})
        ),
        https_fn.FunctionsErrorCode.PERMISSION_DENIED,
    )


@pytest.mark.parametrize("name", ["admin_dashboard", "admin_logs"])
def test_an_admin_signed_in_with_a_password_is_refused(name, db):
    token = {**ADMIN, "firebase": {"sign_in_provider": "password"}}
    error = raises(
        lambda: inner(name)(request({"kind": "decisions"}, token=token)),
        https_fn.FunctionsErrorCode.PERMISSION_DENIED,
    )
    assert error.message == reasons.PHONE_SIGN_IN_REQUIRED


@pytest.mark.parametrize("name", ["admin_dashboard", "admin_logs"])
def test_no_app_check_no_answer(name, db):
    raises(
        lambda: inner(name)(request({"kind": "decisions"}, token=ADMIN, app=False)),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert not _access_lines(db)


def test_a_claim_in_the_body_is_not_a_claim(db):
    raises(
        lambda: inner("admin_dashboard")(request({"admin": True})),
        https_fn.FunctionsErrorCode.PERMISSION_DENIED,
    )


# ------------------------------------------------------------- the dashboard


def test_the_dashboard_counts(db):
    answer = dashboard.build(db, NOW)
    assert answer["members"] == {"total": 2, "verified": 1}
    assert answer["reviews"]["pending"] == 1
    assert answer["reviews"]["overSla"] == 1
    assert answer["reviews"]["oldestHours"] == 80
    assert answer["reviews"]["slaHours"] == 72
    assert answer["outcomes"]["7"][decisions.APPROVED] == 1
    assert answer["outcomes"]["7"][decisions.REJECTED_NOT_ELIGIBLE] == 0
    assert answer["outcomes"]["30"][decisions.REJECTED_NOT_ELIGIBLE] == 1
    assert set(answer["outcomes"]["30"]) == set(decisions.OUTCOMES)
    assert answer["waitlist"] == {"total": 2}
    assert answer["deletions"] == {"pending": 1, "done": 1}
    assert answer["events"] == {"upcoming": 1, "drafts": 1}
    assert answer["content"] == {"exercises": 1, "foods": 0, "recipes": 1, "programs": 0}


def test_the_dashboard_callable_answers_an_admin_and_records_the_read(db):
    answer = inner("admin_dashboard")(request({}, uid="uOwner", token=ADMIN))
    assert answer["members"]["total"] == 2
    lines = _access_lines(db)
    assert len(lines) == 1
    assert lines[0]["action"] == "dashboard"
    assert lines[0]["admin"] == access.short_ref("uOwner")
    assert "uOwner" not in repr(lines[0])
    assert lines[0]["expireAt"] - lines[0]["at"] == dt.timedelta(days=365)


def test_the_dashboard_is_cached_and_refresh_skips_the_cache(db):
    first = dashboard.cached(db, NOW, clock=lambda: 1000.0)
    db.docs["users/uNew"] = {"verification": {"state": "approved"}}
    assert dashboard.cached(db, NOW, clock=lambda: 1100.0) is first
    fresh = dashboard.cached(db, NOW, refresh=True, clock=lambda: 1101.0)
    assert fresh["members"]["total"] == 3
    later = dashboard.cached(db, NOW, clock=lambda: 1101.0 + dashboard.CACHE_SECONDS)
    assert later is not fresh


def test_the_dashboard_names_nobody(db):
    answer = inner("admin_dashboard")(request({}, uid="uOwner", token=ADMIN))
    _assert_names_nobody(answer)


def test_an_unrecorded_read_is_refused(db, monkeypatch):
    def broken(*_args, **_kwargs):
        raise RuntimeError("firestore down")

    monkeypatch.setattr(access, "record", broken)
    raises(
        lambda: inner("admin_dashboard")(request({}, token=ADMIN)),
        https_fn.FunctionsErrorCode.UNAVAILABLE,
    )
    raises(
        lambda: inner("admin_logs")(request({"kind": "decisions"}, token=ADMIN)),
        https_fn.FunctionsErrorCode.UNAVAILABLE,
    )


# ------------------------------------------------------------------ the logs


@pytest.mark.parametrize("kind", oplog.KINDS)
def test_every_log_kind_names_nobody_and_is_recorded(kind, db):
    answer = inner("admin_logs")(request({"kind": kind}, uid="uOwner", token=ADMIN))
    assert answer["kind"] == kind
    _assert_names_nobody(answer)
    assert _access_lines(db)[-1]["action"] == f"logs.{kind}"


def test_decisions_carry_codes_and_a_case_ref_only(db):
    answer = oplog.page(db, {"kind": "decisions"}, NOW)
    first = answer["rows"][0]
    assert set(first) == {"at", "outcome", "reasons", "case"}
    assert first["outcome"] == decisions.APPROVED
    assert first["reasons"] == [sorted(reasons.ALL)[0]], "free text is dropped"
    assert first["case"] == access.short_ref(JOB_ID)
    assert len(first["case"]) == 8


def test_decisions_filter_by_outcome_and_page_by_time(db):
    only = oplog.page(db, {"kind": "decisions", "outcome": decisions.REJECTED_NOT_ELIGIBLE}, NOW)
    assert [r["outcome"] for r in only["rows"]] == [decisions.REJECTED_NOT_ELIGIBLE]

    one = oplog.page(db, {"kind": "decisions", "limit": 1}, NOW)
    assert one["rows"][0]["outcome"] == decisions.APPROVED
    assert one["next"] == one["rows"][0]["at"]
    two = oplog.page(db, {"kind": "decisions", "limit": 1, "before": one["next"]}, NOW)
    assert two["rows"][0]["outcome"] == decisions.REJECTED_NOT_ELIGIBLE


def test_the_review_log_reads_actions_and_refs(db):
    row = oplog.page(db, {"kind": "reviews"}, NOW)["rows"][0]
    assert row["action"] == "schedule"
    assert row["case"] == access.short_ref(FLAG_ID)
    assert row["reviewer"] == access.short_ref("uReviewer0003")


def test_the_deletion_log_carries_no_reference_at_all(db):
    rows = oplog.page(db, {"kind": "deletions"}, NOW)["rows"]
    assert {r["state"] for r in rows} == {"done", "purgingStorage"}
    for row in rows:
        assert set(row) == {"at", "state", "requestedAt", "doneAt", "swept"}


def test_the_waitlist_log_is_counts_per_day(db):
    rows = oplog.page(db, {"kind": "waitlist"}, NOW)["rows"]
    assert len(rows) == oplog.WAITLIST_DAYS
    assert rows[0] == {"day": "2026-10-07", "joined": 1}
    assert {"day": "2026-10-04", "joined": 1} in rows
    assert all(set(r) == {"day", "joined"} for r in rows)


def test_the_error_log_keeps_codes_and_drops_free_text(db):
    rows = oplog.page(db, {"kind": "errors"}, NOW)["rows"]
    assert rows == [{"day": "2026-10-06", "counts": {"account_deletion_failed": 2}}]


@pytest.mark.parametrize(
    "body",
    [
        {"kind": "users"},
        {"kind": "decisions", "before": "yesterday"},
        {"kind": "decisions", "limit": "all"},
        {"kind": "decisions", "outcome": "SOMETHING"},
        {"kind": "reviews", "outcome": decisions.APPROVED},
    ],
)
def test_a_bad_request_is_a_clean_invalid_argument(body, db):
    raises(
        lambda: inner("admin_logs")(request(body, token=ADMIN)),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )


def test_the_page_size_is_capped(db):
    for i in range(80):
        db.docs[f"verificationJobs/j{i:03d}"] = {
            "state": decisions.APPROVED,
            "reasons": [],
            "decidedAt": NOW - dt.timedelta(minutes=i + 1),
        }
    answer = oplog.page(db, {"kind": "decisions", "limit": 500}, NOW)
    assert len(answer["rows"]) == oplog.MAX_LIMIT


# ---------------------------------------------------- errors are counted


def test_a_function_error_is_counted_by_code_only(db):
    from identity import logs

    logs.error("account_deletion_failed", state="failedRetryable")
    today = dt.datetime.now(dt.timezone.utc).date().isoformat()
    counts = db.docs[f"opsErrors/{today}"]["counts"]
    assert counts["account_deletion_failed"] >= 1
    assert "failedRetryable" not in repr(db.docs[f"opsErrors/{today}"])


def test_free_text_is_never_counted_as_an_error_code(db):
    oplog.record_error(db, "Something with a phone +201001234567", now=NOW)
    assert "opsErrors/2026-10-07" not in db.docs


def test_counting_an_error_never_raises(monkeypatch):
    from identity import logs

    # conftest makes store.db raise; the error line must still be fine.
    logs.error("account_deletion_failed")


# ---------------------------------------------------------- the reference


def test_a_short_ref_is_stable_short_and_not_the_id():
    assert access.short_ref(JOB_ID) == access.short_ref(JOB_ID)
    assert access.short_ref(JOB_ID) != access.short_ref(FLAG_ID)
    assert len(access.short_ref(JOB_ID)) == 8
    assert JOB_ID not in access.short_ref(JOB_ID)
    assert access.short_ref(None) is None
    assert access.short_ref("") is None


def test_an_unknown_action_is_never_recorded():
    with pytest.raises(ValueError):
        access.entry("uOwner", "export_everyone", NOW)


# ------------------------------------------------------------------ helpers


def _access_lines(db):
    return [
        data for path, data in sorted(db.docs.items())
        if path.startswith(access.COLLECTION + "/")
    ]


_FORBIDDEN_KEYS = re.compile(
    r"uid|phone|name|nid|id_hmac|contact|email|flagId|jobId|birth|"
    r"weight|cycle|period|measurement|checkin",
    re.IGNORECASE,
)


def _walk(value, path="$"):
    if isinstance(value, dict):
        for key, inner_value in value.items():
            yield path, key, inner_value
            yield from _walk(inner_value, f"{path}.{key}")
    elif isinstance(value, list):
        for i, item in enumerate(value):
            yield from _walk(item, f"{path}[{i}]")


def _assert_names_nobody(answer):
    text = repr(answer)
    for secret in (HER_UID, OTHER_UID, PHONE, FLAG_ID, JOB_ID, "Mona", "Salma",
                   "she@example.com", "f" * 64, "uReviewer0003", "uOwner"):
        assert secret not in text, f"{secret} leaked into the answer"
    for path, key, _ in _walk(answer):
        assert not _FORBIDDEN_KEYS.search(str(key)), f"{path}.{key} is a personal field"
