"""C9: the flags that hold a plan until the coach has read the client's answers."""

from __future__ import annotations

import pytest

from coaching import common, errors, subscriptions
from tests.coaching_helpers import _txn, refusal  # noqa: F401
from tests.test_coaching_free import ask
from tests.test_coaching_plans import NOW, make_db, publish, req
from tests.test_coaching_subscriptions import COACH, db, intake, pushes, seed, sub_of  # noqa: F401


def _raw(**over):
    return intake(**over)


def test_intake_flags_by_stage_and_eating_history():
    # pregnant without the doctor tick is refused, with it kept as asked
    with pytest.raises(errors.CoachingError):
        subscriptions.intake_of(_raw(lifeStage="pregnant", doctorAck=False))
    ok = subscriptions.intake_of(_raw(lifeStage="pregnant", doctorAck=True))
    assert ok["lifeStage"] == "pregnant"
    assert ok["eatingHistory"] is False

    with pytest.raises(errors.CoachingError):
        subscriptions.intake_of(_raw(eatingHistory=True, doctorAck=False))
    assert subscriptions.intake_of(_raw(eatingHistory=True, doctorAck=True))["eatingHistory"] is True

    with pytest.raises(errors.CoachingError):
        subscriptions.intake_of(_raw(eatingHistory="yes"))

    # the old shape (no new keys) still works and is not flagged
    old = subscriptions.intake_of(_raw())
    assert old["eatingHistory"] is False
    assert subscriptions.intake_flagged(old) is False


def test_a_flagged_request_is_never_auto_accepted(db, pushes):
    seed(db, accounts=False, seller=False)  # auto accept on
    result = ask(db, pushes, intake=intake(eatingHistory=True, doctorAck=True))
    assert result["status"] == "requested"
    assert sub_of(db, result["subId"])["status"] == "requested"


@pytest.mark.parametrize("kind", ["workout", "meal"])
def test_publish_refuses_a_flagged_client_until_the_coach_has_read_her_answers(kind):
    store = make_db()
    store.document("subscriptions/sub1").update({"intake": {"lifeStage": "postpartum", "health": {}}})
    new_app = req(kind, reviewsHealth=True)
    assert refusal(lambda: publish(store, new_app)) == (errors.PRECONDITION, errors.HEALTH_NOT_REVIEWED)

    assert subscriptions.review_health(
        store, "coach1", {"subId": "sub1"}, live=True, coach_v="active", now=NOW
    ) == {"ok": True}
    out, _ = publish(store, new_app)
    assert out["revision"] == 1


@pytest.mark.parametrize("kind", ["workout", "meal"])
def test_a_build_that_cannot_clear_the_hold_is_not_locked_out_by_it(kind):
    # Functions go out before the app. A coach still on a build without the
    # "I have read them" button must be able to send, as she could before.
    store = make_db()
    store.document("subscriptions/sub1").update({"intake": {"lifeStage": "postpartum", "health": {}}})
    out, _ = publish(store, req(kind))
    assert out["revision"] == 1
    again, _ = publish(store, req(kind, reviewsHealth=False, name="Again"))
    assert again["revision"] == 1


def test_the_hold_reads_the_intake_the_server_really_stores():
    store = make_db()
    stored = subscriptions.intake_of(intake(eatingHistory=True, doctorAck=True))
    store.document("subscriptions/sub1").update({"intake": stored})
    new_app = req("workout", reviewsHealth=True)
    assert refusal(lambda: publish(store, new_app)) == (errors.PRECONDITION, errors.HEALTH_NOT_REVIEWED)


def test_an_unflagged_client_is_never_held():
    store = make_db()
    store.document("subscriptions/sub1").update(
        {"intake": {"lifeStage": "none", "eatingHistory": False, "health": {k: False for k in common.ENUMS["healthQuestions"]}}}
    )
    out, _ = publish(store, req("workout"))
    assert out["revision"] == 1


def test_only_her_own_coach_can_mark_it_read_and_twice_is_fine():
    import datetime as dt

    store = make_db()
    store.document("coaches/other").set({"displayName": "Other"})
    store.document("coachPrivate/other").set({"payoutState": "confirmed"})
    store.document("subscriptions/sub1").update({"intake": {"lifeStage": "pregnant", "health": {}}})

    assert refusal(
        lambda: subscriptions.review_health(
            store, "other", {"subId": "sub1"}, live=True, coach_v="active", now=NOW
        )
    ) == (errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)

    first = subscriptions.review_health(store, "coach1", {"subId": "sub1"}, live=True, coach_v="active", now=NOW)
    stamp = store.document("subscriptions/sub1").get().to_dict()["healthReviewedAt"]
    second = subscriptions.review_health(
        store, "coach1", {"subId": "sub1"}, live=True, coach_v="active", now=NOW + dt.timedelta(hours=1)
    )
    row = store.document("subscriptions/sub1").get().to_dict()
    assert first == second == {"ok": True}
    assert row["healthReviewedAt"] == stamp == NOW
    assert row["healthReviewedBy"] == "coach1"


@pytest.mark.parametrize("kind", ["workout", "meal"])
def test_the_owner_can_make_the_hold_mandatory_for_a_build_that_never_asks_for_it(kind):
    store = make_db()
    store.document("subscriptions/sub1").update({"intake": {"lifeStage": "postpartum", "health": {}}})
    store.document("coachingConfig/plans").set({"healthHoldMandatory": True})
    assert refusal(lambda: publish(store, req(kind))) == (errors.PRECONDITION, errors.HEALTH_NOT_REVIEWED)
    assert subscriptions.review_health(store, "coach1", {"subId": "sub1"}, live=True, coach_v="active", now=NOW) == {"ok": True}
    assert publish(store, req(kind))[0]["revision"] == 1


@pytest.mark.parametrize("value", [False, "true", 1, None])
def test_the_mandatory_switch_is_off_unless_exactly_true(value):
    store = make_db()
    store.document("subscriptions/sub1").update({"intake": {"lifeStage": "postpartum", "health": {}}})
    store.document("coachingConfig/plans").set({"healthHoldMandatory": value})
    assert publish(store, req("workout"))[0]["revision"] == 1
