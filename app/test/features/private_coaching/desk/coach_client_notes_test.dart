// The coach's private note about a client is phone only: it survives being
// closed, an old snapshot reads as none, and Delete everything clears it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/coach_client_notes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final notes = CoachClientNotes.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    notes.reset();
  });
  tearDown(notes.reset);

  group('the note', () {
    test('is trimmed, cut at 500 characters, and per client', () {
      notes.setFor('u1', '  knee, ask on Thursday  ');
      expect(notes.forClient('u1'), 'knee, ask on Thursday');
      expect(notes.forClient('u2'), '');
      notes.setFor('u2', 'x' * 700);
      expect(notes.forClient('u2').length, kCoachClientNoteMaxLength);
    });

    test('empty removes it', () {
      notes.setFor('u1', 'knee');
      notes.setFor('u1', '   ');
      expect(notes.forClient('u1'), '');
      expect(notes.touched, isFalse);
    });
  });

  group('phone only', () {
    test('the snapshot carries the notes and restores them', () {
      notes.setFor('u1', 'knee, ask on Thursday');
      final document = jsonEncode(AppSnapshot.capture());
      notes.reset();

      AppSnapshot.restore(document);
      expect(notes.forClient('u1'), 'knee, ask on Thursday');
    });

    test('a snapshot with none writes no section', () {
      expect(AppSnapshot.capture().containsKey('coachClientNotes'), isFalse);
    });

    test('damaged entries are dropped rather than trusted', () {
      AppSnapshot.restore(
        jsonEncode({
          'schema': 2,
          'coachClientNotes': {
            'clients': {'u1': 'knee', 'u2': 7, 'u3': '', '': 'x'},
          },
        }),
      );
      expect(notes.toJson(), {'u1': 'knee'});
    });

    test('Delete everything clears them and the count says so', () async {
      notes.setFor('u1', 'knee');
      expect(nothingOfHersRemains, isFalse);
      await const ThisPhoneWipe().clearPersistence();
      expect(notes.touched, isFalse);
      expect(nothingOfHersRemains, isTrue);
    });

    test('they are in no cloud document or analytics', () {
      final cloud = File('lib/app_state/cloud_documents.dart')
          .readAsStringSync();
      expect(cloud.contains('CoachClientNotes'), isFalse);
      expect(cloud.contains('coachClientNotes'), isFalse);
    });
  });
}
