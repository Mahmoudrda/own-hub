/// T09 — Events. The owner's events that are still to come.
///
/// Behind [Feature.events], which ships off: the screen is reachable only once
/// the owner switches it on, and Home's Upcoming card leads here.
///
/// It asks her for nothing. There is no "interested", no RSVP and no count of
/// who is coming, so opening this screen sends nothing about her anywhere; the
/// only outward action is opening the event's own link, and that is her tap.
///
/// Times are Cairo time and say so, because the event happens at one moment
/// for everybody. Digits are Western in both languages.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/content_image.dart';
import '../domain/hub_event.dart';
import 'event_labels.dart';

class EventsView extends StatelessWidget {
  const EventsView({
    super.key,
    this.events = const [],
    this.onBack,
    this.onOpenLink,
  });

  /// Published and not over yet, soonest first.
  final List<HubEvent> events;

  final VoidCallback? onBack;

  /// Opens an online event's link outside the app.
  final ValueChanged<String>? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppScaffold(
      appBar: AppTopBar(title: l10n.upcomingEvents, onBack: onBack),
      children: [
        if (events.isEmpty)
          AppEmptyState(
            icon: Icons.event_outlined,
            title: l10n.noEventsComingUp,
            body: l10n.whenOwnHubPlansOneYouWill,
          )
        else
          for (final event in events)
            EventCard(event: event, onOpenLink: onOpenLink),
      ],
    );
  }
}

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.onOpenLink});

  final HubEvent event;
  final ValueChanged<String>? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final description = event.description(language);
    final link = event.link;

    return AppCard(
      children: [
        // The cover from the content library, or the drawn placeholder when
        // it cannot be loaded: offline, signed out, or not uploaded yet.
        if (event.coverPath != null)
          ContentImage(
            path: event.coverPath,
            height: 120,
            placeholder: const AppMedia(
              height: 120,
              kind: AppMediaKind.photo,
              showPlayButton: false,
            ),
          ),
        Text(event.title(language), style: AppText.titleM),
        Semantics(
          label: '${eventWhen(l10n, event)}, ${l10n.cairoTime}',
          excludeSemantics: true,
          child: Text(
            '${eventWhen(l10n, event)} · ${l10n.cairoTime}',
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        Text(
          eventWhere(l10n, event),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        if (description.isNotEmpty) Text(description, style: AppText.body),
        if (event.mode == EventMode.online &&
            link != null &&
            onOpenLink != null)
          AppButton(
            l10n.openTheLink,
            variant: AppButtonVariant.tonal,
            icon: Icons.open_in_new,
            onPressed: () => onOpenLink!(link),
          ),
      ],
    );
  }
}
