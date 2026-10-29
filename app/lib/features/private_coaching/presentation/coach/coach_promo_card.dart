/// "Videos for Own Hub this month" in the coach space: how many of the month's
/// 2 are approved, this month's videos with where each stands, and a way to
/// send another. The videos go to Own Hub staff only; they are never on her
/// public page.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../../app_state/profile_photo_state.dart'
    show ProfilePhotoPermissionDenied;
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_list_item.dart';
import '../../../../ui/app_pill.dart';
import '../../../../ui/app_sheet.dart';
import '../../domain/coaching_failure.dart';
import '../../domain/promo_video.dart';
import 'coach_text.dart';
import 'coach_widgets.dart';

/// A video she picked: where the file is, its ending, its size and how long
/// it runs.
class CoachVideo {
  const CoachVideo({
    required this.path,
    required this.extension,
    required this.seconds,
    required this.bytes,
  });

  final String path;
  final String extension;
  final int seconds;
  final int bytes;
}

/// Hands back the video to send, or null when she backs out. May throw
/// [ProfilePhotoPermissionDenied]. A test replaces it.
typedef CoachVideoChooser = Future<CoachVideo?> Function(BuildContext context);

const Set<String> _deniedCodes = <String>{
  'camera_access_denied',
  'camera_access_restricted',
  'photo_access_denied',
  'photo_access_restricted',
};

/// Camera or her library. The length is read from the file, never from its
/// bytes in memory.
Future<CoachVideo?> chooseCoachVideo(BuildContext context) async {
  final l10n = AppL10n.of(context);
  final source = await showAppSheet<ImageSource>(
    context: context,
    children: [
      Builder(
        builder: (sheet) => AppListItem(
          title: l10n.recordAVideo,
          leading: const Icon(Icons.videocam_outlined),
          onTap: () => Navigator.of(sheet).pop(ImageSource.camera),
        ),
      ),
      Builder(
        builder: (sheet) => AppListItem(
          title: l10n.chooseFromYourVideos,
          leading: const Icon(Icons.video_library_outlined),
          onTap: () => Navigator.of(sheet).pop(ImageSource.gallery),
        ),
      ),
    ],
  );
  if (source == null) return null;
  try {
    final file = await ImagePicker().pickVideo(
      source: source,
      maxDuration: const Duration(seconds: kPromoMaxSeconds),
    );
    if (file == null) return null;
    final probe = VideoPlayerController.file(File(file.path));
    try {
      await probe.initialize();
      return CoachVideo(
        path: file.path,
        extension: file.path.split('.').last,
        seconds: (probe.value.duration.inMilliseconds / 1000).round(),
        bytes: await file.length(),
      );
    } finally {
      await probe.dispose();
    }
  } on PlatformException catch (e) {
    if (_deniedCodes.contains(e.code)) {
      throw const ProfilePhotoPermissionDenied();
    }
    rethrow;
  }
}

String promoTopicText(AppL10n l10n, PromoTopic? topic) => switch (topic) {
  PromoTopic.workoutTip => l10n.aWorkoutOrMovementTip,
  PromoTopic.eatingIdea => l10n.aHealthyEatingIdea,
  PromoTopic.trainingMyth => l10n.aTrainingMyth,
  PromoTopic.howCoachingWorks => l10n.howCoachingWithMeWorks,
  PromoTopic.introduction => l10n.aShortIntroductionOfMyself,
  null => '',
};

String? promoProblemText(AppL10n l10n, PromoProblem problem) =>
    switch (problem) {
      PromoProblem.tooShort => l10n.theVideoIsShorterThanMinSeconds(
        '$kPromoMinSeconds',
      ),
      PromoProblem.tooLong => l10n.theVideoIsLongerThanMaxMinutes(
        '${kPromoMaxSeconds ~/ 60}',
      ),
      PromoProblem.tooBig => l10n.thatVideoFileIsTooBigTry,
      PromoProblem.unsupported => l10n.onlyVideosInTheUsualPhoneFormat,
    };

class CoachPromoCard extends StatefulWidget {
  const CoachPromoCard({
    super.key,
    this.store,
    this.videoChooser = chooseCoachVideo,
  });

  final PromoVideoStore? store;
  final CoachVideoChooser videoChooser;

  @override
  State<CoachPromoCard> createState() => _CoachPromoCardState();
}

class _CoachPromoCardState extends State<CoachPromoCard> {
  PromoMonth _month = const PromoMonth();
  bool _busy = false;
  String _error = '';

  PromoVideoStore get _store => widget.store ?? PromoVideos.store;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final month = await _store.month();
      if (mounted) setState(() => _month = month);
    } catch (_) {
      // The card still offers an upload; the count comes back with the next look.
    }
  }

  Future<PromoTopic?> _askTopic() {
    final l10n = AppL10n.of(context);
    return showAppSheet<PromoTopic>(
      context: context,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.whatIsTheVideoAbout,
            style: AppText.titleL.copyWith(color: AppColors.ink),
          ),
        ),
        Text(
          l10n.eachVideoRunsFromMinSecondsTo(
            '$kPromoMinSeconds',
            '${kPromoMaxSeconds ~/ 60}',
          ),
          style: AppText.bodyM,
        ),
        for (final topic in PromoTopic.values)
          Builder(
            builder: (sheet) => AppListItem(
              key: ValueKey('promo-topic-${topic.wire}'),
              title: promoTopicText(l10n, topic),
              onTap: () => Navigator.of(sheet).pop(topic),
            ),
          ),
      ],
    );
  }

  Future<void> _add() async {
    final l10n = AppL10n.of(context);
    final topic = await _askTopic();
    if (topic == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    CoachVideo? video;
    try {
      video = await widget.videoChooser(context);
      if (video == null) return;
      final problem = promoProblem(
        seconds: video.seconds,
        bytes: video.bytes,
        extension: video.extension,
      );
      if (problem != null) throw PromoVideoException(problem);
      await _store.send(
        path: video.path,
        extension: video.extension,
        topic: topic,
        seconds: video.seconds,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.yourVideoWasSentOwnHubWill)),
        );
    } on ProfilePhotoPermissionDenied {
      if (mounted) setState(() => _error = l10n.theCameraIsTurnedOffForOwn);
    } on PromoVideoException catch (e) {
      if (mounted) setState(() => _error = promoProblemText(l10n, e.problem)!);
    } on CoachingFailure catch (failure) {
      if (mounted) setState(() => _error = coachFailureText(l10n, failure));
    } catch (_) {
      if (mounted) {
        setState(() => _error = l10n.somethingWentWrongPleaseTryAgain);
      }
    } finally {
      if (video != null) {
        try {
          final file = File(video.path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(AppL10n l10n, PromoVideo video) {
    final (label, background, foreground) = switch (video.status) {
      PromoStatus.waiting => (
        l10n.waitingForOwnHub,
        AppColors.amberContainer,
        AppColors.amber,
      ),
      PromoStatus.approved => (
        l10n.approvedByOwnHub,
        AppColors.tertiaryContainer,
        AppColors.onTertiaryContainer,
      ),
      PromoStatus.changes => (
        l10n.needsChanges,
        AppColors.amberContainer,
        AppColors.amber,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(promoTopicText(l10n, video.topic), style: AppText.bodyM),
        AppPill(label, background: background, foreground: foreground),
        if (video.status == PromoStatus.changes && video.reason.isNotEmpty)
          Text(
            l10n.needsChangesReason(video.reason),
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppCard(
      key: const ValueKey('coach-promo-card'),
      variant: _month.done ? AppCardVariant.filled : AppCardVariant.tonal,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.videosForOwnHubThisMonthCount(
              '${_month.approved}',
              '${_month.target}',
            ),
            style: AppText.titleL,
          ),
        ),
        if (_month.done)
          AppPill(
            l10n.youAreDoneForThisMonthThank,
            background: AppColors.tertiaryContainer,
            foreground: AppColors.onTertiaryContainer,
          ),
        if (_month.items.isEmpty)
          Text(l10n.noVideosYetThisMonth, style: AppText.bodyM)
        else
          for (final video in _month.items) _row(l10n, video),
        Text(
          l10n.onlyOwnHubStaffSeeYourVideos,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        if (_error.isNotEmpty) CoachFieldError(_error),
        AppButton(
          l10n.addAVideo,
          key: const ValueKey('promo-add'),
          variant: AppButtonVariant.tonal,
          onPressed: _busy ? null : _add,
        ),
      ],
    );
  }
}
