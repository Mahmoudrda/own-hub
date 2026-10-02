"""The woman reviewer's queue, from a terminal, signed in as HERSELF.

This tool holds no admin credentials. It does not use Application Default
Credentials, firebase_admin or Firestore. It calls the same HTTPS callables the
server exposes (list_verification_flags, get_review_contact,
schedule_verification_review, decide_verification_flag) with the reviewer's
own Firebase ID token, so the server checks her `womanReviewer` claim, writes
the access log under her uid, and she can see nothing a callable does not
return to her.

===============================================================================
SETTING UP A REVIEWER (owner, once per reviewer)
===============================================================================

1. Email/Password sign-in must be enabled once for the project: Firebase
   console, Authentication, Sign-in method, Email/Password, Enable. (Owner
   step. While it is on, also turn off public sign-up for it if the console
   offers it, Authentication, Settings, User actions, so nobody can create an
   email account with the public API key; reviewer accounts are created by the
   owner only.)
2. Create her account: Authentication, Users, Add user, with her email and a
   strong password she chooses. Note her UID.
3. Give her the claim: `venv/bin/python -m tools.grant_reviewer --uid <UID>`
   (owner's tool, needs the owner's credentials).
4. App Check: one debug token per reviewer, registered on the Android app
   (APP_ID below): Firebase console, App Check, Apps, the Android app, the
   three-dot menu, Manage debug tokens, Add debug token. Name it after her
   ("reviewer: <first name>"), let the console generate the value, and hand it
   to her privately (a password manager share, not chat or email). It is a
   secret: anyone holding it passes App Check as an app.
5. When she leaves: delete her debug token in Manage debug tokens (this
   revokes it at once), remove the claim or disable her account under
   Authentication, Users. Never share one debug token between reviewers, so
   one can be revoked without stopping the others.

===============================================================================
USING IT (reviewer)
===============================================================================

    cd functions
    OWNHUB_REVIEWER_EMAIL=<her email> venv/bin/python -m tools.review_queue <command>

The tool asks for her password and her App Check debug token with hidden
input, signs her in through the Firebase Auth REST API (signInWithPassword,
with the app's public Web API key, which is not a secret), exchanges the debug
token for an App Check token, and refreshes both itself before they expire. The
password, the debug token and every token are held in memory for the run only:
never written to disk, never printed, never logged.

OWNHUB_APP_CHECK_DEBUG_TOKEN may hold the debug token instead of the prompt
(from a password manager, never typed inline where shell history keeps it).
OWNHUB_REVIEWER_ID_TOKEN and OWNHUB_APP_CHECK_TOKEN still take ready-made
tokens, for the emulator. Without App Check every call is refused with
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
import time
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_BASE = "https://europe-west3-own-hub.cloudfunctions.net"
# The Android app's public Firebase options (app/lib/firebase_options.dart).
# A Firebase Web API key identifies the project; it is not a secret.
API_KEY = "AIzaSyBvJ_HEr1xBCkID9sOh0UJpNUbQT4TEYR0"
APP_ID = "1:681714989950:android:3ba803734abd9ca3fbd12f"
SIGN_IN_URL = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
REFRESH_URL = "https://securetoken.googleapis.com/v1/token"
APP_CHECK_URL = "https://firebaseappcheck.googleapis.com/v1/projects/{project}/apps/{app}:exchangeDebugToken"
# Refresh this long before a token's stated expiry.
REFRESH_MARGIN_SEC = 300
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


class SignInError(Exception):
    """A Google REST refusal. The message is the API's error code only
    (INVALID_LOGIN_CREDENTIALS, ...), never anything she typed."""


def rest_post(url: str, body: bytes, content_type: str) -> tuple[int, dict]:
    """POST to a Google REST endpoint; (status, decoded JSON). Nothing logged."""
    request = urllib.request.Request(
        url, data=body, headers={"Content-Type": content_type}, method="POST"
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.status, json.loads(response.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as error:
        try:
            return error.code, json.loads(error.read().decode("utf-8") or "{}")
        except ValueError:
            return error.code, {}


def _rest_error(answer: dict) -> SignInError:
    error = answer.get("error") if isinstance(answer, dict) else None
    message = error.get("message") if isinstance(error, dict) else None
    code = str(message or "sign_in_failed").split(" ", 1)[0]
    return SignInError(code)


class PasswordSession:
    """Her Firebase ID token, from email and password, refreshed in memory.

    The password is used once for signInWithPassword and not kept. The ID
    token and the refresh token live on this object for the run only."""

    def __init__(self, email: str, password: str, api_key: str, *, rest=rest_post, clock=time.time):
        self._api_key = api_key
        self._rest = rest
        self._clock = clock
        status, answer = rest(
            f"{SIGN_IN_URL}?key={api_key}",
            json.dumps(
                {"email": email, "password": password, "returnSecureToken": True}
            ).encode("utf-8"),
            "application/json",
        )
        del password
        if status != 200 or "idToken" not in answer:
            raise _rest_error(answer)
        self._store(answer["idToken"], answer["refreshToken"], answer.get("expiresIn"))

    def _store(self, id_token, refresh_token, expires_in) -> None:
        self._id_token = id_token
        self._refresh_token = refresh_token
        self._expires_at = self._clock() + int(expires_in or 3600)

    def refresh(self) -> None:
        status, answer = self._rest(
            f"{REFRESH_URL}?key={self._api_key}",
            urllib.parse.urlencode(
                {"grant_type": "refresh_token", "refresh_token": self._refresh_token}
            ).encode("utf-8"),
            "application/x-www-form-urlencoded",
        )
        if status != 200 or "id_token" not in answer:
            raise _rest_error(answer)
        self._store(answer["id_token"], answer["refresh_token"], answer.get("expires_in"))

    def token(self) -> str:
        if self._clock() >= self._expires_at - REFRESH_MARGIN_SEC:
            self.refresh()
        return self._id_token


class DebugAppCheck:
    """An App Check token from her registered debug token, renewed in memory."""

    def __init__(self, debug_token: str, app_id: str, api_key: str, *, rest=rest_post, clock=time.time):
        self._debug_token = debug_token
        self._url = APP_CHECK_URL.format(
            project=app_id.split(":")[1], app=app_id
        ) + f"?key={api_key}"
        self._rest = rest
        self._clock = clock
        self._token = None
        self._expires_at = 0.0

    def refresh(self) -> None:
        status, answer = self._rest(
            self._url,
            json.dumps({"debugToken": self._debug_token}).encode("utf-8"),
            "application/json",
        )
        if status != 200 or "token" not in answer:
            raise _rest_error(answer)
        ttl = str(answer.get("ttl") or "3600s").rstrip("s")
        self._token = answer["token"]
        self._expires_at = self._clock() + float(ttl)

    def token(self) -> str:
        if self._token is None or self._clock() >= self._expires_at - REFRESH_MARGIN_SEC:
            self.refresh()
        return self._token


def _value(source):
    """A ready-made token string, or a session that hands one out."""
    return source.token() if hasattr(source, "token") else source


class Client:
    """The callable protocol: POST {"data": ...}, answer {"result"} or {"error"}.

    `id_token` and `app_check` are each a token string or a session object
    (PasswordSession, DebugAppCheck) that refreshes itself. An UNAUTHENTICATED
    answer refreshes the ID token once and retries."""

    def __init__(self, id_token, app_check, base: str, post=http_post):
        self.id_token = id_token
        self.app_check = app_check
        self.base = base.rstrip("/")
        self.post = post

    def _send(self, name: str, data: dict) -> dict:
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {_value(self.id_token)}",
        }
        app_check = _value(self.app_check) if self.app_check else None
        if app_check:
            headers["X-Firebase-AppCheck"] = app_check
        return self.post(f"{self.base}/{name}", headers, {"data": data})

    def call(self, name: str, data: dict) -> dict:
        answer = self._send(name, data)
        if (
            "error" in answer
            and str((answer["error"] or {}).get("status", "")) == "UNAUTHENTICATED"
            and hasattr(self.id_token, "refresh")
        ):
            self.id_token.refresh()
            answer = self._send(name, data)
        if "error" in answer:
            error = answer["error"] or {}
            raise CallError(str(error.get("status", "")), str(error.get("message", "")))
        return answer.get("result") or {}


def _client_from_env(prompt=getpass.getpass, *, rest=rest_post, clock=time.time) -> Client:
    """Ready-made tokens from the environment (emulator), else sign her in."""
    id_token = os.environ.get("OWNHUB_REVIEWER_ID_TOKEN")
    if id_token:
        session = id_token.strip()
    else:
        email = os.environ.get("OWNHUB_REVIEWER_EMAIL") or input("Your reviewer email: ")
        session = PasswordSession(
            email.strip(), prompt("Your password (hidden): "), API_KEY, rest=rest, clock=clock
        )
    app_check = os.environ.get("OWNHUB_APP_CHECK_TOKEN")
    if app_check:
        app_check_source = app_check.strip()
    else:
        debug = os.environ.get("OWNHUB_APP_CHECK_DEBUG_TOKEN") or prompt(
            "Your App Check debug token (hidden): "
        )
        app_check_source = DebugAppCheck(debug.strip(), APP_ID, API_KEY, rest=rest, clock=clock)
    return Client(
        session,
        app_check_source,
        os.environ.get("OWNHUB_FUNCTIONS_BASE") or DEFAULT_BASE,
    )


def main(argv=None, *, client=None, read_nid=None, prompt=None, out=print) -> int:
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

    try:
        client = client or _client_from_env(prompt or getpass.getpass)
    except SignInError as error:
        out(f"sign-in refused: {error}")
        return 1

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
    except SignInError as error:
        out(f"sign-in refused: {error}")
        return 1
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
