# WO-01g: the two local commits (batch A; kitten removal and Moment)
Depends on: WO-01f (every suite green on the tree as it stands)
Size: S (under 1 hour)
Reads first:
- `.claude/CLAUDE.md` section "Owner rules (always)" (local first, no push, no AI signs, never stage this file)
- `docs/plan/RESUME-ROADMAP.md` lines 8-14
- `git status --short` (run it; the list below is today's, yours may differ)

## Why
About 130 files are changed and uncommitted: batch A (screen budgets, screen R13 removed, Undo on the last set, coaching screens and tests), and the kitten removal with the new `Moment` mark (`app/lib/ui/hand/moment.dart`). The owner wants two commits, local only. Facts that shape the steps:

- Many files are mixed (for example `app/lib/features/train/presentation/finished_view.dart` has the R13 and Undo changes and also swaps the kitten for `Moment`). Splitting inside a file needs interactive `git add -p`, which this environment does not support. So the split is per file, by a fixed rule: a changed file goes to the kitten commit when at least half of its changed lines mention kitten, Moment or mascot; every other file goes to batch A. The new files `app/lib/ui/hand/moment.dart` and `app/test/ui/hand/moment_test.dart` go to the kitten commit; the other new files (`last_log_undo_test.dart`, `finish_reveal_test.dart`, `step8_budget_test.dart`) go to batch A.
- Neither commit builds on its own. HEAD itself does not build: commit `8299dfa` already deleted the `Kitten` widget files while the screens still called them. Only the two commits together give the tree that was tested in WO-01f. Say this in your report; do not try to make each commit build.
- Other sessions commit documents (`handover/`, `docs/`) to this same branch, so HEAD can move while you work. Only code and test files from the list below are staged. Nothing under `handover/`, `docs/`, `.claude/` or `graphify-out/` is ever staged by this order.
- Owner rules: no `Co-Authored-By` line, no AI attribution, no em dashes in the message, local only (no `git push`), and `.claude/CLAUDE.md` is never staged (it is ignored by `.gitignore` line 36; `git add -f` is forbidden).

## Final result
`git log --oneline -3` shows two new commits on `feat/motivation-2026-10-13`, batch A first, kitten removal second. `git status --short` shows no tracked change left, only untracked files that are not ours (see step 8). Nothing is pushed.

## Files to edit or create
None in the repo except the two commits. Scratch files go to `/tmp/ownhub-commit/` (outside the repo).

## Steps
1. Preconditions. Run and compare:
   ```
   cd ~/ownhub && git branch --show-current
   git status --short -- app 6-v2 | wc -l
   ```
   The branch must be `feat/motivation-2026-10-13`. The count must equal the count you recorded at the end of WO-01f (step 8 there). If it is higher, files appeared that are not part of Phase 1 (another work order was started): stop, write the file names to `handover/QUESTIONS.md`.
2. Build the two lists. From `~/ownhub`, paste this whole block (it only reads git and writes `/tmp/ownhub-commit/commit1.txt` and `commit2.txt`):
```
python3 - <<'PY'
import subprocess, re, os
KITTEN = re.compile(r'kitten|\bMoment\b|\bmoment\b|mascot|KittenPose', re.I)
NEVER = {'app/test/zz_probe_parser_test.dart'}
C2_NEW = {'app/lib/ui/hand/moment.dart', 'app/test/ui/hand/moment_test.dart'}
out = subprocess.check_output(['git', 'status', '--porcelain'], text=True).splitlines()
c1, c2, skipped = [], [], []
for line in out:
    code, path = line[:2], line[3:]
    if path in NEVER or path.startswith(('handover/', '.claude/', 'docs/', 'graphify-out/')):
        skipped.append(path); continue
    if code == '??':
        (c2 if path in C2_NEW else c1).append(path); continue
    diff = subprocess.check_output(['git', 'diff', '-U0', '--', path], text=True, errors='ignore')
    changed = [l[1:] for l in diff.splitlines() if l[:1] in '+-' and l[:3] not in ('+++', '---')]
    hits = sum(1 for l in changed if KITTEN.search(l))
    ratio = 1.0 if (code.strip() == 'D' and 'kitten' in path) else hits / max(1, len(changed))
    (c2 if ratio >= 0.5 else c1).append(path)
os.makedirs('/tmp/ownhub-commit', exist_ok=True)
open('/tmp/ownhub-commit/commit1.txt', 'w').write('\n'.join(c1) + '\n')
open('/tmp/ownhub-commit/commit2.txt', 'w').write('\n'.join(c2) + '\n')
print('commit 1 (batch A):', len(c1), 'files')
print('commit 2 (kitten removal and Moment):', len(c2), 'files')
print('left out on purpose:', skipped)
PY
```
   Today's output (26 Oct 2026, before the Phase 1 edits of WO-01a to WO-01c):
   ```
   commit 1 (batch A): 109 files
   commit 2 (kitten removal and Moment): 22 files
   left out on purpose: ['app/test/zz_probe_parser_test.dart']
   ```
   After WO-01a to WO-01c expect about 3 more files in commit 1 (`training_reminders_test.dart`, `getting_started_test.dart`, and the 6-v2 files WO-01b touched). The 22 files of commit 2 today are: `app/lib/app_state/{account_data,analytics_consent,analytics_session,haptics,kitten_setting}.dart`, `app/lib/features/private_coaching/presentation/chat/{chat_list_view,chat_thread_view}.dart`, `app/lib/features/signup/presentation/demo/demo_chrome.dart`, `app/lib/features/signup/presentation/{selfie_capture_view,youre_in_view}.dart`, `app/lib/features/train/presentation/{session_share_card,train_view}.dart`, `app/lib/ui/hand/{hand,moment,tilt_parallax}.dart`, `app/test/features/signup/{checking_view_test,verification_choice_and_booking_test}.dart`, `app/test/features/today/first_week_done_test.dart`, `app/test/features/train/{finished_view_test,train_view_test}.dart`, `app/test/routing/offline_verification_launch_test.dart`, `app/test/ui/hand/moment_test.dart`.
3. Sanity-check the lists:
   ```
   grep -c "kitten_setting.dart\|ui/hand/moment.dart\|ui/hand/moment_test.dart" /tmp/ownhub-commit/commit2.txt
   grep -c "last_log_undo_test.dart\|finish_reveal_test.dart\|step8_budget_test.dart\|move_logged_view_test.dart\|lib/routing/app_router.dart" /tmp/ownhub-commit/commit1.txt
   cat /tmp/ownhub-commit/commit1.txt /tmp/ownhub-commit/commit2.txt | grep -c "^\.claude/\|zz_\|^handover/\|^docs/\|CLAUDE.md"
   cat /tmp/ownhub-commit/commit1.txt /tmp/ownhub-commit/commit2.txt | sort | uniq -d | wc -l
   ```
   Expected, in order: `3`, `5`, `0`, `0`. Any other number: stop.
4. Stage batch A and check exactly that is staged:
   ```
   cd ~/ownhub && xargs git add -- < /tmp/ownhub-commit/commit1.txt
   git diff --cached --name-only | sort > /tmp/ownhub-commit/staged1.txt
   sort /tmp/ownhub-commit/commit1.txt | diff - /tmp/ownhub-commit/staged1.txt && echo STAGED_MATCHES
   ```
   Expected last line: `STAGED_MATCHES` (deleted files such as `app/test/features/train/move_logged_view_test.dart` are staged as deletions by the same command). If other files were already staged before you began, `git diff --cached` lists them and the check fails: run `git reset -q` once to clear the index (this changes no file), then repeat step 4.
5. Commit batch A. Write the message file, then commit from it (the message has no `Co-Authored-By` line on purpose):
```
cat > /tmp/ownhub-commit/msg1.txt <<'MSG'
Batch A: screen budgets, one move-logged flow, Undo on the last set

Home, Eat, You, Settings, My coach, a coach's page, a coach's plan and
Events hold to one filled primary and five controls above the fold, in
English and Arabic, checked by the budget tests.

Screen R13 (Move logged) is gone. "I did them all" goes to the next move
with Undo. The last log of a workout keeps five seconds of Undo on the
finish screen, and the workout is saved at once when the app goes to the
background.

The Home follow-up card is sent away by a swipe, with a Not now action
for screen readers. Home's coach card no longer taps; My coach is in the
Change sheet.

Test helpers: a row and its own plus count as one control, a plus in a row
with no tap counts on its own. The reminder tests no longer load the
notification bank. Unused strings removed.
MSG
git commit -F /tmp/ownhub-commit/msg1.txt
```
   Then: `git log -1 --format=%B | grep -c "Co-Authored\|Claude\|Gemini\|—"` must print `0`.
6. Stage the kitten removal and Moment:
   ```
   cd ~/ownhub && xargs git add -- < /tmp/ownhub-commit/commit2.txt
   git diff --cached --name-only | sort > /tmp/ownhub-commit/staged2.txt
   sort /tmp/ownhub-commit/commit2.txt | diff - /tmp/ownhub-commit/staged2.txt && echo STAGED_MATCHES
   ```
   Expected last line: `STAGED_MATCHES`.
7. Commit it:
```
cat > /tmp/ownhub-commit/msg2.txt <<'MSG'
Remove the kitten and its setting, add Moment

The Kitten widget files were deleted earlier; this removes what was left
of it: the setting (kitten_setting.dart), its place in account deletion,
its call sites and the comments that named it. Where a character stood,
screens now draw Moment, a hand-drawn tick that draws on once and is
simply there when motion is off.
MSG
git commit -F /tmp/ownhub-commit/msg2.txt
git log -1 --format=%B | grep -c "Co-Authored\|Claude\|Gemini\|—"
```
   The last command must print `0`.
8. Final state. Run:
   ```
   cd ~/ownhub && git status --short
   git log --oneline -4
   git diff HEAD --quiet -- app 6-v2 && echo TREE_CLEAN
   ```
   Expected: `git status --short` lists nothing except untracked files that are not part of Phase 1 (today: `?? app/test/zz_probe_parser_test.dart`; and any `handover/` files other sessions are writing); the two new commits are the top two of `git log`, or sit under newer documents-only commits from other sessions; `TREE_CLEAN` is printed; nothing is pushed (you must not run `git push`).
9. Pair check on the committed tree: `cd ~/ownhub/app && flutter analyze lib test` must end with `No issues found!`. This is the proof that the two commits together build. Do not re-run the full tests; the tree did not change since WO-01f (step 8 `TREE_CLEAN` proves it).

## Strings to add
None.

## Tests to add or change
None.

## Verify
- Step 3 prints `3`, `5`, `0`, `0`.
- Steps 4 and 6 print `STAGED_MATCHES`.
- Steps 5 and 7: the `grep -c` prints `0`.
- Step 8 prints `TREE_CLEAN`.
- Step 9 prints `No issues found!`.

## Do not
- Do not use `git add .`, `git add -A`, `git add -u` or `git commit -a`. Only the explicit lists.
- Do not stage `.claude/CLAUDE.md` or anything under `.claude/`, `handover/`, `docs/`, `graphify-out/`. Never `git add -f`.
- Do not add a `Co-Authored-By` line, a "Generated with" line, or any mention of an AI tool.
- Do not push, do not create a pull request, do not touch `main`, do not amend or rebase commits that already exist.
- Do not delete `app/test/zz_probe_parser_test.dart`; it is not ours.
- Do not run `git stash`, `git reset --hard` or `git checkout .`.

## Done checklist
- [ ] Preconditions held (branch, file count)
- [ ] Lists built and sanity-checked (3, 5, 0, 0)
- [ ] Commit 1 made, message check printed 0
- [ ] Commit 2 made, message check printed 0
- [ ] `TREE_CLEAN` and analyze clean
- [ ] Report says: two commits, local only, neither builds alone because HEAD already did not

## If stuck
Any check fails, or `git commit` refuses: stop. Do not use `--no-verify` (there are no hooks today, so a refusal means something real). Write the question to `handover/QUESTIONS.md` with the command, the output, and `git status --short | head -30`. If commit 1 was made and commit 2 failed, leave the repository as it is and report; do not try to undo commit 1.
