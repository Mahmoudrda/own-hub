/// "Take a deep breath": once, on the very first launch, before the first
/// setup question. A soft circle breathes in and out over one 4 s breath, with
/// the kitten (72 at most, on its own idle loop) resting inside it, then the
/// questions open on their own. A tap anywhere, or Skip, goes straight on.
///
/// With Reduce Motion on nothing moves: both lines are shown and a Continue
/// button leaves.
library;

import 'package:flutter/material.dart';

import '../../../app_state/first_run_moments.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/hand/hand.dart';

class DeepBreathView extends StatefulWidget {
  const DeepBreathView({super.key, this.onDone});

  /// Where it goes on to. Null pops back to the questions underneath.
  final VoidCallback? onDone;

  @override
  State<DeepBreathView> createState() => _DeepBreathViewState();
}

class _DeepBreathViewState extends State<DeepBreathView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: HandTiming.breath,
  );
  bool _started = false;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    FirstRunMoments.instance.markBreathSeen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!handMotionOff(context)) {
      _c.forward().whenComplete(() {
        if (mounted) _leave();
      });
    }
  }

  void _leave() {
    if (_left) return;
    _left = true;
    final done = widget.onDone;
    if (done != null) {
      done();
      return;
    }
    // Take this screen's own route away, whatever is on top of it now.
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) {
      _left = false;
      return;
    }
    final navigator = Navigator.of(context);
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final still = handMotionOff(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _leave,
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AppButton(
                    l10n.skip,
                    variant: AppButtonVariant.text,
                    height: 48,
                    fontSize: 15,
                    onPressed: _leave,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      final t = _c.value;
                      // Up and back along one smooth hump over the 4 s.
                      final lift = Curves.easeInOut.transform(
                        t < 0.5 ? t * 2 : (1 - t) * 2,
                      );
                      final breathingIn = t < 0.5;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.takeADeepBreath,
                            style: text.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          // The circle does the breathing; the kitten stays
                          // small (72 at most) and only breathes its own idle.
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: Center(
                              child: Container(
                                width: 96 + 64 * lift,
                                height: 96 + 64 * lift,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.brandPink.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                                child: const Center(
                                  child: Kitten(
                                    pose: KittenPose.rest,
                                    size: 72,
                                    holdStill: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (still) ...[
                            Text(l10n.breatheIn, style: text.titleMedium),
                            Text(l10n.breatheOut, style: text.titleMedium),
                          ] else
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                breathingIn ? l10n.breatheIn : l10n.breatheOut,
                                key: const ValueKey('breath-line'),
                                style: text.titleMedium,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (still)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: AppButton(l10n.continueLabel, onPressed: _leave),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
