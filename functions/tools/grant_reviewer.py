"""OWNER'S TOOL ONLY: add the womanReviewer claim to an account.

This one needs admin credentials, which is why it is NOT part of the
reviewer's tool (tools/review_queue.py holds none). It runs on Application
Default Credentials of an owner/admin Google account with Firebase Auth admin
rights on own-hub, and refuses to run without them:

    cd functions
    gcloud auth application-default login      # as the owner
    GOOGLE_CLOUD_PROJECT=own-hub venv/bin/python -m tools.grant_reviewer --uid <uid>

Merge, never replace: set_custom_user_claims replaces the whole claims map, so
the existing claims (verified, coachV, admin) are read and kept. The reviewer
must sign out and in again (or refresh her ID token) to carry the new claim.

Against the Auth emulator, set FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9299.
"""

from __future__ import annotations

import argparse
import sys


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


def grant_reviewer(uid: str) -> None:
    """Merge, never replace: set_custom_user_claims replaces the whole map."""
    import firebase_admin
    from firebase_admin import auth

    if not firebase_admin._apps:
        firebase_admin.initialize_app()
    user = auth.get_user(uid)
    claims = dict(user.custom_claims or {})
    claims["womanReviewer"] = True
    auth.set_custom_user_claims(uid, claims)


def main(argv=None, *, grant=None, require_adc=None, out=print) -> int:
    parser = argparse.ArgumentParser(prog="grant_reviewer")
    parser.add_argument("--uid", required=True)
    args = parser.parse_args(argv)
    (require_adc or _require_adc)()
    (grant or grant_reviewer)(args.uid)
    out(f"womanReviewer granted to {args.uid}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
