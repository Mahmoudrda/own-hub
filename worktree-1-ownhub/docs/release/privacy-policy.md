# Own Hub, Privacy Policy

> **SUPERSEDED on 6 October 2026. Do not send this file to counsel and do not publish it.**
> This 23 September draft is replaced by the Privacy Policy version 3.0, written in English and Arabic in the repository at
> `site/_build/pages_en.py` and `site/_build/pages_ar.py` and built to `site/privacy/index.html` and `site/ar/privacy/index.html`.
> This file describes an earlier build with no accounts and no server. It is kept only as a record.

> **Draft for legal review. This is not legal advice.** It was written from the app's own source
> code, so it is accurate about what the software does. It has not been read by an Egyptian lawyer,
> and it must be before it is published. Every `[OWNER: ...]` marker is a fact only the owner can
> supply.

**Effective date:** `[OWNER: the date this page goes live. It must not be earlier than the day the
app is first downloadable.]`
**Applies to:** Own Hub for iOS and Android, bundle id `com.ownhub.app`.
**Redrafted:** 23 September 2026, against the first release.

---

## The short version

**Own Hub collects nothing about you. Everything you put into it stays on your phone.**

There is no account to make, no server to send anything to, and no company on the other end receiving
your training, your meals or your cycle. The app writes what you log onto your own handset so that it
is still there tomorrow, and one button in your profile erases all of it.

That is not a promise about how carefully we handle your data. It is a statement about software that
has no way to send it anywhere, and the rest of this page explains why you can check that for
yourself.

---

## 1. Who we are

| | |
|---|---|
| App | Own Hub |
| Developer | `[OWNER: registered legal entity name, exactly as it appears on the commercial register]` |
| Registered address | `[OWNER: street address, city, Egypt]` |
| Privacy contact | `[OWNER: privacy contact email address]` |
| Commercial registration and tax card number | `[OWNER: numbers, if counsel wants them here]` |
| Data protection officer | `[OWNER: name and contact, or delete this row if the PDPC does not require one for this entity]` |

Own Hub is a fitness app for women in Egypt. It is free. There are no adverts in it, and nothing in
it is sold to anyone.

## 2. How to read this policy

- **Part A is this release**, the version you can install today. It is complete on its own.
- **Part B describes the release that adds accounts and a server.** None of it is running. It cannot
  start without a new version of the app, a new version of this policy, and your consent where
  consent is required. It is published early so you can read it before you decide to make an account.

If you are reading this from a store listing, **only Part A describes software you can install.**

---

# Part A, the version on the store

## A1. What it collects: nothing

**Own Hub has no server. It cannot send anything anywhere.**

That is a statement about the software, and it is checkable:

- The app's whole dependency list is `flutter`, `flutter_localizations`, `intl`, `meta`, `crypto`,
  `shared_preferences`, `url_launcher` and `cupertino_icons`. **There is no network library of any
  kind in it.** No Firebase, no analytics library, no advertising library, no crash-reporting
  library, no HTTP client.
- On Android, the released app **does not even ask for permission to use the internet.**
- **We receive nothing about you.** Not your name, not your phone number, not what you log, not which
  screens you open, not whether you opened the app at all. We could not tell you how many people are
  using it beyond what Apple and Google count for their own stores.
- **There is no advertising and no tracking.** The app never reads an advertising identifier, never
  asks permission to track you, and shares nothing with ad networks or data brokers.
- There is no account. Nothing in the app identifies you, because the app was never told who you are.

## A2. What it keeps on your phone, and where

Everything you log is written to **your own handset**, so that closing the app does not lose your
week.

| | |
|---|---|
| Where | The phone's own private settings store, inside the app's sandbox. On iOS that is the app's user defaults; on Android it is the app's private preferences file. No other app can read it |
| What | One document, holding your training, your meals, your weekly goal, your personal bests, your measurements, your cycle days, symptoms and settings, your privacy switches, what you told us you avoid eating, your setup answers, and your language |
| When | A few hundred milliseconds after you change something, and again when you swipe the app away |
| Who can read it | This app, on this phone. Nothing uploads it, nothing backs it up to us, and there is no analytics library in the app that could read it |
| How to erase it | Profile, then **Your data**. See A5 |

**This is still not collection.** Both Apple and Google define collecting as data leaving the device.
Nothing here leaves it.

## A3. The features that look like they need a server, and what they actually do

| Feature | What actually happens |
|---|---|
| Signing up or signing in | **There is none.** The app opens straight onto your own Home. No number is asked for, no code is sent, and there is no password anywhere in the product |
| Identity checks, ID and selfie | **Not in this version.** There is no camera in the app, and the screens that would use one are switched off |
| A community, posts, comments, groups | **Not in this version.** There is nothing to post to and nobody to post to. No part of the app connects you to another person |
| Coaching, a coach, payments | **Not in this version.** Nothing in the app can be bought, and no price is shown anywhere |
| An assistant | **Not in this version.** No question can be asked, nothing you write is sent to any AI service, and the app contains no key that could reach one |
| Photos, video, voice notes | Cannot be created. There is no camera, no gallery access, no microphone and no speech recognition |
| Opening our privacy policy, terms or support page | These three rows hand a fixed address, ours, to your phone's own browser. The app has no browser of its own, it fetches nothing, and it learns nothing about what you do once the page opens |

## A4. Permissions it asks for

**None.** No camera, no photos, no microphone, no contacts, no location, no calendar, no health data,
no notifications, no motion or fitness sensors. The iOS build contains no permission text at all,
because nothing in it requests a permission.

The app is not connected to Apple Health, Google Fit, Health Connect, a step counter, or any sensor.
Everything the app knows about your training is what you typed into it.

## A5. Deleting everything

**Profile, then Your data.** A sheet tells you what deleting removes, that it happens at once and
that none of it can be brought back. The button under it does exactly that.

It erases the document described in A2, and empties everything the app is holding: your training,
your meals, your measurements, your cycle, your settings and your answers. The app goes back to its
first day and says so.

Two things worth knowing:

1. **There is nothing on our side to delete**, because we never had anything. You do not have to ask
   us, write to us or wait for us.
2. **Downloading a copy first is not built yet.** The sheet says so rather than showing a button that
   would produce nothing. There is also nothing we could send you, for the same reason.

Deleting the app removes everything too.

## A6. What Apple and Google collect on their own

When you download or update any app, Apple and Google process data under their own privacy policies,
not ours. If you have agreed with them to share crash and usage data with developers, they may make
aggregate reports available through their consoles. We do not control that, we cannot switch it on or
off for you, and you can change it in your device settings. It is not something the app does.

## A7. What the store forms say for this version

For this version the correct answer on Apple's App Privacy questionnaire and Google Play's Data
Safety form is **"Data Not Collected"**, with no data used to track you and no data linked to you.
The app's iOS privacy manifest says the same thing, and the two plugins in the build carry their own
manifests declaring that they collect nothing either.

`[OWNER: the day a server is connected, both forms, the privacy manifest and Part B of this policy
must go live in the same release. A store form that disagrees with this page is a rejection.]`

## A8. Children

Own Hub is not directed at children. It is a fitness and health tracking tool intended for adults.

Because this version has no account and collects nothing, there is no personal data of anyone, of any
age, for us to hold. `[OWNER: the minimum age for membership is still with counsel, and it becomes
enforceable when accounts return. See Part B.]`

## A9. Your rights, in this version

Under Egypt's Personal Data Protection Law No. 151 of 2020 you have the right to know what a company
holds about you, to see it, to correct it, to have it deleted, to take it with you, and to object to
particular processing.

**In this version we hold nothing about you, so there is nothing to see, correct, port or ask us to
delete.** Everything the app holds is on your phone and under your control, and A5 is how you clear
it.

If you want to tell us that, or ask anything else, write to
`[OWNER: privacy contact email address]`.

---

# Part B, when a server is connected

**None of Part B is active.** It describes the release in which sign-in, identity verification and
cloud storage are switched on. Until that release exists, nothing below happens.

## B1. The promises that shape this section

1. **Your ID photo and your selfie are deleted after the check.** Only the pass or fail result is
   kept. The app shows you the date they were deleted, read from the record itself, not from a
   sentence someone typed.
2. **There is no AI face or gender classification anywhere in this product.** We never guess your sex
   from a photograph. The check reads the sex digit that the Egyptian government already put in your
   national ID number.
3. **Your cycle data never goes to analytics, under any circumstance.** Neither does your phone
   number, your name, your verification result, your weight, or any photo.

## B2. What would be collected, by category

The category names are the ones Apple's App Privacy and Google Play's Data Safety forms use, so this
table and those forms can be checked line by line. **Nothing in Own Hub is ever used for tracking, in
any category.**

| Category | What | Why | Linked to you? |
|---|---|---|---|
| Contact info | Your mobile number, the first name you type, and the account identifier we generate | The number is how you sign in. There is no password and no email. Your name is never read off your ID | Yes |
| Sensitive info, government ID | A photograph of your Egyptian national ID and a selfie | To confirm you are a woman, and old enough. The sex digit and the date of birth come from the ID number; the selfie only confirms the card is yours. **The images are deleted after the check**, and only the result, the date, the provider's reference and a one-way scramble of the ID number are kept | Yes |
| Health and fitness | Workouts, sets, meals, weekly goals, personal bests, measurements, daily check-ins, **period days and cycle settings** | To show you your own logs, your progress and your plan. Cycle data adjusts what the app suggests to you, and nothing else. **Never sent to analytics** | Yes |
| User content | Community posts, comments, messages to a coach. Progress photos stay **encrypted on your own phone only** | So the people you chose can see what you shared. We cannot see your progress photos, cannot export them and cannot delete them from our side, because we never had them | Yes |
| Safety records | Reports you make or that are made about you, and who you block | To keep members safe and act on what is reported. Read by a woman on the moderation team | Yes |
| Identifiers | The account identifier, and a device record holding your notification token, language and platform | To keep you signed in and send notifications you asked for. **No advertising ID, ever** | Yes |
| Purchases | If you pay a coach: that a payment happened, its amount, status and reference. **Never your card number**, which is entered on the payment provider's own page | To run the coaching you paid for | Yes |
| Usage data and diagnostics | **Not collected, and nothing is planned that is already built.** There is no analytics SDK and no crash reporter in the app | | |
| Location, contacts, messages, calendar, files, browsing history | **Not collected.** The app requests none of these permissions | | |

If you wear niqab, or do not want to send a face photo, there is a path that needs no face photo at
all: a short live check with a woman reviewer, or an in-person check at a partner ladies-only gym.
Only a woman reviews it, and the recording is not kept.

## B3. What we would rely on to process it

Under the PDPL we must have a lawful basis for every category above, and explicit consent for the
sensitive ones.

| Data | Basis |
|---|---|
| Phone number and account | Necessary to provide the service you asked for |
| ID and selfie | **Your explicit, separate consent**, recorded with the version of the wording you were shown |
| Health, fitness, measurements and cycle data | **Your explicit consent**, given by entering it. You can delete any of it, and cycle data can be deleted on its own |
| Community posts and comments | Necessary to provide the part of the service you chose to use |
| Safety records | Keeping members safe, and our legal obligations |
| Payment records | Performing the contract, and Egyptian invoicing and tax rules |
| Analytics and diagnostics | Not applicable. `[OWNER: if either is ever added, counsel must decide whether it is consent or legitimate interest. If it is consent, the app needs an opt-in switch, and it does not have one]` |

## B4. Who else would handle it

| Who | What they get | Where |
|---|---|---|
| `[OWNER: the authentication provider]` | Your phone number | `[OWNER: region]` |
| `[OWNER: the database and storage provider]` | Everything stored in B2 | `[OWNER: confirm the region. That choice is permanent, and it decides whether data leaves Egypt]` |
| Your mobile operator | The sign-in message | Egypt |
| `[OWNER: identity verification provider]` | Your ID image and selfie, at the moment of the check | `[OWNER: confirm where it processes, and whether images stay in Egypt. That is a contract term, not a setting]` |
| `[OWNER: payment provider, if coaching ships]` | Your payment details, on their own page | Egypt |

**Today this table is empty in practice**, because none of these is connected.

We do not sell your data, and we do not share it with advertisers, data brokers or marketing
companies. **Transfers outside Egypt** are restricted by the PDPL. `[OWNER: counsel must confirm the
transfer mechanism and any permit required, and then this paragraph must name the countries the data
reaches.]`

## B5. How long things would be kept

| What | How long |
|---|---|
| ID image and selfie | Deleted after the check. Only the result survives |
| One-way scramble of the ID number | While the account exists, and in closed form afterwards. See B6 |
| Your logs, meals, measurements, cycle data, plans, posts | Until you delete them, or until you delete your account |
| Messages with a coach | `[OWNER: retention period, with counsel]` |
| In-app notifications | 30 days, then deleted automatically |
| A data export you request | 24 hours, then deleted automatically |
| Safety reports | `[OWNER: retention period, with counsel]` |
| Payment and invoice records | `[OWNER: the period Egyptian tax law requires. This is an exception to deletion and this policy must say so plainly]` |

## B6. Deleting an account, once accounts exist

You will be able to delete from inside the app, and to ask us to delete without installing the app at
all. The public page at `[OWNER: https://yourdomain/delete-account]` explains both, and its text is
in `delete-account.md` beside this file.

**Three things would survive on purpose**, and we would rather say so than let you find out:

1. A one-way scramble of your national ID number, kept in **closed** form with the link to you
   removed, so that someone removed from the app cannot rejoin the next day.
2. Safety reports made by you or about you, with the account identifiers replaced by a meaningless
   token.
3. A record that a deletion happened, reduced to dates and a status.

`[OWNER: rows 1 and 2 are one question for counsel, not two. Does the PDPL right to erasure permit
keeping a pseudonymous safety record and a re-registration block? The engineering can go either way.]`

## B7. Security, in plain language

- Your account would be protected by a code sent to your phone. There is no password to steal, and we
  never ask for one.
- Data would travel over an encrypted connection and be encrypted where it is stored.
- **You could only read your own data.** The rules enforcing that live on the server, not in the app,
  so a modified copy of the app cannot read anyone else's data.
- **The app cannot mark itself as verified.** The verification result is written by our server and by
  nothing else. That is the single most important rule in this product: a women-only app whose gate
  can be set by the phone holding it is not a women-only app.
- Progress photos would be encrypted on your device with a key held in the iOS Keychain or the
  Android Keystore.
- Honest limits: no system is perfectly secure, and a device left unlocked is outside our control.

## B8. Children, once accounts exist

The minimum age would be `[OWNER: 16 or 18, set by counsel]`, and the check would not be a tick box:
your date of birth comes from your national ID.

## B9. Your rights, once we hold something

You would have the rights listed in A9, exercised in the app through "download everything" and
"delete my account", or by writing to `[OWNER: privacy contact email address]` from the number on the
account. **How long we take:** `[OWNER: state the response window the PDPL executive regulations
require, and make sure the app and this page say the same number.]`

**If you are not satisfied**, you can complain to Egypt's Personal Data Protection Centre.
`[OWNER: add the PDPC's contact details once counsel confirms the current channel.]`

---

## Changes to this policy

We will post any change here, with the date and what changed. If a change means we start collecting
something new, we will tell you in the app before it starts, and ask for consent where consent is
required.

| Date | Version | What changed |
|---|---|---|
| `[OWNER: publication date]` | 1.0 | First published. This version of Own Hub has no accounts and collects no data. Everything you log stays on your own phone. Part B describes a server that is not connected |

**Questions:** `[OWNER: privacy contact email address]`
