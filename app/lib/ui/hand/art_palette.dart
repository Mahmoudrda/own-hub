/// The colours the illustrations are painted in.
///
/// ## Why this file exists
///
/// The marks in `art_marks.dart` and `food_marks.dart` were first drawn in one
/// ink: a thin rose outline with a 12% wash inside it. That was licence-clean
/// and cost nothing, and it was also the thing the owner looked at and
/// rejected — the product he had asked for was **clean, flat and colourful**,
/// and a page of single-ink line drawings is none of those. See
/// `assets/art/LICENCE.md` for the whole history, including why the colourful
/// set that used to be here could not simply be put back.
///
/// So the geometry stayed and the paint changed. Every mark now has a
/// **two-colour scheme**: a solid [ArtTone.fill] inside its closed shapes and a
/// deeper [ArtTone.line] on every stroke. That is the flat-illustration idiom —
/// a filled body with a drawn edge — rather than an outline with a hint of
/// colour behind it.
///
/// ## The figures are one colour on purpose
///
/// Every woman in this set is painted in a single [ArtTones.rose], head
/// included. She is a pictogram, not a portrait: there is no skin tone, no
/// hair, no face and no garment anywhere in the set, because an empty-state
/// drawing in an app for women in Egypt has no business deciding whether a
/// woman's hair is covered, or what colour she is. The licensed sets that were
/// considered as replacements all failed on exactly this — see the comparison
/// in `assets/art/LICENCE.md`.
///
/// ## Why these particular colours
///
/// All of them are mixed against the product's own surface (`AppColors.surface`,
/// a warm `#FFF8F9`) and its rose (`AppColors.primary`). The pack that was
/// removed was flat saturated vector art that sat on that page like a sticker;
/// these are tuned to sit on it like print.
///
/// Every [ArtTone.line] clears **4.5:1 against that surface**, measured rather
/// than eyeballed — `cream` and `yolk` were originally `#8E7250` and `#9C6D14`
/// and came in at 4.29 and 4.35, so both were darkened until they cleared. The
/// bar is deliberately the text one rather than the 3:1 that non-text graphics
/// have to meet, because a mark is a shape read at 30 pt beside a list row and
/// the cheap version of this always ends up invisible on somebody's phone in
/// daylight. Nothing in this product puts meaning in a drawing the words beside
/// it do not already carry, so this is a courtesy rather than a requirement —
/// but it costs nothing and it is the kind of thing that is never fixed later.
///
/// [ArtTone.fill] is NOT held to that bar and must not be: a fill is a field of
/// colour with its own line drawn round it, and a fill dark enough to pass
/// against the page would swallow the line and turn every mark into a
/// silhouette.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// One mark's two colours: a solid interior and the line drawn round it.
@immutable
class ArtTone {
  const ArtTone(this.fill, this.line);

  /// Painted solid inside every closed shape of the mark.
  final Color fill;

  /// Every stroke, and the edge of every filled shape.
  final Color line;

  @override
  bool operator ==(Object other) =>
      other is ArtTone && other.fill == fill && other.line == line;

  @override
  int get hashCode => Object.hash(fill, line);
}

/// The twelve colours the whole set is painted from.
///
/// Twelve rather than one per mark: a set in thirty-two unrelated colours is a
/// swatch sheet, not a family. Marks that mean related things share a tone, so
/// two bowls of leaves on one screen look like they came from the same hand.
abstract final class ArtTones {
  /// Every figure, and anything that is about her rather than about a thing.
  static const rose = ArtTone(Color(0xFFF2B6C6), Color(0xFFA24661));

  /// Paler rose, for a surface that sits behind something else.
  static const blush = ArtTone(Color(0xFFFBDCE4), Color(0xFFA24661));

  /// Kit she wears or carries.
  static const plum = ArtTone(Color(0xFFC890B2), Color(0xFF6E3356));

  /// Leaves, and anything green on a plate.
  static const leaf = ArtTone(Color(0xFFA6CCAC), Color(0xFF41634B));

  /// Bread, grain, pastry, nuts.
  static const amber = ArtTone(Color(0xFFF1C68A), Color(0xFF8A5A17));

  /// Crockery, and the white of an egg.
  static const cream = ArtTone(Color(0xFFF7E7D4), Color(0xFF866A48));

  /// Grapes, and the one bag that is not rose.
  static const berry = ArtTone(Color(0xFFB98AC4), Color(0xFF5B3770));

  /// Meat, and the red fruit.
  static const ember = ArtTone(Color(0xFFEE9A92), Color(0xFF9D4040));

  /// A mat, a bottle, anything cool next to all that warmth.
  static const teal = ArtTone(Color(0xFF9CC6C1), Color(0xFF3C6A66));

  /// Metal: a bar, a pot, a frame, a pair of headphones.
  static const slate = ArtTone(Color(0xFFCDC0C4), Color(0xFF645458));

  /// A yolk, and a drizzle of honey.
  static const yolk = ArtTone(Color(0xFFF6C95C), Color(0xFF936510));

  /// The dark of a rind or a sole, where a shape needs a foot to stand on.
  static const shade = ArtTone(Color(0xFF8C6F76), Color(0xFF4A3A3F));
}
