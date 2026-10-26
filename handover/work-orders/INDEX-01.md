# Index 01: Phase 1 close-out (run in this order)

| Order | File | Size | What it does |
|---|---|---|---|
| 1 | WO-01a-fix-two-failing-tests.md | S | Fixes `training_reminders_test.dart:284` and `getting_started_test.dart:242`: both tests now start with an empty notification bank. Root cause is commit `fe5a732` shrinking `notification_lines.json` under 50 KiB, not batch A, the kitten removal or the date. Two test files, no production code. |
| 2 | WO-01b-remove-unused-strings.md | S | Removes `n31212Kg` at its source (`msa/02.json`, `strings.json`), rebuilds `ar.json`, the arb files and `AppL10n`, drops the two stale kitten keys from `6-v2/flutter`, and repairs the two generated files the script overwrites (`app_routes.dart`, `app_tokens.dart`). `finishHere` was already gone. |
| 3 | WO-01c-follow-up-card-dismissal.md | S | Swipe-only dismissal of the Home follow-up card: a visible close button was tried and breaks the Home budget (6 controls against 5), so the swipe stays and the missing test for the screen-reader "Not now" action is added. One decision for the owner is stated. |
| 4 | WO-01d-confirm-fixed-review-items.md | S | No edits. Proves with real test runs that four review items are already fixed on the tree: no-tap "+" in the control counter, last set on app pause, stale R13 steps in the store screenshots, and the Home coach card's My coach route through the Change sheet. Lists two known limits. |
| 5 | WO-01e-format-damage-check.md | S | Finds formatting-only damage in the changed Dart files. On today's tree the only file is `app/lib/theme/app_tokens.dart` (203 whitespace lines); WO-01b removes it. |
| 6 | WO-01f-full-suites.md | M | Runs analyze, `flutter test`, pytest, Firestore rules, storage rules, dashboard tests and the dictionary check, with the expected last lines. Starts with a disk check. |
| 7 | WO-01g-two-local-commits.md | S | Two local commits with explicit `git add` lists built by a fixed per-file rule (109 and 22 files today), no `Co-Authored-By`, never `.claude/CLAUDE.md`, no push. |

## Facts found while writing these (for the owner)
- The Mac disk is full (about 1 GiB free of 228 GiB on 26 Oct 2026). A full `flutter test` run died with `No space left on device`. Old `flutter_tools.*` folders in `/var/folders/.../T` hold several GB.
- HEAD does not build: commit `8299dfa` deleted the `Kitten` widget while the screens still used it. So neither of the two commits builds alone.
- Of the six review items, four were already fixed on the tree, one is a string removal (WO-01b) and one is closed by design (WO-01c).

## UNVERIFIED items: 3
1. The complete `flutter test` number (about 8,840 passed, 102 skipped) was not observed; the run was cut short by the full disk. Verify with WO-01f step 2.
2. WO-01g was dry-run only (the two file lists and the sanity counts 3, 5, 0, 0 were computed; nothing was staged or committed). Verify by following it.
3. WO-01b was run end to end only in a scratch copy of `6-v2` (outputs matched the real arb files except the removed key); the real run also needs `flutter gen-l10n`, checked by its Verify steps.
