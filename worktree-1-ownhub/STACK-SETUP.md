# The stack, the accounts, and exactly what to do — in plain English

**Written 19 September 2026; assistant section updated 22 September 2026 (Claude → Gemini, per D23).** Every price and every quota here was checked against the official page
on that date, and the source is named. Where I could not confirm something, §11 says so plainly rather
than guessing — a setup guide with one invented number is worse than one with a gap.

This covers **all three phases**. You do not need most of it on day one; §8 says what each phase
actually requires.

---

## 1. What you are building on, and why

Nine pieces. Seven are Google's, and you set them up once in a single place.

| Piece | Plain English | Needed from |
|---|---|---|
| **Flutter** | The app itself. One codebase, both iPhone and Android | Already done |
| **Firebase Authentication** | How she signs in — her phone number and a code | Phase 1 |
| **Cloud Firestore** | The database. Her sessions, meals, weeks, cycle | Phase 1 |
| **Cloud Storage** | Files — her photos, coach videos | Phase 1 |
| **Cloud Functions** | Small programs on Google's servers. They do what the app must never be trusted to do: delete an account properly, send notifications, and hold the Gemini key | Phase 1–2 |
| **Firebase App Check** | A bouncer. Confirms a request came from your real app, not a script | Phase 1 |
| **Firebase Emulator** | A copy of the database on your Mac, for testing safely | Phase 1 |
| **Paymob or Fawry** | Taking money and paying coaches | Phase 3 |
| **Google Gemini (Flash)** | The assistant — the owner's choice, D23 | Phase 3 |

**The one thing worth understanding before anything else.** Your app talks to Firestore *directly* —
there is no server of yours in between. What stops one woman reading another's data is a file of
**security rules**. That file already exists in this repo. It has **never actually been run**, because
running it needs Java, which is step one below. This is the single biggest gap in the project.

---

## 2. What it costs

### Free while you build

Firebase's free **Spark** plan, from [firebase.google.com/pricing](https://firebase.google.com/pricing)
(19 Sept 2026):

| | Free every day / month |
|---|---|
| Firestore | **1 GiB** stored · **50,000** reads/day · **20,000** writes/day · **20,000** deletes/day · 10 GiB/month network |
| Cloud Storage | **5 GB** stored · 1 GB/day downloaded (legacy buckets) or 100 GB/month (new buckets) |
| Cloud Functions | **2,000,000** calls/month · 400,000 GB-seconds · 200,000 CPU-seconds |
| Hosting | 10 GB stored · 360 MB/day transferred |
| Sign-in | **50,000** monthly active users |

For building and testing, you will not come close to any of these.

### What actually costs money

**Text messages. This is the one to watch.** Phone sign-in is **billed per SMS sent, with no real free
tier** — only "the first ten SMS you send per day are not billed". Every woman who signs up costs you
one SMS, and so does every re-verification.

Google also offers *Firebase Phone Number Verification*, which gets the number from the carrier without
an SMS — but **Egypt is not covered** (the list is 12 countries, none in the Middle East). So SMS it is.

> **I could not extract the per-message price for Egypt.** The rate table is loaded by JavaScript and is
> not readable by any tool I have. Look it up yourself before launch — it is the number that decides
> your cost per signup. Go to
> [cloud.google.com/identity-platform/pricing](https://cloud.google.com/identity-platform/pricing) and
> find the SMS table. Budget for it as a real per-user acquisition cost, not a rounding error.

**The other paid lines**, all Phase 3:

| | Cost | Source |
|---|---|---|
| Apple Developer Program | **$99/year** | developer.apple.com |
| Google Play Console | **$25 once**, for the life of the account | play.google.com/console |
| Paymob | **2.75% + 3 EGP** per local sale; settles weekly; has a **MarketPlace** product for splitting payouts to coaches | paymob.com/en/pricing |
| Fawry | roughly **1.5%–2.5%** depending on method and volume | vendor material |
| Gemini API (Flash) | Per million tokens — **check the current price before switching the assistant on**; I have not verified it | ai.google.dev/pricing |

**On the assistant specifically:** the owner chose **Gemini Flash** (D23). The earlier cost model was written for Claude and no longer applies. Re-estimate from the current Gemini price before switching the assistant on — it is the one feature with an open-ended third-party bill.

---

## 3. Accounts — what to create, in order, and where

### 3.1 Now: a Google account → Firebase *(free)*

1. Go to **https://console.firebase.google.com**
2. Sign in with any Google account.
3. **Add project** → name it `own-hub`.
4. It asks about **Google Analytics** — **say no.** This product deliberately sends nothing personal to
   analytics, and turning it on here creates a second pipe nobody has reviewed.
5. You land on the dashboard. Leave the tab open.

### 3.2 Now: a Google Cloud billing account *(free to attach)*

Firebase and Google Cloud are the same thing wearing two hats. Some steps happen in the Cloud console
at **https://console.cloud.google.com**, same login, same project.

You may be asked to upgrade to the **Blaze** pay-as-you-go plan when you deploy Cloud Functions. Blaze
**keeps every free allowance above** — you only pay past them. With no users, that is essentially zero.
Before you upgrade, do §6 (budget alerts).

### 3.3 Later: Apple Developer Program *($99/year)*

Only when you want the app on a real iPhone or in TestFlight. The simulator needs nothing. A free Apple
ID installs on your own phone for 7 days at a time.

### 3.4 Later: Google Play Console *($25 once)*

Only to publish on Android.

### 3.5 Phase 3 only: Paymob and/or Fawry, and Gemini

- **Paymob** — apply at paymob.com. Ask specifically about **MarketPlace / split payouts**, because
  paying coaches 80% is the whole model. Expect to need commercial registration and a tax card.
- **Gemini** — create a key at **aistudio.google.com** in the `own-hub` project, and set a spend limit immediately.
  **The key never goes in the app.** It lives in Google's Secret Manager and is read only by a Cloud
  Function. An APK is a zip file: anything inside it is public.

---

## 4. Installs on your Mac

Terminal. If you do not have Homebrew, get it from **https://brew.sh** first.

```bash
brew install --cask temurin      # Java — do this one first
brew install node
npm install -g firebase-tools
```

**Why Java matters more than it sounds.** The Firebase emulator is a Java program. Without it, **not one
security rule in this project has ever been executed.** They are currently checked as text, which proves
a line exists and proves nothing about whether it lets the wrong person in.

Check both worked:

```bash
java -version
firebase --version
```

Xcode and Android Studio you already have — the app builds on both today.

---

## 5. Setting up the project — the exact clicks

### 5.1 Connect your Mac to your project

```bash
firebase login
cd ~/womens-fitness-app-wireframe
firebase use --add          # pick own-hub, alias it "default"
```

`firebase.json` already exists and already points at the rules and indexes.

### 5.2 Turn on the database — **this choice is permanent**

In the Firebase console: **Build → Firestore Database → Create database**.

Choose **production mode** (this repo's rules replace the defaults immediately).

Then the location. From
[firebase.google.com/docs/firestore/locations](https://firebase.google.com/docs/firestore/locations):
**"Once you provision a database instance, you cannot change its location setting."** There is no
migration button. Choose deliberately.

| Option | What it means for you |
|---|---|
| **`me-central1` (Doha)** or **`me-central2` (Dammam)** | Closest to Egypt — lowest latency for your users, and regional pricing is cheaper than multi-region. **My recommendation**, if the console offers it for Firestore |
| **`europe-west1` (Belgium)** | The safe, boring choice. Widest service support, well-trodden |
| **`eur3`** (multi-region Europe) | Highest durability (99.999% vs 99.99% uptime) and **more expensive**. Overkill before you have users |

Google has no Egyptian region, so there is no perfect answer. **Whatever you pick, put your Cloud
Functions in the same region** — a function in one continent talking to a database in another pays for
that on every request.

Then **Build → Storage → Get started**, same location.

### 5.3 Turn on phone sign-in, and fence it

**Build → Authentication → Get started → Phone.**

Then immediately do the thing most people skip: **restrict which countries can receive an SMS.**

Google documents this at
[docs.cloud.google.com/identity-platform/docs/admin/sms-regions](https://docs.cloud.google.com/identity-platform/docs/admin/sms-regions)
— "Use SMS regions to protect your app from SMS abuse". Set it to **Egypt only** while you build.

**Why this matters.** SMS toll fraud is a real and common attack: someone scripts your signup endpoint
against premium-rate numbers abroad and you pay for every message. Your app is for Egypt. Allow +20 and
nothing else, and the attack has nowhere to go.

### 5.4 Turn on App Check

**Build → App Check.** Register the iOS and Android apps (App Attest and Play Integrity).

App Check makes Firestore and your Functions reject anything that is not your genuine app. The
assistant's endpoint in particular is designed to require it, because each call costs real money.

### 5.5 Deploy the rules and the indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

**Deploy the indexes, not just the rules.** Firestore indexes every field automatically. The exemptions
in `firebase/firestore.indexes.json` are what stop `periods.stillBleeding` — a flag true for exactly the
women currently bleeding — from being queryable across every user. They are also what makes "nothing is
ranked" true: without them, "order coaches by how much weight their clients lost" is a query that simply
works. Rules without indexes leaves both open.

### 5.6 Run the emulator — the first real test of the rules

```bash
firebase emulators:start --project demo-own-hub
```

`demo-` means it runs entirely on your Mac, touches no real data, and needs no billing. A dashboard
opens at **http://localhost:4000**.

This unblocks `P0-DEL-01` — "delete my account and nothing survives" — which is currently marked NOT
COVERED for exactly this reason.

---

## 6. Stopping a surprise bill — do this before Blaze

Go to **https://console.cloud.google.com** → **Billing** → **Budgets & alerts** → **Create budget**.
Set an amount you would be annoyed but not hurt to pay. Add alerts at 50%, 90% and 100%.

**Understand what a budget does and does not do: it emails you. It does not switch anything off.**
There is no "stop at $50" switch. Protection comes from layering:

1. The **SMS region allowlist** (§5.3) — closes the most likely expensive attack.
2. **App Check** (§5.4) — keeps scripts out.
3. **Budget alerts** — tells you early.
4. For the assistant, the app's own **hard $5,000/month ceiling** with per-user daily caps enforced
   before any model call, plus a kill switch.

---

## 7. Scaling — what changes, and what does not

The architecture already assumes scale, which is why several things in the code look fussier than they
need to be:

- **Reads are budgeted per screen.** Firestore bills per document returned, so "show her last 8 weeks"
  is eight reads, not one — the app caches those on a document it already loads. Several screens are
  specified as "must cost one read", and the tests hold them to it.
- **Writes never fan out.** A community post is written **once** regardless of follower count.
- **Counters are server-written.** A client that can write its own counters can mint itself any tier.
- **Nothing is ranked**, enforced at the index layer rather than by leaving a query out.

What you will actually change as you grow: the Firestore location (can't — see §5.2, choose right),
the assistant's model (§2), and moving community media to a CDN. The database design does not need
rework.

---

## 8. What each phase needs from you

| | Needs | Roughly |
|---|---|---|
| **Phase 1 — sign up and train** *(built)* | Java · Firebase project · Firestore + Storage on · phone sign-in · rules deployed · the ID-verification vendor contract | Free + SMS |
| **Phase 2 — her day and her privacy** *(built)* | Cloud Functions (needs Blaze) for real account deletion · allergen and contraindication content | Free + SMS |
| **Phase 3 — coaches, community, assistant** *(built, behind feature flags)* | Payment rails + **commercial registration, tax card, ETA e-invoicing** · Gemini key · Apple + Play accounts · **moderators, rostered** | The real money starts here |

**Phase 3 has three blockers that no amount of code removes**, and they are set out in
`6-v2/tests/PHASE3-PLAN.md`:

1. **Who owns the money.** The 80/20 split is specified nowhere mechanically, and collecting money then
   paying out 80% makes you the merchant of record.
2. **Pregnancy and postpartum safety.** Nothing in the specs makes a recorded pregnancy restrict what a
   coach may prescribe, and no clinical review is required anywhere.
3. **Moderation is people, not code.** The app promises a reply within an hour.

**One genuinely good piece of news, settled today:** Apple's guideline 3.1.3(d) explicitly permits
real-world payment methods for "real-time person-to-person services between two individuals", naming
**fitness training**. So 1:1 coaching can be paid through Egyptian rails with **no 30% Apple
commission**, and the 80/20 split survives. The same clause requires in-app purchase for one-to-many
services — so group coaching or live classes would be a different commercial model.

---

## 9. The order I would do it in

| | Step | What it unblocks |
|---|---|---|
| 1 | Java | Rules can run at all |
| 2 | Node + firebase-tools | Emulator and deploys |
| 3 | Firebase project, Firestore, Storage | A real backend |
| 4 | **SMS region allowlist + App Check** | Your bill stops being attackable |
| 5 | Budget alerts | You find out early |
| 6 | Deploy rules + indexes | The safety guarantees become real |
| 7 | Emulator | `P0-DEL-01` and every rules case become testable |
| 8 | Cloud Functions | Account deletion actually deletes |
| 9 | Firestore repository + file picker | Content survives a restart |

**Steps 1–7 are an afternoon.** 8 and 9 are development work and need no account.

---

## 10. Things that will bite you

- **The Firestore location cannot be changed.** §5.2.
- **A budget alert does not stop spending.** §6.
- **Phone SMS has no meaningful free tier** and Egypt is excluded from the cheaper carrier-based
  alternative. §2.
- **Deploying Cloud Functions requires Blaze** — do §6 first.
- **Rules OR across blocks.** A specific rule cannot revoke a broader grant, so one permissive block
  silently defeats a strict one. `users/{uid}` has exactly one ruleset and a test asserts it. Phase 3
  roughly doubles the ruleset and this is where it gets dangerous.
- **`resource` is null when a document is created.** This repo already had a rule that could never have
  succeeded because of it. Test creates in the emulator, not just updates.
- **The Gemini key never ships in the app.** Secret Manager, read by a Function, never in Remote Config
  (client-readable) and never in an env file in the bundle.

---

## 11. What I could not verify, and where to check

Named so you do not treat a gap as a fact:

1. **The per-SMS price for Egypt.** Loaded by JavaScript; not readable by my tools. →
   [cloud.google.com/identity-platform/pricing](https://cloud.google.com/identity-platform/pricing)
2. **Whether Cloud Functions still strictly requires Blaze.** The pricing page now lists Functions
   quotas under the free tier, which historically it did not. → it will tell you at deploy time; if
   prompted, upgrade after doing §6.
3. **App Check pricing.** I believe the standard providers are free; I did not confirm it this session.
   → firebase.google.com/pricing
4. **Whether Firestore offers `me-central1`/`me-central2` in your console.** The regions exist; console
   availability can lag. → the dropdown in §5.2 is the truth.
5. **Paymob and Fawry rates** are from vendor marketing, not a signed contract. Marketplace/split-payout
   pricing is quote-only.
6. **Egypt's PDPL** — the licensing and registration requirements for processing personal and
   **biometric** data (which ID verification is) were not confirmed. This one needs an Egyptian lawyer,
   not a web search. It is already on `README.md`'s list.

---

## 12. If you only do one thing this week

```bash
brew install --cask temurin
```

Then §5.6. It is the difference between "the security rules are written" and "the security rules
work", and right now the project has only the first.
