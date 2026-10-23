// R09 and R13: the in-page Undo lives exactly as long as the window it offers.
//
// The bar used to keep Undo drawn for the whole rest, and on R13 for as long as
// she stayed, while `handle.undo()` had been returning false since the fifth
// second. A tap then did nothing at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/train/presentation/mid_set_view.dart';
import 'package:own_hub/features/train/presentation/move_logged_view.dart';
import 'package:own_hub/features/train/presentation/resting_view.dart';
import 'package:own_hub/features/train/presentation/session_notice.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_undo_bar.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  home: child,
);

LogHandle _log(LogCommandBus bus, List<String> writes) => bus.submit(
  UndoableLog(
    describe: 'Set 1 saved · 10 reps',
    commit: () async => writes.add('set'),
  ),
);

void main() {
  testWidgets('R09: Undo works inside the window', (tester) async {
    final bus = LogCommandBus();
    addTearDown(bus.dispose);
    final writes = <String>[];
    var undone = 0;
    final handle = _log(bus, writes);

    await tester.pumpWidget(
      _host(
        RestingView(autoStart: false, handle: handle, onUndo: () => undone++),
      ),
    );
    await tester.pump();

    expect(find.text('Set 1 saved · 10 reps'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(undone, 1);
    expect(writes, isEmpty);
  });

  testWidgets('R09: once the window closes Undo is gone, the statement stays', (
    tester,
  ) async {
    final bus = LogCommandBus();
    addTearDown(bus.dispose);
    final writes = <String>[];
    var undone = 0;
    final handle = _log(bus, writes);

    await tester.pumpWidget(
      _host(
        RestingView(autoStart: false, handle: handle, onUndo: () => undone++),
      ),
    );
    await tester.pump();
    expect(find.text('Undo'), findsOneWidget);

    await tester.pump(kUndoWindow + const Duration(milliseconds: 50));
    await tester.pump();

    expect(writes, ['set']);
    expect(find.text('Undo'), findsNothing);
    expect(find.text('Set 1 saved · 10 reps'), findsOneWidget);
    expect(undone, 0);
  });

  testWidgets('R13: once the window closes Undo is gone', (tester) async {
    final bus = LogCommandBus();
    addTearDown(bus.dispose);
    final writes = <String>[];
    final handle = _log(bus, writes);

    await tester.pumpWidget(_host(MoveLoggedView(handle: handle)));
    await tester.pump();
    expect(find.text('Undo'), findsOneWidget);

    await tester.pump(kUndoWindow + const Duration(milliseconds: 50));
    await tester.pump();

    expect(writes, ['set']);
    expect(find.text('Undo'), findsNothing);
    expect(find.text('Set 1 saved · 10 reps'), findsOneWidget);
  });

  testWidgets('a handle already closed draws no Undo at all', (tester) async {
    final bus = LogCommandBus();
    final handle = _log(bus, <String>[]);
    await bus.flushAll();

    await tester.pumpWidget(
      _host(
        Scaffold(
          body: AppLiveUndoBar(
            handle: handle,
            message: handle.describe,
            undoLabel: 'Undo',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Undo'), findsNothing);
    expect(find.text('Set 1 saved · 10 reps'), findsOneWidget);
  });

  testWidgets('R07 draws a swap in the page, with Undo', (tester) async {
    final bus = LogCommandBus();
    addTearDown(bus.dispose);
    var undone = 0;
    final notice = SessionNotice(
      handle: bus.submit(
        UndoableLog(
          describe: 'Swapped to Glute bridge for today',
          commit: () async {},
        ),
      ),
      onUndo: () => undone++,
    );

    await tester.pumpWidget(_host(MidSetView(notice: notice)));
    await tester.pump();
    expect(find.text('Swapped to Glute bridge for today'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(undone, 1);
  });
}
