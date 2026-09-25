"""Spec §2's pipeline: the order the checks run in, and nothing else.

The order IS the cost control. Spec §2 opens with "the order matters. Cheap
checks run before expensive ones, so a male applicant is rejected for about USD
0.003 before liveness is ever paid for", and spec §2 step 4 restates it as a
requirement rather than an optimisation.

That makes the ordering a thing to test, not merely a thing to intend, which is
why this module takes its providers and stores as arguments. `run()` is
deterministic given its inputs, so tests/test_pipeline.py can assert the strong
form of the guarantee: **on a male card, the liveness and match providers are
never called at all.** A test that only checked the outcome would pass against
an implementation that paid for liveness and then threw the answer away.

    Step 3  OCR both sides            paid, ~$0.003
    Step 3  parse and validate        free
    Step 4  the sex gate              free   <- male exits HERE
    Step 5  duplicate check           free (one Firestore read)
    Step 6  liveness                  paid, ~$0.015
    Step 7  face match                paid, ~$0.001
    Step 8  decide, mint, clean up

Nothing in this module writes an image anywhere.
"""

from __future__ import annotations

import datetime as dt
from dataclasses import dataclass, field
from typing import Optional, Sequence

from . import arabic, config, decisions, dedupe, ledger, nid, providers, reasons


@dataclass
class Inputs:
    """One verification attempt's raw material.

    `card_front` and `card_back` are JPEG bytes in memory. They are passed
    down, never up: no field on `Outcome` can hold them, which is a structural
    reason the images cannot leak into a return value and from there into a log.
    """

    uid: str
    card_front: bytes
    card_back: bytes
    liveness_session_id: Optional[str] = None
    selfie_frames: Sequence[bytes] = ()
    niqab_path_requested: bool = False
    install_id_hash: Optional[str] = None
    operation_id: str = ""
    today: dt.date = field(default_factory=dt.date.today)


@dataclass
class Deps:
    """Everything the pipeline talks to. Injected so it can all be faked."""

    ocr: providers.OcrProvider
    liveness: providers.LivenessProvider
    face_match: providers.FaceMatchProvider
    ledger_store: ledger.LedgerStore
    registry: dedupe.RegistryStore
    pepper: bytes
    behaviour: "BehaviourStore"
    thresholds: config.ThresholdSet = config.ACTIVE_THRESHOLDS


class BehaviourStore:
    """Spec §3's two cross-account FLAG signals.

    Split out because both need reads keyed on something other than the uid —
    one on the id_hmac across all accounts, one on the app install — and putting
    them behind an interface keeps the pipeline testable without either.
    """

    def failures_for_hmac(self, id_hmac: str) -> int:
        raise NotImplementedError

    def distinct_hmacs_for_install(self, install_id_hash: str) -> int:
        raise NotImplementedError

    def record_attempt(self, id_hmac: str, install_id_hash: Optional[str]) -> None:
        raise NotImplementedError


@dataclass
class Outcome:
    """What the pipeline concluded. Carries no image and no raw identity data.

    `id_hmac` is here because step 8 needs it to claim the registry entry and
    the flag record needs it for spec §3's cross-account signal. The raw number
    is not, and there is nowhere to put it.
    """

    decision: decisions.Decision
    id_hmac: Optional[str] = None
    reference_image: Optional[bytes] = None
    """Held only so the caller can write an evidence bundle for a FLAGGED case
    when spec §4's bundle is enabled. It is not written anywhere by this module,
    and when the bundle is disabled the caller drops it on the floor."""
    card_front: Optional[bytes] = None
    liveness_confidence: Optional[float] = None
    match_similarity: Optional[float] = None
    spent_micro_usd: int = 0
    provider_ids: dict = field(default_factory=dict)
    unknown_governorate_code: Optional[str] = None
    """The two digits, when they were not in nid.GOVERNORATES, so the table can
    be corrected.

    This is the other half of demoting an unknown governorate code from a FLAG
    to a recorded observation (see decisions._score_stage). Removing the review
    without keeping the code would mean the table could never be fixed: the job
    document says only that an unknown code was seen, not which one, and by
    design it will never say more, because a governorate is her place of birth
    and spec §4 does not allow it beside her uid.

    So the code travels only this far, in memory, and main.py adds one to an
    aggregate counter keyed by the code with no uid attached. "We have seen 41
    cards with code 45" tells us to go and look at code 45. It tells nobody
    anything about any of those 41 women."""


def run(inputs: Inputs, deps: Deps) -> Outcome:
    """Spec §2 steps 3 to 8, and the one observation that outlives the request.

    A thin wrapper around `_run` so the unknown-governorate code can be stamped
    onto whichever of `_run`'s many exits was taken, without threading it
    through ten Outcome constructions by hand.
    """
    observed = _Observed()
    outcome = _run(inputs, deps, observed)
    outcome.unknown_governorate_code = observed.unknown_governorate_code
    return outcome


@dataclass
class _Observed:
    """Things worth counting that are not part of the decision.

    Deliberately tiny, and deliberately not a general-purpose bag. Anything
    added here is a thing that survives the request, which is exactly the class
    of change spec §4 exists to restrain."""

    unknown_governorate_code: Optional[str] = None


def _run(inputs: Inputs, deps: Deps, observed: _Observed) -> Outcome:
    signals = decisions.Signals(niqab_path_requested=inputs.niqab_path_requested)
    spent = 0
    provider_ids: dict = {}

    def finish(sig: decisions.Signals, **extra) -> Outcome:
        return Outcome(
            decision=decisions.decide(sig, deps.thresholds),
            spent_micro_usd=spent,
            provider_ids=provider_ids,
            **extra,
        )

    # ------------------------------------------------- step 3: OCR, paid
    #
    # The budget is checked BEFORE the provider is contacted, which is spec
    # §9.4's requirement in its strong form: "the call after the cap is refused
    # before hitting the provider". Checking afterwards would still refuse the
    # result, and would still have been billed for it.

    ocr_cost = deps.ocr.cost_per_call * 2  # front and back, the worst case
    budget = deps.ledger_store.read(inputs.uid)
    refusal = ledger.check(budget, ledger.OCR_SUBMISSION, ocr_cost)
    if refusal is not None:
        return Outcome(
            decision=decisions.Decision(decisions.RETRY_CAPTURE, (refusal.code,)),
            spent_micro_usd=budget.spent_micro_usd,
        )

    ocr_operation = f"{inputs.operation_id}:ocr"
    if budget.already_applied(ocr_operation):
        # A REPLAYED OPERATION ID, REFUSED BEFORE THE PROVIDER IS TOUCHED.
        #
        # `operation_id` comes from the client (main.py reads it out of the
        # request body). The ledger's own idempotency check sits inside `spend`,
        # which runs AFTER the Vision calls, so it suppresses the second debit
        # without suppressing the second bill. Repeating one id therefore bought
        # unlimited billed Vision calls against a ledger that moved exactly once
        # — the per-uid cap and the 4-submission limit both sat still while the
        # invoice grew.
        #
        # Refusing here costs one Firestore read that was happening anyway. It
        # also makes the double tap spec §5 asks about genuinely cheap instead
        # of merely non-double-charging: the second tap does no OCR at all.
        return Outcome(
            decision=decisions.Decision(
                decisions.RETRY_CAPTURE, (reasons.DUPLICATE_SUBMISSION,)
            ),
            spent_micro_usd=budget.spent_micro_usd,
        )

    provider_ids["ocr"] = deps.ocr.provider_id
    front = deps.ocr.read(inputs.card_front)

    # The back is read ONLY once the front is known to be usable.
    #
    # An unreadable front is the commonest failure this endpoint sees — a thumb
    # over the number, glare on the laminate, a dark room — and the back's text
    # is worthless without a front number to cross-check it against. Reading
    # both unconditionally doubled the Vision bill on precisely the branch that
    # gets taken most often, for a value that is then discarded three lines
    # later.
    back = deps.ocr.read(inputs.card_back) if front.ok else None

    # CHARGE FOR WHAT THE PROVIDER ACTUALLY BILLED, on every path out of here.
    #
    # `ok` is about whether the text is usable. `cost_micro_usd` is about
    # whether Google counted a unit. They are different questions and the code
    # used to answer only the first: the debit was skipped whenever `front.ok`
    # was false, which meant a caller submitting blank images looped for ever
    # with the ledger frozen at zero. Vision bills per image submitted, not per
    # image it managed to read, so an unreadable card is a real 3,000 µUSD (or
    # 1,500, now that the back is conditional) and it belongs on the ledger.
    #
    # Only a call that never completed — a timeout, a 5xx, a transport error —
    # reports zero, and that is spec §9.4's no-charge retry, intact and
    # unweakened. See providers_selfhosted.VisionOcr.read, where the two cases
    # are now distinguished at the point the answer is constructed.
    billed = front.cost_micro_usd + (back.cost_micro_usd if back is not None else 0)
    if billed:
        charged, budget, _ = deps.ledger_store.spend(
            inputs.uid, ledger.OCR_SUBMISSION, billed, ocr_operation
        )
        if charged:
            spent = budget.spent_micro_usd

    if not front.ok:
        return finish(
            decisions.Signals(nid_parse_failure=front.reason or reasons.NID_UNREADABLE)
        )

    # --------------------------------------- step 3: parse and cross-check

    parsed, failure = nid.first_valid(front.text, today=inputs.today)
    if parsed is None:
        return finish(decisions.Signals(nid_parse_failure=failure))

    # Spec §2 step 3: "if the number appears on both sides, both reads must
    # agree." Only checked when the back actually yielded a number — most backs
    # do not carry one, and demanding agreement with a number that was never
    # printed would fail every genuine card.
    # `back is not None` is guaranteed here — it is only None when the front was
    # unreadable, and that path returned above — but it is spelled out rather
    # than assumed, because the thing that makes it true is an early return
    # forty lines away and a later edit could move it.
    back_ok = back is not None and back.ok

    if back_ok:
        back_parsed, _ = nid.first_valid(back.text, today=inputs.today)
        if back_parsed is not None and back_parsed.number != parsed.number:
            return finish(decisions.Signals(sides_disagree=True))

    age = parsed.age_on(inputs.today)
    sex_word = arabic.read_sex_field(back.text) if back_ok else None

    if parsed.governorate_unknown:
        # Captured HERE, before `del parsed` at step 5, because this is the last
        # point at which the code exists. It no longer opens a review (see
        # decisions._score_stage for why), so counting it is the only way the
        # table in nid.py ever gets corrected.
        observed.unknown_governorate_code = parsed.governorate_code

    signals = decisions.Signals(
        governorate_unknown=parsed.governorate_unknown,
        underage=age < config.MIN_AGE,
        age_implausible=age > config.MAX_AGE_PLAUSIBLE,
        sex_from_digit=parsed.sex_from_digit,
        sex_from_word=sex_word,
        ocr_retries_exhausted=budget.ocr_submissions >= config.MAX_OCR_SUBMISSIONS,
        niqab_path_requested=inputs.niqab_path_requested,
    )

    # ------------------------------------- step 4: the sex gate, before paying
    #
    # THE ordering requirement. A male applicant is decided here, having spent
    # about $0.003 on OCR and nothing at all on liveness. Note this is reached
    # by running `decide` on the signals gathered SO FAR — if that returns a
    # terminal answer, the pipeline stops and the paid providers below are never
    # constructed, never called, and never billed.

    early = decisions.decide_before_scores(signals)
    if early is not None:
        return Outcome(
            decision=early, spent_micro_usd=spent, provider_ids=provider_ids
        )

    # --------------------------------------------- step 5: the duplicate gate
    #
    # Free (one Firestore read) and placed before liveness so a card already
    # bound to another account never reaches a paid call.
    #
    # `hash_and_forget` is the last thing in this process that sees the raw
    # number. After this line the only surviving form is the hash.

    id_hmac = dedupe.hash_and_forget(parsed.number, deps.pepper)
    del parsed  # spec §2 step 5: discarded from memory after this step

    verdict = dedupe.judge(deps.registry.read(id_hmac), inputs.uid)
    if not verdict.ok:
        signals = _with(
            signals,
            duplicate_of_other_account=verdict.reason == reasons.DUPLICATE_ID,
            registration_closed=verdict.reason == reasons.REGISTRATION_CLOSED,
        )
        duplicate = decisions.decide_before_scores(signals)
        return Outcome(
            decision=duplicate
            or decisions.Decision(decisions.REJECTED_DUPLICATE, (verdict.reason,)),
            id_hmac=id_hmac,
            spent_micro_usd=spent,
            provider_ids=provider_ids,
        )

    deps.behaviour.record_attempt(id_hmac, inputs.install_id_hash)
    signals = _with(
        signals,
        hmac_failure_count=deps.behaviour.failures_for_hmac(id_hmac),
        install_distinct_hmacs=(
            deps.behaviour.distinct_hmacs_for_install(inputs.install_id_hash)
            if inputs.install_id_hash
            else 0
        ),
    )

    # A woman who asked for the woman-reviewer route stops here. She is not made
    # to fail a face match she cannot pass, and no paid liveness call is made
    # for a decision a human is going to take anyway.
    if inputs.niqab_path_requested:
        return Outcome(
            decision=decisions.decide(signals, deps.thresholds),
            id_hmac=id_hmac,
            spent_micro_usd=spent,
            provider_ids=provider_ids,
        )

    # ------------------------------------------------ step 6: liveness, paid

    refusal = ledger.check(
        budget, ledger.LIVENESS_ATTEMPT, deps.liveness.cost_per_call
    )
    if refusal is not None:
        return Outcome(
            decision=decisions.Decision(decisions.RETRY_CAPTURE, (refusal.code,)),
            id_hmac=id_hmac,
            spent_micro_usd=spent,
            provider_ids=provider_ids,
        )

    if hasattr(deps.liveness, "submit_frames") and inputs.selfie_frames:
        deps.liveness.submit_frames(inputs.liveness_session_id, inputs.selfie_frames)

    live = deps.liveness.fetch_result(inputs.liveness_session_id or "", inputs.uid)
    provider_ids["liveness"] = live.provider_id

    if not live.ok:
        # Session problems (missing, expired, consumed, wrong account) and
        # provider errors both land here. Neither is charged for.
        signals = _with(
            signals,
            liveness_ran=True,
            liveness_provider_error=live.reason
            in {
                reasons.LIVENESS_PROVIDER_ERROR,
                reasons.INTERNAL_ERROR,
            },
        )
        if live.reason in {
            reasons.SESSION_MISSING,
            reasons.SESSION_EXPIRED,
            reasons.SESSION_ALREADY_USED,
            reasons.SESSION_WRONG_ACCOUNT,
            reasons.FACE_NOT_FOUND_IN_REFERENCE,
            reasons.FACE_FRAMES_DISAGREE,
            reasons.LIVENESS_FAILED,
            reasons.IMAGE_TOO_LARGE,
            reasons.IMAGE_UNDECODABLE,
        }:
            return Outcome(
                decision=decisions.Decision(decisions.RETRY_CAPTURE, (live.reason,)),
                id_hmac=id_hmac,
                spent_micro_usd=spent,
                provider_ids=provider_ids,
            )
        return Outcome(
            decision=decisions.decide(signals, deps.thresholds),
            id_hmac=id_hmac,
            spent_micro_usd=spent,
            provider_ids=provider_ids,
        )

    charged, budget, _ = deps.ledger_store.spend(
        inputs.uid,
        ledger.LIVENESS_ATTEMPT,
        live.cost_micro_usd,
        f"{inputs.operation_id}:liveness",
    )
    if charged:
        spent = budget.spent_micro_usd

    # ---------------------------------------------- step 7: face match, paid
    #
    # Source is the liveness provider's OWN reference image, never anything the
    # client nominated. Spec §2 step 6's last line, and the reason it is a line
    # of its own: if the client chose the source, an attacker would pass
    # liveness with their own face and then match against a photograph of the
    # woman on the card.

    if live.reference_image is None:
        return Outcome(
            decision=decisions.Decision(
                decisions.RETRY_CAPTURE, (reasons.FACE_NOT_FOUND_IN_REFERENCE,)
            ),
            id_hmac=id_hmac,
            spent_micro_usd=spent,
            provider_ids=provider_ids,
        )

    refusal = ledger.check(budget, ledger.FACE_MATCH, deps.face_match.cost_per_call)
    if refusal is not None:
        return Outcome(
            decision=decisions.Decision(decisions.RETRY_CAPTURE, (refusal.code,)),
            id_hmac=id_hmac,
            spent_micro_usd=spent,
            provider_ids=provider_ids,
        )

    match = deps.face_match.compare(inputs.card_front, live.reference_image)
    provider_ids["match"] = match.provider_id

    if not match.ok:
        return Outcome(
            decision=decisions.Decision(
                decisions.RETRY_CAPTURE, (match.reason or reasons.MATCH_PROVIDER_ERROR,)
            ),
            id_hmac=id_hmac,
            spent_micro_usd=spent,
            provider_ids=provider_ids,
        )

    charged, budget, _ = deps.ledger_store.spend(
        inputs.uid, ledger.FACE_MATCH, match.cost_micro_usd, f"{inputs.operation_id}:match"
    )
    if charged:
        spent = budget.spent_micro_usd

    # ----------------------------------------------------- step 8: decide

    signals = _with(
        signals,
        liveness_ran=True,
        liveness_confidence=live.confidence,
        match_ran=True,
        match_similarity=match.similarity,
        attempts_exhausted=(
            budget.liveness_attempts >= config.MAX_LIVENESS_ATTEMPTS
        ),
        liveness_scale=getattr(deps.liveness, "score_scale", None),
        match_scale=getattr(deps.face_match, "score_scale", None),
    )

    return Outcome(
        decision=decisions.decide(signals, deps.thresholds),
        id_hmac=id_hmac,
        reference_image=live.reference_image,
        card_front=inputs.card_front,
        liveness_confidence=live.confidence,
        match_similarity=match.similarity,
        spent_micro_usd=spent,
        provider_ids=provider_ids,
    )


def _with(signals: decisions.Signals, **changes) -> decisions.Signals:
    """Signals is frozen, so accumulating means replacing."""
    from dataclasses import replace

    return replace(signals, **changes)
