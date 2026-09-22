// The eight payment states, and the nine properties that keep a woman's bank
// account out of this.
//
// `P0-PAY-01` … `P0-PAY-09`, and the two owner decisions behind them: a
// 48-hour refund window, and a platform that absorbs the refund fee.
//
// Every test here runs with no widget and no provider. That is deliberate: a
// rule about money proved through a screen is a rule a layout change can break.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coaching/domain/money.dart';
import 'package:own_hub/features/coaching/domain/payment_state_machine.dart';

final _priced = const Money.pounds(1800);
final _createdAt = DateTime(2026, 9, 16, 19, 5);

PaymentRecord _created({PaymentRail rail = PaymentRail.card}) =>
    PaymentRecord.created(
      providerTxnId: 'pmb-771',
      relId: 'coach-42__client-93',
      engagementId: 'e1',
      rail: rail,
      priced: _priced,
      createdAt: _createdAt,
    );

const PaymentLedger _ledger = PaymentLedger();

PaymentRecord _opened({PaymentRail rail = PaymentRail.card, String? reference}) {
  final result = _ledger.apply(
    _created(rail: rail),
    ProviderOpened(
      at: _createdAt.add(const Duration(seconds: 2)),
      reference: reference,
      expiresAt: reference == null
          ? null
          : _createdAt.add(const Duration(hours: 48)),
    ),
  );
  return result.record;
}

PaymentRecord _paid({PaymentRail rail = PaymentRail.card, DateTime? at}) {
  final when = at ?? _createdAt.add(const Duration(minutes: 3));
  final result = _ledger.apply(
    _opened(rail: rail),
    WebhookPaid(at: when, hmacVerifiedAt: when, amount: _priced),
  );
  return result.record;
}

void main() {
  group('a redirect is not a receipt', () {
    test('a new payment is created, never paid', () {
      expect(_created().state, PaymentState.created);
      expect(_created().paidAt, isNull);
      expect(_created().hmacVerifiedAt, isNull);
    });

    test('opening the provider page does not pay anything', () {
      final record = _opened();
      expect(record.state, PaymentState.awaitingProvider);
      expect(record.state.unlocksCoaching, isFalse);
      expect(record.capturedAmount, isNull, reason: 'nothing captured yet');
    });

    test('only a verified webhook reaches paid', () {
      // There is no event on the sealed hierarchy that means "she came back
      // from the provider", and the one that pays requires a signature
      // timestamp. This asserts the behaviour; the type asserts the rest.
      final record = _paid();
      expect(record.state, PaymentState.paid);
      expect(record.hmacVerifiedAt, isNotNull);
      expect(record.capturedAmount, _priced);
    });
  });

  group('P0-PAY-09 — the client never sends the price', () {
    test('a halved amount does not pay', () {
      final at = _createdAt.add(const Duration(minutes: 4));
      final result = _ledger.apply(
        _opened(),
        WebhookPaid(
          at: at,
          hmacVerifiedAt: at,
          amount: const Money.pounds(900),
        ),
      );

      expect(result.changed, isFalse);
      expect(result.refused, PaymentRefusal.amountMismatch);
      expect(
        result.record.state,
        PaymentState.awaitingProvider,
        reason:
            'A mismatch is refused outright. It is never split, never '
            'partially honoured, and never rounded toward the provider.',
      );
    });

    test('an amount above the price is refused too', () {
      // The asymmetric case matters: a provider that overcharges is a defect
      // in the same family, and "she paid more than we asked" must not be
      // treated as a successful capture either.
      final at = _createdAt.add(const Duration(minutes: 4));
      final result = _ledger.apply(
        _opened(),
        WebhookPaid(
          at: at,
          hmacVerifiedAt: at,
          amount: const Money.pounds(3600),
        ),
      );
      expect(result.record.state, isNot(PaymentState.paid));
      expect(result.refused, PaymentRefusal.amountMismatch);
    });
  });

  group('P0-PAY-07 — a replayed webhook cannot pay twice', () {
    test('the second identical webhook changes nothing', () {
      final paid = _paid();
      final at = _createdAt.add(const Duration(minutes: 9));
      final replay = _ledger.apply(
        paid,
        WebhookPaid(at: at, hmacVerifiedAt: at, amount: _priced),
      );

      expect(replay.changed, isFalse);
      expect(replay.refused, PaymentRefusal.alreadyApplied);
      expect(
        identical(replay.record, paid),
        isTrue,
        reason:
            'The record is returned unchanged and identical, so nothing '
            'downstream can treat the replay as a second settlement.',
      );
      expect(replay.record.paidAt, paid.paidAt);
    });

    test('the document id is the provider transaction id', () {
      // This is what makes idempotency structural rather than a guard: a
      // replay lands on the same document because it is keyed by the thing
      // the provider retries with.
      expect(_created().providerTxnId, 'pmb-771');
    });
  });

  group('P0-PAY-04 — an expired code is dead, and a reissue is new', () {
    test('only a Fawry reference can expire', () {
      final result = _ledger.apply(
        _opened(),
        ReferenceExpired(at: _createdAt.add(const Duration(hours: 50))),
      );
      expect(result.refused, PaymentRefusal.railHasNoReference);
      expect(result.record.state, PaymentState.awaitingProvider);
    });

    test('expiry reads as expired, not as failed', () {
      final fawry = _opened(rail: PaymentRail.fawry, reference: '7719 4402');
      final result = _ledger.apply(
        fawry,
        ReferenceExpired(at: _createdAt.add(const Duration(hours: 50))),
      );
      expect(result.record.state, PaymentState.expired);
      expect(result.record.state, isNot(PaymentState.failed));
      expect(result.record.state.invitesAnotherAttempt, isTrue);
    });

    test('a reissue is a new transaction and the old one stays dead', () {
      final fawry = _opened(rail: PaymentRail.fawry, reference: '7719 4402');
      final expired = _ledger
          .apply(
            fawry,
            ReferenceExpired(at: _createdAt.add(const Duration(hours: 50))),
          )
          .record;

      final fresh = _ledger.reissue(
        expired,
        newProviderTxnId: 'pmb-772',
        now: _createdAt.add(const Duration(hours: 50, minutes: 1)),
      );

      expect(fresh, isNotNull);
      expect(fresh!.providerTxnId, isNot(expired.providerTxnId));
      expect(fresh.state, PaymentState.created);
      expect(fresh.priced, expired.priced);
      expect(
        expired.state,
        PaymentState.expired,
        reason: 'the old code must stay dead, so no double charge is possible',
      );
    });

    test('reissue refuses anything that is not expired', () {
      // Otherwise "reissue" becomes a way to reopen a payment that failed, or
      // worse, one that already settled.
      for (final record in [_created(), _opened(), _paid()]) {
        expect(
          _ledger.reissue(
            record,
            newProviderTxnId: 'pmb-999',
            now: _createdAt,
          ),
          isNull,
          reason: 'reissue must refuse a ${record.state.name} payment',
        );
      }
    });

    test('reissue refuses to reuse the same transaction id', () {
      final expired = _ledger
          .apply(
            _opened(rail: PaymentRail.fawry, reference: 'x'),
            ReferenceExpired(at: _createdAt.add(const Duration(hours: 50))),
          )
          .record;
      expect(
        _ledger.reissue(
          expired,
          newProviderTxnId: expired.providerTxnId,
          now: _createdAt,
        ),
        isNull,
      );
    });
  });

  group('P0-PAY-05 — a failure is never a dead end', () {
    test('a decline fails and charges nothing', () {
      final at = _createdAt.add(const Duration(minutes: 2));
      final result = _ledger.apply(
        _opened(),
        WebhookFailed(at: at, code: 'do_not_honour'),
      );
      expect(result.record.state, PaymentState.failed);
      expect(result.record.capturedAmount, isNull);
      expect(result.record.state.invitesAnotherAttempt, isTrue);
      expect(result.record.state.holdsHerMoney, isFalse);
    });

    test('a failure cannot arrive after a payment', () {
      final result = _ledger.apply(
        _paid(),
        WebhookFailed(at: _createdAt, code: 'late'),
      );
      expect(result.changed, isFalse);
      expect(result.refused, PaymentRefusal.illegalTransition);
      expect(result.record.state, PaymentState.paid);
    });
  });

  group('refunds — 48 hours, and the platform absorbs the fee', () {
    test('the window is 48 hours', () {
      expect(RefundWindow.length, const Duration(hours: 48));
    });

    test('the boundary is inclusive', () {
      final paidAt = DateTime(2026, 9, 16, 19, 0);
      expect(
        RefundWindow.isOpen(
          paidAt: paidAt,
          now: paidAt.add(const Duration(hours: 48)),
        ),
        isTrue,
        reason:
            'a woman who taps at the instant the clock turns should not lose '
            'her money to a strict inequality',
      );
      expect(
        RefundWindow.isOpen(
          paidAt: paidAt,
          now: paidAt.add(const Duration(hours: 48, seconds: 1)),
        ),
        isFalse,
      );
    });

    test('the client bearing the fee is not expressible', () {
      // One value. A second would be a product decision and would show up in
      // review as one, rather than as a branch inside a quote calculation.
      expect(RefundFeeBearer.values, hasLength(1));
      expect(RefundFeeBearer.values.single, RefundFeeBearer.platform);
    });

    test('a refund always returns the gross, for every reason and figure', () {
      for (final gross in [
        const Money.pounds(900),
        const Money.pounds(1800),
        const Money.piastres(180050),
      ]) {
        for (final reason in RefundReason.values) {
          final quote = RefundQuote.full(gross: gross, reason: reason);
          expect(quote.amountBack, gross);
          expect(quote.feeBearer, RefundFeeBearer.platform);
        }
      }
    });

    test('a client-requested refund is bounded by the window', () {
      final paid = _paid();
      final inside = _ledger.apply(
        paid,
        RefundRequested(
          at: paid.paidAt!.add(const Duration(hours: 47)),
          reason: RefundReason.clientChangedMind,
        ),
      );
      expect(inside.record.state, PaymentState.refundPending);
      expect(inside.record.refund!.quote.amountBack, _priced);

      final outside = _ledger.apply(
        paid,
        RefundRequested(
          at: paid.paidAt!.add(const Duration(hours: 49)),
          reason: RefundReason.clientChangedMind,
        ),
      );
      expect(outside.changed, isFalse);
      expect(outside.refundRefusal, RefundRefusal.windowClosed);
      expect(outside.record.state, PaymentState.paid);
    });

    test('P0-PAY-06 — a silent coach refunds however long it took', () {
      // The promise `H03` makes before payment has no deadline attached to it.
      // The three platform-initiated reasons are never time-barred.
      final paid = _paid();
      for (final reason in [
        RefundReason.coachSilent,
        RefundReason.coachDeclined,
        RefundReason.suspended,
      ]) {
        final result = _ledger.apply(
          paid,
          RefundRequested(
            at: paid.paidAt!.add(const Duration(days: 12)),
            reason: reason,
          ),
        );
        expect(
          result.record.state,
          PaymentState.refundPending,
          reason: '$reason must refund outside the window',
        );
        expect(result.record.refund!.quote.amountBack, _priced);
      }
    });

    test('an unpaid payment cannot be refunded', () {
      // Refunding something that was never captured creates money.
      for (final record in [_created(), _opened()]) {
        final result = _ledger.apply(
          record,
          RefundRequested(
            at: _createdAt,
            reason: RefundReason.coachSilent,
          ),
        );
        expect(result.changed, isFalse);
        expect(result.refundRefusal, RefundRefusal.nothingToRefund);
      }
    });

    test('settling comes from a webhook, and only from refundPending', () {
      final paid = _paid();
      final pending = _ledger
          .apply(
            paid,
            RefundRequested(
              at: paid.paidAt!,
              reason: RefundReason.coachSilent,
            ),
          )
          .record;

      final settled = _ledger.apply(
        pending,
        WebhookRefundSettled(at: paid.paidAt!.add(const Duration(days: 3))),
      );
      expect(settled.record.state, PaymentState.refunded);
      expect(settled.record.refund!.isSettled, isTrue);

      final fromPaid = _ledger.apply(
        paid,
        WebhookRefundSettled(at: paid.paidAt!),
      );
      expect(fromPaid.changed, isFalse);
      expect(fromPaid.refused, PaymentRefusal.illegalTransition);
    });
  });

  group('disputes', () {
    test('a chargeback freezes a paid payment', () {
      final result = _ledger.apply(
        _paid(),
        ChargebackOpened(at: _createdAt.add(const Duration(days: 20))),
      );
      expect(result.record.state, PaymentState.disputed);
      expect(result.record.state.holdsHerMoney, isTrue);
    });

    test('a chargeback applies once', () {
      final disputed = _ledger
          .apply(_paid(), ChargebackOpened(at: _createdAt))
          .record;
      final again = _ledger.apply(
        disputed,
        ChargebackOpened(at: _createdAt),
      );
      expect(again.changed, isFalse);
      expect(again.refused, PaymentRefusal.alreadyApplied);
    });
  });

  group('the machine as a whole', () {
    test('there are exactly eight states', () {
      expect(PaymentState.values, hasLength(8));
    });

    test('every state is reachable by a legal sequence', () {
      // A state nothing can reach is a state nothing can test, and one that
      // will eventually be reached by a code path nobody reviewed.
      final reached = <PaymentState>{PaymentState.created};

      reached.add(_opened().state);
      reached.add(_paid().state);
      reached.add(
        _ledger
            .apply(_opened(), WebhookFailed(at: _createdAt, code: 'x'))
            .record
            .state,
      );
      reached.add(
        _ledger
            .apply(
              _opened(rail: PaymentRail.fawry, reference: 'r'),
              ReferenceExpired(at: _createdAt),
            )
            .record
            .state,
      );

      final paid = _paid();
      final pending = _ledger
          .apply(
            paid,
            RefundRequested(
              at: paid.paidAt!,
              reason: RefundReason.coachSilent,
            ),
          )
          .record;
      reached.add(pending.state);
      reached.add(
        _ledger
            .apply(pending, WebhookRefundSettled(at: paid.paidAt!))
            .record
            .state,
      );
      reached.add(
        _ledger.apply(paid, ChargebackOpened(at: paid.paidAt!)).record.state,
      );

      expect(reached, PaymentState.values.toSet());
    });

    test('nothing ever moves backwards into an unpaid state', () {
      // Once money has landed, no event in the table can make the record look
      // as though it had not.
      final paid = _paid();
      final events = <PaymentEvent>[
        ProviderOpened(at: _createdAt),
        WebhookFailed(at: _createdAt, code: 'x'),
        ReferenceExpired(at: _createdAt),
      ];
      for (final event in events) {
        final result = _ledger.apply(paid, event);
        expect(
          result.record.state,
          PaymentState.paid,
          reason: '${event.runtimeType} must not unpay a payment',
        );
      }
    });

    test('the ledger never throws, whatever it is offered', () {
      // A payment screen that crashes on an unexpected webhook is worse than
      // one that says nothing new.
      final records = <PaymentRecord>[
        _created(),
        _opened(),
        _paid(),
        _ledger
            .apply(_opened(), WebhookFailed(at: _createdAt, code: 'x'))
            .record,
      ];
      final events = <PaymentEvent>[
        ProviderOpened(at: _createdAt),
        WebhookPaid(
          at: _createdAt,
          hmacVerifiedAt: _createdAt,
          amount: _priced,
        ),
        WebhookFailed(at: _createdAt, code: 'x'),
        ReferenceExpired(at: _createdAt),
        RefundRequested(at: _createdAt, reason: RefundReason.clientChangedMind),
        WebhookRefundSettled(at: _createdAt),
        ChargebackOpened(at: _createdAt),
      ];
      for (final record in records) {
        for (final event in events) {
          expect(() => _ledger.apply(record, event), returnsNormally);
        }
      }
    });
  });
}
