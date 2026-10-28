import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/data/inbody_ocr.dart';
import 'package:own_hub/features/private_coaching/domain/inbody_scan.dart';
import 'package:own_hub/features/private_coaching/presentation/client/inbody_scan_sheet.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/ui/app_button.dart';

import '../../../helpers/control_counter.dart';
import '../../../helpers/primary_actions.dart';

class FakeOcr implements InBodyOcr {
  FakeOcr(this.text);

  final String? text;
  int calls = 0;

  @override
  Future<String?> readPhoto() async {
    calls++;
    return text;
  }
}

/// A read that finishes only when the test says so.
class HeldOcr implements InBodyOcr {
  final done = Completer<String?>();

  @override
  Future<String?> readPhoto() => done.future;
}

const _sheet = '''
Height: 164.0 cm
Weight: 64.5 kg
SMM (Skeletal Muscle Mass): 24.8 kg
Body Fat Mass: 17.2 kg
Percent Body Fat (PBF): 26.6 %
BMI: 24.0 kg/m2
Basal Metabolic Rate (BMR): 1340 kcal
''';

const _pounds = 'Weight: 142.3 lb\nPBF 26.6 %\nBMR 1340 kcal';

/// Opens the sheet from a button and records what it hands back.
class _Host extends StatefulWidget {
  const _Host({required this.mode, required this.ocr});

  final InBodyMode mode;
  final InBodyOcr ocr;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  InBodyScan? result;
  bool closed = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        key: const ValueKey('open'),
        onPressed: () async {
          final scan = await showInBodyScanSheet(
            context: context,
            mode: widget.mode,
            ocr: widget.ocr,
          );
          setState(() {
            result = scan;
            closed = true;
          });
        },
        child: Text(result == null ? 'open' : 'got ${result!.toJson()}'),
      ),
    ),
  );
}

Future<_HostState> _open(
  WidgetTester tester, {
  InBodyMode mode = InBodyMode.forCoach,
  String? text,
  InBodyOcr? ocr,
  Locale locale = const Locale('en'),
  double scale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: app!,
      ),
      home: _Host(mode: mode, ocr: ocr ?? FakeOcr(text)),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  return tester.state<_HostState>(find.byType(_Host));
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

void main() {
  group('reading a photo', () {
    testWidgets('fills the form, and nothing leaves until she confirms', (
      tester,
    ) async {
      final host = await _open(tester, text: _sheet);
      await _tap(tester, 'inbody-choose');

      expect(_text(tester, 'inbody-weight-field'), '64.5');
      expect(_text(tester, 'inbody-fat-field'), '26.6');
      expect(_text(tester, 'inbody-smm-field'), '24.8');
      expect(_text(tester, 'inbody-bmr-field'), '1340');
      expect(
        host.closed,
        isFalse,
        reason: 'the confirm screen is always shown',
      );
      expect(host.result, isNull);

      await _tap(tester, 'inbody-confirm-btn');
      expect(host.closed, isTrue);
      expect(
        host.result,
        const InBodyScan(
          weightKg: 64.5,
          bodyFatPercent: 26.6,
          skeletalMuscleMassKg: 24.8,
          bmrKcal: 1340,
        ),
      );
    });

    testWidgets('while it reads she sees progress and can type instead', (
      tester,
    ) async {
      final ocr = HeldOcr();
      await _open(tester, ocr: ocr);
      await tester.tap(find.byKey(const ValueKey('inbody-choose')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('inbody-reading-type')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('inbody-weight-field')),
        '70',
      );
      await tester.pump();

      // A read that lands late does not overwrite what she typed.
      ocr.done.complete(_sheet);
      await tester.pumpAndSettle();
      expect(_text(tester, 'inbody-weight-field'), '70');
      expect(_text(tester, 'inbody-fat-field'), '');
    });

    testWidgets('she can correct a number before confirming', (tester) async {
      final host = await _open(tester, text: _sheet);
      await _tap(tester, 'inbody-choose');
      await tester.enterText(
        find.byKey(const ValueKey('inbody-weight-field')),
        '65',
      );
      await tester.pump();
      await _tap(tester, 'inbody-confirm-btn');
      expect(host.result!.weightKg, 65);
    });

    testWidgets('a sheet in pounds is converted and she is told', (
      tester,
    ) async {
      await _open(tester, text: _pounds);
      await _tap(tester, 'inbody-choose');
      expect(_text(tester, 'inbody-weight-field'), '64.5');
      expect(find.byKey(const ValueKey('inbody-note')), findsOneWidget);
      expect(find.textContaining('pounds'), findsOneWidget);
    });

    testWidgets('a sheet that disagrees with itself is flagged', (
      tester,
    ) async {
      await _open(
        tester,
        text: 'Weight 64.5 kg\nBody Fat Mass 25 kg\nPBF 26.6 %\nBMR 1340 kcal',
      );
      await _tap(tester, 'inbody-choose');
      expect(find.textContaining('do not add up'), findsOneWidget);
    });

    testWidgets('a picture with no numbers says so and offers another', (
      tester,
    ) async {
      final host = await _open(tester, text: '');
      await _tap(tester, 'inbody-choose');
      expect(find.byKey(const ValueKey('inbody-unreadable')), findsOneWidget);
      expect(find.byKey(const ValueKey('inbody-weight-field')), findsNothing);
      expect(find.text('Choose another photo'), findsOneWidget);
      expect(host.closed, isFalse);
    });

    testWidgets('choosing nothing leaves her where she was', (tester) async {
      await _open(tester, text: null);
      await _tap(tester, 'inbody-choose');
      expect(find.byKey(const ValueKey('inbody-choose')), findsOneWidget);
      expect(find.byKey(const ValueKey('inbody-unreadable')), findsNothing);
    });
  });

  group('typing the numbers', () {
    testWidgets('is the same form, and reads commas and Arabic digits', (
      tester,
    ) async {
      final host = await _open(tester);
      await _tap(tester, 'inbody-type');
      await tester.enterText(
        find.byKey(const ValueKey('inbody-weight-field')),
        '64,5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('inbody-fat-field')),
        '٢٦٫٦',
      );
      await tester.enterText(
        find.byKey(const ValueKey('inbody-bmr-field')),
        '١٣٤٠',
      );
      await tester.pump();
      await _tap(tester, 'inbody-confirm-btn');
      expect(host.result!.weightKg, 64.5);
      expect(host.result!.bodyFatPercent, 26.6);
      expect(host.result!.bmrKcal, 1340);
    });

    testWidgets(
      'a number outside its range is flagged and cannot be confirmed',
      (tester) async {
        final host = await _open(tester);
        await _tap(tester, 'inbody-type');
        await tester.enterText(
          find.byKey(const ValueKey('inbody-weight-field')),
          '645',
        );
        await tester.pump();
        expect(
          find.text('Check this number, it looks outside the usual range.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<AppButton>(
                find.byKey(const ValueKey('inbody-confirm-btn')),
              )
              .onPressed,
          isNull,
        );
        expect(host.closed, isFalse);
      },
    );

    testWidgets('empty, it cannot be confirmed', (tester) async {
      await _open(tester);
      await _tap(tester, 'inbody-type');
      expect(
        tester
            .widget<AppButton>(find.byKey(const ValueKey('inbody-confirm-btn')))
            .onPressed,
        isNull,
      );
    });
  });

  group('what she is asked for', () {
    testWidgets(
      'her own targets: weight and height only, and it says they stay',
      (tester) async {
        final host = await _open(
          tester,
          mode: InBodyMode.forTargets,
          text: _sheet,
        );
        await _tap(tester, 'inbody-choose');
        expect(
          find.byKey(const ValueKey('inbody-weight-field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('inbody-height-field')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('inbody-fat-field')), findsNothing);
        expect(find.byKey(const ValueKey('inbody-bmr-field')), findsNothing);
        expect(
          find.text('Your weight and height stay on this phone.'),
          findsOneWidget,
        );
        await _tap(tester, 'inbody-confirm-btn');
        expect(host.result, const InBodyScan(weightKg: 64.5, heightCm: 164));
      },
    );

    testWidgets(
      'her coach: four numbers, and it says when the coach sees them',
      (tester) async {
        await _open(tester, text: _sheet);
        await _tap(tester, 'inbody-choose');
        expect(find.byKey(const ValueKey('inbody-height-field')), findsNothing);
        expect(
          find.textContaining('only if you tick the box on the request form'),
          findsOneWidget,
        );
      },
    );
  });

  group('budgets', () {
    const sizes = [Size(390, 844), Size(375, 667)];
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final size in sizes) {
        for (final scale in const [1.0, 2.0]) {
          for (final mode in InBodyMode.values) {
            testWidgets(
              '${locale.languageCode} ${size.width.toInt()}x${size.height.toInt()} '
              'x$scale ${mode.name}: at most five controls and one primary, no overflow',
              (tester) async {
                await _open(
                  tester,
                  mode: mode,
                  text: _sheet,
                  locale: locale,
                  scale: scale,
                  size: size,
                );
                var controls = countControlsAboveFold(
                  tester,
                  includeChrome: false,
                );
                expect(controls, lessThanOrEqualTo(5), reason: 'pick');
                expect(filledPrimaryActions(tester), lessThanOrEqualTo(1));
                await _tap(tester, 'inbody-choose');
                controls = countControlsAboveFold(tester, includeChrome: false);
                expect(controls, lessThanOrEqualTo(5), reason: 'confirm');
                expect(filledPrimaryActions(tester), lessThanOrEqualTo(1));
                expect(tester.takeException(), isNull);
              },
            );
          }
        }
      }
    }
  });
}
