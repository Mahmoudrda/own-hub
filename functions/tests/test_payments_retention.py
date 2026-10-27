"""Payment pictures: the retention period, and uploads nothing refers to (spec 4.15, WO-10a3)."""

from __future__ import annotations

import datetime as dt

from payments import retention
from tests.fake_blobs import FakeBlobs
from tests.payments_helpers import NOW, PAY, _txn, db, later, make_payment, payment_of  # noqa: F401

SHOT = f"payment-proofs/{PAY}/client-abc-1.jpg"


def test_old_finished_payment_loses_its_pictures_and_keeps_the_record(db):
    make_payment(db, status="confirmed", statusAt=later(days=-100),
                 proof={"screenshotPaths": [SHOT], "txnNumber": "T1"}, coachDecision={"statementPaths": [f"payment-proofs/{PAY}/coach-x-1.jpg"]})
    blobs = FakeBlobs({SHOT: (b"x", "image/jpeg"), f"payment-proofs/{PAY}/coach-x-1.jpg": (b"y", "image/jpeg")})
    assert retention.sweep_screenshots(db, now=NOW, blobs=blobs) == 1
    assert set(blobs.deleted) == {SHOT, f"payment-proofs/{PAY}/coach-x-1.jpg"}
    row = payment_of(db)
    assert row["proof"]["screenshotPaths"] == [] and row["proof"]["txnNumber"] == "T1" and row["proof"]["screenshotsDeletedAt"] == NOW
    assert row["coachDecision"]["statementPaths"] == []


def test_a_recent_payment_and_one_under_review_keep_their_pictures(db):
    make_payment(db, "p-new", status="confirmed", statusAt=later(days=-10), proof={"screenshotPaths": ["a.jpg"]})
    make_payment(db, "p-rev", status="in_review", statusAt=later(days=-200), proof={"screenshotPaths": ["b.jpg"]})
    make_payment(db, "p-dis", status="service_dispute", statusAt=later(days=-200), proof={"screenshotPaths": ["c.jpg"]})
    blobs = FakeBlobs()
    assert retention.sweep_screenshots(db, now=NOW, blobs=blobs) == 0 and blobs.deleted == []


def test_a_failed_delete_leaves_the_pointer_for_the_next_run(db):
    make_payment(db, status="refunded", statusAt=later(days=-100), proof={"screenshotPaths": ["a.jpg"]})

    class Broken(FakeBlobs):
        def delete(self, path):
            raise RuntimeError("down")

    assert retention.sweep_screenshots(db, now=NOW, blobs=Broken()) == 0
    assert payment_of(db)["proof"]["screenshotPaths"] == ["a.jpg"]


def test_the_period_is_one_named_number():
    assert retention.SCREENSHOT_RETENTION_DAYS == 90 and retention.RECORD_RETENTION_YEARS == 5


# ------------------------------------------------ uploads nothing refers to

OLD = NOW - dt.timedelta(hours=30)
YOUNG = NOW - dt.timedelta(hours=2)
CHAT_USED = "chat-media/c__k/k/used.jpg"
CHAT_LOST = "chat-media/c__k/k/lost.jpg"


def seed_uploads(db):
    db.document("relationships/c__k/messages/m1").set({"senderUid": "k", "mediaPath": CHAT_USED, "type": "image"})
    make_payment(db, proof={"screenshotPaths": [SHOT]}, coachDecision={"statementPaths": [f"payment-proofs/{PAY}/coach-x-1.jpg"]})
    db.document("paymentProofs/older").set({"imagePath": "payment-proofs/some-uid/p1.jpg"})
    blobs = FakeBlobs()
    for name in (CHAT_USED, CHAT_LOST, SHOT, f"payment-proofs/{PAY}/coach-x-1.jpg", f"payment-proofs/{PAY}/client-lost-1.jpg",
                 "payment-proofs/some-uid/p1.jpg", "payment-proofs/some-uid/p2.jpg", "payment-proofs/gone-payment/client-a-1.jpg"):
        blobs.put(name, created=OLD)
    return blobs


def test_an_upload_no_message_or_payment_names_goes_after_a_day(db):
    blobs = seed_uploads(db)
    assert retention.sweep_orphan_uploads(db, now=NOW, blobs=blobs) == {"chat": 1, "payment": 3}
    assert set(blobs.deleted) == {CHAT_LOST, f"payment-proofs/{PAY}/client-lost-1.jpg", "payment-proofs/some-uid/p2.jpg",
                                  "payment-proofs/gone-payment/client-a-1.jpg"}
    assert CHAT_USED in blobs.objects and SHOT in blobs.objects and "payment-proofs/some-uid/p1.jpg" in blobs.objects


def test_a_young_upload_may_still_be_on_its_way_and_a_very_old_one_was_seen_by_an_earlier_run(db):
    blobs = FakeBlobs()
    blobs.put(CHAT_LOST, created=YOUNG)
    blobs.put("chat-media/c__k/k/ancient.jpg", created=NOW - dt.timedelta(days=30))
    blobs.put("chat-media/c__k/k/unknown-age.jpg", created=None)
    assert retention.sweep_orphan_uploads(db, now=NOW, blobs=blobs) == {"chat": 0, "payment": 0} and blobs.deleted == []


def test_a_path_in_a_shape_the_app_never_writes_is_left_alone(db):
    blobs = FakeBlobs()
    blobs.put("chat-media/c__k/loose.jpg", created=OLD)
    blobs.put("payment-proofs/loose.jpg", created=OLD)
    blobs.put("other/stuff.jpg", created=OLD)
    assert retention.sweep_orphan_uploads(db, now=NOW, blobs=blobs) == {"chat": 0, "payment": 0}


def test_a_failed_delete_is_skipped_and_the_next_run_tries_again(db):
    blobs = seed_uploads(db)

    class Broken(FakeBlobs):
        def delete(self, path):
            raise RuntimeError("down")

    broken = Broken(blobs.objects)
    broken.created = blobs.created
    assert retention.sweep_orphan_uploads(db, now=NOW, blobs=broken) == {"chat": 0, "payment": 0}
    assert retention.sweep_orphan_uploads(db, now=NOW, blobs=blobs)["chat"] == 1


def test_a_reported_message_keeps_its_file_because_the_message_still_names_it(db):
    db.document("relationships/c__k/messages/m1").set({"senderUid": "k", "mediaPath": CHAT_USED, "type": "image", "hidden": False})
    db.document("coachingReports/r1").set({"kind": "coachMessage", "ids": ["c__k", "m1"]})
    blobs = FakeBlobs()
    blobs.put(CHAT_USED, created=OLD)
    assert retention.sweep_orphan_uploads(db, now=NOW, blobs=blobs) == {"chat": 0, "payment": 0} and blobs.deleted == []


def test_a_payment_the_coach_never_decided_loses_its_pictures_without_touching_a_null_decision(db):
    make_payment(db, status="resolved_unpaid", statusAt=later(days=-100), coachDecision=None,
                 proof={"screenshotPaths": [SHOT], "txnNumber": "T2"})
    blobs = FakeBlobs({SHOT: (b"x", "image/jpeg")})
    assert retention.sweep_screenshots(db, now=NOW, blobs=blobs) == 1
    row = payment_of(db)
    assert row["coachDecision"] is None and row["proof"]["screenshotPaths"] == [] and row["proof"]["txnNumber"] == "T2"
