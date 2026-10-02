"""R4: her phone reaches a reviewer only after she asked for the call.

A machine-raised flag (band score, first duplicate, exhausted REJECTED_FAILED)
has no review consent until she taps "Ask for the call", which calls
request_review against the open flag. get_review_contact refuses before that
with FAILED_PRECONDITION review_consent_missing, and the queue shows the
reviewer a plain consentGiven boolean for each flag.
"""

from __future__ import annotations

import pytest
from firebase_functions import https_fn

import main
from identity import config, decisions, reasons, review, store
from tests import fake_firestore
from tests.fake_review_store import FakeReviewStore
from tests.test_entrypoints import inner, request
from tests.test_review_queue_tool import Server, _run


def _machine_flag(fake, uid="her"):
    """What main._raise_flag does for a band score: a flag, state pending, and
    no review consent."""
    decision = decisions.Decision(
        decisions.PENDING_REVIEW, (reasons.MATCH_FLAG_BAND,), (reasons.MATCH_FLAG_BAND,)
    )
    flag_id, created = fake.open_flag(
        uid, {"uid": uid}, review.flag_payload(uid, None, decision, id_hmac="h1")
    )
    assert created
    fake.set_verification_state(uid, review.STATE_PENDING, reset_booking=True)
    return flag_id


def test_the_reason_code_exists():
    assert reasons.REVIEW_CONSENT_MISSING == "review_consent_missing"
    assert reasons.REVIEW_CONSENT_MISSING in reasons.ALL
    assert reasons.to_user_safe([reasons.REVIEW_CONSENT_MISSING]) == []


def test_contact_is_refused_without_her_review_consent():
    fake = FakeReviewStore()
    flag_id = _machine_flag(fake)
    looked_up = []
    fake.phone_for = lambda uid: looked_up.append(uid) or "+201005550132"
    with pytest.raises(review.ReviewError) as caught:
        review.contact(fake, "rev", flag_id)
    assert caught.value.kind == review.PRECONDITION
    assert caught.value.reason == reasons.REVIEW_CONSENT_MISSING
    assert looked_up == [], "her phone is never read without consent"


def test_asking_for_the_call_on_an_open_machine_flag_records_consent_only():
    fake = FakeReviewStore()
    flag_id = _machine_flag(fake)
    result = review.request(fake, "her", "error")
    assert result.state == review.STATE_PENDING
    assert result.flag_id == flag_id and result.created is False
    assert len(fake.flags) == 1, "no second flag"
    assert fake.review_consents == {"her": "error"}
    assert fake.notified == [], "the open flag was already announced"
    assert review.contact(fake, "rev", flag_id) == {"phone": "+201005550132"}


def test_the_queue_says_whether_consent_exists_and_nothing_more():
    fake = FakeReviewStore()
    machine = _machine_flag(fake, "a")
    asked = review.request(fake, "b", "niqab").flag_id
    rows = {row["flagId"]: row for row in review.list_open(fake, "rev")}
    assert rows[machine]["consentGiven"] is False
    assert rows[asked]["consentGiven"] is True
    for row in rows.values():
        assert "uid" not in row and "phone" not in row and "path" not in row


def test_the_callable_answers_failed_precondition(monkeypatch):
    fake = FakeReviewStore()
    flag_id = _machine_flag(fake)
    monkeypatch.setattr(main.store, "FirestoreReviewStore", lambda: fake)
    with pytest.raises(https_fn.HttpsError) as caught:
        inner("get_review_contact")(
            request({"flagId": flag_id}, uid="rev", token={"womanReviewer": True})
        )
    assert caught.value.code == https_fn.FunctionsErrorCode.FAILED_PRECONDITION
    assert caught.value.message == reasons.REVIEW_CONSENT_MISSING


def test_the_firestore_store_reads_the_consent_document(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    reviews = store.FirestoreReviewStore()
    assert reviews.review_consent_given(["her", "other"]) == set()
    store.write_review_consent("her", "niqab")
    assert reviews.review_consent_given(["her", "other"]) == {"her"}
    assert reviews.review_consent_given([]) == set()


def test_the_reviewer_tool_shows_consent_and_will_not_fetch_contact_without_it(
    monkeypatch,
):
    fake = FakeReviewStore()
    flag_id = _machine_flag(fake)
    server = Server(monkeypatch, fake)
    code, lines = _run(["list"], server)
    assert code == 0 and "consent=no" in lines[0]
    server.seen.clear()
    code, lines = _run(["contact", "--flag", flag_id], server)
    assert code == 1
    assert lines == [
        f"refused: {reasons.REVIEW_CONSENT_MISSING} (she has not asked for the call yet)"
    ]
    assert [url.rsplit("/", 1)[-1] for url, _ in server.seen] == [
        "list_verification_flags"
    ], "the tool checks the queue and never asks for her phone"
    review.request(fake, "her", "error")
    code, lines = _run(["contact", "--flag", flag_id], server)
    assert code == 0 and lines == ["+201005550132"]
