# Own Hub production release (public): master plan

Written 26 Oct 2026. This is the one ordered plan for the coding agent. Release 1.0.0 was the beta. This release goes to the public, and Rahma Mohsen coaches clients with it from day one. Evidence files (read them for detail, file:line and test lists): `docs/plan/audit-coaching-day-one.md`, `docs/plan/audit-food-and-voice.md`, `docs/plan/research-online-coaching.md`. Design layer: `docs/plan/EMOTIONAL-REDESIGN-GUIDE.md`. Resume state: `docs/plan/RESUME-ROADMAP.md`. Owner rules in `.claude/CLAUDE.md` apply to everything (no AI signs, no em dashes in product copy, Egyptian Arabic with feminine address, never weaken women-only verification or consent records, no push to main without the owner's OK).

## 0. Honest scope note
The audits found work that was not in the earlier estimate: voice logging is not built, the coach has no check-ins, no photo, video or voice in chat, no multi-client assign, no invite link, and calorie targets have no safety floors. Doing all of it correctly is about 5 to 7 working sessions, not 2. Do not cut the safety and accuracy items to hit a date. If a date matters, move the "Should have" items to the release after, never the P0 ones.

## 1. Order of work

### Phase 1: close what is open (session 1)
1. Find and fix the two failing tests (`training_reminders_test.dart:284`, `getting_started_test.dart:242`); fix batch A's review items (see RESUME-ROADMAP); review; full suites green.
2. Commit batch A and the kitten removal (two commits).

### Phase 2: coaching on day one (sessions 2 to 3). Goal: Rahma's whole week works inside the app, in few taps.
P0 (must ship):
| # | Capability | Smallest change (from the audit) | Taps target |
|---|---|---|---|
| C1 | Invite and share: Rahma sends her existing clients an invite and shares her profile link | expose `functions/coaching/invites.py` through a callable in `functions/main.py`; "Invite a client" button on `coach_space_view.dart`; app links (iOS associated domains, Android assetlinks, `site/.well-known/`) | 3 |
| C2 | Chat: photo and short video (form checks), voice notes, quick replies, read receipts | new message types in the chat model and `media.py` moderation path; `image_picker` exists; mic permission on both platforms; "Saved replies" row above the composer in `chat_thread_view.dart`, stored per coach, EN and Egyptian Arabic | reply 2 |
| C3 | Weekly check-in to the coach: 5 questions or fewer, 1-tap scales, optional photo, under 60 s for the client; Rahma reviews in one list | server-written weekly card in the thread opening a short form; "Needs attention" list for the coach (missed 2+ sessions, no check-in, health flag, unread) | 1 to open, 2 to reply |
| C4 | Build workouts in the app: search the exercise library, sets, reps, weight, rest, notes, superset flag, duplicate day, repeat last week, save as template | add weight, rest and notes fields to `coach_day_editor_view.dart` (model and server already carry them), "Duplicate day", templates seeded with her three plans | add exercise 2, duplicate 2 |
| C5 | Assign one plan to many clients and set a start date | multi-select at publish in `share_workout_view.dart` and `share_meal_plan_view.dart`, looping the existing publish callable | 3 |
| C6 | Programme with weeks (Week 1, Week 2) that the client's Today screen follows | verify `todaysWorkoutDay` with a multi-week plan, add week labels | 3 |
| C7 | Meals, recipes and meal plans she creates and sends: kcal and protein target, swap from an approved list in 2 taps, grocery list, her 39 recipes in the shared book (after her allergen sign-off), the client sees them natively in Eat and can log them in one tap | wire the live meal-plan flow; allergen sign-off first (`OWNER-TODO.md`); hide the old W07 | 3 to build a day |
| C8 | Coach profile and portfolio: photo, intro, credentials, packages, hide the empty reviews block | existing `coach_portfolio_view.dart`; hide "What members say" at zero reviews; correct the package price copy while payments are off | 1 message button |
| C9 | Intake with health flags: PAR-Q+ style screen, injuries, pregnancy and postpartum, eating history; any "yes" raises a flag and limits what plan can be assigned until she reviews; no calorie or macro targets for flagged eating-history answers | extend onboarding intake; K07 already shows flags on Accept | under 3 min |
| C10 | Reachability and safety: no screen reachable that looks like it publishes but is local only (old `coachplan` routes W04 to W09, K19 to K23); rate limits on chat, report and upload; push text decision (generic or first name) | trace every `goTo`, remove or gate; server limits | n/a |

| C11 | InstaPay payments, governed peer-to-peer (owner decision 26 Oct): full spec in `docs/plan/INSTAPAY-PAYMENTS-SPEC.md`; ships LIVE in this release (flag on, server kill switch); section 13 of the spec holds the anti-fraud design and screenshot verification; the owner and counsel steps in its section 12 must be done before submission | work orders WO-10a to 10p | pay in 4 taps, coach confirms in 2 |

Should have (cut these first if time forces it): progress photos and measurements (client controlled, private), habits, broadcast message, Rahma's own video per exercise (library), multi-week "repeat last week" polish.
Skip for now (later release): scheduling calendar, payments, community forum, branded storefront, wearables, AI plan generation.

Coach "better than the field" principles for every screen above: fewer screens than competitors, Arabic and RTL first, women-specific safety built in, read receipts and saved replies visible, one primary action per screen, everything natively inside the client's Home, Train, Eat and chat so she never leaves the app.

### Phase 3: food accuracy and voice logging (sessions 3 to 4)
Facts from the audit: "Say it" voice is not built (it refuses; no speech package, no iOS permission keys, Android strips RECORD_AUDIO); the sentence parser can double-count ("4 eggs" may log 8) and has no quantity cap; the parser has never run on the real 251-food pack; targets have no kcal floor and no pregnancy, breastfeeding, postpartum, under-18 or cycle logic (a small woman on "lose steadily" gets about 830 to 1,000 kcal); all food data is USDA only, two thirds of portion weights are estimated, the pack is marked "pending dietitian review", and everyday words like "عدس" and "بطاطس" resolve to raw foods.
| # | Work | Done when |
|---|---|---|
| F1 | Fix the sentence parser: counts, "اتنين", Arabic-Indic digits, halves, caps, grams route, cooked defaults for lentils and potatoes, attached waw | the corpus in `audit-food-and-voice.md` section 5.4 (60+ phrases, EN and AR) passes against the real food pack |
| F2 | Build voice logging: on-device speech to text where available (iOS Speech with `ar-EG` and `en`, Android SpeechRecognizer), a mic button on E02, parse, show every item as an editable chip with its kcal, one tap to confirm; permission prompts at first use with a one-sentence reason; works offline where the OS allows; clear fallback to typing | tap-count test (speak, confirm: 3 taps); permission, denied, no-speech, noise and unknown-food tests; iOS `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`, Android `RECORD_AUDIO`; privacy policy, App Store privacy answers and Play data safety updated for audio (no audio stored unless the owner decides otherwise) |
| F3 | Calorie and macro safety: kcal floor (common default 1,200 for adult women), no deficit under 18, none while pregnant or breastfeeding, extra kcal for lactation and later pregnancy per WHO or national guidance, protein cap per kg, fat and carb sanity | 20 hand-computed profiles match; the floors have tests; owner decisions in section 3 below made first |
| F4 | Accuracy of the data: golden table of 60+ foods against independent sources (USDA, WAFCT 2020, the Egyptian National Nutrition Institute tables, product labels, five dishes weighed in Rahma's kitchen); property tests on all foods (macros sum to kcal within tolerance, scaling linear, unit round trips, S < M < L, no duplicate aliases); dietitian sign-off to remove "pending review" | golden CSV committed; property tests in CI; dietitian signature recorded |
| F5 | Photo scan: when Google approves the appeal (ticket 67P3AQYUEJ7Z3QH6KJRFZSMSVA), run the test call and one real scan; until then the screen says it is unavailable and the release notes do not promise it | verified or hidden |

### Phase 4: batch B and the release-wide polish (session 5)
Batch B: guest first workout (D62) with "Keep this workout", C08 for coaches only, one step counter, prefill; the walking session with very clear calorie logging; rewards without a mascot (personal-best haptic, one warm R10 line, copy audit).
Sound and animation: pull these into the release: E1 (motion tokens), E1b (sound, synthesised originals, Profile switches), E2 (moments library), then wire M3, M4, M5, M8, M10 only. The rest of the redesign packages (E3 to E10) follow in the release after, per `EMOTIONAL-REDESIGN-GUIDE.md`. The video player and Events tab stay as they are.

### Phase 5: full test program (session 6, runs alongside phases 2 to 4)
Every feature has tests at three levels; nothing ships with a feature that lacks one.
| Area | Required cases |
|---|---|
| Voice and food | corpus of 60+ phrases EN and AR; golden table; property tests; kcal floors; offline; denied permission; noisy and empty input; "500 eggs"; Arabic-Indic digits; undo of the last log |
| Targets | 20 profiles by hand; extremes; pregnancy, postpartum, under 18, eating-history gate |
| Coaching | chat send, receive, media, voice, quick replies, read receipts, moderation and screening hold; invite and join; intake flags block assignment; assign to many; duplicate day; multi-week plan reaches Today; client logs a coach meal in one tap; check-in loop; needs-attention list; account deletion keeps or removes data per policy; Rahma removed client; block and report |
| Workouts | start, log set, undo, rest, finish, next-time weights, walking session, guest first workout, keep workout |
| Money and legal | payments off everywhere; consent records, 18+ tick on approvals, women-only check, deletion and export |
| Platform | iOS and Android: permissions (camera, mic, speech, notifications), push delivery and tap targets, app links, widget, offline, low memory, small screens, 200% text, Arabic RTL, dark where supported |
| Non-functional | cold start, scroll jank on a mid-range Android, battery, install size, crash-free session on a 30-minute scripted walk |
| Existing suites | flutter, pytest, Firestore and storage rules, admin-web, E2E; `app/tool/release_preflight.sh` all PASS |
Device evidence (haptics, sound mixing, Reduce Motion, speech, push) is collected on real phones: an iPhone and a mid-range Android; the iOS 26 simulator cannot run the app, so use the Android emulator `ownhub_pixel8` and real devices.

### Phase 6: release prep, both stores (session 7)
- Version 1.1.0 in `app/pubspec.yaml`; "What's new" EN and AR; screenshots retaken (6.9-inch iOS, Play sizes) with Rahma's frames from `~/Downloads/IMG_1498.MOV`.
- iOS: `app/tool/build_ios.sh`, Transporter upload, TestFlight test, App Store Connect: new privacy answers (microphone, speech, photos and video in chat), review notes (test number, women-only check explained, scan note), submit in place of 1.0.0.
- Android: first Play release is not started. Needs the Play developer account, app signing, data safety form (audio, photos, health data), exercise alarm declaration, content rating, target audience (adults), 12-tester closed test if the account type requires it, store listing files (`docs/release/play-listing.md` is stale for no-account text), release notes.
- Server deploy order: functions, storage rules, dashboard within minutes, re-add pre-approved numbers with the 18+ tick, website (privacy policy changes only go live on deploy), the app last.
- Owner reminders: PDPC filing before 31 Oct 2026; retention periods with counsel; Rahma's allergen confirmation for her 39 recipes; the Google appeal; Rahma's account approved by a woman reviewer.
- Final: one last review, all suites green, push the feature branch, then fast-forward main only on the owner's go.

## 2. Day-one checklist for Rahma (acceptance)
She can, inside the app: sign in as a coach; share her link and invite clients; accept a client after seeing health flags; chat by text, voice, photo and video with saved replies; build a workout and a meal plan from templates in a few taps and send them to one or many clients; see weekly check-ins and who needs attention in one list; edit her portfolio; and her clients see everything natively on Home, Train and Eat, log it in one tap, and message her. A scripted run of this whole list on both platforms is the sign-off.

## 3. Owner decisions needed before building the affected items
1. Calorie floor and the policy for pregnancy, breastfeeding, under 18 and cycle (default proposed: 1,200 kcal floor, no deficit for under 18, pregnant or breastfeeding; refer to a doctor).
2. Eating-history answers: block calorie and macro targets and send to Rahma (proposed yes).
3. Voice logging privacy: process speech on the phone only and store no audio (proposed), or allow cloud recognition with consent.
4. Chat media: moderation rule for photos and videos (hold until reviewed, or send and screen after), and retention.
5. Push text: generic, or the sender's first name.
6. Who signs off the nutrition data (a dietitian) and when.
7. Whether the sound and animation package ships in this release (proposed yes).
