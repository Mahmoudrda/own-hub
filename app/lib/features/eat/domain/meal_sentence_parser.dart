/// "koshari and 2 eggs" → two items, with the sizes already picked.
///
/// E02's whole premise, and E03's too: the voice transcript goes through **this
/// same parser**, so a sentence typed and a sentence spoken resolve identically
/// and there is one place where a fragment becomes a food.
///
/// ## §2 rule 10, the food half: selects, never generates
///
/// The parser can only emit a `foodId` that already exists in the pack, and a
/// quantity that already exists in that food's `sizes[]`. A fragment it cannot
/// match becomes an [UnresolvedFragment] — a tappable chip — and **never** a
/// guessed food or an invented gram figure. That is enforced structurally: the
/// only way to build a [ParsedItem] is from a [Food] and one of its own
/// [FoodSize]s, so there is no constructor that could accept a number somebody
/// made up.
///
/// ## Why a chip and not a best guess
///
/// A wrong guess in a food log is silent. She sees a plausible dish, taps Log,
/// and her day's numbers are wrong in a way nothing will ever surface. An
/// unresolved chip is visible, costs one tap, and is honest about what the
/// product does not know.
library;

import 'package:meta/meta.dart';

import 'food_library.dart';

/// A fragment the parser matched to a real food.
@immutable
class ParsedItem {
  const ParsedItem({
    required this.food,
    required this.size,
    required this.servings,
    required this.sourceText,
  });

  final Food food;

  /// One of [Food.sizes] — never a free number.
  final FoodSize size;

  /// How many of that size. Whole servings; a half portion is a *size*, not a
  /// fraction of one.
  final int servings;

  /// The words she actually typed or said, kept so the row can show what it
  /// matched. A misread is only visible if the input is still visible.
  final String sourceText;

  int get kcal => size.kcal * servings;
  int get proteinG => size.proteinG * servings;

  /// Null when the size does not carry the figure.
  int? get carbsG => _times(size.carbsG);
  int? get fatG => _times(size.fatG);
  int? get fiberG => _times(size.fiberG);

  int? _times(int? perServing) =>
      perServing == null ? null : perServing * servings;

  ParsedItem withSize(FoodSize next) => ParsedItem(
    food: food,
    size: next,
    servings: servings,
    sourceText: sourceText,
  );

  @override
  String toString() => 'ParsedItem(${food.foodId} ×$servings ${size.id})';
}

/// A fragment that matched nothing in the pack.
@immutable
class UnresolvedFragment {
  const UnresolvedFragment(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is UnresolvedFragment && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'UnresolvedFragment("$text")';
}

/// What one sentence produced.
@immutable
class MealSentenceParse {
  const MealSentenceParse({required this.items, required this.unresolved});

  static const MealSentenceParse empty = MealSentenceParse(
    items: <ParsedItem>[],
    unresolved: <UnresolvedFragment>[],
  );

  final List<ParsedItem> items;
  final List<UnresolvedFragment> unresolved;

  bool get isEmpty => items.isEmpty && unresolved.isEmpty;

  /// Totals for the footer button — "Log both · 696 kcal".
  int get kcal => items.fold(0, (sum, item) => sum + item.kcal);
  int get proteinG => items.fold(0, (sum, item) => sum + item.proteinG);

  /// Replaces the size on one row. E02's sizes are chips **on the row**, so she
  /// never opens a food to fix one.
  MealSentenceParse withSizeAt(int index, FoodSize size) {
    if (index < 0 || index >= items.length) return this;
    final next = [...items];
    next[index] = next[index].withSize(size);
    return MealSentenceParse(items: next, unresolved: unresolved);
  }

  /// Removes one row — the `remove` button on E02's parsed card.
  MealSentenceParse withoutAt(int index) {
    if (index < 0 || index >= items.length) return this;
    final next = [...items]..removeAt(index);
    return MealSentenceParse(items: next, unresolved: unresolved);
  }
}

/// Turns a sentence into items, against the local pack only.
class MealSentenceParser {
  const MealSentenceParser(this.library);

  final FoodLibrary library;

  /// Splits on the connectors a woman actually types, in both languages.
  ///
  /// **Not written with `\b`.** Dart's word boundary is defined over
  /// `[A-Za-z0-9_]`, so no Arabic letter is a "word character" and `\bو\b` sits
  /// between two non-word characters and never matches. Written that way, every
  /// Arabic sentence resolved to a single fragment — the whole feature silently
  /// broken in one of the two languages this product ships, with the English
  /// tests still green.
  ///
  /// So punctuation is matched on its own, and the word-like connectors are
  /// required to stand between whitespace, which is true in both scripts.
  static final RegExp _connectors = RegExp(
    r'\s*[,،+]\s*|\s+(?:and|with|و|مع)\s+',
    caseSensitive: false,
  );

  /// Latin and Arabic-Indic digits, plus the small words that mean a number.
  static final RegExp _leadingQuantity = RegExp(r'^\s*(\d+|[٠-٩]+)\s*');

  static const Map<String, int> _spelledNumbers = <String, int>{
    'a': 1,
    'an': 1,
    'one': 1,
    'two': 2,
    'three': 3,
    'واحد': 1,
    'واحدة': 1,
    'اثنين': 2,
    'بيضتين': 2,
    'ثلاثة': 3,
    'ثلاث': 3,
  };

  /// Parses [sentence] into resolved items and unresolved chips.
  MealSentenceParse parse(String sentence) {
    final trimmed = sentence.trim();
    if (trimmed.isEmpty) return MealSentenceParse.empty;

    // A dish whose own name contains a connector is matched whole first, so
    // "Molokhia with chicken" is one dish rather than molokhia plus an
    // unresolved "chicken".
    final whole = library.exact(trimmed);
    if (whole != null) {
      return MealSentenceParse(
        items: [
          ParsedItem(
            food: whole,
            size: whole.defaultSize,
            servings: 1,
            sourceText: trimmed,
          ),
        ],
        unresolved: const <UnresolvedFragment>[],
      );
    }

    final items = <ParsedItem>[];
    final unresolved = <UnresolvedFragment>[];

    for (final raw in trimmed.split(_connectors)) {
      final fragment = raw.trim();
      if (fragment.isEmpty) continue;

      final (quantity, remainder) = _splitQuantity(fragment);
      final needle = remainder.isEmpty ? fragment : remainder;

      final matches = library.resolve(needle);
      if (matches.isEmpty) {
        unresolved.add(UnresolvedFragment(fragment));
        continue;
      }

      final food = matches.first;
      items.add(
        ParsedItem(
          food: food,
          size: _sizeFor(food, quantity),
          // A count that selected a size ("2 eggs" → the "2" size) is not also a
          // multiplier, or two eggs would be logged as four.
          servings: _sizeIsCount(food, quantity) ? 1 : (quantity ?? 1),
          sourceText: fragment,
        ),
      );
    }

    return MealSentenceParse(items: items, unresolved: unresolved);
  }

  /// A leading number, and what is left of the fragment.
  (int?, String) _splitQuantity(String fragment) {
    final match = _leadingQuantity.firstMatch(fragment);
    if (match != null) {
      final digits = _westernise(match.group(1)!);
      final value = int.tryParse(digits);
      if (value != null) {
        return (value, fragment.substring(match.end).trim());
      }
    }

    // "two boiled eggs", "بيضتين".
    final words = fragment.split(RegExp(r'\s+'));
    if (words.isNotEmpty) {
      final spelled = _spelledNumbers[words.first.toLowerCase()];
      if (spelled != null) {
        return (spelled, words.skip(1).join(' ').trim());
      }
      // The Arabic dual is one word: "بيضتين" is both the number and the food.
      final dual = _spelledNumbers[fragment.trim()];
      if (dual != null) return (dual, fragment);
    }

    return (null, fragment);
  }

  /// True when this food's sizes are counts and [quantity] names one of them.
  bool _sizeIsCount(Food food, int? quantity) =>
      quantity != null && food.sizeById('$quantity') != null;

  /// The size a quantity selects, or the one she usually serves.
  ///
  /// Never invents a size: if the number does not name one of this food's own
  /// sizes, the default is used and the number becomes a serving count. Both
  /// come from `sizes[]`, so there is no path to a gram figure nobody authored.
  FoodSize _sizeFor(Food food, int? quantity) {
    if (quantity != null) {
      final counted = food.sizeById('$quantity');
      if (counted != null) return counted;
    }
    return food.defaultSize;
  }

  /// Arabic-Indic digits to Western ones.
  ///
  /// Only for *reading* her input — every number this product renders stays
  /// Western, per `P0-A11Y-01` and the rule `weightLabel()` documents.
  static String _westernise(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.write(rune - 0x0660);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}
