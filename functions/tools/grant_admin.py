"""OWNER'S TOOL ONLY: give an account the `admin` claim, or take it away.

The admin claim opens the content library to writes (firestore.rules
isAdmin()), the events collection, and the admin_dashboard and admin_logs
callables. It is set here and nowhere else: there is no callable that grants
it and no screen in the app that can.

Runs on Application Default Credentials of an owner account with Firebase Auth
admin rights on own-hub, and refuses to run without them:

    cd functions
    gcloud auth application-default login      # as the owner
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.grant_admin --uid <uid>
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.grant_admin --uid <uid> --check
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.grant_admin --uid <uid> --revoke

app/tool/admin_access.sh wraps these three.

Safe to run twice: an account that already holds the claim is left exactly as
it is and nothing is written. Merge, never replace: set_custom_user_claims
replaces the whole claims map, so `verified`, `coachV` and `womanReviewer` are
read and kept. The account must sign in with her phone number (the console
callables refuse any other sign-in), and must sign out and in again, or wait up
to an hour, for her token to carry the change.

Against the Auth emulator, set FIREBASE_AUTH_EMULATOR_HOST to its host:port.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from typing import Callable, Optional


@dataclass(frozen=True)
class Outcome:
    changed: bool
    has: bool
    phone_sign_in: bool


def _require_adc() -> None:
    import os

    if os.environ.get("FIREBASE_AUTH_EMULATOR_HOST"):
        return
    import google.auth

    try:
        google.auth.default()
    except Exception:
        raise SystemExit(
            "refused: no Application Default Credentials. This is the owner's "
            "tool; run `gcloud auth application-default login` as the owner."
        )


def _auth():
    import firebase_admin
    from firebase_admin import auth

    if not firebase_admin._apps:
        firebase_admin.initialize_app()
    return auth


def apply(
    uid: str,
    want: Optional[bool],
    *,
    get_user: Callable,
    set_claims: Callable,
    claim: str = "admin",
) -> Outcome:
    """Read her claims, change `claim` only if it differs from `want`.

    `want` None only reads. Returns whether anything was written."""
    user = get_user(uid)
    claims = dict(user.custom_claims or {})
    has = claims.get(claim) is True
    phone = bool(getattr(user, "phone_number", None))
    if want is None or want == has:
        return Outcome(changed=False, has=has, phone_sign_in=phone)
    if want:
        claims[claim] = True
    else:
        claims.pop(claim, None)
    set_claims(uid, claims)
    return Outcome(changed=True, has=want, phone_sign_in=phone)


PHONE_NOTE = (
    "note: this account has no phone number. The console callables "
    "accept a phone sign-in only."
)


def run(
    claim: str,
    argv=None,
    *,
    auth=None,
    require_adc=None,
    out=print,
    phone_note: str = PHONE_NOTE,
) -> int:
    """The command line for one claim. grant_finance.py runs it for `finance`."""
    parser = argparse.ArgumentParser(prog=f"grant_{claim}")
    parser.add_argument("--uid", required=True)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--revoke", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    uid = args.uid.strip()
    if not uid or len(uid) > 128:
        out("refused: that is not a uid")
        return 2

    (require_adc or _require_adc)()
    a = auth or _auth()
    want = None if args.check else (not args.revoke)
    try:
        result = apply(
            uid, want, get_user=a.get_user, set_claims=a.set_custom_user_claims, claim=claim
        )
    except a.UserNotFoundError:
        out(f"no account with uid {uid}")
        return 1

    if args.check:
        out(f"{uid}: {claim} {'yes' if result.has else 'no'}")
    elif result.changed:
        out(f"{uid}: {claim} {'granted' if result.has else 'removed'}")
    else:
        out(f"{uid}: already {claim if result.has else 'not ' + claim}, nothing written")
    if result.has and not result.phone_sign_in:
        out(phone_note)
    return 0


def main(argv=None, *, auth=None, require_adc=None, out=print) -> int:
    return run("admin", argv, auth=auth, require_adc=require_adc, out=out)


if __name__ == "__main__":
    sys.exit(main())
