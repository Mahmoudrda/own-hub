/// Drives the real app on a simulator so a screen recording can be cut into a
/// launch video.
///
/// This file exists **only** to perform the app for a camera. It asserts almost
/// nothing; it taps, it waits the way a person waits, and it prints a timeline
/// of what it did and when, so the recording can be cut and a tap indicator
/// drawn at the right moments.
///
/// Nothing in `lib/` is changed by it. The one thing it sets is
/// `AppRouter.featureFlags = FeatureFlags.everything`, which is what the
/// crawler and the journey tests already do, so the community tab and the coach
/// side are reachable while it walks.
///
/// ## Why the gestures are hand-rolled
///
/// `tester.tap` and `tester.startGesture` dispatch with
/// `TestBindingEventSource.test`, and the live binding paints a large blue
/// crosshair over every such pointer — on the recording, on top of the button
/// being pressed. Sending the same events as `device` (with
/// `shouldPropagateDevicePointerEvents` on, and put back before the test ends)
/// runs them through exactly the same gesture arena with nothing drawn over
/// them.
///
/// Run:
///   flutter test integration_test/demo_drive_test.dart -d SIMULATOR-UDID
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_log_button.dart';
import 'package:own_hub/ui/app_nav_bar.dart';
import 'package:own_hub/ui/app_toggle.dart';

// ---------------------------------------------------------------- timeline --

late DateTime _t0;
late LiveTestWidgetsFlutterBinding _binding;

void _mark(String kind, String label) {
  final ms = DateTime.now().difference(_t0).inMilliseconds;
  // One line per event, pipe separated, so the host can parse it out of the
  // test log without guessing.
  // ignore: avoid_print
  print('DEMOMARK|$ms|$kind|$label');
}

/// Everything readable on screen right now, and the route it belongs to.
void _dump(String tag) {
  final seen = <String>[];
  String route = '-';
  for (final element in find.byType(Text).hitTestable().evaluate()) {
    final data = (element.widget as Text).data;
    if (data != null && data.isNotEmpty) seen.add(data);
    if (route == '-') route = ModalRoute.of(element)?.settings.name ?? '?';
  }
  // ignore: avoid_print
  print('DEMODUMP|$tag|$route|${seen.take(12).join(' ~ ')}');
}

// ------------------------------------------------------------------ pacing --

/// Stand still for [ms] of real time, drawing while it waits.
///
/// The frame policy is the binding's default, so a frame is produced only when
/// this pumps one. That is deliberate: `fullyLive` draws every frame the
/// framework asks for, and a 1320x2868 display being screen-recorded at that
/// rate takes the app down mid-take on this machine. So the rate is chosen
/// here — smooth while a transition or a drawn-on mark is running, and slow
/// once the screen has settled, where every frame would be identical anyway.
Future<void> _hold(WidgetTester tester, int ms) async {
  const smoothFor = 1500; // ms of 30fps after anything happens
  const smooth = 33;
  const settled = 200;
  var elapsed = 0;
  while (elapsed < ms) {
    final step = elapsed < smoothFor ? smooth : settled;
    final wait = (ms - elapsed) < step ? (ms - elapsed) : step;
    await tester.pump(Duration(milliseconds: wait));
    elapsed += wait;
  }
}

/// Only widgets that can actually be hit at their centre.
Finder _vis(Finder finder) => finder.hitTestable();

Future<Finder> _waitFor(
  WidgetTester tester,
  Finder finder, {
  int timeoutMs = 8000,
}) async {
  final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
  while (DateTime.now().isBefore(deadline)) {
    final hit = _vis(finder);
    if (hit.evaluate().isNotEmpty) return hit;
    await tester.pump(const Duration(milliseconds: 100));
  }
  _dump('miss');
  throw TestFailure('nothing hit-testable matched: $finder');
}

// ----------------------------------------------------------------- gestures

int _nextPointer = 100;
Duration _stamp = Duration.zero;

void _send(PointerEvent event) => _binding.handlePointerEventForSource(event);

/// A tap with a finger on it: down, a beat, up — so the press animation is on
/// the recording rather than skipped between two frames.
Future<void> _tap(
  WidgetTester tester,
  Finder finder,
  String label, {
  int downMs = 80,
  int index = 0,
}) async {
  final target = await _waitFor(tester, finder);
  final centre = tester.getCenter(target.at(index));
  _mark(
    'tap',
    '$label @${centre.dx.toStringAsFixed(0)},${centre.dy.toStringAsFixed(0)}',
  );
  final id = _nextPointer++;
  _stamp += const Duration(milliseconds: 16);
  _send(PointerDownEvent(pointer: id, position: centre, timeStamp: _stamp));
  await _hold(tester, downMs);
  _stamp += Duration(milliseconds: downMs);
  _send(PointerUpEvent(pointer: id, position: centre, timeStamp: _stamp));
  await _hold(tester, 60);
}

/// A real drag, rendered frame by frame, for a control below the fold.
Future<void> _swipeUp(WidgetTester tester, double distance) async {
  final scrollable = _vis(find.byType(Scrollable)).first;
  var point = tester.getCenter(scrollable);
  _mark('scroll', 'up ${distance.toStringAsFixed(0)}');
  final id = _nextPointer++;
  _stamp += const Duration(milliseconds: 16);
  _send(PointerDownEvent(pointer: id, position: point, timeStamp: _stamp));
  await tester.pump(const Duration(milliseconds: 40));
  const steps = 18;
  final step = Offset(0, -distance / steps);
  for (var i = 0; i < steps; i++) {
    point += step;
    _stamp += const Duration(milliseconds: 16);
    _send(
      PointerMoveEvent(
        pointer: id,
        position: point,
        delta: step,
        timeStamp: _stamp,
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  _stamp += const Duration(milliseconds: 16);
  _send(PointerUpEvent(pointer: id, position: point, timeStamp: _stamp));
  await _hold(tester, 800);
}

// --------------------------------------------------------------- navigation

/// The escape hatch the brief allows: open a screen by name when no tap
/// reaches it.
Future<void> _jump(WidgetTester tester, String screenId) async {
  _mark('jump', screenId);
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .pushNamed(appDestinations[screenId]!.name);
  await _hold(tester, 700);
}

/// Back to the Home route the app opened on, **disposing everything above it**.
///
/// Not tidiness. R09's rest countdown is a plain `Timer`, and a route below the
/// top is kept alive rather than disposed, so the clock she left behind keeps
/// running and — 38 seconds later, wherever she now is — calls `onReady` and
/// pushes R07 over the screen she is on. Popping the training routes off is
/// what stops that landing in the middle of a take.
Future<void> _popToRoot(WidgetTester tester) async {
  _mark('nav', 'pop-to-home');
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .popUntil((route) => route.isFirst);
  await _hold(tester, 1000);
}

void _scene(String name, String edge) => _mark('scene', '$name:$edge');

// ------------------------------------------------------------------ finders

Finder _navTab(String label) =>
    find.descendant(of: find.byType(AppNavBar), matching: find.text(label));

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Left at the default on purpose — see `_hold`. The pump rate is the frame
  // rate, so the recording gets smooth transitions without the app rendering
  // (and the recorder capturing) 60 identical frames a second of a still page.

  testWidgets('walks Own Hub for the launch video', (tester) async {
    _binding.shouldPropagateDevicePointerEvents = true;
    AppRouter.featureFlags = FeatureFlags.everything;
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _t0 = DateTime.now();
    await tester.pumpWidget(const OwnHubApp());
    _mark('boot', 'pumped');
    await _hold(tester, 3000);

    // ------------------------------------------------------- warm-up ------
    //
    // None of this is in a clip.
    _mark('warmup', 'begin');

    // (a) My cycle set up, so the hub has a day to show when scene 7 arrives.
    await _jump(tester, 'Y03');
    await _hold(tester, 1200);
    await _tap(
      tester,
      find.text('Track periods and symptoms'),
      'warm.cycle-set-up',
    );
    await _hold(tester, 1200);
    await _tap(
      tester,
      find.text('Track periods and symptoms'),
      'warm.cycle-mode-dates',
    );
    await _hold(tester, 700);
    await _tap(tester, find.text('Continue'), 'warm.cycle-continue');
    await _hold(tester, 1200);
    await _tap(tester, find.text('Save preferences'), 'warm.cycle-save-prefs');
    await _hold(tester, 1500);
    _dump('after-cycle-setup');
    await _popToRoot(tester);

    // (b) The session, advanced to the goblet squat. The day starts on the
    // glute bridge, whose set button reads "Done · 0 kg × 12"; the move the
    // mid-set scene is about is the second one, so the first is logged here.
    await _hold(tester, 1200);
    await _tap(
      tester,
      find.text("Start, everything's ready"),
      'warm.home-start',
    );
    await _hold(tester, 1600);
    await _tap(
      tester,
      find.text("Start, everything's ready"),
      'warm.day-start',
    );
    await _hold(tester, 1800);
    await _tap(
      tester,
      find.text('I did all 3 sets, log them'),
      'warm.log-move',
    );
    await _hold(tester, 1800);
    await _tap(
      tester,
      find.text('Next move · step-back lunge'),
      'warm.next-move',
    );
    await _hold(tester, 1800);
    await _popToRoot(tester);
    await _hold(tester, 1800);
    _mark('warmup', 'end');

    // --------------------------------------------------- 1. Home ----------
    _scene('01-home', 'start');
    await _hold(tester, 2600);
    await _tap(
      tester,
      find.text("Start, everything's ready"),
      '01.start-everythings-ready',
    );
    await _hold(tester, 2600);
    _scene('01-home', 'end');

    // ------------------------------------------ 2. The day's session ------
    _scene('02-session', 'start');
    await _hold(tester, 2600);
    await _tap(
      tester,
      find.text("Start, everything's ready"),
      '02.start-the-session',
    );
    await _hold(tester, 2600);
    _scene('02-session', 'end');

    // ------------------------------------------------- 3. Mid-set ---------
    _scene('03-mid-set', 'start');
    await _hold(tester, 2800);
    await _tap(tester, find.text('Done · 12 kg × 10'), '03.done-12kg-10');
    await _hold(tester, 3000);
    _scene('03-mid-set', 'end');

    // ------------------------------------- 4. Finish the session ----------
    _scene('04-finish', 'start');
    await _hold(tester, 1800);
    await _tap(
      tester,
      find.text("I'm ready, next set"),
      '04.im-ready-next-set',
    );
    await _hold(tester, 2000);
    await _tap(
      tester,
      find.text('I did all 3 sets, log them'),
      '04.i-did-all-3-sets',
    );
    await _hold(tester, 2000);
    await _tap(tester, find.text('Finish here'), '04.finish-here');
    await _hold(tester, 4000);
    _scene('04-finish', 'end');

    // between the clips: off the celebration and back to Home
    await _tap(tester, find.text('Back to today'), 'link.back-to-today');
    await _hold(tester, 1600);
    // Everything the session pushed goes now, rest clock included.
    await _popToRoot(tester);
    await _hold(tester, 1400);

    // ---------------------------------------------------- 5. Tabs ---------
    _scene('05-tabs', 'start');
    await _hold(tester, 2400);
    await _tap(tester, _navTab('Eat'), '05.tab-eat');
    await _hold(tester, 2800);
    _scene('05-tabs', 'end');

    // ----------------------------------------------------- 6. Eat ---------
    _scene('06-eat', 'start');
    await _hold(tester, 2400);
    await _tap(tester, find.byType(AppLogButton), '06.log-a-meal');
    // The undo window is five seconds. Hold past it, so the bar is read and
    // then loses its Undo on camera rather than being cut off.
    await _hold(tester, 7400);
    _scene('06-eat', 'end');

    // between the clips: the cycle hub, then its check-in
    await _jump(tester, 'Y03');
    await _hold(tester, 1500);
    await _tap(
      tester,
      find.text('How are you feeling?'),
      'link.cycle-check-in',
    );
    await _hold(tester, 1800);

    // ------------------------------------------------ 7. My cycle ---------
    _scene('07-cycle', 'start');
    await _hold(tester, 2400);
    await _tap(tester, find.text('Low'), '07.energy-low');
    await _hold(tester, 1400);
    await _tap(tester, find.text('Moderate'), '07.cramps-moderate');
    await _hold(tester, 1400);
    await _tap(tester, find.text('Less hungry'), '07.appetite-less-hungry');
    await _hold(tester, 1600);
    await _tap(tester, find.text('Save check-in'), '07.save-check-in');
    await _hold(tester, 3800);
    _scene('07-cycle', 'end');

    // between the clips: her profile, then Privacy
    await _jump(tester, 'A02');
    await _hold(tester, 1600);
    await _swipeUp(tester, 320);
    await _tap(tester, find.text('Privacy'), 'link.open-privacy');
    await _hold(tester, 1800);

    // ------------------------------------------------- 8. Privacy ---------
    _scene('08-privacy', 'start');
    await _hold(tester, 2400);
    await _tap(
      tester,
      find.byType(AppToggle),
      '08.toggle-personal-bests',
      index: 1,
    );
    await _hold(tester, 2800);
    _scene('08-privacy', 'end');

    // between the clips: onto a screen whose Home tab is a live link. Privacy
    // draws the bar with Home already marked active, so its own Home tab is
    // not tappable at all.
    await _tap(tester, _navTab('Eat'), 'link.tab-eat-again');
    await _hold(tester, 2200);

    // -------------------------------------------- 9. Home again ----------
    _scene('09-home-again', 'start');
    await _hold(tester, 2400);
    await _tap(tester, _navTab('Home'), '09.tab-home');
    await _hold(tester, 4200);
    _scene('09-home-again', 'end');

    _mark('done', 'end-of-walk');
    _binding.shouldPropagateDevicePointerEvents = false;
  }, timeout: const Timeout(Duration(minutes: 12)));
}
