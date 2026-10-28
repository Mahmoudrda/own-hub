/// A walk, of any length: start it, finish it, and log it to count the calories
/// she burned.
///
/// One purpose a screen. Ready says what logging does, in a sentence, before
/// she starts: her walk counts in her week and the calories she burned are
/// kept, as an estimate. Walking is the clock and one button. Finished shows
/// the minutes and the estimate beside the one button that logs it, with a
/// quiet way to drop it.
///
/// The clock is [WalkSessionState]'s, two stored times, so a phone in a pocket
/// or an app killed mid-walk loses nothing. The estimate is
/// `energy_estimate.dart`'s: always called an estimate, and capped at the same
/// three hours, because a walk left running overnight is a forgotten one.
///
/// What it never does: change what she eats, subtract from it, show a net or a
/// remaining figure, or pay for calories. It imports nothing from Eat.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app_state/haptics.dart';
import '../../../app_state/walk_session_state.dart';
import '../../../domain/clock/app_clock.dart';
import '../../../domain/format/number_label.dart';
import '../../../domain/training/energy_estimate.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_stat_hero.dart';
import '../domain/clock_label.dart';

/// `h:mm:ss` from an hour, `m:ss` before. Western digits in both languages.
String walkClockLabel(Duration walked) {
  if (walked.inHours < 1) return clockLabel(walked);
  final rest = Duration(seconds: walked.inSeconds.remainder(3600));
  final minutes = rest.inMinutes.toString().padLeft(2, '0');
  final seconds = rest.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${walked.inHours}:$minutes:$seconds';
}

class WalkSessionView extends StatefulWidget {
  const WalkSessionView({
    super.key,
    required this.onLog,
    this.state,
    this.now,
    this.bodyWeightKg,
    this.onClose,
  });

  /// Records the walk and credits it. Called once, with the seconds walked.
  final Future<void> Function(int durationSec) onLog;

  /// The walk she is on. Defaults to the phone's.
  final WalkSessionState? state;

  /// The clock. Defaults to the app's.
  final DateTime Function()? now;

  /// Her weight for the estimate, or null for a typical one (the page says so).
  final double? bodyWeightKg;

  /// Leaves the page. Defaults to going back.
  final VoidCallback? onClose;

  @override
  State<WalkSessionView> createState() => _WalkSessionViewState();
}

class _WalkSessionViewState extends State<WalkSessionView> {
  Timer? _tick;
  int? _loggedSec;
  bool _logging = false;

  WalkSessionState get _walk => widget.state ?? WalkSessionState.instance;
  DateTime _now() => (widget.now ?? AppClock.now)();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _walk.isWalking && !_walk.isPaused) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _close() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else {
      unawaited(Navigator.of(context).maybePop());
    }
  }

  Future<void> _log(int seconds) async {
    // A second tap before the page has redrawn finds the walk already logged.
    if (_logging || _loggedSec != null) return;
    setState(() => _logging = true);
    try {
      await widget.onLog(seconds);
    } finally {
      if (mounted) setState(() => _logging = false);
    }
    _walk.logged();
    unawaited(AppHaptics.play(HapticMoment.actionDone));
    if (mounted) setState(() => _loggedSec = seconds);
  }

  int _kcal(int seconds) => estimateKcal(
    durationSec: seconds,
    kind: EffortKind.walk,
    bodyWeightKg: widget.bodyWeightKg,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final walk = _walk;
    final logged = _loggedSec;
    final waiting = walk.finishedSeconds;

    final (footer, children) = switch ((logged, waiting, walk.isWalking)) {
      (final int seconds, _, _) => _logged(l10n, seconds),
      (_, final int seconds, _) => _finished(l10n, seconds),
      (_, _, true) => _walking(l10n),
      _ => _ready(l10n),
    };

    return AppScaffold(
      footerScrollsWhenLarge: true,
      appBar: AppTopBar(title: l10n.walking, onBack: _close),
      footer: footer,
      children: children,
    );
  }

  (List<Widget>, List<Widget>) _ready(AppL10n l10n) => (
    [
      AppButton(
        l10n.startWalking,
        key: const ValueKey('walk-start'),
        icon: Icons.directions_walk,
        onPressed: () {
          _walk.start(_now());
          setState(() {});
        },
      ),
    ],
    [
      const SizedBox(height: 8),
      ExcludeSemantics(
        child: Icon(
          Icons.directions_walk,
          size: 48,
          color: AppColors.primaryDim,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        l10n.walkAsLongAsYouLikeLog,
        key: const ValueKey('walk-lead'),
        style: AppText.headline,
      ),
      const SizedBox(height: 12),
      Text(
        l10n.theCaloriesAreAnEstimateTheyNever,
        key: const ValueKey('walk-estimate-note'),
        style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
      ),
    ],
  );

  (List<Widget>, List<Widget>) _walking(AppL10n l10n) {
    final walk = _walk;
    final paused = walk.isPaused;
    return (
      [
        AppButton(
          l10n.finishWalk,
          key: const ValueKey('walk-finish'),
          onPressed: () {
            _walk.finish(_now());
            setState(() {});
          },
        ),
        AppButton(
          paused ? l10n.resume : l10n.pause,
          key: const ValueKey('walk-pause'),
          variant: AppButtonVariant.text,
          height: 48,
          fontSize: 15,
          onPressed: () {
            paused ? _walk.resume(_now()) : _walk.pause(_now());
            setState(() {});
          },
        ),
      ],
      [
        const SizedBox(height: 24),
        Center(
          child: Text(
            walkClockLabel(walk.elapsed(_now())),
            key: const ValueKey('walk-timer'),
            style: AppText.display.copyWith(
              fontSize: 64,
              height: 1.1,
              color: paused ? AppColors.onSurfaceVariant : AppColors.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.loggingCountsItInYourWeekAnd,
          textAlign: TextAlign.center,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  /// What a finished walk reports: minutes and the estimate, or that it was too
  /// short to log. Capped like the strength estimate.
  (List<Widget>, List<Widget>) _finished(AppL10n l10n, int walked) {
    final seconds = math.min(walked, maxEstimatedSeconds);
    if (seconds < 60) {
      return (
        [
          AppButton(
            l10n.done_54ca1,
            key: const ValueKey('walk-discard'),
            onPressed: () {
              _walk.discard();
              _close();
            },
          ),
        ],
        [
          const SizedBox(height: 24),
          Text(
            l10n.thatWasUnderAMinuteSoThere,
            key: const ValueKey('walk-too-short'),
            style: AppText.headline,
          ),
        ],
      );
    }
    return (
      [
        AppButton(
          l10n.logThisWalk,
          key: const ValueKey('walk-log'),
          icon: Icons.check,
          onPressed: _logging ? null : () => unawaited(_log(seconds)),
        ),
        AppButton(
          l10n.dontLogIt,
          key: const ValueKey('walk-drop'),
          variant: AppButtonVariant.text,
          height: 48,
          fontSize: 15,
          onPressed: () {
            _walk.discard();
            _close();
          },
        ),
      ],
      [..._figures(l10n, seconds), _loggingNote(l10n)],
    );
  }

  (List<Widget>, List<Widget>) _logged(AppL10n l10n, int seconds) => (
    [
      AppButton(
        l10n.done_54ca1,
        key: const ValueKey('walk-done'),
        onPressed: _close,
      ),
    ],
    [
      const SizedBox(height: 8),
      Text(
        l10n.walkLogged,
        key: const ValueKey('walk-logged'),
        style: AppText.headline,
      ),
      const SizedBox(height: 16),
      ..._figures(l10n, seconds),
    ],
  );

  List<Widget> _figures(AppL10n l10n, int seconds) => [
    const SizedBox(height: 8),
    AppStatHero(
      key: const ValueKey('walk-figures'),
      hero: AppStat(
        value: countLabel(_kcal(seconds)),
        label: l10n.caloriesBurnedEstimate,
      ),
      others: [AppStat(value: countLabel(seconds ~/ 60), label: l10n.minutes)],
    ),
    if (widget.bodyWeightKg == null ||
        bodyWeightOrDefault(widget.bodyWeightKg) != widget.bodyWeightKg) ...[
      const SizedBox(height: 12),
      Text(
        l10n.workedOutWithATypicalWeightAdd,
        key: const ValueKey('walk-typical-weight'),
        style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
      ),
    ],
  ];

  Widget _loggingNote(AppL10n l10n) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Text(
      l10n.loggingCountsItInYourWeekAnd,
      key: const ValueKey('walk-log-note'),
      style: AppText.bodyM,
    ),
  );
}
