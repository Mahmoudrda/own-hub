# App Store Connect listing, Own Hub 1.0.0

**Rewritten 23 September 2026 for the first release, which is much smaller than the product.**
Everything in a fenced block is paste-ready. The number before the slash is the measured length of
the block, and the number after it is Apple's limit.

Anything marked `[OWNER: ...]` is yours to supply. Do not invent one.

**One formatting note that catches people out:** App Store descriptions render as **plain text**.
Asterisks, hashes and markdown bullets appear literally. The blocks below are already plain text with
line breaks and `·` style bullets, so they go straight in.

## What this listing describes

Home, Train, Eat, My cycle, Progress and her privacy centre. **No account, no sign-up, no community,
no coaching, no marketplace, no assistant, no in-app purchases, and nothing sent anywhere.** Every
claim below was checked against `FeatureFlags.shipped`. See `compliance-inventory.md`.

> ## Two warnings before you paste anything
>
> **1. Every screenshot has to be captured from the current build.** The visual language was rebuilt,
> and the release is now a different shape: **the bar at the bottom carries three tabs, Home, Train
> and Eat.** Any capture that shows four tabs, a Community tab, a sign-up screen or a coach shows a
> user interface this app does not have, which Apple rejects under Guideline 2.3.3. There is no
> usable set in this project today.
>
> **2. The bilingual sentence in the description is only true once code blocker 1 is fixed.** Profile,
> then Language, currently opens the "Switched off" panel, and the app is pinned to English. Arabic
> is complete in the binary and unreachable. Do not publish the Arabic localisation, and do not keep
> the "Arabic and English" block, until she can actually choose. See `compliance-inventory.md`
> section 11.

---

## 1. At a glance

| Field | Value |
|---|---|
| Bundle ID | `com.ownhub.app` |
| Version and build | `1.0.0` and `1` |
| Primary language | English (U.S.) |
| Localisation | Arabic |
| Price | Free |
| In-app purchases | **None** |
| Subscriptions through Apple | **None** |
| Payment outside the app | **None.** Nothing in this release can be bought by any route |
| Devices | iPhone only. `TARGETED_DEVICE_FAMILY` is 1, so do not offer iPad |
| Orientation | Portrait only |
| **Sign-in required to use the app** | **No.** There is no account, no credentials and no demo account to supply. See `review-notes.md` |

---

## 2. App Information, the fields that are not per language

| Field | Value |
|---|---|
| Bundle ID | `com.ownhub.app` |
| SKU | `own-hub-ios-1` |
| Primary category | **Health & Fitness** |
| Secondary category | **Lifestyle** |
| Content rights, does it contain third-party content? | **No.** Nothing in this release is contributed by anyone but the developer. The community is switched off, and the two bundled fonts are used under SIL OFL 1.1 |
| Age rating | Section 6 below |
| Privacy Policy URL | `[OWNER: live URL, English and Arabic]`. The text is drafted in `privacy-policy.md` |
| Support URL | `[OWNER: a real page, not a mailto: link]` |
| Marketing URL | Optional. Leave it empty for 1.0 unless a real page exists |
| License Agreement | Apple's standard EULA, unless counsel supplies a custom one. See the note in `terms.md` |
| Copyright | `[OWNER: for example, 2026 <legal entity name>]` |
| Routing App Coverage File | Not applicable |

---

## 3. English localisation

### Name, 26 / 30

```
Own Hub: Fitness for Women
```

### Subtitle, 26 / 30

```
Quiet workouts, women only
```

### Promotional text, 133 / 170

Editable without submitting a new build, so this is the line to change when something happens. Keep
it a promise, not an announcement.

```
No account, no sign-up, and nothing sent anywhere. Log a set in one tap, undo it in 5 seconds, and keep your cycle on your own phone.
```

### Description, 1771 / 4000

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

**Nothing in this description mentions Android or Google Play**, which Guideline 2.3.10 forbids in
the iOS binary and its metadata. Keep it that way when you edit it.

### Keywords, 99 / 100

Comma separated, **no spaces after the commas**. A space costs a character and splits a phrase.

```
strength,home training,gym,period tracker,menstrual,nutrition,meals,Egyptian,Arabic,offline,private
```

Words already in the Name and the Subtitle are indexed automatically, so *fitness*, *women*,
*workouts* and *quiet* are deliberately not repeated. Nothing in this list is a competitor's name or
a trademark, which the review guidelines treat as grounds for rejection. *coach* and *ladies* were
dropped: one describes a feature that is switched off, and the other was never how this product
talks.

### What's New in This Version, 441 / 4000

```
The first release of Own Hub.

No account and no sign-up: open it and it is yours. One-tap logging with a 5-second undo, today's session on Home, a workout player with rest timers and move swaps, meal logging by tap or by sentence, your week and your personal bests, and period tracking you can delete on its own.

Everything stays on your phone, and one button erases it. No ads, nothing to buy.

Tell us what breaks: [OWNER: support email]
```

### Everything removed from the previous version of this listing

| Removed | Why |
|---|---|
| The COMMUNITY block | `Feature.community` is off. The tab is not drawn |
| The COACHING block, and the 3.1.3(d) argument with it | `coachApp`, `marketplace` and `payments` are all off. Nothing can be paid for, so there is no argument to make |
| "Every member proves who she is before she gets in", and the ID and selfie sentences | `verification` is off, and there is no camera in the build |
| Anything about an assistant | `assistant` is off |
| "or by saying it out loud" | No speech recogniser is attached. Tapping the microphone offers the keyboard instead |
| "Export everything you have ever logged" | There is no export |
| "delete your account and have it actually be gone" | There is no account. **Deleting everything on this phone is real**, and the new block says that instead |
| "Choose your language on the second screen" | There is no second screen: the app opens on Home. See warning 2 |

---

## 4. Arabic localisation

Modern Standard Arabic. Western digits throughout (1, 2, 3), the product's convention in the app and
on the store.

### Name, 21 / 30

```
Own Hub: لياقة للنساء
```

> The Latin wordmark stays in the Arabic listing on purpose: the Arabic wordmark has not been drawn
> yet, and an improvised transliteration is close to impossible to change once women have searched
> for it. `[OWNER: confirm, or supply the Arabic wordmark before this listing goes live.]`

### Subtitle, 26 / 30

```
تمارين هادئة، للنساء وحدهن
```

### Promotional text, 121 / 170

```
لا حساب، ولا تسجيل، ولا شيء يُرسل إلى أي مكان. سجّلي المجموعة بلمسة، وتراجعي خلال 5 ثوانٍ، واحتفظي بدورتك على هاتفك وحدك.
```

### Description, 1438 / 4000

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

### Keywords, 74 / 100

```
قوة,تمارين منزلية,جيم,تتبع الدورة,أعراض,تغذية,وجبات,مصري,بلا إنترنت,خصوصية
```

### What's New in This Version, Arabic, 376 / 4000

```
الإصدار الأول من Own Hub.

لا حساب ولا تسجيل: افتحيه فتجدينه لكِ. تسجيل بلمسة واحدة وتراجع خلال 5 ثوانٍ، وتمرين اليوم في صفحته الأولى، ومشغّل تمارين بمؤقّتات راحة وبدائل للحركات، وتسجيل للوجبات باللمس أو بجملة، وأسبوعك وأفضل أرقامك، وتتبّع للدورة يمكنك حذفه وحده.

كل شيء يبقى على هاتفك، وزر واحد يمحوه. بلا إعلانات، ولا شيء يُشترى.

أخبرينا بما يتعطّل: [OWNER: support email]
```

---

## 5. Category, and the payment question answered in one line

**Primary: Health & Fitness.** The app's core is training, logging and health tracking. Apple
re-categorises apps that hide in a less competitive category.

**Secondary: Lifestyle.** Chosen over *Medical* on purpose. **Do not select Medical.** Apple holds
Medical apps to a materially higher bar under Guideline 1.4.1: accuracy of health measurements,
regulatory clearance and named clinical sourcing. Own Hub makes no diagnosis, offers no treatment and
is not a medical device. Putting it in Medical invites questions this product cannot and should not
answer.

**There is nothing to buy.** No in-app purchase, no subscription, no external payment, no price shown
anywhere in the app, and no checkout that resolves. Guideline 3.1 does not arise, and neither does
3.1.3(d). The coaching payment design exists in the repository behind switches that are off, and it
must not be mentioned on this form or in the review notes. An argument offered for a capability the
binary does not have is an invitation to go looking for it.

---

## 6. Age rating

Apple's 2025 tiers are **4+, 9+, 13+, 16+, 18+**. The tier is **computed from your answers**. You
cannot select one directly and you should not try to reverse-engineer a target.

**This release makes the questionnaire short.** The answer that used to raise the tier, in-app
communication and user-generated content, is now "No", because the community and every messaging
surface are switched off.

| Question area | Answer | Reasoning |
|---|---|---|
| Cartoon or Fantasy Violence | None | |
| Realistic Violence | None | |
| Sexual Content or Nudity | None | Exercise demonstrations are clothed and instructional. Worth a line in the review notes, because a fitness app with a woman's body on screen occasionally draws the question |
| Profanity or Crude Humor | None | |
| Alcohol, Tobacco, or Drug Use | None | |
| Horror or Fear Themes | None | |
| Mature or Suggestive Themes | None | |
| Gambling or Contests | None | |
| Unrestricted Web Access | **No** | There is no in-app browser. Three rows hand a fixed address, ours, to the system browser, and only once those pages exist |
| **Medical or Treatment Information** | **Infrequent or Mild** | The app is not a medical product, and it does show health guidance: on a day she logs severe cramps or heavy bleeding, the workout suggestion is replaced with advice to seek care. Answering "None" would be a misrepresentation |
| **Health and Wellness Topics** | **Yes** | Fitness, nutrition and menstrual tracking are exactly this |
| **In-app messaging, user-generated content, or the ability to communicate with other users** | **No** | There is no community, no messaging, no comments, no profiles and no sharing in this release. Nothing she writes reaches anyone |
| Advertising | None | |
| In-app purchases | None | |

**Expect a low tier**, driven by the health information alone. Take the tier the questionnaire
produces.

### The membership rule, and why it is not an age rating question

**Own Hub is a women-only product.** That is a membership rule, and the rating describes *content*.
The two are different things, and selecting 18+ for a fitness app would misdescribe the app.

In this release the membership rule is **not enforced by the app**, because there is no account and
no verification to attach it to. Say nothing in the store forms that implies otherwise. When accounts
return, the rule is enforced by the date of birth and the sex digit in the national ID, and the
number then has to appear identically in the policy, the Terms, the app's gate and both ratings.

`[OWNER: the minimum age is still with counsel. It does not block this release.]`

---

## 7. App Privacy, the nutrition label

This label must match three other things exactly: `privacy-policy.md`,
`ios/Runner/PrivacyInfo.xcprivacy`, and what the binary does. Use the Xcode privacy report as the
source of truth: Product, Archive, then in the Organizer right-click the archive and choose Generate
Privacy Report.

### The opening answers

| Question | Answer |
|---|---|
| Do you or your third-party partners collect data from this app? | **No. Select "Data Not Collected"** |
| Is any data used to track you across apps and websites owned by other companies? | **No**, and this is a product commitment, not an omission |
| App Tracking Transparency prompt | Not shown, and not required. There is nothing to ask about |

**Why "Data Not Collected" is true even though the app now writes to the phone.** Apple's definition
of collection is transmitting data off the device. Since this release the app writes one JSON
document under one key, `own_hub.snapshot`, into `NSUserDefaults`, so her week survives a restart. It
is inside the app sandbox, it is read by this app and nothing else, no code path copies it anywhere,
there is no analytics or crash SDK that could sample it, and deleting everything from her profile
removes it. Apple's own guidance is explicit that data processed only on the device is not collected.
The argument is checkable in one file: `lib/app_state/local_persistence.dart`.

### The privacy manifests

**`ios/Runner/PrivacyInfo.xcprivacy` declares tracking false, no tracking domains, no collected data
types and no accessed API types.** That is accurate for the app's own code.

**The two new plugins carry their own manifests, and that is deliberate.**
`shared_preferences_foundation` 2.5.7 declares `NSPrivacyAccessedAPICategoryUserDefaults` with reason
`1C8F.1`, and `url_launcher_ios` 6.4.2 declares nothing at all. Apple aggregates the app manifest
with every framework's, so the required reason travels with the package and stays right when the
package updates. **Do not copy that reason into the app's own manifest**: a duplicate declaration is
not required, and hand-maintaining a plugin's reasons is how a manifest goes stale. Confirm it with
the Xcode privacy report on the archive you upload.

### Every data type

Tracking is **No** on every row, in every case.

| Apple data type | Answer | Why |
|---|---|---|
| Contact Info: name, email, phone number, physical address, other | **Not collected** | There is no account and no sign-up. The app never asks |
| Health & Fitness: Health, Fitness | **Not collected** | Sessions, sets, meals, measurements, period days and symptoms are written to her own handset and read back by her own app. Nothing is transmitted |
| Financial Info: payment info, credit info, other | **Not collected** | Nothing can be bought |
| Location: precise, coarse | **Not collected** | |
| Sensitive Info | **Not collected** | Verification is off, so no ID number and no date of birth is ever read |
| Contacts | **Not collected** | |
| User Content: photos or videos, audio, gameplay content, customer support, emails or text messages, other | **Not collected** | There is no camera, no gallery access, no microphone and no messaging in the build |
| Browsing History | **Not collected** | There is no in-app browser |
| Search History | **Not collected** | |
| Identifiers: User ID, Device ID | **Not collected** | There is no account id, and no advertising identifier is read |
| Purchases: purchase history | **Not collected** | |
| Usage Data: product interaction, advertising data, other | **Not collected** | No analytics SDK is in the app |
| Diagnostics: crash data, performance data, other | **Not collected** | No crash reporter is in the app |
| Other Data | **Not collected** | |

Also enter the Privacy Policy URL here: `[OWNER: live URL]`.

**The day a server is connected, this label changes in the same submission that connects it**, along
with the app's own privacy manifest. The categories that would light up first are in
`compliance-inventory.md` section 3.

---

## 8. Screenshots and icon

| Asset | Exact size | Notes |
|---|---|---|
| App icon | **1024 by 1024 px** | PNG or JPEG, **no alpha channel**, **no rounded corners**. Apple applies the mask, and rejects an icon with alpha. **`app/assets/icon/icon-1024.png` exists** and the `AppIcon.appiconset` is generated from it, with `remove_alpha_ios` set. `[OWNER: it is a typographic monogram made from the brand, and a placeholder you may replace.]` |
| 6.9-inch iPhone screenshots | **1320 by 2868 px** portrait, or **1290 by 2796 px**, both accepted as 6.9-inch | **Required.** This is the only iPhone size you must supply. Apple scales it for smaller devices. Minimum 1, maximum 10 |
| iPad screenshots | | **Not needed.** The project is iPhone only. Do not add iPad as a supported destination unless you test iPad layouts, because Apple tests what you declare |
| App previews, video | Optional | Skip for 1.0 |

Screenshots must come from a **real build** at the real resolution. Rendered mockups at the right
pixel size are rejected under Guideline 2.3.3 when they show a user interface the app does not have.

**Both localisations need their own set**, the Arabic ones captured from the Arabic build in right to
left. `--dart-define=OWNHUB_LOCALE=ar` opens the app in Arabic, and the app can be launched straight
onto any screen, so both sets can be captured without walking the whole app each time.

**Capture from the release build, and check the bar.** In this release the bottom bar has **three
tabs: Home, Train and Eat.** A capture showing four tabs or a Community tab came from a build with
the flags in the wrong place and cannot be used.

**Six, in order:**

1. Home, with today's session card and one-tap logging
2. The 5-second undo bar just after a set is logged
3. The workout player mid-set, with the rest timer running
4. Eat, the day view with her usual plates
5. My cycle, showing that it is private by default
6. Progress, the week and personal bests

Two more, if you want eight: the "I already did it" flow for a session trained away from the phone,
and Profile with "Your data". Do not screenshot anything from the switched-off half of the product.

---

## 9. What only you can supply

| # | Item | Blocks |
|---|---|---|
| 1 | Privacy policy URL, live, English and Arabic | Cannot submit |
| 2 | Support URL, a real page, not a mailto | Cannot submit. A broken or missing support URL is among the top three first-submission failures |
| 3 | Support email for the release notes | Cannot submit |
| 4 | Copyright line and the legal entity name | Cannot submit |
| 5 | **6.9-inch screenshots from the current build, English and Arabic** | Cannot submit |
| 6 | Confirmation of the Arabic wordmark decision, section 4 | The Arabic localisation |
| 7 | Review contact name, phone and email. Apple does call | Cannot submit |
| 8 | Whether the generated app icon is the final one | Nothing, but it is your name on her home screen |

**Demo account credentials are not on this list any more.** There is no account in this release, so
"Sign-in required" is No and both credential fields stay empty. See `review-notes.md`.
