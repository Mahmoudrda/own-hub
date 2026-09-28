/// E10 — "Is there anything you cannot eat?"
///
/// **This screen is the reason the recipe library can exist at all**, and it has
/// to land before any dish carrying an allergen is reachable.
///
/// ## The hazard it closes
///
/// `AppRouter.eatConstraints` returned `DietaryConstraints.none` for every woman
/// who had never opened A02's dietary editor. `none` is not "unknown": it is a
/// **claim**, and the claim is *asked, and named nothing*. It was true of nobody,
/// because nothing asked. `AllergyGuard.assess()` short-circuits on an empty
/// allergy set and clears every dish unconditionally, so the moment a recipe
/// shipped with `sesame` in its allergen set, a woman allergic to sesame would
/// have been handed it, silently, by a guard that now looked live.
///
/// `allergy_interlock_test.dart` exists to turn that ordering into a red build,
/// and its own failure message says what to do: "Fix the ORDER, not this test."
/// This is the fix. Nothing here edits that test.
///
/// ## "No, nothing" is an answer, not a skip
///
/// The two buttons write different things. The chips write
/// `allergies: {…}, dietary: {…}`; `لا، ولا حاجة` writes
/// `allergies: {}, dietary: {}`, which is `DietaryProfile.noneNamed` — the one
/// value the repository documents as "only reachable by her actually answering".
///
/// **There is no skip that leaves `asked` false.** Backing out with the system
/// gesture leaves it false and the library stays behind the question, which is
/// the honest fail-closed behaviour: we would rather show her nothing than show
/// her a dish we have not been told is safe for her to see.
///
/// ## It is a route, and it is not a dialog
///
/// `product_rules_test.dart` bans `showDialog` and `AlertDialog` under
/// `lib/features/`, and the ban is right: a dialog is a thing you dismiss, and
/// this is a thing you answer. A full route also means the sixteen chips have
/// room at 1.6x text in Arabic, which a sheet does not.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_scaffold.dart';
import '../../account/domain/dietary_profile.dart';
import '../../account/presentation/allergen_labels.dart';

class AllergyQuestionView extends StatefulWidget {
  const AllergyQuestionView({
    super.key,
    required this.initial,
    required this.onAnswered,
    this.onBack,
    this.onOpenProfile,
  });

  /// What she has already said, if she has said anything. An unasked profile
  /// starts every chip unselected, which is not the same as her having cleared
  /// them.
  final DietaryProfile initial;

  /// Called with her answer. An empty allergy set here is a real answer and the
  /// caller must save it as one.
  final void Function(Set<AllergenTag> allergies, Set<DietaryTag> dietary)
  onAnswered;

  final VoidCallback? onBack;

  /// A02, where she can change this afterwards. The screen says so out loud,
  /// because a question asked once with no visible way back is a question people
  /// answer defensively.
  final VoidCallback? onOpenProfile;

  @override
  State<AllergyQuestionView> createState() => _AllergyQuestionViewState();
}

class _AllergyQuestionViewState extends State<AllergyQuestionView> {
  late final Set<AllergenTag> _allergies = {...?widget.initial.allergies};
  late Set<DietaryTag> _dietary = {...?widget.initial.dietary};

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.whatYouAvoid,
        onBack: widget.onBack,
      ),
      footer: [
        AppButton(
          l10n.saveWhatIAvoid,
          icon: Icons.check,
          // Disabled while nothing is ticked, because an empty selection saved
          // through this button would be indistinguishable from the explicit
          // "no, nothing" below it, and the whole point of that button is that
          // it is a separate, deliberate act.
          onPressed: _allergies.isEmpty && _dietary.isEmpty
              ? null
              : () => widget.onAnswered(_allergies, _dietary),
        ),
        AppButton(
          l10n.noNothing,
          variant: AppButtonVariant.outlined,
          height: 48,
          fontSize: 15,
          // An answer. It writes `DietaryProfile.noneNamed`, which is the value
          // the guard is entitled to treat as "asked, and named nothing".
          onPressed: () =>
              widget.onAnswered(const <AllergenTag>{}, const <DietaryTag>{}),
        ),
      ],
      children: [
        Text(l10n.isThereAnythingYouCannotEat, style: AppText.headline),
        Text(
          l10n.tickAnythingYouAvoidDishesThatContain,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in AllergenTag.values)
              AppChip(
                allergenLabel(l10n, tag),
                selected: _allergies.contains(tag),
                onTap: () => setState(() {
                  if (!_allergies.remove(tag)) _allergies.add(tag);
                }),
              ),
          ],
        ),
        // Fava beans are in the list above and are not an allergen. Said here
        // rather than left for her to wonder about, because a woman with no
        // allergies reading "fava beans" in an allergy list reasonably concludes
        // the list is not to be trusted.
        Text(
          l10n.favaBeansAreListedBecauseOfFavism,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        Text(l10n.howYouUsuallyEat, style: AppText.titleM),
        AppChipRow(
          grow: false,
          items: [l10n.everything, l10n.vegetarianOnWeekdays],
          selected: {
            for (final tag in _dietary) DietaryTag.values.indexOf(tag),
          },
          onTap: (index) => setState(() {
            final tapped = DietaryTag.values[index];
            _dietary = _dietary.contains(tapped)
                ? <DietaryTag>{}
                : <DietaryTag>{tapped};
          }),
        ),
        GestureDetector(
          onTap: widget.onOpenProfile,
          // The minimum target, stated rather than hoped for: this is a text
          // link and text is shorter than a finger.
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.youCanChangeThisAnyTimeFrom,
              style: AppText.bodyM.copyWith(color: AppColors.primaryDim),
            ),
          ),
        ),
      ],
    );
  }
}
