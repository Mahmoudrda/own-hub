"""tools/grant_finance.py: the only way an account becomes finance staff.
Merge never replaces, writes nothing when nothing changes, and refuses to run
without the owner's credentials."""

from __future__ import annotations

from types import SimpleNamespace

import pytest

from tools import grant_finance


class FakeAuth:
    class UserNotFoundError(Exception):
        pass

    def __init__(self, claims=None, phone="+201001234567"):
        self.claims = dict(claims or {})
        self.phone = phone
        self.writes = []

    def get_user(self, uid):
        if uid != "uFin":
            raise self.UserNotFoundError(uid)
        return SimpleNamespace(custom_claims=dict(self.claims), phone_number=self.phone)

    def set_custom_user_claims(self, uid, claims):
        self.writes.append((uid, dict(claims)))
        self.claims = dict(claims)


def run(argv, auth):
    lines = []
    code = grant_finance.main(argv, auth=auth, require_adc=lambda: None, out=lines.append)
    return code, lines


def test_granting_keeps_every_other_claim():
    auth = FakeAuth({"verified": True, "coachV": "active", "admin": True})
    code, lines = run(["--uid", "uFin"], auth)
    assert code == 0
    assert auth.writes == [("uFin", {"verified": True, "coachV": "active", "admin": True, "finance": True})]
    assert lines == ["uFin: finance granted"]


def test_granting_twice_writes_once():
    auth = FakeAuth({"verified": True})
    run(["--uid", "uFin"], auth)
    code, lines = run(["--uid", "uFin"], auth)
    assert code == 0 and len(auth.writes) == 1
    assert lines == ["uFin: already finance, nothing written"]


def test_revoking_removes_only_finance():
    auth = FakeAuth({"verified": True, "finance": True, "womanReviewer": True})
    code, lines = run(["--uid", "uFin", "--revoke"], auth)
    assert code == 0
    assert auth.writes == [("uFin", {"verified": True, "womanReviewer": True})]
    assert lines == ["uFin: finance removed"]


def test_revoking_without_the_claim_writes_nothing():
    auth = FakeAuth({"verified": True})
    code, lines = run(["--uid", "uFin", "--revoke"], auth)
    assert code == 0 and auth.writes == []
    assert lines == ["uFin: already not finance, nothing written"]


def test_check_never_writes():
    auth = FakeAuth({"finance": True})
    code, lines = run(["--uid", "uFin", "--check"], auth)
    assert code == 0 and auth.writes == [] and lines == ["uFin: finance yes"]
    auth = FakeAuth({"admin": True})
    assert run(["--uid", "uFin", "--check"], auth)[1] == ["uFin: finance no"]


def test_the_admin_claim_does_not_count_as_finance():
    auth = FakeAuth({"admin": True})
    run(["--uid", "uFin"], auth)
    assert auth.writes[0][1] == {"admin": True, "finance": True}


def test_an_unknown_uid_is_reported_and_nothing_is_written():
    auth = FakeAuth()
    code, lines = run(["--uid", "uNobody"], auth)
    assert code == 1 and auth.writes == [] and lines == ["no account with uid uNobody"]


def test_an_account_without_a_phone_is_warned_about():
    _, lines = run(["--uid", "uFin"], FakeAuth(phone=None))
    assert any("no phone number" in line for line in lines)


def test_a_blank_uid_is_refused_before_credentials_are_touched():
    called = []
    code = grant_finance.main(
        ["--uid", "  "], auth=FakeAuth(), require_adc=lambda: called.append(True), out=lambda _l: None
    )
    assert code == 2 and called == []


def test_revoke_and_check_cannot_be_combined():
    with pytest.raises(SystemExit):
        grant_finance.main(
            ["--uid", "uFin", "--revoke", "--check"], auth=FakeAuth(),
            require_adc=lambda: None, out=lambda _l: None,
        )


def test_without_owner_credentials_it_refuses(monkeypatch):
    import google.auth

    monkeypatch.delenv("FIREBASE_AUTH_EMULATOR_HOST", raising=False)

    def no_credentials():
        raise google.auth.exceptions.DefaultCredentialsError("none")

    monkeypatch.setattr(google.auth, "default", no_credentials)
    with pytest.raises(SystemExit) as refused:
        grant_finance.main(["--uid", "uFin"], auth=FakeAuth(), out=lambda _l: None)
    assert "refused" in str(refused.value)
