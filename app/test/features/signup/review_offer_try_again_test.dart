// C12's review offer said "or go back and try again" on a screen with no back
// control. The screen already knows how to start again (onRetake, to C10), so
// the offer now carries that control and says "or try again".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/signup/domain/verification_fake.dart';
import 'package:own_hub/features/signup/presentation/checking_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('the offer has a way to try again ($locale)', (tester) async {
      var retakes = 0;
      var reviewers = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: CheckingView(
            repository: FakeVerificationRepository(
              const VerificationState.reviewOffered(),
            ),
            onRetake: () => retakes++,
            onAskForReviewer: () => reviewers++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppL10n.of(tester.element(find.byType(CheckingView)));

      expect(find.text(l10n.theAutomaticCheckCouldNotStartJust), findsNothing);
      expect(
        find.text(l10n.theAutomaticCheckCouldNotStartJust_1od6p),
        findsOneWidget,
      );
      expect(find.text(l10n.askForAWomanReviewer), findsOneWidget);

      await tester.tap(find.text(l10n.tryAgain));
      expect(retakes, 1);
    });
  }
}
