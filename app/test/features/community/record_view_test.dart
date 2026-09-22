// M16 — Record. Blur is a camera control, and it is on.
//
// The rule this screen exists to keep is rule 6: blur is on by default, turning
// it off is an explicit per-image act, and the next composition starts blurred
// again. So the default is asserted, and so is the fact that a fresh model
// comes back on after one was built with it off.
//
// The rest is the launch scope, proved as a pair each time: the capability is
// absent while its flag is off, and present the moment the flag moves — which
// is the difference between shipping dark and quietly deleting a feature.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/community/presentation/community_widgets.dart';
import 'package:own_hub/features/community/presentation/create_view_model.dart';
import 'package:own_hub/features/community/presentation/record_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

/// Community on, at its launch scope: photos and text.
///
/// Built from [FeatureFlags.allOff] rather than from `FeatureFlags.shipped`,
/// so every absence asserted below is an absence this file asked for. Borrowing
/// the defaults would make each of these a test of today's switch positions.
final _communityOn = FeatureFlags.allOff.with_(<Feature, bool>{
  Feature.community: true,
  Feature.communityPosts: true,
});
final _videoOn = _communityOn.with_(<Feature, bool>{
  Feature.communityVideo: true,
});
final _voiceOn = _communityOn.with_(<Feature, bool>{
  Feature.communityVoiceNotes: true,
});

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: child,
  );
}

RecordRailButton _rail(WidgetTester tester, String label) => tester
    .widgetList<RecordRailButton>(find.byType(RecordRailButton))
    .firstWhere((b) => b.label == label);

List<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((s) => s.isNotEmpty)
    .toList();

void main() {
  group('rule 6 — blur is on, on the rail, before anything is taken', () {
    testWidgets('the blur control renders selected by default', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(RecordView(model: RecordScreenModel.from(flags: _communityOn))),
      );
      await tester.pumpAndSettle();

      expect(_rail(tester, 'Blur').selected, isTrue);
    });

    testWidgets('the next composition starts with blur on again', (
      tester,
    ) async {
      _phone(tester);

      // She turned it off for one image.
      await tester.pumpWidget(
        _host(
          RecordView(
            model: RecordScreenModel.from(
              flags: _communityOn,
              blurFacesDefault: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_rail(tester, 'Blur').selected, isFalse);

      // The next composition builds a fresh model, and the default is on.
      await tester.pumpWidget(
        _host(RecordView(model: RecordScreenModel.from(flags: _communityOn))),
      );
      await tester.pumpAndSettle();
      expect(
        _rail(tester, 'Blur').selected,
        isTrue,
        reason: 'P0-COM-09: the opt-out applies to that image only',
      );
    });

    testWidgets('toggling blur reports the new position and no dialog', (
      tester,
    ) async {
      _phone(tester);
      bool? asked;
      await tester.pumpWidget(
        _host(
          RecordView(
            model: RecordScreenModel.from(flags: _communityOn),
            onToggleBlur: (value) => asked = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.blur_on));
      await tester.pumpAndSettle();

      expect(asked, isFalse, reason: 'on → off');
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('the modes are the flags, not this file', () {
    testWidgets('no Reel chip while communityVideo is off', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(RecordView(model: RecordScreenModel.from(flags: _communityOn))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Story'), findsOneWidget);
      expect(find.text('Post'), findsOneWidget);
      expect(find.text('Reel'), findsNothing);
      expect(find.byIcon(Icons.videocam), findsNothing);
      expect(find.byIcon(Icons.videocam_outlined), findsNothing);
    });

    testWidgets('the Reel chip returns when the flag moves', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(RecordView(model: RecordScreenModel.from(flags: _videoOn))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reel'), findsOneWidget);
    });

    testWidgets('no Voice control while communityVoiceNotes is off', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(RecordView(model: RecordScreenModel.from(flags: _communityOn))),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_none), findsNothing);
      expect(find.text('Voice'), findsNothing);
    });

    testWidgets('the Voice control returns when the flag moves', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(RecordView(model: RecordScreenModel.from(flags: _voiceOn))),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Voice'),
        findsOneWidget,
        reason:
            'the absence is flag-gated, so nobody has to find a deletion when '
            'the capability is ready',
      );
    });

    testWidgets('nothing composes while the whole feature is dark', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          RecordView(model: RecordScreenModel.from(flags: FeatureFlags.allOff)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NotAvailablePanel), findsOneWidget);
      expect(
        find.byType(RecordRailButton),
        findsNothing,
        reason: 'no rail behind a switched-off feature',
      );
      expect(find.byType(RecordShutterButton), findsNothing);
      expect(find.text('Story'), findsNothing);
    });
  });

  group('capture, publish, and no confirmations', () {
    testWidgets('the shutter and the confirm both fire once, silently', (
      tester,
    ) async {
      _phone(tester);
      var captured = 0;
      var confirmed = 0;
      await tester.pumpWidget(
        _host(
          RecordView(
            model: RecordScreenModel.from(flags: _communityOn),
            onCapture: () => captured++,
            onConfirm: () => confirmed++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Publish'));
      await tester.pumpAndSettle();
      expect(confirmed, 1);
      expect(
        find.byType(AlertDialog),
        findsNothing,
        reason: 'rule 9 — publish gets a five-second undo, never a dialog',
      );

      await tester.tap(find.byType(RecordShutterButton));
      await tester.pumpAndSettle();
      expect(captured, 1);
      expect(
        confirmed,
        1,
        reason: 'taking a picture is not publishing it',
      );
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('choosing a mode reports it', (tester) async {
      _phone(tester);
      RecordMode? chosen;
      await tester.pumpWidget(
        _host(
          RecordView(
            model: RecordScreenModel.from(flags: _communityOn),
            onSelectMode: (mode) => chosen = mode,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();

      expect(chosen, RecordMode.post);
    });
  });

  group('no figure this screen cannot know', () {
    testWidgets('no elapsed readout and no timer duration', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(RecordView(model: RecordScreenModel.from(flags: _communityOn))),
      );
      await tester.pumpAndSettle();

      expect(
        _texts(tester).where((s) => RegExp(r'\d').hasMatch(s)),
        isEmpty,
        reason:
            "the mockup's '0:12 / 1:00' and '15s' would be figures about her "
            'recording that nobody measured',
      );
    });

    testWidgets('the mode labels are the dictionary in Arabic too', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          RecordView(model: RecordScreenModel.from(flags: _communityOn)),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Story'), findsNothing);
      expect(find.text('Post'), findsNothing);
    });
  });
}
