"""tools/grant_admin.py: the only way an account becomes an admin.

It must merge rather than replace claims, write nothing when there is nothing
to change, take the claim away cleanly, and refuse to run without the owner's
credentials.
"""

from __future__ import annotations

from types import SimpleNamespace

import pytest

from tools import grant_admin


class FakeAuth:
    class UserNotFoundError(Exception):
        pass

    def __init__(self, claims=None, phone="+201001234567"):
        self.claims = dict(claims or {})
        self.phone = phone
        self.writes = []

    def get_user(self, uid):
        if uid != "uOwner":
            raise self.UserNotFoundError(uid)
        return SimpleNamespace(custom_claims=dict(self.claims), phone_number=self.phone)

    def set_custom_user_claims(self, uid, claims):
        self.writes.append((uid, dict(claims)))
        self.claims = dict(claims)


def run(argv, auth):
    lines = []
    code = grant_admin.main(argv, auth=auth, require_adc=lambda: None, out=lines.append)
    return code, lines


def test_granting_keeps_every_other_claim():
    auth = FakeAuth({"verified": True, "coachV": "active"})
    code, lines = run(["--uid", "uOwner"], auth)
    assert code == 0
    assert auth.writes == [
        ("uOwner", {"verified": True, "coachV": "active", "admin": True})
    ]
    assert lines == ["uOwner: admin granted"]


def test_granting_twice_writes_once():
    auth = FakeAuth({"verified": True})
    run(["--uid", "uOwner"], auth)
    code, lines = run(["--uid", "uOwner"], auth)
    assert code == 0
    assert len(auth.writes) == 1
    assert lines == ["uOwner: already admin, nothing written"]


def test_revoking_removes_only_admin():
    auth = FakeAuth({"verified": True, "admin": True, "womanReviewer": True})
    code, lines = run(["--uid", "uOwner", "--revoke"], auth)
    assert code == 0
    assert auth.writes == [("uOwner", {"verified": True, "womanReviewer": True})]
    assert lines == ["uOwner: admin removed"]


def test_check_never_writes():
    auth = FakeAuth({"admin": True})
    code, lines = run(["--uid", "uOwner", "--check"], auth)
    assert code == 0 and auth.writes == []
    assert lines == ["uOwner: admin yes"]


def test_an_unknown_uid_is_reported_and_nothing_is_written():
    auth = FakeAuth()
    code, lines = run(["--uid", "uNobody"], auth)
    assert code == 1 and auth.writes == []
    assert lines == ["no account with uid uNobody"]


def test_an_account_without_a_phone_is_warned_about():
    auth = FakeAuth(phone=None)
    _, lines = run(["--uid", "uOwner"], auth)
    assert any("phone sign-in only" in line for line in lines)


def test_a_blank_uid_is_refused_before_credentials_are_touched():
    called = []
    code = grant_admin.main(
        ["--uid", "  "],
        auth=FakeAuth(),
        require_adc=lambda: called.append(True),
        out=lambda _line: None,
    )
    assert code == 2 and called == []


def test_revoke_and_check_cannot_be_combined():
    with pytest.raises(SystemExit):
        grant_admin.main(
            ["--uid", "uOwner", "--revoke", "--check"],
            auth=FakeAuth(),
            require_adc=lambda: None,
            out=lambda _line: None,
        )


def test_without_owner_credentials_it_refuses(monkeypatch):
    import google.auth

    monkeypatch.delenv("FIREBASE_AUTH_EMULATOR_HOST", raising=False)

    def no_credentials():
        raise google.auth.exceptions.DefaultCredentialsError("none")

    monkeypatch.setattr(google.auth, "default", no_credentials)
    with pytest.raises(SystemExit) as refused:
        grant_admin._require_adc()
    assert "refused" in str(refused.value)
