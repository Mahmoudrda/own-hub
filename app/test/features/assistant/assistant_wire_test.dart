// P0-ASK-12 (the PDPL payload allowlist), the cycle guarantee, and the
// structural half of P0-ASK-01/02/10 — "it returns ids and a template key,
// never a number".
//
// The number guard is deliberately written against the SOURCE of
// `assistant_wire.dart`, not against an instance. An instance test can only
// prove that the one object built here carries no number; a source test proves
// that **no field exists anywhere on the wire that could carry one**, which is
// the actual claim. G15 D2 calls this making an invented quantity
// "unrenderable", and unrenderable is a property of the type, not of a value.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/features/assistant/domain/assistant_wire.dart';

/// Keys that must never appear in an outbound body. G15 §5, rule P3.
///
/// Named `kForbidden…` so `product_rules_test.dart`'s deny-list exemption
/// recognises this as enforcement rather than as a violation — the house rule
/// that has already caught two other agents.
const Set<String> kForbiddenPayloadKeys = <String>{
  'uid',
  'userId',
  'name',
  'firstName',
  'phone',
  'phoneNumber',
  'weight',
  'weightKg',
  'kg',
  'measurement',
  'measurements',
  'photo',
  'photos',
  'avatar',
  'nationalId',
  'idResult',
  'verification',
  'cycle',
  'cycleDay',
  'period',
  'periods',
  'lifeStage',
  'checkIn',
  'checkIns',
  // Health data. Food is screened on the phone by AllergyGuard instead.
  'allergies',
  'allergens',
};

/// Field types that would let a quantity ride the wire.
const Set<String> kBannedWireFieldTypes = <String>{
  'int',
  'double',
  'num',
  'BigInt',
};

AssistantSubject _subject({Set<String>? dietary}) =>
    AssistantSubject.boundToCaller(
      locale: 'ar',
      equipment: const {'mat', 'dumbbells'},
      constraints: ClientSafetyFacts(
        avoid: const {
          ContraindicationTag.deepKneeFlexion,
          ContraindicationTag.highImpact,
        },
        dietary: dietary,
      ),
      sessionMinutes: '20',
      place: 'home',
    );

void main() {
  group('P0-ASK-12 — the payload carries only what it is allowed to', () {
    test('the body contains the allowlist and nothing else', () {
      final body = AssistantRequest(
        question: 'my knee hurts on the squats today',
        subject: _subject(dietary: const {'vegetarian'}),
      ).toWire();

      expect(body.keys.toSet(), <String>{
        'question',
        'locale',
        'equipment',
        'avoid',
        'dietary',
        'sessionMinutes',
        'place',
      }, reason: 'the case FAILS on any other field');
    });

    test('no forbidden key appears, at any depth', () {
      final body = AssistantRequest(
        question: 'anything',
        subject: _subject(dietary: const {'vegetarian'}),
      ).toWire();

      final serialised = body.toString();
      for (final banned in kForbiddenPayloadKeys) {
        expect(
          body.containsKey(banned),
          isFalse,
          reason: 'PDPL: "$banned" must never leave the phone',
        );
        expect(
          RegExp('\\b$banned\\b').hasMatch(serialised),
          isFalse,
          reason: '"$banned" appears in the serialised body',
        );
      }
    });

    test('the avoid list travels as tokens, and the life stage does not', () {
      // The clinical fact never travels; the constraint it implies still
      // applies. G15 §1.1.
      final body = _subject().toWire();
      expect(body['avoid'], <String>['deep_knee_flexion', 'high_impact']);
      expect(body.containsKey('lifeStage'), isFalse);
    });

    test('an unreadable diet is omitted, never sent as an empty claim', () {
      // Null means "could not be read", which is NOT "she has none".
      final body = _subject().toWire();
      expect(body.containsKey('dietary'), isFalse);
    });

    test('her allergies have no field, so they cannot leave the phone', () {
      // APL-18: allergies are health data. AllergyGuard screens food on the
      // device before ranking; the wire has nowhere to put the list.
      final body = _subject(dietary: const {'vegetarian'}).toWire();
      expect(body.containsKey('allergies'), isFalse);
      final code = File('lib/features/assistant/domain/assistant_wire.dart')
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(RegExp(r'\ballerg').hasMatch(code), isFalse);
    });
  });

  group('cycle data is unreachable, sharing switch or not', () {
    test('there is no field, so there is no switch to consult', () {
      // The strongest form of the guarantee: `AssistantSubject.boundToCaller`
      // takes no cycle parameter, so no caller — correct or careless — can put
      // cycle data into a payload. C12.
      final body = _subject(dietary: const {}).toWire();
      for (final key in body.keys) {
        expect(
          RegExp('cycle|period|menstrual', caseSensitive: false).hasMatch(key),
          isFalse,
        );
      }

      final source = File('lib/features/assistant/domain/assistant_wire.dart')
          .readAsLinesSync();
      final offenders = <String>[];
      for (var i = 0; i < source.length; i++) {
        final line = source[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
        if (RegExp(
          r'\b(cycle|period|menstrual)\w*\s*;',
          caseSensitive: false,
        ).hasMatch(line)) {
          offenders.add('${i + 1}  ${line.trim()}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'cycle is not in the payload allowlist at all',
      );
    });
  });

  group('D2 — no field on the wire can carry a number', () {
    test('the wire declares no numeric field', () {
      final lines = File('lib/features/assistant/domain/assistant_wire.dart')
          .readAsLinesSync();

      final offenders = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') ||
            trimmed.startsWith('///') ||
            trimmed.startsWith('*')) {
          continue;
        }
        // A field declaration: `final <type> name;`
        final match = RegExp(r'^\s*final\s+([A-Za-z_][\w<>, ?]*)\s+\w+\s*;')
            .firstMatch(line);
        if (match == null) continue;
        final type = match.group(1)!;
        for (final banned in kBannedWireFieldTypes) {
          if (RegExp('\\b$banned\\b').hasMatch(type)) {
            offenders.add('${i + 1}  ${line.trim()}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'G15 D2: an invented quantity must be unrenderable because no '
            'field on the wire can carry one. A numeric field here reopens it.',
      );
    });

    test('the guard would actually bite', () {
      // A positive control. A source-scanning guard that matches nothing is
      // indistinguishable from one whose regex is broken, and this codebase has
      // already shipped a vacuous guard that passed for weeks by not looking.
      const offender = '  final int kcal;';
      final match = RegExp(r'^\s*final\s+([A-Za-z_][\w<>, ?]*)\s+\w+\s*;')
          .firstMatch(offender);
      expect(match, isNotNull);
      expect(RegExp(r'\bint\b').hasMatch(match!.group(1)!), isTrue);
    });

    test('a pick carries an id and a provenance, and nothing else', () {
      const pick = AssistantPick(
        kind: PickKind.exercise,
        id: 'glute_bridge',
        source: PickSource.moveLibrary,
      );
      // No name, no sets, no reps, no grams. The device reads those from the
      // pack row keyed by this id.
      expect(pick.id, 'glute_bridge');
      expect(pick.toString(), 'AssistantPick(exercise:glute_bridge)');
    });

    test(
      'a plan draft counts its own days, and the model never states one',
      () {
        const draft = PlanDraft(
          days: [
            PlanDraftDay(
              kind: PlanDayKind.training,
              exerciseIds: ['glute_bridge'],
            ),
            PlanDraftDay(kind: PlanDayKind.rest),
            PlanDraftDay(kind: PlanDayKind.training, exerciseIds: ['dead_bug']),
          ],
        );
        // The position in the list IS the day index, so there is no `dayIndex`
        // int for a model to get wrong.
        expect(draft.dayCount, 3);
        expect(draft.sessionCount, 2);
        expect(draft.restCount, 1);
      },
    );
  });

  group('the tool registry is frozen, and nothing in it publishes', () {
    test('exactly six tools exist', () {
      expect(AssistantTool.values, hasLength(6));
    });

    test('no tool publishes or writes', () {
      for (final tool in AssistantTool.values) {
        expect(
          RegExp(
            'publish|write|create|update|delete',
            caseSensitive: false,
          ).hasMatch(tool.wireName),
          isFalse,
          reason: '${tool.wireName} must not be able to change anything',
        );
      }
    });

    test('no tool takes a uid — a model cannot pivot to another woman', () {
      // D4. The subject is bound from the caller; `get_client_context` takes
      // `{}` precisely so there is no argument to point elsewhere.
      final source = File('lib/features/assistant/domain/assistant_wire.dart')
          .readAsStringSync();
      expect(
        RegExp(r"'uid'|\buid\b\s*:").hasMatch(source),
        isFalse,
        reason: 'no tool input and no wire type may carry a uid',
      );
    });

    test('the tool array is sorted, so the cached prefix does not move', () {
      final names = [for (final t in AssistantTool.sortedByName) t.wireName];
      expect(names, List<String>.from(names)..sort());
    });
  });
}
