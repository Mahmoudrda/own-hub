/// The moments library: M1 to M12, the small drawn beats that stand where a
/// character used to cheer.
///
/// Every moment has one grammar: a trigger, a motion on a [HandTiming] token,
/// one touch, one cue from `sound.dart`, and what she gets under Reduce
/// Motion. [kMoments] is that table, so a screen asks for a moment by id and
/// the pairing of touch and sound is made once. Most of the motion already
/// lives in the pieces this table names (`AppStepBar`, `AppRingStat`,
/// `FinishReveal`, `AppWeekSegments`, `StaggerIn`, `TiltParallax`); what is
/// added here is [Moment] (the tick, M1 and M10), [MomentLine] (a line that
/// fades up, M2 and M7) and [MomentNumber] (a number in a drawn ring, M9).
///
/// Rules held by every moment: it plays once per trigger, never loops, never
/// delays the next task, and is simply there under Reduce Motion. Sound is
/// independent of motion: the switch in Profile decides it, never Reduce
/// Motion. At most one moment per screen state; none on R07 mid-set, R09
/// beyond its ring, Progress charts or an error.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_state/haptics.dart';
import '../../app_state/sound.dart';
import '../../theme/app_tokens.dart';
import '../../theme/hand_tokens.dart';
import 'draw_on.dart';
import 'hand_geometry.dart' show handSeed;
import 'hand_marks.dart';
import 'motion.dart';
import 'spring_pop.dart';

enum MomentId {
  /// M1: any "saved" or "done".
  tick,

  /// M2: first open.
  welcome,

  /// M3: a set logged.
  setDone,

  /// M4: the rest ring.
  restRing,

  /// M5: the session peak, R10.
  sessionPeak,

  /// M6: the week reaches its goal.
  weekClosed,

  /// M7: first open after days away.
  welcomeBack,

  /// M8: a meal added.
  foodLogged,

  /// M9: a real milestone.
  milestone,

  /// M10: the women-only check passed.
  verified,

  /// M11: content arriving on a list.
  arrival,

  /// M12: light tilt on the Home hero only.
  tilt,
}

@immutable
class MomentSpec {
  const MomentSpec({
    required this.code,
    required this.piece,
    required this.motion,
    required this.reduced,
    this.haptic,
    this.cue,
  });

  /// "M1" to "M12", as the guide and the docs name them.
  final String code;

  /// The widget that draws it.
  final String piece;

  /// One play, on a [HandTiming] token.
  final Duration motion;

  /// The one touch, or null for none.
  final HapticMoment? haptic;

  /// The one sound, or null for none. A moment with a sound has it pair with
  /// the motion and the touch, and the Profile switch can silence it.
  final SoundCue? cue;

  /// What she gets under Reduce Motion.
  final String reduced;
}

/// The table. Where a touch or a timing here differs from the design guide,
/// it is what the screen already does: the guide's light impact for a set is
/// the selection click D40 chose, and the set bar fills in [HandTiming.progress].
final Map<MomentId, MomentSpec> kMoments = <MomentId, MomentSpec>{
  MomentId.tick: MomentSpec(
    code: 'M1',
    piece: 'Moment',
    motion: HandTiming.moment,
    cue: SoundCue.saved,
    reduced: 'The tick is simply there.',
  ),
  MomentId.welcome: MomentSpec(
    code: 'M2',
    piece: 'MomentLine',
    motion: HandTiming.moment,
    reduced: 'The line is simply there.',
  ),
  MomentId.setDone: MomentSpec(
    code: 'M3',
    piece: 'AppStepBar',
    motion: HandTiming.progress,
    haptic: HapticMoment.setLogged,
    cue: SoundCue.setDone,
    reduced: 'The segment fills at once.',
  ),
  MomentId.restRing: MomentSpec(
    code: 'M4',
    piece: 'AppRingStat',
    motion: const Duration(seconds: 1),
    cue: SoundCue.restEnd,
    reduced: 'The ring steps, the countdown figure stays.',
  ),
  MomentId.sessionPeak: MomentSpec(
    code: 'M5',
    piece: 'FinishReveal',
    motion: const Duration(seconds: 2),
    haptic: HapticMoment.sessionFinished,
    cue: SoundCue.sessionDone,
    reduced: 'The final state, with no motion.',
  ),
  MomentId.weekClosed: MomentSpec(
    code: 'M6',
    piece: 'AppWeekSegments',
    motion: HandTiming.moment,
    haptic: HapticMoment.actionDone,
    cue: SoundCue.weekClosed,
    reduced: 'The marks are filled.',
  ),
  MomentId.welcomeBack: MomentSpec(
    code: 'M7',
    piece: 'MomentLine',
    motion: HandTiming.moment,
    reduced: 'The line is simply there.',
  ),
  MomentId.foodLogged: MomentSpec(
    code: 'M8',
    piece: 'AppRingStat',
    motion: HandTiming.progress,
    haptic: HapticMoment.actionDone,
    cue: SoundCue.foodLogged,
    reduced: 'The value updates.',
  ),
  MomentId.milestone: MomentSpec(
    code: 'M9',
    piece: 'MomentNumber',
    motion: HandTiming.moment,
    haptic: HapticMoment.actionDone,
    cue: SoundCue.milestone,
    reduced: 'The mark and her number are simply there.',
  ),
  MomentId.verified: MomentSpec(
    code: 'M10',
    piece: 'Moment',
    motion: HandTiming.moment,
    haptic: HapticMoment.actionDone,
    cue: SoundCue.verified,
    reduced: 'The tick is simply there.',
  ),
  MomentId.arrival: MomentSpec(
    code: 'M11',
    piece: 'StaggerIn',
    motion: HandTiming.staggerStep * HandTiming.staggerMax + HandTiming.medium,
    reduced: 'No stagger.',
  ),
  MomentId.tilt: MomentSpec(
    code: 'M12',
    piece: 'TiltParallax',
    motion: Duration.zero,
    reduced: 'Off.',
  ),
};

/// Gives the touch and the sound of [id], once. [variant] picks among a cue's
/// files (the set of the move for [MomentId.setDone]).
void feelMoment(MomentId id, {int variant = 0}) {
  final spec = kMoments[id]!;
  final haptic = spec.haptic;
  if (haptic != null) unawaited(AppHaptics.play(haptic));
  final cue = spec.cue;
  if (cue != null) unawaited(AppSound.play(cue, variant: variant));
}

/// M1 and M10: a tick that draws on once. With motion off it is simply there.
///
/// Given an [id] it also gives that moment's touch and sound once, when it
/// first appears, so the tick, the touch and the sound are one beat. Without
/// one it is the quiet tick it always was.
class Moment extends StatefulWidget {
  const Moment({
    super.key,
    this.size = 48,
    this.delay = Duration.zero,
    this.id,
    this.label,
  });

  final double size;
  final Duration delay;
  final MomentId? id;

  /// What a screen reader says for the tick, for a screen whose own text does
  /// not already say it. Null leaves the drawing out of the reading.
  final String? label;

  @override
  State<Moment> createState() => _MomentState();
}

class _MomentState extends State<Moment> {
  @override
  void initState() {
    super.initState();
    final id = widget.id;
    if (id != null) feelMoment(id);
  }

  @override
  Widget build(BuildContext context) {
    final tick = SpringPop(
      delay: widget.delay,
      child: HandTick(size: widget.size, drawOn: true, delay: widget.delay),
    );
    final label = widget.label;
    if (label == null) return ExcludeSemantics(child: tick);
    return Semantics(label: label, excludeSemantics: true, child: tick);
  }
}

/// M2 and M7: one calm line that fades up and settles, once. The words are
/// ordinary text, so a screen reader has them from the first frame whatever
/// the motion does. Under Reduce Motion the line is simply there.
class MomentLine extends StatelessWidget {
  const MomentLine(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final still = handMotionOff(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: still ? 1 : 0, end: 1),
      duration: still ? Duration.zero : HandTiming.moment,
      curve: HandTiming.standard,
      builder: (context, t, child) => Opacity(
        opacity: t,
        // Invisible is not unread: the words are there for a screen reader
        // from the first frame.
        alwaysIncludeSemantics: true,
        child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
      ),
      child: Text(
        text,
        textAlign: textAlign,
        style: style ?? AppText.bodyM,
      ),
    );
  }
}

/// M9: a real milestone, her number inside a ring that draws on once. It is
/// given only for something she earned. [label] is what a screen reader says
/// ("Sessions this week 3"); the drawing and the number are one reading.
class MomentNumber extends StatelessWidget {
  const MomentNumber({
    super.key,
    required this.number,
    required this.label,
    this.size = 72,
  });

  final String number;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $number',
      excludeSemantics: true,
      child: HandCircled(
        seed: handSeed(['milestone', number]),
        color: HandInk.done,
        width: HandStroke.felt,
        level: HandLevel.signature,
        inflate: const EdgeInsets.all(6),
        drawOn: true,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: Text(number, style: AppText.titleL)),
        ),
      ),
    );
  }
}
