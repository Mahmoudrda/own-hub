// S4: A02's "Your data" sheet in the account build. With an account it says
// the server copy goes too and names what is kept; offline it says nothing
// was deleted and stays open; it never claims a deletion the server did not
// report.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/account/domain/account_deletion_service.dart';
import 'package:own_hub/features/account/presentation/your_data_sheet.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Future<List<AccountDeletionResult?>> _open(
  WidgetTester tester, {
  required Future<AccountDeletionResult> Function() onDelete,
  bool hasAccount = true,
  Locale locale = const Locale('en'),
}) async {
  final results = <AccountDeletionResult?>[];
  // A phone, not the 800x600 default: the sheet now also carries the
  // timing line and what is kept, and its buttons sit below them.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(locale),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => results.add(
              await showYourDataSheet(
                context,
                onDelete: onDelete,
                hasAccount: hasAccount,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('with an account it says the server copy goes, and what stays', (
    tester,
  ) async {
    await _open(tester, onDelete: () async => AccountDeletionResult.done);
    expect(
      find.textContaining('removes it from our servers and clears this phone'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Some things are kept on purpose'),
      findsOneWidget,
    );
    // The fraud signals and the access log, which expire on their own.
    expect(
      find.textContaining('180 days after the last attempt'),
      findsOneWidget,
    );
    expect(find.textContaining('after one year'), findsOneWidget);
    // One timing, the same as the privacy policy.
    expect(find.textContaining('usually takes under a minute'), findsOneWidget);
    expect(find.textContaining('It happens at once'), findsNothing);
    expect(find.textContaining('There is no server'), findsNothing);
  });

  testWidgets('offline, nothing was deleted and the sheet stays open', (
    tester,
  ) async {
    final results = await _open(
      tester,
      onDelete: () async => AccountDeletionResult.offline,
    );
    await tester.ensureVisible(find.text('Delete everything'));
    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();
    expect(results, isEmpty, reason: 'the sheet did not close');
    expect(find.textContaining('so nothing was deleted'), findsOneWidget);
    expect(find.byType(YourDataSheet), findsOneWidget);
  });

  testWidgets('an unfinished server deletion is reported as unfinished', (
    tester,
  ) async {
    final results = await _open(
      tester,
      onDelete: () async => AccountDeletionResult.unfinished,
    );
    await tester.ensureVisible(find.text('Delete everything'));
    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();
    expect(results, [AccountDeletionResult.unfinished]);
  });

  testWidgets('cancel returns nothing', (tester) async {
    final results = await _open(
      tester,
      onDelete: () async => AccountDeletionResult.done,
    );
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });

  testWidgets('M8: "Ask for a copy" opens the request', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    var asked = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: YourDataSheet(
              hasAccount: true,
              onDelete: () async => AccountDeletionResult.done,
              onAskForCopy: () => asked++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Want a copy of your data?'), findsOneWidget);
    expect(find.textContaining('not built yet'), findsNothing);
    await tester.ensureVisible(find.text('Ask for a copy'));
    await tester.tap(find.text('Ask for a copy'));
    expect(asked, 1);
  });

  testWidgets('M8: with no mailbox there is no button that goes nowhere', (
    tester,
  ) async {
    await _open(tester, onDelete: () async => AccountDeletionResult.done);
    expect(find.text('Ask for a copy'), findsNothing);
  });

  testWidgets('reads in Arabic', (tester) async {
    await _open(
      tester,
      onDelete: () async => AccountDeletionResult.done,
      locale: const Locale('ar'),
    );
    expect(
      find.textContaining('حذف حسابك بيشيله من سيرفراتنا'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
