/// A coach as a card on the find-a-coach list, and her round photo.
library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_pill.dart';
import '../../domain/coach_profile.dart';
import 'coach_image.dart';
import 'coach_labels.dart';

/// The first letter of her name, past a leading "Coach " or "كوتش ".
String coachInitial(String name) {
  var n = name.trim();
  final m = RegExp(
    r'^(coach|\u0643\u0648\u062A\u0634|\u0643\u0627\u0628\u062A\u0646)\s+',
    caseSensitive: false,
  ).firstMatch(n);
  if (m != null && m.end < n.length) n = n.substring(m.end);
  return n.isEmpty ? '' : n.characters.first;
}

/// Her photo, or the first letter of her display name when there is none or it
/// does not load.
class CoachPhoto extends StatelessWidget {
  const CoachPhoto({
    super.key,
    required this.name,
    required this.photoUrl,
    this.size = 56,
    this.full = false,
  });

  final String name;
  final String? photoUrl;
  final double size;

  /// Load the full-size photo (the portfolio header) instead of the 288 px
  /// avatar copy.
  final bool full;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final initial = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        coachInitial(name),
        style: AppText.titleL.copyWith(
          color: AppColors.onPrimaryContainer,
          fontSize: size * 0.4,
        ),
      ),
    );
    final Widget picture;
    if (url == null || url.isEmpty) {
      picture = initial;
    } else if (url.startsWith('http')) {
      picture = Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => initial,
      );
    } else {
      final small = full ? null : CoachImageBytes.smallPhotoOf(url);
      picture = CoachImage(
        path: small ?? url,
        fallbackPath: small == null ? null : url,
        label: '',
        width: size,
        height: size,
        fallback: initial,
      );
    }
    return Semantics(
      image: true,
      label: AppL10n.of(context).photoOfName(name),
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(child: picture),
      ),
    );
  }
}

class CoachCard extends StatelessWidget {
  const CoachCard({
    super.key,
    required this.coach,
    required this.fromPriceEgp,
    required this.onOpen,
  });

  final CoachProfile coach;

  /// Her cheapest active package for a month, if she has one.
  final int? fromPriceEgp;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final price = fromPriceEgp == null
        ? null
        : coachingPaymentsOn
        ? l10n.fromEgpPriceAMonth(formatEgp(fromPriceEgp!))
        : l10n.freeForNow;
    final languages = <String>[
      for (final key in coach.languages) languageLabel(l10n, key),
    ].join(' · ');
    final spoken = <String>[
      coach.displayName,
      if (coach.headline.isNotEmpty) coach.headline,
      if (price != null) l10n.liveOneToOneVideoSessions,
      ?price,
    ].join('. ');
    return Semantics(
      button: true,
      label: '${l10n.openTheProfileOfName(coach.displayName)}. $spoken',
      excludeSemantics: true,
      child: AppCard(
        onTap: onOpen,
        gap: 10,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoachPhoto(name: coach.displayName, photoUrl: coach.photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coach.displayName,
                      style: AppText.titleM.copyWith(color: AppColors.ink),
                    ),
                    if (coach.headline.isNotEmpty)
                      Text(
                        coach.headline,
                        style: AppText.bodyM.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (coach.badges.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                for (final b in coach.badges)
                  AppPill(
                    badgeLabel(l10n, b),
                    background: b == 'verifiedCoach'
                        ? AppColors.tertiaryContainer
                        : AppColors.primarySoft,
                    foreground: b == 'verifiedCoach'
                        ? AppColors.onTertiaryContainer
                        : AppColors.primaryDim,
                  ),
              ],
            ),
          if (coach.specialties.isNotEmpty)
            Text(
              <String>[
                for (final s in coach.specialties) specialtyLabel(l10n, s),
              ].join(' · '),
              style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
            ),
          if (price != null)
            Text(
              l10n.liveOneToOneVideoSessions,
              style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
            ),
          if (price != null)
            Text(
              price,
              style: AppText.titleS.copyWith(color: AppColors.primary),
            ),
          if (languages.isNotEmpty)
            Text(
              languages,
              style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
