"""Limits, statuses and the one read of the kill switch."""

from __future__ import annotations

import datetime as dt
from typing import Any, Optional

STATUSES = (
    "awaiting_payment", "proof_submitted", "confirmed", "expired", "cancelled",
    "coach_not_received", "in_review", "resolved_paid", "resolved_unpaid",
    "different_amount", "refund_requested", "refunded", "refund_denied", "service_dispute",
)

# A payment in these statuses still holds the coach's unique amount (WO-10m).
HOLDS_AMOUNT = (
    "awaiting_payment", "expired", "proof_submitted", "coach_not_received",
    "in_review", "different_amount",
)

# Statuses in which the amount lock is pushed out to 30 days (a review can take long).
LONG_HOLD = ("proof_submitted", "coach_not_received", "in_review", "different_amount")

# The package may run (fully) only in these (spec section 3).
PAID_STATUSES = ("confirmed", "resolved_paid")

LIMITS = {
    "expiryHours": 24,            # 4.7: a request lasts 24 hours
    "lateProofDays": 7,           # 4.7: a proof within 7 days of the request is still accepted
    "coachRemindHours": 48,       # 4.1
    "escalateHours": 72,          # 4.1, 4.5
    "amberHours": 24,             # 13.4: amber turns into access after 24 hours with no objection
    "provisionalMaxDays": 7,      # 13.1: at most 7 days or the first package week
    "autoConfirmFlagHours": 48,   # 13.4: a coach may flag an auto-confirmed payment within 48 hours
    "refundCoachDays": 3,         # 4.8
    "refundWindowDays": 14,       # 4.8 / RELEASE-2-PLAN 3.10
    "requestsPerDay": 3,          # 4.12
    "disputesPerMonth": 3,        # 4.12
    "screenshotsPerPayment": 5,   # 4.12
    "screenshotMaxBytes": 5_000_000,   # 4.12: at most 5 MB
    "screenshotLongSidePx": 1600,
    "addressDelayHours": 24,      # 4.4
    "strikeWindowDays": 90,       # 13.5
    "strikesToSuspend": 2,        # 4.1, 4.2, 13.5
    "disputeRateMinPayments": 10, # 13.5 (owner tunable in coachingConfig/instapay)
    "disputeRatePercent": 10,
    "feeOverdueDays": 30,         # 4.13
    "idempotencyDays": 30,
    "firstPaymentsStaffVisible": 3,   # 13.1
    "cleanPaymentsForAutoConfirm": 3, # 13.4
    "feeBpsMarketplace": 1500,    # D63 default; the owner overrides in coachingConfig/instapay
    "feeBpsInvite": 800,          # D63 default
    "maxAmountEgp": 20000,        # UNVERIFIED placeholder, see WO-10m step 1
}


def hours(n: int) -> dt.timedelta:
    return dt.timedelta(hours=n)


def days(n: int) -> dt.timedelta:
    return dt.timedelta(days=n)


def pounds_text(piasters: int) -> str:
    """50037 -> '500.37' (Western digits, always two decimals)."""
    return f"{piasters // 100}.{piasters % 100:02d}"


def enabled(db) -> bool:
    """The kill switch. A missing document means OFF (safe); the owner creates
    config/payments with {enabled: true} at deploy (WO-10p)."""
    snap = db.collection("config").document("payments").get()
    row: Optional[dict] = snap.to_dict() if snap.exists else None
    return bool(row) and row.get("enabled") is True


def config(db) -> dict:
    """coachingConfig/instapay merged over the defaults in LIMITS. Server-only."""
    snap = db.collection("coachingConfig").document("instapay").get()
    row: dict[str, Any] = (snap.to_dict() or {}) if snap.exists else {}
    keys = ("feeBpsMarketplace", "feeBpsInvite", "maxAmountEgp",
            "disputeRateMinPayments", "disputeRatePercent")
    return {k: row[k] if isinstance(row.get(k), int) and not isinstance(row.get(k), bool) else LIMITS[k] for k in keys}
