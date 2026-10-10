# Google Play store listing, Own Hub 1.0.0

**Rewritten 23 September 2026 for the first release, which is much smaller than the product.**
Everything in a fenced block is paste-ready: copy it exactly, including the line breaks. The number
before the slash is the measured length of the block as written, and the number after it is Play's
limit.

Anything marked `[OWNER: ...]` is yours to supply. Do not invent one. An empty required field blocks
the release, and a wrong URL or a wrong email gets the app taken down later, which is worse.

## What this listing describes

Home, Train, Eat, My cycle, Progress and her privacy centre. **No account, no sign-up, no community,
no coaching, no marketplace, no assistant, no purchases of any kind, and nothing sent anywhere.**
Every claim below was checked against `FeatureFlags.shipped`. See `compliance-inventory.md`.

> ## Two warnings before you paste anything
>
> **1. Every screenshot has to be captured from the current build.** The visual language was rebuilt,
> and the release is now a different shape: **the bar at the bottom carries three tabs, Home, Train
> and Eat.** Any capture that shows four tabs, a Community tab, a sign-up screen or a coach is a
> picture of an app this listing does not describe, and Play rejects screenshots that do not match
> the app. There is no usable set in this project today.
>
> **2. The bilingual sentence in the description is only true once code blocker 1 is fixed.** Profile,
> then Language, currently opens the "Switched off" panel, and the app is pinned to English. Arabic
> is complete in the binary and unreachable. Do not publish the Arabic listing, and do not keep the
> "Arabic and English" block, until she can actually choose. See `compliance-inventory.md` section 11.

---

## 1. At a glance

| Field | Value |
|---|---|
| Application ID | `com.ownhub.app` |
| Version name and code | `1.0.0` and `1` |
| Default store language | English (United States), `en-US` |
| Translation | Arabic, `ar` |
| Min SDK and target SDK | 24 and 36 |
| Price | Free |
| In-app purchases through Play Billing | **None** |
| Payments outside Play | **None.** Nothing in this release can be bought anywhere, by any route |
| Ads | None |
| Advertising ID | Not used. The permission is not in the manifest |
| Permissions declared in the release manifest | **None at all** |
| Account creation | **The app does not support it.** There is no sign-up and no sign-in |

---

## 2. Store listing, English (`en-US`)

### App name, 26 / 30

```
Own Hub: Fitness for Women
```

### Short description, 78 / 80

```
Women only: quiet home workouts, Egyptian food, and nothing leaves your phone.
```

### Full description, 1771 / 4000

```
Own Hub is a fitness app built for women in Egypt, and only for women.

There is no account here. No sign-up, no password, no phone number. You open the app and it is already yours.

TODAY
Today's session is waiting when you open it, with a walk or a meal one tap away. Everything you log saves at once, and you have 5 seconds to undo it. Nothing here stops you to ask "are you sure?"

TRAIN
A workout player that keeps your place: tap a set to log it, rest timers that start themselves, a swap for any move that hurts or needs equipment you do not own, and a way to log a whole session from memory if you trained without your phone.

EAT
Log a meal by tapping one of your usual plates, or by typing a sentence like "ful and baladi bread". Egyptian food, under the names you already use for it.

MY CYCLE
Period and symptom tracking, private from the start. On a hard day the app offers a gentler session instead of the one it planned. Your cycle can be deleted on its own, without touching anything else.

PROGRESS
Your week, your personal bests, the milestones you have passed, and body measurements nobody else sees.

IT ALL STAYS ON YOUR PHONE
Own Hub has no server. It sends nothing, collects nothing, and asks for no permission at all. What you log is written to your own handset so it is still there tomorrow, and one button in your profile erases every bit of it at once.

WHAT THIS APP WILL NOT DO
• No daily streaks. We count weeks, not days, because a real life is not a straight line.
• No calorie countdown following you around all day.
• Nothing ranks women by body weight or by followers.
• No ads, no purchases, nothing sold.

ARABIC AND ENGLISH
The whole app in both languages, right to left included.

Own Hub is free, and there is nothing in it to buy.
```

### Everything that was in the previous listing and is not in this one

Each was removed because this release does not do it. Do not put any of them back without reading
`FeatureFlags.shipped` again.

| Removed | Why |
|---|---|
| The COMMUNITY block: posting, comments, groups, report and block | `Feature.community` is off. The tab is not drawn |
| The COACHING block: finding a coach, a month at a time, chat, weekly review | `coachApp`, `marketplace` and `payments` are all off |
| "Coaching is paid to your coach" and the whole external-payment line | Nothing in this release can be paid for |
| "Every member proves who she is before she gets in", and the ID and selfie sentences | `verification` is off, and there is no camera in the build |
| Anything about an assistant or asking a question | `assistant` is off |
| "or by saying it out loud", logging a meal by voice | No speech recogniser is attached. Tapping the microphone offers the keyboard instead |
| "Export everything you have ever logged" | There is no export. The deletion sheet says so in a sentence rather than offering a button |
| "delete your account and have it actually be gone" | There is no account. **Deleting everything on this phone is real**, and the new block says that instead |
| "Choose your language on the second screen" | There is no second screen: the app opens on Home. See warning 2 |

---

## 3. Store listing, Arabic (`ar`)

Modern Standard Arabic. Western digits throughout (1, 2, 3), which is this product's convention
everywhere: in the app, in the listing and in the release notes.

### App name, 21 / 30

```
Own Hub: لياقة للنساء
```

> The Latin wordmark is kept in the Arabic listing on purpose: the Arabic wordmark has not been drawn
> yet, and an improvised transliteration on the store is close to impossible to change once women
> have searched for it. `[OWNER: confirm, or supply an Arabic wordmark before this listing goes
> live.]`

### Short description, 67 / 80

```
للنساء وحدهن: تمارين منزلية هادئة، وطعام مصري، ولا شيء يغادر هاتفك.
```

### Full description, 1438 / 4000

```
Own Hub تطبيق لياقة بدنية للنساء في مصر، وللنساء وحدهن.

لا حساب هنا. لا تسجيل، ولا كلمة سر، ولا رقم هاتف. تفتحين التطبيق فتجدينه لكِ وحدك.

اليوم
تجدين تمرين اليوم في انتظارك حين تفتحينه، ومشية أو وجبة على بعد لمسة واحدة. وكل ما تسجّلينه يُحفظ فورًا، ولكِ 5 ثوانٍ للتراجع. ولا شيء هنا يوقفك ليسألك: هل أنتِ متأكدة؟

التمرين
مشغّل تمارين يحفظ موضعك: المسي المجموعة لتسجيلها، ومؤقّت راحة يبدأ من تلقاء نفسه، وبديل لأي حركة تؤلمك أو تحتاج إلى معدات لا تملكينها، وطريقة لتسجيل التمرين كاملًا من الذاكرة إن تمرّنتِ من دون هاتفك.

الطعام
سجّلي وجبتك بلمس واحدة من وجباتك المعتادة، أو بكتابة جملة مثل «فول وخبز بلدي». طعام مصري بالأسماء التي تستعملينها له.

دورتي
تتبّع للدورة وللأعراض، خاص من البداية. وفي يوم صعب يعرض عليك التطبيق جلسة أهدأ بدل التي خطّط لها. ويمكن حذف بيانات دورتك وحدها من دون المساس بشيء آخر.

التقدّم
أسبوعك، وأفضل أرقامك، والإنجازات التي بلغتِها، وقياسات جسمك التي لا يراها أحد سواك.

كل شيء يبقى على هاتفك
لا خادم لـ Own Hub. لا يرسل شيئًا، ولا يجمع شيئًا، ولا يطلب أي إذن. وما تسجّلينه يُكتب على هاتفك وحده ليبقى غدًا، وفي ملفك زر واحد يمحوه كله دفعة واحدة.

ما لا يفعله هذا التطبيق
• لا سلاسل يومية. نحسب الأسابيع لا الأيام، لأن الحياة الحقيقية لا تسير في خط مستقيم.
• لا عدّاد سعرات يلاحقك طوال اليوم.
• لا شيء هنا يرتّب النساء حسب وزن الجسم أو عدد المتابِعات.
• لا إعلانات، ولا مشتريات، ولا شيء يُباع.

بالعربية والإنجليزية
التطبيق كامل باللغتين، ومن اليمين إلى اليسار كما ينبغي.

Own Hub مجاني، وليس فيه ما يُشترى.
```

---

## 4. Release notes for 1.0.0

Play calls this "What's new". It is per language, so both go in.

### English, 441 / 500

```
The first release of Own Hub.

No account and no sign-up: open it and it is yours. One-tap logging with a 5-second undo, today's session on Home, a workout player with rest timers and move swaps, meal logging by tap or by sentence, your week and your personal bests, and period tracking you can delete on its own.

Everything stays on your phone, and one button erases it. No ads, nothing to buy.

Tell us what breaks: [OWNER: support email]
```

### Arabic, 376 / 500

```
الإصدار الأول من Own Hub.

لا حساب ولا تسجيل: افتحيه فتجدينه لكِ. تسجيل بلمسة واحدة وتراجع خلال 5 ثوانٍ، وتمرين اليوم في صفحته الأولى، ومشغّل تمارين بمؤقّتات راحة وبدائل للحركات، وتسجيل للوجبات باللمس أو بجملة، وأسبوعك وأفضل أرقامك، وتتبّع للدورة يمكنك حذفه وحده.

كل شيء يبقى على هاتفك، وزر واحد يمحوه. بلا إعلانات، ولا شيء يُشترى.

أخبرينا بما يتعطّل: [OWNER: support email]
```

---

## 5. Category and tags

| Field | Answer |
|---|---|
| App or game | App |
| Category | **Health & Fitness** |
| Tags, up to 5 | Play offers a fixed list and the wording shifts between console versions. Pick the closest live options to: **Exercise & Fitness**, **Health**, **Nutrition & Diet**, **Women's Health**. If one is not in your console, leave the slot empty rather than reaching for a loosely related tag. A wrong tag puts this app in front of the wrong audience |

Do not put keywords in the app name or the short description to chase ranking. Play's Store Listing
policy rejects keyword stuffing and superlatives such as "best", "number one" and "top", and none
appears anywhere in this file.

---

## 6. Content rating, the IARC questionnaire

You answer a questionnaire and IARC issues the rating. You never pick a rating directly.

**This release makes the questionnaire short**, because the three answers that used to raise the
rating are all "no" now: no user interaction, no user-generated content, and no purchases.

| Questionnaire area | Answer | Why |
|---|---|---|
| Category | **Reference, News, Education or Utility**, whichever your console offers for a health and fitness tool | It is a tracking and training tool, not a game |
| Violence, realistic or cartoon | No | |
| Sexuality or nudity | No | Exercise demonstrations are clothed and instructional |
| Profanity or crude humour | No | |
| Controlled substances: drugs, alcohol, tobacco | No | |
| Gambling, simulated gambling, contests | No | |
| Horror or fear themes | No | |
| Does the app share the user's location with other users? | **No** | Location is never collected, and there are no other users |
| **Does the app let users interact or exchange content?** | **No** | The community is switched off and there is no messaging of any kind. Nothing in the app connects one woman to another |
| **Does the app contain user-generated content?** | **No** | Nothing she writes is published, shared or sent. It is written to her own handset and read back by her own app |
| Can users share their own content publicly? | **No** | There is no share sheet, no export and no upload |
| **Does the app allow purchases?** | **No** | No in-app purchases, no subscriptions, and no payment outside Play either. Nothing in this release costs money |
| Does the app collect or share personal information? | **No** | Nothing leaves the device. This answer must match Data safety exactly, and it does: section 8 |
| Miscellaneous: medical or health information | **Yes.** The app carries general fitness and menstrual-health information, and on a day she logs severe cramps or heavy bleeding it stops suggesting a workout and points her toward care | Answering "no" here while shipping health guidance is a misrepresentation |

**Expected outcome: a low rating**, because the only positive answer is the health-information one.
Take whatever the questionnaire produces and do not reverse-engineer a target.

**Separately from the rating**, in *App content, Target audience and content*, declare the target age
group. `[OWNER: the product is a women-only membership and the minimum age is still with counsel. For
this release, which has no account, no community and no purchases, declare an adult band and "not
designed for children, no appeal to children". Settle the number before accounts ship.]`

---

## 7. App content declarations

Play will not let you roll out until every one of these is green.

| Declaration | Answer for 1.0.0 |
|---|---|
| Privacy policy URL | `[OWNER: live URL, English and Arabic, covering fitness and menstrual data even though none of it is collected]` |
| Ads | **No ads** |
| **App access** | **All functionality is available without any special access.** No login, no credentials, nothing gated. This is the answer that changed: there is no demo account to provide because there is no account at all |
| Content rating | Section 6 above |
| Target audience and content | See the owner note in section 6. Not designed for children, no appeal to children |
| News app | No |
| COVID-19 contact tracing or status | No |
| Data safety | Section 8 below |
| Government apps | No |
| Financial features | **None.** No lending, no banking, no crypto, no money transfer, and no payments of any kind |
| **Health apps declaration** | **Yes, this applies.** The app records fitness activity and menstrual data, on the device. Declare it as a health app, and state that it is not a medical device, makes no diagnosis, provides no treatment, and does not connect to Health Connect, Google Fit or any sensor |
| Advertising ID | **Not declared and not used.** `com.google.android.gms.permission.AD_ID` is not in the manifest |
| Data deletion | Section 10 below |
| Permissions | **The release manifest declares none.** Verify it against the artifact you are uploading, not from memory |

### The payments answer, in one line

**There are no payments.** No Play Billing, no external rail, no price shown anywhere in the app. The
coaching payment design exists in the repository behind switches that are off, and it must not be
described on this form or in any note to a reviewer. Do not offer an argument for a capability the
binary does not have.

---

## 8. Data safety, answered question by question

Play compares this form against what the app actually does on the network. A mismatch is one of the
fastest routes to a suspension there is.

**Nothing leaves the device.** There is no network client in the app, the release manifest requests
no internet permission, and the one thing that is written is written to the handset's own preference
store. Under Play's definition, data that never leaves the device is **not collected**.

**Local storage is not collection, and this is why.** Since this release the app writes one JSON
document under one key, `own_hub.snapshot`, into the app's own private preferences, so her week is
still there tomorrow. It is read by this app and by nothing else, it is inside the app sandbox, no
code path copies it anywhere, there is no analytics or crash SDK that could sample it, and deleting
everything from her profile removes it. Play's own guidance is explicit that data processed only on
the device is not collected. That is the whole argument, and it is checkable in one file:
`lib/app_state/local_persistence.dart`.

### Data collection and security, the opening questions

| Question, as the console asks it | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | Not asked once you answer No above. If your console asks anyway: no data is transmitted at all |
| Do you provide a way for users to request that their data is deleted? | If the console asks: **there is no server-side data to request the deletion of.** The app deletes everything on the handset from Profile, then Your data. See section 10 |
| Has your app been independently validated against a global security standard? | No. Leave it unticked unless you commission one |

> **Verify "No" on the day you submit, from the artifact you are uploading**, not from memory: open
> the `.aab`, check that `AndroidManifest.xml` contains no `INTERNET` permission, and check that no
> network library appears in `pubspec.lock`. The two packages that are new, `shared_preferences` and
> `url_launcher`, are platform wrappers and neither has a server.

### Every data type

| Data type | Answer | Why |
|---|---|---|
| Personal info: name, email, phone number, user IDs, address, race, political or religious beliefs, sexual orientation, other info | **Not collected** | There is no account and no sign-up. The app never asks for a name, a number or an email |
| Financial info: purchase history, payment info, credit score, other | **Not collected** | Nothing can be bought |
| Health and fitness: health info, fitness info | **Not collected** | Her sessions, sets, meals, measurements, period days and symptoms are written to her own handset and read back by her own app. Nothing is transmitted |
| Messages: emails, SMS, other in-app messages | **Not collected** | There is no messaging in this release |
| Photos and videos | **Not collected** | There is no camera and no gallery access in the build |
| Audio: voice recordings, music, other | **Not collected** | There is no microphone access and no speech recognition |
| Files and docs | **Not collected** | |
| Calendar, Contacts | **Not collected** | |
| App activity: interactions, in-app search history, installed apps, other UGC, other actions | **Not collected** | No analytics SDK exists in the app |
| Web browsing history | **Not collected** | There is no in-app browser. `url_launcher` hands an address to the platform browser and learns nothing back |
| App info and performance: crash logs, diagnostics, other | **Not collected** | No crash reporter is in the app |
| Device or other IDs | **Not collected** | No advertising identifier is read, and no install id is assigned |
| Location: approximate, precise | **Not collected** | |

**Data sharing is "No" on every row.** Nothing is sold, nothing goes to a data broker, nothing is
joined with third-party data, and nothing is used to track her across other companies' apps or
websites.

**The day a server is connected, this form changes in the same release that connects it.** A form
that lags the binary by one release is a policy violation, not a paperwork delay. The categories that
would light up first are in `compliance-inventory.md` section 3.

---

## 9. Graphic assets

| Asset | Exact size | Format | Notes |
|---|---|---|---|
| App icon | **512 by 512 px** | 32-bit PNG, under 1 MB | Play applies its own mask and shadow. Keep the mark inside a 410 px safe circle. **Export it from `app/assets/icon/icon-1024.png`**, which exists and is a typographic monogram generated from the brand. `[OWNER: it is a placeholder you may replace.]` |
| Feature graphic | **1024 by 500 px** | JPEG or 24-bit PNG, **no alpha**, under 15 MB | Required. You cannot publish without it. Assume a play button covers the middle on some surfaces |
| Phone screenshots | **1080 by 1920 px** portrait. Play's hard limits are 320 to 3840 px per side, under 8 MB each | PNG or JPEG | Minimum 2, maximum 8 |
| Tablet screenshots | | | **Not needed.** The iOS build is phone only; keep Play the same unless you test tablets |
| Promo video | | YouTube URL | Optional. Skip it for 1.0 |

**Every graphic is per language.** Upload a full English set under `en-US` and a full Arabic set
under `ar`, with the Arabic screenshots taken from the Arabic build in right to left. English
screenshots on an Arabic listing is the single most common sign that a listing was not really
localised.

### Capturing them

The app can be launched straight onto any screen, and `--dart-define=OWNHUB_LOCALE=ar` opens it in
Arabic, so both sets can be captured without walking the whole app each time.

**Capture from the release build, and check the bar.** In this release the bottom bar has **three
tabs: Home, Train and Eat.** If a capture shows four tabs or a Community tab, it came from a build
with the flags in the wrong place and it cannot be used.

**Six, in order.** Each one a real screen from the current build:

1. Home, with today's session card and one-tap logging
2. The 5-second undo bar just after a set is logged
3. The workout player mid-set, with the rest timer running
4. Eat, the day view with her usual plates
5. My cycle, showing that it is private by default
6. Progress, the week and personal bests

Two more, if you want eight: the "I already did it" flow for a session trained away from the phone,
and Profile with "Your data". Do not screenshot anything from the switched-off half of the product.

`[OWNER: whoever cuts these needs the current palette and type from the app's own theme files.]`

---

## 10. Data deletion

**Play requires the account-deletion URL from apps that let users create an account. This one does
not**, so the requirement is not triggered and the field is not blocking.

Publish the page anyway, and point the console at it. It costs nothing, it is one of the four
addresses `lib/config/legal_links.dart` needs before the in-app rows are drawn, and it is the honest
place to explain what deletion means for an app with no server.

```
[OWNER: deletion page URL, for example https://yourdomain/delete-account]
```

What the app itself does, which is what the page has to describe: **Profile, then Your data.** A
sheet explains that deleting takes away her meals, workouts, measurements, cycle and answers, that it
happens at once and cannot be undone, and that everything is on this phone so deleting clears the
phone. The button under it does exactly that, including the stored snapshot. The text is drafted in
`delete-account.md` beside this file.

---

## 11. What only you can supply

| # | Item | Blocks |
|---|---|---|
| 1 | Privacy policy URL, live, English and Arabic | Cannot submit |
| 2 | Support email address, shown publicly in the listing contact details and used in the release notes | Cannot submit |
| 3 | Developer name shown on the store, and the contact address Play publishes | Cannot submit |
| 4 | **Screenshots and a 1024 by 500 feature graphic, from the current build, English and Arabic** | Cannot submit |
| 5 | Confirmation of the Arabic wordmark decision, section 3 | The Arabic listing |
| 6 | The target age declaration in section 6 | The content rating step |
| 7 | Whether the generated app icon is the final one | Nothing, but it is your name on her home screen |
| 8 | The deletion page URL in section 10, once the site exists | The in-app rows, through `legal_links.dart` |
