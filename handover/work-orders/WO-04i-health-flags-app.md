# WO-04i: ask about pregnancy and eating history; show every flag to Rahma; hold plans until she has read them (C9, app)
Depends on: WO-04h
Size: L
Reads first: `app/lib/features/private_coaching/domain/subscription.dart` lines 14-60, 125-150 and the `class Subscription` (`grep -n "class Subscription " -A60 app/lib/features/private_coaching/domain/subscription.dart`); `app/lib/features/private_coaching/presentation/member/join_coach_sheet.dart` lines 100-150 and 330-420; `app/lib/features/private_coaching/presentation/desk/coach_desk_view.dart` lines 390-410 and 460-470; `app/lib/features/private_coaching/presentation/desk/client_detail_view.dart` lines 60-110, 160-262; `app/lib/features/private_coaching/presentation/desk/desk_widgets.dart` lines 318-380 (`IntakeAnswersCard`); `app/lib/features/private_coaching/presentation/coach/coach_text.dart` (`coachFailureText`)

## Why
Rahma must see every health, pregnancy and eating-history answer before she sends a plan. Today the join sheet asks seven health questions only, K07 flags only those, and nothing stops a plan going to a flagged woman. After WO-04h the server holds plans until Rahma ticks that she read the answers; this order makes the app ask, show and let her tick.
Injuries: the existing question "Do you have a bone or joint problem..." (`boneJoint`, `healthQuestionLabel`, `join_coach_sheet.dart:56`) already covers injuries; the new check-in question "Any pain or injury this week?" (WO-04e) covers new ones. No new injury question.

## Final result
Join sheet (client), after the seven health questions and before the doctor tick, two new questions, each shown like the others (label, then two chips):
1. EN "Are you pregnant, or did you have a baby in the last 12 months?" / AR "انتي حامل، ولا خلّفتي في آخر 12 شهر؟" Chips: EN "No", "Pregnant", "Had a baby" / AR "لأ"، "حامل"، "خلّفت من قريب". (Chip mapping: No -> no stage; Pregnant -> `lifeStage: "pregnant"`; Had a baby -> `lifeStage: "postpartum"`.)
2. EN "Has food or weight ever felt out of control or worrying for you?" / AR "الأكل أو الوزن حسّيتي قبل كده إنه خارج عن السيطرة أو بيقلقك؟" Chips: EN "No", "Yes" / AR "لأ"، "أيوه". Muted line under it: EN "Your coach reads this first. You do not have to say more." / AR "مدرّبتك بتقراه الأول. مش لازم تقولي أكتر."
Any "Pregnant", "Had a baby" or eating "Yes" shows the same doctor tick as a health yes (EN "I will check with my doctor before I start" is the existing string `iWillCheckWithMyDoctorBefore`) and its explanation line. The sheet's Send button stays disabled until the two new questions are answered too. Extra taps: 2. The whole join form stays under 3 minutes.
Rahma, K07 request card: the existing "Health answers to read first" line now also shows for the two new flags. Details sheet and client page (W02) show two extra lines in the answers card: EN "Pregnant" or "Had a baby in the last 12 months" and "Food or weight has felt worrying" / AR "حامل" أو "خلّفت في آخر 12 شهر" و"الأكل أو الوزن كان بيقلقها".
W02 (client page), for a flagged client she has not marked as read, at the top under the header, ONE card: title EN "Read her health answers first" / AR "اقري إجاباتها الصحية الأول"; body EN "Plans are on hold until you have. Her answers are below." / AR "الخطط واقفة لحد ما تقريها. إجاباتها تحت."; one outlined button EN "I have read them" / AR "قريتها". While the card shows, "Share a workout" and "Share a meal plan" are disabled (Message and Schedule stay on). Tap "I have read them" (1 tap): the card disappears, the two buttons turn on. If the server still refuses a publish (old data), the share screens show EN "Read her health answers first. Open her page and tick that you have." / AR "اقري إجاباتها الصحية الأول. افتحي صفحتها وأكدي إنك قريتيها."

## Files to edit or create
| path | action | what changes |
|---|---|---|
| `app/lib/features/private_coaching/domain/subscription.dart` | edit | `Intake.eatingHistory`, `anyFlag`; `Subscription.healthReviewedAt` |
| `app/lib/features/private_coaching/domain/health_review.dart` | create | store for `review_client_health` |
| `app/lib/features/private_coaching/presentation/member/join_coach_sheet.dart` | edit | two questions |
| `app/lib/features/private_coaching/presentation/desk/client_detail_view.dart` | edit | hold card, disabled buttons |
| `app/lib/features/private_coaching/presentation/desk/desk_widgets.dart` | edit | answer lines; flag test |
| `app/lib/features/private_coaching/presentation/desk/coach_desk_view.dart` | edit | `flagged` uses `anyFlag` |
| `app/lib/features/private_coaching/presentation/coach/coach_text.dart` | edit | `healthNotReviewed` text |
| tests (see table) | edit/create | |
(Eight code files: if the agent wants smaller steps, do the desk files as WO-04i2.)

## Steps
1. `subscription.dart`, class `Intake`: add `this.eatingHistory = false,` to the constructor (after `this.doctorAck = false,`), field `final bool eatingHistory;`, in `copyWith` a parameter `bool? eatingHistory,` and `eatingHistory: eatingHistory ?? this.eatingHistory,`, in `fromMap` `eatingHistory: readBool(map['eatingHistory']),`, and in the wire map (line ~138, next to `'lifeStage': ?lifeStage,`) `'eatingHistory': eatingHistory,`. Replace lines 47-51 with:
```dart
  bool get anyHealthYes => health.values.any((yes) => yes);

  bool get hasLifeStageFlag => lifeStage == 'pregnant' || lifeStage == 'postpartum';

  /// Anything that makes her coach read her answers first.
  bool get anyFlag => anyHealthYes || hasLifeStageFlag || eatingHistory;

  /// A flag means she ticks "I will check with my doctor"; the coach then
  /// accepts by hand.
  bool get needsDoctorAck => anyFlag;
```
(`needsDoctorAck` keeps its name, so `problems()` at line ~125 is unchanged.) In class `Subscription` add `final DateTime? healthReviewedAt;` (constructor, `fromMap` with `readTime(map['healthReviewedAt'])`, and `bool get healthHeld => (intake?.anyFlag ?? false) && healthReviewedAt == null;`). UNVERIFIED exact names: read `class Subscription` (`readTime` is the helper used by `ChatMessage.fromMap`; confirm it is exported by `parse.dart`).
2. Create `app/lib/features/private_coaching/domain/health_review.dart`, same pattern as WO-04e `check_in.dart`:
```dart
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../../../app_state/firebase_boot.dart';

const String kReviewClientHealthCallable = 'review_client_health';

abstract class HealthReviewStore {
  /// True when the server recorded it.
  Future<bool> markRead(String subId);
}

class HealthReviews {
  HealthReviews._();

  static HealthReviewStore? override;
  static HealthReviewStore get store => override ??
      (FirebaseBoot.isReady ? CallableHealthReviewStore() : InMemoryHealthReviewStore());
}

class CallableHealthReviewStore implements HealthReviewStore {
  CallableHealthReviewStore({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseBoot.functions;

  final FirebaseFunctions _functions;

  @override
  Future<bool> markRead(String subId) async {
    try {
      await _functions
          .httpsCallable(
            kReviewClientHealthCallable,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
          )
          .call<Object?>(<String, Object>{'subId': subId});
      return true;
    } catch (_) {
      return false;
    }
  }
}

class InMemoryHealthReviewStore implements HealthReviewStore {
  final List<String> read = <String>[];
  bool works = true;

  @override
  Future<bool> markRead(String subId) async {
    if (works) read.add(subId);
    return works;
  }
}
```
3. `join_coach_sheet.dart`, state class: add fields next to `_health`:
```dart
  String? _stage; // null = not answered, 'none' | 'pregnant' | 'postpartum'
  bool? _eating;
```
`_intake()`: add `lifeStage: (_stage == 'pregnant' || _stage == 'postpartum') ? _stage : null,` and `eatingHistory: _eating == true,`. Add getters:
```dart
  bool get _flagged => _anyYes || _stage == 'pregnant' || _stage == 'postpartum' || _eating == true;
```
and change `bool get _ready => _intake().isValid && _shares && _stored;` to `bool get _ready => _intake().isValid && _stage != null && _eating != null && _shares && _stored;`. In the build, after the `for (final q in CoachingEnums.healthQuestions) ...[ ... ],` loop (line ~357) and before `if (_anyYes) ...[` insert:
```dart
          const SizedBox(height: 10),
          Text(l10n.areYouPregnantOrDidYouHaveA, style: AppText.body),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              AppChip(l10n.no, selected: _stage == 'none', onTap: () => setState(() => _stage = 'none')),
              AppChip(l10n.pregnant, selected: _stage == 'pregnant', onTap: () => setState(() => _stage = 'pregnant')),
              AppChip(l10n.hadABaby, selected: _stage == 'postpartum', onTap: () => setState(() => _stage = 'postpartum')),
            ],
          ),
          const SizedBox(height: 10),
          Text(l10n.hasFoodOrWeightEverFeltOut, style: AppText.body),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              AppChip(l10n.yes_6deo, selected: _eating == true, onTap: () => setState(() => _eating = true)),
              AppChip(l10n.no, selected: _eating == false, onTap: () => setState(() => _eating = false)),
            ],
          ),
          Text(
            l10n.yourCoachReadsThisFirstYouDo,
            style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
          ),
```
and change `if (_anyYes) ...[` (line ~364) to `if (_flagged) ...[`. (`l10n.no` and `l10n.yes_6deo` are the getters this file already uses at lines 350-356.)
4. `coach_desk_view.dart` line 394: `final flagged = intake?.anyHealthYes ?? false;` becomes `final flagged = intake?.anyFlag ?? false;`. Line ~468 and `desk_widgets.dart:366` use the same test: run `grep -n "anyHealthYes" -r app/lib` and replace each use that decides whether to show "Health answers to read first" with `anyFlag` (do not change the one inside `subscription.dart`).
5. `desk_widgets.dart` `IntakeAnswersCard` (line 318): read it (`sed -n 318,380p`), and after the block that lists health answers add, using the same row helper that card uses for a single line:
```dart
        if (intake.lifeStage == 'pregnant') line(l10n.pregnant),
        if (intake.lifeStage == 'postpartum') line(l10n.hadABabyInTheLast12Months),
        if (intake.eatingHistory) line(l10n.foodOrWeightHasFeltWorrying),
```
(`line(...)` stands for whatever helper that card already uses for a text row; if none exists, use `Text(x, style: AppText.body)` inside the same `Column`.)
6. `client_detail_view.dart`: in `_ClientDetailViewState` add `bool _marking = false;` and
```dart
  Future<void> _markRead(Subscription sub) async {
    setState(() => _marking = true);
    final ok = await HealthReviews.store.markRead(sub.id);
    if (!mounted) return;
    setState(() => _marking = false);
    if (ok) {
      _readSubIds.add(sub.id);
      setState(() {});
    }
  }
  final Set<String> _readSubIds = <String>{};
  bool _held(Subscription sub) => sub.healthHeld && !_readSubIds.contains(sub.id);
```
In the `build` list (line ~177) insert after `_header(l10n, sub, now),`:
```dart
            if (_held(sub))
              AppCard(
                gap: 8,
                children: [
                  Semantics(header: true, child: Text(l10n.readHerHealthAnswersFirst, style: AppText.titleL)),
                  Text(l10n.plansAreOnHoldUntilYouHave, style: AppText.bodyM),
                  AppButton(
                    l10n.iHaveReadThem,
                    variant: AppButtonVariant.outlined,
                    onPressed: _marking ? null : () => _markRead(sub),
                  ),
                ],
              ),
```
and in `_actions(l10n, sub)` (lines ~232-262) change the two `onPressed: call(widget.onShareWorkout),` / `call(widget.onShareMeal),` to `onPressed: _held(sub) ? null : call(widget.onShareWorkout),` and `onPressed: _held(sub) ? null : call(widget.onShareMeal),`. Add imports for `AppCard`, `HealthReviews`, `Subscription` if missing. (Only one filled button on this screen already: "Message"; the new card has an OUTLINED button, so the one-primary rule holds.)
7. `coach_text.dart`, `coachFailureText`: UNVERIFIED shape (`grep -n "String coachFailureText" -A40 app/lib/features/private_coaching/presentation/coach/coach_text.dart`). Add a case for `CoachingRefusal.healthNotReviewed` returning `l10n.readHerHealthAnswersFirstOpenHer`. Then find where the share screens turn a publish failure into text (`grep -n "CoachingFailure\|failureText" app/lib/features/private_coaching/presentation/plans/share_workout_view.dart app/lib/features/private_coaching/presentation/plans/share_meal_plan_view.dart`) and confirm they use `coachFailureText`; if they use another function, add the same case there.
8. Strings, then tests.

## Strings to add
`app/tool/_wo04i_strings.json`; run `cd app && python3 tool/add_strings.py tool/_wo04i_strings.json && flutter gen-l10n`; use the printed getters (the getters in the code above are the expected ones; replace any that differ). Before running, drop any English key already present in `6-v2/i18n/ar-extra.json` with the same Arabic (`grep -c`), as in WO-04e.
| English | Egyptian Arabic |
|---|---|
| Are you pregnant, or did you have a baby in the last 12 months? | انتي حامل، ولا خلّفتي في آخر 12 شهر؟ |
| Pregnant | حامل |
| Had a baby | خلّفت من قريب |
| Has food or weight ever felt out of control or worrying for you? | الأكل أو الوزن حسّيتي قبل كده إنه خارج عن السيطرة أو بيقلقك؟ |
| Your coach reads this first. You do not have to say more. | مدرّبتك بتقراه الأول. مش لازم تقولي أكتر. |
| Had a baby in the last 12 months | خلّفت في آخر 12 شهر |
| Food or weight has felt worrying | الأكل أو الوزن كان بيقلقها |
| Read her health answers first | اقري إجاباتها الصحية الأول |
| Plans are on hold until you have. Her answers are below. | الخطط واقفة لحد ما تقريها. إجاباتها تحت. |
| I have read them | قريتها |
| Read her health answers first. Open her page and tick that you have. | اقري إجاباتها الصحية الأول. افتحي صفحتها وأكدي إنك قريتيها. |
(English "Pregnant" and "No" may exist: skip those already present.)

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| `app/test/features/private_coaching/member/member_browse_test.dart` (group at line 541 onward; reuse `openJoin`, `fillJoin`, `tapText`) | `the two new questions must be answered before Send` | after `fillJoin(tester)` Send is still disabled; tap 'No' (first one under the pregnancy label), tap 'No' under the food label: enabled once the ticks are done |
| same | `Pregnant shows the doctor tick and sends lifeStage` | answer Pregnant; the text 'I will check with my doctor before I start' (use the string the existing yes test at line 589 looks for) appears; without ticking, Send is disabled; tick; send; `repo.lastIntake.lifeStage == 'pregnant'` and `repo.lastIntake.eatingHistory == false` |
| same | `eating history yes is sent` | `repo.lastIntake.eatingHistory == true` |
| `app/test/features/private_coaching/models_test.dart` | `Intake flags` | `Intake(lifeStage: 'postpartum').anyFlag`, `Intake(eatingHistory: true).anyFlag`, `Intake(health: {'heart': true}).anyFlag` true; empty false; `Intake.fromMap({'eatingHistory': true}).eatingHistory`; the wire map contains `eatingHistory` |
| `app/test/features/private_coaching/desk/desk_views_test.dart` | `K07 flags a request for a pregnancy answer` | request whose intake has only `lifeStage: 'pregnant'`: 'Health answers to read first' is shown |
| same | `W02 holds the plan buttons until she has read the answers` | flagged subscription with `healthReviewedAt` null: card 'Read her health answers first' shown, the 'Share a workout' and 'Share a meal plan' buttons have `onPressed == null`; set `HealthReviews.override = InMemoryHealthReviewStore()`; tap 'I have read them'; card gone; buttons enabled; `store.read == [subId]`; a failing store (`works = false`) keeps the card. Reset the override in `tearDown`. |
| `app/test/features/private_coaching/plans/plan_screens_test.dart` | `a publish refused as not reviewed says so` | UNVERIFIED how this file fakes a refused publish (`grep -n "CoachingRefusal" app/test/features/private_coaching/plans/*.dart | head`); use `CoachingFailure(CoachingRefusal.healthNotReviewed)`; expect 'Read her health answers first. Open her page and tick that you have.' |
Run: `cd app && flutter test test/features/private_coaching/`

## Verify
- `flutter analyze` clean; the run prints `All tests passed!`; `flutter test test/qa/screen_budget_test.dart` still passes (the join sheet is a sheet, W02 gains an outlined button in a card).
- Arabic: a widget test in `ar` for the join sheet at text scale 2.0 shows no overflow (add to the existing "every screen at text scale 2.0" pattern if the file has one: `grep -n "scale" app/test/features/private_coaching/member/*.dart | head -3`).

## Do not
- Do not hide the new questions from anyone, and do not pre-select an answer. Do not word the eating question as a diagnosis. Do not show calories anywhere new. Do not store these answers on the phone beyond the existing intake path. No em dashes.
- Do not unlock the buttons locally without the server recording it: `_readSubIds` is only a cache of a successful call.

## Done checklist
- [ ] Intake model + wire
- [ ] join sheet questions
- [ ] flags shown on K07, details, W02 hold card
- [ ] strings EN/AR, tests pass

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
