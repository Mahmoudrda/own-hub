// C01 — the first screen a woman ever sees.
//
// Covers the P2 state rows for C01 (RTL and large text) and the parts of
// P0-VER-01 that begin here. The assertions worth having are the ones that catch
// silent failures: text that vanishes in Arabic, a layout that overflows at the
// largest system font, and copy that bypassed the dictionary.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/domain/locale_preference.dart';
import 'package:own_hub/features/signup/presentation/welcome_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart' show LocaleScope;
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_chip_row.dart';

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
  testWidgets('shows the promise, the explanation and the three ways in', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const WelcomeView()));
    await tester.pumpAndSettle();

    expect(
      find.text('Your training, your food, your cycle. Women only.'),
      findsOneWidget,
    );
    expect(find.text('A room full of women training like you'), findsNothing);
    expect(find.textContaining('Quiet workouts for home'), findsOneWidget);
    expect(find.text('Show me around'), findsOneWidget);
    expect(find.text('Skip the tour and join'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
    expect(find.text('Set up my week'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('says what the tour is before she takes it', (tester) async {
    await tester.pumpWidget(_host(const WelcomeView()));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The tour uses a sample week. No account, and nothing is saved.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('every string comes from the dictionary, in Arabic too', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const WelcomeView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    // If a string were hardcoded in English it would still read English here,
    // which is exactly the failure a hardcoded string produces in production.
    expect(find.text('تدريبكِ، وطعامكِ، ودورتكِ. للنساء فقط.'), findsOneWidget);
    expect(find.text('خذيني في جولة'), findsOneWidget);
    expect(find.text('تخطّي الجولة وانضمّي'), findsOneWidget);
    expect(
      find.text('تستخدم الجولة أسبوعًا تجريبيًّا. دون حساب، ولا يُحفظ شيء.'),
      findsOneWidget,
    );
    expect(find.text('لديّ حساب بالفعل'), findsOneWidget);
    expect(find.text('Show me around'), findsNothing);
  });

  testWidgets('lays out right-to-left in Arabic', (tester) async {
    await tester.pumpWidget(
      _host(const WelcomeView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    final direction = Directionality.of(
      tester.element(find.text('خذيني في جولة')),
    );
    expect(direction, TextDirection.rtl);
  });

  testWidgets('does not overflow at the largest system text size', (
    tester,
  ) async {
    // Arabic runs longer than English and this screen has no scroll, so it is
    // the most likely place in the product for text to be clipped.
    await tester.pumpWidget(
      _host(const WelcomeView(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason:
          'a RenderFlex overflow at large text is a real defect, not a '
          'cosmetic one — it hides the button she needs',
    );
  });

  testWidgets('all three actions are reachable and fire', (tester) async {
    var toured = 0;
    var started = 0;
    var signedIn = 0;
    await tester.pumpWidget(
      _host(
        WelcomeView(
          onLookAround: () => toured++,
          onGetStarted: () => started++,
          onSignIn: () => signedIn++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show me around'));
    await tester.tap(find.text('Skip the tour and join'));
    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();

    expect(toured, 1);
    expect(started, 1);
    expect(signedIn, 1);
  });

  testWidgets('every action meets the minimum tap target', (tester) async {
    await tester.pumpWidget(_host(const WelcomeView()));
    await tester.pumpAndSettle();

    for (final label in const [
      'Show me around',
      'Skip the tour and join',
      'I already have an account',
    ]) {
      final size = tester.getSize(
        find
            .ancestor(of: find.text(label), matching: find.byType(InkWell))
            .first,
      );
      expect(
        size.height,
        greaterThanOrEqualTo(44),
        reason: '$label: tapped one-handed',
      );
    }
  });

  group('the language, as two chips', () {
    testWidgets('preselected from the language the app opened in', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(WelcomeView(preference: InMemoryLocalePreference())),
      );
      await tester.pumpAndSettle();

      expect(find.text('English'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
      final chips = tester.widget<AppChipRow>(find.byType(AppChipRow));
      expect(chips.selected, {0}, reason: 'opened in English');
    });

    testWidgets('one tap switches the app now and remembers it', (
      tester,
    ) async {
      final preference = InMemoryLocalePreference();
      final locale = ValueNotifier<Locale>(const Locale('en'));
      await tester.pumpWidget(
        LocaleScope(
          notifier: locale,
          child: ValueListenableBuilder<Locale>(
            valueListenable: locale,
            builder: (context, value, _) => MaterialApp(
              locale: value,
              localizationsDelegates: AppL10n.localizationsDelegates,
              supportedLocales: AppL10n.supportedLocales,
              theme: buildTheme(value),
              home: WelcomeView(preference: preference),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Show me around'), findsOneWidget);

      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();

      expect(preference.read(), AppLanguage.arabic);
      expect(locale.value, const Locale('ar'));
      expect(find.text('خذيني في جولة'), findsOneWidget);
      expect(find.text('Show me around'), findsNothing);
    });
  });
}
