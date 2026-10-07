/// Home's small Upcoming card: the next event, and a way to all of them.
///
/// Drawn only when [Feature.events] is on and there is something to come.
/// With nothing planned it is not drawn at all: an empty card on Home would be
/// a promise about events that nobody has made.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_chevron.dart';
import '../../../ui/app_list_item.dart';
import '../domain/hub_event.dart';
import 'event_labels.dart';

class UpcomingEventsCard extends StatelessWidget {
  const UpcomingEventsCard({super.key, required this.next, this.onOpen});

  /// The soonest event still to come.
  final HubEvent next;

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return AppListItem(
      leading: const Icon(
        Icons.event_outlined,
        size: 22,
        color: AppColors.primaryDim,
      ),
      title: '${l10n.upcomingEvents} · ${next.title(language)}',
      subtitle: '${eventWhen(l10n, next)} · ${l10n.cairoTime}',
      trailing: const AppChevron(),
      onTap: onOpen,
    );
  }
}
