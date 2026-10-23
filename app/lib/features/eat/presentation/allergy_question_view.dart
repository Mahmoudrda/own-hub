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
///
/// The one sheet on this screen is the confirmation in front of discarding a
/// declared allergy, and a sheet is right there for the opposite reason: it
/// keeps the ticked chips visible behind it, which is the thing she needs to
/// see while deciding.
///
/// ## Why it is not in `firstRunStates`, and must not be
///
/// `firstRunStates` in `app_router.dart` is **not** a list of screens shown at
/// first run. It is the day-one rendering of a tab whose collection is empty —
/// "Home, empty", "Eat, day one" — and its purpose is that `appDestinations`
/// excludes them, so nothing can navigate to one. Putting E10 in it would make
/// this screen unroutable and take the question away.
///
/// E10 is reached from two rows on E05 and one on A02, and that is the whole
/// set. E05 renders none of Rahma's cards until `asked` is true, so the gate
/// holds without anything pushing a route out of a `build`.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
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

  /// Whether there is anything on this screen that "No, nothing" would throw
  /// away.
  bool get _anyTicked => _allergies.isNotEmpty || _dietary.isNotEmpty;

  /// Asks before discarding a declared allergy.
  ///
  /// The sheet is deliberately not symmetrical: keeping what she ticked is the
  /// filled answer and discarding it is the outlined one, because one of those
  /// two outcomes can end with a woman being shown a dish that contains sesame.
  Future<void> _confirmDiscard(BuildContext context) async {
    final l10n = AppL10n.of(context);
    final discard = await showAppSheet<bool>(
      context: context,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.discardWhatYouTicked, style: AppText.titleL),
            const SizedBox(height: 4),
            Text(
              l10n.youTickedSomethingYouAvoidTheOther,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            AppButton(
              l10n.keepWhatITicked,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: 10),
            AppButton(
              l10n.yesSaveNothing,
              variant: AppButtonVariant.outlined,
              height: 48,
              fontSize: 15,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ],
    );
    if (discard != true || !mounted) return;
    widget.onAnswered(const <AllergenTag>{}, const <DietaryTag>{});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(title: l10n.whatYouAvoid, onBack: widget.onBack),
      // ## The footer answers the question in the order it is usually answered
      //
      // It used to open with a **disabled** filled "Save what I avoid" and put
      // the only live control, outlined, underneath it. So the commonest and
      // safest answer was drawn as the lesser one, below a dead button, and the
      // screen's own primary action was unavailable the moment it appeared.
      //
      // Now nothing is ever drawn dead. Before she ticks anything there is one
      // button and it is the answer most women give. The save button appears
      // when there is something to save, and takes the primary slot then.
      footer: [
        if (_anyTicked)
          AppButton(
            l10n.saveWhatIAvoid,
            icon: Icons.check,
            onPressed: () => widget.onAnswered(_allergies, _dietary),
          ),
        AppButton(
          l10n.noNothing,
          variant: _anyTicked
              ? AppButtonVariant.outlined
              : AppButtonVariant.filled,
          height: _anyTicked ? 48 : 56,
          fontSize: _anyTicked ? 15 : 17,
          // An answer. It writes `DietaryProfile.noneNamed`, which is the value
          // the guard is entitled to treat as "asked, and named nothing".
          //
          // Once she has ticked something it is also a way to **throw that
          // away**, and it used to do so in one tap with no word said: ticking
          // sesame and then pressing this saved an empty allergy list. So it
          // asks first, in a sheet — §2 rule 9 and `product_rules_test` both
          // ban a dialog on these paths, and a sheet keeps the ticked chips
          // visible behind it, which is the thing she needs to see.
          onPressed: _anyTicked
              ? () => _confirmDiscard(context)
              : () => widget.onAnswered(
                  const <AllergenTag>{},
                  const <DietaryTag>{},
                ),
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
