# Setting this up on your machine — exactly what to do

Written for someone who has not done any of it before. Every step says **why**, so you can skip the
parts you do not need yet.

**You do not need any of this to look at the app.** It runs today on a simulator with no account, no
Firebase and no internet:

```bash
cd ~/womens-fitness-app-wireframe/app
flutter run
```

You need what follows when you want the app to **remember things between launches**, and when you want
the security rules to be **actually tested** rather than only written.

---

## Part 1 — Accounts to create

### 1.1 A Google account → Firebase
**One account, and you probably already have it.** Firebase is Google's, so any Google account works.

1. Go to **https://console.firebase.google.com**
2. Sign in with your Google account.
3. Click **Add project**. Name it `own-hub` (the name is yours; it becomes part of the project id).
4. It will ask about **Google Analytics** — say **no**. This product deliberately sends nothing personal
   to analytics, and `DECISIONS.md` records what may never be sent. Turning it on here creates a second
   pipe nobody reviewed.
5. Once created, you land on the project dashboard. Leave it open for Part 3.

**Cost:** the free "Spark" plan is enough for development. You are not asked for a card until you exceed
it. Cloud Functions on the free plan are limited — when you get to Part 4 you may be asked to upgrade to
**Blaze** (pay-as-you-go), which for a project with no users costs essentially nothing, but it does want
a card.

### 1.2 An Apple ID — only for a real iPhone
Not needed for the simulator. Only if you want the app on a physical device. A free Apple ID lets you
install on your own phone for 7 days at a time; the **$99/year Apple Developer Program** is required to
put it on the App Store or on someone else's phone.

### 1.3 A Google Play Console account — only to publish on Android
**$25, one time.** https://play.google.com/console — not needed for development.

---

## Part 2 — Installs

Run these in Terminal. If you do not have Homebrew, install it first from **https://brew.sh**.

### 2.1 A Java runtime — **the most important one**
```bash
brew install --cask temurin
```
**Why:** the Firebase emulator is a Java program. Without it, **no security rule in this project has
ever been executed** — they are checked as text, which proves a line is present and proves nothing about
whether it lets someone in. This is the single largest gap in the project.

Check it worked:
```bash
java -version
```

### 2.2 Node.js and the Firebase tools
```bash
brew install node
npm install -g firebase-tools
```
**Why:** `firebase-tools` runs the emulator and deploys the rules. Node also runs this project's own
content generators in `6-v2/src/`.

Check:
```bash
firebase --version
```

### 2.3 Xcode and Android Studio
You already have both, since the app builds for iOS and Android. Nothing to do.

---

## Part 3 — Connect the app to your Firebase project

### 3.1 Log in
```bash
firebase login
```
Opens a browser. Approve with the same Google account from 1.1.

### 3.2 Point the repo at your project
```bash
cd ~/womens-fitness-app-wireframe
firebase use --add
```
Pick `own-hub` from the list and give it the alias `default`.

`firebase.json` already exists and already points at the rules, the indexes and the storage rules — that
part is done.

### 3.3 Turn on the two services, in the console
Back in **https://console.firebase.google.com**, in your project:

* **Build → Firestore Database → Create database.** Choose **production mode** (this repo's rules
  replace the defaults immediately). For location pick **`europe-west1`** or **`eur3`** — closest to
  Egypt among the standard options; Google has no Egyptian region.
* **Build → Storage → Get started.** Same location.

### 3.4 Deploy the rules and indexes
```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```
**Why the indexes matter as much as the rules:** Firestore indexes every field automatically. The
exemptions in `firebase/firestore.indexes.json` are what stop `periods.stillBleeding` — a flag true for
exactly the women currently bleeding — from being queryable across every user. Deploying rules without
indexes leaves that open.

---

## Part 4 — Run the rules for the first time

```bash
cd ~/womens-fitness-app-wireframe
firebase emulators:start --project demo-own-hub
```

`demo-` as a prefix means it runs **entirely on your machine**, needs no real project and cannot touch
production data. Use your real project id only when you mean to.

A dashboard opens at **http://localhost:4000**.

**What this unblocks:** every security-rule case, and `P0-DEL-01` — "delete my account and nothing
survives" — which is currently marked NOT COVERED for exactly this reason.

**Still missing after this**, and it is code rather than setup: `functions/` does not exist. Three Cloud
Functions are specified and none is written — the account-deletion callable, the notification writer,
and `getCycleProjection`. `P0-DEL-01` needs the first.

---

## Part 5 — Make content management fully live

The admin console (Z01–Z13) can now store what it is given, and it **starts stocked**: 56 seeded rows
— 20 foods, 23 exercises, 9 recipes, 4 programmes — so the screens show a real library rather than an
empty one. Recipes and programmes can be authored one at a time (Z12, Z13) as well as by CSV import.

It stores all of it **in memory**, so anything you add is gone when the app restarts. Two things make
it durable, and both are code, not setup:

1. **A Firestore implementation of `ContentRepository`.** The interface exists and the in-memory one
   works; a Firestore one drops in behind it with no screen changes.
2. **A file picker,** so a CSV can be chosen and videos and images actually uploaded:
   ```yaml
   # app/pubspec.yaml, under dependencies:
   file_picker: any
   archive: any        # for the export bundle; already in your local pub cache
   ```
   ```bash
   cd app && flutter pub get
   ```
   Today both are **honest seams**: the buttons render visibly disabled rather than silently doing
   nothing, and `MediaPicker`/`TextSource` are one class away from working.

   One known gap when you do this: `MediaFile` carries a name, a size and a kind — **not the bytes**. A
   real picker needs a content channel added beside it, and nothing uploads to Cloud Storage yet.
   `storagePathFor()` already names the destination safely.

---

## The order I would do it in

| | Step | Unblocks |
|---|---|---|
| 1 | Java (2.1) | Rules can run at all |
| 2 | Node + firebase-tools (2.2) | Emulator and deploys |
| 3 | Firebase project (1.1, 3.1–3.3) | A real backend |
| 4 | Deploy rules + indexes (3.4) | The safety guarantees become real |
| 5 | Emulator (Part 4) | `P0-DEL-01` and every rules case become testable |
| 6 | Cloud Functions | Account deletion actually deletes |
| 7 | Firestore repository + picker (Part 5) | Content survives a restart; media uploads |

Steps 1–5 are an afternoon. Steps 6–7 are development work, and neither needs an account.
