"""M13: store review accounts. Only uids or phone numbers on the owner's
Secret Manager lists are approved without the pipeline; every use is logged;
an empty or unreadable list lets nobody through."""

from __future__ import annotations

import pytest

import main
from identity import decisions, store
from tests.test_entrypoints import body, inner, request, stubbed  # noqa: F401


@pytest.fixture
def recorded(monkeypatch, stubbed):
    log = {"minted": [], "verification": [], "access": [], "warn": []}
    monkeypatch.setattr(main.store, "mint_claims", lambda uid, v: log["minted"].append(uid))
    monkeypatch.setattr(
        main.store, "write_user_verification", lambda uid: log["verification"].append(uid)
    )

    class _Review:
        def log_access(self, reviewer_uid, flag_id, action):
            log["access"].append((reviewer_uid, flag_id, action))

    monkeypatch.setattr(main.store, "FirestoreReviewStore", _Review)
    monkeypatch.setattr(main.logs, "warn", lambda event, **f: log["warn"].append(event))
    return log


def test_a_listed_review_account_is_approved_without_the_pipeline(monkeypatch, recorded, stubbed):
    monkeypatch.setattr(main.store, "store_reviewer_uids", lambda: frozenset({"uid-1"}))
    answer = inner("verify_identity")(request(body()))
    assert answer == {"outcome": decisions.APPROVED, "reasons": [], "refreshToken": True}
    assert recorded["minted"] == ["uid-1"]
    assert recorded["verification"] == ["uid-1"]
    assert stubbed["decoded"] == 0, "no image is read for a review account"


def test_the_bypass_is_logged_and_recorded(monkeypatch, recorded):
    monkeypatch.setattr(main.store, "store_reviewer_uids", lambda: frozenset({"uid-1"}))
    inner("verify_identity")(request(body()))
    assert recorded["access"] == [("uid-1", "store-review", "reviewerBypass")]
    assert recorded["warn"] == ["reviewer_bypass"]


def test_an_unlisted_account_goes_through_the_check(monkeypatch, recorded):
    monkeypatch.setattr(main.store, "store_reviewer_uids", lambda: frozenset({"someone-else"}))
    with pytest.raises(AssertionError, match="pipeline was reached"):
        inner("verify_identity")(request(body()))
    assert recorded["minted"] == [] and recorded["access"] == []


def test_an_empty_list_means_no_bypass(recorded):
    # conftest: nobody is a reviewer by default.
    with pytest.raises(AssertionError, match="pipeline was reached"):
        inner("verify_identity")(request(body()))
    assert recorded["minted"] == []


def test_a_review_account_still_needs_its_consent(monkeypatch, recorded):
    monkeypatch.setattr(main.store, "store_reviewer_uids", lambda: frozenset({"uid-1"}))
    monkeypatch.setattr(main.store, "has_consent", lambda uid: False)
    with pytest.raises(main.https_fn.HttpsError):
        inner("verify_identity")(request(body()))
    assert recorded["minted"] == []


def test_the_secret_is_parsed_strictly():
    assert store.parse_reviewer_uids("abcdef123,  xyz_7890\nfoo") == frozenset(
        {"abcdef123", "xyz_7890"}
    )
    assert store.parse_reviewer_uids("") == frozenset()
    assert store.parse_reviewer_uids("a b; drop table") == frozenset()


def test_an_unreadable_secret_fails_closed(monkeypatch):
    import sys
    import types

    import google.cloud

    class _Boom:
        def __init__(self, *args, **kwargs):
            raise RuntimeError("no credentials")

    fake = types.ModuleType("google.cloud.secretmanager")
    fake.SecretManagerServiceClient = _Boom
    monkeypatch.setitem(sys.modules, "google.cloud.secretmanager", fake)
    monkeypatch.setattr(google.cloud, "secretmanager", fake, raising=False)
    monkeypatch.setattr(store, "_reviewer_cache", None)
    # conftest stubs store_reviewer_uids; this is the real reader.
    assert store._real_store_reviewer_uids() == frozenset()


# ------------------------------------------- the phone number allow-list

REVIEW_PHONE = "+201000000001"


def _phone(number):
    return {"phone_number": number}


def test_a_listed_number_passes_after_the_account_is_recreated(monkeypatch, recorded, stubbed):
    # She deleted the account and signed in again with the same test number:
    # Firebase gave her a new uid that is on no list. The number still is.
    monkeypatch.setattr(main.store, "store_reviewer_uids", lambda: frozenset({"uid-1"}))
    monkeypatch.setattr(main.store, "store_reviewer_phones", lambda: frozenset({REVIEW_PHONE}))
    answer = inner("verify_identity")(
        request(body(), uid="uid-new", token=_phone(REVIEW_PHONE))
    )
    assert answer == {"outcome": decisions.APPROVED, "reasons": [], "refreshToken": True}
    assert recorded["minted"] == ["uid-new"]
    assert recorded["verification"] == ["uid-new"]
    assert recorded["access"] == [("uid-new", "store-review", "reviewerBypass")]
    assert recorded["warn"] == ["reviewer_bypass"]
    assert stubbed["decoded"] == 0


def test_an_unlisted_number_goes_through_the_check(monkeypatch, recorded):
    monkeypatch.setattr(main.store, "store_reviewer_phones", lambda: frozenset({REVIEW_PHONE}))
    with pytest.raises(AssertionError, match="pipeline was reached"):
        inner("verify_identity")(request(body(), token=_phone("+201000000002")))
    assert recorded["minted"] == [] and recorded["access"] == []


def test_a_token_without_a_number_goes_through_the_check(monkeypatch, recorded):
    monkeypatch.setattr(main.store, "store_reviewer_phones", lambda: frozenset({REVIEW_PHONE}))
    with pytest.raises(AssertionError, match="pipeline was reached"):
        inner("verify_identity")(request(body()))
    assert recorded["minted"] == []


def test_a_listed_number_still_needs_its_consent(monkeypatch, recorded):
    monkeypatch.setattr(main.store, "store_reviewer_phones", lambda: frozenset({REVIEW_PHONE}))
    monkeypatch.setattr(main.store, "has_consent", lambda uid: False)
    with pytest.raises(main.https_fn.HttpsError):
        inner("verify_identity")(request(body(), token=_phone(REVIEW_PHONE)))
    assert recorded["minted"] == []


def test_a_review_account_starts_a_session_without_touching_the_limits(monkeypatch, stubbed):
    monkeypatch.setattr(main.store, "store_reviewer_phones", lambda: frozenset({REVIEW_PHONE}))
    monkeypatch.setattr(
        main.store, "FirestoreLedger", lambda: (_ for _ in ()).throw(AssertionError("ledger"))
    )

    class _Liveness:
        def create_session(self, uid):
            raise AssertionError("session minted")

    class _Deps:
        liveness = _Liveness()

    monkeypatch.setattr(main, "_deps", lambda: _Deps())
    with pytest.raises(AssertionError, match="session minted"):
        inner("start_verification")(request({}, token=_phone(REVIEW_PHONE)))
    assert stubbed["daily"] == 0
    assert "per_uid" not in stubbed


def test_an_ordinary_account_still_counts_its_session(monkeypatch, stubbed):
    monkeypatch.setattr(main.store, "store_reviewer_phones", lambda: frozenset({REVIEW_PHONE}))
    monkeypatch.setattr(
        main.store, "FirestoreLedger", lambda: (_ for _ in ()).throw(AssertionError("ledger"))
    )
    with pytest.raises(AssertionError, match="ledger"):
        inner("start_verification")(request({}, token=_phone("+201000000002")))
    assert stubbed["order"] == ["per_uid", "global"]


def test_the_phone_secret_is_parsed_strictly():
    assert store.parse_reviewer_phones("+20 100 000 0001,\n+20-100-000-0002") == frozenset(
        {"+201000000001", "+201000000002"}
    )
    assert store.parse_reviewer_phones("") == frozenset()
    # A local number without the country code could match the wrong token.
    assert store.parse_reviewer_phones("01000000001\n201000000001") == frozenset()
    assert store.parse_reviewer_phones("+20abc; drop") == frozenset()


def test_an_unreadable_phone_secret_fails_closed(monkeypatch):
    import sys
    import types

    import google.cloud

    class _Boom:
        def __init__(self, *args, **kwargs):
            raise RuntimeError("no credentials")

    fake = types.ModuleType("google.cloud.secretmanager")
    fake.SecretManagerServiceClient = _Boom
    monkeypatch.setitem(sys.modules, "google.cloud.secretmanager", fake)
    monkeypatch.setattr(google.cloud, "secretmanager", fake, raising=False)
    monkeypatch.setattr(store, "_reviewer_phone_cache", None)
    assert store._real_store_reviewer_phones() == frozenset()


def test_the_phone_secret_reads_its_own_resource(monkeypatch):
    import sys
    import types

    import google.cloud

    asked = []

    class _Client:
        def access_secret_version(self, request):
            asked.append(request["name"])
            payload = types.SimpleNamespace(data=REVIEW_PHONE.encode("utf-8"))
            return types.SimpleNamespace(payload=payload)

    fake = types.ModuleType("google.cloud.secretmanager")
    fake.SecretManagerServiceClient = _Client
    monkeypatch.setitem(sys.modules, "google.cloud.secretmanager", fake)
    monkeypatch.setattr(google.cloud, "secretmanager", fake, raising=False)
    monkeypatch.setattr(store, "_reviewer_phone_cache", None)
    assert store._real_store_reviewer_phones() == frozenset({REVIEW_PHONE})
    assert asked == ["projects/own-hub/secrets/store-reviewer-phones/versions/latest"]
