/// The last weeks of check-ins of one coaching, for either person: the
/// answers, the weight and workout count when she shared them, and her
/// coach's reply. The coach can reply to a week that has none yet.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_field.dart';
import '../../domain/check_in.dart';
import '../desk/desk_text.dart' show dateText;

String _trainingText(AppL10n l10n, TrainingAnswer answer) => switch (answer) {
  TrainingAnswer.all => l10n.all,
  TrainingAnswer.most => l10n.most,
  TrainingAnswer.some => l10n.some,
  TrainingAnswer.none => l10n.none,
};

class CheckInHistory extends StatefulWidget {
  const CheckInHistory({
    super.key,
    required this.relId,
    required this.canReply,
    this.store,
  });

  final String relId;

  /// True on the coach's side, while the coaching runs.
  final bool canReply;
  final CheckInStore? store;

  @override
  State<CheckInHistory> createState() => _CheckInHistoryState();
}

class _CheckInHistoryState extends State<CheckInHistory> {
  List<CheckInCard>? _cards;
  final Map<String, TextEditingController> _drafts =
      <String, TextEditingController>{};
  String _sending = '';
  String _error = '';

  /// The week whose reply the server refused for a phone number, link or handle.
  String _contactWeek = '';

  CheckInStore get _store => widget.store ?? CheckIns.store;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _drafts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final cards = await _store.history(widget.relId);
    if (mounted) setState(() => _cards = cards);
  }

  Future<void> _reply(CheckInCard card) async {
    final l10n = AppL10n.of(context);
    final text = _drafts[card.weekKey]?.text.trim() ?? '';
    if (text.isEmpty) return;
    setState(() {
      _sending = card.weekKey;
      _error = '';
      _contactWeek = '';
    });
    final outcome = await _store.reply(
      relId: widget.relId,
      weekKey: card.weekKey,
      text: text,
    );
    if (!mounted) return;
    if (outcome == CheckInReply.containsContact) {
      // Her text stays in the field; the refusal sits next to it.
      setState(() {
        _sending = '';
        _contactWeek = card.weekKey;
      });
      return;
    }
    if (outcome == CheckInReply.failed) {
      setState(() {
        _sending = '';
        _error = l10n.weCouldNotSendItTryAgain;
      });
      return;
    }
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.yourReplyWasSent)));
    setState(() => _sending = '');
    await _load();
  }

  Widget _line(String text) => Text(text, style: AppText.bodyM);

  Widget _tile(AppL10n l10n, CheckInCard card) {
    final a = card.answers;
    final draft = _drafts.putIfAbsent(card.weekKey, TextEditingController.new);
    return AppCard(
      key: ValueKey('check-in-${card.weekKey}'),
      variant: AppCardVariant.filled,
      gap: 6,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.checkInOfDate(dateText(l10n, card.answeredAt)),
            style: AppText.titleM.copyWith(color: AppColors.ink),
          ),
        ),
        _line(l10n.trainingValue(_trainingText(l10n, a.training))),
        _line(l10n.energyValue('${a.energy}')),
        _line(l10n.eatingValue('${a.food}')),
        _line(l10n.painOrInjuryValue(a.pain ? l10n.yes_6deo : l10n.no)),
        if (a.weightKg != null)
          _line(l10n.weightValue(l10n.valueKg(a.weightKg!.toStringAsFixed(1)))),
        if (a.workoutsDone != null)
          _line(l10n.workoutsFromThePlanValue('${a.workoutsDone}')),
        if (a.note.isNotEmpty) _line(a.note),
        if (card.reply.isNotEmpty) ...[
          Text(
            widget.canReply ? l10n.yourReply : l10n.yourCoachsReply,
            style: AppText.label.copyWith(color: AppColors.onSurfaceVariant),
          ),
          Text(
            card.reply,
            style: AppText.bodyM,
            key: ValueKey('reply-${card.weekKey}'),
          ),
        ] else if (widget.canReply) ...[
          AppField(
            key: ValueKey('reply-field-${card.weekKey}'),
            controller: draft,
            label: l10n.writeAReply,
            errorText: _contactWeek == card.weekKey
                ? l10n.thisCantIncludePhoneNumbersEmailsLinks
                : '',
            onChanged: (_) {
              if (_contactWeek == card.weekKey) {
                setState(() => _contactWeek = '');
              }
            },
            maxLines: 3,
            inputFormatters: [
              LengthLimitingTextInputFormatter(kCheckInReplyMax),
            ],
          ),
          AppButton(
            l10n.sendReply,
            key: ValueKey('reply-send-${card.weekKey}'),
            variant: AppButtonVariant.tonal,
            height: 48,
            fontSize: 16,
            onPressed: _sending.isEmpty ? () => _reply(card) : null,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cards = _cards;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Semantics(
          header: true,
          child: Text(
            widget.canReply ? l10n.checkInHistory : l10n.yourCheckIns,
            style: AppText.titleM.copyWith(color: AppColors.ink),
          ),
        ),
        if (cards != null && cards.isEmpty) _line(l10n.noCheckInsYet),
        if (cards != null)
          for (final card in cards) _tile(l10n, card),
        if (_error.isNotEmpty)
          Text(_error, style: AppText.bodyM.copyWith(color: AppColors.error)),
      ],
    );
  }
}
