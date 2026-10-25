# Own Hub: resume roadmap (26 Oct 2026)

Branch `feat/motivation-2026-10-13`. Main is at fe5a732 (waves 1 to 3 and the notification cleanup). Plan with the full build log: `~/.claude/plans/wiggly-discovering-elephant.md`. Owner rules: `.claude/CLAUDE.md` (no AI signs, no em dashes in product copy, Egyptian Arabic with feminine address, never push main without the owner's OK, never stage `.claude/CLAUDE.md`).

**The master plan for the public release is `docs/plan/PRODUCTION-RELEASE-PLAN.md` (phases 1 to 6). It supersedes the session list below, which only covers phases 1 and 4.**

## Where things stand
- Committed and pushed: waves 1 to 3 (ec272aa), notification cleanup (fe5a732), emotional redesign guide (8299dfa).
- Uncommitted in the working tree (about 90 files): batch A, plus the kitten removal and the new animation mark `app/lib/ui/hand/moment.dart`.
- Full flutter run on this tree: +8833 ~102 -3. One failure fixed (`being_checked_view_test.dart:258`). Two still open: `app/test/features/train/training_reminders_test.dart:284` (applied has 2 entries, expected 1) and `app/test/app_state/getting_started_test.dart:242` (tips empty, expected kNudgesUnanswered - 1). Not yet known whether batch A or the kitten removal caused them; a clean HEAD check did not load.
- Batch A review (earlier) listed must-fix items: counter hides a no-tap row's "+", app kill inside the 5-second Undo loses the last set, unused strings `finishHere` and `n31212Kg`, stale store screenshot R13 steps, Home coach card tap, swipe-only dismissal of the follow-up card.
- Google Cloud appeal (ticket 67P3AQYUEJ7Z3QH6KJRFZSMSVA) pending: AI photo scanning returns 403 until approved.

## Order of work (recommended: ship release 2 first, redesign as the release after)
### Session 1: finish batch A and the kitten removal (about 3 hours)
1. Find the cause of the two failing tests; fix. Fix the batch A must-fix list above.
2. Run the build-reviewer on the diff; fix every must-fix.
3. Full suites: `cd app && flutter analyze && flutter test`; `cd functions && .venv/bin/python -m pytest -q`; Firestore and storage rules; `cd admin-web && node --test`. All green.
4. Commit batch A and the kitten removal as two commits (explicit `git add`, no Co-Authored-By).

### Session 2: batch B, release prep, final build (about 6 hours)
5. Batch B (Sonnet builders, one review and one commit each): fewer steps (guest first workout D62 with "Keep this workout"; C08 for coaches only; one step counter; prefill), the walking session (any length, very clear calorie logging), rewards without a mascot (personal-best haptic, one warm line on R10, copy-audit test).
6. Release prep: bump `app/pubspec.yaml` to 1.1.0; "What's new" in English and Egyptian Arabic; update `docs/owner/LAUNCH-GUIDE.md`, `docs/owner/OWNER-TODO.md`, `docs/release/appstore-listing.md`; review notes must say AI photo scanning may be unavailable until Google approves.
7. Visual check of every screen in English and Arabic; Android emulator walk on `ownhub_pixel8` (new user to first set, full workout to R10, log a usual breakfast, find and join a coach).
8. New App Store screenshots: retake all screens (6.9-inch, EN and AR) with `app/test/store/store_screenshots_test.dart` and the pipeline in `docs/release/screenshots/`; add Rahma-branded shots from `~/Downloads/IMG_1498.MOV` (candidate sheets in `.claude/feature-briefs/rahma-candidates/`); show the owner the set and pick the best.
9. Last review, all suites green, `app/tool/release_preflight.sh` all PASS, push `feat/motivation-2026-10-13`.

### Owner steps: production (after session 2)
10. Deploy order: functions, then `storage.rules`, then the dashboard within minutes, then re-add pre-approved numbers with the 18+ tick, then the website, the app last.
11. Build: `app/tool/build_ios.sh`; upload the IPA with Transporter; test on TestFlight; then submit the new version in place of 1.0.0 in App Store Connect with the new screenshots and "What's new".
12. Owner reminders: PDPC filing before 31 Oct 2026; Play exact-alarm declaration; retention periods with counsel; Google appeal follow-up (when approved, re-run the Vertex test call, then do one real photo scan).
13. When the owner says so: fast-forward main to the release commit.

### Session 3 (release after): emotional redesign
14. Follow `docs/plan/EMOTIONAL-REDESIGN-GUIDE.md` packages E0 to E10 in order, one review and one commit each. Keep the workout video player and the Events tab as they are.

## Open follow-ups
- When a coach deletes her account, plans she shared (`plans/{clientUid}/coachPlans`) keep coachUid and coachName.
- Recipe titles "Salty fulling Breakfast" and "Yummy Egg Sandwich" in Rahma's recipe data need her review.
- Firestore rules suite had one unexplained flaky failure (445/1, then 446/0).
- Rahma's allergen confirmation for her 39 recipes; Rahma's end-of-workout lines.
