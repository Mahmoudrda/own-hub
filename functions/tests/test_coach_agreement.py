"""Coach Agreement v2: acceptance, the signed copy, staff decision and the gate."""

from __future__ import annotations

import subprocess
import sys

import pytest

from coaching import agreement, errors
from tests.coaching_helpers import Notes, _txn, refusal  # noqa: F401
from tests.test_coaching_subscriptions import (  # noqa: F401
    CLIENT, COACH, NOW, STAFF, answer, ask, db, later, pushes, seed, sub_of,
)

PATH = f"coach-docs/{COACH}/agreement/signed-1.pdf"


def private(db):
    return db.document(f"coachPrivate/{COACH}").get().to_dict()


def agreed(db, **agreement_fields):
    db.document(f"coachPrivate/{COACH}").set({"suspended": False, "agreement": agreement_fields} if agreement_fields else {"suspended": False}, merge=True)


def accept(db, **over):
    data = {"version": 2, "locale": "en", **over}
    return agreement.accept(db, COACH, data, live=True, coach_v="active", now=NOW)


def submit(db, path=PATH, exists=True, coach_v="active"):
    return agreement.submit(db, COACH, {"mediaRef": path}, live=True, coach_v=coach_v, object_exists=lambda p: exists, now=later(hours=1))


def decide(db, notes, **over):
    data = {"uid": COACH, "decision": "verify", **over}
    return agreement.decide(db, STAFF, data, notify=notes, now=later(hours=2))


def test_the_published_text_hashes_match_the_site_source():
    out = subprocess.run([sys.executable, "tools/agreement_hash.py", "--check"], capture_output=True, text=True)
    assert out.returncode == 0, out.stdout + out.stderr


def test_accepting_stores_the_version_and_the_hash_of_her_language(db):
    agreed(db)
    assert accept(db, locale="ar") == {"status": "accepted"}
    assert db.document(f"users/{COACH}/consents/coach-terms-v2").get().to_dict() == {
        "version": 2, "at": NOW, "locale": "ar", "textHash": agreement.HASHES["ar"],
    }
    assert private(db)["agreement"] == {"version": 2, "acceptedAt": NOW, "status": "accepted"}
    assert agreement.HASHES["ar"] != agreement.HASHES["en"]


def test_accepting_twice_changes_nothing(db):
    agreed(db)
    accept(db)
    submit(db)
    assert accept(db, locale="ar") == {"status": "uploaded"}
    assert db.document(f"users/{COACH}/consents/coach-terms-v2").get().to_dict()["locale"] == "en"


@pytest.mark.parametrize("over", [{"version": 1}, {"version": True}, {"version": "2"}])
def test_only_version_two_can_be_accepted(db, over):
    agreed(db)
    assert refusal(lambda: accept(db, **over)) == (errors.INVALID, errors.BAD_REQUEST)


def test_a_member_without_the_coach_claim_cannot_accept(db):
    agreed(db)
    assert refusal(lambda: agreement.accept(db, COACH, {"version": 2}, live=True, coach_v=None, now=NOW))[1] == errors.NOT_A_COACH


def test_the_signed_copy_needs_the_acceptance_first(db):
    agreed(db)
    assert refusal(lambda: submit(db)) == (errors.PRECONDITION, errors.WRONG_STATUS)


@pytest.mark.parametrize(
    "path",
    [f"coach-docs/other/agreement/a.pdf", f"coach-docs/{COACH}/photo/a.pdf", f"coach-docs/{COACH}/agreement/a.exe",
     f"coach-docs/{COACH}/agreement/sub/a.pdf", None, 5],
)
def test_the_signed_copy_must_be_a_file_in_her_own_agreement_folder(db, path):
    agreed(db)
    accept(db)
    assert refusal(lambda: submit(db, path)) == (errors.INVALID, errors.BAD_REQUEST)


def test_a_copy_that_never_reached_the_bucket_is_refused(db):
    agreed(db)
    accept(db)
    assert refusal(lambda: submit(db, exists=False)) == (errors.PRECONDITION, errors.AGREEMENT_NOT_UPLOADED)
    assert private(db)["agreement"]["status"] == "accepted"


def test_staff_verify_and_she_is_told(db):
    agreed(db)
    accept(db)
    assert submit(db) == {"status": "uploaded"}
    notes = Notes()
    assert decide(db, notes) == {"status": "verified"}
    row = private(db)["agreement"]
    assert row["status"] == "verified" and row["path"] == PATH and row["decidedAt"] == later(hours=2) and row["decidedBy"]
    assert notes.sent == [(COACH, "agreementDecision")]
    assert agreement.ready(private(db))
    assert len(list(db.collection("adminAccessLog").stream())) == 1
    assert refusal(lambda: submit(db)) == (errors.PRECONDITION, errors.WRONG_STATUS)


def test_a_rejection_needs_a_reason_and_lets_her_upload_again(db):
    agreed(db)
    accept(db)
    submit(db)
    notes = Notes()
    assert refusal(lambda: decide(db, notes, decision="reject")) == (errors.INVALID, errors.BAD_REQUEST)
    assert decide(db, notes, decision="reject", reason="The signature is cut off.") == {"status": "rejected"}
    row = private(db)["agreement"]
    assert row["status"] == "rejected" and row["reason"] == "The signature is cut off."
    assert not agreement.ready(private(db))
    submit(db, f"coach-docs/{COACH}/agreement/signed-2.pdf")
    row = private(db)["agreement"]
    assert row["status"] == "uploaded" and "reason" not in row and row["path"].endswith("signed-2.pdf")


def test_only_an_uploaded_copy_can_be_decided_and_not_by_the_subject(db):
    agreed(db)
    accept(db)
    notes = Notes()
    assert refusal(lambda: decide(db, notes)) == (errors.PRECONDITION, errors.WRONG_STATUS)
    submit(db)
    assert refusal(lambda: agreement.decide(db, COACH, {"uid": COACH, "decision": "verify"}, notify=notes, now=NOW))[1] == errors.STAFF_IS_SUBJECT
    assert refusal(lambda: decide(db, notes, decision="maybe")) == (errors.INVALID, errors.BAD_REQUEST)
    assert notes.sent == []


def test_staff_list_only_the_copies_waiting_for_them(db):
    agreed(db, version=2, status="uploaded", path=PATH, uploadedAt=NOW, acceptedAt=NOW)
    db.document(f"coachPrivate/{COACH}").update({"fullName": "Mona Hassan"})
    db.document("coachPrivate/other").set({"fullName": "Other", "agreement": {"version": 2, "status": "verified"}})
    assert agreement.list_waiting(db) == {
        "items": [{"uid": COACH, "fullName": "Mona Hassan", "path": PATH, "uploadedAt": NOW, "acceptedAt": NOW}]
    }


# ------------------------------------------------------------------- the gate


def test_a_coach_with_version_one_only_cannot_accept_a_request(db, pushes):
    seed(db, auto=False)
    db.document(f"coachPrivate/{COACH}").update({"agreement": None})
    sub_id = ask(db, pushes)["subId"]
    assert refusal(lambda: answer(db, pushes, sub_id)) == (errors.PRECONDITION, errors.AGREEMENT_NEEDED)
    assert sub_of(db, sub_id)["status"] == "requested"


@pytest.mark.parametrize("status", ["accepted", "uploaded", "rejected"])
def test_every_step_short_of_verified_still_refuses(db, pushes, status):
    seed(db, auto=False)
    db.document(f"coachPrivate/{COACH}").update({"agreement": {"version": 2, "status": status}})
    sub_id = ask(db, pushes)["subId"]
    assert refusal(lambda: answer(db, pushes, sub_id))[1] == errors.AGREEMENT_NEEDED


def test_declining_is_never_gated(db, pushes):
    seed(db, auto=False)
    db.document(f"coachPrivate/{COACH}").update({"agreement": None})
    sub_id = ask(db, pushes)["subId"]
    assert answer(db, pushes, sub_id, decision="decline", reason="not_a_fit") == {"status": "declined"}


def test_a_verified_coach_accepts_after_the_whole_path(db, pushes):
    seed(db, auto=False)
    db.document(f"coachPrivate/{COACH}").update({"agreement": None})
    sub_id = ask(db, pushes)["subId"]
    accept(db)
    submit(db)
    decide(db, Notes())
    assert answer(db, pushes, sub_id, now=later(hours=5)) == {"status": "awaiting_payment"}


def test_auto_accept_waits_for_the_coach_until_the_copy_is_verified(db, pushes):
    seed(db, auto=True)
    db.document(f"coachPrivate/{COACH}").update({"agreement": None})
    assert ask(db, pushes)["status"] == "requested"


def test_a_replaced_copy_is_deleted_and_a_verified_one_is_the_only_file_left(db):
    from tests.fake_blobs import FakeBlobs

    folder = f"coach-docs/{COACH}/agreement/"
    blobs = FakeBlobs({folder + "signed-1.pdf": (b"1", "application/pdf"), "coach-docs/other/agreement/x.pdf": (b"x", "")})
    agreed(db)
    accept(db)
    agreement.submit(db, COACH, {"mediaRef": folder + "signed-1.pdf"}, live=True, coach_v="active",
                     object_exists=blobs.exists, now=later(hours=1), blobs=blobs)
    decide(db, Notes(), decision="reject", reason="Blurry.")
    assert folder + "signed-1.pdf" in blobs.objects, "a rejected copy stays until she sends another"
    blobs.put(folder + "signed-2.pdf")
    blobs.put(folder + "never-sent.jpg")
    agreement.submit(db, COACH, {"mediaRef": folder + "signed-2.pdf"}, live=True, coach_v="active",
                     object_exists=blobs.exists, now=later(hours=3), blobs=blobs)
    assert sorted(n for n in blobs.objects if n.startswith(folder)) == [folder + "signed-2.pdf"]
    agreement.decide(db, STAFF, {"uid": COACH, "decision": "verify"}, notify=Notes(), now=later(hours=4), blobs=blobs)
    assert sorted(n for n in blobs.objects if n.startswith(folder)) == [folder + "signed-2.pdf"]
    assert "coach-docs/other/agreement/x.pdf" in blobs.objects, "nobody else's file is touched"


def test_the_waiting_list_is_oldest_first_across_all_of_it(db):
    for uid, hour in (("c-late", 9), ("c-early", 1), ("c-mid", 5)):
        db.document(f"coachPrivate/{uid}").set(
            {"fullName": uid, "agreement": {"version": 2, "status": "uploaded", "path": "p", "uploadedAt": later(hours=hour)}}
        )
    assert [r["uid"] for r in agreement.list_waiting(db)["items"]] == ["c-early", "c-mid", "c-late"]


def test_a_renewal_from_a_client_she_already_coached_is_accepted_without_the_agreement(db, pushes):
    seed(db, auto=False)
    db.document(f"coachPrivate/{COACH}").update({"agreement": None})
    db.document(f"relationships/{COACH}__{CLIENT}").set(
        {"coachUid": COACH, "clientUid": CLIENT, "status": "ended", "chatOpen": False, "source": "app"})
    sub_id = ask(db, pushes)["subId"]
    assert answer(db, pushes, sub_id)["status"] == "awaiting_payment"


def test_a_renewal_is_auto_accepted_but_a_brand_new_pair_still_waits(db, pushes):
    seed(db, auto=True)
    db.document(f"coachPrivate/{COACH}").update({"agreement": None})
    assert sub_of(db, ask(db, pushes, uid="brand-new-client")["subId"])["status"] == "requested"
    db.document(f"relationships/{COACH}__{CLIENT}").set(
        {"coachUid": COACH, "clientUid": CLIENT, "status": "ended", "chatOpen": False, "source": "app"})
    assert sub_of(db, ask(db, pushes)["subId"])["status"] == "awaiting_payment"
