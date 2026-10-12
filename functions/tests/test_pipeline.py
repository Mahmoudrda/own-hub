"""Spec §9.4: the pipeline, on the emulator-free half of the list.

The headline case is `test_male_card_never_reaches_a_paid_liveness_call`. Spec
§2 step 4 makes the ordering a requirement rather than an optimisation, and the
only way to test a requirement about ORDER is to assert on what was NOT called.
A test that checked the outcome alone would pass against an implementation that
paid for liveness and threw the answer away.
"""

from __future__ import annotations

import datetime as dt

import pytest

from identity import config, decisions, dedupe, ledger, pipeline, providers, reasons
from tests.test_nid import synth

TODAY = dt.date(2026, 9, 25)
PEPPER = b"test-pepper-not-a-real-one"

FEMALE = synth(seq="0134")
MALE = synth(seq="0133")


def front_text(number: str) -> str:
    return f"جمهورية مصر العربية\nالرقم القومي\n{number}"


def back_text(word: str = "أنثى") -> str:
    return f"النوع {word}\nالديانة مسلم"


class CountingLiveness(providers.MockLiveness):
    """A mock that records whether it was touched at all."""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.create_calls = 0
        self.fetch_calls = 0

    def create_session(self, uid):
        self.create_calls += 1
        return super().create_session(uid)

    def fetch_result(self, session_id, uid):
        self.fetch_calls += 1
        return super().fetch_result(session_id, uid)


class CountingMatch(providers.MockFaceMatch):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.calls = 0

    def compare(self, card_jpeg, reference_jpeg):
        self.calls += 1
        return super().compare(card_jpeg, reference_jpeg)


class FakeLedger:
    """A stand-in for store.FirestoreLedger, kept deliberately faithful to it.

    It records applied operation ids ONTO THE BUDGET, exactly as
    FirestoreLedger.spend does, because the pipeline now reads
    `Budget.operations` to refuse a replayed submission before it pays for OCR.
    A fake that dropped that field would let the replay test pass against a
    pipeline that never checked anything — which is the same failure the score
    scales had: a fake whose behaviour quietly differed from the real store, and
    a suite that only ever ran against the fake.
    """

    def __init__(self, budget: ledger.Budget | None = None):
        self.budget = budget or ledger.Budget()
        self.spends: list[tuple[str, int, str]] = []

    def read(self, uid):
        return self.budget

    def spend(self, uid, kind, cost, operation_id):
        # Idempotency on operation_id, as spec §5 requires of the real store.
        if any(op == operation_id for _, _, op in self.spends):
            return False, self.budget, None
        self.spends.append((kind, cost, operation_id))
        applied = ledger.apply(self.budget, kind, cost)
        self.budget = ledger.Budget(
            spent_micro_usd=applied.spent_micro_usd,
            ocr_submissions=applied.ocr_submissions,
            liveness_attempts=applied.liveness_attempts,
            operations=tuple(list(self.budget.operations) + [operation_id])[-50:],
        )
        return True, self.budget, None


class BilledButUnreadableOcr(providers.OcrProvider):
    """Cloud Vision answering "no text in this image", which is a BILLED unit.

    This is the blank-JPEG attack in one class. Vision charges per image
    submitted, not per image it manages to read, so this provider reports the
    full price alongside `ok=False`. Before the fix the pipeline debited the
    ledger only when `ok` was true, so a caller looping on blank images paid
    nothing and was billed for nothing while Google billed us every round.
    """

    provider_id = "billed-but-unreadable"
    cost_per_call = providers.COST_OCR_PER_IMAGE

    def __init__(self):
        self.calls: list[bytes] = []

    def read(self, image_jpeg: bytes) -> providers.OcrResult:
        self.calls.append(image_jpeg)
        return providers.OcrResult(
            provider_id=self.provider_id,
            cost_micro_usd=self.cost_per_call,
            ok=False,
            reason=reasons.NID_UNREADABLE,
            text="",
        )


class NeverReachedOcr(providers.OcrProvider):
    """A provider whose only job is to fail the test if it is ever contacted."""

    provider_id = "never-reached"
    cost_per_call = providers.COST_OCR_PER_IMAGE

    def __init__(self):
        self.calls: list[bytes] = []

    def read(self, image_jpeg: bytes) -> providers.OcrResult:
        self.calls.append(image_jpeg)
        raise AssertionError("the OCR provider was contacted when it must not be")


class TransportFailureOcr(providers.OcrProvider):
    """Vision timed out or returned a 5xx: no unit counted, nothing billed."""

    provider_id = "transport-failure"
    cost_per_call = providers.COST_OCR_PER_IMAGE

    def __init__(self):
        self.calls: list[bytes] = []

    def read(self, image_jpeg: bytes) -> providers.OcrResult:
        self.calls.append(image_jpeg)
        return providers.OcrResult(
            provider_id=self.provider_id,
            cost_micro_usd=0,
            ok=False,
            reason=reasons.INTERNAL_ERROR,
        )


class FakeRegistry:
    def __init__(self, entries=None):
        self.entries = entries or {}
        self.claimed = []

    def read(self, id_hmac):
        return self.entries.get(id_hmac)

    def claim(self, id_hmac, uid):
        self.claimed.append((id_hmac, uid))
        return dedupe.DedupeVerdict(ok=True)


class FakeBehaviour(pipeline.BehaviourStore):
    def __init__(self, failures=0, distinct=0):
        self.failures = failures
        self.distinct = distinct
        self.recorded = []

    def failures_for_hmac(self, id_hmac):
        return self.failures

    def distinct_hmacs_for_install(self, install_id_hash):
        return self.distinct

    def record_attempt(self, id_hmac, install_id_hash):
        self.recorded.append((id_hmac, install_id_hash))


def build(
    number: str = FEMALE,
    word: str = "أنثى",
    liveness: CountingLiveness | None = None,
    match: CountingMatch | None = None,
    ledger_store: FakeLedger | None = None,
    registry: FakeRegistry | None = None,
    behaviour: FakeBehaviour | None = None,
):
    live = liveness or CountingLiveness(confidence=95.0)
    deps = pipeline.Deps(
        ocr=providers.MockOcr(texts=[front_text(number), back_text(word)]),
        liveness=live,
        face_match=match or CountingMatch(similarity=95.0),
        ledger_store=ledger_store or FakeLedger(),
        registry=registry or FakeRegistry(),
        pepper=PEPPER,
        behaviour=behaviour or FakeBehaviour(),
        thresholds=config.THRESHOLDS_REKOGNITION,
    )
    session = live.create_session("uid-1")
    live.create_calls = 0  # the session mint is setup, not part of the run
    return deps, session


def run(**kwargs):
    deps, session = build(**kwargs)
    inputs = pipeline.Inputs(
        uid="uid-1",
        card_front=b"front-jpeg",
        card_back=b"back-jpeg",
        liveness_session_id=session,
        operation_id="op-1",
        today=TODAY,
    )
    return pipeline.run(inputs, deps), deps


# ---------------------------------------------------------- the happy path


def test_happy_path_is_approved():
    outcome, _ = run()
    assert outcome.decision.outcome == decisions.APPROVED


def test_happy_path_produces_a_hash_and_never_the_number():
    outcome, _ = run()
    assert outcome.id_hmac and len(outcome.id_hmac) == 64
    # The strong form: the raw number appears nowhere on the returned object.
    assert FEMALE not in repr(outcome)


# ------------------------------------------- THE ordering guarantee, spec §2


def test_male_card_never_reaches_a_paid_liveness_call():
    liveness = CountingLiveness()
    match = CountingMatch()
    outcome, deps = run(number=MALE, word="ذكر", liveness=liveness, match=match)

    assert outcome.decision.outcome == decisions.REJECTED_NOT_ELIGIBLE
    assert liveness.fetch_calls == 0, "spec §2 step 4: no paid liveness for a male card"
    assert match.calls == 0, "and no CompareFaces either"


def test_male_card_costs_only_the_ocr():
    outcome, deps = run(number=MALE, word="ذكر")
    assert outcome.spent_micro_usd == 2 * providers.COST_OCR_PER_IMAGE
    assert outcome.spent_micro_usd == 3_000, "spec §2: about USD 0.003"


def test_duplicate_card_never_reaches_a_paid_liveness_call():
    # The duplicate gate is free and sits before liveness for this reason.
    liveness = CountingLiveness()
    match = CountingMatch()
    id_hmac = dedupe.hash_and_forget(FEMALE, PEPPER)
    registry = FakeRegistry(
        {id_hmac: dedupe.RegistryEntry(uid="someone-else", state="active", pepper_version=1)}
    )
    outcome, _ = run(registry=registry, liveness=liveness, match=match)

    assert outcome.decision.outcome == decisions.REJECTED_DUPLICATE
    assert liveness.fetch_calls == 0
    assert match.calls == 0


def test_her_own_card_on_a_new_phone_is_not_a_duplicate():
    id_hmac = dedupe.hash_and_forget(FEMALE, PEPPER)
    registry = FakeRegistry(
        {id_hmac: dedupe.RegistryEntry(uid="uid-1", state="active", pepper_version=1)}
    )
    outcome, _ = run(registry=registry)
    assert outcome.decision.outcome == decisions.APPROVED


def test_a_closed_registration_is_refused():
    id_hmac = dedupe.hash_and_forget(FEMALE, PEPPER)
    registry = FakeRegistry(
        {id_hmac: dedupe.RegistryEntry(uid=None, state="closed", pepper_version=1)}
    )
    outcome, _ = run(registry=registry)
    assert outcome.decision.outcome == decisions.REJECTED_DUPLICATE
    assert reasons.REGISTRATION_CLOSED in outcome.decision.reasons


# --------------------------------------------------------- the cost ceiling


def test_the_call_past_the_cap_is_refused_before_the_provider_is_touched():
    liveness = CountingLiveness()
    spent = ledger.Budget(spent_micro_usd=config.COST_CAP_MICRO_USD - 100)
    outcome, deps = run(ledger_store=FakeLedger(spent), liveness=liveness)

    assert reasons.COST_CAP_REACHED in outcome.decision.reasons
    assert liveness.fetch_calls == 0
    assert deps.ocr.calls == [], "spec §9.4: refused BEFORE hitting the provider"


def test_the_ocr_attempt_limit_is_enforced():
    used = ledger.Budget(ocr_submissions=config.MAX_OCR_SUBMISSIONS)
    outcome, _ = run(ledger_store=FakeLedger(used))
    assert reasons.ATTEMPT_LIMIT_OCR in outcome.decision.reasons


def test_the_liveness_attempt_limit_is_enforced():
    used = ledger.Budget(liveness_attempts=config.MAX_LIVENESS_ATTEMPTS)
    liveness = CountingLiveness()
    outcome, _ = run(ledger_store=FakeLedger(used), liveness=liveness)
    assert reasons.ATTEMPT_LIMIT_LIVENESS in outcome.decision.reasons
    assert liveness.fetch_calls == 0


# ----------------------------------- the blank-image loop, and what bounds it
#
# The single most expensive defect this pipeline has had. Cloud Vision bills per
# image submitted; it does not bill per image it manages to read. The pipeline
# debited the ledger only when the OCR came back `ok`, so a caller posting blank
# JPEGs was billed nothing, burned no attempt, and moved neither the 50,000 µUSD
# cap nor the 4-submission limit — while Google billed two units every round, for
# as long as the loop ran. These four tests are the bound.


def _run_with_ocr(ocr, ledger_store, operation_id="op-1", uid="uid-1"):
    deps, session = build(ledger_store=ledger_store)
    deps.ocr = ocr
    inputs = pipeline.Inputs(
        uid=uid,
        card_front=b"front-jpeg",
        card_back=b"back-jpeg",
        liveness_session_id=session,
        operation_id=operation_id,
        today=TODAY,
    )
    return pipeline.run(inputs, deps)


def test_an_unreadable_card_still_charges_the_ledger_because_vision_billed_us():
    ledger_store = FakeLedger()
    outcome = _run_with_ocr(BilledButUnreadableOcr(), ledger_store)

    assert outcome.decision.outcome == decisions.RETRY_CAPTURE
    assert ledger_store.budget.spent_micro_usd == providers.COST_OCR_PER_IMAGE, (
        "Vision counted a unit for the front, so the ledger must show it"
    )
    assert ledger_store.budget.ocr_submissions == 1, (
        "and the submission must be counted, or MAX_OCR_SUBMISSIONS never fires"
    )


def test_the_unreadable_front_is_not_followed_by_a_second_billed_call():
    # The back's text is worthless without a front number to cross-check it
    # against, and an unreadable front is the commonest failure this endpoint
    # sees. Reading both doubled the bill on exactly that branch.
    ocr = BilledButUnreadableOcr()
    _run_with_ocr(ocr, FakeLedger())
    assert len(ocr.calls) == 1, "the back must not be read once the front has failed"


def test_blank_submissions_run_out_after_the_ocr_attempt_limit():
    # The loop, bounded. Four unreadable submissions consume the allowance and
    # the fifth is refused before the provider is contacted at all.
    ledger_store = FakeLedger()
    for attempt in range(config.MAX_OCR_SUBMISSIONS):
        outcome = _run_with_ocr(
            BilledButUnreadableOcr(), ledger_store, operation_id=f"op-{attempt}"
        )
        assert outcome.decision.outcome == decisions.RETRY_CAPTURE

    blocked = NeverReachedOcr()
    outcome = _run_with_ocr(blocked, ledger_store, operation_id="op-one-too-many")
    assert reasons.ATTEMPT_LIMIT_OCR in outcome.decision.reasons
    assert blocked.calls == [], "spec §9.4: refused BEFORE hitting the provider"

    spent = ledger_store.budget.spent_micro_usd
    assert spent == config.MAX_OCR_SUBMISSIONS * providers.COST_OCR_PER_IMAGE
    assert spent <= config.COST_CAP_MICRO_USD


def test_an_exhausted_allowance_never_sends_her_back_to_the_camera():
    """The lock-out. A budget refusal must not be RETRY_CAPTURE.

    The ledger document is keyed by uid and nothing in `functions/` gives it a
    TTL, an expiry or a reset, so once `ocr_submissions` reaches
    MAX_OCR_SUBMISSIONS it stays there. RETRY_CAPTURE maps to the camera screen
    on the client, so the fifth submission asked her for a sixth photograph, and
    the sixth for a seventh, for the life of the account.

    Asserted for all three refusals, because all three have the same shape.
    """
    exhausted = [
        ledger.Budget(ocr_submissions=config.MAX_OCR_SUBMISSIONS),
        ledger.Budget(liveness_attempts=config.MAX_LIVENESS_ATTEMPTS),
        ledger.Budget(spent_micro_usd=config.COST_CAP_MICRO_USD - 100),
    ]
    for budget in exhausted:
        outcome, _ = run(ledger_store=FakeLedger(budget), liveness=CountingLiveness())
        assert outcome.decision.outcome != decisions.RETRY_CAPTURE, (
            "a limit we imposed is not a photograph she can improve"
        )
        assert outcome.decision.outcome == decisions.PENDING_REVIEW


def test_an_exhausted_allowance_still_reaches_her_as_a_hint_she_can_act_on():
    """CONTACT_SUPPORT, not silence. `to_user_safe` is many-to-few on purpose,
    so this leaks nothing about which check failed."""
    used = ledger.Budget(ocr_submissions=config.MAX_OCR_SUBMISSIONS)
    outcome, _ = run(ledger_store=FakeLedger(used))
    assert reasons.to_user_safe(outcome.decision.reasons) == [reasons.CONTACT_SUPPORT]


def test_a_transport_failure_is_still_free_so_our_outage_is_not_her_problem():
    # The other half, and it must not be weakened by the fix above. A call that
    # never completed counted no unit at Google, so it costs her nothing and
    # burns no attempt. Spec §9.4.
    ledger_store = FakeLedger()
    outcome = _run_with_ocr(TransportFailureOcr(), ledger_store)

    assert outcome.decision.outcome == decisions.RETRY_CAPTURE
    assert ledger_store.budget.spent_micro_usd == 0
    assert ledger_store.budget.ocr_submissions == 0
    assert ledger_store.spends == []


def test_a_replayed_operation_id_never_reaches_the_paid_provider():
    # `operationId` comes out of the request body. The ledger's own idempotency
    # check lives inside spend(), which runs AFTER the OCR calls, so repeating
    # one id used to buy unlimited billed Vision calls against a ledger that
    # moved exactly once.
    ledger_store = FakeLedger()
    first = _run_with_ocr(
        providers.MockOcr(texts=[front_text(FEMALE), back_text()]),
        ledger_store,
        operation_id="same-tap",
    )
    assert first.decision.outcome == decisions.APPROVED
    charged_once = ledger_store.budget.spent_micro_usd

    blocked = NeverReachedOcr()
    second = _run_with_ocr(blocked, ledger_store, operation_id="same-tap")

    assert reasons.DUPLICATE_SUBMISSION in second.decision.reasons
    assert blocked.calls == [], "the replay must be refused before Vision is called"
    assert ledger_store.budget.spent_micro_usd == charged_once


def test_a_fresh_operation_id_is_still_allowed_through():
    # The guard must bound a replay without blocking her genuine second attempt,
    # which carries a new operation id.
    ledger_store = FakeLedger()
    _run_with_ocr(
        providers.MockOcr(texts=[front_text(FEMALE), back_text()]),
        ledger_store,
        operation_id="tap-1",
    )
    ocr = providers.MockOcr(texts=[front_text(FEMALE), back_text()])
    _run_with_ocr(ocr, ledger_store, operation_id="tap-2")
    assert len(ocr.calls) == 2, "a new submission reads both sides as normal"
    assert ledger_store.budget.ocr_submissions == 2


def test_a_failed_provider_call_is_not_charged_for():
    # Spec §9.4: provider timeout/5xx gives a retry and records no charge.
    # Charging her budget for our vendor's outage would eventually lock her out.
    liveness = CountingLiveness(ok=False, reason=reasons.LIVENESS_PROVIDER_ERROR)
    ledger_store = FakeLedger()
    outcome, _ = run(liveness=liveness, ledger_store=ledger_store)

    kinds = [kind for kind, _, _ in ledger_store.spends]
    assert ledger.LIVENESS_ATTEMPT not in kinds
    assert outcome.decision.outcome == decisions.RETRY_CAPTURE


# --------------------------------------------- session replay, spec §5 / §9.4


def test_replaying_a_session_from_another_uid_fails():
    deps, session = build()
    inputs = pipeline.Inputs(
        uid="attacker",
        card_front=b"f",
        card_back=b"b",
        liveness_session_id=session,
        operation_id="op-x",
        today=TODAY,
    )
    outcome = pipeline.run(inputs, deps)
    assert reasons.SESSION_WRONG_ACCOUNT in outcome.decision.reasons
    assert outcome.decision.outcome == decisions.RETRY_CAPTURE


def test_a_consumed_session_cannot_be_reused():
    deps, session = build()
    make = lambda op: pipeline.Inputs(
        uid="uid-1",
        card_front=b"f",
        card_back=b"b",
        liveness_session_id=session,
        operation_id=op,
        today=TODAY,
    )
    first = pipeline.run(make("op-1"), deps)
    assert first.decision.outcome == decisions.APPROVED

    deps.ocr = providers.MockOcr(texts=[front_text(FEMALE), back_text()])
    second = pipeline.run(make("op-2"), deps)
    assert reasons.SESSION_ALREADY_USED in second.decision.reasons


def test_a_missing_session_fails():
    deps, _ = build()
    inputs = pipeline.Inputs(
        uid="uid-1",
        card_front=b"f",
        card_back=b"b",
        liveness_session_id="never-minted",
        operation_id="op-1",
        today=TODAY,
    )
    outcome = pipeline.run(inputs, deps)
    assert reasons.SESSION_MISSING in outcome.decision.reasons


# ------------------------------------------------------------ idempotency


def test_a_double_submit_does_not_double_charge_or_double_bill():
    # Spec §5: a double tap must not double-charge.
    #
    # "Does not double-charge" was too weak a property on its own, and this test
    # used to assert only that. It passed against a pipeline that ran the whole
    # of step 3 a second time — two more billed Vision calls — and then skipped
    # the debit inside spend(). The ledger stayed flat and the invoice did not,
    # which is the opposite of what the test's name promises. Both halves are
    # asserted now.
    ledger_store = FakeLedger()
    deps, session = build(ledger_store=ledger_store)
    inputs = pipeline.Inputs(
        uid="uid-1",
        card_front=b"f",
        card_back=b"b",
        liveness_session_id=session,
        operation_id="same-tap",
        today=TODAY,
    )
    pipeline.run(inputs, deps)
    before = ledger_store.budget.spent_micro_usd

    deps.ocr = providers.MockOcr(texts=[front_text(FEMALE), back_text()])
    pipeline.run(inputs, deps)
    assert ledger_store.budget.spent_micro_usd == before
    assert deps.ocr.calls == [], "and the second tap must not pay for OCR again"


# ----------------------------------------------------------------- flags


def test_an_unknown_governorate_is_recorded_and_let_through():
    # Code 20 was never issued, so it is either a gap in nid.GOVERNORATES or an
    # OCR misread of digits 8-9 — and roughly seven in ten misreads in that
    # position land on an unissued code, because only 28 of the 100 are real.
    # Either way it is a fact about our table or our OCR, not about her, and a
    # woman reviewer on a video call has nothing to examine: the card image is
    # gone by the time the call happens. She goes through on the other checks
    # and the code is recorded so the table can be corrected.
    outcome, _ = run(number=synth(gov="20", seq="0134"))
    assert outcome.decision.outcome == decisions.APPROVED
    assert reasons.NID_GOVERNORATE_UNKNOWN not in outcome.decision.flags
    assert reasons.NID_GOVERNORATE_UNKNOWN in outcome.decision.reasons


def test_the_unknown_governorate_code_itself_comes_back_so_the_table_can_be_fixed():
    # The half of the downgrade that makes it honest. Dropping the review is
    # only defensible if somebody can still discover that code 20 exists and
    # correct nid.GOVERNORATES; the job document records the reason and never
    # the digits, so the pipeline has to hand them back.
    outcome, _ = run(number=synth(gov="20", seq="0134"))
    assert outcome.unknown_governorate_code == "20"


def test_a_known_governorate_leaves_nothing_to_count():
    # The code travels only when it is one we do not have. A woman from Cairo
    # contributes nothing to any counter, which is the default this has to hold
    # to for the other 49,000 sign-ups.
    outcome, _ = run(number=synth(gov="01", seq="0134"))
    assert outcome.unknown_governorate_code is None
    assert reasons.NID_GOVERNORATE_UNKNOWN not in outcome.decision.reasons


def test_a_male_digit_with_a_female_word_flags_rather_than_rejects():
    liveness = CountingLiveness(confidence=95.0)
    outcome, _ = run(number=MALE, word="أنثى", liveness=liveness)
    assert outcome.decision.outcome == decisions.PENDING_REVIEW
    assert reasons.SEX_CONFLICT in outcome.decision.flags


def test_repeated_failures_on_one_card_flag_across_accounts():
    outcome, _ = run(behaviour=FakeBehaviour(failures=3))
    assert outcome.decision.outcome == decisions.PENDING_REVIEW
    assert reasons.HMAC_MANY_FAILURES in outcome.decision.flags


def test_the_niqab_path_skips_liveness_and_the_match_entirely():
    liveness = CountingLiveness()
    match = CountingMatch()
    deps, session = build(liveness=liveness, match=match)
    inputs = pipeline.Inputs(
        uid="uid-1",
        card_front=b"f",
        card_back=b"b",
        liveness_session_id=session,
        niqab_path_requested=True,
        operation_id="op-n",
        today=TODAY,
    )
    outcome = pipeline.run(inputs, deps)

    assert outcome.decision.outcome == decisions.PENDING_REVIEW
    assert reasons.NIQAB_PATH_REQUESTED in outcome.decision.flags
    assert liveness.fetch_calls == 0, "she is not made to fail a match she cannot pass"
    assert match.calls == 0


# ------------------------------------------------------------- parse paths


def test_an_underage_applicant_is_not_eligible():
    born = dt.date(TODAY.year - 17, TODAY.month, TODAY.day)
    number = synth(
        century="3",
        yy=f"{born.year % 100:02d}",
        mm=f"{born.month:02d}",
        dd=f"{born.day:02d}",
        seq="0134",
    )
    outcome, _ = run(number=number)
    assert outcome.decision.outcome == decisions.REJECTED_NOT_ELIGIBLE
    assert reasons.UNDERAGE in outcome.decision.reasons


def test_an_applicant_on_her_eighteenth_birthday_is_eligible():
    born = dt.date(TODAY.year - 18, TODAY.month, TODAY.day)
    number = synth(
        century="3" if born.year >= 2000 else "2",
        yy=f"{born.year % 100:02d}",
        mm=f"{born.month:02d}",
        dd=f"{born.day:02d}",
        seq="0134",
    )
    outcome, _ = run(number=number)
    assert outcome.decision.outcome == decisions.APPROVED


def test_disagreeing_sides_ask_for_a_retake():
    deps, session = build()
    deps.ocr = providers.MockOcr(
        texts=[front_text(FEMALE), front_text(synth(seq="0136"))]
    )
    inputs = pipeline.Inputs(
        uid="uid-1",
        card_front=b"f",
        card_back=b"b",
        liveness_session_id=session,
        operation_id="op-d",
        today=TODAY,
    )
    outcome = pipeline.run(inputs, deps)
    assert outcome.decision.outcome == decisions.RETRY_CAPTURE
    assert reasons.NID_SIDES_DISAGREE in outcome.decision.reasons
