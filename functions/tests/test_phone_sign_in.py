"""N1: the women-facing callables accept a phone sign-in only.

Email/password, Google and Apple sign-in are enabled in the project's console.
Without this check anyone could create accounts with no SMS step and reach the
callables, multiplying the per-uid caps, draining the global daily limit and
flooding the review queue. Order: App Check, then auth, then the provider.

Reviewers and admins may also use "password". delete_account takes ANY
provider: everyone who has an account may erase it (Protected List 6).
"""

from __future__ import annotations

import types

import pytest
from firebase_functions import https_fn

import main
from identity import reasons
from tests.test_entrypoints import FakeApp, request

USER_CALLABLES = (
    "record_consent",
    "record_health_consent",
    "start_verification",
    "verify_identity",
    "request_review",
    "record_signup_role",
    "submit_coach_certificate",
    "accept_coach_terms",
    "submit_coach_agreement",
    "create_coach_invite",
    "accept_coach_invite",
    "record_meal_photo_consent",
    "withdraw_meal_photo_consent",
    "record_consent_choice",
    "analyze_meal_photo",
    "claim_fast_verification",
    "list_reviewers",
    "list_review_slots",
    "book_review_slot",
    "register_for_event",
    "cancel_event_registration",
)
STAFF_CALLABLES = (
    "list_verification_flags",
    "get_review_contact",
    "schedule_verification_review",
    "decide_verification_flag",
)
NOT_PHONE = ("password", "google.com", "apple.com", "anonymous", "custom", None)


class _Tripwire(types.ModuleType):
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
    return hits


def _token(provider, **claims):
    token = dict(claims)
    token["firebase"] = {} if provider is None else {"sign_in_provider": provider}
    return token


def _call(name, req):
    import inspect

    return inspect.unwrap(getattr(main, name))(req)


def test_the_reason_code_exists():
    assert reasons.PHONE_SIGN_IN_REQUIRED == "phone_sign_in_required"
    assert reasons.PHONE_SIGN_IN_REQUIRED in reasons.ALL
    assert reasons.to_user_safe([reasons.PHONE_SIGN_IN_REQUIRED]) == []


@pytest.mark.parametrize("provider", NOT_PHONE)
@pytest.mark.parametrize("name", USER_CALLABLES)
def test_a_user_callable_refuses_anything_but_phone(name, provider, wired):
    with pytest.raises(https_fn.HttpsError) as caught:
        _call(name, request({}, token=_token(provider)))
    assert caught.value.code == https_fn.FunctionsErrorCode.PERMISSION_DENIED
    assert caught.value.message == reasons.PHONE_SIGN_IN_REQUIRED
    assert wired == [], "no business logic for a non-phone account"


@pytest.mark.parametrize("name", USER_CALLABLES)
def test_a_token_with_no_firebase_claim_is_refused(name, wired):
    from tests.test_entrypoints import FakeAuth

    req = https_fn.CallableRequest(
        data={}, raw_request=None, app=FakeApp(), auth=FakeAuth("uid-1", {})
    )
    req.auth.token = {}
    with pytest.raises(https_fn.HttpsError) as caught:
        _call(name, req)
    assert caught.value.message == reasons.PHONE_SIGN_IN_REQUIRED
    assert wired == []


@pytest.mark.parametrize("name", USER_CALLABLES)
def test_a_phone_account_gets_past_the_provider_check(name, wired):
    try:
        _call(name, request({"path": "niqab", "consentVersion": 1, "granted": True},
                            token=_token("phone")))
    except https_fn.HttpsError as error:
        assert error.message != reasons.PHONE_SIGN_IN_REQUIRED
    except AssertionError:
        pass  # the tripwire: business logic was reached


@pytest.mark.parametrize("name", USER_CALLABLES + STAFF_CALLABLES + ("delete_account",))
def test_app_check_comes_before_the_provider(name, wired):
    with pytest.raises(https_fn.HttpsError) as caught:
        _call(name, request({}, token=_token("password"), app=False))
    assert caught.value.message == reasons.APP_CHECK_MISSING


@pytest.mark.parametrize("name", USER_CALLABLES + STAFF_CALLABLES + ("delete_account",))
def test_auth_comes_before_the_provider(name, wired):
    with pytest.raises(https_fn.HttpsError) as caught:
        _call(name, request({}, uid=None))
    assert caught.value.code == https_fn.FunctionsErrorCode.UNAUTHENTICATED


@pytest.mark.parametrize("provider", ("phone", "password"))
@pytest.mark.parametrize("name", STAFF_CALLABLES)
def test_a_reviewer_may_use_phone_or_password(name, provider, wired):
    with pytest.raises(AssertionError, match="business logic reached"):
        _call(name, request({"approve": True}, uid="rev",
                            token=_token(provider, womanReviewer=True)))


@pytest.mark.parametrize("provider", ("google.com", "apple.com", "anonymous", None))
@pytest.mark.parametrize("name", STAFF_CALLABLES)
def test_a_reviewer_on_another_provider_is_refused(name, provider, wired):
    with pytest.raises(https_fn.HttpsError) as caught:
        _call(name, request({"approve": True}, uid="rev",
                            token=_token(provider, womanReviewer=True, admin=True)))
    assert caught.value.code == https_fn.FunctionsErrorCode.PERMISSION_DENIED
    assert caught.value.message == reasons.PHONE_SIGN_IN_REQUIRED
    assert wired == []


@pytest.mark.parametrize("provider", ("phone", "password"))
def test_an_admin_may_read_the_queue_with_phone_or_password(provider, wired):
    with pytest.raises(AssertionError, match="business logic reached"):
        _call("list_verification_flags",
              request({}, uid="adm", token=_token(provider, admin=True)))


@pytest.mark.parametrize("provider", ("phone", "password"))
def test_the_admin_guard_accepts_phone_or_password(provider):
    req = request({}, uid="adm", token=_token(provider, admin=True))
    assert main._require_admin(req) == "adm"


def test_the_admin_guard_refuses_google():
    req = request({}, uid="adm", token=_token("google.com", admin=True))
    with pytest.raises(https_fn.HttpsError) as caught:
        main._require_admin(req)
    assert caught.value.message == reasons.PHONE_SIGN_IN_REQUIRED


@pytest.mark.parametrize("provider", ("phone",) + NOT_PHONE)
def test_any_account_may_delete_itself(provider, monkeypatch):
    """Protected List 6: erasure is open to every provider."""
    from account import deletion

    ran = []
    monkeypatch.setattr(deletion, "FirebaseBackend", lambda: object())
    monkeypatch.setattr(
        deletion, "run", lambda uid, backend, deadline=None: ran.append(uid) or {"state": "done"}
    )
    answer = _call("delete_account", request({}, token=_token(provider)))
    assert ran == ["uid-1"]
    assert answer["state"] == "done"
