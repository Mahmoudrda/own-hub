/// E02 — "Type it". The box where search and describing a meal are one thing.
///
/// Holds the parse and the edits she makes to it, with no widget involved. The
/// parser itself is the domain's; this only carries its result and applies the
/// two edits the design allows — change a size, remove a row.
///
/// ## Sizes are chips on the row
///
/// E02's design note: "Sizes are chips on the row, so she never opens a food to
/// fix one." That is why [TypeItViewModel.resize] takes an index into the row
/// list rather than a food id — the edit belongs to the row she is looking at,
/// and a second screen to correct a size would cost more taps than typing the
/// sentence did.
///
/// ## `unresolved` is a first-class part of the result
///
/// A fragment the pack could not match stays visible as a chip. It is never
/// dropped silently and never turned into a guess (§2 rule 10). A dropped
/// fragment would mean she typed something, saw it vanish, and had no idea
/// whether it was logged.
library;

import 'package:meta/meta.dart';

import '../domain/allergy_guard.dart';
import '../domain/food_library.dart';
import '../domain/meal_sentence_parser.dart';

/// What E02 renders.
///
/// Named `TypeItState` rather than `TypeItView` because the *widget* is
/// `TypeItView`. Two classes with one name across the two files a screen is
/// built from is a collision waiting for whoever imports both.
@immutable
class TypeItState {
  const TypeItState({
    required this.text,
    required this.parse,
    required this.history,
  });

  static const TypeItState blank = TypeItState(
    text: '',
    parse: MealSentenceParse.empty,
    history: <ParsedItem>[],
  );

  /// Exactly what she typed, unaltered.
  final String text;

  final MealSentenceParse parse;

  /// "Or one you've had before" — screened plates, offered under the box.
  final List<ParsedItem> history;

  List<ParsedItem> get items => parse.items;
  List<UnresolvedFragment> get unresolved => parse.unresolved;

  /// The footer button's number — "Log both · 696 kcal".
  int get kcal => parse.kcal;
  int get proteinG => parse.proteinG;

  /// A sentence that matched nothing has nothing to log. The button is disabled
  /// rather than absent, so the screen does not reflow while she types.
  bool get canLog => parse.items.isNotEmpty;

  /// True when something she typed could not be matched. The chips are shown
  /// alongside whatever did resolve; one unmatched fragment does not block
  /// logging the rest.
  bool get hasUnresolved => parse.unresolved.isNotEmpty;

  TypeItState _with(MealSentenceParse next) =>
      TypeItState(text: text, parse: next, history: history);
}

/// Parses what she types and applies her edits.
class TypeItViewModel {
  const TypeItViewModel({
    required this.parser,
    required this.guard,
    this.history = const <ParsedItem>[],
  });

  final MealSentenceParser parser;

  /// Screens the **history** row only.
  ///
  /// Deliberately not applied to what she typed. G5 §5.1 separates the two: the
  /// guard filters what the app *offers* her, and a dish she named herself is
  /// handled at the moment of the log by `AllergyGuard.assess`, through
  /// `MealLogService`. Screening her own words here would make a food she can
  /// clearly see in her hand silently unloggable, with no sheet to explain it.
  final AllergyGuard guard;

  /// Plates she has logged before, offered under the box.
  final List<ParsedItem> history;

  TypeItState build(String text) {
    return TypeItState(
      text: text,
      parse: parser.parse(text),
      history: _screenedHistory(),
    );
  }

  /// Swaps the size on one row and recomputes that row only.
  TypeItState resize(TypeItState state, int index, FoodSize size) =>
      state._with(state.parse.withSizeAt(index, size));

  /// Removes one row. The rest of the sentence is untouched.
  TypeItState remove(TypeItState state, int index) =>
      state._with(state.parse.withoutAt(index));

  List<ParsedItem> _screenedHistory() {
    final allowed = guard
        .screen(history.map((entry) => entry.food))
        .map((food) => food.foodId)
        .toSet();
    return history.where((e) => allowed.contains(e.food.foodId)).toList();
  }
}
