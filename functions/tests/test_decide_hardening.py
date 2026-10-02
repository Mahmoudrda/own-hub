"""S19: decide_verification_flag refuses what it must, and the NID typed on the
live call is hashed and dropped, never stored or logged."""

from __future__ import annotations

import datetime as dt
import importlib.machinery
import importlib.util
import logging
import os

import pytest

from identity import decisions, dedupe, reasons, review
from tests.fake_review_store import FakeReviewStore

TODAY = dt.date(2026, 10, 2)
# Synthetic numbers, never real ones. 13th digit even = female, odd = male.
FEMALE_ADULT = "29901012345628"
MALE_ADULT = "29001019876513"
FEMALE_MINOR = "31001012345628"  # born 2010

_SCAN_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "scripts",
    "privacy_scan",
)
_loader = importlib.machinery.SourceFileLoader("privacy_scan_for_decide", _SCAN_PATH)
_spec = importlib.util.spec_from_loader("privacy_scan_for_decide", _loader)
privacy_scan = importlib.util.module_from_spec(_spec)
_loader.exec_module(privacy_scan)


def _booked(fake, uid="her", path="niqab", id_hmac=None):
    flag_id = review.request(fake, uid, path).flag_id
    if id_hmac:
        fake.flags[flag_id]["id_hmac"] = id_hmac
    review.schedule(fake, "rev", flag_id, "video", "2026-10-05T10:00:00+02:00")
    return flag_id


def _refused(fn, reason=None):
    with pytest.raises(review.ReviewError) as caught:
        fn()
    assert caught.value.kind == review.PRECONDITION
    if reason:
        assert caught.value.reason == reason
    return caught.value


# --------------------------------------------------------- the four refusals


def test_refused_when_not_pending():
    fake = FakeReviewStore()
    flag_id = _booked(fake, id_hmac="h1")
    fake.flags[flag_id]["state"] = decisions.RETRY_REQUIRED
    _refused(lambda: review.decide(fake, "rev", flag_id, True), reasons.REVIEW_NOT_PENDING)
    assert fake.minted == []


def test_refused_when_the_reviewer_is_the_subject():
    fake = FakeReviewStore()
    flag_id = _booked(fake, id_hmac="h1")
    _refused(lambda: review.decide(fake, "her", flag_id, True), reasons.REVIEWER_IS_SUBJECT)
    assert fake.minted == []


def test_refused_without_a_booked_live_review():
    fake = FakeReviewStore()
    flag_id = review.request(fake, "her", "niqab").flag_id
    fake.flags[flag_id]["id_hmac"] = "h1"
    _refused(lambda: review.decide(fake, "rev", flag_id, True))
    assert fake.minted == []


def test_a_failed_registry_claim_mints_nothing():
    fake = FakeReviewStore()
    fake.registry["h1"] = dedupe.RegistryEntry("someone-else", dedupe.STATE_ACTIVE, 1)
    flag_id = _booked(fake, id_hmac="h1")
    _refused(lambda: review.decide(fake, "rev", flag_id, True), reasons.DUPLICATE_ID)
    assert fake.minted == []
    assert fake.flags[flag_id]["state"] == decisions.PENDING_REVIEW
    assert fake.states["her"]["state"] == review.STATE_PENDING


def test_a_closed_registration_mints_nothing():
    fake = FakeReviewStore()
    fake.registry["h1"] = dedupe.RegistryEntry(None, dedupe.STATE_CLOSED, 1)
    flag_id = _booked(fake, id_hmac="h1")
    _refused(lambda: review.decide(fake, "rev", flag_id, True), reasons.REGISTRATION_CLOSED)
    assert fake.minted == []


def test_approval_with_a_hash_claims_then_mints():
    fake = FakeReviewStore()
    flag_id = _booked(fake, id_hmac="h1")
    result = review.decide(fake, "rev", flag_id, True)
    assert result.outcome == decisions.APPROVED
    assert fake.registry["h1"].uid == "her"
    assert fake.minted == ["her"]
    assert fake.states["her"]["state"] == review.STATE_APPROVED
    assert fake.flags[flag_id]["state"] == decisions.APPROVED
    assert fake.open_flag_id("her") is None


# ------------------------------------------------------- the NID on the call


def test_a_niqab_flag_needs_the_nid_to_approve():
    fake = FakeReviewStore()
    flag_id = _booked(fake)
    _refused(lambda: review.decide(fake, "rev", flag_id, True))
    assert fake.minted == []


def test_the_nid_path_approves_a_female_adult_and_stores_only_the_hash():
    fake = FakeReviewStore()
    flag_id = _booked(fake)
    review.decide(fake, "rev", flag_id, True, FEMALE_ADULT, today=TODAY)
    expected = dedupe.hash_and_forget(FEMALE_ADULT, fake.pepper())
    assert list(fake.registry) == [expected]
    assert fake.minted == ["her"]
    assert FEMALE_ADULT not in repr(fake.__dict__)


@pytest.mark.parametrize(
    "digits,reason",
    [
        (MALE_ADULT, reasons.SEX_DIGIT_MALE),
        (FEMALE_MINOR, reasons.UNDERAGE),
        ("1234", None),
        ("not digits", None),
    ],
)
def test_the_nid_path_refuses_male_underage_and_garbage(digits, reason):
    fake = FakeReviewStore()
    flag_id = _booked(fake)
    error = _refused(
        lambda: review.decide(fake, "rev", flag_id, True, digits, today=TODAY), reason
    )
    assert digits not in str(error)
    assert fake.minted == [] and not fake.registry


def test_the_digits_never_reach_a_log_or_stdout(caplog, capsys):
    caplog.set_level(logging.DEBUG)
    fake = FakeReviewStore()
    for digits in (FEMALE_ADULT, MALE_ADULT):
        flag_id = _booked(fake, uid=f"u-{digits[-3:]}")
        try:
            review.decide(fake, "rev", flag_id, True, digits, today=TODAY)
        except review.ReviewError:
            pass
    captured = capsys.readouterr()
    text = caplog.text + captured.out + captured.err + repr(fake.__dict__)
    assert not privacy_scan.ASCII_14.search(text)


# ----------------------------------------------- the callable wrapper too


def test_the_callable_message_is_a_code_never_the_digits(monkeypatch):
    import main
    from firebase_functions import https_fn
    from tests.test_entrypoints import inner, request

    fake = FakeReviewStore()
    flag_id = _booked(fake)
    monkeypatch.setattr(main.store, "FirestoreReviewStore", lambda: fake)
    with pytest.raises(https_fn.HttpsError) as caught:
        inner("decide_verification_flag")(
            request(
                {"flagId": flag_id, "approve": True, "nid": MALE_ADULT},
                uid="rev",
                token={"womanReviewer": True},
            )
        )
    assert caught.value.code == https_fn.FunctionsErrorCode.FAILED_PRECONDITION
    assert caught.value.message == reasons.SEX_DIGIT_MALE
    assert MALE_ADULT not in str(caught.value)


# ------------------------------------------------ N11: approve must be a bool


@pytest.mark.parametrize("approve", ["false", "true", 1, 0, None, [], {"x": 1}])
def test_approve_that_is_not_a_bool_is_refused(approve, monkeypatch):
    import main
    from firebase_functions import https_fn
    from tests.test_entrypoints import inner, request

    fake = FakeReviewStore()
    flag_id = _booked(fake, id_hmac="h1")
    monkeypatch.setattr(main.store, "FirestoreReviewStore", lambda: fake)
    with pytest.raises(https_fn.HttpsError) as caught:
        inner("decide_verification_flag")(
            request({"flagId": flag_id, "approve": approve}, uid="rev",
                    token={"womanReviewer": True})
        )
    assert caught.value.code == https_fn.FunctionsErrorCode.INVALID_ARGUMENT
    assert caught.value.message == reasons.INTERNAL_ERROR
    assert fake.minted == []
    assert fake.flags[flag_id]["state"] == decisions.PENDING_REVIEW


def test_missing_approve_is_refused_too(monkeypatch):
    import main
    from firebase_functions import https_fn
    from tests.test_entrypoints import inner, request

    fake = FakeReviewStore()
    flag_id = _booked(fake, id_hmac="h1")
    monkeypatch.setattr(main.store, "FirestoreReviewStore", lambda: fake)
    with pytest.raises(https_fn.HttpsError) as caught:
        inner("decide_verification_flag")(
            request({"flagId": flag_id}, uid="rev", token={"womanReviewer": True})
        )
    assert caught.value.code == https_fn.FunctionsErrorCode.INVALID_ARGUMENT
