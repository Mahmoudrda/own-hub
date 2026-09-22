/// One or two illustrations for the current screen, centred.
///
/// Reads the screen's own id from [ScreenScope] and its illustrations from
/// [ScreenArt], so any screen can drop this in with no arguments. `AppScaffold`
/// draws it automatically; screens with a layout of their own -- a camera
/// viewfinder, a video player, a sheet -- place it where it suits them.
///
/// Draws nothing outside the router or for a screen with no entry, so it is safe
/// anywhere, including in a widget test that builds a screen directly.
library;

import 'package:flutter/widgets.dart';

import '../theme/app_art.dart';
import '../theme/screen_art.dart';
import 'hand/hand.dart';
import 'screen_scope.dart';

class ScreenArtStrip extends StatelessWidget {
  const ScreenArtStrip({super.key, this.size = 92});

  /// Longest side of each illustration, in logical pixels. Sized so two sit
  /// side by side on the narrowest phone with the first content still in view.
  final double size;

  @override
  Widget build(BuildContext context) {
    final names = ScreenArt.headerFor(ScreenScope.of(context));
    if (names.isEmpty) return const SizedBox.shrink();
    // The drawings stand on a pencil ground line, a little wider than they
    // are, so they sit on the page instead of floating over it.
    return Center(
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < names.length; i++) ...[
                    if (i > 0) const SizedBox(width: 20),
                    AppArt.image(names[i], size: size),
                  ],
                ],
              ),
            ),
            HandRule(seed: names.first.hashCode, height: 6),
          ],
        ),
      ),
    );
  }
}

/// A cover screen's illustrations, set inline — beside a title rather than
/// in a strip over it. Draws what [ScreenArt.inlineFor] gives this screen,
/// which is its ordinary entry in the table, and nothing outside the router.
class ScreenArtInline extends StatelessWidget {
  const ScreenArtInline({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final names = ScreenArt.inlineFor(ScreenScope.of(context));
    if (names.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < names.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AppArt.image(names[i], size: size),
        ],
      ],
    );
  }
}
