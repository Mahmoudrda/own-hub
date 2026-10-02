"""The woman reviewer's queue, from a terminal.

Run from functions/ with Application Default Credentials:

    GOOGLE_CLOUD_PROJECT=own-hub venv/bin/python -m tools.review_queue \\
        --reviewer-uid <uid> <command>

Commands:
    list                                       open flags, oldest first
    contact  --flag F                          her phone number (logged)
    schedule --flag F --route video --at 2026-10-05T10:00:00+02:00
    decide   --flag F --reject
    decide   --flag F --approve                asks for the NID read on the call
                                               (hidden input) when the flag has
                                               no hash of its own
    grant-reviewer --uid U                     add the womanReviewer claim

Every command goes through identity/review.py, the same functions the callables
use, so the access log, the checks and the state writes are identical.

HONEST LIMIT: anyone holding admin ADC credentials can pass any uid as
--reviewer-uid. The claim check at start-up guards against mistakes (running it
as the wrong person, or for someone whose claim was removed), not against an
administrator. There is no image path here because no image exists.

Against the emulators, set FIRESTORE_EMULATOR_HOST=127.0.0.1:8288 and
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9299 as well.
"""

from __future__ import annotations

import argparse
import getpass
import sys

from identity import reasons, review


def _store():
    import firebase_admin

    if not firebase_admin._apps:
        firebase_admin.initialize_app()
    from identity import store

    return store.FirestoreReviewStore()


def _is_reviewer(uid: str) -> bool:
    from firebase_admin import auth

    return bool((auth.get_user(uid).custom_claims or {}).get("womanReviewer"))


def grant_reviewer(uid: str) -> None:
    """Merge, never replace: set_custom_user_claims replaces the whole map."""
    from firebase_admin import auth

    user = auth.get_user(uid)
    claims = dict(user.custom_claims or {})
    claims["womanReviewer"] = True
    auth.set_custom_user_claims(uid, claims)


def main(argv=None, *, store=None, is_reviewer=None, read_nid=None, out=print) -> int:
    parser = argparse.ArgumentParser(prog="review_queue")
    parser.add_argument("--reviewer-uid", required=False)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("list")
    contact = sub.add_parser("contact")
    contact.add_argument("--flag", required=True)
    schedule = sub.add_parser("schedule")
    schedule.add_argument("--flag", required=True)
    schedule.add_argument("--route", required=True, choices=["video", "gym"])
    schedule.add_argument("--at", required=True)
    decide = sub.add_parser("decide")
    decide.add_argument("--flag", required=True)
    verdict = decide.add_mutually_exclusive_group(required=True)
    verdict.add_argument("--approve", action="store_true")
    verdict.add_argument("--reject", action="store_true")
    grant = sub.add_parser("grant-reviewer")
    grant.add_argument("--uid", required=True)
    args = parser.parse_args(argv)

    if args.command == "grant-reviewer":
        grant_reviewer(args.uid)
        out(f"womanReviewer granted to {args.uid}")
        return 0

    if not args.reviewer_uid:
        out("--reviewer-uid is required")
        return 2
    is_reviewer = is_reviewer or _is_reviewer
    if not is_reviewer(args.reviewer_uid):
        out("refused: that account does not hold the womanReviewer claim")
        return 3
    store = store or _store()
    me = args.reviewer_uid

    try:
        if args.command == "list":
            for row in review.list_open(store, me):
                note = ""
                if reasons.DUPLICATE_ID in row["flags"]:
                    note = "  card registered to another account: escalate to the owner"
                out(
                    f"{row['flagId']}  {','.join(row['flags'])}  route={row['route']}"
                    f"  at={row['scheduledFor'] or '-'}  sla={row['slaExpiresAt']}"
                    f"  nidOnCall={'yes' if row['needsNidOnCall'] else 'no'}{note}"
                )
        elif args.command == "contact":
            out(review.contact(store, me, args.flag)["phone"])
        elif args.command == "schedule":
            review.schedule(store, me, args.flag, args.route, args.at)
            out(f"booked {args.route} for {args.at}")
        elif args.command == "decide":
            digits = None
            if args.approve:
                flag = store.get_flag(args.flag) or {}
                if not flag.get("id_hmac"):
                    read_nid = read_nid or (
                        lambda: getpass.getpass("NID read on the call (hidden): ")
                    )
                    digits = read_nid()
            result = review.decide(store, me, args.flag, args.approve, digits)
            digits = None
            out(f"decided: {result.outcome}")
    except review.ReviewError as error:
        if error.reason == reasons.DUPLICATE_ID:
            out("refused: duplicate_id (card registered to another account: escalate to the owner)")
        else:
            out(f"refused: {error.reason}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
