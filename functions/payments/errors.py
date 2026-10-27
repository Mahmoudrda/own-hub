"""Refusal codes. No sentence is composed here: the app speaks both languages."""

from __future__ import annotations

from coaching.errors import (  # noqa: F401  (re-exported for the other modules)
    BAD_REQUEST,
    EXHAUSTED,
    IMAGE_INVALID,
    INVALID,
    NOT_FOUND,
    NOT_VERIFIED,
    PERMISSION,
    PRECONDITION,
    WRONG_STATUS,
    CoachingError,
)

PAYMENTS_OFF = "payments_off"
PAYMENT_NOT_FOUND = "payment_not_found"
ILLEGAL_TRANSITION = "illegal_transition"
COACH_NOT_READY = "coach_not_ready"
COACH_PAYMENTS_SUSPENDED = "coach_payments_suspended"
CLIENT_PAYMENTS_SUSPENDED = "client_payments_suspended"
AMOUNT_OVER_LIMIT = "amount_over_limit"
FIRST_PAYMENT_SHORTEST_ONLY = "first_payment_shortest_only"
TOO_MANY_REQUESTS = "too_many_requests"
OPEN_PAYMENT_EXISTS = "open_payment_exists"
AMOUNT_UNAVAILABLE = "amount_unavailable"
AMOUNT_MISMATCH = "amount_mismatch"
PROOF_WINDOW_CLOSED = "proof_window_closed"
TOO_MANY_SCREENSHOTS = "too_many_screenshots"
PROOF_INCOMPLETE = "proof_incomplete"
WRONG_KIND_OF_MESSAGE = "wrong_kind_of_message"
CLAIM_CONTRADICTED = "appears_in_statement"
EVIDENCE_REQUIRED = "evidence_required"
REASON_REQUIRED = "reason_required"
NO_COACH_REPORT = "no_coach_report"
TXN_REUSED = "txn_reused"
ADDRESS_NOT_HANDLE = "address_not_handle"
ADDRESS_FORMAT = "address_format"
RECENT_SIGN_IN_REQUIRED = "recent_sign_in_required"
REFUND_WINDOW_CLOSED = "refund_window_closed"
REFUND_ALREADY_REQUESTED = "refund_already_requested"
DISPUTE_LIMIT = "dispute_limit"
DISPUTE_ALREADY_USED = "dispute_already_used"
DISPUTE_WINDOW_CLOSED = "dispute_window_closed"
AUTO_CONFIRM_OFF = "auto_confirm_off"
REFUND_TXN_INVALID = "refund_txn_invalid"
REFUND_PAID_AT_INVALID = "refund_paid_at_invalid"
ACCEPT_LOWER_TOO_LOW = "accept_lower_too_low"
TWO_STAFF_REQUIRED = "two_staff_required"
SAME_STAFF = "same_staff"
NOT_YOUR_PAYMENT = PAYMENT_NOT_FOUND  # one reason, so a stranger learns nothing
