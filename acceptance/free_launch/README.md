# Tests to read and run before implementation

Read [the implementation guide](../../docs/plan/FREE-LAUNCH-COACHING-PLAN.md) first, then [ACCEPTANCE.md](ACCEPTANCE.md). These tests specify future behavior. They do not implement the seven features or assert that the app is launch-ready.

## Run from the repository root

```sh
(cd app && flutter pub get)
# Existing backend setup: Python 3.12, functions/.venv and requirements installed.
# If pytest is absent: functions/.venv/bin/python -m pip install pytest
bash acceptance/free_launch/run.sh
```

The runner invokes each Dart suite separately from `app/`, using its real package configuration, and pytest with `functions/` on PYTHONPATH. It does not access a real payment provider or production Firebase. It runs all suites even after a failure and exits nonzero if any fails or a tool is missing. Logs are in ignored `results/`. Future tests are outside `app/test` so ordinary CI is not deliberately broken by absent APIs. Do not run a root-level `flutter analyze`: the Flutter package and its analysis configuration are in `app/`.

## Baseline recorded before feature implementation

On 12 October 2026, feature baseline `96de1f0` (plus the separate PostHog integration, which does not implement these features):

| Suite | Baseline result | What it establishes |
|---|---|---|
| `flutter/existing_behavior_test.dart` | 3 passed, 4 failed | Empty/compatible catalogue and no fabricated results pass. Equipment mismatch rejection, gym vocabulary, active-session restore and repository-driven swap fail with real behavior assertions. |
| `flutter/media_surface_test.dart` | Expected failure: available source still renders an empty `AppMedia` | Structural player-wiring check only; actual decoding still requires plugin/device tests. |
| `flutter/progression_contract_test.dart` | Expected compilation failure: missing production `progression_policy.dart` | Implement F6's documented API, then execute its behavioral cases. |
| `flutter/first_gym_contract_test.dart` | Expected compilation failure: missing `FirstGymGuideView` | Implement the real four-step U0 view, not a placeholder returning test keys. |
| `python/test_commission_contract.py` | 18 setup errors, all identify missing `coaching.commerce` | Implement the pure commission contract below. No real payment credentials needed. |

A missing API is an unresolved requirement, not a passing/skipped test. A syntax error, wrong import or mismatched fixture is a test defect; fix that without weakening the behavior. No `skip`, `xfail`, fake production class, hidden test-only route or hardcoded expected calculation. When approved product requirements change, update the guide and test together and explain the change.

The media surface test uses a synthetic URI and does not decode a file. As the player is integrated, inject the player controller/platform test double to avoid real I/O; retain the assertion that production source-present wiring mounts media, and add playback/error tests. Do not satisfy it with a blank Container.

## Proposed contracts that do not exist yet

**F6 progression:** exact signature and decision rules are in guide section 9. Inputs are work sets only, no warm-up sets. Invalid finite/nonnegative values or invalid positive targets throw `ArgumentError`; an empty list of available weights is valid and means no higher load available. Pain/return review takes precedence over difficulty and increase. No history holds null, including review if there is no weight to review. The policy is a suggestion and cannot publish a coach plan. Add an integration test proving that distinction.

**U0 first-gym guide:** widget signature, four step keys and action keys are in guide section 12. Tests cover English/Arabic, Back/Next, final action, Skip, small viewport, 200% text and final-step touch/semantics checks. Implementing agent must extend semantics/touch checks to each step, assert actual useful localized content and add route/persistence/practice-mode tests. The keys alone are not sufficient acceptance.

**C0 arithmetic:** add `functions/coaching/commerce.py` exporting:

```python
def commission_breakdown(*, gross_minor: int, refunded_minor: int,
                         commission_bps: int) -> dict[str, int]: ...
```

Only real integers (not bool or float); `0 <= refunded_minor <= gross_minor` and `0 <= commission_bps <= 10000`, otherwise `ValueError`. Return exactly `base_minor`, `platform_minor`, `coach_minor`. Proposed commission base is `gross_minor - refunded_minor`. Platform amount rounds half-up to an integer minor unit using integer arithmetic: `(base * commission_bps + 5000) // 10000`; coach receives `base - platform` before separate fees/taxes/adjustments. Cumulative refunds recompute the cumulative entitlement; the ledger books the difference, avoiding per-refund rounding drift. Rates are synthetic test data, not approved commercial terms. Large-number tests prevent silent floating-point loss. Integrate the policy with an immutable, versioned offer and verified server ledger; this function is not proof of paid entitlement.

**No gateway exists.** Build contracts/fakes and free-launch behavior first. Mark paid launch blocked until a selected eligible provider or store billing adapter has real sandbox webhook/verification, reconciliation and refund tests. Do not mark this criterion passed because arithmetic passes.

## Existing regressions to keep

Run affected suites during development. At implementation completion run the full Flutter, backend and rules suites using README's local emulator setup. Relevant existing suites include `app/test/features/coachplan/`, `app/test/features/coaching/`, `app/test/features/train/`, `app/test/app_state/app_snapshot_test.dart`, `app/test/features/account/`, `app/test/release/analytics_consent_test.dart`, `app/test/release/analytics_privacy_guard_test.dart`, and `functions/tests/`. Check actual suite names before invoking. New authorization tests must use the same emulator and fake infrastructure; do not hit production.

The newly implemented PostHog tests live in the ordinary suite at `app/test/release/posthog_analytics_test.dart` and must pass now. They are separate from these intentionally failing future-feature contracts.

See [the handoff review](REVIEW.md) for verified results and unresolved release evidence.

## Completion evidence

For every checklist row, record commit, exact command/test name, result, date, device/build (where relevant), and redacted evidence path. Distinguish automated unit checks, emulator integration, provider sandbox, device behavior, usability observation and legal/owner decisions. Preserve failures; never convert an unperformed check into a tick. The current executable pack is a starting set, not complete launch certification.
