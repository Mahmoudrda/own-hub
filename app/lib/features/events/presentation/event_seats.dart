/// The seats line and the Reserve or Cancel button on one event.
///
/// The count comes from the event, and her own state from her attendee
/// document; both move only through the server's answer to her tap. A woman
/// who holds a seat can always give it back, on a full, closed or finished
/// event too, so she is never stuck holding one. An event with no seat limit
/// takes no reservations (the server refuses them), so it shows no seats line
/// and no Reserve button.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_sage_note.dart';
import '../domain/event_registration.dart';
import '../domain/hub_event.dart';

class EventSeats extends StatefulWidget {
  const EventSeats({
    super.key,
    required this.event,
    this.registrar,
    this.now,
    this.onSeatsChanged,
  });

  final HubEvent event;

  /// Null draws the seats line alone, with no way to reserve.
  final EventRegistrar? registrar;

  /// The clock; the phone's by default.
  final DateTime Function()? now;

  /// Called with the server's count after each answer.
  final void Function(String eventId, int seatsTaken)? onSeatsChanged;

  @override
  State<EventSeats> createState() => _EventSeatsState();
}

class _EventSeatsState extends State<EventSeats> {
  bool? _registered;
  bool _loadFailed = false;
  late int _taken = widget.event.seatsTaken;
  bool _busy = false;
  bool _closed = false;
  SeatFailure? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(EventSeats old) {
    super.didUpdateWidget(old);
    if (old.event.id != widget.event.id) {
      _taken = widget.event.seatsTaken;
      _registered = null;
      _loadFailed = false;
      _closed = false;
      _failure = null;
      unawaited(_load());
    } else if (old.event.seatsTaken != widget.event.seatsTaken) {
      _taken = widget.event.seatsTaken;
    }
  }

  Future<void> _load() async {
    final registrar = widget.registrar;
    if (registrar == null) return;
    try {
      final mine = await registrar.isRegistered(widget.event.id);
      if (mounted) {
        setState(() {
          _registered = mine;
          _loadFailed = false;
        });
      }
    } catch (_) {
      // Keep the last known state; an unknown one offers Cancel, which is a
      // no-op on the server when she holds no seat.
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _ask(bool reserve) async {
    final registrar = widget.registrar;
    if (registrar == null || _busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final result = reserve
          ? await registrar.register(widget.event.id)
          : await registrar.cancel(widget.event.id);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _loadFailed = false;
        _registered = result.registered;
        _taken = result.seatsTaken;
      });
      widget.onSeatsChanged?.call(widget.event.id, result.seatsTaken);
    } on EventRegistrationException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failure = error.failure;
        if (error.failure == SeatFailure.full) {
          _taken = widget.event.capacity ?? _taken;
        }
        if (error.failure == SeatFailure.closed ||
            error.failure == SeatFailure.notFound) {
          _closed = true;
        }
      });
    }
  }

  String _message(AppL10n l10n, SeatFailure failure) => switch (failure) {
    SeatFailure.full => l10n.thisEventIsFull,
    SeatFailure.closed ||
    SeatFailure.notFound => l10n.reservationsForThisEventAreClosed,
    SeatFailure.notVerified => l10n.onlyVerifiedMembersCanReserveASeat,
    SeatFailure.updateApp => l10n.updateOwnHubToReserveASeat,
    SeatFailure.offline => l10n.weCouldNotUpdateYourReservationCheck,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final event = widget.event;
    final capacity = event.capacity;
    final unknown = _registered == null && _loadFailed;
    final registered = _registered == true;
    final clock = widget.now ?? DateTime.now;
    final closed =
        _closed ||
        event.status != EventStatus.published ||
        !event.isUpcoming(clock()) ||
        !clock().toUtc().isBefore(event.startsAt);
    final remaining = capacity == null
        ? null
        : (capacity - _taken).clamp(0, capacity);
    final full = remaining == 0;
    if (capacity == null && !registered) return const SizedBox.shrink();

    final canReserve =
        widget.registrar != null &&
        _registered == false &&
        !closed &&
        !full &&
        capacity != null;
    final failure = _failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (remaining != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppPill(
              full
                  ? l10n.full
                  : l10n.remainingOfCapacitySeatsLeft(
                      '$remaining',
                      '$capacity',
                    ),
              icon: Icons.event_seat_outlined,
            ),
          ),
        if (registered)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.yourSeatIsReserved,
              style: AppText.bodyM.copyWith(color: AppColors.primary),
            ),
          ),
        if (!registered && closed && widget.registrar != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.reservationsForThisEventAreClosed,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        if (failure != null &&
            !((failure == SeatFailure.closed ||
                    failure == SeatFailure.notFound) &&
                !registered))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: AppSageNote(_message(l10n, failure)),
            ),
          ),
        if (_loadFailed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: AppSageNote(l10n.weCouldNotUpdateYourReservationCheck),
            ),
          ),
        if (_loadFailed)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => unawaited(_load()),
              child: Text(l10n.tryAgain),
            ),
          ),
        if (registered || unknown || canReserve) ...[
          const SizedBox(height: 12),
          AppButton(
            registered || unknown
                ? l10n.cancelMyReservation
                : l10n.reserveMySeat,
            variant: registered || unknown
                ? AppButtonVariant.outlined
                : AppButtonVariant.filled,
            onPressed: _busy
                ? null
                : () => unawaited(_ask(!(registered || unknown))),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ],
    );
  }
}
