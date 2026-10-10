# Own Hub: session handoff (local only, never commit)

Updated 6 Oct 2026. Read this first in any new session opened in ~/ownhub.

## The project
- Own Hub (project name "ownhub"): women-only fitness app for Egypt. Flutter app + Python Firebase functions (project `own-hub`, region europe-west3). English and Arabic (MSA, RTL).
- Folder: ~/ownhub (renamed from ~/womens-fitness-app-wireframe). Repo: github.com/Mahmoudrda/own-hub.
- Bundle ID everywhere: `com.ownhub.app`. Widget extension: `com.ownhub.app.OwnHubWidgets`. App Group: `group.com.ownhub.app`.
- Publisher: Mahmoud Reda. Brand face and voice: Rahma Mohsen (a real coach). Never mix the two.

## Where the work is
- Active code: worktree ~/ownhub/.claude/worktrees/onboarding, branch `onboarding/2026-10-06`, pushed to GitHub at bf4b076 (7 Oct 2026). main untouched.
  - Contains: tour-first onboarding + release compliance, iOS widgets, kitten mascot, ready-to-deploy website (site/, deploy.sh), Firebase Analytics + Crashlytics behind opt-in, admin console (dashboard, logs, content to Firestore, events, workout library, media upload tool).
  - Verified 7 Oct 2026: 5,224 app tests, 1,225 functions tests, 322 rules tests, Android + iOS build; no advertising ID on either platform (iOS store builds must set FIREBASE_ANALYTICS_WITHOUT_ADID=true, which tool/build_release.sh does).
- Live backend: first deploy verified 6 Oct 2026. The admin/events/workout rules, indexes and functions (admin_dashboard, admin_logs) are NOT deployed yet: owner task in the sheet.
- Owner's task sheet: ~/OwnHub-Launch-Tasks.xlsx (the old copy in ~/Downloads is superseded). Regenerate with ~/.claude/jobs/9eda914b/tmp/make_sheet_v2.py + carry_over.py if that folder still exists.
- Reports: ~/ownhub/.claude/onboarding-audit/, ~/ownhub/.claude/release-compliance/, ~/ownhub/.claude/feature-briefs/.

## Owner rules (always)
- Local first: no commit or push without the owner's explicit OK. Never push to main.
- No AI signs in the repo: no AI comments, no planning markdown, no AI attribution lines.
- Product copy: no em dashes (use a comma, a full stop or a middle dot). Write UI copy yourself; strings go through app/tool/add_strings.py in English and Arabic MSA (feminine address, Western digits).
- Never weaken women-only verification or legal consent records.

## Mascot
Done and merged (A1 rose kitten, pure Flutter, see app/lib/ui/hand/mascot). Rules for any change: ~/ownhub/.claude/release-compliance/mascot-research.md.
