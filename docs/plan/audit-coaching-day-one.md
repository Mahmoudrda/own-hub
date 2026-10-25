# Coaching audit for Rahma, day one (branch feat/motivation-2026-10-13, dirty tree)

Method: graphify query, then reading code. No app was run; "works" means the code path exists, is wired in a route and has tests. Tap counts are counted from code, not measured. Paths are under ~/ownhub. Evidence is partly from l10n key lists per screen file, so a feature absent from the key list is "missing" only to that level of proof.

Two coach codebases exist side by side. The live one is `app/lib/features/private_coaching/` plus `functions/coaching/` (server-backed, tested). The older one is `features/coach/`, `features/coachplan/` and `app_state/coaching_desk_state.dart` (wireframe-era, local state; its header says "nothing is seeded"). `routing/app_router.dart` still routes both (W04 to W09 and K19 to K23 use the old desk state; W01, W02, W03, W06, W10, K07, K16, K18 use the live one, lines 4983-5079). Treat the older screens as unverified or dead for day one.

## Status table

Legend: works = wired, server-backed, tested. partial = exists with a limit that matters to Rahma. missing = no code found. unclear = could not verify.

### (a) Chat

| Capability | Status | Taps today | Evidence |
|---|---|---|---|
| Text, coach and client | works | Coach: Clients tab, chat row, type, send = 3. Client: My coach, Message, type, send = 4 | `presentation/chat/chat_thread_view.dart:525` (2000 chars), `chat_thread_controller.dart`, `functions/coaching/chat.py:151` |
| Chat rules shown once before client's first message | works | +1 once | `chat_thread_view.dart:165-193`, `chat.py:224 accept_rules` |
| Contact/payment/link screening of text (hides message server-side) | works | 0 | `chat.py:65-140`; counts like "12 10 10 8" are exempt, `chat.py:55` |
| Voice notes | missing | n/a | `MessageType` has text, recipe, workoutPlan, mealPlan, session, system only (`domain/chat_message.dart:9-16`). No audio package in `app/pubspec.yaml`. Android manifest removes RECORD_AUDIO (`AndroidManifest.xml:30`) |
| Photos / video in chat (form checks) | missing | n/a | no image_picker use in `presentation/chat/`; image_picker only in `apply/apply_photo.dart:9`. RELEASE-2-PLAN 3.6 item 6 lists form-check media as "later" |
| Read state | works | 0 | ticks sent/delivered/read `chat/chat_logic.dart:35-38`, `chat_bubbles.dart:23`, `watchOtherReadAt` `chat_thread_controller.dart:112`, `chat.py:258 mark_read` |
| Unread counts / filter | works | 1 | `desk/clients_view.dart` (Unread filter), `unreadFor.{uid}` `chat.py:38` |
| Push on new message | works, generic | 0 | `chat.py:211 notify(recipient,"newMessage")`, throttled once per 3 minutes (`coaching_contract.json:44`). Body is "You have a new message." with no sender or text by design (`push.py:49`). Token sync `app_state/push_registration.dart:247-297` |
| Quick replies / saved replies | missing in the live app | n/a | Only `features/coachplan/presentation/coach_inbox_view.dart:41-109` (`onOpenSavedReplies`); no caller found for it in any route. Live thread has no canned-reply control (`chat_sheets.dart` offers share recipe/workout/meal/session and copy/report only) |
| Share recipe / workout / meal plan / live session card from chat "+" | works | 2 to open sheet and pick, then the editor | `chat/chat_sheets.dart:90-114` |
| Report a line, block | works | 2 | `chat_sheets.dart` line sheet, `member/report_coach_sheet.dart` |
| Chat read-only after coaching ends | works | 0 | `end_coaching_sheet.dart`, tests `client/my_coach_end_test.dart`, `desk/desk_end_test.dart` |
| Tests | works | | `app/test/features/private_coaching/chat/` (controller, logic, views incl. Arabic and 2.0 text scale) |

### (b) Custom workouts

| Capability | Status | Taps | Evidence |
|---|---|---|---|
| Exercise library to pick moves | works | Client page, Share a workout, pick start, Edit days and moves, Add moves, pick = about 6 to the first move | `plans/share_workout_view.dart:5-8,32-40` (uses `move_picker_view.dart`, `exercise_library.dart`, clip player) |
| Sets, reps, hold seconds per move | works | 1 to 2 per change | `plans/coach_day_editor_view.dart` (keys: sets, reps, holdInSeconds, remove, earlier/later); server bounds `plans.py:40-52` |
| Rest per move | partial | n/a | Stored (`coach_plan_logic.dart:109,201`, `plans.py MAX_REST`) but no rest control in the day editor key list. Defaults 60s, 45s if timed |
| Target weight (kg) per move | partial | n/a | Model and server accept `kg` (`my_plan.dart:67-76`, `plans.py:59,182-184`; kept in `coach_plan_logic.dart:152,222`) but no weight control found in `coach_day_editor_view.dart` or `share_workout_view.dart`. Unclear whether `plan_editor_view.dart` exposes it; not verified |
| Per-move notes | unclear | | `notesEn/notesAr` carried (`coach_plan_logic.dart:202`); no note field in the day editor key list. Plan-level "note" exists only on the meal plan (`noteForHerIfYouLike`) |
| Duplicate / copy day or week | missing in live flow | n/a | Copy week exists only in old `coachplan/copy_week_view.dart` (W05, old desk state). Live editor has move earlier/later and remove only |
| Templates | works | Save: 1 tap on "Save as a template" at publish; reuse: pick under "Your templates" | `share_workout_view.dart` l10n saveAsATemplate, yourTemplates, templateSaved; `coach/coach_templates.dart` (package templates). Workout template store is on the coach's phone: unclear if synced across devices |
| Start from one of the three splits or blank | works | 1 | `share_workout_view.dart:4-6` |
| Multi-week programme | partial | n/a | A plan is a list of days (`plans.py _PLAN_KEYS = source,name,revision,days`); no week dimension. Re-publish makes a new revision. A "month planner" exists only in the old desk (W03/W04/W05/K19/K20) |
| Assign to one client | works | from client page: Share a workout = 1 tap | `routing/app_router.dart:5049 ShareWorkoutScreen(subId)`, `coaching_wiring.dart:304` |
| Assign to several clients at once | missing | n/a | Route takes a single `subId`; `plans.py` writes `plans/{clientUid}/coachPlans/{planId}` for one client. Workaround: template then repeat per client (about 6 to 8 taps each) |
| Preview as client sees it, publish, republish as new version | works | 2 | `share_workout_view.dart` l10n seeItFirst, publishAsANewVersion |
| Client sees it on Home / Train, starts it | works | Home card then Start: 1 to 2 | `client/coach_home_card.dart:28-62`, `client/coach_plan_view.dart:210-241` (filled "Start this workout" for today only), `client/my_coach_view.dart`. Plan is blocked from start when it conflicts with her health constraints (`held`, `coach_plan_view.dart:210`) |
| Push to client when a plan is shared | works | 0 | `push.py "planShared"` |
| Tests | works | | `private_coaching/plans/plan_screens_test.dart`, `plan_logic_test.dart`, `app/test/journeys/custom_workout_journey_test.dart` (member side) |

### (c) Portfolio / profile and how a woman finds and joins her

| Capability | Status | Taps | Evidence |
|---|---|---|---|
| Edit portfolio: photos, bio/approach, credentials, results | works | Profile, Become a coach / coach home, Portfolio = 3 to open | `coach/portfolio_edit_view.dart`, `portfolio_media_view.dart`, `media_add_view.dart`, `coach_photo.dart`; certificates `functions/coaching/certificates.py`; photos are staff-moderated before showing (`media.py`, `moderation.py`) |
| Packages (price, duration, includes, sessions, check-ins per week) | works | 3 | `coach/package_edit_view.dart`, `packages_view.dart`, `functions/coaching/packages.py:23-57` |
| Package editor price text | partial (known contradiction) | | RELEASE-2-PLAN 3.6 / D63: editor says "Members see EGP price x 1.15" while decision is coach pays commission; plan marks server and editor change as pending. Payments are off (`functions/coaching/__init__.py:22 COACH_PAYMENTS_LIVE = False`), so the portfolio shows "free for now" |
| Preview "this is how members see you" | works | 1 | `coach_space_view.dart` onPreviewPortfolio (route app_router.dart:4987) |
| Reviews | partial | | UI section "What members say" exists (`member/coach_portfolio_view.dart`); reviews are meant to come only from paid in-app coaching (RELEASE-2-PLAN 3.6 item 3). With payments off, expect none on day one. Review write path not verified |
| Reply-time badge ("usually replies within N hours") | works | | l10n usuallyRepliesWithinNHours in portfolio and find views |
| Approval to appear at all | works, gated | | Rahma applies in app (`apply/*`, Profile > Become a coach), a woman reviewer approves in dashboard Coaches tab, which mints `coachV` (`functions/coaching/applications.py:554`, `docs/owner/LAUNCH-GUIDE.md:26`). Her own account cannot approve herself unless she also holds the reviewer role: unclear |
| How a woman finds her | works | Train, Find a coach, 3 quiz questions, pick, Ask to join = about 8 to 12 by code; plan says "about 20" today with target 8 (`RELEASE-2-PLAN.md:35`) | `member/find_coach_view.dart`, `coach_directory_controller.dart`, `coach_portfolio_view.dart`, `join_coach_sheet.dart` |
| Join request carries intake and health questions | works | Join sheet: goal, level, days, place, 8 health yes/no, 2 ticks, send | `member/join_coach_sheet.dart` (l10n lists PAR-Q-style questions, consent ticks). Not prefilled from onboarding (RELEASE-2-PLAN D, still open) |
| Rahma's own share link / deep link | missing | n/a | Desk empty state says "share your portfolio link" (`desk/coach_desk_view.dart:273`) but no share control and no app-link handling found: no intent-filter data host in manifest grep, no `site/.well-known/`, no app_links dependency. Server has invite codes (`functions/coaching/invites.py`) but I found no callable in `functions/main.py` and no coach-side UI that creates one; only `features/signup/presentation/invite_code_sheet.dart` on the member side. Treat as missing |
| Featured placement, women-only search | unclear | | not verified |

### (d) Meals, recipes, meal plans

| Capability | Status | Taps | Evidence |
|---|---|---|---|
| Share a meal plan to one client (days x slots of recipes, foods in grams, free text, per-item note) | works | Client page, Share a meal plan, set days, add items, name, publish = about 8 minimum | `plans/share_meal_plan_view.dart` (l10n: howManyDays, addToSlot, recipes, foods, grams, servingsN, herChoice, noteForHerIfYouLike), `plans.py:35-58` |
| Macros shown on the plan | works, client-side | | Server rejects nutrition keys (`plans.py:56 NUTRITION_KEYS`); the phone computes figures from the verified food pack and recipe library (`share_meal_plan_view.dart` figuresComeFromOwnHubsFoodTables, someItemsHaveNoFigures). The coach cannot type her own macros |
| Allergy guard in coach editor | works | | blocks/marks items against her intake allergies (`share_meal_plan_view.dart`, `client/coach_meal_row.dart:296 flagMealPlan`) |
| Rahma's own new recipe created in the app | missing in live flow | n/a | Only old `coachplan/create_meal_view.dart` (W07, old desk state). The live picker uses the shared recipe book (`coach_plan_logic.dart MealCatalog:346`). Recipes are a library (Rahma's 39 recipes; allergen sign-off pending `OWNER-TODO.md:99`) |
| Meal templates | works | 1 to save | saveAsATemplate / yourTemplates |
| Several clients at once | missing | | same single-`subId` limit as workouts |
| Client sees in Eat and logs it | works | Eat, coach meal row, "Log this" = 1 per item, allergy check with undo | `client/coach_meal_row.dart:68,194`, `coach_plan_view.dart:109-110` |

### (e) Intake, health flags, check-ins, photos, measurements, desk, approvals, schedule

| Capability | Status | Taps | Evidence |
|---|---|---|---|
| Client intake at join | works | see (c) | `join_coach_sheet.dart` |
| Health flags to the coach | works | Open request card = 1 | `desk/coach_desk_view.dart:394-487`; Accept on a flagged request goes through the details sheet first (`:242`, fix from RELEASE-2-PLAN safety item is present) |
| Accept / decline with reason; "my places are full" | works | 1 to 2 | `coach_desk_view.dart` (accept, decline, whyAreYouDeclining, myPlacesAreFull), `functions/coaching/receiving.py` |
| Coach desk K07: new requests, waiting for reply, ending soon, unread, follow-ups | works | 0 to see, 1 to open | `desk/coach_desk_view.dart`, `desk_model.dart`, tests `desk/desk_*_test.dart` |
| Clients list with search, filters | works | 1 | `desk/clients_view.dart` |
| Client detail: answers, private note (stays on this phone), plans shared, sessions | works | 1 from desk | `desk/client_detail_view.dart` (saveNote, yourPrivateNote, staysOnThisPhoneOnly). Private note is local-only: lost on a new phone (unclear if intended) |
| Weekly check-ins (form plus optional photo) | missing | n/a | `checkInsPerWeek` is only a package number (`packages.py:26,57`). No check-in form, answer, or review code in `private_coaching/` or `functions/coaching/` (grep for check-in, progress photo, measurement found nothing outside that field). RELEASE-2-PLAN 3.6 item 4 lists it as planned. The old `coachplan/review_view.dart` (W09) shows "her week from her logs" but runs on the old desk state |
| Progress photos / measurements shared with coach | missing | n/a | Same grep. Member-side progress features exist (`features/progress/`) but nothing sends them to a coach |
| What coach sees of client training (adherence) | partial | | Plan-share history listed; log-sharing to coach not verified. Old W09 review may be the only consumer |
| Schedule a live session (propose, client confirms) | works | Client page, Schedule, pick date/time/minutes, send = about 4 | `plans/schedule_session_sheet.dart`, `functions/coaching/sessions.py`, push `sessionProposed`; call link via `domain/session_link.dart`. Video call is external link (no in-app call) |
| Coach availability calendar | partial | dashboard only | admin-web Calendar tab "My availability" (`admin-web/index.html:99-124`); relation to the in-app schedule sheet not verified |
| End coaching, refunds | works / payments off | 2 | `end_coaching_sheet.dart`, `functions/coaching/refunds.py` |
| Earnings view | partial | | `coach/` `features/coach/presentation/coach_earnings_view.dart` (K17) routed at app_router.dart:5229; payments off so empty |

### (f) Dashboard vs in-app (admin-web/ is the staff/reviewer tool, not a coach tool)

| Task | Where | Evidence |
|---|---|---|
| Approve coach applications, check certificates, moderate portfolio photos | dashboard only (Coaches tab, hidden unless role) | `admin-web/index.html:30,211`, `admin-web/coaching.js` (mountCoaching, decisions approve/reject/decline/refund) |
| Verify women, pre-approve phones, adult-proof tick | dashboard only | `index.html:24-26,79,127-137` |
| Upload exercise clips, foods, events | dashboard only | tabs Exercises, Foods, Events |
| Payments, refunds, payouts, reports (reported chats are read only after a report) | dashboard only, hidden/payments off | tabs payments, refunds, payouts, reports |
| Everything about clients, chat, plans, meals, sessions, packages, portfolio | in app only | no coach client management in admin-web (`coaching.js` has none) |

Implication: Rahma never needs the dashboard to coach once approved, but she cannot do client work on a laptop; everything is on her phone. Dashboard 2-step staff sign-in is still an open follow-up (memory file).

### (g) Android parity

| Item | Status | Evidence |
|---|---|---|
| Same code path for all coaching screens | works (Flutter) | single codebase; no platform branches seen in `private_coaching/` |
| App id and signing | partial | `com.ownhub.app`, release keystore read from uncommitted `android/key.properties` (`build.gradle.kts:13-26`); compile/target SDK 36, min 24 (`build.gradle.kts:52-67`). Memory notes say Android not started |
| Push | partial | FCM token code is shared (`push_registration.dart`), `google-services.json` present, POST_NOTIFICATIONS declared (`AndroidManifest.xml:40`) and asked only on her tap. Default notification icon/channel meta at `:155`. Not tested on a device; production APNs equivalent for Android not applicable |
| Permissions | works, but blocks voice | CAMERA declared (`:9`); RECORD_AUDIO, READ/WRITE_EXTERNAL_STORAGE and ad-id permissions removed (`:24-32,59-65`). Voice notes would require re-adding RECORD_AUDIO and a Data safety update |
| Exact alarms | partial | SCHEDULE_EXACT_ALARM declared (`:52`); the Play declaration is an open owner step (memory, launch pass) |
| Play listing / Data safety | stale | `docs/release/play-listing.md` stale (no-account text), per memory |
| App links to coach profile | missing | no verified-host intent filter, no assetlinks file in `site/` |
| iOS simulator can't run the app | n/a | use Android emulator `ownhub_pixel8` (memory) |
| Android coaching tests | unclear | no Android-specific coaching tests found; shared Flutter tests only |

## Prioritized day-one gap list (smallest change that closes each)

P0 means Rahma will hit it in her first week. Estimates are by relative size, not time.

1. P0 No weekly check-in or progress photos/measurements to the coach (e). It is the retention driver the plan names, and `checkInsPerWeek` on a package promises it. Smallest change: reuse chat as the carrier. Add a server-written weekly "check-in" system card in the thread that opens a short form (three sliders and one note); store under `relationships/{relId}/checkIns/{weekKey}`; list it on `client_detail_view.dart`. Skip photos and measurements for day one, or send one photo through the existing portfolio photo upload path.
2. P0 No photo/video/voice in chat (a). Form checks are the first thing a coach asks for. Smallest change: one new message type `image` using `image_picker` (already a dependency) and the existing upload and moderation path in `media.py`; the screening rule must hide it until reviewed or accept risk. Voice and video later (needs RECORD_AUDIO on Android and a Data safety edit). Interim: Rahma asks for a video link; link screening in `chat.py` may block it, so decide first whether to allow a short allow-list.
3. P0 Cannot assign one plan to several clients, and no copy/duplicate of days (b). Smallest change: in `share_workout_view.dart` and `share_meal_plan_view.dart` add a multi-select of her clients at publish, looping the existing publish callable per client (no server change). Add "Duplicate day" to `coach_day_editor_view.dart` (clone a `MyDay`, there are already move helpers in `coach_plan_logic.dart`). Until then use templates.
4. P0 Quick replies missing in the live thread (a). Smallest change: a "Saved replies" row above the composer in `chat_thread_view.dart` fed from a list in coach templates (`coach/coach_templates.dart` pattern, stored on-phone); tapping inserts text. Send still goes through screening.
5. P1 No way to share her own profile link or invite her existing clients (c). Today she is found only by search. Smallest change: expose the existing `invites.py` through a callable in `functions/main.py` (check first that it is absent), add one "Invite a client" button on `coach_space_view.dart` that shares the code text with the OS share sheet; the web page at `own-hub.app/c/{code}` can be a static redirect to the store. App links can wait.
6. P1 Per-move weight, rest and notes not editable in the live day editor (b). Model and server already carry them (`my_plan.dart:67`, `plans.py:59,182`, `notesEn/notesAr`). Smallest change: three small fields in `coach_day_editor_view.dart` writing to existing `targetKg`, `restSeconds`, `notes`. Verify first whether `plan_editor_view.dart` already offers them to the coach (I could not confirm).
7. P1 Multi-week programme (b). Smallest change: label several days in a plan "Week 1 / Week 2" and publish as a plan with 14 days; the client app's `todaysWorkoutDay` logic would need checking (not verified). Real weeks belong in release 2.
8. P1 Push text is generic (a). By design, but for a coach with 10 clients "You have a new message" gives no triage. Smallest change: none now; add the sender first name only if the privacy review allows (decision for owner).
9. P1 No coach-created recipes in the live flow (d). Smallest change: Rahma's 39 recipes go in the shared recipe book, so day one works with those; do the allergen sign-off first (`OWNER-TODO.md:99`). Do not wire the old W07.
10. P2 Private client notes are phone-local only (e). Smallest change: say so in the UI (it does: "stays on this phone") and add iOS/Android backup later; no code for day one.
11. P2 Package editor still says price x 1.15 while the commission decision changed (c). Smallest change: copy and `finalPrice` change listed in RELEASE-2-PLAN 3.6; hide prices while payments are off (already "free for now").
12. P2 Reviews will be empty on day one (c). Smallest change: none; accept, or hide the "What members say" block when there are zero reviews (check what it shows now).
13. P2 Android: voice and app links need manifest and Play console work (g). Not needed for day one unless item 2 includes voice.
14. P2 Remove or hide the old coachplan routes (W04-W09, K19-K23) that run on local state, so Rahma cannot reach a screen that appears to publish but does not (`app_router.dart:5635-5860`). Check reachability from the live UI first; I did not find a live link into them but did not trace every `goTo`.

## What I could not verify
- No device or emulator run; no coverage numbers; whether the full test suite is green on this dirty tree.
- Whether `plan_editor_view.dart` (shared with members) exposes weight, rest and notes to the coach editor.
- Whether any live screen still navigates into the old desk screens, and whether those publish to the server.
- Whether Rahma's account can both hold `coachV` and be approved by herself or by a second reviewer (a woman reviewer is required, per LAUNCH-GUIDE).
- Review write path, featured placement, calendar link to the in-app scheduler, and server enforcement of the coach rate limits (open follow-up in memory: "chat/report/upload rate limits").
- The wording of every Arabic string.
