// Z13: building a programme's sessions from the exercise library.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/presentation/content_form_view.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

Finder _labelled(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  ),
  matching: find.byType(TextField),
);

Future<void> _type(WidgetTester tester, Finder field, String value) async {
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

const _row = {
  'programId': 'quiet_start',
  'name_en': 'Quiet start',
  'name_ar': 'bidaya',
  'weeks': '4',
  'daysPerWeek': '3',
  'sessionLength': '20',
  'quiet': 'true',
  'equipment': 'none',
};

void main() {
  testWidgets('a session is built from an exercise and saved with the row', (
    tester,
  ) async {
    _phone(tester);
    (Map<String, String>, List<AuthoredSession>, bool)? saved;
    await tester.pumpWidget(
      _host(
        ContentFormView(
          collection: ContentCollection.programmes,
          values: _row,
          exercises: const [('glute_bridge', 'Glute bridge')],
          onSaveProgramme: (values, sessions, published) =>
              saved = (values, sessions, published),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Add a session'));
    await _type(tester, _labelled('Session title (English)'), 'Floor strength');
    await _type(tester, _labelled('Session title (Arabic)'), 'quwwa');
    // Written for pregnancy as well as for everyone.
    await _tap(tester, find.text('Pregnant'));
    await _tap(tester, find.text('Add a move'));
    await _tap(tester, find.byType(DropdownButton<String>));
    await tester.tap(find.text('Glute bridge').last);
    await tester.pumpAndSettle();
    await _type(tester, _labelled('Reps'), '12');
    await _type(
      tester,
      _labelled('Safety note (English)'),
      'Stop if it hurts.',
    );
    await _tap(tester, find.text('Show this programme to members'));
    await _tap(tester, find.text('Save'));

    expect(saved, isNotNull);
    final (values, sessions, published) = saved!;
    expect(values['programId'], 'quiet_start');
    expect(published, isTrue);
    final session = sessions.single;
    expect(session.titleEn, 'Floor strength');
    expect(session.lifeStages, {LifeStage.none, LifeStage.pregnant});
    final move = session.moves.single;
    expect(move.exerciseId, 'glute_bridge');
    expect(move.sets, 3);
    expect(move.reps, 12);
    expect(move.holdSeconds, isNull);
    expect(move.restSeconds, 60);
    expect(move.safetyEn, 'Stop if it hurts.');
  });

  testWidgets('reps and a hold together are refused beside the field', (
    tester,
  ) async {
    _phone(tester);
    var saves = 0;
    await tester.pumpWidget(
      _host(
        ContentFormView(
          collection: ContentCollection.programmes,
          values: _row,
          exercises: const [('glute_bridge', 'Glute bridge')],
          onSaveProgramme: (_, _, _) => saves++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Add a session'));
    await _tap(tester, find.text('Add a move'));
    await _type(tester, _labelled('Reps'), '12');
    await _type(tester, _labelled('Hold, seconds'), '30');
    await _tap(tester, find.text('Save'));
    expect(saves, 0);
    expect(find.text('Reps or a hold, not both.'), findsOneWidget);
    expect(find.text('Required'), findsWidgets, reason: 'no exercise chosen');
  });

  testWidgets('with no exercises it says to add some first', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        const ContentFormView(
          collection: ContentCollection.programmes,
          values: _row,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Add a session'));
    expect(find.text('Add exercises to the library first.'), findsOneWidget);
    expect(find.text('Add a move'), findsNothing);
  });

  testWidgets('it opens again on the saved sessions, in Arabic too', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        ContentFormView(
          collection: ContentCollection.programmes,
          values: _row,
          exercises: const [('glute_bridge', 'Glute bridge')],
          published: true,
          sessions: const [
            AuthoredSession(
              sessionId: 's1',
              titleEn: 'Floor strength',
              titleAr: 'quwwa',
              minutes: 25,
              lifeStages: {LifeStage.postpartum},
              moves: [
                AuthoredMove(
                  exerciseId: 'glute_bridge',
                  nameEn: 'Glute bridge',
                  nameAr: 'jisr',
                  sets: 2,
                  holdSeconds: 30,
                ),
              ],
            ),
          ],
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Floor strength'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });
}
