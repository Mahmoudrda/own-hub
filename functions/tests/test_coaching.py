"""The coach side's callables: her role (C08), her certificates (K02) and her
invites (K07). The role and certificates follow COACH_PORTFOLIO_LIVE and the
invites COACH_CLIENTS_LIVE; each refuses to write anything while its switch is
False."""

from __future__ import annotations

import datetime as dt

import pytest
from firebase_functions import https_fn

import coaching
import main
from coaching import certificates, errors, invites, roles
from identity import store
from tests import fake_firestore
from tests.test_entrypoints import inner, raises, request, stubbed  # noqa: F401

NOW = dt.datetime(2026, 10, 6, 12, tzinfo=dt.timezone.utc)
VERIFIED = {"verified": True}
COACH = {"verified": True, "coachV": "active"}


@pytest.fixture
def fs(monkeypatch, stubbed):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    return db


@pytest.fixture
def live(monkeypatch):
    monkeypatch.setattr(coaching, "COACH_PORTFOLIO_LIVE", True)
    monkeypatch.setattr(coaching, "COACH_CLIENTS_LIVE", True)


@pytest.fixture
def portfolio_closed(monkeypatch):
    monkeypatch.setattr(coaching, "COACH_PORTFOLIO_LIVE", False)


@pytest.fixture
def clients_closed(monkeypatch):
    monkeypatch.setattr(coaching, "COACH_CLIENTS_LIVE", False)


def test_the_portfolio_and_clients_ship_on_and_payments_off():
    # Move with coachPortfolioLive(), coachClientsLive() and coachPaymentsLive()
    # in both rules files.
    assert coaching.COACH_PORTFOLIO_LIVE is True
    assert coaching.COACH_CLIENTS_LIVE is True
    assert coaching.COACH_PAYMENTS_LIVE is False


# ------------------------------------------------------------------ roles


@pytest.mark.parametrize(
    "role, held",
    [("trainee", ["trainee"]), ("coach", ["coach"]), ("both", ["trainee", "coach"])],
)
def test_her_choice_is_written_by_the_server(fs, role, held):
    answer = roles.record(
        fs, "uid-1", {"role": role}, live=True, timestamp=NOW, coach_v="active"
    )
    assert answer == {"ok": True, "held": held}
    stored = fs.docs["users/uid-1"]["roles"]
    assert stored["held"] == held and stored["chosen"] == role
    assert set(stored) <= set(roles.FIELDS)


@pytest.mark.parametrize("coach_v", [None, "suspended", "pending", True])
@pytest.mark.parametrize("role", ["coach", "both"])
def test_a_coach_role_needs_the_coach_claim(fs, role, coach_v):
    with pytest.raises(errors.CoachingError) as caught:
        roles.record(fs, "uid-1", {"role": role}, live=True, timestamp=NOW, coach_v=coach_v)
    assert caught.value.code == errors.PERMISSION
    assert caught.value.reason == errors.NOT_A_COACH
    assert "users/uid-1" not in fs.docs


def test_the_closed_app_is_refused_before_the_claim(fs):
    with pytest.raises(errors.CoachingError) as caught:
        roles.record(fs, "uid-1", {"role": "coach"}, live=False, timestamp=NOW, coach_v=None)
    assert caught.value.reason == errors.COACH_APP_CLOSED


def test_a_trainee_needs_no_claim(fs, live):
    answer = inner("record_signup_role")(request({"role": "trainee"}))
    assert answer == {"ok": True, "held": ["trainee"]}


def test_a_trainee_is_recorded_while_the_portfolio_is_closed(fs, portfolio_closed):
    inner("record_signup_role")(request({"role": "trainee"}))
    assert fs.docs["users/uid-1"]["roles"]["held"] == ["trainee"]


@pytest.mark.parametrize("role", ["coach", "both"])
def test_a_coach_role_is_refused_while_closed(fs, portfolio_closed, role):
    error = raises(
        lambda: inner("record_signup_role")(request({"role": role})),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert error.message == errors.COACH_APP_CLOSED
    assert "users/uid-1" not in fs.docs


@pytest.mark.parametrize("role", [None, "admin", "Coach", 1, ["coach"]])
def test_anything_else_is_refused(fs, live, role):
    raises(
        lambda: inner("record_signup_role")(request({"role": role})),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )
    assert "users/uid-1" not in fs.docs


def test_choosing_again_replaces_the_roles_and_keeps_her_profile(fs, live):
    fs.docs["users/uid-1"] = {"profile": {"firstName": "Mai"}}
    roles.record(fs, "uid-1", {"role": "both"}, live=True, timestamp=NOW, coach_v="active")
    inner("record_signup_role")(request({"role": "trainee"}))
    doc = fs.docs["users/uid-1"]
    assert doc["roles"]["held"] == ["trainee"]
    assert doc["profile"] == {"firstName": "Mai"}


# ----------------------------------------------------------- certificates


def _cert(**overrides):
    body = {"credentialId": "nasm_cpt", "mediaRef": "coach-docs/uid1/nasm_cpt-1700000000000.jpg"}
    body.update(overrides)
    return body


def _submit(db, data, *, uid="uid1", verified=True, live=True, exists=True):
    return certificates.submit(
        db, uid, data, verified=verified, live=live,
        object_exists=lambda ref: exists, timestamp=NOW,
    )


def test_a_certificate_is_recorded_for_a_reviewer():
    db = fake_firestore.FakeFirestore()
    answer = _submit(db, _cert())
    assert answer == {"ok": True, "certificateId": "nasm_cpt-1700000000000", "state": "uploaded"}
    record = db.docs["coaches/uid1/certificates/nasm_cpt-1700000000000"]
    assert record["state"] == "uploaded" and record["credentialId"] == "nasm_cpt"
    assert set(record) <= set(certificates.FIELDS)


def test_sending_the_same_photo_twice_writes_once():
    db = fake_firestore.FakeFirestore()
    _submit(db, _cert())
    db.docs["coaches/uid1/certificates/nasm_cpt-1700000000000"]["state"] = "checking"
    _submit(db, _cert())
    assert db.docs["coaches/uid1/certificates/nasm_cpt-1700000000000"]["state"] == "checking"


@pytest.mark.parametrize(
    "data",
    [
        _cert(credentialId="Personal trainer"),
        _cert(credentialId=None),
        _cert(mediaRef="coach-docs/someone-else/x.jpg"),
        _cert(mediaRef="coach-docs/uid1/../uid2/x.jpg"),
        _cert(mediaRef="user-media/uid1/x.jpg"),
        _cert(mediaRef="coach-docs/uid1/x.exe"),
        _cert(mediaRef=7),
    ],
)
def test_a_typed_credential_or_a_foreign_path_is_refused(data):
    db = fake_firestore.FakeFirestore()
    with pytest.raises(errors.CoachingError) as caught:
        _submit(db, data)
    assert caught.value.reason == errors.BAD_REQUEST
    assert db.docs == {}


def test_a_photo_that_is_not_in_the_bucket_is_refused():
    db = fake_firestore.FakeFirestore()
    with pytest.raises(errors.CoachingError) as caught:
        _submit(db, _cert(), exists=False)
    assert caught.value.reason == errors.CERTIFICATE_NOT_UPLOADED
    assert db.docs == {}


def test_closed_and_unverified_are_refused_before_anything_is_read():
    db = fake_firestore.FakeFirestore()
    for kwargs, reason in (
        ({"live": False}, errors.COACH_APP_CLOSED),
        ({"verified": False}, errors.NOT_VERIFIED),
    ):
        with pytest.raises(errors.CoachingError) as caught:
            _submit(db, _cert(), **kwargs)
        assert caught.value.reason == reason
    assert db.docs == {}


def test_there_is_a_ceiling():
    db = fake_firestore.FakeFirestore()
    for n in range(certificates.MAX_CERTIFICATES):
        _submit(db, _cert(mediaRef=f"coach-docs/uid1/nasm_cpt-{n}.jpg"))
    with pytest.raises(errors.CoachingError) as caught:
        _submit(db, _cert(mediaRef="coach-docs/uid1/nasm_cpt-99.jpg"))
    assert caught.value.reason == errors.TOO_MANY_CERTIFICATES


def test_the_callable_is_closed_when_the_portfolio_is_off(fs, portfolio_closed):
    error = raises(
        lambda: inner("submit_coach_certificate")(request(_cert(), token=VERIFIED)),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert error.message == errors.COACH_APP_CLOSED


def test_the_callable_checks_the_bucket(fs, live, monkeypatch):
    seen = []
    monkeypatch.setattr(main, "_coach_object_exists", lambda ref: seen.append(ref) or True)
    body = _cert(mediaRef="coach-docs/uid-1/nasm_cpt-1.jpg")
    with pytest.raises(https_fn.HttpsError):
        # "uid-1" has a dash, which a Firebase uid never does: refused as shape.
        inner("submit_coach_certificate")(request(body, token=VERIFIED))
    body = _cert(mediaRef="coach-docs/uid1/nasm_cpt-1.jpg")
    answer = inner("submit_coach_certificate")(request(body, uid="uid1", token=VERIFIED))
    assert answer["state"] == "uploaded"
    assert seen == ["coach-docs/uid1/nasm_cpt-1.jpg"]


# ---------------------------------------------------------------- invites


def _codes(seq):
    it = iter(seq)
    return lambda: next(it)


def _create(db, uid="coach1", **kwargs):
    args = {"is_coach": True, "verified": True, "live": True, "now": NOW}
    args.update(kwargs)
    return invites.create(db, uid, **args)


def _accept(db, code, uid="client1", **kwargs):
    args = {"verified": True, "live": True, "now": NOW, "timestamp": NOW}
    args.update(kwargs)
    return invites.accept(db, uid, {"code": code}, **args)


def _coach_page(db, uid="coach1"):
    db.docs[f"coaches/{uid}"] = {"displayName": "Salma"}


def test_a_code_is_eight_unambiguous_characters():
    code = invites.new_code()
    assert len(code) == 8 and all(ch in invites.ALPHABET for ch in code)
    for ch in "01OIL":
        assert ch not in invites.ALPHABET


@pytest.mark.parametrize(
    "raw, code",
    [
        ("abcd-2345", "ABCD2345"),
        (" ABCD 2345 ", "ABCD2345"),
        ("ABCD٢٣٤٥", "ABCD2345"),
        ("ABCD234", None),
        ("ABCD2340", None),
        ("ABCDO345", None),
        (None, None),
        ("A" * 50, None),
    ],
)
def test_codes_are_forgiven_their_formatting_and_nothing_else(raw, code):
    assert invites.normalise(raw) == code


def test_a_coach_gets_one_live_code():
    db = fake_firestore.FakeFirestore()
    first = _create(db, make_code=_codes(["ABCD2345"]))
    assert first["code"] == "ABCD2345"
    again = _create(db, make_code=_codes(["ZZZZ2222"]))
    assert again["code"] == "ABCD2345", "asking again returns the same code"
    record = db.docs["coachInvites/ABCD2345"]
    assert set(record) <= set(invites.FIELDS) and record["coachUid"] == "coach1"


def test_a_lapsed_code_is_replaced():
    db = fake_firestore.FakeFirestore()
    db.docs["coachInvites/OLDC2345"] = {
        "coachUid": "coach1", "createdAt": NOW, "expiresAt": NOW - dt.timedelta(days=1),
    }
    fresh = _create(db, make_code=_codes(["NEWC2345"]))
    assert fresh["code"] == "NEWC2345"


def test_a_collision_takes_another_code():
    db = fake_firestore.FakeFirestore()
    db.docs["coachInvites/ABCD2345"] = {
        "coachUid": "other", "createdAt": NOW, "expiresAt": NOW + dt.timedelta(days=3),
    }
    made = _create(db, make_code=_codes(["ABCD2345", "EFGH2345"]))
    assert made["code"] == "EFGH2345"


@pytest.mark.parametrize(
    "kwargs, reason",
    [
        ({"live": False}, errors.COACH_APP_CLOSED),
        ({"verified": False}, errors.NOT_VERIFIED),
        ({"is_coach": False}, errors.NOT_A_COACH),
    ],
)
def test_only_a_live_verified_coach_may_invite(kwargs, reason):
    db = fake_firestore.FakeFirestore()
    with pytest.raises(errors.CoachingError) as caught:
        _create(db, **kwargs)
    assert caught.value.reason == reason
    assert db.docs == {}


def test_redeeming_opens_an_enquiry_with_her_coach():
    db = fake_firestore.FakeFirestore()
    _coach_page(db)
    code = _create(db, make_code=_codes(["ABCD2345"]))["code"]
    answer = _accept(db, code.lower())
    assert answer == {"ok": True, "relId": "coach1__client1", "coachUid": "coach1"}
    rel = db.docs["relationships/coach1__client1"]
    assert rel["status"] == "enquiry" and rel["source"] == "invite"
    assert rel["coachUid"] == "coach1" and rel["clientUid"] == "client1"
    # Nothing about her is written onto the code.
    assert set(db.docs["coachInvites/ABCD2345"]) == set(invites.FIELDS)


def test_redeeming_twice_changes_nothing():
    db = fake_firestore.FakeFirestore()
    _coach_page(db)
    code = _create(db, make_code=_codes(["ABCD2345"]))["code"]
    _accept(db, code)
    db.docs["relationships/coach1__client1"]["status"] = "active"
    _accept(db, code)
    assert db.docs["relationships/coach1__client1"]["status"] == "active"


def test_a_block_either_way_reads_as_no_such_code():
    for blocks in ("users/coach1/blocks/client1", "users/client1/blocks/coach1"):
        db = fake_firestore.FakeFirestore()
        _coach_page(db)
        code = _create(db, make_code=_codes(["ABCD2345"]))["code"]
        db.docs[blocks] = {"at": NOW}
        with pytest.raises(errors.CoachingError) as caught:
            _accept(db, code)
        assert caught.value.reason == errors.INVITE_INVALID
        assert "relationships/coach1__client1" not in db.docs


def test_refusals():
    db = fake_firestore.FakeFirestore()
    code = _create(db, make_code=_codes(["ABCD2345"]))["code"]
    cases = [
        (lambda: _accept(db, "ZZZZ2222"), errors.INVITE_INVALID),
        (lambda: _accept(db, "nonsense"), errors.INVITE_INVALID),
        # No coach page: the coach is gone or never cleared.
        (lambda: _accept(db, code), errors.INVITE_INVALID),
        (lambda: _accept(db, code, uid="coach1"), errors.INVITE_OWN),
        (lambda: _accept(db, code, verified=False), errors.NOT_VERIFIED),
        (lambda: _accept(db, code, live=False), errors.COACH_APP_CLOSED),
        (
            lambda: _accept(db, code, now=NOW + dt.timedelta(days=31)),
            errors.INVITE_EXPIRED,
        ),
    ]
    for call, reason in cases:
        with pytest.raises(errors.CoachingError) as caught:
            call()
        assert caught.value.reason == reason
    assert not any(path.startswith("relationships/") for path in db.docs)


def test_the_invite_callables_are_closed_when_clients_are_off(fs, clients_closed):
    for name, body in (("create_coach_invite", {}), ("accept_coach_invite", {"code": "ABCD2345"})):
        error = raises(
            lambda: inner(name)(request(body, token=COACH)),
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
        )
        assert error.message == errors.COACH_APP_CLOSED
    assert fs.docs == {}


def test_the_invite_callables_read_the_claims(fs, live):
    error = raises(
        lambda: inner("create_coach_invite")(request({}, token=VERIFIED)),
        https_fn.FunctionsErrorCode.PERMISSION_DENIED,
    )
    assert error.message == errors.NOT_A_COACH
    made = inner("create_coach_invite")(request({}, uid="coach1", token=COACH))
    fs.docs["coaches/coach1"] = {"displayName": "Salma"}
    error = raises(
        lambda: inner("accept_coach_invite")(request({"code": made["code"]}, uid="client1")),
        https_fn.FunctionsErrorCode.PERMISSION_DENIED,
    )
    assert error.message == errors.NOT_VERIFIED
    answer = inner("accept_coach_invite")(
        request({"code": made["code"]}, uid="client1", token=VERIFIED)
    )
    assert answer["relId"] == "coach1__client1"
