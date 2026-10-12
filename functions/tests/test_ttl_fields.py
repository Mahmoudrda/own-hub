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


# ------------------------------------------- M9: the signals and the access log


class _Recorder:
    def __init__(self):
        self.writes = []

    def collection(self, name):
        return _Ref(self, name)

    def transaction(self):
        return None


class _Ref:
    def __init__(self, root, path):
        self.root, self.path = root, path

    def document(self, name):
        return _Ref(self.root, f"{self.path}/{name}")

    def set(self, payload, merge=False):
        self.root.writes.append((self.path, dict(payload)))

    def add(self, payload):
        self.root.writes.append((self.path, dict(payload)))
        return None, None


def _days_left(when):
    return (when - dt.datetime.now(dt.timezone.utc)).days


def test_a_failure_count_expires_after_the_signal_period(monkeypatch):
    recorder = _Recorder()
    monkeypatch.setattr(store, "db", lambda: recorder)
    store.FirestoreBehaviour().record_failure("hmac-1")
    (path, payload), = recorder.writes
    assert path == "verificationBehaviour/hmac-1"
    days = _days_left(payload["expireAt"])
    assert config.SIGNAL_RETENTION_DAYS - 1 <= days <= config.SIGNAL_RETENTION_DAYS


def test_an_install_record_expires_after_the_signal_period(monkeypatch):
    recorder = _Recorder()
    monkeypatch.setattr(store, "db", lambda: recorder)

    class _Snap:
        exists = False

        def to_dict(self):
            return {}

    class _Txn:
        def set(self, ref, payload):
            ref.set(payload)

    monkeypatch.setattr(_Ref, "get", lambda self, transaction=None: _Snap(), raising=False)
    monkeypatch.setattr(
        store.firestore, "transactional", lambda fn: (lambda txn: fn(_Txn()))
    )
    store.FirestoreBehaviour().record_attempt("hmac-1", "install-hash")
    (path, payload), = recorder.writes
    assert path == "verificationInstalls/install-hash"
    assert payload["hmacs"] == ["hmac-1"]
    days = _days_left(payload["expireAt"])
    assert config.SIGNAL_RETENTION_DAYS - 1 <= days <= config.SIGNAL_RETENTION_DAYS


def test_a_reviewer_access_entry_expires_after_a_year(monkeypatch):
    recorder = _Recorder()
    monkeypatch.setattr(store, "db", lambda: recorder)
    store.FirestoreReviewStore().log_access("reviewer-1", "flag-1", "contact")
    (path, payload), = recorder.writes
    assert path == config.COL_REVIEW_ACCESS
    days = _days_left(payload["expireAt"])
    assert config.ACCESS_LOG_RETENTION_DAYS - 1 <= days <= config.ACCESS_LOG_RETENTION_DAYS


def test_the_new_periods_are_marked_pending_counsel():
    import inspect

    source = inspect.getsource(config)
    for name in ("SIGNAL_RETENTION_DAYS = ", "ACCESS_LOG_RETENTION_DAYS = "):
        at = source.index(name)
        assert "PENDING COUNSEL" in source[at : at + 700], name
