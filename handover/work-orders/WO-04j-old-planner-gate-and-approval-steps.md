# WO-04j: prove the old planner screens cannot be reached, and write down how Rahma gets approved (C10)
Depends on: none (run it last in this series: it re-checks what WO-04a to WO-04i changed)
Size: M
Reads first: `app/lib/routing/screen_features.dart` lines 195-217; `app/lib/domain/flags/feature_flags.dart` lines 485-500; `app/lib/routing/app_router.dart` lines 529-552 (`onGenerateRoute`), 4983-5132 (live coach builders, K18 to H01) and 5635-5870 (the old builders); `app/test/routing/coaching_router_test.dart` lines 1-90 and 256-286 (`the payment screens are dark`, the pattern to copy); `docs/owner/LAUNCH-GUIDE.md` lines 205-215

## Why
The plan asked: can Rahma reach a screen that looks like it publishes but only changes her phone (the old `coachplan` screens W04 to W09, K19 to K23)? Traced 26 Oct, from the code:
1. Those screens run on the old local desk state (`coachDesk`, `coachPlanDraft`, `app_router.dart:5655-5870`). They are built, tested and compiled in, but dark.
2. They are dark by two switches in `screen_features.dart`: `W04, W05, W07, W08, W09, W11, K19, K20, K21, K22, K23` -> `Feature.coachPlanning`; `K26, K27` -> `Feature.assistant`. Shipped values (`feature_flags.dart:491-496`): `coachPlanning: false`, `assistant: false`. `AppRouter.screenIsOn` (`app_router.dart:789`) then returns false and `onGenerateRoute` (line 546) answers `FeatureOff`, never the screen. On a cold start `_openable` (`main.dart`) sends such a name to the front door. So no screen of the list can be opened by a tap or by a link.
3. Inbound references from LIVE screens: none. Searched `'W04'`, `'W05'`, `'W07'`, `'W08'`, `'W09'`, `'K19'` to `'K23'`, `'K26'`, `'K27'` in `app/lib`: the only callers are (a) the old builders in `app_router.dart` (they call each other), (b) `features/coach/presentation/coach_today_view.dart` lines 86, 260, 390, 437, 443 (a widget that NO route builds: K07 builds `CoachDeskView`, `app_router.dart:4998`), (c) `features/coach/presentation/coach_first_week_view.dart` lines 76, 81, 125 and `coach_being_checked_view.dart:87` (UNVERIFIED that no route builds them: command in step 1), (d) `features/coachplan/domain/review/review_feedback_service.dart:77` (a string). The live coach builders (K18, K07, W01, W02, W03, W06, W10, K16) never name an old id; W03 and W06 are the live `ShareWorkoutScreen` and `ShareMealScreen`.
4. Also dark: K17 earnings (`Feature.payments` false), K05 (payments), B01 to B07 (`Feature.coachPortfolio` false).
So the answer is "gated, not reachable". What was missing is a test that fails the day somebody turns a switch on or adds a link. This order adds it. It deletes nothing (the screens are used by tests and by the screen inventory).
WO-04b adds links by path. Only `/c/*` and `/p/*` reach the app (manifest and AASA in WO-04c), so a link to `/coachplan/w04` cannot open the app from outside.

## Final result
- A new test file fails if: any of the 13 ids is on in the shipped flags; its route stops answering `FeatureOff`; a live coach builder names an old id; a live source file under `features/private_coaching/` names one; `Feature.coachPlanning` or `Feature.assistant` or `Feature.payments` or `Feature.coachPortfolio` is turned on in `shipped`.
- `docs/owner/LAUNCH-GUIDE.md` gets a short exact section "Approving Rahma" (below) so the reviewer and Rahma know the taps.
No change to what a woman sees.

## Files to edit or create
| path | action | what changes |
|---|---|---|
| `app/test/routing/old_planner_dark_test.dart` | create | the guard tests |
| `docs/owner/LAUNCH-GUIDE.md` | edit | section "Approving Rahma" under the bullet at line 210 |

## Steps
1. Verify, and put the real output in your report. Run each:
   - `cd app && grep -rnE "CoachTodayView\(|CoachFirstWeekView\(|CoachBeingCheckedView\(|CoachEarningsView\(" lib | grep -v "^lib/features/coach/presentation"` (expect only `routing/app_router.dart:5229 CoachEarningsView(`, K17, dark by `payments`).
   - `cd app && grep -rnE "'(W04|W05|W07|W08|W09|W11|K19|K20|K21|K22|K23|K26|K27)'" lib | grep -v "^lib/theme/screen_art.dart\|^lib/routing/screen_features.dart\|^lib/routing/app_routes.dart\|^lib/l10n"` (expect: `app_router.dart` old builders and `features/coach/presentation/*` only).
   - `sed -n 440,470p app/lib/routing/app_router.dart` to read what the list holding `'K24'` (line 457) and `'W11'` (line 458) is (UNVERIFIED: it looks like screens that are not built on purpose). If any listed screen has a builder, add it to the test in step 2.
   If the first command prints a line outside the expectation, STOP and write it to `handover/QUESTIONS.md`.
2. Create `app/test/routing/old_planner_dark_test.dart`:
```dart
// C10. The old planner screens (W04 to W09, K19 to K23, and the assistant's two
// drafts) run on local state and would look like they publish. They are dark by
// Feature.coachPlanning and Feature.assistant. These tests fail the day that
// stops being true, or a live screen links to one.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

const List<String> kOldIds = <String>[
  'W04', 'W05', 'W07', 'W08', 'W09', 'W11',
  'K19', 'K20', 'K21', 'K22', 'K23', 'K26', 'K27',
];

void main() {
  final original = AppRouter.featureFlags;
  tearDown(() => AppRouter.featureFlags = original);

  test('the switches that keep them dark are off in the shipped flags', () {
    final flags = AppRouter.featureFlags;
    for (final f in <Feature>[
      Feature.coachPlanning,
      Feature.assistant,
      Feature.payments,
      Feature.coachPortfolio,
    ]) {
      expect(flags.isOn(f), isFalse, reason: '$f must stay off until its screens write to the server');
    }
  });

  test('none of the old ids is on', () {
    for (final id in kOldIds) {
      expect(AppRouter.screenIsOn(id), isFalse, reason: id);
    }
  });

  testWidgets('each old route answers FeatureOff, never the screen', (tester) async {
    for (final id in kOldIds) {
      final route = AppRouter.onGenerateRoute(RouteSettings(name: appRoutes[id]!.name));
      expect(route, isNotNull, reason: id);
      await tester.pumpWidget(
        MaterialApp(home: Builder(builder: (context) => (route! as MaterialPageRoute<dynamic>).builder(context))),
      );
      expect(find.byType(FeatureOff), findsOneWidget, reason: id);
    }
  });

  test('no live coach builder names an old id', () {
    final source = File('lib/routing/app_router.dart').readAsStringSync();
    final start = source.indexOf("    'K18': (context)");
    final end = source.indexOf("    'H01': (context)");
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final live = source.substring(start, end);
    for (final id in kOldIds) {
      expect(live.contains("'$id'"), isFalse, reason: "$id is named between K18 and H01");
    }
  });

  test('no file of the live coaching feature names an old id', () {
    final hits = <String>[];
    for (final entity in Directory('lib/features/private_coaching').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final id in kOldIds) {
        if (RegExp("['\"]$id['\"]").hasMatch(text)) hits.add('${entity.path} names $id');
      }
    }
    expect(hits, isEmpty);
  });
}
```
`FeatureOff` is imported from where `app_router.dart` defines or imports it: UNVERIFIED: `grep -rn "class FeatureOff" app/lib`; add that import. If `AppRouter.featureFlags` is not assignable/readable as shown, use the same access `feature_gating_test.dart` uses (lines 12-14 read it as `AppRouter.featureFlags`, so it is). Marker strings `    'K18': (context)` and `    'H01': (context)` are lines 4983 and 5132 (verified by `awk`); if indentation differs the `indexOf` returns -1 and the first `expect` explains.
3. Run `cd app && flutter test test/routing/old_planner_dark_test.dart`. If `each old route answers FeatureOff` fails for one id because its flow gate answers first, print `AppRouter.screenIsOn(id)` for it, and write the finding to QUESTIONS.md; do not change the router.
4. `docs/owner/LAUNCH-GUIDE.md`: after the bullet at line 210 ("A woman reviewer opens the dashboard, **Coaches**, approves her ...") add the block below, exactly (it is owner-facing English; no em dashes):
```
#### Approving Rahma, tap by tap

Before anything: Rahma must already be a verified woman (she passed the check, so her account is verified), and the person who approves her must be a DIFFERENT woman reviewer. The server refuses a reviewer who tries to decide her own application (`functions/coaching/applications.py` `decide`, `refuse_if_subject`).

1. Rahma, on her phone: Profile, Become a coach. Fill the 8 steps and send. The status screen says it is being checked.
2. The reviewer opens the dashboard (https://ownhub-reviewers.pages.dev) and signs in. The Coaches tab is the second row of tabs and shows a number when an application waits.
3. Coaches, tap Rahma's application. Look at the profile photo, then open each certificate file. A certificate that is unreadable or not hers: tick nothing for it.
4. Tick the certificate or certificates you checked. The Approve button stays grey until at least one is ticked ("To approve, tick at least one certificate you checked").
5. Optional: write a note to her. Tap Approve. Rahma gets a notification and her coach access starts.
6. Portfolio photos tab: open her photos, approve each one that shows only her or people who agreed in writing. A rejection needs a reason from the list.
7. Rahma, on her phone: on the status screen tap Open coach space. She sees My coach space (K18). Her page shows to members only once she has turned on one package.
Other statuses: "Needs changes" sends her back to the steps with the reasons; "Reject" lets her apply again after 30 days.
```
UNVERIFIED wording to confirm before saving: that the Coaches tab is "second row" (`admin-web/index.html:30` shows the tab; its position is not checked) and the Portfolio photos tab label: `grep -n "Portfolio photos" admin-web/index.html admin-web/coaching.js | head -3`. Remove the words "is the second row of tabs and" if the position is not as stated, and use the exact label found. Also UNVERIFIED: that Rahma gets a notification on approval (`notify` is passed to `decide`, `applications.py:462`; the text kind is not checked): `grep -n "portfolioDecision\|applicationDecision" functions/coaching/push.py` and delete the sentence "Rahma gets a notification and" if there is no matching text.

## Strings to add
None.

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| `app/test/routing/old_planner_dark_test.dart` | the five tests in step 2 | as coded above |
Run: `cd app && flutter test test/routing/old_planner_dark_test.dart test/routing/coaching_router_test.dart test/routing/feature_gating_test.dart`

## Verify
- That command prints `All tests passed!`.
- Mutation check (do it, then undo it): set `Feature.coachPlanning: true` in `feature_flags.dart:491` area; the new test file must fail on `the switches...` and `none of the old ids is on`. Restore the value and re-run: green. Put both outputs in the report.

## Do not
- Do not delete the old builders, screens or `features/coachplan/` (tests and the generated inventory use them).
- Do not turn any of the four flags on. Do not edit `FeatureOff`.
- Not covered here (the plan lists them under C10, assigned elsewhere): server rate limits on chat, report and upload; the push text decision. Say so in the report.

## Done checklist
- [ ] three greps run, outputs in report
- [ ] guard test passes; mutation check fails then passes
- [ ] launch guide section added with verified labels

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
