"""R7: the reviewer tool signs her in itself (email and password, Firebase
Auth REST), refreshes the ID token itself, and exchanges her registered App
Check debug token itself. Nothing secret is written to disk or printed."""

from __future__ import annotations

import builtins
import json
import logging
import os
import re
import urllib.parse

import pytest

from identity import reasons, review
from tests.fake_review_store import FakeReviewStore
from tests.test_review_queue_tool import TOKENS, Server
from tools import review_queue

PASSWORD = "s3cret-pass"
DEBUG_TOKEN = "dbg-1111-2222"


class Rest:
    """Fake identitytoolkit, securetoken and App Check exchange endpoints."""

    def __init__(self):
        self.calls = []
        self.issued = 0
        self.exchanged = 0
        TOKENS.setdefault("id-1", ("rev", {"womanReviewer": True}))
        TOKENS.setdefault("id-2", ("rev", {"womanReviewer": True}))

    def __call__(self, url, body, content_type):
        self.calls.append((url, body, content_type))
        if "accounts:signInWithPassword" in url:
            data = json.loads(body)
            if data != {"email": "rev@example.com", "password": PASSWORD,
                        "returnSecureToken": True}:
                return 400, {"error": {"code": 400, "message": "INVALID_LOGIN_CREDENTIALS"}}
            self.issued += 1
            return 200, {"idToken": f"id-{self.issued}", "refreshToken": "r-1",
                         "expiresIn": "3600"}
        if "securetoken.googleapis.com" in url:
            form = urllib.parse.parse_qs(body.decode())
            assert form == {"grant_type": ["refresh_token"], "refresh_token": ["r-1"]}
            self.issued += 1
            return 200, {"id_token": f"id-{self.issued}", "refresh_token": "r-1",
                         "expires_in": "3600"}
        if ":exchangeDebugToken" in url:
            assert json.loads(body) == {"debugToken": DEBUG_TOKEN}
            self.exchanged += 1
            return 200, {"token": f"ac-{self.exchanged}", "ttl": "3600s"}
        raise AssertionError(url)


class Clock:
    def __init__(self):
        self.now = 1_000_000.0

    def __call__(self):
        return self.now


def _session(rest, clock):
    auth = review_queue.PasswordSession(
        "rev@example.com", PASSWORD, review_queue.API_KEY, rest=rest, clock=clock
    )
    app_check = review_queue.DebugAppCheck(
        DEBUG_TOKEN, review_queue.APP_ID, review_queue.API_KEY, rest=rest, clock=clock
    )
    return auth, app_check


def test_signs_in_with_password_and_uses_the_id_token(monkeypatch):
    fake = FakeReviewStore()
    review.request(fake, "her", "niqab")
    server = Server(monkeypatch, fake)
    rest, clock = Rest(), Clock()
    auth, app_check = _session(rest, clock)
    client = review_queue.Client(auth, app_check, "https://fn.example", post=server.post)
    lines = []
    assert review_queue.main(["list"], client=client, out=lines.append) == 0
    url = rest.calls[0][0]
    assert url.startswith(
        "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key="
    )
    assert ":exchangeDebugToken" in rest.calls[1][0]
    assert f"/apps/{review_queue.APP_ID}:" in rest.calls[1][0]
    _, headers = server.seen[0]
    assert headers["Authorization"] == "Bearer id-1"
    assert headers["X-Firebase-AppCheck"] == "ac-1"


def test_refreshes_the_id_token_and_app_check_token_before_they_expire(monkeypatch):
    fake = FakeReviewStore()
    server = Server(monkeypatch, fake)
    rest, clock = Rest(), Clock()
    auth, app_check = _session(rest, clock)
    client = review_queue.Client(auth, app_check, "https://fn.example", post=server.post)
    client.call("list_verification_flags", {})
    clock.now += 3600 - 60  # inside the refresh margin
    client.call("list_verification_flags", {})
    assert [h["Authorization"] for _, h in server.seen] == ["Bearer id-1", "Bearer id-2"]
    assert [h["X-Firebase-AppCheck"] for _, h in server.seen] == ["ac-1", "ac-2"]
    assert any(
        c[0].startswith("https://securetoken.googleapis.com/v1/token?key=")
        for c in rest.calls
    )


def test_an_unauthenticated_answer_refreshes_once_and_retries(monkeypatch):
    fake = FakeReviewStore()
    server = Server(monkeypatch, fake)
    rest, clock = Rest(), Clock()
    auth, app_check = _session(rest, clock)
    TOKENS.pop("id-1")
    try:
        client = review_queue.Client(auth, app_check, "https://fn.example", post=server.post)
        assert client.call("list_verification_flags", {}) == {"flags": []}
        assert [h["Authorization"] for _, h in server.seen] == ["Bearer id-1", "Bearer id-2"]
    finally:
        TOKENS["id-1"] = ("rev", {"womanReviewer": True})


def test_a_wrong_password_is_refused_without_echoing_it(monkeypatch):
    rest = Rest()
    with pytest.raises(review_queue.SignInError) as caught:
        review_queue.PasswordSession(
            "rev@example.com", "wrong", review_queue.API_KEY, rest=rest, clock=Clock()
        )
    assert str(caught.value) == "INVALID_LOGIN_CREDENTIALS"


def test_env_and_prompts_build_a_signed_in_client(monkeypatch):
    for name in ("OWNHUB_REVIEWER_ID_TOKEN", "OWNHUB_APP_CHECK_TOKEN",
                 "OWNHUB_APP_CHECK_DEBUG_TOKEN", "OWNHUB_FUNCTIONS_BASE"):
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setenv("OWNHUB_REVIEWER_EMAIL", "rev@example.com")
    asked = []

    def prompt(label):
        asked.append(label)
        return PASSWORD if "password" in label.lower() else DEBUG_TOKEN

    rest = Rest()
    client = review_queue._client_from_env(prompt=prompt, rest=rest, clock=Clock())
    assert isinstance(client.id_token, review_queue.PasswordSession)
    assert isinstance(client.app_check, review_queue.DebugAppCheck)
    assert len(asked) == 2 and all("hidden" in label for label in asked)


def test_no_secret_is_written_to_disk_or_logged_or_printed(monkeypatch, caplog, capsys):
    fake = FakeReviewStore()
    flag_id = review.request(fake, "her", "niqab").flag_id
    server = Server(monkeypatch, fake)
    rest, clock = Rest(), Clock()

    real_open = builtins.open

    def no_write(path, mode="r", *args, **kwargs):
        assert not any(m in mode for m in "wax+"), f"wrote {path}"
        return real_open(path, mode, *args, **kwargs)

    monkeypatch.setattr(builtins, "open", no_write)
    caplog.set_level(logging.DEBUG)
    lines = []
    auth, app_check = _session(rest, clock)
    client = review_queue.Client(auth, app_check, "https://fn.example", post=server.post)
    for argv in (["list"], ["contact", "--flag", flag_id]):
        review_queue.main(argv, client=client, out=lines.append)
    seen = " ".join(lines) + caplog.text + capsys.readouterr().out
    for secret in (PASSWORD, DEBUG_TOKEN, "id-1", "ac-1", "r-1"):
        assert secret not in seen
    assert not hasattr(auth, "password") and not hasattr(auth, "_password")


def test_the_built_in_key_and_app_are_the_public_android_options():
    path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
        "app", "lib", "firebase_options.dart",
    )
    if not os.path.exists(path):
        pytest.skip("app/ not present")
    source = open(path, encoding="utf-8").read()
    android = source[source.index("FirebaseOptions android"):]
    assert re.search(r"apiKey: '([^']+)'", android).group(1) == review_queue.API_KEY
    assert re.search(r"appId: '([^']+)'", android).group(1) == review_queue.APP_ID


def test_the_docs_explain_debug_tokens_per_reviewer():
    doc = review_queue.__doc__
    for phrase in ("Manage debug tokens", "one debug token per reviewer", "revoke",
                   "Email/Password"):
        assert phrase.lower() in doc.lower(), phrase
