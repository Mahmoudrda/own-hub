import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/assign_many.dart';

void main() {
  test('keeps going after a failure', () async {
    final outcome = await publishToMany(
      subIds: ['a', 'b', 'c'],
      send: (id) async {
        if (id == 'b') {
          throw const CoachingFailure(CoachingRefusal.badRequest);
        }
      },
    );
    expect(outcome.sent, ['a', 'c']);
    expect(outcome.failed.keys.toList(), ['b']);
    expect(outcome.allSent, isFalse);
  });

  test('sends in order and once', () async {
    final order = <String>[];
    final outcome = await publishToMany(
      subIds: ['a', 'b', 'c'],
      send: (id) async => order.add(id),
    );
    expect(order, ['a', 'b', 'c']);
    expect(outcome.sent, ['a', 'b', 'c']);
    expect(outcome.allSent, isTrue);
  });
}
