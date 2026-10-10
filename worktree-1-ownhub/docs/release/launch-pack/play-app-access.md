# Play Console, App access (step 10, item 3)

Own Hub is women only. Nobody gets in without signing up with a phone number and an SMS code, then
passing a check with an Egyptian national ID card and a live selfie. Google's reviewer has neither an
Egyptian SIM nor an Egyptian ID card, so without a test path they see a sign-up screen and nothing
else, and the app is rejected for restricted access. This page gives them that path.

**The ID check cannot be passed by a reviewer.** It needs a real Egyptian national ID card and the face
of the woman on it. There is no bypass in the app and there must never be one: a hidden switch that
skips the check would also work for anyone who found it. Instead, the test account is approved on the
server before review through the reviewer allow-list, the Secret Manager secret `store-reviewer-phones`
(empty by default, read only by the server, fails closed, every use logged). Part 2 is that step.
The list holds the test numbers, not account ids, so a reviewer who deletes her test account and signs
in again with the same number is still let through. `store-reviewer-uids` also exists for an account
that has no test number; leave it empty otherwise.

Reviewers can also see the app with no account at all: "Show me around" on the first screen runs the
real screens on a sample week and saves nothing. The text in Part 3 says so.

---

## Part 1. Add a test phone number in Firebase (5 minutes)

Firebase lets you register a fictional phone number with a fixed code. No SMS is ever sent to it, it
costs nothing, and it works only with the code you set.

1. Open **console.firebase.google.com** and choose the project **own-hub**.
2. In the left menu open **Build**, then **Authentication**, then the **Sign-in method** tab.
3. Click **Phone** in the list of providers.
4. Open **Phone numbers for testing (optional)**.
5. Add the number **+20 10 0000 0001** with the code **123456**.
6. Add a second one for Apple: **+20 10 0000 0002** with the code **123456**. Two accounts means that if
   one reviewer deletes her test account (reviewers do test account deletion), the other store's
   review still works.
7. Click **Save**.

Rules for these numbers:
- Use numbers nobody owns. If you pick different ones, keep them on +20 (your SMS policy from step 6
  only allows Egypt) and never use a real person's number.
- Use a code you have never used anywhere else. Do not reuse a password.
- Send Mahmoud only "test numbers added". He already knows the numbers from this page; never send codes
  from real login screens in chat.

## Part 2. Approve the test accounts through the allow-list (before each submission)

1. In Google Cloud Secret Manager (project **own-hub**), add a new version of the secret
   `store-reviewer-phones` containing the two test numbers in international form, one per line:
   `+201000000001` and `+201000000002`. The server reads it within 5 minutes.
2. On a phone with the release build, tap "I already have an account" and sign in once with each test
   number. That creates the two accounts.
3. On the phone, carry on with each account: agree on the check screen, photograph any card with a
   printed photo and take the selfie. For a listed number the server approves without reading the
   photos, stores nothing, and records a `reviewerBypass` entry in the review access log.
4. Sign out and back in with each number, and confirm it opens on Home without the ID screens.
5. When both reviews are closed, add an empty version of the secret.

If a reviewer deletes a test account and signs in again with the same number, she gets a new account
id but the number is still listed: she goes through the ID screens once and is approved, with nothing
to do on your side.

## Part 3. Fill in the form in Play Console

Play Console, your app, **Policy and programs**, **App content**, **App access**, then **Manage**.

1. Choose **All or some functionality in my app is restricted**.
2. Click **Add new instructions** and fill it in:

| Field | Paste this |
|---|---|
| Name of instructions | `Verified test account` |
| Username, email address or phone number | `[TEST PHONE: +20 10 0000 0001]` |
| Password | `[TEST CODE: 123456]` |
| Any other information required to access your app | the text in the box below |

3. Click **Apply**, then **Save**.

Replace the two bracketed values with the number and code you actually added in Part 1, and remove the
brackets.

### Text for "Any other information required to access your app"

```
Own Hub is a fitness app for women in Egypt, and only for women. For their safety, members sign in with a phone number and an SMS code, then pass a one-time check with an Egyptian national ID card and a live selfie. A reviewer cannot pass that check, so this test number is approved on our server through a server-side allow-list. There is no bypass in the app. After deleting the account and signing in again, take any photos once; the number is approved.

To look around without an account: tap "Show me around" on the first screen. It shows the real screens on a sample week and saves nothing.

To sign in: tap "I already have an account", enter 10 0000 0001 after the +20, tap "Agree and send me a code", then enter the code 123456. No SMS is sent; the code is fixed. The account opens on Home: Train, Eat, Cycle and Progress. Community, coaching and the assistant are off in this version.

The card and selfie photos are never stored. To delete the account: avatar on Home > Your data > Delete everything.
```

Before pasting, change `10 0000 0001` and `123456` if you used a different number or code in Part 1.
The text is 1010 characters. If Play says it is too long, delete the last paragraph, then the
one about looking around.

---

## If Google writes back

| They say | Answer |
|---|---|
| "We could not sign in" | Check the number and code in Firebase match the form exactly, and that Part 2 is done for the account. Then reply with the same instructions |
| "The app asks for an ID card" | The number is missing from `store-reviewer-phones`, or the secret was emptied. Do Part 2 for it, then reply. After a deleted and recreated account the ID screens appear once and pass on their own |
| "Is a women-only app allowed?" | It is a membership model, like a women-only gym, for women in Egypt who will not train in mixed spaces. Sex and age are read from the national ID number, never guessed from a face |
| "Why do you need a government ID?" | To keep the app women only and 18 and over. The photos are never stored; only a one-way code of the ID number is kept, so one card cannot open two accounts |
