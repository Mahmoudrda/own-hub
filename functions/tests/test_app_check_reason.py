"""R3: a phone without a valid App Check token hears the real reason.

These go through the REAL firebase-functions wrapper (a werkzeug request in,
an HTTP response out), not the unwrapped body. With `enforce_app_check=True`
on the decorator the framework itself answers a missing or invalid token with
UNAUTHENTICATED "Unauthenticated" before main.py runs, so the app could never
tell her the cause. The explicit check in main._require_auth is the gate now,
and it must answer FAILED_PRECONDITION app_check_missing on every callable
before any work is done.
"""

from __future__ import annotations

import json
import types

import pytest
from flask import Flask, Request
from firebase_functions.private import util as fn_util
from werkzeug.test import EnvironBuilder

import main
from identity import config, reasons

from tests.test_entrypoints import CALLABLES


class _Tripwire(types.ModuleType):
    """Stands in for main.store and main.review: any use is business logic."""

    def __init__(self, name, hits):
        super().__init__(name)
        self._hits = hits

    def __getattr__(self, attr):
        self._hits.append(attr)
        raise AssertionError(f"business logic reached: {attr}")


@pytest.fixture
def wired(monkeypatch):
    hits: list = []
    monkeypatch.setattr(main, "store", _Tripwire("store", hits))
    monkeypatch.setattr(main, "review", _Tripwire("review", hits))
    monkeypatch.setattr(
        fn_util._auth, "verify_id_token", lambda token: {"uid": "uid-1"}
    )
    return hits


def _call(name, app_check_header=None):
    headers = {"Authorization": "Bearer id-token"}
    if app_check_header is not None:
        headers["X-Firebase-AppCheck"] = app_check_header
    environ = EnvironBuilder(
        method="POST",
        data=json.dumps({"data": {}}),
        content_type="application/json",
        headers=headers,
    ).get_environ()
    with Flask(__name__).test_request_context():
        response = getattr(main, name)(Request(environ))
    return response.status_code, json.loads(response.get_data())


def test_app_check_stays_enforced_in_config():
    assert config.ENFORCE_APP_CHECK is True


@pytest.mark.parametrize("name", sorted(CALLABLES))
def test_a_missing_app_check_token_is_failed_precondition(name, wired):
    status, body = _call(name)
    assert status == 400, body
    assert body["error"]["status"] == "FAILED_PRECONDITION"
    assert body["error"]["message"] == reasons.APP_CHECK_MISSING
    assert wired == [], "no business logic before the App Check check"


@pytest.mark.parametrize("name", sorted(CALLABLES))
def test_an_invalid_app_check_token_is_failed_precondition(name, wired, monkeypatch):
    def reject(token):
        raise ValueError("bad token")

    monkeypatch.setattr(fn_util._app_check, "verify_token", reject)
    status, body = _call(name, "forged")
    assert status == 400, body
    assert body["error"]["message"] == reasons.APP_CHECK_MISSING
    assert wired == []


def test_a_valid_app_check_token_gets_past_the_check(wired, monkeypatch):
    # The framework still VERIFIES the token with enforcement off: request.app
    # is set only for a token that verify_token accepted.
    monkeypatch.setattr(
        fn_util._app_check, "verify_token", lambda token: {"sub": "app-1"}
    )
    status, body = _call("list_verification_flags", "good")
    # Past App Check, the account is refused (N1 provider or reviewer claim).
    assert status == 403, body
    assert body["error"]["status"] == "PERMISSION_DENIED"
