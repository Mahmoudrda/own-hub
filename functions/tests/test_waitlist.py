"""W1: join_waitlist, the launch waitlist behind the public site.

One field (an Egyptian mobile number or an email), a consent that must be
true, a honeypot, a per-IP daily cap keyed on an HMAC of the IP (never the raw
IP), and a duplicate that answers exactly like a first join so the endpoint
cannot be used to learn who is on the list.
"""

from __future__ import annotations

import ast
import datetime as dt
import json
import os

import pytest

from tests import fake_firestore
from waitlist import join

_FUNCTIONS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_ROOT = os.path.dirname(_FUNCTIONS)
NOW = dt.datetime(2026, 10, 4, 9, 30, tzinfo=dt.timezone.utc)
KEY = b"k" * 32
IP = "197.32.10.20"


# ----------------------------------------------------------- validation


@pytest.mark.parametrize(
    "raw,expected",
    [
        ("01012345678", "+201012345678"),
        ("011 2345 6789", "+201123456789"),
        ("012-3456-7890", "+201234567890"),
        ("015 1234 5678", "+201512345678"),
        ("+20 10 1234 5678", "+201012345678"),
        ("00201012345678", "+201012345678"),
        ("201012345678", "+201012345678"),
        ("٠١٠١٢٣٤٥٦٧٨", "+201012345678"),
        ("۰۱۰۱۲۳۴۵۶۷۸", "+201012345678"),
    ],
)
def test_egyptian_mobiles_are_normalised(raw, expected):
    assert join.normalise(raw) == ("phone", expected)


@pytest.mark.parametrize(
    "raw",
    [
        "0223456789",  # Cairo landline
        "01312345678",  # no such mobile prefix
        "0101234567",  # one digit short
        "010123456789",  # one digit long
        "+441012345678",
        "+2001012345678",
        "1012345678",
        "phone",
        "",
        "   ",
        None,
        12345678901,
    ],
)
def test_anything_else_is_not_a_phone(raw):
    assert join.normalise(raw) is None


@pytest.mark.parametrize(
    "raw,expected",
    [
        ("Salma@Example.com", "salma@example.com"),
        ("  noor.a+gym@mail.example.eg ", "noor.a+gym@mail.example.eg"),
    ],
)
def test_emails_are_normalised(raw, expected):
    assert join.normalise(raw) == ("email", expected)


@pytest.mark.parametrize(
    "raw",
    [
        "salma@",
        "@example.com",
        "salma@example",
        "sal ma@example.com",
        "salma@@example.com",
        "<script>@example.com",
        "a" * 250 + "@example.com",
    ],
)
def test_bad_emails_are_refused(raw):
    assert join.normalise(raw) is None


# ---------------------------------------------------------------- fakes


class FakeStore:
    def __init__(self):
        self.attempts: dict = {}
        self.entries: list = []
        self.proofs: dict = {}

    def count_attempt(self, ip_hash, day, now):
        key = (ip_hash, day)
        self.attempts[key] = self.attempts.get(key, 0) + 1
        return self.attempts[key]

    def has_contact(self, contact):
        return any(e["contact"] == contact for e in self.entries)

    def add(self, entry):
        self.entries.append(dict(entry))

    def record_consent_proof(self, proof_id, proof):
        self.proofs[proof_id] = dict(proof)

    def new_entries_today(self, day):
        return sum(1 for e in self.entries if e["at"].date().isoformat() == day)


def req(fields=None, *, method="POST", origin=None, form=False, ip=IP, too_large=False):
    payload = {"contact": "01012345678", "consent": True, "lang": "en"}
    if form:
        payload["consent"] = "yes"
    payload.update(fields or {})
    return join.Request(
        method=method,
        origin=origin,
        is_form=form,
        fields=payload,
        ip=ip,
        too_large=too_large,
    )


def handle(request, store=None):
    store = store if store is not None else FakeStore()
    return join.handle(request, store, lambda: KEY, NOW), store


def body(response):
    return json.loads(response.body)


# --------------------------------------------------------------- joining


def test_a_valid_phone_is_stored_with_exactly_the_promised_fields():
    response, store = handle(req())
    assert response.status == 200 and body(response) == {"ok": True}
    assert len(store.entries) == 1
    entry = store.entries[0]
    assert set(entry) == {"contact", "kind", "lang", "consent", "at", "ipHash", "expireAt"}
    assert entry["contact"] == "+201012345678"
    assert entry["kind"] == "phone"
    assert entry["lang"] == "en"
    assert entry["consent"] is True
    assert entry["at"] == NOW
    assert entry["expireAt"] == NOW + dt.timedelta(days=180)
    assert entry["ipHash"] == join.ip_hash(KEY, IP)


def test_the_raw_ip_is_never_stored():
    response, store = handle(req())
    assert IP not in repr(store.entries) and IP not in repr(store.attempts)
    assert join.ip_hash(KEY, IP) != join.ip_hash(b"other-key" * 4, IP)


def test_an_email_is_stored_as_an_email_and_arabic_is_kept():
    _, store = handle(req({"contact": "Noor@Example.com", "lang": "ar"}))
    assert store.entries[0]["kind"] == "email"
    assert store.entries[0]["contact"] == "noor@example.com"
    assert store.entries[0]["lang"] == "ar"


def test_an_unknown_language_falls_back_to_english():
    _, store = handle(req({"lang": "fr"}))
    assert store.entries[0]["lang"] == "en"


@pytest.mark.parametrize("consent", [False, None, "", "no", 0, "false"])
def test_without_consent_nothing_is_stored(consent):
    response, store = handle(req({"consent": consent}))
    assert response.status == 400 and body(response) == {"ok": False, "error": "invalid"}
    assert store.entries == []


def test_a_missing_consent_field_is_refused():
    request = req()
    del request.fields["consent"]
    response, store = handle(request)
    assert response.status == 400 and store.entries == []


@pytest.mark.parametrize("contact", ["0223456789", "not a contact", "", None, ["01012345678"]])
def test_an_invalid_contact_is_refused(contact):
    response, store = handle(req({"contact": contact}))
    assert response.status == 400 and store.entries == []


def test_an_oversized_body_is_refused_before_anything_else():
    response, store = handle(req(too_large=True))
    assert response.status == 400
    assert store.entries == [] and store.attempts == {}


# -------------------------------------------------------------- honeypot


def test_a_filled_honeypot_looks_like_success_and_writes_nothing():
    response, store = handle(req({join.HONEYPOT_FIELD: "https://spam.example"}))
    assert response.status == 200 and body(response) == {"ok": True}
    assert store.entries == [] and store.attempts == {}


def test_an_empty_honeypot_is_fine():
    _, store = handle(req({join.HONEYPOT_FIELD: ""}))
    assert len(store.entries) == 1


# ------------------------------------------------------------ rate limit


def test_the_attempt_past_the_cap_from_one_ip_in_a_day_is_refused():
    store = FakeStore()
    for n in range(join.DAILY_LIMIT_PER_IP):
        response, _ = handle(req({"contact": f"010{n:08d}"}), store)
        assert response.status == 200
    response, _ = handle(req({"contact": "01099999999"}), store)
    assert response.status == 429 and body(response) == {"ok": False, "error": "later"}
    assert len(store.entries) == join.DAILY_LIMIT_PER_IP


def test_invalid_attempts_count_against_the_cap_too():
    store = FakeStore()
    for _ in range(join.DAILY_LIMIT_PER_IP):
        handle(req({"contact": "nonsense"}), store)
    response, _ = handle(req(), store)
    assert response.status == 429 and store.entries == []


def test_another_ip_has_its_own_allowance():
    store = FakeStore()
    for n in range(join.DAILY_LIMIT_PER_IP + 1):
        handle(req({"contact": f"0101234567{n}"}), store)
    response, _ = handle(req({"contact": "01199999999"}, ip="41.33.1.1"), store)
    assert response.status == 200


def test_the_cap_is_fifty_a_day():
    # C3: Egyptian mobile carriers put many women behind one public address.
    assert join.DAILY_LIMIT_PER_IP == 50


# ------------------------------------------------------------- duplicates


def test_a_duplicate_answers_exactly_like_a_first_join_and_stores_nothing():
    store = FakeStore()
    first, _ = handle(req(), store)
    again, _ = handle(req({"contact": "+20 10 1234 5678"}), store)
    assert len(store.entries) == 1
    assert (again.status, again.body, again.headers) == (first.status, first.body, first.headers)


def test_a_duplicate_by_form_redirects_to_the_same_page():
    store = FakeStore()
    first, _ = handle(req(form=True), store)
    again, _ = handle(req(form=True), store)
    assert first.status == again.status == 303
    assert first.headers["Location"] == again.headers["Location"]
    assert len(store.entries) == 1


# ----------------------------------------------------- method and origin


@pytest.mark.parametrize("method", ["GET", "PUT", "DELETE", "PATCH"])
def test_only_post_is_accepted(method):
    response, store = handle(req(method=method))
    assert response.status == 405
    assert response.headers["Allow"] == "POST, OPTIONS"
    assert store.entries == [] and store.attempts == {}


def test_a_foreign_origin_is_refused_without_writing():
    response, store = handle(req(origin="https://evil.example"))
    assert response.status == 403
    assert "Access-Control-Allow-Origin" not in response.headers
    assert store.entries == [] and store.attempts == {}


@pytest.mark.parametrize(
    "origin", [join.SITE_ORIGIN, "http://localhost:8000", "http://127.0.0.1:5000", "http://localhost"]
)
def test_the_site_and_localhost_get_cors_headers(origin):
    response, _ = handle(req(origin=origin))
    assert response.status == 200
    assert response.headers["Access-Control-Allow-Origin"] == origin
    assert response.headers["Vary"] == "Origin"


@pytest.mark.parametrize(
    "origin", ["http://localhost.evil.example", "https://localhost:8000", "http://127.0.0.2"]
)
def test_lookalike_origins_are_refused(origin):
    response, _ = handle(req(origin=origin))
    assert response.status == 403


def test_a_preflight_from_the_site_is_answered():
    response, store = handle(req(method="OPTIONS", origin=join.SITE_ORIGIN))
    assert response.status == 204
    assert response.headers["Access-Control-Allow-Origin"] == join.SITE_ORIGIN
    assert response.headers["Access-Control-Allow-Methods"] == "POST, OPTIONS"
    assert store.attempts == {}


def test_a_preflight_from_elsewhere_is_refused():
    response, _ = handle(req(method="OPTIONS", origin="https://evil.example"))
    assert response.status == 403
    assert "Access-Control-Allow-Origin" not in response.headers


def test_a_no_script_form_post_with_a_null_origin_is_accepted():
    # The site sends Referrer-Policy: no-referrer, under which a browser sends
    # `Origin: null` on a form POST. The cap and validation still apply.
    response, store = handle(req(origin="null", form=True))
    assert response.status == 303 and len(store.entries) == 1


# ----------------------------------------------------- form redirects


@pytest.mark.parametrize(
    "fields,page",
    [
        ({}, "joined"),
        ({"contact": "nonsense"}, "check"),
        ({"consent": ""}, "check"),
    ],
)
def test_a_form_post_is_redirected_to_an_honest_page(fields, page):
    response, _ = handle(req(fields, form=True))
    assert response.status == 303
    assert response.headers["Location"] == f"{join.SITE_ORIGIN}/waitlist/{page}"


def test_an_arabic_form_post_lands_on_the_arabic_page():
    response, _ = handle(req({"lang": "ar"}, form=True))
    assert response.headers["Location"] == f"{join.SITE_ORIGIN}/ar/waitlist/joined"


def test_a_rate_limited_form_post_lands_on_the_later_page():
    store = FakeStore()
    for _ in range(join.DAILY_LIMIT_PER_IP):
        handle(req({"contact": "nonsense"}, form=True), store)
    response, _ = handle(req(form=True), store)
    assert response.headers["Location"] == f"{join.SITE_ORIGIN}/waitlist/later"


def test_a_form_post_from_localhost_is_redirected_back_to_localhost():
    response, _ = handle(req(form=True, origin="http://localhost:8000"))
    assert response.headers["Location"] == "http://localhost:8000/waitlist/joined"


def test_a_server_failure_is_an_honest_try_later(monkeypatch):
    class Broken(FakeStore):
        def add(self, entry):
            raise RuntimeError("firestore down")

    response, _ = handle(req(), Broken())
    assert response.status == 503 and body(response) == {"ok": False, "error": "later"}

    def no_key():
        raise RuntimeError("secret missing")

    response = join.handle(req(form=True), FakeStore(), no_key, NOW)
    assert response.headers["Location"].endswith("/waitlist/later")


# ------------------------------------------------- the Firestore store


@pytest.fixture
def fs():
    return fake_firestore.FakeFirestore()


def test_the_firestore_store_counts_per_ip_per_day(fs):
    store = join.FirestoreWaitlist(fs)
    assert store.count_attempt("h1", "2026-10-04", NOW) == 1
    assert store.count_attempt("h1", "2026-10-04", NOW) == 2
    assert store.count_attempt("h1", "2026-10-05", NOW) == 1
    assert store.count_attempt("h2", "2026-10-04", NOW) == 1
    record = fs.docs["waitlistRate/h1_2026-10-04"]
    assert set(record) == {"count", "expireAt"}
    assert record["expireAt"] == NOW + dt.timedelta(days=join.RATE_RETENTION_DAYS)


def test_the_firestore_store_finds_a_duplicate_and_adds(fs):
    store = join.FirestoreWaitlist(fs)
    assert store.has_contact("+201012345678") is False
    store.add({"contact": "+201012345678", "kind": "phone"})
    assert store.has_contact("+201012345678") is True
    assert store.has_contact("+201112345678") is False
    assert [p for p in fs.docs if p.startswith("waitlist/")]


def test_end_to_end_on_the_fake_firestore(fs):
    store = join.FirestoreWaitlist(fs)
    join.handle(req(), store, lambda: KEY, NOW)
    join.handle(req(), store, lambda: KEY, NOW)
    entries = [v for p, v in fs.docs.items() if p.startswith("waitlist/")]
    assert len(entries) == 1 and entries[0]["contact"] == "+201012345678"
    assert IP not in repr(fs.docs)


# ------------------------------------------------------------ the wiring


def test_the_site_origin_matches_the_site_config():
    with open(os.path.join(_ROOT, "site", "config.json"), encoding="utf-8") as handle_:
        base = json.load(handle_)["baseUrl"].rstrip("/")
    assert join.SITE_ORIGIN == base


def test_the_site_form_posts_to_this_function():
    with open(os.path.join(_ROOT, "site", "config.json"), encoding="utf-8") as handle_:
        endpoint = json.load(handle_)["values"]["waitlistEndpoint"]["value"]
    assert endpoint == "https://europe-west3-own-hub.cloudfunctions.net/join_waitlist"


def test_join_waitlist_is_a_post_only_http_function_in_frankfurt():
    tree = ast.parse(open(os.path.join(_FUNCTIONS, "main.py"), encoding="utf-8").read())
    found = [n for n in ast.walk(tree) if isinstance(n, ast.FunctionDef) and n.name == "join_waitlist"]
    assert len(found) == 1
    (decorator,) = found[0].decorator_list
    assert ast.unparse(decorator.func) == "https_fn.on_request"
    keywords = {k.arg: ast.unparse(k.value) for k in decorator.keywords}
    assert keywords["region"] == "config.REGION"
    assert "enforce_app_check" not in keywords


def test_the_flask_adapter_end_to_end(monkeypatch):
    import main
    from werkzeug.test import EnvironBuilder
    from flask import Request

    store = FakeStore()
    monkeypatch.setattr(main, "_waitlist_store", lambda: store)
    monkeypatch.setattr(join, "ip_key", lambda: KEY)
    builder = EnvironBuilder(
        method="POST",
        data={"contact": "01012345678", "consent": "yes", "lang": "ar", "website": ""},
        headers={"Origin": "null", "X-Forwarded-For": f"10.0.0.1, {IP}"},
    )
    response = main.join_waitlist.__wrapped__(Request(builder.get_environ())) if hasattr(
        main.join_waitlist, "__wrapped__"
    ) else main.join_waitlist(Request(builder.get_environ()))
    assert response.status_code == 303
    assert response.headers["Location"] == f"{join.SITE_ORIGIN}/ar/waitlist/joined"
    # The LAST X-Forwarded-For entry is the one Google's front end added.
    assert store.entries[0]["ipHash"] == join.ip_hash(KEY, IP)
    assert store.entries[0]["lang"] == "ar"


def test_the_waitlist_never_logs_a_contact():
    source = open(os.path.join(_FUNCTIONS, "waitlist", "join.py"), encoding="utf-8").read()
    tree = ast.parse(source)
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and ast.unparse(node.func).startswith("logs."):
            assert not any(k.arg in {"contact", "ip", "ipHash"} for k in node.keywords)


# ----------------------------------------------- M11: proof of her agreement


def test_a_join_records_a_proof_of_the_wording_she_agreed_to():
    _, store = handle(req({"lang": "ar"}))
    ((proof_id, proof),) = store.proofs.items()
    assert proof_id == join.proof_id(KEY, "+201012345678")
    assert set(proof) == {"wordingVersion", "lang", "at", "expireAt"}
    assert proof["wordingVersion"] == join.CONSENT_WORDING_VERSION
    assert proof["lang"] == "ar"
    assert proof["at"] == NOW
    assert proof["expireAt"] == NOW + dt.timedelta(days=180 + 3 * 365)


def test_the_proof_outlives_the_last_possible_message_by_three_years():
    # PDPL Art. 18: 3 years from the last message. The one message is sent
    # while her entry exists, so no later than RETENTION_DAYS after joining.
    _, store = handle(req())
    ((_, proof),) = store.proofs.items()
    last_message = NOW + dt.timedelta(days=join.RETENTION_DAYS)
    assert proof["expireAt"] == last_message + dt.timedelta(days=3 * 365)


def test_the_proof_holds_no_contact_and_no_ip():
    _, store = handle(req())
    text = repr(store.proofs)
    assert "1012345678" not in text and IP not in text
    assert join.ip_hash(KEY, IP) not in text


def test_the_proof_code_is_not_the_ip_code_or_a_plain_hash():
    import hashlib

    contact = "+201012345678"
    code = join.proof_id(KEY, contact)
    assert code != join.ip_hash(KEY, contact)
    assert code != hashlib.sha256(contact.encode()).hexdigest()
    assert code == join.proof_id(KEY, contact)


def test_nothing_is_proved_without_consent_or_for_a_duplicate():
    _, store = handle(req({"consent": False}))
    assert store.proofs == {}
    store = FakeStore()
    handle(req(), store)
    handle(req(), store)
    assert len(store.proofs) == 1


def test_the_proof_collection_is_closed_to_every_client():
    rules = open(
        os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "firebase", "firestore.rules"),
        encoding="utf-8",
    ).read()
    assert "match /waitlistConsentProof/{key} { allow read, write: if false; }" in rules
