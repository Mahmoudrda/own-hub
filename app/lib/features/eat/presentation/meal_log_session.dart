/// The five seconds after a meal is logged, shared by every screen that can
/// show it.
///
/// Each Eat screen used to hold its own [LogCommandBus]. The write then lived
/// inside the screen that made it: E02 logged, pushed E04, and E04 opened on an
/// empty day — the day-one branch, with no undo bar — because the meal was
/// still sitting in E02's private bus. Five seconds later the write landed, the
/// undo bar appeared, and tapping it did nothing because the window had closed.
///
/// A session is one bus plus the list of meals still inside their window, so
/// any screen can draw them the moment they are logged and any screen can take
/// them back. Rule 9 is unchanged: the write is held here and reaches the
/// repository only when the window closes, so an undone meal is never written.
///
/// ## When the window closes early
///
/// Screens that show pending meals [attach] while they are open. When the last
/// one leaves, whatever is still pending is committed at once rather than left
/// waiting: nothing on screen offers the undo any more, and the log belongs to
/// her from that moment — the same rule every screen's own bus followed when
/// it flushed on dispose.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/logging/log_command_bus.dart';
import '../../../domain/week/week_key.dart';
import '../domain/item_id.dart';
import '../domain/meal_log_service.dart';
import '../domain/meal_repository.dart';

/// A meal inside its undo window — or, once passed to `onCommitted`, one that
/// has just been written.
@immutable
class PendingMeal {
  const PendingMeal({
    required this.handle,
    required this.write,
    required this.slot,
    required this.items,
  });

  final LogHandle handle;
  final MealWrite write;
  final MealSlot slot;
  final List<MealItem> items;

  String get dayId => write.dayId;

  /// When she logged it. Every item in one log shares the moment.
  DateTime get at => items.first.loggedAt;
}

class MealLogSession extends ChangeNotifier {
  MealLogSession({
    required this.repository,
    LogCommandBus? bus,
    this.rememberPlates = true,
    this.onCommitted,
    this.onRemoved,
  }) : bus = bus ?? LogCommandBus();

  final MealRepository repository;
  final LogCommandBus bus;

  /// Whether a written meal is folded into her remembered plates — what turns
  /// "logged twice" into a one-tap suggestion on E01.
  final bool rememberPlates;

  /// Runs after a meal has been written, never for one she took back.
  final FutureOr<void> Function(PendingMeal meal)? onCommitted;

  /// Runs after a removal has been written, never for one she took back, with
  /// the day as it now stands and the plate the removal broke, if it was one
  /// of her remembered plates.
  final FutureOr<void> Function(
    PendingMeal removal,
    MealDay day,
    String? plateId,
  )?
  onRemoved;

  final List<PendingMeal> _pending = <PendingMeal>[];

  /// Removals inside their window. Held like a log, so Undo means nothing was
  /// ever removed, and every screen already draws the slot without them.
  final List<PendingMeal> _removals = <PendingMeal>[];
  final Expando<bool> _issued = Expando<bool>('issued');
  final Expando<bool> _committed = Expando<bool>('committed');

  /// `dayId|plateId` → how many times that plate is in that day.
  final Map<String, int> _platesByDay = <String, int>{};

  EatPrefs _prefs = const EatPrefs();
  int _attached = 0;
  bool _disposed = false;

  /// Her remembered plates as of the last write this session made.
  EatPrefs get prefs => _prefs;

  /// Meals still inside their window, oldest first.
  List<PendingMeal> get pending => [
    for (final meal in _pending)
      if (bus.isPending(meal.handle)) meal,
  ];

  /// Logs a prepared meal. Saves immediately, offers five seconds, asks
  /// nothing — the same shape as [LogCommandBus.submit], which it wraps.
  LogHandle submit(
    MealLogPrepared prepared, {
    required MealSlot slot,
    required String describe,
  }) {
    late final PendingMeal meal;
    final handle = bus.submit(
      UndoableLog(describe: describe, commit: () => _commit(meal)),
    );
    meal = PendingMeal(
      handle: handle,
      write: prepared.write,
      slot: slot,
      items: prepared.items,
    );
    _issued[handle] = true;
    _pending.add(meal);
    _notify();
    return handle;
  }

  /// Takes [items] out of [slot] on [dayId], after she logged them. Offers
  /// five seconds and asks nothing, like a log; the write waits for the window
  /// and is an `arrayRemove` of exactly these items, never a rewrite.
  ///
  /// The day's zone and pack version are not this call's to set: the write is
  /// made with the stored day's own when the window closes.
  LogHandle remove({
    required String dayId,
    required MealSlot slot,
    required List<MealItem> items,
    required String describe,
  }) {
    late final PendingMeal removal;
    final handle = bus.submit(
      UndoableLog(describe: describe, commit: () => _commitRemoval(removal)),
    );
    removal = PendingMeal(
      handle: handle,
      write: MealWrite.transform(
        dayId: dayId,
        slot: slot,
        tz: WeekKey.fallbackTimezone,
        libVersion: 1,
        removed: items,
      ),
      slot: slot,
      items: items,
    );
    _issued[handle] = true;
    _removals.add(removal);
    _notify();
    return handle;
  }

  /// Takes a meal back. False once the window has closed.
  bool undo(LogHandle handle) {
    final undone = handle.undo();
    if (undone) {
      _pending.removeWhere((meal) => identical(meal.handle, handle));
      _removals.removeWhere((meal) => identical(meal.handle, handle));
      _notify();
    }
    return undone;
  }

  /// Call after something outside the session undid a handle directly — the
  /// snackbar does — so every screen redraws without it.
  void settle() {
    _pending.removeWhere((meal) => !bus.isPending(meal.handle));
    _removals.removeWhere((meal) => !bus.isPending(meal.handle));
    _notify();
  }

  /// True when this session made [handle].
  bool issued(LogHandle handle) => _issued[handle] ?? false;

  /// True while [handle] can still be taken back.
  bool isOpen(LogHandle handle) => bus.isPending(handle);

  /// True when [handle] was written rather than taken back.
  bool isCommitted(LogHandle handle) => _committed[handle] ?? false;

  /// True when this session made [handle] and she took it back.
  bool wasUndone(LogHandle handle) =>
      issued(handle) && !isOpen(handle) && !isCommitted(handle);

  /// The stored day plus every meal still inside its window for that day, and
  /// less every item she is removing.
  MealDay project(MealDay stored) {
    final live = pending.where((meal) => meal.dayId == stored.dayId);
    final going = [
      for (final removal in _removals)
        if (bus.isPending(removal.handle) && removal.dayId == stored.dayId)
          removal,
    ];
    if (live.isEmpty && going.isEmpty) return stored;
    final slots = <MealSlot, List<MealItem>>{...stored.slots};
    for (final meal in live) {
      slots[meal.slot] = [...?slots[meal.slot], ...meal.items];
    }
    for (final removal in going) {
      final ids = {for (final item in removal.items) item.itemId};
      slots[removal.slot] = [
        for (final item in slots[removal.slot] ?? const <MealItem>[])
          if (!ids.contains(item.itemId)) item,
      ];
    }
    return stored.copyWith(slots: slots);
  }

  /// A screen that draws pending meals is open.
  void attach() => _attached++;

  /// That screen has closed. When it was the last one, pending meals are
  /// written now — see the library note.
  void detach() {
    if (_attached > 0) _attached--;
    if (_attached == 0) flushNow();
  }

  /// Writes every pending meal immediately.
  ///
  /// Cancels each timer synchronously (through the bus's own undo path, which
  /// drops the held write without running it) and then runs the write itself,
  /// so no timer outlives the screens that were showing it.
  void flushNow() {
    for (final meal in pending) {
      if (meal.handle.undo()) unawaited(_commit(meal));
    }
    for (final removal in [..._removals]) {
      if (removal.handle.undo()) unawaited(_commitRemoval(removal));
    }
  }

  /// Reads her remembered plates again, for a screen opening cold.
  Future<EatPrefs> refreshPrefs() async {
    _prefs = await repository.prefs();
    return _prefs;
  }

  /// Drops everything without writing it. For tests and sign-out.
  void reset() {
    bus.dispose();
    _pending.clear();
    _removals.clear();
    _platesByDay.clear();
    _prefs = const EatPrefs();
    _attached = 0;
  }

  Future<void> _commit(PendingMeal meal) async {
    _pending.remove(meal);
    _committed[meal.handle] = true;
    await repository.applyLog(meal.write);
    if (rememberPlates) await _remember(meal);
    await onCommitted?.call(meal);
    _notify();
  }

  Future<void> _commitRemoval(PendingMeal removal) async {
    _removals.remove(removal);
    _committed[removal.handle] = true;
    // A removal changes what is in a slot, never the zone or the pack version
    // the day was logged under, so the write carries the day's own.
    final stored = await repository.day(removal.dayId);
    await repository.applyLog(
      MealWrite.transform(
        dayId: removal.dayId,
        slot: removal.slot,
        tz: stored.tz.isEmpty ? removal.write.tz : stored.tz,
        libVersion: stored.libVersion > 0
            ? stored.libVersion
            : removal.write.libVersion,
        removed: removal.items,
      ),
    );
    final forgotten = rememberPlates ? await _forget(removal, stored) : null;
    final hook = onRemoved;
    if (hook != null) {
      await hook(removal, await repository.day(removal.dayId), forgotten);
    }
    _notify();
  }

  /// The plate a removal broke, taken off that day's count, as if the meal had
  /// been undone: a meal logged by mistake is not offered back as a usual one.
  ///
  /// The meal is every item in the slot logged at the same moment as the
  /// removed ones, as the day held it before the removal. Returns the plate's
  /// id, or null when that meal is not a plate counted on that day: a
  /// photographed meal, one an earlier removal already broke, or a day the
  /// rollup no longer remembers.
  Future<String?> _forget(PendingMeal removal, MealDay before) async {
    if (removal.items.isEmpty) return null;
    final at = removal.at;
    final meal = [
      for (final item in before.itemsIn(removal.slot))
        if (item.loggedAt == at) item,
    ];
    if (meal.isEmpty) return null;
    if (meal.any((item) => item.origin == MealOrigin.photo)) return null;
    final plateId = plateIdOf([
      for (final item in meal) (foodId: item.foodId, size: item.size),
    ]);
    final plate = (await repository.prefs()).plates[plateId];
    if (plate == null) return null;
    final key = '${removal.dayId}|$plateId';
    final times = _platesByDay[key] ?? plate.dayCounts[removal.dayId] ?? 0;
    if (times <= 0) return null;
    _platesByDay[key] = times - 1;
    await repository.recordPlate(
      PlateObservation(
        plateId: plateId,
        items: plate.items,
        dayId: removal.dayId,
        slot: removal.slot,
        at: at,
        timesToday: times - 1,
      ),
    );
    _prefs = await repository.prefs();
    return plateId;
  }

  /// Folds a written meal into her plates, with the absolute count the rollup
  /// needs rather than an increment.
  Future<void> _remember(PendingMeal meal) async {
    if (meal.items.isEmpty) return;
    // A plate she photographed and checked holds foods the pack cannot log
    // again in one tap, so it is never offered back as one.
    if (meal.items.any((item) => item.origin == MealOrigin.photo)) return;
    final plateId = plateIdOf([
      for (final item in meal.items) (foodId: item.foodId, size: item.size),
    ]);
    final key = '${meal.dayId}|$plateId';
    var times = _platesByDay[key];
    if (times == null) {
      final stored = await repository.prefs();
      times = stored.plates[plateId]?.dayCounts[meal.dayId] ?? 0;
    }
    times += 1;
    _platesByDay[key] = times;

    await repository.recordPlate(
      PlateObservation(
        plateId: plateId,
        items: [
          for (final item in meal.items)
            PlateItem(
              foodId: item.foodId,
              size: item.size,
              servings: item.servings,
            ),
        ],
        dayId: meal.dayId,
        slot: meal.slot,
        at: meal.at,
        timesToday: times,
      ),
    );
    _prefs = await repository.prefs();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
