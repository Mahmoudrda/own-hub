"""One-click approval, pre-approved and test phones, known contacts, reviewer
settings, slots, booking and the schedule, over the in-memory Firestore.

Sections: approval with no call and no ID number, pre-approved and test
numbers (an empty environment approves nobody), the known-contact pass with and
without auto-pass, and slots, booking and the reviewer's schedule. The last
section holds each callable to its guard.
"""

from __future__ import annotations

import datetime as dt

import pytest
from firebase_functions import https_fn

import main
from identity import approvals, config, decisions, reasons, review, scheduling, store
from tests import fake_firestore
from tests.test_entrypoints import inner, request

DENIED = https_fn.FunctionsErrorCode.PERMISSION_DENIED
INVALID = https_fn.FunctionsErrorCode.INVALID_ARGUMENT
PRECONDITION = https_fn.FunctionsErrorCode.FAILED_PRECONDITION

HER = "her-uid"
HER_PHONE = "+201001234567"
REV = "rev-1"
REV2 = "rev-2"
MONDAY_10 = [{"weekday": 1, "start": "10:00", "end": "11:00"}]


class World:
    def __init__(self, db):
        self.db = db
        self.claims: dict = {}
        self.active = {REV, REV2}
        self.phones: dict = {}
        self.ghosts = {"ghost"}


@pytest.fixture
def world(monkeypatch):
    db = fake_firestore.FakeFirestore()
    w = World(db)
    monkeypatch.setattr(store, "db", lambda: db)
    monkeypatch.setattr(store.firestore, "transactional", fake_firestore.transactional)

    def mint(uid, verified):
        if uid in w.ghosts:
            raise RuntimeError("no such user")
        w.claims[uid] = verified

    monkeypatch.setattr(store, "mint_claims", mint)
    monkeypatch.setattr(store.FirestoreReviewStore, "notify_approved", lambda self, uid: None)
    monkeypatch.setattr(store.FirestoreReviewStore, "notify", lambda self, fid, codes: None)
    monkeypatch.setattr(review, "_sleep", lambda s: None)
    monkeypatch.setattr(approvals, "reviewer_active", lambda r: r in w.active)
    monkeypatch.setattr(
        approvals, "phones_for", lambda uids: {u: w.phones[u] for u in uids if u in w.phones}
    )
    return w


def staff(name, data=None, *, uid=REV, **claims):
    claims = claims or {"womanReviewer": True}
    token = {"firebase": {"sign_in_provider": "password"}, **claims}
    return inner(name)(request(data or {}, uid=uid, token=token))


def member(name, data=None, *, uid=HER, phone=HER_PHONE):
    token = {"phone_number": phone} if phone else {}
    return inner(name)(request(data or {}, uid=uid, token=token))


def ask(world, uid=HER, path="niqab"):
    """She asks for a woman reviewer: a pending case with a flag."""
    return review.request(store.FirestoreReviewStore(), uid, path)


def user(world, uid=HER):
    return world.db.docs.get(f"users/{uid}", {})


def raises(fn, code):
    with pytest.raises(https_fn.HttpsError) as caught:
        fn()
    assert caught.value.code == code
    return caught.value


# ----------------------------------------------------------------- approval


def test_one_call_approves_with_no_call_no_nid_no_note(world):
    flag_id = ask(world).flag_id
    answer = staff("approve_user", {"uid": HER})
    assert answer == {"state": "approved"}
    assert world.claims[HER] is True
    assert user(world)["verification"]["state"] == "approved"
    assert world.db.docs[f"verification_flags/{flag_id}"]["state"] == decisions.APPROVED
    ledger = world.db.docs[f"verificationLedger/{HER}"]
    assert ledger["approvedVia"] == "approve" and ledger["approvedBy"] == REV
    assert ledger["openFlagId"] is None


def test_known_person_reason_is_recorded(world):
    ask(world)
    staff("approve_user", {"uid": HER, "reason": "knownPerson"})
    assert world.db.docs[f"verificationLedger/{HER}"]["approvedVia"] == "knownPerson"


def test_approval_works_with_no_flag_and_no_booking(world):
    assert staff("approve_user", {"uid": HER}) == {"state": "approved"}
    assert user(world)["verification"]["state"] == "approved"


def test_approval_works_before_a_booking_and_clears_one(world):
    world.db.docs["verificationBookings/x"] = {"uid": HER, "reviewerId": REV, "start": "z"}
    ask(world)
    staff("approve_user", {"uid": HER})
    assert "verificationBookings/x" not in world.db.docs


def test_a_flag_with_an_id_hash_still_claims_the_registry(world):
    flag_id = ask(world).flag_id
    world.db.docs[f"verification_flags/{flag_id}"]["id_hmac"] = "h1"
    world.db.docs["nidRegistry/h1"] = {"uid": "someone-else", "state": "active", "pepper_version": 1}
    error = raises(lambda: staff("approve_user", {"uid": HER}), PRECONDITION)
    assert error.message == reasons.DUPLICATE_ID
    assert HER not in world.claims


def test_a_reviewer_cannot_approve_herself(world):
    error = raises(lambda: staff("approve_user", {"uid": REV}), PRECONDITION)
    assert error.message == reasons.REVIEWER_IS_SUBJECT


def test_only_a_reviewer_or_admin_may_approve(world):
    raises(lambda: staff("approve_user", {"uid": HER}, other=True), DENIED)
    assert staff("approve_user", {"uid": HER}, admin=True) == {"state": "approved"}


def test_an_unknown_reason_is_refused(world):
    raises(lambda: staff("approve_user", {"uid": HER, "reason": "sure"}), INVALID)
    assert HER not in world.claims


def test_bulk_approve_reports_each_row(world):
    ask(world, "a")
    ask(world, "b")
    answer = staff("approve_users", {"uids": ["a", "b", "a", "ghost", 7]})
    assert answer["approved"] == ["a", "b"]
    assert answer["failed"] == ["ghost", 7]
    assert world.claims == {"a": True, "b": True}


def test_bulk_approve_is_capped(world):
    uids = [f"u{i}" for i in range(config.APPROVE_BATCH_MAX + 1)]
    raises(lambda: staff("approve_users", {"uids": uids}), INVALID)


def test_revoke_takes_the_claim_back_and_reopens_the_case(world):
    ask(world)
    staff("approve_user", {"uid": HER})
    assert staff("revoke_user", {"uid": HER}) == {"state": "pending"}
    assert world.claims[HER] is False
    assert user(world)["verification"]["state"] == "pending"
    rows = staff("list_review_queue", {"status": "pending"})
    assert [r["uid"] for r in rows] == [HER]
    assert approvals.store.verification_gate(HER).open_flag_id


def test_decline_closes_the_flag_and_leaves_an_audit_trail(world):
    ask(world)
    assert staff("decline_user", {"uid": HER, "reason": "notClear"}) == {"state": "rejected"}
    assert user(world)["verification"]["state"] == "rejected"
    assert world.claims.get(HER) is not True
    assert not approvals.store.verification_gate(HER).open_flag_id
    ledger = world.db.docs[f"{config.COL_LEDGER}/{HER}"]
    assert ledger["declinedBy"] == REV and ledger["declineReason"] == "notClear"
    assert ledger["declinedAt"] is not None
    logged = [d for k, d in world.db.docs.items() if d.get("action") == "decline"]
    assert logged and logged[0].get("reviewerUid", REV) == REV


def test_decline_without_a_flag_still_rejects_and_records(world):
    assert staff("decline_user", {"uid": HER}) == {"state": "rejected"}
    assert user(world)["verification"]["state"] == "rejected"
    assert world.db.docs[f"{config.COL_LEDGER}/{HER}"]["declineReason"] == "other"


def test_decline_guards(world):
    raises(lambda: staff("decline_user", {"uid": REV}), PRECONDITION)
    raises(lambda: staff("decline_user", {"uid": HER, "reason": "free text"}), INVALID)
    raises(lambda: staff("decline_user", {"uid": HER}, uid="x", foo=True), DENIED)


def test_revoking_an_unknown_account_is_not_found(world):
    raises(lambda: staff("revoke_user", {"uid": "ghost"}), https_fn.FunctionsErrorCode.NOT_FOUND)


# ----------------------------------------------------------------- queue


def test_the_queue_lists_pending_scheduled_and_approved(world):
    ask(world, "p")
    ask(world, "s")
    world.db.docs["users/p"]["displayName"] = "Mona"
    world.db.docs["verification_flags/" + store.verification_gate("s").open_flag_id][
        "scheduledFor"
    ] = dt.datetime(2026, 10, 5, 7, tzinfo=dt.timezone.utc)
    ask(world, "d")
    staff("approve_user", {"uid": "d"})
    by_state = {r["uid"]: r for r in staff("list_review_queue", {})}
    assert by_state["p"]["state"] == "pending" and by_state["p"]["displayName"] == "Mona"
    assert by_state["s"]["state"] == "scheduled"
    assert by_state["s"]["scheduledFor"] == "2026-10-05T07:00:00Z"
    assert by_state["d"]["state"] == "approved"
    assert [r["uid"] for r in staff("list_review_queue", {"status": "scheduled"})] == ["s"]
    assert [r["uid"] for r in staff("list_review_queue", {"status": "approved"})] == ["d"]
    assert [r["uid"] for r in staff("list_review_queue", {"query": "mon"})] == ["p"]
    raises(lambda: staff("list_review_queue", {"status": "weird"}), INVALID)


def test_a_phone_shows_only_where_she_asked_for_the_call(world):
    ask(world, "asked")
    world.phones = {"asked": "+201000000001", "silent": "+201000000002"}
    decision = decisions.Decision(
        decisions.PENDING_REVIEW, (reasons.CAMERA_DECLINED,), (reasons.CAMERA_DECLINED,)
    )
    rs = store.FirestoreReviewStore()
    rs.open_flag("silent", None, review.flag_payload("silent", None, decision))
    rows = {r["uid"]: r for r in staff("list_review_queue", {"status": "pending"})}
    assert rows["asked"]["phone"] == "+201000000001"
    assert "phone" not in rows["silent"]
    access = [d for p, d in world.db.docs.items() if p.startswith("verificationReviewAccess/")]
    assert any(d["action"] == "list:phone" for d in access)


# ------------------------------------------------------ phone normalising


@pytest.mark.parametrize(
    "raw",
    ["+201001234567", "01001234567", "1001234567", "00201001234567", "201001234567",
     "+20 100 123 4567", "٠١٠٠١٢٣٤٥٦٧", "+20-100-123-4567"],
)
def test_egyptian_numbers_normalise_alike(raw):
    assert approvals.normalise_phone(raw) == "+201001234567"


@pytest.mark.parametrize("raw", ["", "12", "0100123456", "abc", None, 7, "+0123"])
def test_bad_numbers_normalise_to_nothing(raw):
    assert approvals.normalise_phone(raw) is None


def test_other_countries_keep_their_plus():
    assert approvals.normalise_phone("+44 7700 900123") == "+447700900123"


def test_a_list_is_split_on_commas_and_lines_and_deduplicated():
    assert approvals.parse_numbers("0100 123 4567, +201001234567\n01112223334; nope") == [
        "+201001234567",
        "+201112223334",
    ]


def test_preapproved_numbers_add_list_remove(world):
    answer = staff("set_preapproved_phones", {"add": "01001234567, 01112223334, bad"})
    assert answer == {"phones": ["+201001234567", "+201112223334"]}
    answer = staff("set_preapproved_phones", {"remove": ["01001234567", "zzz"]})
    assert answer == {"phones": ["+201112223334"]}
    assert staff("list_preapproved_phones") == {"phones": ["+201112223334"]}
    raises(lambda: staff("set_preapproved_phones", {"add": 5}), INVALID)
    raises(lambda: staff("set_preapproved_phones", {}, other=True), DENIED)


# ------------------------------------------------ claim_fast_verification


def test_a_preapproved_number_is_approved_at_sign_in(world):
    staff("set_preapproved_phones", {"add": "01001234567"})
    answer = member("claim_fast_verification")
    assert answer == {"state": "approved", "via": "preapproved"}
    assert world.claims[HER] is True
    assert world.db.docs[f"verificationLedger/{HER}"]["approvedBy"] == "system"
    assert world.db.docs[f"verificationLedger/{HER}"]["approvedVia"] == "preapproved"


def test_an_unlisted_number_gets_none(world):
    assert member("claim_fast_verification") == {"state": "none"}
    assert HER not in world.claims


def test_the_request_body_cannot_name_the_phone(world):
    staff("set_preapproved_phones", {"add": "01009998887"})
    answer = member("claim_fast_verification", {"phone": "+201009998887"})
    assert answer == {"state": "none"}


def test_a_test_phone_in_the_environment_is_approved(world, monkeypatch):
    monkeypatch.setenv("TEST_BYPASS_PHONES", "01005550000, +201006660000")
    approvals.reset_env_cache()
    answer = member("claim_fast_verification", phone="+201006660000")
    assert answer == {"state": "approved", "via": "testPhone"}
    assert member("claim_fast_verification", uid="other", phone="+201007770000") == {
        "state": "none"
    }


def test_an_empty_environment_approves_nobody(world, monkeypatch):
    for value in ("", " ", ",", "garbage"):
        monkeypatch.setenv("TEST_BYPASS_PHONES", value)
        approvals.reset_env_cache()
        assert approvals.bypass_phones() == frozenset()
        assert member("claim_fast_verification") == {"state": "none"}
    monkeypatch.delenv("TEST_BYPASS_PHONES")
    approvals.reset_env_cache()
    assert member("claim_fast_verification") == {"state": "none"}
    assert world.claims == {}


def test_a_token_with_no_phone_gets_none(world, monkeypatch):
    monkeypatch.setenv("TEST_BYPASS_PHONES", "01005550000")
    approvals.reset_env_cache()
    assert member("claim_fast_verification", phone=None) == {"state": "none"}


def test_a_store_review_account_is_approved(world, monkeypatch):
    monkeypatch.setattr(store, "store_reviewer_uids", lambda: frozenset({HER}))
    assert member("claim_fast_verification") == {"state": "approved", "via": "storeReviewer"}


def test_a_rejected_woman_is_not_passed_by_a_preapproved_number(world):
    staff("set_preapproved_phones", {"add": "01001234567"})
    world.db.docs[f"users/{HER}"] = {"verification": {"state": "rejected"}}
    assert member("claim_fast_verification") == {"state": "none"}


def test_an_approved_woman_just_hears_approved(world):
    staff("approve_user", {"uid": HER})
    assert member("claim_fast_verification") == {"state": "approved"}


def test_a_fast_claim_closes_her_open_flag(world):
    flag_id = ask(world).flag_id
    staff("set_preapproved_phones", {"add": "01001234567"})
    member("claim_fast_verification")
    assert world.db.docs[f"verification_flags/{flag_id}"]["state"] == decisions.APPROVED


def test_a_preapproved_claim_consumes_the_number(world):
    staff("set_preapproved_phones", {"add": "01001234567, 01002223334"})
    member("claim_fast_verification")
    assert "verificationPreapproved/+201001234567" not in world.db.docs
    assert "verificationPreapproved/+201002223334" in world.db.docs


def test_a_revoked_preapproved_woman_stays_revoked(world):
    staff("set_preapproved_phones", {"add": "01001234567"})
    assert member("claim_fast_verification")["via"] == "preapproved"
    world.phones[HER] = HER_PHONE
    staff("revoke_user", {"uid": HER})
    assert member("claim_fast_verification") == {"state": "none"}
    assert user(world)["verification"]["state"] == "pending"
    assert world.claims[HER] is False


def test_revoke_removes_an_unclaimed_preapproved_number(world):
    staff("set_preapproved_phones", {"add": "01001234567"})
    world.phones[HER] = HER_PHONE
    staff("approve_user", {"uid": HER})
    staff("revoke_user", {"uid": HER})
    assert "verificationPreapproved/+201001234567" not in world.db.docs
    assert member("claim_fast_verification") == {"state": "none"}


def test_a_revoked_test_number_stays_revoked_until_a_reviewer_approves(world, monkeypatch):
    monkeypatch.setenv("TEST_BYPASS_PHONES", "+201006660000")
    approvals.reset_env_cache()
    assert member("claim_fast_verification", phone="+201006660000")["via"] == "testPhone"
    staff("revoke_user", {"uid": HER})
    assert member("claim_fast_verification", phone="+201006660000") == {"state": "none"}
    staff("approve_user", {"uid": HER})
    assert member("claim_fast_verification", phone="+201006660000") == {"state": "approved"}
    staff("revoke_user", {"uid": HER})
    assert member("claim_fast_verification", phone="+201006660000") == {"state": "none"}


def _approve_with_failing_mint(world, monkeypatch):
    real = store.mint_claims

    def failing(uid, verified):
        if verified:
            raise RuntimeError("auth outage")
        real(uid, verified)

    monkeypatch.setattr(store, "mint_claims", failing)
    flag_id = ask(world).flag_id
    staff("approve_user", {"uid": HER})
    assert world.db.docs[f"verification_flags/{flag_id}"]["mintPending"] is True
    monkeypatch.setattr(store, "mint_claims", real)
    return flag_id


def test_revoke_clears_the_mint_retry_left_by_a_failed_approval(world, monkeypatch):
    flag_id = _approve_with_failing_mint(world, monkeypatch)
    staff("revoke_user", {"uid": HER})
    assert "mintPending" not in world.db.docs[f"verification_flags/{flag_id}"]
    main.expire_stale_reviews.__wrapped__(None)
    assert world.claims[HER] is False


def test_the_hourly_retry_skips_a_woman_revoked_since_her_approval(world, monkeypatch):
    flag_id = _approve_with_failing_mint(world, monkeypatch)
    staff("revoke_user", {"uid": HER})
    world.db.docs[f"verification_flags/{flag_id}"]["mintPending"] = True
    main.expire_stale_reviews.__wrapped__(None)
    assert world.claims[HER] is False
    assert world.db.docs[f"verification_flags/{flag_id}"]["mintPending"] is True


def test_a_revoked_store_review_account_is_not_bypassed(world, monkeypatch):
    monkeypatch.setattr(store, "store_reviewer_uids", lambda: frozenset({HER}))
    staff("approve_user", {"uid": HER})
    staff("revoke_user", {"uid": HER})
    assert member("request_review", {"path": "niqab"}) == {"state": "pending"}
    assert world.claims[HER] is False


def test_the_queue_shows_who_and_how_each_approval_happened(world):
    staff("set_preapproved_phones", {"add": "01001234567"})
    member("claim_fast_verification")
    staff("approve_user", {"uid": "other", "reason": "knownPerson"})
    world.db.docs["users/other"] = {"verification": {"state": "approved", "decidedAt": dt.datetime.now(dt.timezone.utc)}}
    rows = {r["uid"]: r for r in staff("list_review_queue", {"status": "approved"})}
    assert rows[HER]["approvedVia"] == "preapproved" and rows[HER]["approvedBy"] == "system"
    assert rows["other"]["approvedVia"] == "knownPerson" and rows["other"]["approvedBy"] == REV


def test_a_revoked_woman_has_no_approval_trail_in_the_queue(world):
    staff("approve_user", {"uid": HER})
    staff("revoke_user", {"uid": HER})
    world.db.docs[f"users/{HER}"]["verification"]["state"] = "approved"
    rows = staff("list_review_queue", {"status": "approved"})
    assert "approvedVia" not in rows[0]


# ------------------------------------------------------ known contact pass


def _settings(auto, listed=True, name="Rahma", uid=REV):
    return staff(
        "set_reviewer_settings",
        {"firstName": name, "listed": listed, "autoPassKnown": auto, "availability": MONDAY_10,
         "slotMinutes": 15},
        uid=uid,
    )


def test_a_known_contact_with_auto_pass_is_approved_at_once(world):
    _settings(True)
    answer = member("request_review", {"path": "niqab", "knownReviewerId": REV})
    assert answer == {"state": "approved", "via": "knownContact"}
    assert world.claims[HER] is True
    ledger = world.db.docs[f"verificationLedger/{HER}"]
    assert ledger["approvedVia"] == "knownContact" and ledger["approvedBy"] == REV
    assert not any(p.startswith("verification_flags/") for p in world.db.docs)


def test_a_known_contact_records_who_she_knows(world):
    _settings(True)
    member("request_review", {"path": "niqab", "knownReviewerId": REV})
    assert user(world)["verification"]["knownReviewerId"] == REV
    assert world.db.docs[f"verificationLedger/{HER}"]["knownReviewerId"] == REV


def test_a_revoked_known_contact_stays_pending(world):
    _settings(True)
    member("request_review", {"path": "niqab", "knownReviewerId": REV})
    staff("revoke_user", {"uid": HER}, uid=REV2)
    answer = member("request_review", {"path": "niqab", "knownReviewerId": REV})
    assert answer == {"state": "pending"}
    assert user(world)["verification"]["state"] == "pending"
    assert world.claims[HER] is False
    staff("approve_user", {"uid": HER}, uid=REV2)
    assert user(world)["verification"]["state"] == "approved"


def test_a_known_contact_without_auto_pass_waits_for_review(world):
    _settings(False)
    answer = member("request_review", {"path": "niqab", "knownReviewerId": REV})
    assert answer == {"state": "pending"}
    assert HER not in world.claims
    rows = staff("list_review_queue", {"status": "pending"})
    assert rows[0]["knownReviewer"] == REV


def test_a_reviewer_who_lost_the_claim_passes_nobody(world):
    _settings(True)
    world.active.discard(REV)
    assert member("request_review", {"path": "niqab", "knownReviewerId": REV}) == {
        "state": "pending"
    }
    assert HER not in world.claims


def test_an_unknown_reviewer_id_passes_nobody(world):
    assert member("request_review", {"path": "niqab", "knownReviewerId": "nobody"}) == {
        "state": "pending"
    }
    assert "knownReviewerId" not in user(world).get("verification", {})


def test_a_rejected_woman_is_not_passed_by_a_known_contact(world):
    _settings(True)
    world.db.docs[f"users/{HER}"] = {"verification": {"state": "rejected"}}
    raises(
        lambda: member("request_review", {"path": "niqab", "knownReviewerId": REV}),
        PRECONDITION,
    )
    assert HER not in world.claims


def test_a_reviewer_cannot_vouch_for_herself(world):
    _settings(True)
    answer = member("request_review", {"path": "niqab", "knownReviewerId": REV}, uid=REV)
    assert answer == {"state": "pending"}


def test_without_a_known_reviewer_the_request_is_unchanged(world):
    assert member("request_review", {"path": "niqab"}) == {"state": "pending"}


# ------------------------------------------------------ reviewer settings


def test_settings_default_then_round_trip(world):
    assert staff("get_reviewer_settings") == {
        "firstName": "", "listed": False, "autoPassKnown": False,
        "availability": [], "slotMinutes": 15,
    }
    saved = _settings(True)
    assert saved["availability"] == MONDAY_10 and saved["listed"] is True
    assert staff("get_reviewer_settings") == saved


@pytest.mark.parametrize(
    "patch",
    [
        {"availability": [{"weekday": 0, "start": "10:00", "end": "11:00"}]},
        {"availability": [{"weekday": 8, "start": "10:00", "end": "11:00"}]},
        {"availability": [{"weekday": True, "start": "10:00", "end": "11:00"}]},
        {"availability": [{"weekday": 1, "start": "11:00", "end": "10:00"}]},
        {"availability": [{"weekday": 1, "start": "10:00", "end": "25:00"}]},
        {"availability": "monday"},
        {"slotMinutes": 7},
        {"listed": "yes"},
        {"firstName": ""},
    ],
)
def test_bad_settings_are_refused(world, patch):
    data = {"firstName": "Rahma", "listed": True, "autoPassKnown": False,
            "availability": MONDAY_10, "slotMinutes": 15, **patch}
    raises(lambda: staff("set_reviewer_settings", data), INVALID)
    assert f"verificationReviewers/{REV}" not in world.db.docs


def test_only_a_woman_reviewer_has_settings(world):
    raises(lambda: staff("get_reviewer_settings", admin=True), DENIED)


def test_list_reviewers_shows_listed_active_reviewers_only(world):
    _settings(False, listed=True, name="Rahma")
    _settings(False, listed=False, name="Hidden", uid="rev-hidden")
    world.active.add("rev-hidden")
    _settings(False, listed=True, name="Gone", uid="rev-gone")
    assert member("list_reviewers") == [{"reviewerId": REV, "firstName": "Rahma"}]


# ------------------------------------------------------- slots, booking

NOW = dt.datetime(2026, 10, 2, 12, tzinfo=dt.timezone.utc)  # a Friday


def _starts(world):
    return [s["start"] for s in member("list_review_slots", {"days": 7})]


def test_slots_come_from_availability_in_cairo_time(world):
    _settings(False)
    assert _starts(world) == [
        "2026-10-05T07:00:00Z", "2026-10-05T07:15:00Z",
        "2026-10-05T07:30:00Z", "2026-10-05T07:45:00Z",
    ]
    assert {s["reviewerId"] for s in member("list_review_slots", {"days": 7})} == {REV}


def test_slots_follow_daylight_saving():
    settings = {"availability": MONDAY_10, "slotMinutes": 15}
    summer = scheduling._slot_starts(settings, NOW, 7)
    winter_now = dt.datetime(2026, 10, 28, 9, tzinfo=dt.timezone.utc)
    winter = scheduling._slot_starts(settings, winter_now, 7)
    assert summer[0].hour == 7 and winter[0] == dt.datetime(2026, 11, 2, 8, tzinfo=dt.timezone.utc)


def test_slots_respect_the_lead_time_and_the_horizon(world, monkeypatch):
    _settings(False)
    # Monday 10:00 Cairo is 07:00Z; "now" 06:30Z leaves under an hour's notice.
    monkeypatch.setattr(review, "_now", lambda: dt.datetime(2026, 10, 5, 6, 30, tzinfo=dt.timezone.utc))
    starts = _starts(world)
    assert starts[0] == "2026-10-05T07:30:00Z"
    assert all(s <= "2026-10-12T06:30:00Z" for s in starts)
    assert "2026-10-12T07:00:00Z" not in starts


def test_unlisted_reviewers_offer_no_slots(world):
    _settings(False, listed=False)
    assert _starts(world) == []


def test_a_booked_slot_leaves_the_list_and_shows_on_the_schedule(world):
    _settings(False)
    ask(world)
    answer = member("book_review_slot", {"reviewerId": REV, "start": "2026-10-05T07:15:00Z"})
    assert answer == {"scheduledFor": "2026-10-05T07:15:00Z"}
    assert "2026-10-05T07:15:00Z" not in _starts(world)
    assert user(world)["verification"]["reviewScheduledFor"] == dt.datetime(
        2026, 10, 5, 7, 15, tzinfo=dt.timezone.utc
    )
    rows = staff("list_schedule", {"from": "2026-10-05T00:00:00Z", "to": "2026-10-06T00:00:00Z"})
    assert [(r["uid"], r["start"]) for r in rows] == [(HER, "2026-10-05T07:15:00Z")]
    other = staff(
        "list_schedule",
        {"from": "2026-10-05T00:00:00Z", "to": "2026-10-06T00:00:00Z"},
        uid=REV2,
    )
    assert other == []


def test_the_schedule_shows_her_phone_only_with_consent(world):
    _settings(False)
    ask(world)
    world.phones[HER] = "+201000000009"
    member("book_review_slot", {"reviewerId": REV, "start": "2026-10-05T07:00:00Z"})
    window = {"from": "2026-10-05T00:00:00Z", "to": "2026-10-06T00:00:00Z"}
    assert staff("list_schedule", window)[0]["phone"] == "+201000000009"
    del world.db.docs[f"users/{HER}/consents/review-v{config.REVIEW_CONSENT_VERSION}"]
    assert "phone" not in staff("list_schedule", window)[0]


def test_two_women_cannot_take_the_same_slot(world):
    _settings(False)
    ask(world)
    ask(world, "second")
    member("book_review_slot", {"reviewerId": REV, "start": "2026-10-05T07:00:00Z"})
    error = raises(
        lambda: member(
            "book_review_slot", {"reviewerId": REV, "start": "2026-10-05T07:00:00Z"}, uid="second"
        ),
        PRECONDITION,
    )
    assert error.message == reasons.SLOT_UNAVAILABLE


def test_rebooking_replaces_the_old_slot(world):
    _settings(False)
    ask(world)
    member("book_review_slot", {"reviewerId": REV, "start": "2026-10-05T07:00:00Z"})
    member("book_review_slot", {"reviewerId": REV, "start": "2026-10-05T07:30:00Z"})
    assert "2026-10-05T07:00:00Z" in _starts(world)
    assert "2026-10-05T07:30:00Z" not in _starts(world)
    mine = [d for p, d in world.db.docs.items() if p.startswith("verificationBookings/")]
    assert [d["start"] for d in mine] == ["2026-10-05T07:30:00Z"]


@pytest.mark.parametrize(
    "start",
    ["2026-10-05T08:00:00Z", "2026-10-06T07:00:00Z", "2026-10-05T07:07:00Z",
     "2026-10-12T07:00:00Z", "2026-09-28T07:00:00Z", "not a time", "2026-10-05T07:00:00"],
)
def test_only_real_free_slots_book(world, start):
    _settings(False)
    ask(world)
    with pytest.raises(https_fn.HttpsError):
        member("book_review_slot", {"reviewerId": REV, "start": start})
    assert not [p for p in world.db.docs if p.startswith("verificationBookings/")]


def test_booking_needs_an_open_review(world):
    _settings(False)
    error = raises(
        lambda: member("book_review_slot", {"reviewerId": REV, "start": "2026-10-05T07:00:00Z"}),
        PRECONDITION,
    )
    assert error.message == reasons.REVIEW_NOT_PENDING
    assert not [p for p in world.db.docs if p.startswith("verificationBookings/")]


def test_booking_an_unlisted_reviewer_is_refused(world):
    _settings(False, listed=False)
    ask(world)
    raises(
        lambda: member("book_review_slot", {"reviewerId": REV, "start": "2026-10-05T07:00:00Z"}),
        PRECONDITION,
    )


def test_a_booking_pushes_the_flag_expiry_past_the_call(world):
    _settings(False)
    flag_id = ask(world).flag_id
    sla_before = world.db.docs[f"verification_flags/{flag_id}"]["slaExpiresAt"]
    staff("reschedule_review", {"uid": HER, "start": "2026-10-09T07:45:00Z"})
    flag = world.db.docs[f"verification_flags/{flag_id}"]
    assert flag["route"] == "video"
    assert flag["slaExpiresAt"] >= dt.datetime(2026, 10, 10, 7, 45, tzinfo=dt.timezone.utc)
    assert flag["slaExpiresAt"] > sla_before


def test_a_reviewer_reschedules_to_any_time(world):
    _settings(False)
    ask(world)
    member("book_review_slot", {"reviewerId": REV, "start": "2026-10-05T07:00:00Z"})
    answer = staff("reschedule_review", {"uid": HER, "start": "2026-10-06T13:20:00+03:00"}, uid=REV2)
    assert answer == {"scheduledFor": "2026-10-06T10:20:00Z"}
    rows = staff("list_schedule", {"from": "2026-10-05T00:00:00Z", "to": "2026-10-08T00:00:00Z"}, uid=REV2)
    assert [(r["uid"], r["start"]) for r in rows] == [(HER, "2026-10-06T10:20:00Z")]
    assert "2026-10-05T07:00:00Z" in _starts(world)


def test_reschedule_refuses_a_time_out_of_range_or_herself(world):
    ask(world)
    raises(lambda: staff("reschedule_review", {"uid": HER, "start": "2027-01-01T10:00:00Z"}), INVALID)
    raises(lambda: staff("reschedule_review", {"uid": REV, "start": "2026-10-05T10:00:00Z"}), PRECONDITION)


def test_approval_leaves_the_schedule_empty(world):
    _settings(False)
    ask(world)
    member("book_review_slot", {"reviewerId": REV, "start": "2026-10-05T07:00:00Z"})
    staff("approve_user", {"uid": HER})
    window = {"from": "2026-10-05T00:00:00Z", "to": "2026-10-06T00:00:00Z"}
    assert staff("list_schedule", window) == []
    assert "2026-10-05T07:00:00Z" in _starts(world)


def test_the_schedule_range_is_bounded(world):
    raises(lambda: staff("list_schedule", {"from": "2026-10-05T00:00:00Z", "to": "2026-10-05T00:00:00Z"}), INVALID)
    raises(lambda: staff("list_schedule", {"from": "2026-10-05T00:00:00Z", "to": "2027-10-05T00:00:00Z"}), INVALID)


# ------------------------------------------------------------------ guards

REVIEWER_OR_ADMIN = (
    "approve_user", "approve_users", "revoke_user", "list_review_queue",
    "set_preapproved_phones", "list_preapproved_phones",
)
REVIEWER_ONLY = (
    "get_reviewer_settings", "set_reviewer_settings", "list_schedule", "reschedule_review",
)
NOT_PHONE = ("google.com", "apple.com", "anonymous", "custom")


def _as(name, claims, provider):
    token = {"firebase": {"sign_in_provider": provider}, **claims}
    return inner(name)(request({}, uid="someone", token=token))


@pytest.mark.parametrize("name", REVIEWER_OR_ADMIN + REVIEWER_ONLY)
def test_a_phone_member_without_a_claim_is_refused(world, name):
    raises(lambda: _as(name, {}, "phone"), DENIED)


@pytest.mark.parametrize("provider", NOT_PHONE)
@pytest.mark.parametrize("name", REVIEWER_OR_ADMIN + REVIEWER_ONLY)
def test_a_reviewer_on_another_provider_is_refused(world, name, provider):
    error = raises(lambda: _as(name, {"womanReviewer": True}, provider), DENIED)
    assert error.message == reasons.PHONE_SIGN_IN_REQUIRED


@pytest.mark.parametrize("name", REVIEWER_ONLY)
def test_an_admin_is_refused_the_reviewer_only_callables(world, name):
    raises(lambda: _as(name, {"admin": True}, "password"), DENIED)


@pytest.mark.parametrize(
    "name",
    ("claim_fast_verification", "list_reviewers", "list_review_slots", "book_review_slot"),
)
@pytest.mark.parametrize("provider", ("password",) + NOT_PHONE)
def test_member_callables_stay_phone_only(world, name, provider):
    error = raises(lambda: _as(name, {"womanReviewer": True, "admin": True}, provider), DENIED)
    assert error.message == reasons.PHONE_SIGN_IN_REQUIRED


def test_an_admin_may_use_the_dashboard_callables(world):
    assert _as("list_preapproved_phones", {"admin": True}, "password") == {"phones": []}
