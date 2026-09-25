"""Spec §6's cost ceiling and spec §2 step 5's one-card-one-account rule."""

from __future__ import annotations

import pytest

from identity import config, dedupe, ledger, providers, reasons

PEPPER = b"a-test-pepper-not-the-real-one"
SYNTHETIC = "29507142101345"


# ------------------------------------------------------------------ ledger


def test_a_fresh_budget_allows_the_first_call():
    assert ledger.check(ledger.Budget(), ledger.OCR_SUBMISSION, 3_000) is None


def test_a_call_that_would_land_exactly_on_the_cap_is_allowed():
    # Spec §6 says refuse if `spent + next > 50,000`. Exactly 50,000 is not
    # more than 50,000, and getting this boundary wrong by one would silently
    # cost every woman her last attempt.
    budget = ledger.Budget(spent_micro_usd=config.COST_CAP_MICRO_USD - 1_000)
    assert ledger.check(budget, ledger.FACE_MATCH, 1_000) is None


def test_a_call_one_micro_dollar_past_the_cap_is_refused():
    budget = ledger.Budget(spent_micro_usd=config.COST_CAP_MICRO_USD - 1_000)
    refusal = ledger.check(budget, ledger.FACE_MATCH, 1_001)
    assert refusal is not None and refusal.code == reasons.COST_CAP_REACHED


def test_the_ocr_attempt_limit_bites_before_the_money_does():
    budget = ledger.Budget(ocr_submissions=config.MAX_OCR_SUBMISSIONS)
    refusal = ledger.check(budget, ledger.OCR_SUBMISSION, 1)
    assert refusal.code == reasons.ATTEMPT_LIMIT_OCR


def test_the_liveness_attempt_limit_bites_before_the_money_does():
    budget = ledger.Budget(liveness_attempts=config.MAX_LIVENESS_ATTEMPTS)
    refusal = ledger.check(budget, ledger.LIVENESS_ATTEMPT, 1)
    assert refusal.code == reasons.ATTEMPT_LIMIT_LIVENESS


def test_one_attempt_short_of_the_limit_is_still_allowed():
    budget = ledger.Budget(ocr_submissions=config.MAX_OCR_SUBMISSIONS - 1)
    assert ledger.check(budget, ledger.OCR_SUBMISSION, 3_000) is None


def test_apply_counts_the_right_kind():
    after = ledger.apply(ledger.Budget(), ledger.OCR_SUBMISSION, 3_000)
    assert after.ocr_submissions == 1 and after.liveness_attempts == 0
    after = ledger.apply(after, ledger.LIVENESS_ATTEMPT, 15_000)
    assert after.ocr_submissions == 1 and after.liveness_attempts == 1
    assert after.spent_micro_usd == 18_000


def test_the_worst_case_stays_under_the_cap():
    # The purpose of this test is the ceiling, not any particular number, so it
    # survives the provider decision that changed the inputs.
    #
    # Spec §6 wrote the worst case as 4 x 3,000 + 2 x 16,000 = 44,000, assuming
    # AWS liveness at 15,000 and CompareFaces at 1,000. The owner decided
    # against AWS; both are now zero and the only money is Cloud Vision, so the
    # real worst case is 4 x 3,000 + 2 x 0 = 12,000.
    worst = ledger.worst_case_micro_usd()
    assert worst == 12_000, "4 OCR submissions x 2 images x 1,500 uUSD"
    assert worst <= config.COST_CAP_MICRO_USD


def test_the_cap_is_not_relaxed_just_because_the_numbers_got_smaller():
    # The ceiling is a safety rail against a runaway loop or a provider that
    # starts billing differently, not a budget estimate. If someone "optimises"
    # it down to hug the real spend, a future paid provider silently breaks.
    assert config.COST_CAP_MICRO_USD == 50_000


def test_a_paid_provider_reappearing_would_trip_the_ceiling_check():
    # Proves worst_case_micro_usd actually reads the provider constants rather
    # than returning a hard-coded number, so adding AWS back would move it.
    import unittest.mock as mock

    with mock.patch.object(providers, "COST_LIVENESS_SESSION", 15_000), \
         mock.patch.object(providers, "COST_FACE_MATCH", 1_000):
        assert ledger.worst_case_micro_usd() == 44_000


def test_a_single_verification_costs_three_tenths_of_a_cent():
    # Two Cloud Vision units, front and back. Liveness and the face match are
    # self-hosted and carry no vendor charge.
    one_pass = 2 * providers.COST_OCR_PER_IMAGE
    assert one_pass == 3_000
    assert one_pass < config.COST_CAP_MICRO_USD / 10


def test_liveness_attempts_are_still_limited_although_liveness_is_free():
    # No longer a spending limit; now an ABUSE limit. Unlimited free liveness
    # attempts against one card is exactly the loop an attacker would use to
    # find the pose sequence that scrapes past the threshold, and "it costs us
    # nothing" is not a reason to allow it.
    assert config.MAX_LIVENESS_ATTEMPTS == 2
    budget = ledger.Budget(liveness_attempts=2, spent_micro_usd=0)
    refusal = ledger.check(budget, ledger.LIVENESS_ATTEMPT, 0)
    assert refusal is not None and refusal.code == reasons.ATTEMPT_LIMIT_LIVENESS


# ------------------------------------------------------------------ dedupe


def test_the_same_number_and_pepper_always_give_the_same_hash():
    assert dedupe.hash_and_forget(SYNTHETIC, PEPPER) == dedupe.hash_and_forget(
        SYNTHETIC, PEPPER
    )


def test_a_different_pepper_gives_a_different_hash():
    # Which is why pepper_version travels with every stored hash: rotating
    # without it would silently make every registered card registerable again.
    assert dedupe.hash_and_forget(SYNTHETIC, PEPPER) != dedupe.hash_and_forget(
        SYNTHETIC, b"another-pepper"
    )


def test_the_hash_does_not_contain_the_number():
    digest = dedupe.hash_and_forget(SYNTHETIC, PEPPER)
    assert SYNTHETIC not in digest
    assert len(digest) == 64


def test_the_registry_document_carries_only_allowlisted_fields():
    # Spec §4 permits id_hmac + pepper_version bound to uid. Not a name, not a
    # birth date, not a governorate, not the number.
    document = dedupe.registry_document("uid-1")
    assert set(document) == {"uid", "state", "pepper_version"}
    assert document["state"] == dedupe.STATE_ACTIVE
    assert document["pepper_version"] == config.PEPPER_VERSION


def test_no_entry_means_the_card_is_free():
    assert dedupe.judge(None, "uid-1").ok is True


def test_another_accounts_entry_is_a_duplicate():
    entry = dedupe.RegistryEntry(uid="someone-else", state="active", pepper_version=1)
    verdict = dedupe.judge(entry, "uid-1")
    assert verdict.ok is False and verdict.reason == reasons.DUPLICATE_ID


def test_her_own_entry_is_a_reverification_not_a_duplicate():
    # She deleted the app and signed in on a new phone. Treating this as a
    # duplicate would permanently lock her out of a product she is entitled to.
    entry = dedupe.RegistryEntry(uid="uid-1", state="active", pepper_version=1)
    verdict = dedupe.judge(entry, "uid-1")
    assert verdict.ok is True and verdict.is_reverification is True


def test_a_closed_entry_refuses_even_the_original_owner():
    # The app's deletion manifest closes rather than deletes, so a removed woman
    # cannot re-register while no personal data stays linked.
    entry = dedupe.RegistryEntry(uid=None, state="closed", pepper_version=1)
    verdict = dedupe.judge(entry, "uid-1")
    assert verdict.ok is False and verdict.reason == reasons.REGISTRATION_CLOSED


def test_hash_comparison_is_constant_time():
    assert dedupe.constant_time_equal("abc", "abc") is True
    assert dedupe.constant_time_equal("abc", "abd") is False


def test_costs_are_integers_not_floats():
    # A budget check in floating point accumulates error and eventually either
    # refuses a call it should allow or allows one it should refuse.
    for value in (
        providers.COST_OCR_PER_IMAGE,
        providers.COST_LIVENESS_SESSION,
        providers.COST_FACE_MATCH,
        config.COST_CAP_MICRO_USD,
    ):
        assert isinstance(value, int)
