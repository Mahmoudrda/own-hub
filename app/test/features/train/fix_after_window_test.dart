// R08 closed without saving goes back rather than leaving a blank page, and a
// logged session comes off her week only on purpose, with Undo.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/train/presentation/change_set_view.dart';
import 'package:own_hub/features/train/presentation/finished_view.dart';
import 'package:own_hub/features/train/presentation/logged_from_memory_view.dart';
import 'package:own_hub/features/train/presentation/session_removal.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  home: child,
);

void main() {
  group('R08 closed without saving', () {
    testWidgets('closing the sheet without saving goes back', (tester) async {
      var closed = 0;
      await tester.pumpWidget(_host(ChangeSetView(onClose: () => closed++)));
      await tester.pumpAndSettle();
      expect(find.text('What did you do?'), findsOneWidget);

      // Dismiss the sheet the way she would: tap the scrim above it.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(closed, 1);
    });
  });

  group('removing a logged session', () {
    testWidgets('R10 and R12 offer it only when told how', (tester) async {
      await tester.pumpWidget(_host(const LoggedFromMemoryView()));
      await tester.pumpAndSettle();
      expect(find.text('Remove this session'), findsNothing);

      await tester.pumpWidget(_host(LoggedFromMemoryView(onRemove: () {})));
      await tester.pumpAndSettle();
      expect(find.text('Remove this session'), findsOneWidget);

      await tester.pumpWidget(_host(FinishedView(onRemove: () {})));
      await tester.pump(const Duration(seconds: 3));
      // On R10 it is in the "…", so the peak stays the peak.
      expect(find.text('Remove this session'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('overflow-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Remove this session'), findsOneWidget);
    });

    testWidgets('asks first, then removes with Undo', (tester) async {
      final bus = LogCommandBus();
      addTearDown(bus.dispose);
      var removed = 0;
      var left = 0;
      await tester.pumpWidget(
        _host(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => removeSessionWithUndo(
                  context,
                  bus: bus,
                  describe: 'Session removed · your week is at 0 of 3',
                  commit: () async => removed++,
                  then: () => left++,
                ),
                child: const Text('remove'),
              ),
            ),
          ),
        ),
      );

      // Keeping it is the filled answer, and keeps it.
      await tester.tap(find.text('remove'));
      await tester.pumpAndSettle();
      expect(find.text('Remove this session?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(left, 0);

      // Removing offers Undo, and Undo means nothing was removed.
      await tester.tap(find.text('remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove it'));
      await tester.pump();
      // The sheet's own exit, then the bar's entrance.
      await tester.pump(const Duration(milliseconds: 600));
      expect(left, 1);
      expect(
        find.text('Session removed · your week is at 0 of 3'),
        findsOneWidget,
      );
      await tester.tap(find.text('Undo'));
      await tester.pump(const Duration(seconds: 6));
      expect(removed, 0);

      // Left alone, the removal lands when the window closes.
      await tester.tap(find.text('remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove it'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(removed, 1);
    });
  });
}
