// `K04` — how many women she can carry, and the two rules that keep the number
// on her public page true: the ceiling, and the fact that a device may never
// write `taken`.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coach/domain/coach_capacity.dart';

void main() {
  test('the product cap is sixty', () {
    expect(CoachCapacity.ceiling, 60);
    expect(CoachCapacity(max: 60).max, 60);
    expect(() => CoachCapacity(max: 61), throwsArgumentError);
  });

  test('a coach who can take nobody is not a capacity', () {
    expect(() => CoachCapacity(max: 0), throwsArgumentError);
    expect(() => CoachCapacity(max: -3), throwsArgumentError);
  });

  test('it refuses rather than clamps', () {
    // A clamp would let K04 send 200 and silently store 60, so she would read
    // one number on her form and another on her page.
    try {
      CoachCapacity(max: 200);
      fail('200 should not have been accepted');
    } on ArgumentError catch (e) {
      expect(e.invalidValue, 200);
    }
  });

  test('taken can never exceed max', () {
    expect(() => CoachCapacity(max: 9, taken: 10), throwsArgumentError);
    expect(() => CoachCapacity(max: 9, taken: -1), throwsArgumentError);
    expect(CoachCapacity(max: 9, taken: 9).hasRoom, isFalse);
  });

  test('an unset capacity is not a capacity of twenty', () {
    // Twenty is the prototype's sample. A pre-filled answer states her capacity
    // on her behalf; K04 asks.
    expect(CoachCapacity.unset.isSet, isFalse);
    expect(CoachCapacity.unset.max, 0);
    expect(CoachCapacity.unset.hasRoom, isFalse);
    expect(CoachCapacity.unset.spotsLeft, 0);
  });

  group('spots left is a real number', () {
    test('it counts down as women arrive', () {
      final roster = CoachCapacity(max: 14, taken: 9);
      expect(roster.spotsLeft, 5);
      expect(roster.hasRoom, isTrue);
      expect(roster.isEmpty, isFalse);
    });

    test('an empty roster is the K24 branch', () {
      expect(CoachCapacity(max: 14).isEmpty, isTrue);
      expect(CoachCapacity(max: 14, taken: 1).isEmpty, isFalse);
    });
  });

  group('taken moves only through the accept transaction', () {
    test('one more is taken when there is room', () {
      final next = CoachCapacity(max: 14, taken: 9).withOneMoreTaken();
      expect(next, isNotNull);
      expect(next!.taken, 10);
      expect(next.max, 14);
    });

    test('a full roster returns null rather than overshooting', () {
      expect(CoachCapacity(max: 3, taken: 3).withOneMoreTaken(), isNull);
    });

    test('a spot is released when coaching ends', () {
      expect(CoachCapacity(max: 5, taken: 2).withOneFewerTaken().taken, 1);
      expect(CoachCapacity(max: 5).withOneFewerTaken().taken, 0);
    });
  });

  group('changing her ceiling never re-sends taken', () {
    test('taken is carried through untouched', () {
      final moved = CoachCapacity(max: 14, taken: 9).withMax(22);
      expect(moved.max, 22);
      expect(
        moved.taken,
        9,
        reason:
            'A stale taken from an offline device is exactly how '
            'last-write-wins invents a spot.',
      );
    });

    test('she cannot strand the women she already has', () {
      expect(
        () => CoachCapacity(max: 14, taken: 9).withMax(4),
        throwsArgumentError,
      );
    });

    test('she may lower it to exactly her roster', () {
      expect(CoachCapacity(max: 14, taken: 9).withMax(9).max, 9);
    });

    test('and never above the product cap', () {
      expect(
        () => CoachCapacity(max: 10, taken: 2).withMax(61),
        throwsArgumentError,
      );
    });
  });

  test('two capacities with the same numbers are the same capacity', () {
    expect(CoachCapacity(max: 7, taken: 3), CoachCapacity(max: 7, taken: 3));
    expect(
      CoachCapacity(max: 7, taken: 3).hashCode,
      CoachCapacity(max: 7, taken: 3).hashCode,
    );
    expect(
      CoachCapacity(max: 7, taken: 3) == CoachCapacity(max: 7, taken: 4),
      isFalse,
    );
  });
}
