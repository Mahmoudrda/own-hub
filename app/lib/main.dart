import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'domain/flags/feature_flags.dart';
import 'domain/identity/user_roles.dart';
import 'l10n/app_l10n.dart';
import 'routing/app_router.dart';
import 'routing/app_routes.dart';
import 'theme/app_tokens.dart';
import 'theme/hand_theme.dart';

void main() {
  // Dark status-bar content, before anything is drawn.
  //
  // The theme sets this too, but `AppBarTheme.systemOverlayStyle` only reaches
  // screens that HAVE an app bar, and several — C13 among them — pass none at
  // all. Without this those screens keep the platform default and draw a
  // near-white clock on the pale surface colour.
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  LicenseRegistry.addLicense(_handFontLicences);
  runApp(const OwnHubApp());
}

/// The two OFL handwriting faces in `assets/fonts/`. The OFL asks that its
/// text travel with the font, and the licences page is where it travels to.
Stream<LicenseEntry> _handFontLicences() async* {
  for (final (family, asset) in [
    ('La Belle Aurore', 'assets/fonts/OFL-LaBelleAurore.txt'),
    ('Aref Ruqaa', 'assets/fonts/OFL-ArefRuqaa.txt'),
  ]) {
    yield LicenseEntryWithLineBreaks([
      family,
    ], await rootBundle.loadString(asset));
  }
}

/// Holds the chosen locale. Arabic is not a setting buried in preferences here —
/// C02 asks for the language before anything else, so the app must be able to
/// switch without a restart.
class LocaleScope extends InheritedNotifier<ValueNotifier<Locale>> {
  const LocaleScope({
    super.key,
    required ValueNotifier<Locale> super.notifier,
    required super.child,
  });

  static ValueNotifier<Locale> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()!.notifier!;
}

class OwnHubApp extends StatefulWidget {
  const OwnHubApp({super.key});

  @override
  State<OwnHubApp> createState() => _OwnHubAppState();
}

class _OwnHubAppState extends State<OwnHubApp> {
  /// Arabic by default, because this ships in Egypt. `C02` is the second screen
  /// she sees and lets her change it; until then the device locale would be a
  /// worse guess than the product's own audience.
  ///
  /// `--dart-define=OWNHUB_LOCALE=ar` opens the build in Arabic, so any
  /// screen can be captured in either language — the store listing needs
  /// both, and right-to-left layout is only ever checked by looking at it.
  final ValueNotifier<Locale> _locale = ValueNotifier(
    const Locale(String.fromEnvironment('OWNHUB_LOCALE', defaultValue: 'en')),
  );

  /// Her roles, and which app she is in (D11). Trainee until C08 says
  /// otherwise: it is the common case, and it is the safe one — the trainee
  /// side grants nothing a coach account would.
  ///
  /// With [Feature.accountRequired] off there is no sign-up to choose a role
  /// in, so she is a guest holding BOTH roles: the trainee app opens, and her
  /// picture switches to the coach side, so neither half is out of reach.
  final ValueNotifier<UserRoles> _roles = ValueNotifier(
    AppRouter.featureFlags.isOn(Feature.accountRequired)
        ? UserRoles.trainee
        : UserRoles.both,
  );

  @override
  void dispose() {
    _locale.dispose();
    _roles.dispose();
    super.dispose();
  }

  /// The route to open on, preferring one the platform supplied.
  ///
  /// Falls back to the front door for anything unrecognised. The fallback is
  /// the point: an unknown route must not reach the initial-route machinery,
  /// which resolves nothing and renders a blank white page — running,
  /// responsive and completely empty. That shipped once already.
  ///
  /// With no route supplied, the front door depends on
  /// [Feature.accountRequired]: sign-up (C01) when an account is required,
  /// Home (T01) when it is not.
  String _initialRoute() {
    final supplied =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    if (screenIdForRoute(supplied) != null) return supplied;
    return AppRouter.featureFlags.isOn(Feature.accountRequired)
        ? appRoutes['C01']!.name
        : appRoutes['T01']!.name;
  }

  @override
  Widget build(BuildContext context) {
    // RoleScope sits above MaterialApp so every route can read it: routes are
    // built by the Navigator, which is a descendant, and a role switch must
    // rebuild the navigation and the screen under it together.
    return RoleScope(
      notifier: _roles,
      child: LocaleScope(
        notifier: _locale,
        child: ValueListenableBuilder<Locale>(
          valueListenable: _locale,
          builder: (context, locale, _) => MaterialApp(
            onGenerateTitle: (context) => 'Own Hub',
            debugShowCheckedModeBanner: false,
            locale: locale,
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            // buildTheme takes the locale because Arabic renders two points larger
            // with more line height; the size decision belongs in the theme, not in
            // per-screen overrides.
            theme: handTheme(buildTheme(locale)),
            // The front door: C01, the first screen a woman ever sees. Expressed
            // as a screen id rather than a path string so it cannot drift from the
            // generated inventory.
            //
            // A route the platform supplies wins, when it names a real screen.
            // That is the form a notification tap or a deep link arrives in —
            // T07's lock-screen nudge has nowhere to land without it — and it is
            // also what allows a build to be launched directly onto any screen
            // for a screenshot. Both rendering defects in this app's history
            // were caught by a screenshot and by nothing else, so being able to
            // take one of an arbitrary screen is worth this much.
            initialRoute: _initialRoute(),
            // Generate the initial route ourselves, as ONE route.
            //
            // Flutter's default splits "/signup/c01" into "/", "/signup" and
            // "/signup/c01" and asks onGenerateRoute for each ancestor. Neither
            // "/" nor "/signup" is a screen, so both return null, the initial
            // route fails, and the app renders a blank white page — running,
            // responsive, and completely empty.
            //
            // This shipped once. Every test passed and the app launched fine; only
            // a screenshot caught it, because pumpWidget does not exercise the
            // ancestor-splitting path that breaks it.
            onGenerateInitialRoutes: (initial) {
              final route = AppRouter.onGenerateRoute(
                RouteSettings(name: initial),
              );
              return [
                route ?? AppRouter.onUnknownRoute(RouteSettings(name: initial)),
              ];
            },
            onGenerateRoute: AppRouter.onGenerateRoute,
            onUnknownRoute: AppRouter.onUnknownRoute,
          ),
        ),
      ),
    );
  }
}
