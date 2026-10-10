# Review notes, Own Hub 1.0.0 (account build)

App Store Connect > App Review Information. Play uses `launch-pack/play-app-access.md`, same facts.
Fill every `[OWNER]` value, then paste the box into Notes.

| Field | Value |
|---|---|
| Sign-in required | Yes |
| User name | `[OWNER: Apple test number, e.g. +20 10 0000 0002]` |
| Password | `[OWNER: its fixed 6-digit code]` |
| Contact | `[OWNER: name, a phone answered during review, an inbox read daily]` |

Before submitting: put the test number, in the form `+201000000002`, in the Secret Manager secret
`store-reviewer-phones`. Sign in once with it, finish the check once (the server approves a listed
number without reading the photos), and confirm it opens on Home. Because the list holds the number,
not the account id, it keeps working if the reviewer deletes the account and signs in again. Empty
the secret when the review closes.

```
Own Hub is a free fitness app for women in Egypt, and only for women: home workouts, meals and recipes, private period tracking and progress. No ads and no purchases.

SEE THE APP WITHOUT AN ACCOUNT
On the first screen tap "Show me around". The tour runs the real Home, Train, workout, recipe, dinner plan, My cycle and Progress screens on a sample week. Nothing is saved or sent.

SIGN IN WITH THE TEST ACCOUNT
1. On the first screen tap "I already have an account".
2. Enter [OWNER: 10 0000 0002] after +20 and tap "Agree and send me a code".
3. Enter [OWNER: code]. This is a Firebase test number: no SMS is sent and the code is fixed.
4. Answer the short setup if asked. The app opens on Home.

WHY THERE IS AN ID CHECK
Own Hub is a women-only space, and safety is the product. Each member proves once, at sign-up, that she is a woman aged 18 or over: she photographs her Egyptian national ID card and takes a live selfie. Our own server reads sex and age from the ID number and matches the selfie to the card photo. The photos are deleted when the check ends and are never stored. Sex is never guessed from a face. If the check cannot decide, or she prefers not to use the camera, a woman from Own Hub reviews her case and contacts her by phone within 72 hours.

A reviewer cannot pass that check, so this test number is on a server-side allow-list that we keep empty outside review, and the account was approved on our server before submission. The app has no bypass, hidden switch or special code. If you delete the account and sign in again with the same number, the ID screens appear once: photograph any card and follow the selfie prompts. The server approves the test number without reading the photos, and nothing is stored.

NOT IN THIS VERSION
Community, messaging, coaching and the AI assistant are switched off by flags compiled into this build. They have no entry point, cannot be turned on remotely, and would need a new build and a new review.

HEALTH
Cycle, measurements, pregnancy or postpartum stage and allergies stay on the phone unless she turns on "Back up my health data", which is off by default. Health data is never used for advertising. Own Hub is not a medical device and does not diagnose or treat anything.

WIDGETS
Long-press the Home Screen, tap +, search "Own Hub". "Your week" (small and Lock Screen) and "Today" (medium) show this week's session count and today's status from data on the phone. They never show cycle, pregnancy, weight or health data. Tapping opens Today, the workout, Progress or Eat. Before sign-in they show only "Open Own Hub to start".

DELETING DATA
In the app: the avatar on Home > Your data > Delete everything. It deletes the account and its data on our servers and clears the phone. On the web: [OWNER: https://DOMAIN/delete-account/]

The only permission is the camera, for the ID check. No tracking, no ads, no advertising ID. Usage statistics and crash reports are each off until she turns them on (phone-number screen or Privacy).
```
