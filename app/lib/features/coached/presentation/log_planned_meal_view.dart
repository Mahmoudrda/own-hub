/// G10 — log the meal her coach planned.
///
/// Matches `6-v2/src/screens-coached.mjs` → `G10`. Its design note: *"Opening
/// lunch from Home lands on today's planned lunch with the serving and the
/// coach note ready… because most days, she ate the thing."*
///
/// ## The blocked state is a designed state
///
/// When [blockedReason] is non-null the planned row is **disabled with its
/// reason** and "Ate this" is unavailable. That is `P0-INTAKE-03`'s second half:
/// a conflicting meal should be refused at publish time, and if one ever
/// arrives anyway it must not be one tap from being logged. The reason comes
/// from `AllergyGuard` through `PlannedMealService`; this screen renders it and
/// decides nothing.
///
/// With her allergies unreadable — a cold start, a new install — the guard
/// fails closed and this screen shows the same blocked state. **Unknown is not
/// absent.**
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_scaffold.dart';

class LogPlannedMealView extends StatelessWidget {
  const LogPlannedMealView({
    super.key,
    this.onClose,
    this.onLog,
    this.onAdjustPortion,
    this.onAlternative,
    this.onSomethingElse,
    this.onRecent,
    this.onSearch,
    this.title,
    this.foodName,
    this.foodMeta,
    this.coachNote,
    this.ingredients,
    this.blockedReason,
  });

  final VoidCallback? onClose;

  /// "Ate this". Logs immediately with five seconds to undo — never a
  /// confirmation. Null when the row is blocked.
  final VoidCallback? onLog;

  final VoidCallback? onAdjustPortion;
  final VoidCallback? onAlternative;
  final VoidCallback? onSomethingElse;
  final VoidCallback? onRecent;
  final VoidCallback? onSearch;

  final String? title;
  final String? foodName;
  final String? foodMeta;

  /// Her coach's note on this item. Absent when she wrote none.
  final String? coachNote;

  final List<String>? ingredients;

  /// Why this row cannot be logged, in her own words — an allergen the guard
  /// named, or the fact that her constraints could not be read. Null means the
  /// row is clear.
  final String? blockedReason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final blocked = blockedReason != null;

    return AppScaffold(
      appBar: AppTopBar(
        title: title ?? l10n.logLunch,
        onBack: onClose,
        leadingIcon: Icons.close,
      ),
      footer: [
        AppButton(
          l10n.ateThis,
          icon: Icons.check,
          // Disabled while the guard's verdict is outstanding. The block is in
          // the domain; this is the door it closes.
          onPressed: blocked ? null : onLog,
        ),
      ],
      children: [
        Row(
          children: [
            Expanded(child: AppChip(l10n.fromYourPlan, selected: true)),
            const SizedBox(width: 8),
            Expanded(child: AppChip(l10n.recent, onTap: onRecent)),
            const SizedBox(width: 8),
            Expanded(child: AppChip(l10n.search, onTap: onSearch)),
          ],
        ),
        AppCard(
          gap: 10,
          children: [
            AppMedia(
              height: 120,
              kind: AppMediaKind.photo,
              badge: l10n.foodPhoto,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(foodName ?? l10n.koshariBowlMedium, style: AppText.titleL),
                // "1 serving · 540 kcal · 18 g protein" is koshari's line in
                // the mockup, and it was read out for whatever dish this
                // screen was given. No figures unless they are this dish's.
                if (foodMeta case final meta?) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            if (blocked)
              AppCard(
                variant: AppCardVariant.error,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 20,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          blockedReason!,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            if (coachNote != null || foodName == null)
              Text(
                coachNote ?? l10n.sarasNoteAddTheSaladIfYou,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item
                    in ingredients ?? [l10n.riceLentilsPasta, l10n.tomatoSauce])
                  AppChip(item),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: AppButton(
                l10n.adjustPortion,
                variant: AppButtonVariant.outlined,
                height: 44,
                fontSize: 14,
                onPressed: onAdjustPortion,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AppButton(
                l10n.anAlternative,
                variant: AppButtonVariant.outlined,
                height: 44,
                fontSize: 14,
                onPressed: onAlternative,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AppButton(
                l10n.somethingElse,
                variant: AppButtonVariant.text,
                height: 44,
                fontSize: 14,
                onPressed: onSomethingElse,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
