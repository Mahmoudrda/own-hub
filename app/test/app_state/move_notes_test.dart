// The note she keeps for a move, and the bar she loads, are phone only: they
// survive being closed, an old snapshot reads as none, and Delete everything
// clears them.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/bar_preference.dart';
import 'package:own_hub/app_state/move_notes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final notes = MoveNotes.instance;
  final bar = BarPreference.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    notes.reset();
    bar.reset();
  });
  tearDown(() {
    notes.reset();
    bar.reset();
  });

  group('the note', () {
    test('is trimmed, cut at 80 characters, and per move', () {
      notes.setFor('leg_press', '  seat 4, pin 3  ');
      expect(notes.forMove('leg_press'), 'seat 4, pin 3');
      expect(notes.forMove('squat'), isNull);
      notes.setFor('squat', 'x' * 120);
      expect(notes.forMove('squat')!.length, kMoveNoteMaxLength);
    });

    test('empty removes it', () {
      notes.setFor('leg_press', 'seat 4');
      notes.setFor('leg_press', '   ');
      expect(notes.forMove('leg_press'), isNull);
      expect(notes.touched, isFalse);
    });
  });

  group('phone only', () {
    test('the snapshot carries notes and the bar and restores them', () {
      notes.setFor('leg_press', 'seat 4, pin 3');
      bar.choose(15);
      final document = jsonEncode(AppSnapshot.capture());
      notes.reset();
      bar.reset();

      AppSnapshot.restore(document);
      expect(notes.forMove('leg_press'), 'seat 4, pin 3');
      expect(bar.kg, 15);
    });

    test('a snapshot with none writes no section', () {
      final captured = AppSnapshot.capture();
      expect(captured.containsKey('moveNotes'), isFalse);
      expect(captured.containsKey('barKg'), isFalse);
    });

    test('damaged entries are dropped rather than trusted', () {
      AppSnapshot.restore(
        jsonEncode({
          'schema': 2,
          'moveNotes': {
            'moves': {'squat': 'seat 4', 'row': 7, 'lunge': '', '': 'x'},
          },
          'barKg': 12,
        }),
      );
      expect(notes.toJson(), {'squat': 'seat 4'});
      expect(bar.touched, isFalse);
    });

    test('Delete everything clears them and the count says so', () async {
      notes.setFor('leg_press', 'seat 4');
      expect(nothingOfHersRemains, isFalse);
      await const ThisPhoneWipe().clearPersistence();
      expect(notes.touched, isFalse);
      expect(nothingOfHersRemains, isTrue);

      bar.choose(10);
      expect(nothingOfHersRemains, isFalse);
      await const ThisPhoneWipe().clearPersistence();
      expect(bar.touched, isFalse);
      expect(nothingOfHersRemains, isTrue);
    });

    test('they are in no cloud document or analytics', () {
      final cloud = File('lib/app_state/cloud_documents.dart')
          .readAsStringSync();
      expect(cloud.contains('MoveNotes'), isFalse);
      expect(cloud.contains('moveNotes'), isFalse);
      expect(cloud.contains('BarPreference'), isFalse);
    });
  });
}
