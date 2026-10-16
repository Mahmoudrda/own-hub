# Own Hub: free launch and coach commission implementation guide

Status: specification and tests written before implementation. No feature in this document is implemented by this documentation change.

Baseline reviewed: `96de1f0` on `main`, 12 October 2026. Recheck the current code before implementing: comments in this repository sometimes describe an older state than the executable code. Live Firebase content, deployed functions, provider contracts, and store-console settings were not audited.

## 1. Owner's objective and scope

The member app is free. Own Hub earns commission from paid training supplied by coaches. Coach efficiency, client retention, and trustworthy payouts are therefore core product requirements. Do not introduce a member subscription or require paid coaching to use ordinary training, history, progress, or existing free features.

This guide retains the seven requested training improvements and adds the coaching and commerce foundation they require. The foundation is necessary scope, not an optional eighth enhancement. It is a substantial backend project: working screens and domain tests do not mean paid coaching is connected.

The intended loop is: a woman uses the free app; optionally chooses a coach; the coach accepts an enquiry; an eligible payment is confirmed; the coach publishes an individual plan; the member trains; the coach reviews permitted results; Own Hub records its commission and the coach receives her payout.

Free access for members does not mean zero operating cost. Budget for identity/SMS, storage and delivery, payment/store fees, refunds, and owner support time. Do not put an exact cost forecast or a promised commission margin into the product until the inputs are measured or contracted.

**Confirmed launch market: Egypt only. Saudi Arabia and UAE are future expansion research, not launch scope. No payment gateway is currently available.** Keep free launch independently usable; paid coaching cannot be activated until real billing, refund and payout acceptance passes.

### Confirmed constraints

- Reuse Flutter, Firebase, existing screens, domain models, and the admin content publisher.
- Preserve Egyptian Arabic and English, RTL, Western digits, and existing design components.
- Preserve the current women-only verification policy. This guide does not authorize removing the whole-app account gate.
- A prescription is never a recorded result. An edit or message is never a coach plan publication.
- Keep health/cycle sharing opt-in and limited to the current permitted relationship; raw health data must not become analytics.
- Use deterministic, coach-reviewed rules and curated content. No AI generation or paid inference in the workout loop.
- Keep community, video calls, full social feeds, and unrelated marketplace features out of the minimum build.

### Decisions that must not be silently invented

| Decision | Why it matters | Work that can proceed first |
|---|---|---|
| What is sold: an asynchronous programme, a coaching package, a live one-to-one session, or in-person training? | Determines entitlements, delivery, cancellations, and store billing. | Free training, templates, invitations, and draft editing. |
| Commission rate and base | Gross price versus net receipts changes coach earnings. | Implement a configurable, versioned ledger and test with explicitly synthetic values. |
| Who bears gateway/store fees, refunds, disputes, and taxes? | Determines the payout equation and commercial terms. | Model separate ledger entries without hardcoded commercial defaults. |
| Payout provider, schedule, minimum, and refund reserve | Determines operational cost and coach expectations. | Build accurate pending/eligible/paid states; do not promise dates. |
| Who authors and signs off programmes, cues, and progression rules? | Code cannot certify exercise suitability. | Content tools and validation; keep unreviewed content in draft. |
| Does paid coaching have to launch on the same date as the free app? | Free training may be usable before commerce is ready. | Treat free launch and revenue launch as separate acceptance gates. |

Recommended starting scope, pending those decisions: a small invited group of verified coaches, their existing clients, one clearly described offer type, one currency, and the minimum billing integration required for the selected offer and storefronts. Invitations should lead to real in-app delivery and accountable payment records, not an off-platform payment workaround.

## 2. Verified reuse map

All paths below are relative to the repository root. These are starting points, not permission to replace established contracts wholesale.

| Area | Existing code | Observed gap |
|---|---|---|
| Feature switches | `app/lib/domain/flags/feature_flags.dart`, `functions/coaching/__init__.py`, `firebase/firestore.rules`, `firebase/storage.rules` | Coach, coached life, planning, marketplace, and payments are dormant. Server and rules gates must agree with the app. |
| Programme preview | `app/lib/features/onboarding/domain/starting_program.dart` | One bundled starting-programme entry; equipment mismatch is currently scored rather than rejected. |
| Published workout content | `app/lib/features/train/domain/workout_library.dart`, `app/lib/features/train/data/workout_sync.dart`, `app/lib/app_state/workout_library_state.dart` | Content publishing and caching exist; live published content is unverified. Do not assume there are complete launch programmes. |
| Coach planning | `app/lib/features/coachplan/domain/plan/`, `app/lib/features/coachplan/domain/split/`, `app/lib/app_state/coaching_desk_state.dart` | Reusable drafts, splits, copy-week logic, and publishing contracts exist. `_DeskPublishGateway` currently creates receipts locally. |
| Coach working day | `app/lib/features/coach/domain/coach_desk.dart`, `app/lib/features/coach/domain/client_view.dart` | Reuse the bounded queue and client summaries; production data delivery needs verification and wiring. |
| Invitations and credentials | `functions/coaching/roles.py`, `certificates.py`, `invites.py`, `functions/main.py` | Some server functions exist, behind a disabled gate. This is not a complete coaching backend. |
| Privacy boundary | `app/lib/features/coached/domain/coach_projection.dart` | Existing projection contracts must govern what a coach can see. UI hiding alone is insufficient. |
| Checkout and earnings | `app/lib/features/coaching/domain/payment_provider.dart`, `payment_state_machine.dart`, `checkout_gate.dart`, `app/lib/features/coach/domain/payments.dart`, `app/lib/app_state/coaching_link_state.dart` | Production provider is unavailable; test payment behavior must remain test-only. |
| Equipment | `app/lib/features/onboarding/domain/intake.dart` | Only none/mat/dumbbells/bands are represented. |
| Demonstrations | `app/lib/features/train/presentation/exercise_video_view.dart`, `app/lib/ui/app_media.dart`, `WorkoutVideoRepository` in `train_repository.dart` | The screen asks for a source but still renders placeholder media. |
| Swaps | `app/lib/features/train/presentation/swap_move_view.dart`, `app/lib/app_state/workout_session_state.dart` | The screen defaults to two fixed alternatives; the router does not pass the live exercise/session identifiers to the swap view. |
| Session recovery | `app/lib/app_state/workout_session_state.dart`, `app_snapshot.dart`, `local_persistence.dart` | Persisted records exist; active session position and swaps are excluded from the snapshot. |
| Logging and history | `app/lib/features/train/presentation/mid_set_view.dart`, `resting_view.dart`, `change_set_view.dart`, `app/lib/features/train/domain/set_history.dart` | Keep logging/undo/history. Extend equipment semantics, interruptions, and progression. |
| Rewards (§15) | `app/lib/domain/rewards/`, `app/lib/app_state/workout_session_state.dart`, `app/lib/features/progress/` | Points, levels, tiers, milestones, weekly runs and rest-week repair exist; at baseline only session points were ever paid and weeks never closed. |
| Streak and challenge (§15) | `app/lib/domain/rewards/training_streak.dart`, `app/lib/app_state/training_streak_state.dart`, `app/lib/features/train/domain/own_best_challenge.dart` (all new) | Device-local, derived from what she logged; never synced. |

## 3. C0: coaching and commission foundation

### C0.1 Coach onboarding and client acquisition

Reuse existing coach setup, certificates, offers, portfolio, and invite screens. A coach can complete a profile and draft a reusable programme while credentials are pending; publishing to a client requires the relevant verified role. Show status and next action instead of repeated setup screens.

Keep the initial portfolio minimal: identity, verified credential status, coaching description, supported training setting, availability, and one clear offer. Do not require a custom website builder, follower counts, public reviews, paid promotion, or a recommendation algorithm to get started.

Make the invite code/link survive sign-in and verification. Opening an invite is not consent to buy, does not bypass verification, and cannot forge a relationship. Support expired/revoked invites and a coach who is no longer accepting clients. Existing capacity limits must be checked on the server at acceptance, not only in the UI.

### C0.2 A real coach workspace

Provide a single queue for new enquiries, clients awaiting a plan, client-requested changes, and scheduled reviews. Show last sync and distinguish no data from no activity. Use bounded, server-maintained summaries rather than opening listeners on every set for every client.

The minimum useful workflow is: accept enquiry -> select/duplicate template -> adapt to client's shared equipment and constraints -> preview as member -> publish -> review a permitted weekly summary -> prepare the next draft. Include a short structured coach response/check-in; reuse existing messaging contracts if activated, with pagination, relationship authorization, and no public chat surface.

Persist coach drafts across process death. A queued publish must say it is queued and must revalidate role, relationship, version, and safety on reconnect. If a competing publication arrived first, show a conflict instead of overwriting it. Published versions are immutable; the active workout stays pinned to the version it started with.

Implement the existing `PlanPublishGateway` with a real callable and authenticated server authorization. Publishing must be idempotent and atomically establish the version and current pointer. Do not ship `_DeskPublishGateway` or a test payment adapter as production success.

### C0.3 Payment, commission, and coach trust

Before choosing a gateway, classify the actual product and intended storefronts. Apple's rules distinguish real-time one-to-one services from digital content and group services. Google also distinguishes eligible one-to-one services and requires that qualifying sessions not be replayable. Asynchronous programmes are not automatically exempt because a human coach wrote them. Review the relevant policy at implementation time; do not infer that an external link or hosted checkout is permitted in every market. [Apple payment rules](https://developer.apple.com/app-store/review/guidelines/), [Google payment guidance](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en-en).

Use one eligible external provider if the selected service permits it; otherwise integrate required store billing and authoritative purchase verification. Supporting both stores may mean two billing adapters. Do not add subscriptions, stored card details, wallets, or custom escrow merely to make an initial sale possible.

Required server behavior:

1. Read the accepted offer and relationship on the server; snapshot offer version, price, currency, commission policy, and delivery terms at purchase. The client never supplies authoritative price or commission.
2. Create an idempotent order. A returned browser page or client success message cannot mark it paid.
3. Verify the provider signature or store notification/purchase server-side. Validate transaction identity, expected amount/currency, and allowable state transition.
4. Apply payment, entitlement, commission, refund, and payout changes idempotently. Duplicate and out-of-order notifications must not produce duplicate revenue or access.
5. Keep gross receipts, refunds, platform commission, processor/store deductions, coach payable, and actual payouts separate. Use integer minor units; round according to a versioned policy.
6. Show a coach the gross amount, each deduction, net payable, payout status, and the reason for any hold. Keep an audit trail and a downloadable statement.
7. Provide cancellation/refund support, remove paid entitlements according to the actual contract, and preserve the member's own workout history. Never remove free features because coaching ends.

Budget-conscious payout operations may initially require owner approval of a batch through the provider, if supported by the provider and applicable requirements. The ledger, receipts, and reconciliation must still be real. A spreadsheet or uploaded payment screenshot is not authoritative proof of payment. Do not manually mark an account paid in a way that bypasses verification.

Unit economics to calculate before activating paid offers:

`platform contribution = collected platform commission - platform-borne payment/store fees - refund/dispute costs - variable infrastructure - support cost`

`coach payable = commissionable amount - agreed platform commission - coach-borne fees - agreed adjustments`

The tested commission arithmetic uses gross collected minus refunded principal as a proposed base. Commercial approval is still required; change the documented contract and tests together if the owner chooses another base. Taxes and fee allocation are separate entries, not silently hidden inside this equation.

### C0 acceptance gates

- Two separate test accounts/devices complete enquiry, acceptance, payment confirmation, plan publication, training, and authorized coach review.
- A different coach cannot read or publish for that member; forged IDs, revoked roles, expired relationships, and revoked sharing are refused server-side.
- A replayed publish or payment notification changes the corresponding record only once.
- Payment failure/timeout does not activate coaching. Refunds and duplicates reconcile to the same final ledger.
- Coach earnings match provider/store records, including failed payouts and adjustments.
- App, server, and rules flags are enabled only after their connected path passes. Turning payments off stops new purchases without hiding existing receipts or support.

## 4. F1: complete programmes and reusable coach templates

**Value:** members know what to do next; coaches spend time adapting a plan rather than retyping it. **Effort:** medium content work, medium-to-large integration; minimal new service costs.

Minimum scope is one complete coach-reviewed beginner gym programme with practical two/three-day variants and a complete home fallback. Programme length and prescriptions are content-owner decisions. Prefer a small complete library over many titles with missing sessions. The implementation must support the next week/session, rest, missed days, and programme completion; it must not promise an eight-week course backed by a single repeatable sample unless it explicitly describes that repetition.

Implementation tasks:

- Extend existing programme/session models with the minimum selection metadata: equipment requirements, training setting, level, schedule, duration, and version. Preserve existing wire values and readers.
- Reject programmes requiring unavailable equipment. Choose among compatible programmes using deterministic preference scoring. Return an honest no-match state when none fit.
- Reuse splits, copy-week, plan drafts, and publication for coach templates. Duplicate-by-value into a client draft; later template edits must not mutate existing assignments.
- Allow a coach to adjust exercises, sets, rep ranges, rest, and instructions in a draft, preview it as the member, then publish explicitly.
- Connect selected programme and published session to the actual R03/R07 execution path. A programme preview that does not affect the workout is not complete.
- Make required content fields and missing demonstrations visible to the coach before publication; do not invent clinical suitability.

Acceptance: compatible selection, no-match handling, stable next-session sequencing, template isolation, immutable publication, client ownership checks, offline draft retention, and two-device delivery. Existing tests under `app/test/features/coachplan/` and `app/test/features/train/workout_library_test.dart` remain applicable. Add content tests covering every exercise actually referenced by launch programmes.

## 5. F2: real demonstrations and equipment setup

**Value:** members understand movements and machine setup; coaches reuse instructions. **Effort:** medium upfront filming and player integration, low controlled running cost.

- Produce only the demonstrations required by the launch programmes and their approved swaps. Record with a qualified trainer in one batch. Budget targets, not provider promises: short compressed clips, no autoplay of the full library, and an explicit download size before downloading.
- Each exercise has stable ID, Arabic/English names, equipment/setup guidance, concise cues, duration, media version, and rights/reviewer metadata.
- Resolve through `WorkoutVideoRepository`; actually mount a playable media child. Support cached local files, unavailable media, retry, captions/text, and returning to the same workout position.
- Reuse approved public demonstrations across coaches. Keep any future private client uploads on an authenticated private path. Do not make private video public to save delivery cost.
- Choose a delivery/cache implementation using current measured costs. Existing comments contain historical egress estimates; they are not current quotes.

Acceptance: source-present mounts playback, missing source gives an honest fallback, cached playback works in airplane mode, downloaded version is invalidated correctly, and video interruption never changes logged sets. Test playback and audio coexistence on a real iPhone and budget Android; a widget that merely exists does not prove decoding works.

## 6. F3: equipment profiles that match the gym

**Value:** fewer unusable assignments and fewer equipment questions for coaches. **Effort:** low-to-medium, negligible service cost.

- Preserve `none`, `mat`, `dumbbells`, and `bands`; add `bench`, `barbell`, `cable`, `smith_machine`, and `machine` wire values as the minimum equipment vocabulary. Machine exercise definitions must also identify the actual machine required; generic `machine` alone is not proof that a gym has a leg press.
- Add saved home/gym profiles with explicit available equipment and load increments. Never infer a full gym from selecting “ladies gym.” Let a member edit after onboarding and choose the active profile before starting.
- Store weight units and basis explicitly (per dumbbell, total bar load, or machine setting). Record machine identity where useful; two stacks labelled the same weight are not automatically equivalent.
- Migrate old intake data without losing choices. Unknown future values must not grant equipment access. Do not persist enum ordinal positions.
- Share only the selected, permitted equipment/constraint projection with the coach; show when it changed so the coach can review a draft.

Acceptance: old profiles round-trip, missing equipment is excluded, home/gym switching changes candidates, load increments are respected, unit conversion does not corrupt records, and a coach cannot edit the member's declared equipment through a shared projection.

## 7. F4: appropriate substitutions in a busy gym

**Value:** a busy machine does not end the workout; the coach understands deviations. **Effort:** medium rules/content work, no inference cost.

- Pass the actual session ID and selected/current exercise ID from `AppRouter` to `SwapMoveView`. Load candidates from the repository, not the default glute-bridge/lunge pair.
- Maintain a coach-reviewed mapping by movement pattern, equipment, level, and relevant contraindications. Allow a coach to restrict a published assignment to approved alternatives.
- Reasons: equipment busy/unavailable, unfamiliar movement, preference, or difficulty. Pain/discomfort must lead to stop/skip and appropriate guidance rather than an automatic claim that another movement is medically safe.
- “Do later” changes order while preserving completed sets. A swap changes only remaining work; retain original exercise, chosen alternative, reason, and timestamps as session provenance.
- Never copy a barbell load onto a different machine or bodyweight alternative. Use that alternative's own history or a reviewed starting rule. If there is no match, offer skip/request-help instead of a generic exercise.

Acceptance: alternatives correspond to the requested move, equipment filters hold, no-match remains empty, unrelated defaults never appear, completed sets survive, live prescription version is unchanged, and permitted summaries communicate the substitution to the coach once.

## 8. F5: session recovery, offline training, and durable coach drafts

**Value:** neither a member's workout nor a coach's planning work disappears. **Effort:** medium reliability work, local storage first.

- Extend persistence to include active session ID, owner UID, programme version, exercise/set position, completed outcomes, substitutions/order, and rest deadline. Add schema migration; retain old completed-history sections.
- Save completed actions durably. Persist an undoable operation with its deadline so a restart cannot silently finalize an undone action or lose a confirmed action. Account for the existing five-second undo contract explicitly.
- Keep wall-clock rest deadline separate from rendered ticks. Returning from background recalculates remaining time; an old timer must not navigate over another screen. Schedule/cancel native notifications correctly.
- Use idempotent operation IDs and per-session conflict detection. For the first version, allow one active workout device per account with explicit takeover; do not silently merge conflicting live sessions.
- Flush bounded batches (for example by completed movement and session end); avoid a server write for each timer tick. Do not rely on background execution being guaranteed.
- Coach drafts and publish intents must persist separately from member session data. Revalidate queued publication on reconnect; no offline queued payment.
- Logout/account deletion clears account-owned caches and queued operations. A cached session from account A must never be restored into account B.

Acceptance: force-stop recovery, offline recovery, undo across restart, duplicate sync, corrupt-section isolation, schema migration, account isolation, and active-plan update handling. Use fake clocks in automated tests; use real device background/lock tests for operating-system behavior.

## 9. F6: explainable progression with coach control

**Value:** members know the next sensible target; coaches review exceptions instead of calculating every routine change. **Effort:** medium, no AI API.

- Build a pure progression policy over measured outcomes, available load increments, programme rules, and simple difficulty feedback. Never use a prescribed-but-uncompleted set as evidence.
- No history or incomplete history produces no increase. Difficulty, pain, and a long training break must suppress automatic increase; do not diagnose or invent rehabilitation rules.
- A reviewed policy may suggest an available higher load after all target sets satisfy the rule. The precise physiological thresholds need trainer approval. Test fixtures specify algorithm behavior, not medical advice.
- Separate suggestion from prescription. For a coached member, put suggestions into the coach's review queue/draft and require explicit publication to change the assigned plan. The member can still record what she actually did.
- Explain using actual previous values. Record policy version and whether the coach accepted/changed/rejected it. Avoid collecting extra health data just to generate a suggestion.

Proposed pure API for the acceptance contract: `app/lib/features/train/domain/progression_policy.dart` exports `ProgressionDecision suggestProgression({required double? previousWeightKg, required List<int> completedReps, required int targetSets, required int targetReps, required List<double> availableWeightsKg, required bool difficult, required bool painReported, required bool returningAfterBreak, required bool coached})`. Decision fields: `String action` (`hold`, `increase`, `review`), `double? suggestedWeightKg`, `bool requiresCoachApproval`. Inputs must be finite/nonnegative and set/rep targets positive; invalid values throw `ArgumentError`. Contract details: all completed work sets must be present (list length equals targetSets) and each meet targetReps; choose the smallest available weight strictly above the previous one, without mutating the input list. After input validation, null history holds null and takes precedence over the remaining rules. Pain or return after a break yields review at the previous weight; difficulty yields hold. No larger available weight yields hold. A coached increase sets requiresCoachApproval=true; all other decisions set it false. This API is new, not present at baseline; wire it into production rather than implementing a test-only calculator.

Acceptance: no fabricated history, incomplete sets do not progress, the next available increment is used, no weights beyond equipment limits, difficult/pain/return cases do not increase, coached increases require approval, input is not mutated, and actual plan changes only on publish.

## 10. F7: fast and trustworthy gym logging

**Value:** members use the app between sets and coaches receive interpretable records. **Effort:** low-to-medium; keep existing components.

- Put actual previous results next to the current prescription. Keep an explicit tap to record; starting a workout cannot mark targets completed.
- Make reps/weight adjustable with large controls and the equipment's supported increments. State whether weight is per hand, total, or a machine setting.
- Keep one-tap logging and five-second undo. An edit or undo updates totals and coach summaries idempotently without rewarding a session twice.
- Start rest automatically, let the user extend/skip it, and ensure an extension cancels/replaces an earlier notification.
- The coach sees planned versus actual work and useful exceptions only where sharing allows it. Missing/offline data is not labelled noncompliance.
- Test short screens, Arabic RTL, large text, and navigation while the timer is active. Avoid adding a new full-screen confirmation to every set.

Acceptance: authentic last-session values, undo, skipped sets, per-hand labels, Western digits in Arabic, no hidden logging controls, and no timer navigation after the user leaves. Real-device targets: a first-time user can log a normal set without instructions; document observed taps and time rather than claiming a universal latency target.

## 11. Implementation order and cost boundaries

| Work package | Dependencies | Completion boundary |
|---|---|---|
| A: data contracts, equipment, and persistence (F3/F5) | Current code/schema audit | Existing records migrate; active work survives restart; account boundaries hold. |
| B: programmes and coach authoring (F1/C0.1/C0.2) | A; reviewed content | A coach publishes a real template-derived plan to a separate client device. |
| C: gym execution (F2/F4/F7) | A/B; filmed/reviewed content | Member completes the assigned workout offline with appropriate substitutions and logging. |
| D: progression (F6) | Reliable actual results from C | Suggestions are explainable; coach-owned plans require publication. |
| E: commerce (C0.3) | Owner's offer/commission decisions, billing classification, provider/store setup | Verified payments, refunds, entitlements, and payouts reconcile end to end. |
| G: motivation design and honest rewards (§15) | Current reward engine; owner decisions D37–D41 | Rewards shown are rewards paid; R10, streak, challenge and waits pass G01–G19, with G20 on devices. |

Free training cannot be called ready until A–D, U0 usability and P0 regional/privacy gates pass. U0/P0 design and data contracts begin before A and apply to every package. Commission revenue cannot be called ready until the relevant coaching paths and E pass. If money or content dependencies are unavailable, report that exact gap; do not enable a nonworking feature to meet a date.

Save money by sharing templates and demonstrations, batching writes, caching immutable media, polling bounded coach summaries on demand, using one codebase, and using provider-supported payout operations. Do not cut ownership checks, local durability, payment verification, refund accounting, or content review.

Defer AI chat, AI pose/form scoring, live video infrastructure, a public community, advanced matching, custom coach websites, coupons/referral commissions, unnecessary multi-currency expansion beyond approved launch offers, automated tax engines, and unlimited coach media uploads. Retain free features already shipped. No hardcoded provider fee, unlimited usage promise, or invented budget ceiling.

## 12. U0: first gym visit and simple navigation (mandatory across F1–F7 and coaching)

This is a release requirement, not a cosmetic follow-up. A newcomer must understand what a screen is for and what to do next; a coach must accomplish routine work without exploring unrelated tools. Reuse the design system and existing routes rather than building another navigation framework.

### Research translated into Own Hub decisions

Use familiar labels, visible feedback, consistent actions, undo and focused screens. These principles reduce the need to remember instructions. [Nielsen Norman Group usability heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/).

Offer help beside the relevant task and let people dismiss and reopen it. Avoid a mandatory slideshow explaining every feature before the first workout. [NN/g contextual onboarding guidance](https://www.nngroup.com/articles/onboarding-tutorials/).

Use touch areas at least 48 logical pixels square in Flutter, including icon buttons, and leave separation between adjacent actions. This is Own Hub's cross-platform implementation target based on [Android touch target guidance](https://support.google.com/accessibility/android/answer/7101858?hl=en). Target text contrast of at least 4.5:1 for normal text and 3:1 for large text, with labels rather than color alone for states. [W3C contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

The screen specifications below are product proposals derived from those principles, not claims that research proves one universal button placement.

### U0.1 First time at the gym

Add a free, optional “First time at the gym?” entry on Train and the first programme preview. Keep it available from Train help afterwards; do not put it in a paid coach offer or force experienced users through it. Ask only “Would you like a quick guide?” with Skip; no additional medical questionnaire or new account gate.

Implement four short steps, one purpose per step, offline text available from the bundled app:

1. **Before you start:** show today's short workout, expected time, and a small practical preparation checklist. Explain that gym staff can help locate equipment. No fitness guarantee or invented screening advice.
2. **Find and set up the equipment:** show the name/photo of the actual first assigned station, a link to its reviewed setup/demo, and “Equipment busy?” leading to approved swaps. Generic text cannot claim it explains every machine's adjustments.
3. **Understand a set:** explain rep, set and rest in plain Egyptian Arabic/English with an illustrative example explicitly labelled practice. Let the user try a sample log/undo without writing workout history, rewards or coach statistics. Teach the weight basis (per hand/total/machine setting) where it is used.
4. **Start with confidence:** recap the next action; the primary button opens her actual workout. Include a short, trainer-reviewed reminder to stop and seek appropriate help if she feels pain/unwell, without a diagnostic questionnaire. Provide a staff-help cue, not AI form diagnosis.

Use brief text and existing licensed illustrations first; no new video production specifically for the tour. Exercise clips belong to F2 and are optional to understanding this guide. Back, Next and Skip must preserve the chosen programme. Closing a demo returns to the same step. Completion/dismissal persists per local profile and content version; reopen does not replay a forced modal on every launch. Do not label the user a beginner forever or send guide answers to analytics.

Proposed widget contract for prewritten tests: `app/lib/features/train/presentation/first_gym_guide_view.dart`, `FirstGymGuideView({required VoidCallback onStartWorkout, required VoidCallback onClose})`. Four steps indexed 0–3; keys `gym-guide-step-0` through `gym-guide-step-3`, `gym-guide-next`, `gym-guide-back`, `gym-guide-skip`, and final `gym-guide-start`. The keys identify actionable controls, not invisible test-only widgets. Steps 0–2 expose Next; step 3 exposes Start; Skip closes without starting/logging anything. Tests exercise the widget, while route, persistence, practice isolation and content correctness remain required integration checks.

### U0.2 Navigation and onboarding contracts

- Audit `app/lib/ui/app_nav_bar.dart`, `app/lib/routing/app_router.dart`, `app/lib/routing/app_routes.dart`, `app/lib/ui/app_scaffold.dart`, all shipped presentation views and the onboarding/coach routes before moving destinations. Produce a route inventory with role, entry/exit, primary task and feature gate. Include loading, empty, error, pending-verification and offline variants. No claim that every existing screen was visually audited by this document.
- Preserve the member's familiar Home/Train/Eat destinations and existing profile access; do not add a tab for every new feature. Hide dormant Community from the production navigation rather than send users to an unavailable screen. Preserve access to existing Progress and Cycle through their established routes. Coach mode uses its existing Today/Clients/Chats/Earnings shell, showing only available destinations; earnings may be absent until commerce works. Give dual-role users an explicit, labelled role switch; never silently change their shell.
- Labels accompany navigation icons; keep destination order stable within a role. Back returns to the prior context with scroll/filter/draft position intact. Android system Back, iOS back gesture and the visible Back button agree. Deep links preserve their intended destination through sign-in/verification, then recheck authorization.
- Collect required setup answers only when they affect the immediate next step. Account/verification requirements remain; optional analytics, notifications and backup are separate, default-off choices. Do not add notification/camera permission prompts on unrelated pages. Let users edit equipment and schedule later.
- Teach a new feature on first intentional use with one short hint and a visible Help entry. Dismissal persists locally. Do not stack a tour, a permission prompt and an upsell on the first Home visit.
- Define one visually dominant action per task state. Use concrete verb labels such as “Start workout”, “Log set”, “Preview plan”, “Publish plan”. Keep secondary actions beside the item they affect; use an overflow menu only for infrequent actions. Destructive actions stay away from the frequent primary action and have clear recovery/confirmation proportional to the consequence.
- In workout pages place the frequent primary action in a stable bottom action region above the safe area/keyboard, with enough scroll padding that it never covers content. In coach editing place Save draft/status and Preview/Publish consistently; draft save never looks like Publish. At 200% text allow the layout to grow/scroll rather than force a fixed-height footer that clips labels. Mirror directional controls for RTL; do not mirror numbers, weights or media controls incorrectly.

### U0.3 Screen content and action placement

| Screen / task | Visible first | Primary action and position | Secondary content / navigation |
|---|---|---|---|
| Member Home | Next workout or resumable session, one relevant status | Start/Resume within the next-workout card | Weekly summary below; no coach sales dashboard, setup checklist stack or finance cards |
| Programme preview | Who it suits, schedule, duration, needed equipment | Choose programme below the summary | Details expandable; first-gym guide link beside Start context |
| Equipment profile | Active place, selected equipment, clear edit controls | Save at end/stable action region | Load increments/machine detail on selection, not dozens of fields on first entry |
| Workout overview | Today's moves, expected duration, equipment | Start/Resume in bottom action region | Tap a move for demo; programme history is a separate destination |
| Exercise demo | Exercise name, setup, playable demo or text fallback, 2–3 cues | Back to workout, stable bottom region | Swap beside exercise; long explanation in Learn more |
| Set logging | Current move/set, target, actual entry, authentic previous result | Log set in stable reachable action region | Edit and Skip labelled; no unrelated progress charts, purchases or coach metrics |
| Rest | Remaining time and next move | Continue/Skip rest | Extend nearby; leaving/restoring does not reset the deadline |
| Swap sheet | Current exercise and short suitable candidate list with reason | Confirm selected swap at bottom | Keep selection/workout context; explain no-match with a useful return action |
| Completion | What was actually recorded and what happens next | Done/Return home | Optional feedback or reminder after main outcome; no forced social share |
| Coach Today | Small bounded queue ordered by next action, last sync | Open the relevant client task on each row | Filter/search; no detailed earnings or all-client health charts |
| Coach client | Client identity, shared equipment/constraints, plan state, latest permitted summary | Create/Review plan in predictable location | History and consented detail on demand; no raw cycle data on overview |
| Coach editor | Client, draft state/version, current day/move being edited | Preview; Publish only from explicit review | Reuse template/copy week nearby; advanced scheduling collapsed |
| Coach onboarding | Current credential/profile status and next required action | Continue next required step | Draft work remains available while review pending; no fake paid activation |
| Earnings (after billing) | Pending/eligible/paid totals with currency and status | View statement | Tap for line items/holds; never show demo revenue as actual income |
| Privacy | Plain-language purpose and current state for each control | Each setting has its own labelled control | Details on demand; separate Delete account; no all-or-nothing consent bundle |

For every enabled route, implement explicit loading, empty, failure and success states; retries retain entered data. Disable duplicate submission while in flight with meaningful status. Explain a disabled action briefly near it; avoid unexplained grey buttons. Provide semantics labels, logical focus order, readable dates/units and real localized errors. No developer IDs, database names or exception dumps in product copy.

### U0.4 Budget usability acceptance

Run the critical flows in English and Egyptian Arabic on a small Android phone and an iPhone, with normal and 200% text, TalkBack/VoiceOver, keyboard open, slow network and airplane mode. Test reachable controls and scroll at each step; a golden screenshot alone does not prove navigation.

Recruit a small first round of five gym newcomers and three coaches through the owner's network, with informed participation and no production health data. These counts are a budget research choice, not statistical proof. Give tasks, not instructions: find today's workout; explain sets/reps; open and leave a demo; swap a busy station; log/undo; resume after interruption; find privacy; and, for coaches, accept an invite/client, reuse a template, preview/publish and interpret a client summary.

Proposed release target: at least four of five newcomers complete each critical training task unassisted, and all three coaches can distinguish draft from published and deliver a plan without moderator instructions. Any accidental purchase/publication, lost workout, inaccessible control or misunderstood consent is a release blocker regardless of score. Record time, taps, wrong turns and exact confusing labels; fix and retest failures with fresh participants where possible. Do not collect session replay or health data to run this inexpensive study.

## 13. P0: privacy, local storage and regional release requirements

**Launch scope confirmed by owner: Egypt only.** Saudi Arabia/UAE research below is retained for future expansion and is not a prerequisite for the Egypt release. Do not implement country selection, foreign-ID processing or multi-currency just for this launch. This is an engineering and launch review checklist, not a legal certification. Local-device storage reduces exposure but does not remove privacy obligations. Country availability, company establishment, user residence, coaching service type and data processing all affect applicability; app language or app-store country alone is not enough. Configure launch distribution and marketing for Egypt, and document how requests from outside the supported market are handled without collecting precise location just for that purpose. A phone prefix alone does not establish applicable law. Qualified local review must resolve applicable Egypt items before launch; other countries need their own review before expansion. Other MENA countries need their own review before expansion.

### P0.1 Egypt launch and future-market legal starting points (researched 12 October 2026)

| Market | Official starting point | Required launch decision / evidence |
|---|---|---|
| Egypt | The PDPC identifies Law 151/2020 and Executive Regulations 816/2025 as its framework. [Egypt PDPC](https://www.pdpc.gov.eg/) | Determine controller/processor roles, applicable licences/permits, sensitive-data and biometric/ID handling, DPO/registration duties and transfer permissions. Verify current deadlines directly; do not rely on old claims that regulations are still unpublished. |
| Saudi Arabia | PDPL and its implementing/transfer rules; the authority explains extraterritorial application and data minimization. [SDAIA knowledge centre](https://dgp.sdaia.gov.sa/wps/portal/pdp/knowledgecenter) | Document lawful purposes, sensitive health treatment, rights, processor agreements, impact assessment and any registration/DPO duties. Assess overseas transfers individually under current transfer rules, including safeguards and any required risk assessment; consent alone is not a universal transfer solution. [SDAIA transfer guidance](https://sdaia.gov.sa/en/SDAIA/about/Pages/RegulationsAndPolicies.aspx) |
| UAE federal | Federal Decree-Law 45/2021 on personal data protection. [Official law download](https://www.uaelegislation.gov.ae/en/legislations/1972/download) | Determine federal scope/exemptions, current executive requirements, rights, sensitive data, breach obligations and transfer mechanism. Do not invent a universal breach deadline or assume GDPR compliance is sufficient. |
| UAE health boundary | Federal Law 2/2019 addresses ICT in the health sector, including free zones. [UAE government health ICT guidance](https://u.ae/en/about-the-uae/digital-uae/whole-of-government-approach/digital-health/ict-in-the-health-sector) | Obtain a classification of this fitness/coaching service and its health/cycle processing. Check whether sector-specific hosting/transfer restrictions apply; do not assume every fitness app is healthcare, or that calling it wellness creates an exemption. |
| UAE establishment-specific | DIFC and ADGM have their own data-protection regimes. [DIFC commissioner](https://www.difc.com/business/registrars-and-commissioners/commissioner-of-data-protection), [ADGM guidance](https://www.adgm.com/operating-in-adgm/office-of-data-protection/guidance) | Apply the regime matching actual establishment/processing; record relevant registration, officer, transfer and rights obligations rather than treating all UAE businesses identically. |

Do not certify “compliant with all MENA regulations” from this table. Maintain a dated market decision register with owner/reviewer, authoritative source, applicability reasoning, evidence, expiry/recheck date and release status. Obtain a scoped local review of data flows, identity verification, coaching terms and billing classification to control cost; engineering cannot supply a licence or professional legal determination.

### P0.1a Future expansion only: regional functionality gaps

For the Egypt launch, retain current Egyptian phone normalization, document handling and EGP contracts, subject to the Egypt privacy/verification review. The following work is deferred until expansion is authorized. The current app is Egypt-specific. `app/lib/features/signup/presentation/phone_number_view.dart` fixes the country context; `app/lib/features/signup/data/firebase_auth_repository.dart` normalizes through `egyptianE164`; `functions/identity/nid.py` parses Egyptian national IDs. `app/lib/features/coaching/domain/money.dart` defines EGP and coach earnings use piastres. None of this proves Saudi/UAE residents can onboard or purchase.

Before opening those markets, add an explicit country selector with region-aware E.164 validation/normalization, Arabic digit handling and approved Firebase SMS regions/rate/cost controls. Keep Egyptian behavior compatible. Country selection is not a reliable proxy for residence, jurisdiction or a document's nationality. Preserve the verification gate through approved country/document-specific verification or an operational reviewer path; do not apply Egyptian ID sex/date parsing to foreign IDs or use AI/face-based gender inference. Define supported residency/document cases with the verification reviewer and legal owner, then test rejections, expiry, appeals and deletion.

Keep a single-currency paid pilot only if the provider and offer terms actually support the chosen buyer/coach countries. Display the actual charge currency and any known conversion terms. Otherwise introduce explicit currency/minor-unit contracts and country-specific offers as necessary; do not simply rename EGP to SAR/AED or promise cross-border payouts. Free regional access can precede paid regional availability, but paid availability must be communicated accurately. Test locale-independent currency arithmetic and historical records. Regional settings must not depend on the UI language or a spoofable client assertion for authorization.

### P0.2 Preserve features with minimum data

Current reuse: `app/lib/app_state/local_persistence.dart`, `app_snapshot.dart`, `analytics_consent.dart`, `account_data.dart`, `app/lib/features/account/domain/health_backup.dart`, `app/lib/features/coached/domain/coach_projection.dart`, `firebase/firestore.rules`, `firebase/storage.rules`, and the identity/account functions. Existing health backup is opt-in; this is partly implemented already. Do not claim all user data is currently device-only: accounts, verification, cloud training paths and SDK metadata require an actual data-flow audit.

| Data | Default location / purpose | Minimum shared/server exception | Feature-preserving behavior |
|---|---|---|---|
| Cycle, symptoms, measurements, personal notes and health intake | Device only by default | Explicit, purpose-specific authorized backup or selected coach projection only after regional clearance | Logging and viewing continue without backup or analytics; explain device-loss risk honestly |
| Active workout, actual sets, rest deadline and equipment | Durable local state for offline use | Necessary account sync and selected coaching summaries where enabled/authorized; audit existing automatic sync before changing policy | F5 recovery works offline; opting out of optional sharing cannot erase own history |
| Coach-client relationship and published plan | Minimal authenticated server record | Required for coach delivery/versioning/revocation and synchronization | Explain what coach sees; detailed health/raw logs remain separately controlled |
| Account and verification | Only fields necessary for identity/access | Sign-in provider, verification processing/result, anti-abuse fields and required audit records | Retain women-only verification; assess biometric/ID processing and delete source images per verified retention job, not a UI promise |
| Payments (future) | Provider handles payment instrument; Own Hub keeps minimal order/ledger references | Legally necessary accounting/dispute records, role-restricted | Deletion removes unnecessary personal fields; required financial records are separately retained with explanation |
| Analytics and diagnostics | Off unless separately permitted | PostHog US and existing Firebase receive strictly minimized events only after consent | Core training, coaching, progress and cycle work with analytics off; no replay, names, phone, raw health, messages or card data |
| Public coach profile | Deliberately published fields only | Public portfolio after coach review | Private certificate files, client list and draft notes never become profile data |

Treat pseudonymous SDK IDs and hashes as potentially personal data. Do not log request bodies, tokens, identity documents or health fields in Cloud Functions, crash tooling, admin dashboards or support tickets. Minimize metadata as well as content. Review CDN, push, authentication, SMS, logs, backups and support access; a Frankfurt database does not mean every provider processes solely in Frankfurt. The requested PostHog endpoint is US-based: record its transfer assessment and processor agreement explicitly. A disclosure/consent switch alone does not establish lawful transfer.

### P0.3 Concrete engineering tasks

1. Inventory each collection, local snapshot section, API, SDK and export: fields, purpose, lawful basis for the market, recipient, role, country, retention trigger, deletion job and owning feature. Capture actual network requests on synthetic accounts; compare consent off/on, fresh install and withdrawal. Inventory OS cloud backups too.
2. Keep optional consent granular: analytics, crash reports, health backup and coach health sharing must not be bundled with terms or ordinary training access. Version notices and server consent records where needed; record purpose/version/time, no extra health payload. Revoke on the server and purge stale local coach projections; offline coaches must lose expired projections when authorization expires, with a defined short cache lifetime. Never promise remote erasure on an unreachable device instantly.
3. Audit local protection: sandboxing alone is not a complete solution. Evaluate encryption for sensitive persisted data using OS-backed key storage and backup exclusion; migrate safely without loss. Existing SharedPreferences JSON is not to be described as an encrypted health vault. Logout/account switching must prevent the next user reading the previous user's data. Offer an explicit export and clear-device action, with accurate device-loss/backup consequences.
4. Enforce least privilege in functions and rules. Verified coach role plus active relationship plus permitted field projection is required. Staff access needs assigned role, a reason and an audit entry; do not copy raw health into audit logs. Encrypt in transit and use managed encryption at rest; do not build custom cryptography.
5. Implement access/correction/export/withdrawal/deletion request workflows with authenticated identity checks and clear status. Existing “request a copy” entry must actually produce an export, not only send an email. Define country-specific response deadlines with the reviewer; use a configurable deadline table and test reminders/escalation. Avoid deleting legally retained financial records without classification.
6. Define retention per data category and purpose, including verification images, declined applicants, abandoned drafts, chat, coach projections, deleted accounts, provider analytics and backups. Automate expiry where feasible; test delete retries, partial failure and completion claims. Withdrawal stops future optional collection; it is distinct from requesting deletion of already-collected data.
7. Prepare an incident runbook: accountable contact, detect/contain, assess affected data/countries, preserve minimum evidence, notify regulator/users where required, recovery and lessons. Have the legal reviewer set actual jurisdiction/sector deadlines; do not hardcode “72 hours everywhere”. Test the runbook with synthetic data.
8. Review age eligibility and guardian rules, coach professional boundaries, ID/biometric verification, consumer cancellation/refund rights, marketplace obligations, tax/invoicing and regulated payment/payout activity for the selected offer in each market. Use a licensed eligible provider; no custom stored-value wallet or escrow. Trainer-reviewed educational content must not drift into diagnosis or regulated treatment without a separate assessment.
9. Update bilingual notices, processor list, contacts and app-store privacy/Data safety declarations to the shipped behavior. Maintain processor agreements and lawful transfer evidence. The repository's existing Egypt-oriented notices need expansion before Saudi/UAE release; adding this guide does not publish or legally approve them.
10. Preserve core flows in tests with all optional switches off. If a country's rules require a hosting/process change, implement an appropriate regional backend/processor adapter and migrate only authorized data. Do not delete core features to simplify compliance or silently route prohibited data abroad. If required infrastructure/approvals are unavailable, report that country's release as blocked while preserving the implementation and already-lawful markets.

Budget priorities: collect less, retain less, reuse existing local caches and permission gates, keep self-service privacy controls simple and spend review effort first on health, ID/biometrics, international transfers and coach payments. Do not buy a generic “compliance badge” or assume a cloud provider's certification covers Own Hub.

## 14. Tests, evidence, and agent handoff

Read [the acceptance test guide](../../acceptance/free_launch/README.md) and [the launch acceptance checklist](../../acceptance/free_launch/ACCEPTANCE.md) before coding. Executable tests are intentionally separate from the ordinary suite because some test future APIs. A missing API is an expected baseline failure, not a skipped release criterion.

Run `bash acceptance/free_launch/run.sh` from the repository root. The G suite (`gamification_contract`) covers §15 and is expected to pass. This must finish with a nonzero exit if any required suite fails or a tool is absent. Logs remain in `acceptance/free_launch/results/` (ignored). Do not rewrite a test to accept current broken behavior, add `skip`/`xfail`, or replace production calls with hardcoded expected outputs.

The initial tests cover selected existing behaviors and proposed pure domain contracts. They do not prove real payments, authorization, media playback, notification delivery, multi-device synchronization, or coach/member usability. The checklist explicitly records the integration tests and device evidence that the implementing agent must add. Passing the initial pack alone is not launch approval.

Implementation responsibilities:

1. Reconcile this guide with current code, record changed assumptions, and confirm unresolved commercial/content decisions before dependent implementation.
2. Make small feature-scoped changes. Extend existing models; do not create a second independent workout or payment system.
3. Read `README.md` for generated-code boundaries. Use the localization helper/generators; do not hand-edit generated ARB, route, or token outputs. Every new surface needs a feature switch and bilingual copy.
4. Implement the new production contracts exercised by the tests; connect them to real call sites. Pure policies passing without UI/server integration are incomplete.
5. Add server/rules tests for every new authorization and payment boundary. Reuse the existing fake Firestore and emulator test infrastructure without contacting production.
6. Run affected suites while implementing; run the full Flutter, Python, Firestore, and Storage suites before the final implementation handoff. Run Android/iOS builds with local credentials, never committed credentials.
7. Complete each acceptance checklist row with test or evidence references, remaining blockers, and measured cost observations. Do not turn unchecked rows into claims of success.

Existing verification commands (read setup instructions first):

```sh
# Run from the repository root:
(cd app && flutter pub get && flutter analyze && flutter test)
(cd functions && .venv/bin/python -m pytest)
# Firestore: run the local emulators from the repo root as README describes,
# then npm --prefix test/rules test. Storage: npm --prefix test/rules run test:storage.
```

Baseline validation before this guide: analyzer clean; full Flutter run had 5,302 passes and nine stale Arabic assertion failures, then all 175 tests in affected files passed after corrections. Backend 1,233, Firestore 337, Storage 14 passed. The entire Flutter suite was not repeated after those test-only corrections. These results are historical context, not evidence for any new feature.

Research supporting product direction: [Hevy workout workflow](https://www.hevyapp.com/features/track-workouts/), [Sweat equipment substitutions and planning](https://sweat.com/blogs/community/how-to-use-the-sweat-app), [Fitbod progression](https://help.fitbod.me/hc/en-us/articles/43492523917207-How-does-Fitbod-adapt-as-I-get-stronger). Their feature presence does not establish a guaranteed retention or revenue effect for Own Hub.

## 15. G: motivation design from two video studies

Added 13 October 2026 on baseline `d353189`. Decisions: `DECISIONS.md` D37–D41. Acceptance rows: [G01–G20](../../acceptance/free_launch/ACCEPTANCE.md). This section applies to every member screen, not to one feature.

Sources, both studied in full:

- Tim Gabe, *I Studied 500+ Gamified Apps (Here's What Actually Works)*, May 2026, https://www.youtube.com/watch?v=LXX_qOA5D8E. Seven patterns.
- Wyatt Feaster, *The psychology trick that makes any app feel 10x better*, September 2026, https://www.youtube.com/watch?v=MVOpq3WRnbo. Five patterns.

Every figure below is the speaker's claim, quoted as a claim. None was verified for Own Hub, and none promises a retention or revenue effect.

### 15.1 What each pattern says, and what Own Hub does with it

| # | Pattern (video) | The claim | Own Hub decision |
|---|---|---|---|
| 1 | Points, badges, leaderboards are the scoreboard, not the game (V1) | Rewarding the metric breeds metric-chasing. LinkedIn retired Top Voice badges (2024), Foursquare dropped badges (2014), Google News dropped its badges; Strava reached 180M users without classic badges. | **Adopted.** No new point types. Points come only from training and eating, and R10 shows them as a quiet line under her real results. |
| 2 | Local, winnable competition (V1) | Strava segments: thousands of small cohort leaderboards people can win; kudos increase later activity (2022 ScienceDirect study; clubs +59% in 2024; 14 billion kudos in 2025). | **Adapted (D38).** One weekly challenge against her own last week, always beatable by finishing her plan. No ranking of women, no kudos while community is off. |
| 3 | The S-curve of feature richness (V1) | Engagement rises with mechanics, then falls (2025 *Frontiers in Psychology*); Habitica's game layer buried the real work. | **Adopted.** Only two mechanics are added (streak, challenge). The existing ones are made honest, not multiplied. |
| 4 | The streak trap (V1) | Streaks turn from motivation into obligation (Decision Lab); a 2023 Belgian study of about 2,500 adolescents linked them with FOMO; Snapchat was sued (Nevada, 2024); the EU Digital Fairness Act targets them. Duolingo's safe version: she picks the goal, can freeze, can escape. | **Adapted (D37).** A training streak she controls: rest days count while the week's goal is reachable, an earned rest week covers a slipped week, pause and off switch, silent ending, never in notifications or widgets. |
| 5 | Variable reward magnitude (V1) | Anticipation, a one-by-one reveal and a celebration with haptics pull people forward instead of threatening a loss. | **Adapted (D40).** R10 reveals her real results one by one. **Rejected:** any prize decided by chance. |
| 6 | Completion drive (V1, the one to pick) | Apple's rings use Gestalt closure; claimed 49.5% behaviour change across 160,000 people, and 48% lower odds of poor sleep among ring-closers. | **Adopted.** The week marks close, a set bar runs through every workout, and the first-week arc can finally complete. |
| 7 | Competence over badge theatre (V1) | Gamification lifts autonomy and relatedness but barely competence (2024 Springer Nature meta-analysis); Peloton's live output and automatic personal records (15% more workouts), Chess.com Elo, Garmin readiness. | **Adopted.** Personal bests only when she really improved, shown with her previous value; last-time numbers on every set; milestones that actually move. |
| 8 | Goal gradient (V2) | Motivation rises near the finish line; show "5 of 7", not "complete this task". | **Adopted.** "{done} of {total} sets done" during the workout; "one more and this week counts"; the nearest milestone on Progress. |
| 9 | Peak-end rule (V2) | People remember the best moment and the end (Airbnb and Duolingo success screens); broken flows are remembered for their friction. | **Adopted (D40).** R10 is the peak, with reveal, paper confetti, kitten cheer and haptics. The low points are fixed first: a duplicate session, a rest timer that opened at 0:38, undo that did not rewind, a last set that could be lost, rewards shown that were never paid. |
| 10 | Labour illusion (V2) | People trust results more when they see the work; sensitive checks feel safer when not instant. | **Adapted (D39).** Short steps on O05 and C12 that each name an operation that really ran. **Rejected:** fake waits, and any wait on frequent actions. |
| 11 | Von Restorff effect (V2) | The item that differs is the one remembered; good apps choose what to highlight. | **Adopted.** One emphasised element and at most one filled primary button per screen state; R11 marks one recommended session. |
| 12 | Choice overload (V2) | Too many options cause hesitation; filter, group or remove. | **Adopted.** Home has one primary action and at most three secondary items; day one hides the optional rows behind "More you can do"; R11 shows filters only when there are more than three sessions; R08 offers only weights around her plan. |

### 15.2 Rules that hold everywhere

- Reward real training and eating only. Never reward opening the app, posting, inviting or completing a profile.
- Nothing is decided by chance. No random prize, bonus or unlock.
- Nothing ranks women. Competition is with her own past only.
- Ending a streak, missing a challenge or skipping a week is silent and never red. The kitten is never sad.
- One celebration per session, on R10. Every motion plays once, can be skipped by a tap, and holds still under Reduce Motion.
- Show only figures that are hers. A number that was not earned is not shown.
- Streak, challenge and rewards stay on the phone. `firestore.rules` and cloud sync are unchanged.
- Copy: Egyptian Arabic and English as equals, feminine address, Western digits, no em dashes, no loss words ("lose", "break", "miss", "at risk") near the streak.

### 15.3 Work packages

| Package | Content | Rows |
|---|---|---|
| G0 | Decisions D37–D41, this section, acceptance rows | — |
| G1 | Workout plumbing: one session per Start, a session-scoped log bus that flushes before credit, real rest timer and up-next, undo that rewinds, weights around the plan, hold seconds, set bar | G01, G02, G10 |
| G2 | One current week and a day that rolls over; Home's done state; first week completes | G08, G09 |
| G3 | Honest rewards: persisted ledger and cap, counted week, real bests, food day, milestones, week close on open and resume | G03–G07 |
| G4 | Feature switches `trainingStreak`, `weeklyChallenge`, `finishReveal`, `haptics`, `reassuringWaits`; rule guards | G12, G18 |
| G5 | Training streak (D37) | G11, G12 |
| G6 | Weekly challenge (D38) | G14 |
| G7 | Visible progress: set bar, week counted, first week inside the week block, next milestone | G08, G09 |
| G8 | R10 peak (D40): staged reveal, paper confetti, haptics, sage bests, kitten budget | G15 |
| G9 | Reassuring waits (D39) on O05 and C12 | G16 |
| G10 | Fewer choices and one emphasis per screen | G17 |
| G11 | Switches on, contract suite, design and mascot docs | G13, G19, G20 |

### 15.4 Known limits

- The streak and the ledger are not synced: a new phone starts them fresh.
- A first-ever lift still counts as a personal best for tiers and the `first_personal_best` milestone, as before. R10 and points celebrate only a real improvement.
- The week runs Monday to Sunday (ISO). Copy never names the last day of the week, because many Egyptian users think of Saturday as the first day.
- Device evidence for haptics, Reduce Motion and Arabic at 200% text is the owner's to collect (G20).

## 16. Animation quality: two video studies

Added 15 October 2026. Decision: `DECISIONS.md` D46. This section applies to every member screen.

Sources:

- Jason Lee, *Watch Me Vibe Code an Animated App with Claude Opus 5.5*, https://www.youtube.com/watch?v=Rk6t9Uq1y9M (20:56).
- John Kim, *AI App Animations is Hard Until You Learn This*, https://www.youtube.com/watch?v=f-Ar8mwm3kQ (22:50).

**What was and was not available.** Only each video's description and chapter list were read. No transcript was available for either: the captions need a session token, and Lee's prompts page is behind an email signup that was not filled in. So nothing below quotes or paraphrases what either speaker said, and none of it is checked against the footage.

- From Lee's chapters and description: build the app's structure first; then a dedicated animation-quality pass; then animation that responds to the phone's tilt; with screen references and generated motion assets.
- From Kim's description and chapters: the toolbox is keyframes, springs, gestures, physics, layout transitions, particles, Rive and Lottie; you compose them; you review the motion yourself. His examples include a gesture-driven tilt and confetti on finish.
- Finch and Gentler Streak are cited where the 14 October research of top-rated apps names them (guide section 15 and the plan's references); their exact timings were not published. Where a row says "Own Hub's choice", no source names it, and it is standard mobile practice or our own.

Nothing here promises a retention or engagement effect for Own Hub.

### 16.1 Pattern, decision, where

| Pattern (source) | Own Hub decision | Where |
|---|---|---|
| A dedicated animation pass after the structure exists (Lee) | Motion is a separate work package (WP6) applied to finished screens, then reviewed in the screenshots. | whole app |
| Animation that responds to phone tilt (Lee) | The accelerometer moves two pieces of art up to 8 px, low-pass filtered, while their screen is in front. Not the kitten. | C01, R10, `ui/hand/tilt_parallax.dart` |
| Compose a few tools rather than one big effect (Kim) | Flutter's own animation classes only, combined as below. | `lib/ui/hand/` |
| Springs (Kim) | Buttons and tappable rows shrink to 0.97 on a spring. | `AppButton`, `AppListItem` |
| Gestures (Kim: gesture-driven tilt) | The progress card leans up to 6 degrees under a finger and springs back. | P05, `ui/hand/finger_tilt.dart` |
| Layout transitions (Kim) | Cards and lists that change state fade and resize. | T01 cards, R03 moves, `ui/hand/hand_swap.dart` |
| Particles on finish (Kim: confetti) | The existing paper confetti stays the only particles, and now comes last. | R10 |
| A response to every finished action (Finch) | Already built in WP5; the press spring and the R10 staging extend it. | R07, R13, E04, E08, Y09, R10 |
| Progress over comparison (Gentler Streak) | The week fills and its figure counts up against her own plan. | R10 |
| Review the motion yourself (Kim) | Motion is checked in the screenshots and on a device, not accepted from a test alone. | WP7, G20 |
| One set of timings (Own Hub's choice) | Three durations, 150, 220 and 400 ms, standard curves and one spring. | `ui/hand/motion.dart` |
| Route transition (Own Hub's choice) | One Material fade-through for every route, none under reduced motion. | `theme/hand_theme.dart`, `ui/hand/page_transition.dart` |
| Staggered entrances (Own Hub's choice) | The first eight rows ease in, 40 ms apart, once per visit. Bars tween. | R01, R11, R14, E05 |
| Skeleton while a load lasts (Own Hub's choice) | A shimmer on posters, still under reduced motion, gone when the data arrives. | R14, R15 |

### 16.2 Rejected

- **Rive and Lottie** (both named by Kim). Each adds a runtime and an authoring file format for motion Flutter already does. The kitten must stay pure Flutter under the mascot rules, and a state machine in a binary file cannot be checked against the no-loop and budget tests.
- **Shaders.** Budget phones in Egypt are the floor, and no screen needs a look a gradient cannot give.
- **New looping animation.** The shimmer is the only one that repeats, and only while a load lasts.

### 16.3 Rules that hold

- Every animation asks `handMotionOff` and is still under Reduce Motion, Android "Remove animations" and, for the tilt, the Profile motion switch.
- Nothing delays an action she is doing: presses answer at once, and entrances never block a tap.
- Sensor readings stay on the screen. Nothing is stored or sent, and there is no permission prompt.

### 16.4 Known limits

- The fade-through replaces iOS's edge-swipe back gesture; the Back button and the system back action still work. Restoring the swipe means taking iOS out of the theme's transition map.
- R10's heavy "big moment" haptic is no longer played; the one haptic is the medium impact as the kitten cheers.
- Device evidence for the tilt, the haptic and reduced motion is the owner's to collect (G20).
