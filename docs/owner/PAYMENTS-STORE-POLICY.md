# Paying a coach by InstaPay: Apple and Google rules, risks and what to paste

Written 27 October 2026. This is a reading of the stores' published rules, **not legal advice and not verified with Apple or Google**. Nothing here says either store approved the flow. Counsel and the owner decide the points marked DECIDE.

## 1. The short version

- A member pays an independent coach by InstaPay, from her own bank app. Own Hub never holds or moves the money. The best fit in both stores is **live one-to-one coaching as a real-world service between two people**, paid to the person who delivers it. Both policies name personal training or health coaching as an example.
- Apple's risk is the part that is not live: plans, check-ins and chat that stay in the app after payment can be read as "unlocking functionality" that must use in-app purchase. Google's risk is the same idea: a saved plan or chat history can be read as something that "can be replayed".
- If a store objects, the fallback needs no code change: turn the server switch `config/payments.enabled` off. The app then shows "Free for now" exactly as today. Ask Apple first (a pre-submission question) so a rejection does not cost days.

## 2. What the rules say (paraphrased; read on 27 October 2026)

**Apple, App Review Guidelines**

- **3.1.1**: features or functionality unlocked inside the app (subscriptions, premium content, a full version) must use in-app purchase. The app may not invent its own unlock method.
- **3.1.3(d) Person-to-person services**: an app that lets people buy a real-time service between two individuals (tutoring, medical consultations, real estate tours, fitness training are the examples) may collect payment by a method other than in-app purchase. One-to-few and one-to-many real-time services must use in-app purchase. This is the exemption that fits one coach and one client. The limits are "real-time" and "between two individuals".
- **3.1.3(e) Goods and services outside the app**: services consumed outside the app use payment methods other than in-app purchase. Live sessions that open in the coach's own video tool fit this; plans and chat inside the app fit it less.
- **3.1.3 (opening sentence)**: apps in the exemptions may not encourage people, inside the app, to use a purchase method other than in-app purchase, except where an exemption applies. This is the sentence an InstaPay screen runs into if no exemption fits.
- **3.2.1(vii)**: people may give each other money as an optional gift without in-app purchase when all of it goes to the recipient, but a gift tied to getting digital content or services must use in-app purchase. **Do not describe a coaching payment as a gift, a tip or peer-to-peer money.** It is payment for a service.
- **3.2.1(viii)**: apps for financial trading, investing or money management must come from the financial institution. Own Hub is not one and must not read like one. It handles no money, so avoid words such as "send", "transfer", "wallet" or "balance" for what Own Hub does. Say "pay your coach" and "your coach confirms she received it".
- Not used: 3.1.2 subscriptions, 3.1.3(a) reader apps, (b) multiplatform, (c) enterprise, (f) free companion, (g) ad management.

**Google Play, Payments policy**

- Digital items, subscriptions (fitness subscriptions are named), app features and cloud services sold in a Play app must use Play Billing unless an exemption applies.
- **1:1 online services exemption**: billing is not required for a paid service between two individuals when the session cannot be replayed or reused afterwards. Health coaching such as personal trainer sessions is an example.
- Inside the app you may not direct people to a non-Play payment method, including wording that pushes them to buy outside the app, unless an exemption applies.
- The requirement does not apply where Play Billing is not available. Whether that includes Egypt for this app is NOT VERIFIED.
- The page names no special Play Console declaration for the 1:1 exemption. NOT VERIFIED which form Play shows for this app.

## 3. Risks, in plain words

| # | Risk | What to do |
|---|---|---|
| A | Apple 3.1.3(d) says "real-time". A package also gives plans, check-ins and chat inside the app. A reviewer may read "pay, then plans and chat unlock" as 3.1.1 and the pay screen as steering to another payment method | Describe the package as a personal service between two named people; live sessions are in the package; plans and chat are how that coach delivers her service, not features of the app |
| B | Google: "not available for replay". Saved plans and chat history stay in the app | Unknown. Ask Google (question 6) |
| C | Own Hub's fee, paid by the coach to Own Hub, can look like a commission on a digital service | The fee is for introducing a client to a service the coach delivers. Say so; never describe it to members |
| D | Egypt storefront: the rules may apply differently. NOT VERIFIED | Ask both stores |
| E | The review account cannot make a real transfer | The notes say so (paragraph below) |
| F | A rejection | Turn the switch off; ship with "Free for now"; no code change |
| G | Wording that makes it look like an unlock | See section 4 |

## 4. Package wording that keeps this a real-world service

DECIDE (owner, with counsel): use these rules for every coach package shown in the app.

- Name the package after the service: "8 live one-to-one sessions with [coach]", with the number of sessions and their length. Not "membership", "Pro", "Premium", "unlock", "subscribe" or "monthly plan".
- Every package includes **live one-to-one sessions** with the coach, in her own video tool outside the app. DECIDE the minimum (for example at least one live session per week of the package). Plans, check-ins and chat are described as how she supports you between sessions.
- A fixed term or fixed number of sessions. **No automatic renewal.** Nothing recurs without a new payment the member starts.
- The pay screen says "Pay [coach name]" and "[coach] confirms she received it". It never says "buy", "unlock", "get access", or that paying outside the app is cheaper or avoids a fee. It never mentions Apple, Google or in-app purchase.
- Nothing in the app is locked behind a payment except that one coach's own service (her private chat and plans). Home, Train, Eat and Events stay free. Say it that way to the stores too: a payment starts a service from one person, it does not unlock a feature of the app.
- Do not call the payment a gift, a tip or a transfer between friends.
- Keep the payment screens free of the words "wallet", "balance", "deposit" and "withdraw".

## 5. Questions to ask (copy these to `handover/QUESTIONS.md`; not done here)

Apple (pre-submission question in App Store Connect, "Contact Us", or an appeal after a rejection):

1. Does a one-to-one fitness coaching package, delivered partly in live video sessions outside the app and partly through personal plans and text chat inside it, qualify as a person-to-person service under 3.1.3(d)?
2. May the app show payment instructions for an external bank transfer (the coach's InstaPay address, the exact amount and a reference) without in-app purchase, and then give the client access to that coach's chat and plans after the coach confirms receipt?
3. Is it acceptable that Own Hub receives a fee from the coach, paid outside the app, for introducing the client?
4. Does the answer differ on the Egypt storefront?
5. What must we show App Review, given a reviewer cannot complete a real InstaPay transfer?

Google (Play Console support):

6. For the 1:1 online services exemption, is a personal plan or a chat history that stays in the app "available for replay afterwards"?
7. Does the list of regions without Play Billing include Egypt for paid services like this?
8. Which Play Console declarations must we answer for an app that links members to an external payment under the 1:1 exemption?

Counsel:

9. Does the exemption reasoning hold under the stores' terms as signed by the developer accounts?
10. Does handling no money at all keep Own Hub outside payment-service regulation in Egypt? (also question 1 in `INSTAPAY-TERMS-DRAFTS.md`)

## 6. Review-notes paragraph to paste

App Store Connect "Notes" and Play "App access" notes. Put it after the "SIGN IN WITH THE TEST ACCOUNT" block and before "NEW IN THIS VERSION":

```
PAYING A COACH (new)
A member may pay an independent coach for one-to-one coaching by InstaPay, from her own bank app. Own Hub never holds or moves the money. Home, Train, Eat and Events stay free; a payment starts only that coach's own service. The coaching is a personal service between two individuals, fitness training (guideline 3.1.3(d)), with live sessions in the coach's own video tool outside the app. The app shows who to pay and how much; the coach confirms receipt. We sell no in-app purchases, subscriptions or digital goods. No real InstaPay account is needed to review: the test account can open the payment instructions but cannot pay.
```

Notes on this paragraph:

- It cites 3.1.3(d) as our reading. It does not say Apple approved anything. It must not say "nothing is unlocked": the coach's chat and plans are available only after payment, and a reviewer will see that.
- DEPENDS ON THE BUILD: the last sentence is true only if the review account can open the payment instructions (the pay screen) without paying. Check on a real build before pasting. Also check the claim that the account "cannot pay".
- If a coach package in the review account has no live session, the paragraph is not accurate. Make sure the review coach's package includes live sessions.

The notes box has a 4,000-character limit. It is 3,979 characters now (with the two `[OWNER: ...]` placeholders still in; about 18 fewer with the real values). The paragraph is about 650 characters. To fit, make these cuts in `docs/release/review-notes.md` (a gitignored working file, not edited here). Applied to a copy, they give 3,959 characters with real values, which leaves about 40:

- `No ads and no purchases.` becomes `No ads. No in-app purchases.`
- Delete ` No payments in this version.` at the end of the "Coaching (applications and portfolios)" line.
- Replace the whole "NOT IN THIS VERSION" paragraph with: `Community and the AI assistant are switched off by flags compiled into this build and cannot be turned on remotely.` (The old text says payments and paid coaching are off, which is now false.)
- Delete the "Widgets" line, the "Events: published by Own Hub" line and the "Profile photo" line.
- Replace the "Meal photos" line with: `Meal photos: Eat > Scan your meal. One photo goes once to Google Cloud Vertex AI in Frankfurt and is never stored.`
- In the Permissions sentence, delete `, and motion (to tilt a few illustrations)`.

Still stale after those cuts, to fix if room allows: in the Permissions sentence, "generic coaching alerts" should read "generic coaching and payment alerts"; the Coaching line says "can ask to join a coach for free" (asking is still free, but a coach may now charge). Other changes in this release (microphone for chat voice notes, weekly check-ins, InBody scan, voice logging) are not in these notes either, and the box has almost no room left: that needs its own pass in the release-prep step. Check the length with:

```
python3 - <<'EOF'
t = open('docs/release/review-notes.md', encoding='utf-8').read()
s = t.index('```') + 3
box = t[s:t.index('```', s)]
print(len(box))
EOF
```

For Play, put the same facts in `docs/release/launch-pack/play-app-access.md`, and in the Play Console "App content" answers say that the app sells no digital goods or subscriptions and that coaching is a one-to-one service paid directly to the coach.

## 7. Decisions for the owner and counsel

1. Ask Apple first (recommended) or submit and use the switch as the fallback.
2. The package rules in section 4, including the minimum number of live sessions per package.
3. Whether to ask Google the three questions before the Play release, or release on iPhone first.
4. Whether counsel is comfortable with the 3.1.3(d) reading (question 9).
5. Whether the Play account is an organisation account (needed anyway to avoid the personal-account test rule; see `OWNER-TODO.md`).
