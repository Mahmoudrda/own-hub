"""The state machine as data. A change that is not in TRANSITIONS is refused."""

from __future__ import annotations

from . import errors

CLIENT, COACH, STAFF, SYSTEM = "client", "coach", "staff", "system"

# (from, to) -> who may make the move. Spec section 3 plus section 13:
#  - awaiting_payment/expired -> confirmed: the coach reported the payment and the client agrees (4.5)
#  - proof_submitted -> in_review by system: a RED proof, or 72 hours of silence (4.1, 13.4)
#  - confirmed -> in_review by coach: ONLY for an auto-confirmed payment within 48 hours,
#    with evidence (13.4); the callable checks that, not this table
#  - resolved_* / confirmed -> in_review by staff: a second reviewer reopens (13.9)
#  - refunded -> in_review: the coach's refund record is her word only, so the client
#    (she did not receive it) or staff can open a dispute; no other way back (4.8)
#  - expired -> cancelled: a request that nobody paid has an exit
TRANSITIONS: dict[tuple[str, str], frozenset] = {
    ("awaiting_payment", "proof_submitted"): frozenset({CLIENT}),
    ("awaiting_payment", "confirmed"): frozenset({CLIENT}),
    ("awaiting_payment", "cancelled"): frozenset({CLIENT}),
    ("awaiting_payment", "expired"): frozenset({SYSTEM}),
    ("awaiting_payment", "in_review"): frozenset({SYSTEM}),
    ("expired", "proof_submitted"): frozenset({CLIENT}),
    ("expired", "confirmed"): frozenset({CLIENT}),
    ("expired", "in_review"): frozenset({SYSTEM}),
    ("expired", "cancelled"): frozenset({CLIENT, SYSTEM}),
    ("proof_submitted", "confirmed"): frozenset({COACH, SYSTEM}),
    ("proof_submitted", "coach_not_received"): frozenset({COACH}),
    ("proof_submitted", "different_amount"): frozenset({COACH}),
    ("proof_submitted", "in_review"): frozenset({SYSTEM}),
    ("coach_not_received", "in_review"): frozenset({SYSTEM}),
    ("different_amount", "confirmed"): frozenset({CLIENT}),
    ("different_amount", "cancelled"): frozenset({CLIENT}),
    ("different_amount", "in_review"): frozenset({CLIENT, SYSTEM}),
    ("in_review", "resolved_paid"): frozenset({STAFF}),
    ("in_review", "resolved_unpaid"): frozenset({STAFF}),
    ("in_review", "confirmed"): frozenset({STAFF}),
    ("in_review", "refunded"): frozenset({COACH}),
    ("confirmed", "refund_requested"): frozenset({CLIENT}),
    ("confirmed", "service_dispute"): frozenset({CLIENT}),
    ("confirmed", "in_review"): frozenset({STAFF, COACH}),
    ("resolved_paid", "refund_requested"): frozenset({CLIENT}),
    ("resolved_paid", "service_dispute"): frozenset({CLIENT}),
    ("resolved_paid", "in_review"): frozenset({STAFF}),
    ("resolved_unpaid", "in_review"): frozenset({STAFF}),
    ("refunded", "in_review"): frozenset({CLIENT, STAFF}),
    ("refund_requested", "refunded"): frozenset({COACH}),
    ("refund_requested", "refund_denied"): frozenset({COACH}),
    ("refund_requested", "in_review"): frozenset({SYSTEM}),
    ("refund_denied", "in_review"): frozenset({CLIENT}),
    ("service_dispute", "in_review"): frozenset({SYSTEM}),
}


def check(frm: str, to: str, role: str) -> None:
    """Raises illegal_transition unless `role` may move `frm` to `to`."""
    allowed = TRANSITIONS.get((frm, to))
    if allowed is None or role not in allowed:
        raise errors.CoachingError(errors.PRECONDITION, errors.ILLEGAL_TRANSITION)


# (from, to) -> [(who gets it, notice kind)]. Kinds are keys of notices.TEXT.
# A pair missing here sends nothing (for example expiry, which is silent).
_NOTICES: dict[tuple[str, str], list[tuple[str, str]]] = {
    ("awaiting_payment", "proof_submitted"): [(COACH, "instapayProofSent")],
    ("expired", "proof_submitted"): [(COACH, "instapayProofSent")],
    ("awaiting_payment", "confirmed"): [(COACH, "instapayConfirmedByClient")],
    ("proof_submitted", "confirmed"): [(CLIENT, "instapayConfirmed")],
    ("proof_submitted", "coach_not_received"): [(CLIENT, "instapayNotReceived")],
    ("proof_submitted", "different_amount"): [(CLIENT, "instapayDifferentAmount")],
    ("proof_submitted", "in_review"): [(CLIENT, "instapayReviewStarted"), (COACH, "instapayDisputeOpened")],
    ("awaiting_payment", "in_review"): [(CLIENT, "instapayReviewStarted"), (COACH, "instapayDisputeOpened")],
    ("expired", "in_review"): [(CLIENT, "instapayReviewStarted"), (COACH, "instapayDisputeOpened")],
    ("coach_not_received", "in_review"): [(CLIENT, "instapayReviewStarted")],
    ("different_amount", "in_review"): [(COACH, "instapayDisputeOpened")],
    ("in_review", "resolved_paid"): [(CLIENT, "instapayReviewDecided"), (COACH, "instapayCoachReviewDecided")],
    ("in_review", "resolved_unpaid"): [(CLIENT, "instapayReviewDecided"), (COACH, "instapayCoachReviewDecided")],
    ("in_review", "confirmed"): [(CLIENT, "instapayReviewDecided"), (COACH, "instapayCoachReviewDecided")],
    ("in_review", "refunded"): [(CLIENT, "instapayRefundRecorded")],
    ("refund_requested", "refunded"): [(CLIENT, "instapayRefundRecorded")],
    ("confirmed", "refund_requested"): [(COACH, "instapayRefundRequested")],
    ("resolved_paid", "refund_requested"): [(COACH, "instapayRefundRequested")],
    ("refund_requested", "refund_denied"): [(CLIENT, "instapayReviewDecided")],
    ("refund_requested", "in_review"): [(CLIENT, "instapayReviewStarted"), (COACH, "instapayDisputeOpened")],
    ("service_dispute", "in_review"): [(CLIENT, "instapayReviewStarted"), (COACH, "instapayDisputeOpened")],
    ("refund_denied", "in_review"): [(CLIENT, "instapayReviewStarted"), (COACH, "instapayDisputeOpened")],
    ("refunded", "in_review"): [(CLIENT, "instapayReviewStarted"), (COACH, "instapayDisputeOpened")],
}


def notices_for(frm: str, to: str) -> list[tuple[str, str]]:
    return list(_NOTICES.get((frm, to), []))
