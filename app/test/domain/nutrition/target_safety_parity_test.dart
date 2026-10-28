// The calorie and macro limits are written down in three places: TargetSafety
// (what the phone computes), MealGoal (what the coach's composer accepts) and
// functions/coaching/plans.py (what the server lets out). They must be the same
// numbers, or a goal one of them refuses another sends.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/nutrition/target_safety.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';

String _pair(String source, String name) {
  final match = RegExp(
    '^$name\\s*=\\s*\\(([^)]*)\\)',
    multiLine: true,
  ).firstMatch(source);
  expect(match, isNotNull, reason: '$name not found in plans.py');
  return match!.group(1)!.replaceAll(' ', '');
}

double _number(String source, String name) {
  final match = RegExp(
    '^$name\\s*=\\s*([0-9.]+)',
    multiLine: true,
  ).firstMatch(source);
  expect(match, isNotNull, reason: '$name not found in plans.py');
  return double.parse(match!.group(1)!);
}

void main() {
  final plans = File('../functions/coaching/plans.py').readAsStringSync();

  test('the server accepts the same kcal range as the phone computes', () {
    expect(
      _pair(plans, 'GOAL_KCAL'),
      '${TargetSafety.floorKcal},${TargetSafety.ceilingKcal}',
    );
  });

  test('the server holds a stage goal to the same floor', () {
    expect(
      _number(plans, 'STAGE_GOAL_KCAL_FLOOR'),
      TargetSafety.stageGoalFloorKcal,
    );
  });

  test('the server caps protein at the same share of the day', () {
    expect(_number(plans, 'MAX_PROTEIN_SHARE'), TargetSafety.maxProteinShare);
  });

  test('the coach composer accepts the same ranges as the server', () {
    expect(MealGoal.kcalMin, TargetSafety.floorKcal);
    expect(MealGoal.kcalMax, TargetSafety.ceilingKcal);
    expect(
      _pair(plans, 'GOAL_PROTEIN_G'),
      '${MealGoal.proteinMin},${MealGoal.proteinMax}',
    );
  });

  test('every stage the server holds a goal for is one the phone protects', () {
    final subscriptions = File('../functions/coaching/subscriptions.py')
        .readAsStringSync();
    final match = RegExp(
      r'^FLAGGED_STAGES\s*=\s*\(([^)]*)\)',
      multiLine: true,
    ).firstMatch(subscriptions);
    expect(match, isNotNull, reason: 'FLAGGED_STAGES not found');
    final held = [
      for (final m in RegExp(r'"([^"]+)"').allMatches(match!.group(1)!))
        m.group(1)!,
    ];
    expect(held, containsAll(['pregnant', 'postpartum']));
    for (final stage in held) {
      expect(TargetStage.fromWire(stage).isProtected, isTrue, reason: stage);
    }
  });
}
