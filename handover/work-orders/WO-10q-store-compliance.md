# WO-10q: store rules for taking payment for coaching outside in-app purchase
Depends on: none (reading and writing only)
Size: M
Reads first: `docs/release/review-notes.md` (all); `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` sections 5, 12.3, 13.1; `docs/plan/RELEASE-2-PLAN.md` section 3 (coaching); the two policy pages below (already read once on 27 Oct 2026; Gemini does not need to fetch them again)

## Why
The owner wants members to pay coaches by InstaPay inside the app flow. Both stores have rules about payments for what an app delivers. Getting this wrong can mean a rejected update or a removed app. This order records what each policy says, which exemptions might fit, the honest risks, the exact paragraph for the review notes, and the questions to put to Apple and counsel. EVERY CONCLUSION BELOW IS "NOT VERIFIED WITH APPLE" (or Google). Nothing in this order is legal advice.

## Final result
This file, plus the edit to `docs/release/review-notes.md` in step 3 (the paragraph and the cuts), plus the question list in step 4 copied into `handover/QUESTIONS.md` under the heading "Questions for Apple, Google and counsel (payments)".

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| handover/work-orders/WO-10q-store-compliance.md | this file | the analysis |
| docs/release/review-notes.md | edit | the paragraph and the cuts (step 3) |
| handover/QUESTIONS.md | edit | the question list |

## Steps
1. What Apple says (App Review Guidelines, section 3.1, read at https://developer.apple.com/app-store/review/guidelines/ on 27 Oct 2026). Paraphrase, with guideline numbers:
   - 3.1.1: to unlock features or functionality in an app (examples: subscriptions, premium content, a full version) the app must use in-app purchase, and may not invent its own unlock mechanisms. NOT VERIFIED WITH APPLE: whether a package of one coach that opens chat, plans and check-ins for one client counts as "unlocking functionality".
   - 3.1.3 (opening sentence): apps in the exemption list may not, inside the app, encourage people to use a purchasing method other than in-app purchase, except for the U.S. storefront and the cases named in 3.1.1(a) and 3.1.3(a). This is the sentence an InstaPay payment screen runs into unless an exemption fits.
   - 3.1.3(d) Person-to-Person Services: if the app lets people buy real-time person-to-person services between two individuals, with the examples of tutoring, medical consultations, real estate tours and fitness training, the app may use a purchase method other than in-app purchase to collect those payments. One-to-few and one-to-many real-time services must use in-app purchase. This is the exemption that most directly fits one coach and one client. Its limits: "real-time" and "between two individuals".
   - 3.1.3(e) Goods and Services Outside of the App: services that will be consumed outside the app must use payment methods other than in-app purchase. Fits the live sessions (they open in the coach's own video tool, outside the app); fits less the plans and chat that live inside the app.
   - 3.1.3(a) reader apps, (b) multiplatform, (c) enterprise, (f) free stand-alone companion, (g) advertising management: none fit.
   - 3.1.2: auto-renewable subscriptions are the Apple way for ongoing digital value: not used here.
   NOT VERIFIED WITH APPLE: the text after character 100,000 of the guidelines page was not read (it is the later sections, not 3.1).
2. What Google says (Google Play Payments policy, https://support.google.com/googleplay/android-developer/answer/10281818, read on 27 Oct 2026). Paraphrase:
   - Digital items, subscriptions (the policy lists fitness subscriptions), app features and cloud services sold in an app distributed on Google Play must use Google Play's billing system, unless the policy permits otherwise.
   - Exemptions that exist: physical goods and services (examples: gym memberships, transport, food delivery); peer-to-peer tips where 100 percent goes to the creator and nothing digital is unlocked; consumption-only apps; purchases that cannot be used in a Play app; and "1:1 online services": billing is not required if the paid service is between two individuals and is not available for replay afterwards. The policy names health coaching, such as personal trainer sessions, as an example.
   - Inside the app a developer may not lead users to a payment method other than Play's billing, which includes language that encourages buying outside the app, unless an exemption applies.
   - The page says the requirement does not apply where Google Play's billing system is not yet available; whether that includes Egypt for this app is NOT VERIFIED WITH GOOGLE.
3. Reading for Own Hub (all NOT VERIFIED WITH APPLE / GOOGLE):
   - What helps: a coaching package is one coach and one client; the examples in both policies name personal training; Own Hub never holds the money; Own Hub sells no digital good; the app's own features (Home, Train, Eat, Events) stay free and are not unlocked by any payment; live sessions run outside the app.
   - Risk A (Apple 3.1.3(d)): the exemption speaks of real-time services. A package also gives asynchronous plans, check-ins and chat that sit inside the app after payment. A reviewer may read "pay, then chat and plans unlock" as unlocking functionality (3.1.1) and the payment screen as steering to another method (3.1.3). Mitigation: describe the package as a personal service between two named people; the live sessions are in the package; the chat and plans are how that coach delivers it, not features of the app.
   - Risk B (Google 1:1 exemption): the service must "not be available for replay afterwards". Saved plans and chat history stay in the app, so a reviewer may say it can be replayed. Mitigation: unknown; ask Google.
   - Risk C: Own Hub's fee (D63) is paid by the coach to Own Hub by InstaPay. A reviewer could see Own Hub as taking a commission on a digital service. Mitigation: the fee is for introducing a client to a service delivered by the coach.
   - Risk D: the Egypt storefront: whether the rules apply the same way is NOT VERIFIED.
   - Risk E: the review account cannot make a real transfer, so the reviewer sees the payment instructions only. State this in the notes (below).
   - Risk F: if Apple rejects, the fallback is to turn the server switch off (`config/payments.enabled`, spec 10) and ship with "Free for now" as today. No code change is needed. Say this to the owner.
4. The exact review-notes paragraph (English, App Store Connect "Notes", Play "App access" notes). Put it right after the line `SIGN IN WITH THE TEST ACCOUNT` block and before `NEW IN THIS VERSION`:
```
PAYING A COACH (new)
A member may pay an independent coach for one-to-one coaching by InstaPay, from her own bank app. Own Hub never holds or moves the money. No feature of the app is unlocked by a payment: Home, Train, Eat and Events stay free. The coaching is a personal service between two individuals, fitness training (guideline 3.1.3(d)), with live sessions in the coach's own video tool outside the app. The app shows who to pay and how much; the coach confirms receipt. We sell no in-app purchases, subscriptions or digital goods. No real InstaPay account is needed to review: the test account can open the payment instructions but cannot pay.
```
Then make these exact edits to the same box so it stays at or under 4,000 characters (it is 3,961 now with the owner's test values filled; Apple's limit is 4,000):
   - `No ads and no purchases.` becomes `No ads. No in-app purchases.`
   - delete ` No payments in this version.` at the end of the "Coaching (applications and portfolios)" line.
   - replace the whole "NOT IN THIS VERSION" paragraph text with `Community and the AI assistant are switched off by flags compiled into this build and cannot be turned on remotely.`
   - delete the line `Widgets ("Your week", "Today") show session counts only, never health data.` and its blank line.
   - delete the line starting `Events: published by Own Hub.`
   - delete the line starting `Profile photo: camera or system picker`
   - replace the line starting `Meal photos:` with `Meal photos: Eat > Scan your meal. One photo goes once to Google Cloud Vertex AI in Frankfurt and is never stored.`
   - in the Permissions sentence delete `, and motion (to tilt a few illustrations)`.
   Check the length with this command (fill the `[OWNER: ...]` values first so the count is real):
```
python3 - <<'EOF'
t = open('docs/release/review-notes.md', encoding='utf-8').read()
s = t.index('```') + 3
box = t[s:t.index('```', s)]
print(len(box))
EOF
```
It must print 4000 or less after the owner's values replace the `[OWNER: ...]` placeholders (a dry run on 27 Oct with the placeholders still in gave 4,008, about 18 above the real count). If it is over, shorten the "Coaching" line first. Also update the first paragraph of the file (the "Updated ..." note) to say the box was changed for payments, and the number of characters.
   For Play, the same facts go in `docs/release/launch-pack/play-app-access.md` (UNVERIFIED path: `ls docs/release/launch-pack | grep play`); in the Play Console "Payments" or "App content" answers state that the app does not sell digital goods or subscriptions through the app and that coaching is a one-to-one service paid directly to the coach (NOT VERIFIED which form Play shows for this).
5. Questions to ask (copy to `handover/QUESTIONS.md`):
   Apple, through App Review (a pre-submission question in App Store Connect, "Contact Us", or an appeal after a rejection):
   1. Does a one-to-one fitness coaching package, whose service is delivered partly in live video sessions outside the app and partly through personal plans and text chat inside the app, qualify as a person-to-person service under guideline 3.1.3(d)?
   2. May the app show payment instructions for an external bank transfer (the coach's InstaPay address, the exact amount and a reference) without using in-app purchase, and may it then give the client access to that coach's chat and plans after the coach confirms receipt?
   3. Is it acceptable that Own Hub receives a fee from the coach, paid outside the app, for introducing the client?
   4. Does the answer differ on the Egypt storefront?
   5. What must we show App Review, given that a reviewer cannot complete a real InstaPay transfer?
   Google, through Play Console support:
   6. For the 1:1 online services exemption, is a personal plan or a chat history that stays in the app "available for replay afterwards"?
   7. Does the policy's list of regions without billing include Egypt for paid services like this?
   8. Which Play Console declarations must we answer for an app that links members to an external payment method under the 1:1 exemption?
   Counsel:
   9. Does the exemption reasoning above hold under the stores' terms as signed by the owner's developer accounts?
   10. Does handling no money at all keep Own Hub outside payment-service regulation in Egypt (spec 12.2)? (also in `instapay-terms-drafts.md`, WO-10j3)
6. What the owner must decide before submitting: whether to ask Apple first (recommended: a pre-submission question, because a rejection costs days) or submit and use the switch as the fallback.

## Strings to add
None.

## Tests to add or change
| file | test | what |
|---|---|---|
| (command) | `the review box is within the limit` | the python snippet in step 4 prints 4000 or less with the owner's values filled |
| (command) | `no stale sentence remains` | `grep -n "No payments in this version\|no purchases" docs/release/review-notes.md` prints nothing |

## Verify
- the two commands above give the stated output.
- `grep -c "PAYING A COACH" docs/release/review-notes.md` prints 1.

## Do not
- Do not state in the notes that Apple or Google approved anything.
- Do not describe the feature as "peer-to-peer tips" or "gifts".
- Do not name the owner's private contact details in the notes.
- Do not quote the policies at length in any document; paraphrase.

## Done checklist
- [ ] review-notes paragraph and cuts, character count under 4,000
- [ ] questions copied to QUESTIONS.md
- [ ] owner told the fallback (the server switch)

## If stuck
If an anchor is not found or the count stays over 4,000: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10k1).

UNVERIFIED in this order: 0 facts about the code; every policy conclusion is "not verified with Apple/Google" by design (see step 3).
