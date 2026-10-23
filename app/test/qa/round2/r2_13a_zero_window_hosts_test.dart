// R2-13a. Tests that lay out against nothing.
//
// The device-size helper is copy-pasted into the test estate as a private
// `_host(WidgetTester)`. 38 files build `MediaQueryData(textScaler: ...)` from
// scratch; ZERO files use `MediaQuery.of(context).copyWith(...)` at the point
// of the override. Two files publish a host that gets it right by re-reading
// the ambient data first:
//   app/test/features/today/today_view_test.dart:45-52  (documents the trap)
//   app/test/features/coachbrand/coachbrand_test_host.dart:41-47
// The named offenders in the plan are:
//   app/test/features/train/train_view_test.dart:28
//   app/test/ui/app_nav_bar_test.dart:33
//
// This file does not edit any of them. It proves what the bare constructor
// actually costs, so the finding is a measurement rather than a claim.
//
// What a bare `MediaQueryData()` zeroes (Flutter's own const defaults):
//   size            -> Size.zero
//   padding         -> EdgeInsets.zero   (no notch, no gesture bar)
//   viewInsets      -> EdgeInsets.zero   (no keyboard)
//   viewPadding     -> EdgeInsets.zero
// and it drops whatever the ambient query held.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shape 38 test files use.
Widget _bareHost(Widget child, {double textScale = 1.0}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  ),
);

/// The shape `today_view_test.dart` and `coachbrand_test_host.dart` use.
Widget _copyWithHost(Widget child, {double textScale = 1.0}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  ),
);

/// Reports the query it is given, and lays out at a fraction of the width the
/// way `coach_chat_view.dart:141`, `coached_widgets.dart:435` and
/// `enquiry_view.dart:193` all do (`MediaQuery.of(context).size.width * 0.8`).
class _Probe extends StatelessWidget {
  const _Probe(this.onData);

  final void Function(MediaQueryData data, double bubbleMaxWidth) onData;

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    onData(data, data.size.width * 0.8);
    return const SizedBox(width: 10, height: 10);
  }
}

void main() {
  testWidgets('a bare MediaQueryData zeroes the window; copyWith keeps it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(bottom: 102, top: 141);
    addTearDown(tester.view.reset);

    late MediaQueryData bare;
    late double bareBubble;
    await tester.pumpWidget(
      _bareHost(
        _Probe((d, b) {
          bare = d;
          bareBubble = b;
        }),
      ),
    );

    late MediaQueryData kept;
    late double keptBubble;
    await tester.pumpWidget(
      _copyWithHost(
        _Probe((d, b) {
          kept = d;
          keptBubble = b;
        }),
      ),
    );

    // ignore: avoid_print
    print(
      'R2-13a  bare MediaQueryData: size=${bare.size} '
      'padding=${bare.padding} viewPadding=${bare.viewPadding} '
      'devicePixelRatio=${bare.devicePixelRatio}',
    );
    // ignore: avoid_print
    print(
      'R2-13a  copyWith:            size=${kept.size} '
      'padding=${kept.padding} viewPadding=${kept.viewPadding} '
      'devicePixelRatio=${kept.devicePixelRatio}',
    );
    // ignore: avoid_print
    print(
      'R2-13a  a chat bubble at 0.8 * width: '
      'bare=$bareBubble  copyWith=$keptBubble',
    );

    // The trap, stated as an assertion so it is evidence and not prose.
    expect(bare.size, Size.zero);
    expect(bare.padding, EdgeInsets.zero);
    expect(bareBubble, 0.0);

    // And the correct host, for contrast.
    expect(kept.size.width, 390);
    expect(kept.size.height, 844);
    expect(kept.padding.bottom, 34);
    expect(keptBubble, closeTo(312, 0.5));
  });
}
