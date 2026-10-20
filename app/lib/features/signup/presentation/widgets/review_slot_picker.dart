/// Day chips over time pills: the next days' free times for the review call.
///
/// One tap on a time books it. Nothing is shown as booked until the server
/// has confirmed it, and a failed load or booking says so in one line without
/// taking anything else away from the waiting screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../data/review_scheduling_repository.dart';

class ReviewSlotPicker extends StatefulWidget {
  const ReviewSlotPicker({
    super.key,
    required this.repository,
    required this.onBooked,
  });

  final ReviewSchedulingRepository repository;

  /// The server confirmed this time.
  final ValueChanged<DateTime> onBooked;

  @override
  State<ReviewSlotPicker> createState() => _ReviewSlotPickerState();
}

enum _Load { loading, failed, ready }

class _ReviewSlotPickerState extends State<ReviewSlotPicker> {
  _Load _load = _Load.loading;
  Map<DateTime, List<ReviewSlot>> _byDay = const {};
  DateTime? _day;
  bool _booking = false;
  bool _bookFailed = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  static DateTime _dayOf(DateTime at) {
    final local = at.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static const int _windowDays = 7;

  Future<void> _fetch() async {
    try {
      final slots = await widget.repository.listSlots(days: _windowDays);
      if (!mounted) return;
      final byDay = <DateTime, List<ReviewSlot>>{};
      final seen = <DateTime>{};
      for (final slot in slots) {
        if (!seen.add(slot.start)) continue;
        byDay.putIfAbsent(_dayOf(slot.start), () => []).add(slot);
      }
      setState(() {
        _byDay = byDay;
        _day = byDay.keys.isEmpty ? null : byDay.keys.reduce(_earlier);
        _load = _Load.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _load = _Load.failed);
    }
  }

  static DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  Future<void> _book(ReviewSlot slot) async {
    if (_booking) return;
    setState(() {
      _booking = true;
      _bookFailed = false;
    });
    try {
      final at = await widget.repository.book(slot);
      if (!mounted) return;
      widget.onBooked(at);
    } catch (_) {
      if (!mounted) return;
      setState(() => _bookFailed = true);
      // The slot may be gone; show what is free now.
      unawaited(_fetch());
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final quiet = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);
    final locale = Localizations.localeOf(context).toString();
    final material = MaterialLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Text(l10n.pickATimeForYourCall, style: AppText.titleM),
        switch (_load) {
          _Load.loading => const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
          _Load.failed => Text(
            l10n.weCouldNotLoadTheFreeTimes,
            key: const ValueKey('slots-failed'),
            style: quiet,
          ),
          _Load.ready when _byDay.isEmpty => Text(
            l10n.thereAreNoFreeTimesInThe_bzb9s('$_windowDays'),
            key: const ValueKey('slots-empty'),
            style: quiet,
          ),
          _Load.ready => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final day in (_byDay.keys.toList()..sort()))
                    ChoiceChip(
                      key: ValueKey('slot-day-${day.month}-${day.day}'),
                      label: Text(DateFormat('E d', locale).format(day)),
                      selected: day == _day,
                      onSelected: _booking
                          ? null
                          : (_) => setState(() => _day = day),
                    ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slot in _byDay[_day] ?? const <ReviewSlot>[])
                    ActionChip(
                      key: ValueKey('slot-${slot.start.toIso8601String()}'),
                      label: Text(
                        material.formatTimeOfDay(
                          TimeOfDay.fromDateTime(slot.start.toLocal()),
                        ),
                      ),
                      onPressed: _booking ? null : () => _book(slot),
                    ),
                ],
              ),
            ],
          ),
        },
        if (_bookFailed)
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.weCouldNotBookThatTimePick,
              key: const ValueKey('slots-book-failed'),
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
