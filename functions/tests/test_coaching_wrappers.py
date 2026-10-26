"""The coaching callables in main.py: what each guard does before any module
runs. Every member and coach callable named in the contract refuses while the
switch of its group is off (portfolio, clients or payments), a coach callable
refuses a woman who is not verified, and each staff callable holds to the claim
its `who` line names."""

from __future__ import annotations

import inspect
import json
import os

import pytest
from firebase_functions import https_fn

import coaching
import main
from tests import fake_firestore
from tests.test_entrypoints import inner, raises, request

CONTRACT = json.load(
    open(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "contracts", "coaching_contract.json"), encoding="utf-8")
)
CALLABLES = CONTRACT["callables"]

DENIED = https_fn.FunctionsErrorCode.PERMISSION_DENIED
CLOSED = https_fn.FunctionsErrorCode.FAILED_PRECONDITION
INVALID = https_fn.FunctionsErrorCode.INVALID_ARGUMENT
UNAUTH = https_fn.FunctionsErrorCode.UNAUTHENTICATED

PHONE = {"firebase": {"sign_in_provider": "phone"}}
PASSWORD = {"firebase": {"sign_in_provider": "password"}}


def kind_of(who: str) -> str:
    who = who.strip()
    if who.startswith("finance"):
        return "finance"
    if who.startswith("admin"):
        return "admin"
    if who.startswith("womanReviewer"):
        return "reviewer"
    if who.startswith("coach"):
        return "coach"
    return "member"


KINDS = {name: kind_of(row["who"]) for name, row in CALLABLES.items()}
MEMBER_SIDE = sorted(
    name for name, kind in KINDS.items() if kind in ("member", "coach") and name != "record_signup_role"
)
REVIEWER_ONLY = {"list_portfolio_media", "decide_portfolio_media"}  # admins never see these photos
COACH_SIDE = sorted(name for name, kind in KINDS.items() if kind == "coach")
STAFF_SIDE = sorted(name for name, kind in KINDS.items() if kind in ("finance", "admin", "reviewer"))


PORTFOLIO = {
    "record_signup_role", "submit_coach_application", "update_coach_profile",
    "save_coach_package",
    "add_portfolio_media", "remove_portfolio_media", "confirm_portfolio_consent",
}
PAYMENTS = {"submit_payment_proof", "request_cancellation", "request_payout_account_change"}
# The weekly check-in has a second switch (CHECK_INS_LIVE) on top of the clients one.
CHECK_INS = {"submit_check_in", "coach_needs_attention"}
CLIENTS = set(MEMBER_SIDE) - PORTFOLIO - PAYMENTS - CHECK_INS | {"request_coaching"}
SWITCHES = {
    "COACH_PORTFOLIO_LIVE": PORTFOLIO,
    "COACH_CLIENTS_LIVE": CLIENTS,
    "COACH_PAYMENTS_LIVE": PAYMENTS,
}


def switches(monkeypatch, **on):
    for name in SWITCHES:
        monkeypatch.setattr(coaching, name, on.get(name, False))


class NoBucket:
    def __getattr__(self, name):
        pytest.fail("the bucket was used")


@pytest.fixture
def world(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(main.store, "db", lambda: db)
    monkeypatch.setattr(main, "_PersonalBlobs", lambda: NoBucket())
    switches(monkeypatch)
    return db


def call(name, data=None, *, token=None, uid="uid-1"):
    claims = {**PHONE, **(token or {})}
    return inner(name)(request(data or {}, uid=uid, token=claims))


def refusal(name, **kw):
    with pytest.raises(https_fn.HttpsError) as caught:
        call(name, **kw)
    return caught.value


def test_every_member_or_coach_callable_belongs_to_one_switch():
    assert PORTFOLIO | CLIENTS | PAYMENTS | CHECK_INS == set(MEMBER_SIDE) | {"record_signup_role"}
    assert not PORTFOLIO & CLIENTS and not CLIENTS & PAYMENTS and not PORTFOLIO & PAYMENTS
    assert "mark_thread_read" in CLIENTS and "request_coaching" in CLIENTS


def test_the_contract_lists_every_callable_this_file_maps():
    assert set(KINDS.values()) == {"finance", "admin", "reviewer", "coach", "member"}
    assert COACH_SIDE == [
        "add_portfolio_media", "coach_needs_attention", "confirm_portfolio_consent",
        "publish_coach_plan", "remove_portfolio_media", "request_payout_account_change",
        "respond_coaching_request", "review_client_health", "save_coach_package",
        "schedule_live_session", "update_coach_profile",
    ]
    for name in CALLABLES:
        assert callable(getattr(main, name)), name


# ------------------------------------------------------------ app switched off


@pytest.mark.parametrize("name", MEMBER_SIDE)
def test_a_member_or_coach_callable_refuses_while_its_switch_is_off(name, world):
    token = {"verified": True, "coachV": "active"}
    error = refusal(name, token=token, data={"imageJpeg": "not-base64!!"})
    assert error.code == CLOSED and error.message == "coach_app_closed"
    assert world.docs == {}


def test_the_role_choice_refuses_a_coach_role_while_the_coach_app_is_off(world):
    error = refusal("record_signup_role", data={"role": "coach"}, token={"verified": True})
    assert error.code == CLOSED and error.message == "coach_app_closed"
    assert world.docs == {}


def test_the_payment_proof_is_refused_before_its_image_is_decoded(world, monkeypatch):
    monkeypatch.setattr(main, "_decode_image", lambda *a, **k: pytest.fail("decoded"))
    error = refusal("submit_payment_proof", token={"verified": True}, data={"imageJpeg": "AAAA"})
    assert error.message == "coach_app_closed"


def test_the_message_trigger_does_nothing_while_the_clients_switch_is_off(world, monkeypatch):
    from types import SimpleNamespace

    monkeypatch.setattr(main.store, "db", lambda: pytest.fail("the database was opened"))
    event = SimpleNamespace(data=SimpleNamespace(to_dict=lambda: {"text": "hi"}), params={"relId": "r", "messageId": "m"})
    assert inspect.unwrap(main.on_coaching_message)(event) is None
    assert world.docs == {}


@pytest.mark.parametrize("on", sorted(SWITCHES))
def test_one_switch_on_opens_only_its_own_group(on, world, monkeypatch):
    switches(monkeypatch, **{on: True})
    monkeypatch.setattr(main, "_decode_image", lambda *a, **k: None)
    token = {"verified": True, "coachV": "active"}
    for switch, names in SWITCHES.items():
        for name in names:
            if name == "record_signup_role":
                continue
            with pytest.raises(https_fn.HttpsError) as caught:
                call(name, token=token, data={})
            closed = caught.value.message == "coach_app_closed"
            assert closed == (switch != on), (name, on, caught.value.message)


@pytest.mark.parametrize("name", sorted(CHECK_INS))
def test_the_check_in_callables_need_both_the_clients_and_the_check_in_switch(name, world, monkeypatch):
    token = {"verified": True, "coachV": "active"}
    for clients, check_ins in ((False, False), (True, False), (False, True)):
        switches(monkeypatch, COACH_CLIENTS_LIVE=clients)
        monkeypatch.setattr(coaching, "CHECK_INS_LIVE", check_ins)
        error = refusal(name, token=token, data={})
        assert error.code == CLOSED and error.message == "coach_app_closed", (clients, check_ins)
    switches(monkeypatch, COACH_CLIENTS_LIVE=True)
    monkeypatch.setattr(coaching, "CHECK_INS_LIVE", True)
    assert refusal(name, token=token, data={}).message != "coach_app_closed"


def test_the_role_choice_runs_with_the_portfolio_switch_alone(world, monkeypatch):
    switches(monkeypatch, COACH_PORTFOLIO_LIVE=True)
    answer = call("record_signup_role", data={"role": "coach"}, token={"verified": True, "coachV": "active"})
    assert answer["held"] == ["coach"]


# --------------------------------------------------- the women-only check


@pytest.fixture
def live(monkeypatch):
    switches(monkeypatch, COACH_PORTFOLIO_LIVE=True, COACH_CLIENTS_LIVE=True, COACH_PAYMENTS_LIVE=True)
    monkeypatch.setattr(coaching, "CHECK_INS_LIVE", True)


@pytest.mark.parametrize("name", MEMBER_SIDE)
def test_every_member_and_coach_callable_refuses_a_woman_who_is_not_verified(name, world, live):
    error = refusal(name, token={"coachV": "active"})
    assert error.code == DENIED and error.message == "not_verified"
    assert world.docs == {}


@pytest.mark.parametrize("name", COACH_SIDE)
def test_the_coach_callables_check_verification_before_the_coach_claim(name, world, live):
    error = refusal(name, token={})
    assert error.message == "not_verified"
    error = refusal(name, token={"verified": True})
    assert error.code == DENIED and error.message == "not_a_coach"
    if name != "remove_portfolio_media":  # a suspended coach may take her own photos down
        error = refusal(name, token={"verified": True, "coachV": "suspended"})
        assert error.code == DENIED and error.message == "coach_suspended"
    assert world.docs == {}


@pytest.mark.parametrize("name", sorted(set(MEMBER_SIDE) - set(COACH_SIDE)))
def test_a_verified_member_gets_past_the_guards_and_meets_the_module(name, world, live):
    error = refusal(name, token={"verified": True}, data={})
    assert error.code == INVALID, name
    assert world.docs == {}


# ------------------------------------------------------ staff, by the contract


@pytest.mark.parametrize("name", STAFF_SIDE)
def test_a_member_never_passes_a_staff_guard(name, world, live):
    error = refusal(name, token={"verified": True, "coachV": "active"})
    assert error.code == DENIED
    assert world.docs == {}


@pytest.mark.parametrize("name", STAFF_SIDE)
def test_a_staff_callable_needs_a_signed_in_caller(name, world, live):
    with pytest.raises(https_fn.HttpsError) as caught:
        inner(name)(request({}, uid=None))
    assert caught.value.code == UNAUTH


@pytest.mark.parametrize("name", [n for n in STAFF_SIDE if KINDS[n] == "admin"])
def test_admin_only_callables_refuse_finance_and_reviewers(name, world, live):
    for claim in ({"finance": True}, {"womanReviewer": True}):
        error = refusal(name, token={**PASSWORD, **claim})
        assert error.code == DENIED
    assert world.docs == {}


@pytest.mark.parametrize("name", [n for n in STAFF_SIDE if KINDS[n] == "finance"])
def test_finance_callables_refuse_a_reviewer(name, world, live):
    error = refusal(name, token={**PASSWORD, "womanReviewer": True})
    assert error.code == DENIED
    assert world.docs == {}


@pytest.mark.parametrize("name", [n for n in STAFF_SIDE if KINDS[n] == "reviewer"])
def test_reviewer_callables_refuse_finance(name, world, live):
    error = refusal(name, token={**PASSWORD, "finance": True})
    assert error.code == DENIED
    assert world.docs == {}


def test_require_finance_admits_finance_and_admin_and_refuses_the_rest():
    def guard(token, uid="uid-1"):
        return main._require_finance(request({}, uid=uid, token={**PASSWORD, **token}))

    assert guard({"finance": True}) == "uid-1"
    assert guard({"admin": True}, uid="boss") == "boss"
    raises(lambda: guard({"womanReviewer": True}), DENIED)
    raises(lambda: guard({}), DENIED)
    raises(lambda: guard({"verified": True, "coachV": "active"}), DENIED)


# ------------------------------------------- the switched-on wiring of the two jobs


def test_the_sweeper_hands_the_bucket_to_the_sweep_and_runs_the_claim_retry(world, live, monkeypatch):
    from types import SimpleNamespace

    from coaching import applications, subscriptions

    seen = {}

    def sweep(db, *, now, notify, blobs=None, clients=True, payments=False):
        seen["sweep"] = {"db": db, "notify": notify, "blobs": blobs, "clients": clients, "payments": payments}
        return {"staleProofImages": 0}

    def retry(db, *, merge_claims):
        seen["retry"] = {"db": db, "merge_claims": merge_claims}
        return 0

    bucket = object()
    monkeypatch.setattr(subscriptions, "sweep", sweep)
    monkeypatch.setattr(applications, "retry_claims", retry)
    monkeypatch.setattr(main, "_PersonalBlobs", lambda: bucket)
    assert inspect.unwrap(main.coaching_sweeper)(SimpleNamespace()) is None
    assert seen["sweep"]["blobs"] is bucket and seen["sweep"]["notify"] is main._coaching_notify
    assert seen["retry"]["merge_claims"] is main._coaching_merge_claims
    assert seen["sweep"]["db"] is world and seen["retry"]["db"] is world
    assert seen["sweep"]["clients"] is True and seen["sweep"]["payments"] is True


def test_the_claim_retry_runs_even_with_clients_and_payments_off(world, monkeypatch):
    from types import SimpleNamespace

    from coaching import applications, subscriptions

    ran = []
    monkeypatch.setattr(applications, "retry_claims", lambda db, **kw: ran.append("retry"))
    monkeypatch.setattr(subscriptions, "sweep", lambda *a, **k: pytest.fail("the sweep ran"))
    assert inspect.unwrap(main.coaching_sweeper)(SimpleNamespace()) is None
    assert ran == ["retry"]


@pytest.mark.parametrize("on, expected", [("COACH_CLIENTS_LIVE", (True, False)), ("COACH_PAYMENTS_LIVE", (False, True))])
def test_the_sweeper_passes_each_switch_to_its_own_parts(on, expected, world, monkeypatch):
    from types import SimpleNamespace

    from coaching import applications, subscriptions

    switches(monkeypatch, **{on: True})
    seen = {}
    monkeypatch.setattr(applications, "retry_claims", lambda db, **kw: 0)
    monkeypatch.setattr(
        subscriptions, "sweep",
        lambda db, **kw: seen.update(clients=kw["clients"], payments=kw["payments"]) or {"staleProofImages": 0},
    )
    monkeypatch.setattr(main, "_PersonalBlobs", lambda: object())
    inspect.unwrap(main.coaching_sweeper)(SimpleNamespace())
    assert (seen["clients"], seen["payments"]) == expected


def test_a_failing_claim_retry_does_not_stop_the_sweeper(world, live, monkeypatch):
    from types import SimpleNamespace

    from coaching import applications, subscriptions

    monkeypatch.setattr(subscriptions, "sweep", lambda db, **kw: {"staleProofImages": 0})
    monkeypatch.setattr(applications, "retry_claims", lambda *a, **k: (_ for _ in ()).throw(RuntimeError("auth down")))
    monkeypatch.setattr(main, "_PersonalBlobs", lambda: object())
    assert inspect.unwrap(main.coaching_sweeper)(SimpleNamespace()) is None


def test_the_message_trigger_reaches_the_chat_module_when_the_app_is_on(world, live, monkeypatch):
    from types import SimpleNamespace

    from coaching import chat

    seen = []
    monkeypatch.setattr(chat, "on_message", lambda db, rel, message, data, **kw: seen.append((rel, message, data)))
    event = SimpleNamespace(data=SimpleNamespace(to_dict=lambda: {"text": "hi"}), params={"relId": "r", "messageId": "m"})
    assert inspect.unwrap(main.on_coaching_message)(event) is None
    assert seen == [("r", "m", {"text": "hi"})]


def test_confirming_a_payout_account_needs_the_payments_switch(world, monkeypatch):
    switches(monkeypatch, COACH_PORTFOLIO_LIVE=True, COACH_CLIENTS_LIVE=True)
    error = refusal("confirm_payout_account", token={**PASSWORD, "finance": True}, data={"uid": "c", "decision": "confirm"})
    assert error.code == CLOSED and error.message == "coach_app_closed"
    switches(monkeypatch, COACH_PAYMENTS_LIVE=True)
    error = refusal("confirm_payout_account", token={**PASSWORD, "finance": True}, data={"uid": "c", "decision": "confirm"})
    assert error.message == "not_a_coach"


def test_the_application_drops_its_payout_while_payments_are_off(world, monkeypatch):
    from coaching import applications

    seen = []
    monkeypatch.setattr(applications, "submit", lambda *a, **kw: seen.append(kw["payments_live"]) or {})
    switches(monkeypatch, COACH_PORTFOLIO_LIVE=True)
    call("submit_coach_application", token={"verified": True})
    switches(monkeypatch, COACH_PORTFOLIO_LIVE=True, COACH_PAYMENTS_LIVE=True)
    call("submit_coach_application", token={"verified": True})
    assert seen == [False, True]


def _block_event(blocker="a", blocked="b"):
    from types import SimpleNamespace

    return SimpleNamespace(params={"uid": blocker, "otherUid": blocked})


def test_the_block_trigger_does_nothing_while_the_clients_switch_is_off(world, monkeypatch):
    monkeypatch.setattr(main.store, "db", lambda: pytest.fail("the database was opened"))
    assert inspect.unwrap(main.on_coaching_block)(_block_event()) is None


def test_the_block_trigger_ends_the_coaching_between_the_two_when_the_app_is_on(world, live, monkeypatch):
    from coaching import subscriptions

    seen = []
    monkeypatch.setattr(subscriptions, "end_for_block", lambda db, a, b, **kw: seen.append((a, b)))
    assert inspect.unwrap(main.on_coaching_block)(_block_event("a", "b")) is None
    assert seen == [("a", "b")]


# --------------------------------------- each callable holds to its `who` line


def _guards_called(name: str) -> set:
    import ast

    tree = ast.parse(inspect.getsource(inner(name)).lstrip())
    called = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id.startswith("_require"):
            called.add(node.func.id)
            if node.func.id == "_require_woman_reviewer" and name not in REVIEWER_ONLY:
                assert any(k.arg == "allow_admin" and getattr(k.value, "value", None) is True for k in node.keywords), name
    return called


@pytest.mark.parametrize("name", sorted(CALLABLES))
def test_each_wrapper_calls_the_guard_its_who_line_names(name):
    kind = KINDS[name]
    called = _guards_called(name)
    if kind == "finance":
        assert called == {"_require_finance"}
    elif kind == "admin":
        assert called == {"_require_admin"}
    elif kind == "reviewer":
        assert called == {"_require_woman_reviewer"}
    elif name == "record_signup_role":
        assert called == {"_require_auth"}
    elif name in ("submit_coach_application", "request_coaching"):
        # These two check verification inside their module, with the claim passed in.
        assert called == {"_require_auth"}
        assert "_verified(request)" in inspect.getsource(inner(name))
    else:
        assert called == {"_require_auth", "_require_verified"}


# ------------------------------------------------- the shared staff-claim guard

def _token(**claims):
    return {**PHONE, **claims}


@pytest.mark.parametrize(
    "guard,kwargs,claims,allowed",
    [
        ("_require_finance", {}, {"finance": True}, True),
        ("_require_finance", {}, {"admin": True}, True),
        ("_require_finance", {}, {"womanReviewer": True}, False),
        ("_require_finance", {}, {"verified": True, "coachV": "active"}, False),
        ("_require_woman_reviewer", {}, {"womanReviewer": True}, True),
        ("_require_woman_reviewer", {}, {"admin": True}, False),
        ("_require_woman_reviewer", {"allow_admin": True}, {"admin": True}, True),
        ("_require_woman_reviewer", {"allow_admin": True}, {"finance": True}, False),
    ],
)
def test_the_staff_guards_hold_to_their_own_claims(guard, kwargs, claims, allowed):
    req = request({}, token=_token(**claims))
    if allowed:
        assert getattr(main, guard)(req, **kwargs) == "uid-1"
    else:
        raises(lambda: getattr(main, guard)(req, **kwargs), DENIED)


def test_a_staff_guard_takes_a_password_sign_in_too_and_refuses_another_provider():
    assert main._require_finance(request({}, token={**PASSWORD, "finance": True})) == "uid-1"
    other = {"firebase": {"sign_in_provider": "google.com"}, "finance": True}
    raises(lambda: main._require_finance(request({}, token=other)), DENIED)


def test_the_certificate_check_asks_the_personal_bucket(monkeypatch):
    class Bucket:
        def exists(self, path):
            return path == "coach-docs/u/certificates/a.jpg"

    monkeypatch.setattr(main, "_PersonalBlobs", lambda: Bucket())
    assert main._coach_object_exists("coach-docs/u/certificates/a.jpg") is True
    assert main._coach_object_exists("elsewhere") is False

    def down():
        raise RuntimeError("no credentials")

    monkeypatch.setattr(main, "_PersonalBlobs", down)
    assert main._coach_object_exists("coach-docs/u/certificates/a.jpg") is False
