/// Her portfolio: photo, headline, how she coaches, and the switches that
/// decide who can ask to join. Save sends only what she changed.
library;

import 'package:flutter/material.dart';

import '../../../../app_state/profile_photo_state.dart'
    show ProfilePhotoPermissionDenied;
import '../../../../domain/format/number_label.dart';
import '../../../../app_state/honest_notice.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_field.dart';
import '../../../../ui/app_scaffold.dart';
import '../../data/coaching_repository.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/coaching_failure.dart';
import 'coach_data.dart';
import 'coach_photo.dart';
import 'coach_text.dart';
import 'coach_validation.dart';
import 'coach_widgets.dart';

class PortfolioEditView extends StatefulWidget {
  const PortfolioEditView({
    super.key,
    required this.data,
    this.photoChooser = chooseCoachPhoto,
  });

  final CoachSpaceData data;
  final CoachPhotoChooser photoChooser;

  @override
  State<PortfolioEditView> createState() => _PortfolioEditViewState();
}

class _PortfolioEditViewState extends State<PortfolioEditView> {
  late final TextEditingController _headline;
  late final TextEditingController _approach;
  late String _savedHeadline;
  late String _savedApproach;
  late bool _accepting;
  late bool _auto;
  late int _most;
  late bool _savedAccepting;
  late bool _savedAuto;
  late int _savedMost;

  bool _busy = false;
  bool _tried = false;
  String _message = '';
  bool _messageIsError = false;

  CoachingRepository get _repository => widget.data.repository;

  @override
  void initState() {
    super.initState();
    final profile = widget.data.profile;
    _savedHeadline = profile?.headline ?? '';
    _savedApproach = profile?.approach ?? '';
    _savedAccepting = profile?.acceptingClients ?? false;
    _savedAuto = profile?.autoAccept ?? false;
    _savedMost =
        profile?.maxActiveClients ?? CoachingLimits.maxActiveClientsDefault;
    _headline = TextEditingController(text: _savedHeadline);
    _approach = TextEditingController(text: _savedApproach);
    _accepting = _savedAccepting;
    _auto = _savedAuto;
    _most = _savedMost;
  }

  @override
  void dispose() {
    _headline.dispose();
    _approach.dispose();
    super.dispose();
  }

  bool get _changed =>
      _headline.text.trim() != _savedHeadline.trim() ||
      _approach.text.trim() != _savedApproach.trim() ||
      _accepting != _savedAccepting ||
      _auto != _savedAuto ||
      _most != _savedMost;

  void _say(String text, {bool error = false}) => setState(() {
    _message = text;
    _messageIsError = error;
  });

  Future<void> _changePhoto() async {
    final l10n = AppL10n.of(context);
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final bytes = await widget.photoChooser(context);
      if (bytes == null) return;
      final path = await _repository.uploadCoachDoc(
        CoachDocFolder.photo,
        bytes,
        'image/png',
      );
      await _repository.updateCoachProfile(photoPath: path);
      if (mounted) _say(l10n.yourPhotoIsSaved);
    } on ProfilePhotoPermissionDenied {
      if (mounted) _say(l10n.theCameraIsTurnedOffForOwn, error: true);
    } on CoachingFailure catch (failure) {
      if (mounted) _say(coachFailureText(l10n, failure), error: true);
    } catch (_) {
      if (mounted) _say(l10n.thatPictureCouldNotBeUsedTry, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final l10n = AppL10n.of(context);
    setState(() => _tried = true);
    final headlineChanged = _headline.text.trim() != _savedHeadline.trim();
    final approachChanged = _approach.text.trim() != _savedApproach.trim();
    // Only the text she changed is checked and sent, so an old text the
    // server would no longer take cannot block a switch.
    final problems = portfolioProblems(
      headline: headlineChanged ? _headline.text : 'x' * kHeadlineMin,
      approach: approachChanged
          ? _approach.text
          : 'x' * CoachingLimits.approachTextMin,
    );
    if (problems.isNotEmpty) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      await _repository.updateCoachProfile(
        headline: headlineChanged ? westernDigits(_headline.text.trim()) : null,
        approachText: approachChanged
            ? westernDigits(_approach.text.trim())
            : null,
        acceptingClients: _accepting != _savedAccepting ? _accepting : null,
        autoAccept: _auto != _savedAuto ? _auto : null,
        maxActiveClients: _most != _savedMost ? _most : null,
      );
      if (!mounted) return;
      setState(() {
        _savedHeadline = _headline.text;
        _savedApproach = _approach.text;
        _savedAccepting = _accepting;
        _savedAuto = _auto;
        _savedMost = _most;
        _tried = false;
      });
      _say(l10n.yourPortfolioIsSaved);
      showHonestNotice(context, l10n.saved);
    } on CoachingFailure catch (failure) {
      if (mounted) _say(coachFailureText(l10n, failure), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _lengthHint(AppL10n l10n, int low, int high) =>
      l10n.useLowToHighCharacters(countLabel(low), countLabel(high));

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final headlineBad =
        _tried &&
        _headline.text.trim() != _savedHeadline.trim() &&
        portfolioProblems(
          headline: _headline.text,
          approach: 'x' * CoachingLimits.approachTextMin,
        ).contains('headline');
    final approachBad =
        _tried &&
        _approach.text.trim() != _savedApproach.trim() &&
        portfolioProblems(
          headline: 'x' * kHeadlineMin,
          approach: _approach.text,
        ).contains('approach');
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: l10n.myPortfolio,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      footer: [
        AppButton(
          l10n.saveChanges,
          onPressed: _busy || !_changed ? null : _save,
        ),
      ],
      children: [
        ListenableBuilder(
          listenable: widget.data,
          builder: (context, _) {
            final profile = widget.data.profile;
            final has = (profile?.photoUrl ?? '').isNotEmpty;
            return Row(
              children: [
                CoachPhoto(
                  name: profile?.displayName ?? '',
                  photoUrl: profile?.photoUrl,
                  size: 72,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppButton(
                    has ? l10n.changePhoto : l10n.addAPhoto,
                    variant: AppButtonVariant.tonal,
                    icon: Icons.photo_camera_outlined,
                    onPressed: _busy ? null : _changePhoto,
                  ),
                ),
              ],
            );
          },
        ),
        AppField(
          controller: _headline,
          label: l10n.headline,
          hint: l10n.oneLineMembersReadFirst,
          helper: _lengthHint(l10n, kHeadlineMin, CoachingLimits.headlineMax),
          errorText: headlineBad
              ? _lengthHint(l10n, kHeadlineMin, CoachingLimits.headlineMax)
              : '',
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        AppField(
          controller: _approach,
          label: l10n.howYouCoach,
          hint: l10n.tellMembersHowYouWorkWithA,
          helper: _lengthHint(
            l10n,
            CoachingLimits.approachTextMin,
            CoachingLimits.approachTextMax,
          ),
          errorText: approachBad
              ? _lengthHint(
                  l10n,
                  CoachingLimits.approachTextMin,
                  CoachingLimits.approachTextMax,
                )
              : '',
          maxLines: 6,
          onChanged: (_) => setState(() {}),
        ),
        AppCard(
          variant: AppCardVariant.filled,
          gap: 4,
          children: [
            CoachSwitchRow(
              title: l10n.acceptingNewClients,
              value: _accepting,
              onChanged: _busy ? null : (v) => setState(() => _accepting = v),
            ),
            CoachSwitchRow(
              title: l10n.acceptRequestsAutomatically,
              subtitle: l10n.whenThisIsOnARequestGoes,
              value: _auto,
              onChanged: _busy ? null : (v) => setState(() => _auto = v),
            ),
            CoachStepper(
              label: l10n.mostClientsAtOnce,
              value: _most,
              min: CoachingLimits.maxActiveClientsMin,
              max: CoachingLimits.maxActiveClientsMax,
              display: countLabel(_most),
              onChanged: (v) => setState(() => _most = v),
            ),
            Text(
              l10n.newRequestsWaitOnceYouReachCount(countLabel(_most)),
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
        if (_message.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              _message,
              style: AppText.body.copyWith(
                color: _messageIsError ? AppColors.error : AppColors.tertiary,
              ),
            ),
          ),
        CoachHeading(l10n.whatMembersSee),
        ListenableBuilder(
          listenable: widget.data,
          builder: (context, _) {
            final profile = widget.data.profile;
            return AppCard(
              children: [
                Row(
                  children: [
                    CoachPhoto(
                      name: profile?.displayName ?? '',
                      photoUrl: profile?.photoUrl,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        profile?.displayName ?? '',
                        style: AppText.titleM,
                      ),
                    ),
                  ],
                ),
                if (_headline.text.trim().isNotEmpty)
                  Text(_headline.text.trim(), style: AppText.titleS),
                if (_approach.text.trim().isNotEmpty)
                  Text(_approach.text.trim(), style: AppText.body),
              ],
            );
          },
        ),
      ],
    );
  }
}
