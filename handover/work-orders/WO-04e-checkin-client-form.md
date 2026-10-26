# WO-04e: the weekly check-in card and form on the client's phone (C3, part 2)
Depends on: WO-04d
Size: L
Reads first: `app/lib/features/private_coaching/presentation/chat/chat_thread_view.dart` lines 28-70 and 425-445; `app/lib/features/private_coaching/domain/chat_message.dart` lines 30-100; `app/lib/features/private_coaching/domain/coaching_contract.dart` lines 846-870 (`SystemMessageKind`); `app/lib/features/private_coaching/presentation/chat/chat_logic.dart` lines 240-255 (`systemLine`); `app/lib/app_state/coach_invite_state.dart` lines 85-143 (the store pattern to copy); `app/lib/ui/app_segmented.dart` lines 1-55

## Why
The server (WO-04d) puts a "weekly check-in" card into the thread every Friday. The client opens it from the thread and answers four taps and an optional line, then sends. Under 60 seconds. The words never blame her.

## Final result
In the thread (client side), a system line of kind `checkIn` is no longer a small grey pill; it is a card:
- Title EN "Weekly check-in" / AR "التشيك إن الأسبوعي". Body EN "Four quick taps. It takes under a minute." / AR "أربع ضغطات سريعة. بياخد أقل من دقيقة." One text button EN "Answer" / AR "جاوبي".
- For the COACH the same system line is a plain pill with EN "Weekly check-in sent" / AR "التشيك إن الأسبوعي اتبعت" (no button; she reads answers in the Needs attention list, WO-04f).
Tap "Answer" (1 tap) opens **CheckInView**, top to bottom:
1. app bar title EN "Your week" / AR "أسبوعك" with back.
2. EN "How did your training go?" / AR "التمرين مشي إزاي؟" and a 4-way segmented control: EN All, Most, Some, None / AR كله، أغلبه، شوية، ولا حاجة.
3. EN "How is your energy?" / AR "طاقتك عاملة إيه؟" segmented 1 2 3 4 5; muted line EN "1 is low, 5 is high." / AR "1 قليلة، 5 عالية."
4. EN "How did eating go?" / AR "الأكل مشي إزاي؟" segmented 1 2 3 4 5; muted line EN "1 is hard, 5 is easy." / AR "1 صعب، 5 سهل."
5. EN "Any pain or injury this week?" / AR "حسيتي بألم أو إصابة الأسبوع ده؟" segmented EN No, Yes / AR لأ، أيوه. When Yes is chosen a muted line appears: EN "Tell your coach more below if you like. If it is sharp or getting worse, please see a doctor." / AR "لو حابة احكي لمدرّبتك أكتر تحت. ولو الألم حاد أو بيزيد، اروحي لدكتور."
6. an optional text field (max 300 characters), hint EN "Anything you want your coach to know? (optional)" / AR "حابة مدرّبتك تعرفي حاجة؟ (لو حابة)".
7. the ONE filled button EN "Send to my coach" / AR "ابعتي لمدرّبتك", disabled until questions 2 to 5 have an answer. Nothing is pre-selected (a pre-selected "No" would hide pain).
Controls above the fold: 4 segmented + 1 field = 5 others, 1 filled: inside the budget (`test/qa/screen_budget_test.dart`: at most 5 other, 1 primary).
Taps: Answer 1, four answers 4, Send 1 = 6 taps, no typing.
After Send: the screen closes and a notice shows EN "Sent. Your coach will see it." / AR "اتبعت. مدرّبتك هتشوفه." The card in the thread then reads EN "Sent. Thank you." / AR "اتبعت. شكرًا." for the rest of this session (kept in memory only; the server holds the truth: a second send is refused and the form says EN "You already sent this one." / AR "انتي بعتّي ده قبل كده.").
Errors: EN "We could not send it. Try again in a moment." / AR "ماقدرناش نبعته. جرّبي تاني كمان شوية." (the answers stay on screen).
Photo: NOT in this order. A progress photo needs a storage path, a storage rule and the moderation path in `functions/coaching/media.py`, none of which is verified. Report it as open (UNVERIFIED: `grep -n "match /" firebase/storage.rules | head -20`).

## Files to edit or create
| path | action | what changes |
|---|---|---|
| `app/lib/features/private_coaching/domain/coaching_contract.dart` | edit | `SystemMessageKind.checkIn` |
| `app/lib/features/private_coaching/domain/chat_message.dart` | edit | `weekKey` field |
| `app/lib/features/private_coaching/domain/check_in.dart` | create | model, store, callable store, in-memory store |
| `app/lib/features/private_coaching/presentation/chat/check_in_view.dart` | create | the form and the card |
| `app/lib/features/private_coaching/presentation/chat/chat_logic.dart` | edit | `systemLine` case |
| `app/lib/features/private_coaching/presentation/chat/chat_thread_view.dart` | edit | draw the card |
| `app/test/features/private_coaching/chat/check_in_test.dart` | create | tests |

## Steps
1. File `coaching_contract.dart`, enum `SystemMessageKind` (line 846). After `sessionDone('sessionDone'),` add `checkIn('checkIn'),`. (WO-04d already added `'checkIn'` to the string list near line 310.) Adding the enum member makes `systemLine` (`chat_logic.dart:245`, an exhaustive `switch`) fail to compile: that is step 3.
2. File `chat_message.dart`: in class `ChatMessage` add a field `final String? weekKey;` (constructor: `this.weekKey,` next to `this.systemKind,` line 38; field next to line 55) and in `fromMap` (line 91 area) add `weekKey: readStringOrNull(map['weekKey']),` after `systemKind: system,`.
3. File `chat_logic.dart`, `systemLine` (line 245): the signature stays. Add the case before `SystemMessageKind.hidden || null`:
```dart
  SystemMessageKind.checkIn => l10n.weeklyCheckInSent,
```
4. Create `app/lib/features/private_coaching/domain/check_in.dart`:
```dart
/// The weekly check-in: what she answers, and how it reaches the server.
/// Same shape as `app_state/coach_invite_state.dart`: an interface, a callable
/// implementation, an in-memory one for tests and a build with no back end.
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../../../app_state/firebase_boot.dart';

const String kSubmitCheckInCallable = 'submit_check_in';
const String kCoachNeedsAttentionCallable = 'coach_needs_attention';

enum TrainingAnswer { all, most, some, none }

class CheckInAnswers {
  const CheckInAnswers({
    required this.training,
    required this.energy,
    required this.food,
    required this.pain,
    this.note = '',
  });

  final TrainingAnswer training;
  final int energy;
  final int food;
  final bool pain;
  final String note;

  Map<String, Object> toWire() => <String, Object>{
    'training': training.name,
    'energy': energy,
    'food': food,
    'pain': pain,
    'note': note.trim(),
  };
}

enum CheckInResult { sent, alreadySent, failed }

abstract class CheckInStore {
  Future<CheckInResult> submit({
    required String relId,
    required String weekKey,
    required CheckInAnswers answers,
  });

  Future<List<AttentionRow>> needsAttention();
}

/// One client on the coach's "Needs attention" list.
class AttentionRow {
  const AttentionRow({
    required this.subId,
    required this.relId,
    required this.clientName,
    required this.reasons,
  });

  final String subId;
  final String relId;
  final String clientName;

  /// Wire names: noCheckIn, missedSessions, healthFlag, unread.
  final List<String> reasons;
}

class CheckIns {
  CheckIns._();

  static CheckInStore? override;
  static CheckInStore get store =>
      override ??
      (FirebaseBoot.isReady ? CallableCheckInStore() : InMemoryCheckInStore());

  /// Weeks answered in this session, so the card can say so.
  static final Set<String> answeredThisSession = <String>{};
}

class CallableCheckInStore implements CheckInStore {
  CallableCheckInStore({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseBoot.functions;

  final FirebaseFunctions _functions;

  HttpsCallable _callable(String name) => _functions.httpsCallable(
    name,
    options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
  );

  @override
  Future<CheckInResult> submit({
    required String relId,
    required String weekKey,
    required CheckInAnswers answers,
  }) async {
    try {
      await _callable(kSubmitCheckInCallable).call<Object?>(<String, Object>{
        'relId': relId,
        'weekKey': weekKey,
        'answers': answers.toWire(),
      });
      return CheckInResult.sent;
    } on FirebaseFunctionsException catch (error) {
      // UNVERIFIED: the reason string for a repeated send. The server raises
      // errors.WRONG_STATUS; read its text in functions/coaching/errors.py and
      // compare with error.message here.
      return error.message == 'wrong_status'
          ? CheckInResult.alreadySent
          : CheckInResult.failed;
    } catch (_) {
      return CheckInResult.failed;
    }
  }

  @override
  Future<List<AttentionRow>> needsAttention() async {
    try {
      final result = await _callable(kCoachNeedsAttentionCallable)
          .call<Object?>(<String, Object>{});
      final data = result.data;
      final list = data is Map ? data['clients'] : null;
      if (list is! List) return const <AttentionRow>[];
      return <AttentionRow>[
        for (final raw in list)
          if (raw is Map)
            AttentionRow(
              subId: '${raw['subId']}',
              relId: '${raw['relId']}',
              clientName: '${raw['clientName'] ?? ''}',
              reasons: <String>[
                for (final r in (raw['reasons'] is List ? raw['reasons'] as List : const []))
                  '$r',
              ],
            ),
      ];
    } catch (_) {
      return const <AttentionRow>[];
    }
  }
}

class InMemoryCheckInStore implements CheckInStore {
  InMemoryCheckInStore({this.rows = const <AttentionRow>[]});

  final List<AttentionRow> rows;
  final List<CheckInAnswers> sent = <CheckInAnswers>[];
  CheckInResult result = CheckInResult.sent;

  @override
  Future<CheckInResult> submit({
    required String relId,
    required String weekKey,
    required CheckInAnswers answers,
  }) async {
    if (result == CheckInResult.sent) sent.add(answers);
    return result;
  }

  @override
  Future<List<AttentionRow>> needsAttention() async => rows;
}
```
Before using `'wrong_status'`: run `grep -n "WRONG_STATUS" functions/coaching/errors.py` and use that exact string.
5. Create `app/lib/features/private_coaching/presentation/chat/check_in_view.dart` containing two public widgets. Full code:
```dart
library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_field.dart';
import '../../../../ui/app_scaffold.dart';
import '../../../../ui/app_segmented.dart';
import '../../domain/check_in.dart';

/// The card in the thread. Tapping Answer opens [CheckInView].
class CheckInCard extends StatelessWidget {
  const CheckInCard({super.key, required this.weekKey, required this.onAnswer});

  final String weekKey;
  final VoidCallback onAnswer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final done = CheckIns.answeredThisSession.contains(weekKey);
    return AppCard(
      variant: AppCardVariant.tonal,
      gap: 6,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.weeklyCheckIn, style: AppText.titleL),
        ),
        Text(
          done ? l10n.sentThankYou : l10n.fourQuickTapsItTakesUnder,
          style: AppText.bodyM,
        ),
        if (!done)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: onAnswer,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(l10n.answer),
            ),
          ),
      ],
    );
  }
}

class CheckInView extends StatefulWidget {
  const CheckInView({
    super.key,
    required this.relId,
    required this.weekKey,
    this.store,
  });

  final String relId;
  final String weekKey;
  final CheckInStore? store;

  @override
  State<CheckInView> createState() => _CheckInViewState();
}

class _CheckInViewState extends State<CheckInView> {
  int _training = -1;
  int _energy = -1;
  int _food = -1;
  int _pain = -1;
  final TextEditingController _note = TextEditingController();
  bool _busy = false;
  String _error = '';

  bool get _ready => _training >= 0 && _energy >= 0 && _food >= 0 && _pain >= 0;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = '';
    });
    final result = await (widget.store ?? CheckIns.store).submit(
      relId: widget.relId,
      weekKey: widget.weekKey,
      answers: CheckInAnswers(
        training: TrainingAnswer.values[_training],
        energy: _energy + 1,
        food: _food + 1,
        pain: _pain == 1,
        note: _note.text,
      ),
    );
    if (!mounted) return;
    switch (result) {
      case CheckInResult.sent:
        CheckIns.answeredThisSession.add(widget.weekKey);
        messenger?.showSnackBar(SnackBar(content: Text(l10n.sentYourCoachWillSeeIt)));
        navigator.maybePop();
      case CheckInResult.alreadySent:
        CheckIns.answeredThisSession.add(widget.weekKey);
        setState(() {
          _busy = false;
          _error = l10n.youAlreadySentThisOne;
        });
      case CheckInResult.failed:
        setState(() {
          _busy = false;
          _error = l10n.weCouldNotSendItTryAgain;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final scale = <String>['1', '2', '3', '4', '5'];
    Widget ask(String q, Widget control, [String? hint]) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(q, style: AppText.titleL),
        const SizedBox(height: 8),
        control,
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint, style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ],
    );
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: l10n.yourWeek,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      children: [
        ask(
          l10n.howDidYourTrainingGo,
          AppSegmented(
            items: [l10n.all, l10n.most, l10n.some, l10n.none],
            selectedIndex: _training,
            onChanged: (i) => setState(() => _training = i),
          ),
        ),
        ask(
          l10n.howIsYourEnergy,
          AppSegmented(
            items: scale,
            selectedIndex: _energy,
            onChanged: (i) => setState(() => _energy = i),
          ),
          l10n.n1IsLow5IsHigh,
        ),
        ask(
          l10n.howDidEatingGo,
          AppSegmented(
            items: scale,
            selectedIndex: _food,
            onChanged: (i) => setState(() => _food = i),
          ),
          l10n.n1IsHard5IsEasy,
        ),
        ask(
          l10n.anyPainOrInjuryThisWeek,
          AppSegmented(
            items: [l10n.no, l10n.yes],
            selectedIndex: _pain,
            onChanged: (i) => setState(() => _pain = i),
          ),
          _pain == 1 ? l10n.tellYourCoachMoreBelowIfYou : null,
        ),
        AppField(
          controller: _note,
          label: l10n.anythingYouWantYourCoachToKnow,
          maxLength: 300,
        ),
        if (_error.isNotEmpty) Text(_error, style: AppText.bodyM),
        AppButton(
          l10n.sendToMyCoach,
          onPressed: _ready && !_busy ? _send : null,
        ),
      ],
    );
  }
}
```
UNVERIFIED in this snippet (verify each, adjust the call to the real signature, do not invent): `AppField` constructor (`grep -n "class AppField" -A25 app/lib/ui/app_field.dart`: names `controller`, `label`, `maxLength`); `AppSegmented` accepting `selectedIndex: -1` (read `app_segmented.dart` lines 13-55; if it asserts a valid index, keep a separate "unanswered" flag and pass 0 with a visual-less state, or ask); the getters `l10n.all`, `l10n.most`, `l10n.some`, `l10n.none`, `l10n.no`, `l10n.yes`, `l10n.answer` may already exist or collide: the add_strings tool prints the real names (single-word English keys such as "All", "No", "Yes" exist already in most apps: use `grep -n '^  "\(all\|no\|yes\|none\|answer\)":' app/lib/l10n/app_en.arb` and reuse any whose English AND Arabic equal the ones below). `AppText.titleL`, `AppText.bodyM`, `AppColors.onSurfaceVariant`, `AppCard(variant: AppCardVariant.tonal, gap:)`, `AppScaffold(showArt:, appBar: AppTopBar(...), children:)` are verified in `coach_space_view.dart`.
6. File `chat_thread_view.dart`, the line `if (message.type == MessageType.system) {` (about line 439). Replace its body:
```dart
        if (message.type == MessageType.system) {
          if (message.systemKind == SystemMessageKind.checkIn &&
              message.weekKey != null &&
              widget.otherIsCoach) {
            // otherIsCoach is true on the CLIENT's side (the other person is
            // the coach): she is the one who answers.
            final week = message.weekKey!;
            return CheckInCard(
              weekKey: week,
              onAnswer: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => CheckInView(relId: widget.relId, weekKey: week),
                ),
              ),
            );
          }
          return NoticePill(systemLine(l10n, message.systemKind));
        }
```
Add imports `check_in_view.dart` and (if not present) `../../domain/coaching_contract.dart`. For the coach (`otherIsCoach` false) the pill shows `systemLine` = "Weekly check-in sent".
7. Strings (next section), then tests.

## Strings to add
File `app/tool/_wo04e_strings.json` (delete after), run `cd app && python3 tool/add_strings.py tool/_wo04e_strings.json && flutter gen-l10n`; use the getters it prints.
| English (key) | Egyptian Arabic |
|---|---|
| Weekly check-in | التشيك إن الأسبوعي |
| Four quick taps. It takes under a minute. | أربع ضغطات سريعة. بياخد أقل من دقيقة. |
| Answer | جاوبي |
| Weekly check-in sent | التشيك إن الأسبوعي اتبعت |
| Sent. Thank you. | اتبعت. شكرًا. |
| Your week | أسبوعك |
| How did your training go? | التمرين مشي إزاي؟ |
| All | كله |
| Most | أغلبه |
| Some | شوية |
| None | ولا حاجة |
| How is your energy? | طاقتك عاملة إيه؟ |
| 1 is low, 5 is high. | 1 قليلة، 5 عالية. |
| How did eating go? | الأكل مشي إزاي؟ |
| 1 is hard, 5 is easy. | 1 صعب، 5 سهل. |
| Any pain or injury this week? | حسيتي بألم أو إصابة الأسبوع ده؟ |
| No | لأ |
| Yes | أيوه |
| Tell your coach more below if you like. If it is sharp or getting worse, please see a doctor. | لو حابة احكي لمدرّبتك أكتر تحت. ولو الألم حاد أو بيزيد، اروحي لدكتور. |
| Anything you want your coach to know? (optional) | حابة مدرّبتك تعرفي حاجة؟ (لو حابة) |
| Send to my coach | ابعتي لمدرّبتك |
| Sent. Your coach will see it. | اتبعت. مدرّبتك هتشوفه. |
| You already sent this one. | انتي بعتّي ده قبل كده. |
| We could not send it. Try again in a moment. | ماقدرناش نبعته. جرّبي تاني كمان شوية. |
No placeholders, so no `parameterised` block. Several of these (All, No, Yes, None, Answer) probably exist: the tool overwrites the Arabic of an existing English key with the new value (`extra[en] = ar`, `add_strings.py` line 81). Before running, for each of those five run `grep -n '"All"\|"No"\|"Yes"\|"None"\|"Answer"' 6-v2/i18n/ar-extra.json 6-v2/i18n/ar.json` and DROP from your JSON any key already present, so no other screen's Arabic changes.

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| `app/test/features/private_coaching/chat/check_in_test.dart` | `Send stays off until the four questions are answered` | pump `CheckInView(relId: 'r', weekKey: '2026-W44', store: InMemoryCheckInStore())` in the `_host` pattern of `coach_test.dart` lines 41-56 at 390x844; find the FilledButton/`AppButton` 'Send to my coach': disabled; tap 'All', '4', '3' only: still disabled; tap 'No': enabled |
| same | `a full answer sends the right values once` | answer All, 4, 3, Yes; enter 'knee' in the field; tap Send; `store.sent.single` has training all, energy 4, food 3, pain true, note 'knee'; the view is popped |
| same | `pain Yes shows the doctor line` | tap 'Yes': text 'Tell your coach more below if you like. If it is sharp or getting worse, please see a doctor.' found; tap 'No': gone |
| same | `a refused or repeated send is said in words and keeps the answers` | `store.result = CheckInResult.failed` -> 'We could not send it. Try again in a moment.' visible and button still enabled; `alreadySent` -> 'You already sent this one.' |
| same | `Arabic and 2.0 text scale fit` | pump with `Locale('ar')` and scale 2.0 inside a 390x844 view: no overflow exception (`tester.takeException() == null`), button text 'ابعتي لمدرّبتك' found |
| same | `the thread draws the card for the client and a pill for the coach` | use the thread test helpers in `app/test/features/private_coaching/chat/` (UNVERIFIED names: `ls app/test/features/private_coaching/chat/`); a `ChatMessage` with `systemKind: checkIn, weekKey: '2026-W44'`: with `otherIsCoach: true` find 'Answer'; with `otherIsCoach: false` find 'Weekly check-in sent' and no 'Answer' |
| same | `form budget` | use `control_counter.dart` (`app/test/helpers/control_counter.dart`, see its header) exactly as `app/test/qa/screen_budget_test.dart` does for a screen built from a widget: at most 5 other controls and 1 filled primary above the fold at 390x844 |
Run: `cd app && flutter test test/features/private_coaching/chat/ test/contracts/coaching_contract_test.dart`

## Verify
- `flutter analyze` clean; the run above prints `All tests passed!`.
- Android emulator: needs server `CHECK_INS_LIVE = True` in an emulator project only; otherwise only the widget tests prove it. Say which in the report.

## Do not
- Do not pre-select any answer. Do not add a photo control. Do not show streaks, counts or the word "missed" anywhere.
- Do not edit the coach side here (WO-04f).

## Done checklist
- [ ] enum, message field, `systemLine` case compile
- [ ] store file, view file, thread edit
- [ ] strings in EN and AR with printed getters used
- [ ] tests pass

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
