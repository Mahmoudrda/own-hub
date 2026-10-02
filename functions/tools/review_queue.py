"""The woman reviewer's queue, from a terminal, signed in as HERSELF.

This tool holds no admin credentials. It does not use Application Default
Credentials, firebase_admin or Firestore. It calls the same HTTPS callables the
server exposes (list_verification_flags, get_review_contact,
schedule_verification_review, decide_verification_flag) with the reviewer's
own Firebase ID token, so the server checks her `womanReviewer` claim, writes
the access log under her uid, and she can see nothing a callable does not
return to her.

    cd functions
    OWNHUB_REVIEWER_ID_TOKEN=<her Firebase ID token> \\
    OWNHUB_APP_CHECK_TOKEN=<an App Check token> \\
        venv/bin/python -m tools.review_queue <command>

If OWNHUB_REVIEWER_ID_TOKEN is not set, the token is asked for (hidden input).
ID tokens last one hour; get a fresh one when a call says unauthenticated.

The callables enforce App Check. OWNHUB_APP_CHECK_TOKEN is sent as the
X-Firebase-AppCheck header. From a terminal that means an App Check DEBUG
token registered in the Firebase console (App Check, Manage debug tokens) and
exchanged for an App Check token. Without it every call is refused with
app_check_missing.

OWNHUB_FUNCTIONS_BASE overrides where the callables live. Default:
https://europe-west3-own-hub.cloudfunctions.net . Against the QA emulator:
http://127.0.0.1:5101/own-hub/europe-west3 .

Commands:
    list                                       open flags, oldest first;
                                               consent=yes once she asked
                                               for the call
    contact  --flag F                          her phone number (logged);
                                               refused until consent=yes
    schedule --flag F --route video --at 2026-10-05T10:00:00+02:00
    decide   --flag F --reject
    decide   --flag F --approve                asks for the NID read on the call
                                               (hidden input) when the flag has
                                               no hash of its own

Granting the womanReviewer claim is NOT here: it needs admin credentials. It is
the owner's tool, tools/grant_reviewer.py.
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import sys
import urllib.error
import urllib.request

DEFAULT_BASE = "https://europe-west3-own-hub.cloudfunctions.net"
DUPLICATE_ID = "duplicate_id"
REVIEW_CONSENT_MISSING = "review_consent_missing"


class CallError(Exception):
    def __init__(self, status: str, reason: str):
        super().__init__(reason)
        self.status = status
        self.reason = reason


def http_post(url: str, headers: dict, payload: dict) -> dict:
    """POST one callable request and return the decoded JSON body."""
    request = urllib.request.Request(
        url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST"
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as error:
        try:
            return json.loads(error.read().decode("utf-8") or "{}")
        except ValueError:
            return {"error": {"status": str(error.code), "message": "internal_error"}}


class Client:
    """The callable protocol: POST {"data": ...}, answer {"result"} or {"error"}."""

    def __init__(self, id_token: str, app_check: str | None, base: str, post=http_post):
        self.id_token = id_token
        self.app_check = app_check
        self.base = base.rstrip("/")
        self.post = post

    def call(self, name: str, data: dict) -> dict:
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.id_token}",
        }
        if self.app_check:
            headers["X-Firebase-AppCheck"] = self.app_check
        answer = self.post(f"{self.base}/{name}", headers, {"data": data})
        if "error" in answer:
            error = answer["error"] or {}
            raise CallError(str(error.get("status", "")), str(error.get("message", "")))
        return answer.get("result") or {}


def _client_from_env(read_token) -> Client:
    token = os.environ.get("OWNHUB_REVIEWER_ID_TOKEN") or read_token()
    return Client(
        token.strip(),
        os.environ.get("OWNHUB_APP_CHECK_TOKEN") or None,
        os.environ.get("OWNHUB_FUNCTIONS_BASE") or DEFAULT_BASE,
    )


def main(argv=None, *, client=None, read_nid=None, read_token=None, out=print) -> int:
    parser = argparse.ArgumentParser(prog="review_queue")
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
    args = parser.parse_args(argv)

    client = client or _client_from_env(
        read_token or (lambda: getpass.getpass("Your Firebase ID token (hidden): "))
    )

    try:
        if args.command == "list":
            for row in client.call("list_verification_flags", {}).get("flags", []):
                note = ""
                if DUPLICATE_ID in row.get("flags", []):
                    note = "  card registered to another account: escalate to the owner"
                out(
                    f"{row['flagId']}  {','.join(row.get('flags', []))}  route={row.get('route')}"
                    f"  at={row.get('scheduledFor') or '-'}  sla={row.get('slaExpiresAt')}"
                    f"  nidOnCall={'yes' if row.get('needsNidOnCall') else 'no'}"
                    f"  consent={'yes' if row.get('consentGiven') else 'no'}{note}"
                )
        elif args.command == "contact":
            # R4: never ask for her phone before she asked for the call. The
            # server refuses too; this keeps the request from being made.
            rows = client.call("list_verification_flags", {}).get("flags", [])
            row = next((r for r in rows if r.get("flagId") == args.flag), None)
            if row is not None and row.get("consentGiven") is not True:
                raise CallError("FAILED_PRECONDITION", REVIEW_CONSENT_MISSING)
            out(client.call("get_review_contact", {"flagId": args.flag})["phone"])
        elif args.command == "schedule":
            client.call(
                "schedule_verification_review",
                {"flagId": args.flag, "route": args.route, "scheduledFor": args.at},
            )
            out(f"booked {args.route} for {args.at}")
        elif args.command == "decide":
            data = {"flagId": args.flag, "approve": bool(args.approve)}
            if args.approve:
                rows = client.call("list_verification_flags", {}).get("flags", [])
                row = next((r for r in rows if r.get("flagId") == args.flag), {})
                if row.get("needsNidOnCall", True):
                    read_nid = read_nid or (
                        lambda: getpass.getpass("NID read on the call (hidden): ")
                    )
                    data["nid"] = read_nid()
            result = client.call("decide_verification_flag", data)
            data = None
            out(f"decided: {result.get('outcome')}")
    except CallError as error:
        if error.reason == REVIEW_CONSENT_MISSING:
            out(f"refused: {REVIEW_CONSENT_MISSING} (she has not asked for the call yet)")
        elif error.reason == DUPLICATE_ID:
            out("refused: duplicate_id (card registered to another account: escalate to the owner)")
        else:
            out(f"refused: {error.reason or error.status}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
