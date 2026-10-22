"""Local end-to-end seed: four phone accounts on the Auth emulator.

    cd functions
    .venv/bin/python -m tools.e2e_seed            # create or refresh, print them
    .venv/bin/python -m tools.e2e_seed codes      # latest SMS code per phone

Needs the emulators of firebase.e2e.json running (tool/e2e_coaching.sh). The
Auth emulator invents the SMS code itself, so there is no fixed code; the
`codes` command (and the emulator log) shows it. Stdlib only, and it refuses
anything but a local host.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

PROJECT = "own-hub"
AUTH = os.environ.get("E2E_AUTH_HOST", "127.0.0.1:9299")
IDT = f"http://{AUTH}/identitytoolkit.googleapis.com/v1"

ACCOUNTS = {
    "reviewer": {"phone": "+201000000001", "claims": {"verified": True, "womanReviewer": True}},
    "admin": {"phone": "+201000000002", "claims": {"verified": True, "admin": True}},
    "coach": {"phone": "+201000000003", "claims": {"verified": True}},
    "client": {"phone": "+201000000004", "claims": {"verified": True}},
    "stranger": {"phone": "+201000000005", "claims": {"verified": True}},
}


def _local() -> None:
    host = AUTH.split(":")[0]
    if host not in ("127.0.0.1", "localhost", "[::1]", "10.0.2.2"):
        sys.exit(f"refusing a non-local auth host: {AUTH}")


def post(url: str, body: dict, bearer: str | None = None) -> dict:
    headers = {"Content-Type": "application/json"}
    if bearer:
        headers["Authorization"] = f"Bearer {bearer}"
    url += ("&" if "?" in url else "?") + "key=e2e"
    req = urllib.request.Request(url, json.dumps(body).encode(), headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            return json.loads(res.read() or b"{}")
    except urllib.error.HTTPError as err:
        raise RuntimeError(f"{url}: {err.code} {err.read()[:300]!r}") from None


def sms_codes() -> dict:
    url = f"http://{AUTH}/emulator/v1/projects/{PROJECT}/verificationCodes"
    with urllib.request.urlopen(url, timeout=10) as res:
        rows = json.loads(res.read()).get("verificationCodes", [])
    return {r["phoneNumber"]: r["code"] for r in rows}  # later rows win


def sign_in(phone: str) -> dict:
    """{idToken, localId} for a phone, through the emulator's own SMS flow."""
    started = post(f"{IDT}/accounts:sendVerificationCode", {"phoneNumber": phone, "recaptchaToken": "e2e"})
    code = sms_codes()[phone]
    return post(f"{IDT}/accounts:signInWithPhoneNumber", {"sessionInfo": started["sessionInfo"], "code": code})


def seed() -> dict:
    _local()
    out = {}
    for name, spec in ACCOUNTS.items():
        first = sign_in(spec["phone"])
        post(
            f"{IDT}/accounts:update",
            {"localId": first["localId"], "customAttributes": json.dumps(spec["claims"]),
             "displayName": name.capitalize()},
            bearer="owner",
        )
        out[name] = {"uid": first["localId"], "phone": spec["phone"], "claims": spec["claims"]}
    return out


def tokens() -> dict:
    """Fresh ID tokens (carrying the claims) for every seeded account."""
    return {name: sign_in(spec["phone"]) for name, spec in ACCOUNTS.items()}


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "codes":
        print(json.dumps(sms_codes(), indent=2))
    else:
        for name, row in seed().items():
            print(f"{name:9} uid={row['uid']} phone={row['phone']} claims={row['claims']}")
        print("SMS codes are issued by the emulator at sign-in: run `python -m tools.e2e_seed codes`.")
