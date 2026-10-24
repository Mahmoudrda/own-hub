// Her picture and the language switch at the end of every header: where they
// appear, where they do not, that they never double, that they do not crowd
// the title at the largest text size in English and Arabic, and that they
// work.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart' show LocaleScope;
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_avatar.dart';
import 'package:own_hub/ui/app_scaffold.dart';
import 'package:own_hub/ui/language_switch.dart';
import 'package:own_hub/ui/screen_scope.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  String? screen,
  Locale locale = const Locale('en'),
  double scale = 1,
}) {
  Widget body = child;
  if (screen != null) body = ScreenScope(screenId: screen, child: body);
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: body,
      ),
    ),
  );
}

Widget _page({bool showChrome = true, List<Widget> actions = const []}) =>
    Scaffold(
      appBar: AppTopBar(
        title: 'Personal bests and body measurements',
        onBack: () {},
        actions: actions,
        showChrome: showChrome,
      ),
      body: const SizedBox.shrink(),
    );

Finder get _avatar => find.byWidgetPredicate((w) => w is AppAvatar && w.isSelf);
Finder get _switch => find.byType(LanguageSwitchButton);

void main() {
  group('where the chrome draws', () {
    testWidgets('a routed header carries one picture and one switch', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_page(), screen: 'P02'));
      expect(_avatar, findsOneWidget);
      expect(_switch, findsOneWidget);
    });

    testWidgets('a header pumped off the router is unchanged', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_page()));
      expect(_avatar, findsNothing);
      expect(_switch, findsNothing);
    });

    testWidgets('showChrome: false leaves the bar bare', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_page(showChrome: false), screen: 'P02'));
      expect(_avatar, findsNothing);
      expect(_switch, findsNothing);
    });

    for (final id in ['R07', 'R13', 'C10', 'E12', 'C06']) {
      testWidgets('$id never shows it', (tester) async {
        _phone(tester);
        await tester.pumpWidget(_host(_page(), screen: id));
        expect(_avatar, findsNothing);
        expect(_switch, findsNothing);
      });
    }

    testWidgets('the setup results O01 to O06 carry it', (tester) async {
      for (final id in ['O01', 'O02', 'O03', 'O04', 'O05', 'O06']) {
        _phone(tester);
        await tester.pumpWidget(_host(_page(), screen: id));
        expect(_avatar, findsOneWidget, reason: id);
        expect(_switch, findsOneWidget, reason: id);
      }
    });

    testWidgets('a screen with no bar gets a slim row, once', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const AppScaffold(children: [Text('Hello')]), screen: 'P02'),
      );
      expect(_avatar, findsOneWidget);
      expect(_switch, findsOneWidget);
    });

    testWidgets('a bar and a scaffold under it do not double', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          Scaffold(
            appBar: AppTopBar(title: 'Milestones', onBack: () {}),
            body: const AppScaffold(children: [Text('Hello')]),
          ),
          screen: 'P02',
        ),
      );
      expect(_avatar, findsOneWidget);
      expect(_switch, findsOneWidget);
    });

    testWidgets('under the strip the bar adds nothing, and the strip has '
        'both', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          ScreenScope(
            screenId: 'P03',
            child: LanguageSwitchFrame(
              preference: AppRouter.localePreference,
              child: _page(),
            ),
          ),
          screen: 'P03',
        ),
      );
      expect(_avatar, findsOneWidget);
      expect(_switch, findsOneWidget);
    });

    testWidgets('the strip on a sign-in screen keeps only the switch', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          ScreenScope(
            screenId: 'C06',
            child: LanguageSwitchFrame(
              preference: AppRouter.localePreference,
              child: _page(),
            ),
          ),
          screen: 'C06',
        ),
      );
      expect(_avatar, findsNothing);
      expect(_switch, findsOneWidget);
    });
  });

  group('the chrome never crowds the title', () {
    for (final (locale, scale) in [
      (const Locale('en'), 1.0),
      (const Locale('en'), 2.0),
      (const Locale('ar'), 1.0),
      (const Locale('ar'), 2.0),
    ]) {
      testWidgets('${locale.languageCode} at $scale', (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _host(
            _page(
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.share),
                  tooltip: 'Share',
                ),
              ],
            ),
            screen: 'P02',
            locale: locale,
            scale: scale,
          ),
        );
        expect(tester.takeException(), isNull);
        final title = tester.getRect(find.byType(Text).first);
        final switchRect = tester.getRect(_switch);
        final avatarRect = tester.getRect(_avatar);
        final share = tester.getRect(find.byIcon(Icons.share));
        expect(title.overlaps(switchRect), isFalse);
        expect(title.overlaps(avatarRect), isFalse);
        expect(switchRect.overlaps(avatarRect), isFalse);
        expect(share.overlaps(switchRect), isFalse);
        expect(share.overlaps(avatarRect), isFalse);
        // Targets stay whole at 2.0.
        expect(switchRect.height, greaterThanOrEqualTo(48));
        expect(avatarRect.width, greaterThanOrEqualTo(44));
        final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
        for (final r in [title, switchRect, avatarRect, share]) {
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(screen.width));
        }
      });
    }
  });

  group('the controls work', () {
    final saved = AppRouter.featureFlags;
    setUp(() {
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        for (final f in Feature.values) f: f != Feature.accountRequired,
      });
    });
    tearDown(() => AppRouter.featureFlags = saved);

    Future<ValueNotifier<Locale>> openP02(WidgetTester tester) async {
      _phone(tester);
      final notifier = ValueNotifier<Locale>(const Locale('en'));
      await tester.pumpWidget(
        LocaleScope(
          notifier: notifier,
          child: ValueListenableBuilder<Locale>(
            valueListenable: notifier,
            builder: (context, locale, _) => MaterialApp(
              locale: locale,
              localizationsDelegates: AppL10n.localizationsDelegates,
              supportedLocales: AppL10n.supportedLocales,
              theme: buildTheme(locale),
              onGenerateRoute: AppRouter.onGenerateRoute,
              onUnknownRoute: AppRouter.onUnknownRoute,
              initialRoute: appRoutes['P02']!.name,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      return notifier;
    }

    testWidgets('her picture opens A02', (tester) async {
      await openP02(tester);
      await tester.tap(_avatar);
      // One frame to build the page and one to finish the slide in.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      final scopes = tester.widgetList<ScreenScope>(find.byType(ScreenScope));
      expect(scopes.last.screenId, 'A02');
    });

    testWidgets('the switch changes the language and back', (tester) async {
      final notifier = await openP02(tester);
      await tester.tap(_switch);
      await tester.pump(const Duration(milliseconds: 600));
      expect(notifier.value.languageCode, 'ar');
      await tester.tap(_switch);
      await tester.pump(const Duration(milliseconds: 600));
      expect(notifier.value.languageCode, 'en');
    });
  });
}
