/// How this product renders a sentence whose number is baked into the string.
///
/// ## The defect this exists to make impossible
///
/// `PHASE1-FIXES.md` records the same defect five times, and `PHASE1-QA-VERDICT`
/// calls the fifth occurrence the blocking one: a screen states the prototype's
/// sample number as a fact about *her*. C13 told every woman her check took "74
/// seconds". R07's button named the mockup's set. T01 read "This week, 0 of 3"
/// to a woman whose goal was four. T04 says "Your 14 weeks are safe" and T05
/// says "Your 14 counted weeks" — to everyone.
///
/// Where a parameterised message exists, the fix is to use it, and this file has
/// nothing to do with that case. But much of the dictionary ships **fixed
/// strings with the number inside them** — `your14WeeksAreSafe`, `n14Of20`,
/// `level7`, `n1Saved` — and `app_en.arb` carries only thirteen parameterised
/// messages in total. For those, there are exactly three honest options:
///
///   1. Invent a new English string in the widget. Forbidden: it bypasses the
///      dictionary, so the Arabic build shows English and no test notices.
///   2. Render it to everyone. This is the defect.
///   3. **Render it only to the woman it is true of.**
///
/// This file is option 3. [statedLine] returns the sentence when the figure it
/// states really is hers, and null otherwise — and null renders nothing at all.
///
/// It is the generalisation of the fix already made for C13, where
/// `verifiedInSeconds` became nullable and *"null renders a duration-free
/// variant of the same sentence… If we did not measure it, the screen says
/// nothing about it."* A sentence that says less is better than one that says
/// something untrue.
///
/// ## Why this is a stopgap, and says so
///
/// Every call site is a string the dictionary should carry in parameterised
/// form. The build reports each one, and when the key is minted the call site
/// becomes `l10n.someMessage(hers)` and the [statedLine] wrapper is deleted. A
/// grep for this function is therefore a live list of the outstanding
/// dictionary work — which is better than a comment nobody re-reads.
library;

/// The dictionary line, but only when it is true of her.
///
/// [states] is the figure baked into [line]; [hers] is the real one. They are
/// compared with `==`, so this works for a count, a date, or anything else with
/// value equality.
///
/// ```dart
/// // 'Your 14 weeks are safe' — true only for a woman with 14 counted weeks.
/// final safe = statedLine(l10n.your14WeeksAreSafe, states: 14, hers: counted);
/// if (safe != null) Text(safe),
/// ```
String? statedLine<T>(String line, {required T states, required T hers}) =>
    states == hers ? line : null;

/// True when [line] may be shown — the same test as [statedLine], for a widget
/// that needs the condition without the string.
bool statesHerFigure<T>({required T states, required T hers}) => states == hers;
