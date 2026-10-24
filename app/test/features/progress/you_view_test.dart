// P01 — You, the last tab.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/identity/user_roles.dart';
import 'package:own_hub/domain/rewards/rewards.dart';
import 'package:own_hub/domain/rewards/weekly_goal.dart';
import 'package:own_hub/features/progress/presentation/you_view.dart';
import 'package:own_hub/features/progress/presentation/progress_view_model.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_avatar.dart';

import '../../helpers/primary_actions.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) => MaterialApp(
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

YouView _you({
  List<String>? log,
  bool hasCoach = false,
  String? firstName = 'Mai',
}) => YouView(
  summary: ProgressSummary.from(
    goal: const WeeklyGoal(sessionsTarget: 3),
    rewards: const Rewards(bestsCount: 4),
  ),
  minutesThisWeek: 95,
  firstName: firstName,
  hasCoach: hasCoach,
  activities: const Text('the activities list'),
  onOpenSettings: () => log?.add('settings'),
  onOpenInsights: () => log?.add('insights'),
  onOpenCoach: () => log?.add('coach'),
  onOpenEvents: () => log?.add('events'),
  onOpenCycle: () => log?.add('cycle'),
  onOpenCommunity: () => log?.add('community'),
  onSelectTab: (id) => log?.add('tab:$id'),
);

void main() {
  final saved = AppRouter.featureFlags;
  tearDown(() => AppRouter.featureFlags = saved);

  testWidgets('a tab root: no back button, the gear opens settings', (
    tester,
  ) async {
    AppRouter.featureFlags = FeatureFlags.everything;
    _phone(tester);
    final log = <String>[];
    await tester.pumpWidget(_host(_you(log: log)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.text('Mai'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('you-settings')));
    expect(log, ['settings']);
    expectAtMostOnePrimaryAction(tester, where: 'You');
  });

  testWidgets('Progress shows three figures and a way to see more', (
    tester,
  ) async {
    AppRouter.featureFlags = FeatureFlags.everything;
    _phone(tester);
    final log = <String>[];
    await tester.pumpWidget(_host(_you(log: log)));
    await tester.pumpAndSettle();

    expect(find.text('Sessions this week'), findsOneWidget);
    expect(find.text('95'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('the activities list'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('you-see-more')));
    expect(log, ['insights']);
  });

  testWidgets('Activities swaps the panel in', (tester) async {
    AppRouter.featureFlags = FeatureFlags.everything;
    _phone(tester);
    await tester.pumpWidget(_host(_you()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activities'));
    await tester.pumpAndSettle();
    expect(find.text('the activities list'), findsOneWidget);
    expect(find.text('Sessions this week'), findsNothing);
  });

  testWidgets('rows follow the flags: all on', (tester) async {
    AppRouter.featureFlags = FeatureFlags.everything;
    _phone(tester);
    final log = <String>[];
    await tester.pumpWidget(_host(_you(log: log)));
    await tester.pumpAndSettle();

    expect(find.text('Find a coach'), findsOneWidget);
    for (final key in ['you-coach', 'you-events', 'you-cycle']) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.tap(find.byKey(ValueKey(key)));
    }
    expect(log, ['coach', 'events', 'cycle']);
  });

  testWidgets('a woman with a coach sees My coach', (tester) async {
    AppRouter.featureFlags = FeatureFlags.everything;
    _phone(tester);
    await tester.pumpWidget(_host(_you(hasCoach: true)));
    await tester.pumpAndSettle();
    expect(find.text('My coach'), findsOneWidget);
    expect(find.text('Find a coach'), findsNothing);
  });

  testWidgets('rows follow the flags: all off', (tester) async {
    AppRouter.featureFlags = FeatureFlags.everything.with_({
      Feature.marketplace: false,
      Feature.events: false,
      Feature.cycle: false,
      Feature.community: false,
    });
    _phone(tester);
    await tester.pumpWidget(_host(_you()));
    await tester.pumpAndSettle();

    for (final key in [
      'you-coach',
      'you-events',
      'you-cycle',
      'you-community',
    ]) {
      expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
    }
  });

  for (final (locale, scale) in [
    (const Locale('en'), 1.0),
    (const Locale('ar'), 1.0),
    (const Locale('en'), 2.0),
    (const Locale('ar'), 2.0),
  ]) {
    testWidgets('no overflow in ${locale.languageCode} at x$scale', (
      tester,
    ) async {
      AppRouter.featureFlags = FeatureFlags.everything;
      _phone(tester);
      await tester.pumpWidget(_host(_you(), locale: locale, textScale: scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('without a name it says You', (tester) async {
    AppRouter.featureFlags = FeatureFlags.everything;
    _phone(tester);
    await tester.pumpWidget(_host(_you(firstName: null)));
    await tester.pumpAndSettle();
    expect(find.text('You'), findsWidgets);
  });

  group('the picture', () {
    Widget withRoles(UserRoles roles) {
      final notifier = ValueNotifier(roles);
      addTearDown(notifier.dispose);
      return RoleScope(notifier: notifier, child: _host(_you()));
    }

    testWidgets('is not a button for a one-role woman', (tester) async {
      AppRouter.featureFlags = FeatureFlags.everything;
      _phone(tester);
      final handle = tester.ensureSemantics();
      final log = <String>[];
      final notifier = ValueNotifier(UserRoles.trainee);
      addTearDown(notifier.dispose);
      await tester.pumpWidget(
        RoleScope(
          notifier: notifier,
          child: _host(_you(log: log)),
        ),
      );
      await tester.pumpAndSettle();

      final picture = find.byType(AppAvatar);
      expect(
        find.bySemanticsLabel(RegExp('Your profile|Switch app')),
        findsNothing,
      );
      // No node under the picture is announced as a button.
      final node = tester.getSemantics(find.byType(Scaffold).first);
      var buttons = 0;
      void walk(SemanticsNode n) {
        if (n.flagsCollection.isButton &&
            RegExp('Your profile|Switch app').hasMatch(n.label)) {
          buttons++;
        }
        n.visitChildren((c) {
          walk(c);
          return true;
        });
      }

      walk(node);
      expect(buttons, 0);

      await tester.tap(picture, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(log, isEmpty, reason: 'settings did not open');
      expect(find.byType(BottomSheet), findsNothing);
      handle.dispose();
    });

    testWidgets('is a working button for a two-role woman', (tester) async {
      AppRouter.featureFlags = FeatureFlags.everything;
      _phone(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(withRoles(UserRoles.both));
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.byType(AppAvatar));
      expect(node.label, contains('Switch app'));
      expect(node.flagsCollection.isButton, isTrue);
      await tester.tap(find.byType(AppAvatar));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      handle.dispose();
    });
  });
}
