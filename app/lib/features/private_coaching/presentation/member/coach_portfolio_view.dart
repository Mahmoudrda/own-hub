/// H02: a coach's public portfolio, as a member sees it. Works from the data
/// it is given, so a coach can preview her own with [preview] on.
library;

import 'package:flutter/material.dart';

import '../../../../app_state/private_coaching_state.dart';
import '../../../account/domain/safety.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_overflow_menu.dart';
import '../../../../ui/app_pill.dart';
import '../../../../ui/app_scaffold.dart';
import '../../../../ui/hand/skeleton.dart';
import '../../data/coaching_repository.dart';
import '../../domain/approved_media.dart';
import '../../domain/portfolio_media.dart';
import '../../domain/coach_profile.dart';
import '../chat/chat_sheets.dart' show confirmBlock;
import '../coaching_when.dart';
import 'coach_card.dart';
import 'coach_image.dart';
import 'coach_labels.dart';
import 'join_coach_sheet.dart';
import 'report_coach_sheet.dart';

/// The portfolio. With more than one package she taps the one she wants, and
/// the pinned Ask to join asks for that one.
class CoachPortfolioView extends StatefulWidget {
  const CoachPortfolioView({
    super.key,
    required this.coach,
    required this.packages,
    this.media = const <ApprovedMedia>[],
    this.preview = false,
    this.repository,
    this.declaredAllergies = const <String>[],
    this.blocks,
    this.onBack,
  });

  final CoachProfile coach;
  final List<CoachPackage> packages;
  final List<ApprovedMedia> media;
  final bool preview;
  final CoachingRepository? repository;
  final List<String> declaredAllergies;
  final BlockService? blocks;
  final VoidCallback? onBack;

  @override
  State<CoachPortfolioView> createState() => _CoachPortfolioViewState();
}

class _CoachPortfolioViewState extends State<CoachPortfolioView> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => _PortfolioBody(
    coach: widget.coach,
    packages: widget.packages,
    media: widget.media,
    preview: widget.preview,
    repository: widget.repository,
    declaredAllergies: widget.declaredAllergies,
    blocks: widget.blocks,
    onBack: widget.onBack,
    selected: _selected,
    onSelect: (i) => setState(() => _selected = i),
  );
}

class _PortfolioBody extends StatelessWidget {
  const _PortfolioBody({
    required this.selected,
    required this.onSelect,
    required this.coach,
    required this.packages,
    this.media = const <ApprovedMedia>[],
    this.preview = false,
    this.repository,
    this.declaredAllergies = const <String>[],
    this.blocks,
    this.onBack,
  });

  /// The index of the package the pinned Ask to join asks for.
  final int selected;
  final ValueChanged<int> onSelect;

  final CoachProfile coach;

  /// Her packages. Only the active ones are shown.
  final List<CoachPackage> packages;

  /// Her approved photos and results.
  final List<ApprovedMedia> media;

  /// A coach looking at her own page: a banner, and no Report.
  final bool preview;

  /// Where a report is written. Defaults to the app's coaching repository.
  final CoachingRepository? repository;

  /// Wire names of the allergies on her profile, to prefill the join sheet.
  final List<String> declaredAllergies;

  /// The app's block list. Without it the menu has no Block.
  final BlockService? blocks;
  final VoidCallback? onBack;

  Future<void> _block(BuildContext context) async {
    final service = blocks;
    if (service == null) return;
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    if (!await confirmBlock(context, coach.displayName)) return;
    await service.block(coach.uid, BlockSource.profile);
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.nameIsBlocked(coach.displayName))),
    );
    await navigator.maybePop();
  }

  Widget _heading(String text) => Semantics(
    header: true,
    child: Text(text, style: AppText.titleL.copyWith(color: AppColors.ink)),
  );

  Widget _muted(String text) =>
      Text(text, style: AppText.bodyM.copyWith(color: AppColors.textSecondary));

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final repo = repository ?? PrivateCoachingState.instance.repository;
    // A coach looking at her own page can neither join nor report it.
    final ownPage = preview || (repo?.uid != null && repo!.uid == coach.uid);
    final active = <CoachPackage>[
      for (final p in packages)
        if (p.active) p,
    ]..sort((a, b) => a.order.compareTo(b.order));
    final languages = <String>[
      for (final k in coach.languages) languageLabel(l10n, k),
    ].join(coachListSep(l10n));
    final pick = active.isEmpty ? 0 : selected.clamp(0, active.length - 1);
    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.coachProfile,
        onBack: onBack,
        actions: [
          if (!ownPage && (repo != null || blocks != null))
            AppOverflowMenu(
              color: AppColors.ink,
              items: [
                if (repo != null)
                  AppOverflowItem(
                    icon: Icons.flag_outlined,
                    label: l10n.reportThisProfile,
                    onTap: () => showReportCoachSheet(
                      context: context,
                      repository: repo,
                      coachUid: coach.uid,
                    ),
                  ),
                if (blocks != null)
                  AppOverflowItem(
                    icon: Icons.block,
                    label: l10n.block,
                    onTap: () => _block(context),
                  ),
              ],
            ),
        ],
      ),
      footer: [
        if (!ownPage && active.isNotEmpty)
          AppButton(
            l10n.askToJoin,
            onPressed: repo == null
                ? null
                : () => showJoinCoachSheet(
                    context: context,
                    repository: repo,
                    coach: coach,
                    package: active[pick],
                    declaredAllergies: declaredAllergies,
                  ),
          ),
      ],
      children: [
        if (preview)
          AppCard(
            variant: AppCardVariant.tonal,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.thisIsHowMembersSeeYou,
                  style: AppText.titleS.copyWith(
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        _header(l10n, languages),
        if (coach.specialties.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              for (final s in coach.specialties)
                AppPill(specialtyLabel(l10n, s)),
            ],
          ),
        _heading(l10n.packages),
        if (active.isEmpty) _muted(l10n.noPackagesYet),
        for (var i = 0; i < active.length; i++)
          _package(
            context,
            l10n,
            active[i],
            repo,
            ownPage,
            picked: active.length > 1 && i == pick,
            onPick: active.length > 1 ? () => onSelect(i) : null,
          ),
        if (coach.approach.trim().isNotEmpty) ...[
          _heading(l10n.approach),
          Text(coach.approach, style: AppText.body),
        ],
        if (coach.testimonials.isNotEmpty) ...[
          _heading(l10n.whatMembersSay),
          for (final t in coach.testimonials)
            AppCard(
              variant: AppCardVariant.filled,
              gap: 6,
              children: [
                Text(t.text, style: AppText.body),
                if (t.from.isNotEmpty) _muted(t.from),
              ],
            ),
        ],
        if (coach.certificates.isNotEmpty) ...[
          _heading(l10n.checkedCertificates),
          for (final c in coach.certificates)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.title,
                    style: AppText.titleS.copyWith(color: AppColors.ink),
                  ),
                  if (c.issuer.isNotEmpty || c.year != null)
                    _muted(
                      <String>[
                        if (c.issuer.isNotEmpty) c.issuer,
                        if (c.year != null) '${c.year}',
                      ].join(' · '),
                    ),
                ],
              ),
            ),
        ],
        ..._results(context, l10n),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _results(BuildContext context, AppL10n l10n) {
    final transformations = <ApprovedMedia>[
      for (final m in media)
        if (m.kind == MediaKind.transformation) m,
    ];
    final feedback = <ApprovedMedia>[
      for (final m in media)
        if (m.kind == MediaKind.feedback) m,
    ];
    final photos = <ApprovedMedia>[
      for (final m in media)
        if (m.kind == MediaKind.photo) m,
    ];
    if (media.isEmpty) {
      return preview
          ? <Widget>[_muted(l10n.nothingApprovedYetPhotosAndResultsShow)]
          : const <Widget>[];
    }
    return <Widget>[
      if (transformations.isNotEmpty || feedback.isNotEmpty) ...[
        _heading(l10n.results),
        for (final t in transformations) _transformation(l10n, t),
        for (final f in feedback) _feedbackCard(l10n, f),
      ],
      if (photos.isNotEmpty) ...[
        _heading(l10n.photos),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final photo = photos[i];
              final label = photo.caption.isNotEmpty
                  ? photo.caption
                  : l10n.photoOfName(coach.displayName);
              return Semantics(
                button: true,
                label: label,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => _openFull(context, photo.imagePath!, label),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CoachImage(
                      path: photo.imagePath!,
                      label: label,
                      width: 120,
                      height: 120,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ];
  }

  void _openFull(BuildContext context, String path, String label) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: AppColors.ink,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.inverseOnSurface,
            leading: IconButton(
              tooltip: AppL10n.of(context).close,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CoachImage(path: path, label: label, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _side(String label, String path) => Expanded(
    child: Column(
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CoachImage(
              path: path,
              label: label,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppText.nav.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _transformation(AppL10n l10n, ApprovedMedia t) => AppCard(
    gap: 8,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _side(l10n.before, t.beforePath!),
          const SizedBox(width: 8),
          _side(l10n.after, t.afterPath!),
        ],
      ),
      if (t.weeks != null)
        Text(
          l10n.overWeeksPluralOne1WeekOther(t.weeks!),
          style: AppText.titleS.copyWith(color: AppColors.ink),
        ),
      if (t.note.isNotEmpty) Text(t.note, style: AppText.bodyM),
      _muted(l10n.sharedWithHerClientsWrittenConsent),
    ],
  );

  Widget _feedbackCard(AppL10n l10n, ApprovedMedia f) => AppCard(
    variant: AppCardVariant.filled,
    gap: 8,
    children: [
      if (f.imagePath != null)
        CoachImage(
          path: f.imagePath!,
          label: l10n.screenshotOfAMessageFromAClient,
          width: double.infinity,
          height: 220,
          fit: BoxFit.contain,
        ),
      Text(f.text, style: AppText.body),
      if (f.from.isNotEmpty) _muted(f.from),
    ],
  );

  Widget _header(AppL10n l10n, String languages) {
    final facts = <String>[
      if (coach.yearsExperience > 0) l10n.yearsCoachingN(coach.yearsExperience),
      if (languages.isNotEmpty) l10n.languagesList(languages),
      if (coach.replyHours != null)
        l10n.usuallyRepliesWithinNHours(coach.replyHours!),
    ];
    return Column(
      children: [
        CoachPhoto(
          name: coach.displayName,
          photoUrl: coach.photoUrl,
          size: 96,
          full: true,
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(
            coach.displayName,
            textAlign: TextAlign.center,
            style: AppText.headline.copyWith(color: AppColors.ink),
          ),
        ),
        if (coach.headline.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            coach.headline,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (coach.badges.contains('verifiedCoach')) ...[
          const SizedBox(height: 8),
          AppPill(
            l10n.verifiedCoach,
            icon: Icons.verified,
            background: AppColors.tertiaryContainer,
            foreground: AppColors.onTertiaryContainer,
          ),
        ],
        const SizedBox(height: 8),
        for (final fact in facts)
          Text(
            fact,
            textAlign: TextAlign.center,
            style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
          ),
      ],
    );
  }

  Widget _package(
    BuildContext context,
    AppL10n l10n,
    CoachPackage p,
    CoachingRepository? repo,
    bool ownPage, {
    bool picked = false,
    VoidCallback? onPick,
  }) {
    final card = AppCard(
      gap: 8,
      onTap: onPick,
      variant: picked ? AppCardVariant.selected : AppCardVariant.outlined,
      children: [
        Text(p.title, style: AppText.titleM.copyWith(color: AppColors.ink)),
        // 3.1.3(d): the live one-to-one video sessions come before anything else.
        Text(
          l10n.countPluralOneCountLiveOneTo(p.liveSessionsPerMonth),
          key: ValueKey('package-live-${p.id}'),
          style: AppText.titleS.copyWith(color: AppColors.primary),
        ),
        if (p.description.isNotEmpty) Text(p.description, style: AppText.bodyM),
        if (p.includes.isNotEmpty) ...[
          Text(
            l10n.whatIsIncluded,
            style: AppText.titleS.copyWith(color: AppColors.ink),
          ),
          for (final item in p.includes)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsetsDirectional.only(top: 3, end: 8),
                  child: Icon(Icons.check, size: 16, color: AppColors.primary),
                ),
                Expanded(child: Text(item, style: AppText.bodyM)),
              ],
            ),
        ],
        _muted(l10n.durationDaysPluralOne1DayOther(p.durationDays)),
        if (coachingPaymentsOn) ...[
          Text(
            l10n.egpPrice(formatEgp(p.priceFinalEgp)),
            style: AppText.headline.copyWith(color: AppColors.primary),
          ),
          _muted(l10n.finalPriceTaxesAndFeesIncluded),
        ] else ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppPill(
              l10n.freeForNow,
              background: AppColors.tertiaryContainer,
              foreground: AppColors.onTertiaryContainer,
            ),
          ),
          // Only the coach previewing her page sees the price to come.
          if (ownPage)
            _muted(l10n.egpPriceWhenPaymentsOpen(formatEgp(p.priceFinalEgp))),
        ],
      ],
    );
    if (onPick == null) return card;
    return Semantics(selected: picked, button: true, child: card);
  }
}

/// The portfolio drawn from the repository's live streams: the coach, her
/// active packages and her approved media. This is what the router opens.
class LiveCoachPortfolioView extends StatelessWidget {
  const LiveCoachPortfolioView({
    super.key,
    required this.coachUid,
    this.repository,
    this.declaredAllergies = const <String>[],
    this.preview = false,
    this.blocks,
    this.onBack,
  });

  final String coachUid;
  final BlockService? blocks;
  final CoachingRepository? repository;
  final List<String> declaredAllergies;
  final bool preview;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? PrivateCoachingState.instance.repository!;
    final l10n = AppL10n.of(context);
    return StreamBuilder<CoachProfile?>(
      stream: repo.watchCoach(coachUid),
      builder: (context, coachSnap) {
        final coach = coachSnap.data;
        if (coach == null) {
          return AppScaffold(
            appBar: AppTopBar(title: l10n.coachProfile, onBack: onBack),
            children: [
              coachSnap.hasError
                  ? Text(l10n.weCouldNotLoadTheCoachesCheck)
                  : Semantics(
                      label: l10n.loadingCoaches,
                      child: const Skeleton(height: 160, radius: 16),
                    ),
            ],
          );
        }
        return StreamBuilder<List<CoachPackage>>(
          stream: repo.watchPackages(coachUid),
          builder: (context, pkgSnap) => StreamBuilder<List<ApprovedMedia>>(
            stream: repo.watchApprovedMedia(coachUid),
            builder: (context, mediaSnap) => CoachPortfolioView(
              coach: coach,
              packages: pkgSnap.data ?? const <CoachPackage>[],
              media: mediaSnap.data ?? const <ApprovedMedia>[],
              repository: repo,
              declaredAllergies: declaredAllergies,
              preview: preview,
              blocks: blocks,
              onBack: onBack,
            ),
          ),
        );
      },
    );
  }
}
