/// "Draw a tick to promise yourself": after she picks her plan, once. She draws
/// a tick with her finger; any reasonable down, then up and to the right
/// counts. The ideal tick is drawn on once she lifts, the tick settles and she
/// goes on. Skip is always there, and "I promise" does the same for a screen
/// reader or a switch.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/hand/hand.dart';
import '../domain/tick_stroke.dart';

class TickPromiseView extends StatefulWidget {
  const TickPromiseView({super.key, required this.onDone});

  /// Told once, after the promise or a Skip. The caller pops this screen.
  final VoidCallback onDone;

  @override
  State<TickPromiseView> createState() => _TickPromiseViewState();
}

class _TickPromiseViewState extends State<TickPromiseView> {
  static const double _boxHeight = 220;

  final List<Offset> _stroke = [];
  bool _promised = false;
  bool _left = false;
  bool _drawing = false;
  bool _tryAgain = false;
  Timer? _timer;
  Timer? _hintTimer;

  void _promise() {
    if (_promised || _left) return;
    setState(() => _promised = true);
    final wait = handMotionOff(context)
        ? HandTiming.short
        : HandMotion.draw + const Duration(milliseconds: 900);
    _timer = Timer(wait, _leave);
  }

  void _leave() {
    if (_left) return;
    _left = true;
    _timer?.cancel();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hintTimer?.cancel();
    super.dispose();
  }

  void _strokeEnded() {
    if (TickStroke.isTick(_stroke)) {
      _promise();
      return;
    }
    _hintTimer?.cancel();
    setState(() {
      _stroke.clear();
      _tryAgain = true;
    });
    _hintTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _tryAgain = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: AppButton(
                  l10n.skip,
                  variant: AppButtonVariant.text,
                  height: 48,
                  fontSize: 15,
                  onPressed: _leave,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: _drawing
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        l10n.drawATickToPromiseYourself,
                        style: text.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: _promised ? const Moment(size: 48) : null,
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        label: l10n.drawingBoxForYourTick,
                        child: Container(
                          key: const ValueKey('tick-box'),
                          height: _boxHeight,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLowest,
                            border: Border.all(color: AppColors.outline),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _promised
                                ? DrawOn(
                                    builder: (context, p) => CustomPaint(
                                      painter: TickPainter(
                                        seed: 7,
                                        color: AppColors.brandPetrol,
                                        width: 8,
                                        progress: p,
                                      ),
                                      child: const SizedBox.expand(),
                                    ),
                                  )
                                // Raw pointers, so a drawing finger never
                                // competes with the page scrolling at large
                                // text; the page is held still while she draws.
                                : Listener(
                                    behavior: HitTestBehavior.opaque,
                                    onPointerDown: (e) {
                                      _hintTimer?.cancel();
                                      setState(() {
                                        _drawing = true;
                                        _tryAgain = false;
                                        _stroke
                                          ..clear()
                                          ..add(e.localPosition);
                                      });
                                    },
                                    onPointerMove: (e) => setState(
                                      () => _stroke.add(e.localPosition),
                                    ),
                                    onPointerUp: (_) {
                                      setState(() => _drawing = false);
                                      _strokeEnded();
                                    },
                                    onPointerCancel: (_) => setState(() {
                                      _drawing = false;
                                      _stroke.clear();
                                    }),
                                    child: CustomPaint(
                                      painter: _StrokePainter(List.of(_stroke)),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: _tryAgain,
                        child: Text(
                          _tryAgain
                              ? l10n.tryOnceMoreOrTapIPromise
                              : l10n.drawItInTheBoxDownThen,
                          key: const ValueKey('tick-hint'),
                          style: text.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 14),
                child: AppButton(
                  l10n.iPromise,
                  variant: AppButtonVariant.tonal,
                  onPressed: _promise,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.brandPetrol,
    );
  }

  @override
  bool shouldRepaint(_StrokePainter old) => true;
}
