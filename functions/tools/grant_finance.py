"""OWNER'S TOOL ONLY: give an account the `finance` claim, or take it away.

The finance claim opens the payments side of private coaching: the payment
proof queue, refunds, coach payouts and payout account confirmation (the
`finance or admin` callables). It is set here and nowhere else: there is no
callable that grants it and no screen in the app that can.

Runs on Application Default Credentials of an owner account with Firebase Auth
admin rights on own-hub, and refuses to run without them:

    cd functions
    gcloud auth application-default login      # as the owner
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.grant_finance --uid <uid>
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.grant_finance --uid <uid> --check
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.grant_finance --uid <uid> --revoke

Safe to run twice: an account that already holds the claim is left exactly as
it is and nothing is written. Merge, never replace: set_custom_user_claims
replaces the whole claims map, so `verified`, `coachV`, `admin` and
`womanReviewer` are read and kept. The account must sign out and in again, or wait up to an hour, for her token
to carry the change.

Against the Auth emulator, set FIREBASE_AUTH_EMULATOR_HOST to its host:port.
"""

from __future__ import annotations

import sys

from tools.grant_admin import run

PHONE_NOTE = (
    "note: this account has no phone number. The staff callables "
    "check the sign-in method; make sure this is the account she uses."
)


def main(argv=None, *, auth=None, require_adc=None, out=print) -> int:
    return run("finance", argv, auth=auth, require_adc=require_adc, out=out, phone_note=PHONE_NOTE)


if __name__ == "__main__":
    sys.exit(main())
