"""M1: record_legal_acceptance. Terms and Privacy accepted at C06, recorded
server-side once per material version, with allow-listed fields only."""

from __future__ import annotations

import pytest
from firebase_functions import https_fn

import main
from identity import config, reasons, store
from tests.test_entrypoints import inner, raises, request, stubbed  # noqa: F401


def _body(**overrides):
    payload = {
        "termsVersion": config.TERMS_VERSION,
        "privacyVersion": config.PRIVACY_VERSION,
        "locale": "ar",
        "appVersion": "1.0.0+12",
        "platform": "android",
        "acceptedAtMs": 1791000000000,
    }
    payload.update(overrides)
    return payload


@pytest.fixture
def recorded(monkeypatch, stubbed):
    log = {"on_file": False, "writes": []}
    monkeypatch.setattr(main.store, "has_legal_acceptance", lambda uid: log["on_file"])

    def write(uid, locale, app_version, platform, accepted_at):
        log["writes"].append((uid, locale, app_version, platform, accepted_at))
        log["on_file"] = True

    monkeypatch.setattr(main.store, "write_legal_acceptance", write)
    return log


def test_current_versions_are_recorded(recorded):
    answer = inner("record_legal_acceptance")(request(_body()))
    assert answer == {
        "ok": True,
        "termsVersion": config.TERMS_VERSION,
        "privacyVersion": config.PRIVACY_VERSION,
    }
    assert recorded["writes"] == [("uid-1", "ar", "1.0.0+12", "android", 1791000000000)]


def test_accepting_again_is_a_no_op(recorded):
    inner("record_legal_acceptance")(request(_body()))
    inner("record_legal_acceptance")(request(_body()))
    assert len(recorded["writes"]) == 1


@pytest.mark.parametrize(
    "overrides",
    [
        {"termsVersion": config.TERMS_VERSION - 1},
        {"privacyVersion": config.PRIVACY_VERSION + 1},
        {"termsVersion": str(config.TERMS_VERSION)},
        {"termsVersion": None},
    ],
)
def test_a_wrong_version_is_refused(overrides, recorded):
    error = raises(
        lambda: inner("record_legal_acceptance")(request(_body(**overrides))),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert error.message == reasons.CONSENT_MISSING
    assert recorded["writes"] == []


@pytest.mark.parametrize(
    "overrides",
    [
        {"locale": "fr"},
        {"locale": None},
        {"appVersion": "1.0.0; drop"},
        {"appVersion": "x" * 40},
        {"appVersion": "1" * 33},
        {"platform": "web"},
        {"acceptedAtMs": "yesterday"},
        {"acceptedAtMs": True},
        {"acceptedAtMs": 0},
    ],
)
def test_a_bad_field_is_refused(overrides, recorded):
    raises(
        lambda: inner("record_legal_acceptance")(request(_body(**overrides))),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )
    assert recorded["writes"] == []


def test_a_body_that_is_not_an_object_is_refused(recorded):
    raises(
        lambda: inner("record_legal_acceptance")(request(["x"])),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )


def test_the_record_holds_allow_listed_fields_only():
    payload = store.legal_acceptance_payload("en", "1.0.0", "ios", 1791000000000)
    assert set(payload) == set(store.LEGAL_ACCEPTANCE_FIELDS)
    assert payload["termsVersion"] == config.TERMS_VERSION
    assert payload["privacyVersion"] == config.PRIVACY_VERSION


def test_the_record_lives_beside_the_other_consents(monkeypatch):
    written = {}

    class _Ref:
        def __init__(self, path):
            self.path = path

        def collection(self, name):
            return _Ref(f"{self.path}/{name}")

        def document(self, name):
            return _Ref(f"{self.path}/{name}")

        def set(self, payload, merge=False):
            written[self.path] = dict(payload)

    monkeypatch.setattr(store, "db", lambda: _Ref(""))
    store.write_legal_acceptance("her", "ar", "1.0.0", "android", 1)
    path = f"/users/her/consents/legal-t{config.TERMS_VERSION}-p{config.PRIVACY_VERSION}"
    assert list(written) == [path]
    assert written[path]["locale"] == "ar"


def test_the_versions_are_ints_and_material():
    assert isinstance(config.TERMS_VERSION, int)
    assert isinstance(config.PRIVACY_VERSION, int)
    assert config.TERMS_VERSION == 3 and config.PRIVACY_VERSION == 3


def _int64(n):
    return {"@type": "type.googleapis.com/google.protobuf.Int64Value", "value": str(n)}


def test_an_iphone_sends_wrapped_whole_numbers_and_is_recorded(recorded):
    # The iOS SDK sends every Dart int as an Int64Value wrapper; Android sends
    # a plain number. Both must reach the same checks.
    body = _body(
        termsVersion=_int64(config.TERMS_VERSION),
        privacyVersion=_int64(config.PRIVACY_VERSION),
        acceptedAtMs=_int64(1791000000000),
        platform="ios",
    )
    inner("record_legal_acceptance")(request(body))
    assert recorded["writes"] == [("uid-1", "ar", "1.0.0+12", "ios", 1791000000000)]


def test_a_wrapped_wrong_version_is_still_refused(recorded):
    error = raises(
        lambda: inner("record_legal_acceptance")(
            request(_body(termsVersion=_int64(config.TERMS_VERSION - 1)))
        ),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert error.message == reasons.CONSENT_MISSING
    assert recorded["writes"] == []


@pytest.mark.parametrize(
    "value",
    [
        {"@type": "type.googleapis.com/google.protobuf.Int64Value", "value": "x"},
        {"@type": "type.googleapis.com/google.protobuf.DoubleValue", "value": "3"},
        {"@type": "type.googleapis.com/google.protobuf.Int64Value", "value": 3},
        {"@type": "type.googleapis.com/google.protobuf.Int64Value", "value": "3", "x": 1},
    ],
)
def test_anything_else_shaped_like_a_wrapper_is_left_alone(value):
    assert main._unwrap(value) == value
    assert main._unwrap([value, {"n": _int64(4)}]) == [value, {"n": 4}]
