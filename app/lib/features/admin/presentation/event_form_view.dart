/// Z18 — Add or edit an event, publish it, take it back to draft, or cancel it.
///
/// Titles and descriptions in both languages: an Arabic member reads the
/// Arabic, an English one the English, and the title may not be blank in
/// either, because the rules refuse it. Times are typed in Cairo time, which is
/// what members are shown. An online event takes an `https` link; an event in
/// person takes a place's name, an optional street address and an optional
/// Google Maps link. Seats are optional, but members can reserve only on an
/// event that has them, and the count of reserved seats is the server's: this
/// form never writes it. Pictures and clips are chosen from the media library
/// by name, at most six and two.
///
/// Cancelling asks once, inline, rather than in a dialog: the console raises
/// no dialogs (see `admin_never_reads_user_data_test.dart`), and a cancelled
/// event can be put back to draft, so the step is a confirmation and not a
/// warning.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_scaffold.dart';
import '../../events/domain/event_draft.dart';
import '../../events/domain/event_repository.dart';
import '../../events/domain/hub_event.dart';
import 'admin_widgets.dart';

class EventFormView extends StatefulWidget {
  const EventFormView({
    super.key,
    required this.store,
    this.event,
    this.mediaNames = const [],
    this.onSaved,
    this.onFailed,
    this.onClose,
  });

  final EventAdminStore store;

  /// Null adds a new event.
  final HubEvent? event;

  /// Pictures in the media library, to choose a cover from.
  final List<String> mediaNames;

  /// Called once the event is stored, with what was stored.
  final ValueChanged<HubEvent>? onSaved;

  /// Called when the store refused or could not be reached.
  final VoidCallback? onFailed;

  final VoidCallback? onClose;

  @override
  State<EventFormView> createState() => _EventFormViewState();
}

class _EventFormViewState extends State<EventFormView> {
  late final EventDraft _initial = widget.event == null
      ? const EventDraft()
      : EventDraft.of(widget.event!);

  late final Map<EventField, TextEditingController> _text = {
    EventField.titleEn: TextEditingController(text: _initial.titleEn),
    EventField.titleAr: TextEditingController(text: _initial.titleAr),
    EventField.descriptionEn: TextEditingController(
      text: _initial.descriptionEn,
    ),
    EventField.descriptionAr: TextEditingController(
      text: _initial.descriptionAr,
    ),
    EventField.startsAt: TextEditingController(text: _initial.startsAt),
    EventField.endsAt: TextEditingController(text: _initial.endsAt),
    EventField.link: TextEditingController(text: _initial.link),
    EventField.placeName: TextEditingController(text: _initial.placeName),
    EventField.locationAddress: TextEditingController(
      text: _initial.locationAddress,
    ),
    EventField.locationUrl: TextEditingController(text: _initial.locationUrl),
    EventField.capacity: TextEditingController(text: _initial.capacity),
  };

  late EventMode _mode = _initial.mode;
  late String? _cover = _initial.coverFile;
  late List<String> _images = [..._initial.imageFiles];
  late List<String> _videos = [..._initial.videoFiles];
  Map<EventField, EventProblem> _problems = const {};
  bool _confirmingCancel = false;
  bool _saving = false;

  EventStatus? get _status => widget.event?.status;

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  EventDraft get _draft => EventDraft(
    titleEn: _text[EventField.titleEn]!.text,
    titleAr: _text[EventField.titleAr]!.text,
    descriptionEn: _text[EventField.descriptionEn]!.text,
    descriptionAr: _text[EventField.descriptionAr]!.text,
    startsAt: _text[EventField.startsAt]!.text,
    endsAt: _text[EventField.endsAt]!.text,
    mode: _mode,
    link: _text[EventField.link]!.text,
    placeName: _text[EventField.placeName]!.text,
    locationAddress: _text[EventField.locationAddress]!.text,
    locationUrl: _text[EventField.locationUrl]!.text,
    capacity: _text[EventField.capacity]!.text,
    seatsTaken: _initial.seatsTaken,
    coverFile: _cover,
    imageFiles: _images,
    videoFiles: _videos,
  );

  Future<void> _save(EventStatus status) async {
    final draft = _draft;
    final problems = draft.problems();
    setState(() {
      _problems = problems;
      _confirmingCancel = false;
    });
    if (problems.isNotEmpty || _saving) return;
    final id = widget.event?.id ?? widget.store.newId();
    final event = draft.toEvent(id: id, status: status)!;
    setState(() => _saving = true);
    try {
      await widget.store.save(event);
      if (!mounted) return;
      setState(() => _saving = false);
      widget.onSaved?.call(event);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      widget.onFailed?.call();
    }
  }

  String _message(AppL10n l10n, EventProblem? problem) => switch (problem) {
    null => '',
    EventProblem.required => l10n.requiredLabel,
    EventProblem.tooLong => l10n.thisIsLongerThanTheAppAllows,
    EventProblem.badTime => l10n.useTheFormat2026110518,
    EventProblem.endBeforeStart => l10n.theEndMustComeAfterTheStart,
    EventProblem.badLink => l10n.useALinkThatStartsWithHttps,
    EventProblem.badCapacity => l10n.aWholeNumberAboveZero,
    EventProblem.capacityBelowSeats => l10n.nSeatsAreAlreadyReservedSoThe(
      countLabel(_initial.seatsTaken),
    ),
    EventProblem.badMapsLink => l10n.useALinkFromGoogleMaps,
    EventProblem.tooMany => l10n.chooseAtMostPicturesPicturesAndClips(
      countLabel(EventMediaLimits.pictures),
      countLabel(EventMediaLimits.clips),
    ),
    EventProblem.badFile => l10n.checkThisFileName,
  };

  /// Picks or drops [name] in [chosen], keeping the order she picked them in.
  List<String> _toggled(List<String> chosen, String name) =>
      chosen.contains(name)
      ? [
          for (final n in chosen)
            if (n != name) n,
        ]
      : [...chosen, name];

  Widget _picker(
    AppL10n l10n,
    EventField field,
    List<String> options,
    List<String> chosen,
    String empty,
    ValueChanged<String> onToggle,
  ) {
    final problem = _problems[field];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (options.isEmpty)
          Text(
            empty,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          )
        else
          AppChipRow(
            grow: false,
            items: options,
            selected: {
              for (final n in chosen)
                if (options.contains(n)) options.indexOf(n),
            },
            onTap: (i) => onToggle(options[i]),
          ),
        if (problem != null)
          Text(
            _message(l10n, problem),
            style: AppText.bodyM.copyWith(color: AppColors.error),
          ),
      ],
    );
  }

  Widget _field(
    AppL10n l10n,
    EventField field,
    String label, {
    String helper = '',
    TextDirection? direction,
    TextInputType? keyboard,
    int? maxLines = 1,
  }) => AppField(
    controller: _text[field],
    label: label,
    helper: helper,
    errorText: _message(l10n, _problems[field]),
    textDirection: direction,
    keyboardType: keyboard,
    maxLines: maxLines,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final status = _status;
    final pictures = [
      for (final n in widget.mediaNames)
        if (isEventPictureName(n)) n,
    ];
    final clips = [
      for (final n in widget.mediaNames)
        if (isEventClipName(n)) n,
    ];
    final covers = <String?>[null, ...pictures];

    return AppScaffold(
      appBar: AppTopBar(
        title: widget.event == null ? l10n.addAnEvent : l10n.editAnEvent,
        leadingIcon: Icons.close,
        onBack: widget.onClose,
      ),
      footer: _actions(l10n, status),
      children: [
        _field(
          l10n,
          EventField.titleEn,
          l10n.titleEnglish,
          direction: TextDirection.ltr,
        ),
        _field(
          l10n,
          EventField.titleAr,
          l10n.titleArabic,
          direction: TextDirection.rtl,
        ),
        _field(
          l10n,
          EventField.descriptionEn,
          l10n.descriptionEnglish,
          direction: TextDirection.ltr,
          maxLines: null,
        ),
        _field(
          l10n,
          EventField.descriptionAr,
          l10n.descriptionArabic,
          direction: TextDirection.rtl,
          maxLines: null,
        ),
        _field(
          l10n,
          EventField.startsAt,
          l10n.startsCairoTime,
          helper: l10n.dateAndTimeLike20261105,
          direction: TextDirection.ltr,
          keyboard: TextInputType.datetime,
        ),
        _field(
          l10n,
          EventField.endsAt,
          l10n.endsCairoTime,
          helper: l10n.dateAndTimeLike20261105,
          direction: TextDirection.ltr,
          keyboard: TextInputType.datetime,
        ),
        AppChipRow(
          items: [l10n.online, l10n.inPerson],
          selected: {_mode == EventMode.online ? 0 : 1},
          onTap: (i) => setState(
            () => _mode = i == 0 ? EventMode.online : EventMode.place,
          ),
        ),
        if (_mode == EventMode.online)
          _field(
            l10n,
            EventField.link,
            l10n.linkStartingWithHttps,
            direction: TextDirection.ltr,
            keyboard: TextInputType.url,
          )
        else
          _field(
            l10n,
            EventField.placeName,
            l10n.placeName,
            helper: l10n.theVenuesNameLikeZamalekLadiesGym,
          ),
        if (_mode == EventMode.place) ...[
          _field(l10n, EventField.locationAddress, l10n.streetAddressOptional),
          _field(
            l10n,
            EventField.locationUrl,
            l10n.googleMapsLinkOptional,
            helper: l10n.shareThePlaceFromGoogleMapsAnd,
            direction: TextDirection.ltr,
            keyboard: TextInputType.url,
          ),
        ],
        _field(
          l10n,
          EventField.capacity,
          l10n.seatsMembersCanReserveOptional,
          helper: l10n.reservingWorksOnlyWhenThisIsSet,
          direction: TextDirection.ltr,
          keyboard: TextInputType.number,
        ),
        AdminSectionHead(l10n.coverPicture),
        // The id `tool/admin_access.sh upload-media events <id>` needs. A new
        // event has one only once it is saved, as a draft or published.
        if (widget.event case final saved?)
          SelectableText(
            l10n.uploadItsPicturesUnderThisIdId(saved.id),
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        if (pictures.isEmpty)
          Text(
            l10n.noPicturesInTheMediaLibraryYet,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          )
        else
          AppChipRow(
            grow: false,
            items: [for (final c in covers) c ?? l10n.none],
            selected: {covers.indexOf(_cover)},
            onTap: (i) => setState(() => _cover = covers[i]),
          ),
        AdminSectionHead(l10n.eventPictures),
        _picker(
          l10n,
          EventField.imageFiles,
          pictures,
          _images,
          l10n.noPicturesInTheMediaLibraryYet,
          (name) => setState(() => _images = _toggled(_images, name)),
        ),
        AdminSectionHead(l10n.eventVideos),
        _picker(
          l10n,
          EventField.videoFiles,
          clips,
          _videos,
          l10n.noVideosInTheMediaLibraryYet,
          (name) => setState(() => _videos = _toggled(_videos, name)),
        ),
        if (_confirmingCancel) ...[
          Text(l10n.membersWillNoLongerSeeIt, style: AppText.body),
          AppButton(
            l10n.yesCancelIt,
            variant: AppButtonVariant.outlined,
            onPressed: () => _save(EventStatus.cancelled),
          ),
          AppButton(
            l10n.keepIt,
            variant: AppButtonVariant.text,
            onPressed: () => setState(() => _confirmingCancel = false),
          ),
        ],
      ],
    );
  }

  List<Widget> _actions(AppL10n l10n, EventStatus? status) {
    final busy = _saving;
    VoidCallback? act(VoidCallback f) => busy ? null : f;
    return switch (status) {
      null || EventStatus.draft => [
        AppButton(
          l10n.publish,
          onPressed: act(() => _save(EventStatus.published)),
        ),
        AppButton(
          l10n.saveAsDraft,
          variant: AppButtonVariant.outlined,
          onPressed: act(() => _save(EventStatus.draft)),
        ),
      ],
      EventStatus.published => [
        AppButton(
          l10n.save,
          onPressed: act(() => _save(EventStatus.published)),
        ),
        AppButton(
          l10n.moveBackToDraft,
          variant: AppButtonVariant.outlined,
          onPressed: act(() => _save(EventStatus.draft)),
        ),
        AppButton(
          l10n.cancelThisEvent,
          variant: AppButtonVariant.text,
          onPressed: act(() => setState(() => _confirmingCancel = true)),
        ),
      ],
      EventStatus.cancelled => [
        AppButton(
          l10n.moveBackToDraft,
          onPressed: act(() => _save(EventStatus.draft)),
        ),
      ],
    };
  }
}
