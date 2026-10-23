/// The two ways a setup screen asks for an answer.
///
/// [IntakeOption] is the prototype's `opt()` helper, defined once at the top of
/// `6-v2/src/screens-onboarding.mjs` and used on O01, O02 and O04.
/// [IntakeAnswerGroup] is its `col(m(label) + chipRow(...))` pattern, used on
/// O02 and O04's shorter answers. Both live here for the same reason the
/// prototype declares them once: several copies of a selected-row is how several
/// screens end up marking a choice several slightly different ways.
library;

import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../../ui/app_list_item.dart';

/// One answer in a list of answers.
///
/// [AppListItem] with the prototype's geometry — `card()`'s large radius, 14×16
/// padding, `titleM` over `bodyM` — plus the thing that makes it an *option*:
/// the choice is marked by a **shape**, a filled tick against an empty ring, and
/// not only by the border colour. Colour alone is not a reliable signal, and
/// this is the screen where she has to be able to see what she picked.
class IntakeOption extends StatelessWidget {
  const IntakeOption({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.selected,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: AppListItem(
        title: title,
        subtitle: subtitle,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        borderRadius: AppRadius.lg,
        variant: selected ? AppCardVariant.selected : AppCardVariant.outlined,
        onTap: onTap,
        trailing: selected
            ? const Icon(Icons.check_circle, size: 24, color: AppColors.primary)
            : Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // The ring that says "not this one", beside a filled tick
                  // that says "this one". A selection state is meaning, so it
                  // takes `outline` and not the decorative hairline role.
                  border: Border.all(color: AppColors.outline, width: 2),
                ),
              ),
      ),
    );
  }
}

/// A quiet label above a row of answers — `col(m(label) + …, { gap: 8 })`.
///
/// The label is `bodyM` in `onSurfaceVariant` rather than a heading, because on
/// O03 there are two of these on one screen and two headings would compete with
/// the question itself.
class IntakeAnswerGroup extends StatelessWidget {
  const IntakeAnswerGroup({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
