// C02 — Choose your language.
//
// The screen has one unusual property worth testing carefully: it is bilingual
// regardless of locale, because a woman who has not chosen a language yet cannot
// be shown a screen written only in one. So the assertions here are the opposite
// of the usual ones — some text must NOT change when the locale does.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/domain/locale_preference.dart';
import 'package:own_hub/features/signup/presentation/language_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart' show LocaleScope;
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_list_item.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
  ValueNotifier<Locale>? notifier,
}) {
  final localeNotifier = notifier ?? ValueNotifier<Locale>(locale);
  return LocaleScope(
    notifier: localeNotifier,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(locale),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

void main() {
  group('it is readable before she has chosen a language', () {
    testWidgets('both headings show at once, in English', (tester) async {
      await tester.pumpWidget(
        _host(LanguageView(preference: InMemoryLocalePreference())),
      );
      await tester.pumpAndSettle();

      expect(find.text('اختاري لغتك'), findsOneWidget);
      expect(find.text('Choose your language'), findsOneWidget);
    });

    testWidgets('both headings still show in Arabic', (tester) async {
      await tester.pumpWidget(
        _host(
          LanguageView(preference: InMemoryLocalePreference()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      // Neither disappears when the locale flips — that is the whole point.
      expect(find.text('اختاري لغتك'), findsOneWidget);
      expect(find.text('Choose your language'), findsOneWidget);
    });

    testWidgets('the options are labelled with their own names', (
      tester,
    ) async {
      for (final locale in [const Locale('en'), const Locale('ar')]) {
        await tester.pumpWidget(
          _host(
            LanguageView(preference: InMemoryLocalePreference()),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        // Endonyms: never translated, in either direction.
        expect(find.text('العربية'), findsOneWidget, reason: '$locale');
        expect(find.text('English'), findsOneWidget, reason: '$locale');
      }
    });
  });

  group('choosing', () {
    testWidgets('Arabic is preselected, because this ships in Egypt', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          LanguageView(
            preference: InMemoryLocalePreference(AppLanguage.arabic),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final arabicRow = tester.widget<AppListItem>(
        find.ancestor(
          of: find.text('العربية'),
          matching: find.byType(AppListItem),
        ),
      );
      expect(arabicRow.variant, AppCardVariant.selected);
      expect(
        arabicRow.trailing,
        isNotNull,
        reason: 'the tick marks the choice',
      );
    });

    // R1-P9: on a phone set to a third language the app opens in English,
    // so with no choice made the tick is on English, not on Arabic.
    testWidgets('with no choice, the tick is on the language on screen', (
      tester,
    ) async {
      tester.platformDispatcher.localeTestValue = const Locale('fr');
      tester.platformDispatcher.localesTestValue = const [Locale('fr')];
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      for (final (locale, ticked, plain) in [
        (const Locale('en'), 'English', 'العربية'),
        (const Locale('ar'), 'العربية', 'English'),
      ]) {
        await tester.pumpWidget(
          _host(
            LanguageView(
              key: ValueKey(locale),
              preference: InMemoryLocalePreference(),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        AppListItem row(String label) => tester.widget<AppListItem>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(AppListItem),
          ),
        );
        expect(row(ticked).variant, AppCardVariant.selected, reason: '$locale');
        expect(row(plain).variant, AppCardVariant.outlined, reason: '$locale');
      }
    });

    testWidgets('tapping English selects it and moves the tick', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          LanguageView(
            preference: InMemoryLocalePreference(AppLanguage.arabic),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      final englishRow = tester.widget<AppListItem>(
        find.ancestor(
          of: find.text('English'),
          matching: find.byType(AppListItem),
        ),
      );
      final arabicRow = tester.widget<AppListItem>(
        find.ancestor(
          of: find.text('العربية'),
          matching: find.byType(AppListItem),
        ),
      );
      expect(englishRow.variant, AppCardVariant.selected);
      expect(arabicRow.variant, AppCardVariant.outlined);
    });

    testWidgets('the choice is written to the pre-auth mirror', (tester) async {
      // NOT profile.language: there is no account yet. See LocalePreference.
      final preference = InMemoryLocalePreference(AppLanguage.arabic);
      await tester.pumpWidget(_host(LanguageView(preference: preference)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(preference.read(), AppLanguage.english);
    });

    testWidgets('the choice applies immediately, not on Continue', (
      tester,
    ) async {
      // She should see the app change under her hand, rather than be promised it.
      final notifier = ValueNotifier<Locale>(const Locale('en'));
      await tester.pumpWidget(
        _host(
          LanguageView(
            preference: InMemoryLocalePreference(AppLanguage.english),
          ),
          notifier: notifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();

      expect(notifier.value.languageCode, 'ar');
    });

    testWidgets('Continue moves her on', (tester) async {
      var continued = 0;
      await tester.pumpWidget(
        _host(
          LanguageView(
            preference: InMemoryLocalePreference(),
            onContinue: () => continued++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(continued, 1);
    });
  });

  testWidgets('does not overflow at the largest system text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        LanguageView(preference: InMemoryLocalePreference()),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
