"""Suite-wide guard: no test may open a real Firestore client.

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
    yield
