# Own Hub release 2 plan: one clear next step, warmer moments, coaching that stays in the app

Status: plan, not built. Written 23 October 2026 against commit `178b0dc` on `feat/motivation-2026-10-13` (release 1.0.0, build 424738, submitted to App Review). Line numbers drift: re-find every reference before editing.

## 0. How to use this plan (coding agent)

- Owner rules that always apply: no commit or push without the owner's explicit OK, never push to `main`; no AI comments, planning labels or attribution lines in code or commits; product copy has no em dashes; every string goes through `app/tool/add_strings.py` in English and Egyptian Arabic (feminine address, Western digits) and re-adding an existing English key overwrites its Arabic; never weaken women-only verification or legal consent records; no streak pressure, guilt, missed-day counts or body-shaming (DECISIONS D37); never write in Rahma's voice unless she approved the line.
- Work in the order of section 6. Each item lists its evidence, the files, what to change, and how to prove it. An item is done only when its acceptance checks pass and the full `flutter test`, `flutter analyze`, pytest, rules suites and `admin-web` tests are green.
- Paths are relative to `app/lib/` unless they start with `app/`, `functions/`, `firebase/`, `admin-web/` or `site/`. `R:` means `routing/app_router.dart`.
- Screen ids: T01 Home, T06 Home day one, R01 Train, R03 Workout day, R07 Set, R09 Rest, R10 Finished, R13 Move logged, E01 Eat, E06 Recipe, P01 Insights, P03 Bests, A01 Notifications, O01-O06 onboarding, C06-C14 sign-up and verification, H01-H06 member coaching, K01-K18 coach, W01-W10 coach tools.

## 1. What the evidence says

The owner asked whether apps like Duolingo and Strava feel easy because they give one option at a time. The evidence says: partly. What works is four things together.

1. **One clear next step that is chosen for her, with other options one tap away.** Duolingo replaced its skill tree with a single path because learners were unsure they were using the app "the correct way" ([Duolingo blog](https://blog.duolingo.com/new-duolingo-home-screen-design)); Strava preselects the last sport so recording is 2 taps ([Strava support](https://support.strava.com/en-us/articles/15402137-recording-an-activity)); Fitbod and Ladder hand her today's workout ([Fitbod](https://fitbod.me/blog/how-fitbods-ai-knows-exactly-when-you-should-lift-heavier-and-when-to-recover/)); Peloton shows one Top Pick with up to 6 swaps ([Peloton](https://onepeloton.com/blog/personalized-workout-plan)). Removing choice entirely backfired for Duolingo with some users; the average effect of "choice overload" across 63 studies is about zero ([Scheibehenne 2010](https://ideas.repec.org/a/oup/jconrs/v37y2010i3p409-425.html)), but it appears when the task is hard, she is unsure, or wants low effort ([Chernev 2015](https://www.kellogg.northwestern.edu/faculty/research/detail/2015/when-product-assortment-leads-to-choice-overload-a-conceptual)): a tired woman choosing a workout.
2. **Very low effort.** Moving sign-up later gave Duolingo about +20% daily active users ([First Round](https://review.firstround.com/the-tenets-of-a-b-testing-from-duolingos-master-growth-hacker)); effort of reliable food entry is a main reason people stop logging ([Cordeiro, CHI 2015](https://my.eng.utah.edu/~cs5540/au16/readings/PersonalInformatics-Cordeiro2015.pdf)); Fogg: behaviour happens when motivation, ability and a prompt meet, and ability is the reliable lever ([behaviormodel.org](https://behaviormodel.org/)).
3. **An immediate reward.** Duolingo's streak milestone animation: +1.7% day-7 retention for new learners ([Duolingo](https://blog.duolingo.com/how-duolingo-streak-builds-habit)); peak-end rule: people remember the peak and the end, and a gentler ending improves memory and return ([Kahneman 1993](https://ius.uzh.ch/dam/jcr:5ae9adc9-61ec-4174-b37c-4b752f36c23b/Kahnemann%20et%20al.%20-%20When%20More%20Pain%20is%20Preferred%20to%20Less%20(1993).pdf), [Redelmeier 2003](https://pubmed.ncbi.nlm.nih.gov/12855328/)).
4. **A reason to come back, without guilt.** Forgiving mechanics retain: Streak Freeze +0.38% daily active learners, Weekend Amulet 4% more likely to return a week later ([Duolingo](https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals)); a broken streak lowers later engagement most when people blame themselves, less when it can be repaired ([Silverman and Barasch 2023](https://udspace.udel.edu/items/42ce576b-8e1f-429a-8541-e29e48dbcfbb/full)); about half of 141 lapsed Fitbit users felt guilty ([UW](https://www.washington.edu/news/2016/09/08/life-after-fitbit-appealing-to-those-who-feel-guilty-vs-free/)); Gentler Streak keeps the streak through rest and sick days and won Apple's 2024 Design Award for Social Impact ([App Store](https://apps.apple.com/us/app/gentler-streak-workout-tracker/id1576857102)); watchOS 11 lets people pause rings without losing the streak ([MacRumors](https://macrumors.com/2024/09/16/apple-releases-watchos-11)). Missing one day does not materially hurt habit formation (median 66 days, [Lally 2010](https://www.ucl.ac.uk/news/2009/aug/how-long-does-it-take-form-habit)).

Emotional design (Norman's visceral, behavioural, reflective levels; Walter's functional, reliable, usable, pleasurable): delight works only on top of a reliable, usable product ([Norman](https://en.wikipedia.org/wiki/Emotional_Design), [Walter](https://uxdesign.cc/designing-for-emotion-a-book-review-9b73d81be97d)). Self-determination theory: autonomy and competence predict long-term exercise adherence ([Teixeira 2012](https://doi.org/10.1186/1479-5868-9-78)). Health framing beats appearance framing for women with body-image concerns ([Ohio State](https://news.osu.edu/some-women-benefit-more-from-exercise-when-emphasis-is-on-health-not-appearance/)). In Egypt, the top barriers among 760 working women were energy (80.4%), resources (74%), willpower (69.6%) and time (69.4%) ([PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC11726727/)): short, low-effort sessions and a women-only space answer real needs.

Honest counter-evidence: guilt and loss do lift engagement elsewhere (Duolingo's staged mascot "death" in 2025, [TechCrunch](https://techcrunch.com/2025/02/18/duolingo-killed-its-mascot-with-a-cybertruck-and-its-going-weirdly-well); loss-framed step incentives 45% vs 30%, [Penn Medicine](https://pennmedicine.org/news/news-releases/2016/february/to-encourage-physical-activity)). Own Hub's no-guilt rule (D37) is a wellbeing choice: keep it and measure it (section 5).

Reference screens (official App Store screenshots, downloaded 23 Oct 2026, local copies in `.claude/feature-briefs/references/app-store/`, not in git): [Duolingo](https://apps.apple.com/us/app/duolingo-learn-languages/id570060128) (one task per screen, a progress bar, one answer area, only an X to leave), [Strava](https://apps.apple.com/us/app/strava-run-bike-walk/id426826309) (record opens on the map with the sport preselected), [Hevy](https://apps.apple.com/us/app/hevy-workout-tracker-gym-log/id1458862350) (previous weights beside each set, one tick per set, a one-line next-session hint), [Fitbod](https://apps.apple.com/us/app/fitbod-gym-fitness-planner/id1041517543) ("My Plan: Push Day" with one Switch, duration and gym chips), [Nike Training Club](https://apps.apple.com/us/app/nike-training-club/id301521403), [Flo](https://apps.apple.com/us/app/flo-cycle-period-tracker/id1038369065) ("Period in 2 days" with one "Log period" button).

## 2. Where Own Hub stands (measured from code and screenshots, 23 Oct 2026)

| Journey | Taps today | Target | Evidence |
|---|---|---|---|
| Start today's workout | 2 (3 on first gym day): Home "Start, everything's ready" then the same label on R03 | 1 | `features/today/presentation/today_view.dart` ~513, `features/train/presentation/workout_day_view.dart` ~896 |
| Log one set | 1 | 1 (keep) | `mid_set_view.dart` ~503-531 |
| Last set to the finish screen | a full rest timer labelled "I'm ready, next set" runs first | straight to R10 | `app_state/workout_session_state.dart` ~364-370, `resting_view.dart` ~385 |
| Log breakfast she has eaten before | 4 + typing | 1 to 2 | `eat_view.dart` ~1116, `eat_hub_view.dart` ~291, `food_portion_sheet.dart` ~328 |
| Find a coach and ask to join | about 20 | 8 or fewer | `train_view.dart` ~482, `coach_portfolio_view.dart` ~416, `join_coach_sheet.dart` |
| First set for a new user | about 20 screens (onboarding, sign-up, ID check) | first set before sign-up (owner decision 1) | R ~3004, `guest_session` ~108-120, C06-C13 |

Choice density: Home above the fold has 12 tappable choices and three plan controls (Your training, Edit, Change plan) above the one filled Start (`today_view.dart` ~441-476); after 20:00 the filled button becomes "I already did it" (~328, `today_cards.dart` ~1020-1048); a coached woman on day one sees two filled Start buttons for different workouts (`coach_home_card.dart` ~87 and T06 ~886); R01 Train shows 5 plan-building actions and no Start above the fold (`train_view.dart` ~341-361); R03 shows a tune icon per move and "Add a move" before Start (~977-1112); E01 Eat has 3 navigation layers and 4 identical "Log" pills that only focus the text field; H05 My coach has 3 filled buttons with "End coaching" prominent; W02 client detail stacks 5 buttons with a red "End coaching" in the middle.

Emotional design today: the kitten has 27 placements but is absent from daily Home, Eat, Insights, the live set and every error or loading state; the only celebration is R10 (confetti, staged reveal under 2 s); a personal best gets a chip on R09 and a stage on R10 but no haptic (`app_state/haptics.dart` defines `bigMoment`, never called); "Remove this session" sits right under the R10 peak (`finished_view.dart` ~222-229); notification lines and error copy are already warm; coaching uses bare spinners and flat empty states.

Safety gap found: on the coach desk K07, "Accept" on a request card skips her flagged health answers; only the details sheet shows them (`features/private_coaching/presentation/desk/coach_desk_view.dart` ~481-486 vs ~129-169).

## 3. Workstreams

### 3.1 One clear next step (priority 1)

**A. Home shows one primary action: today's next step.**
- Files: `features/today/presentation/today_view.dart`, `today_cards.dart`, `features/train/presentation/plan_entry_cards.dart`, `features/followup/presentation/follow_up_card.dart`, `features/private_coaching/presentation/client/coach_home_card.dart`.
- Change: order the regular Home as greeting, then the Today card (the workout card with its single filled Start), then the week strip, then Eat; move "Your training", "Edit" and "Change plan" into one quiet "Plan" row under the Today card (or the card's overflow menu); move the follow-up card below the Today card. Keep the filled button as Start all day; "I already did it" stays a text button (remove the 20:00 swap). When a coach plan exists for today, the Today card IS the coach's workout (one filled Start, labelled with the coach's name); the solo plan becomes a text link "Do my own plan instead". On a rest day the Today card says so and offers the 10-minute walk card as its one action.
- Acceptance: widget test counts exactly one `FilledButton`-style primary on T01 in each state (regular, after 20:00, coached, rest day, day one); a golden test of T01 at 375x667 and 375x812 in EN and AR; Today card fully above the fold at 375x667.

**B. One tap from Home to the first set.**
- Files: `today_view.dart`, R (the T01 Start handler and R03 builder ~2503, ~3039), `workout_day_view.dart`.
- Change: Home Start starts the session and opens R07 directly; R03 stays reachable from R07's header ("All moves") and from Train for browsing and editing. The first-gym guide still shows once, before R07.
- Acceptance: a router test from T01: one tap lands on R07 with the session live; a tap on "All moves" opens R03 without ending the session.

**C. Train opens on today.**
- Files: `features/train/presentation/train_view.dart` (R01), `plan_entry_cards.dart`.
- Change: R01's first block is the same Today card as Home (one filled Start); plan building (Build my own, customise, the three splits) moves under a "Plans" section below; "Find a coach" gets its own row in the top half.
- Acceptance: R01 golden at 375x667 shows Start above the fold; one primary.

**D. R03 shows the workout, editing is a mode.**
- Files: `workout_day_view.dart`.
- Change: hide per-move tune icons and "Add a move" until she taps "Edit"; Start (when R03 is opened from Train) is the only filled button.
- Acceptance: widget test: R03 not editing has no tune icons and one primary.

**E. Insights opens on what she did.**
- Files: `features/progress/presentation/progress_view.dart`, `progress_insights_sections.dart`.
- Change: first section is "This week" (sessions, sets, minutes as positive counts) and personal bests; the body map moves below.
- Acceptance: P01 golden shows week and bests above the fold.

**F. Eat: log what she usually eats in one tap.**
- Files: `features/eat/presentation/eat_hub_view.dart`, `eat_view.dart`, `food_portion_sheet.dart`, `app_state/eat_state.dart`.
- Change: each meal row's "Log" pill shows her usual item for that meal ("Ful with egg") and logs it with one tap and an Undo snackbar (portion as last time); a second control "Something else" opens the typing field. Recent foods first in search. Keep allergy guard and portion sheet behaviour for new items.
- Acceptance: test: breakfast row with a usual item logs on one tap and Undo removes it; first-time row opens the field; logging a repeat meal is 1 tap, a recent food is 3 taps or fewer.

### 3.2 Fewer steps to value (priority 1)

**A. Owner decision 1: a first workout before sign-up.** Evidence: Duolingo +20% DAU from later sign-up. Today a guest sees her plan after onboarding (6-7 screens, no account) but cannot start a workout (R ~3004). Proposal: let a guest do day 1 on the phone (sessions are local today), then ask her to sign up at R10 ("Keep this workout: create your account") with the progress carried over by `SnapshotOwner`. Women-only verification still gates everything social or server-backed (coaching, events, community, meal scan, cloud backup). If the owner says no, skip A.
- Files: R (guest gate ~3004), `app_state/guest_session.dart`, `features/train/presentation/finished_view.dart`, `app_state/snapshot_owner.dart`.
- Acceptance: journey test: guest finishes day 1, signs up, the finished session is on her account; a guest still cannot open H01, events booking, meal scan or chat.

**B. Ask "client or coach" only of coaches.** C08 shows to everyone because `coachApp` is on (`domain/flags/feature_flags.dart` ~490, R ~1598). Move the choice to Profile "Become a coach" (already there) and to coach invite links; members never see C08.
- Acceptance: sign-up journey for a member has no C08; a coach invite code still lands on the coach path.

**C. One step counter in sign-up.** Setup says "5 of 5", sign-up then says "2 of 3" (`B02`, `B01` screenshots). Use one counter across setup and sign-up, or none in sign-up.

**D. Don't ask twice.** The join sheet starts goal, level, days and place empty (`join_coach_sheet.dart` ~106-109) though onboarding asked them; H01's quiz asks goal and place again and asks budget while coaching is free (`find_coach_view.dart` ~192). Prefill from `IntakeRepository`, keep each field editable, drop the budget question while payments are off.
- Acceptance: test: join sheet opens with intake values; H01 has no budget chip while `payments` is off.

### 3.3 Live workout polish (priority 2)

- After the last set, go straight to R10 (no rest timer); after the last set of a move, the rest button says "Next move" (`workout_session_state.dart` ~364-370, `resting_view.dart` ~385-396).
- R09: remove "Skip timer" (it does the same as "I'm ready"); keep -15 s / +15 s.
- R07: one exit at the top ("End workout", which opens the existing end sheet); remove the duplicate X.
- "I did them all" on R07 logs the remaining sets and goes to the next move directly (no R13 stop), or to R10 after the last move.
- Check the store screenshots' mismatch (Home "10 moves 3 x 12" vs R07 "Move 1 of 11, 4 x 12") is not a real data mismatch between Home facts and the session.
- Acceptance: router tests for each change; the existing live session tests stay green.

### 3.4 Rewards and warm moments (priority 2)

Rules (each checkable): never mention a missed day; the kitten's mood never reacts to inactivity; every celebration can be skipped and respects Reduce Motion; haptics use system patterns for their meaning only and one switch turns them off ([Apple HIG haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics), [motion](https://developer.apple.com/design/human-interface-guidelines/motion)); feedback animations 100 to 300 ms ([NN/g](https://www.nngroup.com/articles/animation-duration/)).

- **Personal best:** play `HapticMoment.bigMoment` once when a best is set (R09 chip) and on the R10 best stage; kitten cheer on R10 for a best (`app_state/haptics.dart`, `resting_view.dart` ~414-422, `finished_view.dart`).
- **Protect the peak:** move "Remove this session" from under the R10 peak into an overflow menu (`finished_view.dart` ~222-229).
- **Peak-end ending:** R10 shows what she did (never what is left) and ends on one warm line in Own Hub's voice, chosen from a small bank (same pattern as `assets/content/notification_lines.json`); a Rahma line only if Rahma records or approves it.
- **The kitten in daily use, lightly:** one small kitten state on Home's Today card (wave in the morning, rest pose on rest days), on Eat after the first log of the day (nod), and on error and loading states that last over 1 s (wait pose). Keep the existing cap of 3 animated appearances per sitting (`ui/hand/mascot/kitten.dart` ~56).
- **Weekly consistency, forgiving:** show "3 this week" against her own goal; a rest, sick or pause day she marks never breaks anything and has no deadline; cycle-aware gentle days count. No red or empty-day marks. (D37, DECISIONS D38 weekly challenge against her own last week stays.)
- **Coaching warmth:** replace bare spinners in coaching (`routing/coaching_wiring.dart` ~86, `chat_thread_view.dart` ~325, `application_status_view.dart` ~245) with the app's existing reassuring loading steps; every coaching empty state says what will appear and gives one action (e.g. "Your coach has not shared a plan yet" plus "Message her").
- **Copy audit test:** a test that fails if any English or Arabic string contains missed, lost, failed, broken streak, "you haven't", فاتك, ضيعتي, فشلتي, انقطع, or if an error string says invalid, incorrect or wrong ([NN/g errors](https://www.nngroup.com/articles/error-message-guidelines/)).
- Acceptance: tests for the haptic call on a best, the overflow placement, the copy audit, Reduce Motion skipping celebrations.

### 3.5 Coaching screens (priority 1 for the safety item, 2 for the rest)

- **Safety: Accept shows health flags.** On K07, tapping Accept on a request with any health "yes" opens the details sheet first, with the flagged answers and the doctor note, and Accept inside it (`coach_desk_view.dart` ~481-486, ~129-169). Test: Accept on a flagged request never responds without the sheet.
- **H02 portfolio:** a sticky bottom "Ask to join" (or "Message" when already her coach) visible without scrolling (`coach_portfolio_view.dart` ~416).
- **H05 My coach:** one filled action (Message); session Confirm stays on the session card; "End coaching" moves to an overflow menu.
- **W02 client detail:** one filled action (Message); Share a workout, Share a meal plan and Schedule a session as a row of secondary actions; "End coaching" in an overflow menu with its existing confirm sheet.
- **H03 coach plan:** mark today's day and give only today a filled "Start this workout".
- **Events:** "Reserve my seat" is the primary; "Open in Maps" becomes a text link; when loading the seat state fails, never show "Cancel my reservation" (`event_seats.dart` ~226-236).

### 3.6 Coaching retention for the payments phase (priority 1 before payments open)

Leakage happens when a client and coach meet once and then pay outside to skip the fee; it is worst for repeat 1:1 relationships like coaching ([Rework](https://resources.rework.com/libraries/marketplace-growth/marketplace-disintermediation), [Reforge](https://www.reforge.com/blog/what-is-a-marketplace)). On Lalamove a new commission roughly doubled off-platform deals and customers kept about half the saving ([Xie and Zhu](https://questromworld.bu.edu/platformstrategy/wp-content/uploads/sites/49/2023/06/PlatStrat2023_paper_27.pdf)); some leakage is the stable outcome ([Hagiu and Wright 2024](https://pubsonline.informs.org/doi/10.1287/mnsc.2023.4757)). Measure before policing. Egyptian platforms charge the provider, not the client: Vezeeta shows the doctor's own fee ([App Store](https://apps.apple.com/us/app/-/id1010281314)), Shezlong keeps 30% from therapists ([TechPoint](https://techpoint.africa/2021/03/09/egyptian-mental-healthtech-startup-shezlong/)).

**What the client gets that WhatsApp cannot give (build before payments open unless marked later):**
1. Own Hub Guarantee: full refund within 14 days of start (required anyway by Consumer Protection Law 181/2018 Art. 40/41, refund within 7 days by the same payment method, [Andersen text](https://eg.andersen.com/wp-content/uploads/2025/07/Law-No.-181-of-2018.pdf)) and a pro-rata refund if the coach no-shows or leaves; the coach's share is released only after 14 days (already in the server design: `functions/coaching/subscriptions.py`). Precedents: TaskRabbit Happiness Pledge, Rover Guarantee, Airbnb AirCover apply only to on-platform payments ([TaskRabbit](https://support.taskrabbit.com/hc/articles/30621785849613), [Rover](https://www.rover.com/rover-protect), [Airbnb](https://www.airbnb.com/help/article/209/paying-and-communicating-through-airbnb)).
2. Installments for 3-month packages (valU, Sympl 3 months interest-free, Souhoola, Aman, Contact) through Paymob or Fawry; Paymob pays the merchant upfront ([Paymob BNPL](https://developers.paymob.com/paymob-docs/payments-and-features/payment-methods/bnpls-egy-ksa-uae), [Sympl](https://ibsintelligence.com/ibsi-news/valu-and-sympl-partner-to-provide-short-term-bnpl-plans-for-customers)). Needs the licensed provider, not manual InstaPay.
3. Verified reviews only from paid in-app coaching (Vezeeta, Airbnb model, [Egyptian Streets](https://egyptianstreets.com/2018/12/12/how-vezeeta-is-redefining-the-relationship-between-patients-and-doctors/)).
4. Weekly check-ins her coach answers (form plus optional progress photo, private), the top retention driver in online coaching; Coachway's 5,666-client data shows 94% active at month 1, 82% at 3, 65% at 6, and quitting is preceded by shorter, then missed check-ins ([Coachway](https://coachway.io/articles/online-fitness-coaching-statistics/), [signals](https://coachway.io/articles/why-online-coaching-clients-quit/)).
5. Progress she can see: measurements and private progress photos over time, habit ticks (water, steps, sleep) as positive counts.
6. Form-check video or photo to her coach in chat (later: needs media moderation and storage rules).
7. Pause (up to 2 weeks, travel, Ramadan, illness) and switch coach without losing her plans and history.
8. A reply-time promise on each coach profile ("usually replies within a day"), measured from chat timestamps (Noom targets under 4 hours, [job ad](https://jobs.primary.vc/companies/noom/jobs/51124831-noom-mindset-coach)).
9. Privacy and safety: her phone number is never shown to a coach; women-only verified coaches; report and block; staff read a chat only after a report. Frame the contact rule as safety, not as fee protection.
10. Bundles: a 3-month package cheaper per month than monthly; no short expiry (a Shezlong review complained about one-month expiry, [Trustpilot](https://at.trustpilot.com/review/shezlong.com)).
11. Later: cashback as app credit on renewal (optional, she can always choose a refund), an Own Hub membership that lowers the service fee (talabat pro pattern, [talabat](https://corporate.talabat.com/news/corporate-website-news-item-6)), women-only group challenges with her coach.

**What the coach gets that WhatsApp cannot give:**
1. New clients she would never find: Find a coach, the match questions, featured placement for coaches with good reviews and reply times.
2. Payments handled: collection, monthly auto-renew with failed-payment reminders, installments paid to her in full, payouts on a fixed weekly day, an earnings screen, and a monthly income statement for her taxes (simplified regime, Law 6/2025, [Enterprise](https://enterpriseam.com/egypt/2026/10/11/your-guide-to-registering-as-a-freelancer-in-egypt/)). Harbiz and TrueCoach lead with this for a reason ([Harbiz](https://harbiz.io/en/pricing/), [TrueCoach](https://truecoach.co/pricing/)).
3. A fee that falls the longer she keeps a client: for example 15% on the first package, 10% on the second, 5% from the third; theory and practice both support charging more on the first transaction and less on repeats ([Enache and Rhodes](https://www.tse-fr.eu/articles/platform-disintermediation-repeated-transactions); Upwork's former 20/10/5, [Wise](https://wise.com/us/blog/upwork-fees)). Owner decision 2.
4. A "bring your own client" rate (invite code) so she runs all her clients here, not only the ones Own Hub found (Vezeeta added a doctor software product, [Wamda](https://www.wamda.com/en/2022/10/vezeeta-raises-undisclosed-growth-funding)).
5. Reputation only here: verified reviews, badges (clients coached, reply time), portfolio results.
6. Time savers: templates (exist), weekly check-in forms sent automatically, a welcome message, an adherence view on the desk that flags clients whose check-ins got shorter or stopped (Coachway's signals), AI drafts later.
7. Session booking with a late-cancel and no-show rule that protects her income (Mindbody and ClassPass patterns, [Mindbody](https://www.mindbodyonline.com/en-gb/business/scheduling), [ClassPass](https://help.classpass.com/hc/en-us/articles/207942743)).

**Pricing (owner decision 2):** keep one all-in price for the client (never show "+15%"); choose between (a) client pays coach price plus a smaller service fee and the coach pays a falling commission, or (b) the coach pays a falling commission and the client sees the coach's own price (the Egyptian provider-pays pattern). Do not raise the take above about 15% ([Gurley](https://abovethecrowd.com/2013/04/18/a-rake-too-far-optimal-platformpricing-strategy/)).

**Product friction that is fair:**
- Move the chat contact screen before the message is saved: send through a callable that screens then writes, instead of a direct Firestore write screened afterwards by the trigger (today a live listener can see the original text briefly: `functions/coaching/chat.py`).
- Detect spelled-out numbers in Arabic and English ("zero one zero", "صفر واحد") in `features/private_coaching/domain/chat_screen.dart` and its server twin.
- Keep contact details blocked for the whole coaching (safety in a women-only app), not only before the first payment.

**Rules (light, with a lawyer):** coach terms: no taking a client met on Own Hub off the app for 12 months, with an honest paid exit (Upwork's conversion fee pattern, [Upwork](https://support.upwork.com/hc/en-us/articles/17995710125715--The-Upwork-Conversion-Fee)) instead of a ban; proportionate damages only (Civil Code Art. 224); keep timestamped acceptance logs (e-signature Law 15/2004). Never forbid coaches charging less elsewhere (Competition Authority action against price parity, [Mondaq](https://webiis10.mondaq.com/antitrust-eu-competition/1603712/the-egyptian-competition-authority-eca-takes-actions-against-mfns-and-hub-and-spokes-arrangements)). The report reason `off_platform_payment` exists; add a staff warning then suspension ladder in the dashboard Reports tab.

**What backfires:** bans and threats, punishing honest coaches, removing messaging, a fee that is too high, strong trust signals without protection ([Gu and Zhu 2021](https://pubsonline.informs.org/doi/10.1287/mnsc.2020.3583), [Sharetribe](https://www.sharetribe.com/academy/how-to-discourage-people-from-going-around-your-payment-system/)).

### 3.7 Measurement (priority 1, needed to judge everything above)

Only with her analytics consent, never health, cycle, food or chat content (privacy policy and D-rules):
- Activation: share of new users who finish a first workout within 24 hours; time from install to first set.
- Retention: day 1, 7, 30 cohorts (health and fitness baselines about 20%, 8%, 3 to 4%, [Phiture](https://phiture.com/mobilegrowthstack/managing-retention-rate-benchmarks-and-expectations/)) and current-user retention, Duolingo's strongest lever ([Lenny's](https://www.lennysnewsletter.com/p/how-duolingo-reignited-user-growth)).
- Effort: taps to start today's workout (from screen events), meal logs per active day.
- Wellbeing: share of store reviews mentioning guilt or pressure (EN and AR), rest-day use, return after a gap of 7+ days.
- Coaching: renewal rate per coach vs the platform; clients who stop renewing but keep messaging; contact-screen hits per coach; off-platform reports; coach reply time.
- Ship retention changes as experiments against current-user retention where traffic allows.

### 3.8 Carried over from release 1 (open)

- Staff two-step sign-in (TOTP) in `admin-web/` before turning it on in Identity Platform.
- Incremental cloud pull with a `pulledUpTo` mark (`app_state/cloud_transport.dart` ~126, `cloud_store.dart`), with a two-phone test; full pull at least weekly and on account change.
- Exclude the local snapshot and coach photos from iOS backups (or say so in the privacy policy).
- Rate limits for chat messages, reports and coach-docs uploads (server counters).
- Native dSYM upload for Crashlytics in `app/tool/build_ios.sh` (upload tool path).
- Optional: remove the unused ARB key `pickHerNameIfSheKnowsYou`.
- Google Play release: follow the owner's launch guide (Play section). Repo files that are out of date for Play and must be fixed before the Play submission:
  - `docs/release/play-listing.md` describes the old no-account build (Data safety all "Not collected", no login, three tabs): delete it or replace it, so nobody pastes from it; the current texts are in `docs/release/launch-pack/store-listing-copy.md`.
  - `docs/release/launch-pack/store-listing-copy.md`: add a coaching paragraph in English and Egyptian Arabic (coaching is on since `691bbe9`); keep the closing "not a medical device" sentence in both languages ([Play health apps](https://support.google.com/googleplay/android-developer/answer/16679511)).
  - `docs/release/launch-pack/play-app-access.md`: it says coaching is off and tells the owner to empty the reviewer allow-list after review; Play needs reviewer access at all times ([App access](https://support.google.com/googleplay/android-developer/answer/15748846)), so the reviewer number stays in `store-reviewer-phones` while the app is live; describe how the reviewer reaches coach chat (a test coach linked to the test number).
  - `app/android/play-data-safety.txt`: merge the PostHog note into the data types; add the meal photo under Photos (ephemeral, App functionality); note that coach chat means "users can interact" for the content rating; drop the line about an exact-alarm declaration (`SCHEDULE_EXACT_ALARM` needs none, [policy](https://support.google.com/googleplay/android-developer/answer/9888170)).
  - `app/tool/build_release.sh` with `app_state/firebase_boot.dart`: the hand-out APK is signed with the upload key, so Play Integrity reports it as unrecognised and App Check will refuse it once enforcement is on; drop the hand-out APK or relax App Check's recognised-version requirement.

## 4. Owner decisions needed before building

1. Guest first workout before sign-up (3.2 A): yes or no.
2. Fee design for payments (3.6 Pricing): option (a) or (b), and the falling commission steps.
3. Conversion fee and 12-month non-circumvention in coach terms: yes or no (lawyer).
4. Rahma: will she record or approve end-of-workout lines (3.4)?

## 5. Verification for the whole release

- Per item: the tests named in its acceptance line, written to fail before the change.
- Tap-count tests in `app/test/journeys/` for: start today's workout (1), log a repeat meal (1), find a coach and send a join request (8 or fewer).
- Goldens for T01, R01, R03, P01, E01, H02, H05, W02 at 375x667 and 375x812 in EN and AR; the existing small-screen sweep (4 sizes, EN and AR, 0 overflow) must stay at 0.
- The copy audit test (3.4).
- Full suites: `flutter analyze`, `flutter test`, `functions/.venv/bin/python -m pytest -q`, Firestore and storage rules suites, `cd admin-web && node --test`, `app/tool/release_preflight.sh`.
- A device walk on the Android emulator (`app/tool/e2e_coaching.sh start` plus a debug build with `OWNHUB_EMULATOR_HOST=10.0.2.2`) through: new user to first set, a full workout to R10 with a best, logging a usual breakfast, finding a coach and joining, the coach accepting a flagged request.

## 6. Order of work

1. Safety: 3.5 Accept shows health flags.
2. Measurement events (3.7), so the effect of each change can be seen.
3. One clear next step: 3.1 A, B, C, D, then E, F.
4. Fewer steps: 3.2 B, C, D; 3.2 A after owner decision 1.
5. Live workout polish 3.3 and rewards 3.4.
6. Coaching screens 3.5 (rest).
7. Payments-phase retention 3.6, after owner decisions 2 and 3 and the licensed payment provider.
8. Carried-over items 3.8 as capacity allows.
