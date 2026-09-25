"""One national ID, one account. Spec §2 step 5.

The whole mechanism is a keyed hash used as a document id:

    id_hmac = HMAC-SHA256(key = ID_PEPPER, message = the 14 digits)

and `nidRegistry/{id_hmac}` holds `{uid, pepper_version, state, createdAt}` and
nothing else. **The raw number is never stored**, anywhere, in any form. It is
discarded from memory immediately after this step, which is spec §2 step 5's
last line and is enforced by `hash_and_forget` below taking the number and
returning only the hash.

## Why HMAC and not a plain hash

`sha256(pepper + number)` is length-extendable and, more practically, invites
the mistake of concatenating in the other order or with no separator. HMAC is
the standard keyed construction, it is in the standard library, and spec §4
names it explicitly.

## Why the pepper version travels with the hash

Without `pepper_version`, rotating the pepper is a one-way door: every existing
hash becomes unmatchable, every previously-registered card silently becomes
registerable again, and the one-card-one-account rule breaks without an error
anywhere. With it, a rotation can compute both and migrate.

## What a leaked pepper would mean — recorded, not hidden

An Egyptian national ID is fourteen digits but nowhere near 10^14 possibilities:
roughly 36,500 plausible birth dates x 27 governorate codes x 10,000 sequence
numbers is about 10^10. A consumer GPU does 10^10 HMAC-SHA256 operations in
well under a minute. So if the pepper leaked alongside a database dump, every
hash in nidRegistry would be reversible to a real person's ID number.

The pepper's secrecy is therefore the entire defence, and Secret Manager plus
least-privilege IAM is the entire mechanism. A memory-hard KDF (scrypt at
n=2^14 costs about 50 ms and six cents across all 50,000 verifications) would
turn that GPU minute into years, and is NOT implemented here because spec §4
specifies HMAC-SHA256 and rule of engagement 2 forbids substituting my own
judgement for a stated requirement. It is written up in RESIDUAL_RISKS.md as a
proposed hardening for the owner to accept or decline.
"""

from __future__ import annotations

import hashlib
import hmac
from dataclasses import dataclass
from typing import Optional, Protocol

from . import config, reasons

STATE_ACTIVE = "active"
STATE_CLOSED = "closed"
"""The app's own deletion manifest (row 23) closes a registry entry rather than
deleting it: `state:'closed'`, `uid:null`, so a removed woman cannot re-register
while no personal data stays linked. That shape is already documented on the
client side, so it is the shape this module writes."""


def hash_and_forget(number: str, pepper: bytes) -> str:
    """The only function that ever sees the raw number, and it returns a hash.

    Named for what it is for. The caller passes the number in and gets a hash
    back; there is no variant that returns both, and no place to put the number
    down on the way through.
    """
    return hmac.new(pepper, number.encode("ascii"), hashlib.sha256).hexdigest()


def constant_time_equal(a: str, b: str) -> bool:
    """For comparing two hashes.

    A timing side channel on a hash comparison is a stretch as a real attack
    here, but `hmac.compare_digest` costs nothing and removes the question.
    """
    return hmac.compare_digest(a, b)


@dataclass(frozen=True)
class RegistryEntry:
    uid: Optional[str]
    state: str
    pepper_version: int


@dataclass(frozen=True)
class DedupeVerdict:
    ok: bool
    reason: Optional[str] = None
    is_reverification: bool = False


def judge(entry: Optional[RegistryEntry], uid: str) -> DedupeVerdict:
    """What an existing registry entry means for this caller.

    Pure, so the three branches are testable without a database.

    The re-verification branch matters more than it looks: a woman who deletes
    the app and signs in again on a new phone hits her OWN entry, and treating
    that as a duplicate would permanently lock her out of a product she is
    entitled to use. Spec §3's REJECTED_DUPLICATE is for another account, not
    for hers.
    """
    if entry is None:
        return DedupeVerdict(ok=True)
    if entry.state == STATE_CLOSED:
        return DedupeVerdict(False, reasons.REGISTRATION_CLOSED)
    if entry.uid == uid:
        return DedupeVerdict(True, is_reverification=True)
    return DedupeVerdict(False, reasons.DUPLICATE_ID)


class RegistryStore(Protocol):
    """Implemented over Firestore in store.py.

    `claim` MUST be a transaction. Two accounts submitting the same card at the
    same moment both read "no entry" under a non-transactional read and both
    write, and the one-card-one-account rule is broken by a race that is
    trivially reproducible on a shared phone.
    """

    def read(self, id_hmac: str) -> Optional[RegistryEntry]: ...

    def claim(self, id_hmac: str, uid: str) -> DedupeVerdict: ...


def registry_document(uid: str) -> dict:
    """Exactly the fields spec §4's allowlist permits, and no others.

    Not a name, not a birth date, not a governorate, not the number. If a future
    change adds a field here, it needs a corresponding row in spec §4's table or
    it is a defect by definition.
    """
    return {
        "uid": uid,
        "state": STATE_ACTIVE,
        "pepper_version": config.PEPPER_VERSION,
    }
