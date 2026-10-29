"""S4: delete_account. Order, completeness, the three rows that survive, and
recovery after a failure part way."""

from __future__ import annotations

import filecmp
import json
import os
import re

import pytest

from account import deletion, manifest
from identity import config

_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_JSON = os.path.join(_ROOT, "contracts", "deletion_manifest.json")
_DART = os.path.join(
    _ROOT, "app", "lib", "features", "account", "domain", "deletion_manifest.dart"
)


class FakeBackend:
    """An in-memory world: Firestore, Auth and Storage."""

    def __init__(self, uid="her", fail_at=None):
        self.calls: list[tuple] = []
        self.fail_at = fail_at
        self.record: dict = {}
        self.auth = {uid: {"disabled": False}}
        self.users = {uid: {"profile": {}}, "other": {"blockedBy": {uid: True}}}
        self.blocks = {uid: ["other"]}
        self.plans = {uid: True}
        self.storage = {
            (None, f"user-media/{uid}/a.jpg"),
            (None, f"user-exports/{uid}/x.zip"),
            ("own-hub-personal", f"user-media/{uid}/b.jpg"),
            (None, "user-media/someone/c.jpg"),
        }
        self.collections = {
            config.COL_VERIFICATION_JOBS: {"j1": {"uid": uid}, "j2": {"uid": "x"}},
            config.COL_FLAGS: {"f1": {"uid": uid}},
            config.COL_SESSIONS: {"s1": {"uid": uid}},
            config.COL_BOOKINGS: {
                "b1": {"uid": uid, "reviewerId": "rev"},
                "b2": {"uid": "other", "reviewerId": uid},
                "b3": {"uid": "other", "reviewerId": "rev"},
            },
            config.COL_REVIEWERS: {uid: {"listed": True}, "rev": {"listed": True}},
            config.COL_LEDGER: {uid: {"spent_micro_usd": 3000}},
            config.COL_PREAPPROVED: {"+201001234567": {"phone": "+201001234567"}, "+201009999999": {}},
        }
        self.phones = {uid: "+201001234567"}
        self.registry = {"h1": {"uid": uid, "state": "active", "pepper_version": 1}}
        self.reports = {
            "r1": {"reporterUid": uid, "subjectUid": "x"},
            "r2": {"reporterUid": "x", "subjectUid": uid},
        }

    def _step(self, name, *args):
        self.calls.append((name, *args))
        if self.fail_at == name:
            self.fail_at = None  # fail once
            raise RuntimeError("simulated outage")

    def set_state(self, uid, state):
        self._step("set_state", state)
        self.record.setdefault("requestedAt", "t0")
        self.record.update({"state": state, "updatedAt": "t"})

    def finish_record(self, uid):
        self._step("finish_record")
        self.record = {
            "state": "done",
            "requestedAt": self.record.get("requestedAt"),
            "updatedAt": "t",
            "doneAt": "t",
            "sweepAfter": "t+65m",
        }

    def mark_swept(self, uid):
        self._step("mark_swept")
        self.record.pop("sweepAfter", None)
        self.record["sweptAt"] = "t"

    def lock_auth(self, uid):
        self._step("lock_auth")
        if uid in self.auth:
            self.auth[uid]["disabled"] = True

    def blocked_uids(self, uid):
        self._step("blocked_uids")
        return list(self.blocks.get(uid, []))

    def retain_legal_hold(self, uid):
        self._step("retain_legal_hold")

    def delete_blocked_by(self, other, uid):
        self._step("delete_blocked_by", other)
        self.users.get(other, {}).get("blockedBy", {}).pop(uid, None)

    def delete_user_tree(self, uid):
        self._step("delete_user_tree")
        self.users.pop(uid, None)
        self.blocks.pop(uid, None)

    def delete_plans_tree(self, uid):
        self._step("delete_plans_tree")
        self.plans.pop(uid, None)

    def delete_storage_prefix(self, bucket, prefix):
        self._step("delete_storage_prefix", bucket, prefix)
        self.storage = {
            (b, p) for (b, p) in self.storage if not (b == bucket and p.startswith(prefix))
        }

    def delete_where_uid(self, collection, uid, field="uid"):
        self._step("delete_where_uid", collection)
        docs = self.collections[collection]
        for key in [k for k, v in docs.items() if v.get(field) == uid]:
            del docs[key]

    def delete_doc(self, collection, doc_id):
        self._step("delete_doc", collection)
        self.collections[collection].pop(doc_id, None)

    def delete_preapproved(self, uid):
        self._step("delete_preapproved")
        phone = self.phones.get(uid) if uid in self.auth else None
        if phone:
            self.collections[config.COL_PREAPPROVED].pop(phone, None)

    def close_registry(self, uid, may_rejoin):
        self._step("close_registry", may_rejoin)
        for key in [k for k, v in self.registry.items() if v["uid"] == uid]:
            if may_rejoin:
                del self.registry[key]
            else:
                self.registry[key].update({"state": "closed", "uid": None})

    hook_pauses = 0  # B3: how many calls run out of time before finishing

    def purge_group_hook(self, uid, deadline=None):
        self._step("purge_group_hook")
        if self.hook_pauses:
            self.hook_pauses -= 1
            return False
        self.community_purged = True
        return True

    def pseudonymise_reports(self, uid, token):
        self._step("pseudonymise_reports")
        for report in self.reports.values():
            for field in ("reporterUid", "subjectUid"):
                if report[field] == uid:
                    report[field] = token

    def delete_auth(self, uid):
        self._step("delete_auth")
        self.auth.pop(uid, None)


def _destructive(calls):
    return [c for c in calls if c[0].startswith("delete") or c[0] in {"close_registry", "pseudonymise_reports"}]


def test_the_journal_is_the_contract():
    with open(os.path.join(_ROOT, "contracts", "identity_contract.json")) as handle:
        assert deletion.JOURNAL == json.load(handle)["deletionJournal"]
    result = deletion.run("her", FakeBackend())
    assert result == {"state": "done", "journal": deletion.JOURNAL}


def test_states_are_written_in_journal_order():
    fake = FakeBackend()
    deletion.run("her", fake)
    states = [c[1] for c in fake.calls if c[0] == "set_state"]
    assert states == deletion.JOURNAL[:-1]


def test_auth_is_locked_before_any_delete_and_deleted_last():
    fake = FakeBackend()
    deletion.run("her", fake)
    names = [c[0] for c in fake.calls]
    first_destructive = fake.calls.index(_destructive(fake.calls)[0])
    assert names.index("lock_auth") < first_destructive
    assert [c for c in fake.calls if c[0] != "finish_record"][-1][0] == "delete_auth"
    assert "her" not in fake.auth


def test_everything_uid_keyed_is_gone():
    fake = FakeBackend()
    deletion.run("her", fake)
    assert "her" not in fake.users
    assert "her" not in fake.users["other"]["blockedBy"], "row 17 reverse cleanup"
    assert "her" not in fake.plans
    assert fake.storage == {(None, "user-media/someone/c.jpg")}
    assert list(fake.collections[config.COL_VERIFICATION_JOBS]) == ["j2"]
    assert fake.collections[config.COL_FLAGS] == {}
    assert fake.collections[config.COL_SESSIONS] == {}
    assert fake.collections[config.COL_LEDGER] == {}
    assert list(fake.collections[config.COL_BOOKINGS]) == ["b3"]
    assert list(fake.collections[config.COL_REVIEWERS]) == ["rev"]
    assert list(fake.collections[config.COL_PREAPPROVED]) == ["+201009999999"]


def test_the_registry_is_closed_not_deleted_by_default():
    assert config.DELETED_ACCOUNT_MAY_REJOIN is False
    fake = FakeBackend()
    deletion.run("her", fake)
    assert fake.registry["h1"]["state"] == "closed" and fake.registry["h1"]["uid"] is None


def test_the_registry_is_deleted_when_rejoining_is_allowed(monkeypatch):
    monkeypatch.setattr(config, "DELETED_ACCOUNT_MAY_REJOIN", True)
    fake = FakeBackend()
    deletion.run("her", fake)
    assert fake.registry == {}


def test_reports_are_pseudonymised_with_one_token():
    fake = FakeBackend()
    deletion.run("her", fake)
    token_a = fake.reports["r1"]["reporterUid"]
    token_b = fake.reports["r2"]["subjectUid"]
    assert token_a == token_b and re.fullmatch(r"deleted-[0-9a-f]{16}", token_a)
    assert fake.reports["r1"]["subjectUid"] == "x"


def test_the_deletion_record_keeps_only_state_and_timestamps():
    fake = FakeBackend()
    deletion.run("her", fake)
    assert set(fake.record) <= deletion.DELETION_RECORD_FIELDS
    assert set(fake.record) == {"state", "requestedAt", "updatedAt", "doneAt", "sweepAfter"}
    assert fake.record["state"] == "done"


@pytest.mark.parametrize(
    "step", ["delete_user_tree", "delete_storage_prefix", "close_registry", "delete_auth"]
)
def test_a_failure_part_way_is_recorded_and_a_rerun_finishes(step):
    fake = FakeBackend(fail_at=step)
    with pytest.raises(RuntimeError):
        deletion.run("her", fake)
    assert fake.record["state"] == deletion.FAILED_RETRYABLE
    assert deletion.FAILED_RETRYABLE in deletion.UNFINISHED_STATES
    assert deletion.run("her", fake)["state"] == "done"
    assert fake.record["state"] == "done"
    assert "her" not in fake.auth and "her" not in fake.users


# ------------------------------------------------------------- the manifest


def test_every_manifest_row_has_a_server_action():
    rows = manifest.load(_JSON)
    assert [r.number for r in rows] == list(range(1, 63))
    assert set(manifest.ACTIONS) == {r.number for r in rows}
    manifest.check(rows)


def test_a_row_without_an_action_is_a_visible_failure():
    with pytest.raises(RuntimeError):
        manifest.check([manifest.Row(99, "newCollection/{uid}", "recursive")])


def test_the_bundled_copy_is_identical_to_the_contract():
    bundled = os.path.join(os.path.dirname(manifest.__file__), "deletion_manifest.json")
    assert filecmp.cmp(_JSON, bundled, shallow=False)


def test_the_json_and_the_dart_manifest_agree():
    source = open(_DART, encoding="utf-8").read()
    literal = r"'(?:[^'\\]|\\.)*'"
    dart = set()
    for m in re.finditer(
        r"DeletionRow\(\s*number:\s*(\d+),.*?path:\s*((?:" + literal + r"\s*)+),"
        r".*?method:\s*DeletionMethod\.(\w+)",
        source,
        re.S,
    ):
        path = "".join(
            part.replace("\\'", "'") for part in re.findall(r"'((?:[^'\\]|\\.)*)'", m.group(2))
        )
        dart.add((int(m.group(1)), path, m.group(3)))
    json_rows = {(r.number, r.path, r.method) for r in manifest.load(_JSON)}
    assert dart <= json_rows, sorted(dart - json_rows)
    top = max(n for n, _, _ in dart)
    assert {r for r in json_rows if r[0] <= top} == dart


def test_the_new_rows_are_the_verification_collections():
    rows = {r.number: r for r in manifest.load(_JSON)}
    assert rows[39].path == "verification_flags where uid == {uid}"
    assert rows[40].path == "verificationLedger/{uid}"
    assert rows[41].path == "verificationSessions where uid == {uid}"
    assert {rows[n].method for n in (39, 40, 41)} == {"groupHook"}


def test_a_missing_bucket_is_treated_as_empty(monkeypatch):
    from firebase_admin import storage
    from google.api_core import exceptions

    def no_bucket(name=None, app=None):
        if name is None:
            raise ValueError("no default bucket configured")
        raise exceptions.NotFound("no such bucket")

    monkeypatch.setattr(storage, "bucket", no_bucket)
    backend = deletion.FirebaseBackend.__new__(deletion.FirebaseBackend)
    backend.delete_storage_prefix(None, "user-media/her/")
    backend.delete_storage_prefix("own-hub-personal", "user-media/her/")


def test_the_ttl_rows_are_the_unlinked_signals_and_the_access_log():
    rows = {r.number: r for r in manifest.load(_JSON)}
    assert rows[42].path == "verificationBehaviour/{idHmac}"
    assert rows[43].path == "verificationInstalls/{installHash}"
    assert rows[44].path == "verificationReviewAccess where flagId in her flags"
    assert {rows[n].method for n in (42, 43, 44)} == {"ttl"}
    assert {manifest.ACTIONS[n] for n in (42, 43, 44)} == {manifest.TTL}


def test_the_community_and_coach_rows_run_in_the_group_hook():
    # APL-16: posts, her comments, coach pages, relationships and invite codes
    # are named one by one, and all of them are purge_group_hook's work.
    rows = {r.number: r for r in manifest.load(_JSON)}
    assert rows[45].path.startswith("posts/{postId} where authorUid == uid")
    assert rows[47].path.startswith("coaches/{uid}/**")
    assert rows[49].path == "coachInvites where coachUid == uid"
    assert {rows[n].method for n in range(45, 50)} == {"groupHook"}
    assert {manifest.ACTIONS[n] for n in range(45, 50)} == {manifest.GROUP_HOOK}


def test_a_booked_slot_is_gone_after_deletion_on_the_real_backend():
    from tests.fake_firestore import FakeFirestore

    db = FakeFirestore()
    db.docs["verificationBookings/rev_20261005T0700Z"] = {"uid": "her", "reviewerId": "rev"}
    db.docs["verificationBookings/rev_20261005T0715Z"] = {"uid": "other", "reviewerId": "rev"}
    db.docs["verificationBookings/her_20261005T0730Z"] = {"uid": "other", "reviewerId": "her"}
    db.docs["verificationReviewers/her"] = {"listed": True}
    backend = deletion.FirebaseBackend.__new__(deletion.FirebaseBackend)
    backend.db = db
    backend.delete_where_uid(config.COL_BOOKINGS, "her")
    backend.delete_where_uid(config.COL_BOOKINGS, "her", field="reviewerId")
    backend.delete_doc(config.COL_REVIEWERS, "her")
    assert list(db.docs) == ["verificationBookings/rev_20261005T0715Z"]


def test_row_52_is_the_preapproved_number_and_runs_in_the_group_hook():
    rows = {r.number: r for r in manifest.load(_JSON)}
    assert rows[52].path == "verificationPreapproved/{E.164 phone of her Auth account}"
    assert rows[52].method == "groupHook"
    assert manifest.ACTIONS[52] == manifest.PREAPPROVED


def test_a_preapproved_number_is_deleted_by_her_auth_phone_on_the_real_backend(monkeypatch):
    from firebase_admin import auth

    from tests.fake_firestore import FakeFirestore

    db = FakeFirestore()
    db.docs["verificationPreapproved/+201001234567"] = {"phone": "+201001234567"}
    db.docs["verificationPreapproved/+201009999999"] = {"phone": "+201009999999"}
    backend = deletion.FirebaseBackend.__new__(deletion.FirebaseBackend)
    backend.db = db

    class _User:
        phone_number = "+201001234567"

    monkeypatch.setattr(auth, "get_user", lambda uid: _User())
    backend.delete_preapproved("her")
    assert list(db.docs) == ["verificationPreapproved/+201009999999"]

    def gone(uid):
        raise auth.UserNotFoundError("gone")

    monkeypatch.setattr(auth, "get_user", gone)
    backend.delete_preapproved("her")
    assert list(db.docs) == ["verificationPreapproved/+201009999999"]


def test_the_coaching_rows_are_named_and_run_in_the_group_hook():
    rows = {r.number: r for r in manifest.load(_JSON)}
    assert rows[55].path == "coachApplications/{uid}"
    assert rows[56].path.startswith("coachPrivate/{uid}/**")
    assert rows[57].path == "coaches/{uid}/packages/**, coaches/{uid}/drafts/** and coaches/{uid}/media/**"
    assert rows[58].path.startswith("subscriptions where clientUid or coachUid == uid")
    assert {rows[n].method for n in (55, 56, 57, 58)} == {"groupHook"}
    assert {manifest.ACTIONS[n] for n in (55, 56, 57, 58)} == {manifest.GROUP_HOOK}
    # Payment records survive on purpose, with her uid replaced.
    assert rows[59].method == "pseudonymised"
    assert manifest.ACTIONS[59] == manifest.GROUP_HOOK


def test_rows_60_and_61_the_report_evidence_and_the_release_evidence_are_named():
    rows = {r.number: r for r in manifest.load(_JSON)}
    assert rows[60].path.startswith("reports/{id}/evidence/content")
    assert manifest.ACTIONS[60] == manifest.REPORTS
    assert rows[61].path == "coachPrivate/{uid}/mediaConsents/{id}"
    assert manifest.ACTIONS[61] == manifest.GROUP_HOOK


def _reports_backend():
    from tests.fake_firestore import FakeFirestore

    db = FakeFirestore()
    db.docs["reports/r1"] = {"reporterUid": "her", "subjectUid": "x"}
    db.docs["reports/r1/evidence/content"] = {"subject": {"text": "hello"}}
    db.docs["reports/r1"]["subjectRef"] = "relationships/x__her/messages/m1"
    db.docs["reports/r2"] = {"reporterUid": "y", "subjectUid": "her", "subjectRef": "relationships/her__y/messages/m2"}
    db.docs["reports/r2/evidence/content"] = {
        "subject": {"displayName": "Her Name", "headline": "Coach Her", "text": "kept", "name": "Plan A"},
        "plan": {"coachName": "Her Name", "coachUid": "her", "subId": "s1", "name": "Plan A", "body": {"note": "reported words"}},
    }
    db.docs["reports/r3"] = {"reporterUid": "y", "subjectUid": "z"}
    db.docs["reports/r3/evidence/content"] = {"subject": {"text": "other"}}
    backend = deletion.FirebaseBackend.__new__(deletion.FirebaseBackend)
    backend.db = db
    return backend, db


def test_the_reporter_deleting_hers_deletes_the_evidence_on_the_real_backend():
    backend, db = _reports_backend()
    backend.pseudonymise_reports("her", "tok")
    assert db.docs["reports/r1"]["reporterUid"] == "tok"
    assert "reports/r1/evidence/content" not in db.docs
    assert "reports/r3/evidence/content" in db.docs


def test_the_reported_side_deleting_hers_keeps_the_evidence_pseudonymised():
    backend, db = _reports_backend()
    backend.pseudonymise_reports("her", "tok")
    assert db.docs["reports/r2"]["subjectUid"] == "tok"
    kept = db.docs["reports/r2/evidence/content"]["subject"]
    assert kept == {"displayName": None, "headline": "Coach Her", "text": "kept", "name": "Plan A"}
    plan = db.docs["reports/r2/evidence/content"]["plan"]
    assert plan == {"coachName": None, "name": "Plan A", "body": {"note": "reported words"}}


def test_the_kept_report_no_longer_links_to_the_deleted_account():
    backend, db = _reports_backend()
    backend.pseudonymise_reports("her", "tok")
    assert db.docs["reports/r2"]["subjectRef"] == "relationships/tok__y/messages/m2"
    assert db.docs["reports/r1"]["subjectRef"] == "relationships/x__tok/messages/m1"
    assert "her" not in str(db.docs["reports/r2"]) and "her" not in str(db.docs["reports/r1"])
