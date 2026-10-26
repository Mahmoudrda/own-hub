# WO-03g: Send one plan to many clients, with a start date
Depends on: WO-03d
Size: L
Reads first: `app/lib/features/private_coaching/presentation/plans/share_workout_view.dart` lines 46-100, 190-230, 296-320; `app/lib/features/private_coaching/presentation/plans/share_meal_plan_view.dart` lines 42-72, 130-170, 205-262; `app/lib/ui/app_sheet.dart` lines 1-60; `app/lib/routing/coaching_wiring.dart` lines 288-362; `app/lib/features/private_coaching/presentation/desk/desk_text.dart` lines 10-18

## Why
Rahma coaches a group on the same programme. Today she repeats five taps per client. This adds "Send to more clients" next to Publish: she ticks her other active clients, picks a start date, and the app calls the existing `publish_coach_plan` once per client. No server change (WO-03d added the date). Each client gets her own plan document, so a later edit for one client does not change the others. A failure for one client must never hide the ones that worked, and must never send twice to a client who already got it.

## Final result
Screen "Share a workout" (and "Share a meal plan", same change), with a plan ready. Footer: ONE filled button, `Publish to Mariam` (unchanged). Directly above the controls list, one new text-variant button `Send to more clients` / `ابعتيها لعميلات تانيات` (key `assign-more`), shown only when she has at least one other active client and the plan is new (not a new version of a published plan).
Tapping it opens a bottom sheet, top to bottom:
1. Title `Who gets this plan?` / `مين هتاخد الخطة دي؟`
2. Row `Mariam` with a ticked, locked checkbox (the client whose page she came from).
3. One row per other active client with a checkbox (`assign-client-<subId>`), her name from `clientName(l10n, sub)`.
4. Row `Start date` / `تاريخ البداية` showing the date (default today, `assign-date`), tapping opens the date picker (today to 60 days ahead).
5. Filled button `Choose 3 clients` / `تمام، 3 عميلات` (key `assign-done`), count includes Mariam. Closing the sheet keeps the choice.
Back on the screen the footer label becomes `Publish to 3 clients` / `ابعتيها لـ 3 عميلات` and a line under the plan name says `Starts Sat 1 Nov` style: `Starts {date}` / `بتبدأ {date}` (key `assign-summary`).
Pressing Publish: one call per client, one after another (not parallel, so a rate limit hits the last ones). While sending the button is disabled and shows the usual busy state.
Result, all sent: the existing green card, text `Sent to 3 clients` / `اتبعتت لـ 3 عميلات`.
Result, some failed (partial failure): an amber card with `Sent to 2 clients` / `اتبعتت لـ 2 عميلة`, then one line per failed client `Salma: <reason>` (reason from `coachFailureText`), and one filled button `Try again for 1 client` / `جرّبي تاني لعميلة واحدة` (key `assign-retry`) that sends ONLY to the failed ones. A `Back` outlined button stays. Clients already sent are never sent again, even after Back and reopen (the state holds `_sentSubs`).
Tap count (plan ready, one extra client): Send to more clients (1), tick her (2), Choose 2 clients (3), Publish (4). Target was 3 for the assignment itself (1, 2, 3); Publish is the existing step.

## Files to edit or create
| path | file action | change |
|---|---|---|
| app/lib/features/private_coaching/presentation/plans/assign_many.dart | create | pure loop with partial failures |
| app/lib/features/private_coaching/presentation/plans/assign_clients_sheet.dart | create | the sheet |
| app/lib/features/private_coaching/presentation/plans/share_workout_view.dart | edit | button, summary, loop, result card |
| app/lib/features/private_coaching/presentation/plans/share_meal_plan_view.dart | edit | same |
| app/lib/routing/coaching_wiring.dart | edit | pass `others` clients |
| app/test/features/private_coaching/plans/assign_many_test.dart | create | unit tests |
| app/test/features/private_coaching/plans/plan_screens_test.dart | edit | 3 widget tests |

## Steps
1. Create `assign_many.dart`:
```dart
/// Sends one plan to several clients, one call each, and keeps going when one
/// call fails. Nothing is retried here: the caller offers a retry for the
/// failures only.
library;

import '../../domain/coaching_failure.dart';

class AssignOutcome {
  const AssignOutcome({this.sent = const <String>[], this.failed = const <String, CoachingFailure>{}});

  final List<String> sent;

  /// Sub id to why it was not sent.
  final Map<String, CoachingFailure> failed;

  bool get allSent => failed.isEmpty;
}

Future<AssignOutcome> publishToMany({
  required List<String> subIds,
  required Future<void> Function(String subId) send,
}) async {
  final sent = <String>[];
  final failed = <String, CoachingFailure>{};
  for (final id in subIds) {
    try {
      await send(id);
      sent.add(id);
    } on CoachingFailure catch (failure) {
      failed[id] = failure;
    }
  }
  return AssignOutcome(sent: sent, failed: failed);
}
```
UNVERIFIED: `CoachingFailure` constructor takes a `CoachingRefusal` positional (seen in `firestore_coaching_repository.dart` line 814: `CoachingFailure(CoachingRefusal.badRequest)`). A network error that is not a `CoachingFailure` is thrown by `_call` as a `CoachingFailure` too (UNVERIFIED: `grep -n "Future<Map<String, Object?>> _call" -A25 app/lib/features/private_coaching/data/firestore_coaching_repository.dart`); if it can throw anything else, add `catch (_)` that stores `const CoachingFailure(CoachingRefusal.unavailable)` (use the enum value the `_call` helper uses for offline, read it there).
2. Create `assign_clients_sheet.dart`:
```dart
library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_list_item.dart';

class AssignClient {
  const AssignClient({required this.subId, required this.name});
  final String subId;
  final String name;
}

class AssignChoice {
  const AssignChoice(this.subIds, this.startsOn);
  final Set<String> subIds;
  final DateTime startsOn;
}

/// Shown by the "Send to more clients" button. [mine] is locked on.
class AssignClientsSheet extends StatefulWidget {
  const AssignClientsSheet({
    super.key,
    required this.mine,
    required this.others,
    required this.initial,
    required this.startsOn,
  });

  final AssignClient mine;
  final List<AssignClient> others;
  final Set<String> initial;
  final DateTime startsOn;

  @override
  State<AssignClientsSheet> createState() => _AssignClientsSheetState();
}

class _AssignClientsSheetState extends State<AssignClientsSheet> {
  late final Set<String> _picked = {...widget.initial};
  late DateTime _date = widget.startsOn;

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: first,
      lastDate: first.add(const Duration(days: 60)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final count = _picked.length + 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.whoGetsThisPlan, style: AppText.titleL),
        CheckboxListTile(
          key: ValueKey('assign-client-${widget.mine.subId}'),
          value: true,
          onChanged: null,
          title: Text(widget.mine.name),
        ),
        for (final c in widget.others)
          CheckboxListTile(
            key: ValueKey('assign-client-${c.subId}'),
            value: _picked.contains(c.subId),
            onChanged: (on) => setState(
              () => on == true ? _picked.add(c.subId) : _picked.remove(c.subId),
            ),
            title: Text(c.name),
          ),
        AppListItem(
          key: const ValueKey('assign-date'),
          title: l10n.startDate,
          subtitle: MaterialLocalizations.of(context).formatMediumDate(_date),
          onTap: _pickDate,
        ),
        AppButton(
          l10n.chooseNClients(count.toString()),
          key: const ValueKey('assign-done'),
          onPressed: () =>
              Navigator.of(context).pop(AssignChoice({..._picked}, _date)),
        ),
      ],
    );
  }
}
```
The English date from `formatMediumDate` follows the app locale (Arabic digits risk): replace `.toString()`/date text with the project's own formatter if `MaterialLocalizations` prints Arabic-Indic digits; check by running the Arabic test in step 7. If it does, use `dateText(l10n, _date)` from `../desk/desk_text.dart` (UNVERIFIED output, see WO-03f step 3) and keep the key. `l10n.startDate` exists (arb line 1047, "Start date").
3. File `share_workout_view.dart`. Constructor (about line 47-60): add `this.others = const <AssignClient>[],`; field `final List<AssignClient> others;` with doc `/// Her other active clients, for "Send to more clients".` Import the two new files. State additions after `String _error = '';` (about line 101):
```dart
  Set<String> _also = <String>{};
  DateTime? _startsOn;
  final Set<String> _sentSubs = <String>{};
  Map<String, CoachingFailure> _failed = <String, CoachingFailure>{};
  int _sentCount = 0;

  Future<void> _assign() async {
    final choice = await showAppSheet<AssignChoice>(
      context: context,
      children: [
        AssignClientsSheet(
          mine: AssignClient(
            subId: widget.subscription.id,
            name: widget.clientName,
          ),
          others: widget.others,
          initial: _also,
          startsOn: _startsOn ?? DateTime.now(),
        ),
      ],
    );
    if (choice == null || !mounted) return;
    setState(() {
      _also = choice.subIds;
      _startsOn = choice.startsOn;
    });
  }
```
Add `import '../../../../ui/app_sheet.dart';` and `import 'assign_many.dart'; import 'assign_clients_sheet.dart';`.
4. Same file, `_publish` (about line 190-229). Replace the `try { ... }` block (lines 206-228) so the main client is first and extras follow, keeping the old single-client path when `_also.isEmpty`:
```dart
    try {
      final stamped = stampSafetyTags(plan, _byId);
      final start = _startsOn == null ? null : dayKey(_startsOn!);
      final ids = <String>[
        if (!_sentSubs.contains(widget.subscription.id)) widget.subscription.id,
        for (final id in _also)
          if (!_sentSubs.contains(id)) id,
      ];
      String? firstPlanId;
      var firstRevision = 1;
      final outcome = await publishToMany(
        subIds: ids,
        send: (subId) async {
          final sent = await widget.repository.publishCoachPlan(
            subId: subId,
            name: _name.text.trim(),
            workout: stamped,
            planId: subId == widget.subscription.id ? widget.existing?.id : null,
            startsOn: start,
          );
          if (subId == widget.subscription.id) {
            firstPlanId = sent.planId;
            firstRevision = sent.revision;
          }
        },
      );
      if (!mounted) return;
      _sentSubs.addAll(outcome.sent);
      setState(() {
        _busy = false;
        _failed = outcome.failed;
        _sentCount = _sentSubs.length;
        _published = outcome.allSent;
      });
      if (firstPlanId != null) widget.onPublished?.call(firstPlanId!, firstRevision);
      if (!outcome.allSent) showHonestNotice(context, l10n.someWereNotSent);
    } on CoachingFailure catch (failure) {
```
Leave the existing `on CoachingFailure` handler below it as is (it now only catches errors thrown outside the loop, for example from `stampSafetyTags`). `dayKey` is `import '../../../../domain/format/day_key.dart';` (the same import `authored_workout.dart` line 8 uses; UNVERIFIED output is `YYYY-MM-DD`: `grep -n "String dayKey" -A6 app/lib/domain/format/day_key.dart`). Note `onPublished` in the wiring calls `onBack`, which would close the screen before she sees a partial failure: only call `onPublished` when `outcome.allSent`. Move the `if (firstPlanId != null) ...` line inside `if (outcome.allSent)`.
5. Same file, `build`. (a) Footer label (about line 311-313): `widget.existing == null ? l10n.publishToName(first) : l10n.publishAsANewVersion` becomes
```dart
                    widget.existing != null
                        ? l10n.publishAsANewVersion
                        : _also.isEmpty
                        ? l10n.publishToName(first)
                        : l10n.publishToNClients(countLabel(_also.length + 1)),
```
(b) In the `if (_published) AppCard(...)` branch (about line 326-344) use the text `_sentSubs.length > 1 ? l10n.sentToNClients(countLabel(_sentSubs.length)) : l10n.publishedNameCanSeeItNow(first)`. (c) Before `if (_published)` add the partial failure card:
```dart
            if (_failed.isNotEmpty)
              AppCard(
                variant: AppCardVariant.amber,
                key: const ValueKey('assign-partial'),
                children: [
                  Text(l10n.sentToNClients(countLabel(_sentCount)), style: AppText.titleS),
                  for (final e in _failed.entries)
                    Text(
                      '${_nameOf(e.key)}: ${coachFailureText(l10n, e.value)}',
                      style: AppText.bodyM,
                    ),
                  AppButton(
                    l10n.tryAgainForNClients(countLabel(_failed.length)),
                    key: const ValueKey('assign-retry'),
                    onPressed: _busy ? null : _publish,
                  ),
                ],
              ),
```
with helper `String _nameOf(String subId) => subId == widget.subscription.id ? widget.clientName : widget.others.firstWhere((c) => c.subId == subId, orElse: () => AssignClient(subId: subId, name: subId)).name;`. Because `_publish` skips `_sentSubs`, retry sends only to the failed ones. Clear `_failed` at the top of `_publish` (`_failed = {}` inside the first `setState`). (d) The `assign-more` button, in the `else ...[` branch right after the `workout-name` field (about line 356): 
```dart
              if (widget.existing == null && widget.others.isNotEmpty)
                AppButton(
                  l10n.sendToMoreClients,
                  key: const ValueKey('assign-more'),
                  variant: AppButtonVariant.text,
                  height: 48,
                  fontSize: 15,
                  onPressed: _busy ? null : _assign,
                ),
              if (_startsOn != null && _also.isNotEmpty)
                Text(
                  l10n.startsDate(MaterialLocalizations.of(context).formatMediumDate(_startsOn!)),
                  key: const ValueKey('assign-summary'),
                  style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
                ),
```
6. File `share_meal_plan_view.dart`: do exactly steps 3, 4 and 5 again. Differences: constructor at about line 43; state at about line 80; `_publish` try block at lines 118-140 (`meal: _body` instead of `workout: stamped`, no stamping); footer label at about line 255-258 (`widget.existing == null ? l10n.publishToName(first) : ...`); published card at lines 268-285; `assign-more` after the `meal-name` field (about line 295-301). Meal day 1 is the start date; nothing else changes.
7. File `coaching_wiring.dart`, in `ShareWorkoutScreen.build` (about line 303-318) and `ShareMealScreen.build` (about line 339-355) add to the view call:
```dart
        others: [
          for (final s in PrivateCoachingState.instance.coachSubscriptions)
            if (s.status == SubscriptionStatus.active && s.id != sub.id)
              AssignClient(subId: s.id, name: clientName(AppL10n.of(context), s)),
        ],
```
Imports: `plans/assign_clients_sheet.dart`, `domain/subscription.dart` (for `SubscriptionStatus`, may already be imported; UNVERIFIED `grep -n "subscription.dart" app/lib/routing/coaching_wiring.dart`). `clientName` comes from `desk_text.dart`, already used in this file at line 308.

## Strings to add
| key | English | Egyptian Arabic |
|---|---|---|
| sendToMoreClients | Send to more clients | ابعتيها لعميلات تانيات |
| whoGetsThisPlan | Who gets this plan? | مين هتاخد الخطة دي؟ |
| chooseNClients | Choose {n} clients | تمام، {n} عميلات |
| publishToNClients | Publish to {n} clients | ابعتيها لـ {n} عميلات |
| sentToNClients | Sent to {n} clients | اتبعتت لـ {n} عميلات |
| tryAgainForNClients | Try again for {n} | جرّبي تاني لـ {n} |
| someWereNotSent | Some clients did not get the plan. | في عميلات الخطة ماوصلتش لهم. |
| startsDate | Starts {date} | بتبدأ {date} |
Parameterised: `{n}` and `{date}` as String placeholders. Arabic counts: for exactly 1 the retry text reads "جرّبي تاني لـ 1", which is understood; do not add plural machinery. Command: `cd app && python3 tool/add_strings.py /tmp/ownhub-wo03g.json && flutter gen-l10n`; use the printed getter names where they differ from the table.

## Tests to add or change
| file | test | arrange, act, assert |
|---|---|---|
| assign_many_test.dart | `keeps going after a failure` | `send` throws `CoachingFailure(CoachingRefusal.badRequest)` for 'b' only; ids [a,b,c]; assert `sent == [a, c]`, `failed.keys == [b]`, `allSent` false. |
| same | `sends in order and once` | Record the ids sent; assert exact order [a,b,c], each once. |
| plan_screens_test.dart | `assign: pick one more client and publish` | Fake repository from `plans_support.dart` records publish calls (UNVERIFIED shape; read the file). Pump `ShareWorkoutView(others: [Nour])`, start from a split, tap `assign-more`, tap `assign-client-nour`, tap `assign-done`; footer text is `Publish to 2 clients`; tap `workout-publish`; assert two calls, subIds [mariam, nour], both with the same `startsOn` string; `workout-published` text is `Sent to 2 clients`. |
| same | `assign: a failure shows the partial card and retry sends only the failed one` | Fake throws for nour on the first call and succeeds the second. After publish `assign-partial` exists and shows 1 sent; tap `assign-retry`; calls are [mariam, nour, nour]; `workout-published` shown. Mariam never gets a second call. |
| same | `assign button is hidden with no other clients and for a new version` | `others: []` -> no `assign-more`; `existing != null` -> none. |
| same | `meal plan: same flow` | One test mirroring the first with `ShareMealPlanView` and `meal-publish`. |
Run: `cd app && flutter test test/features/private_coaching/plans`.

## Verify
`flutter analyze lib/features/private_coaching lib/routing/coaching_wiring.dart` -> `No issues found!`; plans tests -> `All tests passed!`; Arabic pump of the sheet has no overflow with 6 clients; `flutter test test/qa/screen_budget_test.dart` still passes (the footer keeps one filled button; the sheet is not counted unless listed).

## Do not
Never publish to a client twice in one session (no retry of sent ones). Do not add a server callable. Do not send to clients who are not `active`. Do not weaken the server's `subscription.coachUid == uid` check. No em dashes. No commit.

## Done checklist
- [ ] Loop helper + tests  - [ ] Sheet  - [ ] Workout screen  - [ ] Meal screen  - [ ] Wiring  - [ ] Partial failure verified  - [ ] Strings EN/AR

## If stuck
Stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to WO-03h.
