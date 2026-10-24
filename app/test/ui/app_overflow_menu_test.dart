import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_overflow_menu.dart';

Widget _host(
  List<AppOverflowItem> items, {
  Locale locale = const Locale('en'),
  double textScale = 1,
  bool motionOff = false,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: motionOff,
    ),
    child: child!,
  ),
  home: Scaffold(
    appBar: AppBar(actions: [AppOverflowMenu(items: items)]),
  ),
);

void main() {
  var ran = 0;
  var removed = 0;
  List<AppOverflowItem> items() => [
    AppOverflowItem(icon: Icons.edit, label: 'Edit moves', onTap: () => ran++),
    AppOverflowItem(
      icon: Icons.delete_outline,
      label: 'Remove session',
      confirmMessage: 'Remove this session?',
      onTap: () => removed++,
    ),
  ];

  setUp(() {
    ran = 0;
    removed = 0;
  });

  for (final (locale, name) in [
    (const Locale('en'), 'More options'),
    (const Locale('ar'), 'خيارات تانية'),
  ]) {
    testWidgets(
      '${locale.languageCode}: labelled, 48 px, opens and runs a row',
      (tester) async {
        await tester.pumpWidget(_host(items(), locale: locale));
        expect(find.byTooltip(name), findsOneWidget);
        final size = tester.getSize(
          find.byKey(const ValueKey('overflow-menu')),
        );
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));

        await tester.tap(find.byKey(const ValueKey('overflow-menu')));
        await tester.pumpAndSettle();
        final row = find.byKey(const ValueKey('overflow-row-Edit moves'));
        expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(ran, 1);
        expect(
          find.byKey(const ValueKey('overflow-row-Edit moves')),
          findsNothing,
        );
      },
    );
  }

  testWidgets('a destructive row asks first, and can be backed out of', (
    tester,
  ) async {
    await tester.pumpWidget(_host(items()));
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('overflow-row-Remove session')));
    await tester.pumpAndSettle();
    expect(removed, 0);
    expect(find.text('Remove this session?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('overflow-cancel')));
    await tester.pumpAndSettle();
    expect(removed, 0);
    expect(
      find.byKey(const ValueKey('overflow-row-Edit moves')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('overflow-row-Remove session')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('overflow-confirm')));
    await tester.pumpAndSettle();
    expect(removed, 1);
    expect(find.text('Remove this session?'), findsNothing);
  });

  testWidgets('large text and Arabic lay out without overflow', (tester) async {
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      await tester.pumpWidget(_host(items(), locale: locale, textScale: 2));
      await tester.tap(find.byKey(const ValueKey('overflow-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('overflow-row-Remove session')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('with motion off the confirm swap is immediate', (tester) async {
    await tester.pumpWidget(_host(items(), motionOff: true));
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('overflow-row-Remove session')));
    await tester.pump();
    expect(find.text('Remove this session?'), findsOneWidget);
  });
}
