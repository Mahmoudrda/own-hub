"""OWNER'S TOOL ONLY: seed what App Review needs to see a payment.

Creates a demo coach, "Own Hub Review Coach" (approved, agreement verified,
published, a package with two live one-to-one video sessions a month and a
clearly fake InstaPay address that cannot receive money), and one coaching
request from the review account that is accepted and waits for payment, so the
reviewer can open the payment instructions and upload a receipt.

    cd functions
    gcloud auth application-default login      # as the owner
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.seed_review_coaching \\
        --client-uid <review account uid> --project own-hub --i-am-the-owner

Without both flags it refuses and writes nothing. It prints every document it
will write, then writes them. Safe to run again: the same ids are overwritten,
so run it after the review account is deleted and signs up again (pass the new
uid). Payments must be on (`tools.set_payments_switch on`) for the Pay button
to appear. The demo coach is published but not accepting clients, so members can see her
profile and cannot ask to join. The request waits 30 days for payment.
"""

from __future__ import annotations

import argparse
import datetime as dt
import sys

from coaching import common, subscriptions
from payments.address import DEFAULTS as PROFILE_DEFAULTS

COACH_UID = "review-coach-demo"
PACKAGE_ID = "review-package"
SUB_ID = "review-coaching-demo"
ADDRESS = "ownhub-review-demo@instapay"  # not a registered handle: a transfer to it fails
HOLDER = "Own Hub Review Demo"
COACH_PRICE_EGP = 1000
LIVE_SESSIONS = 2
DURATION_DAYS = 28
PAY_BY_DAYS = 30


def plan(client_uid: str, now: dt.datetime) -> list:
    """[(path, document)] to write, in order."""
    final = common.final_price(COACH_PRICE_EGP)
    package = {
        "title": "Review demo: four weeks with live video sessions",
        "description": "A demo package for App Review: a plan, chat and live one-to-one video sessions.",
        "durationDays": DURATION_DAYS,
        "includes": ["Two live one-to-one video sessions a month", "A plan made for you", "Chat with your coach"],
        "liveSessionsPerMonth": LIVE_SESSIONS,
        "sessionMinutes": 45,
        "checkInsPerWeek": 2,
    }
    rel_id = common.rel_id(COACH_UID, client_uid)
    sub = {
        "coachUid": COACH_UID,
        "clientUid": client_uid,
        "relId": rel_id,
        "packageId": PACKAGE_ID,
        "package": package,
        "priceFinalEgp": final,
        "clientName": "",
        "source": "app",
        "intake": {},
        "sessionsIncluded": common.sessions_included(LIVE_SESSIONS, DURATION_DAYS),
        "sessionsUsed": 0,
        "createdAt": now,
        **subscriptions.instapay_acceptance(now),
    }
    sub["payBy"] = now + dt.timedelta(days=PAY_BY_DAYS)  # the hourly sweep would expire the usual 7 days before review starts
    return [
        (f"coaches/{COACH_UID}", {
            "displayName": "Own Hub Review Coach",
            "headline": "Demo coach for App Review",
            "governorate": "Cairo",
            "languages": ["en", "ar"],
            "specialties": ["strength"],
            "approach": "A demo account used only to show the payment steps.",
            "yearsExperience": 5,
            "certificates": [],
            "testimonials": [],
            "badges": ["verifiedCoach"],
            "stats": {"clientsCoached": 0, "plansShared": 0, "sessionsDone": 0},
            "fromPriceEgp": final,
            "fromMonthlyEgp": common.monthly_equivalent(final, DURATION_DAYS),
            "acceptingClients": False,  # real members cannot ask her; the review coaching is seeded directly
            "autoAccept": False,
            "maxActiveClients": 15,
            "activeClients": 0,
            "published": True,
            "instapayReady": True,
            "trainsWhere": ["home"],
            "updatedAt": now,
        }),
        (f"coaches/{COACH_UID}/packages/{PACKAGE_ID}",
         {**package, "priceFinalEgp": final, "active": True, "order": 0}),
        (f"coachPrivate/{COACH_UID}/prices/{PACKAGE_ID}", {"coachPriceEgp": COACH_PRICE_EGP, "priceFinalEgp": final}),
        (f"coachPrivate/{COACH_UID}", {
            "agreement": {"version": 2, "status": "verified"},
            "owedEgp": 0,
            "paidEgp": 0,
        }),
        (f"coachPaymentProfiles/{COACH_UID}", {
            **PROFILE_DEFAULTS, "address": ADDRESS, "accountName": HOLDER, "verifiedAt": now,
            "changedAt": now, "pending": None,
        }),
        (f"relationships/{rel_id}", {
            "coachUid": COACH_UID, "clientUid": client_uid, "status": "none", "chatOpen": False, "createdAt": now,
        }),
        (f"subscriptions/{SUB_ID}", sub),
        (f"subscriptions/{SUB_ID}/private/terms", {
            "coachPriceEgp": COACH_PRICE_EGP, "packageId": PACKAGE_ID, "createdAt": now,
        }),
    ]


def main(argv=None, *, db=None, now=None, out=print) -> int:
    parser = argparse.ArgumentParser(prog="seed_review_coaching")
    parser.add_argument("--client-uid", required=True)
    parser.add_argument("--project")
    parser.add_argument("--i-am-the-owner", action="store_true")
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)
    if args.project != "own-hub" or not args.i_am_the_owner:
        out("Refusing: pass --project own-hub and --i-am-the-owner to write to production. Nothing was written.")
        return 2
    if not args.client_uid.strip() or "/" in args.client_uid or args.client_uid == COACH_UID:
        out("Refusing: --client-uid must be the review account's uid.")
        return 2
    rows = plan(args.client_uid.strip(), now or dt.datetime.now(dt.timezone.utc))
    out(f"Project own-hub. Review account uid: {args.client_uid}. Will write {len(rows)} documents:")
    for path, doc in rows:
        out(f"  {path}  ({', '.join(sorted(doc))})")
    out(f"Demo InstaPay address: {ADDRESS} (cannot receive money). Package price for the member: EGP {rows[1][1]['priceFinalEgp']}.")
    if db is None:
        from google.cloud import firestore

        db = firestore.Client(project="own-hub")
    for path, doc in rows:
        db.document(path).set(doc)
    out("Done. Turn payments on with tools.set_payments_switch on if it is not on yet.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
