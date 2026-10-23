"""C08: the apps she chose to hold, written by the server (D11).

`users/{uid}.roles` is outside the client's write whitelist in
firestore.rules, so this callable is the only writer. What it records is the
navigation she chose: trainee, coach or both. It grants nothing on the server:
every coach privilege in the rules reads the `coachV` claim, which only a
reviewer's decision mints. The copy here is what lets a new phone open on the
right side of the app.
"""

from __future__ import annotations

from typing import Optional

from . import errors

HELD = {
    "trainee": ["trainee"],
    "coach": ["coach"],
    "both": ["trainee", "coach"],
}
"""Her choice at C08 and the roles it gives her app, in a fixed order."""

FIELDS = ("held", "chosen", "at")
"""Every key `users/{uid}.roles` may carry, and nothing else."""


def held_for(choice) -> Optional[list]:
    if not isinstance(choice, str):
        return None
    held = HELD.get(choice)
    return list(held) if held is not None else None


def record(
    db, uid: str, data: dict, *, live: bool, timestamp, coach_v: Optional[str] = None
) -> dict:
    """Writes `users/{uid}.roles` from `{role}`. A coach role while the coach
    app is closed, or without the server-minted coach claim, is refused and
    nothing is written."""
    choice = data.get("role")
    held = held_for(choice)
    if held is None:
        raise errors.CoachingError(errors.INVALID, errors.BAD_REQUEST)
    if "coach" in held and not live:
        raise errors.CoachingError(errors.PRECONDITION, errors.COACH_APP_CLOSED)
    if "coach" in held and coach_v != "active":
        raise errors.CoachingError(errors.PERMISSION, errors.NOT_A_COACH)
    roles = {"held": held, "chosen": choice, "at": timestamp}
    assert set(roles) <= set(FIELDS)
    db.collection("users").document(uid).set({"roles": roles}, merge=True)
    return {"ok": True, "held": held}
