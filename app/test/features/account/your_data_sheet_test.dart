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
    expect(find.textContaining('Three things are kept'), findsOneWidget);
    expect(find.textContaining('There is no server'), findsNothing);
  });

  testWidgets('offline, nothing was deleted and the sheet stays open', (
    tester,
  ) async {
    final results = await _open(
      tester,
      onDelete: () async => AccountDeletionResult.offline,
    );
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
    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();
    expect(results, [AccountDeletionResult.unfinished]);
  });

  testWidgets('cancel returns nothing', (tester) async {
    final results = await _open(
      tester,
      onDelete: () async => AccountDeletionResult.done,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });

  testWidgets('reads in Arabic', (tester) async {
    await _open(
      tester,
      onDelete: () async => AccountDeletionResult.done,
      locale: const Locale('ar'),
    );
    expect(find.textContaining('خوادمنا'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
