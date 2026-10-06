"""Suite-wide guard: no test may open a real Firestore client or read a secret.

The store module creates `firestore.Client(project="own-hub")` lazily. On a
machine with Application Default Credentials that is the production project, so
a test that forgot a stub would read (or worse, write) real data. Every test
must stub what it reaches; this makes forgetting fail loudly instead.
"""

import pytest


@pytest.fixture(autouse=True)
def _no_real_firestore(monkeypatch):
    from identity import store

    def refuse():
        raise AssertionError("a test reached store.db(): stub the store call instead")

    monkeypatch.setattr(store, "db", refuse)

    from identity import webhook

    def no_secret():
        raise AssertionError("a test reached Secret Manager: stub webhook._secret_url")

    monkeypatch.setattr(webhook, "_secret_url", no_secret)

    # M13: no test reads the store reviewer list from Secret Manager. Nobody
    # is a reviewer unless a test says so.
    monkeypatch.setattr(store, "store_reviewer_uids", lambda: frozenset())
    monkeypatch.setattr(store, "store_reviewer_phones", lambda: frozenset())
    # verify_identity marks itself in flight on the ledger (request_review
    # refuses meanwhile). A no-op unless a test says otherwise; the store
    # functions themselves are tested against the fake Firestore.
    monkeypatch.setattr(store, "mark_verify_in_flight", lambda uid, now=None: None)
    monkeypatch.setattr(store, "clear_verify_in_flight", lambda uid: None)
    monkeypatch.setattr(webhook, "_url_cache", None)
    monkeypatch.delenv("FLAG_WEBHOOK_URL", raising=False)
    monkeypatch.delenv("FUNCTIONS_EMULATOR", raising=False)

    # Bookings are refused in the past and beyond a 7-day horizon. Tests book
    # fixed dates (2026-10-05), so "now" for scheduling is pinned to the day
    # they were written; tests that care pass now= explicitly.
    import datetime as dt

    from identity import review

    monkeypatch.setattr(
        review, "_now", lambda: dt.datetime(2026, 10, 2, 12, tzinfo=dt.timezone.utc)
    )
    yield
