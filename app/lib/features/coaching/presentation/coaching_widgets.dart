/// The chrome and the small pieces the six marketplace screens share.
///
/// Built once here for the reason `coach_setup_scaffold.dart` gives: six
/// screens drawing their own version of the same row is six chances for one of
/// them to state a figure the others withhold.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/hand/hand.dart';
import '../domain/coach_directory.dart';
import 'coaching_money.dart';

/// Navigates by screen id, or calls the override a test supplied.
///
/// The literal screen id stays visible at every call site, which is what
/// `nav_reachability_test` recovers the navigation graph from once the router
/// wires these screens.
void goToScreen(
  BuildContext context,
  String screenId, [
  VoidCallback? override,
]) {
  if (override != null) {
    override();
    return;
  }
  AppRouter.goTo(context, screenId);
}

/// The dictionary's word for one facet.
///
/// A `switch` over the enum rather than a map, so adding a facet is a compile
/// error here instead of a silently unlabelled chip.
String specialtyLabel(AppL10n l10n, CoachingSpecialty specialty) =>
    switch (specialty) {
      CoachingSpecialty.postpartum => l10n.postpartum,
      CoachingSpecialty.beginners => l10n.beginners,
      CoachingSpecialty.strength => l10n.strength,
      CoachingSpecialty.pregnancy => l10n.pregnantOrPostpartum,
    };

String languageLabel(AppL10n l10n, CoachingLanguage language) =>
    switch (language) {
      CoachingLanguage.arabic => l10n.arabic,
      CoachingLanguage.english => l10n.english,
    };

/// Her rating, drawn as an icon and a figure rather than read from a string.
///
/// Returns null below the five-review floor, and null draws nothing at all —
/// no empty stars, no "no reviews yet", no placeholder. A coach with four
/// reviews is not a coach with a bad rating.
///
/// The star is an [Icon]. `'4.8 ★ (126)'` lives in the dictionary and is
/// exactly the defect `baked_in_samples_test` counts: a mockup's figure
/// rendered as a fact about a real woman.
Widget? ratingRow(DirectoryRow row) {
  final text = ratingText(row.ratingToDisplay);
  if (text == null) return null;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.star_rounded, size: 16, color: AppColors.amber),
      const SizedBox(width: 3),
      Text(
        text,
        style: AppText.label.copyWith(color: AppColors.onSurfaceVariant),
      ),
      const SizedBox(width: 4),
      Text(
        '(${row.reviewCount})',
        style: AppText.label.copyWith(color: AppColors.onSurfaceVariant),
      ),
    ],
  );
}

/// A quiet line of explanation under a heading.
class CoachingNote extends StatelessWidget {
  const CoachingNote(this.text, {super.key, this.tone});

  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppText.bodyM.copyWith(color: tone ?? AppColors.onSurfaceVariant),
  );
}

/// A heading with the spacing the prototype's `sectionHead` gives.
class CoachingSectionHead extends StatelessWidget {
  const CoachingSectionHead(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      title,
      style: AppText.titleM.copyWith(color: AppColors.onSurface),
    ),
  );
}

/// An amber strip that explains rather than blocks.
///
/// Used for every refusal in this feature — offline, unverified, no accepted
/// enquiry, a full coach. It is a strip and not a dialog on purpose: rule 9's
/// guard bans `showDialog` across every feature, and a refusal a woman can read
/// while still seeing the screen she was on is better than one that covers it.
class CoachingNotice extends StatelessWidget {
  const CoachingNotice({
    super.key,
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  // Drawn the way an amber card is: precise, with no loose hand in it. A
  // refusal is where she needs to trust the page most.
  @override
  Widget build(BuildContext context) {
    return HandSurface(
      seed: handSeed(['notice', text]),
      fill: AppColors.amberContainer,
      frame: AppColors.amber.withValues(alpha: 0.35),
      frameWidth: 1,
      level: HandLevel.structural,
      radius: 4,
      looseCorner: 12,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.amber),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: AppText.bodyM.copyWith(color: AppColors.onSurface),
            ),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              child: Text(
                action!,
                style: AppText.label.copyWith(color: AppColors.primaryDim),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A circle with her initial, for a product that has no coach photographs yet.
class CoachAvatar extends StatelessWidget {
  const CoachAvatar(this.name, {super.key, this.diameter = 48});

  final String name;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceHigh,
        shape: BoxShape.circle,
      ),
      child: Text(
        trimmed.isEmpty ? '' : trimmed.characters.first,
        style: AppText.titleM.copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }
}
