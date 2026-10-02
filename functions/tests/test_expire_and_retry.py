"""S7: SLA expiry. RETRY_REQUIRED, state retry, one bonus OCR submission per
expired flag and only under the cost cap. Nothing is ever reset."""

from __future__ import annotations

import datetime as dt

from identity import config, decisions, ledger, providers, reasons, review
from tests.fake_review_store import FakeReviewStore

LATER = dt.datetime.now(dt.timezone.utc) + dt.timedelta(hours=config.REVIEW_SLA_HOURS + 1)


def _expired(fake, uid="her", spent=0):
    flag_id = review.request(fake, uid, "error").flag_id
    fake.ledgers[uid]["spent_micro_usd"] = spent
    assert review.expire(fake, LATER) == 1
    return flag_id


def test_expiry_moves_flag_job_and_state():
    fake = FakeReviewStore()
    flag_id = _expired(fake)
    assert fake.flags[flag_id]["state"] == decisions.RETRY_REQUIRED
    assert fake.jobs[flag_id]["state"] == decisions.RETRY_REQUIRED
    assert fake.states["her"]["state"] == review.STATE_RETRY
    assert fake.open_flag_id("her") is None


def test_a_grant_under_the_cap():
    fake = FakeReviewStore()
    _expired(fake, spent=0)
    assert fake.ledgers["her"]["bonusOcrSubmissions"] == 1


def test_no_grant_when_a_whole_submission_would_cross_the_cap():
    fake = FakeReviewStore()
    spent = config.COST_CAP_MICRO_USD - 2 * providers.COST_OCR_PER_IMAGE + 1
    _expired(fake, spent=spent)
    assert fake.ledgers["her"].get("bonusOcrSubmissions", 0) == 0
    assert fake.ledgers["her"]["spent_micro_usd"] == spent, "spend is never reset"


def test_one_grant_per_flag():
    fake = FakeReviewStore()
    flag_id = _expired(fake)
    assert fake.grant_bonus("her", flag_id) is False
    assert fake.ledgers["her"]["bonusOcrSubmissions"] == 1


def test_a_second_expired_flag_earns_a_second_grant():
    fake = FakeReviewStore()
    _expired(fake)
    review.request(fake, "her", "error")
    review.expire(fake, LATER)
    assert fake.ledgers["her"]["bonusOcrSubmissions"] == 2


def test_the_ledger_honours_the_bonus_and_still_refuses_after_it():
    used = ledger.Budget(ocr_submissions=config.MAX_OCR_SUBMISSIONS, bonus_ocr_submissions=1)
    assert ledger.check(used, ledger.OCR_SUBMISSION, 3_000) is None
    spent = ledger.apply(used, ledger.OCR_SUBMISSION, 3_000)
    assert spent.bonus_ocr_submissions == 1
    refusal = ledger.check(spent, ledger.OCR_SUBMISSION, 3_000)
    assert refusal is not None and refusal.code == reasons.ATTEMPT_LIMIT_OCR


def test_the_bonus_never_lifts_the_cost_cap():
    near = ledger.Budget(
        spent_micro_usd=config.COST_CAP_MICRO_USD - 100, bonus_ocr_submissions=5
    )
    refusal = ledger.check(near, ledger.OCR_SUBMISSION, 3_000)
    assert refusal is not None and refusal.code == reasons.COST_CAP_REACHED


def test_a_pending_flag_inside_the_sla_is_left_alone():
    fake = FakeReviewStore()
    review.request(fake, "her", "niqab")
    assert review.expire(fake, dt.datetime.now(dt.timezone.utc)) == 0
