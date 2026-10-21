/// Y09 — Log a period.
///
/// Matches `screens-cycle.mjs` → `Y09`. Add, edit and delete.
///
/// ## An impossible date is refused before any write
///
/// `P0-CYC-10`: "Each is refused on screen with the reason, before any write is
/// attempted. No document is created, so there is nothing to undo and nothing to
/// sync."
///
/// [PeriodEntry.validate] is the only way to build a [PeriodEntry], so this
/// screen cannot hand the repository something invalid even by mistake — the
/// refusal is a property of the type, and the on-screen message is only how it
/// is reported. The picker additionally refuses to *offer* a future date
/// (`lastDate` is today), so the common case never reaches validation at all;
/// the validation is there for the case where it does.
///
/// ## Editing a start date rewrites the id
///
/// The id **is** the start date (spine C1), so changing it is a delete plus a
/// create in one transaction ([PeriodRepository.replace]), and `recentStarts` is
/// rebuilt inside that transaction. That is what makes the screen's own note —
/// "editing a date clears estimates built on the old one" — structurally true
/// rather than a promise the sheet makes.
///
/// ## Why the date picker is Material's
///
/// It is fully localised by `MaterialLocalizations` in both languages and needs
/// no dictionary strings, so it adds no untranslated English. It is also not a
/// confirmation: §2 rule 9 bans asking "are you sure" before a log, and a picker
/// is how she supplies the value, not a prompt asking her to approve one.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_state/haptics.dart';
import '../../../domain/clock/app_clock.dart';
import '../../../domain/format/date_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/cycle_repository.dart';
import '../domain/period_entry.dart';

class LogPeriodView extends StatefulWidget {
  const LogPeriodView({
    super.key,
    this.repository,
    this.existing,
    this.now,
    this.onBack,
    this.onSaved,
    this.onSavedPeriod,
    this.onDeleted,
  });

  final PeriodRepository? repository;

  /// The period being edited, or null when logging a new one.
  final PeriodEntry? existing;

  final DateTime? now;
  final VoidCallback? onBack;
  final VoidCallback? onSaved;

  /// The same moment as [onSaved], with what was saved, so the caller can say
  /// it back to her.
  final ValueChanged<PeriodEntry>? onSavedPeriod;

  final VoidCallback? onDeleted;

  @override
  State<LogPeriodView> createState() => _LogPeriodViewState();
}

class _LogPeriodViewState extends State<LogPeriodView> {
  late DateTime _start = widget.existing?.start ?? _today;
  late DateTime? _end = widget.existing?.end;

  /// The reasons the last attempt was refused. Empty until she tries.
  Set<PeriodProblem> _problems = const <PeriodProblem>{};

  /// The entry is written and the tick is drawing; Save waits so a second
  /// tap cannot write it again.
  bool _saved = false;

  DateTime get _today => dayOnly(widget.now ?? AppClock.now());

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(_today.year - 2),
      // A future start is not offered in the first place.
      lastDate: _today,
    );
    if (picked != null) setState(() => _start = dayOnly(picked));
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end ?? _start,
      // An end before the start is not offered either.
      firstDate: _start,
      lastDate: _today,
    );
    if (picked != null) setState(() => _end = dayOnly(picked));
  }

  Future<void> _save() async {
    final result = PeriodEntry.validate(
      start: _start,
      end: _end,
      today: _today,
    );

    if (result is PeriodInvalid) {
      // Refused. Nothing is written — there is no entry to write.
      setState(() => _problems = result.problems);
      return;
    }

    setState(() => _problems = const <PeriodProblem>{});
    final entry = (result as PeriodValid).entry;
    final repository = widget.repository;

    if (repository != null) {
      final existing = widget.existing;
      if (existing != null && existing.id != entry.id) {
        // The start date changed, so the id changed. Delete plus create.
        await repository.replace(oldId: existing.id, entry: entry);
      } else {
        await repository.save(entry);
      }
    }

    if (!mounted) return;
    // Saved: she feels it and sees the tick drawn before the page moves on.
    unawaited(AppHaptics.play(HapticMoment.actionDone));
    setState(() => _saved = true);
    if (!handMotionOff(context)) await Future<void>.delayed(HandMotion.draw);
    if (!mounted) return;
    widget.onSaved?.call();
    widget.onSavedPeriod?.call(entry);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing != null) await widget.repository?.remove(existing.id);
    if (!mounted) return;
    widget.onDeleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final refused = _problems.isNotEmpty;

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.myCycle,
        onBack: widget.onBack,
        leadingIcon: Icons.close,
      ),
      footer: [
        if (_saved)
          const Center(child: HandTick(size: 28, seed: 21, drawOn: true)),
        AppButton(l10n.save, onPressed: _saved ? null : _save),
        Row(
          children: [
            if (widget.existing != null)
              Expanded(
                child: AppButton(
                  l10n.deleteThisPeriod,
                  variant: AppButtonVariant.text,
                  height: 44,
                  fontSize: 15,
                  onPressed: _delete,
                ),
              ),
            Expanded(
              child: AppButton(
                l10n.cancel,
                variant: AppButtonVariant.text,
                height: 44,
                fontSize: 15,
                onPressed: widget.onBack,
              ),
            ),
          ],
        ),
      ],
      children: [
        Text(l10n.noteAPeriod, style: AppText.titleL),
        AppField(
          label: l10n.startDate,
          hint: dayMonthYearLabel(l10n, _start),
          // One message covers both refusals; the dictionary carries it as a
          // single sentence naming both rules.
          errorText: _problems.contains(PeriodProblem.startInFuture)
              ? l10n.futureDatesAreNotAcceptedAndAn
              : '',
          trailing: IconButton(
            tooltip: l10n.startDate,
            onPressed: _pickStart,
            icon: const Icon(
              Icons.calendar_month,
              size: 22,
              color: AppColors.primaryDim,
            ),
          ),
        ),
        AppField(
          label: l10n.endDate,
          // "Still bleeding" is what null means, and it is derived from the
          // absence of an end date rather than stored beside it.
          hint: _end == null
              ? l10n.stillBleeding
              : dayMonthYearLabel(l10n, _end!),
          errorText:
              _problems.contains(PeriodProblem.endBeforeStart) ||
                  _problems.contains(PeriodProblem.endInFuture)
              ? l10n.futureDatesAreNotAcceptedAndAn
              : '',
          trailing: IconButton(
            tooltip: l10n.endDate,
            onPressed: _pickEnd,
            icon: const Icon(
              Icons.calendar_month,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        if (!refused)
          Text(
            l10n.futureDatesAreNotAcceptedAndAn,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// "Period saved · 2026-10-01 to 2026-10-05", or "from 2026-10-01" while it is
/// still going.
String periodSavedLabel(AppL10n l10n, PeriodEntry entry) {
  final end = entry.end;
  return end == null
      ? l10n.periodSavedFromStart(dayMonthYearLabel(l10n, entry.start))
      : l10n.periodSavedStartToEnd(
          dayMonthYearLabel(l10n, entry.start),
          dayMonthYearLabel(l10n, end),
        );
}

/// "Period removed · 2026-10-01 to 2026-10-05".
String periodRemovedLabel(AppL10n l10n, PeriodEntry entry) {
  final end = entry.end;
  return end == null
      ? l10n.periodRemovedFromStart(dayMonthYearLabel(l10n, entry.start))
      : l10n.periodRemovedStartToEnd(
          dayMonthYearLabel(l10n, entry.start),
          dayMonthYearLabel(l10n, end),
        );
}
