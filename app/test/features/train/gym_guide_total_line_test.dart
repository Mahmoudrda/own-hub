import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/presentation/first_gym_guide_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

void main() {
  testWidgets('the guide tells her to log the total, bar included', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildTheme(const Locale('en')),
        home: FirstGymGuideView(onClose: () {}, onStartWorkout: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Log the total, bar included.'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('gym-guide-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gym-guide-next')));
    await tester.pumpAndSettle();
    expect(find.text('Log the total, bar included.'), findsOneWidget);
  });
}
