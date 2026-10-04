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
            config.COL_LEDGER: {uid: {"spent_micro_usd": 3000}},
        }
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

    def delete_where_uid(self, collection, uid):
        self._step("delete_where_uid", collection)
        docs = self.collections[collection]
        for key in [k for k, v in docs.items() if v.get("uid") == uid]:
            del docs[key]

    def delete_doc(self, collection, doc_id):
        self._step("delete_doc", collection)
        self.collections[collection].pop(doc_id, None)

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
    assert [r.number for r in rows] == list(range(1, 42))
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
    dart = {
        (int(m.group(1)), m.group(2).replace("\\'", "'"), m.group(3))
        for m in re.finditer(
            r"DeletionRow\(\s*number:\s*(\d+),.*?path:\s*'((?:[^'\\]|\\.)*)',"
            r".*?method:\s*DeletionMethod\.(\w+)",
            source,
            re.S,
        )
    }
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
