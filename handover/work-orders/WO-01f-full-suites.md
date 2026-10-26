# WO-01f: run every suite and report the real output
Depends on: WO-01a, WO-01b, WO-01c, WO-01d, WO-01e
Size: M (one to two hours, mostly waiting)
Reads first:
- `docs/plan/RESUME-ROADMAP.md` lines 8-14 (what the baseline was)
- `test/rules/package.json` (the two rules scripts)
- `firebase.emulator.json` (ports 8088 Firestore, 9098 Auth, 9198 Storage)

## Why
Phase 1 ends only when every suite is green on the tree that will be committed. The roadmap's last full Flutter run on this tree was `+8833 ~102 -3` (8,833 passed, 102 skipped, 3 failed); one of those three was fixed since, the other two are fixed by WO-01a. This order runs all five suites and records the real last lines. It fixes nothing.

Checked on 26 Oct 2026, before the Phase 1 edits, with these results (so you know what "normal" looks like): pytest 3459 passed; Firestore rules 446 passed; storage rules 33 passed; dashboard (admin-web) 77 passed; `flutter analyze lib test` clean. The full `flutter test` was not completed that day because the disk filled up (see step 0), so its number is the one to watch.

## Final result
A table in your report: suite, command, the last 3 lines of real output, pass or fail.

## Files to edit or create
None.

## Steps
0. Disk check, first. The Mac disk was at 100 percent on 26 Oct 2026 (about 1 GiB free) and a test run died with `No space left on device (errno = 28)`. Run `df -h /System/Volumes/Data`. If the `Avail` column shows less than 5Gi, stop: write the number into your report and tell the owner. Do not delete anything outside `~/ownhub`; the big folders are old `flutter_tools.*` folders in `/var/folders/.../T` and the owner decides about those.
1. Static check: `cd ~/ownhub/app && flutter analyze lib test`. Success: `No issues found!`.
2. App tests: `cd ~/ownhub/app && flutter test > /tmp/ownhub-flutter-test.log 2>&1; tail -3 /tmp/ownhub-flutter-test.log`. Allow up to 40 minutes (run it in the background and read the log if your shell has a time limit). Success: the last line looks like `NN:NN +88xx ~102: All tests passed!` with no `-N` in it. Expect roughly 8,840 passed (8,833 baseline plus the fixed ones plus the new tests from WO-01c) and about 102 skipped. If an untracked file `app/test/zz_probe_parser_test.dart` exists it adds 2 passing tests; that is fine.
3. Server tests: `cd ~/ownhub/functions && .venv/bin/python -m pytest -q 2>&1 | tail -3`. Success: `3459 passed in` and a time near 55 seconds (the number may be higher if tests were added; no `failed`).
4. Firestore rules (starts and stops its own emulator; needs Java 21, which is at `/opt/homebrew/opt/openjdk@21`):
   ```
   cd ~/ownhub && PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH firebase emulators:exec --config firebase.emulator.json --project own-hub --only firestore,auth "cd test/rules && npm test" 2>&1 | tail -14
   ```
   Success: lines `ℹ tests 446`, `ℹ pass 446`, `ℹ fail 0` and `Script exited successfully (code 0)`. If exactly one test fails, run the same command once more; the roadmap notes one flaky failure seen once (445/1, then 446/0). Two failures in a row: report both outputs.
5. Storage rules: `cd ~/ownhub/test/rules && npm run test:storage 2>&1 | tail -12`. Success: `ℹ tests 33`, `ℹ pass 33`, `ℹ fail 0`. (The owner's launch guide still says 32; 33 is the current count.)
6. Dashboard: `cd ~/ownhub/admin-web && node --test 2>&1 | tail -9`. Success: `ℹ tests 77`, `ℹ pass 77`, `ℹ fail 0`.
7. Wireframe dictionary (the strings check from WO-01b): `cd ~/ownhub/6-v2 && node src/merge-i18n.mjs | head -2`. Success, exactly: `source files: 14 | dictionary entries: 4243` then `strings on screens now: 1831 | covered: 1813 | missing: 18`. Run `cd ~/ownhub && git diff --stat -- 6-v2/i18n/ar.json` before and after this command: it must print the same line both times (the script rewrites the same bytes).
8. Write the table. For every suite that is not green: the suite name, the first failing test name, and the first 10 lines of its error text, copied exactly. Do not summarise errors in your own words.

## Strings to add
None.

## Tests to add or change
None.

## Verify
All of steps 1 to 7 as described. Anything else is a failed run, not a pass with a note.

## Do not
- Do not fix, skip, tag or delete a failing test to make the run pass.
- Do not run `firebase deploy` or any command against production (project `own-hub`) other than the local emulator command in step 4. The `--project own-hub` there only names the local emulator; with `emulators:exec` nothing is sent to Google.
- Do not run `flutter test --update-goldens` or anything that writes files in the repo.
- Do not commit yet.

## Done checklist
- [ ] Disk check passed (5Gi or more free)
- [ ] Seven commands run, last lines pasted
- [ ] Every non-green suite reported with exact error text

## If stuck
A suite fails: stop at that suite, write the question to `handover/QUESTIONS.md` with file:line and what you saw, run the remaining suites that do not depend on it (they are independent), and report. Do not start WO-01g until all seven are green.
