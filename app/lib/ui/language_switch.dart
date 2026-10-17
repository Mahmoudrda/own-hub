/// A small "العربية" / "English" button that is on every screen she might land
/// on in the wrong language.
///
/// It reuses [applyLanguage], the one setter the welcome chips and the
/// language screen use, so it stores the choice and switches the app at once.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../features/signup/domain/locale_preference.dart';
import '../features/signup/presentation/language_view.dart'
    show applyLanguage, languageSwitchLabel;
import '../l10n/app_l10n.dart';
import '../theme/app_tokens.dart';

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
                  child: LanguageSwitchButton(
                    preference: preference,
                    onDark: onDark,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
