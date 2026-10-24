/// The sheets of a thread: the coach's "+", a long-pressed line, reporting and
/// blocking.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_chip_row.dart';
import '../../../../ui/app_sheet.dart';
import '../../domain/coaching_contract.dart';
import '../member/coach_labels.dart';

/// A tappable row of a sheet, at least 48 high.
class SheetAction extends StatelessWidget {
  const SheetAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppText.body.copyWith(color: AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// What the coach can put into the thread.
class ShareChoices {
  const ShareChoices({
    this.onRecipe,
    this.onWorkoutPlan,
    this.onMealPlan,
    this.onSession,
  });

  final VoidCallback? onRecipe;
  final VoidCallback? onWorkoutPlan;
  final VoidCallback? onMealPlan;
  final VoidCallback? onSession;

  bool get any =>
      onRecipe != null ||
      onWorkoutPlan != null ||
      onMealPlan != null ||
      onSession != null;
}

Future<void> showShareSheet(BuildContext context, ShareChoices choices) {
  final l10n = AppL10n.of(context);
  void run(BuildContext sheet, VoidCallback callback) {
    Navigator.of(sheet).pop();
    callback();
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.45),
    builder: (sheet) => AppSheet(
      gap: 8,
      children: [
        if (choices.onRecipe != null)
          SheetAction(
            icon: Icons.menu_book_outlined,
            label: l10n.shareARecipe,
            onTap: () => run(sheet, choices.onRecipe!),
          ),
        if (choices.onWorkoutPlan != null)
          SheetAction(
            icon: Icons.fitness_center,
            label: l10n.shareAWorkoutPlan,
            onTap: () => run(sheet, choices.onWorkoutPlan!),
          ),
        if (choices.onMealPlan != null)
          SheetAction(
            icon: Icons.restaurant_menu,
            label: l10n.shareAMealPlan,
            onTap: () => run(sheet, choices.onMealPlan!),
          ),
        if (choices.onSession != null)
          SheetAction(
            icon: Icons.videocam_outlined,
            label: l10n.scheduleALiveSession,
            onTap: () => run(sheet, choices.onSession!),
          ),
        const SizedBox(height: 12),
      ],
    ),
  );
}

/// Long press on a line: copy it, and report it when it is hers.
Future<void> showLineSheet(
  BuildContext context, {
  required String? text,
  required VoidCallback? onReport,
}) {
  final l10n = AppL10n.of(context);
  return showAppSheet<void>(
    context: context,
    gap: 8,
    children: [
      if (text != null && text.isNotEmpty)
        Builder(
          builder: (sheet) => SheetAction(
            icon: Icons.copy_outlined,
            label: l10n.copy,
            onTap: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              Navigator.of(sheet).pop();
              await Clipboard.setData(ClipboardData(text: text));
              messenger?.showSnackBar(SnackBar(content: Text(l10n.copied)));
            },
          ),
        ),
      if (onReport != null)
        Builder(
          builder: (sheet) => SheetAction(
            icon: Icons.flag_outlined,
            label: l10n.reportThisMessage,
            onTap: () {
              Navigator.of(sheet).pop();
              onReport();
            },
          ),
        ),
      const SizedBox(height: 12),
    ],
  );
}

/// Pick a reason, add a note, send. [onSend] does the write.
Future<void> showChatReportSheet(
  BuildContext context, {
  required Future<void> Function(String reason, String note) onSend,
}) => showAppSheet<void>(
  context: context,
  children: [
    ChatReportForm(onSend: onSend),
    const SizedBox(height: 12),
  ],
);

class ChatReportForm extends StatefulWidget {
  const ChatReportForm({super.key, required this.onSend});

  final Future<void> Function(String reason, String note) onSend;

  @override
  State<ChatReportForm> createState() => _ChatReportFormState();
}

class _ChatReportFormState extends State<ChatReportForm> {
  final TextEditingController _note = TextEditingController();
  String? _reason;
  bool _sending = false;
  bool _failed = false;
  bool _sent = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() {
      _sending = true;
      _failed = false;
    });
    try {
      await widget.onSend(reason, _note.text);
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    if (_sent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.thankYouWeWillLookAtThis,
              style: AppText.titleL.copyWith(color: AppColors.ink),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.yourReportIsPrivate,
            style: AppText.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          AppButton(l10n.close, onPressed: () => Navigator.of(context).pop()),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.whyAreYouReportingThis,
            style: AppText.titleL.copyWith(color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final reason in CoachingEnums.reportReasons)
              AppChip(
                reportReasonLabel(l10n, reason),
                selected: _reason == reason,
                onTap: () => setState(() => _reason = reason),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLines: 3,
          minLines: 2,
          maxLength: 1000,
          decoration: InputDecoration(labelText: l10n.addANoteOptional),
        ),
        if (_failed)
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.weCouldNotSendYourReportTry,
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          ),
        const SizedBox(height: 12),
        AppButton(
          l10n.sendReport,
          onPressed: _reason == null || _sending ? null : _send,
        ),
      ],
    );
  }
}

/// Asks before blocking; true when she confirmed.
Future<bool> confirmBlock(BuildContext context, String name) async {
  final l10n = AppL10n.of(context);
  final answer = await showAppSheet<bool>(
    context: context,
    children: [
      Builder(
        builder: (sheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.blockName(name),
                style: AppText.titleL.copyWith(color: AppColors.ink),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.nameCannotWriteToYouAfterThis(name),
              style: AppText.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            AppButton(
              l10n.block,
              onPressed: () => Navigator.of(sheet).pop(true),
            ),
            const SizedBox(height: 8),
            AppButton(
              l10n.notNow,
              variant: AppButtonVariant.outlined,
              onPressed: () => Navigator.of(sheet).pop(false),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ],
  );
  return answer ?? false;
}

/// The words of the chat and conduct rules, in order, as she reads them. The
/// hash of this text is what the record keeps.
String chatRulesText(AppL10n l10n) => <String>[
  l10n.beforeYourFirstMessage,
  l10n.beRespectfulInsultsHarassmentAndHatefulWords,
  l10n.keepTheChatInOwnHubPhone,
  l10n.yourCoachSharesTrainingAndFoodIdeas,
  l10n.messagesAreStoredOnOwnHubsServers,
  l10n.iHaveReadTheseRulesAndI,
].join('\n');

/// The rules before her first message, with an unticked box. True when she
/// ticked and agreed.
Future<bool> showChatRulesSheet(BuildContext context) async {
  final l10n = AppL10n.of(context);
  final answer = await showAppSheet<bool>(
    context: context,
    children: [
      Builder(
        builder: (sheet) => _ChatRules(
          l10n: l10n,
          onAgree: () => Navigator.of(sheet).pop(true),
        ),
      ),
    ],
  );
  return answer == true;
}

class _ChatRules extends StatefulWidget {
  const _ChatRules({required this.l10n, required this.onAgree});

  final AppL10n l10n;
  final VoidCallback onAgree;

  @override
  State<_ChatRules> createState() => _ChatRulesState();
}

class _ChatRulesState extends State<_ChatRules> {
  bool _ticked = false;

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.beforeYourFirstMessage,
            style: AppText.titleL.copyWith(color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 12),
        for (final line in <String>[
          l10n.beRespectfulInsultsHarassmentAndHatefulWords,
          l10n.keepTheChatInOwnHubPhone,
          l10n.yourCoachSharesTrainingAndFoodIdeas,
          l10n.messagesAreStoredOnOwnHubsServers,
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              line,
              style: AppText.body.copyWith(color: AppColors.ink),
            ),
          ),
        Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            value: _ticked,
            onChanged: (v) => setState(() => _ticked = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.iHaveReadTheseRulesAndI, style: AppText.bodyM),
          ),
        ),
        const SizedBox(height: 8),
        AppButton(
          l10n.agreeAndSend,
          onPressed: _ticked ? widget.onAgree : null,
        ),
      ],
    );
  }
}
