/// The recipe book's own colours: the app's Linen, Petrol and Pale Pink, laid
/// out as a page.
///
/// Hand-written and deliberately separate from the generated `app_tokens.dart`,
/// exactly as `hand_tokens.dart` is: a token regeneration must never be able to
/// wipe this.
///
/// ## This is a theme inside the hand system, not a fork of it
///
/// Both are paper, both are drawn by hand. The book sets dark petrol ink
/// ([ink]) on a white card ([paper]) over a soft pink ground ([bg]), and the
/// arithmetic is worth stating: the app's own `AppColors.primary` on
/// `AppColors.surface` measures **6.94:1**, while [ink] on [paper] measures
/// **11.34:1**. Any text on [bg] is the dark petrol, never the lighter one,
/// the same ink the cards use, so the page reads as one hand.
///
/// `r2_41_app_palette_contrast_test.dart` asserts the app's figures and
/// `recipe_book_tokens_test.dart` asserts the book's.
///
/// ## The section title
///
/// The book's own divider title, `#D3737E`, measured **2.51:1** on the paper and
/// **1.68:1** on the pink ground it is drawn over, and failed WCAG AA at any
/// size. It was never shipped. [roseTitle] is the replacement, and in this
/// palette it is the dark petrol: the constraint is 3:1 on [bg] and 4.5:1 on
/// [paper], and `recipe_book_tokens_test.dart` measures both rather than
/// trusting this comment.
///
/// ## There is no dark mode here, and there must not be
///
/// `buildTheme()` uses `const ColorScheme.light(...)` only. There is no
/// `darkTheme`, no `ThemeMode` and no `Brightness.dark` anywhere in `lib/`. A
/// dark Eat tab inside a light app is worse than no dark mode at all, so this
/// file has no dark variant and no `Brightness` branch.
///
/// For the day the app gets one, the inversion that works is dark petrol
/// paper with ink `#F9DEDC`; the pink survives only as the
/// clip, a hairline edge and the section titles. Recorded here as a note and
/// deliberately not wired.
library;

import 'package:flutter/painting.dart';

import 'app_tokens.dart';

/// The book's palette. Shaped like `HandInk`, on purpose: a reader who knows
/// one knows the other.
abstract final class BookInk {
  /// The soft pink behind the cards. The ground of every page, kept soft so
  /// the pink is a setting and not a wall.
  static const Color bg = AppColors.pinkSoft;

  /// The card itself, and the divider's inner panel.
  static const Color paper = AppColors.white;

  /// Titles and body on [paper]. **11.34:1**.
  static const Color ink = AppColors.petrolDark;

  /// The PS line under a section title. **11.34:1** on [paper].
  static const Color inkSoft = AppColors.petrolDark;

  /// The clip at the top of each card. Decorative only: it carries no
  /// information, takes no tap and is excluded from the semantics tree, so it
  /// is never measured for contrast.
  static const Color clip = AppColors.petrolMuted;

  /// The section title. Replaces the book's own `#D3737E`, which is 2.51:1 and
  /// fails AA at any size. 11.34:1 on [paper], 8.91:1 on [bg].
  static const Color roseTitle = AppColors.petrolDark;

  /// A hairline for a rule or an edge on the paper. The ink at low alpha rather
  /// than a grey, so nothing on this surface is a colour from a different book.
  static const Color hairline = Color(0x33123F50);
}

/// How much room the card gives her words.
///
/// The book's card is a fixed-aspect page. This one cannot be: the large-text
/// sweep pumps every screen at 1.6x and a 38 pt title becomes 61 pt, which
/// wraps `Shrimp white sauce pasta` onto three lines. So the card is
/// intrinsically sized and scrollable, and **can never be shipped as a picture
/// of a card**.
abstract final class BookMetrics {
  /// Matches the book's generous head room above the title, where the
  /// illustration overlaps.
  static const EdgeInsets cardPadding = EdgeInsets.fromLTRB(20, 34, 20, 26);

  /// The clip sits above the card's top edge, half on and half off.
  static const double clipHeight = 34;
  static const double clipWidth = 26;

  /// One card per row at phone width. Two is the book's layout on a 1057 pt
  /// page and it produces a 170 pt card on a 390 pt phone, which fails at 1.6x.
  static const double cardGap = 18;
}
