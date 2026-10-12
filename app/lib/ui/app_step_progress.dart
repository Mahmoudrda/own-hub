/// Where a woman is in a multi-step flow — "Step 2 of 4".
///
/// In `6-v2/src/screens-onboarding.mjs` the step counter is the **app bar
/// title**, not a bar drawn across the screen: `appBar({ title: 'Step 2 of 4' })`.
/// The prototype's `linear()` progress track exists in the kit but the setup
/// flow deliberately does not use it, and adding one here would be a design
/// change smuggled in as a primitive.
///
/// So the primitive is the part that would otherwise be copied onto four
/// screens: resolving `(step, total)` to the right dictionary entry. Every step
/// counter is a **separate translated string**, not a template — the Arabic
/// entry is already written out in full in the dictionary — so there is no
/// formatting to do here and no place a screen could invent one.
///
/// The counters keep Western numerals in both languages (`P0-A11Y-01`), which is
/// a property of the dictionary and is asserted by the screen tests rather than
/// assumed here.
library;

import '../l10n/app_l10n.dart';

/// The label for step [step] of [total].
///
/// Throws [ArgumentError] when the dictionary has no entry for that pair rather
/// than falling back to a built string: a hand-built "Step 3 of 7" would be
/// English in an Arabic build, which is exactly the failure the localisation
/// guard exists to catch.
String stepOfLabel(AppL10n l10n, {required int step, required int total}) {
  if (total == 4) {
    switch (step) {
      case 1:
        return l10n.step1Of4;
      case 2:
        return l10n.step2Of4;
      case 3:
        return l10n.step3Of4;
      case 4:
        return l10n.step4Of4;
    }
  }
  throw ArgumentError(
    'No dictionary entry for step $step of $total. Add the string to the ARB '
    'files and extend stepOfLabel; never build the counter from parts.',
  );
}

/// The three parts of joining, in the order she meets them.
///
/// One count for the whole of sign-up, replacing "Step 1 of 2" on the number
/// and "Step 2 of 2" on the code, which promised the end two screens before a
/// role, a consent, three camera passes and a wait.
enum SignupPhase {
  /// Her week: the setup screens before she has an account.
  week,

  /// Her number and the code sent to it.
  number,

  /// The one identity check.
  check,
}

/// The bar title for [phase]. Whole dictionary strings, Western digits in both
/// languages, for the same reason [stepOfLabel] never builds a counter.
String signupPhaseLabel(AppL10n l10n, SignupPhase phase) => switch (phase) {
  SignupPhase.week => l10n.n1Of3YourWeek,
  SignupPhase.number => l10n.n2Of3YourNumber,
  SignupPhase.check => l10n.n3Of3QuickCheck,
};
