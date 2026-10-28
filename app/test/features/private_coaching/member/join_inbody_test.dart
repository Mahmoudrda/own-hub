// Adding InBody numbers to a request to join a coach: optional, confirmed
// number by number, and sent only with its own tick. The tick's words hash
// to what the server accepts.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/private_coaching/data/inbody_ocr.dart';
import 'package:own_hub/features/private_coaching/presentation/member/join_coach_sheet.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_button.dart';

import 'member_browse_test.dart'
    show MemberRepo, coach, fillJoin, host, phone, pkg, tapText;

class _Ocr implements InBodyOcr {
  @override
  Future<String?> readPhoto() async =>
      'Weight 64.5 kg\nPBF 26.6 %\nSMM 24.8 kg\nBMR 1340 kcal';
}

String _sha(String text) => sha256.convert(utf8.encode(text)).toString();

Future<MemberRepo> _form(WidgetTester tester) async {
  phone(tester);
  final repo = MemberRepo();
  await tester.pumpWidget(
    host(
      Scaffold(
        body: SingleChildScrollView(
          child: JoinCoachForm(
            repository: repo,
            coach: coach('c2', 'Amal'),
            package: pkg('a', 2000),
            inbodyOcr: _Ocr(),
          ),
        ),
      ),
    ),
  );
  await fillJoin(tester);
  return repo;
}

Future<void> _attach(WidgetTester tester) async {
  await tapText(tester, find.byKey(const ValueKey('join-inbody-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('inbody-choose')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('inbody-confirm-btn')));
  await tester.pumpAndSettle();
}

Future<void> _tickAll(WidgetTester tester) async {
  final boxes = find.byType(CheckboxListTile);
  for (var i = 0; i < tester.widgetList(boxes).length; i++) {
    await tapText(tester, boxes.at(i));
  }
}

bool _sendEnabled(WidgetTester tester) =>
    tester
        .widget<AppButton>(find.widgetWithText(AppButton, 'Send request'))
        .onPressed !=
    null;

void main() {
  testWidgets('the row is there, optional, and says the photo is never seen', (
    tester,
  ) async {
    await _form(tester);
    expect(find.text('Add your InBody numbers'), findsOneWidget);
    expect(
      find.text('Optional. Your coach sees the numbers, never the photo.'),
      findsOneWidget,
    );
    expect(find.text('Read my InBody sheet'), findsOneWidget);
  });

  testWidgets('with numbers attached the request needs its own tick', (
    tester,
  ) async {
    await _form(tester);
    await _attach(tester);
    expect(find.text('InBody numbers added'), findsOneWidget);
    final boxes = find.byType(CheckboxListTile);
    expect(tester.widgetList(boxes).length, 3, reason: 'share, InBody, stored');

    // The two old ticks alone are not enough.
    await tapText(tester, boxes.at(0));
    await tapText(tester, boxes.at(2));
    expect(_sendEnabled(tester), isFalse);
    await tapText(tester, boxes.at(1));
    expect(_sendEnabled(tester), isTrue);
  });

  testWidgets('the request carries the numbers and the hash of the tick', (
    tester,
  ) async {
    final repo = await _form(tester);
    await _attach(tester);
    await _tickAll(tester);
    await tapText(tester, find.text('Send request'));
    await tester.pumpAndSettle();

    final scan = repo.lastIntake!.inbodyScan!;
    expect(scan.weightKg, 64.5);
    expect(scan.bodyFatPercent, 26.6);
    expect(scan.skeletalMuscleMassKg, 24.8);
    expect(scan.bmrKcal, 1340);
    expect(scan.heightCm, isNull, reason: 'not asked for a coach');
    expect(repo.lastIntake!.toRequest()['inbody'], isA<Map<String, Object>>());

    final l10n = lookupAppL10n(const Locale('en'));
    expect(
      repo.lastConsent!['inbodyHash'],
      _sha(l10n.iShareMyInbodyNumbersWithName('Amal')),
    );
    expect(
      repo.lastConsent!['inbodyHash'],
      _sha(
        'I share my InBody numbers with Amal. They are body measurements, '
        'stored with my other answers in Frankfurt, Germany, outside Egypt.',
      ),
    );
  });

  testWidgets('removing them takes the tick and the numbers away', (
    tester,
  ) async {
    final repo = await _form(tester);
    await _attach(tester);
    await tapText(tester, find.byKey(const ValueKey('join-inbody-remove')));
    expect(find.text('Add your InBody numbers'), findsOneWidget);
    expect(tester.widgetList(find.byType(CheckboxListTile)).length, 2);
    await _tickAll(tester);
    await tapText(tester, find.text('Send request'));
    await tester.pumpAndSettle();
    expect(repo.lastIntake!.inbodyScan, isNull);
    expect(repo.lastIntake!.toRequest().containsKey('inbody'), isFalse);
    expect(repo.lastConsent!.containsKey('inbodyHash'), isFalse);
  });

  testWidgets('the Arabic tick is the Arabic text the server knows', (
    tester,
  ) async {
    expect(
      lookupAppL10n(const Locale('ar')).iShareMyInbodyNumbersWithName('أمل'),
      'أنا بشارك أرقام الـ InBody بتاعتي مع أمل. دي قياسات جسم، وبتتخزّن مع '
      'باقي إجاباتي في فرانكفورت بألمانيا، يعني برّه مصر.',
    );
  });

  testWidgets('switched off, there is no row', (tester) async {
    final flags = AppRouter.featureFlags;
    AppRouter.featureFlags = flags.with_(<Feature, bool>{
      Feature.inbodyScan: false,
    });
    addTearDown(() => AppRouter.featureFlags = flags);
    phone(tester);
    await tester.pumpWidget(
      host(
        Scaffold(
          body: SingleChildScrollView(
            child: JoinCoachForm(
              repository: MemberRepo(),
              coach: coach('c2', 'Amal'),
              package: pkg('a', 2000),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Add your InBody numbers'), findsNothing);
  });
}
