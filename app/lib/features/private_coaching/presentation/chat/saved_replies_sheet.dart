/// The saved reply editor sheet and starter replies for coaches.
library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_sheet.dart';
import '../../data/saved_reply_store.dart';
import '../../domain/chat_screen.dart';

List<String> starterRepliesOf(AppL10n l10n) => <String>[
  l10n.greatWorkTodayIAmProudOf,
  l10n.howDidTheSessionFeelTellMe,
  l10n.sendMeAShortVideoOfThat,
  l10n.lowerTheWeightALittleAndFocus,
  l10n.restWellTodayRecoveryIsPartOf,
  l10n.rememberToDrinkWaterAndEatYour,
  l10n.ifAnythingHurtsStopAndTellMe,
  l10n.iSawYourWeeklyCheckInThank,
  l10n.missedADayNoProblemPickUp,
  l10n.sendMeAPhotoOfYourMeal,
];

Future<String?> showReplyEditor(BuildContext context, {String? initial}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: AppColors.ink.withValues(alpha: 0.45),
    builder: (sheet) => _ReplyEditor(initial: initial),
  );
}

class _ReplyEditor extends StatefulWidget {
  const _ReplyEditor({required this.initial});
  final String? initial;

  @override
  State<_ReplyEditor> createState() => _ReplyEditorState();
}

class _ReplyEditorState extends State<_ReplyEditor> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial ?? '',
  );
  ChatScreenReason? _refusal;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _refusalText(AppL10n l10n, ChatScreenReason reason) =>
      switch (reason) {
        ChatScreenReason.contact => l10n.phoneNumbersCantBeSentInThe,
        ChatScreenReason.payment => l10n.paymentDetailsCantBeSharedInThe,
        ChatScreenReason.link => l10n.linksCantBeSentInTheChat,
        ChatScreenReason.abuse => l10n.someWordsInThisMessageArentAllowed,
      };

  void _save() {
    final trimmed = _text.text.trim();
    if (trimmed.isEmpty) return;
    final reason = ChatScreen.screen(trimmed);
    if (reason != null) {
      setState(() => _refusal = reason);
      return;
    }
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final canSave = _text.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AppSheet(
        gap: 12,
        children: [
          Text(
            widget.initial == null ? l10n.newReply : l10n.editReply,
            style: AppText.titleM.copyWith(color: AppColors.ink),
          ),
          TextField(
            controller: _text,
            maxLength: kSavedReplyChars,
            minLines: 1,
            maxLines: 5,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: AppText.body.copyWith(color: AppColors.ink),
            onChanged: (_) => setState(() => _refusal = null),
            decoration: InputDecoration(
              hintText: l10n.writeYourReply,
              hintStyle: AppText.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
          if (_refusal != null)
            Text(
              _refusalText(l10n, _refusal!),
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          AppButton(l10n.save, onPressed: canSave ? _save : null),
          if (widget.initial != null)
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(''),
                child: Text(
                  l10n.delete,
                  style: AppText.body.copyWith(color: AppColors.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
