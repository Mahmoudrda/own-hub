"""S17 server half: record_health_consent. Server-only writes of
users/{uid}/consents/health-v1; withdrawing purges the cloud copy."""

from __future__ import annotations

import pytest
from firebase_functions import https_fn

import main
from identity import config, reasons, store
from tests.test_entrypoints import inner, raises, request, stubbed  # noqa: F401
from tests.test_identity_contract import contract


@pytest.fixture
def recorded(monkeypatch, stubbed):
    log = {"writes": [], "purged": []}
    monkeypatch.setattr(
        main.store, "write_health_consent", lambda uid, granted: log["writes"].append(granted)
    )
    monkeypatch.setattr(main.store, "purge_health_data", lambda uid: log["purged"].append(uid))
    return log


def test_granting(recorded):
    answer = inner("record_health_consent")(
        request({"consentVersion": config.HEALTH_CONSENT_VERSION, "granted": True})
    )
    assert answer == {"ok": True, "state": "granted"}
    assert answer == contract()["callables"]["record_health_consent"]["response"]
    assert recorded["writes"] == [True] and recorded["purged"] == []


def test_withdrawing_purges(recorded):
    answer = inner("record_health_consent")(
        request({"consentVersion": config.HEALTH_CONSENT_VERSION, "granted": False})
    )
    assert answer == {"ok": True, "state": "withdrawn"}
    assert recorded["writes"] == [False] and recorded["purged"] == ["uid-1"]


def test_a_wrong_version_is_refused(recorded):
    error = raises(
        lambda: inner("record_health_consent")(request({"consentVersion": 2, "granted": True})),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert error.message == reasons.CONSENT_MISSING
    assert recorded["writes"] == []


@pytest.mark.parametrize("bad", [{"consentVersion": 1}, {"consentVersion": 1, "granted": "yes"}, ["x"]])
def test_a_bad_body_is_invalid(bad, recorded):
    error = raises(
        lambda: inner("record_health_consent")(request(bad)),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )
    assert error.message == reasons.INTERNAL_ERROR


def test_the_request_shape_is_the_contract():
    assert contract()["callables"]["record_health_consent"]["request"] == {
        "consentVersion": config.HEALTH_CONSENT_VERSION,
        "granted": True,
    }


class _Recorder:
    def __init__(self):
        self.sets = []
        self.deleted = []

    def collection(self, name):
        return _Ref(self, name)

    def recursive_delete(self, ref):
        self.deleted.append(ref.path)


class _Ref:
    def __init__(self, root, path):
        self.root, self.path = root, path

    def collection(self, name):
        return _Ref(self.root, f"{self.path}/{name}")

    def document(self, name):
        return _Ref(self.root, f"{self.path}/{name}")

    def set(self, payload, merge=False):
        self.root.sets.append((self.path, dict(payload), merge))


def test_the_document_path_and_fields_are_the_contract(monkeypatch):
    recorder = _Recorder()
    monkeypatch.setattr(store, "db", lambda: recorder)
    store.write_health_consent("{uid}", True)
    doc = contract()["documents"]["healthConsent"]
    path, payload, _ = recorder.sets[0]
    assert path == doc["path"]
    assert set(payload) == set(doc["fields"])
    assert payload["state"] == "granted" and payload["withdrawnAt"] is None
    assert payload["version"] == config.HEALTH_CONSENT_VERSION

    recorder.sets.clear()
    store.write_health_consent("{uid}", False)
    _, payload, merge = recorder.sets[0]
    assert payload["state"] == "withdrawn" and "withdrawnAt" in payload and merge
    assert set(payload) <= set(doc["fields"])
    assert set(doc["states"]) == {"granted", "withdrawn"}


def test_the_purge_covers_the_four_collections_and_the_profile_keys(monkeypatch):
    from google.cloud import firestore

    recorder = _Recorder()
    monkeypatch.setattr(store, "db", lambda: recorder)
    store.purge_health_data("her")
    assert sorted(recorder.deleted) == sorted(
        f"users/her/{name}" for name in ("checkins", "measurements", "cycle", "periods")
    )
    path, payload, merge = recorder.sets[0]
    assert path == "users/her" and merge
    assert payload == {
        "profile": {"lifeStage": firestore.DELETE_FIELD, "allergies": firestore.DELETE_FIELD}
    }
