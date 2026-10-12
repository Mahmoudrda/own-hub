"""request_review while verify_identity is still running, and the commit that
never turns an approval back.

C12 offers "Ask for a woman reviewer" once the check has run longer than
usual. The automatic check may still be deciding at that moment, so the server
refuses the request (VERIFICATION_IN_PROGRESS) until it has answered, and the
check's own writes leave an `approved` state alone.
"""

from __future__ import annotations

import datetime as dt

import pytest
from firebase_functions import https_fn

import main
from identity import config, decisions, reasons, review, store
from identity.store import clear_verify_in_flight as REAL_CLEAR
from identity.store import mark_verify_in_flight as REAL_MARK
from tests import fake_firestore
from tests import test_pipeline as tp
from tests.fake_review_store import FakeReviewStore
from tests.test_entrypoints import body, inner, raises, request, stubbed  # noqa: F401
from tests.test_verify_gate import writes  # noqa: F401

NOW = dt.datetime(2026, 10, 6, 12, tzinfo=dt.timezone.utc)


# ------------------------------------------------------------- review.request


def test_a_request_during_a_running_check_is_refused_and_costs_nothing():
    fake = FakeReviewStore()
    fake.verifying.add("her")
    with pytest.raises(review.ReviewError) as caught:
        review.request(fake, "her", "error")
    assert caught.value.kind == review.PRECONDITION
    assert caught.value.reason == reasons.VERIFICATION_IN_PROGRESS
    assert fake.flags == {}
    assert fake.daily == {}
    assert fake.review_consents == {}
    assert fake.verification_state("her") is None


def test_the_same_request_opens_a_review_once_the_check_has_answered():
    fake = FakeReviewStore()
    fake.verifying.add("her")
    with pytest.raises(review.ReviewError):
        review.request(fake, "her", "error")
    fake.verifying.discard("her")
    result = review.request(fake, "her", "error")
    assert result.state == review.STATE_PENDING and result.created


def test_an_approved_account_is_answered_approved_even_mid_check():
    fake = FakeReviewStore()
    fake.set_verification_state("her", review.STATE_APPROVED)
    fake.verifying.add("her")
    assert review.request(fake, "her", "error").state == review.STATE_APPROVED


def test_the_refusal_is_a_contract_reason():
    import json
    import pathlib

    contract = json.loads(
        (pathlib.Path(__file__).resolve().parents[2] / "contracts" / "identity_contract.json").read_text()
    )
    assert reasons.VERIFICATION_IN_PROGRESS in contract["errorReasons"].values()


# ------------------------------------------------------------- the store


@pytest.fixture
def fs(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    monkeypatch.setattr(store.firestore, "transactional", fake_firestore.transactional)
    monkeypatch.setattr(store, "mark_verify_in_flight", REAL_MARK)
    monkeypatch.setattr(store, "clear_verify_in_flight", REAL_CLEAR)
    return db


def test_the_marker_holds_until_cleared(fs):
    assert store.verify_in_flight("her", now=NOW) is False
    store.mark_verify_in_flight("her", now=NOW)
    assert store.verify_in_flight("her", now=NOW + dt.timedelta(seconds=30)) is True
    store.clear_verify_in_flight("her")
    assert store.verify_in_flight("her", now=NOW) is False


def test_the_review_store_reads_the_same_marker(fs):
    store.mark_verify_in_flight("her")
    assert store.FirestoreReviewStore().verify_in_flight("her") is True
    store.clear_verify_in_flight("her")
    assert store.verify_in_flight("her", now=NOW) is False


def test_a_marker_left_by_a_killed_call_expires(fs):
    store.mark_verify_in_flight("her", now=NOW)
    later = NOW + dt.timedelta(seconds=config.VERIFY_IN_FLIGHT_SEC + 1)
    assert store.verify_in_flight("her", now=later) is False
    assert config.VERIFY_IN_FLIGHT_SEC > config.TIMEOUT_SEC


def test_the_marker_lives_on_the_ledger_beside_her_open_flag(fs):
    fs.collection(config.COL_LEDGER).document("her").set({"openFlagId": "f1"})
    store.mark_verify_in_flight("her", now=NOW)
    store.clear_verify_in_flight("her")
    ledger = fs.docs[f"{config.COL_LEDGER}/her"]
    assert ledger["openFlagId"] == "f1"
    assert ledger[store.VERIFY_IN_FLIGHT_FIELD] is None


@pytest.mark.parametrize("state", [review.STATE_PENDING, review.STATE_REJECTED])
def test_keep_approved_never_turns_an_approval_back(fs, state):
    store.set_verification_state("her", review.STATE_APPROVED, decided=True)
    wrote = store.set_verification_state("her", state, keep_approved=True)
    assert wrote is False
    assert fs.docs[f"{config.COL_USERS}/her"]["verification"]["state"] == "approved"


def test_keep_approved_still_writes_over_anything_else(fs):
    store.set_verification_state("her", review.STATE_RETRY)
    assert store.set_verification_state(
        "her", review.STATE_PENDING, keep_approved=True
    )
    assert fs.docs[f"{config.COL_USERS}/her"]["verification"]["state"] == "pending"


# ------------------------------------------------------------- verify_identity


@pytest.fixture
def marks(monkeypatch):
    log = []
    monkeypatch.setattr(store, "mark_verify_in_flight", lambda uid, now=None: log.append(("mark", uid)))
    monkeypatch.setattr(store, "clear_verify_in_flight", lambda uid: log.append(("clear", uid)))
    return log


def _verify(session):
    return inner("verify_identity")(request(body(liveness={"sessionId": session})))


def test_verify_marks_itself_in_flight_and_clears_when_done(monkeypatch, writes, marks):
    deps, session = tp.build()
    monkeypatch.setattr(main, "_deps", lambda: deps)
    seen = {}
    real_run = main.pipeline.run

    def spy(inputs, d):
        seen["during"] = list(marks)
        return real_run(inputs, d)

    monkeypatch.setattr(main.pipeline, "run", spy)
    assert _verify(session)["outcome"] == decisions.APPROVED
    assert seen["during"] == [("mark", "uid-1")]
    assert marks == [("mark", "uid-1"), ("clear", "uid-1")]


def test_a_check_that_crashes_still_clears_its_marker(monkeypatch, writes, marks):
    deps, session = tp.build()
    monkeypatch.setattr(main, "_deps", lambda: deps)

    def boom(inputs, d):
        raise RuntimeError("provider fell over")

    monkeypatch.setattr(main.pipeline, "run", boom)
    with pytest.raises(RuntimeError):
        _verify(session)
    assert marks == [("mark", "uid-1"), ("clear", "uid-1")]


def test_a_marker_that_cannot_be_written_does_not_stop_her_check(monkeypatch, writes):
    def down(uid, now=None):
        raise OSError("firestore unavailable")

    monkeypatch.setattr(store, "mark_verify_in_flight", down)
    monkeypatch.setattr(store, "clear_verify_in_flight", lambda uid: down(uid))
    deps, session = tp.build()
    monkeypatch.setattr(main, "_deps", lambda: deps)
    assert _verify(session)["outcome"] == decisions.APPROVED


def test_the_checks_own_review_and_rejection_keep_an_approval(monkeypatch, writes):
    calls = []
    monkeypatch.setattr(
        main.store,
        "set_verification_state",
        lambda uid, state, **kw: calls.append((state, kw.get("keep_approved"))),
    )
    deps, session = tp.build(number=tp.MALE, word="ذكر")
    monkeypatch.setattr(main, "_deps", lambda: deps)
    _verify(session)
    assert calls == [(review.STATE_REJECTED, True)]

    calls.clear()
    main._raise_flag(
        "uid-1",
        decisions.Decision(
            decisions.PENDING_REVIEW, (reasons.LIVENESS_FAILED,), (reasons.LIVENESS_FAILED,)
        ),
        type(
            "O",
            (),
            {
                "spent_micro_usd": 0,
                "provider_ids": None,
                "id_hmac": None,
                "liveness_confidence": None,
                "match_similarity": None,
            },
        )(),
        0,
    )
    assert calls == [(review.STATE_PENDING, True)]


def test_request_review_callable_says_in_progress(monkeypatch, stubbed):
    fake = FakeReviewStore()
    fake.verifying.add("uid-1")
    monkeypatch.setattr(main.store, "FirestoreReviewStore", lambda: fake)
    error = raises(
        lambda: inner("request_review")(request({"path": "error"})),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert error.message == reasons.VERIFICATION_IN_PROGRESS
