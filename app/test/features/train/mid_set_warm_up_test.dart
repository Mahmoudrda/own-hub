// R07 warm-up sets: a switch for the next set, off by default. A warm-up is
// saved and shown but is not a working set, so it never reaches the sets that
// bests, volume and the summary are read from.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/mid_set_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

/// A loaded move, 20 kg × 8, three sets.
const PlannedMove _loaded = PlannedMove(
  exerciseId: 'goblet_squat',
  name: 'Goblet squat',
  prescriptionLabel: '3 × 8 · 20 kg',
  sets: [
    PrescribedSet(exerciseId: 'goblet_squat', order: 1, weightKg: 20, reps: 8),
    PrescribedSet(exerciseId: 'goblet_squat', order: 2, weightKg: 20, reps: 8),
    PrescribedSet(exerciseId: 'goblet_squat', order: 3, weightKg: 20, reps: 8),
  ],
);

const PlannedMove _bodyweight = PlannedMove(
  exerciseId: 'glute_bridge',
  name: 'Glute bridge',
  prescriptionLabel: '3 × 12',
  sets: [
    PrescribedSet(exerciseId: 'glute_bridge', order: 1, reps: 12),
    PrescribedSet(exerciseId: 'glute_bridge', order: 2, reps: 12),
  ],
);

const String _hint =
    'Warm up with about 10 kg first, around half your working weight.';

void main() {
  late InMemoryTrainRepository repository;
  late LogCommandBus bus;

  setUp(() {
    repository = InMemoryTrainRepository();
    bus = LogCommandBus();
  });
  tearDown(() => bus.dispose());

  Widget view({
    PlannedMove move = _loaded,
    int setIndex = 0,
    List<SetOutcome> warmUps = const [],
    SetOutcome? lastLogged,
    WarmUpLogged? onWarmUpLogged,
    ValueChanged<LogHandle>? onSetLogged,
  }) => MidSetView(
    move: move,
    setIndex: setIndex,
    repository: repository,
    bus: bus,
    sessionId: 's1',
    warmUps: warmUps,
    lastLogged: lastLogged,
    onWarmUpLogged: onWarmUpLogged,
    onSetLogged: onSetLogged,
  );

  group('the switch', () {
    testWidgets('is not drawn when nothing handles a warm-up', (tester) async {
      await tester.pumpWidget(_host(view()));
      await tester.pumpAndSettle();
      expect(find.text('Warm-up set'), findsNothing);
      expect(find.text(_hint), findsNothing);
    });

    testWidgets('is off by default and the button names the working set', (
      tester,
    ) async {
      await tester.pumpWidget(_host(view(onWarmUpLogged: (_, _) {})));
      await tester.pumpAndSettle();
      expect(find.text('Warm-up set'), findsOneWidget);
      expect(find.text('Done · 20 kg × 8'), findsOneWidget);
    });

    testWidgets('on, the button names the warm-up it will save', (
      tester,
    ) async {
      await tester.pumpWidget(_host(view(onWarmUpLogged: (_, _) {})));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('r07-warm-up')));
      await tester.pumpAndSettle();
      expect(find.text('Done · warm-up 10 kg × 8'), findsOneWidget);
      expect(find.text('Done · 20 kg × 8'), findsNothing);
    });

    testWidgets('the warm-up weight comes from her last weight', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          view(
            lastLogged: const SetOutcome(weightKg: 17.5, reps: 8),
            onWarmUpLogged: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Warm up with about 9 kg first, around half your working weight.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('r07-warm-up')));
      await tester.pumpAndSettle();
      expect(find.text('Done · warm-up 9 kg × 8'), findsOneWidget);
    });

    testWidgets('a 48 point target that works at text scale 2.0 in Arabic', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          view(onWarmUpLogged: (_, _) {}),
          locale: const Locale('ar'),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byKey(const ValueKey('r07-warm-up')));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(find.text('سيت إحماء'), findsOneWidget);
      expect(find.bySemanticsLabel('سيت إحماء'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('the suggestion', () {
    testWidgets('shows before the first set of a loaded move', (tester) async {
      await tester.pumpWidget(_host(view(onWarmUpLogged: (_, _) {})));
      await tester.pumpAndSettle();
      expect(find.text(_hint), findsOneWidget);
    });

    testWidgets('does not pressure: it goes away once the switch is on', (
      tester,
    ) async {
      await tester.pumpWidget(_host(view(onWarmUpLogged: (_, _) {})));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('r07-warm-up')));
      await tester.pumpAndSettle();
      expect(find.text(_hint), findsNothing);
    });

    testWidgets('is made once: not after a warm-up, not on later sets', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          view(
            warmUps: const [SetOutcome(weightKg: 10, reps: 8)],
            onWarmUpLogged: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_hint), findsNothing);

      await tester.pumpWidget(
        _host(view(setIndex: 1, onWarmUpLogged: (_, _) {})),
      );
      await tester.pumpAndSettle();
      expect(find.text(_hint), findsNothing);
    });

    testWidgets('is not made for a move with no working weight', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(view(move: _bodyweight, onWarmUpLogged: (_, _) {})),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('r07-warm-up-hint')), findsNothing);
      expect(find.text('Warm-up set'), findsOneWidget);
    });
  });

  group('saving a warm-up', () {
    testWidgets('goes to the warm-up callback, never the working one', (
      tester,
    ) async {
      LogHandle? handle;
      SetOutcome? saved;
      var working = 0;
      await tester.pumpWidget(
        _host(
          view(
            onWarmUpLogged: (h, o) {
              handle = h;
              saved = o;
            },
            onSetLogged: (_) => working++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('r07-warm-up')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done · warm-up 10 kg × 8'));
      await tester.pump();

      expect(working, 0);
      expect(saved?.weightKg, 10);
      expect(saved?.reps, 8);
      expect(handle?.describe, 'Warm-up saved · 10 kg × 8');
      // The switch is off again for the next set.
      expect(find.text('Done · 20 kg × 8'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('reaches no flushed set, however long it waits', (
      tester,
    ) async {
      await tester.pumpWidget(_host(view(onWarmUpLogged: (_, _) {})));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('r07-warm-up')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done · warm-up 10 kg × 8'));
      await tester.pump(const Duration(seconds: 10));

      expect(
        repository.flushes,
        isEmpty,
        reason: 'bests, volume and the summary read the flushed sets',
      );
    });

    testWidgets('a working set still flushes, so the test above means it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(view(onWarmUpLogged: (_, _) {}, onSetLogged: (_) {})),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done · 20 kg × 8'));
      await tester.pump(const Duration(seconds: 10));
      expect(repository.flushes, hasLength(1));
    });

    testWidgets('can be taken back inside the window', (tester) async {
      LogHandle? handle;
      await tester.pumpWidget(
        _host(view(onWarmUpLogged: (h, _) => handle = h)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('r07-warm-up')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done · warm-up 10 kg × 8'));
      await tester.pump();

      expect(handle!.undo(), isTrue);
    });

    testWidgets('is listed above the working sets once saved', (tester) async {
      await tester.pumpWidget(
        _host(
          view(
            warmUps: const [SetOutcome(weightKg: 10, reps: 8)],
            onWarmUpLogged: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Warm-up'), findsOneWidget);
      expect(find.text('10 kg × 8'), findsOneWidget);
    });
  });
}
