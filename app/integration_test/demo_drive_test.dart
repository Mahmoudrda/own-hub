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
/// crawler and the journey tests already do.
///
/// **That flag set is visible on camera**, in three places, and whoever cuts
/// the film should know: the bottom bar carries a Community tab the first
/// release does not ship, `R10` offers "Share the squat with your group", and
/// `A03` draws four privacy switches. With the shipping six features instead,
/// `A03` draws **no** switches at all — every one of them answers "who else
/// sees this", and with no community and no coach there is nobody to see — so
/// scene 8 as briefed only exists in the everything build.
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
///
/// or, to record it, `docs/release/video/footage/record.sh` — with a
/// `flutter test` session attached the app is force-quit part way through
/// every take that is being screen-recorded.
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
  // log without guessing.
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
  print('DEMODUMP|$tag|$route|${seen.take(14).join(' ~ ')}');
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
  await _hold(tester, 40);
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

/// Scrolls until [finder] can be tapped, then taps it.
Future<void> _revealAndTap(
  WidgetTester tester,
  Finder finder,
  String label,
) async {
  for (var attempt = 0; attempt < 4; attempt++) {
    if (_vis(finder).evaluate().isNotEmpty) break;
    await _swipeUp(tester, 320);
  }
  await _tap(tester, finder, label);
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

/// Back to the route the app opened on, disposing everything above it. Keeps
/// the stack shallow so a finder cannot reach a screen two pushes down.
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

  testWidgets('walks Own Hub for the launch video', (tester) async {
    _binding.shouldPropagateDevicePointerEvents = true;
    AppRouter.featureFlags = FeatureFlags.everything;
    // A clean install every take: the setup walk is scene 00, and it only runs
    // while she has not been asked.
    AppRouter.intakeRepository.reset();
    AppRouter.progressStore.reset();
    AppRouter.todayRepository.reset();
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
    _dump('first-frame');

    // ------------------------------------------------ 0. Setup -----------
    //
    // Four questions and a summary, on a fresh install. Paced brisker than the
    // rest of the film on purpose: it is an opening montage, not a scene.
    _scene('00-setup', 'start');
    await _hold(tester, 1100);
    await _tap(tester, find.text('Get back into it'), '00.goal');
    await _hold(tester, 700);
    await _tap(tester, find.text('Continue'), '00.continue-1');
    await _hold(tester, 800);

    await _tap(tester, find.text('A ladies-only gym'), '00.place');
    await _hold(tester, 600);
    await _tap(tester, find.text('Dumbbells'), '00.equipment');
    await _hold(tester, 700);
    await _tap(tester, find.text('Continue'), '00.continue-2');
    await _hold(tester, 800);

    await _tap(tester, find.text('4'), '00.days-4');
    await _hold(tester, 600);
    await _tap(tester, find.text('30'), '00.minutes-30');
    await _hold(tester, 700);
    await _tap(tester, find.text('Continue'), '00.continue-3');
    await _hold(tester, 800);

    await _tap(tester, find.text('A knee, back or shoulder'), '00.life-stage');
    await _hold(tester, 700);
    await _tap(tester, find.text('Continue'), '00.continue-4');
    await _hold(tester, 3000);
    _scene('00-setup', 'end');
    _dump('summary');

    // between the clips: out of setup, onto her own Home
    await _tap(
      tester,
      find.text('I will start tomorrow'),
      'link.start-tomorrow',
    );
    await _hold(tester, 2200);
    _dump('home-day-one');

    // --------------------------------------------------- 1. Home ----------
    _scene('01-home', 'start');
    await _hold(tester, 2600);
    await _tap(tester, find.text('Start day 1'), '01.start-day-1');
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
    _dump('mid-set');

    // ------------------------------------------------- 3. Mid-set ---------
    _scene('03-mid-set', 'start');
    await _hold(tester, 2800);
    await _tap(tester, find.text('Done · 12 reps'), '03.done-12-reps');
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
    _dump('finished');

    // between the clips: off the celebration and back to Home
    await _tap(tester, find.text('Back to today'), 'link.back-to-today');
    await _hold(tester, 1600);
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
    _dump('eat-logged');

    // between the clips: My cycle, set it up, then the check-in.
    //
    // Opened by name. Home's own "My cycle" row is drawn from
    // `TodayDay.showCycleCard`, which only becomes true once she has set My
    // cycle up, so on a fresh install there is no door to it on Home at all —
    // the only one in the product is the row in her profile.
    await _jump(tester, 'Y03');
    await _hold(tester, 1500);
    await _tap(
      tester,
      find.text('Track periods and symptoms'),
      'link.cycle-set-up',
    );
    await _hold(tester, 1200);
    await _tap(
      tester,
      find.text('Track periods and symptoms'),
      'link.cycle-mode-dates',
    );
    await _hold(tester, 700);
    await _tap(tester, find.text('Continue'), 'link.cycle-continue');
    await _hold(tester, 1200);
    await _tap(tester, find.text('Save preferences'), 'link.cycle-save-prefs');
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
    _dump('gentler');

    // between the clips: her profile, then Privacy
    await _jump(tester, 'A02');
    await _hold(tester, 1600);
    await _revealAndTap(tester, find.text('Privacy'), 'link.open-privacy');
    await _hold(tester, 1800);
    _dump('privacy');

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

    // -------------------------------------------- 9. Home again ----------
    //
    // Straight off Privacy now: the bar there used to draw Home as the active
    // tab, which made its own Home tab a link to itself and therefore dead.
    _scene('09-home-again', 'start');
    await _hold(tester, 2400);
    await _tap(tester, _navTab('Home'), '09.tab-home');
    await _hold(tester, 4200);
    _scene('09-home-again', 'end');
    _dump('home-again');

    _mark('done', 'end-of-walk');
    _binding.shouldPropagateDevicePointerEvents = false;
  }, timeout: const Timeout(Duration(minutes: 12)));
}
