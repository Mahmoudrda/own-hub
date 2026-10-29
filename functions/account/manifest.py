"""contracts/deletion_manifest.json, mapped row by row onto what the server does.

The manifest is data so that an omission is visible (G7 §7.3). Every row must
map to an action here; a row with no action raises at import time, so a new
collection added to the manifest without server handling breaks the deploy
instead of being left behind on the server.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass

_CONTRACT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "contracts",
    "deletion_manifest.json",
)
# When deployed, functions/ is the source root and contracts/ is not uploaded,
# so a byte-identical copy is committed next to this file.
# tests/test_account_deletion.py fails if the two ever differ.
_BUNDLED = os.path.join(os.path.dirname(os.path.abspath(__file__)), "deletion_manifest.json")


@dataclass(frozen=True)
class Row:
    number: int
    path: str
    method: str


# What the server does for each row. See deletion.run for the order.
USERS_RECURSIVE = "users_recursive"        # db.recursive_delete(users/{uid})
PLANS_RECURSIVE = "plans_recursive"        # db.recursive_delete(plans/{uid})
REVERSE_BLOCKED_BY = "reverse_blocked_by"  # users/{other}/blockedBy/{uid}
JOBS = "jobs"                              # verificationJobs where uid ==
FLAGS = "flags"                            # verification_flags where uid ==
SESSIONS = "sessions"                      # verificationSessions where uid ==
LEDGER = "ledger"                          # verificationLedger/{uid}
BOOKINGS = "bookings"                      # verificationBookings where uid ==
REVIEWER_DATA = "reviewer_data"            # verificationReviewers/{uid}, her slots
PREAPPROVED = "preapproved"                # verificationPreapproved/{her Auth phone}
REGISTRY = "registry"                      # nidRegistry where uid == : closed
STORAGE = "storage"                        # deletion.STORAGE_PREFIXES, both buckets
GROUP_HOOK = "group_hook"                  # row 26: community, coach, assistant (N14)
THIRD_PARTY = "third_party"                # no identifier is ever sent
AUTH = "auth"                              # disabled first, deleted last
REPORTS = "reports"                        # pseudonymised
DELETION_RECORD = "deletion_record"        # retained: state and timestamps
HANDSET = "handset"                        # local to the phone; no server copy
TTL = "ttl"                                # not linked to her: expires on its own
                                           # clock (config.SIGNAL_RETENTION_DAYS,
                                           # ACCESS_LOG_RETENTION_DAYS, field expireAt)

ACTIONS: dict[int, str] = {
    1: USERS_RECURSIVE, 2: USERS_RECURSIVE, 3: USERS_RECURSIVE, 4: USERS_RECURSIVE,
    5: USERS_RECURSIVE, 6: USERS_RECURSIVE, 7: USERS_RECURSIVE, 8: USERS_RECURSIVE,
    9: HANDSET,
    10: USERS_RECURSIVE,  # consents live under users/{uid}; a coach's coach-terms records are copied to legalHolds/{uid} first (account/legal_hold.py)
    11: USERS_RECURSIVE, 12: USERS_RECURSIVE, 13: USERS_RECURSIVE, 14: USERS_RECURSIVE,
    15: USERS_RECURSIVE, 16: USERS_RECURSIVE,
    17: REVERSE_BLOCKED_BY,
    18: USERS_RECURSIVE, 19: USERS_RECURSIVE,
    20: PLANS_RECURSIVE, 21: PLANS_RECURSIVE,
    22: JOBS,
    23: REGISTRY,
    24: STORAGE,  # a coach's signed agreement is copied to legal-hold/{uid}/ first (account/legal_hold.py)
    25: STORAGE,
    26: GROUP_HOOK,
    27: THIRD_PARTY, 28: THIRD_PARTY,
    29: AUTH,
    30: REPORTS,
    31: DELETION_RECORD,
    32: USERS_RECURSIVE,
    33: HANDSET, 34: HANDSET,
    35: USERS_RECURSIVE, 36: USERS_RECURSIVE, 37: USERS_RECURSIVE, 38: USERS_RECURSIVE,
    39: FLAGS,
    40: LEDGER,
    41: SESSIONS,
    42: TTL, 43: TTL, 44: TTL,
    # Community and coach data, named row by row (APL-16). All five run inside
    # row 26's purge_group_hook.
    45: GROUP_HOOK, 46: GROUP_HOOK, 47: GROUP_HOOK, 48: GROUP_HOOK, 49: GROUP_HOOK,
    50: BOOKINGS,
    51: REVIEWER_DATA,
    52: PREAPPROVED,
    53: GROUP_HOOK,  # events/{eventId}/attendees/{uid}, run inside purge_group_hook
    54: GROUP_HOOK,  # communityFoodCandidates/{key}/by/{hash}, run inside purge_group_hook
    # Private coaching, all run inside purge_group_hook.
    55: GROUP_HOOK, 56: GROUP_HOOK, 57: GROUP_HOOK, 58: GROUP_HOOK,
    59: GROUP_HOOK,  # receipts, paymentProofs: pseudonymised inside purge_group_hook
    60: REPORTS,     # the copy of what was reported: deleted when the reporter deletes hers; kept pseudonymised when the reported side does, until the reporter deletes hers or the retention period set with counsel
    61: GROUP_HOOK,  # coachPrivate/{uid}/** is recursively deleted inside purge_group_hook; its agreement state is copied to legalHolds/{uid} first
    62: GROUP_HOOK,  # relationships/{relId}/checkIns goes with the relationship in purge_group_hook
}


def load(path: str | None = None) -> list[Row]:
    path = path or (_CONTRACT if os.path.exists(_CONTRACT) else _BUNDLED)
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    rows = [Row(int(r["number"]), r["path"], r["method"]) for r in data["rows"]]
    return sorted(rows, key=lambda r: r.number)


def check(rows: list[Row]) -> None:
    missing = [r.number for r in rows if r.number not in ACTIONS]
    if missing:
        raise RuntimeError(
            f"deletion manifest rows {missing} have no server action: a collection "
            f"added to the manifest must be handled in account/manifest.py"
        )


ROWS = load()
check(ROWS)
