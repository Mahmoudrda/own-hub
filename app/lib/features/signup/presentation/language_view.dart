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
library;

import 'package:flutter/material.dart';

import '../../../app_state/app_changes.dart';
import '../../../l10n/app_l10n.dart';
import '../../../main.dart' show LocaleScope;
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/locale_preference.dart';

class LanguageView extends StatefulWidget {
  const LanguageView({super.key, required this.preference, this.onContinue});

  final LocalePreference preference;
  final VoidCallback? onContinue;

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

  AppLanguage get _effective =>
      _selected ??
      AppLanguage.fromCode(
        WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'en'
            ? 'en'
            : 'ar',
      );

  Future<void> _choose(AppLanguage language) async {
    setState(() => _selected = language);
    await widget.preference.write(language);
    // The language is one of the things written to the phone, and this is the
    // signal the storage layer listens to. Without it she would pick Arabic,
    // close the app and open it again in English.
    AppChanges.bump();
    if (!mounted) return;
    // Apply it now, so the change is visible rather than promised.
    LocaleScope.of(context).value = language.locale;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final selected = _effective;

    return AppScaffold(
      appBar: const AppTopBar(),
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
          subtitle: l10n.arabicText_vqu26,
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
