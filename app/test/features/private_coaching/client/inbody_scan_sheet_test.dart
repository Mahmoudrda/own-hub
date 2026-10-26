import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/inbody_scan.dart';
import 'package:own_hub/features/private_coaching/presentation/client/inbody_scan_sheet.dart';
import 'package:own_hub/l10n/app_l10n.dart';

void main() {
  Widget wrap(Widget child, {Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('InBodyScanSheet', () {
    testWidgets('allows manual entry of InBody metrics and saves', (tester) async {
      InBodyScan? saved;
      await tester.pumpWidget(
        wrap(
          InBodyScanSheet(
            onSaved: (s) => saved = s,
          ),
        ),
      );

      await tester.enterText(find.byKey(const ValueKey('inbody-weight-field')), '68.5');
      await tester.enterText(find.byKey(const ValueKey('inbody-height-field')), '165');
      await tester.enterText(find.byKey(const ValueKey('inbody-smm-field')), '26.2');
      await tester.enterText(find.byKey(const ValueKey('inbody-fat-field')), '24.5');
      await tester.enterText(find.byKey(const ValueKey('inbody-bmr-field')), '1420');

      await tester.tap(find.byKey(const ValueKey('inbody-save-btn')));
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!.weightKg, 68.5);
      expect(saved!.heightCm, 165.0);
      expect(saved!.skeletalMuscleMassKg, 26.2);
      expect(saved!.bodyFatPercent, 24.5);
      expect(saved!.bmrKcal, 1420);
    });

    testWidgets('extracts metrics automatically from pasted OCR text', (tester) async {
      InBodyScan? saved;
      await tester.pumpWidget(
        wrap(
          InBodyScanSheet(
            onSaved: (s) => saved = s,
          ),
        ),
      );

      // Open OCR section
      await tester.tap(find.byKey(const ValueKey('inbody-toggle-ocr')));
      await tester.pumpAndSettle();

      const ocrSample = '''
      Weight: 64.5 kg
      SMM: 24.8 kg
      Percent Body Fat: 26.6 %
      BMR: 1340 kcal
      Height: 164.0 cm
      ''';

      await tester.enterText(find.byKey(const ValueKey('inbody-raw-text-field')), ocrSample);
      await tester.tap(find.byKey(const ValueKey('inbody-extract-btn')));
      await tester.pumpAndSettle();

      // Verify fields are populated
      expect(find.text('64.5'), findsOneWidget);
      expect(find.text('24.8'), findsOneWidget);
      expect(find.text('26.6'), findsOneWidget);
      expect(find.text('1340'), findsOneWidget);
      expect(find.text('164.0'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('inbody-save-btn')));
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!.weightKg, 64.5);
      expect(saved!.skeletalMuscleMassKg, 24.8);
      expect(saved!.bodyFatPercent, 26.6);
      expect(saved!.bmrKcal, 1340);
      expect(saved!.heightCm, 164.0);
    });
  });
}
