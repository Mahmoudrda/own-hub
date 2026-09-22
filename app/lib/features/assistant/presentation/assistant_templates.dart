/// The complete catalogue of sentences the assistant is allowed to say.
///
/// G15 §10 Q6 settles the trade this file implements: the response schema
/// carries an `answerKey` — an enum of dictionary template keys — and **no
/// free-text field at all**. A `note` field is where an invented quantity or an
/// un-localised English sentence would re-enter, and "structured outputs cannot
/// express `pattern` or `maxLength`, so a prose guard must be a server-side
/// regex, which is weaker than not having the field".
///
/// So every sentence the feature can put on screen is resolved here, from a
/// closed enum, through `AppL10n`. A model that wanted to say something else has
/// no key to say it with.
///
/// ## Why one template can still be withheld
///
/// [assistantAnswerTemplate] returns `String?`, and null renders nothing.
///
/// `twoMovesInYourSessionWorkThe` — *"Two moves in your session work the same
/// muscles without loading the knee"* — states a count. It is the mockup's
/// count, and `baked_in_samples_test.dart` exists because this product has
/// repeatedly told a woman the prototype's number as though it were hers. The
/// dictionary has no parameterised form of this sentence, and `lib/l10n/**` is
/// not this feature's to edit, so it takes the third of
/// `stated_figure.dart`'s three options: **render it only to the woman it is
/// true of**. Two surviving picks get the sentence; one or three get the rows
/// and no sentence, which says less rather than something untrue.
///
/// A grep for `statedLine` is the live list of outstanding dictionary work, and
/// this is one more entry on it.
///
/// ## The key the dictionary now carries
///
/// `AnswerKey.nothingFound` is the state `P0-ASK-02` cares most about — *"It
/// returns nothing and says so"* — and for a long time no string in either ARB
/// said so, so the screen had a state and no sentence for it. That gap was
/// recorded in [kAnswerKeysWithNoDictionaryLine] rather than filled in with
/// hardcoded English, which would have bypassed the dictionary and shown
/// English in the Arabic build.
///
/// `nothingFoundForThatIWouldRather` — *"Nothing found for that. I would rather
/// say so than guess."* — has since been minted, so the state says so in her
/// language and the set is empty. It is kept, empty, because the test below
/// asserts the set against what actually resolves: the next withheld key has
/// somewhere to be recorded, and an empty set is the honest reading today.
library;

import '../../../domain/rewards/stated_figure.dart';
import '../../../l10n/app_l10n.dart';
import '../domain/assistant_wire.dart';

/// Answer keys the dictionary has no line for. See the library note.
///
/// This is a gap in the content, recorded where the code is rather than in a
/// document nobody re-reads. When the string is minted, remove the entry — the
/// test below fails if the set stops matching what actually resolves.
///
/// **Empty today.** `AnswerKey.nothingFound` was the one entry, and its
/// sentence has been minted.
const Set<AnswerKey> kAnswerKeysWithNoDictionaryLine = <AnswerKey>{};

/// The sentence for [key], or null when there is none to show.
///
/// [rowCount] is how many picks actually survived validation and resolved
/// against the pack — the real number on screen, not the model's idea of it.
String? assistantAnswerTemplate(
  AppL10n l10n,
  AnswerKey key, {
  required int rowCount,
}) => switch (key) {
  // Withheld unless the count it states is hers. See the library note.
  AnswerKey.groundedAlternatives => statedLine(
    l10n.twoMovesInYourSessionWorkThe,
    states: 2,
    hers: rowCount,
  ),
  AnswerKey.swapChangesTodayOnly => l10n.swappingChangesTodayOnlyYourPlanFrom,
  // "Nothing found for that. I would rather say so than guess." The state
  // P0-ASK-02 cares most about finally has the sentence that says so, and it
  // names no move because there is none to name.
  AnswerKey.nothingFound => l10n.nothingFoundForThatIWouldRather,
};
