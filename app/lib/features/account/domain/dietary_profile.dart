/// The allergy capture surface — `DECISIONS.md` **D3**, and the reason
/// `P0-EAT-01` cannot pass today.
///
/// D3: "Collect what the product needs about her **as soon as possible** … and
/// put every one of those answers behind an edit control in **My Profile**.
/// Applies to: goal, days, session length, place, equipment, **allergies**,
/// **dietary preferences**, life stage."
///
/// **Nothing implemented it.** `DECISIONS.md` records the consequence under
/// "Blocking Phase 2": "No screen anywhere collects allergies, although D3 says
/// they are collected at sign-up and editable in My Profile. Until one exists
/// the guard fails closed for *every* woman."
///
/// # The live hazard this closes
///
/// `AppRouter.eatConstraints` is pinned to `DietaryConstraints.none`, and `none`
/// is not "unknown" — it is a **claim**: *asked, and named nothing*. True of
/// nobody, because nobody was asked. `AllergyGuard.assess()` short-circuits on
/// it (`if (allergies.isEmpty) return AllergyAssessment.clear`).
///
/// Today that is contained, because no food carries allergen data. The hazard is
/// **ordering**, and `test/features/eat/allergy_interlock_test.dart` exists to
/// make it a red build rather than a silent regression: the moment
/// `foods.allergens[]` lands — D12's admin console is the mechanism and it is on
/// the critical path — but *before* a capture screen exists, the guard holds real
/// allergen data plus a fabricated claim that she has no allergies. At that
/// instant it clears a dish containing nuts for a woman with a nut allergy,
/// silently, with no sheet.
///
/// This file is the capture surface that fixes the order.
///
/// # Who writes the field
///
/// `users/{uid}.profile` is **G2's** document (spine §2). G7 Q18 settles the
/// split in one line: "if A02 is chosen, **G7 hosts the row and G2 writes the
/// field** — two groups writing one field is a rejected plan."
///
/// So [DietaryProfileRepository] is a **port**, published by G7 as the contract
/// A02 renders against, and the Firestore implementation belongs to G2 beside
/// `IntakeRepository` — same document, same merge, same "editable forever"
/// guarantee. G7 never writes `profile.allergies` itself; it calls this.
///
/// # The vocabulary is authored, not invented
///
/// The two dietary answers are exactly the ones the prototype authors on `G17` —
/// which its own design note calls "the only place in the product where a client
/// states her allergies". Nothing here adds a *category* the content team has not
/// written, because a plausible-looking allergen list is precisely the fabricated
/// safety guarantee this feature exists to avoid.
///
/// The allergen list grew from four to sixteen when Rahma's recipe book was
/// authored: see [AllergenTag], which records where each of the sixteen comes
/// from and why folding any of them together would be worse than carrying it.
library;

import 'package:meta/meta.dart';

import '../../eat/domain/allergy_guard.dart';

/// What she can tell us she cannot eat.
///
/// ## Why sixteen, and where they come from
///
/// The **EU/UK 14** declarable allergens, which are a superset of both Codex STAN
/// 1-1985 and the FDA 9 and therefore map cleanly onto Egyptian labelling, plus
/// two Egypt needs:
///
///   * **`fava`** is not an allergen at all; it is a metabolic
///     contraindication. G6PD deficiency (favism) is common enough in Egypt that
///     `Fool & Ta3mya` — recipe 14 of Rahma's book — needs a flag. It lives in
///     this enum rather than beside the advisories because it is the same *user
///     action*: she ticks a thing she cannot eat. What she does with it is
///     identical; only the biology differs, and the biology is not this type's
///     business.
///   * **`coconut` is its own token** rather than folded into [treeNuts],
///     because the FDA calls coconut a tree nut and the EU does not. Folding it
///     produces either a false positive for every woman with a nut allergy — she
///     loses `Coconut apple Pudding`, recipe 4, for no reason — or a false
///     negative for the one woman who actually reacts to coconut. Two tokens
///     cost one extra chip; one token costs somebody a reaction.
///
/// `lupin` (الترمس) is in the EU 14, is Egyptian street food, and appears
/// nowhere in the book. It is here because the library grows, and because lupin
/// cross-reacts with peanut, so a woman who ticks [peanuts] and later meets a
/// lupin dish needs the tag to exist before the dish does.
///
/// ## Why the four old spellings still work
///
/// The first version of this enum had four members — `nuts`, `dairy`, `gluten`,
/// `shellfish` — and women have already saved profiles using them.
/// [fromWire] therefore accepts all four as **aliases**, because a rename that
/// silently drops a saved declaration is a woman whose nut allergy stops being
/// screened on the day of an app update. `shellfish` is the hard case: it split
/// into [crustaceans] and [molluscs], and one wire token cannot become two enum
/// members, so it maps to [crustaceans] (shrimp and crab, which is what
/// "shellfish" means in practice in Egypt) and [expandAliases] widens it back to
/// both for screening. Narrowing on read and widening on screen is the safe
/// direction.
///
/// [wireName] is what lands in `profile.allergies[]` and what must match
/// `foods.allergens[]` and `Recipe.allergensFinal`. `AllergyGuard` compares case-
/// and whitespace-insensitively, so these are lowercase single tokens by
/// convention rather than by accident.
enum AllergenTag {
  // ------------------------------------------------------------ the EU/UK 14
  gluten('gluten'),
  crustaceans('crustaceans'),
  eggs('eggs'),
  fish('fish'),
  peanuts('peanuts'),
  soy('soy'),
  milk('milk'),
  treeNuts('tree_nuts'),
  celery('celery'),
  mustard('mustard'),
  sesame('sesame'),
  sulphites('sulphites'),
  lupin('lupin'),
  molluscs('molluscs'),

  // ----------------------------------------------------------- and two more
  /// Not an allergen. G6PD deficiency / favism. See the enum's note.
  fava('fava'),

  /// Its own token because the FDA and the EU disagree. See the enum's note.
  coconut('coconut');

  const AllergenTag(this.wireName);

  final String wireName;

  /// The four wire tokens the first version of this enum wrote.
  ///
  /// Read by [fromWire] and asserted **total** by a test: every member of the
  /// old four must still resolve to something, or an already-saved profile
  /// silently loses a declaration.
  static const Map<String, AllergenTag> legacyAliases = <String, AllergenTag>{
    'nuts': AllergenTag.treeNuts,
    'dairy': AllergenTag.milk,
    'gluten': AllergenTag.gluten,
    // "shellfish" covered both classes. One token cannot become two members, so
    // it lands on the one Egyptian kitchens mean by it and [expandAliases]
    // widens it back to molluscs for screening.
    'shellfish': AllergenTag.crustaceans,
  };

  static AllergenTag? fromWire(String wire) {
    final needle = wire.trim().toLowerCase();
    for (final tag in values) {
      if (tag.wireName == needle) return tag;
    }
    return legacyAliases[needle];
  }

  /// The tokens a dish must be screened against, given what she declared.
  ///
  /// One entry in, one or more out. Only `shellfish` widens today, and it widens
  /// because the old token meant both classes: a woman who saved "shellfish"
  /// before the split told us she cannot eat calamari either, and a guard that
  /// dropped that on upgrade would be a silent regression in exactly the
  /// direction this file exists to prevent.
  static Set<String> expandAliases(Iterable<String> declared) {
    final out = <String>{};
    for (final raw in declared) {
      final token = raw.trim().toLowerCase();
      if (token == 'shellfish') {
        out.add(AllergenTag.crustaceans.wireName);
        out.add(AllergenTag.molluscs.wireName);
        continue;
      }
      final tag = fromWire(token);
      // An unrecognised token is kept rather than dropped. It may be a tag a
      // later content release added and this build has never heard of, and
      // forgetting it would fail open.
      out.add(tag?.wireName ?? token);
    }
    return out;
  }
}

/// How she usually eats. `G17`'s second row.
///
/// [everything] is an answer, not an absence — the same distinction
/// `Equipment.none` makes in `Intake`. It maps to an empty preference set,
/// because "I eat everything" means nothing is filtered.
enum DietaryTag {
  everything('everything'),
  vegetarianWeekdays('vegetarian_weekdays');

  const DietaryTag(this.wireName);

  final String wireName;

  /// The tags a dish must carry to satisfy this answer.
  ///
  /// **The weekday qualifier is not representable.** `DietaryConstraints` has no
  /// notion of a day, and `AllergyGuard._satisfies` asks only whether the dish
  /// carries the tag. So "vegetarian on weekdays" screens as plain "vegetarian".
  /// That is narrower than her answer on two days of the week and it is reported
  /// rather than papered over — a preference filter that is slightly too strict
  /// costs her a suggestion, which is the safe direction for a *preference*.
  Set<String> get requiredDishTags => switch (this) {
    DietaryTag.everything => const <String>{},
    DietaryTag.vegetarianWeekdays => const <String>{'vegetarian'},
  };

  static DietaryTag? fromWire(String wire) {
    for (final tag in values) {
      if (tag.wireName == wire.trim().toLowerCase()) return tag;
    }
    return null;
  }
}

/// `users/{uid}.profile.{allergies, dietary}`.
///
/// # Null is the whole design
///
/// Both sets are nullable and **null means "never asked"**, never "she has
/// none". That is the distinction `DietaryConstraints` is built around and the
/// one this type exists to carry across the boundary intact:
///
/// | her state | `allergies` | becomes | guard behaviour |
/// |---|---|---|---|
/// | never asked | `null` | `DietaryConstraints.unknown` | fails closed |
/// | asked, named nothing | `{}` | `DietaryConstraints.none` | clears |
/// | asked, named nuts | `{nuts}` | real constraints | blocks nuts |
///
/// Collapsing the first two rows is exactly how a guard silently turns itself
/// off for the women who have not been asked yet.
@immutable
class DietaryProfile {
  const DietaryProfile({this.allergies, this.dietary});

  /// The state every woman is in before A02 asks her.
  static const DietaryProfile unasked = DietaryProfile();

  /// Asked, and named nothing. A **claim** about her, and only reachable by her
  /// actually answering — see [DietaryProfileRepository.save].
  static const DietaryProfile noneNamed = DietaryProfile(
    allergies: <AllergenTag>{},
    dietary: <DietaryTag>{},
  );

  /// Null until she has been asked.
  final Set<AllergenTag>? allergies;

  /// Null until she has been asked.
  final Set<DietaryTag>? dietary;

  /// True once the allergy question has actually been put to her.
  ///
  /// This is what A02's row reads to decide between "tell us what you avoid" and
  /// showing her answer back — and what the Eat feature reads to know whether
  /// `none` is a claim it is entitled to make.
  bool get asked => allergies != null;

  /// The bridge into the Eat feature's safety guard.
  ///
  /// This is the single function that makes `P0-EAT-01` reachable: wire
  /// `AppRouter.eatConstraints` to `profile.toConstraints()` and
  /// `AllergyGuard`'s fail-closed behaviour goes live with no other change.
  /// The alias expansion happens here rather than in the guard, because the
  /// profile is the side that knows a wire token may be an old spelling. A
  /// woman who saved `shellfish` before the tag split told us she cannot eat
  /// calamari either, and the guard must screen both classes for her.
  DietaryConstraints toConstraints() => DietaryConstraints(
    allergies: allergies == null
        ? null
        : AllergenTag.expandAliases(allergies!.map((a) => a.wireName)),
    dietary: dietary?.expand((d) => d.requiredDishTags).toSet(),
  );

  DietaryProfile copyWith({
    Set<AllergenTag>? allergies,
    Set<DietaryTag>? dietary,
  }) => DietaryProfile(
    allergies: allergies ?? this.allergies,
    dietary: dietary ?? this.dietary,
  );

  @override
  bool operator ==(Object other) =>
      other is DietaryProfile &&
      _sameSet(other.allergies, allergies) &&
      _sameSet(other.dietary, dietary);

  static bool _sameSet<T>(Set<T>? a, Set<T>? b) {
    if (a == null || b == null) return a == null && b == null;
    return a.length == b.length && a.containsAll(b);
  }

  @override
  int get hashCode => Object.hash(
    allergies == null ? null : Object.hashAllUnordered(allergies!),
    dietary == null ? null : Object.hashAllUnordered(dietary!),
  );

  @override
  String toString() =>
      'DietaryProfile(allergies: ${allergies?.map((a) => a.wireName).toList() ?? "unasked"}, '
      'dietary: ${dietary?.map((d) => d.wireName).toList() ?? "unasked"})';
}

/// Where her allergies are read and written.
///
/// **A port, not an implementation.** The document is G2's (`users/{uid}.profile`),
/// so the Firestore version of this belongs beside `IntakeRepository` and writes
/// the same document with the same merge. G7 hosts the row on A02 and calls
/// this; G7 does not write the field.
///
/// Like `IntakeRepository`, the only write is a **merge** and there is no
/// `create`, no `complete` and no `lock` — D3's "editable forever" is a property
/// of the type rather than a promise in a comment.
abstract class DietaryProfileRepository {
  /// Her answers, or [DietaryProfile.unasked] if the question has never been put
  /// to her.
  ///
  /// Never invents [DietaryProfile.noneNamed]. That value is only ever produced
  /// by her answering.
  DietaryProfile read();

  /// Writes only the fields named, and returns the merged result.
  ///
  /// Passing an **empty set** is a real answer — "I have no allergies" — and is
  /// what turns `unknown` into `none`. Passing null does not touch the field.
  Future<DietaryProfile> save({
    Set<AllergenTag>? allergies,
    Set<DietaryTag>? dietary,
  });
}

/// In-memory, recording which fields each save wrote — the same evidence
/// `InMemoryIntakeRepository` keeps, for the same reason: "A02 wrote allergies
/// and nothing else" is the assertion that proves the per-field merge is real
/// rather than a whole-profile save wearing a merge's name.
class InMemoryDietaryProfileRepository implements DietaryProfileRepository {
  InMemoryDietaryProfileRepository([DietaryProfile? initial])
    : _profile = initial ?? DietaryProfile.unasked;

  DietaryProfile _profile;

  /// The field names touched by each [save], oldest first.
  final List<Set<String>> writes = <Set<String>>[];

  @override
  DietaryProfile read() => _profile;

  @override
  Future<DietaryProfile> save({
    Set<AllergenTag>? allergies,
    Set<DietaryTag>? dietary,
  }) async {
    writes.add({
      if (allergies != null) 'profile.allergies',
      if (dietary != null) 'profile.dietary',
    });
    _profile = _profile.copyWith(allergies: allergies, dietary: dietary);
    return _profile;
  }

  /// Puts back the answers she had already given when the app closed.
  ///
  /// It cannot invent [DietaryProfile.noneNamed]: the storage layer only ever
  /// hands back what it read, and a woman who was never asked has nothing
  /// stored, so she stays unasked. See `lib/app_state/local_persistence.dart`.
  void restore(DietaryProfile profile) => _profile = profile;

  /// Back to unasked. Account deletion calls it, and `unasked` rather than
  /// `none` is the point: "she has no allergies" is a claim, and a deleted
  /// account has not made it.
  void reset() {
    _profile = DietaryProfile.unasked;
    writes.clear();
  }
}
