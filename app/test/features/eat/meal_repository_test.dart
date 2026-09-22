// P0-LOG-11 — "Two devices offline log into the same meal slot."
//
// From TEST-CASES.csv: "Both items survive. Neither overwrites the other and
// the total reflects both. A plain document merge would lose one." Rule
// protected: "Spine C3 (amended): same-slot writes need arrayUnion/increment,
// not merge."
//
// The spine is explicit that this is a REGRESSION test for a specific mistake:
//
// > The original claim — that writing into `slots.<slot>` merges commutatively —
// > is only true *across different slots*. Two devices offline writing into the
// > **same** slot would have one overwrite the other's array, losing a log.
//
// So the assertions below are about convergence, and they are run in BOTH
// arrival orders. A merge bug that loses the later write passes a single-order
// test half the time.
//
// This file also pins the strictness of the fake itself. G5's own §8 lists
// `P0-EAT-11` as a gap "worth asserting because `arrayUnion` vs. a plain array
// `set` is invisible in review" — and a fake that accepted a whole-array write
// would let this case pass here and fail on a real phone.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/day_totals.dart';
import 'package:own_hub/features/eat/domain/meal_day_reader.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';

const _dayId = '2026-09-15';

MealItem _item(
  String itemId, {
  required String foodId,
  required int kcal,
  required int proteinG,
  required int minute,
}) => MealItem(
  itemId: itemId,
  foodId: foodId,
  servings: 1,
  size: 'M',
  loggedAt: DateTime(2026, 9, 15, 13, minute),
  source: MealSource.search,
  origin: MealOrigin.search,
  kcal: kcal,
  proteinG: proteinG,
);

MealWrite _lunchWrite(List<MealItem> items) => MealWrite.transform(
  dayId: _dayId,
  slot: MealSlot.lunch,
  added: items,
  tz: 'Africa/Cairo',
  libVersion: 1,
);

/// The phone's lunch: koshari and two eggs.
List<MealItem> get _phoneItems => [
  _item(
    'phone-koshari',
    foodId: 'koshari_bowl',
    kcal: 540,
    proteinG: 18,
    minute: 12,
  ),
  _item(
    'phone-eggs',
    foodId: 'boiled_eggs',
    kcal: 156,
    proteinG: 13,
    minute: 12,
  ),
];

/// The tablet's lunch: molokhia.
List<MealItem> get _tabletItems => [
  _item(
    'tablet-molokhia',
    foodId: 'molokhia_chicken',
    kcal: 460,
    proteinG: 34,
    minute: 20,
  ),
];

void main() {
  group('P0-LOG-11 — two devices, one slot, no signal', () {
    /// Runs the whole scenario and returns the day both devices end up sharing.
    Future<MealDay> converge({required bool phoneFirst}) async {
      // One account, one server. Two handsets.
      final server = MealStore()..days[_dayId] = const MealDay(dayId: _dayId);
      final phone = InMemoryMealRepository(store: server);
      final tablet = InMemoryMealRepository(store: server);

      phone.goOffline();
      tablet.goOffline();

      await phone.applyLog(_lunchWrite(_phoneItems));
      await tablet.applyLog(_lunchWrite(_tabletItems));

      // Nothing has reached the server yet — but each device already shows her
      // own log, with its real numbers (§4.3).
      expect(server.days[_dayId]!.itemsIn(MealSlot.lunch), isEmpty);
      expect((await phone.day(_dayId)).itemsIn(MealSlot.lunch), hasLength(2));
      expect((await tablet.day(_dayId)).itemsIn(MealSlot.lunch), hasLength(1));

      if (phoneFirst) {
        await phone.goOnline();
        await tablet.goOnline();
      } else {
        await tablet.goOnline();
        await phone.goOnline();
      }

      return server.days[_dayId]!;
    }

    test('all three items survive, whichever device syncs first', () async {
      for (final phoneFirst in [true, false]) {
        final day = await converge(phoneFirst: phoneFirst);
        final items = const MealDayReader().itemsIn(day, MealSlot.lunch);

        expect(
          items.map((i) => i.itemId).toSet(),
          {'phone-koshari', 'phone-eggs', 'tablet-molokhia'},
          reason:
              'arrival order must not decide whose lunch is kept '
              '(phoneFirst: $phoneFirst)',
        );
      }
    });

    test('the total reflects both devices', () async {
      final day = await converge(phoneFirst: true);
      final totals = const MealDayReader().totals(day);

      // 540 + 156 + 460. The figure G5 §4.5 works through by hand.
      expect(totals.kcalSoFar, 1156);
      expect(totals.proteinSoFar, 18 + 13 + 34);
    });

    test(
      'both devices render the identical day, in the identical order',
      () async {
        final day = await converge(phoneFirst: false);
        final reader = const MealDayReader();

        // Deterministic ordering is what makes "every device renders the same
        // day" true of the order as well as the contents.
        expect(
          reader.itemsIn(day, MealSlot.lunch).map((i) => i.itemId).toList(),
          reader.itemsIn(day, MealSlot.lunch).map((i) => i.itemId).toList(),
        );
        expect(
          reader.itemsIn(day, MealSlot.lunch).map((i) => i.itemId).toList(),
          ['phone-eggs', 'phone-koshari', 'tablet-molokhia'],
          reason: 'sorted by (loggedAt, itemId), not by arrival',
        );
      },
    );

    test('different slots on two devices also merge', () async {
      // The case spine C3 originally claimed was the only one. It must keep
      // working — the amendment added the same-slot case, it did not replace
      // this one.
      final server = MealStore()..days[_dayId] = const MealDay(dayId: _dayId);
      final phone = InMemoryMealRepository(store: server)..goOffline();
      final tablet = InMemoryMealRepository(store: server)..goOffline();

      await phone.applyLog(_lunchWrite(_phoneItems));
      await tablet.applyLog(
        MealWrite.transform(
          dayId: _dayId,
          slot: MealSlot.dinner,
          added: _tabletItems,
          tz: 'Africa/Cairo',
          libVersion: 1,
        ),
      );
      await tablet.goOnline();
      await phone.goOnline();

      final day = server.days[_dayId]!;
      expect(day.itemsIn(MealSlot.lunch), hasLength(2));
      expect(day.itemsIn(MealSlot.dinner), hasLength(1));
    });
  });

  group('a value overwrite is not expressible', () {
    test('MealWrite carries transforms and deltas, never a slot or a total', () {
      final write = _lunchWrite(_phoneItems);

      // What it CAN say.
      expect(write.added, hasLength(2));
      expect(write.removed, isEmpty);
      expect(write.kcalDelta, 696);

      // The deltas are derived from the items, so they cannot drift from them —
      // there is no constructor that takes a total independently of the list it
      // is supposed to describe.
      expect(
        write.kcalDelta,
        _phoneItems.fold<int>(0, (sum, i) => sum + i.kcal),
      );
      expect(
        write.proteinDelta,
        _phoneItems.fold<int>(0, (sum, i) => sum + i.proteinG),
      );
    });

    test('a second write appends rather than replacing the slot', () async {
      final repository = InMemoryMealRepository()
        ..store.days[_dayId] = const MealDay(dayId: _dayId);

      await repository.applyLog(_lunchWrite(_phoneItems));
      await repository.applyLog(_lunchWrite(_tabletItems));

      expect(
        (await repository.day(_dayId)).itemsIn(MealSlot.lunch),
        hasLength(3),
        reason:
            'if applyLog assigned the slot instead of unioning into it, the '
            'second write would leave one item and P0-LOG-11 would be false in '
            'production while passing here',
      );
    });
  });

  group('the fake is strict where the real backend is strict', () {
    late InMemoryMealRepository repository;

    setUp(() {
      repository = InMemoryMealRepository()
        ..store.days[_dayId] = const MealDay(dayId: _dayId);
    });

    test('a duplicate itemId that removes nothing is refused', () async {
      await repository.applyLog(_lunchWrite(_phoneItems));

      // This is the shape of the bug P0-LOG-10 guards: the same identity added
      // a second time, with no arrayRemove. Left to Firestore's arrayUnion it
      // would depend on whole-element equality, so a changed size would append
      // and double the serving.
      await expectLater(
        repository.applyLog(
          _lunchWrite([
            _item(
              'phone-koshari',
              foodId: 'koshari_bowl',
              kcal: 610,
              proteinG: 27,
              minute: 40,
            ),
          ]),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('removing an item that is not there is refused', () async {
      await expectLater(
        repository.applyLog(
          MealWrite.transform(
            dayId: _dayId,
            slot: MealSlot.lunch,
            removed: _tabletItems,
            tz: 'Africa/Cairo',
            libVersion: 1,
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('a document id that is not yyyy-MM-dd is refused', () async {
      // Spine C1. The security rules refuse `2026-6-1` too; a fake that
      // accepted it would let a non-idempotent id ship.
      for (final bad in ['2026-6-1', 'today', '2026-09-15T10:00:00Z']) {
        await expectLater(
          repository.applyLog(
            MealWrite.transform(
              dayId: bad,
              slot: MealSlot.lunch,
              added: _tabletItems,
              tz: 'Africa/Cairo',
              libVersion: 1,
            ),
          ),
          throwsA(isA<StateError>()),
          reason: '"$bad" is not a deterministic date key',
        );
      }
    });

    test('a slot cannot exceed the cap the rules enforce', () async {
      await expectLater(
        repository.applyLog(
          _lunchWrite([
            for (var i = 0; i <= kSlotItemCap; i++)
              _item(
                'item-$i',
                foodId: 'f$i',
                kcal: 10,
                proteinG: 1,
                minute: 12,
              ),
          ]),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('the day document', () {
    test('firstLogAt is written once and never moved', () async {
      final repository = InMemoryMealRepository()
        ..store.days[_dayId] = const MealDay(dayId: _dayId);

      await repository.applyLog(_lunchWrite(_phoneItems));
      final first = (await repository.day(_dayId)).firstLogAt;

      await repository.applyLog(_lunchWrite(_tabletItems));
      expect(
        (await repository.day(_dayId)).firstLogAt,
        first,
        reason:
            'G6 awards +5 points once a day on the document, so this field '
            'means "she logged something today" and must not follow the '
            'latest log',
      );
    });

    test('an untouched day reads as empty rather than as an error', () async {
      final repository = InMemoryMealRepository();
      final day = await repository.day('2026-01-01');

      expect(day.hasNothingLogged, isTrue);
      expect(const MealDayReader().isFirstDay(day), isTrue);
      expect(const MealDayReader().totals(day), DayTotals.empty);
    });
  });
}
