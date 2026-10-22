/// First time at the gym: four short steps before her first gym session.
///
/// `docs/plan/FREE-LAUNCH-COACHING-PLAN.md` §12 U0.1. One purpose a step, plain
/// words, nothing to download, and nothing it asks of her beyond reading. It is
/// a help, so it is optional: Skip leaves without starting anything, and the
/// caller remembers that she has seen it.
///
/// The practice set on the third step is a toy. It writes nothing: no session,
/// no points, no number a coach could read. Undo takes it back, as it does for
/// a real set.
///
/// It reads nothing from the app's singletons, so it can be shown on its own.
/// Every control is 48 points or more and the page scrolls, so it holds at the
/// largest text size.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';

/// The number of steps.
const int kGymGuideSteps = 4;

class FirstGymGuideView extends StatefulWidget {
  const FirstGymGuideView({
    super.key,
    required this.onStartWorkout,
    required this.onClose,
  });

  /// The last step's button: her actual workout.
  final VoidCallback onStartWorkout;

  /// Skip. Leaves the guide and starts nothing.
  final VoidCallback onClose;

  @override
  State<FirstGymGuideView> createState() => _FirstGymGuideViewState();
}

class _FirstGymGuideViewState extends State<FirstGymGuideView> {
  int _step = 0;

  /// The practice set on step three. Local to this screen and gone with it.
  bool _practiced = false;

  void _go(int step) => setState(() => _step = step);

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final last = _step == kGymGuideSteps - 1;

    final (icon, title, body) = switch (_step) {
      0 => (
        Icons.fitness_center,
        l10n.beforeYouStart,
        l10n.todaysSessionIsShortBringWaterAnd,
      ),
      1 => (
        Icons.search,
        l10n.findYourEquipment,
        l10n.lookForTheStationYourFirstMove,
      ),
      2 => (Icons.repeat, l10n.whatASetIs, l10n.aRepIsOneTimeThroughA),
      _ => (
        Icons.favorite_border,
        l10n.startWithConfidence,
        l10n.takeItAtWhateverPaceFeelsRight,
      ),
    };

    return AppScaffold(
      footerScrollsWhenLarge: true,
      appBar: AppTopBar(title: l10n.firstTimeAtTheGym),
      footer: [
        if (last)
          AppButton(
            l10n.startWorkout,
            key: const ValueKey('gym-guide-start'),
            icon: Icons.play_arrow,
            onPressed: widget.onStartWorkout,
          )
        else
          AppButton(
            l10n.next,
            key: const ValueKey('gym-guide-next'),
            onPressed: () => _go(_step + 1),
          ),
        Row(
          children: [
            Expanded(
              child: _step == 0
                  ? const SizedBox.shrink()
                  : AppButton(
                      l10n.back,
                      key: const ValueKey('gym-guide-back'),
                      variant: AppButtonVariant.text,
                      height: 48,
                      fontSize: 15,
                      onPressed: () => _go(_step - 1),
                    ),
            ),
            Expanded(
              child: AppButton(
                l10n.skip,
                key: const ValueKey('gym-guide-skip'),
                variant: AppButtonVariant.text,
                height: 48,
                fontSize: 15,
                onPressed: widget.onClose,
              ),
            ),
          ],
        ),
      ],
      children: [
        Column(
          key: ValueKey('gym-guide-step-$_step'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.countOfTotal(
                countLabel(_step + 1),
                countLabel(kGymGuideSteps),
              ),
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Icon(icon, size: 40, color: AppColors.primaryDim),
            ),
            const SizedBox(height: 12),
            Text(title, style: AppText.headline),
            const SizedBox(height: 8),
            Text(body, style: AppText.bodyM),
            if (_step == 2) ...[
              const SizedBox(height: 8),
              Text(
                l10n.logTheTotalBarIncluded,
                key: const ValueKey('gym-guide-total-line'),
                style: AppText.bodyM,
              ),
              const SizedBox(height: 16),
              if (!_practiced)
                AppButton(
                  l10n.tryItLogAPracticeSet,
                  key: const ValueKey('gym-guide-practice'),
                  variant: AppButtonVariant.tonal,
                  height: 48,
                  fontSize: 15,
                  onPressed: () => setState(() => _practiced = true),
                )
              else ...[
                AppSageNote(l10n.practiceSetLoggedNothingIsSaved),
                const SizedBox(height: 8),
                AppButton(
                  l10n.undo,
                  key: const ValueKey('gym-guide-practice-undo'),
                  variant: AppButtonVariant.text,
                  height: 48,
                  fontSize: 15,
                  onPressed: () => setState(() => _practiced = false),
                ),
              ],
            ],
          ],
        ),
      ],
    );
  }
}
