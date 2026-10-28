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
import 'units.dart';

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

/// The most one sentence may hold. A longer one is not a meal, it is a
/// ramble, and parsing it would only produce rows nobody asked for.
const int kMaxSentenceLength = 400;

/// The most fragments of one sentence that are read; the rest come back as one
/// chip, never dropped.
const int kMaxSentenceFragments = 12;

/// The most of one food she may log in one go, and the most energy one row may
/// carry. A number past either is a misheard word ("999 eggs"), so it becomes
/// a chip with her words in it instead of a row of 155,844 kcal.
const int kMaxServings = 20;
const int kMaxRowKcal = 3000;

enum _Unit { grams, kilograms, ounces, millilitres, cup, spoon, piece }

/// The items a fragment named and the words of it that named nothing.
class _Found {
  const _Found(this.items, this.chips);

  final List<ParsedItem> items;
  final List<String> chips;
}

/// What the front of a fragment said about how much.
class _Quantity {
  const _Quantity({
    this.amount,
    this.unit,
    this.size,
    this.raw = false,
    this.invalid = false,
    this.rest = '',
  });

  /// "3", "2.5", "half", "اتنين". Null when she gave no number.
  final double? amount;
  final _Unit? unit;

  /// 'S' or 'L' when she said small or large.
  final String? size;

  /// She said raw or dry, so a food weighed that way may be offered.
  final bool raw;

  /// A number that cannot be a quantity: zero or below.
  final bool invalid;

  /// The words that are left, which should name a food.
  final String rest;
}

/// Turns a sentence into items, against the local pack only.
class MealSentenceParser {
  const MealSentenceParser(this.library, {this.fromSpeech = false});

  final FoodLibrary library;

  /// A sentence that was spoken. A spoken sentence is only ever matched to a
  /// food she named in full: there is no half-typed word to complete, and a
  /// recogniser's near miss must become a chip she can fix, not a food.
  final bool fromSpeech;

  /// Splits on the connectors a woman actually types, in both languages,
  /// keeping each one so a dish whose own name holds one can be put back
  /// together ("Molokhia with chicken").
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
    r'(\s*[,،+;؛:]\s*|\s+(?:and|with|plus|w|و|مع)\s+)',
    caseSensitive: false,
  );

  static final RegExp _hiddenMarks = RegExp(
    r'[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]',
  );

  /// A number, with an optional sign, Arabic-Indic digits, a decimal part and a
  /// unit stuck to it ("200g"). "3eesh" (Franco for a word) and "1e9" do not
  /// match, so they stay words.
  static final RegExp _number = RegExp(
    r'^([-+]?)([0-9٠-٩]+(?:[.,٫][0-9٠-٩]+)?)(\p{L}*)$',
    unicode: true,
  );

  static const Map<String, double> _numberWords = <String, double>{
    'a': 1,
    'an': 1,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'half': 0.5,
    'quarter': 0.25,
    'واحد': 1,
    'واحده': 1,
    'اتنين': 2,
    'اثنين': 2,
    'اثنان': 2,
    'تنين': 2,
    'تلاته': 3,
    'ثلاثه': 3,
    'تلات': 3,
    'ثلاث': 3,
    'اربعه': 4,
    'اربع': 4,
    'خمسه': 5,
    'خمس': 5,
    'سته': 6,
    'ست': 6,
    'سبعه': 7,
    'سبع': 7,
    'تمانيه': 8,
    'ثمانيه': 8,
    'تمن': 8,
    'ثمان': 8,
    'تسعه': 9,
    'تسع': 9,
    'عشره': 10,
    'عشر': 10,
    'نص': 0.5,
    'نصف': 0.5,
    'ربع': 0.25,
  };

  /// The Arabic dual is one word that is both "two" and the thing:
  /// "بيضتين" is two eggs. Each maps to the single noun it counts.
  static const Map<String, String> _duals = <String, String>{
    'بيضتين': 'بيضه',
    'موزتين': 'موزه',
    'تفاحتين': 'تفاحه',
    'برتقالتين': 'برتقاله',
    'جوافتين': 'جوافه',
    'خيارتين': 'خياره',
    'طماطمتين': 'طماطمه',
    'تمرتين': 'تمره',
    'رغيفين': 'رغيف',
    'كوبين': 'كوب',
    'كوبايتين': 'كوبايه',
    'كبايتين': 'كبايه',
    'طبقين': 'طبق',
    'حتتين': 'حته',
    'قطعتين': 'قطعه',
    'شريحتين': 'شريحه',
    'حبتين': 'حبه',
  };

  static const Map<String, _Unit> _units = <String, _Unit>{
    'g': _Unit.grams,
    'gm': _Unit.grams,
    'gms': _Unit.grams,
    'gram': _Unit.grams,
    'grams': _Unit.grams,
    'جم': _Unit.grams,
    'جرام': _Unit.grams,
    'غرام': _Unit.grams,
    'غم': _Unit.grams,
    'kg': _Unit.kilograms,
    'kgs': _Unit.kilograms,
    'kilo': _Unit.kilograms,
    'kilos': _Unit.kilograms,
    'kilogram': _Unit.kilograms,
    'كيلو': _Unit.kilograms,
    'كجم': _Unit.kilograms,
    'كغم': _Unit.kilograms,
    'oz': _Unit.ounces,
    'ounce': _Unit.ounces,
    'ounces': _Unit.ounces,
    'ml': _Unit.millilitres,
    'مل': _Unit.millilitres,
    'ملل': _Unit.millilitres,
    'cup': _Unit.cup,
    'cups': _Unit.cup,
    'glass': _Unit.cup,
    'glasses': _Unit.cup,
    'كوب': _Unit.cup,
    'اكواب': _Unit.cup,
    'كوبايه': _Unit.cup,
    'كوبايات': _Unit.cup,
    'كبايه': _Unit.cup,
    'كبايات': _Unit.cup,
    'كاسه': _Unit.cup,
    'كاس': _Unit.cup,
    'tbsp': _Unit.spoon,
    'tsp': _Unit.spoon,
    'tablespoon': _Unit.spoon,
    'tablespoons': _Unit.spoon,
    'teaspoon': _Unit.spoon,
    'teaspoons': _Unit.spoon,
    'spoon': _Unit.spoon,
    'spoons': _Unit.spoon,
    'معلقه': _Unit.spoon,
    'ملعقه': _Unit.spoon,
    'معالق': _Unit.spoon,
    'ملاعق': _Unit.spoon,
    'piece': _Unit.piece,
    'pieces': _Unit.piece,
    'slice': _Unit.piece,
    'slices': _Unit.piece,
    'pc': _Unit.piece,
    'pcs': _Unit.piece,
    'plate': _Unit.piece,
    'plates': _Unit.piece,
    'bowl': _Unit.piece,
    'bowls': _Unit.piece,
    'serving': _Unit.piece,
    'servings': _Unit.piece,
    'portion': _Unit.piece,
    'portions': _Unit.piece,
    'حته': _Unit.piece,
    'حتت': _Unit.piece,
    'قطعه': _Unit.piece,
    'قطع': _Unit.piece,
    'حبه': _Unit.piece,
    'حبات': _Unit.piece,
    'رغيف': _Unit.piece,
    'ارغفه': _Unit.piece,
    'شريحه': _Unit.piece,
    'شرايح': _Unit.piece,
    'طبق': _Unit.piece,
    'اطباق': _Unit.piece,
    'صحن': _Unit.piece,
    'وجبه': _Unit.piece,
    'وجبات': _Unit.piece,
  };

  static const Set<String> _smallWords = {
    'small',
    'little',
    'mini',
    'صغير',
    'صغيره',
  };
  static const Set<String> _largeWords = {'large', 'big', 'كبير', 'كبيره'};
  static const Set<String> _mediumWords = {
    'medium',
    'regular',
    'وسط',
    'متوسط',
    'متوسطه',
  };
  static const Set<String> _rawWords = {
    'raw',
    'dry',
    'dried',
    'uncooked',
    'نيء',
    'ني',
    'نيه',
    'ناشف',
    'ناشفه',
    'خام',
  };

  /// Hesitation sounds a recogniser writes down. They are not food and not a
  /// miss, so they are dropped rather than shown as chips.
  static final RegExp _noise = RegExp(
    r'^(?:u+[hm]+|h*m+|a+h+|e+h+|o+h*|ok|okay|so|then|also|and|with|plus|w|و|مع|اه+|ا+م{2,}|ه+م{2,}|كده|يعني|طيب)$',
  );

  /// A meal word at the start of a sentence ("Breakfast: ful") is not a food.
  static final RegExp _leadingSlot = RegExp(
    r'^(?:for\s+)?(?:breakfast|lunch|dinner|snack|فطار|فطور|غدا|غداء|عشا|عشاء|سناك)\s*[:：-]?\s+',
    caseSensitive: false,
  );

  static final RegExp _leadingConnector = RegExp(
    r'^(?:and|with|plus|w|و|مع)\s+',
    caseSensitive: false,
  );

  static final RegExp _leadingVerb = RegExp(
    r'^(?:i\s+(?:just\s+|only\s+)?(?:had|ate)|i\s+have\s+had|had|ate|اكلت|أكلت|كلت|فطرت|اتغديت|اتعشيت)\s+',
    caseSensitive: false,
  );

  /// Parses [sentence] into resolved items and unresolved chips.
  MealSentenceParse parse(String sentence) {
    var text = sentence.replaceAll(_hiddenMarks, '').trim();
    if (FoodLibrary.normalise(text).isEmpty) return MealSentenceParse.empty;
    if (text.length > kMaxSentenceLength) {
      return MealSentenceParse(
        items: const <ParsedItem>[],
        unresolved: [UnresolvedFragment(text.substring(0, 60))],
      );
    }

    final raw = _says(text, _rawWords);
    if (library.named(text, allowRaw: raw).isEmpty) {
      text = text
          .replaceFirst(_leadingSlot, '')
          .replaceFirst(_leadingVerb, '')
          .replaceFirst(_leadingConnector, '');
    }

    // A dish whose own name contains a connector is matched whole first, so
    // "Molokhia with chicken" is one dish rather than molokhia plus an
    // unresolved "chicken". Without a connector the fragment path reads the
    // quantity and size words that a whole-name match would swallow.
    if (_connectors.hasMatch(text)) {
      final whole = library.named(text, allowRaw: raw);
      if (whole.isNotEmpty) {
        return MealSentenceParse(
          items: [
            ParsedItem(
              food: whole.first,
              size: whole.first.defaultSize,
              servings: 1,
              sourceText: text,
            ),
          ],
          unresolved: const <UnresolvedFragment>[],
        );
      }
    }

    // Pieces and the connector that stood before each.
    final pieces = <String>[];
    final joiners = <String>[];
    var from = 0;
    for (final match in _connectors.allMatches(text)) {
      pieces.add(text.substring(from, match.start));
      joiners.add(match.group(0)!);
      from = match.end;
    }
    pieces.add(text.substring(from));
    final single = pieces.length == 1;

    final items = <ParsedItem>[];
    final unresolved = <UnresolvedFragment>[];
    var i = 0;
    var read = 0;
    while (i < pieces.length) {
      if (read == kMaxSentenceFragments) {
        final rest = text.substring(
          text.length - pieces.sublist(i).join(' ').length,
        );
        unresolved.add(UnresolvedFragment(_clip(rest)));
        break;
      }
      read++;

      // The longest run of pieces that is one dish, then one piece alone.
      var matched = false;
      for (var width = 3; width >= 1 && !matched; width--) {
        if (i + width > pieces.length) continue;
        final span = StringBuffer(pieces[i]);
        for (var k = 1; k < width; k++) {
          span
            ..write(joiners[i + k - 1])
            ..write(pieces[i + k]);
        }
        final found = _items(span.toString(), single: single, whole: width > 1);
        if (found != null && (width == 1 || found.chips.isEmpty)) {
          items.addAll(found.items);
          unresolved.addAll([
            for (final c in found.chips) UnresolvedFragment(c),
          ]);
          i += width;
          matched = true;
        }
      }
      if (matched) continue;

      final fragment = pieces[i].trim();
      if (FoodLibrary.normalise(fragment).isNotEmpty && !_isNoise(fragment)) {
        unresolved.add(UnresolvedFragment(fragment));
      }
      i++;
    }

    return MealSentenceParse(items: items, unresolved: unresolved);
  }

  /// True when any word of [text] is one of [words].
  static bool _says(String text, Set<String> words) =>
      FoodLibrary.normalise(text).split(' ').any(words.contains);

  static String _clip(String text) {
    final t = text.trim();
    return t.length > 60 ? t.substring(0, 60) : t;
  }

  bool _isNoise(String fragment) {
    final words = FoodLibrary.normalise(fragment).split(' ');
    return words.every(_noise.hasMatch);
  }

  /// What one fragment names, or null when it names nothing. More than one
  /// item only when a "و" was stuck to the next word ("فول وعيش"); the words on
  /// the side that named nothing come back as chips.
  _Found? _items(String fragment, {required bool single, required bool whole}) {
    final text = fragment.trim();
    if (text.isEmpty) return null;
    if (_isNoise(text)) return const _Found(<ParsedItem>[], <String>[]);

    final one = _item(text, partial: false);
    if (one != null) return _Found([one], const <String>[]);

    // "وعيش": the waw is a word, written stuck to the next one. Tried only
    // when the fragment as written named nothing, so "ورق عنب" stays whole.
    if (!whole) {
      final words = text.split(RegExp(r'\s+'));
      for (var w = 0; w < words.length; w++) {
        final word = words[w];
        if (word.length < 3 || !word.startsWith('و')) continue;
        final left = words.sublist(0, w).join(' ');
        final right = [word.substring(1), ...words.skip(w + 1)].join(' ');
        final a = left.isEmpty
            ? const _Found(<ParsedItem>[], <String>[])
            : _items(left, single: false, whole: true);
        final b = _items(right, single: false, whole: false);
        if (a == null && b == null) continue;
        final items = [...?a?.items, ...?b?.items];
        if (items.isEmpty) continue;
        return _Found(items, [
          ...?a?.chips,
          if (a == null && left.isNotEmpty) left,
          ...?b?.chips,
          if (b == null) right,
        ]);
      }
    }

    // A lone half-typed word ("kosh") is completed from the pack, the way the
    // search list under the box does. Never for speech, and never inside a
    // longer sentence, where every word was finished.
    if (single && !fromSpeech) {
      final partial = _item(text, partial: true);
      if (partial != null) return _Found([partial], const <String>[]);
    }
    return null;
  }

  ParsedItem? _item(String fragment, {required bool partial}) {
    // Her words are a food's own name, spelled as the pack spells it ("طبق
    // شاورما فراخ" is the plate, not a sandwich with "plate" read as a unit).
    final named = library
        .named(
          fragment,
          allowRaw: _says(fragment, _rawWords),
          spelledOnly: true,
        )
        .firstOrNull;
    if (named != null) {
      return ParsedItem(
        food: named,
        size: named.defaultSize,
        servings: 1,
        sourceText: fragment,
      );
    }
    final q = _readQuantity(fragment);
    if (q.invalid || q.rest.isEmpty) return null;

    Food? food;
    if (partial) {
      // Only a bare word: "250 g of kosh" is a weight of something she did not
      // finish naming.
      if (q.amount != null || q.unit != null) return null;
      final needle = FoodLibrary.normalise(q.rest);
      if (needle.length < 3) return null;
      // Her letters must begin the name the food is shown under, and begin
      // exactly one food's. A word in the middle of a name ("juice" in
      // "hibiscus juice"), or one that fits several foods, is not a choice the
      // app may make for her: it stays a chip, and the list below the box
      // offers them.
      final starts = library.resolve(q.rest).where((f) {
        if (!q.raw && f.isCookedFirst) return false;
        return f.names
            .take(2)
            .any((n) => FoodLibrary.normalise(n).startsWith(needle));
      }).toList();
      if (starts.length == 1) food = starts.first;
    } else {
      food = library.named(q.rest, allowRaw: q.raw).firstOrNull;
    }
    if (food == null) return null;
    return _build(food, q, fragment);
  }

  /// Reads "2 eggs", "200 g rice", "half a loaf", "كوباية شاي", "large koshari".
  _Quantity _readQuantity(String fragment) {
    final tokens = [
      for (final t in fragment.split(RegExp(r'\s+')))
        if (t.isNotEmpty) t,
    ];
    double? amount;
    _Unit? unit;
    var i = 0;

    String norm(int at) => FoodLibrary.normalise(tokens[at]);

    if (tokens.isNotEmpty) {
      final match = _number.firstMatch(tokens[0]);
      final word = norm(0);
      if (match != null) {
        final suffix = match.group(3)!.toLowerCase();
        final stuck = suffix.isEmpty ? null : _units[suffix];
        if (suffix.isEmpty || stuck != null) {
          final value = double.tryParse(
            _westernise(match.group(2)!).replaceAll(RegExp('[,٫]'), '.'),
          );
          if (match.group(1) == '-' || value == null || value <= 0) {
            return const _Quantity(invalid: true);
          }
          amount = value;
          unit = stuck;
          i = 1;
        }
      } else if (_duals.containsKey(word)) {
        amount = 2;
        tokens[0] = _duals[word]!;
      } else if (_numberWords.containsKey(word) &&
          // "a" and "ست" are only numbers when something follows them.
          tokens.length > 1) {
        amount = _numberWords[word];
        i = 1;
        // "half a loaf", "نص رغيف"
        if (i < tokens.length && const {'a', 'an', 'of'}.contains(norm(i))) i++;
      }
    }

    // The unit, with its own noun ("200 g rice") or the dual's ("كوبين شاي").
    if (unit == null && i < tokens.length) {
      final u = _units[norm(i)];
      if (u != null) {
        unit = u;
        i++;
        if (i < tokens.length && const {'of', 'من'}.contains(norm(i))) i++;
      }
    }

    String? size;
    var raw = false;
    final rest = <String>[];
    for (var k = i; k < tokens.length; k++) {
      final w = norm(k);
      if (w.isEmpty || _noise.hasMatch(w)) continue;
      if (_smallWords.contains(w)) {
        size = 'S';
      } else if (_largeWords.contains(w)) {
        size = 'L';
      } else if (_mediumWords.contains(w)) {
        size = 'M';
      } else {
        if (_rawWords.contains(w)) raw = true;
        rest.add(tokens[k]);
      }
    }

    // "a" alone, or a number alone, names no food.
    return _Quantity(
      amount: amount,
      unit: unit,
      size: size,
      raw: raw,
      rest: rest.join(' '),
    );
  }

  ParsedItem? _build(Food food, _Quantity q, String source) {
    final amount = q.amount;
    FoodSize? size;
    var servings = 1;

    switch (q.unit) {
      case _Unit.spoon:
        // The pack has no weight for a spoonful of anything, and none is made up.
        return null;
      case _Unit.grams || _Unit.kilograms || _Unit.ounces || _Unit.millilitres:
        final unit = switch (q.unit!) {
          _Unit.ounces => FoodUnit.oz,
          _Unit.millilitres => FoodUnit.ml,
          _ => FoodUnit.g,
        };
        final factor = q.unit == _Unit.kilograms ? 1000 : 1;
        size = FoodUnits.sizeFor(food, unit, (amount ?? 1) * factor);
        if (size == null) return null;
      case _Unit.cup:
        size = FoodUnits.sizeFor(food, FoodUnit.cup, amount ?? 1);
        if (size == null) return null;
      case _Unit.piece || null:
        final base =
            (q.size == null ? null : food.sizeById(q.size!)) ??
            food.defaultSize;
        if (amount == null) {
          size = base;
        } else if (_countsAreSizes(food)) {
          // Eggs, here, come as 1, 2 and 3: two eggs is the "2" size, and
          // four is four of the "1" size, never four of the size of two.
          if (amount % 1 != 0) return null;
          final count = amount.toInt();
          final named = food.sizeById('$count');
          final one = food.sizeById('1');
          if (named != null) {
            size = named;
          } else if (one != null && count <= kMaxServings) {
            size = one;
            servings = count;
          } else {
            return null;
          }
        } else {
          final pieces = food.mediumPieces;
          if (amount % pieces == 0) {
            size = base;
            servings = amount ~/ pieces;
          } else {
            // Three eggs of a two-egg size, half a loaf: the weight of what
            // she said, from the food's own weighed size. A food with no
            // weight has no half.
            final medium = food.weighedSize?.grams;
            if (medium == null) return null;
            size = food.sizeForGrams((medium * amount / pieces).round());
            if (size == null) return null;
          }
        }
    }

    if (servings < 1 || servings > kMaxServings) return null;
    final item = ParsedItem(
      food: food,
      size: size,
      servings: servings,
      sourceText: source,
    );
    return item.kcal > kMaxRowKcal ? null : item;
  }

  /// True when the food's sizes are counts (1, 2, 3) rather than S, M, L.
  bool _countsAreSizes(Food food) =>
      food.sizes.isNotEmpty &&
      food.sizes.every((s) => int.tryParse(s.id) != null);

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

/// Words that only link one ingredient phrase to the next.
const _recipeConnectors = {
  'على',
  'عليها',
  'عليهم',
  'عليه',
  'او',
  'أو',
  'مع',
  'من',
  'في',
  'ب',
};

/// The words of [text] left once every one of [phrases] is taken out of it,
/// without bare "and"s, digits and connectors. A step with none left is only
/// ingredients, and has no method in it.
List<String> arabicMethodWords(String text, Iterable<String> phrases) {
  final all = <String>{
    for (final p in phrases) ...[p, ...p.split('\n').map((l) => l.trim())],
  }..remove('');
  final longestFirst = all.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  var rest = text;
  for (final phrase in longestFirst) {
    rest = rest.replaceAll(phrase, ' ');
  }
  final out = <String>[];
  for (var token in rest.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))) {
    if (token.length > 1) token = token.replaceFirst(RegExp('^و+'), '');
    if (token.isEmpty || token == 'و') continue;
    if (RegExp(r'^\p{N}+$', unicode: true).hasMatch(token)) continue;
    if (_recipeConnectors.contains(token)) continue;
    out.add(token);
  }
  return out;
}
