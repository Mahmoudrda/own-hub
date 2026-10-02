"""tools/review_queue.py: the reviewer signs in as herself and calls the HTTPS
callables; the tool holds no admin credentials (N8).

The fake transport below runs every request through the REAL callable bodies
in main.py with a FakeReviewStore, so the claim check, the access log and the
reason codes are the server's own."""

from __future__ import annotations

import os

import pytest
from firebase_functions import https_fn

import main
from identity import reasons, review
from tests.fake_review_store import FakeReviewStore
from tests.test_entrypoints import inner, request
from tools import grant_reviewer, review_queue

FEMALE_ADULT = "29901012345628"
TOKENS = {
    "tok-rev": ("rev", {"womanReviewer": True}),
    "tok-plain": ("plain", {}),
}


class Server:
    """Decodes the bearer token the way the callable framework would."""

    def __init__(self, monkeypatch, fake):
        self.seen = []
        monkeypatch.setattr(main.store, "FirestoreReviewStore", lambda: fake)

    def post(self, url, headers, payload):
        self.seen.append((url, dict(headers)))
        name = url.rsplit("/", 1)[-1]
        token = headers.get("Authorization", "").removeprefix("Bearer ")
        if token not in TOKENS:
            return {"error": {"status": "UNAUTHENTICATED", "message": "unauthenticated"}}
        uid, claims = TOKENS[token]
        req = request(
            payload["data"], uid=uid, token=claims,
            app="X-Firebase-AppCheck" in headers,
        )
        try:
            return {"result": inner(name)(req)}
        except https_fn.HttpsError as error:
            return {"error": {"status": error.code.name, "message": error.message}}


def _run(argv, server, token="tok-rev", nid=None, app_check="ac-token"):
    lines = []
    client = review_queue.Client(token, app_check, "https://fn.example", post=server.post)
    code = review_queue.main(
        argv, client=client, read_nid=(lambda: nid) if nid else None, out=lines.append
    )
    return code, lines


def test_a_woman_reviewer_may_list_the_queue_over_the_callable(monkeypatch):
    fake = FakeReviewStore()
    review.request(fake, "her", "niqab")
    server = Server(monkeypatch, fake)
    code, lines = _run(["list"], server)
    assert code == 0 and len(lines) == 1
    url, headers = server.seen[0]
    assert url == "https://fn.example/list_verification_flags"
    assert headers["Authorization"] == "Bearer tok-rev"
    assert headers["X-Firebase-AppCheck"] == "ac-token"
    assert ("rev", "*", "list") in fake.access


def test_refuses_without_the_claim(monkeypatch):
    fake = FakeReviewStore()
    review.request(fake, "her", "niqab")
    code, lines = _run(["list"], Server(monkeypatch, fake), token="tok-plain")
    assert code == 1 and "refused" in lines[0]
    assert fake.access == []


def test_without_app_check_the_server_refuses(monkeypatch):
    fake = FakeReviewStore()
    code, lines = _run(["list"], Server(monkeypatch, fake), app_check=None)
    assert code == 1 and lines == [f"refused: {reasons.APP_CHECK_MISSING}"]


def test_the_whole_loop_on_a_niqab_flag(monkeypatch):
    fake = FakeReviewStore()
    flag_id = review.request(fake, "her", "niqab").flag_id
    server = Server(monkeypatch, fake)
    code, lines = _run(["contact", "--flag", flag_id], server)
    assert code == 0 and lines == ["+201005550132"]
    _run(
        ["schedule", "--flag", flag_id, "--route", "video",
         "--at", "2026-10-05T10:00:00+02:00"],
        server,
    )
    code, lines = _run(["decide", "--flag", flag_id, "--approve"], server, nid=FEMALE_ADULT)
    assert code == 0, lines
    assert lines == ["decided: APPROVED"]
    assert fake.minted == ["her"]
    assert FEMALE_ADULT not in " ".join(lines)
    actions = [a for _, _, a in fake.access]
    assert actions == ["list", "contact", "schedule:video", "list", "decide"]
    assert {who for who, _, _ in fake.access} == {"rev"}


def test_a_duplicate_flag_says_escalate(monkeypatch):
    fake = FakeReviewStore()
    flag_id = review.request(fake, "her", "error").flag_id
    fake.flags[flag_id]["flags"] = [reasons.DUPLICATE_ID]
    code, lines = _run(["list"], Server(monkeypatch, fake))
    assert "escalate to the owner" in lines[0]


def test_the_reviewer_tool_holds_no_admin_credentials():
    path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "tools", "review_queue.py")
    source = open(path, encoding="utf-8").read()
    for banned in ("firebase_admin", "identity.store", "from identity", "google.auth",
                   "initialize_app", "grant-reviewer"):
        assert banned not in source.split('"""', 2)[2], banned


def test_ready_made_tokens_still_come_from_the_environment(monkeypatch):
    monkeypatch.setenv("OWNHUB_REVIEWER_ID_TOKEN", "from-env")
    monkeypatch.setenv("OWNHUB_APP_CHECK_TOKEN", "ac-env")
    monkeypatch.delenv("OWNHUB_FUNCTIONS_BASE", raising=False)
    client = review_queue._client_from_env(lambda label: pytest.fail("asked"))
    assert client.id_token == "from-env" and client.app_check == "ac-env"
    assert client.base == review_queue.DEFAULT_BASE


def test_grant_reviewer_is_a_separate_owner_tool_that_needs_adc():
    granted = []
    lines = []

    def no_adc():
        raise SystemExit("refused: no Application Default Credentials")

    with pytest.raises(SystemExit):
        grant_reviewer.main(["--uid", "u1"], grant=granted.append, require_adc=no_adc)
    assert granted == []
    assert grant_reviewer.main(
        ["--uid", "u1"], grant=granted.append, require_adc=lambda: None, out=lines.append
    ) == 0
    assert granted == ["u1"]
