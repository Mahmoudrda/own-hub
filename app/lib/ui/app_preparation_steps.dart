/// D39 — a short, true account of work the app has just done for her.
///
/// The second video study's labour illusion: a result arrives with more trust
/// when the work behind it is seen. Own Hub takes the half that is honest.
/// Each step names an operation that really ran, the steps that are done tick
/// in turn over a short minimum, and a step that has not happened waits in
/// pencil and never ticks. Nothing here holds back a result: the caller decides
/// when its result shows, and a tap anywhere finishes the ticking at once.
///
/// Never on logging, navigation or anything she does often (D39). Still under
/// Reduce Motion: every done step is ticked on the first frame.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/hand.dart';

class AppPreparationSteps extends StatefulWidget {
  const AppPreparationSteps({
    super.key,
    required this.labels,
    required this.completed,
    this.minimum = const Duration(milliseconds: 1200),
    this.enabled = true,
    this.onShown,
  });

  /// Every step, in order. Each names something that runs.
  final List<String> labels;

  /// How many of [labels], from the first, have really happened. The rest
  /// wait in pencil and are never ticked by this widget.
  final int completed;

  /// How long the done steps take to tick, all together.
  final Duration minimum;

  /// False ticks every done step at once.
  final bool enabled;

  /// Called once, when every done step is ticked.
  final VoidCallback? onShown;

  @override
  State<AppPreparationSteps> createState() => _AppPreparationStepsState();
}

class _AppPreparationStepsState extends State<AppPreparationSteps>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.minimum,
  )..addStatusListener(_status);
  bool _started = false;
  bool _announced = false;

  int get _done => widget.completed.clamp(0, widget.labels.length);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.enabled ||
        _done == 0 ||
        handMotionOff(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _c.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
      return;
    }
    _c.forward();
  }

  void _status(AnimationStatus status) {
    // After the frame: with motion off the controller is set to its end while
    // the page is being built, and telling the parent then would rebuild it
    // in the middle of its own build.
    if (status == AnimationStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    }
  }

  void _finish() {
    if (_announced || !mounted) return;
    _announced = true;
    widget.onShown?.call();
  }

  void _skip() {
    if (_c.isAnimating) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _skip(),
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // One done step ticks per equal share of [minimum]; the last as it
        // completes.
        final shown = _c.isCompleted
            ? _done
            : (_c.value * _done).floor().clamp(0, _done);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _StepRow(
                  label: widget.labels[i],
                  state: i < shown
                      ? _StepState.done
                      : i < _done
                      ? _StepState.coming
                      : _StepState.waiting,
                  // The latest tick is announced, once, for anyone not
                  // looking at the screen.
                  announce: i == shown - 1,
                ),
              ),
          ],
        );
      },
    ),
  );
}

enum _StepState { done, coming, waiting }

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.state,
    required this.announce,
  });

  final String label;
  final _StepState state;
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final done = state == _StepState.done;
    final mark = SizedBox.square(
      dimension: 24,
      child: Center(
        child: switch (state) {
          _StepState.done => const HandTick(size: 22, seed: 7, drawOn: true),
          _StepState.coming => const SizedBox.shrink(),
          _StepState.waiting => const Icon(
            Icons.autorenew,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
        },
      ),
    );
    return Semantics(
      liveRegion: announce,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mark,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppText.bodyM.copyWith(
                color: done ? AppColors.onSurface : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
