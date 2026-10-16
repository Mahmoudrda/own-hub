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
/// # Health backup (S17)
///
/// Her cycle, check-ins, measurements, life stage and allergies stay on the
/// phone by default. The "Back up my health data" row is drawn only when there
/// is an account to back up to ([PrivacyView.healthBackup] is non-null).
/// Turning it on opens a sheet that names the data, where it goes (Frankfurt,
/// and the United States for the sign-in phone number) and that it can be
/// turned off; agreeing records the consent on the server first and only then
/// starts the backup. The sheet wording is PENDING COUNSEL REVIEW (PDPL health
/// data and transfer-abroad consent) and is not a legal opinion.
///
/// # Crash reports (privacy policy v3, 3.7)
///
/// Sent only if she allows them, and off until she does. The row is drawn
/// when the router hands in [PrivacyView.onCrashReportsChanged]; turning it
/// off also deletes any report still waiting on the phone.
///
/// # Help improve Own Hub (usage statistics)
///
/// Its own switch, separate from crash reports: drawn when the router hands
/// in [PrivacyView.onAnalyticsChanged], off until she turns it on. Turning it
/// off stops collection at once and resets the statistics ID on this phone
/// (`lib/app_state/analytics_consent.dart`).
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
import '../../signup/domain/review_request.dart';
import '../domain/health_backup.dart';
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
    this.healthBackup,
    this.onSignInAgain,
    this.crashReportsAllowed = false,
    this.onCrashReportsChanged,
    this.analyticsAllowed = false,
    this.onAnalyticsChanged,
  });

  /// Whether she has allowed usage statistics.
  final bool analyticsAllowed;

  /// Records and applies her usage-statistics choice. Null hides the row.
  final Future<void> Function(bool allowed)? onAnalyticsChanged;

  /// Whether she has allowed crash reports.
  final bool crashReportsAllowed;

  /// Records and applies her crash-report choice. Null hides the row.
  final Future<void> Function(bool allowed)? onCrashReportsChanged;

  /// The server did not accept her sign-in: out to sign in again (N4).
  final VoidCallback? onSignInAgain;

  final PrivacySettingsService service;

  /// The health backup switch, or null when there is no account to back up
  /// to (signed out, or no back end), in which case the row is not drawn.
  final HealthBackupController? healthBackup;

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

  late bool _crashReports = widget.crashReportsAllowed;

  late bool _analytics = widget.analyticsAllowed;

  Future<void> _toggleAnalytics(bool value) async {
    final change = widget.onAnalyticsChanged;
    if (change == null) return;
    setState(() => _analytics = value);
    await change(value);
  }

  Future<void> _toggleCrashReports(bool value) async {
    final change = widget.onCrashReportsChanged;
    if (change == null) return;
    setState(() => _crashReports = value);
    await change(value);
  }

  /// True while the health consent call is in flight.
  bool _healthBusy = false;

  /// True after the health consent call failed; nothing changed.
  bool _healthFailed = false;

  /// True after turning it off when the server could not be reached: off on
  /// this phone, the cloud copy removed once she is back online.
  bool _healthWithdrawPending = false;

  Future<void> _toggleHealth(bool turnOn) async {
    final controller = widget.healthBackup;
    if (controller == null || _healthBusy) return;
    if (turnOn) {
      final agreed = await _confirmHealthBackup();
      if (!agreed || !mounted) return;
    }
    setState(() {
      _healthBusy = true;
      _healthFailed = false;
      _healthWithdrawPending = false;
    });
    final ok = turnOn ? await controller.enable() : await controller.disable();
    if (!mounted) return;
    setState(() {
      _healthBusy = false;
      // Turning it on changes nothing unless the server agreed. Turning it
      // off always takes effect here; only the cloud removal can wait.
      _healthFailed = turnOn && !ok;
      _healthWithdrawPending = !turnOn && !ok;
    });
  }

  /// The health and transfer-abroad consent. A sheet, never a dialog.
  /// Wording PENDING COUNSEL REVIEW.
  Future<bool> _confirmHealthBackup() async {
    final l10n = AppL10n.of(context);
    final body = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);

    final result = await showAppSheet<bool>(
      context: context,
      children: [
        Text(l10n.backUpYourHealthData, style: AppText.titleL),
        Text(l10n.ifYouTurnThisOnACopy, style: body),
        Text(l10n.theCopyIsStoredOnGoogleCloud, style: body),
        Text(l10n.thisIsHealthDataSoWeOnly, style: body),
        Text(l10n.ifYouDontTurnItOnNothing, style: body),
        // The policy, one tap away. Version 1 of the consent is the Egyptian
        // wording (DECISIONS.md D45).
        if (widget.onOpenPrivacyPolicy != null)
          AppButton(
            l10n.readThePrivacyPolicy,
            variant: AppButtonVariant.text,
            height: 44,
            fontSize: 15,
            onPressed: widget.onOpenPrivacyPolicy,
          ),
        AppButton(
          l10n.notNow,
          variant: AppButtonVariant.outlined,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          l10n.iAgreeBackUpMyHealthData,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );

    return result ?? false;
  }

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
      // Its own id. `'T01'` marked the Home tab as the current page, and the
      // bar gives the active tab no `onTap` on purpose, so Home was drawn and
      // dead on a screen nobody stays on. A03 is not a tab.
      footer: [AppNavBar(activeScreenId: 'A03', onSelect: widget.onSelectTab)],
      children: [
        // The note names what the switches below are for. With none of them
        // drawn it would be a sentence about members and a choice she does
        // not have, so it is replaced by the thing that is true instead: what
        // goes to her account, what stays on the phone, and that photos of
        // her ID card and selfie are never stored.
        AppSageNote(
          _community
              ? l10n.yourMealsWorkoutsWeightPhotosAndPhone
              : l10n.yourWorkoutsMealsAndSetupAnswersAre,
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
            title: l10n.myCoachCanSeeMyMealsAnd,
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

        // Health data stays on the phone unless she opts in, server first.
        if (widget.healthBackup case final backup?) ...[
          AppListItem(
            leading: const Icon(
              Icons.backup_outlined,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.backUpMyHealthData,
            subtitle: backup.enabled
                ? l10n.onACopyIsKeptInYour
                : l10n.offYourCycleCheckInsMeasurementsLife,
            trailing: AppToggle(
              key: const ValueKey('health-backup-toggle'),
              value: backup.enabled,
              semanticLabel: l10n.backUpMyHealthData,
              onChanged: _healthBusy ? null : (value) => _toggleHealth(value),
            ),
            onTap: _healthBusy ? null : () => _toggleHealth(!backup.enabled),
          ),
          if (_healthFailed)
            Text(
              switch (classifyCallFailure(backup.lastFailure ?? Object())) {
                CallFailureKind.appCannotReach =>
                  l10n.thisCopyOfTheAppCannotReach_mr83s,
                CallFailureKind.signInAgain =>
                  l10n.yourSignInIsNoLongerValid_1ccq0,
                _ => l10n.weCouldNotReachOwnHubSo,
              },
              key: const ValueKey('health-backup-error'),
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          if ((_healthFailed || _healthWithdrawPending) &&
              widget.onSignInAgain != null &&
              classifyCallFailure(backup.lastFailure ?? Object()) ==
                  CallFailureKind.signInAgain)
            AppButton(
              l10n.signInAgain,
              variant: AppButtonVariant.outlined,
              onPressed: widget.onSignInAgain,
            ),
          // Off here either way. "When you are back online" only when the
          // network is what stopped the removal: a refused copy of the app
          // or a refused sign-in will not clear by reconnecting.
          if (_healthWithdrawPending)
            Text(
              switch (classifyCallFailure(backup.lastFailure ?? Object())) {
                CallFailureKind.appCannotReach =>
                  l10n.healthBackupIsOffOnThisPhone_1x622,
                CallFailureKind.signInAgain =>
                  l10n.healthBackupIsOffOnThisPhone_1x3p3,
                _ => l10n.healthBackupIsOffOnThisPhone,
              },
              key: const ValueKey('health-backup-withdraw-pending'),
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
        ],

        // Crash reports, only with her consent. Off by default.
        if (widget.onCrashReportsChanged != null)
          AppListItem(
            leading: const Icon(
              Icons.bug_report_outlined,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.crashReports,
            subtitle: _crashReports
                ? l10n.onIfTheAppCrashesTheError
                : l10n.offNothingIsSentWhenTheApp,
            trailing: AppToggle(
              key: const ValueKey('crash-reports-toggle'),
              value: _crashReports,
              semanticLabel: l10n.crashReports,
              onChanged: (value) => _toggleCrashReports(value),
            ),
            onTap: () => _toggleCrashReports(!_crashReports),
          ),

        // Usage statistics, only with her consent. Off by default, and a
        // separate choice from crash reports.
        if (widget.onAnalyticsChanged != null)
          AppListItem(
            leading: const Icon(
              Icons.insights_outlined,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.helpImproveOwnHub,
            subtitle: _analytics
                ? l10n.onGoogleAnalyticsAndPosthogReceiveBasic
                : l10n.offNothingAboutHowYouUseThe,
            trailing: AppToggle(
              key: const ValueKey('analytics-toggle'),
              value: _analytics,
              semanticLabel: l10n.helpImproveOwnHub,
              onChanged: (value) => _toggleAnalytics(value),
            ),
            onTap: () => _toggleAnalytics(!_analytics),
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
            l10n.yourIdAndSelfieWereDeletedAfter_nl9hl,
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
