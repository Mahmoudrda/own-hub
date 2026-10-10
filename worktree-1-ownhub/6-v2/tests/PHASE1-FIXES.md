# Phase 1 — defects found and fixed

Written for whoever picks this up next, including an AI agent with no memory of
the session that made these changes. Each row is a defect that **a fully green
test suite did not catch**, which is the part worth learning from: in every case
a test existed, passed, and asserted the wrong thing.

Suite at the time of writing: **476 tests, all passing**, `flutter analyze`
clean.

---

## 1. R08 "Change a set" saved nothing at all

**What she saw.** She corrected 12 kg × 10 to 14 kg × 9, tapped Save, and R09
announced *"Set 2 saved · 12 kg × 10"* — the numbers she had just overridden.

**Root cause.** `ChangeSetView.onSaved` handed a `ChangedSet` to the router,
which assigned it to a field named `lastChangedSet` that **nothing ever read**.
No repository write, no bus submit. The field was not even declared — it was an
undefined identifier that only surfaced as a compile error later.

**Fix.** `ChangeSetView` now owns its own `LogCommandBus` and `TrainRepository`
(mirroring `MidSetView`), submits an `UndoableLog` describing *her* numbers, and
hands the `LogHandle` to the router, which carries it to R09 as a route
argument.

**Why the old test passed.** It asserted the callback's argument — `saved!
.outcome.weightKg == 14` — which was correct and always had been. The argument
was right; nobody was listening. The test now asserts against
`repository.flushes`, so "nothing was written" cannot pass again.

Covers `P0-LOG-05`, `P1-RULE-09`.

---

## 2. R09's rest clock never ticked

**What she saw.** A timer frozen at 0:38. It never counted down, never ended,
and "Add 30 seconds" did nothing at all.

**Root cause.** `RestingView` was a `StatelessWidget` holding
`const Duration(seconds: 38)`. There was no `Timer`, `Ticker` or
`AnimationController` anywhere in the file — while its own doc comment promised
"the timer starts itself, ends itself". Separately, the "+30 seconds" button
bound to `onAddThirtySeconds`, which **the router never passes**, so it rendered
permanently disabled.

**Fix.** Stateful, with a one-second periodic tick that stops at zero and calls
`onReady` — so rest ends without a tap, which is the screen's entire premise.
"+30 seconds" applies the time itself and grows `total` alongside `remaining`,
or the progress ring would run backwards past full.

**The testing trap, recorded because it will recur.** A live tick schedules a
frame every second, so `pumpAndSettle()` on a running clock **never settles** —
it pumps until it times out. Adding the timer naively turns a green suite into a
hanging one. Hence `autoStart`: the seven layout tests pass `false` and assert a
static frame; the countdown tests leave it `true` and drive the clock with
explicit `pump(duration)` calls.

---

## 3. C13 told every woman the mockup's "74 seconds" as a fact

**What she saw.** *"Verified in 74 seconds."* — on the screen where she is most
likely to believe what the product tells her, and directly alongside the rule-7
deletion promise it is meant to reinforce.

**Root cause.** `YoureInView.verifiedInSeconds` defaulted to `74`, the
prototype's sample. The router passed nothing. And it could not have passed
anything real: **nothing anywhere recorded when a check started** —
`VerificationChecking` had no fields, and `VerificationResult` had `decidedAt`
but no start time, so the duration was not derivable.

**Fix.** `VerificationChecking.startedAt` and `VerificationResult.startedAt`,
with `Duration? get took`. `CheckingView.onVerified` now carries the
`VerificationResult` upward instead of discarding it; the router keeps it and
passes `took?.inSeconds` to C13.

**The part that matters.** `verifiedInSeconds` is now **nullable**, and null
renders a duration-free variant of the same sentence. If we did not measure it,
the screen says nothing about it. A sentence that says less is better than one
that says something untrue.

---

## 4. Weights rendered as "14.0 kg"

**Root cause.** `gen-l10n` interpolates a placeholder with no `format` directly
into the message, and her chosen weight comes off a `List<double>`, so agreeing
to 14 kg produced `14.0`.

**Why the obvious fix was wrong.** Adding `format: decimalPattern` makes
`NumberFormat` emit **Eastern Arabic digits** under an `ar` locale, which breaks
`P0-A11Y-01` — the Arabic dictionary uses Western digits in all 457 of its
values containing a number.

**Fix.** The placeholder is a `String`, formatted by `weightLabel()` — plain
Dart, Western digits in every locale, exactly the rule `clockLabel()` already
documented for timers.

---

## 5. Arabic verb agreement in a templated sentence

**Root cause.** Parameterising "{move} saved · {sets} sets" produced Arabic
`حُفظ {move}` — but an Arabic verb agrees in gender with its subject, and the
subject here is a move name that varies across all 124 of them. No single
conjugation is correct for every move.

**Fix.** Restructured to `تم حفظ {move}`, which requires no agreement.

**Expect this again.** Every parameterised Arabic string in Phase 2 faces the
same constraint, plus the reverse problem: Arabic has six plural categories to
English's two, so `{sets} مجموعات` is wrong for one, two, and eleven-plus.
`PHASE2-ACCEPTANCE.md` §5 lists ~14 rows that will need it.

---

## 6. C07 was correct but unpinned

`CodeView` already showed the number she typed, read from `AuthAwaitingCode`.
Nothing asserted it, and the file's own header still claimed the opposite
("`AppL10n` has no parameterised messages at all"). Tests added in both locales;
two stale doc comments corrected.

---

## 7. The generator wrote somewhere the app does not read

**Root cause.** `build-flutter.mjs` writes to `6-v2/flutter/`, and **no script
copied those files into `app/lib/`**. That copy was being done by hand.

**Why it cost an hour.** Forgetting it fails *silently*: `flutter gen-l10n`
happily re-reads the stale ARB still sitting in `app/lib/l10n/`, so a corrected
string appears not to have been corrected, and the debugging goes into a
generator that was already right.

**Fix.** `build-flutter.mjs` now writes through to the app itself and reports
what it synced. A documented manual step can be forgotten; this cannot.

---

## 8. R07's button named the prototype's set, not hers

**What she saw.** *"Done — 12 kg × 10"* — whatever her plan actually prescribed.
Tapping it logged the numbers from her real prescription, so the button and the
log could disagree: the screen showed her one set and saved another.

**Root cause.** The label was `l10n.done12Kg10`, a fixed dictionary string,
while `_logOneSet` independently read `move.sets[widget.setIndex]`. Two sources,
one of them constant.

**Fix.** A parameterised `doneWeightKgReps({weight}, {reps})`, and — more
importantly — **one shared accessor**. The label and the log now read the same
set through `_prescribedOf(move)`, so they cannot drift apart. That accessor is
also bounds-checked: the raw index would have thrown during *build* for a move
with fewer sets than `setIndex`, taking the whole player down mid-session, and a
crash on render is worse than a crash on tap.

**Why the old tests could not catch it.** The default move is goblet squat
12 kg × 10, so the parameterised label renders **byte-identical** text. All five
existing assertions pass before and after the change. Only a *different*
prescription distinguishes a real label from a constant one, which is what the
new test uses (20 kg × 8).

---

## 9. The status bar was unreadable on most screens

**What she saw.** The clock, wifi and battery in near-white on the pale pink
surface — effectively invisible. Not on every screen: any screen with a titled
app bar was fine, which is why it looked like a rendering fluke rather than a
defect.

**Root cause.** Nothing in the app set `SystemUiOverlayStyle` anywhere.
`AppBar` derives status-bar brightness from its own background colour when none
is given, and **both** of this product's top bars (`AppTopBar`, `TrainTopBar`)
are deliberately `Colors.transparent` — so they asked iOS for light status-bar
content over a light background.

**Fix, in two halves, because one is not enough.**
`appBarTheme.systemOverlayStyle` in the generated theme covers screens that have
an app bar; `SystemChrome.setSystemUIOverlayStyle` in `main()` covers the ones
that pass `appBar: null` — C13 among them — which `appBarTheme` cannot reach.

**Note for whoever edits the theme next.** `buildTheme` is **generated**, from
the template inside `6-v2/src/build-flutter.mjs`. Editing
`app/lib/theme/app_tokens.dart` directly works until the next regeneration and
then silently reverts.

---

## 10. The bottom navigation bar on Home did nothing

**What she saw.** She finishes sign-up, lands on Home, taps **Train** — and nothing
happens. Same for Community and Eat. The app's primary navigation was inert on the
first screen she sees.

**Root cause.** `TodayView` declares `onSelectTab` and hands its `AppNavBar` an
`onSelect` that calls it. The `T01` route block never passed it, so the callback was
null and every tab tap fell on the floor. Four other callbacks were unwired in the
same block: `onOpenPlate`, `onTellUsWhatYouEat`, `onOpenBeginnersGroup` and
`onOpenFirstWeek`.

**Why every test passed.** `app_nav_bar_test.dart` builds `AppNavBar` **directly and
supplies its own `onSelect`**, so it proved the bar reports taps correctly — which was
never in doubt. Nothing tested that the app's own screens actually pass one in. A
component test cannot see a missing argument at the call site.

---

## 11. T07 was built, routable, and reachable by nobody

**Root cause.** `onOpenFirstWeek` was unwired, and T07's only designed inbound edge is
from **T06** — "Home, day one" — which is a *state* of `TodayView` rather than a
separate destination. So the one door into the first-week arc was a callback nobody
passed.

It was briefly misdiagnosed as blocked on Phase 2. It was not; it was one line.

---

## 12. R06 was unreachable — all three entry tiles were inert

**Root cause.** `TrainView` renders three "Short ones that still count" tiles, and the
design puts `data-go="R06"` on the first of them (10 min · Floor only — the timed
follow-along that logs itself). `ShortSession` already carried an `onTap` field. All
three tiles were constructed without one, so the cards rendered, looked tappable, and
did nothing.

**How all three were found.** By writing `nav_reachability_test.dart` — the first test
of any kind against `P0-NAV-01`, which until then was the only P0 case with no test at
all. It recovers the navigation graph from the router and measures tap depth. Two-tap
reachability was **63%**; wiring these three defects took it to **79.2%**.

**What it did not do is hit the 80% bar**, and that is recorded in `DECISIONS.md` as an
owner decision rather than fixed by editing the threshold. What remains beyond two taps
is the workout player (`R08`, `R09`, `R10`, `R13`) plus `E08`, and a session is a
sequence — no navigation design puts "Resting" two taps from a tab root.

---

## 13. Four screens stated the prototype's numbers as her personal facts

Found by an independent QA pass, not by the suite. **The third and fourth occurrences of
the class already fixed in #3 (C13's invented "74 seconds") and #8 (R07's fixed label).**

**Eat, E01/E04.** `eat_view.dart` chose between two fixed dictionary constants on
`justLogged == null` — so the totals changed when she logged *anything* and never
reflected what she ate. Meanwhile `DayCard` drew its protein bar from the real
`totals.proteinPercent`. **The bar and the sentence beside it came from different sources
and disagreed for every woman**: a 460 kcal lunch read "About 1,106 kcal so far today".

**T01.** The week line was two finished sentences — "This week, 0 of 3" and "This week,
1 of 3" — selected by `sessionsLogged == 0`. It never counted past one, and a woman whose
goal was four read "0 of 3" while the ring immediately below drew four segments from the
same object.

**Fixed structurally, not textually.** `DayCard` no longer *accepts* `proteinLabel` and
`kcalLabel`; it derives them from the `totals` it already holds. Handing a card both a
number and a sentence about that number is an invitation to disagree, so the parameters
were removed rather than corrected — a disagreement is now unrepresentable. T01 uses a new
parameterised `thisWeekDoneOfTarget(done, target)` fed from the same object as the ring.

**`proteinDelta` now renders nothing.** It was a fixed "+31 g", and nothing computes a
delta: a `LogHandle` carries a description and an undo, and `EatDayView` exposes current
totals with no before/after pair. An existing test asserting "+31 g" appeared was deleted,
not satisfied.

**Why the tests missed it, twice.** `eat_view_test.dart` asserted
`textContaining('so far today')` — true of a computed sentence and of a constant alike.
And every `today_view` test uses the default 1-of-3 fixture, where the parameterised output
is **byte-identical** to the old constant. Both replacements now use figures that differ
from the prototype's (a 2-of-4 week; totals derived from the seeded meal), because only a
different number can tell a computation from a constant.

**T04 and T05 are NOT fixed, deliberately.** They state "Your 14 weeks are safe", "Your 14
counted weeks", "Level 7" — and their views receive no week count, tier or level at all.
There is nothing to parameterise from, and inventing data to fill a placeholder is the very
defect being fixed. Recorded in `DECISIONS.md` as a copy decision for the owner; T05 also
contradicts D6 directly.

---

## 14. The rule-7 guard was written, and could never have fired

Rules 3, 8, 9 and 11 each had an executable source scan. Rule 7 — *the ID photo and the
selfie are deleted* — had only copy assertions on three screens, so nothing stopped
`String? idPhotoUrl` being added to `VerificationResult` with the suite fully green. QA
called it the most valuable missing guard in the codebase.

The guard written for it **did not work**. The pattern ended in `\b`, so `idPhotoUrl` never
matched: the boundary would have to fall between `Photo` and `Url`, and both are word
characters. Three of six realistic offenders slipped through — every identifier that
continues past the banned suffix, which is most of them.

**It was caught by its own positive control**, written alongside it precisely because a
source-scanning guard that matches nothing is indistinguishable from one that works. This
codebase had already shipped exactly that: the rule-9 scan passed for weeks by not looking
at `lib/features/train/`.

The lesson is narrow and worth keeping: **a new guard needs a test proving it bites before
it is trusted to protect anything.**

---

## The pattern worth taking away

Three of the nine defects above — the blank white screen, the frozen clock, and
the invisible status bar — **could not be caught by any widget test**, and were
found by taking a screenshot and looking at it. Two more (R08 writing nothing,
R07's fixed label) had passing tests over them the whole time, because the tests
asserted the thing that was already correct.

The suite is necessary and it is not sufficient. Build it, run it on a
simulator, and look at the screen.

---

## Still open at the end of Phase 1

- **The 29 error, offline and permission strings are referenced by zero views.**
  Verified directly against the source, not taken from a report:
  `i18n/msa/14-states.json` carries wrong-code, expired-code, offline, retry,
  camera, microphone and notification-permission copy in both languages, and no
  screen in the app references any of it. In a product whose core promise is
  that logging never requires signal, there is currently no offline UI at all.
- **Permission request copy is absent entirely**, which blocks the camera and
  microphone flows Phase 2's E03 needs.
- **8 acceptance cases remain NOT COVERED.**
