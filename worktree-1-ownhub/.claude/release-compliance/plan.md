# Own Hub compliance plan: legal texts, consent, data rights, claims, build order

Prepared 6 Oct 2026 from the judge output, the master checklist and a fresh read of the worktree at `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding` (branch `onboarding/2026-10-06`, uncommitted).

**Markers**
- **[LAWYER]** means a licensed Egyptian lawyer has to confirm the point before publishing.
- **[OWNER]** means a value only Mahmoud can supply. It goes into `site/config.json` or the app config.
- Nothing in this file is legal advice.

**Copy rules:** there are no em dashes in the product copy. The Arabic is Modern Standard Arabic and addresses the reader in the feminine, as the current app and site do.

---

## 0. Facts from the code that the drafts rely on

| Fact | Where |
|---|---|
| Region europe-west3 (Frankfurt). Cloud Vision uses the EU endpoint `eu-vision.googleapis.com`. | `functions/identity/config.py:48,55` |
| Face match runs on the self-hosted YuNet (MIT) and SFace (Apache-2.0) models. No outside face service is used. | `functions/models/*`, `providers_selfhosted.py` |
| `MIN_AGE = 18`. Sex comes only from digit 13 of the national ID number. | `config.py:114`, `nid.py:291` |
| Job fields are allow-listed: no image, name, birth date or raw NID. Reasons, flags, attempt, bands and dates are kept. | `store.py:308-345` |
| Decided jobs and flags get a TTL of 180 days. Pending cases have no TTL. | `config.py:548`, `store.py:403` |
| `nidRegistry` is CLOSED, not deleted, when she deletes her account. | `config.py:579`, manifest row 23 |
| `verificationBehaviour` (failure count per ID HMAC) and `verificationInstalls` (SHA-256 of the install id, holding the last 10 HMACs) have no TTL and survive deletion. | `store.py:259-303`, `deletion.py:40-42` |
| `verificationReviewAccess` (the reviewer access log) has no TTL and survives deletion. | `config.py:601`, `main.py:754` |
| Review routes are `video` and `gym`. The SLA is 72h and a booking can be up to 7 days ahead. | `config.py:494,512,527` |
| The flag webhook posts only the flag id and reason codes to "a third-party chat service". | `identity/webhook.py:1-4` |
| Consent records live at `users/{uid}/consents/verification-v1`, `health-v1` and `review-v1`. Clients can read them; only the server writes them. | `store.py:532-640`, `firestore.rules:910-913` |
| `record_consent` stores only the version and a timestamp: no locale, no app version. | `store.py:532` |
| Health backup is gated by `health-v1` and the doc id is hard-coded in the rules. | `firestore.rules:145-147` |
| Synced profile keys: goal, place, equipment, days, minutes, lifeStage*, setupDone, allergies*, dietary, language. Starred keys need health consent. | `firestore.rules:382-388` |
| Synced collections: sessions, meals, eatPrefs (plates, **ramadanMode**, protein target), mealPlans, notices, firstWeek. Health collections sync only with backup on. | `cloud_documents.dart:226-268`, `firestore.rules:630-643` |
| `meals` and `eatPrefs` have `allow delete: if false`. A day is corrected by rewriting it. | `firestore.rules:626,643` |
| Crashlytics is enabled at boot in release. Native defaults are off. Reports carry the error type and stack only. | `firebase_boot.dart:106,146-153`, `crash_reports.dart` |
| App Check (Play Integrity / App Attest) is activated at boot. | `firebase_boot.dart:132-137` |
| ML Kit face detection runs on the device. | `pubspec.yaml google_mlkit_face_detection` |
| There is no analytics SDK. The analytics sink is debug-only. | `main.dart:43`, `deletion.py` "purgingThirdParty" |
| The assistant is off and uses a stub provider. The wire carries the `avoid` tags and `allergies`, and no uid. | `feature_flags.dart:216`, `assistant_wire.dart:122-194` |
| All 4 `LegalLinks` are empty. | `app/lib/config/legal_links.dart` |
| ARB files are generated. String changes go through `app/tool/add_strings.py` and `6-v2/i18n/*.json`. Never hand-edit the ARB files. | `tool/add_strings.py` |
| Site pages are generated from `site/_build/pages_en.py` and `pages_ar.py` plus `site/config.json`. | `site/_build/build.py` |

---

## 1. Privacy Policy v3.0

**Where it goes:** this replaces the privacy page in `site/_build/pages_en.py` and `pages_ar.py`. Remove the draft banner only once counsel has signed off.

**Two decisions are built into the draft:**
- Crash reports need her consent (MUST item M3).
- Fraud signals and the access log get TTLs (MUST item M9).

If either is not built, the matching lines have to change before publishing.

### 1A. English

---

# Privacy Policy

**Version 3.0** · Effective [OWNER: launch date] · Applies to Own Hub for iOS and Android (bundle id com.ownhub.app) and to this website.

If the English and Arabic versions of this policy differ, the Arabic version applies. [LAWYER]

## The short version

- Own Hub is a fitness app for women in Egypt aged 18 and over. Membership is for women only, for women's safety and privacy. To keep it that way, we check your Egyptian national ID card and a live selfie once, when you join.
- **The photographs of your card and your face are never stored.** Our server in Frankfurt, Germany reads them in memory and discards them when the check ends. We keep the result for 180 days. We also keep a keyed code made from your ID number, so that one card cannot open two accounts.
- **Your cycle, check-ins, measurements, weight, pregnancy or postpartum stage and allergies stay on your phone,** unless you turn on health backup yourself.
- Once you are verified, your workouts and meals are copied to Google Cloud in Frankfurt, so a new phone does not mean starting again. No other member can see them.
- To send your sign-in code, your phone number goes to Google Firebase in the United States.
- We do not sell your data. There are no adverts, no tracking and no analytics. Crash reports are sent only if you allow them.
- **We never use your data to train AI, ours or anyone's.**
- You can delete your account in the app at any time, and ask us for a copy of your data.

## 1. Who is responsible for your data

| | |
|---|---|
| Controller | [OWNER and LAWYER: "Mahmoud Reda, an individual publishing Own Hub in his own name", or the company name if a company is formed] |
| Address | [LAWYER: a full postal address, required by Consumer Protection Law 181/2018 Art. 5, or confirmation that an exemption applies] |
| Commercial registration | [LAWYER: number, or "not applicable"] |
| Privacy contact | [OWNER: privacy@ mailbox on the Own Hub domain] |
| Data protection officer | [LAWYER: name and registration, required if a company is the controller] |
| Personal Data Protection Centre licence or permit | [OWNER: number and expiry, once issued] |

Rahma Mohsen is Own Hub's founder and coach, and the face of the brand. She is not the controller of your data and has no access to your account data. [OWNER: confirm]

The women who review verification cases act on the controller's instructions and are bound by a written confidentiality agreement. [OWNER: agreements signed]

## 2. Who can use Own Hub, and why it is for women only

Own Hub is for women aged 18 or over who hold an Egyptian national ID card. It is for women only so that women can train in a space where they feel safe and their privacy is respected. [LAWYER: framing under LAW-14]

Your sex and your age are read from the digits of your national ID number. We never guess them from your face.

We do not knowingly collect data from anyone under 18. If the check shows that you are under 18, your application is refused. The refusal is kept as section 6 describes.

## 3. What we collect, why, and on what basis

[LAWYER: confirm each legal basis against Law 151/2020 and its Executive Regulations.]

### 3.1 Your account

- **Your mobile number.** Used to create your account and sign you in with a code sent by SMS, and to phone you if you ask a woman reviewer to check you.
- **An account identifier we generate.** Used to link your data to your account.
- **Your language, settings and setup answers.** This covers your privacy switches, notification preferences and quiet hours, your goal, where you train, your equipment, your training days and minutes, and your dietary preferences. Used to run the app the way you set it.
- **Basis:** performing our agreement with you (the Terms of Use).

### 3.2 Your agreements

When you sign up, we record which versions of the Terms of Use and this policy you accepted, in which language, from which app version, and when. We keep a similar record for each separate consent you give: the identity check, health backup and a review by a woman.

- **Basis:** proving what you agreed to, which the law requires of us. [LAWYER]

### 3.3 Checking that you are a woman aged 18 or over

This happens once, when you join, and only after you have read a separate screen and agreed to it. The camera does not start until our server has recorded that agreement. The camera is the only way to take the photographs: the app cannot upload a picture that is already on your phone.

- **Photographs of the front and back of your ID card.** Sent over an encrypted connection to our server in Frankfurt, Germany. Google Cloud Vision reads the text on the card through its European Union endpoint. The images are not stored anywhere.
- **A short live selfie,** taken while you follow prompts chosen by our server. It checks that a live person is present and that the face matches the portrait on the card. The comparison runs on our own server, with no outside face recognition service. We do not store the selfie or any face measurement.
- **Your national ID number.** Used to confirm your sex (from the digit the Civil Status authority sets in the number) and your age (from the birth date encoded in it). It is then turned into a one-way keyed code, with a secret key held separately in Google Secret Manager. The number itself is not stored.
- **Your name and date of birth** as printed on the card. Read only to cross-check the number, and not stored.
- **The result:** approved, refused, or sent to a woman reviewer. It comes with reason codes, coarse score bands (never raw scores), the attempt number and the dates. The app shows you whether your check is pending, approved, refused or ready to try again.
- **Fraud signals:**
  - a count of failed attempts for each ID code;
  - a scrambled code for the app installation, together with the last ID codes tried from it, so that one installation trying many cards can be noticed.
- **Basis:** your explicit consent, given on the screen before the camera opens. The face match is biometric data, which the law treats as sensitive. [LAWYER: sensitive-data licence, LAW-02]
- You can refuse. If you do, you can still ask a woman reviewer to check you (section 3.4). Without a check you cannot open a verified account, because a women-only membership is the purpose of the service.

### 3.4 Review by a woman

Your case goes to a woman reviewer in four situations:
- the automatic check is unsure;
- you wear niqab and prefer a woman reviewer;
- you decline the camera;
- the check cannot run for a technical reason.

What happens next:
- **Your request.** When you ask for this, we record your request and the route you chose (section 3.2).
- **The queue.** The review queue holds reason codes and score bands. It never holds a photograph or your phone number.
- **The call.** When a reviewer is ready to contact you, she looks up your number at that moment. Each lookup is recorded with the reviewer and the time. She phones you to arrange either:
  - a short video check on [OWNER: video service name], or
  - a visit to a ladies-only gym. [OWNER: confirm which routes run at launch, and delete any that do not]
- **Nothing is recorded.** The check is not recorded, and the reviewer writes down only her decision and the date.
- **Your ID number.** If your case has no ID code yet, the reviewer may ask you to read out your ID number. It is turned into the keyed code at once, and is never stored or written to a log.
- **Our team's alert.** When a case enters the queue, our team gets an alert containing only the case number and the reason codes. It is sent through [OWNER: chat service name, or delete this sentence if the alert is removed].
- **Basis:** your consent, given when you ask for the review.

### 3.5 Your training and meals

Workouts, sets, weights and repetitions, weekly goals, personal bests, the meals you log, your usual plates, your protein target and your meal plans stay on your phone. Once your account is verified, a copy is also kept in Google Cloud Firestore in Frankfurt, Germany, so that it survives a lost or replaced phone. Server security rules let only your own verified account read it. No other member can see it.

Your Ramadan setting stays on your phone only. [needs MUST item M10]

- **Basis:** performing our agreement with you.

### 3.6 Your health information stays on your phone

By default, these are kept on your phone only:
- your cycle settings and period days;
- your daily check-ins (for example energy, sleep, bloating, pain and bleeding);
- your body measurements and weight;
- your life stage (pregnancy, postpartum or training around an injury);
- the allergies you tell us about.

You can choose to back them up. In Profile, then Privacy, "Back up my health data" asks for a separate consent. That consent names this information and the countries where it would be stored. Nothing is copied until our server has recorded the consent, and our server's security rules refuse the copy without it. If you turn backup off, we delete the copy on our servers straight away. The copy on your phone stays.

Your cycle and health information is never used for advertising or marketing, never sold, never sent to any analytics service, and never used to train AI.

- **Basis:** your explicit consent. [LAWYER]

### 3.7 Technical data

- **Sign-in security.** When you sign in, Google Firebase Authentication receives your IP address and device details. To stop abuse of text messages, Firebase may confirm that the request comes from a real device, using Google Play Integrity, an Apple push notification, or a reCAPTCHA check page.
- **Genuine-app check.** From the first time you open the app, Firebase App Check uses Google Play Integrity (Android) or Apple App Attest (iOS) to confirm that requests come from the real Own Hub app. Firebase gives the installation a random identifier for this.
- **Selfie guidance.** Google ML Kit detects your face on the phone to guide the selfie camera. Your images do not leave the phone through ML Kit. ML Kit sends Google the device model, operating system, app version, an installation identifier and performance events.
- **Crash reports, only if you allow them.** You can allow them on the sign-up screen, or later in Profile, then Privacy. They are off until you do.
  - What Firebase Crashlytics receives when the app crashes: the type of error and where in the code it happened, your device model, operating system, app version, free memory and storage, and an installation identifier.
  - What is never attached: your account identifier, your name or your phone number.
  - If you turn them off, reports waiting on your phone are deleted.
- **Our server logs.** These record outcomes and reason codes. They never record your phone number or your ID number, and they never place your account identifier beside an outcome.
- **Basis:** our legitimate interest in keeping the service secure and working, except crash reports, which need your consent. [LAWYER: confirm that App Check and ML Kit can run before sign-up on this basis, LAW-17 item 10]

### 3.8 Artificial intelligence

- **We never use your data to train AI models, ours or anyone's.**
- Google Cloud Vision reads the text on your ID card only to run the check. Under Google Cloud's terms, Google may not use that data to train its own models. [LAWYER: confirm in the Google Cloud data processing terms]
- The face comparison uses open-source models that run on our own server. Their authors trained them before Own Hub existed. They are not trained or adjusted with your face.
- There is no AI assistant in this version of Own Hub. If we add one, we will ask for your separate agreement first, naming the provider, before anything is sent to it.

### 3.9 Messages you send us

If you write to us, we keep your message and your email address so that we can answer you. These are deleted [LAWYER: period, for example 2 years] after the conversation ends.

### 3.10 The waitlist and this website

**If you joined the waitlist on this website,** we keep the mobile number or email address you gave, the language you chose, your agreement and the date you joined.
- We use it for one thing: to message you once when Own Hub opens. Then we delete it.
- If that has not happened, it is deleted automatically 180 days after you joined.
- So that we can prove you agreed, we keep a keyed code made from your contact, the version of the wording you agreed to, and the date, for 3 years. [LAWYER]
- To protect the form from abuse, we keep a keyed code made from your internet address (never the address itself) and a count of attempts from it. Both are deleted after two days.
- It is all stored in Google Cloud Firestore in Frankfurt, Germany.

**This website** sets no cookies, runs no scripts and counts no visits. Our hosting provider, [OWNER: host name], receives the standard data any website receives, such as your IP address and browser type, in order to deliver the pages. [OWNER: confirm the host's log retention]

## 4. Who handles your data, and where

We do not sell your data, and we do not share it with advertisers, data brokers or marketing companies. The service providers below process data only on our instructions. [LAWYER: confirm the processor agreements, LAW-08]

| Provider | What it handles | Where |
|---|---|---|
| Google Firebase Authentication | Your phone number, IP address and device details | United States |
| Your mobile operator and Google's SMS partners | Your phone number and the sign-in code | Egypt, and the route Google uses |
| Google Cloud Firestore, Cloud Functions, Cloud Storage and Secret Manager | Your account, training and meals, health information if you turn on backup, verification results and the keyed ID code | Frankfurt, Germany (europe-west3) |
| Google Cloud Vision | The text on your ID card, during the check only | European Union |
| Google Play Integrity, Apple App Attest, reCAPTCHA, Firebase App Check | Confirmation that the app and the device are genuine | Google and Apple systems [LAWYER: countries] |
| Google ML Kit | Device and performance data (section 3.7) | Google systems [LAWYER: countries] |
| Firebase Crashlytics, only if you allow it | Crash data (section 3.7) | United States |
| [OWNER: video service] | Your image and voice during a review call, if you have one | [OWNER: region] |
| [OWNER: chat service for review alerts] | A case number and reason codes only | [OWNER: region] |
| [OWNER: email provider] | Messages you send us | [OWNER: region] |
| [OWNER: website host] | Standard website request data | [OWNER: region] |

We may also disclose data where Egyptian law requires it, for example in answer to a lawful order from a court or a competent authority. If Own Hub is ever transferred to another publisher, we will tell you in the app first, and this policy will continue to protect your data. [LAWYER]

## 5. Transfers outside Egypt

Your data is stored and processed outside Egypt:
- **Germany and the European Union:** your account, your training and meals, any health backup, and your verification.
- **The United States:** your phone number, the device checks, ML Kit performance data, and crash reports if you allow them.
- [OWNER: the video service's country, if one is used.]

Egypt's Personal Data Protection Law No. 151 of 2020 allows transfers abroad only under a licence or permit from the Personal Data Protection Centre, and with your consent. We ask for that consent on the sign-up screen, naming these countries, before your phone number is sent. We ask again, separately, before any health information is backed up.

Licence or permit: [OWNER: number]. Safeguards: [LAWYER: the transfer mechanism, for example Google's data processing terms and standard contractual clauses].

## 6. How long we keep it

| Data | How long |
|---|---|
| ID card photographs, selfie, name and date of birth from the card, your raw ID number | Never stored. Discarded from memory when the check ends, whatever the result. |
| The single-use selfie session | 5 minutes, then deleted automatically |
| Verification result and review case | 180 days after the case is decided, or earlier if you delete your account. A case still waiting for review is kept until it is decided. [LAWYER] |
| The keyed code of your ID number | While your account exists. After you delete your account it is closed, not deleted: it is no longer linked to any account, and it stops the same card opening a new one. [LAWYER: the period, and whether a woman who deleted may rejoin] |
| Count of failed attempts per ID code, and the scrambled installation record | 180 days after the last attempt. Not linked to your account. [LAWYER] |
| Reviewer access log (which reviewer opened which case, and when) | 1 year. It holds no photograph, phone number or ID number. [LAWYER] |
| Your account, settings, training, meals, any health backup and your consent records | Until you delete them or delete your account |
| The record that a deletion was carried out (status and dates only) | [LAWYER: period], as proof that your request was honoured |
| Daily totals of verifications, with no link to any person | Kept |
| Our server logs | [OWNER: 30 days, the Cloud Logging default; confirm] |
| Crash reports, if you allow them | [OWNER: 90 days, as Google keeps them; confirm] |
| Messages you send us | [LAWYER: period] |
| Waitlist contact | 180 days at most. The proof that you agreed is kept for 3 years (section 3.10). |
| Backups held by Google | Removed within Google's own deletion period [OWNER: confirm] |

## 7. Deleting your account

**In the app:** Profile, then Your data, then Delete everything. You do not need to be verified to do this.
- Our server locks your sign-in first.
- It then deletes your account and the data in section 3, and deletes your sign-in record, including your phone number, last.
- Your phone is cleared at the same time.
- It usually takes under a minute. If anything interrupts it, it finishes on its own within the hour.

**Without the app:** use the deletion page on this website [OWNER: URL]. It explains how to ask by email. We confirm that the request comes from the owner of the number on the account [OWNER: method, for example a code sent by SMS], then delete within [LAWYER: period] and confirm in writing.

**What remains after deletion, on purpose:**
- the closed keyed code of your ID number (section 6);
- the failed-attempt count and the installation record, until their 180 days end, linked to no account;
- reviewer access log entries for your case, until their year ends;
- the record that the deletion was carried out.

Crash reports and ML Kit data are never linked to your account. Google deletes them on its own schedule.

**Deleting only part of your data:**
- turn off health backup (this deletes the cloud copy);
- delete your cycle data on its own, from cycle settings;
- remove items from a day's log, and delete individual measurements.

## 8. Your rights

Under Egypt's Personal Data Protection Law No. 151 of 2020, you have the right to:

- know what personal data we hold about you, and get a copy of it;
- have it corrected or completed;
- have it erased;
- withdraw your consent at any time, without affecting processing that took place before. You can turn off crash reports and health backup yourself in Profile, then Privacy.
- object to processing, or ask us to restrict it;
- be told of any breach of your personal data.

**A copy of your data:**
- How to ask: in the app (Profile, then Your data, then Ask for a copy), or write to [OWNER: privacy mailbox].
- What you get: a file a computer can read, plus a summary in your language.
- How you get it: [LAWYER: delivery method, for example a password-protected file by email with the password sent by SMS].
- Health information that is only on your phone is not held by us. You can see it in the app.

**Response time:** we answer every request within [LAWYER: for example 6 working days]. Requests are free. [LAWYER]

**Complaints:** if you are not satisfied with our answer, you can complain to Egypt's Personal Data Protection Centre: [LAWYER: contact details].

## 9. Security

- Sign-in uses a one-time code sent to your phone. There is no password to steal.
- Data travels over encrypted connections, and Google encrypts it where it is stored.
- Server rules let your account read only your own data, and the app cannot mark itself as verified. Only our server can do that.
- We never write verification images to disk, logs or storage.
- The secret key behind the ID code is held in Google Secret Manager, separate from the database.
- Access to our systems is limited to the people who run Own Hub, and every lookup of a phone number for a review is recorded.
- No system is perfectly secure. If a breach affects your personal data, we will notify the Personal Data Protection Centre within 72 hours of becoming aware of it, and tell you within three working days after that. [LAWYER]

## 10. What Own Hub does not do

- No adverts, no advertising identifiers, and no tracking across other apps or websites.
- No analytics software.
- No sale of your data.
- No training of AI on your data.
- No access to your contacts, location, photo library, microphone, text messages, or Apple Health or Health Connect. The app itself never uses your microphone. A video review, if you have one, takes place in [OWNER: video service], outside the app.
- Nothing that guesses your sex, age or anything else about you from your face.

## 11. Children

Own Hub is not for anyone under 18. We do not knowingly keep data about children. If you believe a child has an account, write to us and we will delete it.

## 12. Changes to this policy

We publish every change here, with its date and version.
- **Material changes** require your agreement in the app before they apply to you. A material change is one that collects something new, uses your data for a new purpose, adds a new country or a new kind of provider, or reduces your rights.
- **Other changes** are announced in the app.

Version history:
- **3.0, [OWNER: date]:** acceptance recorded at sign-up, crash reports by consent, AI statement, full retention periods, copy of your data on request.
- **2.0, 24 September 2026:** accounts and the women-only check.

## 13. Language

This policy is published in Arabic and English. If they differ, the Arabic version applies. [LAWYER]

## 14. Contact

[OWNER: privacy mailbox] · [OWNER/LAWYER: controller name and address]

---

### 1B. العربية

---

# سياسة الخصوصية

**الإصدار 3.0** · تاريخ السريان [OWNER: تاريخ الإطلاق] · تنطبق على تطبيق Own Hub على iOS وAndroid (معرّف الحزمة com.ownhub.app) وعلى هذا الموقع.

إذا اختلفت النسختان العربية والإنجليزية من هذه السياسة، فالنسخة العربية هي المعتمدة. [LAWYER]

## باختصار

- Own Hub تطبيق لياقة للنساء في مصر ممن بلغن الثامنة عشرة فأكثر. العضوية مقصورة على النساء، حفاظًا على أمانهن وخصوصيتهن. ولكي تبقى كذلك، نتحقق من بطاقة الرقم القومي المصرية ومن صورة ذاتية حية مرة واحدة عند انضمامك.
- **لا تُخزَّن صور بطاقتك ولا صورة وجهك أبدًا.** يقرؤها خادمنا في فرانكفورت بألمانيا في الذاكرة، ويتلفها عند انتهاء التحقق. ونحتفظ بالنتيجة مدة 180 يومًا، وبرمز مشفّر مشتق من رقمك القومي حتى لا تفتح البطاقة الواحدة حسابين.
- **دورتك، والمتابعات اليومية، والقياسات، والوزن، ومرحلة الحمل أو ما بعد الولادة، والحساسية الغذائية تبقى على هاتفك،** إلا إذا فعّلتِ النسخ الاحتياطي الصحي بنفسك.
- بعد التحقق من حسابك تُنسخ تمارينك ووجباتك إلى Google Cloud في فرانكفورت، حتى لا تبدئي من جديد إذا غيّرتِ هاتفك. ولا تستطيع أي عضوة أخرى رؤيتها.
- لإرسال رمز الدخول، يُنقل رقم هاتفك إلى خدمة Google Firebase في الولايات المتحدة.
- لا نبيع بياناتك. لا إعلانات، ولا تتبّع، ولا أدوات تحليلات. ولا تُرسل تقارير الأعطال إلا إذا سمحتِ بها.
- **لا نستخدم بياناتك أبدًا لتدريب الذكاء الاصطناعي، لا نحن ولا غيرنا.**
- يمكنك حذف حسابك من داخل التطبيق في أي وقت، وطلب نسخة من بياناتك.

## ١. المسؤول عن بياناتك

| | |
|---|---|
| المتحكّم في البيانات | [OWNER وLAWYER: «محمود رضا، فرد ينشر Own Hub باسمه الشخصي»، أو اسم الشركة إن أُسست] |
| العنوان | [LAWYER: عنوان بريدي كامل وفق المادة 5 من قانون حماية المستهلك 181 لسنة 2018، أو تأكيد الإعفاء] |
| السجل التجاري | [LAWYER: الرقم، أو «لا ينطبق»] |
| التواصل بشأن الخصوصية | [OWNER: صندوق بريد privacy@ على نطاق Own Hub] |
| مسؤول حماية البيانات | [LAWYER: الاسم والقيد، وهو مطلوب إذا كانت الشركة هي المتحكّم] |
| ترخيص أو تصريح مركز حماية البيانات الشخصية | [OWNER: الرقم وتاريخ الانتهاء بعد الإصدار] |

رحمة محسن هي مؤسِّسة Own Hub ومدرّبته ووجه علامته. وهي ليست المتحكّمة في بياناتك، ولا تطّلع على بيانات حسابك. [OWNER: للتأكيد]

المراجِعات اللواتي يراجعن حالات التحقق يعملن وفق تعليمات المتحكّم في البيانات، ويلتزمن باتفاق سرّية مكتوب. [OWNER: توقيع الاتفاقات]

## ٢. من تستطيع استخدام Own Hub، ولماذا هو للنساء فقط

Own Hub مخصّص للنساء ممن بلغن الثامنة عشرة فأكثر ويحملن بطاقة رقم قومي مصرية. وهو للنساء فقط لكي تتدرّب المرأة في مساحة تشعر فيها بالأمان وتُحترم فيها خصوصيتها. [LAWYER: الصياغة وفق البند LAW-14]

يُقرأ جنسك وعمرك من أرقام رقمك القومي، ولا نخمّنهما من وجهك أبدًا.

لا نجمع عن علم بيانات أي شخص دون الثامنة عشرة. فإذا تبيّن من التحقق أنك دون الثامنة عشرة، يُرفض طلبك، ويُحتفظ بقرار الرفض على النحو المبيّن في القسم ٦.

## ٣. ما نجمعه، ولماذا، وعلى أي أساس

[LAWYER: تأكيد كل أساس قانوني وفق القانون 151 لسنة 2020 ولائحته التنفيذية.]

### ٣.١ حسابك

- **رقم هاتفك المحمول.** لإنشاء حسابك وتسجيل دخولك برمز يُرسل برسالة نصية، وللاتصال بك إذا طلبتِ أن تراجع حالتك امرأة.
- **معرّف للحساب ننشئه نحن.** لربط بياناتك بحسابك.
- **لغتك وإعداداتك وإجاباتك عند الإعداد.** وتشمل مفاتيح الخصوصية، وتفضيلات الإشعارات، وساعات الهدوء، وهدفك، ومكان تدريبك، وأدواتك، وأيام تدريبك ومدته، وتفضيلاتك الغذائية. ليعمل التطبيق كما ضبطتِه.
- **الأساس:** تنفيذ اتفاقنا معك (شروط الاستخدام).

### ٣.٢ موافقاتك

عند التسجيل نسجّل إصداري شروط الاستخدام وهذه السياسة اللذين قبلتِهما، واللغة، وإصدار التطبيق، والوقت. ونسجّل مثل ذلك لكل موافقة مستقلة تمنحينها: التحقق من الهوية، والنسخ الاحتياطي الصحي، ومراجعة امرأة لحالتك.

- **الأساس:** إثبات ما وافقتِ عليه، وهو التزام قانوني علينا. [LAWYER]

### ٣.٣ التحقق من أنك امرأة بلغت الثامنة عشرة

يحدث هذا مرة واحدة عند انضمامك، وبعد أن تقرئي شاشة مستقلة وتوافقي عليها فقط. ولا تعمل الكاميرا قبل أن يسجّل خادمنا موافقتك. والكاميرا هي الطريقة الوحيدة لالتقاط الصور، فلا يستطيع التطبيق رفع صورة موجودة مسبقًا على هاتفك.

- **صورتا وجه بطاقتك وظهرها.** تُرسلان عبر اتصال مشفّر إلى خادمنا في فرانكفورت بألمانيا، ويقرأ Google Cloud Vision النص المطبوع على البطاقة عبر نقطة الاتصال الخاصة بالاتحاد الأوروبي. لا تُخزَّن الصور في أي مكان.
- **صورة ذاتية حية قصيرة** تلتقطينها وأنت تتبعين تعليمات يختارها خادمنا، للتأكد من وجود شخص حيّ ومن تطابق الوجه مع الصورة المطبوعة على البطاقة. تجري المقارنة على خادمنا نفسه، دون أي خدمة خارجية للتعرّف على الوجوه. لا نخزّن الصورة الذاتية ولا أي قياس للوجه.
- **رقمك القومي.** يُستخدم لتأكيد جنسك (من الرقم الذي تضعه مصلحة الأحوال المدنية فيه) وعمرك (من تاريخ الميلاد المرمّز فيه)، ثم يُحوَّل إلى رمز مشفّر باتجاه واحد بمفتاح سرّي محفوظ منفصلًا في Google Secret Manager. لا يُخزَّن الرقم نفسه.
- **اسمك وتاريخ ميلادك** كما طُبعا على البطاقة. يُقرآن فقط لمطابقة الرقم، ولا يُخزَّنان.
- **النتيجة:** قبول، أو رفض، أو إحالة إلى مراجِعة. ومعها رموز الأسباب، وفئات تقريبية للدرجات (لا الدرجات نفسها أبدًا)، ورقم المحاولة، والتواريخ. ويُظهر لك التطبيق ما إذا كان التحقق قيد الانتظار أو مقبولًا أو مرفوضًا أو جاهزًا لإعادة المحاولة.
- **مؤشرات الاحتيال:**
  - عدد المحاولات الفاشلة لكل رمز بطاقة؛
  - رمز مُموَّه لتثبيت التطبيق مع آخر رموز البطاقات التي جُرّبت منه، حتى يُلاحَظ تثبيت واحد يجرّب بطاقات كثيرة.
- **الأساس:** موافقتك الصريحة على الشاشة التي تسبق فتح الكاميرا. ومطابقة الوجه بيانات حيوية يعدّها القانون بيانات حساسة. [LAWYER: ترخيص البيانات الحساسة، البند LAW-02]
- لك أن ترفضي. وعندها يمكنك أن تطلبي أن تراجع حالتك امرأة (القسم ٣.٤). ومن دون تحقق لا يمكن فتح حساب موثّق، لأن العضوية المقصورة على النساء هي الغاية من الخدمة.

### ٣.٤ المراجعة على يد امرأة

تُحال حالتك إلى مراجِعة في أربع حالات:
- إذا لم يحسم التحقق الآلي حالتك؛
- إذا كنتِ ترتدين النقاب وتفضّلين مراجِعة؛
- إذا رفضتِ تشغيل الكاميرا؛
- إذا تعذّر إجراء التحقق لسبب تقني.

ما يحدث بعد ذلك:
- **طلبك.** حين تطلبين ذلك نسجّل طلبك والطريقة التي اخترتِها (القسم ٣.٢).
- **قائمة المراجعة.** تحتوي على رموز الأسباب وفئات الدرجات، ولا تحتوي أبدًا على صورة ولا على رقم هاتفك.
- **الاتصال.** حين تستعدّ المراجِعة للتواصل معك تطّلع على رقمك في تلك اللحظة، ويُسجَّل كل اطّلاع مع اسم المراجِعة ووقته. ثم تتصل بك لترتيب أحد أمرين:
  - تحقق قصير بالفيديو عبر [OWNER: اسم خدمة الفيديو]؛
  - أو زيارة إلى صالة رياضية للسيدات. [OWNER: تأكيد الطرق المتاحة عند الإطلاق، وحذف ما لا يعمل منها]
- **لا يُسجَّل شيء.** لا يُسجَّل التحقق، ولا تدوّن المراجِعة إلا قرارها وتاريخه.
- **رقمك القومي.** إذا لم يكن لحالتك رمز بطاقة بعد، قد تطلب منك المراجِعة قراءة رقمك القومي، فيُحوَّل فورًا إلى الرمز المشفّر، ولا يُخزَّن ولا يُكتب في أي سجل.
- **تنبيه فريقنا.** حين تدخل حالة إلى قائمة المراجعة يصل إلى فريقنا تنبيه لا يحتوي إلا على رقم الحالة ورموز الأسباب، عبر [OWNER: اسم خدمة المحادثة، أو احذفي هذه الجملة إذا أُلغي التنبيه].
- **الأساس:** موافقتك التي تمنحينها عند طلب المراجعة.

### ٣.٥ تدريبك ووجباتك

تبقى التمارين والمجموعات والأوزان والتكرارات، والأهداف الأسبوعية، والأرقام الشخصية، والوجبات التي تسجّلينها، وأطباقك المعتادة، وهدفك من البروتين، وخطط وجباتك على هاتفك. وبعد التحقق من حسابك تُحفظ منها نسخة أيضًا في Google Cloud Firestore في فرانكفورت بألمانيا، حتى لا تضيع إذا فقدتِ هاتفك أو استبدلتِه. وتضمن قواعد الأمان على الخادم ألا يقرأها إلا حسابك الموثّق أنتِ، ولا تراها أي عضوة أخرى.

يبقى إعداد رمضان على هاتفك فقط. [يتطلب البند M10]

- **الأساس:** تنفيذ اتفاقنا معك.

### ٣.٦ معلوماتك الصحية تبقى على هاتفك

تُحفظ هذه البيانات على هاتفك فقط افتراضيًا:
- إعدادات دورتك وأيام الحيض؛
- المتابعات اليومية (مثل الطاقة والنوم والانتفاخ والألم والنزيف)؛
- قياسات الجسم والوزن؛
- مرحلتك (الحمل أو ما بعد الولادة أو التدريب مع إصابة)؛
- الحساسية الغذائية التي تخبريننا بها.

ولك أن تختاري نسخها احتياطيًا. ففي الملف الشخصي ثم الخصوصية، يطلب خيار «النسخ الاحتياطي لبياناتي الصحية» موافقة مستقلة تسمّي هذه المعلومات والدول التي ستُخزَّن فيها. ولا يُنسخ شيء منها قبل أن يسجّل خادمنا تلك الموافقة، وترفض قواعد الأمان على خادمنا نسخها من دونها. وإذا أوقفتِ النسخ الاحتياطي نحذف النسخة الموجودة على خوادمنا فورًا، وتبقى النسخة التي على هاتفك.

لا تُستخدم معلومات دورتك وصحتك في الإعلان أو التسويق أبدًا، ولا تُباع، ولا تُرسل إلى أي خدمة تحليلات، ولا تُستخدم لتدريب الذكاء الاصطناعي.

- **الأساس:** موافقتك الصريحة. [LAWYER]

### ٣.٧ البيانات التقنية

- **أمان تسجيل الدخول.** عند تسجيل الدخول تتلقّى خدمة Google Firebase Authentication عنوان IP وتفاصيل جهازك. ولمنع إساءة استخدام الرسائل النصية قد تتأكد Firebase من أن الطلب صادر عن جهاز حقيقي، عبر Google Play Integrity، أو إشعار من Apple، أو صفحة تحقق reCAPTCHA.
- **التأكد من أصالة التطبيق.** منذ أول فتح للتطبيق تستخدم Firebase App Check خدمة Google Play Integrity (على Android) أو Apple App Attest (على iOS) لتأكيد أن الطلبات صادرة عن تطبيق Own Hub الحقيقي، وتمنح Firebase التثبيت معرّفًا عشوائيًا لهذا الغرض.
- **توجيه الصورة الذاتية.** تكشف مكتبة Google ML Kit وجهك على الهاتف لتوجيه كاميرا الصورة الذاتية، ولا تغادر صورك الهاتف عبرها. وترسل ML Kit إلى Google طراز الجهاز ونظام التشغيل وإصدار التطبيق ومعرّفًا للتثبيت وأحداث الأداء.
- **تقارير الأعطال، فقط إذا سمحتِ بها.** يمكنك السماح بها في شاشة التسجيل، أو لاحقًا من الملف الشخصي ثم الخصوصية، وتبقى متوقفة حتى تفعلي.
  - ما تتلقاه خدمة Firebase Crashlytics إذا تعطّل التطبيق: نوع الخطأ وموضعه في الشيفرة، وطراز الجهاز، ونظام التشغيل، وإصدار التطبيق، والذاكرة والمساحة المتاحتين، ومعرّفًا للتثبيت.
  - ما لا يُرفق أبدًا: معرّف حسابك، أو اسمك، أو رقم هاتفك.
  - إذا أوقفتِها تُحذف التقارير المنتظرة على هاتفك.
- **سجلات خادمنا.** تسجّل النتائج ورموز الأسباب، ولا تسجّل رقم هاتفك ولا رقمك القومي أبدًا، ولا تضع معرّف حسابك بجوار أي نتيجة.
- **الأساس:** مصلحتنا المشروعة في حماية الخدمة وتشغيلها، باستثناء تقارير الأعطال التي تتطلب موافقتك. [LAWYER: تأكيد جواز تشغيل App Check وML Kit قبل التسجيل على هذا الأساس، البند 10 من LAW-17]

### ٣.٨ الذكاء الاصطناعي

- **لا نستخدم بياناتك أبدًا لتدريب نماذج الذكاء الاصطناعي، لا نماذجنا ولا نماذج غيرنا.**
- يقرأ Google Cloud Vision نص بطاقتك فقط لإجراء التحقق، ولا تسمح شروط Google Cloud لـ Google باستخدام تلك البيانات لتدريب نماذجها. [LAWYER: التأكيد من شروط معالجة البيانات لدى Google Cloud]
- تستخدم مقارنة الوجه نماذج مفتوحة المصدر تعمل على خادمنا نفسه، درّبها مطوّروها قبل وجود Own Hub، ولا تُدرَّب ولا تُعدَّل بوجهك.
- لا يوجد مساعد ذكاء اصطناعي في هذا الإصدار من Own Hub. وإذا أضفناه سنطلب موافقتك المستقلة أولًا، مع تسمية مقدّم الخدمة، قبل إرسال أي شيء إليه.

### ٣.٩ الرسائل التي ترسلينها إلينا

إذا راسلتِنا نحتفظ برسالتك وعنوان بريدك الإلكتروني لنجيبك، ويُحذفان بعد [LAWYER: المدة، مثلًا سنتان] من انتهاء المراسلة.

### ٣.١٠ قائمة الانتظار وهذا الموقع

**إذا انضممتِ إلى قائمة الانتظار على هذا الموقع،** نحتفظ برقم الهاتف أو البريد الإلكتروني الذي قدّمتِه، واللغة التي اخترتِها، وموافقتك، وتاريخ انضمامك.
- نستخدم ذلك لغرض واحد: أن نراسلك مرة واحدة عند افتتاح Own Hub، ثم نحذفه.
- وإن لم يحدث ذلك، يُحذف تلقائيًا بعد 180 يومًا من انضمامك.
- ولكي نثبت موافقتك، نحتفظ مدة 3 سنوات برمز مشتق بمفتاح سري من وسيلة التواصل، وبإصدار الصياغة التي وافقتِ عليها، وبالتاريخ. [LAWYER]
- ولحماية النموذج من إساءة الاستخدام، نحتفظ برمز مشتق من عنوان الإنترنت الخاص بك (لا بالعنوان نفسه) وبعدد المحاولات الصادرة منه، ويُحذفان بعد يومين.
- وتُخزَّن هذه البيانات كلها في Google Cloud Firestore في فرانكفورت بألمانيا.

**هذا الموقع** لا يضع ملفات تعريف ارتباط، ولا يشغّل أي برمجيات، ولا يحصي الزيارات. ويتلقّى مزوّد الاستضافة [OWNER: اسم المزوّد] البيانات المعتادة التي يتلقاها أي موقع، مثل عنوان IP ونوع المتصفح، لعرض الصفحات. [OWNER: تأكيد مدة احتفاظ المزوّد بسجلاته]

## ٤. من يتعامل مع بياناتك وأين

لا نبيع بياناتك، ولا نشاركها مع المعلنين أو تجّار البيانات أو شركات التسويق. ويعالج مقدّمو الخدمات التالية أسماؤهم البيانات وفق تعليماتنا فقط. [LAWYER: تأكيد عقود المعالجة، البند LAW-08]

| مقدّم الخدمة | ما يتعامل معه | أين |
|---|---|---|
| Google Firebase Authentication | رقم هاتفك وعنوان IP وتفاصيل جهازك | الولايات المتحدة |
| مشغّل شبكة هاتفك وشركاء Google للرسائل النصية | رقم هاتفك ورمز الدخول | مصر، والمسار الذي تستخدمه Google |
| Google Cloud Firestore وCloud Functions وCloud Storage وSecret Manager | حسابك، وتدريبك ووجباتك، والمعلومات الصحية إذا فعّلتِ النسخ الاحتياطي، ونتائج التحقق، ورمز البطاقة المشفّر | فرانكفورت، ألمانيا (europe-west3) |
| Google Cloud Vision | نص بطاقتك، أثناء التحقق فقط | الاتحاد الأوروبي |
| Google Play Integrity وApple App Attest وreCAPTCHA وFirebase App Check | تأكيد أصالة التطبيق والجهاز | أنظمة Google وApple [LAWYER: الدول] |
| Google ML Kit | بيانات الجهاز والأداء (القسم ٣.٧) | أنظمة Google [LAWYER: الدول] |
| Firebase Crashlytics، فقط إذا سمحتِ بها | بيانات الأعطال (القسم ٣.٧) | الولايات المتحدة |
| [OWNER: خدمة الفيديو] | صورتك وصوتك أثناء مكالمة المراجعة، إن وُجدت | [OWNER: المنطقة] |
| [OWNER: خدمة المحادثة لتنبيهات المراجعة] | رقم الحالة ورموز الأسباب فقط | [OWNER: المنطقة] |
| [OWNER: مزوّد البريد الإلكتروني] | الرسائل التي ترسلينها إلينا | [OWNER: المنطقة] |
| [OWNER: مزوّد استضافة الموقع] | بيانات الطلبات المعتادة للموقع | [OWNER: المنطقة] |

وقد نفصح عن البيانات حيث يوجب القانون المصري ذلك، كالرد على أمر مشروع من محكمة أو جهة مختصة. وإذا انتقل Own Hub يومًا إلى ناشر آخر، فسنخبرك في التطبيق أولًا، وتبقى هذه السياسة سارية على بياناتك. [LAWYER]

## ٥. نقل البيانات خارج مصر

تُخزَّن بياناتك وتُعالَج خارج مصر:
- **في ألمانيا والاتحاد الأوروبي:** حسابك، وتدريبك ووجباتك، وأي نسخة احتياطية صحية، والتحقق.
- **في الولايات المتحدة:** رقم هاتفك، وفحوص الجهاز، وبيانات أداء ML Kit، وتقارير الأعطال إذا سمحتِ بها.
- [OWNER: دولة خدمة الفيديو إن وُجدت.]

ولا يجيز قانون حماية البيانات الشخصية المصري رقم 151 لسنة 2020 النقل إلى الخارج إلا بترخيص أو تصريح من مركز حماية البيانات الشخصية، وبموافقتك. ونطلب هذه الموافقة في شاشة التسجيل، مع تسمية هذه الدول، قبل إرسال رقم هاتفك، ثم نطلبها مرة أخرى مستقلة قبل نسخ أي معلومات صحية.

الترخيص أو التصريح: [OWNER: الرقم]. الضمانات: [LAWYER: آلية النقل، مثل شروط معالجة البيانات لدى Google والبنود التعاقدية القياسية].

## ٦. مدة الاحتفاظ

| البيانات | المدة |
|---|---|
| صور البطاقة، والصورة الذاتية، والاسم وتاريخ الميلاد من البطاقة، ورقمك القومي نفسه | لا تُخزَّن أبدًا. تُتلف من الذاكرة عند انتهاء التحقق، أيًا كانت النتيجة. |
| جلسة الصورة الذاتية ذات الاستخدام الواحد | 5 دقائق، ثم تُحذف تلقائيًا |
| نتيجة التحقق وحالة المراجعة | 180 يومًا بعد البتّ في الحالة، أو قبل ذلك إذا حذفتِ حسابك. أما الحالة التي ما زالت تنتظر المراجعة فتبقى حتى يُبتّ فيها. [LAWYER] |
| الرمز المشفّر لرقمك القومي | ما دام حسابك قائمًا. وبعد حذف حسابك يُغلق ولا يُحذف: لا يعود مرتبطًا بأي حساب، ويمنع البطاقة نفسها من فتح حساب جديد. [LAWYER: المدة، وهل يجوز لمن حذفت حسابها العودة] |
| عدد المحاولات الفاشلة لكل رمز بطاقة، وسجل التثبيت المُموَّه | 180 يومًا بعد آخر محاولة، دون ربط بحسابك. [LAWYER] |
| سجل اطّلاع المراجِعات (من فتحت أي حالة ومتى) | سنة واحدة. لا يحتوي على صورة ولا رقم هاتف ولا رقم قومي. [LAWYER] |
| حسابك، وإعداداتك، وتدريبك، ووجباتك، وأي نسخة صحية، وسجلات موافقاتك | حتى تحذفيها أو تحذفي حسابك |
| سجل تنفيذ الحذف (الحالة والتواريخ فقط) | [LAWYER: المدة]، إثباتًا لتنفيذ طلبك |
| الأعداد اليومية لعمليات التحقق، دون ربط بأي شخص | تُحفظ |
| سجلات خادمنا | [OWNER: 30 يومًا، وهي المدة الافتراضية في Cloud Logging؛ للتأكيد] |
| تقارير الأعطال، إذا سمحتِ بها | [OWNER: 90 يومًا كما تحتفظ بها Google؛ للتأكيد] |
| الرسائل التي ترسلينها إلينا | [LAWYER: المدة] |
| بيانات التواصل في قائمة الانتظار | 180 يومًا كحدّ أقصى. ويُحفظ إثبات موافقتك 3 سنوات (القسم ٣.١٠). |
| النسخ الاحتياطية لدى Google | تُزال خلال مدة الحذف الخاصة بـ Google [OWNER: للتأكيد] |

## ٧. حذف حسابك

**من التطبيق:** الملف الشخصي، ثم بياناتك، ثم حذف كل شيء. ولا يلزم أن يكون حسابك موثّقًا لتفعلي ذلك.
- يقفل خادمنا تسجيل دخولك أولًا.
- ثم يحذف حسابك والبيانات الواردة في القسم ٣، ويحذف سجل الدخول، بما فيه رقم هاتفك، في النهاية.
- ويُمسح هاتفك في الوقت نفسه.
- يستغرق ذلك عادة أقل من دقيقة، وإذا انقطع شيء يكتمل الحذف تلقائيًا خلال ساعة.

**من دون التطبيق:** استخدمي صفحة الحذف على هذا الموقع [OWNER: الرابط]، وهي تشرح كيف تطلبين الحذف بالبريد الإلكتروني. نتأكد من أن الطلب صادر عن صاحبة الرقم المسجّل على الحساب [OWNER: الطريقة، مثل رمز يُرسل برسالة نصية]، ثم نحذف خلال [LAWYER: المدة] ونؤكد لك كتابيًا.

**ما يبقى بعد الحذف، عن قصد:**
- رمز بطاقتك المشفّر بعد إغلاقه (القسم ٦)؛
- عدد المحاولات الفاشلة وسجل التثبيت حتى تنقضي مدة 180 يومًا، دون ربط بأي حساب؛
- قيود سجل اطّلاع المراجِعات على حالتك حتى تنقضي سنتها؛
- سجل تنفيذ الحذف.

أما تقارير الأعطال وبيانات ML Kit فلا ترتبط بحسابك أبدًا، وتحذفها Google وفق جدولها.

**حذف جزء من بياناتك فقط:**
- إيقاف النسخ الاحتياطي الصحي، وهو يحذف النسخة على خوادمنا؛
- حذف بيانات دورتك وحدها من إعدادات الدورة؛
- إزالة عناصر من سجل يوم، وحذف قياسات بعينها.

## ٨. حقوقك

بموجب قانون حماية البيانات الشخصية المصري رقم 151 لسنة 2020 يحق لك:

- معرفة البيانات الشخصية التي نحتفظ بها عنك، والحصول على نسخة منها؛
- تصحيحها أو استكمالها؛
- محوها؛
- سحب موافقتك في أي وقت، دون أن يتأثر ما جرى من معالجة قبل ذلك. ويمكنك بنفسك إيقاف تقارير الأعطال والنسخ الاحتياطي الصحي من الملف الشخصي ثم الخصوصية.
- الاعتراض على المعالجة أو طلب تقييدها؛
- إبلاغك بأي خرق لبياناتك الشخصية.

**الحصول على نسخة من بياناتك:**
- طريقة الطلب: من التطبيق (الملف الشخصي، ثم بياناتك، ثم اطلبي نسخة)، أو بمراسلة [OWNER: صندوق بريد الخصوصية].
- ما تحصلين عليه: ملف يقرؤه الحاسوب، وملخّص بلغتك.
- طريقة الإرسال: [LAWYER: طريقة التسليم، مثل ملف محمي بكلمة مرور يُرسل بالبريد الإلكتروني، وكلمة المرور برسالة نصية].
- أما المعلومات الصحية الموجودة على هاتفك فقط فليست لدينا، ويمكنك رؤيتها في التطبيق.

**مدة الرد:** نرد على كل طلب خلال [LAWYER: مثلًا 6 أيام عمل]، والطلبات مجانية. [LAWYER]

**الشكاوى:** إذا لم يرضك ردّنا، يمكنك تقديم شكوى إلى مركز حماية البيانات الشخصية: [LAWYER: بيانات التواصل].

## ٩. الأمان

- يجري تسجيل الدخول برمز يُرسل مرة واحدة إلى هاتفك، فلا توجد كلمة مرور يمكن سرقتها.
- تنتقل البيانات عبر اتصالات مشفّرة، وتشفّرها Google حيث تُخزَّن.
- لا تسمح قواعد الخادم لحسابك بقراءة أي بيانات سوى بياناتك، ولا يستطيع التطبيق توثيق نفسه. فخادمنا وحده يفعل ذلك.
- لا نكتب صور التحقق أبدًا على قرص أو في سجل أو في مخزن.
- المفتاح السري لرمز البطاقة محفوظ في Google Secret Manager، منفصلًا عن قاعدة البيانات.
- يقتصر الوصول إلى أنظمتنا على من يشغّلون Own Hub، ويُسجَّل كل اطّلاع على رقم هاتف لغرض المراجعة.
- لا يوجد نظام آمن تمامًا. إذا وقع خرق يمسّ بياناتك الشخصية، سنُخطر مركز حماية البيانات الشخصية خلال 72 ساعة من علمنا به، ونخبرك خلال ثلاثة أيام عمل بعد ذلك. [LAWYER]

## ١٠. ما لا يفعله Own Hub

- لا إعلانات، ولا معرّفات إعلانية، ولا تتبّع عبر تطبيقات أو مواقع أخرى.
- لا برامج تحليلات.
- لا بيع لبياناتك.
- لا تدريب للذكاء الاصطناعي على بياناتك.
- لا وصول إلى جهات اتصالك أو موقعك أو مكتبة صورك أو الميكروفون أو رسائلك النصية أو Apple Health أو Health Connect. ولا يستخدم التطبيق نفسه الميكروفون أبدًا، أما مراجعة الفيديو، إن وُجدت، فتجري عبر [OWNER: خدمة الفيديو] خارج التطبيق.
- لا شيء يخمّن جنسك أو عمرك أو أي شيء آخر عنك من وجهك.

## ١١. الأطفال

Own Hub ليس لمن هم دون الثامنة عشرة، ولا نحتفظ عن علم ببيانات أطفال. وإذا ظننتِ أن لطفل حسابًا، راسلينا وسنحذفه.

## ١٢. التعديلات على هذه السياسة

ننشر كل تعديل هنا مع تاريخه وإصداره.
- **التعديل الجوهري** يتطلب موافقتك في التطبيق قبل أن يسري عليك. والتعديل الجوهري هو ما يجمع شيئًا جديدًا، أو يستخدم بياناتك لغرض جديد، أو يضيف دولة جديدة أو نوعًا جديدًا من مقدّمي الخدمات، أو ينقص من حقوقك.
- **التعديلات الأخرى** نعلنها في التطبيق.

سجل الإصدارات:
- **3.0، [OWNER: التاريخ]:** تسجيل القبول عند التسجيل، وتقارير الأعطال بالموافقة، وبيان الذكاء الاصطناعي، ومدد الاحتفاظ كاملة، ونسخة من بياناتك عند الطلب.
- **2.0، 24 سبتمبر 2026:** الحسابات والتحقق من أن العضوية للنساء فقط.

## ١٣. اللغة

تُنشر هذه السياسة بالعربية والإنجليزية، وإذا اختلفتا فالنسخة العربية هي المعتمدة. [LAWYER]

## ١٤. التواصل

[OWNER: صندوق بريد الخصوصية] · [OWNER/LAWYER: اسم المتحكّم وعنوانه]

---

## 2. Terms of Use v3.0

**Where it goes:** this replaces the terms page in `site/_build/pages_en.py` and `pages_ar.py`. The drafting notes in today's §12 (terms:227-229) move to `config.json._draftingNotesNotPublished` and are never published.

### 2A. English

---

# Terms of Use

**Version 3.0** · Effective [OWNER: launch date] · Applies to Own Hub for iOS and Android (bundle id com.ownhub.app).

If the English and Arabic versions of these Terms differ, the Arabic version applies. [LAWYER]

## 1. Who you are agreeing with, and how

- Own Hub was founded by Rahma Mohsen. It is published and developed by [OWNER/LAWYER: Mahmoud Reda, or the company name], [LAWYER: address and registration].
- In these Terms, "we" and "us" mean that publisher, and "you" means the person using the app.
- Contact: [OWNER: support mailbox].
- **How you accept:** by tapping "Agree and send me a code" when you sign up. Before you tap, the screen links to these Terms and to the Privacy Policy. We record the version you accepted, the language, the app version and the time. If you do not accept, do not create an account. [LAWYER: click-wrap evidence under Law 15/2004]

## 2. What Own Hub is, in this version

- **A fitness app for women in Egypt.** You can follow workouts, log what you train and eat, set a weekly goal, track measurements you enter yourself, and record your menstrual cycle.
- **You need an account, and you are checked once.** You sign up with your Egyptian mobile number and a code sent by SMS. There is no password, and there is no profile that anyone else can see.
- **It is free.** There are no adverts, no in-app purchases, no subscriptions and no payments of any kind.
- **What is not in this version:** no community, no coaching and no AI assistant. Nothing in the app connects you to another person. If any of these arrives, it will come in a later version, with updated Terms that you will be asked to accept.

## 3. Who may use it, and why it is for women only

- Own Hub is made for women in Egypt, so that women can train in a space where they feel safe and their privacy is respected. [LAWYER: framing under LAW-14]
- You must be a woman aged 18 or over who holds an Egyptian national ID card.
- **How membership is confirmed:** once, when you join.
  - Your sex and age are read from your national ID number.
  - A live selfie is compared with the portrait on your card.
  - If the automatic check cannot decide, or you choose the niqab route, a woman reviewer contacts you to arrange a check with her ([OWNER: by video, or at a ladies-only gym]).
  - The photographs of your card and your face are never stored. We never guess your sex or your age from your face.
- One account per person. You may not use anyone else's identity documents, or let anyone else use your account.

## 4. Own Hub is not medical advice

Read this section even if you skip the rest.

- Own Hub is a fitness and wellbeing app. **It is not a medical device.** It does not diagnose, treat, cure or prevent any condition, and it is not a substitute for a doctor.
- Workouts, meal suggestions, calorie and macro figures, and anything the app shows about your cycle are general guidance, not prescriptions. Cycle dates are estimates.
- **Talk to a doctor before you start**, especially if any of these apply to you:
  - you are pregnant or have recently given birth;
  - you have a heart, joint, bone or blood-pressure condition, diabetes, or an eating disorder;
  - you are recovering from surgery or an injury;
  - you take medication that affects exercise.
- Stop exercising if something hurts, and get medical help if you need it. The app never penalises you for stopping or resting.
- Where the app shows guidance about severe symptoms, it is telling you to seek care, not treating you. In an emergency, contact emergency services or go to a hospital.

## 5. Allergies and food

The app refuses to say a dish is safe when it cannot tell. You are still responsible for checking what you eat. Nothing in the app replaces reading a label or asking whoever cooked it.

## 6. Your account and your data

- Your account is tied to your mobile number, so keep your phone and SIM card safe. Anyone who can unlock your phone can open the app.
- The Privacy Policy explains what we keep, where, and for how long.
- **Deleting:** you can delete your account and data at any time, from Profile, then Your data. Deletion cannot be undone.
- **A copy of your data:** ask from the same place, or by email. We send it as the Privacy Policy describes.

## 7. What you may not do

You may not:
- defeat or try to defeat the women-only check;
- use someone else's ID card or face;
- scrape the app, access it automatically, reverse engineer it, or test its security without our written permission;
- reach features that are switched off;
- redistribute the app, its exercise library or its food data as your own;
- use Own Hub for anything illegal under Egyptian law.

## 8. What you make is yours

What you log is yours, and we do not claim ownership of it. We keep a copy only to provide the service, as the Privacy Policy describes. The app's content (exercise instructions, programmes, recipes, food data, design) belongs to us or to the people who licensed it to us.

## 9. Free

The app is free. If a future version adds anything paid, it will come with its own terms, shown before anything is charged, and nothing will renew without your clear agreement.

## 10. Ending it

- **You** can stop at any time by deleting your account. Deleting the app alone does not delete your account.
- **We** may suspend or close an account that breaks section 3 or section 7. Where the law allows, we will tell you why. [LAWYER]

## 11. The app is provided as it is

We work to keep Own Hub accurate and available, but we do not promise that it is free of errors, that it will always be available, or that any particular result will follow from using it.

## 12. Later features

Community, coaching, an AI assistant and payments are not part of this version. Each will come with its own rules, published with the release that switches it on, and you will be asked to accept them before you use it.

## 13. Limits on what we owe you

To the fullest extent Egyptian law allows: [LAWYER: confirm this section survives Consumer Protection Law Art. 28]

- We are not liable for injury, illness or loss that results from exercise you chose to do, food you chose to eat, or following general guidance in the app instead of seeing a doctor.
- We are not liable for indirect or consequential loss.
- Where liability cannot be excluded, it is limited to [LAWYER: the cap].
- Nothing here excludes liability that Egyptian law does not allow us to exclude, including for death or personal injury caused by our negligence, or for fraud.

## 14. Changes to these Terms

- **Material changes:** we ask you to accept them in the app before they apply to you. If you do not accept, you can delete your account.
- **Other changes:** we publish them here with the date and tell you in the app.
- Continuing to use the app alone never counts as accepting a material change.

## 15. Law, disputes and language

- These Terms are governed by the laws of the Arab Republic of Egypt.
- Disputes go to [LAWYER: the court, for example the Economic Courts in Cairo].
- These Terms are published in Arabic and English, and the Arabic version applies if they differ. [LAWYER]
- Own Hub is offered in Egypt only.

## 16. Apple and Google

[LAWYER: Apple minimum terms]

- These Terms are between you and the publisher only, not Apple or Google. The publisher alone, not Apple, is responsible for the app and its content, its maintenance and support, any product claims, and any claim that the app infringes someone else's rights.
- Apple has no obligation to provide maintenance or support for the app.
- If the app fails to meet any warranty that applies, you may tell Apple, and Apple will refund any price you paid for it (the app is free). To the extent the law allows, Apple has no other warranty obligation for the app.
- You confirm that you are not in a country subject to a United States Government embargo, and that you are not on a United States Government list of prohibited or restricted parties.
- Apple and its subsidiaries are third-party beneficiaries of these Terms and may enforce them against you.
- Your use of the App Store or Google Play is also governed by their own terms.

## 17. The rest

- If a court finds one clause unenforceable, the rest stays in force.
- Not enforcing a clause once does not waive it.
- These Terms and the Privacy Policy are the whole agreement between us about Own Hub.
- You may not transfer your rights under these Terms. We may transfer ours if Own Hub is transferred, and if we do we will tell you first. [LAWYER]
- Own Hub uses the Rubik, La Belle Aurore and Aref Ruqaa typefaces under the SIL Open Font Licence 1.1.

## 18. Contact

[OWNER: support mailbox] · [OWNER/LAWYER: publisher name and address]

Version 3.0, [OWNER: date]: acceptance at sign-up, Arabic prevails, store terms, AI assistant listed as a later feature. Replaces version 2.0.

---

### 2B. العربية

---

# شروط الاستخدام

**الإصدار 3.0** · تاريخ السريان [OWNER: تاريخ الإطلاق] · تنطبق على تطبيق Own Hub على iOS وAndroid (معرّف الحزمة com.ownhub.app).

إذا اختلفت النسختان العربية والإنجليزية من هذه الشروط، فالنسخة العربية هي المعتمدة. [LAWYER]

## ١. مع من تتفقين، وكيف

- أسّست رحمة محسن Own Hub، ويتولّى نشره وتطويره [OWNER/LAWYER: محمود رضا، أو اسم الشركة]، [LAWYER: العنوان والقيد].
- في هذه الشروط، يُقصد بـ «نحن» ذلك الناشر، ويُقصد بـ «أنتِ» من تستخدم التطبيق.
- للتواصل: [OWNER: صندوق بريد الدعم].
- **كيف تقبلين:** بالضغط على «أوافق، أرسلوا لي الرمز» عند التسجيل. وقبل الضغط تعرض الشاشة رابطًا إلى هذه الشروط وإلى سياسة الخصوصية. ونسجّل الإصدار الذي قبلتِه، واللغة، وإصدار التطبيق، والوقت. وإذا لم تقبلي، فلا تنشئي حسابًا. [LAWYER: إثبات القبول الإلكتروني وفق القانون 15 لسنة 2004]

## ٢. ما هو Own Hub في هذا الإصدار

- **تطبيق لياقة للنساء في مصر.** يتيح لك اتّباع التمارين، وتسجيل تدريبك وطعامك، ووضع هدف أسبوعي، ومتابعة قياسات تُدخلينها بنفسك، وتسجيل دورتك الشهرية.
- **تحتاجين إلى حساب، ويجري التحقق منك مرة واحدة.** تسجّلين برقم هاتفك المحمول المصري وبرمز يُرسل برسالة نصية. لا توجد كلمة مرور، ولا ملف شخصي يراه غيرك.
- **التطبيق مجاني.** لا إعلانات، ولا مشتريات داخل التطبيق، ولا اشتراكات، ولا مدفوعات من أي نوع.
- **ما ليس في هذا الإصدار:** لا مجتمع، ولا تدريب شخصي، ولا مساعد ذكاء اصطناعي، ولا شيء في التطبيق يصلك بشخص آخر. وإذا أُضيف أي من ذلك فسيكون في إصدار لاحق، مع شروط محدّثة يُطلب منك قبولها.

## ٣. من تستطيع استخدامه، ولماذا هو للنساء فقط

- صُمّم Own Hub للنساء في مصر، لكي تتدرّب المرأة في مساحة تشعر فيها بالأمان وتُحترم فيها خصوصيتها. [LAWYER: الصياغة وفق البند LAW-14]
- يجب أن تكوني امرأة بلغت الثامنة عشرة فأكثر وتحملين بطاقة رقم قومي مصرية.
- **كيف تُؤكَّد العضوية:** مرة واحدة عند انضمامك.
  - يُقرأ جنسك وعمرك من رقمك القومي.
  - تُقارَن صورة ذاتية حية بالصورة المطبوعة على بطاقتك.
  - إذا لم يحسم التحقق الآلي حالتك، أو اخترتِ مسار النقاب، تتواصل معك مراجِعة لترتيب تحقق معها ([OWNER: بالفيديو، أو في صالة رياضية للسيدات]).
  - لا تُخزَّن صور بطاقتك ولا وجهك أبدًا، ولا نخمّن جنسك ولا عمرك من وجهك أبدًا.
- حساب واحد لكل شخص. ولا يجوز لك استخدام وثائق هوية غيرك، ولا السماح لغيرك باستخدام حسابك.

## ٤. Own Hub ليس نصيحة طبية

اقرئي هذا القسم حتى لو تجاوزتِ بقية الشروط.

- Own Hub تطبيق للياقة والعافية. **وهو ليس جهازًا طبيًا،** ولا يشخّص أي حالة ولا يعالجها ولا يشفيها ولا يقي منها، وليس بديلًا عن الطبيب.
- التمارين، واقتراحات الوجبات، وأرقام السعرات والعناصر الغذائية، وكل ما يعرضه التطبيق عن دورتك إرشادات عامة، لا وصفات علاجية. ومواعيد الدورة تقديرات.
- **استشيري الطبيب قبل البدء**، خاصةً في هذه الحالات:
  - إذا كنتِ حاملًا أو وضعتِ حديثًا؛
  - إذا كانت لديك حالة في القلب أو المفاصل أو العظام أو ضغط الدم، أو السكري، أو اضطراب في الأكل؛
  - إذا كنتِ تتعافين من جراحة أو إصابة؛
  - إذا كنتِ تتناولين دواءً يؤثر في ممارسة الرياضة.
- توقّفي عن التمرين إذا شعرتِ بألم، واطلبي المساعدة الطبية إن احتجتِ إليها. ولا يعاقبك التطبيق أبدًا على التوقف أو الراحة.
- حين يعرض التطبيق إرشادًا عن أعراض شديدة فهو يدعوك إلى طلب الرعاية، ولا يعالجك. وفي الطوارئ، اتصلي بخدمات الطوارئ أو توجّهي إلى المستشفى.

## ٥. الحساسية الغذائية والطعام

يرفض التطبيق أن يقول إن طبقًا آمن حين لا يستطيع التأكد. ومع ذلك تبقين مسؤولة عن التحقق مما تأكلينه، ولا شيء في التطبيق يغني عن قراءة الملصق أو سؤال من أعدّ الطعام.

## ٦. حسابك وبياناتك

- حسابك مرتبط برقم هاتفك المحمول، فاحرصي على هاتفك وشريحتك. ومن يستطيع فتح قفل هاتفك يستطيع فتح التطبيق.
- تشرح سياسة الخصوصية ما نحتفظ به، وأين، ولأي مدة.
- **الحذف:** يمكنك حذف حسابك وبياناتك في أي وقت من الملف الشخصي ثم بياناتك. ولا يمكن التراجع عن الحذف.
- **نسخة من بياناتك:** اطلبيها من المكان نفسه أو بالبريد الإلكتروني، ونرسلها كما تبيّن سياسة الخصوصية.

## ٧. ما لا يجوز لك فعله

لا يجوز لك:
- التحايل على التحقق من أن العضوية للنساء فقط، أو محاولة ذلك؛
- استخدام بطاقة غيرك أو وجه غيرك؛
- استخراج محتوى التطبيق آليًا، أو الوصول إليه آليًا، أو الهندسة العكسية له، أو اختبار أمانه دون إذن كتابي منا؛
- الوصول إلى الخصائص المتوقفة؛
- إعادة توزيع التطبيق أو مكتبة تمارينه أو بيانات أطعمته على أنها لك؛
- استخدام Own Hub في أي أمر يخالف القانون المصري.

## ٨. ما تصنعينه ملكك

ما تسجّلينه ملكك، ولا ندّعي ملكيته. ونحتفظ بنسخة منه فقط لتقديم الخدمة، كما تبيّن سياسة الخصوصية. أما محتوى التطبيق (تعليمات التمارين، والبرامج، والوصفات، وبيانات الأطعمة، والتصميم) فملك لنا أو لمن رخّصه لنا.

## ٩. التطبيق مجاني

التطبيق مجاني. وإذا أضاف إصدار لاحق أي شيء مدفوع، فسيأتي بشروطه الخاصة التي تُعرض عليك قبل أي خصم، ولن يتجدد شيء دون موافقتك الواضحة.

## ١٠. إنهاء الاستخدام

- **يمكنك** التوقف في أي وقت بحذف حسابك. وحذف التطبيق وحده لا يحذف حسابك.
- **يجوز لنا** إيقاف أو إغلاق حساب يخالف القسم ٣ أو القسم ٧، ونخبرك بالسبب حيث يسمح القانون. [LAWYER]

## ١١. التطبيق مقدَّم كما هو

نعمل على أن يبقى Own Hub دقيقًا ومتاحًا، لكننا لا نضمن خلوّه من الأخطاء، ولا إتاحته الدائمة، ولا تحقق نتيجة معيّنة من استخدامه.

## ١٢. الخصائص اللاحقة

المجتمع، والتدريب الشخصي، ومساعد الذكاء الاصطناعي، والمدفوعات ليست جزءًا من هذا الإصدار. ولكل منها قواعده التي تُنشر مع الإصدار الذي يفعّله، ويُطلب منك قبولها قبل استخدامه.

## ١٣. حدود مسؤوليتنا

في أقصى حدود ما يسمح به القانون المصري: [LAWYER: التأكد من صمود هذا القسم أمام المادة 28 من قانون حماية المستهلك]

- لا نتحمّل المسؤولية عن إصابة أو مرض أو خسارة تنتج عن تمرين اخترتِ أداءه، أو طعام اخترتِ تناوله، أو اتّباع إرشادات عامة في التطبيق بدلًا من مراجعة الطبيب.
- لا نتحمّل المسؤولية عن الخسائر غير المباشرة أو التبعية.
- وحيث لا يجوز استبعاد المسؤولية، فإنها تقتصر على [LAWYER: الحد الأقصى].
- لا يستبعد شيء هنا مسؤولية لا يجيز القانون المصري استبعادها، بما في ذلك الوفاة أو الإصابة الشخصية الناتجة عن إهمالنا، أو الاحتيال.

## ١٤. التعديلات على هذه الشروط

- **التعديلات الجوهرية:** نطلب منك قبولها في التطبيق قبل أن تسري عليك. وإذا لم تقبليها، يمكنك حذف حسابك.
- **التعديلات الأخرى:** ننشرها هنا مع تاريخها ونخبرك بها في التطبيق.
- ولا يُعدّ استمرارك في استخدام التطبيق وحده قبولًا لتعديل جوهري.

## ١٥. القانون والنزاعات واللغة

- تخضع هذه الشروط لقوانين جمهورية مصر العربية.
- تُعرض النزاعات على [LAWYER: المحكمة المختصة، مثل المحاكم الاقتصادية بالقاهرة].
- تُنشر هذه الشروط بالعربية والإنجليزية، والنسخة العربية هي المعتمدة عند الاختلاف. [LAWYER]
- يُتاح Own Hub في مصر فقط.

## ١٦. Apple وGoogle

[LAWYER: الحد الأدنى من شروط Apple]

- هذه الشروط بينك وبين الناشر فقط، لا Apple ولا Google. والناشر وحده، لا Apple، مسؤول عن التطبيق ومحتواه، وعن صيانته ودعمه، وعن أي مطالبات تتعلق به، وعن أي ادعاء بأن التطبيق يتعدّى على حقوق غيره.
- لا تلتزم Apple بتقديم أي صيانة أو دعم للتطبيق.
- إذا لم يفِ التطبيق بأي ضمان منطبق، يمكنك إبلاغ Apple، وتردّ إليك Apple أي ثمن دفعتِه مقابله (والتطبيق مجاني). وفي حدود ما يسمح به القانون، لا تتحمّل Apple أي التزام آخر بالضمان تجاه التطبيق.
- تؤكدين أنك لستِ في دولة خاضعة لحظر من حكومة الولايات المتحدة، وأنك لستِ مدرجة على أي قائمة لحكومة الولايات المتحدة للأطراف المحظورة أو المقيّدة.
- تُعدّ Apple وشركاتها التابعة مستفيدة من هذه الشروط بصفتها طرفًا ثالثًا، ويحق لها إنفاذها في مواجهتك.
- ويخضع استخدامك لمتجر App Store أو Google Play أيضًا لشروطهما الخاصة.

## ١٧. أحكام عامة

- إذا قضت محكمة بعدم نفاذ بند، تبقى بقية البنود سارية.
- عدم إنفاذ بند مرة لا يعني التنازل عنه.
- هذه الشروط مع سياسة الخصوصية هي الاتفاق الكامل بيننا بشأن Own Hub.
- لا يجوز لك نقل حقوقك بموجب هذه الشروط. ويجوز لنا نقل حقوقنا إذا انتقل Own Hub إلى غيرنا، وسنخبرك بذلك أولًا. [LAWYER]
- يستخدم Own Hub الخطوط Rubik وLa Belle Aurore وعارف رقعة بموجب رخصة SIL Open Font Licence 1.1.

## ١٨. التواصل

[OWNER: صندوق بريد الدعم] · [OWNER/LAWYER: اسم الناشر وعنوانه]

الإصدار 3.0، [OWNER: التاريخ]: القبول عند التسجيل، واعتماد النسخة العربية، وشروط المتاجر، وإدراج مساعد الذكاء الاصطناعي ضمن الخصائص اللاحقة. يحلّ محل الإصدار 2.0.

---

## 3. In-app consent design

### 3.1 Terms and Privacy acceptance on C06, in one step with no new screen

The value-first order stays: Welcome > O03 > O05 > **C06** > C07 > C09b > ID > selfie > C12 > C13. O03 and O05 never count as consent.

**C06 layout, top to bottom:**
1. The title and the number field stay as they are.
2. A new line under the field: the transfer notice.
3. A new optional row: the crash-reports checkbox, unticked.
4. The primary button, with a new label.
5. The new acceptance line, with two tappable links.

| Element | EN | AR |
|---|---|---|
| Transfer line | To send your code, your number goes to Google Firebase in the United States. Your account and training are kept by Google Cloud in Frankfurt, Germany. | لإرسال الرمز يُنقل رقمكِ إلى Google Firebase في الولايات المتحدة، ويُحفظ حسابكِ وتدريبكِ لدى Google Cloud في فرانكفورت بألمانيا. |
| Crash row title | Send crash reports | إرسال تقارير الأعطال |
| Crash row subtitle | Optional. Helps us fix the app. No name, number or account is attached. You can change this in Privacy. | اختياري. يساعدنا في إصلاح التطبيق، ولا يُرفق به اسم ولا رقم ولا حساب. يمكنكِ تغييره من الخصوصية. |
| Button | Agree and send me a code | أوافق، أرسلوا لي الرمز |
| Acceptance line | By tapping Agree and send me a code, you accept the Terms of Use and the Privacy Policy. | بالضغط على «أوافق، أرسلوا لي الرمز» تقبلين شروط الاستخدام وسياسة الخصوصية. |

**Links:** the two links open `LegalLinks.terms` and `LegalLinks.privacyPolicy`, localised by `LegalLinks.localised(url, locale)`, which inserts `/ar/` for Arabic. They open in the browser, and the number she typed is kept.

**Taps:** the tap count stays the same. Her one tap is both the acceptance and the send. The crash box is optional, so it adds no required tap.

**Flow:**
1. On the tap, before `sendCode`:
   - write a pending acceptance to SharedPreferences `own_hub.legal_pending = {t:3, p:3, locale, acceptedAtMs}`;
   - write `own_hub.crash_reports_allowed = <checkbox>`;
   - apply the crash choice immediately (section 3.2).
2. When C07 accepts the code, the app calls a new callable `record_legal_acceptance {termsVersion, privacyVersion, locale, appVersion, platform, acceptedAtMs}`.
3. The server checks that the versions equal `TERMS_VERSION` and `PRIVACY_VERSION`, that locale is `en` or `ar`, and that appVersion matches `^[0-9.+]{1,32}$`.
4. The server writes `users/{uid}/consents/legal-t3-p3 = {termsVersion, privacyVersion, locale, appVersion, platform, clientAcceptedAt, at: SERVER_TIMESTAMP}`. Writing it twice does nothing. Rules are unchanged: clients can get and list consents, and cannot write them.
5. **Router gate `legalAccepted`**, placed before C09b and checked on every launch for signed-in users:
   - if a pending acceptance exists, flush it;
   - otherwise, if the server document for the current versions is missing, show the **Legal update sheet**.

**Re-prompt when a material version rises** (`TERMS_VERSION` or `PRIVACY_VERSION` goes up):
- The blocking sheet reads:
  - EN: "We have updated our Terms and Privacy Policy" / AR: «حدّثنا شروط الاستخدام وسياسة الخصوصية».
  - It shows up to 3 bundled "what changed" lines and the two links.
- Primary button: "Agree and continue" / «أوافق وأتابع».
- Secondary button: "Delete my account instead" / «أفضّل حذف حسابي», which opens Your data.
- Non-material edits change only the document number (3.0 to 3.1) and are announced with a one-time notice. They do not bump the ints.

**What this step does not cover:** the C09b capture consent, the health-backup consent and the review consent stay separate, each with its own record.

### 3.2 Granular consent for crash reports and analytics, nothing before consent

**Crash reports:**
- `crashCollectionFor({required bool release, required bool allowed}) => release && allowed`.
- At boot:
  - if not allowed, call `setCrashlyticsCollectionEnabled(false)` and `deleteUnsentReports()`;
  - `CrashReports.flutterError/uncaught` return early unless allowed.
- The native defaults stay off (`Info.plist:72-73`, `AndroidManifest.xml:84-86`). This is on the must-protect list.
- Privacy centre switch, a new row in `privacy_view.dart`:

| | EN | AR |
|---|---|---|
| Title | Crash reports | تقارير الأعطال |
| Subtitle when on | On. If the app crashes, the error and your phone model are sent to Firebase. Nothing about you is attached. | مفعّلة. إذا تعطّل التطبيق يُرسل الخطأ وطراز هاتفكِ إلى Firebase، دون أي شيء عنكِ. |
| Subtitle when off | Off. Nothing is sent when the app crashes. | متوقفة. لا يُرسل شيء إذا تعطّل التطبيق. |

  Turning it off calls `deleteUnsentReports()`.
- `ThisPhoneWipe` resets the setting to off.

**Analytics:**
- The release sink stays `NullAnalyticsSink`.
- Add a test asserting that a release `main()` wires no sink.
- If a real sink ever ships (LATER), it needs:
  - its own switch, "Help improve Own Hub", off by default;
  - App Store "Product Interaction" and Play "App activity" labels;
  - privacy §3.7 and §10 updated;
  - a material-change re-prompt.

**App Check and Firebase Installations** run from first launch on a security basis, disclosed in §3.7. [LAWYER] If counsel says no, defer `FirebaseBoot.start()` for fresh installs until the C06 tap (LATER).

### 3.3 Health and ID consent: kept, with corrected wording

**C09b (capture consent)**
- Rewrite the bullets, then bump `CONSENT_VERSION` (`config.py:634`) and `kCaptureConsentVersion` (`capture_consent.dart:47`) to **2** together.
- `record_consent` additionally stores `locale` and `appVersion`. Update the "three fields" docstring in `store.py:532` and the spec note.
- Women already verified under v1 are not asked again. A woman mid-flow on v1 sees v2 at the gate.

| # | EN | AR |
|---|---|---|
| 1 | Your photos go to our server in Frankfurt, Germany. Google Cloud Vision reads the text on the card in the European Union. | تُرسل صوركِ إلى خادمنا في فرانكفورت بألمانيا، ويقرأ Google Cloud Vision نص البطاقة داخل الاتحاد الأوروبي. |
| 2 | Your face is matched on our own server. No outside face service sees it. | تجري مطابقة وجهكِ على خادمنا نفسه، ولا تطّلع عليه أي خدمة خارجية للتعرّف على الوجوه. |
| 3 | No photo is ever stored. Both sides of the card and the selfie are deleted from memory when the check ends, whatever the result. | لا تُخزَّن أي صورة أبدًا. يُحذف وجها البطاقة والصورة الذاتية من الذاكرة فور انتهاء التحقق، أيًا كانت النتيجة. |
| 4 | We keep the result and its reasons for 180 days, and a keyed code of your ID number so one card opens one account. The code cannot be turned back into your number. | نحتفظ بالنتيجة وأسبابها 180 يومًا، وبرمز مشفّر من رقمكِ القومي حتى لا تفتح البطاقة الواحدة أكثر من حساب. ولا يمكن تحويل الرمز إلى رقمكِ. |
| 5 | If the check cannot decide, you can ask a woman from Own Hub to check you instead. | إذا تعذّر حسم التحقق، يمكنكِ أن تطلبي أن تتحقق منكِ امرأة من Own Hub. |
| 6 | The camera is the only way in. You cannot choose a picture you already have. (unchanged) | الكاميرا هي الطريقة الوحيدة. لا يمكنكِ اختيار صورة محفوظة لديكِ. |
| link | Read the Privacy Policy | اقرئي سياسة الخصوصية |

- The "90 seconds" bullet at `consent_view.dart:220` changes to the line in section 5, row 10.

**Health backup sheet:** the text stays as it is, so `health-v1` holds. The rules hard-code that doc id. Add a "Read the Privacy Policy" link under it; that does not change the consent wording.

**Review consent (`review-v1`):** unchanged.

### 3.4 Prominent disclosure for the camera

- **C09b is the prominent disclosure.** It is shown before the OS camera prompt, and the prompt is triggered only after the server records consent (`app_router.dart:418-422`). Android has no purpose string, so C09b alone satisfies Google's rule.
- **iOS purpose string:** update `ios/Runner/Info.plist:27`, `en.lproj/InfoPlist.strings` and `ar.lproj/InfoPlist.strings`.
  - EN: "Own Hub uses the camera to photograph both sides of your ID card and take one selfie, so we can check that you are a woman. Nothing is uploaded until you tap send. The photographs are read in memory and never stored."
  - AR: «يستخدم Own Hub الكاميرا لتصوير وجهي بطاقتكِ الشخصية والتقاط صورة ذاتية واحدة، للتحقق من أنكِ امرأة. لا يُرفع شيء قبل أن تضغطي إرسال، وتُقرأ الصور في الذاكرة ولا تُخزَّن أبدًا.»
- C10, C10b and C11 keep the visible live-camera state.

---

## 4. Data export and deletion

### 4.1 Export

**MUST now: the interim route by email**
- The Your data sheet (`your_data_sheet.dart:150-152`) replaces "not built yet" with a body line and a button. The button opens a mailto to the privacy mailbox. Subject: "Copy of my Own Hub data". The body asks only for the phone number on the account.
  - EN body: "Want a copy of your data? Ask us and we will send it within {window}." Button: "Ask for a copy".
  - AR body: «تريدين نسخة من بياناتكِ؟ اطلبيها وسنرسلها خلال {window}.» Button: «اطلبي نسخة».
- **Identity check:** the same method as web deletion (section 4.2). [OWNER]
- **Internal tool:** `functions/tools/export_user.py <uid>` is driven by `deletion_manifest.json`. It writes `ownhub-data-<date>.json` plus `summary-<lang>.html`.
- **Delivery:** a password-protected ZIP by email, with the password sent by SMS. [LAWYER: confirm that an emailed copy meets Art. 2]
- **Test:** `functions/tests/test_export_user.py` asserts that every manifest row is either exported or listed in `EXPORT_EXCLUSIONS` with a reason.

**What the export contains, by manifest row:**

| Section | Source | Notes |
|---|---|---|
| account | Auth record (phone, created, last sign-in), uid | |
| settings and setup | `users/{uid}` profile, privacy, notify | |
| agreements | `users/{uid}/consents/*` (legal, verification, health, review) | |
| verification | `users/{uid}.verification`, `verificationJobs` and `verification_flags` where uid | Reason codes are explained in plain words [LAWYER: whether reason codes must be disclosed] |
| identity code | `nidRegistry` entry: state only (active or closed) | The hash value is not exported [LAWYER] |
| fraud signals | `verificationBehaviour` (failure count for her HMAC) | `verificationInstalls` only if she supplies her install id; in-app export does this automatically |
| review access | `verificationReviewAccess` entries for her flag ids: date and action | Reviewer shown as "a reviewer" [LAWYER] |
| attempts | `verificationLedger/{uid}` attempt counts | |
| training | sessions, weeks, bests, awards, splits, firstWeek, notices | |
| food | meals, eatPrefs, mealPlans | |
| health (cloud) | checkins, measurements, cycle, periods, profile lifeStage and allergies | Only if backup was on |
| health (phone only) | Local snapshot | In-app export only. The email export says these are on her phone. |
| excluded | syncQueue, Storage prefixes (empty at launch), `deletionRequests`, `verificationStats`, Crashlytics, ML Kit | Reason given for each |

**Format:**
- JSON, UTF-8, ISO-8601 dates.
- Top-level `{"schema":"ownhub.export/1","generatedAt":…,"language":…,"sections":{…}}`.
- Keys are in English. `labels_ar` is included for the Arabic summary.
- Each section carries `source` (manifest row numbers) and `retention` text copied from privacy §6.
- The readable `summary-en.html` or `summary-ar.html` (RTL, no scripts) lists each section in plain words.

**LATER: the in-app export**
- **Path:** Profile > Your data > "Download my data" / «نزّلي بياناتي».
- **Server:**
  - Callable `export_account` (App Check enforced, verified or unverified) reuses the export_user builder.
  - At 8 MB or under, it returns inline.
  - Over 8 MB, it writes to `user-exports/{uid}/` (already deletion row 25 and in `STORAGE_PREFIXES`) and returns a signed URL valid for 1 hour, with a bucket lifecycle delete after 1 day.
- **Client:** merges the local snapshot (`app_snapshot.dart`, phone-only health, life stage, allergies, cycle), builds the JSON and the summary in her locale, and opens the OS share sheet.
  - New dependency: `share_plus`, which ships its own privacy manifest. Check the required-reason APIs.
  - Nothing is emailed.
- **Tests:**
  - every manifest row is exported or excluded (Dart and Python);
  - the export includes local-only health while backup is off;
  - the export contains no other uid.

### 4.2 Deletion

**In the app.** It is in place and must stay working. MUST fixes:
- **One timing line**, replacing `arb:2747`'s "It happens at once" and aligning 3135 and 3138:
  - EN: "Deleting usually takes under a minute. If it is interrupted, it finishes on its own within the hour, and none of it can be brought back."
  - AR: «يستغرق الحذف عادة أقل من دقيقة، وإذا انقطع يكتمل تلقائيًا خلال ساعة، ولا يمكن استعادة شيء منه.»
- **Show the web route:** fill `LegalLinks.deleteAccount` so `your_data_sheet.dart:72` shows the web link.
- **Name what stays:** the sheet's "kept on purpose" list adds the 180-day fraud signals and the access log, matching privacy §7.
- **Fix the Play path:** `play-data-safety.txt:14` path becomes "Profile > Your data > Delete everything".
- **Manifest rows for the TTL collections:**
  - add rows 42 `verificationBehaviour/{idHmac}`, 43 `verificationInstalls/{hash}` and 44 `verificationReviewAccess where flagId in her flags`, with a new method `ttl`;
  - update `deletion_manifest.json`, `app/lib/features/account/domain/deletion_manifest.dart`, the `deletion.py` docstring and the manifest-vs-rules gap test.
- **Clear new local keys:** `ThisPhoneWipe` also clears `own_hub.legal_pending` and `own_hub.crash_reports_allowed`.
- **Meals and eat preferences:**
  - Keep `meals` and `eatPrefs` delete as `false`, since correction is by rewrite. Verify on a device that removing an item from a day works.
  - Change the delete-page line to "You can remove items from a day's log and delete individual measurements."
  - Ramadan mode: stop syncing it (M10).

**On the web, MUST now:**
- Fill the reply window in `site/delete-account`.
- Replace "we will phone that number" with: "We send a one-time code by SMS to the number on the account. Reply to our email with the code, and we delete within {window}." [OWNER: an SMS route; LAWYER: the method]
- The email goes to the role mailbox.

**On the web, LATER:** a self-serve page at `/delete-account/start`, with its own scoped CSP allowing Firebase JS. It uses Firebase phone sign-in and then the existing `delete_account` callable. The main site keeps `default-src 'none'`.

---

## 5. Claims cleanup

String changes go through `app/tool/add_strings.py`. The getter name comes from the English text, so a rewrite means:
1. add the new string;
2. switch the call site;
3. remove the old key from the `6-v2/i18n` source.

| # | Where | Today | Fix (EN / AR) |
|---|---|---|---|
| 1 | `site/index.html:57` (pages_en/ar) | "or by a woman reviewer on a short video call" | "or, if the check cannot decide, by a woman from Own Hub who contacts you to arrange it." / «أو، إذا تعذّر حسم التحقق، عبر امرأة من Own Hub تتواصل معكِ لترتيبه.» |
| 2 | `site/index.html` "One permission" card | "No photo library, no microphone, no location, no health data." | "No photo library, no microphone, no location, no access to Apple Health or Health Connect." / «لا مكتبة صور، ولا ميكروفون، ولا موقع، ولا وصول إلى Apple Health أو Health Connect.» |
| 3 | site index, privacy "short version", privacy 3.4 | "Only you can read them." | "No other member can see them." / «ولا تستطيع أي عضوة أخرى رؤيتها.» [LAWYER: disclose admin access in §9] |
| 4 | privacy §5 (privacy:313) | "We ask for that consent … before your data leaves your phone" | True only once M1 ships. Publish the v3 text and M1 together. |
| 5 | privacy short version | "use no advertising or analytics tools" | "No adverts, no tracking, no analytics. Crash reports only if you allow them." (v3 text) |
| 6 | privacy §3.3 and §4 | the video vendor placeholder | The v3 text with the [OWNER] route choice, or the routes removed |
| 7 | privacy §6 | access log "kept as an audit trail"; behaviour and installs missing | The v3 §6 table (needs M9 TTLs) |
| 8 | privacy §10 (privacy:410) "No access to … microphone" vs a video review | | The v3 §10 line: the app never uses the microphone; video happens in [service] outside the app |
| 9 | `privacy:46`, `terms:46`, `delete-account` banners; `terms:227-229` drafting notes | "Draft pending review…" plus owner notes | Remove the banners after counsel sign-off. Move the notes to `_draftingNotesNotPublished`. |
| 10 | `arb:679` `itTakesAbout90Seconds` (C09, C09b) | "It takes about 90 seconds." | "Usually a couple of minutes. If a woman needs to check, up to 3 days." / «عادةً دقيقتان تقريبًا، وإذا احتاجت امرأة إلى التحقق فقد يستغرق ذلك حتى 3 أيام.» |
| 11 | `arb:2830` C09b | "nothing is kept except a one way keyed hash" | Section 3.3, bullet 4 |
| 12 | `arb:2854` C09b | "servers outside Egypt" | Section 3.3, bullet 1 |
| 13 | `arb:2853` C09b | "a short video call with you" | Section 3.3, bullet 5 |
| 14 | `arb:453` `bothImagesAreDeletedAfterTheCheck` (why_we_check_view:91) | "We keep the result, nothing else." | "Both images are deleted after the check. We keep the result and a keyed code of your ID number." / «تُحذف الصورتان بعد التحقق، ونحتفظ بالنتيجة وبرمز مشفّر من رقمكِ القومي.» |
| 15 | `yourIdAndSelfieWereDeletedAfter` (privacy_view:412) | "Only the result is kept." | "Your ID and selfie were deleted after the check. We keep the result and a keyed code of your ID number." / «حُذفت بطاقتكِ وصورتكِ الذاتية بعد التحقق، ونحتفظ بالنتيجة وبرمز مشفّر من رقمكِ القومي.» |
| 16 | `arb:1139` (woman_reviewer_view:150) | "Two minutes with a woman reviewer. Nothing is recorded or kept." | "A woman reviewer checks your card with you. Nothing is recorded. She keeps only her decision and the date." / «تتحقق مراجِعة من بطاقتكِ معكِ. لا يُسجَّل شيء، ولا تحتفظ إلا بقرارها وتاريخه.» |
| 17 | `askForAVideoCheck`, `aShortVideoCheck` (C15) | "Ask for a video check" | Until the vendor is decided: "Ask a woman to check me" / «اطلبي أن تتحقق منكِ امرأة». Title: "A check with a woman" / «تحقق مع امرأة». |
| 18 | `arb:383` safety centre | "A woman on the team, 9am to 9pm" | "Email us. Read Sunday to Thursday, 9:00 to 17:00 Cairo time." / «راسلينا. نقرأ الرسائل من الأحد إلى الخميس، من 9:00 إلى 17:00 بتوقيت القاهرة.» |
| 19 | `arb:912` | "Cleared for postpartum from week six, with your doctor's go-ahead." | "Rebuilt around the pelvic floor first. For after a birth, only once your doctor has cleared you to exercise." / «مبنيّ أولًا حول عضلات قاع الحوض. وبعد الولادة، فقط بعد أن يأذن لكِ طبيبكِ بممارسة الرياضة.» |
| 20 | `arb:2730` | "Downloading … not built yet, so there is no button" | The interim copy in section 4.1 |
| 21 | `arb:2747`, `3135`, `3138` | three different timings | The single line in section 4.2 |
| 22 | `arb:3173` C06 | "By joining you agree to the Own Hub rules." | Replaced by the click-wrap in section 3.1 |
| 23 | `weTextYouASixDigitCode` | "We never show your number to anyone." | "We text you a six-digit code. No other member ever sees your number." / «نرسل إليكِ رمزًا من ستة أرقام، ولا ترى أي عضوة أخرى رقمكِ أبدًا.» |
| 24 | `yourPhoneNumberIsUsedOnlyTo` (C15) | "used only to arrange this call" | "Your phone number is used only to arrange your check." / «يُستخدم رقم هاتفكِ فقط لترتيب التحقق.» |
| 25 | `Info.plist:27` plus `en.lproj` and `ar.lproj` | "deleted after the check" | Section 3.4 |
| 26 | `PrivacyInfo.xcprivacy` comment | "six Firebase packages" | Fix the count after M12 |
| 27 | `play-data-safety.txt:14,16,73` | wrong path; "Name" missing; audio | Section 7 |
| 28 | Terms §1 and §14 | browse-wrap, "continuing to use… means you accept" | Terms v3 §1 and §14 |
| 29 | Terms §3, support page, site index | "a woman reviewer phones you to arrange a short video check" | "a woman reviewer contacts you to arrange a check with her" plus the [OWNER] route |
| 30 | Terms §6 and the support page "no export" | | "Ask for a copy" text |
| 31 | `site/delete-account` "we will phone that number"; "delete individual … meals" | | Section 4.2 |
| 32 | `thePhotographsAreProcessedByGoogleCloud` (names AWS, unused) | | Delete the key (LATER, as hygiene) |
| 33 | `onlyWomenReviewTheseChecksNoMan` | "No man ever sees your face, your card or your name." | Keep. No image, card or name exists in any record. [LAWYER: male admin console access, LAW-15] |
| 34 | **New disclaimer** (APL-12) | missing | EN: "Own Hub is a fitness and wellbeing app. It is not a medical device and does not diagnose, treat, cure or prevent any condition. Check with your doctor before you start, especially if you are pregnant or have recently given birth." AR: «Own Hub تطبيق للياقة والعافية، وليس جهازًا طبيًا، ولا يشخّص أي حالة ولا يعالجها ولا يشفيها ولا يقي منها. استشيري طبيبكِ قبل البدء، خاصةً إذا كنتِ حاملًا أو وضعتِ حديثًا.» Show it on the Profile footer (About), `cycle_hub_view.dart`, `cycle_setup_view.dart`, `life_stage_view.dart`, and `schedule_view.dart` when pregnant or postpartum is selected (inline, no extra step). |

**Store listing draft (EN/AR), first lines, for GPL-07 and APL-12:**
- EN: "Own Hub is a fitness app for women in Egypt aged 18 and over. Membership is women only and is confirmed once with your Egyptian national ID and a live selfie; the photos are never stored. Own Hub is not a medical device and does not diagnose, treat, cure or prevent any condition. Consult a healthcare professional before starting."
- AR: «Own Hub تطبيق لياقة للنساء في مصر ممن بلغن الثامنة عشرة فأكثر. العضوية للنساء فقط، وتُؤكَّد مرة واحدة ببطاقة الرقم القومي المصرية وصورة ذاتية حية، ولا تُخزَّن الصور أبدًا. Own Hub ليس جهازًا طبيًا، ولا يشخّص أي حالة ولا يعالجها ولا يشفيها ولا يقي منها. استشيري مختصًا في الرعاية الصحية قبل البدء.»
- Do not use "#1", "best", outcome promises, "accurate cycle predictions", or screenshots of off features.

---

## 6. Implementation list

### MUST: code, in order (about 5 days, alongside the owner track)

**M1. Terms and Privacy acceptance (OWN-03, LAW-03, LAW-11)**
- `functions/identity/config.py`: `TERMS_VERSION = 3`, `PRIVACY_VERSION = 3`, `LEGAL_LOCALES = ("en","ar")`.
- `functions/identity/store.py`: `write_legal_acceptance()`, `has_legal_acceptance()`.
- `functions/main.py`: the `record_legal_acceptance` callable (App Check, auth required, validation, idempotent).
- `functions/tests/test_legal_acceptance.py`: wrong version refused, bad locale refused, idempotent, fields allow-listed.
- `app/lib/features/signup/domain/legal_acceptance.dart` (new): `kTermsVersion`, `kPrivacyVersion`, `PendingLegalAcceptance` store, callable client, and `kAppVersion` from `String.fromEnvironment('APP_VERSION')`. Set it in `app/tool/build_release.sh`.
- `app/lib/features/signup/presentation/phone_number_view.dart:105-155`: new footer, links, crash checkbox, button label, and the pending write before `sendCode`.
- `app/lib/routing/app_router.dart`: flush after C07, the `legalAccepted` gate before C09b and at launch.
- `app/lib/features/account/presentation/legal_update_sheet.dart` (new).
- `app/lib/config/legal_links.dart`: `localised()`.
- Tests:
  - `test/features/signup/legal_acceptance_test.dart` (no SMS before the tap; pending flushed; a version bump re-prompts);
  - update `test/journeys/value_first_signup_test.dart`.
- Release check: `kTermsVersion == TERMS_VERSION` in `release_preflight.sh`.

**M2. Legal links reachable (OWN-01, OWN-02, APL-02)**
- Fill the 4 URLs in `legal_links.dart` once the domain is live.
- `main.dart`: `assert`, plus a release-mode `StateError` if `!LegalLinks.allSet`. Keep the hide-when-empty guard.
- Add links on C09b (`consent_view.dart`), the health sheet (`privacy_view.dart:154-165`) and Your data.
- The support row at `app_router.dart:2312` lights up once the URL is set.

**M3. Crash reports by consent (OWN-04)**
- `app/lib/app_state/crash_consent.dart` (new).
- `firebase_boot.dart:106,146-153`.
- `crash_reports.dart` guard.
- `privacy_view.dart` switch.
- `account_data.dart` wipe.
- `test/release/crash_consent_test.dart`.

**M4. C09b rewrite plus version 2 (APL-06, LAW-02)**
- Strings via `add_strings.py`.
- `consent_view.dart:200-275`.
- `capture_consent.dart:47` set to 2.
- `config.py:634` set to 2.
- `store.write_consent` and `main.record_consent` gain locale and appVersion.
- Update `signup_consent_test`, `test_verify_gate.py` and any test pinning v1.

**M5. Info.plist purpose strings (Claims #25)**
- `ios/Runner/Info.plist:27`, `ios/Runner/en.lproj/InfoPlist.strings`, `ios/Runner/ar.lproj/InfoPlist.strings`.

**M6. Medical disclaimer (APL-12)**
- One string pair.
- Placements: profile view footer, `cycle_hub_view.dart`, `cycle_setup_view.dart`, `life_stage_view.dart`, `schedule_view.dart`.
- Test: `grep "medical device"` finds it in both ARBs and in widget tests.

**M7. Copy truth (OWN-08)**
- Claims rows 1 to 31 across `app_en.arb`/`app_ar.arb` (through `add_strings.py`), `safety_centre_view.dart:263`, `woman_reviewer_view.dart`, `why_we_check_view.dart:91-95` and `your_data_sheet.dart`.

**M8. Interim export (OWN-05)**
- `your_data_sheet.dart:150-152` mailto button.
- `functions/tools/export_user.py` plus `functions/tests/test_export_user.py`.

**M9. Retention TTLs (LAW-07)**
- `store.py` `record_failure` and `record_attempt`: add `expireAt = now + 180d` on every write.
- `FirestoreReviewStore.log_access`: `expireAt = now + 365d`.
- New `config.SIGNAL_RETENTION_DAYS = 180` and `ACCESS_LOG_RETENTION_DAYS = 365`, both marked PENDING COUNSEL.
- Extend `functions/tests/test_ttl_fields.py`.
- Deletion manifest rows 42 to 44 (section 4.2).
- Ops: enable the Firestore TTL policies on `verificationBehaviour.expireAt`, `verificationInstalls.expireAt` and `verificationReviewAccess.expireAt`, and add the gcloud commands to `firebase/ops`.

**M10. Ramadan setting stays on the device**
- `app/lib/app_state/cloud_documents.dart`: drop `ramadanMode` from the eatPrefs push. The rules may keep allowing the key.
- Test that the push payload omits it. [LAWYER may later allow it with health consent]

**M11. Waitlist consent proof (LAW-09)**
- `functions/waitlist/join.py:76`: also write `waitlistConsentProof/{hmac(contact)}` `{wordingVersion, lang, at, expireAt: +3y}`.
- Rules: deny all.
- Extend `test_waitlist.py`.

**M12. Privacy declarations (APL-04, GPL-04)**
- `ios/Runner/PrivacyInfo.xcprivacy:57-140` per section 7.
- `android/play-data-safety.txt` per section 7.
- Then Xcode Archive > Generate Privacy Report and compare.

**M13. Reviewer access path (APL-03)**
- `functions/identity/config.py`: `SECRET_REVIEWER_UIDS = "store-reviewer-uids"`.
- `main.start_verification` / `verify_identity`: if the uid is in the secret, mint the verified claim and write the user verification plus an audit log entry `reviewerBypass`. No client change.
- `functions/tests/test_reviewer_access.py`: only listed uids pass, the bypass is logged, and an empty secret means no bypass.

**M14. Site rebuild (OWN-01, 02, 06, LAW-11)**
- `site/_build/pages_en.py` and `pages_ar.py`: privacy and terms v3 from sections 1 and 2, the delete-account and support changes, index rows 1 to 3.
- `site/config.json`: real `baseUrl`, mailboxes, new keys (`hostingProvider`, `chatService`, `deletionVerifyMethod`, `supportRetention`).
- `build.py`: wrap Latin runs in `<bdi>` on the AR pages.
- `functions/tests/test_site_build.py`: no `class="todo"`, no "Draft pending", no `مسودة بانتظار`, no `بانتظار الاستكمال` in a release build.

**M15. Preflight extension (OWN-11)**
- `app/tool/release_preflight.sh`: FAIL on any of these:
  - the AR marker or `class="todo"` in `site/`;
  - `NSPrivacyCollectedDataTypeHealthFitness` present;
  - `kCaptureConsentVersion != CONSENT_VERSION`;
  - `kTermsVersion != TERMS_VERSION`;
  - `LegalLinks` empty.

**M16. Flag webhook disclosure**
- Name the chat provider in privacy §4 ([OWNER]).
- Or, if the owner prefers, set `FLAG_WEBHOOK_REQUIRED=False` and drop it. The alert policy then relies on Cloud Monitoring on the `flag_raised` log.

### LATER

- In-app export (`export_account` plus client assembly plus `share_plus`).
- Self-serve web deletion page.
- Defer App Check and Firebase init until C06 for fresh installs, if counsel requires.
- An analytics consent switch, if a sink ever ships.
- Health consent v2 wording (no AI, no ads), with a rules migration away from the hard-coded `health-v1`.
- Video vendor integration (DPA, region, §4 and §10, labels).
- Assistant (APL-18): Vertex AI in europe-west3 on a paid account with zero data retention, a separate opt-in naming Google, and stripping the allergies and `avoid` fields from `assistant_wire.dart` or covering them by health consent.
- Delete the stale AWS string.
- Retire `privacy.policyVersion` in `users/{uid}`.
- Manifest rows for the community and coach data.

### OWNER ACTIONS (the critical path)

**Lawyer, this week:**
1. Engage Egyptian counsel with the LAW-17 list (13 items) plus every [LAWYER] marker above.
2. Get a signed memo on file.

**Before 31 Oct / 1 Nov:**
3. File with the PDPC on pdpc.gov.eg.
4. Decide individual or company. This sets the controller in privacy §1, the DPO, the store account types, APL-01 and GPL-01.

**Domain and mailboxes:**
5. Set up the domain, privacy@ and support@ mailboxes, and the website host.
6. Fill `site/config.json` and deploy.

**Processor terms:**
7. Accept the Google Cloud DPA and screenshot it.
8. Confirm the Cloud Vision no-training term.
9. Confirm the Crashlytics and Cloud Logging retention.

**Decisions:**
10. Video review: pick a vendor, or launch with the gym route and phone only. Test with niqab-wearing women on TestFlight.
11. Flag webhook: name the chat service or drop it.

**Women reviewers and the brand:**
12. Signed confidentiality agreements with the women reviewers.
13. Rahma Mohsen image and content licence to the publisher.

**Build and store access:**
14. Create the release keystore and `key.properties`.
15. Set `DEVELOPMENT_TEAM`.
16. Apple Organization account and D-U-N-S if a company.
17. Check Play developer verification now (the deadline was 30 Sep).
18. Create the +20 Firebase test number with a fixed code, and put the reviewer uid in Secret Manager.

**Store consoles:**
19. 18+ rating with Age Assurance; DSA non-trader; IARC; Target audience 18+ with Restrict Minor Access; Health apps declaration; Egypt-only storefronts.
20. Review Notes and a screen recording.

**Operations:**
21. SMS route for deletion and export identity checks.
22. Breach runbook in `firebase/ops`, kept local: the 72h clock, EN/AR templates, the register.
23. Records of processing and transfer impact assessments (Germany/EU, US).

---

## 7. Prepared store answers (they match privacy v3 §3 and §4)

### 7.1 App Store Connect: App Privacy

- **Tracking:** No. There is no ATT prompt.
- **Privacy Policy URL:** `{baseUrl}/privacy/`.

**Data Linked to You**

| Category > Type | What | Purpose |
|---|---|---|
| Contact Info > Phone Number | Sign-in, review call | App Functionality |
| Identifiers > User ID | Firebase uid | App Functionality |
| Health & Fitness > Fitness | Workouts, meals, plans | App Functionality |
| Health & Fitness > Health | Cycle, check-ins, measurements, weight, allergies (only with backup on) | App Functionality |
| Sensitive Info | Pregnancy or postpartum stage (with backup on); biometric face match during the check | App Functionality |
| User Content > Photos or Videos | ID card photos and selfie frames, processed in memory and never stored | App Functionality |
| Other Data > Other Data Types | Verification result, keyed ID code, consent records | App Functionality |
| Identifiers > Device ID | App Check, Firebase installation ID, hashed install id for fraud signals | App Functionality |

**Data Not Linked to You**

| Category > Type | What | Purpose |
|---|---|---|
| Diagnostics > Crash Data | Crashlytics, only with consent | App Functionality |
| Diagnostics > Performance Data | ML Kit performance events | App Functionality |

Notes:
- Apple's definition of "collect" may exempt the photos and the biometric processing as real-time and ephemeral. The plan declares them anyway, because the judge directed it and it is the safer reading. [LAWYER may choose otherwise]
- Do not declare Name: it is read in memory and not retained, so it is not "collected" under Apple's definition.
- Add Product Interaction only if analytics ships.

**`PrivacyInfo.xcprivacy` (M12):**
- `NSPrivacyTracking` false; tracking domains empty.
- Linked, AppFunctionality: `NSPrivacyCollectedDataTypePhoneNumber`, `NSPrivacyCollectedDataTypeUserID`, `NSPrivacyCollectedDataTypeDeviceID`, `NSPrivacyCollectedDataTypeFitness`, `NSPrivacyCollectedDataTypeHealth`, `NSPrivacyCollectedDataTypeSensitiveInfo`, `NSPrivacyCollectedDataTypePhotosorVideos`, `NSPrivacyCollectedDataTypeOtherDataTypes`.
- Not linked, AppFunctionality: `NSPrivacyCollectedDataTypeCrashData`, `NSPrivacyCollectedDataTypePerformanceData`.
- Remove `NSPrivacyCollectedDataTypeHealthFitness` (not a valid key) and `NSPrivacyCollectedDataTypeOtherUserContent`.
- Keep the required-reason API entries. The archive report (APL-05) checks them.

**Other answers:**
- Age rating: 18+. Medical/Wellness topics: yes (fitness, cycle). Age Assurance: national ID check.
- Encryption: `ITSAppUsesNonExemptEncryption` false.
- DSA: not a trader (Egypt only).
- Sign in with Apple: not required (phone OTP only).

### 7.2 Google Play Console: Data safety

**Overview**
- Collects or shares required data: **Yes**.
- Encrypted in transit: **Yes**.
- Way to request deletion: **Yes**.
  - In app: Profile > Your data > Delete everything.
  - Web: `{baseUrl}/delete-account/`.
- Data shared with third parties: **No**. Google Cloud and Firebase, the SMS route, the [OWNER] video service and the [OWNER] chat service act as service providers. [LAWYER: confirm the video vendor's status]
- Independent security review: No.

**Data types**

| Category | Type | Collected | Shared | Ephemeral | Required or optional | Purposes |
|---|---|---|---|---|---|---|
| Personal info | Name | Yes | No | **Yes** (read from the card, not kept) | Required | Fraud prevention, security and compliance |
| Personal info | Phone number | Yes | No | No | Required | Account management, App functionality, Fraud prevention |
| Personal info | User IDs | Yes | No | No | Required | Account management, App functionality |
| Personal info | Other info: national ID number (kept only as a keyed code), sex and age read from it | Yes | No | No | Required | Fraud prevention, security and compliance; App functionality |
| Health and fitness | Fitness info | Yes | No | No | Required | App functionality |
| Health and fitness | Health info (cycle, check-ins, measurements, weight, life stage, allergies) | Yes | No | No | **Optional** (backup) | App functionality |
| Photos and videos | Photos (ID card, selfie frames) | Yes | No | **Yes** | Required, with a woman-reviewer alternative | Fraud prevention, security and compliance; App functionality |
| App info and performance | Crash logs | Yes | No | No | **Optional** (consent) | Analytics |
| App info and performance | Diagnostics (ML Kit performance, crash device info) | Yes | No | No | Required | Analytics |
| Device or other IDs | Device or other IDs (Firebase installation ID, App Check, hashed install id) | Yes | No | No | Required | Fraud prevention, security and compliance; App functionality |

**Not collected:**
- location, contacts, messages (the SMS code is read by the SMS Retriever, not READ_SMS), audio, files and docs, calendar, web browsing, financial info, app activity, gallery photos.
- A video check, if one exists, happens in [OWNER: service] outside the app and is not collected by the app.

**Other Play Console answers:**
- Health apps: Activity and fitness; Nutrition and weight management; Period tracking. Pregnancy and postpartum are fitness adaptations used "with your doctor's clearance". [LAWYER]
- Target audience: 18+ only, with Restrict Minor Access on.
- Content rating: no UGC, no chat.
- App access: the test number, fixed code and reviewer allow-list (M13), plus Review Notes.
- Privacy policy URL: `{baseUrl}/privacy/`.

These answers have to match privacy v3 §3.3 to §3.7, §4, and the manifest above. After M12, regenerate the Xcode privacy report and compare all four sources line by line before submitting.

---

**Files referenced** (all under `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/`):

- **Site:** `site/_build/pages_en.py`, `site/_build/pages_ar.py`, `site/_build/build.py`, `site/config.json`
- **App code:** `app/lib/config/legal_links.dart`, `app/lib/features/signup/presentation/phone_number_view.dart`, `app/lib/features/signup/presentation/consent_view.dart`, `app/lib/features/signup/domain/capture_consent.dart`, `app/lib/app_state/firebase_boot.dart`, `app/lib/app_state/crash_reports.dart`, `app/lib/app_state/cloud_documents.dart`, `app/lib/features/account/presentation/privacy_view.dart`, `app/lib/features/account/presentation/your_data_sheet.dart`, `app/lib/routing/app_router.dart`
- **Strings and tools:** `app/tool/add_strings.py`, `app/tool/release_preflight.sh`
- **Store declarations:** `app/ios/Runner/Info.plist`, `app/ios/Runner/PrivacyInfo.xcprivacy`, `app/android/play-data-safety.txt`
- **Functions:** `functions/main.py`, `functions/identity/config.py`, `functions/identity/store.py`, `functions/identity/webhook.py`, `functions/account/deletion.py`, `functions/account/deletion_manifest.json`, `functions/waitlist/join.py`
- **Rules:** `firebase/firestore.rules`