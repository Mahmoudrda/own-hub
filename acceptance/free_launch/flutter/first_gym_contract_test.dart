// Future real UI, intentionally missing at baseline. No test-only implementation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/presentation/first_gym_guide_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

void main() {
  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets(
      'U0 four short steps, Back and Start work at 200% text in ${locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var started = 0;
        var closed = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            theme: buildTheme(locale),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: FirstGymGuideView(
              onStartWorkout: () => started++,
              onClose: () => closed++,
            ),
          ),
        );
        Future<void> tap(String key) async {
          final finder = find.byKey(ValueKey(key));
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        expect(find.byKey(const ValueKey('gym-guide-step-0')), findsOneWidget);
        await tap('gym-guide-next');
        await tap('gym-guide-back');
        expect(find.byKey(const ValueKey('gym-guide-step-0')), findsOneWidget);
        for (var i = 1; i <= 3; i++) {
          await tap('gym-guide-next');
          expect(find.byKey(ValueKey('gym-guide-step-$i')), findsOneWidget);
        }
        expect(started, 0);
        expect(closed, 0);
        final semantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        semantics.dispose();
        await tap('gym-guide-start');
        expect(started, 1);
      },
    );
    testWidgets(
      'U0 skipping does not start a workout in ${locale.languageCode}',
      (tester) async {
        var started = 0;
        var closed = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            theme: buildTheme(locale),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: FirstGymGuideView(
              onStartWorkout: () => started++,
              onClose: () => closed++,
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('gym-guide-skip')));
        await tester.pumpAndSettle();
        expect(started, 0);
        expect(closed, 1);
      },
    );
  }
}
