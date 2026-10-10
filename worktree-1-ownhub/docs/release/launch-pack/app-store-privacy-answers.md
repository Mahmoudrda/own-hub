# App Store Connect answers (step 20)

Three things to fill in on App Store Connect before you submit: **App Privacy**, the **age rating**, and
**App Review Information**. The privacy answers below match the app's privacy manifest
(`app/ios/Runner/PrivacyInfo.xcprivacy`) and the Play answers (`app/android/play-data-safety.txt`)
line for line. If one of the three changes, all three change, and so does the privacy policy.

---

## 1. App Privacy

App Store Connect, your app, **App Privacy** (left menu), then **Get Started** or **Edit**.

### First questions

| Question | Answer |
|---|---|
| Privacy Policy URL | the privacy page from step 12, for example `https://[your domain]/privacy` |
| Do you or your third-party partners collect data from this app? | **Yes, we collect data from this app** |

### Tick these data types, and nothing else

| Category | Data type to tick |
|---|---|
| Contact Info | **Phone Number** |
| Health & Fitness | **Health** and **Fitness** |
| Sensitive Info | **Sensitive Info** |
| User Content | **Photos or Videos** |
| Identifiers | **User ID** and **Device ID** |
| Usage Data | **Product Interaction** |
| Location | **Coarse Location** |
| Diagnostics | **Crash Data** and **Performance Data** |
| Other Data | **Other Data Types** |

Leave every other box empty: no name, email, address, precise location, contacts, audio, browsing or
search history, purchases, financial info, advertising data, other usage data, other user content or
other diagnostic data.

Product Interaction and Coarse Location come from Google Analytics for Firebase, which runs only if she
turns on "Help improve Own Hub" (off by default, on the phone-number screen or in Privacy). Optional
data still has to be declared.

### Then answer for each type

The purpose is **App Functionality** for every type except three: **Product Interaction** and
**Coarse Location** are **Analytics** only, and **Device ID** is **App Functionality** and
**Analytics**. Never tick Product Personalisation, Developer's Advertising, Third-Party Advertising or
Other Purposes.
For **every** type, "Do you or your third-party partners use this data for tracking?" is **No**. Own Hub
collects no advertising identifier (no IDFA, no AdSupport, no App Tracking Transparency prompt) and
shares nothing with data brokers.

| Data type | What it is in Own Hub | Linked to the user? | Used for tracking? | Purpose |
|---|---|---|---|---|
| Phone Number | Sign-in by SMS code | **Yes** | **No** | App Functionality |
| Health | Cycle and period dates, daily check-ins, measurements and weight, allergies. Only sent if she turns on "Back up my health data" (off by default), but optional data still has to be declared | **Yes** | **No** | App Functionality |
| Fitness | Workouts, sessions and meals, saved to her account | **Yes** | **No** | App Functionality |
| Sensitive Info | Her pregnancy or postpartum stage, sent only with health backup, and the biometric face match during the ID check. No face measurement is stored | **Yes** | **No** | App Functionality |
| Photos or Videos | The two photos of her ID card and the selfie, checked on our server and discarded when the check ends, never stored. "Deleted afterwards" does not exempt it from being declared | **Yes** | **No** | App Functionality |
| User ID | The account ID her data is kept under | **Yes** | **No** | App Functionality |
| Device ID | The Firebase installation ID and the App Attest check that the app is genuine; with her consent to usage statistics, also the Google Analytics app instance ID, reset when she withdraws it | **Yes** | **No** | App Functionality, Analytics |
| Product Interaction | Which screens (by screen id) and steps she uses, sent to Google Analytics only if she turns on "Help improve Own Hub". Never health, body, cycle, life stage, name, number, ID or anything she typed. No user ID is set | **No** | **No** | Analytics |
| Coarse Location | The approximate location Google Analytics derives from the masked IP address, with the same consent. The app reads no location | **No** | **No** | Analytics |
| Crash Data | Crash reports from Firebase Crashlytics, only if she allows them: crashes, and non-fatal reports of a server call that failed with a bug's status code. The app never attaches her account to them; the only keys are the screen id, app version and build channel | **No** | **No** | App Functionality |
| Performance Data | Performance events Google ML Kit sends while it guides the selfie camera | **No** | **No** | App Functionality |
| Other Data Types | Her national ID number, kept only as a one-way keyed code so one card cannot open two accounts | **Yes** | **No** | App Functionality |

When you are done, click **Publish**. The summary on the store page should read:
- **Data Linked to You:** Contact Info, Health & Fitness, Sensitive Info, User Content, Identifiers, Other Data
- **Data Not Linked to You:** Location, Usage Data, Diagnostics
- **Data Used to Track You:** none

---

## 2. Age rating

App Store Connect, your app, **App Information**, **Age Rating**, then **Edit**.

The app is for women aged 18 and over, and the ID check refuses anyone younger. Answer the questions
honestly for the content, then set the rating to 18+.

| Question | Answer |
|---|---|
| Violence of any kind (cartoon, realistic, graphic) | None |
| Sexual content or nudity, suggestive themes | None. Exercise demonstrations are clothed and instructional |
| Profanity or crude humour | None |
| Horror or fear themes | None |
| Alcohol, tobacco or drug use or references | None |
| Medical or treatment information | None. Own Hub is not medical. If you are unsure, "Infrequent" is also defensible, because the cycle screen points her to care on a severe day |
| Health or wellness topics | **Yes** (fitness, nutrition, period tracking) |
| Simulated gambling, gambling, contests, loot boxes | None / No |
| Unrestricted web access | No. The app only opens its own privacy, terms and support pages |
| User-generated content shared with others | No. There is no community in this build |
| Messaging or chat | No |
| Advertising | No |
| Parental controls | No |
| Age assurance (if asked) | Yes. Age is read from the national ID number at sign-up, and under 18 is refused |

Then, where App Store Connect offers to set a **higher age rating than calculated**, choose **18+**.
Apple allows this so the rating can match the app's own minimum age. On Play, the matching answer is
**Target audience: 18 and over** (step 10, item 5).

---

## 3. App Review Information

App Store Connect, your app, the version page, scroll to **App Review Information**.

Use the second test number from `play-app-access.md`, so a Google reviewer deleting her account does not
break Apple's review. Approve it through the reviewer allow-list exactly as in `play-app-access.md`
Part 2.

| Field | Answer |
|---|---|
| Sign-in required | **Yes** |
| User name | `[TEST PHONE: +20 10 0000 0002]` |
| Password | `[TEST CODE: 123456]` |
| Contact first and last name | Mahmoud Reda |
| Contact phone | `[OWNER: a number that is answered during review; Apple does call]` |
| Contact email | `[OWNER: an inbox read every day]` |
| Attachment | Optional: a short screen recording of the ID and selfie check on a real card, with the card details blurred. It lets the reviewer see the part they cannot try |

### Notes box

Paste the box in `../review-notes.md`. It is the one current text (under 4000 characters), so it
is not repeated here.

Before pasting, change `10 0000 0002` and `123456` if you added a different number or code in Firebase.
