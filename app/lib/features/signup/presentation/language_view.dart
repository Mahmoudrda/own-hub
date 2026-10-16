/// C02 — Choose your language.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C02`.
///
/// **This screen is bilingual on purpose, and it is the one place in the product
/// where hardcoded Arabic is correct.** She has not chosen a language yet, so the
/// screen cannot be written in a language she may not read: the heading appears
/// in both, and the two options are labelled with their own names. "العربية" and
/// "English" are endonyms — a language's name in itself — and are never
/// translated. Arabic is preselected because this product ships in Egypt.
///
/// The choice applies immediately rather than on Continue, so she sees the app
/// change under her hand and knows it worked. It is stored in the pre-auth mirror
/// (see [LocalePreference]), not in `profile.language`, which does not exist yet.
///
/// The welcome screen carries the same choice as two chips ([LanguageToggle]),
/// so a first run no longer spends a screen confirming the language the app
/// already opened in. Both write through [applyLanguage]. The toggle lives in
/// this file for the reason above: its two labels are endonyms.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_state/app_changes.dart';
import '../../../l10n/app_l10n.dart';
import '../../../main.dart' show LocaleScope;
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/locale_preference.dart';

class LanguageView extends StatefulWidget {
  const LanguageView({
    super.key,
    required this.preference,
    this.onContinue,
    this.onBack,
  });

  final LocalePreference preference;
  final VoidCallback? onContinue;

  /// Null on the way through sign-up, where there is nothing behind this
  /// screen. Set when she opens it from her profile to change the language,
  /// which is a visit rather than a step.
  final VoidCallback? onBack;

  @override
  State<LanguageView> createState() => _LanguageViewState();
}

class _LanguageViewState extends State<LanguageView> {
  AppLanguage? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.preference.read();
  }

  /// Her choice, or else the language the app is showing right now. It was
  /// the phone's language, which ticked Arabic on a French phone while
  /// `main.dart` opened the app in English: the screen said one language and
  /// was written in the other.
  AppLanguage get _effective =>
      _selected ??
      AppLanguage.fromCode(Localizations.localeOf(context).languageCode);

  Future<void> _choose(AppLanguage language) async {
    setState(() => _selected = language);
    await applyLanguage(context, widget.preference, language);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final selected = _effective;

    return AppScaffold(
      appBar: AppTopBar(onBack: widget.onBack),
      footer: [AppButton(l10n.continueLabel, onPressed: widget.onContinue)],
      children: [
        // Both headings, always. See the note at the top of this file.
        Text(
          'اختاري لغتك',
          textDirection: TextDirection.rtl,
          style: AppText.headline.copyWith(color: AppColors.onPrimaryContainer),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose your language',
          textDirection: TextDirection.ltr,
          style: AppText.titleL.copyWith(color: AppColors.onPrimaryContainer),
        ),
        Text(
          l10n.youCanChangeThisAnyTimeIn,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        AppListItem(
          title: 'العربية',
          subtitle: l10n.arabicText_3cakp,
          padding: const EdgeInsets.all(16),
          variant: selected == AppLanguage.arabic
              ? AppCardVariant.selected
              : AppCardVariant.outlined,
          trailing: selected == AppLanguage.arabic
              ? const Icon(
                  Icons.check_circle,
                  size: 26,
                  color: AppColors.primary,
                )
              : null,
          onTap: () => _choose(AppLanguage.arabic),
        ),
        AppListItem(
          title: 'English',
          subtitle: l10n.everythingInTheApp,
          padding: const EdgeInsets.all(16),
          variant: selected == AppLanguage.english
              ? AppCardVariant.selected
              : AppCardVariant.outlined,
          trailing: selected == AppLanguage.english
              ? const Icon(
                  Icons.check_circle,
                  size: 26,
                  color: AppColors.primary,
                )
              : null,
          onTap: () => _choose(AppLanguage.english),
        ),
      ],
    );
  }
}

/// Stores [language] and switches the app to it, now.
///
/// The language is one of the things written to the phone, and the bump is
/// the signal the storage layer listens to. Without it she would pick Arabic,
/// close the app and open it again in English. The switch happens at once, so
/// the change is visible rather than promised.
Future<void> applyLanguage(
  BuildContext context,
  LocalePreference preference,
  AppLanguage language,
) async {
  await preference.write(language);
  AppChanges.bump();
  if (!context.mounted) return;
  LocaleScope.maybeOf(context)?.value = language.locale;
}

/// "English · العربية" as two chips, for the welcome screen.
///
/// Preselected from what the app opened in, which is her phone's language
/// when she has not chosen. One tap switches the whole app and remembers it.
class LanguageToggle extends StatefulWidget {
  const LanguageToggle({super.key, required this.preference});

  final LocalePreference preference;

  @override
  State<LanguageToggle> createState() => _LanguageToggleState();
}

class _LanguageToggleState extends State<LanguageToggle> {
  AppLanguage? _chosen;

  static const List<AppLanguage> _order = [
    AppLanguage.english,
    AppLanguage.arabic,
  ];

  @override
  Widget build(BuildContext context) {
    final current =
        _chosen ??
        widget.preference.read() ??
        AppLanguage.fromCode(Localizations.localeOf(context).languageCode);
    return Semantics(
      container: true,
      child: AppChipRow(
        grow: false,
        items: const ['English', 'العربية'],
        selected: {_order.indexOf(current)},
        onTap: (i) {
          final language = _order[i];
          setState(() => _chosen = language);
          unawaited(applyLanguage(context, widget.preference, language));
        },
      ),
    );
  }
}
