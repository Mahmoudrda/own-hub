/// A02 — Profile and settings.
///
/// Matches `6-v2/src/screens-account.mjs` → `A02`, with one row the prototype
/// does not have and the product cannot ship without: **allergies and dietary
/// preferences**.
///
/// # The allergy row is the point of this screen
///
/// `DECISIONS.md` D3 — "ask early, editable forever" — names allergies among the
/// answers that must be editable in My Profile, and `DECISIONS.md` records under
/// "Blocking Phase 2" that **no screen anywhere collects them**. That is why
/// `AppRouter.eatConstraints` is pinned to `DietaryConstraints.none` — a claim
/// that every woman was asked and named nothing, true of nobody — and why
/// `P0-EAT-01` cannot pass.
///
/// The editor is a **sheet**, not a route: HANDOFF rule 16 forbids turning a
/// state into a destination, and there is no screen id for it among the 161.
///
/// G7 hosts this row; **G2 writes the field** (G7 Q18). The write goes through
/// [DietaryProfileRepository], whose Firestore implementation belongs beside
/// `IntakeRepository` on `users/{uid}.profile`.
///
/// # Numbers this screen does not state
///
/// The prototype's header reads "Mai Farouk · Verified woman · Regular · level
/// 7". Three of those four are unrenderable as facts about her:
///
///   * the name is hers and **is** rendered — a name is a value, not copy;
///   * "Verified woman" has no standalone dictionary string, so the badge is the
///     verified icon alone;
///   * **the tier and level are not rendered at all.** `DECISIONS.md` D6: "Until
///     written here, no tier number is authoritative", and `verifiedWomanRegularLevel7`
///     is a fixed sample. `PHASE1-FIXES.md` §13 records `T05` shipping exactly
///     these three numbers as her personal facts.
///
/// Likewise "Period day 2 · symptom tracking" and "Sara Hany · day 9 of 30" are
/// the mockup's samples with no parameterised form in the dictionary, so those
/// rows carry no subtitle rather than a subtitle about somebody else.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_avatar.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../app_state/kitten_setting.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/app_toggle.dart';
import '../../../ui/hand/hand.dart';
import '../domain/dietary_profile.dart';
import 'allergen_labels.dart';
import '../domain/privacy_settings.dart';
import '../domain/verification_claim.dart';
import 'account_view_models.dart';
import '../../../ui/medical_disclaimer.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({
    super.key,
    required this.dietaryRepository,
    this.firstName,
    this.verification = VerificationRecord.none,
    this.notify = NotifySettings.initial,
    this.onBack,
    this.onOpenCycle,
    this.onOpenCoach,
    this.onOpenTraining,
    this.onOpenLanguage,
    this.onOpenNotifications,
    this.onOpenPrivacy,
    this.onOpenSafetyCentre,
    this.onOpenYourData,
    this.onOpenAllScreens,
    this.onOpenAdmin,
    this.onSelectTab,
  });

  /// G2's port. A02 renders the row; G2 owns the field.
  final DietaryProfileRepository dietaryRepository;

  /// Typed by her at C13. Null renders the avatar without an initial rather
  /// than inventing a name.
  final String? firstName;

  final VerificationRecord verification;
  final NotifySettings notify;

  final VoidCallback? onBack;
  final VoidCallback? onOpenCycle;
  final VoidCallback? onOpenCoach;

  /// The four setup questions, reopened — `O01` to `O05`.
  ///
  /// D3's "editable forever" had no door here at all. Her goal, her days a
  /// week, her session length, her equipment and what the programme has to
  /// train around were collected once, in a flow that only sign-up could reach,
  /// and after that there was no screen in the product that could change any of
  /// them. Null leaves the row off, the way every other optional row here
  /// behaves.
  final VoidCallback? onOpenTraining;

  final VoidCallback? onOpenLanguage;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenPrivacy;
  final VoidCallback? onOpenSafetyCentre;

  /// The testing index of every screen. Null — and the row absent — whenever
  /// an account is required.
  final VoidCallback? onOpenAllScreens;

  /// The owner's admin console. Null, and the row absent, in every build but
  /// the admin build (`tool/admin_access.sh build`); a store build cannot
  /// resolve the console at all.
  final VoidCallback? onOpenAdmin;

  /// Account deletion.
  ///
  /// This was a callback with nothing behind it and a row that rendered anyway,
  /// so the tap did nothing: Apple 2.1 for the dead control, and 5.1.1(v) for
  /// an account that can be made in the app and not removed in it. The router
  /// now opens `your_data_sheet.dart`, which explains what deleting takes away
  /// and then takes it away.
  ///
  /// The sentences that were missing are minted. The row says **delete**
  /// rather than "download everything, or delete": there is no server in this
  /// build and no export to hand her, and the sheet says so in plain words
  /// rather than showing a download button that would produce nothing.
  final VoidCallback? onOpenYourData;

  final ValueChanged<String>? onSelectTab;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late DietaryProfile _dietary = widget.dietaryRepository.read();

  Future<void> _editDietary() async {
    final saved = await showAppSheet<DietaryProfile>(
      context: context,
      children: [
        _DietaryEditor(
          initial: _dietary,
          onSave: (profile) => Navigator.of(context).pop(profile),
        ),
      ],
    );

    if (saved == null || !mounted) return;

    // G2 writes the field. A02 never touches `profile.allergies` itself.
    final merged = await widget.dietaryRepository.save(
      allergies: saved.allergies,
      dietary: saved.dietary,
    );
    if (!mounted) return;
    setState(() => _dietary = merged);
  }

  /// Whether this build has a community at all. Several rows here describe
  /// one, and a subtitle about members is a claim as much as a button is.
  bool get _community => AppRouter.featureFlags.isOn(Feature.community);

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final view = ProfileScreenView.from(
      verification: widget.verification,
      dietary: _dietary,
      notify: widget.notify,
      firstName: widget.firstName,
    );

    return AppScaffold(
      // This page carried no title at all: a back arrow, an illustration, her
      // picture and a list of rows, on the screen half the product hangs off.
      // The route table has always called it "Profile and settings"; the
      // dictionary's own name for it is the one the avatar announces, so the
      // page and the control that opens it now say the same words.
      appBar: AppTopBar(title: l10n.yourProfile, onBack: widget.onBack),
      // Its own id, which is what the bar's `activeScreenId` has always asked
      // for: "the screen currently shown". This passed `'T01'`, and the bar has
      // a deliberate rule that the active tab is not a link to itself — so the
      // Home tab was drawn as the current page, given no `onTap`, and did
      // nothing, on a settings screen where Home is the one place she is most
      // likely to be heading. A02 is not a tab, so naming itself leaves all
      // three tabs live and none of them marked.
      footer: [AppNavBar(activeScreenId: 'A02', onSelect: widget.onSelectTab)],
      children: [
        _header(l10n, view),

        // First, because it is the only row that changes what the app gives
        // her: her goal, her days a week, her minutes a session, her equipment
        // and what the programme has to train around.
        if (widget.onOpenTraining != null)
          _row(
            icon: Icons.fitness_center_outlined,
            title: l10n.yourTraining,
            subtitle: l10n.yourGoalYourDaysAndWhatYou,
            onTap: widget.onOpenTraining,
          ),

        _row(
          icon: Icons.self_improvement,
          title: l10n.myCycle,
          onTap: widget.onOpenCycle,
        ),
        // Hiring a coach is the marketplace, and the marketplace waits on a
        // payment rail. D11 moved this row here from the deleted fifth tab;
        // it comes back the day that flag does.
        if (AppRouter.screenIsOn('H01'))
          _row(
            icon: Icons.sports_outlined,
            title: l10n.myCoach,
            onTap: widget.onOpenCoach,
          ),

        // D3's row. The one the Eat safety guard has been waiting for.
        _row(
          icon: Icons.restaurant_outlined,
          title: l10n.allergiesAndDietaryPreferences,
          subtitle: l10n.anythingYouCannotEat,
          onTap: _editDietary,
        ),

        // The language chooser lives in the sign-up flow and is a setting all
        // the same, which is why `AppRouter.ungatedScreens` keeps it
        // reachable with sign-up dark. Without that this row was the one
        // control in the product that could strand a woman in a language she
        // does not read.
        _row(
          icon: Icons.language,
          title: l10n.language,
          subtitle: l10n.english_imxmn,
          onTap: widget.onOpenLanguage,
        ),
        _row(
          icon: Icons.notifications_none,
          title: l10n.notifications,
          // True only while her notification settings ARE the defaults this
          // sentence describes. Otherwise it is a statement about somebody
          // else's quiet hours.
          subtitle: view.notifyIsDefault ? l10n.oneADayQuiet10pmTo8am : '',
          onTap: widget.onOpenNotifications,
        ),
        // The kitten that guides her through onboarding. Off, it is still
        // there but never moves.
        AppListItem(
          leading: const Icon(
            Icons.pets_outlined,
            size: 24,
            color: AppColors.primaryDim,
          ),
          title: l10n.movingKitten,
          subtitle: KittenSetting.instance.moves
              ? l10n.theKittenShowsYouAroundAndMoves
              : l10n.theKittenStaysStill,
          trailing: AppToggle(
            key: const ValueKey('kitten-moves-toggle'),
            value: KittenSetting.instance.moves,
            semanticLabel: l10n.movingKitten,
            onChanged: _setKittenMoves,
          ),
          onTap: () => _setKittenMoves(!KittenSetting.instance.moves),
        ),
        _row(
          icon: Icons.lock_outline,
          title: l10n.privacy,
          // "Who sees your profile and wins" describes a profile other women
          // read. With the community dark nobody sees either, so the row
          // carries no subtitle rather than a promise about a room that is
          // not open.
          subtitle: _community ? l10n.whoSeesYourProfileAndWins : '',
          onTap: widget.onOpenPrivacy,
        ),
        _row(
          icon: Icons.shield_outlined,
          title: l10n.safetyCentre,
          // Same rule: reports and blocked members are about members. What is
          // left on A04 with the community off is the help route and the
          // emergency line, which are worth keeping and are not a list.
          subtitle: _community ? l10n.reportsBlockedMembersHelp : '',
          onTap: widget.onOpenSafetyCentre,
        ),
        _row(
          icon: Icons.delete_outline,
          title: l10n.yourData,
          subtitle: l10n.deleteYourAccountAndEverythingInIt,
          onTap: widget.onOpenYourData,
        ),
        if (widget.onOpenAdmin != null)
          _row(
            icon: Icons.admin_panel_settings_outlined,
            title: l10n.adminConsole,
            subtitle: l10n.contentEventsCountsAndLogs,
            onTap: widget.onOpenAdmin,
          ),
        if (widget.onOpenAllScreens != null)
          _row(
            icon: Icons.grid_view,
            title: l10n.allScreens,
            subtitle: l10n.openAnyScreenForTesting,
            onTap: widget.onOpenAllScreens,
          ),
        // About Own Hub, at the foot of the page: what the app is not.
        const MedicalDisclaimer(),
      ],
    );
  }

  Widget _header(AppL10n l10n, ProfileScreenView view) {
    final name = view.firstName;

    return Row(
      children: [
        AppAvatar(firstName: name, size: 56),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              // Her name on the line, as on the first page of a diary: the
              // only mark on a page that is otherwise settings.
              if (name != null && name.isNotEmpty)
                Flexible(
                  child: HandUnderline(
                    level: HandLevel.crafted,
                    gap: 3,
                    child: Text(
                      name,
                      textWidthBasis: TextWidthBasis.longestLine,
                      style: EditorialType.section,
                    ),
                  ),
                ),
              if (view.verified) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified,
                  size: 18,
                  color: AppColors.primaryDim,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _setKittenMoves(bool moves) {
    unawaited(KittenSetting.instance.set(moves));
    setState(() {});
  }

  Widget _row({
    required IconData icon,
    required String title,
    String subtitle = '',
    VoidCallback? onTap,
  }) {
    return AppListItem(
      leading: Icon(icon, size: 24, color: AppColors.primaryDim),
      title: title,
      subtitle: subtitle,
      trailing: const Icon(
        Icons.chevron_right,
        size: 22,
        color: AppColors.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

/// The allergy and dietary editor — a **branch of A02**, never a route.
///
/// The vocabulary is [AllergenTag]'s sixteen, drawn from one shared label table
/// so this screen and `G17` and `E10` cannot disagree about what she declared.
/// It grew from four when Rahma's book was authored and dishes started carrying
/// real allergen data; `dietary_profile.dart` records where each of the sixteen
/// comes from. Every label is in the dictionary in both languages, and nothing
/// here invents a category content has not written: a plausible-looking allergen
/// list is the fabricated safety guarantee this whole feature exists to avoid.
class _DietaryEditor extends StatefulWidget {
  const _DietaryEditor({required this.initial, required this.onSave});

  final DietaryProfile initial;
  final ValueChanged<DietaryProfile> onSave;

  @override
  State<_DietaryEditor> createState() => _DietaryEditorState();
}

class _DietaryEditorState extends State<_DietaryEditor> {
  late final Set<AllergenTag> _allergies = {...?widget.initial.allergies};
  late Set<DietaryTag> _dietary = {...?widget.initial.dietary};

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final dietaryLabels = <DietaryTag, String>{
      DietaryTag.everything: l10n.everything,
      DietaryTag.vegetarianWeekdays: l10n.vegetarianOnWeekdays,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.allergiesAndDietaryPreferences, style: AppText.titleL),
        const SizedBox(height: 14),

        Text(
          l10n.anythingYouCannotEat,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
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

        const SizedBox(height: 14),
        Text(
          l10n.howYouUsuallyEat,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in DietaryTag.values)
              AppChip(
                dietaryLabels[tag]!,
                selected: _dietary.contains(tag),
                // Single choice: "everything" and a restriction are not both
                // true, and a woman who picks one has answered the question.
                onTap: () => setState(() => _dietary = {tag}),
              ),
          ],
        ),

        const SizedBox(height: 16),
        AppButton(
          l10n.save,
          // Saving with nothing selected is a real answer — "I have no
          // allergies" — and is what turns `unknown` into `none`. That is the
          // whole reason this screen exists, so the button is never disabled.
          onPressed: () => widget.onSave(
            DietaryProfile(allergies: _allergies, dietary: _dietary),
          ),
        ),
      ],
    );
  }
}
