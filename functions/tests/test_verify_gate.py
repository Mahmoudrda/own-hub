"""verify_identity and start_verification around the review loop (S7, S8, S12).

Driven through the real callable bodies with the pipeline's own fakes, and every
store write stubbed and recorded.
"""

from __future__ import annotations

import pytest
from firebase_functions import https_fn

import main
from identity import dedupe, decisions, reasons, review
from tests import test_pipeline as tp
from tests.test_entrypoints import body, inner, raises, request, stubbed  # noqa: F401


@pytest.fixture
def writes(monkeypatch, stubbed):
    log = {"jobs": [], "flags": [], "states": [], "minted": [], "gate": main.store.Gate()}

    def write_job(uid, decision, outcome, attempt):
        log["jobs"].append(decision.outcome)
        return f"job-{len(log['jobs'])}"

    def open_flag(uid, job, flag, *, job_id=None, mark_duplicate=False):
        log["flags"].append({"flag": flag, "mark_duplicate": mark_duplicate})
        return f"flag-{len(log['flags'])}", True

    monkeypatch.setattr(main.store, "write_job", write_job)
    monkeypatch.setattr(main.store, "open_flag", open_flag)
    monkeypatch.setattr(
        main.store, "job_payload", lambda uid, d, a, s=0, p=None: {"state": d.outcome}
    )
    monkeypatch.setattr(
        main.store,
        "set_verification_state",
        lambda uid, state, **kw: log["states"].append(state),
    )
    monkeypatch.setattr(main.store, "mint_claims", lambda uid, v: log["minted"].append(uid))
    monkeypatch.setattr(
        main.store, "write_user_verification", lambda uid: log["states"].append("approved")
    )
    monkeypatch.setattr(main.store, "record_unknown_governorate", lambda code: None)
    monkeypatch.setattr(main.store, "verification_gate", lambda uid: log["gate"])
    monkeypatch.setattr(main, "_post_flag_webhook", lambda *a: None)
    return log


def _wire(monkeypatch, deps):
    monkeypatch.setattr(main, "_deps", lambda: deps)


# ------------------------------------------------------------- the gate


def test_a_rejected_account_is_closed_before_any_counter_or_decode(writes, stubbed):
    writes["gate"] = main.store.Gate(state=review.STATE_REJECTED)
    error = raises(
        lambda: inner("verify_identity")(request(body())),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert error.message == reasons.VERIFICATION_CLOSED
    assert stubbed["daily"] == 0 and stubbed["decoded"] == 0


def test_an_open_review_answers_pending_at_no_cost(writes, stubbed):
    writes["gate"] = main.store.Gate(open_flag_id="f-1")
    answer = inner("verify_identity")(request(body()))
    assert answer == {"outcome": "PENDING_REVIEW", "reasons": [], "refreshToken": False}
    assert stubbed["daily"] == 0 and stubbed["decoded"] == 0


def test_start_verification_with_an_open_review_says_so(writes, stubbed):
    writes["gate"] = main.store.Gate(open_flag_id="f-1")
    error = raises(
        lambda: inner("start_verification")(request({})),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert error.message == reasons.REVIEW_ALREADY_OPEN
    assert stubbed["daily"] == 0


def test_start_verification_on_a_rejected_account_is_closed(writes, stubbed):
    writes["gate"] = main.store.Gate(state=review.STATE_REJECTED)
    error = raises(
        lambda: inner("start_verification")(request({})),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert error.message == reasons.VERIFICATION_CLOSED


# ----------------------------------------------------- outcomes and state


def _verify(session, **overrides):
    return inner("verify_identity")(
        request(body(liveness={"sessionId": session}, **overrides))
    )


def test_approval_mints_and_sets_approved(monkeypatch, writes):
    deps, session = tp.build()
    _wire(monkeypatch, deps)
    answer = _verify(session)
    assert answer["outcome"] == decisions.APPROVED and answer["refreshToken"] is True
    assert writes["minted"] == ["uid-1"]
    assert "approved" in writes["states"]


def test_a_male_card_is_rejected_and_the_state_says_rejected(monkeypatch, writes):
    deps, session = tp.build(number=tp.MALE, word="ذكر")
    _wire(monkeypatch, deps)
    answer = _verify(session)
    assert answer["outcome"] == decisions.REJECTED_NOT_ELIGIBLE
    assert answer["reasons"] == []
    assert writes["states"] == [review.STATE_REJECTED]
    assert writes["minted"] == []


def _duplicate_deps():
    id_hmac = dedupe.hash_and_forget(tp.FEMALE, tp.PEPPER)
    registry = tp.FakeRegistry(
        {id_hmac: dedupe.RegistryEntry(uid="someone-else", state="active", pepper_version=1)}
    )
    return tp.build(registry=registry)


def test_the_first_duplicate_gets_exactly_one_review(monkeypatch, writes):
    deps, session = _duplicate_deps()
    _wire(monkeypatch, deps)
    answer = _verify(session)
    assert answer["outcome"] == decisions.PENDING_REVIEW
    assert len(writes["flags"]) == 1
    raised = writes["flags"][0]
    assert raised["mark_duplicate"] is True
    assert raised["flag"]["flags"] == [reasons.DUPLICATE_ID]
    assert raised["flag"]["id_hmac"], "the reviewer cannot approve it: the claim will fail"
    assert writes["states"] == [review.STATE_PENDING]


def test_the_second_duplicate_is_final(monkeypatch, writes):
    writes["gate"] = main.store.Gate(duplicate_flag_raised=True)
    deps, session = _duplicate_deps()
    _wire(monkeypatch, deps)
    answer = _verify(session)
    assert answer["outcome"] == decisions.REJECTED_DUPLICATE
    assert writes["flags"] == []
    assert writes["states"] == [review.STATE_REJECTED]


def test_a_closed_registration_never_opens_a_review(monkeypatch, writes):
    id_hmac = dedupe.hash_and_forget(tp.FEMALE, tp.PEPPER)
    registry = tp.FakeRegistry(
        {id_hmac: dedupe.RegistryEntry(uid=None, state="closed", pepper_version=1)}
    )
    deps, session = tp.build(registry=registry)
    _wire(monkeypatch, deps)
    answer = _verify(session)
    assert answer["outcome"] == decisions.REJECTED_DUPLICATE
    assert writes["flags"] == []


# ----------------------------------------------------- S12 end to end


def test_a_replayed_operation_id_never_calls_ocr_twice(monkeypatch, writes):
    ledger_store = tp.FakeLedger()
    deps, session = tp.build(ledger_store=ledger_store)
    _wire(monkeypatch, deps)
    first = _verify(session, operationId="11111111-2222-3333-4444-555555555555")
    assert first["outcome"] == decisions.APPROVED
    charged = ledger_store.budget.spent_micro_usd

    blocked = tp.NeverReachedOcr()
    deps.ocr = blocked
    second = _verify(session, operationId="11111111-2222-3333-4444-555555555555")
    assert second["outcome"] == decisions.RETRY_CAPTURE
    assert blocked.calls == []
    assert ledger_store.budget.spent_micro_usd == charged


def test_the_install_id_is_hashed_before_the_pipeline_sees_it(monkeypatch, writes):
    seen = {}
    real_run = main.pipeline.run

    def spy(inputs, deps):
        seen["install"] = inputs.install_id_hash
        return real_run(inputs, deps)

    deps, session = tp.build()
    _wire(monkeypatch, deps)
    monkeypatch.setattr(main.pipeline, "run", spy)
    _verify(session, installId="raw-install-id")
    assert seen["install"] and seen["install"] != "raw-install-id"
    assert len(seen["install"]) == 64


# ------------------------------------------------- S7: NOT_ELIGIBLE pin


def test_not_eligible_only_when_digit_and_word_both_say_male():
    from identity.decisions import Signals, decide_before_scores

    both = decide_before_scores(Signals(sex_from_digit="male", sex_from_word="male"))
    assert both.outcome == decisions.REJECTED_NOT_ELIGIBLE

    # Disagreement is not terminal before scores: it continues to a flag.
    conflict = decide_before_scores(
        Signals(sex_from_digit="male", sex_from_word="female", ocr_retries_exhausted=True)
    )
    assert conflict is None

    unreadable = decide_before_scores(Signals(sex_from_digit="male", sex_from_word=None))
    assert unreadable.outcome == decisions.RETRY_CAPTURE

    unreadable_last = decide_before_scores(
        Signals(sex_from_digit="male", sex_from_word=None, ocr_retries_exhausted=True)
    )
    assert unreadable_last is None


# ------------------------------------- N3: a failed check goes to a human


def _failed_deps():
    from identity import config, ledger

    worn = tp.FakeLedger(ledger.Budget(liveness_attempts=config.MAX_LIVENESS_ATTEMPTS - 1))
    return tp.build(ledger_store=worn, match=tp.CountingMatch(similarity=5.0))


def test_a_failed_check_with_no_attempts_left_opens_one_review_not_a_rejection(
    monkeypatch, writes
):
    recorded = []
    monkeypatch.setattr(
        main.store.FirestoreBehaviour, "record_failure", lambda self, h: recorded.append(h)
    )
    deps, session = _failed_deps()
    _wire(monkeypatch, deps)
    answer = _verify(session)

    assert answer["outcome"] == decisions.PENDING_REVIEW
    assert answer["refreshToken"] is False
    assert len(writes["flags"]) == 1
    raised = writes["flags"][0]
    assert raised["mark_duplicate"] is False
    assert raised["flag"]["flags"] == [reasons.MATCH_FAILED]
    assert writes["states"] == [review.STATE_PENDING]
    assert review.STATE_REJECTED not in writes["states"]
    assert writes["jobs"] == [] and writes["minted"] == []
    # The card still carries the failure signal for spec §3.
    assert len(recorded) == 1


def test_a_failed_check_while_a_review_is_open_opens_nothing_new(monkeypatch, writes):
    writes["gate"] = main.store.Gate(open_flag_id="f-1")
    deps, session = _failed_deps()
    _wire(monkeypatch, deps)
    assert _verify(session)["outcome"] == decisions.PENDING_REVIEW
    assert writes["flags"] == [] and writes["states"] == []
