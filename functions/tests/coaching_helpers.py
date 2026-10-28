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
    """A recorder for `notify(uid, kind)` that is the list of (uid, kind).
    A payments push also gets what its tap opens, kept in `.refs`."""

    def __init__(self, *items):
        super().__init__(*items)
        self.refs = []

    def __call__(self, uid, kind, ref=None):
        self.append((uid, kind))
        self.refs.append((uid, kind, ref))


class Notes:
    """A recorder for `notify(uid, kind)` (`.sent`, also `.notes`) and for
    `merge_claims(uid, changes)` (`.claims`). Call it, or pass `.notify`."""

    def __init__(self):
        self.sent = []
        self.refs = []  # (uid, kind, ref): what a payments push's tap opens
        self.claims = []

    @property
    def notes(self):
        return self.sent

    def __call__(self, uid, kind, ref=None):
        self.sent.append((uid, kind))
        self.refs.append((uid, kind, ref))

    def notify(self, uid, kind, ref=None):
        self.__call__(uid, kind, ref)

    def merge(self, uid, changes):
        self.claims.append((uid, changes))


Recorder = Notes
