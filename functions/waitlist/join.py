"""W1: join_waitlist, the one door from the public site into Firestore.

The site promises it runs no script, so the waitlist page is a plain HTML form
that POSTs here, and this answers a form with a 303 redirect to one of three
static pages: joined, check (what she typed was not usable) or later (the cap,
or our failure). A JSON caller gets {ok} or {ok: false, error} with CORS for
the site origin and localhost only.

What is stored, in waitlist/{autoId}, and nothing else:

    contact   +201XXXXXXXXX or a lower-cased email
    kind      "phone" | "email"
    lang      "en" | "ar"
    consent   true (nothing is stored without it)
    at        when she joined
    ipHash    HMAC-SHA256 of the IP under a secret key, never the IP itself
    expireAt  at + 180 days; a Firestore TTL deletes it (pending counsel)

Controls, because there is no App Check on the web:
  * POST only, a 4 KB body cap, strict validation of every field;
  * a honeypot field a person never sees: filled means a bot, which is told
    it joined and nothing is written;
  * DAILY_LIMIT_PER_IP attempts per IP per day, valid or not, counted on
    waitlistRate/{ipHash}_{day} (expires after two days);
  * GLOBAL_DAILY_LIMIT new entries a day across everyone, a cost ceiling,
    counted on waitlistRate/all_{day};
  * a duplicate contact answers exactly like a first join, so the endpoint
    cannot be used to learn who is on the list;
  * no log line carries a contact, an IP or its hash.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import hmac
import ipaddress
import json
import re
import threading
from dataclasses import dataclass, field
from typing import Callable, Optional

SITE_ORIGIN = "https://ownhub.example"
"""Must equal baseUrl in site/config.json (a test holds them together). Update
both when the real domain exists."""

_DEV_ORIGIN = re.compile(r"^http://(localhost|127\.0\.0\.1)(:\d{1,5})?$")

COLLECTION = "waitlist"
RATE_COLLECTION = "waitlistRate"
SECRET_IP_KEY = "waitlist-ip-key"
"""Secret Manager secret holding the HMAC key for IPs. Separate from the NID
pepper on purpose: a different purpose gets a different key."""

DAILY_LIMIT_PER_IP = 50
"""C3, the owner's decision: Egyptian mobile carriers put many women behind one
public address (carrier NAT), so 5 would turn real sign-ups away."""
GLOBAL_DAILY_LIMIT = 5000
"""C3: new waitlist entries a day, across everyone. A cost ceiling. Past it
every valid submission is answered "try again later" and nothing is written:
the honest option, because the form never says "joined" for something it did
not keep and nothing is queued or slowed in secret. A contact already on the
list is answered "later" too, so the ceiling cannot be used to learn who is
on the list. Counted on waitlistRate/all_{day}, under the same two-day TTL as
the per-IP counters."""
GLOBAL_COUNTER_PREFIX = "all_"
TRUSTED_PUBLIC_HOPS = 0
"""B4: public X-Forwarded-For entries Google appends AFTER the client's own.

0 for the Cloud Run URL the form posts to today (europe-west3-own-hub.
cloudfunctions.net, a gen2 function): the front end appends only the address
it saw, so the client is the last public entry. 1 if an external Application
Load Balancer is ever put in front, which appends "<client>, <its own
address>". See client_ip."""
RETENTION_DAYS = 180
RATE_RETENTION_DAYS = 2
MAX_BODY_BYTES = 4096
HONEYPOT_FIELD = "website"
LANGS = ("en", "ar")

_TRUE = {True, "true", "yes", "on", "1"}

_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")
_EG_MOBILE = re.compile(r"^1[0125]\d{8}$")
_EMAIL = re.compile(
    r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]{1,64}"
    r"@[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$"
)


def normalise(raw) -> Optional[tuple]:
    """("phone", "+201XXXXXXXXX") or ("email", "x@y.z"), else None."""
    if not isinstance(raw, str):
        return None
    text = raw.strip()
    if not text or len(text) > 254:
        return None
    if "@" in text:
        email = text.lower()
        return ("email", email) if _EMAIL.match(email) else None
    digits = text.translate(_DIGITS)
    digits = re.sub(r"[\s\-().]", "", digits)
    if digits.startswith("+20"):
        national = digits[3:]
    elif digits.startswith("0020"):
        national = digits[4:]
    elif digits.startswith("20") and len(digits) == 12:
        national = digits[2:]
    elif digits.startswith("0"):
        national = digits[1:]
    else:
        return None
    if not _EG_MOBILE.match(national):
        return None
    return ("phone", "+20" + national)


def _public(entry: str):
    """One X-Forwarded-For entry as a public address, or None."""
    text = entry.strip()
    if text.startswith("["):  # [v6]:port
        text = text[1:].split("]", 1)[0]
    elif text.count(":") == 1:  # v4:port
        text = text.split(":", 1)[0]
    try:
        address = ipaddress.ip_address(text)
    except ValueError:
        return None
    if isinstance(address, ipaddress.IPv6Address) and address.ipv4_mapped:
        address = address.ipv4_mapped
    return address if address.is_global else None


def client_ip(forwarded: Optional[str], remote_addr: Optional[str], trusted_hops: Optional[int] = None) -> str:
    """B4: the address the per-IP cap is counted on.

    A client may send any X-Forwarded-For; Google's front end APPENDS what it
    saw, so everything to the left of that is the client's own text and is
    never trusted. Read from the right: skip entries that are not public
    addresses (an internal Google hop, a private or carrier-NAT address,
    junk), drop TRUSTED_PUBLIC_HOPS more, and the next one is the client.
    Nothing a client prepends can move it, so spoofing buys no attempts.

    IPv6 is returned as its /64: one home or phone is given a whole /64 and
    could otherwise rotate through it for a fresh allowance each time.
    Falls back to the peer address when no entry is usable.
    """
    hops = TRUSTED_PUBLIC_HOPS if trusted_hops is None else trusted_hops
    public = [a for a in (_public(e) for e in (forwarded or "").split(",")) if a is not None]
    chosen = public[-1 - hops] if len(public) > hops else _public(remote_addr or "")
    if chosen is None:
        return (remote_addr or "").strip()
    if isinstance(chosen, ipaddress.IPv6Address):
        return str(ipaddress.ip_network(f"{chosen}/64", strict=False))
    return str(chosen)


def ip_hash(key: bytes, ip: str) -> str:
    return hmac.new(key, (ip or "").encode("utf-8"), hashlib.sha256).hexdigest()


def allowed_origin(origin: Optional[str]) -> bool:
    return origin == SITE_ORIGIN or bool(origin and _DEV_ORIGIN.match(origin))


@dataclass
class Request:
    method: str
    origin: Optional[str]
    is_form: bool
    fields: dict
    ip: str
    too_large: bool = False


@dataclass
class Response:
    status: int
    headers: dict = field(default_factory=dict)
    body: str = ""


def handle(request: Request, store, key: Callable[[], bytes], now: dt.datetime) -> Response:
    origin = request.origin
    cors = {}
    if allowed_origin(origin):
        cors = {"Access-Control-Allow-Origin": origin, "Vary": "Origin"}
    elif origin not in (None, "null"):
        # A page on another site. `null` is what a browser sends on a form POST
        # from a page with Referrer-Policy: no-referrer, which is this site.
        return Response(403, {}, "")

    if request.method == "OPTIONS":
        if not cors:
            return Response(403, {}, "")
        return Response(
            204,
            {
                **cors,
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type",
                "Access-Control-Max-Age": "3600",
            },
        )
    if request.method != "POST":
        return Response(405, {"Allow": "POST, OPTIONS", **cors}, "")

    fields = request.fields if isinstance(request.fields, dict) else {}
    lang = fields.get("lang") if fields.get("lang") in LANGS else "en"

    def answer(outcome: str) -> Response:
        if request.is_form:
            base = origin if cors else SITE_ORIGIN
            prefix = "/ar" if lang == "ar" else ""
            page = {"joined": "joined", "invalid": "check", "later": "later"}[outcome]
            return Response(303, {"Location": f"{base}{prefix}/waitlist/{page}", **cors})
        status = {"joined": 200, "invalid": 400, "later": 429}[outcome]
        payload = {"ok": True} if outcome == "joined" else {"ok": False, "error": outcome}
        return Response(
            status, {"Content-Type": "application/json", **cors}, json.dumps(payload)
        )

    if request.too_large:
        return answer("invalid")
    if fields.get(HONEYPOT_FIELD):
        return answer("joined")

    try:
        hashed = ip_hash(key(), request.ip)
        if store.count_attempt(hashed, now.date().isoformat(), now) > DAILY_LIMIT_PER_IP:
            return answer("later")

        parsed = normalise(fields.get("contact"))
        if parsed is None or fields.get("consent") not in _TRUE:
            return answer("invalid")
        kind, contact = parsed

        # C3: before the duplicate check, so past the ceiling a known contact
        # and a new one get the same answer.
        if store.new_entries_today(now.date().isoformat()) >= GLOBAL_DAILY_LIMIT:
            return answer("later")

        if not store.has_contact(contact):
            store.add(
                {
                    "contact": contact,
                    "kind": kind,
                    "lang": lang,
                    "consent": True,
                    "at": now,
                    "ipHash": hashed,
                    "expireAt": now + dt.timedelta(days=RETENTION_DAYS),
                }
            )
        return answer("joined")
    except Exception:
        from identity import logs

        logs.error("waitlist_failed")
        response = answer("later")
        if not request.is_form:
            response.status = 503
        return response


class FirestoreWaitlist:
    def __init__(self, db):
        self.db = db

    def count_attempt(self, ip_hash_: str, day: str, now: dt.datetime) -> int:
        from google.cloud import firestore

        reference = self.db.collection(RATE_COLLECTION).document(f"{ip_hash_}_{day}")
        reference.set(
            {
                "count": firestore.Increment(1),
                "expireAt": now + dt.timedelta(days=RATE_RETENTION_DAYS),
            },
            merge=True,
        )
        return int((reference.get().to_dict() or {}).get("count", 0))

    def has_contact(self, contact: str) -> bool:
        query = self.db.collection(COLLECTION).where("contact", "==", contact).limit(1)
        return any(True for _ in query.stream())

    def _day_counter(self, day: str):
        return self.db.collection(RATE_COLLECTION).document(f"{GLOBAL_COUNTER_PREFIX}{day}")

    def new_entries_today(self, day: str) -> int:
        snapshot = self._day_counter(day).get()
        return int((snapshot.to_dict() or {}).get("count", 0)) if snapshot.exists else 0

    def add(self, entry: dict) -> None:
        from google.cloud import firestore

        self.db.collection(COLLECTION).document().set(entry)
        at = entry.get("at") or dt.datetime.now(dt.timezone.utc)
        self._day_counter(at.date().isoformat()).set(
            {
                "count": firestore.Increment(1),
                "expireAt": at + dt.timedelta(days=RATE_RETENTION_DAYS),
            },
            merge=True,
        )


_key_cache: Optional[bytes] = None
_key_lock = threading.Lock()


def ip_key() -> bytes:
    """The IP HMAC key from Secret Manager, once per instance. Never logged."""
    global _key_cache
    if _key_cache is None:
        with _key_lock:
            if _key_cache is None:
                from google.cloud import secretmanager

                client = secretmanager.SecretManagerServiceClient()
                name = f"projects/own-hub/secrets/{SECRET_IP_KEY}/versions/latest"
                response = client.access_secret_version(request={"name": name})
                _key_cache = response.payload.data
    return _key_cache


def from_flask(request) -> Request:
    """The parts of a Flask request handle() needs, read defensively."""
    too_large = (request.content_length or 0) > MAX_BODY_BYTES
    is_form = request.mimetype in (
        "application/x-www-form-urlencoded",
        "multipart/form-data",
    )
    fields: dict = {}
    if not too_large:
        if is_form:
            fields = {k: request.form.get(k) for k in request.form.keys()}
        else:
            parsed = request.get_json(silent=True)
            fields = parsed if isinstance(parsed, dict) else {}
    # B4: read from the right, past internal hops. See client_ip.
    ip = client_ip(request.headers.get("X-Forwarded-For", ""), request.remote_addr)
    return Request(
        method=request.method,
        origin=request.headers.get("Origin"),
        is_form=is_form,
        fields=fields,
        ip=ip,
        too_large=too_large,
    )

