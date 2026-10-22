"""The payment screenshot: sending it, the flags, and staff deciding."""

from __future__ import annotations

import copy
import datetime as dt

import pytest

from coaching import common, dhash, errors, proofs
from tests import fake_firestore
from tests.coaching_helpers import _txn  # noqa: F401
from tests.test_coaching_subscriptions import (  # noqa: F401
    CLIENT,
    COACH,
    COACH_PRICE,
    FINAL,
    NOW,
    PACKAGE,
    STAFF,
    approve,
    ask,
    awaiting,
    blobs,
    db,
    keep,
    later,
    make_jpeg,
    pushes,
    refuse,
    seed,
    send_proof,
    sub_of,
)


def proof_of(db, proof_id):
    return db.document(f"paymentProofs/{proof_id}").get().to_dict()


def reject(db, blobs, pushes, proof_id, reason="amount_wrong", now=NOW):
    return proofs.decide(
        db, STAFF, {"proofId": proof_id, "decision": "reject", "reason": reason}, now=now, blobs=blobs, notify=pushes
    )


# -- dhash -------------------------------------------------------------------


def test_dhash_is_stable_for_a_recompressed_picture_and_far_for_another():
    a, b, c = make_jpeg(1), make_jpeg(1, noise=3), make_jpeg(2)
    assert 0 <= dhash.dhash(a) < 2**64
    assert dhash.hamming(dhash.dhash(a), dhash.dhash(b)) <= 6
    assert dhash.hamming(dhash.dhash(a), dhash.dhash(c)) > 6
    assert dhash.hamming(0b1011, 0b0001) == 2
    assert dhash.from_text(dhash.to_text(2**63 + 5)) == 2**63 + 5


def test_dhash_refuses_bytes_that_are_not_a_picture():
    with pytest.raises(ValueError):
        dhash.dhash(b"not an image")


# -- submit ------------------------------------------------------------------


def test_a_proof_moves_the_subscription_to_review(db, pushes, blobs):
    sub_id = awaiting(db, pushes)
    out = send_proof(db, blobs, sub_id, reference="ab-123456")
    assert out["status"] == "payment_review"
    sub = sub_of(db, sub_id)
    assert sub["status"] == "payment_review" and sub["payment"]["proofId"] == out["proofId"]
    proof = proof_of(db, out["proofId"])
    assert proof["status"] == "pending" and proof["flags"] == []
    assert proof["expectedEgp"] == FINAL and proof["amountEgp"] == FINAL
    assert proof["subId"] == sub_id and proof["clientUid"] == CLIENT and proof["coachUid"] == COACH
    assert proof["imagePath"] == f"payment-proofs/{CLIENT}/{out['proofId']}.jpg"
    assert blobs.exists(proof["imagePath"])
    assert len(proof["sha256"]) == 64 and len(proof["dHash"]) == 16
    assert db.document("paymentRefs/instapay_AB123456").get().to_dict()["subId"] == sub_id
    assert db.document(f"users/{CLIENT}/consents/payment-proof-v1").get().to_dict()["version"] == 1


def test_the_image_is_reencoded_before_it_is_kept(db, pushes, blobs):
    sub_id = awaiting(db, pushes)
    seen = {}

    def reencode(raw, long_side=None):
        seen["long_side"] = long_side
        return make_jpeg(7)

    out = proofs.submit(
        db, CLIENT,
        {"subId": sub_id, "rail": "instapay", "reference": "REF123456", "amountEgp": FINAL,
         "paidAt": "2026-10-06", "senderName": "Client Name", "locale": "en"},
        b"original", live=True, now=NOW, blobs=blobs, reencode=reencode,
    )
    assert seen["long_side"] == common.LIMITS["proofLongSidePx"]
    assert blobs.read(proof_of(db, out["proofId"])["imagePath"]) == make_jpeg(7)


def test_a_bad_image_is_refused(db, pushes, blobs):
    sub_id = awaiting(db, pushes)

    def broken(raw, long_side=None):
        raise ValueError("nope")

    data = {"subId": sub_id, "rail": "instapay", "reference": "REF123456", "amountEgp": FINAL,
            "paidAt": "2026-10-06", "senderName": "Client Name", "locale": "en"}
    for image, reencode in [(b"x", broken), (b"", keep), (None, keep), (b"x" * 8_000_001, keep), (b"not a jpeg", keep)]:
        refuse(
            lambda: proofs.submit(db, CLIENT, data, image, live=True, now=NOW, blobs=blobs, reencode=reencode),
            errors.INVALID, errors.IMAGE_INVALID,
        )
    assert blobs.objects == {} and sub_of(db, sub_id)["status"] == "awaiting_payment"


@pytest.mark.parametrize(
    "over",
    [
        {"rail": "paypal"},
        {"rail": None},
        {"reference": "short"},
        {"reference": "has space!!"},
        {"reference": 123456},
        {"amountEgp": 0},
        {"amountEgp": 100001},
        {"amountEgp": 1150.5},
        {"amountEgp": True},
        {"paidAt": "06/10/2026"},
        {"paidAt": "2026-13-01"},
        {"paidAt": "2026-10-04"},
        {"paidAt": "2026-10-08"},
        {"senderName": "A"},
        {"senderName": "A" * 81},
        {"locale": "fr"},
        {"rail": "vodafoneCash"},
    ],
)
def test_bad_fields_are_refused(db, pushes, blobs, over):
    sub_id = awaiting(db, pushes)
    before = copy.deepcopy(db.docs)
    refuse(lambda: send_proof(db, blobs, sub_id, **over), errors.INVALID, errors.BAD_REQUEST)
    assert db.docs == before and blobs.objects == {}


def test_paid_the_day_before_acceptance_is_allowed_and_flagged_only_when_before(db, pushes, blobs):
    sub_id = awaiting(db, pushes)
    out = send_proof(db, blobs, sub_id, paidAt="2026-10-05")
    assert proof_of(db, out["proofId"])["flags"] == ["paidBeforeAccept"]


def test_a_different_amount_is_flagged(db, pushes, blobs):
    sub_id = awaiting(db, pushes)
    out = send_proof(db, blobs, sub_id, amountEgp=FINAL - 100)
    assert proof_of(db, out["proofId"])["flags"] == ["amountDiffers"]


def test_wrong_status_owner_and_deadline(db, pushes, blobs):
    sub_id = awaiting(db, pushes)
    refuse(lambda: send_proof(db, blobs, sub_id, uid="stranger"), errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    refuse(lambda: send_proof(db, blobs, "missing"), errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    refuse(lambda: send_proof(db, blobs, sub_id, now=later(hours=73)), errors.PRECONDITION, errors.PAST_PAY_BY)
    refuse(
        lambda: proofs.submit(db, CLIENT, {}, b"x", live=False, now=NOW, blobs=blobs, reencode=keep),
        errors.PRECONDITION, errors.COACH_APP_CLOSED,
    )
    send_proof(db, blobs, sub_id)
    refuse(lambda: send_proof(db, blobs, sub_id, reference="ANOTHER123"), errors.PRECONDITION, errors.WRONG_STATUS)


def test_attempts_are_capped(db, pushes, blobs):
    sub_id = awaiting(db, pushes)
    db.document(f"subscriptions/{sub_id}").update({"payment": {"state": "rejected", "attempts": 3, "lastReason": "other", "proofId": None}})
    refuse(lambda: send_proof(db, blobs, sub_id), errors.PRECONDITION, errors.ATTEMPTS_EXHAUSTED)


def test_a_reference_from_another_subscription_is_refused_and_the_image_deleted(db, pushes, blobs):
    first = awaiting(db, pushes)
    send_proof(db, blobs, first, reference="SHARED-REF-1")
    seed(db)
    other = ask(db, pushes, uid="client-2")["subId"]
    before_blobs = dict(blobs.objects)
    before = copy.deepcopy(db.docs)
    refuse(
        lambda: send_proof(db, blobs, other, uid="client-2", reference="shared-ref-1", image=make_jpeg(5)),
        errors.PRECONDITION, errors.REFERENCE_USED,
    )
    assert blobs.objects == before_blobs and db.docs == before
    assert sub_of(db, other)["status"] == "awaiting_payment"
    assert len(blobs.deleted) == 1


def test_the_same_reference_is_fine_on_the_same_subscription_after_a_rejection(db, pushes, blobs):
    sub_id = awaiting(db, pushes)
    first = send_proof(db, blobs, sub_id, reference="SAME-REF-99")
    reject(db, blobs, pushes, first["proofId"])
    second = send_proof(db, blobs, sub_id, reference="SAME-REF-99", image=make_jpeg(3))
    assert second["proofId"] != first["proofId"]
    assert db.document("paymentRefs/instapay_SAMEREF99").get().to_dict()["proofId"] == second["proofId"]


def test_the_reference_is_per_rail(db, pushes, blobs):
    first = awaiting(db, pushes)
    send_proof(db, blobs, first, reference="01012345678")
    seed(db)
    db.document("coachingConfig/receivingAccounts").update({"vodafoneCash.enabled": True})
    other = ask(db, pushes, uid="client-2")["subId"]
    send_proof(db, blobs, other, uid="client-2", rail="vodafoneCash", reference="01012345678", image=make_jpeg(5))


def test_the_same_image_on_another_subscription_is_flagged(db, pushes, blobs):
    first = awaiting(db, pushes)
    send_proof(db, blobs, first, image=make_jpeg(1))
    seed(db)
    other = ask(db, pushes, uid="client-2")["subId"]
    out = send_proof(db, blobs, other, uid="client-2", reference="OTHER-REF-1", image=make_jpeg(1))
    assert proof_of(db, out["proofId"])["flags"] == ["sameImage", "nearImage"]


def test_a_near_image_is_flagged_and_a_different_one_is_not(db, pushes, blobs):
    first = awaiting(db, pushes)
    send_proof(db, blobs, first, image=make_jpeg(1))
    seed(db)
    near = ask(db, pushes, uid="client-2")["subId"]
    out = send_proof(db, blobs, near, uid="client-2", reference="NEAR-REF-1", image=make_jpeg(1, noise=3))
    assert proof_of(db, out["proofId"])["flags"] == ["nearImage"]
    far = ask(db, pushes, uid="client-3")["subId"]
    out = send_proof(db, blobs, far, uid="client-3", reference="FAR-REF-1", image=make_jpeg(2))
    assert proof_of(db, out["proofId"])["flags"] == []


def test_the_same_clients_own_resend_is_not_flagged(db, pushes, blobs):
    sub_id = awaiting(db, pushes)
    first = send_proof(db, blobs, sub_id, image=make_jpeg(1))
    reject(db, blobs, pushes, first["proofId"])
    again = send_proof(db, blobs, sub_id, image=make_jpeg(1))
    assert proof_of(db, again["proofId"])["flags"] == []


# -- staff list --------------------------------------------------------------


def test_the_staff_queue_is_oldest_first_with_names(db, pushes, blobs):
    seed(db)
    ids = []
    for index in range(3):
        uid = f"c{index}"
        sub = ask(db, pushes, uid=uid, now=later(minutes=index))["subId"]
        ids.append(send_proof(db, blobs, sub, uid=uid, reference=f"QUEUE-REF-{index}", image=make_jpeg(10 + index), now=later(minutes=index))["proofId"])
    out = proofs.list_for_staff(db, STAFF, {}, now=NOW)
    assert [item["proofId"] for item in out["items"]] == ids and out["next"] is None
    first = out["items"][0]
    assert first["coachName"] == "Coach One" and first["packageTitle"] == "Strong in 4 weeks"
    assert first["status"] == "pending" and isinstance(first["createdAt"], str)
    assert any(row.to_dict()["action"] == "coaching.proofs.list" for row in db.collection("adminAccessLog").stream())


def test_the_staff_queue_pages_and_filters(db, pushes, blobs):
    seed(db)
    for index in range(27):
        db.document(f"paymentProofs/p{index:02d}").set(
            {"subId": "none", "coachUid": COACH, "status": "pending", "createdAt": later(minutes=index)}
        )
    db.document("paymentProofs/done").set({"subId": "none", "status": "approved", "createdAt": NOW})
    page = proofs.list_for_staff(db, STAFF, {}, now=NOW)
    assert len(page["items"]) == 25 and page["next"] == "p24"
    rest = proofs.list_for_staff(db, STAFF, {"after": page["next"]}, now=NOW)
    assert [item["proofId"] for item in rest["items"]] == ["p25", "p26"] and rest["next"] is None
    approved = proofs.list_for_staff(db, STAFF, {"status": "approved"}, now=NOW)
    assert [item["proofId"] for item in approved["items"]] == ["done"]
    refuse(lambda: proofs.list_for_staff(db, STAFF, {"status": "x"}, now=NOW), errors.INVALID, errors.BAD_REQUEST)


def test_the_staff_queue_pages_through_equal_times_without_a_gap_or_a_repeat(db):
    seed(db)
    for index in range(60):
        db.document(f"paymentProofs/p{index:02d}").set(
            {"subId": "none", "coachUid": COACH, "status": "pending", "createdAt": NOW}
        )
    seen, after = [], None
    for _ in range(3):
        page = proofs.list_for_staff(db, STAFF, {"after": after} if after else {}, now=NOW)
        seen += [item["proofId"] for item in page["items"]]
        after = page["next"]
    assert seen == [f"p{index:02d}" for index in range(60)] and after is None
    assert proofs.list_for_staff(db, STAFF, {"after": "gone"}, now=NOW) == {"items": [], "next": None}


def test_the_staff_queue_reads_one_page_and_one_more_not_the_history(db, monkeypatch):
    seed(db)
    for index in range(80):
        db.document(f"paymentProofs/p{index:02d}").set(
            {"subId": "none", "coachUid": COACH, "status": "pending", "createdAt": later(minutes=index)}
        )
    streamed = []
    real = fake_firestore.CollectionRef.stream

    def counting(self, transaction=None):
        rows = list(real(self, transaction))
        if self.path == "paymentProofs":
            streamed.append(len(rows))
        return iter(rows)

    monkeypatch.setattr(fake_firestore.CollectionRef, "stream", counting)
    proofs.list_for_staff(db, STAFF, {}, now=NOW)
    assert streamed == [proofs.PAGE + 1]


# -- decide: approve ---------------------------------------------------------


def submitted(db, pushes, blobs):
    sub_id = awaiting(db, pushes)
    out = send_proof(db, blobs, sub_id)
    return sub_id, out["proofId"]


def test_approval_starts_the_coaching(db, pushes, blobs):
    sub_id, proof_id = submitted(db, pushes, blobs)
    pushes.clear()
    at = later(hours=2)
    assert approve(db, blobs, pushes, proof_id, now=at) == {"status": "approved"}

    sub = sub_of(db, sub_id)
    assert sub["status"] == "active" and sub["startsAt"] == at and sub["endsAt"] == at + dt.timedelta(days=28)
    rel = db.document(f"relationships/{COACH}__{CLIENT}").get().to_dict()
    assert rel["status"] == "active" and rel["chatOpen"] is True and rel["activeSubId"] == sub_id
    coach = db.document(f"coaches/{COACH}").get().to_dict()
    assert coach["activeClients"] == 1 and coach["stats"]["clientsCoached"] == 1

    ledger = db.document(f"coachPrivate/{COACH}/ledger/{sub_id}").get().to_dict()
    assert ledger["coachAmountEgp"] == COACH_PRICE and ledger["status"] == "pending"
    assert ledger["eligibleAt"] == at + dt.timedelta(days=14)
    assert ledger["clientLabel"] == f"#{sub_id[-4:]}" and ledger["packageTitle"] == "Strong in 4 weeks"

    proof = proof_of(db, proof_id)
    assert proof["status"] == "approved" and proof["imagePath"] is None and proof["decidedAt"] == at
    assert proof["decidedBy"] and proof["decidedBy"] != STAFF
    assert blobs.objects == {} and len(blobs.deleted) == 1

    messages = [m.to_dict() for m in db.collection(f"relationships/{COACH}__{CLIENT}/messages").stream()]
    assert [(m["senderUid"], m["type"], m["systemKind"]) for m in messages] == [("system", "system", "started")]
    assert sorted(pushes) == sorted([(CLIENT, "paymentApproved"), (COACH, "coachingStarted")])


def test_the_receipt_is_issued_with_a_number_and_vat(db, pushes, blobs):
    sub_id, proof_id = submitted(db, pushes, blobs)
    approve(db, blobs, pushes, proof_id)
    receipt = db.document(f"receipts/{sub_id}").get().to_dict()
    assert receipt["number"] == "OH-2026-000001" and receipt["clientUid"] == CLIENT
    assert receipt["priceFinalEgp"] == FINAL and receipt["vatRatePercent"] == 14
    assert receipt["vatEgp"] == FINAL * 14 // 114
    assert receipt["seller"]["companyNameEn"] == "Own Hub LLC" and "updatedAt" not in receipt["seller"]
    assert receipt["coachName"] == "Coach One" and receipt["line"]["title"] == "Strong in 4 weeks"
    assert "coachPriceEgp" not in str(receipt) and COACH_PRICE not in receipt.values()


def test_approval_needs_the_seller_and_changes_nothing_without_it(db, pushes, blobs):
    sub_id, proof_id = submitted(db, pushes, blobs)
    db.document("coachingConfig/seller").delete()
    before = {k: copy.deepcopy(v) for k, v in db.docs.items()}
    refuse(lambda: approve(db, blobs, pushes, proof_id), errors.PRECONDITION, errors.SELLER_NOT_SET)
    assert {k: v for k, v in db.docs.items() if not k.startswith("adminAccessLog/")} == before
    assert len(blobs.objects) == 1


def test_a_returning_client_is_not_counted_twice(db, pushes, blobs):
    db.document(f"relationships/{COACH}__{CLIENT}").set(
        {"coachUid": COACH, "clientUid": CLIENT, "status": "ended", "chatOpen": False}
    )
    sub_id, proof_id = submitted(db, pushes, blobs)
    approve(db, blobs, pushes, proof_id)
    coach = db.document(f"coaches/{COACH}").get().to_dict()
    assert coach["activeClients"] == 1 and coach["stats"]["clientsCoached"] == 0


def test_a_decided_proof_cannot_be_decided_again(db, pushes, blobs):
    sub_id, proof_id = submitted(db, pushes, blobs)
    approve(db, blobs, pushes, proof_id)
    refuse(lambda: approve(db, blobs, pushes, proof_id), errors.PRECONDITION, errors.WRONG_STATUS)
    refuse(lambda: reject(db, blobs, pushes, proof_id), errors.PRECONDITION, errors.WRONG_STATUS)
    refuse(lambda: approve(db, blobs, pushes, "missing"), errors.NOT_FOUND, errors.PROOF_NOT_FOUND)


def test_decide_checks_its_input(db, pushes, blobs):
    sub_id, proof_id = submitted(db, pushes, blobs)
    for data in [
        {"proofId": proof_id, "decision": "maybe"},
        {"proofId": proof_id, "decision": "reject"},
        {"proofId": proof_id, "decision": "reject", "reason": "because"},
        {"decision": "approve"},
    ]:
        refuse(lambda: proofs.decide(db, STAFF, data, now=NOW, blobs=blobs, notify=pushes), errors.INVALID, errors.BAD_REQUEST)
    assert proof_of(db, proof_id)["status"] == "pending" and len(blobs.objects) == 1


# -- decide: reject ----------------------------------------------------------


def test_a_rejection_gives_her_another_go(db, pushes, blobs):
    sub_id, proof_id = submitted(db, pushes, blobs)
    pushes.clear()
    at = later(days=1)
    assert reject(db, blobs, pushes, proof_id, reason="unreadable", now=at) == {"status": "rejected"}
    sub = sub_of(db, sub_id)
    assert sub["status"] == "awaiting_payment" and sub["payBy"] == at + dt.timedelta(hours=72)
    assert sub["payment"]["attempts"] == 1 and sub["payment"]["lastReason"] == "unreadable"
    proof = proof_of(db, proof_id)
    assert proof["status"] == "rejected" and proof["reason"] == "unreadable" and proof["imagePath"] is None
    assert blobs.objects == {} and pushes == [(CLIENT, "paymentRejected")]
    assert db.document(f"receipts/{sub_id}").get().exists is False
    assert db.document(f"relationships/{COACH}__{CLIENT}").get().to_dict()["chatOpen"] is False


def test_three_rejections_fail_the_payment(db, pushes, blobs):
    sub_id = awaiting(db, pushes)
    for attempt in range(3):
        out = send_proof(db, blobs, sub_id, reference=f"TRY-REF-{attempt}", image=make_jpeg(20 + attempt))
        reject(db, blobs, pushes, out["proofId"])
        expected = "awaiting_payment" if attempt < 2 else "payment_failed"
        assert sub_of(db, sub_id)["status"] == expected
    assert sub_of(db, sub_id)["payment"]["attempts"] == 3
    assert blobs.objects == {}
    refuse(lambda: send_proof(db, blobs, sub_id), errors.PRECONDITION, errors.WRONG_STATUS)


def test_nothing_the_client_may_read_holds_the_reference_or_the_proof(db, pushes, blobs):
    sub_id, proof_id = submitted(db, pushes, blobs)
    approve(db, blobs, pushes, proof_id)
    for path in (f"subscriptions/{sub_id}", f"receipts/{sub_id}", f"relationships/{COACH}__{CLIENT}"):
        text = str(db.document(path).get().to_dict())
        assert "REF123456" not in text and "payment-proofs/" not in text


def test_reencode_takes_a_long_side_and_keeps_its_default():
    import cv2
    import numpy as np

    from nutrition import config, photo

    ok, raw = cv2.imencode(".jpg", np.full((300, 400, 3), 120, dtype=np.uint8))
    assert ok

    def long_edge(data):
        return max(cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR).shape[:2])

    assert long_edge(photo.reencode(raw.tobytes(), long_side=200)) == 200
    assert long_edge(photo.reencode(raw.tobytes())) == min(400, config.IMAGE_LONG_SIDE)


# -- staff never decide their own payment, and the screenshot always goes -------


from coaching import subscriptions  # noqa: E402
from tests.fake_blobs import FakeBlobs  # noqa: E402


class FailingDelete(FakeBlobs):
    def delete(self, path):
        raise RuntimeError("storage unavailable")


@pytest.mark.parametrize("actor", [CLIENT, COACH])
@pytest.mark.parametrize("decision", ["approve", "reject"])
def test_staff_never_decide_a_proof_for_their_own_subscription(db, pushes, blobs, actor, decision):
    sub_id = awaiting(db, pushes)
    proof = send_proof(db, blobs, sub_id)
    before, files = copy.deepcopy(db.docs), dict(blobs.objects)
    data = {"proofId": proof["proofId"], "decision": decision, "reason": "unreadable"}
    refuse(
        lambda: proofs.decide(db, actor, data, now=NOW, blobs=blobs, notify=pushes),
        errors.PERMISSION, errors.STAFF_IS_SUBJECT,
    )
    stored_before = {k: v for k, v in before.items() if not k.startswith("adminAccessLog")}
    stored_after = {k: v for k, v in db.docs.items() if not k.startswith("adminAccessLog")}
    assert stored_after == stored_before and blobs.objects == files
    assert sub_of(db, sub_id)["status"] == "payment_review"


def test_a_failed_delete_leaves_the_pointer_and_a_pending_flag(db, pushes):
    blobs = FailingDelete()
    sub_id = awaiting(db, pushes)
    proof = send_proof(db, blobs, sub_id)
    path = proof_of(db, proof["proofId"])["imagePath"]
    out = approve(db, blobs, pushes, proof["proofId"])
    assert out == {"status": "approved"}
    row = proof_of(db, proof["proofId"])
    assert row["status"] == "approved" and row["imagePath"] == path and row["imageDeletePending"] is True
    assert blobs.exists(path)
    assert (CLIENT, "paymentApproved") in pushes


def test_a_clean_delete_clears_the_pointer_and_the_flag(db, pushes, blobs):
    sub_id = awaiting(db, pushes)
    proof = send_proof(db, blobs, sub_id)
    approve(db, blobs, pushes, proof["proofId"])
    row = proof_of(db, proof["proofId"])
    assert row["imagePath"] is None and row["imageDeletePending"] is False and blobs.objects == {}


def test_the_sweeper_retries_the_delete_and_counts_what_it_cannot_remove(db, pushes):
    broken = FailingDelete()
    sub_id = awaiting(db, pushes)
    proof = send_proof(db, broken, sub_id)
    approve(db, broken, pushes, proof["proofId"])
    path = proof_of(db, proof["proofId"])["imagePath"]
    assert subscriptions.sweep(db, now=later(days=1), notify=pushes, blobs=broken, payments=True)["staleProofImages"] == 1
    assert subscriptions.sweep(db, now=later(days=1), notify=pushes, payments=True)["staleProofImages"] == 1
    fixed = FakeBlobs({path: (b"x", "image/jpeg")})
    assert subscriptions.sweep(db, now=later(days=2), notify=pushes, blobs=fixed, payments=True)["staleProofImages"] == 0
    row = proof_of(db, proof["proofId"])
    assert row["imagePath"] is None and row["imageDeletePending"] is False and fixed.objects == {}
    assert subscriptions.sweep(db, now=later(days=3), notify=pushes, blobs=fixed, payments=True)["staleProofImages"] == 0


# -- a reference from a payment that came to nothing -------------------------------


@pytest.mark.parametrize("dead", ["payment_failed", "expired", "cancelled"])
def test_her_own_reference_from_a_dead_subscription_can_be_used_again(db, pushes, blobs, dead):
    first = awaiting(db, pushes)
    send_proof(db, blobs, first, reference="DEAD-REF-1")
    db.document(f"subscriptions/{first}").update({"status": dead})
    second = ask(db, pushes)["subId"]
    out = send_proof(db, blobs, second, reference="dead-ref-1", image=make_jpeg(6))
    assert db.document("paymentRefs/instapay_DEADREF1").get().to_dict() == {
        "subId": second, "proofId": out["proofId"], "createdAt": NOW}
    # Allowed, and staff see it was sent before.
    assert "duplicateReference" in proof_of(db, out["proofId"])["flags"]


def test_a_payment_for_a_coach_suspended_since_cannot_be_approved(db, pushes, blobs):
    sub_id = awaiting(db, pushes)
    proof = send_proof(db, blobs, sub_id)
    db.document(f"coachPrivate/{COACH}").set({"suspended": True}, merge=True)
    with pytest.raises(errors.CoachingError) as caught:
        proofs.decide(db, STAFF, {"proofId": proof["proofId"], "decision": "approve"},
                      now=NOW, blobs=blobs, notify=pushes)
    assert caught.value.reason == errors.COACH_SUSPENDED
    assert db.document(f"subscriptions/{sub_id}").get().to_dict()["status"] == "payment_review"
    # Staff can still reject it, so she is not left waiting.
    out = proofs.decide(db, STAFF, {"proofId": proof["proofId"], "decision": "reject", "reason": "other"},
                        now=NOW, blobs=blobs, notify=pushes)
    assert out == {"status": "rejected"}


@pytest.mark.parametrize("status", ["ended", "ended_early"])
def test_her_own_reference_stays_taken_while_her_subscription_is_not_dead(db, pushes, blobs, status):
    first = awaiting(db, pushes)
    send_proof(db, blobs, first, reference="LIVE-REF-1")
    db.document(f"subscriptions/{first}").update({"status": status})
    second = ask(db, pushes)["subId"]
    refuse(lambda: send_proof(db, blobs, second, reference="LIVE-REF-1", image=make_jpeg(6)),
           errors.PRECONDITION, errors.REFERENCE_USED)
    assert sub_of(db, second)["status"] == "awaiting_payment"


def test_a_reference_whose_subscription_is_gone_is_not_free_for_anyone(db, pushes, blobs):
    first = awaiting(db, pushes)
    send_proof(db, blobs, first, reference="GONE-REF-1")
    db.docs.pop(f"subscriptions/{first}")
    seed(db)
    other = ask(db, pushes, uid="client-2")["subId"]
    refuse(lambda: send_proof(db, blobs, other, uid="client-2", reference="GONE-REF-1", image=make_jpeg(6)),
           errors.PRECONDITION, errors.REFERENCE_USED)


def test_another_client_cannot_take_a_dead_subscriptions_reference(db, pushes, blobs):
    first = awaiting(db, pushes)
    send_proof(db, blobs, first, reference="DEAD-REF-2")
    db.document(f"subscriptions/{first}").update({"status": "payment_failed"})
    seed(db)
    other = ask(db, pushes, uid="client-2")["subId"]
    refuse(lambda: send_proof(db, blobs, other, uid="client-2", reference="DEAD-REF-2", image=make_jpeg(6)),
           errors.PRECONDITION, errors.REFERENCE_USED)
