// C15 — Checked by a woman, no photo kept.
//
// The niqab path, and P0-VER-05: **no selfie is requested at any point.** The
// strongest assertion available in a widget test is that both options submit a
// niqab-friendly method and that nothing on this screen can open a camera — the
// view does not import the capture layer at all, so there is no code path from
// here to C11.
//
// The rest is ordinary but load-bearing copy: only women review these checks,
// nothing is recorded, and the ID card does the same work it does everywhere
// else.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/signup/domain/verification_fake.dart';
import 'package:own_hub/features/signup/presentation/woman_reviewer_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_card.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

void main() {
  testWidgets('offers two ways to be checked without a photograph', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(WomanReviewerView(repository: FakeVerificationRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Checked by a woman, no photo kept'), findsOneWidget);
    expect(find.text('A short video check'), findsOneWidget);
    expect(find.text('In person at a ladies-only gym'), findsOneWidget);
    expect(
      find.text('12 partner gyms in Cairo, Giza and Alexandria.'),
      findsOneWidget,
    );
    expect(find.text('Book the video check'), findsOneWidget);
  });

  testWidgets('says plainly that no camera is asked for', (tester) async {
    await tester.pumpWidget(
      _host(WomanReviewerView(repository: FakeVerificationRepository())),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'If you do not show your face to a camera, nothing here asks you to',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Nothing is recorded or kept'), findsOneWidget);
    expect(
      find.textContaining('Only women review these checks'),
      findsOneWidget,
    );
  });

  testWidgets('P0-VER-05 — the video path never asks for a selfie', (
    tester,
  ) async {
    final repository = FakeVerificationRepository();
    final booked = <ReviewerPath>[];
    await tester.pumpWidget(
      _host(WomanReviewerView(repository: repository, onBooked: booked.add)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Book the video check'));
    await tester.pumpAndSettle();

    expect(repository.submitted, [VerificationMethod.niqabFriendly]);
    expect(booked, [ReviewerPath.video]);
    expect(
      repository.current,
      isA<VerificationAwaitingReviewer>(),
      reason: 'she waits for a reviewer, she is not rejected',
    );
  });

  testWidgets('the gym path is niqab-friendly too', (tester) async {
    final repository = FakeVerificationRepository();
    final booked = <ReviewerPath>[];
    await tester.pumpWidget(
      _host(WomanReviewerView(repository: repository, onBooked: booked.add)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('In person at a ladies-only gym'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book the video check'));
    await tester.pumpAndSettle();

    expect(repository.submitted, [VerificationMethod.niqabFriendly]);
    expect(booked, [ReviewerPath.gym]);
  });

  testWidgets('the video check is preselected, and the choice moves', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(WomanReviewerView(repository: FakeVerificationRepository())),
    );
    await tester.pumpAndSettle();

    AppCard cardBehind(String label) => tester.widget<AppCard>(
      find.ancestor(of: find.text(label), matching: find.byType(AppCard)).first,
    );

    expect(cardBehind('A short video check').variant, AppCardVariant.selected);

    await tester.tap(find.text('In person at a ladies-only gym'));
    await tester.pumpAndSettle();

    expect(
      cardBehind('In person at a ladies-only gym').variant,
      AppCardVariant.selected,
    );
    expect(cardBehind('A short video check').variant, AppCardVariant.outlined);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(
        WomanReviewerView(repository: FakeVerificationRepository()),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تراجعها امرأة، ولا تُحفظ أي صورة'), findsOneWidget);
    expect(find.text('احجزي تحقّق الفيديو'), findsOneWidget);
    expect(find.text('Checked by a woman, no photo kept'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        WomanReviewerView(repository: FakeVerificationRepository()),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
