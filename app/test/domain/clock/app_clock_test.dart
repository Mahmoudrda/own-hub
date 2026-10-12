import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';

void main() {
  tearDown(() => AppClock.debugNow = null);

  test('on a phone it is the wall clock', () {
    final before = DateTime.now();
    final read = AppClock.now();
    final after = DateTime.now();
    expect(read.isBefore(before), isFalse);
    expect(read.isAfter(after), isFalse);
  });

  test('a pinned clock is what her week reads, and null puts it back', () {
    final monday = DateTime(2026, 10, 12, 9, 30);
    AppClock.debugNow = () => monday;
    expect(AppClock.now(), monday);
    expect(WeekKey.current(), WeekKey.of(monday));

    AppClock.debugNow = null;
    final wall = DateTime.now();
    expect(AppClock.now().difference(wall).inSeconds.abs(), lessThan(5));
  });

  test("Home's first day is the pinned day", () {
    AppClock.debugNow = () => DateTime(2026, 10, 14, 8);
    expect(InMemoryTodayRepository.dayOne().date.weekday, DateTime.wednesday);
  });
}
