"""S13 and S16: the queries the functions run have their indexes, and the TTL
fields have their policies declared next to them.

Reads firebase/firestore.indexes.json as text, the way the app's own index test
does, so it runs with no emulator and no project.
"""

from __future__ import annotations

import json
import os

_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_INDEXES = os.path.join(_ROOT, "firebase", "firestore.indexes.json")


def _spec() -> dict:
    with open(_INDEXES, encoding="utf-8") as handle:
        return json.load(handle)


def _composite(group: str, fields: list[str]) -> bool:
    for index in _spec()["indexes"]:
        if index["collectionGroup"] != group:
            continue
        if [f["fieldPath"] for f in index["fields"]] == fields:
            return True
    return False


def test_expire_stale_reviews_has_its_composite_index():
    # state == PENDING_REVIEW and slaExpiresAt < now: equality plus a range on a
    # second field. Without the composite the hourly job fails on every run.
    assert _composite("verification_flags", ["state", "slaExpiresAt"])


def test_the_reviewer_queue_has_its_composite_index():
    assert _composite("verification_flags", ["state", "createdAt"])


def test_the_chat_rate_limit_has_its_composite_index():
    # chat.too_fast: senderUid == x and createdAt >= t. Without the index every
    # client message in the thread fails before it is counted, hidden or pushed.
    assert _composite("messages", ["senderUid", "createdAt"])


def test_the_report_throttle_has_its_composite_index():
    # main.on_coaching_report: reporterUid == x and createdAt >= t. Without it
    # no evidence is captured for any report.
    assert _composite("reports", ["reporterUid", "createdAt"])


def test_ttl_policies_are_declared_for_the_expiring_collections():
    ttl = {
        (o["collectionGroup"], o["fieldPath"])
        for o in _spec()["fieldOverrides"]
        if o.get("ttl") is True
    }
    assert ttl == {
        ("verificationSessions", "expiresAt"),
        ("verificationJobs", "expireAt"),
        ("verification_flags", "expireAt"),
        # W1: 180 days for a waitlist entry, two days for its per-IP counter.
        ("waitlist", "expireAt"),
        ("waitlistRate", "expireAt"),
        # M9: the fraud signals and the reviewer access log expire too.
        ("verificationBehaviour", "expireAt"),
        ("verificationInstalls", "expireAt"),
        ("verificationReviewAccess", "expireAt"),
        # M11: the proof she agreed to the waitlist wording, three years.
        ("waitlistConsentProof", "expireAt"),
        # The console: every read of it, a year; error counts, 90 days.
        ("adminAccessLog", "expireAt"),
        ("opsErrors", "expireAt"),
        ("verificationBookings", "expireAt"),
        # Meal-photo repeat answers: 30 days.
        ("scanCache", "expiresAt"),
        # InstaPay: the replay answer of a double tap, 30 days (it carries a coach's address).
        ("paymentIdempotency", "expireAt"),
    }


def test_the_console_and_events_have_their_composite_indexes():
    # admin_dashboard counts outcomes by state over a decidedAt window, and
    # admin_logs pages one outcome newest first; a member's events query is
    # status == published over endsAt.
    assert _composite("verificationJobs", ["state", "decidedAt"])
    assert _composite("events", ["status", "endsAt"])


def test_no_ttl_on_the_registry():
    # The registry entry is closed, not deleted, and has no clock of its own.
    for o in _spec()["fieldOverrides"]:
        if o.get("ttl"):
            assert o["collectionGroup"] != "nidRegistry"


def test_every_entry_says_why_and_every_override_exempts():
    spec = _spec()
    for index in spec["indexes"]:
        assert index.get("_why")
    for override in spec["fieldOverrides"]:
        assert override.get("_why")
        # Every override exempts a field, except the ones that switch on a
        # collection-group index a query needs; those hold nothing sensitive.
        if override["indexes"]:
            # ledger: the payout run; promoVideos: the staff month view and the 20th reminder.
            assert override["collectionGroup"] in ("ledger", "promoVideos")
            assert {"queryScope": "COLLECTION_GROUP", "order": "ASCENDING"} in override["indexes"]


def test_the_instapay_composite_indexes_the_new_jobs_need_exist():
    assert _composite("feeStatements", ["coachUid", "status"])          # fees.confirm_payment: is another statement of hers late
    assert _composite("payments", ["status", "expiresAt"])              # timers.hourly: the 12 hour reminder, expiry
    assert _composite("payments", ["status", "statusAt"])               # retention.sweep_screenshots
    assert _composite("payments", ["coachUid", "feeOwedAt"])
    assert _composite("paymentStrikes", ["uid", "role", "at"])          # strikes.live_strikes
