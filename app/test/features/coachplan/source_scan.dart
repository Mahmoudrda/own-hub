// Reads this feature's own source, for the rules whose enforcement is an
// **absence**.
//
// Several of G14's rules are kept by there being no code that could break them
// — no publisher outside W08's, no acknowledgement argument on a coach's
// allergy path, no `actual*` field anywhere. An absence cannot be exercised by
// calling it, so these tests read the folder instead, the way
// `product_rules_test.dart` reads `lib/`.
//
// Comments are stripped first, for that file's reason: a file that says "there
// is deliberately no override here" is documenting the rule, not breaking it,
// and a guard that fails on correct code for explaining itself teaches people
// to stop explaining.

import 'dart:io';

/// Everything under `lib/features/coachplan/`, keyed by the path below it.
///
/// Comment-only lines are removed. Blank lines are kept so a line number in a
/// failure still means something.
Map<String, String> coachPlanSources() {
  const root = 'lib/features/coachplan';
  final out = <String, String>{};
  for (final file in Directory(root).listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    out[file.path.substring(root.length + 1)] = withoutComments(
      file.readAsStringSync(),
    );
  }
  return out;
}

/// The same files, exactly as written. For assertions about documentation.
Map<String, String> coachPlanSourcesVerbatim() {
  const root = 'lib/features/coachplan';
  final out = <String, String>{};
  for (final file in Directory(root).listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    out[file.path.substring(root.length + 1)] = file.readAsStringSync();
  }
  return out;
}

/// [source] with every comment-only line blanked.
String withoutComments(String source) => <String>[
  for (final line in source.split('\n'))
    if (_isComment(line)) '' else line,
].join('\n');

bool _isComment(String line) {
  final trimmed = line.trimLeft();
  return trimmed.startsWith('//') || trimmed.startsWith('*');
}

/// An override of somebody else's allergy, in any of the shapes it would take.
///
/// G5 gives *her* an override, because she is the authority on her own body. A
/// coach is not, and prescribing around another woman's allergy is not hers to
/// override — so none of these may appear in this feature's code.
const Set<String> kForbiddenOverrideTokens = <String>{
  'acknowledged:',
  'allergenOverride',
  'overrideAllergen',
  'assignAnyway',
  'logItAnyway',
};

/// Quantities a coach could type in. Every gram and serving on W06 traces to
/// `foods[].sizes[]` in G5's verified pack, so a slot has nowhere to put one.
const Set<String> kForbiddenQuantityKeys = <String>{
  'grams',
  'kcal',
  'proteinG',
  'quantity',
  'amount',
};

/// Result-shaped fields. §2.1: a prescribed value is never a result, and rule 1
/// is a shape rather than a discipline — there is no field to pre-fill.
const Set<String> kForbiddenResultFields = <String>{
  'actualWeight',
  'actualReps',
  'actualSeconds',
  'actualHoldSec',
  'actualLoad',
  'actualSets',
};

/// Anything that would let a plan be published from a screen that is not W08.
const Set<String> kForbiddenPublishReferences = <String>{
  'CoachPlanPublisher',
  'PlanPublishGateway',
  'publishCoachPlan',
};

/// Weight, in every spelling. C7: nothing in a coach's planning tools may
/// become somewhere a woman's body weight is stored — or ranked.
const Set<String> kForbiddenWeightFields = <String>{
  'weightKg',
  'bodyWeight',
  'bmi',
  'bodyFat',
  'weightLost',
};
