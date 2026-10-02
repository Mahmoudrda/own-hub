"""S3, S7, S8: request_review, one open flag per uid, the reviewer callables."""

from __future__ import annotations

import datetime as dt

import pytest

from identity import config, decisions, reasons, review
from tests.fake_review_store import FakeReviewStore

ALLOWED_FLAG_KEYS = review.FLAG_FIELDS | {"jobId", "createdAt"}
NOW = dt.datetime(2026, 10, 2, 12, tzinfo=dt.timezone.utc)


@pytest.mark.parametrize(
    "path,code",
    [
        ("niqab", reasons.NIQAB_PATH_REQUESTED),
        ("declined", reasons.CAMERA_DECLINED),
        ("error", reasons.REVIEW_REQUESTED_AFTER_ERROR),
    ],
)
def test_each_path_writes_its_code_and_nothing_personal(path, code):
    fake = FakeReviewStore()
    result = review.request(fake, "her", path)

    assert result.state == review.STATE_PENDING and result.created
    flag = fake.flags[result.flag_id]
    assert flag["flags"] == [code] and flag["reasons"] == [code]
    assert set(flag) <= ALLOWED_FLAG_KEYS, set(flag) - ALLOWED_FLAG_KEYS
    for banned in ("phone", "phoneNumber", "image", "frames", "front", "back", "nid"):
        assert banned not in flag
    assert flag["id_hmac"] is None
    assert flag["requestedWomanReviewer"] is (path == "niqab")
    assert fake.jobs[result.flag_id]["state"] == decisions.PENDING_REVIEW
    assert fake.states["her"]["state"] == review.STATE_PENDING
    assert fake.notified == [(result.flag_id, (code,))]


def test_a_bad_path_is_refused():
    with pytest.raises(review.ReviewError) as caught:
        review.request(FakeReviewStore(), "her", "gym")
    assert caught.value.kind == review.INVALID


def test_one_open_flag_per_account():
    fake = FakeReviewStore()
    first = review.request(fake, "her", "niqab")
    second = review.request(fake, "her", "error")
    assert second.flag_id == first.flag_id and not second.created
    assert len(fake.flags) == 1
    assert len(fake.notified) == 1


def test_a_rejected_account_is_closed():
    fake = FakeReviewStore()
    fake.set_verification_state("her", review.STATE_REJECTED)
    with pytest.raises(review.ReviewError) as caught:
        review.request(fake, "her", "niqab")
    assert caught.value.kind == review.PRECONDITION
    assert caught.value.reason == reasons.VERIFICATION_CLOSED
    assert not fake.flags


def test_an_approved_account_is_told_so_and_nothing_is_written():
    fake = FakeReviewStore()
    fake.set_verification_state("her", review.STATE_APPROVED)
    assert review.request(fake, "her", "niqab").state == review.STATE_APPROVED
    assert not fake.flags


def test_the_daily_cap_on_review_requests():
    fake = FakeReviewStore()
    for _ in range(config.PER_UID_DAILY_REVIEW_LIMIT):
        review.request(fake, "her", "niqab")
    with pytest.raises(review.ReviewError) as caught:
        review.request(fake, "her", "niqab")
    assert caught.value.kind == review.EXHAUSTED
    assert caught.value.reason == reasons.PER_UID_DAILY_LIMIT


# ------------------------------------------------------------ the reviewer


def _open(fake, uid="her", path="niqab"):
    return review.request(fake, uid, path).flag_id


def test_contact_returns_her_phone_and_logs_the_lookup():
    fake = FakeReviewStore()
    flag_id = _open(fake)
    assert review.contact(fake, "rev", flag_id) == {"phone": "+201005550132"}
    assert ("rev", flag_id, "contact") in fake.access
    assert "phone" not in fake.flags[flag_id]


def test_contact_is_refused_to_the_subject_and_on_a_closed_flag():
    fake = FakeReviewStore()
    flag_id = _open(fake)
    with pytest.raises(review.ReviewError) as caught:
        review.contact(fake, "her", flag_id)
    assert caught.value.reason == reasons.REVIEWER_IS_SUBJECT
    fake.flags[flag_id]["state"] = decisions.APPROVED
    with pytest.raises(review.ReviewError) as caught:
        review.contact(fake, "rev", flag_id)
    assert caught.value.reason == reasons.REVIEW_NOT_PENDING
    with pytest.raises(review.ReviewError) as caught:
        review.contact(fake, "rev", "nope")
    assert caught.value.kind == review.NOT_FOUND


def test_schedule_parses_the_time_and_tells_her():
    fake = FakeReviewStore()
    flag_id = _open(fake)
    review.schedule(fake, "rev", flag_id, "video", "2026-10-05T10:00:00+02:00")
    when = dt.datetime(2026, 10, 5, 8, tzinfo=dt.timezone.utc)
    assert fake.flags[flag_id]["scheduledFor"] == when
    assert fake.states["her"]["reviewRoute"] == "video"
    assert fake.states["her"]["reviewScheduledFor"] == when
    assert fake.states["her"]["state"] == review.STATE_PENDING
    assert ("rev", flag_id, "schedule:video") in fake.access


@pytest.mark.parametrize("bad", ["", "tomorrow", "2026-10-05T10:00:00", None, 5])
def test_schedule_refuses_a_time_without_an_offset(bad):
    fake = FakeReviewStore()
    flag_id = _open(fake)
    with pytest.raises(review.ReviewError) as caught:
        review.schedule(fake, "rev", flag_id, "video", bad)
    assert caught.value.kind == review.INVALID


def test_schedule_refuses_the_subject_and_a_decided_flag():
    fake = FakeReviewStore()
    flag_id = _open(fake)
    with pytest.raises(review.ReviewError):
        review.schedule(fake, "her", flag_id, "video", "2026-10-05T10:00:00+02:00")
    fake.flags[flag_id]["state"] = decisions.RETRY_REQUIRED
    with pytest.raises(review.ReviewError) as caught:
        review.schedule(fake, "rev", flag_id, "video", "2026-10-05T10:00:00+02:00")
    assert caught.value.reason == reasons.REVIEW_NOT_PENDING


def test_a_reviewer_reject_closes_her_account_and_the_flag():
    fake = FakeReviewStore()
    flag_id = _open(fake)
    review.schedule(fake, "rev", flag_id, "video", "2026-10-05T10:00:00+02:00")
    result = review.decide(fake, "rev", flag_id, False)
    assert result.outcome == "rejected"
    assert fake.states["her"]["state"] == review.STATE_REJECTED
    assert fake.flags[flag_id]["state"] == decisions.REJECTED_FAILED
    assert fake.jobs[flag_id]["state"] == decisions.REJECTED_FAILED
    assert fake.open_flag_id("her") is None
    assert fake.minted == []
    assert ("rev", flag_id, "decide") in fake.access


def test_list_carries_no_phone_and_no_hash():
    fake = FakeReviewStore()
    _open(fake)
    rows = review.list_open(fake, "rev")
    assert len(rows) == 1
    assert "phone" not in rows[0] and "id_hmac" not in rows[0]
    assert rows[0]["needsNidOnCall"] is True
    assert ("rev", "*", "list") in fake.access
