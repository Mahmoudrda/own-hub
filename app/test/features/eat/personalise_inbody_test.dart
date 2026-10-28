// "Read my InBody sheet" on the Personalise sheet: weight and height from the
// sheet she confirms, kept on this phone, with the sheet's budgets intact.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/eat/presentation/personalise_sheet.dart';
import 'package:own_hub/features/onboarding/domain/body_data.dart';
import 'package:own_hub/features/private_coaching/data/inbody_ocr.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/app_sheet.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';

class _Ocr implements InBodyOcr {
  @override
  Future<String?> readPhoto() async =>
      'Height 164 cm\nWeight 64.5 kg\nPBF 26.6 %\nBMR 1340 kcal';
}

class _Host extends StatefulWidget {
  const _Host({required this.open});

  final Future<BodyData?> Function(BuildContext) open;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  BodyData? saved;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey('open'),
        onPressed: () async {
          final body = await widget.open(context);
          setState(() => saved = body);
        },
        child: const Text('open'),
      ),
    ),
  );
}

Future<_HostState> _pump(
  WidgetTester tester,
  Future<BodyData?> Function(BuildContext) open, {
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
      home: _Host(open: open),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  return tester.state<_HostState>(find.byType(_Host));
}

Future<BodyData?> _panel(BuildContext context, {bool inbody = true}) =>
    showAppSheet<BodyData>(
      context: context,
      children: [
        PersonalisePanel(
          current: BodyData.empty,
          inbody: inbody,
          inbodyOcr: _Ocr(),
        ),
      ],
    );

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
  testWidgets(
    'weight and height come from the confirmed sheet; age stays hers',
    (tester) async {
      final host = await _pump(tester, _panel);
      await tester.tap(find.byKey(const ValueKey('personalise-inbody')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('inbody-choose')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inbody-fat-field')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('inbody-confirm-btn')));
      await tester.pumpAndSettle();

      expect(_text(tester, 'personalise-weight'), '64.5');
      expect(_text(tester, 'personalise-height'), '164');
      expect(_text(tester, 'personalise-age'), '');
      await tester.enterText(
        find.byKey(const ValueKey('personalise-age')),
        '31',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('personalise-save')));
      await tester.pumpAndSettle();
      expect(
        host.saved,
        const BodyData(weightKg: 64.5, heightCm: 164, ageYears: 31),
      );
    },
  );

  testWidgets('closing the sheet without confirming changes nothing', (
    tester,
  ) async {
    await _pump(tester, _panel);
    await tester.tap(find.byKey(const ValueKey('personalise-inbody')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inbody-choose')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(195, 20)); // the scrim
    await tester.pumpAndSettle();
    expect(_text(tester, 'personalise-weight'), '');
    expect(_text(tester, 'personalise-height'), '');
  });

  testWidgets('without the switch there is no row', (tester) async {
    await _pump(tester, (c) => _panel(c, inbody: false));
    expect(find.byKey(const ValueKey('personalise-inbody')), findsNothing);
  });

  for (final on in [true, false]) {
    testWidgets(
      'the switch ${on ? 'on' : 'off'} decides what the real sheet offers',
      (tester) async {
        final flags = AppRouter.featureFlags;
        addTearDown(() => AppRouter.featureFlags = flags);
        AppRouter.featureFlags = flags.with_(<Feature, bool>{
          Feature.inbodyScan: on,
        });
        await _pump(
          tester,
          (c) => showPersonaliseSheet(context: c, current: BodyData.empty),
        );
        expect(
          find.byKey(const ValueKey('personalise-inbody')),
          on ? findsOneWidget : findsNothing,
        );
      },
    );
  }

  group('budgets', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final size in const [Size(390, 844), Size(375, 667)]) {
        for (final scale in const [1.0, 2.0]) {
          testWidgets(
            '${locale.languageCode} ${size.width.toInt()}x${size.height.toInt()} '
            'x$scale: five controls at most, one primary, no overflow',
            (tester) async {
              await _pump(
                tester,
                _panel,
                locale: locale,
                scale: scale,
                size: size,
              );
              expect(
                countControlsAboveFold(tester, includeChrome: false),
                lessThanOrEqualTo(5),
              );
              expect(filledPrimaryActions(tester), lessThanOrEqualTo(1));
              expect(tester.takeException(), isNull);
              expect(
                tester
                    .widget<AppButton>(
                      find.byKey(const ValueKey('personalise-inbody')),
                    )
                    .variant,
                AppButtonVariant.text,
              );
            },
          );
        }
      }
    }
  });
}
