/// Training reminders, as she sees them: the one-time offer on `R10` and the
/// sheet where she picks her days and time.
///
/// The sheet is the same from `R10` and from `A01`, so there is one place the
/// rules live: at least one day, a time she chose, and permission asked only
/// when she taps "Remind me". A refusal is answered on the sheet with the way
/// to Settings, not with a second prompt.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_state/reminder_scheduler.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_sheet.dart';
import '../domain/training_reminders.dart';

/// A weekday's name, Monday = 1.
String reminderWeekdayLabel(AppL10n l10n, int weekday) => switch (weekday) {
  DateTime.monday => l10n.monday,
  DateTime.tuesday => l10n.tuesday,
  DateTime.wednesday => l10n.wednesday,
  DateTime.thursday => l10n.thursday,
  DateTime.friday => l10n.friday,
  DateTime.saturday => l10n.saturday,
  _ => l10n.sunday,
};

/// The offer on `R10`, shown once.
class ReminderOfferCard extends StatelessWidget {
  const ReminderOfferCard({super.key, this.onChooseDays, this.onNotNow});

  final VoidCallback? onChooseDays;
  final VoidCallback? onNotNow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppCard(
      key: const ValueKey('r10-reminder-offer'),
      variant: AppCardVariant.tonal,
      children: [
        Text(l10n.aReminderOnYourTrainingDays, style: AppText.titleM),
        const SizedBox(height: 6),
        Text(
          l10n.oneQuietNoteOnTheDaysYou,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        AppButton(
          l10n.chooseMyDays,
          key: const ValueKey('r10-reminder-choose'),
          variant: AppButtonVariant.outlined,
          height: 48,
          onPressed: onChooseDays,
        ),
        AppButton(
          l10n.notNow,
          key: const ValueKey('r10-reminder-not-now'),
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: onNotNow,
        ),
      ],
    );
  }
}

/// Opens the sheet. Completes when it closes.
Future<void> showReminderSheet(
  BuildContext context, {
  required int sessionsAWeek,
  TrainingReminders? current,
  required Future<ReminderPermission> Function(TrainingReminders) onSave,
  Future<void> Function()? onTurnOff,
  VoidCallback? onOpenSettings,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: AppColors.ink.withValues(alpha: 0.45),
  builder: (_) => ReminderSheet(
    sessionsAWeek: sessionsAWeek,
    current: current,
    onSave: onSave,
    onTurnOff: onTurnOff,
    onOpenSettings: onOpenSettings,
  ),
);

class ReminderSheet extends StatefulWidget {
  const ReminderSheet({
    super.key,
    required this.sessionsAWeek,
    required this.onSave,
    this.current,
    this.onTurnOff,
    this.onOpenSettings,
  });

  /// Her week's target. Decides the days first offered.
  final int sessionsAWeek;

  /// Her reminders now, or null when they are off.
  final TrainingReminders? current;

  /// Asks for permission and schedules. The sheet closes on
  /// [ReminderPermission.granted] and explains anything else in place.
  final Future<ReminderPermission> Function(TrainingReminders) onSave;

  /// Shown only while reminders are on.
  final Future<void> Function()? onTurnOff;

  final VoidCallback? onOpenSettings;

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  late final Set<int> _days = {
    ...widget.current?.weekdays ?? suggestedReminderDays(widget.sessionsAWeek),
  };
  late TimeOfDay _time = TimeOfDay(
    hour: widget.current?.hour ?? TrainingReminders.defaultHour,
    minute: widget.current?.minute ?? 0,
  );
  bool _busy = false;
  ReminderPermission? _refused;

  void _toggle(int day) => setState(() {
    _refused = null;
    if (!_days.remove(day)) _days.add(day);
  });

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_days.isEmpty) return;
    setState(() {
      _busy = true;
      _refused = null;
    });
    final outcome = await widget.onSave(
      TrainingReminders(
        weekdays: _days,
        hour: _time.hour,
        minute: _time.minute,
      ),
    );
    if (!mounted) return;
    if (outcome == ReminderPermission.granted) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _refused = outcome;
    });
  }

  Future<void> _turnOff() async {
    final off = widget.onTurnOff;
    if (off == null) return;
    setState(() => _busy = true);
    await off();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final quiet = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);
    return AppSheet(
      children: [
        Text(l10n.trainingReminders, style: AppText.titleL),
        Text(
          l10n.sessionsInYourWeekCountPickThe('${widget.sessionsAWeek}'),
          style: quiet,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final day in egyptianWeekOrder)
              AppChip(
                reminderWeekdayLabel(l10n, day),
                key: ValueKey('reminder-day-$day'),
                selected: _days.contains(day),
                onTap: _busy ? null : () => _toggle(day),
              ),
          ],
        ),
        if (_days.isEmpty)
          Text(
            l10n.pickAtLeastOneDay,
            key: const ValueKey('reminder-no-day'),
            style: quiet,
          ),
        Row(
          children: [
            Expanded(
              child: Text(
                '${l10n.time}: '
                '${MaterialLocalizations.of(context).formatTimeOfDay(_time)}',
                key: const ValueKey('reminder-time'),
                style: AppText.label,
              ),
            ),
            AppButton(
              l10n.changeTime,
              variant: AppButtonVariant.text,
              height: 44,
              fontSize: 15,
              onPressed: _busy ? null : () => unawaited(_pickTime()),
            ),
          ],
        ),
        if (_refused case final refused?) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              refused == ReminderPermission.denied
                  ? l10n.notificationsAreOffForOwnHubOn
                  : l10n.remindersCannotBeSetOnThisPhone,
              key: const ValueKey('reminder-refused'),
              style: quiet,
            ),
          ),
          if (refused == ReminderPermission.denied &&
              widget.onOpenSettings != null)
            AppButton(
              l10n.openSettings,
              variant: AppButtonVariant.text,
              height: 44,
              fontSize: 15,
              onPressed: widget.onOpenSettings,
            ),
        ],
        AppButton(
          l10n.remindMe,
          key: const ValueKey('reminder-save'),
          onPressed: _busy || _days.isEmpty ? null : () => unawaited(_save()),
        ),
        if (widget.current != null && widget.onTurnOff != null)
          AppButton(
            l10n.turnRemindersOff,
            key: const ValueKey('reminder-off'),
            variant: AppButtonVariant.outlined,
            onPressed: _busy ? null : () => unawaited(_turnOff()),
          ),
      ],
    );
  }
}
