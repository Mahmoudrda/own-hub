"""Spec §6: the per-uid cost ledger, in micro-USD.

The rule is one sentence: **before every paid call, refuse if
`spent + next_call_cost > COST_CAP`.** Everything else here exists to make that
sentence true under concurrency, under retries, and under a provider that fails
after we have already committed to paying it.

Integers throughout. A budget check written in floating point accumulates error
and eventually either refuses a call it should allow or allows one it should
refuse; money is counted, never measured.

Three properties that are easy to get wrong and are each enforced below:

  * **Charge on success, not on intent.** `reserve` checks the budget and
    `commit` debits it. A provider timeout or 5xx never debits, because spec
    §9.4 requires that a failed call gives the user a retry with no charge.
    Charging a woman's budget for our vendor's outage would lock her out of the
    product through no fault of her own.

  * **Attempt limits are counted separately from spend.** Spec §6 caps 4 OCR
    submissions and 2 liveness attempts as well as the 50,000 µUSD. Both must
    hold: a cheap provider would otherwise let someone attempt forever.

  * **The check and the debit are one transaction.** Two concurrent requests
    that both read "44,000 spent" would both pass a non-transactional check and
    both spend, landing at 60,000. Spec §5 requires callables to be idempotent
    and this is half of how that is achieved; the other half is the
    `operation_id` below.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Protocol

from . import config, reasons

OCR_SUBMISSION = "ocr"
LIVENESS_ATTEMPT = "liveness"
FACE_MATCH = "match"


@dataclass(frozen=True)
class Budget:
    """One uid's spending state."""

    spent_micro_usd: int = 0
    ocr_submissions: int = 0
    liveness_attempts: int = 0
    operations: tuple[str, ...] = ()
    """The operation ids already applied, newest last, as `spend` stored them.

    Carried on the budget rather than fetched separately because the pipeline
    already reads the budget before the first paid call, so checking for a
    replayed operation id costs nothing extra — and it has to be checked THERE,
    before the provider is contacted, not inside `spend` afterwards.

    Inside `spend` the idempotency check happens after the provider has already
    been called and billed, so it prevents the second debit without preventing
    the second bill. A client that repeats one operation id therefore used to
    get an unlimited number of billed Vision calls against a ledger that moved
    exactly once. `operation_id` is chosen by the client (main.py takes it
    straight from the request body), so that was an attacker-controlled way to
    suppress the debit, not a rare accident."""

    bonus_ocr_submissions: int = 0
    """Extra OCR submissions granted when OUR review queue missed its SLA.

    S7: an undecided flag past REVIEW_SLA_HOURS is our failure, not hers, so
    expiry grants exactly one more photograph of the card, and only while the
    cumulative spend stays under COST_CAP_MICRO_USD (see `may_grant_bonus`).
    Nothing ever resets `spent_micro_usd` or the counters; the bonus raises the
    ceiling the counter is compared against instead.

    Consequence worth stating: if her liveness attempts are already used, the
    bonus submission passes OCR and then meets `decide_budget_refusal`, which
    opens a second review. That is the intended "our backlog failed her"
    outcome, not a loop: each grant is tied to one expired flag."""

    @property
    def remaining(self) -> int:
        return config.COST_CAP_MICRO_USD - self.spent_micro_usd

    def already_applied(self, operation_id: str) -> bool:
        """Has this exact operation id already been charged for?

        `spend` keeps only the last 50 ids, so this answers "recently" rather
        than "ever". That is the right window: it covers any plausible retry
        while keeping the ledger document well inside Firestore's 1 MiB limit,
        and an id that has aged out of the list is one whose 50 successors have
        each been charged for in the meantime, so the spend was real."""
        return bool(operation_id) and operation_id in self.operations


@dataclass(frozen=True)
class Refusal:
    code: str


def check(budget: Budget, kind: str, cost: int) -> Optional[Refusal]:
    """May this call be made? None means yes.

    Pure, so tests/test_ledger.py can walk the boundary exactly — including the
    case that sits ON the cap, which spec §9.4 requires be refused BEFORE the
    provider is contacted rather than after.
    """
    if kind == OCR_SUBMISSION and budget.ocr_submissions >= (
        config.MAX_OCR_SUBMISSIONS + budget.bonus_ocr_submissions
    ):
        return Refusal(reasons.ATTEMPT_LIMIT_OCR)
    if (
        kind == LIVENESS_ATTEMPT
        and budget.liveness_attempts >= config.MAX_LIVENESS_ATTEMPTS
    ):
        return Refusal(reasons.ATTEMPT_LIMIT_LIVENESS)
    if budget.spent_micro_usd + cost > config.COST_CAP_MICRO_USD:
        return Refusal(reasons.COST_CAP_REACHED)
    return None


def apply(budget: Budget, kind: str, cost: int) -> Budget:
    """The budget after a SUCCESSFUL call. Never called on a failure."""
    return Budget(
        spent_micro_usd=budget.spent_micro_usd + cost,
        ocr_submissions=budget.ocr_submissions + (1 if kind == OCR_SUBMISSION else 0),
        liveness_attempts=budget.liveness_attempts
        + (1 if kind == LIVENESS_ATTEMPT else 0),
        bonus_ocr_submissions=budget.bonus_ocr_submissions,
    )


def may_grant_bonus(budget: Budget, flag_id: str, granted_for: tuple = ()) -> bool:
    """S7: may an expired review earn her one more OCR submission?

    Only if a whole submission (front and back) still fits under the cost cap,
    and only once per expired flag. The cap is never raised and the spend is
    never reset: the grant is a second chance inside the same ceiling.
    """
    from . import providers

    if flag_id in tuple(granted_for or ()):
        return False
    return (
        budget.spent_micro_usd + 2 * providers.COST_OCR_PER_IMAGE
        <= config.COST_CAP_MICRO_USD
    )


def worst_case_micro_usd() -> int:
    """The arithmetic, executed rather than asserted in a comment.

    4 OCR submissions x 2 images x 1,500 + 2 liveness attempts x (0 + 0)
    = 12,000 + 0 = 12,000, well under the 50,000 cap.

    Spec §6 wrote this as 44,000 on the assumption of AWS liveness at 15,000 and
    CompareFaces at 1,000. The owner has decided against AWS, so the only money
    in this pipeline is Cloud Vision.

    Computed, not hard-coded, so that adding a paid provider back — or Google
    changing Vision's price — moves this number automatically and trips the test
    below if it ever crosses the ceiling.
    """
    from . import providers

    ocr = config.MAX_OCR_SUBMISSIONS * 2 * providers.COST_OCR_PER_IMAGE
    liveness = config.MAX_LIVENESS_ATTEMPTS * (
        providers.COST_LIVENESS_SESSION + providers.COST_FACE_MATCH
    )
    return ocr + liveness


class LedgerStore(Protocol):
    """The transactional half. Implemented over Firestore in store.py.

    `spend` must perform check-and-debit inside ONE transaction and must be
    idempotent on `operation_id`: a double tap resends the same operation id,
    and the second call must return the first call's answer rather than
    charging twice. Spec §5 requires exactly this.
    """

    def read(self, uid: str) -> Budget: ...

    def spend(
        self, uid: str, kind: str, cost: int, operation_id: str
    ) -> tuple[bool, Budget, Optional[str]]: ...
