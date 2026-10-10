# Own Hub, Privacy Policy

> **SUPERSEDED on 6 October 2026. Do not send this file to counsel and do not publish it.**
> This proposed version 2.0 is replaced by the Privacy Policy version 3.0, written in English and Arabic in the repository at
> `site/_build/pages_en.py` and `site/_build/pages_ar.py` and built to `site/privacy/index.html` and `site/ar/privacy/index.html`.
> This file describes an earlier build, including review by video call and in person at partner gyms, neither of which exists. It is kept only as a record.

> **Proposed revision for counsel. Not legal advice.** Prepared on 2 October 2026 as a pre-counsel draft
> to replace `privacy-policy.md`, which describes an earlier build with no server. It describes the
> build in `release-readiness` with accounts, identity verification and cloud sync switched on. Items in
> `[OWNER: ...]` are facts only the owner can supply. Items in `[COUNSEL: ...]` are decisions only an
> Egyptian lawyer can make. An Arabic version must be published alongside this one, and counsel should
> say which version prevails. Remove this box before publishing.

> **Change log for counsel (4 October 2026).** The 2 October draft no longer matched the build, so these
> sections were corrected. Remove this box before publishing.
> - **Health data (short version, 3.3, 4).** Cycle, check-ins, measurements, weight, life stage and
>   allergies now stay on the phone unless she turns on "Back up my health data", which has its own
>   consent and can be withdrawn; withdrawing deletes the cloud copy. Only training and meal logs sync
>   to her account once she is verified. The earlier draft said everything synced with no separate consent.
> - **Crash reports (short version, 3.4, 5, 6, 10).** The build uses Firebase Crashlytics, with no user
>   identifier and no error messages. The earlier draft said there was no crash reporting.
> - **Waitlist (new 3.5, 4, 5).** The website collects a phone number or email for the waitlist. It was
>   not covered before.
> - **Reviewers (1, 3.1, 3.2, 4).** Members sign in by phone only; women reviewers sign in separately, see
>   a member's phone number only for a review she asked for, and every lookup is logged. Consent to a
>   review call is recorded for each review.
> - **Deletion (4.1, 7).** In-app deletion now erases the server data, with a second sweep an hour
>   later. The ID number code is kept closed. The earlier draft said deletion only cleared the phone.

**Effective date:** `[OWNER: the date this page goes live, not earlier than the first public download]`
**Version:** 2.0
**Applies to:** the Own Hub app for iOS and Android (`com.ownhub.app`) and this website.

---

## The short version

- Own Hub is a fitness app for women in Egypt aged 18 and over. To keep it women only, we check your
  Egyptian national ID card and a live selfie once, when you join.
- **The photographs of your card and your selfie are never stored.** They are read in memory on Google
  Cloud servers in the European Union and discarded when the check ends. We keep the result, and a
  one way keyed code made from your ID number so the same card cannot open two accounts.
- Your cycle, daily check-ins, measurements, weight, pregnancy or postpartum status and allergies are
  health information. **They stay on your phone** unless you turn on "Back up my health data", which
  asks for your consent separately. You can turn it off at any time, and turning it off deletes the
  copy on our servers.
- Once your account is verified, your training and meal logs are stored in your account on Google
  Cloud servers in Frankfurt, Germany, so you do not lose them if you lose your phone. Only you can
  read them.
- Your phone number is handled by Google Firebase Authentication, which keeps it in the United States.
- When the app crashes, Firebase Crashlytics receives a crash report. It carries no account identifier
  and no error message, only the type of error and where in the code it happened.
- We do not sell your data, we show no adverts, we use no advertising or analytics tools, and we never
  use your health information for marketing.
- You can delete your account and your data from inside the app at any time.

---

## 1. Who is responsible for your data

The controller of your personal data, meaning the person who decides how and why it is used, is:

| | |
|---|---|
| Name | Mahmoud Reda, an individual, publishing Own Hub in his own name |
| Address | `[OWNER: full postal address, city, Egypt]` |
| Privacy contact | mahmoud.reda.acc@gmail.com |
| Data protection officer | Mahmoud Reda. Under the PDPL Executive Regulations an individual who holds a permit acts as his own data protection officer `[COUNSEL: confirm]` |
| Personal Data Protection Center permit | `[COUNSEL: permit number and expiry, once issued]` |

Rahma Mohsen is Own Hub's founder and public face, and the author of its recipes. She is not the
controller of your data and `[OWNER: confirm] she has no access to members' personal data`.

The people who review verification cases by video call are women acting on the controller's
instructions and bound by confidentiality. They sign in to a separate review tool with their own
accounts, not through the app. A reviewer can see your phone number only for a review you asked for,
so that she can arrange the call, and every time a reviewer looks up a phone number it is logged.
`[OWNER: confirm who they are, and that each has signed a confidentiality undertaking.]`

## 2. Who can use Own Hub

Own Hub is for women aged **18 or over** who hold an Egyptian national ID card. We do not knowingly
collect data from anyone under 18. Your age and sex are read from your national ID number during the
check. If the check shows that you are under 18, your application is refused and nothing about you is
kept except the record described in section 4.2.

## 3. What we collect, and why

### 3.1 Your account

| What | Why | Legal basis `[COUNSEL: confirm each]` |
|---|---|---|
| Your mobile number | To create your account and sign you in with a one time code sent by SMS. Members can sign in only this way | Necessary to provide the service you asked for |
| An account identifier we generate | To link your data to your account | Necessary to provide the service |
| Your app language and settings (privacy switches, notification preferences, quiet hours) | To run the app the way you set it | Necessary to provide the service |

### 3.2 Checking that you are a woman aged 18 or over

This happens once, when you join, and only after you have read a separate screen and tapped
"I agree, start the camera". The camera is the only way to take the photographs. The app cannot
upload a picture already on your phone.

| What | What happens to it |
|---|---|
| Photographs of the front and back of your national ID card | Sent over an encrypted connection to our server in Frankfurt, Germany. The text on the card is read by Google Cloud Vision through its European Union endpoint. Google states that images sent this way are processed in memory and not written to disk, and are not used to train its models. **We do not store the images anywhere.** |
| A short live selfie, taken while you follow on-screen prompts | Used to check that a live person is present and that the face matches the portrait on the card. The comparison runs on our own server in Frankfurt and does not use any outside face recognition service. The face measurements it computes exist only in memory during the check. **We do not store the selfie or any face measurement.** |
| Your national ID number | Read from the card, used to confirm your sex (from the digit the Civil Status authority set in the number) and your age (from the date of birth encoded in it), then turned into a one way keyed code (HMAC-SHA256 with a secret key held separately in Google Secret Manager). **The number itself is not stored.** The code is stored so that one card cannot open two accounts. |
| Your name and date of birth as printed on the card | Read only to cross check the number during the check. **Not stored.** |
| The result | Approved, refused, or sent to a woman reviewer, with the reason codes, the match and liveness scores, the attempt number, the date, and the date the images were discarded. Stored with your account. |
| Fraud signals | A count of failed attempts per ID code, and a scrambled (hashed) identifier for the app installation, so that one installation trying many different cards can be noticed. |
| Your consent | The version of the consent wording you accepted, and when. |

We never guess your sex from your face. The decision about sex comes from your national ID.

**If the automatic check is uncertain, or if you wear niqab and prefer not to take a selfie**, a
woman reviewer checks you in a short live video call `[OWNER: name the video call service used, for
example Google Meet or WhatsApp, because that service will process your image and voice during the
call]`, or in person at a partner ladies-only gym `[OWNER: confirm the partner gyms exist and are
contracted before this sentence is published]`. A review happens only after you ask for one, and we
record your consent to the call separately for each review. **The call is not recorded.** The reviewer
records only her decision and the date. Only women review these cases.

Legal basis: your explicit consent, given on the screen before the camera opens. `[COUNSEL: confirm
that explicit electronic consent satisfies the PDPL for biometric data and for the national ID number,
and whether a licence or permit from the Personal Data Protection Center is needed for this
processing.]`

You can refuse. If you refuse, you cannot join Own Hub, because a women-only membership is the purpose
of the service. You can withdraw your consent at any time by deleting your account (section 7).

### 3.3 Your health and fitness information

| What | Why |
|---|---|
| Your setup answers: your goal, where you train, your equipment, days and minutes per week, and whether you are pregnant, postpartum, or training around pain or an injury | To build your plan and keep its suggestions safe for your situation |
| Workouts, sets, weights, repetitions, weekly goals, personal bests and milestones | To show you your training and your progress |
| Body measurements and weight you enter | To show you your progress |
| Meals you log, your eating preferences, foods you avoid and allergies you tell us about | To suggest meals and to refuse to call a dish safe when we cannot tell |
| Period days, cycle settings and daily check-ins (for example energy, sleep, bloating, pain and bleeding) | To adjust what the app suggests on a given day, and to stop suggesting a workout when you log severe symptoms |

Where it is kept depends on what it is:

- **Training and meal logs** (workouts, sets, weights, repetitions, weekly goals, personal bests,
  milestones and meals) stay on your phone, and once your account is verified a copy is also stored in
  Google Cloud Firestore in Frankfurt, Germany, under your account, so it survives a lost or replaced
  phone.
- **Health data** (period days, cycle settings, daily check-ins, body measurements and weight,
  pregnancy, postpartum or injury status, and allergies) **stays on your phone only.** It is copied to
  our servers in Frankfurt only if you turn on "Back up my health data" in the app. That switch is off
  until you choose it, and it asks for your consent on its own screen before anything is copied. You
  can turn it off at any time. Turning it off withdraws that consent and deletes the copy on our
  servers; your phone keeps its own copy.

Security rules on the server mean only your own signed-in, verified account can read what is stored
there.

Legal basis: your explicit consent, given on the backup screen for health data. `[COUNSEL: confirm that
this separate consent, and the in-app wording, meet the PDPL requirements for health data, and whether
syncing training and meal logs also needs explicit consent rather than being necessary to provide the
service.]` You can delete individual entries, or all your cycle data on its own, inside the app, and you
can remove everything by deleting your account.

**Your cycle and health information is never used for advertising or marketing, never sold, and never
sent to any analytics service.** Own Hub contains no analytics or advertising software.

### 3.4 Technical data

| What | Who | Why |
|---|---|---|
| Your IP address and device user agent at sign-in | Google Firebase Authentication | Security and sign-in. Google keeps IP addresses for a few weeks |
| An attestation that the app is genuine and unmodified | Google Play Integrity (Android) or Apple App Attest (iOS), through Firebase App Check | To stop automated abuse of the verification service, which costs money per check |
| Device model, operating system version, app version, a per-installation identifier, and performance and error events | Google ML Kit, the on-device face detection used to guide the selfie camera | Google uses these to run and improve ML Kit. Your images do not leave the phone through ML Kit |
| When the app crashes: the type of error, where in the code it happened, the device model, operating system version, app version, and free memory and storage at that moment | Google Firebase Crashlytics, release builds only | To find and fix crashes. No account identifier, phone number or error message is attached, so a crash report is not linked to you |

### 3.5 The waitlist on our website

Before the app opens to everyone, our website lets you join a waitlist.

| What | Why | How long |
|---|---|---|
| Your phone number or email address, whichever you give us, and your consent | To tell you once that the app is open | Deleted after that message is sent, and in any case within 180 days `[COUNSEL: confirm the period]` |
| Your IP address, only as a keyed one way code (a hash), never in readable form | To limit how often one connection can submit the form, so the list cannot be flooded | `[OWNER: confirm how long the rate limit code is kept]` |

Legal basis: your consent, given by ticking the box on the form. Joining the waitlist does not create
an Own Hub account, and we do not use these details for anything else.

## 4. How long we keep it

| What | How long |
|---|---|
| ID card photographs and selfie | Not stored. Discarded in memory when the check ends, whatever the result |
| Verification session state | Up to one hour, then deleted automatically |
| Your account, settings, training and meal logs, and consent records (including the consent for each review call) | Until you delete them or delete your account |
| The server copy of your health data | Only while "Back up my health data" is on. Deleted when you turn it off or delete your account |
| Log of reviewers looking up phone numbers | `[COUNSEL: period]` |
| Crash reports | Kept by Firebase Crashlytics for up to 90 days `[OWNER: confirm in the Crashlytics settings]` |
| Waitlist phone number or email | Until the one message telling you the app is open, and at most 180 days `[COUNSEL: confirm]` |
| Verification result, scores and fraud signals | Until you delete your account `[COUNSEL: or a fixed shorter period]` |
| One way keyed code of your ID number | See 4.1 |
| Daily totals of verifications, with no link to any person | Indefinitely |
| A record that a deletion was carried out, reduced to dates and status | `[COUNSEL: period]`, as proof that your request was honoured |
| Backups held by Google | Removed from Google's systems within Google's own deletion window, up to 180 days for Firebase Authentication |

### 4.1 What survives account deletion, on purpose

When you delete your account, the keyed code of your ID number is not deleted. It is kept **closed**:
the link to your account is removed and it is marked as no longer in use, but it still stops the same
card from opening a new account. No image, name, number or date of birth is kept with it.

`[COUNSEL: this is what the build does today. Decide whether a woman who deleted her account may rejoin
with the same card, and for how long the closed code is kept. Choose one option below and delete the
other; if counsel chooses Option A, the build must change before launch.]`

- **Option A.** When you delete your account, the keyed code of your ID number is deleted too, unless
  your account was removed for breaking the community rules. In that case the code is kept, with no
  link to your account, for `[COUNSEL: period]` so that the same card cannot rejoin.
- **Option B.** When you delete your account, the keyed code of your ID number is kept with the link to
  your account removed, for `[COUNSEL: period]`, so that the same card cannot open a new account during
  that time. This means that if you delete your account you cannot rejoin with the same card until
  that period ends.

### 4.2 Refused applications

If your application is refused, we keep the keyed code of your ID number, the reason code and the date
for `[COUNSEL: period]`, so that repeated attempts with the same card can be recognised. No image,
name, number or date of birth is kept.

## 5. Who else handles your data

We do not sell your data and do not share it with advertisers, data brokers or marketing companies. We
use the following service providers, who process data only on our instructions:

| Provider | What they handle | Where |
|---|---|---|
| Google Firebase Authentication | Your phone number, IP address and device user agent | United States |
| Your mobile operator, and the SMS partners Google uses | Your phone number and the sign-in code | Egypt and `[OWNER: unknown, Google does not publish the SMS route]` |
| Google Cloud Firestore, Cloud Functions, Secret Manager and Cloud Storage | Your account, your health and fitness information, verification results and the keyed ID code | Frankfurt, Germany (europe-west3). The content library (exercise and recipe media, which contains no personal data) is served from the United States |
| Google Cloud Vision | The text on your ID card, during the check only | European Union |
| Google Firebase Crashlytics | Crash reports as described in 3.4, with no account identifier | United States |
| `[OWNER: the website host, for example Cloudflare]` | Waitlist phone numbers or email addresses, and the hashed IP addresses used for rate limiting | `[OWNER: region]` |
| Google Play Integrity, Apple App Attest | Attestation that the app is genuine | Google and Apple systems, worldwide |
| Google ML Kit | Device and performance data listed in 3.4 | Google systems, worldwide |
| `[OWNER: video call service]` | Your image and voice during a review call, if you choose one | `[OWNER: region]` |

Google acts as our processor under the Google Cloud and Firebase data processing terms, which commit it
to protect the data to a standard at least equal to this policy. `[OWNER: confirm the Google Cloud Data
Processing Addendum has been accepted in the Cloud console for project own-hub.]`

We may also disclose data where Egyptian law requires it, for example in answer to a lawful order of a
court or a competent authority.

## 6. Transfers outside Egypt

Your data is stored and processed outside Egypt: in Germany and the European Union for your health
information and your verification, and in the United States for your phone number, which Firebase
Authentication keeps there, and for crash reports. Egypt's Personal
Data Protection Law No. 151 of 2020 allows transfers abroad only with a licence or permit from the
Personal Data Protection Center, and its Executive Regulations also require your consent to the
transfer. We ask for that consent, naming these countries, before any of your data leaves your phone.
`[COUNSEL: add the permit number and the countries it covers once issued, and confirm whether the
United States, where Firebase Authentication runs, can be covered.]`

## 7. Deleting your account

**In the app:** Profile, then Your data, then Delete my account. We confirm your request with a code
sent to your phone, then erase your account and everything listed in section 3 from our servers,
including any health data backup, and from your phone. About an hour later a second sweep runs over
your account again and removes anything that was still being written when you deleted it. The app tells
you when deletion is complete.

**Without the app:** write to mahmoud.reda.acc@gmail.com from any address, giving the phone number on
the account, or use the page at `[OWNER: https://yourdomain/delete-account]`. We will ask you to
confirm with a code sent to that number, and we will complete the deletion within
`[COUNSEL: period required by the Executive Regulations, for example 30 days]`.

What is kept after deletion is listed in section 4.1.

## 8. Your rights

Under Egypt's Personal Data Protection Law No. 151 of 2020 you have the right to:

- know what personal data we hold about you and obtain a copy of it;
- have it corrected or completed;
- have it erased;
- withdraw your consent at any time, without affecting processing that took place before;
- object to processing, or ask us to restrict it;
- be told of any breach of your personal data.

To use any of these rights, write to mahmoud.reda.acc@gmail.com. We will answer within six working
days, as Article 32 of the law requires. We do not charge for these requests `[COUNSEL: confirm; the law
allows a capped fee]`. A copy of your data is not yet
available as a button in the app, so we will send it to you by email on request.

If you are not satisfied with our answer, you can complain to the Personal Data Protection Center
(PDPC) in Egypt. `[COUNSEL: add the PDPC's current complaint channel.]`

## 9. Security

- Sign-in uses a one time code sent to your phone. There is no password to steal.
- Data travels over encrypted connections (TLS) and Google encrypts it where it is stored.
- Server rules mean that your account can read only your own data, and the app cannot mark itself as
  verified. Only our server can do that.
- Verification images are never written to disk, logs or storage by us.
- The secret key behind the ID code is held in Google Secret Manager, separate from the database.
- No system is perfectly secure. If a breach affects your personal data, we will notify the Personal
  Data Protection Center within 72 hours of becoming aware of it, and tell you by SMS within three
  working days after that, as the Executive Regulations require.

## 10. What Own Hub does not do

- No adverts, no advertising identifiers, no tracking across other apps or websites.
- No analytics software. The only crash reporting is Firebase Crashlytics, which carries no account
  identifier and no error message (section 3.4).
- No access to your contacts, location, photo library, microphone, or Apple Health or Health Connect.
- No AI that guesses your sex, age or anything else about you from your face.
- No community, coaching, payments or assistant in this version. When any of those are added, this
  policy will be updated first.

## 11. Changes to this policy

We will publish any change here with its date. If a change means collecting something new or using
your data in a new way, we will tell you in the app before it takes effect and ask for your consent
where the law requires it.

| Date | Version | What changed |
|---|---|---|
| `[OWNER: date]` | 2.0 | Accounts, identity verification, cloud storage of training and meal logs, an optional health data backup, crash reports and the website waitlist. Replaces the version written for a build with no server |

**Questions:** mahmoud.reda.acc@gmail.com
