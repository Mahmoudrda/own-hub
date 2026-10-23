import 'package:flutter/material.dart';

import '../../../../../l10n/app_l10n.dart';
import '../../../../../ui/app_list_item.dart';
import '../../../../../ui/app_sheet.dart';
import '../../../domain/coach_application.dart';
import '../../../domain/coaching_contract.dart';
import '../apply_labels.dart';
import '../apply_rules.dart';
import '../apply_widgets.dart';

/// Step 1: who she is, as members will see her, and her photo.
class PersonalStep extends StatelessWidget {
  const PersonalStep({
    super.key,
    required this.app,
    required this.problems,
    required this.tools,
    required this.onChanged,
  });

  final CoachApplication app;
  final ApplyProblems problems;
  final ApplyTools tools;
  final ValueChanged<CoachApplication> onChanged;

  CoachPersonal get _p => app.personal;

  void _set(CoachPersonal p) => onChanged(app.copyWith(personal: p));

  Future<void> _pickGovernorate(BuildContext context) async {
    final l10n = AppL10n.of(context);
    final ids = CoachingEnums.governorates;
    final picked = await showAppSheet<String>(
      context: context,
      children: [
        Builder(
          builder: (sheet) => ApplyChoice(
            items: [for (final id in ids) governorateLabel(l10n, id)],
            selected: {
              if (ids.contains(_p.governorate)) ids.indexOf(_p.governorate),
            },
            onTap: (i) => Navigator.of(sheet).pop(ids[i]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
    if (picked != null) _set(_p.copyWith(governorate: picked));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final langs = CoachingEnums.languages;
    final hasGov = CoachingEnums.governorates.contains(_p.governorate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        ApplyTextField(
          initial: _p.fullName,
          label: l10n.fullName,
          helper: l10n.forTheReviewOnlyNeverShownPublicly,
          problem: problems['fullName'],
          maxLength: CoachingLimits.fullNameMax,
          onChanged: (v) => _set(_p.copyWith(fullName: v)),
        ),
        ApplyTextField(
          initial: _p.displayName,
          label: l10n.displayName,
          problem: problems['displayName'],
          maxLength: CoachingLimits.displayNameMax,
          onChanged: (v) => _set(_p.copyWith(displayName: v)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            AppListItem(
              title: hasGov
                  ? governorateLabel(l10n, _p.governorate)
                  : l10n.governorate,
              subtitle: hasGov ? l10n.governorate : '',
              trailing: const Icon(Icons.expand_more),
              onTap: () => _pickGovernorate(context),
            ),
            ApplyErrorLine(problems['governorate']),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            ApplyLabel(l10n.languagesYouCoachIn),
            ApplyChoice(
              items: [for (final id in langs) languageLabel(l10n, id)],
              selected: {
                for (var i = 0; i < langs.length; i++)
                  if (_p.languages.contains(langs[i])) i,
              },
              onTap: (i) {
                final next = List<String>.of(_p.languages);
                next.contains(langs[i])
                    ? next.remove(langs[i])
                    : next.add(langs[i]);
                _set(_p.copyWith(languages: next));
              },
            ),
            ApplyErrorLine(problems['languages']),
          ],
        ),
        ApplyTextField(
          initial: _p.headline,
          label: l10n.headline,
          helper: l10n.minToMaxCharacters(
            '10',
            '${CoachingLimits.headlineMax}',
          ),
          problem: problems['headline'],
          maxLength: CoachingLimits.headlineMax,
          onChanged: (v) => _set(_p.copyWith(headline: v)),
        ),
        ApplyPhotoSlot(
          label: l10n.profilePhoto,
          value: _p.photoPath,
          tools: tools,
          problem: problems['photo'],
          onChanged: (marker, _) => _set(_p.copyWith(photoPath: marker)),
        ),
      ],
    );
  }
}
