"""The callables themselves: the guards that run before any work is done.

Everything else in this suite tests a pure module with hand-built inputs. That
is the right way to test a decision matrix and the wrong way to find out whether
the ENTRY POINT refuses a bad request cheaply — and the entry point is where the
money is spent, because it is the thing an attacker can reach.

Two defects found in this file's absence are the reason it exists:

  * the frame count was validated AFTER the whole list had been base64-decoded,
    and not at all when `niqabPath` was true;
  * spec §6's global kill switch was checked in start_verification, which is
    free, and not in verify_identity, which is the only callable that spends
    money — and which needs no session to reach Cloud Vision, since OCR is step
    3 and the liveness session is not consulted until step 6.

The function bodies are exercised with the decorators unwrapped, so these are
about the code in main.py and not about the firebase-functions decorator. The
decorator's own configuration is asserted separately, over the syntax tree,
because `enforce_app_check` is a deploy-time option whose absence would not show
up in any behavioural test.
"""

from __future__ import annotations

import ast
import inspect
import os

import pytest
from firebase_functions import https_fn

import main
from identity import config, reasons

_MAIN = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "main.py"
)

CALLABLES = {
    "record_consent",
    "start_verification",
    "verify_identity",
    "list_verification_flags",
    "schedule_verification_review",
    "decide_verification_flag",
    "request_review",
    "get_review_contact",
    "delete_account",
    "record_health_consent",
}


# ------------------------------------------------------------------ fixtures


class FakeAuth:
    def __init__(self, uid="uid-1", token=None):
        self.uid = uid
        self.token = token or {}


class FakeApp:
    app_id = "app-1"


def request(data, *, uid="uid-1", token=None, app=True):
    """A CallableRequest with the two credentials the guards look at."""
    return https_fn.CallableRequest(
        data=data,
        raw_request=None,
        app=FakeApp() if app else None,
        auth=FakeAuth(uid, token) if uid else None,
    )


def body(**overrides):
    """A request body that would otherwise sail through every guard."""
    payload = {
        "front": "AAAA",
        "back": "AAAA",
        "frames": ["AAAA", "AAAA", "AAAA"],
        "liveness": {"sessionId": "s-1"},
        "operationId": "op-1",
    }
    payload.update(overrides)
    return payload


@pytest.fixture
def stubbed(monkeypatch):
    """Consent granted, kill switch open, and a tripwire on everything paid.

    `_deps` raising means any test that reaches the pipeline fails loudly rather
    than silently trying to open a Firestore client.
    """
    calls = {"consent": 0, "daily": 0, "decoded": 0}

    def has_consent(uid):
        calls["consent"] += 1
        return True

    def daily(field="sessions"):
        calls["daily"] += 1
        calls["daily_field"] = field
        calls.setdefault("order", []).append("global")
        return 1

    real_decode = main._decode_image

    def counting_decode(value, budget_left):
        calls["decoded"] += 1
        return real_decode(value, budget_left)

    def no_deps():
        raise AssertionError("the pipeline was reached when it must not be")

    monkeypatch.setattr(main.store, "has_consent", has_consent)
    monkeypatch.setattr(main.store, "daily_count_and_increment", daily)
    monkeypatch.setattr(main.store, "verification_gate", lambda uid: main.store.Gate())

    def per_uid(uid, field):
        calls["per_uid"] = calls.get("per_uid", 0) + 1
        calls["per_uid_field"] = field
        calls.setdefault("order", []).append("per_uid")
        return 1

    monkeypatch.setattr(main.store, "uid_daily_count_and_increment", per_uid)
    monkeypatch.setattr(main, "_decode_image", counting_decode)
    monkeypatch.setattr(main, "_deps", no_deps)
    return calls


def inner(name):
    """The function as main.py wrote it, with both decorator layers removed.

    `https_fn.on_call` wraps twice: an outer Flask view that expects a
    werkzeug Request, and an inner adapter. `inspect.unwrap` walks to the
    bottom, which is the body these tests are about. The decorator's own
    configuration is asserted separately, over the syntax tree.
    """
    return inspect.unwrap(getattr(main, name))


def raises(fn, code):
    with pytest.raises(https_fn.HttpsError) as caught:
        fn()
    assert caught.value.code == code, f"expected {code}, got {caught.value.code}"
    return caught.value


# ------------------------------------------------------- App Check and auth


def test_every_callable_declares_app_check_enforcement():
    """`enforce_app_check` is a deploy-time option, so assert it in the source.

    A callable that lost this argument would behave identically in every
    behavioural test and would be open to any script with a stolen ID token in
    production. config.ENFORCE_APP_CHECK is True, and this checks that each
    decorator actually reads it.
    """
    tree = ast.parse(open(_MAIN, encoding="utf-8").read())
    seen = set()

    for node in ast.walk(tree):
        if not isinstance(node, ast.FunctionDef) or node.name not in CALLABLES:
            continue
        seen.add(node.name)
        enforced = False
        for decorator in node.decorator_list:
            if not isinstance(decorator, ast.Call):
                continue
            for keyword in decorator.keywords:
                if keyword.arg == "enforce_app_check":
                    enforced = True
        assert enforced, f"{node.name} does not pass enforce_app_check"

    assert seen == CALLABLES, f"callables not found in main.py: {CALLABLES - seen}"


@pytest.mark.parametrize("name", sorted(CALLABLES))
def test_no_callable_does_any_work_for_an_unauthenticated_caller(name, stubbed):
    fn = inner(name)
    raises(
        lambda: fn(request(body(), uid=None)),
        https_fn.FunctionsErrorCode.UNAUTHENTICATED,
    )
    assert stubbed["consent"] == 0, "not even a consent read before auth"
    assert stubbed["decoded"] == 0


@pytest.mark.parametrize("name", sorted(CALLABLES))
def test_no_callable_does_any_work_without_an_app_check_token(name, stubbed):
    # The decorator is the real gate, but main._require_auth re-checks because a
    # silently unenforced deploy would not show up in any test.
    fn = inner(name)
    raises(
        lambda: fn(request(body(), app=False)),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert stubbed["consent"] == 0
    assert stubbed["decoded"] == 0


# --------------------------------------------------------- the admin surface


def test_an_ordinary_account_cannot_read_the_review_queue(stubbed):
    raises(
        lambda: inner("list_verification_flags")(request({})),
        https_fn.FunctionsErrorCode.PERMISSION_DENIED,
    )


@pytest.mark.parametrize(
    "name", ["schedule_verification_review", "decide_verification_flag"]
)
def test_the_live_review_callables_need_the_woman_reviewer_claim(name, stubbed):
    fn = inner(name)
    # An ordinary account is refused.
    raises(
        lambda: fn(request({"flagId": "f-1", "route": "video"})),
        https_fn.FunctionsErrorCode.PERMISSION_DENIED,
    )
    # And so is a plain admin. The separation is the point: an admin
    # administers a system, a woman reviewer meets a woman.
    raises(
        lambda: fn(request({"flagId": "f-1", "route": "video"}, token={"admin": True})),
        https_fn.FunctionsErrorCode.PERMISSION_DENIED,
    )


def test_an_admin_claim_a_client_invented_is_not_a_claim_at_all():
    # The claim is read from the verified ID token, never from the request body.
    # This is the shape of the attack, asserted so nobody wires the body in.
    raises(
        lambda: inner("list_verification_flags")(
            request({"admin": True, "role": "admin"})
        ),
        https_fn.FunctionsErrorCode.PERMISSION_DENIED,
    )


# ------------------------------------------------ the payload, before decoding


def test_an_absurd_frame_count_is_refused_before_anything_is_decoded(stubbed):
    error = raises(
        lambda: inner("verify_identity")(
            request(body(frames=["AAAA"] * 500))
        ),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )
    assert error.message == reasons.IMAGE_TOO_LARGE
    assert stubbed["decoded"] == 0, (
        "500 frames must cost a list length, not 500 base64 decodes"
    )


def test_the_niqab_path_does_not_escape_the_frame_cap(stubbed):
    # The count used to be checked only on the non-niqab branch, so
    # `niqabPath: true` skipped it entirely while every frame was still decoded.
    raises(
        lambda: inner("verify_identity")(
            request(body(frames=["AAAA"] * 500, niqabPath=True))
        ),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )
    assert stubbed["decoded"] == 0


def test_the_frame_cap_is_exactly_config_max_selfie_frames(stubbed):
    # One over is refused. The limit is not weakened to make anything pass.
    raises(
        lambda: inner("verify_identity")(
            request(body(frames=["AAAA"] * (config.MAX_SELFIE_FRAMES + 1)))
        ),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )


def test_too_few_frames_is_refused(stubbed):
    raises(
        lambda: inner("verify_identity")(
            request(body(frames=["AAAA"] * (config.MIN_SELFIE_FRAMES - 1)))
        ),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )


@pytest.mark.parametrize("bad", [[], "a string", 42, None])
def test_a_body_that_is_not_an_object_is_a_clean_invalid_argument(bad, stubbed):
    # `request.data` is whatever the client sent. A list or a string would turn
    # every `.get` into an AttributeError and a 500 with a stack trace, for what
    # is plainly a bad request.
    if bad is None:
        return  # `None` is the legitimate empty body and becomes {}
    raises(
        lambda: inner("verify_identity")(request(bad)),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )


@pytest.mark.parametrize("bad", ["not-a-dict", 7, ["sessionId"]])
def test_a_malformed_liveness_block_does_not_raise_an_attribute_error(bad, stubbed):
    # It is refused for the frame floor or reaches the pipeline stub, but never
    # as an AttributeError rendered to the client as INTERNAL.
    with pytest.raises((https_fn.HttpsError, AssertionError)) as caught:
        inner("verify_identity")(request(body(liveness=bad)))
    assert not isinstance(caught.value, AttributeError)


@pytest.mark.parametrize("bad", ["AAA!", "not base64 at all", "", 5, None, {}])
def test_malformed_base64_is_refused_without_quoting_the_input(bad, stubbed):
    error = raises(
        lambda: inner("verify_identity")(request(body(front=bad))),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )
    # The message is a reason code, never the offending bytes: a base64 error
    # message can quote its input, which here is image data.
    assert error.message in {reasons.IMAGE_UNDECODABLE, reasons.IMAGE_TOO_LARGE}
    if str(bad):
        assert str(bad) not in str(error.message)


def test_an_oversized_image_is_refused_on_its_base64_length(stubbed):
    # Checked before decoding, so the bomb never materialises in memory.
    oversized = "A" * (4 * (config.MAX_IMAGE_BYTES // 3) + 8)
    error = raises(
        lambda: inner("verify_identity")(request(body(front=oversized))),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )
    assert error.message == reasons.IMAGE_TOO_LARGE


# ------------------------------------------------------- the global kill switch


def test_the_kill_switch_guards_the_callable_that_spends_money(monkeypatch, stubbed):
    def over_limit(field="sessions"):
        stubbed["daily_field"] = field
        return config.DAILY_VERIFICATION_LIMIT + 1

    monkeypatch.setattr(main.store, "daily_count_and_increment", over_limit)
    error = raises(
        lambda: inner("verify_identity")(request(body())),
        https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
    )
    assert error.message == reasons.DAILY_LIMIT_REACHED
    assert stubbed["decoded"] == 0, "refused before the payload is decoded"


def test_verify_identity_counts_against_its_own_daily_field(stubbed):
    # start_verification is free and counts `sessions`. verify_identity is the
    # only callable that calls Cloud Vision and must have its own counter, or a
    # caller who never starts a session is invisible to the global limit.
    with pytest.raises(AssertionError, match="pipeline was reached"):
        inner("verify_identity")(request(body()))
    assert stubbed["daily_field"] == main.store.DAILY_VERIFY_FIELD
    assert stubbed["daily_field"] != "sessions"


def test_start_verification_still_counts_sessions(monkeypatch, stubbed):
    monkeypatch.setattr(
        main.store, "FirestoreLedger", lambda: (_ for _ in ()).throw(AssertionError("x"))
    )
    with pytest.raises(AssertionError):
        inner("start_verification")(request({}))
    assert stubbed["daily_field"] == "sessions"


# ---------------------------------------------------------- the operation id


def test_an_unbounded_operation_id_is_replaced_rather_than_stored():
    # It lands in a list of the last 50 on the ledger document, and a Firestore
    # document is capped at 1 MiB. An unbounded string from the request body is
    # a way to make that document fail to write, which would jam the counter
    # that limits her spend.
    assert main._operation_id("x" * 10_000) != "x" * 10_000
    assert len(main._operation_id("x" * 10_000)) == 36


@pytest.mark.parametrize("bad", [None, "", 7, {"a": 1}, ["op"]])
def test_a_missing_or_malformed_operation_id_becomes_a_server_generated_one(bad):
    generated = main._operation_id(bad)
    assert isinstance(generated, str) and len(generated) == 36


def test_a_sane_operation_id_is_kept_so_a_double_tap_is_still_recognised():
    assert main._operation_id("11111111-2222-3333-4444-555555555555") == (
        "11111111-2222-3333-4444-555555555555"
    )


# --------------------------------------------------------------- consent

@pytest.mark.parametrize("name", ["start_verification", "verify_identity"])
def test_the_camera_callables_refuse_without_a_recorded_consent(
    name, monkeypatch, stubbed
):
    monkeypatch.setattr(main.store, "has_consent", lambda uid: False)
    fn = inner(name)
    error = raises(
        lambda: fn(request(body())),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert error.message == reasons.CONSENT_MISSING
    assert stubbed["decoded"] == 0


def test_consent_for_an_unrecognised_version_is_refused(stubbed):
    error = raises(
        lambda: inner("record_consent")(request({"consentVersion": 999})),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert error.message == reasons.CONSENT_MISSING


# ------------------------------------------- S21: consent is recorded once


def test_consent_already_on_file_is_a_no_op_with_the_same_answer(monkeypatch, stubbed):
    writes = {"n": 0}
    monkeypatch.setattr(main.store, "has_consent", lambda uid: True)
    monkeypatch.setattr(
        main.store, "write_consent", lambda uid: writes.__setitem__("n", writes["n"] + 1)
    )
    answer = inner("record_consent")(
        request({"consentVersion": config.CONSENT_VERSION})
    )
    assert answer == {"ok": True, "consentVersion": config.CONSENT_VERSION}
    assert writes["n"] == 0, "a second agreement must not write again"


def test_first_consent_is_written_exactly_once(monkeypatch, stubbed):
    writes = {"n": 0}
    monkeypatch.setattr(main.store, "has_consent", lambda uid: False)
    monkeypatch.setattr(
        main.store, "write_consent", lambda uid: writes.__setitem__("n", writes["n"] + 1)
    )
    answer = inner("record_consent")(
        request({"consentVersion": config.CONSENT_VERSION})
    )
    assert answer == {"ok": True, "consentVersion": config.CONSENT_VERSION}
    assert writes["n"] == 1


def test_an_unknown_version_is_refused_even_when_consent_is_on_file(monkeypatch, stubbed):
    monkeypatch.setattr(main.store, "has_consent", lambda uid: True)
    error = raises(
        lambda: inner("record_consent")(request({"consentVersion": 2})),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert error.message == reasons.CONSENT_MISSING


def test_delete_account_needs_only_a_signed_in_account(monkeypatch, stubbed):
    # Protected List 6: erasure is not gated on verification.
    from account import deletion

    ran = {}

    class _Backend:
        pass

    monkeypatch.setattr(deletion, "FirebaseBackend", _Backend)
    monkeypatch.setattr(
        deletion, "run", lambda uid, backend: ran.setdefault("uid", uid) and {"state": "done", "journal": deletion.JOURNAL}
    )
    answer = inner("delete_account")(request({}, token={}))
    assert ran["uid"] == "uid-1"
    assert answer["state"] == "done"


def test_delete_account_failure_is_internal_with_a_code(monkeypatch, stubbed):
    from account import deletion

    monkeypatch.setattr(deletion, "FirebaseBackend", lambda: object())

    def boom(uid, backend):
        raise RuntimeError("outage with details")

    monkeypatch.setattr(deletion, "run", boom)
    error = raises(
        lambda: inner("delete_account")(request({})),
        https_fn.FunctionsErrorCode.INTERNAL,
    )
    assert error.message == reasons.INTERNAL_ERROR


# ------------------------------------------------- S6: per-uid caps first


@pytest.mark.parametrize(
    "name,field,limit",
    [
        ("start_verification", "starts", "PER_UID_DAILY_START_LIMIT"),
        ("verify_identity", "verifies", "PER_UID_DAILY_VERIFY_LIMIT"),
    ],
)
def test_one_account_over_its_daily_cap_never_touches_the_global_counter(
    name, field, limit, monkeypatch, stubbed
):
    def over(uid, f):
        stubbed["per_uid_field"] = f
        return getattr(config, limit) + 1

    monkeypatch.setattr(main.store, "uid_daily_count_and_increment", over)
    error = raises(
        lambda: inner(name)(request(body())),
        https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
    )
    assert error.message == reasons.PER_UID_DAILY_LIMIT
    assert stubbed["per_uid_field"] == field
    assert stubbed["daily"] == 0, "one account must not move the global counter"
    assert stubbed["decoded"] == 0


def test_the_global_counter_runs_after_the_per_uid_pass(stubbed):
    with pytest.raises(AssertionError, match="pipeline was reached"):
        inner("verify_identity")(request(body()))
    assert stubbed["order"] == ["per_uid", "global"]


def test_start_verification_checks_per_uid_then_global(monkeypatch, stubbed):
    monkeypatch.setattr(
        main.store, "FirestoreLedger", lambda: (_ for _ in ()).throw(AssertionError("x"))
    )
    with pytest.raises(AssertionError):
        inner("start_verification")(request({}))
    assert stubbed["order"] == ["per_uid", "global"]
    assert stubbed["per_uid_field"] == "starts"


def test_the_per_uid_caps_sit_well_under_the_kill_switch():
    assert config.PER_UID_DAILY_START_LIMIT < config.DAILY_VERIFICATION_LIMIT
    assert config.PER_UID_DAILY_VERIFY_LIMIT < config.DAILY_VERIFICATION_LIMIT
    assert config.DAILY_VERIFICATION_LIMIT == 2_000, "the kill switch stays"
