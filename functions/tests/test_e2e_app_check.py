"""App Check steps aside only inside the local emulator suite.

`_local_emulator` is the one switch (see the E0 hook). Every way of getting it
wrong is a callable open to a caller without an App Check token in production,
so each variable is taken away in turn.
"""

from __future__ import annotations

import json

import pytest
from flask import Flask, Request
from firebase_functions.private import util as fn_util
from werkzeug.test import EnvironBuilder

import main
from identity import config, reasons

pytestmark = pytest.mark.skipif(
    not hasattr(main, "_local_emulator"), reason="hook E0-main is not applied yet"
)

LOCAL = {
    "FUNCTIONS_EMULATOR": "true",
    "FIRESTORE_EMULATOR_HOST": "127.0.0.1:8288",
    "FIREBASE_AUTH_EMULATOR_HOST": "127.0.0.1:9299",
}


@pytest.fixture(autouse=True)
def _clean(monkeypatch):
    for name in ("FUNCTIONS_EMULATOR", "FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST", "K_SERVICE"):
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setattr(fn_util._auth, "verify_id_token", lambda token: {"uid": "u1"})


def _call():
    environ = EnvironBuilder(
        method="POST",
        data=json.dumps({"data": {}}),
        content_type="application/json",
        headers={"Authorization": "Bearer t"},
    ).get_environ()
    with Flask(__name__).test_request_context():
        response = main.list_verification_flags(Request(environ))
    return response.status_code, json.loads(response.get_data())


def _set(monkeypatch, **env):
    for name, value in env.items():
        monkeypatch.setenv(name, value)


def test_enforcement_stays_on_in_config():
    assert config.ENFORCE_APP_CHECK is True


def test_production_environment_is_refused():
    status, body = _call()
    assert status == 400 and body["error"]["message"] == reasons.APP_CHECK_MISSING


def test_the_emulator_environment_opens_the_gate(monkeypatch):
    _set(monkeypatch, **LOCAL)
    status, body = _call()
    # Past App Check the account is refused for the claim, not for App Check.
    assert status == 403, body


@pytest.mark.parametrize("missing", sorted(LOCAL))
def test_each_variable_is_needed(monkeypatch, missing):
    _set(monkeypatch, **{k: v for k, v in LOCAL.items() if k != missing})
    status, body = _call()
    assert status == 400 and body["error"]["message"] == reasons.APP_CHECK_MISSING


def test_the_emulator_sets_k_service_too_and_is_still_open(monkeypatch):
    _set(monkeypatch, **LOCAL, K_SERVICE="submit_coach_application")
    status, body = _call()
    assert status == 403, body


@pytest.mark.parametrize("name", ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"])
@pytest.mark.parametrize("host", ["firestore.googleapis.com:443", "10.0.0.5:8288", "evil.example:80", ""])
def test_a_host_that_is_not_loopback_is_refused(monkeypatch, name, host):
    _set(monkeypatch, **{**LOCAL, name: host})
    status, body = _call()
    assert status == 400 and body["error"]["message"] == reasons.APP_CHECK_MISSING


def test_the_flag_must_be_exactly_true(monkeypatch):
    _set(monkeypatch, **{**LOCAL, "FUNCTIONS_EMULATOR": "false"})
    status, body = _call()
    assert status == 400 and body["error"]["message"] == reasons.APP_CHECK_MISSING
