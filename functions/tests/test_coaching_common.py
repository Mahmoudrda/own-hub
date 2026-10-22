"""The helpers every coaching module shares."""

from __future__ import annotations

import datetime as dt

import pytest

from coaching import common, errors
from tests import fake_firestore
from tests.coaching_helpers import _txn, refusal  # noqa: F401

NOW = dt.datetime(2026, 11, 1, 12, tzinfo=dt.timezone.utc)


def test_session_and_refund_maths():
    assert common.sessions_included(4, 28) == 4
    assert common.sessions_included(4, 84) == 12
    assert common.refund_amount(1150, 1, 4) == 863
    assert common.refund_amount(1150, 4, 4) == 0
    assert common.refund_amount(1150, 9, 4) == 0
    assert common.coach_share_after_refund(1000, 1, 4) == 250
    assert common.monthly_equivalent(3450, 84) == 1150


@pytest.mark.parametrize(
    "coach,price,refund,share",
    [(1000, 1150, 0, 1000), (1000, 1150, 1150, 0), (1000, 1150, 575, 500), (1000, 1150, 100, 913)],
)
def test_the_coach_keeps_her_price_in_proportion_to_what_is_kept(coach, price, refund, share):
    assert common.coach_share_of_kept(coach, price, refund) == share


def test_whole_of_takes_only_whole_numbers_from_the_list():
    assert common.whole_of(28, (28, 56)) == 28
    for value in (True, 28.0, "28", 30, None):
        assert refusal(lambda v=value: common.whole_of(v, (28, 56))) == (errors.INVALID, errors.BAD_REQUEST)
    assert refusal(lambda: common.whole_of(1, (2,), errors.PRICE_OUT_OF_RANGE)) == (
        errors.INVALID,
        errors.PRICE_OUT_OF_RANGE,
    )


def test_a_price_outside_the_limits_says_so():
    low = common.LIMITS["coachPriceMinEgp"] - 1
    code = refusal(lambda: common.whole(low, low=low + 1, high=low + 5, reason=errors.PRICE_OUT_OF_RANGE))
    assert code == (errors.INVALID, errors.PRICE_OUT_OF_RANGE)


def test_a_day_is_a_calendar_date_and_nothing_else():
    assert common.parse_day("2026-11-01") == dt.date(2026, 11, 1)
    for value in ("2026-13-01", "2026-1-1", "2026-11-01T00:00", 20261101, None):
        assert refusal(lambda v=value: common.parse_day(v)) == (errors.INVALID, errors.BAD_REQUEST)


def test_the_cairo_day_turns_over_at_cairo_midnight():
    late = dt.datetime(2026, 11, 1, 22, 30, tzinfo=dt.timezone.utc)
    assert common.cairo_day(late) == dt.date(2026, 11, 2)


def test_run_goes_through_the_transaction_wrapper_and_returns_the_answer():
    db = fake_firestore.FakeFirestore()

    def body(transaction):
        transaction.set(db.document("a/b"), {"x": 1})
        return "done"

    assert common.run(db, body) == "done"
    assert db.docs["a/b"] == {"x": 1}


def test_read_gives_a_dict_or_none():
    db = fake_firestore.FakeFirestore()
    db.docs["a/b"] = {}
    assert common.read(db.document("a/b"), None) == {}
    assert common.read(db.document("a/missing"), None) is None


def test_a_consent_is_written_once():
    db = fake_firestore.FakeFirestore()
    ref = common.consent_ref(db, "u1", "payment-proof-v1")
    assert ref.path == "users/u1/consents/payment-proof-v1"

    def body(transaction):
        common.record_consent(transaction, ref, ref.get(transaction=transaction), "ar", NOW)

    common.run(db, body)
    later = NOW + dt.timedelta(days=1)

    def again(transaction):
        common.record_consent(transaction, ref, ref.get(transaction=transaction), "en", later)

    common.run(db, again)
    assert db.docs[ref.path] == {"version": 1, "at": NOW, "locale": "ar"}


def test_a_decision_is_stamped_with_a_short_reference_not_the_uid():
    stamp = common.decided_stamp("staff-uid-123", NOW)
    assert stamp["decidedAt"] == NOW and "staff-uid-123" not in stamp["decidedBy"]
    assert common.staff_ref("staff-uid-123") == stamp["decidedBy"]


class _Blobs:
    def __init__(self, fail=False):
        self.deleted, self.fail = [], fail

    def delete(self, path):
        if self.fail:
            raise RuntimeError("storage down")
        self.deleted.append(path)


def test_a_decided_screenshot_is_deleted_and_the_pointer_cleared():
    db = fake_firestore.FakeFirestore()
    ref = db.document("paymentProofs/p1")
    ref.set({"imagePath": "payment-proofs/u/p1.jpg", "imageDeletePending": True})
    blobs = _Blobs()
    assert common.drop_proof_image(ref, "payment-proofs/u/p1.jpg", blobs) is True
    assert blobs.deleted == ["payment-proofs/u/p1.jpg"]
    assert db.docs["paymentProofs/p1"] == {"imagePath": None, "imageDeletePending": False}


def test_a_screenshot_that_cannot_be_deleted_keeps_its_flag():
    db = fake_firestore.FakeFirestore()
    ref = db.document("paymentProofs/p1")
    ref.set({"imagePath": "payment-proofs/u/p1.jpg", "imageDeletePending": True})
    assert common.drop_proof_image(ref, "payment-proofs/u/p1.jpg", _Blobs(fail=True)) is False
    assert db.docs["paymentProofs/p1"]["imageDeletePending"] is True


def test_plain_turns_times_into_text_all_the_way_down():
    out = common.plain({"at": NOW, "rows": [{"t": NOW}], "n": 1})
    assert out == {"at": NOW.isoformat(), "rows": [{"t": NOW.isoformat()}], "n": 1}
