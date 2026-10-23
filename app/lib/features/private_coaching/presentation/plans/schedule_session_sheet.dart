/// A coach proposes a live session: a date and time picked in Cairo time, 30, 45
/// or 60 minutes, and a Google Meet or Zoom link.
///
/// The checks are the server's, found before the call: the start is at least 15
/// minutes away and before her coaching ends, the link is an allowed meeting
/// link, and the package still has a session to give. The server decides.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_chip_row.dart';
import '../../../../ui/app_field.dart';
import '../../../../ui/app_sheet.dart';
import '../../../../domain/format/number_label.dart';
import '../../../events/domain/cairo_time.dart';
import '../../data/coaching_repository.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/coaching_failure.dart';
import '../../domain/session_link.dart';
import '../../domain/subscription.dart';
import '../coach/coach_text.dart';
import '../coaching_when.dart';

/// The server keeps a new session at least this far from now.
const Duration kSessionLead = Duration(minutes: 15);

/// Sessions that count against the package: all but the cancelled and the
/// declined.
int sessionsCounted(Iterable<LiveSession> sessions) => sessions
    .where(
      (s) =>
          s.status != SessionStatus.cancelled &&
          s.status != SessionStatus.declined,
    )
    .length;

/// What is wrong with a proposed session, found before the call.
enum SessionProblem { time, tooSoon, afterEnd, link, noneLeft }

/// The first refusal the server would give, or null.
SessionProblem? sessionProblem({
  required String typedTime,
  required String link,
  required Subscription subscription,
  required Iterable<LiveSession> sessions,
  required DateTime now,
}) {
  if (sessionsCounted(sessions) >= subscription.sessionsIncluded) {
    return SessionProblem.noneLeft;
  }
  final at = parseCairo(typedTime);
  if (at == null) return SessionProblem.time;
  if (at.isBefore(now.toUtc().add(kSessionLead))) return SessionProblem.tooSoon;
  final end = subscription.endsAt;
  if (end != null && at.isAfter(end)) return SessionProblem.afterEnd;
  if (!sessionLinkAllowed(link.trim())) return SessionProblem.link;
  return null;
}

Future<void> showScheduleSessionSheet({
  required BuildContext context,
  required CoachingRepository repository,
  required Subscription subscription,
  required List<LiveSession> sessions,
  String clientName = '',
  DateTime Function()? now,
  VoidCallback? onScheduled,
}) => showAppSheet<void>(
  context: context,
  children: [
    ScheduleSessionSheet(
      repository: repository,
      subscription: subscription,
      sessions: sessions,
      clientName: clientName,
      now: now,
      onScheduled: onScheduled,
    ),
  ],
);

class ScheduleSessionSheet extends StatefulWidget {
  const ScheduleSessionSheet({
    super.key,
    required this.repository,
    required this.subscription,
    required this.sessions,
    this.clientName = '',
    this.now,
    this.onScheduled,
  });

  final CoachingRepository repository;
  final Subscription subscription;

  /// The sessions of this subscription so far.
  final List<LiveSession> sessions;
  final String clientName;
  final DateTime Function()? now;
  final VoidCallback? onScheduled;

  @override
  State<ScheduleSessionSheet> createState() => _ScheduleSessionSheetState();
}

class _ScheduleSessionSheetState extends State<ScheduleSessionSheet> {
  DateTime? _at;
  final TextEditingController _link = TextEditingController();
  int _minutes = CoachingLimits.sessionMinutes.first;
  bool _busy = false;
  bool _sent = false;
  String _error = '';

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  String _problemText(AppL10n l10n, SessionProblem p) => switch (p) {
    SessionProblem.time => l10n.chooseADateAndTime,
    SessionProblem.tooSoon => l10n.pickATimeAtLeastMinutesMinutes(
      '${kSessionLead.inMinutes}',
    ),
    SessionProblem.afterEnd => l10n.thatTimeIsAfterHerCoachingEnds,
    SessionProblem.link => l10n.thatLinkIsNotAllowedUseGoogle,
    SessionProblem.noneLeft => l10n.noSessionsLeftInThisPackage,
  };

  DateTime get _now => (widget.now ?? DateTime.now)();

  SessionProblem? get _problem => sessionProblem(
    typedTime: _at == null ? '' : formatCairo(_at!),
    link: _link.text,
    subscription: widget.subscription,
    sessions: widget.sessions,
    now: _now,
  );

  /// The platform date picker, then the time picker, both on Cairo's clock.
  Future<void> _pickTime() async {
    final earliest = toCairo(_now.add(kSessionLead));
    final first = DateTime(earliest.year, earliest.month, earliest.day);
    final end = widget.subscription.endsAt;
    final lastDay = end == null
        ? first.add(const Duration(days: 365))
        : toCairo(end);
    final last = DateTime(lastDay.year, lastDay.month, lastDay.day);
    final date = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: first,
      lastDate: last.isBefore(first) ? first : last,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (time == null || !mounted) return;
    final picked = parseCairo(
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} '
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}',
    );
    setState(() {
      _at = picked;
      _error = '';
    });
  }

  Future<void> _send() async {
    final l10n = AppL10n.of(context);
    final problem = _problem;
    if (problem != null) {
      setState(() => _error = _problemText(l10n, problem));
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await widget.repository.scheduleLiveSession(
        subId: widget.subscription.id,
        startsAt: _at!,
        minutes: _minutes,
        link: _link.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sent = true;
      });
      widget.onScheduled?.call();
    } on CoachingFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = coachFailureText(l10n, failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final used = widget.subscription.sessionsUsed;
    final included = widget.subscription.sessionsIncluded;
    final none = sessionsCounted(widget.sessions) >= included;
    final problem = _problem;
    final at = _at;
    final shown =
        problem == null ||
            problem == SessionProblem.time ||
            (problem == SessionProblem.link && _link.text.trim().isEmpty)
        ? _error
        : _problemText(l10n, problem);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.scheduleASession, style: AppText.titleL),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.sessionsUsedUsedOfIncluded(
            countLabel(used),
            countLabel(included),
          ),
          key: const ValueKey('session-used'),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (_sent) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.sessionSentNameCanConfirmIt(widget.clientName),
              key: const ValueKey('session-sent'),
              style: AppText.titleS,
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            l10n.done_54ca1,
            key: const ValueKey('session-done'),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ] else if (none)
          Text(
            l10n.noSessionsLeftInThisPackage,
            key: const ValueKey('session-none-left'),
            style: AppText.bodyM.copyWith(color: AppColors.error),
          )
        else ...[
          Text(l10n.startsCairoTime, style: AppText.titleS),
          const SizedBox(height: 6),
          AppButton(
            at == null
                ? l10n.chooseADateAndTime
                : coachWhen(l10n, at, cairo: true),
            key: const ValueKey('session-time'),
            variant: AppButtonVariant.outlined,
            icon: Icons.event_outlined,
            height: 48,
            fontSize: 16,
            onPressed: _busy ? null : _pickTime,
          ),
          const SizedBox(height: 10),
          Text(l10n.length, style: AppText.titleS),
          const SizedBox(height: 6),
          AppChipRow(
            key: const ValueKey('session-minutes'),
            items: [
              for (final m in CoachingLimits.sessionMinutes)
                l10n.nMin(countLabel(m)),
            ],
            selected: {CoachingLimits.sessionMinutes.indexOf(_minutes)},
            onTap: (i) =>
                setState(() => _minutes = CoachingLimits.sessionMinutes[i]),
          ),
          const SizedBox(height: 10),
          AppField(
            key: const ValueKey('session-link'),
            controller: _link,
            label: l10n.meetingLink,
            helper: l10n.aGoogleMeetOrZoomLinkThat,
            onChanged: (_) => setState(() {}),
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.url,
            inputFormatters: [
              LengthLimitingTextInputFormatter(kSessionLinkMax),
            ],
          ),
          if (shown.isNotEmpty) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                shown,
                key: const ValueKey('session-error'),
                style: AppText.bodyM.copyWith(color: AppColors.error),
              ),
            ),
          ],
          const SizedBox(height: 12),
          AppButton(
            l10n.sendToName(widget.clientName),
            key: const ValueKey('session-send'),
            onPressed: _busy || problem != null ? null : _send,
          ),
          const SizedBox(height: 6),
          AppButton(
            l10n.cancel,
            key: const ValueKey('session-cancel'),
            variant: AppButtonVariant.text,
            height: 48,
            fontSize: 16,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}
