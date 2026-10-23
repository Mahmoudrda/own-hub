/// The page shape every screen in this product uses.
///
/// The prototype wraps each screen in `phone()` — a 390×844 frame with a drawn
/// status bar reading 9:41 — because it renders in a browser and has to imply a
/// device. **That chrome is not product UI**: on a real phone the OS draws the
/// status bar and the home indicator, and drawing our own would put a fake 9:41
/// above the real clock. `SafeArea` is the faithful translation, not a compromise.
///
/// What IS faithful, and is reproduced exactly, is the layout contract from
/// `6-v2/src/kit.mjs`:
///
///   body   → padding `4px 16px 0`, 10px gap between children, fills the screen
///   footer → padding `10px 16px 14px`, 10px gap, sits at the bottom, never scrolls
///
/// Keeping those numbers in one place is what lets a spacing change land on 161
/// screens at once instead of 161 times.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/screen_art.dart';
import 'hand/hand.dart';
import 'language_switch.dart' show AppChrome;
import 'screen_art_strip.dart';
import 'screen_scope.dart';

/// Vertical gap between children of [AppScaffold.children] and `footer`.
const double kStackGap = 10;

const EdgeInsets kBodyPadding = EdgeInsets.fromLTRB(16, 4, 16, 0);
const EdgeInsets kFooterPadding = EdgeInsets.fromLTRB(16, 10, 16, 14);

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.children,
    this.footer = const [],
    this.appBar,
    this.backgroundColor,
    this.scrollable = true,
    this.footerScrollsWhenLarge = false,
    this.staggerGroup,
    this.showArt = true,
    this.gap = kStackGap,
    this.showChrome = true,
  });

  /// The body. Laid out in a column with [kStackGap] between each child, exactly
  /// as `body()` does in the prototype.
  final List<Widget> children;

  /// Pinned to the bottom. The primary action lives here, within thumb reach —
  /// this product is used one-handed, between sets.
  final List<Widget> footer;

  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;

  /// Whether the body is a plain scroll view.
  ///
  /// Set false for a screen that uses [AppSpacer] to push content apart. That
  /// does **not** mean "cannot scroll": the body still fills the viewport so the
  /// spacers have room to expand, and scrolls once the content no longer fits.
  ///
  /// That distinction is not theoretical. C01 overflowed by 5 pixels in Arabic at
  /// the largest system text size — Arabic runs longer than English, and a
  /// spacer-centred layout has nowhere to give. Fixing it here fixes it for every
  /// screen built on this scaffold rather than one at a time.
  final bool scrollable;

  /// Whether, at a large system text size, the footer joins the scrolling
  /// body instead of staying pinned.
  ///
  /// For a screen whose footer is tall — the mid-set log button is 84 high
  /// before any text grows — so that at the largest sizes the pinned footer
  /// does not leave the body a sliver of the screen.
  final bool footerScrollsWhenLarge;

  /// Names this screen's list when its first rows should ease in, once per
  /// visit: 40 ms apart, at most eight, none under reduced motion. Null
  /// leaves the body as it is.
  final String? staggerGroup;

  /// Whether this screen's illustration strip is drawn. A setup question turns
  /// it off so the answers fit the screen without scrolling.
  final bool showArt;

  /// Vertical gap between the body's children.
  final double gap;

  /// Whether a screen with no top bar of its own gets a slim row with her
  /// picture and the language switch above its body. Not drawn when a bar
  /// is present (an [AppTopBar] carries them itself), off the router, on the
  /// no-chrome screens, or under a strip that already has them.
  final bool showChrome;

  @override
  Widget build(BuildContext context) {
    // This screen's illustrations, from the one table that holds them all.
    // Empty outside the router, and for the screens that draw their own hero.
    final art = showArt
        ? ScreenArt.headerFor(ScreenScope.of(context))
        : const <String>[];
    final footerInBody =
        footerScrollsWhenLarge &&
        footer.isNotEmpty &&
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _withGaps(gap, [
        if (art.isNotEmpty) const ScreenArtStrip(),
        if (staggerGroup case final group?)
          for (var i = 0; i < children.length; i++)
            StaggerIn(index: i, group: group, child: children[i])
        else
          ...children,
        if (footerInBody) ...[const SizedBox(height: 6), ...footer],
      ]),
    );

    final chromeRow =
        showChrome &&
        appBar == null &&
        !(Scaffold.maybeOf(context)?.hasAppBar ?? false) &&
        AppChrome.shownFor(context);

    // The page is paper, top to bottom — under the top bar as well — so the
    // Scaffold itself is transparent and the grain is laid beneath it.
    return PaperPage(
      color: backgroundColor ?? AppColors.surface,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: SafeArea(
          child: Column(
            children: [
              if (chromeRow)
                const Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: AppChrome(),
                ),
              Expanded(
                child: Padding(
                  padding: kBodyPadding,
                  child: scrollable
                      ? SingleChildScrollView(child: body)
                      // Fills the viewport so [AppSpacer] has room to expand, and
                      // becomes scrollable the moment the content exceeds it.
                      : LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: IntrinsicHeight(child: body),
                                ),
                              ),
                        ),
                ),
              ),
              if (footer.isNotEmpty && !footerInBody)
                Padding(
                  padding: kFooterPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _withGaps(kStackGap, footer),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static List<Widget> _withGaps(double gap, List<Widget> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(SizedBox(height: gap));
      out.add(items[i]);
    }
    return out;
  }
}

/// The prototype's `spacer()` — flexible space that pushes content apart.
///
/// Only usable inside a non-scrolling [AppScaffold]: infinite height inside a
/// scroll view has no meaning, and Flutter will say so loudly rather than
/// silently misplacing everything.
class AppSpacer extends StatelessWidget {
  const AppSpacer({super.key});

  @override
  Widget build(BuildContext context) => const Spacer();
}

/// A back/close bar. Matches `appBar()`: 64 high, title in `titleM`.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    this.title = '',
    this.onBack,
    this.actions = const [],
    this.leadingIcon = Icons.arrow_back,
    this.showChrome = true,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  /// [Icons.arrow_back] for a screen that has a previous page, [Icons.close] for
  /// one drawn *over* the screen it came from — E02 and E03 sit over Eat, so
  /// closing returns her to it rather than walking back through a history.
  ///
  /// `train_widgets.dart` asked for exactly this: "Fold the `leading` choice
  /// into [AppTopBar] once that work has landed." It is an optional parameter
  /// with the old default, so every existing caller is unchanged.
  final IconData leadingIcon;

  /// Whether her picture and the language switch end the bar. They draw only
  /// on a routed screen that is not in the no-chrome list; pass false for a
  /// bar that must stay bare.
  final bool showChrome;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  /// What the chrome (switch, picture) and the back arrow take of the bar's
  /// width, and the least the actions keep, so a wide action row scales down
  /// instead of pushing the chrome off the screen.
  static const double _chromeAndBackWidth = 210;
  static const double _leastActionsWidth = 72;

  @override
  Widget build(BuildContext context) {
    final actionsMax = showChrome && AppChrome.shownFor(context)
        ? (MediaQuery.sizeOf(context).width - _chromeAndBackWidth - 64).clamp(
            _leastActionsWidth,
            220.0,
          )
        : 220.0;
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 4,
      // Directional by design: this arrow mirrors in Arabic, which is the whole
      // point of the RTL work.
      leading: onBack == null
          ? const SizedBox(width: 8)
          : IconButton(
              onPressed: onBack,
              iconSize: 24,
              color: AppColors.onSurface,
              // Named for a screen reader, in her language, by the platform's
              // own words for it — an arrow with no name is announced as
              // "button" and nothing else.
              tooltip: leadingIcon == Icons.close
                  ? MaterialLocalizations.of(context).closeButtonTooltip
                  : MaterialLocalizations.of(context).backButtonTooltip,
              icon: Icon(leadingIcon),
            ),
      title: title.isEmpty
          ? null
          // One line, shortened at the end: the bar is a fixed 64 high, and
          // at the largest text size a title beside a button action would
          // otherwise wrap out of it. The screen's own heading carries the
          // full name where it matters.
          : Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.titleM.copyWith(color: AppColors.onSurface),
            ),
      // Scaled down rather than overflowing: at the largest text size a
      // button in the bar can be wider than the room beside the title.
      actions: [
        if (actions.isNotEmpty)
          // A fixed cap rather than a share of the screen: it must hold
          // even where no screen size is known, and 220 leaves the title
          // room on the narrowest phone.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: actionsMax),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
          ),
        // Outside the scaled-down box above, so its targets keep their size.
        if (showChrome) const AppChrome(routedOnly: true),
      ],
    );
  }
}
