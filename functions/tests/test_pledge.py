"""C16: record_pledge. Her agreement to the community's three rules, recorded
server-side once per version, with allow-listed fields only."""

from __future__ import annotations

import json
import pathlib

import pytest
from firebase_functions import https_fn

import main
from identity import config, reasons, store
from tests import fake_firestore
from tests.test_entrypoints import inner, raises, request, stubbed  # noqa: F401

CONTRACT = json.loads(
    (pathlib.Path(__file__).resolve().parents[2] / "contracts" / "identity_contract.json").read_text()
)


@pytest.fixture
def fs(monkeypatch, stubbed):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    return db


def _doc(fs):
    return fs.docs.get(f"{config.COL_USERS}/uid-1/{config.COL_CONSENTS}/pledge-v{config.PLEDGE_VERSION}")


def test_the_current_version_is_recorded_once(fs):
    body = {"version": config.PLEDGE_VERSION, "locale": "ar", "appVersion": "1.0.0+12"}
    answer = inner("record_pledge")(request(body))
    assert answer == {"ok": True, "version": config.PLEDGE_VERSION}
    first = dict(_doc(fs))
    assert set(first) <= set(store.PLEDGE_FIELDS)
    assert first["version"] == config.PLEDGE_VERSION
    assert first["locale"] == "ar" and first["appVersion"] == "1.0.0+12"

    inner("record_pledge")(request({**body, "locale": "en"}))
    assert _doc(fs) == first, "agreeing again changes nothing"


@pytest.mark.parametrize("version", [None, 0, config.PLEDGE_VERSION + 1, True, "1"])
def test_any_other_version_is_refused_and_nothing_is_written(fs, version):
    error = raises(
        lambda: inner("record_pledge")(request({"version": version})),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert error.message == reasons.CONSENT_MISSING
    assert _doc(fs) is None


def test_free_text_never_lands_in_the_record(fs):
    inner("record_pledge")(
        request({"version": config.PLEDGE_VERSION, "locale": "fr; drop", "appVersion": "x" * 80, "note": "hi"})
    )
    assert set(_doc(fs)) == {"version", "at"}


def test_the_contract_matches_the_server():
    callable_ = CONTRACT["callables"]["record_pledge"]
    assert callable_["request"]["version"] == config.PLEDGE_VERSION
    assert callable_["response"] == {"ok": True, "version": config.PLEDGE_VERSION}
    doc = CONTRACT["documents"]["pledge"]
    assert doc["path"] == f"users/{{uid}}/consents/{store.pledge_doc_id()}"
    assert set(doc["fields"]) == set(store.PLEDGE_FIELDS)
