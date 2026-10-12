// A03 — Privacy.
//
// Covers P2-RTL-A03, P2-TXT-A03 and P2-OFF-A03, plus the two rules this screen
// carries: every sharing switch defaults off, and the rule-7 sentence is a fact
// or it is absent.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/features/account/domain/health_backup.dart';
import 'package:own_hub/features/account/domain/privacy_settings.dart';
import 'package:own_hub/features/account/domain/verification_claim.dart';
import 'package:own_hub/features/account/presentation/privacy_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_toggle.dart';

/// The shipped English sentence for rule 7, written out so the test fails if
/// the dictionary entry is ever repointed at different words.
const _rule7 =
    'Your ID and selfie were deleted after the check. We keep the result and '
    'a keyed code of your ID number.';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

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
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

List<AppToggle> _toggles(WidgetTester tester) =>
    tester.widgetList<AppToggle>(find.byType(AppToggle)).toList();

void main() {
  // Three of the four switches decide what the community sees and the fourth
  // what a coach sees, so both have to be on for four switches to exist.
  final savedFlags = AppRouter.featureFlags;
  setUp(
    () => AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.community: true,
      Feature.coachedLife: true,
    }),
  );
  tearDown(() => AppRouter.featureFlags = savedFlags);

  group('M3: crash reports, only with her consent', () {
    testWidgets('off by default, and the switch says what it means', (
      tester,
    ) async {
      _phone(tester);
      final choices = <bool>[];
      await tester.pumpWidget(
        _host(
          PrivacyView(
            service: PrivacySettingsService(InMemoryPrivacyRepository()),
            onCrashReportsChanged: (allowed) async => choices.add(allowed),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggle = find.byKey(const ValueKey('crash-reports-toggle'));
      await tester.ensureVisible(toggle);
      expect(tester.widget<AppToggle>(toggle).value, isFalse);
      expect(
        find.text('Off. Nothing is sent when the app crashes.'),
        findsOneWidget,
      );

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(choices, [true]);
      expect(find.textContaining('Nothing about you is attached'), findsOneWidget);

      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(choices, [true, false]);
    });

    testWidgets('no row without a place to record the choice', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(PrivacyView(service: PrivacySettingsService(InMemoryPrivacyRepository()))),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('crash-reports-toggle')), findsNothing);
    });
  });

  group('usage statistics, only with her consent', () {
    testWidgets('off by default, separate from crash reports, and says what '
        'turning it off does', (tester) async {
      _phone(tester);
      final choices = <bool>[];
      final crash = <bool>[];
      await tester.pumpWidget(
        _host(
          PrivacyView(
            service: PrivacySettingsService(InMemoryPrivacyRepository()),
            onCrashReportsChanged: (allowed) async => crash.add(allowed),
            onAnalyticsChanged: (allowed) async => choices.add(allowed),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggle = find.byKey(const ValueKey('analytics-toggle'));
      await tester.ensureVisible(toggle);
      expect(tester.widget<AppToggle>(toggle).value, isFalse);
      expect(find.textContaining('clears the statistics ID'), findsOneWidget);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(choices, [true]);
      expect(crash, isEmpty, reason: 'two choices, never one');
      expect(find.textContaining('Google Analytics and PostHog receive'), findsOneWidget);

      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(choices, [true, false]);
    });

    testWidgets('no row without a place to record the choice', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          PrivacyView(
            service: PrivacySettingsService(InMemoryPrivacyRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('analytics-toggle')), findsNothing);
    });
  });

  group('the switches', () {
    testWidgets('four switches, and only the blur starts on', (tester) async {
      _phone(tester);
      final repository = InMemoryPrivacyRepository();

      await tester.pumpWidget(
        _host(PrivacyView(service: PrivacySettingsService(repository))),
      );
      await tester.pumpAndSettle();

      final toggles = _toggles(tester);
      expect(toggles, hasLength(4));
      expect(
        toggles.map((t) => t.value).toList(),
        [false, false, true, false],
        reason:
            'profileVisible, showBests, blurFacesDefault, shareLogsWithCoach — '
            'every sharing switch off, the protective default on',
      );
    });

    testWidgets('tapping one switch writes exactly one field path', (
      tester,
    ) async {
      _phone(tester);
      final repository = InMemoryPrivacyRepository();

      await tester.pumpWidget(
        _host(PrivacyView(service: PrivacySettingsService(repository))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show my personal bests'));
      await tester.pumpAndSettle();

      expect(repository.writes, ['privacy.showBests']);
      expect(_toggles(tester)[1].value, isTrue);
      // And nothing else moved.
      expect(_toggles(tester)[0].value, isFalse);
      expect(_toggles(tester)[3].value, isFalse);
    });

    testWidgets('turning the blur off states the consequence first', (
      tester,
    ) async {
      _phone(tester);
      final repository = InMemoryPrivacyRepository();

      await tester.pumpWidget(
        _host(PrivacyView(service: PrivacySettingsService(repository))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blur faces in my photos'));
      await tester.pumpAndSettle();

      // A sheet, never a dialog — the rule-9 source guard bans showDialog
      // across lib/features/.
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Close'), findsOneWidget);

      // Backing out leaves the blur exactly where it was.
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(repository.writes, isEmpty);
      expect(_toggles(tester)[2].value, isTrue);
    });

    testWidgets('confirming the consequence turns it off', (tester) async {
      _phone(tester);
      final repository = InMemoryPrivacyRepository();

      await tester.pumpWidget(
        _host(PrivacyView(service: PrivacySettingsService(repository))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blur faces in my photos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(repository.writes, ['privacy.blurFacesDefault']);
      expect(_toggles(tester)[2].value, isFalse);
    });
  });

  group('rule 7 — the claim is a fact or it is absent', () {
    testWidgets('with no recorded deletion, the screen says nothing about it', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          PrivacyView(
            service: PrivacySettingsService(InMemoryPrivacyRepository()),
            // decided, but the purge has not reported back
            verification: VerificationRecord(decidedAt: DateTime(2026, 7, 3)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(_rule7),
        findsNothing,
        reason:
            'G7 §5: A03 cannot claim a deletion that has not happened. The '
            '"deletion pending" string it should show instead is absent from '
            'the dictionary and is reported rather than invented.',
      );
    });

    testWidgets('with a recorded deletion, the sentence appears', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          PrivacyView(
            service: PrivacySettingsService(InMemoryPrivacyRepository()),
            verification: VerificationRecord(
              decidedAt: DateTime(2026, 7, 3, 14, 25),
              imagesDeletedAt: DateTime(2026, 7, 3, 14, 27),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_rule7), findsOneWidget);
    });
  });

  group('P2-OFF-A03 — offline', () {
    testWidgets('a queued switch says it is saved on this phone', (
      tester,
    ) async {
      _phone(tester);
      // Seeded ON, because revocation is the case that matters: P0-SHARE-03 is
      // about turning a live sharing switch OFF with no signal. Starting from
      // the default would test turning one on, which promises nothing.
      final repository = InMemoryPrivacyRepository(
        privacy: const PrivacySettings(shareLogsWithCoach: true),
      )..goOffline();

      await tester.pumpWidget(
        _host(PrivacyView(service: PrivacySettingsService(repository))),
      );
      await tester.pumpAndSettle();

      expect(_toggles(tester)[3].value, isTrue);

      // She revokes her coach's access with no signal. The row sits below the
      // fold on a 390x844 phone, so it has to be scrolled to — tapping an
      // off-screen row is how a widget test silently asserts nothing.
      final row = find.text('My coach can see my meals and workouts');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      // The switch flips at once — she is never blocked on the network.
      expect(_toggles(tester)[3].value, isFalse);
      expect(find.text('Saved on your phone'), findsOneWidget);
      // Never a spinner (G7 §4).
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('online, no queued chip appears', (tester) async {
      _phone(tester);
      final repository = InMemoryPrivacyRepository();

      await tester.pumpWidget(
        _host(PrivacyView(service: PrivacySettingsService(repository))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile visible to members'));
      await tester.pumpAndSettle();

      expect(find.text('Saved on your phone'), findsNothing);
    });
  });

  group('P2-RTL-A03 and P2-TXT-A03', () {
    testWidgets('Arabic renders right-to-left with no overflow', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          PrivacyView(
            service: PrivacySettingsService(InMemoryPrivacyRepository()),
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(AppToggle).first)),
        TextDirection.rtl,
      );
      expect(_toggles(tester), hasLength(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the largest system text size clips nothing', (tester) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          PrivacyView(
            service: PrivacySettingsService(InMemoryPrivacyRepository()),
          ),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_toggles(tester), hasLength(4));
    });

    testWidgets('Arabic at the largest text size also holds', (tester) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          PrivacyView(
            service: PrivacySettingsService(InMemoryPrivacyRepository()),
          ),
          locale: const Locale('ar'),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('health backup off, offline (C4)', () {
    testWidgets('it is off here at once, and she is told the cloud copy '
        'goes when she is back online', (tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final pref = HealthBackupPreference.instance..resetForTest();
      await pref.set(true);
      addTearDown(pref.resetForTest);
      final controller = HealthBackupController(store: _OfflineHealthStore());

      await tester.pumpWidget(
        _host(
          PrivacyView(
            service: PrivacySettingsService(InMemoryPrivacyRepository()),
            healthBackup: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('health-backup-toggle')),
      );
      await tester.tap(find.byKey(const ValueKey('health-backup-toggle')));
      await tester.pumpAndSettle();

      expect(pref.enabled, isFalse);
      expect(
        find.byKey(const ValueKey('health-backup-withdraw-pending')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('health-backup-error')), findsNothing);
    });

    testWidgets('the note says what syncs, what stays, and what is never '
        'stored', (tester) async {
      _phone(tester);
      AppRouter.featureFlags = FeatureFlags.allOff;
      await tester.pumpWidget(
        _host(
          PrivacyView(
            service: PrivacySettingsService(InMemoryPrivacyRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'saved to your Own Hub account once you are '
          'verified',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Photos of your ID card and your selfie are never '
          'stored',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('stay on this phone.'), findsNothing);
    });
  });
}

class _OfflineHealthStore implements HealthConsentStore {
  @override
  Future<void> record({required bool granted}) async =>
      throw StateError('unavailable');

  @override
  Future<HealthConsentState?> current(String uid) async => null;
}
