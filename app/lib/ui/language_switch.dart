/// A small "العربية" / "English" button that is on every screen she might land
/// on in the wrong language.
///
/// It reuses [applyLanguage], the one setter the welcome chips and the
/// language screen use, so it stores the choice and switches the app at once.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../features/signup/domain/locale_preference.dart';
import '../features/today/presentation/today_cards.dart' show openScreen;
import '../features/signup/presentation/language_view.dart'
    show applyLanguage, languageSwitchLabel;
import '../app_state/workout_session_state.dart';
import '../l10n/app_l10n.dart';
import '../routing/app_router.dart' show AppRouter;
import '../theme/app_tokens.dart';
import 'app_avatar.dart';
import 'screen_scope.dart';

/// The least height of the strip [LanguageSwitchFrame] adds above a screen:
/// the 48dp tap target. It grows with her text size and never clips.
const double kLanguageSwitchHeight = 48;

/// The text button on its own. It names the language it switches TO, in that
/// language's own script, and tells a screen reader the same in hers.
class LanguageSwitchButton extends StatelessWidget {
  const LanguageSwitchButton({
    super.key,
    required this.preference,
    this.onDark = false,
  });

  final LocalePreference preference;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final target = isEnglish ? AppLanguage.arabic : AppLanguage.english;
    return Semantics(
      button: true,
      label: isEnglish
          ? l10n.switchLanguageToArabic
          : l10n.switchLanguageToEnglish,
      excludeSemantics: true,
      child: TextButton(
        onPressed: () => unawaited(applyLanguage(context, preference, target)),
        style: TextButton.styleFrom(
          foregroundColor: onDark ? Colors.white : AppColors.primary,
          minimumSize: const Size(48, kLanguageSwitchHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: Text(
          languageSwitchLabel(isEnglish: isEnglish),
          style: AppText.label.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Puts a slim strip with [LanguageSwitchButton] above [child], at the end of
/// the line, so it mirrors in Arabic. The strip takes the status-bar inset and
/// the screen below it is told that inset is already used.
class LanguageSwitchFrame extends StatelessWidget {
  const LanguageSwitchFrame({
    super.key,
    required this.preference,
    required this.child,
    this.onDark = false,
  });

  final LocalePreference preference;
  final Widget child;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final background = onDark ? AppColors.inverseSurface : AppColors.surface;
    final profile = _carriesChrome(context);
    return ColoredBox(
      color: background,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kLanguageSwitchHeight,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: profile
                      ? const AppChrome(inStrip: true)
                      : LanguageSwitchButton(
                          preference: preference,
                          onDark: onDark,
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _LanguageStrip(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether the screen being built draws her picture and the switch: it is
/// routed and not in [kNoChromeScreens].
bool _carriesChrome(BuildContext context) {
  final id = ScreenScope.of(context);
  return id != null && !_hasNoChrome(id);
}

/// Whether [id] is one of the screens that never carry the chrome. R03 is the
/// workout day: its preview, opened from Home, carries it, and only the screen
/// she trains on, once a session is live, does not.
bool _hasNoChrome(String id) =>
    kNoChromeScreens.contains(id) ||
    (id == 'R03' && WorkoutSessionState.instance.isLive);

/// Marks that a [LanguageSwitchFrame] strip above this subtree already
/// carries the switch (and her picture, on a screen that has one), so
/// [AppChrome] below it draws nothing more.
class _LanguageStrip extends InheritedWidget {
  const _LanguageStrip({required super.child});

  static bool isAbove(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_LanguageStrip>() != null;

  @override
  bool updateShouldNotify(_LanguageStrip old) => false;
}

/// Screens that never carry the profile picture or the language switch: the
/// live workout, the camera and ID screens (M16 is the Record camera), sign-in
/// and the setup questions, the safety sheet (M08) and the coach's preview of
/// what a client sees (B10), which must show only what the client would.
/// R03 is left out on purpose: it is in this list only while a session is
/// live (see `_hasNoChrome`).
const Set<String> kNoChromeScreens = {
  'R04',
  'R05',
  'R06',
  'R07',
  'R08',
  'R09',
  'R13',
  'C01',
  'C02',
  'C03',
  'C04',
  'C05',
  'C06',
  'C07',
  'C08',
  'C09',
  'C09b',
  'C10',
  'C10b',
  'C11',
  'C12',
  'C13',
  'C14',
  'C15',
  'E12',
  'M08',
  'M16',
  'B10',
};

/// Screens that already show her own picture in their page, so the chrome
/// adds only the switch there.
const Set<String> _ownPictureScreens = {'A02', 'K07'};

/// Her profile picture and the language switch, side by side, for the end of
/// a header. Drawn on every routed screen except [kNoChromeScreens].
///
/// The picture opens A02. A02 and K07 already show her picture, so they get
/// only the switch. A screen under a
/// [LanguageSwitchFrame] strip gets its chrome from the strip, so a header
/// below it draws nothing.
class AppChrome extends StatelessWidget {
  const AppChrome({
    super.key,
    this.avatarSize = 48,
    this.firstName,
    this.onOpenProfile,
    this.routedOnly = false,
    this.inStrip = false,
  });

  final double avatarSize;
  final String? firstName;

  /// Replaces the default way into A02.
  final VoidCallback? onOpenProfile;

  /// Draws nothing outside the router, where no [ScreenScope] names the
  /// screen. A header uses this so a widget test that pumps one screen
  /// directly sees the header it always had.
  final bool routedOnly;

  /// Set by the strip itself, which is the one place allowed to draw while a
  /// strip is above.
  final bool inStrip;

  /// Whether a header built here would draw anything: false outside the
  /// router when [routedOnly], on the no-chrome screens, and under a strip.
  static bool shownFor(BuildContext context, {bool routedOnly = true}) {
    final id = ScreenScope.of(context);
    if (id == null) return !routedOnly;
    if (_hasNoChrome(id)) return false;
    return !_LanguageStrip.isAbove(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!inStrip && !shownFor(context, routedOnly: routedOnly)) {
      return const SizedBox.shrink();
    }
    final id = ScreenScope.of(context);
    final open = onOpenProfile ?? (() => openScreen(context, 'A02'));
    final picture = !_ownPictureScreens.contains(id);
    // The label is a few characters: past 1.3 it stops growing so the title
    // keeps its room, and its 48 point target does not change.
    final scaler = MediaQuery.textScalerOf(context);
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: scaler.clamp(maxScaleFactor: 1.3)),
      // The strip sits above any Scaffold, and the picture's ink needs a
      // Material of its own to land on.
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LanguageSwitchButton(preference: AppRouter.localePreference),
            if (picture)
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Center(
                  child: AppAvatar(
                    size: avatarSize,
                    firstName: firstName,
                    onOpenProfile: open,
                  ),
                ),
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
