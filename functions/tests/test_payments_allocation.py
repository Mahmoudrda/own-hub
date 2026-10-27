from __future__ import annotations

import random

import pytest

from coaching import common
from payments import allocation, engine, errors, model, states
from tests.payments_helpers import AMOUNT, BASE, COACH, NOW, PAY, REVIEWER, _txn, db, later, make_payment, refusal  # noqa: F401


def test_an_amount_is_between_one_and_ninety_nine_piasters_above_the_base(db):
    amount, lock = common.run(db, lambda t: allocation.allocate(t, db, COACH, BASE, PAY, NOW, rng=random.Random(1)))
    assert BASE + 1 <= amount <= BASE + 99 and lock == f"{COACH}__{amount}"


def test_two_open_payments_of_one_coach_never_share_an_amount(db):
    seen = set()
    for n in range(30):
        def body(t, n=n):
            amount, lock = allocation.allocate(t, db, COACH, BASE, f"p{n}", NOW, rng=random.Random(n))
            allocation.claim(t, db, lock, COACH, amount, f"p{n}", NOW)
            return amount
        seen.add(common.run(db, body))
    assert len(seen) == 30


def test_a_lock_that_has_expired_is_free_again(db):
    db.document(f"paymentAmountLocks/{COACH}__{BASE + 1}").set({"heldUntil": later(hours=-1), "paymentId": "old"})
    rng = random.Random(3)
    for extra in range(2, 100):
        db.document(f"paymentAmountLocks/{COACH}__{BASE + extra}").set({"heldUntil": later(days=2), "paymentId": "x"})
    amount, _ = common.run(db, lambda t: allocation.allocate(t, db, COACH, BASE, PAY, NOW, rng=rng))
    assert amount == BASE + 1


def test_all_ninety_nine_taken_is_refused(db):
    for extra in range(1, 100):
        db.document(f"paymentAmountLocks/{COACH}__{BASE + extra}").set({"heldUntil": later(days=2), "paymentId": "x"})
    assert refusal(lambda: common.run(db, lambda t: allocation.allocate(t, db, COACH, BASE, PAY, NOW))) == (errors.EXHAUSTED, errors.AMOUNT_UNAVAILABLE)


def test_another_coach_may_use_the_same_amount(db):
    db.document(f"paymentAmountLocks/other-coach__{BASE + 5}").set({"heldUntil": later(days=2), "paymentId": "x"})
    for extra in range(1, 100):
        if extra != 5:
            db.document(f"paymentAmountLocks/{COACH}__{BASE + extra}").set({"heldUntil": later(days=2), "paymentId": "x"})
    amount, _ = common.run(db, lambda t: allocation.allocate(t, db, COACH, BASE, PAY, NOW, rng=random.Random(0)))
    assert amount == BASE + 5


def test_moving_to_a_finished_status_frees_the_lock_and_open_statuses_extend_it(db):
    make_payment(db, status="awaiting_payment", lockId=f"{COACH}__{AMOUNT}")
    db.document(f"paymentAmountLocks/{COACH}__{AMOUNT}").set({"heldUntil": later(days=7), "paymentId": PAY})

    def to(status, role):
        def body(t):
            ref, row = engine.load(t, db, PAY)
            engine.move(t, db, ref, row, status, role, None, NOW)
        common.run(db, body)

    to("proof_submitted", states.CLIENT)
    assert db.document(f"paymentAmountLocks/{COACH}__{AMOUNT}").get().to_dict()["heldUntil"] == later(days=30)
    to("confirmed", states.COACH)
    assert db.document(f"paymentAmountLocks/{COACH}__{AMOUNT}").get().to_dict()["heldUntil"] == NOW


def test_a_reference_has_six_characters_without_lookalikes_and_is_unique(db):
    made = set()
    for n in range(50):
        ref = common.run(db, lambda t, n=n: allocation.new_reference(t, db, rng=random.Random(n)))
        assert ref.startswith("OH-") and len(ref) == 9 and not set(ref[3:]) & set("01OIL")
        make_payment(db, f"p{n}", reference=ref)
        made.add(ref)
    assert len(made) == 50


def test_a_reference_already_in_use_is_skipped(db):
    first = common.run(db, lambda t: allocation.new_reference(t, db, rng=random.Random(7)))
    make_payment(db, "pa", reference=first)
    again = common.run(db, lambda t: allocation.new_reference(t, db, rng=random.Random(7)))
    assert again != first
