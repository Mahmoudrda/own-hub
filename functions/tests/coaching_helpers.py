"""Test helpers the coaching test files share. Import what you use; the
`_txn` fixture must be imported by name into a test module for pytest to run
it there."""

from __future__ import annotations

import pytest
from google.cloud import firestore

from coaching import errors
from tests import fake_firestore


@pytest.fixture(autouse=True)
def _txn(monkeypatch):
    """Runs every `common.run` transaction against the in-memory Firestore."""
    monkeypatch.setattr(firestore, "transactional", fake_firestore.transactional)


def refusal(call):
    """(code, reason) of the CoachingError `call` raises."""
    with pytest.raises(errors.CoachingError) as caught:
        call()
    return caught.value.code, caught.value.reason


class Pushes(list):
    """A recorder for `notify(uid, kind)` that is the list of (uid, kind)."""

    def __call__(self, uid, kind):
        self.append((uid, kind))


class Notes:
    """A recorder for `notify(uid, kind)` (`.sent`, also `.notes`) and for
    `merge_claims(uid, changes)` (`.claims`). Call it, or pass `.notify`."""

    def __init__(self):
        self.sent = []
        self.claims = []

    @property
    def notes(self):
        return self.sent

    def __call__(self, uid, kind):
        self.sent.append((uid, kind))

    def notify(self, uid, kind):
        self.sent.append((uid, kind))

    def merge(self, uid, changes):
        self.claims.append((uid, changes))


Recorder = Notes
