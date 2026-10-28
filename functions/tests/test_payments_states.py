"""The transition table, the event writer and idempotency."""

from __future__ import annotations

import itertools

import pytest

from coaching import common
from payments import engine, errors, model, notices, states
from tests.payments_helpers import (  # noqa: F401
    CLIENT, COACH, NOW, PAY, REVIEWER, _txn, db, events, later, make_payment, payment_of, refusal,
)

ROLES = (states.CLIENT, states.COACH, states.STAFF, states.SYSTEM)


@pytest.mark.parametrize("pair,roles", sorted(states.TRANSITIONS.items()))
def test_every_legal_transition_passes_for_exactly_its_roles(pair, roles):
    for role in ROLES:
        if role in roles:
            states.check(pair[0], pair[1], role)
        else:
            assert refusal(lambda: states.check(pair[0], pair[1], role)) == (errors.PRECONDITION, errors.ILLEGAL_TRANSITION)


def test_every_pair_of_statuses_not_in_the_table_is_refused_for_every_role():
    pairs = [p for p in itertools.product(model.STATUSES, model.STATUSES) if p not in states.TRANSITIONS]
    assert len(pairs) == len(model.STATUSES) ** 2 - len(states.TRANSITIONS)
    for frm, to in pairs:
        for role in ROLES:
            assert refusal(lambda: states.check(frm, to, role)) == (errors.PRECONDITION, errors.ILLEGAL_TRANSITION)


def test_the_table_only_names_known_statuses():
    for frm, to in states.TRANSITIONS:
        assert frm in model.STATUSES and to in model.STATUSES


def test_terminal_statuses_only_reopen_by_staff():
    assert not [p for p in states.TRANSITIONS if p[0] == "cancelled"]
    assert states.TRANSITIONS[("resolved_unpaid", "in_review")] == frozenset({states.STAFF})


def test_a_recorded_refund_is_the_coachs_word_so_it_reopens_only_into_review():
    # The client (she did not receive it) or staff open a dispute; nothing else leaves 'refunded'.
    assert [p for p in states.TRANSITIONS if p[0] == "refunded"] == [("refunded", "in_review")]
    assert states.TRANSITIONS[("refunded", "in_review")] == frozenset({states.CLIENT, states.STAFF})


def test_an_expired_request_has_an_exit():
    assert states.TRANSITIONS[("expired", "cancelled")] == frozenset({states.CLIENT, states.SYSTEM})


def test_every_notice_kind_has_both_languages_and_no_amount_or_em_dash():
    for kind, by_locale in notices.TEXT.items():
        assert set(by_locale) == {"en", "ar"}, kind
        for title, body in by_locale.values():
            assert "—" not in body and not any(c.isdigit() for c in body.replace("48", "").replace("3", "")), kind
    for pair in states._NOTICES.values():
        for _, kind in pair:
            assert kind in notices.TEXT


def test_a_tap_names_only_the_payment_or_the_statement_month():
    assert notices.STATEMENT_KINDS <= set(notices.KINDS)
    assert notices.data_for("instapayConfirmed", "pay-1") == {"kind": "instapayConfirmed", "paymentId": "pay-1"}
    for kind in notices.STATEMENT_KINDS:
        assert notices.data_for(kind, "2026-10") == {"kind": kind, "statementMonth": "2026-10"}
    assert notices.data_for("instapaySuspended", None) == {"kind": "instapaySuspended"}


def test_the_push_carries_the_ref_and_nothing_else():
    from tests import fake_firestore
    from tests.test_coaching_push import _Messaging, _device

    db_ = fake_firestore.FakeFirestore()
    _device(db_, CLIENT, "a", token="t1", locale="en", topics=["payments"])
    messaging = _Messaging()
    assert notices.send_kind(CLIENT, "instapayConfirmed", db=db_, messaging=messaging, ref="pay-1") == 1
    assert messaging.sent[0].data == {"kind": "instapayConfirmed", "paymentId": "pay-1"}
    messaging = _Messaging()
    notices.send_kind(CLIENT, "instapayPaused", db=db_, messaging=messaging)
    assert messaging.sent[0].data == {"kind": "instapayPaused"}


def test_a_payment_push_reaches_only_phones_that_asked_for_payment_alerts():
    from tests import fake_firestore
    from tests.test_coaching_push import _Messaging, _device

    db_ = fake_firestore.FakeFirestore()
    _device(db_, CLIENT, "c14", token="t-c14", locale="en")
    _device(db_, CLIENT, "approval", token="t-approval", locale="en", topics=["approval"])
    _device(db_, CLIENT, "pay", token="t-pay", locale="en", topics=["payments"])
    _device(db_, CLIENT, "both", token="t-both", locale="en", topics=["approval", "payments"])
    messaging = _Messaging()
    assert notices.send_kind(CLIENT, "instapayConfirmed", db=db_, messaging=messaging, ref="pay-1") == 2
    assert {t for m in messaging.sent for t in m.tokens} == {"t-pay", "t-both"}


def test_move_writes_the_status_and_one_event_and_returns_the_new_payment(db):
    make_payment(db, status="proof_submitted")
    ref = engine.payment_ref(db, PAY)

    def body(transaction):
        ref_, row = engine.load(transaction, db, PAY)
        return engine.move(transaction, db, ref_, row, "confirmed", states.COACH, COACH, NOW, changes={"x": 1}, code="coach_confirmed")

    out = common.run(db, body)
    assert out["status"] == "confirmed" and out["x"] == 1
    assert payment_of(db)["status"] == "confirmed"
    assert events(db) == [("proof_submitted", "confirmed", "coach")]
    event = next(iter(db.collection(f"payments/{PAY}/events").stream())).to_dict()
    assert event["actor"] == "coach" and event["code"] == "coach_confirmed"
    assert COACH not in str(event)


def test_move_refuses_an_illegal_pair_and_writes_nothing(db):
    make_payment(db, status="proof_submitted")

    def body(transaction):
        ref_, row = engine.load(transaction, db, PAY)
        engine.move(transaction, db, ref_, row, "refunded", states.COACH, COACH, NOW)

    assert refusal(lambda: common.run(db, body)) == (errors.PRECONDITION, errors.ILLEGAL_TRANSITION)
    assert payment_of(db)["status"] == "proof_submitted" and events(db) == []


def test_a_staff_event_names_a_short_reference_never_the_uid(db):
    make_payment(db, status="in_review")

    def body(transaction):
        ref_, row = engine.load(transaction, db, PAY)
        engine.move(transaction, db, ref_, row, "resolved_paid", states.STAFF, REVIEWER, NOW)

    common.run(db, body)
    event = next(iter(db.collection(f"payments/{PAY}/events").stream())).to_dict()
    assert REVIEWER not in str(event) and event["actor"] != REVIEWER


def test_a_stranger_gets_payment_not_found(db):
    make_payment(db)

    def body(transaction):
        engine.load_for_party(transaction, db, PAY, "someone-else", states.CLIENT)

    assert refusal(lambda: common.run(db, body)) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)


def test_idempotency_replays_the_first_answer(db):
    def first(transaction):
        assert engine.replay(transaction, db, CLIENT, "create", "key-12345678") is None
        engine.remember(transaction, db, CLIENT, "create", "key-12345678", {"paymentId": "p9"}, NOW)

    common.run(db, first)
    assert common.run(db, lambda t: engine.replay(t, db, CLIENT, "create", "key-12345678")) == {"paymentId": "p9"}
    assert common.run(db, lambda t: engine.replay(t, db, "other", "create", "key-12345678")) is None


@pytest.mark.parametrize("bad", [None, 5, "", "short", "has space 12345", "x" * 65])
def test_a_bad_idempotency_key_is_refused(bad):
    assert refusal(lambda: engine.idem_key(bad))[0] == errors.INVALID


def test_the_kill_switch_reads_off_when_missing_and_on_when_true(db):
    assert model.enabled(db) is False
    db.document("config/payments").set({"enabled": True})
    assert model.enabled(db) is True
    db.document("config/payments").set({"enabled": "yes"})
    assert model.enabled(db) is False


def test_pounds_text_uses_western_digits_and_two_decimals():
    assert model.pounds_text(50037) == "500.37" and model.pounds_text(50000) == "500.00" and model.pounds_text(5) == "0.05"
