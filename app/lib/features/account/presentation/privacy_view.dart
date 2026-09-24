/// A03 — Privacy.
///
/// Matches `6-v2/src/screens-account.mjs` → `A03`.
///
/// # Four switches, each one independent
///
/// Every row writes exactly one field path through [PrivacySettingsService].
/// There is no "save" button and no dialog: §2 rule 9 is undo-not-confirmation,
/// and a toggle **is** its own undo — tapping it again puts it back. The one
/// exception is turning the face blur off, which opens a sheet stating the
/// consequence (G7 §5) — a sheet, never a dialog, which the rule-9 source guard
/// enforces across `lib/features/`.
///
/// # The rule-7 line is a fact or it is absent
///
/// "Your ID and selfie were deleted after the check. Only the result is kept."
/// renders **only** when `verification.imagesDeletedAt` is set. When it is null
/// the screen says nothing about it, because G7 §5 requires A03 to render
/// "deletion pending" instead and **that string is not in the dictionary** —
/// reported, not invented. A screen that stays quiet is better than one that
/// claims a deletion which has not happened.
///
/// # Offline
///
/// A queued switch shows a quiet "Saved on your phone" chip and never a spinner
/// (G7 §4). The copy deliberately does not say the change applies everywhere:
/// offline it does not, and HANDOFF rule 6's "immediately" cannot be honoured on
/// a handset with no signal.
library;

import 'package:flutter/material.dart';

import '../../../config/legal_links.dart';
import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/app_toggle.dart';
import '../domain/media_blur_policy.dart';
import '../domain/privacy_settings.dart';
import '../domain/verification_claim.dart';
import 'account_view_models.dart';

class PrivacyView extends StatefulWidget {
  const PrivacyView({
    super.key,
    required this.service,
    this.verification = VerificationRecord.none,
    this.onBack,
    this.onOpenCycleSharing,
    this.onOpenPrivacyPolicy,
    this.onOpenTerms,
    this.onSelectTab,
  });

  final PrivacySettingsService service;

  /// Read from `users/{uid}.verification`, which is already cached from T01.
  final VerificationRecord verification;

  final VoidCallback? onBack;

  /// A03's cycle row hands off to Y12. G7 renders the row; **G9 owns the
  /// switches behind it** — two groups writing one field is a rejected plan.
  final VoidCallback? onOpenCycleSharing;

  /// Open the published policy and terms pages. The launching itself belongs to
  /// the router, which is the only place that knows how to reach the outside.
  final VoidCallback? onOpenPrivacyPolicy;
  final VoidCallback? onOpenTerms;

  final ValueChanged<String>? onSelectTab;

  @override
  State<PrivacyView> createState() => _PrivacyViewState();
}

class _PrivacyViewState extends State<PrivacyView> {
  /// Keys whose most recent write has not reached the server.
  final Set<PrivacyKey> _queued = <PrivacyKey>{};

  late PrivacySettings _settings = widget.service.current;

  Future<void> _toggle(PrivacyKey key, bool value) async {
    // Rule 6: turning the blur OFF states the consequence first. Turning it on
    // needs nothing — nobody has to be warned about becoming more private.
    if (key == PrivacyKey.blurFacesDefault &&
        MediaBlurPolicy.needsConsequenceSheet(turningOn: value)) {
      final confirmed = await _confirmBlurOff();
      if (!confirmed) return;
    }

    final outcome = await widget.service.setSwitch(key, value);
    if (!mounted) return;

    setState(() {
      _settings = outcome.settings;
      if (outcome.queuedLocally) {
        _queued.add(key);
      } else {
        _queued.remove(key);
      }
    });
  }

  Future<bool> _confirmBlurOff() async {
    final l10n = AppL10n.of(context);

    final result = await showAppSheet<bool>(
      context: context,
      children: [
        Text(l10n.blurFacesInMyPhotos, style: AppText.titleL),
        Text(
          l10n.facesArriveBlurredUnlessYouTurnThat,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        AppButton(
          l10n.close,
          variant: AppButtonVariant.outlined,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          l10n.continueLabel,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );

    return result ?? false;
  }

  /// Whether there is anybody to be visible to.
  bool get _community => AppRouter.featureFlags.isOn(Feature.community);

  /// Whether a coach can be reading anything of hers.
  bool get _coached => AppRouter.featureFlags.isOn(Feature.coachedLife);

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final view = PrivacyScreenView.from(
      settings: _settings,
      verification: widget.verification,
      queuedKeys: _queued,
    );

    return AppScaffold(
      appBar: AppTopBar(title: l10n.privacy, onBack: widget.onBack),
      footer: [AppNavBar(activeScreenId: 'T01', onSelect: widget.onSelectTab)],
      children: [
        // The note names what the switches below are for. With none of them
        // drawn it would be a sentence about members and a choice she does
        // not have, so it is replaced by the thing that is true instead:
        // there is no server in the first release and nothing leaves the
        // handset.
        AppSageNote(
          _community
              ? l10n.yourLogsWeightPhotosAndPhoneNumber
              : l10n.yourLogsWeightAndPhotosStayOn,
        ),

        // Every switch here answers "who else sees this". The first three ask
        // it about the community and the fourth about a coach, so with both
        // dark they are four controls that change nothing for anybody. Not
        // drawn rather than drawn and inert: a privacy switch that does
        // nothing is the worst kind of control to leave on a screen.
        if (_community) ...[
          _switchRow(
            l10n: l10n,
            view: view,
            key: PrivacyKey.profileVisible,
            icon: Icons.person_outline,
            title: l10n.profileVisibleToMembers,
            subtitle: l10n.nameTierAndGroups,
          ),
          _switchRow(
            l10n: l10n,
            view: view,
            key: PrivacyKey.showBests,
            icon: Icons.emoji_events_outlined,
            title: l10n.showMyPersonalBests,
            subtitle: l10n.numbersOnlyNeverWeightFromAScale,
          ),
          _switchRow(
            l10n: l10n,
            view: view,
            key: PrivacyKey.blurFacesDefault,
            icon: Icons.blur_on,
            title: l10n.blurFacesInMyPhotos,
            subtitle: l10n.onByDefaultForEveryPost,
          ),
        ],
        if (_coached)
          _switchRow(
            l10n: l10n,
            view: view,
            key: PrivacyKey.shareLogsWithCoach,
            icon: Icons.sports_outlined,
            title: l10n.myCoachCanSeeMyLogs,
            subtitle: l10n.sessionsFoodDaysAndBests,
          ),

        // Cycle sharing is G9's. A03 hosts the door, Y12 owns the switches.
        AppListItem(
          leading: const Icon(
            Icons.self_improvement,
            size: 24,
            color: AppColors.primaryDim,
          ),
          title: l10n.cycleInformation,
          subtitle: l10n.energyAndAppetiteOnlyYouChoose,
          trailing: const Icon(
            Icons.chevron_right,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
          onTap: widget.onOpenCycleSharing,
        ),

        // The two public pages the stores require to be reachable from inside
        // the app, not only from the listing. They appear once the pages have
        // an address: a row that opens nothing is worse than no row, and
        // `LegalLinks` is empty until the site is published.
        if (LegalLinks.privacyPolicy.isNotEmpty)
          AppListItem(
            leading: const Icon(
              Icons.shield_outlined,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.privacyPolicy,
            subtitle: l10n.opensInYourBrowser,
            trailing: const Icon(
              Icons.open_in_new,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: widget.onOpenPrivacyPolicy,
          ),
        if (LegalLinks.terms.isNotEmpty)
          AppListItem(
            leading: const Icon(
              Icons.description_outlined,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.termsOfUse,
            subtitle: l10n.opensInYourBrowser,
            trailing: const Icon(
              Icons.open_in_new,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: widget.onOpenTerms,
          ),

        // Rule 7 — stated only when it is true. See the file note on why there
        // is no `else` branch here.
        if (view.mayStateImagesDeleted)
          Text(
            l10n.yourIdAndSelfieWereDeletedAfter,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
      ],
    );
  }

  Widget _switchRow({
    required AppL10n l10n,
    required PrivacyScreenView view,
    required PrivacyKey key,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final row = view.rowFor(key);

    return AppListItem(
      leading: Icon(icon, size: 24, color: AppColors.primaryDim),
      title: title,
      // The queued state replaces the explanatory subtitle rather than sitting
      // beside it: "saved on your phone" is the more useful of the two at the
      // moment it is true, and two lines of small text is how a row stops being
      // read at all.
      subtitle: row.queuedLocally ? l10n.savedOnYourPhone : subtitle,
      trailing: AppToggle(
        value: row.value,
        semanticLabel: title,
        onChanged: (value) => _toggle(key, value),
      ),
      onTap: () => _toggle(key, !row.value),
    );
  }
}
