import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state/cloud_store.dart';
import 'app_state/firebase_boot.dart';
import 'app_state/local_persistence.dart';
import 'app_state/onboarding_state.dart';
import 'features/account/domain/health_backup.dart';
import 'domain/flags/feature_flags.dart';
import 'domain/identity/user_roles.dart';
import 'l10n/app_l10n.dart';
import 'routing/app_router.dart';
import 'routing/app_routes.dart';
import 'theme/app_tokens.dart';
import 'theme/hand_theme.dart';

Future<void> main() async {
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

  // Her week, read off this phone BEFORE the first frame.
  //
  // Awaited here rather than loaded from a screen so that the first thing she
  // sees is already hers: Home drawn once, from her own session count and her
  // own meal, instead of the app's defaults replaced a frame later. One read,
  // one decode — see `lib/app_state/local_persistence.dart`.
  //
  // It cannot fail the launch. A missing, empty, truncated, corrupt or older
  // snapshot restores nothing and the app opens exactly as it did before any
  // of this existed.
  await LocalPersistence.instance.load();
  LocalPersistence.instance.start();

  // The back end, brought up AFTER her local week and unable to fail the
  // launch. The order matters: whatever Firebase does or does not do, the
  // first frame is already drawn from her own data, so a dead network costs
  // her nothing she can see. See `lib/app_state/firebase_boot.dart`.
  await FirebaseBoot.start();

  // Has the server already let her in? Read once, here, because
  // `AppRouter.onGenerateRoute` is synchronous and the whole-app gate has to
  // answer before the first route is built rather than a frame later. It cannot
  // fail the launch either: no Firebase, no signed-in user or no network all
  // leave the claim false, and false means she meets the check rather than the
  // app. See `AppRouter.readVerificationClaim`.
  await AppRouter.readVerificationClaim();

  // The cloud copy of her week, started but deliberately NOT awaited.
  //
  // `start()` only attaches listeners and reads one preferences key; it does
  // no network work of its own, so awaiting it would be harmless today. That
  // is precisely why it is not awaited: the promise this boot makes is that
  // nothing before the first frame touches the network, and a promise kept by
  // accident is one a later edit breaks quietly. `unawaited` makes it
  // structural rather than incidental.
  //
  // With no account, no Firebase, or no verified claim it does nothing at all,
  // and the app is exactly what it was before any of this existed. See
  // `lib/app_state/cloud_store.dart`.
  //
  // Her health backup choice is read first (a local key, no network). If it
  // is on, the server's consent record is checked before the sync starts, so
  // a phone that thinks it may back up her health data cannot push it after
  // the server withdrew the consent. Off, the check returns at once.
  await HealthBackupPreference.instance.load();
  unawaited(() async {
    try {
      await AppRouter.reconcileHealthBackup();
    } catch (_) {
      // The rules refuse health writes without the consent anyway.
    }
    await CloudStore.instance.start();
  }());

  runApp(const OwnHubApp());
}

/// Every OFL face bundled in `assets/fonts/`. The licence asks that its text
/// travel with the font, and the licences page is where it travels to.
///
/// Rubik was missing here for a long time while the two handwriting faces were
/// registered, which is an easy omission to make and a hard one to notice:
/// Rubik is the body face of the entire product, so it is the one a reader is
/// most likely to ask about and the one whose absence says least. The use was
/// always permitted, OFL 1.1 like the others. What was missing was the notice,
/// and a notice nobody can reach is the same as no notice at all.
Stream<LicenseEntry> _handFontLicences() async* {
  for (final (family, asset) in [
    ('La Belle Aurore', 'assets/fonts/OFL-LaBelleAurore.txt'),
    ('Aref Ruqaa', 'assets/fonts/OFL-ArefRuqaa.txt'),
    ('Rubik', 'assets/fonts/OFL-Rubik.txt'),
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
  /// The language she has already chosen, else the one her phone is set to,
  /// else English.
  ///
  /// The phone is the better guess and it used to be ignored: this shipped in
  /// Egypt opening in English on a handset set to Arabic, with the chooser one
  /// screen deep. The whole Arabic product was in the binary and she had to go
  /// looking for it.
  ///
  /// `--dart-define=OWNHUB_LOCALE=ar` still forces a language, because a
  /// screenshot of the Arabic build has to be repeatable and right-to-left
  /// layout is only ever checked by looking at it. A choice she has made wins
  /// over everything, and it is read before the first frame so the app opens in
  /// her language rather than switching once she notices.
  final ValueNotifier<Locale> _locale = ValueNotifier(
    AppRouter.localePreference.read()?.locale ?? _firstRunLocale(),
  );

  /// What to open in before she has said. `const String.fromEnvironment`
  /// defaults to empty rather than to a language, so an unforced build falls
  /// through to the phone.
  static Locale _firstRunLocale() {
    const forced = String.fromEnvironment('OWNHUB_LOCALE');
    if (forced.isNotEmpty) return Locale(forced);
    for (final locale in WidgetsBinding.instance.platformDispatcher.locales) {
      for (final supported in AppL10n.supportedLocales) {
        if (supported.languageCode == locale.languageCode) return supported;
      }
    }
    return const Locale('en');
  }

  /// Her roles, and which app she is in (D11). Trainee until C08 says
  /// otherwise: it is the common case, and it is the safe one — the trainee
  /// side grants nothing a coach account would.
  ///
  /// With [Feature.accountRequired] off there is no sign-up to choose a role
  /// in, so she is a guest. She holds both roles only where there is a coach
  /// side to hold: the first release ships without one, and a picture that
  /// switches to an app that is switched off is a door into nothing.
  final ValueNotifier<UserRoles> _roles = ValueNotifier(
    AppRouter.featureFlags.isOn(Feature.accountRequired) ||
            !AppRouter.featureFlags.isOn(Feature.coachApp)
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
  ///
  /// The setup questions are not chosen here, and the reason is worth stating
  /// where somebody will look for them. They are not an alternative front door;
  /// they open **on top of** the front door, as the second entry of
  /// [_firstRunStack], so that finishing, skipping or closing is a pop back to
  /// the screen underneath rather than a push to a new one. See
  /// `lib/app_state/onboarding_state.dart`.
  String _initialRoute() => _openable(
    WidgetsBinding.instance.platformDispatcher.defaultRouteName,
  );

  /// [name] if the app is willing to OPEN on it, else the front door.
  ///
  /// Two rules, and both are about the first thing a woman ever sees rather
  /// than about reachability, which `onGenerateRoute` already decides.
  ///
  ///   * **A route this build does not resolve.** The admin console in a
  ///     release binary. It is already unreachable; without this she would
  ///     launch into the "no screen serves this" page instead of the app.
  ///   * **A route whose feature is switched off.** `onGenerateRoute` answers
  ///     one with `FeatureOff` — an app bar carrying the raw screen id and a
  ///     sentence about a feature flag, in English, with no way back because
  ///     there is nothing underneath it. Pushed onto a running app that is a
  ///     dead end she can leave. As the opening screen it is the entire
  ///     product. `community`, `coaching`, `marketplace` and `assistant` are
  ///     all off in the first release, so every link anyone shares about them
  ///     before the second release arrives exactly here. `resolvesInThisBuild`
  ///     does not cover it: those screens are built, tested and resolvable,
  ///     they are merely switched off.
  ///
  /// It is a separate method because it has to be applied in TWO places, and
  /// the reason is a trap worth naming. `WidgetsApp` does not simply use the
  /// `initialRoute` it is handed: when the platform supplied a route of its
  /// own it prefers that one and ignores `initialRoute` entirely. So the
  /// filtering this app did in `_initialRoute` alone never ran in the one case
  /// it was written for — a deep link — and the admin-console guard above has
  /// been quietly ineffective for as long as it has existed. [_firstRunStack]
  /// is where the name actually arrives, so that is where it must also hold.
  static String _openable(String name) {
    final id = screenIdForRoute(name);
    if (id != null &&
        AppRouter.resolvesInThisBuild(id) &&
        AppRouter.screenIsOn(id)) {
      return name;
    }
    return _frontDoor;
  }

  /// The app's own first screen, with nothing supplied from outside.
  static String get _frontDoor =>
      AppRouter.featureFlags.isOn(Feature.accountRequired)
      ? appRoutes['C01']!.name
      : appRoutes['T01']!.name;

  /// The routes the app opens holding, newest last.
  ///
  /// Generated here as ONE route each, rather than letting Flutter split them.
  ///
  /// Flutter's default splits "/signup/c01" into "/", "/signup" and
  /// "/signup/c01" and asks onGenerateRoute for each ancestor. Neither "/" nor
  /// "/signup" is a screen, so both return null, the initial route fails, and
  /// the app renders a blank white page — running, responsive, and completely
  /// empty.
  ///
  /// This shipped once. Every test passed and the app launched fine; only a
  /// screenshot caught it, because pumpWidget does not exercise the
  /// ancestor-splitting path that breaks it.
  ///
  /// On a first launch the stack is two deep: the front door, and the setup
  /// questions open on top of it. Both are built before the first frame and
  /// neither is animated in, so she sees `O01` and not a flash of a Home she
  /// has not filled in yet. The questions are stacked only over the app's own
  /// front door — a build launched straight onto a named screen for a
  /// screenshot, or a notification landing on `T03`, is left exactly where it
  /// was sent.
  List<Route<dynamic>> _firstRunStack(String supplied) {
    // Filtered HERE, not only in `_initialRoute`. `WidgetsApp` prefers the
    // platform's own route over the `initialRoute` it was given, so on the one
    // path that matters — a deep link — this is the only place the decision
    // can be made. See [_openable].
    final initial = _openable(supplied);

    Route<dynamic> routeFor(String name) =>
        AppRouter.onGenerateRoute(RouteSettings(name: name)) ??
        AppRouter.onUnknownRoute(RouteSettings(name: name));

    final front = routeFor(initial);
    // Compared against the front door itself rather than against
    // `_initialRoute()`, which answers with whatever the platform supplied. A
    // build launched straight onto `/onboarding/o02` for a screenshot would
    // otherwise have question one stacked on top of question two.
    if (!OnboardingState.instance.isDue || initial != _frontDoor) {
      return [front];
    }
    final setup = AppRouter.onGenerateRoute(
      RouteSettings(name: appRoutes['O01']!.name),
    );
    return setup == null ? [front] : [front, setup];
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
            // Generated ourselves, one route per entry, and two of them on a
            // first launch. See `_firstRunStack`.
            onGenerateInitialRoutes: _firstRunStack,
            onGenerateRoute: AppRouter.onGenerateRoute,
            onUnknownRoute: AppRouter.onUnknownRoute,
          ),
        ),
      ),
    );
  }
}
