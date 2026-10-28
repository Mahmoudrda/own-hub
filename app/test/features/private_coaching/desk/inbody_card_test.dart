// What the coach reads of her client's InBody numbers on the desk, and the
// starting point offered from them: figures only where the safety rules allow.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/inbody_scan.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/desk_widgets.dart';
import 'package:own_hub/l10n/app_l10n.dart';

const _scan = InBodyScan(
  weightKg: 64.5,
  bodyFatPercent: 26.6,
  skeletalMuscleMassKg: 24.8,
  bmrKcal: 1340,
);

Future<void> _show(
  WidgetTester t,
  Intake intake, {
  Locale locale = const Locale('en'),
}) async {
  t.view.physicalSize = const Size(1170, 4000);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: IntakeAnswersCard(intake)),
      ),
    ),
  );
}

Intake _intake({
  InBodyScan? scan = _scan,
  String? stage,
  bool eating = false,
}) => Intake(
  goal: 'loseSteadily',
  daysPerWeek: 3,
  lifeStage: stage,
  eatingHistory: eating,
  inbodyScan: scan,
);

String _line(WidgetTester t) =>
    t.widget<Text>(find.byKey(const ValueKey('inbody-suggestion'))).data!;

void main() {
  testWidgets('shows her numbers and a starting point, in English', (t) async {
    await _show(t, _intake());
    expect(find.text('InBody numbers'), findsOneWidget);
    expect(find.text('64.5'), findsOneWidget);
    expect(find.text('26.6'), findsOneWidget);
    expect(find.text('24.8'), findsOneWidget);
    expect(find.text('1,340'), findsOneWidget);
    expect(_line(t), 'A place to start: 1,566 kcal and 103 g protein a day');
  });

  testWidgets('says it in Egyptian Arabic with Western digits', (t) async {
    await _show(t, _intake(), locale: const Locale('ar'));
    expect(find.text('أرقام الـ InBody'), findsOneWidget);
    expect(_line(t), 'نقطة بداية: 1,566 سعرة و103 جم بروتين في اليوم');
  });

  for (final stage in ['pregnant', 'postpartum']) {
    testWidgets('a $stage client gets no figure, and a calm line', (t) async {
      await _show(t, _intake(stage: stage));
      expect(
        _line(t),
        'No target is suggested while she is pregnant or after a birth. '
        'Set her food with her doctor.',
      );
    });
  }

  testWidgets('an eating-history answer gets no figure either', (t) async {
    await _show(t, _intake(eating: true));
    expect(
      _line(t),
      'No target is suggested for her. Her answers ask you to guide her '
      'food yourself.',
    );
    expect(RegExp(r'\d').hasMatch(_line(t)), isFalse, reason: 'no figure');
  });

  testWidgets('a sheet without a metabolic rate suggests nothing', (t) async {
    await _show(t, _intake(scan: const InBodyScan(weightKg: 64.5)));
    expect(
      _line(t),
      'There is not enough on her sheet to suggest a target. Set it by hand.',
    );
  });

  testWidgets('no numbers, no card', (t) async {
    await _show(t, _intake(scan: null));
    expect(find.text('InBody numbers'), findsNothing);
    expect(find.byKey(const ValueKey('inbody-suggestion')), findsNothing);
  });
}
