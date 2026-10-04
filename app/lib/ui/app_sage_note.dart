/// A quiet green note, matching `sageNote()` in `6-v2/src/kit.mjs`.
///
/// This is the app speaking in its own voice to reassure rather than to
/// instruct: what a rest week covers, that nothing here expires. Sage, never
/// pink and never amber — the colour carries the meaning "this costs you
/// nothing", and using it for anything else would spend that.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_card.dart' show kCardHatchOpacity;
import 'hand/hand.dart';

class AppSageNote extends StatelessWidget implements HandSeedName {
  @override
  String get handSeedName => 'AppSageNote';

  const AppSageNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    // Sage pencil hatching laid on the page — tone the way a pencil makes it
    // — with no frame, one loose corner, and the words in the app's own plain
    // voice.
    return SizedBox(
      width: double.infinity,
      child: HandSurface(
        seed: handSeed(['sage', text]),
        hatch: AppColors.tertiary,
        hatchOpacity: kCardHatchOpacity,
        radius: 3,
        looseCorner: 20,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          text,
          style: AppText.body.copyWith(color: AppColors.onTertiaryContainer),
        ),
      ),
    );
  }
}
