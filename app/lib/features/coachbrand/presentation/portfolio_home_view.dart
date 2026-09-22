/// B01 — My portfolio. And B14, which is the same route with no blocks yet.
///
/// `P0-PORT-01`: *"B14 renders inside the B01 route: dashed placeholder, the
/// three starter sections, no tour and no overlay. No `/coachbrand/b14`
/// destination is registered and nothing navigates to one."*
///
/// So this file holds one widget with a branch in it, not two screens. The
/// branch is [PortfolioHomeState.isDayOne], decided in the view model. A test
/// asserts there is no overlay, no coach mark and no tour widget anywhere in
/// the tree, because HANDOFF rule 17 says the empty state **is** the
/// onboarding — it names three things worth doing and states that nothing is
/// decided for her.
///
/// ## The figures this screen refuses to state
///
/// The mockup's B01 reads "Published 4 days ago · version 3", "6 sections" and
/// "1,204 views". Those are fixed strings with the prototype's numbers inside
/// them, and `stated_figure.dart` exists because rendering one to everybody is
/// the defect `PHASE1-QA-VERDICT` calls blocking.
///
/// So each goes through [statedLine] and appears only for the coach it is true
/// of. `published4DaysAgoVersion3` states two figures at once and effectively
/// never matches, so it is reported as needing a parameterised form rather
/// than faked here. The funnel card draws its *label* and no numbers at all,
/// because B12 is deferred and there is nothing measured to put in it.
library;

import 'package:flutter/material.dart';

import '../../../domain/rewards/stated_figure.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../../today/presentation/today_cards.dart' show openScreen;
import 'portfolio_home_view_model.dart';

class PortfolioHomeView extends StatelessWidget {
  const PortfolioHomeView({
    super.key,
    required this.state,
    this.onBack,
    this.onDesign,
    this.onPreview,
    this.onOpenInsights,
    this.onOpenAds,
    this.onOpenResults,
    this.onOpenSections,
    this.onStart,
  });

  final PortfolioHomeState state;

  final VoidCallback? onBack;
  final VoidCallback? onDesign;
  final VoidCallback? onPreview;
  final VoidCallback? onOpenInsights;
  final VoidCallback? onOpenAds;
  final VoidCallback? onOpenResults;
  final VoidCallback? onOpenSections;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.myPortfolio,
        onBack: onBack,
        actions: [
          IconButton(
            onPressed: () => openScreen(context, 'B10', onPreview),
            icon: const Icon(Icons.visibility),
            color: AppColors.onSurface,
            tooltip: l10n.preview,
          ),
        ],
      ),
      body: state.isDayOne
          ? _DayOne(onOpenSections: onOpenSections, onStart: onStart)
          : _Built(
              state: state,
              onDesign: onDesign,
              onPreview: onPreview,
              onOpenInsights: onOpenInsights,
              onOpenAds: onOpenAds,
              onOpenResults: onOpenResults,
            ),
    );
  }
}

/// B14. A branch, reached only when the draft holds nothing.
class _DayOne extends StatelessWidget {
  const _DayOne({this.onOpenSections, this.onStart});

  final VoidCallback? onOpenSections;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      footer: [
        AppButton(
          l10n.startWithACover,
          height: 54,
          onPressed: () => openScreen(context, 'B04', onStart),
        ),
      ],
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The dashed placeholder. It shows the SHAPE of a page without
            // suggesting a template — there is nothing in it to accept. Dashed
            // pencil is the page's mark for space waiting to be filled.
            HandSurface(
              seed: handSeed(['portfolio-day-one']),
              fill: AppColors.surfaceLow,
              frame: AppColors.outline,
              dashed: true,
              radius: 5,
              looseCorner: 14,
              child: const SizedBox(
                width: 104,
                height: 132,
                child: Icon(Icons.add, size: 26, color: AppColors.outline),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.yourPageIsEmpty,
                    style: AppText.titleM.copyWith(color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    l10n.notATemplateWithYourNameDropped,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Text(
          l10n.mostCoachesStartWithTheseThree,
          style: AppText.titleS.copyWith(color: AppColors.onSurfaceVariant),
        ),
        for (final starter in PortfolioHomeState.dayOneStarters)
          AppListItem(
            leading: Icon(
              _starterIcon(starter),
              size: 22,
              color: AppColors.primaryDim,
            ),
            title: _starterTitle(l10n, starter),
            subtitle: _starterSubtitle(l10n, starter),
            trailing: const Icon(
              Icons.chevron_right,
              size: 21,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: () => openScreen(context, starter.screenId),
          ),
        AppCard(
          variant: AppCardVariant.filled,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          onTap: () => openScreen(context, 'B03', onOpenSections),
          children: [
            Row(
              children: [
                const Icon(Icons.add, size: 22, color: AppColors.primaryDim),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    // "Browse all 12 sections" states a catalogue size, and
                    // the catalogue holds fourteen block types, not twelve.
                    // The row's job is the action, so it names the action.
                    l10n.addASection,
                    style: AppText.titleS.copyWith(color: AppColors.primaryDim),
                  ),
                ),
              ],
            ),
          ],
        ),
        AppSageNote(l10n.nothingHereIsDecidedForYouTwo),
      ],
    );
  }

  static IconData _starterIcon(DayOneStarter starter) => switch (starter) {
    DayOneStarter.cover => Icons.image,
    DayOneStarter.offer => Icons.payments,
    DayOneStarter.method => Icons.checklist,
  };

  static String _starterTitle(AppL10n l10n, DayOneStarter starter) =>
      switch (starter) {
        DayOneStarter.cover => l10n.aCover,
        DayOneStarter.offer => l10n.oneOffer,
        DayOneStarter.method => l10n.howYouWork,
      };

  static String _starterSubtitle(AppL10n l10n, DayOneStarter starter) =>
      switch (starter) {
        DayOneStarter.cover => l10n.onePhotoOneSentenceAboutWhatYou,
        DayOneStarter.offer => l10n.whatItIsCalledWhatIsIn,
        DayOneStarter.method => l10n.yourMethodInTheWordsYouAlready,
      };
}

/// B01 proper, once she has built something.
class _Built extends StatelessWidget {
  const _Built({
    required this.state,
    this.onDesign,
    this.onPreview,
    this.onOpenInsights,
    this.onOpenAds,
    this.onOpenResults,
  });

  final PortfolioHomeState state;
  final VoidCallback? onDesign;
  final VoidCallback? onPreview;
  final VoidCallback? onOpenInsights;
  final VoidCallback? onOpenAds;
  final VoidCallback? onOpenResults;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // "6 sections" states a figure. It is shown to the coach who has six.
    final sections = statedLine<int>(
      l10n.n6Sections,
      states: 6,
      hers: state.blockCount,
    );

    return AppScaffold(
      children: [
        Row(
          children: [
            if (state.isVisibleToClients)
              AppPill(
                l10n.live,
                background: AppColors.tertiaryContainer,
                foreground: AppColors.tertiary,
                icon: Icons.check_circle,
              )
            else if (state.isHidden)
              AppPill(
                l10n.hidden,
                background: AppColors.surfaceContainer,
                foreground: AppColors.onSurfaceVariant,
              )
            else if (state.isPublishQueued)
              AppPill(
                l10n.waitingForSignal,
                background: AppColors.surfaceContainer,
                foreground: AppColors.onSurfaceVariant,
                icon: Icons.schedule,
              )
            else
              AppPill(
                l10n.draft,
                background: AppColors.amberContainer,
                foreground: AppColors.amber,
              ),
            if (sections != null) ...[
              const SizedBox(width: 6),
              AppPill(
                sections,
                background: AppColors.surfaceContainer,
                foreground: AppColors.onSurfaceVariant,
              ),
            ],
          ],
        ),
        Row(
          children: [
            Expanded(
              child: AppButton(
                l10n.designIt,
                height: 48,
                icon: Icons.edit,
                onPressed: () => openScreen(context, 'B02', onDesign),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: AppButton(
                l10n.preview,
                height: 48,
                fontSize: 15,
                variant: AppButtonVariant.outlined,
                onPressed: () => openScreen(context, 'B10', onPreview),
              ),
            ),
          ],
        ),
        // A pencil rule between her page and the tools around it.
        const HandRule(seed: 21, height: 8),
        // The funnel. Its LABEL, and no numbers: B12 is deferred, there are no
        // beacons, and "0 views · 0 enquiries" is a statement about our
        // telemetry dressed up as a statement about her work.
        AppCard(
          onTap: () => openScreen(context, 'B12', onOpenInsights),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.whatItIsDoing,
                        style: AppText.titleM.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.viewsProfileEnquiries,
                        style: AppText.bodyM.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 21,
                  color: AppColors.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
        AppListItem(
          leading: const Icon(
            Icons.image,
            size: 22,
            color: AppColors.primaryDim,
          ),
          title: l10n.designAnAd,
          subtitle: l10n.yourLookSizedForTheFeedA,
          trailing: const Icon(
            Icons.chevron_right,
            size: 21,
            color: AppColors.onSurfaceVariant,
          ),
          onTap: () => openScreen(context, 'B09', onOpenAds),
        ),
        AppListItem(
          leading: const Icon(
            Icons.trending_up,
            size: 22,
            color: AppColors.primaryDim,
          ),
          title: l10n.clientResults,
          subtitle: l10n.weAskHerShePicksThePictures,
          trailing: const Icon(
            Icons.chevron_right,
            size: 21,
            color: AppColors.onSurfaceVariant,
          ),
          onTap: () => openScreen(context, 'B08', onOpenResults),
        ),
        AppSageNote(l10n.nothingAboutThisPageIsATemplate),
      ],
    );
  }
}
