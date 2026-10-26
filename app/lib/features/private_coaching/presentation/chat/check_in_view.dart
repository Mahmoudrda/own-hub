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
