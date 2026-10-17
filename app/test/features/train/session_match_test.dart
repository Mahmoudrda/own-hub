// A button that names a kind of session opens that session, or is not drawn.
//
// R01's short tiles, T04's ten minutes and Y06's gentle mobility all opened
// her normal planned day: a longer workout behind a label that said otherwise.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/cycle/presentation/gentler_option_view.dart';
import 'package:own_hub/features/today/presentation/quiet_week_view.dart';
import 'package:own_hub/features/train/domain/session_match.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';
import 'package:own_hub/features/train/presentation/train_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

AuthoredMove _move(
  String id, {
  bool floor = false,
  bool quiet = false,
  bool kit = false,
}) => AuthoredMove(
  exerciseId: id,
  nameEn: id,
  nameAr: id,
  sets: 2,
  reps: 10,
  floorOnly: floor,
  quiet: quiet,
  needsEquipment: kit,
);

OfferedSession _offer(String id, int minutes, List<AuthoredMove> moves) {
  final session = AuthoredSession(
    sessionId: id,
    titleEn: id,
    titleAr: id,
    minutes: minutes,
    lifeStages: const {},
    moves: moves,
  );
  return (
    programme: AuthoredProgramme(
      programId: 'p',
      titleEn: 'P',
      titleAr: 'P',
      status: ProgrammeStatus.published,
      sessions: [session],
    ),
    session: session,
  );
}

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  home: child,
);

void main() {
  final floor10 = _offer('floor10', 10, [
    _move('a', floor: true),
    _move('b', floor: true),
  ]);
  final quiet15 = _offer('quiet15', 15, [_move('c', quiet: true)]);
  final kit20 = _offer('kit20', 20, [_move('d', kit: true), _move('e')]);
  final long35 = _offer('long35', 35, [_move('f', floor: true, quiet: true)]);
  final offered = [floor10, quiet15, kit20, long35];

  group('shortSessionFor', () {
    test('finds the session each tile names', () {
      expect(
        shortSessionFor(offered, maxMinutes: 10, floorOnly: true)
            ?.session
            .sessionId,
        'floor10',
      );
      expect(
        shortSessionFor(offered, maxMinutes: 15, quiet: true)
            ?.session
            .sessionId,
        'quiet15',
      );
      expect(
        shortSessionFor(offered, maxMinutes: 20, withEquipment: true)
            ?.session
            .sessionId,
        'kit20',
      );
    });

    test('never answers with a longer session', () {
      expect(
        shortSessionFor([long35], maxMinutes: 15, quiet: true),
        isNull,
      );
    });

    test('T04 holds to four moves', () {
      final five = _offer('five', 10, [
        for (var i = 0; i < 5; i++) _move('m$i', floor: true),
      ]);
      expect(
        shortSessionFor([five], maxMinutes: 10, floorOnly: true, maxMoves: 4),
        isNull,
      );
    });
  });

  group('gentleMobilitySessionFor', () {
    test('a session of mobility moves, the shortest', () {
      final stretch = _offer('stretch', 15, [_move('cat_cow', floor: true)]);
      final named = _offer('Gentle mobility', 20, [_move('x')]);
      expect(
        gentleMobilitySessionFor(
          [stretch, named, floor10],
          isMobility: (id) => id == 'cat_cow',
        )?.session.sessionId,
        'stretch',
      );
    });

    test('none when the library has none', () {
      expect(
        gentleMobilitySessionFor(offered, isMobility: (_) => false),
        isNull,
      );
    });
  });

  testWidgets('R01 with no short sessions draws no tiles and no heading', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const TrainView(shortSessions: [])));
    await tester.pumpAndSettle();
    expect(find.text('Short ones that still count'), findsNothing);
    expect(find.textContaining('min ·'), findsNothing);
  });

  testWidgets('Y06 with no gentle session offers no option', (tester) async {
    await tester.pumpWidget(_host(GentlerOptionView(reason: const [], onKeepWorkout: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Use this option'), findsNothing);
    expect(find.text('Keep my workout'), findsOneWidget);
  });

  testWidgets('T04 with no ten-minute session offers breakfast alone', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const QuietWeekView(offersShortSession: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start the 10 minutes'), findsNothing);
  });
}
