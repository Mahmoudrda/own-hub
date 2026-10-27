/// The small pieces the coach's desk is built from: the avatar, a chat row
/// like WhatsApp's, a count tile and the badge for unread lines.
library;

import 'package:flutter/material.dart';

import '../../../../domain/nutrition/target_safety.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_card.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/inbody_scan.dart';
import '../../domain/subscription.dart';
import '../member/coach_card.dart' show coachInitial;
import '../member/coach_labels.dart' show allergenNames, goalLabel, placeLabel;
import 'desk_model.dart';
import 'desk_text.dart';

/// A round avatar with the first letter of the name.
class DeskAvatar extends StatelessWidget {
  const DeskAvatar({super.key, required this.name, this.size = 48});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clean = name.trim();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Text(
          coachInitial(clean),
          textScaler: TextScaler.noScaling,
          style: AppText.titleL.copyWith(
            color: AppColors.onPrimaryContainer,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}

/// The unread count in a round petrol badge.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppText.nav.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// One client in a list, laid out like a chat row: the avatar opens her
/// details, the rest opens the chat.
class DeskClientRow extends StatelessWidget {
  const DeskClientRow({
    super.key,
    required this.client,
    required this.myUid,
    required this.now,
    required this.onOpenChat,
    required this.onOpenClient,
    this.reasons = false,
  });

  final DeskClient client;
  final String? myUid;
  final DateTime now;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenClient;

  /// Shows why she needs a follow up in place of the last message.
  final bool reasons;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final name = clientName(l10n, client.subscription);
    final package = client.subscription.package.title;
    final left = daysLeftText(l10n, client.daysLeft);
    final subtitle = <String>[
      if (package.isNotEmpty) package,
      ?left,
    ].join(' · ');
    final preview = reasons && client.needsFollowUp
        ? reasonsText(l10n, client)
        : previewText(l10n, client.lastMessage, myUid);
    final time = rowTime(l10n, client.lastActivity, now);
    final spoken = <String>[
      name,
      if (subtitle.isNotEmpty) subtitle,
      if (client.unread > 0) l10n.countUnread('${client.unread}'),
      preview,
      if (time.isNotEmpty) time,
    ].join('. ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: l10n.openTheDetailsOfName(name),
          excludeSemantics: true,
          child: InkResponse(
            onTap: onOpenClient,
            radius: 28,
            child: SizedBox(
              width: 56,
              height: 64,
              child: Center(child: DeskAvatar(name: name)),
            ),
          ),
        ),
        Expanded(
          child: Semantics(
            button: true,
            label: '${l10n.openTheChatWithName(name)}. $spoken',
            excludeSemantics: true,
            child: InkWell(
              onTap: onOpenChat,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 4,
                    end: 12,
                    top: 8,
                    bottom: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.titleM.copyWith(
                                color: AppColors.ink,
                              ),
                            ),
                            if (subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.nav.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            Text(
                              preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.bodyM.copyWith(
                                color: reasons && client.needsFollowUp
                                    ? AppColors.amber
                                    : AppColors.textSecondary,
                                fontWeight: client.unread > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (time.isNotEmpty)
                            Text(
                              time,
                              style: AppText.nav.copyWith(
                                color: client.unread > 0
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          if (client.unread > 0) ...[
                            const SizedBox(height: 4),
                            UnreadBadge(client.unread),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A count with its name. Tappable when [onTap] is given.
class CountTile extends StatelessWidget {
  const CountTile({
    super.key,
    required this.count,
    required this.label,
    this.onTap,
    this.highlight = false,
  });

  final int count;
  final String label;
  final VoidCallback? onTap;

  /// Draws the count in petrol: there is something to do.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? AppColors.pinkSoft : AppColors.surfaceLowest,
        border: Border.all(color: AppColors.borderWarm),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: AppText.headline.copyWith(
              color: highlight ? AppColors.primary : AppColors.ink,
            ),
          ),
          Text(
            label,
            style: AppText.nav.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: '$count $label',
      excludeSemantics: true,
      child: onTap == null
          ? tile
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: tile,
            ),
    );
  }
}

/// A label and its value on one line.
class DeskFact extends StatelessWidget {
  const DeskFact(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label: $value',
    excludeSemantics: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppText.bodyM.copyWith(color: AppColors.ink),
          ),
        ),
      ],
    ),
  );
}

/// What she told the coach when she asked to join: her goals, her allergies
/// and the health questions, with any yes marked.
class IntakeAnswersCard extends StatelessWidget {
  const IntakeAnswersCard(this.intake, {super.key});

  final Intake intake;

  Widget _title(String text) => Semantics(
    header: true,
    child: Text(text, style: AppText.titleM.copyWith(color: AppColors.ink)),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final yesNo = <Widget>[
      for (final q in CoachingEnums.healthQuestions)
        if (intake.health.containsKey(q))
          _healthRow(l10n, q, intake.health[q] ?? false),
    ];
    return AppCard(
      gap: 8,
      children: [
        _title(l10n.herAnswers),
        Text(
          l10n.sharedWithYouWhileYouCoachHer,
          style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
        ),
        DeskFact(l10n.goal, goalLabel(l10n, intake.goal)),
        DeskFact(l10n.level, levelLabel(l10n, intake.level)),
        DeskFact(l10n.daysAWeek, '${intake.daysPerWeek}'),
        DeskFact(l10n.place, placeLabel(l10n, intake.place)),
        DeskFact(
          l10n.allergies,
          intake.allergies.isEmpty
              ? l10n.none
              : allergenNames(l10n, intake.allergies),
        ),
        if (lifeStageText(l10n, intake.lifeStage ?? '') case final stage?)
          DeskFact(l10n.lifeStage, stage),
        if (intake.note.trim().isNotEmpty)
          DeskFact(l10n.herNote, intake.note.trim()),
        if (intake.inbodyScan case final scan?) ...[
          const SizedBox(height: 4),
          _title('InBody Scan & Target Estimates'),
          if (scan.weightKg != null) DeskFact('Weight', '${scan.weightKg} kg'),
          if (scan.skeletalMuscleMassKg != null)
            DeskFact('Muscle (SMM)', '${scan.skeletalMuscleMassKg} kg'),
          if (scan.bodyFatPercent != null)
            DeskFact('Body Fat', '${scan.bodyFatPercent}%'),
          if (scan.bmrKcal != null)
            DeskFact('BMR (Basal Rate)', '${scan.bmrKcal} kcal'),
          if (!intake.eatingHistoryFlag &&
              !TargetStage.fromWire(intake.lifeStage).isProtected)
            Builder(
              builder: (context) {
                final targets = InBodyTargetEstimator.estimate(
                  scan: scan,
                  goal: ClientFitnessGoal.fromString(intake.goal),
                  daysPerWeek: intake.daysPerWeek > 0 ? intake.daysPerWeek : 4,
                );
                return Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Suggested Daily Targets: ${targets.dailyCaloriesKcal} kcal · ${targets.dailyProteinGrams}g protein',
                        style: AppText.label.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        targets.rationale,
                        style: AppText.nav.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
        if (yesNo.isNotEmpty || intake.anyFlag) ...[
          const SizedBox(height: 4),
          _title(l10n.healthQuestions),
          ...yesNo,
          if (intake.lifeStage == 'pregnant')
            Text(l10n.pregnant, style: AppText.body),
          if (intake.lifeStage == 'postpartum')
            Text(l10n.hadABabyInTheLast12, style: AppText.body),
          if (intake.eatingHistory)
            Text(l10n.foodOrWeightHasFeltWorrying, style: AppText.body),
          _flag(
            intake.anyFlag
                ? (intake.doctorAck
                      ? l10n.sheTickedThatSheWillCheckWith
                      : l10n.healthAnswersToReadFirst)
                : l10n.noHealthFlagsInHerAnswers,
            warn: intake.anyFlag,
          ),
        ],
      ],
    );
  }

  /// A line that wraps in full, with an icon so it never rests on colour alone.
  Widget _flag(String text, {required bool warn}) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: warn ? AppColors.amberContainer : AppColors.tertiaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          warn ? Icons.warning_amber_rounded : Icons.check_circle_outline,
          size: 20,
          color: warn ? AppColors.amber : AppColors.onTertiaryContainer,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppText.bodyM.copyWith(
              color: warn ? AppColors.amber : AppColors.onTertiaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _healthRow(AppL10n l10n, String id, bool yes) {
    final question = healthQuestionLabel(l10n, id);
    final answer = yes ? l10n.yes_6deo : l10n.no;
    if (yes) return _flag('$question ${l10n.yes_6deo}', warn: true);
    return Semantics(
      container: true,
      label: '$question $answer',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                question,
                style: AppText.bodyM.copyWith(color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              answer,
              style: AppText.titleS.copyWith(
                color: yes ? AppColors.amber : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
