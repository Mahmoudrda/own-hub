/// The body map's own colours, for P06 "Your muscles".
///
/// Hand-written and separate from the generated `app_tokens.dart`, like
/// `recipe_book_tokens.dart`: a token regeneration must never be able to wipe
/// them.
///
/// The figure is a neutral grey so her training is the only colour on it: the
/// app's pinks, then petrol for her most trained muscle. A muscle she has not
/// trained is the same grey as the body, told apart only by the white line
/// round it.
library;

import 'package:flutter/painting.dart';

abstract final class BodyMapInk {
  /// The body, and every muscle she has not trained.
  static const Color body = Color(0xFFD9D9D9);

  /// The line round the figure, a step darker than the body.
  static const Color outline = Color(0xFFB5B5B5);

  /// Her hair.
  static const Color hair = Color(0xFF5E5E5E);
}
