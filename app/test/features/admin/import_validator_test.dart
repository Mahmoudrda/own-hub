// The dry run — G16 §3, and the reason this console exists.
//
// Every case here is a line from the plan:
//
//   §3.1 "The file is parsed and validated in full before anything is written.
//         If any row fails, nothing is written at all."
//   §3.2 "A mandatory safety column must carry an explicit value. `none` is
//         valid… Empty is rejected, named row by row at Z09."
//   §3.5 the seven validation rules.
//
// Written before the validator. The plan is the specification; the code is not.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/domain/csv_parser.dart';
import 'package:own_hub/features/admin/domain/import_validator.dart';

/// Validates [source] as [collection], with an optional media upload and an
/// optional set of ids already in the library.
ImportPlan _check(
  String source, {
  ContentCollection collection = ContentCollection.foods,
  Set<String> uploaded = const {},
  Set<String> existing = const {},
}) {
  return validateImport(
    collection: collection,
    table: parseCsv(source),
    uploadedMedia: uploaded,
    existingIds: existing,
  );
}

/// A foods file with the mandatory columns present and correct.
const String _goodFoods =
    'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
    'koshari,Koshari,K,plate,430,13,78,7,gluten,vegetarian\n'
    'ful,Ful,F,bowl,220,12,30,6,none,vegetarian\n';

void main() {
  group('a clean file', () {
    test('every row is accepted and the plan may commit', () {
      final plan = _check(_goodFoods);

      expect(plan.problems, isEmpty);
      expect(plan.canCommit, isTrue);
      expect(plan.creates, hasLength(2));
      expect(plan.updates, isEmpty);
      expect(plan.rowsReady, 2);
    });

    test('values are parsed into the shape the library stores', () {
      final plan = _check(_goodFoods);
      final koshari = plan.creates.first;

      expect(koshari.id, 'koshari');
      expect(koshari.value('name_en'), 'Koshari');
      expect(koshari.number('kcal'), 430);
      expect(koshari.list('allergens'), ['gluten']);
    });

    test('a pipe-separated list becomes several values', () {
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'k,K,K,plate|half plate,430,13,78,7,gluten|sesame,vegetarian|vegan\n',
      );

      expect(plan.creates.single.list('dietTags'), ['vegetarian', 'vegan']);
      expect(plan.creates.single.list('portions'), ['plate', 'half plate']);
    });
  });

  group('§3.1 — all or nothing', () {
    test('one bad row makes the whole batch uncommittable', () {
      // "If any row fails, nothing is written at all." The plan is not allowed
      // to offer a partial commit, because a half-imported food library is
      // worse than none: the gaps are invisible and AllergyGuard reads a
      // missing tag as unknown-therefore-unsafe.
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'koshari,Koshari,K,plate,430,13,78,7,gluten,vegetarian\n'
        'ful,Ful,F,bowl,220,12,30,6,,vegetarian\n',
      );

      expect(plan.problems, hasLength(1));
      expect(plan.canCommit, isFalse);
    });

    test('the good rows in a failing batch are still not writable', () {
      // The tempting bug: expose `creates` and let the UI write "the ones that
      // passed". Whatever the plan reports for review, `canCommit` is the only
      // gate, and it is false.
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'koshari,Koshari,K,plate,430,13,78,7,gluten,vegetarian\n'
        'ful,Ful,F,bowl,220,12,30,6,,vegetarian\n',
      );

      expect(plan.canCommit, isFalse);
      expect(
        plan.writes,
        isEmpty,
        reason:
            'a plan that cannot commit must offer nothing to write, not a '
            'filtered subset of it',
      );
    });
  });

  group('§3.2 — blank is not none', () {
    test('an empty allergens cell is rejected, and names its row', () {
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'koshari,Koshari,K,plate,430,13,78,7,,vegetarian\n',
      );

      final problem = plan.problems.single;
      expect(problem.code, ImportProblemCode.blankSafetyTag);
      expect(problem.column, 'allergens');
      expect(problem.row, 2, reason: 'the header is line 1');
    });

    test('"none" is accepted and means it contains none', () {
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'ful,Ful,F,bowl,220,12,30,6,none,vegetarian\n',
      );

      expect(plan.problems, isEmpty);
      expect(plan.creates.single.list('allergens'), ['none']);
    });

    test('a cell holding only spaces is blank, not a value', () {
      // The parser deliberately keeps whitespace (rule 4). This is where it is
      // judged. A space-only cell arrives from a spreadsheet constantly, and
      // treating it as an explicit tag would create exactly the ambiguity §3.2
      // refuses to create.
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'k,K,K,plate,430,13,78,7,   ,vegetarian\n',
      );

      expect(plan.problems.single.code, ImportProblemCode.blankSafetyTag);
    });

    test(
      'an exercise with no contraindicationTags is rejected the same way',
      () {
        final plan = _check(
          'exerciseId,name_en,name_ar,equipment,pattern,contraindicationTags,quiet,floorOnly,videoFile,thumbFile\n'
          'squat,Squat,S,dumbbell,squat,,true,false,,\n',
          collection: ContentCollection.exercises,
        );

        expect(plan.problems.single.code, ImportProblemCode.blankSafetyTag);
        expect(plan.problems.single.column, 'contraindicationTags');
      },
    );

    test('an exercise tagged "none" is accepted', () {
      final plan = _check(
        'exerciseId,name_en,name_ar,equipment,pattern,contraindicationTags,quiet,floorOnly,videoFile,thumbFile\n'
        'squat,Squat,S,dumbbell,squat,none,true,false,,\n',
        collection: ContentCollection.exercises,
      );

      expect(plan.problems, isEmpty);
    });
  });

  group('§3.5 — the bilingual pair', () {
    test('a missing name_ar is rejected and names the column', () {
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'k,Koshari,,plate,430,13,78,7,gluten,vegetarian\n',
      );

      expect(plan.problems.single.code, ImportProblemCode.blankRequired);
      expect(plan.problems.single.column, 'name_ar');
    });

    test('a missing name_en is rejected too', () {
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'k,,K,plate,430,13,78,7,gluten,vegetarian\n',
      );

      expect(plan.problems.single.column, 'name_en');
    });
  });

  group('§3.5 — ids', () {
    test('a duplicate id inside one file is rejected', () {
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'ful,Ful,F,bowl,220,12,30,6,none,vegetarian\n'
        'ful,Ful again,F,bowl,220,12,30,6,none,vegetarian\n',
      );

      final problem = plan.problems.single;
      expect(problem.code, ImportProblemCode.duplicateId);
      expect(
        problem.row,
        3,
        reason: 'the SECOND occurrence is the problem, not the first',
      );
    });

    test('a blank id is rejected', () {
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        ',Koshari,K,plate,430,13,78,7,gluten,vegetarian\n',
      );

      expect(plan.problems.single.code, ImportProblemCode.blankRequired);
      expect(plan.problems.single.column, 'foodId');
    });
  });

  group('§3.5 — re-running the same file must not duplicate', () {
    test('an id already in the library is an update, not a create', () {
      // "Re-importing a row with an existing id updates it." Determinism comes
      // from the id in the file being the document id — there is no minted key
      // that could differ between two runs of the same file.
      final plan = _check(_goodFoods, existing: {'koshari'});

      expect(plan.updates.map((r) => r.id), ['koshari']);
      expect(plan.creates.map((r) => r.id), ['ful']);
      expect(plan.canCommit, isTrue);
    });

    test('importing the same file twice produces the same document ids', () {
      final first = _check(_goodFoods);
      final second = _check(
        _goodFoods,
        existing: first.writes.map((r) => r.id).toSet(),
      );

      expect(second.creates, isEmpty, reason: 'nothing new the second time');
      expect(
        second.writes.map((r) => r.documentId).toList(),
        first.writes.map((r) => r.documentId).toList(),
      );
      expect(second.writes, hasLength(2));
    });

    test('the document id is the id column, unchanged', () {
      // Hashing it would be a second source of truth and would break every
      // reference already written against the plain id.
      final plan = _check(_goodFoods);
      expect(plan.writes.map((r) => r.documentId), ['koshari', 'ful']);
    });
  });

  group('§3.5 — unknown columns are rejected, not ignored', () {
    test('a misspelled header is a problem in its own right', () {
      // "a typo in a header silently dropping `allergens` is the exact failure
      // this console exists to prevent."
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergen,dietTags\n'
        'k,K,K,plate,430,13,78,7,gluten,vegetarian\n',
      );

      expect(plan.canCommit, isFalse);
      expect(
        plan.problems.map((p) => p.code),
        containsAll([
          ImportProblemCode.unknownColumn,
          ImportProblemCode.missingColumn,
        ]),
      );
      expect(
        plan.problems.map((p) => p.column),
        containsAll(['allergen', 'allergens']),
      );
    });

    test('a header problem is reported against line 1', () {
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags,extra\n'
        'k,K,K,plate,430,13,78,7,gluten,vegetarian,x\n',
      );

      final unknown = plan.problems.firstWhere(
        (p) => p.code == ImportProblemCode.unknownColumn,
      );
      expect(unknown.row, 1);
      expect(unknown.column, 'extra');
    });

    test('a file with no header at all is rejected rather than crashing', () {
      final plan = _check('');

      expect(plan.canCommit, isFalse);
      expect(plan.problems, isNotEmpty);
    });

    test('a duplicated header is rejected', () {
      // Two columns called `allergens` means one of them is silently discarded,
      // and nobody can say which.
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,allergens\n'
        'k,K,K,plate,430,13,78,7,gluten,gluten\n',
      );

      expect(
        plan.problems.map((p) => p.code),
        contains(ImportProblemCode.duplicateColumn),
      );
    });
  });

  group('§3.5 — a row must have as many cells as the header', () {
    test('a short row is rejected rather than padded', () {
      // Padding with blanks would turn a truncated line into a row with a blank
      // `allergens`, which is the failure the safety rule is about — arriving
      // through the back door.
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'k,K,K,plate,430\n',
      );

      expect(plan.problems.single.code, ImportProblemCode.wrongFieldCount);
      expect(plan.problems.single.row, 2);
    });

    test('a long row is rejected rather than truncated', () {
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'k,K,K,plate,430,13,78,7,gluten,vegetarian,surplus\n',
      );

      expect(plan.problems.single.code, ImportProblemCode.wrongFieldCount);
    });

    test('a completely blank line is skipped, not reported', () {
      // Spreadsheets leave them behind constantly. Reporting a blank line as a
      // bad row would make a correct file unimportable for a cosmetic reason.
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'k,K,K,plate,430,13,78,7,gluten,vegetarian\n'
        '\n',
      );

      expect(plan.problems, isEmpty);
      expect(plan.creates, hasLength(1));
    });
  });

  group('§3.5 — macros numeric and non-negative', () {
    test('a non-numeric macro is rejected', () {
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'k,K,K,plate,four hundred,13,78,7,gluten,vegetarian\n',
      );

      expect(plan.problems.single.code, ImportProblemCode.notANumber);
      expect(plan.problems.single.column, 'kcal');
    });

    test('a negative macro is rejected', () {
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'k,K,K,plate,-10,13,78,7,gluten,vegetarian\n',
      );

      expect(plan.problems.single.code, ImportProblemCode.negativeNumber);
    });

    test('zero is a legitimate macro', () {
      // Black coffee, water, a zero-fat food. Rejecting 0 would be a rule
      // nobody asked for.
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'k,K,K,cup,0,0,0,0,none,vegan\n',
      );

      expect(plan.problems, isEmpty);
    });

    test(
      'Eastern Arabic numerals are rejected rather than silently misread',
      () {
        // The product writes Western digits everywhere (P0-A11Y-01). A macro typed
        // in Eastern digits is not a number this app can store, and guessing at it
        // would put an unverifiable calorie figure in front of a woman.
        final plan = _check(
          'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
          'k,K,K,plate,٤٣٠,13,78,7,gluten,vegetarian\n',
        );

        expect(plan.problems.single.code, ImportProblemCode.notANumber);
      },
    );
  });

  group('§3.4 — a named media file must be in the upload', () {
    test('a row naming a video that was never uploaded is rejected', () {
      // "A row naming a file that was never uploaded is a validation failure,
      // not a broken link discovered later by a woman mid-workout."
      final plan = _check(
        'exerciseId,name_en,name_ar,equipment,pattern,contraindicationTags,quiet,floorOnly,videoFile,thumbFile\n'
        'squat,Squat,S,dumbbell,squat,none,true,false,squat.mp4,\n',
        collection: ContentCollection.exercises,
      );

      final problem = plan.problems.single;
      expect(problem.code, ImportProblemCode.missingMedia);
      expect(problem.column, 'videoFile');
      expect(problem.value, 'squat.mp4');
    });

    test('the same row passes once the file is in the upload', () {
      final plan = _check(
        'exerciseId,name_en,name_ar,equipment,pattern,contraindicationTags,quiet,floorOnly,videoFile,thumbFile\n'
        'squat,Squat,S,dumbbell,squat,none,true,false,squat.mp4,\n',
        collection: ContentCollection.exercises,
        uploaded: {'squat.mp4'},
      );

      expect(plan.problems, isEmpty);
    });

    test('an empty media cell names no file and is not a problem', () {
      final plan = _check(
        'exerciseId,name_en,name_ar,equipment,pattern,contraindicationTags,quiet,floorOnly,videoFile,thumbFile\n'
        'squat,Squat,S,dumbbell,squat,none,true,false,,\n',
        collection: ContentCollection.exercises,
      );

      expect(plan.problems, isEmpty);
    });

    test('a recipe photo is checked the same way', () {
      final plan = _check(
        // The recipe contract grew with Rahma's book: nineteen more facts a
        // recipe carries and a CSV can hold. The subject of this test is the
        // photo column, and the rest of the row is here only so the row is
        // complete enough to reach it.
        'recipeId,name_en,name_ar,minutes,ingredients,allergens,dietTags,photoFile,sectionId,source,status,sourcePage,authoredBy,allergenReviewedBy,serves,activeMinutes,kcal,proteinG,carbsG,fatG,macroBasis,egpPerServing,egpPricedAt,advisories,doneness,markKey,tier\n'
        'soup,Soup,S,25,lentils,none,vegan,soup.jpg,,authored,draft,,,,,,,,,,withheld,,,none,,pot,free\n',
        collection: ContentCollection.recipes,
      );

      expect(plan.problems.single.column, 'photoFile');
    });
  });

  group('booleans', () {
    test('true and false are accepted in either case', () {
      final plan = _check(
        'exerciseId,name_en,name_ar,equipment,pattern,contraindicationTags,quiet,floorOnly,videoFile,thumbFile\n'
        'a,A,A,none,squat,none,TRUE,False,,\n',
        collection: ContentCollection.exercises,
      );

      expect(plan.problems, isEmpty);
      expect(plan.creates.single.boolean('quiet'), isTrue);
      expect(plan.creates.single.boolean('floorOnly'), isFalse);
    });

    test('"yes" is rejected rather than quietly read as false', () {
      // `quiet` decides whether a move is offered to a woman training in a flat
      // with neighbours below. Defaulting an unrecognised value to false would
      // put jumping into her quiet programme.
      final plan = _check(
        'exerciseId,name_en,name_ar,equipment,pattern,contraindicationTags,quiet,floorOnly,videoFile,thumbFile\n'
        'a,A,A,none,squat,none,yes,false,,\n',
        collection: ContentCollection.exercises,
      );

      expect(plan.problems.single.code, ImportProblemCode.notABoolean);
      expect(plan.problems.single.column, 'quiet');
    });
  });

  group('the report Z09 draws', () {
    test('problems are ordered by row so the list reads like the file', () {
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'a,A,A,plate,430,13,78,7,gluten,vegetarian\n'
        'b,B,,bowl,220,12,30,6,none,vegetarian\n'
        'c,C,C,bowl,220,12,30,6,,vegetarian\n',
      );

      expect(plan.problems.map((p) => p.row), [3, 4]);
    });

    test('a row with two faults reports both, not just the first', () {
      // She has to fix the file once, not discover the second fault on the next
      // run. An importer that stops at the first problem per row turns one
      // round trip into four.
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'a,A,,plate,430,13,78,7,,vegetarian\n',
      );

      expect(plan.problems, hasLength(2));
      expect(
        plan.problems.map((p) => p.column),
        containsAll(['name_ar', 'allergens']),
      );
    });

    test('rowsReady counts only rows with nothing wrong', () {
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'a,A,A,plate,430,13,78,7,gluten,vegetarian\n'
        'b,B,B,bowl,220,12,30,6,,vegetarian\n',
      );

      expect(plan.rowsReady, 1);
      expect(plan.rowsWithProblems, 1);
    });

    test('a row counts once however many faults it has', () {
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'a,A,,plate,430,13,78,7,,vegetarian\n',
      );

      expect(plan.rowsWithProblems, 1);
      expect(plan.problems, hasLength(2));
    });
  });

  group('the missing-safety-tag count Z01 leads with', () {
    test('it counts rows whose safety column is blank', () {
      // Z01 "leads with what is missing rather than what exists, because an
      // incomplete library is the failure mode that matters and a count of rows
      // hides it".
      final plan = _check(
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'a,A,A,plate,430,13,78,7,,vegetarian\n'
        'b,B,B,bowl,220,12,30,6,none,vegetarian\n'
        'c,C,C,bowl,220,12,30,6,,vegetarian\n',
      );

      expect(plan.rowsMissingASafetyTag, 2);
    });

    test('"none" is tagged, and does not count as missing', () {
      final plan = _check(_goodFoods);
      expect(plan.rowsMissingASafetyTag, 0);
    });
  });
}
