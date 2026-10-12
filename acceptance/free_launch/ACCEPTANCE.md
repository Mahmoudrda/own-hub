# Launch acceptance tests and review ledger

All rows begin **OPEN**, including rows with existing implementation until current evidence is attached. “Prewritten” means runnable now with expected failures described in [README](README.md). “Add integration” is a concrete test specification for the implementing agent to create as its real adapter lands. Device/owner review cannot be replaced by a mocked unit test.

Use synthetic accounts, programmes and payment records. Never put health data, ID images, tokens or card details in screenshots, logs or fixtures.

## C0 — coach workflow and commerce

| ID | Given / action | Required result | Evidence type |
|---|---|---|---|
| C01 | Invited coach submits incomplete/complete profile and credential | Clear next step; draft templates allowed while pending; publishing rejected until verified | Add UI + server integration |
| C02 | Open valid/expired/revoked invite before sign-in; finish sign-in and verification | Destination survives; only valid authorized relationship can be accepted; no implicit purchase | Add deep-link + function/rules integration |
| C03 | Two concurrent accepts at final capacity slot | Server grants at most available capacity, clear retry/error for other request | Add transactional server test |
| C04 | Duplicate template for clients A/B; edit A and original template | B and published versions unchanged; draft changes remain private | Existing coachplan + add repository integration |
| C05 | Edit draft, force-stop, reopen offline; reconnect after another device publishes | Draft survives; queued operation revalidates, conflicting version cannot silently replace plan | Add persistence/conflict integration |
| C06 | Coach previews and publishes same request twice, then client opens separate device | One immutable version/receipt/current pointer; actual client assignment arrives | Add emulator + two-device test |
| C07 | Different coach/expired relationship/forged uid/revoked role attempts read/write | Denied by server/rules, not merely hidden in UI | Add emulator negative tests |
| C08 | Client revokes health/raw-log sharing | Subsequent authorized projection omits it; cached view invalidated/expired; ordinary plan delivery works | Add rules/projection/cache tests |
| C09 | Payment flag off and no provider configured; client/coach opens affected routes | Free training and draft work usable; no working-looking Buy or fake paid/payout state | Add UI/gate regression |
| C10 | Client alters price, commission, currency, offer version or beneficiary | Server ignores/rejects client claims and uses accepted immutable offer | Add function integration |
| C11 | Forged/invalid signature or browser “success” without confirmed payment | No paid entitlement, revenue or payout record | Add provider sandbox/security test |
| C12 | Duplicate, delayed and out-of-order verified notifications; retry after partial failure | One durable transition/ledger effect; transaction rollback/retry consistent; no paid resurrection after full refund | Add transactional integration |
| C13 | Synthetic rates, integer boundaries, partial/full refunds, invalid numbers | Exact documented breakdown, conservation, no float/bool inputs | Prewritten Python commission suite |
| C14 | Payment timeout then later authoritative success; wrong amount/currency | Pending truthfully shown; verified valid success activates once; mismatches quarantined for reconciliation | Add provider sandbox test |
| C15 | Partial/full refund after payout, dispute, payout failure/retry | Separate reversal/adjustment ledger, defined reserve/negative balance handling, no duplicate transfer | Add provider sandbox + owner reconciliation |
| C16 | Coaching ends/refunds; compare free training/history before and after | Paid entitlement follows contract; own history and free features remain | Add integration |
| C17 | Coach opens earnings/exports statement; owner compares provider report | Gross, commission, fees, refunds and payable reconcile exactly; pending differs from paid | Add UI/export + reconciliation evidence |
| C18 | Offer/billing country/store classification and fee allocation unresolved | Payments stay gated; no invented commercial promises | Owner/store-policy review |

## F1–F7 — useful gym training

| ID | Given / action | Required result | Evidence type |
|---|---|---|---|
| F101 | Empty/compatible/incompatible programme catalogue | Honest no-match or compatible result; unavailable equipment never recommended | Prewritten existing-behavior suite |
| F102 | Traverse every launch programme/week/day and all approved swaps | All required content resolves; bilingual cues/setup reviewed; no placeholder pretending complete | Add content validation + trainer sign-off |
| F103 | Miss a day, take rest, finish a week/programme; reopen | Stable next session, no duplicate/fabricated completion; selected plan reaches actual workout | Add sequence/router integration |
| F201 | Valid demo, missing/expired URI, download failure and retry | Real player or honest useful fallback; same workout position on return | Prewritten media-surface test covers mounting only; add plugin/error tests |
| F202 | Cached clip in airplane mode; new media version; interrupted playback | Correct content/version, explicit storage/download handling; logged sets unchanged | Android/iPhone device evidence |
| F301 | Old equipment profile and new gym vocabulary | Old wire values retained, new values available | Prewritten existing-behavior suite |
| F302 | Home/gym switch, unknown future equipment, specific machine absent | Only supported candidates; unknown is not “all available”; coach sees authorized changes | Add model/migration + integration |
| F303 | Switch units, per-hand/total/stack basis, unavailable increment | Historical values preserved; labels clear; unsupported progression not offered | Add conversion/UI tests |
| F401 | Swap a live row exercise using repository candidate | Actual exercise queried and mapped; session-only replacement, no results fabricated | Prewritten existing-behavior suite |
| F402 | Busy station, unsuitable candidate, no candidates, offline curated map | Approved pattern/equipment/constraint match; truthful no-match; coach knows permitted deviation | Add domain/router/offline integration |
| F501 | Mid-session snapshot, clear all memory, restore | Same ID, plan version, move and set index | Prewritten existing-behavior suite |
| F502 | Log/edit/undo/swap then force-stop offline and reopen | Actual results and undo/swaps retained; no local durability gap | Add persistence + device tests |
| F503 | Reconnect twice, same edit queued twice, corrupt one snapshot section | No duplicate credit/results; unrelated valid sections survive | Add sync/idempotence/corruption tests |
| F504 | Background/lock during rest; extend, skip, leave, kill/reopen | Deadline-derived time; stale notifications cancelled; no unwanted navigation | Fake-clock tests + real devices |
| F505 | Logout/switch account/delete local data | No prior account's live workout, cached coaching data or health shown | Add privacy integration |
| F601 | Null/incomplete/difficult/pain/return history or unsupported weight | No automatic increase; correct hold/review | Prewritten progression suite |
| F602 | All targets met, unsorted/duplicate increments, coached plan | Next supported increment; inputs unchanged; coach approval required | Prewritten progression suite |
| F603 | Suggestion exists; coach has not published | Actual assigned plan unchanged; review/accept/reject auditable | Add publish integration |
| F701 | Start prescribed workout without entering results | No logged outcomes manufactured | Prewritten existing-behavior suite |
| F702 | Log/edit/skip/undo normal sets while offline | Actual previous values, correct totals, no duplicate awards/coach rollups | Existing train + add integration |
| F703 | Large text/RTL/keyboard on logging and rest pages | Action reachable, units clear, Western digits correct, no overflow or lost state | Widget + Android/iPhone device evidence |

## U0 — first-time understanding and navigation

| ID | Given / action | Required result | Evidence type |
|---|---|---|---|
| U01 | English/Arabic guide at 360×740 and 200% text | Four short steps; Back/Next/Start/Skip work; controls labelled/reachable | Prewritten first-gym widget suite |
| U02 | Practice log/undo, close guide, open actual workout | No practice result/reward/coach summary persists; actual selected workout opens | Add route/state test |
| U03 | Dismiss/complete guide then restart, switch profile, reopen Help | Per-profile/version state correct; guide optional and discoverable offline | Add persistence/integration |
| U04 | Check every enabled route in member and coach shells | Role-correct destinations, stable order, no dead disabled features, expected Back/deep-link context | Add route inventory + navigation tests |
| U05 | Each page in loading/empty/error/offline/success states | Only task-relevant content, clear next step, retry retains input, duplicate submits prevented | Screen review + widget tests |
| U06 | All core pages with TalkBack/VoiceOver, 200% text, small screen, keyboard | Logical focus, labelled 48px targets, readable contrast, RTL layout, no obscured controls | Accessibility tests + devices |
| U07 | Five newcomers attempt guide/demo/swap/log/undo/resume/privacy without instruction | Proposed target 4/5 on each task; no critical error; record confusion and retest | Observed usability, no replay required |
| U08 | Three coaches onboard, reuse/adapt template, preview/publish and review | All distinguish draft/published and complete delivery; record wrong turns | Observed usability |
| U09 | Analytics/backup/notification consent declined; permissions denied | No stacked prompts or blocked core features; contextual help works | Add end-to-end negative-choice tests |

## P0 — local-first storage and Egypt launch readiness

Saudi/UAE checks in P11/P12 are **DEFERRED—future expansion**, not Egypt launch blockers. P06–P09 apply to Egypt at launch and must be repeated for additional markets before expansion.

| ID | Given / action | Required result | Evidence type |
|---|---|---|---|
| P01 | Synthetic account, capture traffic before/after each consent | No unauthorized health/identity/message payload in APIs, SDKs, logs, push, crash reports or exports | Network inspection + automated payload guards |
| P02 | Health backup off; local logging/reading then kill/reopen | Health remains usable locally; no health upload; device-loss implications accurately explained | Add integration/device test |
| P03 | Inspect persisted files, OS backup and account switch | Document actual encryption/key storage/backup policy; no other-account exposure | Device/storage/security review |
| P04 | Export/correct/delete account and withdraw optional sharing | Requested operations complete with tracked status; lawful retained records separated; no false “deleted” claim | Add function/rules/device tests |
| P05 | Expiry/deletion job interrupted, retry, cached projection, restore backup | Idempotent cleanup; deleted data not silently restored; truthful pending state | Add backend recovery tests |
| P06 | Egypt market decision record (Saudi/UAE only before future expansion) | Current applicability, permits/registration/DPO duties, sensitive/biometric handling and lawful transfers assessed and signed off | Owner + qualified local review |
| P07 | Hosting and recipient map includes Firebase, PostHog US, SMS, push, logs, support, backups | Actual processing locations and contracts recorded; sector/localization applicability resolved | Processor/transfer assessment |
| P08 | Privacy/terms/store disclosures reviewed against actual build | Arabic/English accurate, contacts/retention/rights process ready for Egypt; extend before expansion | Owner review + build/network evidence |
| P09 | Simulated personal-data incident | Responsible owner, country-specific deadlines, containment/notification/recovery workable | Tabletop exercise |
| P11 (DEFERRED) | Egyptian, Saudi and UAE phone/document fixtures, Arabic digits, supported residents and invalid/expired IDs | Correct country-aware normalization; no Egyptian parser on foreign ID; verification gate preserved; permitted SMS routes and costs checked | Add auth/provider integration + operations review |
| P12 (DEFERRED) | EGP/SAR/AED offer display and supported payout countries | Actual currency/minor units preserved; unsupported purchases blocked honestly; no renamed historical amounts | Add commerce/UI + provider evidence |
| P10 | Turn all optional analytics/backup/sharing off; finish full core user journeys | Free training/history/cycle and required coach delivery still work with minimum necessary data | Add end-to-end regression |

## PostHog — implemented now, separate from future features

| ID | Given / action | Required result | Evidence type |
|---|---|---|---|
| A01 | No/fresh/old consent, grant, revoke during setup, queued event after revoke | No pre-consent setup; old Google-only grant not reused; no stale queued app event; reset on withdrawal | `app/test/release/posthog_analytics_test.dart` |
| A02 | Repeated events, unknown event, raw properties, 150 captures, SDK failure | Only eight milestone names, caller properties dropped, 120/process cap, failure isolated | Same executable suite |
| A03 | Inspect config/native files | Replay, surveys, flags, push capture, lifecycle and native auto-init disabled; one fixed status log | Same executable suite + native review |
| A04 | Opt in on real Android/iPhone using explicit debug flag; perform genuine milestone | Event and `analytics_ready` log received in correct project; no sensitive payload; after revoke/restart inspect queued delivery behavior | Device + PostHog project evidence still required |
| A05 | Check project billing/retention/processor settings | Free plan/no paid add-ons or $0 billing limits confirmed; actual retention and transfer approval recorded | Owner dashboard review; ingestion token cannot inspect settings |

## Final review and handoff

- Attach actual results and unresolved failures to each row; do not blanket-mark the table complete.
- Full regression: Flutter analyze/tests, backend tests, Firestore/Storage emulators, Android/iOS builds; no credentials committed.
- Confirm guide/API/tests agree and new functions are called by real UI/backend paths.
- Free launch: all applicable F/U/P and operational checks pass. Paid launch additionally requires every C0 revenue/delivery check and actual approved gateway/store setup.
- Document provider cost observations and content/media rights. No promised commission margin until rates, fees, refunds and support costs are known.
