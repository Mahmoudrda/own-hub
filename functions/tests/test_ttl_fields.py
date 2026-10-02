"""S16: decided records carry expireAt for the TTL policy; waiting ones do not."""

from __future__ import annotations

import datetime as dt

from identity import config, decisions, reasons, store


def _payload(outcome, code=reasons.MATCH_PASS):
    return store.job_payload("her", decisions.Decision(outcome, (code,)), 1)


def test_decided_jobs_carry_an_expiry():
    for outcome in (
        decisions.APPROVED,
        decisions.REJECTED_NOT_ELIGIBLE,
        decisions.REJECTED_FAILED,
        decisions.REJECTED_DUPLICATE,
        decisions.RETRY_CAPTURE,
    ):
        payload = _payload(outcome)
        assert "expireAt" in payload, outcome
        days = (payload["expireAt"] - dt.datetime.now(dt.timezone.utc)).days
        assert config.DECIDED_RECORD_RETENTION_DAYS - 1 <= days <= config.DECIDED_RECORD_RETENTION_DAYS


def test_a_job_waiting_on_review_never_expires():
    assert "expireAt" not in _payload(decisions.PENDING_REVIEW, reasons.NIQAB_PATH_REQUESTED)


def test_the_allowlist_admits_expire_at():
    assert "expireAt" in store._ALLOWED_JOB_FIELDS


def test_retention_is_marked_pending_counsel():
    import inspect

    source = inspect.getsource(config)
    at = source.index("DECIDED_RECORD_RETENTION_DAYS = ")
    assert "PENDING COUNSEL" in source[at : at + 600]
