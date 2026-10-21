import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/onboarding/domain/tick_stroke.dart';

List<Offset> _line(Offset a, Offset b, int n) => [
  for (var i = 0; i <= n; i++) Offset.lerp(a, b, i / n)!,
];

void main() {
  test('a down-then-up stroke is a tick', () {
    final stroke = [
      ..._line(const Offset(20, 100), const Offset(70, 160), 8),
      ..._line(const Offset(70, 160), const Offset(190, 30), 16),
    ];
    expect(TickStroke.isTick(stroke), isTrue);
  });

  test('a small, slanted tick still counts', () {
    final stroke = [
      ..._line(const Offset(10, 60), const Offset(40, 100), 6),
      ..._line(const Offset(40, 100), const Offset(120, 20), 10),
    ];
    expect(TickStroke.isTick(stroke), isTrue);
  });

  test('a dot is not a tick', () {
    final dot = [for (var i = 0; i < 10; i++) Offset(50 + i * 0.2, 50)];
    expect(TickStroke.isTick(dot), isFalse);
  });

  test(
    'a straight diagonal, a vertical line and a flat line are not ticks',
    () {
      expect(
        TickStroke.isTick(
          _line(const Offset(0, 0), const Offset(150, 150), 20),
        ),
        isFalse,
      );
      expect(
        TickStroke.isTick(
          _line(const Offset(50, 0), const Offset(50, 150), 20),
        ),
        isFalse,
      );
      expect(
        TickStroke.isTick(
          _line(const Offset(0, 80), const Offset(200, 80), 20),
        ),
        isFalse,
      );
    },
  );

  test('a stroke that goes up first, then down, is not a tick', () {
    final stroke = [
      ..._line(const Offset(20, 160), const Offset(70, 40), 8),
      ..._line(const Offset(70, 40), const Offset(190, 160), 16),
    ];
    expect(TickStroke.isTick(stroke), isFalse);
  });

  test('a mirrored tick, right to left, counts', () {
    final stroke = [
      ..._line(const Offset(190, 100), const Offset(140, 160), 8),
      ..._line(const Offset(140, 160), const Offset(20, 30), 16),
    ];
    expect(TickStroke.isTick(stroke), isTrue);
  });

  test('a large tick counts', () {
    final stroke = [
      ..._line(const Offset(10, 150), const Offset(120, 320), 12),
      ..._line(const Offset(120, 320), const Offset(340, 20), 24),
    ];
    expect(TickStroke.isTick(stroke), isTrue);
  });

  test('a small tick counts', () {
    final stroke = [
      ..._line(const Offset(0, 20), const Offset(14, 40), 5),
      ..._line(const Offset(14, 40), const Offset(50, 0), 8),
    ];
    expect(TickStroke.isTick(stroke), isTrue);
  });

  test('a very short first stroke counts, both ways round', () {
    final ltr = [
      ..._line(const Offset(40, 146), const Offset(50, 160), 4),
      ..._line(const Offset(50, 160), const Offset(190, 30), 16),
    ];
    final rtl = [
      ..._line(const Offset(190, 146), const Offset(180, 160), 4),
      ..._line(const Offset(180, 160), const Offset(40, 30), 16),
    ];
    expect(TickStroke.isTick(ltr), isTrue);
    expect(TickStroke.isTick(rtl), isTrue);
  });

  test('a V counts', () {
    final stroke = [
      ..._line(const Offset(20, 40), const Offset(100, 160), 12),
      ..._line(const Offset(100, 160), const Offset(180, 40), 12),
    ];
    expect(TickStroke.isTick(stroke), isTrue);
  });

  test('a line up and to the right is not a tick', () {
    expect(
      TickStroke.isTick(_line(const Offset(0, 150), const Offset(150, 0), 20)),
      isFalse,
    );
  });

  test('a scribble in one place is not a tick', () {
    final scribble = <Offset>[
      for (var i = 0; i < 40; i++)
        Offset(20 + (i.isEven ? 0 : 60), 20 + (i % 4 < 2 ? 0 : 60) + i * 0.5),
    ];
    expect(TickStroke.isTick(scribble), isFalse);
  });
}
