/// The recipe book's own colours, measured off the page.
///
/// Sampled from a 1175 px render of page 3 of `Rahoma's Recipe Book.pdf`, and
/// from page 2 for the section divider. Hand-written and deliberately separate
/// from the generated `app_tokens.dart`, exactly as `hand_tokens.dart` is: a
/// token regeneration must never be able to wipe this.
///
/// ## This is a theme inside the hand system, not a fork of it
///
/// The two languages are closer than they look. Both are paper, both are rose,
/// both are drawn by hand. What the book adds is a much darker ink on a much
/// warmer paper, and the arithmetic is worth stating: the app's own
/// `AppColors.primary` on `AppColors.surface` measures **4.58:1**. The book's
/// [ink] on [paper] measures **10.55:1**. Adopting her ink makes this surface
/// the most readable in the product.
///
/// ## One colour in the book is wrong and is not shipped
///
/// The divider's huge stacked section title is `#D3737E`, which measures
/// **2.51:1** on the paper and **1.68:1** on the pink ground it is actually
/// drawn over. That fails WCAG AA at any size, including the 3:1 allowance for
/// large text, and it fails it by more on the ground than on the panel. It is
/// the one thing in her palette that has to change, and
/// [roseTitle] is the replacement: the same hue and saturation at 55% value,
/// which clears large-text AA on the pink ground and normal-text AA on the
/// paper. A designer may prefer a different landing point; the constraint is
/// 3:1 on [bg] and 4.5:1 on [paper], and `recipe_book_tokens_test.dart`
/// measures both rather than trusting this comment.
///
/// ## There is no dark mode here, and there must not be
///
/// `buildTheme()` uses `const ColorScheme.light(...)` only. There is no
/// `darkTheme`, no `ThemeMode` and no `Brightness.dark` anywhere in `lib/`. A
/// dark Eat tab inside a light app is worse than no dark mode at all, so this
/// file has no dark variant and no `Brightness` branch.
///
/// For the day the app gets one, the inversion that works is paper `#1A1114`
/// with ink `#FBDCD9`, which measures 14.41:1; the pink survives only as the
/// clip, a hairline edge and the section titles. Recorded here as a note and
/// deliberately not wired.
library;

import 'package:flutter/painting.dart';

/// The book's palette. Shaped like `HandInk`, on purpose: a reader who knows
/// one knows the other.
abstract final class BookInk {
  /// The deeper pink behind the cards. The ground of every page.
  static const Color bg = Color(0xFFF5A6AF);

  /// The card itself, and the divider's inner panel.
  static const Color paper = Color(0xFFFBDCD9);

  /// Titles and body on [paper]. **10.55:1**, and hers exactly.
  static const Color ink = Color(0xFF610904);

  /// The PS line under a section title. **12.54:1** on [paper].
  static const Color inkSoft = Color(0xFF4B0009);

  /// The wooden clip at the top of each card. Decorative only: it carries no
  /// information, takes no tap and is excluded from the semantics tree, so it
  /// is never measured for contrast.
  static const Color clip = Color(0xFFBF9A5E);

  /// The section title. Replaces the book's own `#D3737E`, which is 2.51:1 and
  /// fails AA at any size. 5.72:1 on [paper], 3.83:1 on [bg].
  static const Color roseTitle = Color(0xFF7F454C);

  /// A hairline for a rule or an edge on the paper. Her ink at low alpha rather
  /// than a grey, so nothing on this surface is a colour from a different book.
  static const Color hairline = Color(0x33610904);
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
