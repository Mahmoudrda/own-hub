/// C04, the tour, and C05, the join sheet raised over it.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C04`/`C05` in purpose: the one
/// place a woman sees the app before she has an account. It used to be a
/// browse page with two previews of workouts that did not exist. It is now a
/// short tour of the **real** screens, Home, today's workout, the workout
/// player, Rahma's recipes, the week's dinners, the daily check-in and Progress, each
/// drawn by the product's own widget with a sample week in it.
///
/// ## What keeps it a tour
///
///  * **The sample is labelled and refuses writes.** "Sample · nothing is
///    saved" is on every stop. The repositories behind the screens are fresh
///    objects that refuse every write (`demo_sample.dart`), and nothing in the
///    tour calls a store or the analytics gateway, or asks the network for
///    data. Which stop she reached and where she tapped Join are handed to
///    [LookAroundView.onStopViewed] and [LookAroundView.onJoinFrom], which the
///    router builds; the tour itself reports nothing. The app-wide crash reporting and App Check still run underneath,
///    as they do on every screen; neither carries anything she entered.
///  * **No product route can open.** The screens sit under `DemoScope`, and
///    `AppRouter.goTo` turns any route asked for under it into the join sheet.
///  * **Every real action asks her to join.** Starting a workout, logging a
///    set or a meal, opening something the sample does not carry: each raises
///    "Join to make this yours", and "Keep looking" leaves her on the stop.
///
/// The stop she is on lives in this widget's state and nowhere else, so a
/// relaunch starts at the front door again. System back walks back through
/// the stops; on the first it leaves the tour.
///
/// C05 is not a separate page. In the prototype it is C04 with a sheet drawn
/// over it, and it is built that way here too: [openJoinPrompt] raises the
/// sheet as the screen appears, so the route can still be reviewed on its own.
library;

import 'package:flutter/material.dart';

import '../../../app_state/demo_mode.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/screen_scope.dart';
import '../../eat/data/seeded_recipe_library.dart';
import '../../eat/presentation/rahma_recipe_view.dart';
import '../demo/demo_sample.dart';
import 'demo/demo_chrome.dart';
import 'demo/demo_stops.dart';

/// Where she tapped Join: the badge bar (on every stop, the end card and
/// Rahma's recipe), the join sheet, or "Make it mine" on the end card.
enum DemoJoinSource { bar, sheet, end }

class LookAroundView extends StatefulWidget {
  const LookAroundView({
    super.key,
    this.onJoin,
    this.onLeave,
    this.onSignIn,
    this.waiting = false,
    this.setupDone = false,
    this.openJoinPrompt = false,
    this.initialStop = 0,
    this.sample,
    this.onStopViewed,
    this.onJoinFrom,
  });

  /// "Join Own Hub", "Make it mine" and the sheet's join button. All lead to
  /// the same place: her week, then her number.
  final VoidCallback? onJoin;

  /// The close button: leaves the tour.
  final VoidCallback? onLeave;

  /// "I already have an account", on the end card.
  final VoidCallback? onSignIn;

  /// She is already signed up and waiting on her check (`C14` opened this).
  /// The join button reads "Back to my check" and [onJoin] takes her there.
  final bool waiting;

  /// Her week is already built on this phone, so Join goes straight to her
  /// number. Only changes what the join sheet says comes next.
  final bool setupDone;

  /// Raises the join sheet as soon as the screen appears. See the file note.
  final bool openJoinPrompt;

  /// Zero-based. [DemoStop.values.length] is the end card.
  final int initialStop;

  /// Injectable so a test can hold the sample it inspects.
  final DemoSample? sample;

  /// The stop now on screen, zero-based, as the tour opens and each time it
  /// moves. [DemoStop.values.length] is the end card.
  final ValueChanged<int>? onStopViewed;

  /// Which Join she tapped, and on which stop. Called just before [onJoin].
  final void Function(DemoJoinSource source, int stop)? onJoinFrom;

  @override
  State<LookAroundView> createState() => _LookAroundViewState();
}

class _LookAroundViewState extends State<LookAroundView> {
  late final DemoSample _sample;
  late int _stop;
  bool _sheetOpen = false;

  /// The bundled recipe seed did not load, so no recipe opens and the recipes
  /// stop must not promise one.
  bool _bookFailed = false;

  int get _endCard => DemoStop.values.length;

  @override
  void initState() {
    super.initState();
    _sample = widget.sample ?? DemoSample.build();
    _sample.refusals.listener = _requestJoin;
    _stop = widget.initialStop.clamp(0, _endCard);
    widget.onStopViewed?.call(_stop);
    if (_sample.book == null) {
      // The bundled seed, read on the phone. Never the library on the
      // server: the tour asks the network for no data.
      SeededRecipeLibrary().load().then(
        (book) {
          if (mounted) setState(() => _sample.book = book);
        },
        onError: (_) {
          if (mounted) setState(() => _bookFailed = true);
        },
      );
    }
    if (widget.openJoinPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestJoin());
    }
  }

  @override
  void dispose() {
    if (widget.sample == null) {
      _sample.dispose();
    } else {
      _sample.refusals.listener = null;
    }
    super.dispose();
  }

  /// One sheet at a time, however many things asked for it in one tap: a
  /// logged set is refused by the sample and handed to the stop's own
  /// callback in the same frame.
  Future<void> _requestJoin() async {
    if (_sheetOpen || !mounted) return;
    _sheetOpen = true;
    try {
      await showJoinSheet(
        context,
        waiting: widget.waiting,
        setupDone: widget.setupDone,
        onJoin: _joinFrom(DemoJoinSource.sheet),
      );
    } finally {
      _sheetOpen = false;
    }
  }

  void _show(int stop) {
    final next = stop.clamp(0, _endCard);
    if (next == _stop) return;
    setState(() => _stop = next);
    widget.onStopViewed?.call(next);
  }

  /// [LookAroundView.onJoin], reporting where it was tapped first. Null when
  /// there is no join, so the button is drawn disabled as before.
  VoidCallback? _joinFrom(DemoJoinSource source) {
    final join = widget.onJoin;
    if (join == null) return null;
    return () {
      widget.onJoinFrom?.call(source, _stop);
      join();
    };
  }

  /// Rahma's first recipe opens in full, read-only, still inside the tour.
  /// Any other recipe asks her to join.
  void _openRecipe(String recipeId) {
    final recipe = firstBookRecipe(_sample.book);
    if (recipe == null || recipe.recipeId != recipeId) {
      _requestJoin();
      return;
    }
    final joinLabel = _joinLabel(AppL10n.of(context));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (page) => Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                DemoBadgeBar(
                  joinLabel: joinLabel,
                  onJoin: _joinFrom(DemoJoinSource.bar),
                ),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: page,
                    removeTop: true,
                    child: DemoScope(
                      requestJoin: (_) => _requestJoin(),
                      child: ScreenScope(
                        screenId: 'E06',
                        child: RahmaRecipeView(
                          recipe: recipe,
                          onBack: () => Navigator.of(page).pop(),
                          onShare: _requestJoin,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _joinLabel(AppL10n l10n) =>
      widget.waiting ? l10n.backToMyCheck : l10n.joinOwnHub;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final atEnd = _stop >= _endCard;
    final stop = atEnd ? null : DemoStop.values[_stop];

    final wiring = DemoWiring(
      sample: _sample,
      show: (next) => _show(next.index),
      join: _requestJoin,
      openRecipe: _openRecipe,
    );

    return PopScope(
      canPop: _stop == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _show(_stop - 1);
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                DemoBadgeBar(
                  joinLabel: _joinLabel(l10n),
                  onJoin: _joinFrom(DemoJoinSource.bar),
                  onLeave: widget.onLeave,
                ),
                if (stop != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    // Never more than two fifths of the screen, and less at
                    // a large text size, so the stop under it stays the
                    // larger part. The card scrolls inside that.
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                            constraints.maxHeight *
                            (MediaQuery.textScalerOf(context).scale(1) > 1.3
                                ? 0.28
                                : 0.4),
                      ),
                      child: SingleChildScrollView(
                        child: DemoCoachCard(
                          number: stop.index + 1,
                          total: DemoStop.values.length,
                          title: stop.title(l10n),
                          line:
                              stop == DemoStop.recipes &&
                                  _bookFailed &&
                                  _sample.book == null
                              ? l10n.homeCookingYouAlreadyKnowWrittenBy_7q8w1
                              : stop.line(l10n),
                          onBack: stop.index == 0
                              ? null
                              : () => _show(stop.index - 1),
                          onNext: () => _show(stop.index + 1),
                          guide: stop != DemoStop.cycle,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: stop == null
                        ? DemoEndCard(
                            joinLabel: widget.waiting
                                ? l10n.backToMyCheck
                                : l10n.makeItMine,
                            onJoin: _joinFrom(DemoJoinSource.end),
                            onAgain: () => _show(0),
                            onSignIn: widget.waiting ? null : widget.onSignIn,
                          )
                        : DemoScope(
                            requestJoin: (_) => _requestJoin(),
                            child: ScreenScope(
                              screenId: stop.screenId,
                              child: KeyedSubtree(
                                key: ValueKey<DemoStop>(stop),
                                child: buildDemoStop(context, stop, wiring),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
