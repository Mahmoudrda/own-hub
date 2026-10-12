/// Z17 — Events. Every event the owner has made, drafts and cancelled ones too.
///
/// Reading every event is an admin read under the rules; a member's app can
/// read published events only. Tapping one opens Z18 to edit, publish or
/// cancel it, and Add opens Z18 empty.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../../events/domain/event_repository.dart';
import '../../events/domain/hub_event.dart';
import '../../events/presentation/event_labels.dart';
import '../domain/console_source.dart';
import 'dashboard_view.dart' show ConsoleFailureNote;

class EventsAdminView extends StatefulWidget {
  const EventsAdminView({
    super.key,
    required this.store,
    this.onBack,
    this.onAdd,
    this.onOpen,
    this.revision = 0,
  });

  final EventAdminStore store;

  /// Moves on every save in Z18, so coming back reads the list again.
  final int revision;
  final VoidCallback? onBack;
  final VoidCallback? onAdd;
  final ValueChanged<HubEvent>? onOpen;

  @override
  State<EventsAdminView> createState() => _EventsAdminViewState();
}

class _EventsAdminViewState extends State<EventsAdminView> {
  List<HubEvent>? _events;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EventsAdminView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Back from Z18 after a save: what was saved there belongs on the list.
    if (oldWidget.revision != widget.revision) _load();
  }

  Future<void> _load() async {
    try {
      final events = await widget.store.all();
      if (!mounted) return;
      setState(() {
        _events = events;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final events = _events;
    return AppScaffold(
      appBar: AppTopBar(title: l10n.events, onBack: widget.onBack),
      footer: [
        AppButton(l10n.addAnEvent, icon: Icons.add, onPressed: widget.onAdd),
      ],
      children: [
        if (_failed)
          ConsoleFailureNote(
            failure: ConsoleFailure.unavailable,
            onRetry: _load,
          )
        else if (events == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (events.isEmpty)
          AppEmptyState(
            icon: Icons.event_outlined,
            title: l10n.noEventsYet,
            body: l10n.addOneThenPublishItWhenIt,
          )
        else
          for (final event in events) _row(l10n, event),
      ],
    );
  }

  Widget _row(AppL10n l10n, HubEvent event) {
    final language = Localizations.localeOf(context).languageCode;
    final (label, background, foreground) = switch (event.status) {
      EventStatus.draft => (
        l10n.draft,
        AppColors.amberContainer,
        AppColors.amber,
      ),
      EventStatus.published => (
        l10n.published,
        AppColors.tertiaryContainer,
        AppColors.onTertiaryContainer,
      ),
      EventStatus.cancelled => (
        l10n.cancelled,
        AppColors.surfaceHigh,
        AppColors.onSurfaceVariant,
      ),
    };
    return AppListItem(
      title: event.title(language),
      subtitle: '${eventWhen(l10n, event)} · ${eventWhere(l10n, event)}',
      trailing: AppPill(label, background: background, foreground: foreground),
      onTap: () => widget.onOpen?.call(event),
    );
  }
}
