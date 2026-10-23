/// T09 — Events. The owner's events that are still to come.
///
/// Behind [Feature.events]. It is a tab of its own where the community's slot
/// is unused, and Home's Upcoming card leads here as well.
///
/// Opening the screen sends nothing about her. Her seat is asked for only when
/// she taps Reserve or Cancel, and the server answers with the count; see
/// `event_seats.dart`. Pictures page sideways, the clip waits for her tap, and
/// the only other outward actions are her taps on the event's link or on its
/// place in Maps.
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
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../train/presentation/exercise_clip_player.dart';
import '../data/event_clip_cache.dart';
import '../domain/event_registration.dart';
import '../domain/hub_event.dart';
import 'event_labels.dart';
import 'event_media.dart';
import 'event_seats.dart';

class EventsView extends StatelessWidget {
  const EventsView({
    super.key,
    this.events = const [],
    this.onBack,
    this.onOpenLink,
    this.registrar,
    this.onSelectTab,
    this.onSeatsChanged,
    this.fetchClip = fetchEventClip,
    this.players,
    this.now,
  });

  /// Published and not over yet, soonest first.
  final List<HubEvent> events;

  final VoidCallback? onBack;

  /// Opens an event's link, or its place in Maps, outside the app.
  final ValueChanged<String>? onOpenLink;

  /// Reserves and gives back seats. Null shows the seats and nothing to tap.
  final EventRegistrar? registrar;

  /// Draws the bottom bar with this tab active. Null when the screen was
  /// opened from Home and has a back button instead.
  final ValueChanged<String>? onSelectTab;

  final void Function(String eventId, int seatsTaken)? onSeatsChanged;

  final EventClipFetcher fetchClip;

  /// Makes the clip player. Null draws the clip's frame and plays nothing.
  final ExerciseClipPlayerFactory? players;

  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final body = AppScaffold(
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
            EventCard(
              key: ValueKey('event-${event.id}'),
              event: event,
              onOpenLink: onOpenLink,
              registrar: registrar,
              onSeatsChanged: onSeatsChanged,
              fetchClip: fetchClip,
              players: players,
              now: now,
            ),
      ],
    );
    if (onSelectTab == null) return body;
    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'T09',
        onSelect: onSelectTab,
      ),
      body: body,
    );
  }
}

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    this.onOpenLink,
    this.registrar,
    this.onSeatsChanged,
    this.fetchClip = fetchEventClip,
    this.players,
    this.now,
  });

  final HubEvent event;
  final ValueChanged<String>? onOpenLink;
  final EventRegistrar? registrar;
  final void Function(String eventId, int seatsTaken)? onSeatsChanged;
  final EventClipFetcher fetchClip;
  final ExerciseClipPlayerFactory? players;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final description = event.description(language);
    final link = event.link;
    final mapsUrl = event.locationUrl;
    final address = event.locationAddress;

    return AppCard(
      children: [
        // Pictures from the content library; each is the drawn placeholder
        // when it cannot be loaded: offline, signed out, or not uploaded yet.
        EventGallery(paths: event.picturePaths),
        for (final path in event.videoPaths)
          EventClipPreview(path: path, fetch: fetchClip, players: players),
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
          eventVenue(l10n, event),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        if (event.mode == EventMode.place && address != null)
          Text(
            address,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        if (description.isNotEmpty) Text(description, style: AppText.body),
        EventSeats(
          event: event,
          registrar: registrar,
          now: now,
          onSeatsChanged: onSeatsChanged,
        ),
        if (event.mode == EventMode.place &&
            mapsUrl != null &&
            isAllowedMapsUrl(mapsUrl) &&
            onOpenLink != null)
          AppButton(
            l10n.openInMaps,
            variant: AppButtonVariant.tonal,
            icon: Icons.map_outlined,
            onPressed: () => onOpenLink!(mapsUrl),
          ),
        if (event.mode == EventMode.online &&
            link != null &&
            onOpenLink != null)
          AppButton(
            l10n.openEventLink,
            variant: AppButtonVariant.tonal,
            icon: Icons.open_in_new,
            onPressed: () => onOpenLink!(link),
          ),
      ],
    );
  }
}
