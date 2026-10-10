# Own Hub — QA report

Date: 2026-09-23 · Companion to `01-PLAN.md`

This is what was tested, what was found, what was fixed, and what is still not possible in a build
with no backend. The last section is the guide for testing it by hand.

## How it was tested

Four instruments, all repeatable:

| Instrument | What it does | Command |
|---|---|---|
| Tap-everything crawler | Opens all 161 screens over Home and taps every control a screen reader can see, one at a time, recording what each tap did: navigated, changed the screen, opened a sheet, showed a snackbar, focused a field, went back, or did nothing. | `OWNHUB_QA_REPORT=/tmp/crawl.tsv flutter test test/qa/tap_crawler_test.dart` |
| Journey tests | Boot the real app with no account required and walk a whole feature the way a woman would, asserting what she sees afterwards. | `flutter test test/journeys` |
| The full suite | Every unit, widget, guard and product-rule test. | `flutter test` |
| Large-text sweep | Opens all 161 screens at 1.6x text and fails on any overflow. | `flutter test test/qa/large_text_sweep_test.dart` |
| Both platforms by hand | iPhone 17 simulator and a Pixel 8 emulator, English and Arabic, normal and extra-large text. | see the guide below |

## Where it ended up

| | |
|---|---|
| `flutter analyze lib test` | clean |
| `flutter test` | 3,553 tests, all passing |
| Tap crawler, all 18 flows | 1,102 taps, zero exceptions, zero placeholder screens |
| Large text, all 161 screens | no overflow at 1.6x |
| iPhone 17 simulator | English and Arabic, both walked |
| Pixel 8 emulator | English, walked |

The taps that still report "no visible effect" are all an already-selected option being tapped again
(the first chip, the open tab, the current filter), which is the correct no-op.

The first crawl, before this round of work, found that much of the app was a shell: screens drawn
from fixed prototype values, buttons with no callback behind them, and six routes that opened a "not
built" panel. Everything below was found by the crawler, the journey tests or a pair of eyes on the
simulator, and fixed.

### Whole features that did not work, and now do

| Area | What was wrong | What it does now |
|---|---|---|
| A workout | R07 handed back the same move and the same set forever; finishing changed nothing anywhere. | A session holds the thread: start, log a set, rest, advance move by move, finish. The week, the points and the level agree on Home, Train and Progress, and one session can never count twice (dedupe by session id in the week rollup, the award ledger and Today's own copy). |
| Eat | Every Eat screen logged into its own corner; the after-log screen opened before the log landed; Home's meal card never reflected Eat; "your usual" stayed empty forever. | One log session across the whole tab, with a live five-second undo. Home's plate card logs (it used to only navigate). Logging something twice makes it a one-tap plate. Recipe filters read the same numbers the cards state. Allergies saved in the profile now reach Eat. |
| Community | Nothing could be posted; likes, saves, comments, follows, joins, filters, report and mute were all inert. | She writes a post and it is in the feed, on her profile and opens as a post. Every action is wired to the same store, so what she does in one place is true in the others. |
| Coach page | Every editor dropped her edits; Publish was disabled. | Sections, cover, look, offers, method, results and media all save, and the page publishes. Picking a palette, a typeface or a corner style now shows as chosen and reaches the published page; the three typeface cards are drawn in the pairing each one offers. |
| Finding a coach | The directory was hard-wired to "unavailable". | The coach published in this session is in the directory, her page and packages open, and enquiring or paying (test payment) reaches her desk. |
| The coaching loop | No enquiry ever arrived, the client list was always empty, planner edits were dropped, "Publish the plan" opened a "not built" page. | Enquiry lands on the desk, accept makes her a client, the month is planned and published, and the client sees *that* plan: trains it, logs a planned meal, chats, answers the weekly review. |
| Cycle | Home's cycle card never appeared. | It appears once the cycle is set up, and symptom-only mode shows no dates and no estimates. |

### Screens that opened on a placeholder

W08 (publish the plan), B12 (insights), K22 (re-assessment) and H06 (chat in the coaching tab) were
in the route table with nothing behind them. All four are built. H06 is the same conversation as G14,
read from and written to the same thread: two doors, one room.

### Controls that looked alive and were not

- **The undo bar never closed.** `SnackBar.persist` defaults to on whenever the bar has an action, so
  every undo offer in the product (Eat, Today, Progress) stayed on screen long after its five seconds
  had passed and tapping Undo had become a no-op. One line; all three are correct now.
- **The admin console**: the four content tabs did not redraw the screen, and "Export the content
  library" was not wired at all. Both work; the export copies CSV to the clipboard and says so.
- **Sign-up**: "Continue" on the code screen looked live and silently did nothing on a short code, and
  "Send it again" gave no feedback. Continue is now disabled until six digits are in, and the resend
  confirms. The one code this build accepts is now named on screen, so the sign-up chain can be
  walked by hand.
- **The planner opened without a client** offered chips that could not save. It now opens on its own
  day-one state with a way through to her clients, or on her longest-waiting client.
- **The assistant's send button** was live but unlabelled and inert. It is named and disabled, which
  is the truth: the assistant is not connected.
- **A follow-up thread's like and save** were callbacks that returned null, so they drew as available.
  They are absent now when there is no moment to act on.

### Things that were quietly wrong

- P01 showed "Personal bests 0 of 0" with a full bar, because "no target" returned 100 per cent.
- The first-week arc numbered every day zero.
- R01's ring was hard-wired to "2/3" whatever the week held.
- Screens were drawn once from shared data, so coming back from a screen showed stale content.
  Every routed screen now redraws when shared state changes.

### Accessibility

Back buttons had no name for a screen reader. Chips, segments and chosen cards did not announce
selection. The coach's six palettes were six unlabelled swatches. The profile's tabs were drawn as
chosen but never said so. All fixed.

Text scaling is now swept by a test rather than by hand. The redesign fixed twelve screens that
overflowed at extra-large text; the sweep found one more, R10, where the hand-painted points note and
the level bar shared a line and ran 111 pixels off the right at 1.6x. Past 1.3x the bar now sits
under the note. All 161 screens are clean at 1.6x.

### The copy

Every em dash and en dash is gone from the product's text, in both languages: 104 strings rewritten
by hand. Date ranges read "8 Sep to 7 Oct", clauses are joined by a comma, a full stop, a colon or
the middle dot the app already used, and the Arabic uses `،` and `إلى` rather than a dash it never
wanted. Two labels that named the prototype's client to every coach ("Note for Nour", "Save and
apply to Nour") are neutral now. Three places in code joined values with a dash; two say "from x to
y" in her own language, and a set she has not logged says "Not yet" instead of drawing a dash.

The rest of the copy was scanned for the usual machine tells (seamless, journey, unlock, empower,
elevate, curated, "not just x but y", exclamation marks, emoji) and had none.

### Content gaps, for the owner rather than the code

These are places where the code is right and the content behind it is missing:

1. **No dish lists its allergens.** The moment a woman saves an allergy, Eat can suggest nothing and
   log nothing, because unknown is treated as unsafe. The screens now say so out loud instead of
   going blank, but authoring `foods.allergens[]` is what makes the Eat tab usable for her.
2. **Recipes and foods are two separately authored sets.** Four of seven recipe ids name a dish the
   food pack does not carry, so those recipes cannot be logged. The screen names the recipe she
   tapped and says it cannot be logged, rather than logging a different dish.
3. **No exercise library for coaches**, so a planned session carries a name, a length, a rest and her
   note, but no move rows.

## Known limits of this build

These are not defects. There is no backend yet (Firebase comes later), and this build deliberately
refuses to fake the things it cannot do:

- **No camera, gallery, microphone or file picker.** Anything that needs a photo, a video, a voice
  note or a file says so instead of pretending: the portfolio's media slots, the community's photo
  and voice posts, the coach's voice reply on a weekly review, the ID and selfie steps of sign-up.
- **No SMS.** Sign-up's code screen names the one code this build accepts, and says it is a test.
- **No payment provider.** Paying a coach uses a clearly labelled test provider that moves no money
  and is only available while no account is required. Earnings stay unavailable rather than zero
  until a test payment settles.
- **No assistant.** The assistant screen says it is not connected yet rather than inviting a
  question that would go nowhere. The API key never ships in the app; it will be read by a Cloud
  Function.
- **No exercise library for coaches.** A coach can name a session, set its length, its rest and her
  note, but cannot yet prescribe individual moves: a planner selects from a library and never
  invents, and the library is empty in this build.
- **Exporting files.** The admin console copies CSV to the clipboard, because this build cannot
  write files.

## Testing it by hand

### Run it

```sh
cd ~/womens-fitness-app-wireframe/app
flutter run                      # English
flutter run --dart-define=OWNHUB_LOCALE=ar   # Arabic
```

The app opens straight onto Home as a guest who holds **both** roles, trainee and coach. There is no
sign-up and no login: `Feature.accountRequired` is off. Sign-up still exists and can be looked at
(see "All screens" below) — it is simply not a gate.

> **This changed on 23 September.** The first release ships without accounts at all, so that flag
> stays off and `FeatureFlags.shipped` now describes a smaller product: Today, Train, Eat, My cycle
> and Progress. The community, the coach side, payments, the assistant and the admin console are off
> until there is a back end. The testing affordances no longer key off that flag, because it is now
> the shipping shape: they need a debug build. See `test/release_readiness_test.dart` and
> `tool/release_preflight.sh`. To walk the whole product, run the tests, which build
> `FeatureFlags.everything`.

### Move between the two sides

Tap your picture in the top corner: **Training**, **Coaching**, **Your profile**. The coach side has
its own navigation (desk, clients, chats, earnings) and the same switcher to come back.

### Every screen, by name

Profile → **All screens**. It lists all 161 screens by id and title, grouped by flow, including
sign-up, onboarding and the admin console — anything that is otherwise behind a first run or a deep
link. It exists only while no account is required.

### The walks worth doing

1. **A session.** Home → Train → start today's session → log a set, rest, log the rest of them →
   finish. Then check Home, Train and Progress: the week count, the points and the level agree, and
   finishing twice never counts twice.
2. **A meal.** Eat → log something by plate → the undo bar gives you five seconds → Home's meal card
   and E01 both show it. Log the same thing twice and it becomes a one-tap plate.
3. **The community.** Write a post → it is in the feed, on your profile, and opens as a post → like,
   save, comment, follow, join a group, filter, report, mute.
4. **Build a coach page.** Switch to Coaching → set up the basics and packages → add sections, write
   them, pick the look → publish.
5. **Find a coach.** Switch back to Training → Coaching tab → the directory lists the coach you just
   published → open her page, her packages, enquire or pay with the test payment.
6. **Be a coach with a client.** Switch to Coaching → the enquiry is on your desk → accept → plan
   her month → publish the plan.
7. **Be the client.** Switch back → the plan you just published is the plan you see → train a
   session from it, log a planned meal, send a message, answer the weekly review.
8. **Your cycle.** Set it up → the card appears on Home → log a day → symptom-only mode shows no
   dates and no estimates.

### What to look at while you walk

- Nothing should ever read as a placeholder or a number that was not yours.
- Arabic is Modern Standard Arabic addressed to a woman, right to left, with Western digits.
- Large text: iOS Settings → Accessibility → Display → Larger Text, or
  `xcrun simctl ui booted content_size accessibility-extra-large`. Nothing should overflow.
