library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_field.dart';
import '../../../../ui/app_scaffold.dart';
import '../../../../ui/app_segmented.dart';
import '../../domain/check_in.dart';
import '../apply/apply_widgets.dart' show ApplyTick;
import '../coach/coach_text.dart' show westernDigits;

/// Kilograms from what she typed (Arabic digits and a decimal comma allowed),
/// to one decimal, or null when it is not a weight the server will take.
double? parseCheckInWeight(String text) {
  final plain = westernDigits(text.trim())
      .replaceAll('\u066B', '.')
      .replaceAll(',', '.');
  final kg = double.tryParse(plain);
  if (kg == null || !kg.isFinite) return null;
  final rounded = (kg * 10).round() / 10;
  return rounded < kCheckInWeightMinKg || rounded > kCheckInWeightMaxKg
      ? null
      : rounded;
}

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
          done ? l10n.sentThankYou : l10n.fourQuickTapsItTakesUnderA,
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
    this.workoutsDone,
  });

  final String relId;
  final String weekKey;
  final CheckInStore? store;

  /// The coach-plan workouts she finished in this card's week; null when her
  /// coach has no workout plan for her, which hides the row.
  final int? workoutsDone;

  @override
  State<CheckInView> createState() => _CheckInViewState();
}

class _CheckInViewState extends State<CheckInView> {
  int _training = -1;
  int _energy = -1;
  int _food = -1;
  int _pain = -1;
  final TextEditingController _note = TextEditingController();
  final TextEditingController _weight = TextEditingController();
  bool _shareWeight = false; // health data: off until she ticks it
  bool _shareWorkouts = false; // her choice, so off until she ticks it
  bool _noteRefused = false; // the server refused a phone number or link
  bool _busy = false;
  String _error = '';

  /// Her weight when she typed one and agreed to share it; the typed text
  /// being unusable is its own state (see [_weightBad]).
  double? get _sharedWeight =>
      _shareWeight ? parseCheckInWeight(_weight.text) : null;

  bool get _weightBad =>
      _shareWeight && _weight.text.trim().isNotEmpty && _sharedWeight == null;

  bool get _ready =>
      _training >= 0 && _energy >= 0 && _food >= 0 && _pain >= 0 && !_weightBad;

  @override
  void dispose() {
    _note.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = '';
      _noteRefused = false;
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
        weightKg: _sharedWeight,
        workoutsDone: _shareWorkouts ? widget.workoutsDone : null,
      ),
    );
    if (!mounted) return;
    switch (result) {
      case CheckInResult.sent:
        CheckIns.answeredThisSession.add(widget.weekKey);
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.sentYourCoachWillSeeIt)),
        );
        navigator.maybePop();
      case CheckInResult.alreadySent:
        CheckIns.answeredThisSession.add(widget.weekKey);
        setState(() {
          _busy = false;
          _error = l10n.youAlreadySentThisOne;
        });
      case CheckInResult.containsContact:
        // Her words stay; the refusal sits next to the note.
        setState(() {
          _busy = false;
          _noteRefused = true;
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
          Text(
            hint,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
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
            items: [l10n.no, l10n.yes_6deo],
            selectedIndex: _pain,
            onChanged: (i) => setState(() => _pain = i),
          ),
          _pain == 1 ? l10n.tellYourCoachMoreBelowIfYou : null,
        ),
        AppField(
          controller: _note,
          label: l10n.anythingYouWantYourCoachToKnow,
          inputFormatters: [LengthLimitingTextInputFormatter(300)],
          errorText: _noteRefused
              ? l10n.thisCantIncludePhoneNumbersEmailsLinks
              : '',
          onChanged: (_) {
            if (_noteRefused) setState(() => _noteRefused = false);
          },
        ),
        AppField(
          key: const ValueKey('check-in-weight'),
          controller: _weight,
          label: l10n.yourWeightInKgOptional,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [LengthLimitingTextInputFormatter(6)],
          errorText: _weightBad
              ? l10n.enterAWeightBetweenLowAndHigh(
                  '${kCheckInWeightMinKg.round()}',
                  '${kCheckInWeightMaxKg.round()}',
                )
              : '',
          onChanged: (_) => setState(() {}),
        ),
        if (_weight.text.trim().isNotEmpty)
          ApplyTick(
            key: const ValueKey('check-in-share-weight'),
            text: l10n.shareMyWeightWithMyCoach,
            value: _shareWeight,
            onChanged: (on) => setState(() => _shareWeight = on),
          ),
        if (widget.workoutsDone != null) ...[
          Text(
            l10n.workoutsFromYourCoachsPlanThisWeek('${widget.workoutsDone}'),
            style: AppText.bodyM,
          ),
          ApplyTick(
            key: const ValueKey('check-in-share-workouts'),
            text: l10n.shareTheWorkoutsIFinishedThisWeek,
            value: _shareWorkouts,
            onChanged: (on) => setState(() => _shareWorkouts = on),
          ),
        ],
        if (_weight.text.trim().isNotEmpty || widget.workoutsDone != null)
          Text(
            l10n.onlyYourCoachSeesTheseAndOnly,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
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
