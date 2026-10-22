/// "Photos and results": everything she has added for members to see, where
/// each item stands in Own Hub's check, and the way to add, confirm or remove.
library;

import 'package:flutter/material.dart';

import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_empty_state.dart';
import '../../../../ui/app_pill.dart';
import '../../../../ui/app_scaffold.dart';
import '../../../../ui/app_sheet.dart';
import '../../domain/coaching_failure.dart';
import '../../domain/portfolio_media.dart';
import '../member/coach_image.dart' as pub show CoachImage;
import 'coach_data.dart';
import 'coach_photo.dart';
import 'coach_text.dart';
import 'coach_widgets.dart';
import 'media_add_view.dart';
import '../../domain/coaching_contract.dart';

class PortfolioMediaView extends StatefulWidget {
  const PortfolioMediaView({
    super.key,
    required this.data,
    this.imageChooser = chooseCoachImage,
  });

  final CoachSpaceData data;
  final CoachImageChooser imageChooser;

  @override
  State<PortfolioMediaView> createState() => _PortfolioMediaViewState();
}

class _PortfolioMediaViewState extends State<PortfolioMediaView> {
  String _error = '';
  String? _busyId;

  void _add(MediaKind kind) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MediaAddView(
          data: widget.data,
          kind: kind,
          imageChooser: widget.imageChooser,
        ),
      ),
    );
  }

  Future<void> _run(String id, Future<void> Function() action) async {
    final l10n = AppL10n.of(context);
    setState(() {
      _busyId = id;
      _error = '';
    });
    try {
      await action();
    } on CoachingFailure catch (failure) {
      if (mounted) setState(() => _error = coachFailureText(l10n, failure));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _remove(PortfolioMedia item) async {
    final l10n = AppL10n.of(context);
    final yes = await showAppSheet<bool>(
      context: context,
      children: [
        Text(l10n.removeThisFromYourPortfolio, style: AppText.titleM),
        Builder(
          builder: (sheet) => AppButton(
            l10n.remove,
            onPressed: () => Navigator.of(sheet).pop(true),
          ),
        ),
        Builder(
          builder: (sheet) => AppButton(
            l10n.keep,
            variant: AppButtonVariant.outlined,
            onPressed: () => Navigator.of(sheet).pop(false),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
    if (yes != true || !mounted) return;
    await _run(
      item.id,
      () => widget.data.repository.removePortfolioMedia(item.id),
    );
  }

  String _title(AppL10n l10n, PortfolioMedia m) => switch (m.kind) {
    MediaKind.transformation => l10n.transformationWeeksPluralOne1WeekOther(
      m.weeks ?? 0,
    ),
    MediaKind.feedback => l10n.feedbackFromName(m.from),
    MediaKind.photo => m.caption.isEmpty ? l10n.photo : m.caption,
  };

  String _reasonText(AppL10n l10n, String code) => switch (code) {
    'unclear' => l10n.thePhotoWasNotClearEnough,
    'not_allowed' => l10n.itDoesNotFollowTheRulesFor,
    'no_consent' => l10n.weNeedYourClientsWrittenAgreement,
    _ => l10n.ownHubCouldNotApproveIt,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: l10n.photosAndResults,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      children: [
        CoachDataGate(
          data: widget.data,
          builder: (context) {
            final items = widget.data.media;
            final full = items.length >= kPortfolioMediaMax;
            return <Widget>[
              if (widget.data.mediaFailure != null)
                CoachFieldError(
                  coachFailureText(l10n, widget.data.mediaFailure!),
                ),
              Text(
                l10n.whatMembersSeeAfterOwnHubChecks,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              if (items.isEmpty)
                AppEmptyState(
                  icon: Icons.photo_library_outlined,
                  title: l10n.photosAndResults,
                  body: l10n.nothingHereYetAddYourFirstResult,
                )
              else ...[
                Text(
                  l10n.countOf30Items(countLabel(items.length)),
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                for (final item in items) _card(l10n, item),
              ],
              if (_error.isNotEmpty) CoachFieldError(_error),
              if (full)
                Text(
                  l10n.youHaveCountItemsRemoveOneTo(
                    '${CoachingLimits.mediaMaxItems}',
                  ),
                  style: AppText.bodyM,
                )
              else ...[
                AppButton(
                  l10n.addATransformation,
                  icon: Icons.compare_outlined,
                  onPressed: () => _add(MediaKind.transformation),
                ),
                AppButton(
                  l10n.addFeedback,
                  icon: Icons.format_quote_outlined,
                  variant: AppButtonVariant.outlined,
                  onPressed: () => _add(MediaKind.feedback),
                ),
                AppButton(
                  l10n.addAPhotoOfYouOrYour,
                  icon: Icons.add_a_photo_outlined,
                  variant: AppButtonVariant.outlined,
                  onPressed: () => _add(MediaKind.photo),
                ),
              ],
            ];
          },
        ),
      ],
    );
  }

  /// Her photos, so she sees what she is confirming. Her own uploads while the
  /// item waits; the public copies once it is approved.
  Widget _thumbs(AppL10n l10n, PortfolioMedia item) {
    final files = <(String?, String)>[
      if (item.kind == MediaKind.transformation) ...[
        (item.beforeFile, l10n.beforePhoto),
        (item.afterFile, l10n.afterPhoto),
      ] else
        (item.imageFile, l10n.photo),
    ];
    final shown = [
      for (final f in files)
        if (f.$1 != null) f,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (final f in shown)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: pub.CoachImage(
                key: ValueKey('thumb-${item.id}-${f.$1}'),
                path: f.$1!,
                label: f.$2,
                own: !f.$1!.startsWith('coach-public/'),
                width: 96,
                height: 96,
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(AppL10n l10n, PortfolioMedia item) {
    final (label, bg, fg) = switch (item.status) {
      MediaStatus.needsConsent => (
        l10n.needsYourClientsConsent,
        AppColors.amberContainer,
        AppColors.amber,
      ),
      MediaStatus.approved => (
        l10n.shownOnYourPortfolio,
        AppColors.tertiaryContainer,
        AppColors.onTertiaryContainer,
      ),
      MediaStatus.rejected => (
        l10n.notApproved,
        AppColors.errorContainer,
        AppColors.onErrorContainer,
      ),
      MediaStatus.pending => (
        l10n.waitingForOwnHubsCheck,
        AppColors.surfaceHighest,
        AppColors.onSurface,
      ),
    };
    final busy = _busyId == item.id;
    final body = item.kind == MediaKind.feedback ? item.text : item.note;
    return AppCard(
      variant: AppCardVariant.filled,
      gap: 8,
      children: [
        Text(_title(l10n, item), style: AppText.titleS),
        _thumbs(l10n, item),
        if (body.isNotEmpty) Text(body, style: AppText.bodyM),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppPill(label, background: bg, foreground: fg),
        ),
        if (item.status == MediaStatus.rejected)
          Text(
            _reasonText(l10n, item.reason),
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        if (item.needsConsent)
          AppButton(
            l10n.confirmMyClientAgreed,
            variant: AppButtonVariant.tonal,
            onPressed: busy
                ? null
                : () => _run(
                    item.id,
                    () => widget.data.repository.confirmMediaConsent(item.id),
                  ),
          ),
        AppButton(
          l10n.remove,
          variant: AppButtonVariant.text,
          onPressed: busy ? null : () => _remove(item),
        ),
      ],
    );
  }
}
